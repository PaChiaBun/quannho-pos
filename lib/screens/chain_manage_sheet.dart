import 'package:flutter/material.dart';

import '../core/repositories/chain_repository.dart';

const _kOrange = Color(0xFFFF6B35);
const _kGreen = Color(0xFF2E7D32);
const _kMuted = Color(0xFF9E9085);

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
  );
}

/// Tạo chuỗi, thêm/gỡ cửa hàng. Mọi thao tác do server kiểm quyền và ghi audit.
class ChainManageSheet extends StatefulWidget {
  final ChainRepository repo;
  final MyChains mine;
  final String? chainId;
  const ChainManageSheet({super.key, required this.repo, required this.mine, required this.chainId});

  @override
  State<ChainManageSheet> createState() => _ChainManageSheetState();
}

class _ChainManageSheetState extends State<ChainManageSheet> {
  late MyChains _mine = widget.mine;
  late String? _chainId = widget.chainId;
  final _name = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await job();
      final fresh = await widget.repo.listMine();
      if (mounted) setState(() => _mine = fresh);
    } on ChainException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    } catch (_) {
      if (mounted) setState(() => _msg = 'Không thực hiện được. Kiểm tra kết nối rồi thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(StoreChain chain, ChainStoreRef s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gỡ khỏi chuỗi?'),
        content: Text('${s.name} sẽ không còn trong báo cáo gộp của "${chain.name}". Dữ liệu cửa hàng không bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gỡ')),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.repo.removeStore(chain.id, s.storeId));
  }

  @override
  Widget build(BuildContext context) {
    StoreChain? chain;
    for (final c in _mine.chains) {
      if (c.id == _chainId) chain = c;
    }
    chain ??= _mine.chains.isEmpty ? null : _mine.chains.first;
    final free = _mine.ownedStores.where((s) => s.chainId == null).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Quản lý chuỗi cửa hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Chỉ Chủ quán lập được chuỗi. Chuỗi chỉ gộp báo cáo; menu, kho, nhân viên, bàn và doanh thu của mỗi cửa hàng vẫn tách riêng.',
            style: TextStyle(color: _kMuted, fontSize: 12.5),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: _Banner(text: _msg!, color: Colors.red.shade700)),
          const SizedBox(height: 12),
          if (chain != null) ...[
            Text('Cửa hàng trong "${chain.name}"', style: const TextStyle(fontWeight: FontWeight.w800)),
            for (final s in chain.stores)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                subtitle: Text('Mã ${s.storeCode}'),
                trailing: IconButton(
                  tooltip: 'Gỡ khỏi chuỗi',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _busy ? null : () => _confirmRemove(chain!, s),
                ),
              ),
            if (free.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Thêm cửa hàng của bạn', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final s in free)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  subtitle: Text('Mã ${s.storeCode}'),
                  trailing: IconButton(
                    tooltip: 'Thêm vào chuỗi',
                    icon: const Icon(Icons.add_circle_outline, color: _kGreen),
                    onPressed: _busy ? null : () => _run(() => widget.repo.addStore(chain!.id, s.storeId)),
                  ),
                ),
            ],
            const Divider(height: 28),
          ],
          const Text('Tạo chuỗi mới', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(hintText: 'Tên chuỗi', border: OutlineInputBorder(), isDense: true, counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kOrange),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final id = await widget.repo.createChain(_name.text);
                      _chainId = id;
                      _name.clear();
                    }),
              child: const Text('Tạo'),
            ),
          ]),
        ]),
      ),
    );
  }
}
