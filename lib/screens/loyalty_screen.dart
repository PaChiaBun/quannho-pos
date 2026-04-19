import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../core/database/app_database.dart';
import '../core/providers/app_providers.dart';
import '../modules/loyalty/repository/loyalty_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY PROVIDERS — local trong file này
// ─────────────────────────────────────────────────────────────────────────────
final _loyaltyRepoProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );
});

final _topCustomersProvider = StreamProvider<List<CoreCustomer>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchTopCustomers(limit: 30);
});

final _allCustomersProvider = StreamProvider<List<CoreCustomer>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchCustomers();
});

final _loyaltyStatsProvider = FutureProvider<LoyaltyStats>((ref) {
  ref.watch(_topCustomersProvider); // auto-refresh
  return ref.read(_loyaltyRepoProvider).getStats();
});

final _rewardsProvider = StreamProvider<List<LoyaltyReward>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchRewards();
});

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_loyaltyStatsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'loyalty_fab',
        onPressed: _openAddCustomer,
        backgroundColor: _kPurple,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Thêm khách',
          style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          _buildHeader(statsAsync),

          // ── TabBar ────────────────────────────────────────────────
          Container(
            color: _kNavy,
            child: TabBar(
              controller: _tab,
              indicatorColor: _kGold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Khách hàng'),
                Tab(text: 'Phần thưởng'),
              ],
            ),
          ),

          // ── Search (only on customers tab) ────────────────────────
          _buildSearch(),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildCustomerList(),
                _buildRewardsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<LoyaltyStats> statsAsync) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A148C), _kPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Điểm thưởng',
                    style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900, letterSpacing: -0.3,
                    )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 26),
                    onPressed: _openAddReward,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              statsAsync.when(
                loading: () => const SizedBox(height: 72,
                  child: Center(child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(
                  children: [
                    _HeaderStatTile(
                      value: '${stats.totalCustomers}',
                      label: 'Khách hàng',
                      icon: Icons.people_rounded,
                    ),
                    _HeaderStatTile(
                      value: '${stats.customersWithPts}',
                      label: 'Có điểm',
                      icon: Icons.stars_rounded,
                      highlight: true,
                    ),
                    _HeaderStatTile(
                      value: _fmtPts(stats.totalActivePts),
                      label: 'Tổng điểm',
                      icon: Icons.loyalty_rounded,
                    ),
                    _HeaderStatTile(
                      value: _fmtPts(stats.totalPtsRedeemed),
                      label: 'Đã dùng',
                      icon: Icons.redeem_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSearch() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Tìm khách hàng...',
        hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded,
            color: _kMuted, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: _kMuted, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                })
            : null,
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // CUSTOMER LIST
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCustomerList() {
    final async = ref.watch(_allCustomersProvider);
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kPurple)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (customers) {
        final q = _searchCtrl.text.toLowerCase();
        final filtered = q.isEmpty
            ? customers
            : customers.where((c) =>
                c.name.toLowerCase().contains(q) ||
                (c.phone?.contains(q) ?? false)).toList();

        if (filtered.isEmpty) {
          return _emptyState(
            Icons.people_outline_rounded, 'Chưa có khách hàng nào');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _CustomerCard(
            customer: filtered[i],
            rank: i + 1,
            onTap: () => _openCustomerDetail(filtered[i]),
          )
              .animate(delay: (i * 35).ms)
              .fadeIn(duration: 200.ms)
              .slideX(begin: 0.05, end: 0, duration: 200.ms),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REWARDS LIST
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRewardsList() {
    final async = ref.watch(_rewardsProvider);
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kPurple)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (rewards) {
        if (rewards.isEmpty) {
          return _emptyState(
            Icons.card_giftcard_rounded,
            'Chưa có phần thưởng nào\nNhấn + để thêm',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: rewards.length,
          itemBuilder: (_, i) => _RewardCard(reward: rewards[i])
              .animate(delay: (i * 40).ms)
              .fadeIn(duration: 200.ms),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 72,
          color: _kMuted.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: _kMuted)),
      ],
    ),
  );

  void _openCustomerDetail(CoreCustomer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDetailSheet(customer: customer),
    );
  }

  void _openAddCustomer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCustomerSheet(
        onSaved: (name, phone, email, note) async {
          try {
            await ref.read(customerRepositoryProvider).create(
              name: name, phone: phone.isEmpty ? null : phone,
              email: email.isEmpty ? null : email, note: note.isEmpty ? null : note,
            );
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'),
                  behavior: SnackBarBehavior.floating));
            }
          }
        },
      ),
    );
  }

  void _openAddReward() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💡 Thêm phần thưởng — sắp ra mắt'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final CoreCustomer customer;
  final int rank;
  final VoidCallback onTap;

  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);

  const _CustomerCard({
    required this.customer,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pts = customer.loyaltyPts;
    final tier = _tier(pts);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          leading: Stack(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tier.color.withValues(alpha: 0.7), tier.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (rank <= 3)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: rank == 1 ? _kGold
                          : rank == 2 ? Colors.grey
                          : const Color(0xFFCD7F32),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$rank',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(customer.name,
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: _kInk)),
          subtitle: Row(
            children: [
              if (customer.phone != null) ...[
                const Icon(Icons.phone_rounded,
                    size: 11, color: _kMuted),
                const SizedBox(width: 3),
                Text(customer.phone!,
                  style: const TextStyle(
                    fontSize: 11, color: _kMuted)),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tier.name,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: tier.color)),
              ),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded,
                    size: 14, color: _kGold),
                  const SizedBox(width: 3),
                  Text('${pts.toStringAsFixed(0)} điểm',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: _kInk)),
                ],
              ),
              Text('Chi: ${_fmtShort(customer.totalSpent)}đ',
                style: const TextStyle(
                  fontSize: 11, color: _kMuted)),
            ],
          ),
        ),
      ),
    );
  }

  _TierInfo _tier(double pts) {
    if (pts >= 500) return _TierInfo('VIP 💎', const Color(0xFF1565C0));
    if (pts >= 200) return _TierInfo('Vàng ⭐', _kGold);
    if (pts >= 50)  return _TierInfo('Bạc 🥈', Colors.grey);
    return _TierInfo('Đồng 🥉', const Color(0xFF8D6E63));
  }
}

class _TierInfo {
  final String name;
  final Color color;
  const _TierInfo(this.name, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// REWARD CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RewardCard extends StatelessWidget {
  final LoyaltyReward reward;
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _kPurple.withValues(alpha: 0.15)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.card_giftcard_rounded,
            color: _kPurple, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reward.name,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _kInk)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.stars_rounded,
                    size: 13, color: _kGold),
                  const SizedBox(width: 3),
                  Text(
                    '${reward.ptsRequired.toStringAsFixed(0)} điểm',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: _kGold)),
                ],
              ),
            ],
          ),
        ),
        if (reward.discountAmount != null)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '-${_fmtShort(reward.discountAmount!)}đ',
              style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w800)),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerDetailSheet extends ConsumerWidget {
  final CoreCustomer customer;
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);

  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo  = LoyaltyRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appEventBusProvider),
    );
    final txAsync = ref.watch(
      StreamProvider.autoDispose((r) =>
          repo.watchTransactions(customer.id)));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A148C), _kPurple]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name,
                        style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: _kInk)),
                      if (customer.phone != null)
                        Text(customer.phone!,
                          style: const TextStyle(
                            fontSize: 13, color: _kMuted)),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                    color: _kPurple, size: 20),
                  tooltip: 'Sửa thông tin',
                  onPressed: () => _openEditCustomerSheet(
                    context, ref, customer),
                  style: IconButton.styleFrom(
                    backgroundColor: _kPurple.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 6),
                // Điểm hiện tại
                Column(
                  children: [
                    const Icon(Icons.stars_rounded,
                      color: _kGold, size: 24),
                    Text('${customer.loyaltyPts.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: _kPurple)),
                    const Text('điểm',
                      style: TextStyle(fontSize: 11, color: _kMuted)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            child: Row(
              children: [
                _InfoTile(
                  label: 'Tổng chi',
                  value: '${_fmtShort(customer.totalSpent)}đ',
                  icon: Icons.payments_rounded,
                ),
                _InfoTile(
                  label: 'Số lần',
                  value: '${customer.visitCount}',
                  icon: Icons.receipt_long_rounded,
                ),
                _InfoTile(
                  label: 'Điểm tích',
                  value: '${customer.loyaltyPts.toStringAsFixed(0)}',
                  icon: Icons.stars_rounded,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // Transaction history
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              Icon(Icons.history_rounded,
                size: 16, color: _kMuted),
              SizedBox(width: 6),
              Text('Lịch sử điểm',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _kMuted)),
            ]),
          ),

          Expanded(
            child: txAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kPurple)),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (txs) {
                if (txs.isEmpty) {
                  return const Center(
                    child: Text('Chưa có lịch sử',
                      style: TextStyle(color: _kMuted)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: txs.length,
                  itemBuilder: (_, i) {
                    final t = txs[i];
                    final isEarn = t.ptsEarned > 0;
                    final dt = t.createdAt != null
                        ? DateTime.fromMillisecondsSinceEpoch(t.createdAt!)
                        : DateTime.now();
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: (isEarn ? _kGold : _kPurple)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEarn
                              ? Icons.add_rounded
                              : Icons.remove_rounded,
                          size: 16,
                          color: isEarn ? _kGold : _kPurple,
                        ),
                      ),
                      title: Text(t.note ?? (isEarn ? 'Tích điểm' : 'Đổi điểm'),
                        style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                        style: const TextStyle(fontSize: 11, color: _kMuted)),
                      trailing: Text(
                        '${isEarn ? '+' : '-'}${(isEarn ? t.ptsEarned : t.ptsUsed).toStringAsFixed(0)} pt',
                        style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13,
                          color: isEarn ? _kGold : _kPurple)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kInk    = Color(0xFF1A1207);

  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 18, color: _kPurple),
        const SizedBox(height: 4),
        Text(value,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: _kInk)),
        Text(label,
          style: const TextStyle(fontSize: 10, color: _kMuted)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER STAT TILE
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderStatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final bool highlight;
  const _HeaderStatTile({
    required this.value, required this.label, required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0x33F9A825)
            : const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon,
            color: highlight ? const Color(0xFFF9A825) : Colors.white70,
            size: 18),
          const SizedBox(height: 4),
          Text(value,
            style: const TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          Text(label,
            style: const TextStyle(
              color: Colors.white54, fontSize: 9,
              fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmtPts(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD CUSTOMER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddCustomerSheet extends StatefulWidget {
  final Future<void> Function(String name, String phone, String email, String note) onSaved;
  const _AddCustomerSheet({required this.onSaved});

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  bool _saving = false;

  static const _kPurple = Color(0xFF7B1FA2);
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                      color: _kPurple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Thêm khách hàng',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: _kNavy)),
                ],
              ),
              const SizedBox(height: 20),

              // Name (required)
              _Field(
                ctrl: _nameCtrl, label: 'Tên khách hàng *',
                icon: Icons.person_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 12),

              // Phone
              _Field(
                ctrl: _phoneCtrl, label: 'Số điện thoại',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Email
              _Field(
                ctrl: _emailCtrl, label: 'Email',
                icon: Icons.email_rounded,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // Note
              _Field(
                ctrl: _noteCtrl, label: 'Ghi chú',
                icon: Icons.note_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu khách hàng',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSaved(
      _nameCtrl.text.trim(),
      _phoneCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _noteCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  final int maxLines;

  static const _kPurple = Color(0xFF7B1FA2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  const _Field({
    required this.ctrl, required this.label, required this.icon,
    this.validator, this.keyboard, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    validator: validator,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: _kPurple, size: 18),
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPurple, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 12),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OPEN EDIT CUSTOMER
// ─────────────────────────────────────────────────────────────────────────────
void _openEditCustomerSheet(
    BuildContext context, WidgetRef ref, CoreCustomer customer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditCustomerSheet(
      customer: customer,
      onSaved: (name, phone, email, note) async {
        await ref.read(customerRepositoryProvider).update(
          customer.id,
          CoreCustomersCompanion(
            name:  Value(name),
            phone: Value(phone.isEmpty ? null : phone),
            email: Value(email.isEmpty ? null : email),
            note:  Value(note.isEmpty  ? null : note),
          ),
        );
        if (ctx.mounted) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã cập nhật thông tin khách'),
              behavior: SnackBarBehavior.floating),
          );
        }
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT CUSTOMER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EditCustomerSheet extends StatefulWidget {
  final CoreCustomer customer;
  final Future<void> Function(
      String name, String phone, String email, String note) onSaved;

  const _EditCustomerSheet({required this.customer, required this.onSaved});

  @override
  State<_EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<_EditCustomerSheet> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _noteCtrl;
  bool _saving = false;

  static const _kPurple = Color(0xFF7B1FA2);
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kRed    = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.customer.name);
    _phoneCtrl = TextEditingController(text: widget.customer.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.customer.email ?? '');
    _noteCtrl  = TextEditingController(text: widget.customer.note  ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_rounded,
                      color: _kPurple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sửa thông tin',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: _kNavy)),
                        Text(widget.customer.name,
                          style: const TextStyle(
                            fontSize: 12, color: _kMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _Field(ctrl: _nameCtrl, label: 'Tên khách hàng *',
                icon: Icons.person_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên' : null),
              const SizedBox(height: 12),

              _Field(ctrl: _phoneCtrl, label: 'Số điện thoại',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone),
              const SizedBox(height: 12),

              _Field(ctrl: _emailCtrl, label: 'Email',
                icon: Icons.email_rounded,
                keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),

              _Field(ctrl: _noteCtrl, label: 'Ghi chú',
                icon: Icons.note_rounded, maxLines: 2),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  // Delete button
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.person_remove_rounded, size: 18),
                    label: const Text('Xoá',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  // Save button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSaved(
      _nameCtrl.text.trim(),
      _phoneCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _noteCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá khách hàng?',
          style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Thông tin "${widget.customer.name}" sẽ bị ẩn khỏi danh sách. Lịch sử giao dịch vẫn được lưu.',
          style: const TextStyle(color: _kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: call softDelete from ref
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}
