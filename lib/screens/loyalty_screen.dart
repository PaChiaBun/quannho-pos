import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/money_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

=======
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../core/database/app_database.dart';
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
import '../core/providers/app_providers.dart';
import '../modules/loyalty/repository/loyalty_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY PROVIDERS — local trong file này
// ─────────────────────────────────────────────────────────────────────────────
final _loyaltyRepoProvider = Provider<LoyaltyRepository>((ref) {
<<<<<<< HEAD
  return LoyaltyRepository();
});

final _topCustomersProvider = StreamProvider<List<LoyaltyCustomerModel>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchTopCustomers(limit: 30);
});

final _allCustomersProvider = StreamProvider<List<LoyaltyCustomerModel>>((ref) {
=======
  return LoyaltyRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );
});

final _topCustomersProvider = StreamProvider<List<CoreCustomer>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchTopCustomers(limit: 30);
});

final _allCustomersProvider = StreamProvider<List<CoreCustomer>>((ref) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  return ref.watch(_loyaltyRepoProvider).watchCustomers();
});

final _loyaltyStatsProvider = FutureProvider<LoyaltyStats>((ref) {
  ref.watch(_topCustomersProvider); // auto-refresh
  return ref.read(_loyaltyRepoProvider).getStats();
});

<<<<<<< HEAD
final _rewardsProvider = StreamProvider<List<LoyaltyRewardModel>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchRewards();
});

final _packagesProvider = FutureProvider<List<TopupPackageModel>>((ref) async {
  return ref.read(_loyaltyRepoProvider).getPackages();
});

=======
final _rewardsProvider = StreamProvider<List<LoyaltyReward>>((ref) {
  return ref.watch(_loyaltyRepoProvider).watchRewards();
});

>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
  int _tabIndex = 0;
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

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
<<<<<<< HEAD
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging || _tab.index != _tabIndex) {
        setState(() => _tabIndex = _tab.index);
      }
    });
    // Seed gói mặc định nếu store chưa có
    Future.microtask(() async {
      await ref.read(_loyaltyRepoProvider).seedDefaultPackagesIfEmpty();
      ref.refresh(_packagesProvider);
    });
=======
    _tab = TabController(length: 2, vsync: this);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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

<<<<<<< HEAD
    final mainBody = Column(
=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
                Tab(text: 'Khách'),
                Tab(text: 'Ví'),
                Tab(text: 'Thưởng'),
                Tab(text: 'Gói nạp'),
=======
                Tab(text: 'Khách hàng'),
                Tab(text: 'Phần thưởng'),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              ],
            ),
          ),

<<<<<<< HEAD
          // ── Search (chỉ tab Khách hàng) ───────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _tabIndex == 0 ? _buildSearch() : const SizedBox.shrink(),
          ),
=======
          // ── Search (only on customers tab) ────────────────────────
          _buildSearch(),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildCustomerList(),
<<<<<<< HEAD
                _buildWalletSummary(),
                _buildRewardsList(),
                _buildPackagesTab(),
=======
                _buildRewardsList(),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              ],
            ),
          ),
        ],
<<<<<<< HEAD
      );

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _tabIndex == 3
          ? FloatingActionButton.extended(
              key: const ValueKey('fab_pkg'),
              heroTag: 'loyalty_fab_pkg',
              onPressed: () => _openEditPackage(),
              backgroundColor: _kNavy,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Thêm gói',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : FloatingActionButton.extended(
              key: const ValueKey('fab_cust'),
              heroTag: 'loyalty_fab_cust',
              onPressed: _openAddCustomer,
              backgroundColor: _kPurple,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Thêm khách',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainBody),
              SizedBox(
                width: 280,
                child: _LoyaltyRightPanel(statsAsync: statsAsync),
              ),
            ]);
          }
          return mainBody;
        },
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
          colors: [Color(0xFF1E1C5E), Color(0xFF4A148C)],
=======
          colors: [Color(0xFF4A148C), _kPurple],
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
<<<<<<< HEAD
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ─────────────────────────────────────────
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Khách hàng thân thiết',
                    style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  Text('Loyalty & Ví điện tử',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
                const Spacer(),
                _CircleIconBtn(icon: Icons.card_giftcard_rounded,
                  onTap: _openAddReward),
              ]),
              const SizedBox(height: 14),

              // ── Stats row ─────────────────────────────────────────
              statsAsync.when(
                loading: () => const SizedBox(height: 66,
                  child: Center(child: CircularProgressIndicator(
                    color: Colors.white38, strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(children: [
                  _StatPill(value: '${stats.totalCustomers}',
                    label: 'Khách', icon: Icons.people_alt_rounded),
                  const SizedBox(width: 8),
                  _StatPill(value: '${stats.customersWithPts}',
                    label: 'Có điểm', icon: Icons.stars_rounded, highlight: true),
                  const SizedBox(width: 8),
                  _StatPill(value: _fmtPts(stats.totalActivePts),
                    label: 'Điểm active', icon: Icons.loyalty_rounded),
                  const SizedBox(width: 8),
                  _StatPill(value: _fmtPts(stats.totalPtsRedeemed),
                    label: 'Đã đổi', icon: Icons.redeem_rounded),
                ]),
=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
    final q = _searchCtrl.text.toLowerCase();
=======
        final q = _searchCtrl.text.toLowerCase();
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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

<<<<<<< HEAD
  // ─────────────────────────────────────────────────────────────────────────
  // WALLET SUMMARY TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWalletSummary() {
    final async = ref.watch(_allCustomersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (customers) {
        final withWallet = customers.where((c) => c.hasWallet).toList()
          ..sort((a, b) => b.totalWallet.compareTo(a.totalWallet));
        final totalReal  = withWallet.fold<double>(0, (s, c) => s + c.realBalance);
        final totalBonus = withWallet.fold<double>(0, (s, c) => s + c.bonusBalance);
        return Column(children: [
          Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1C5E), Color(0xFF4A148C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: const Color(0xFF1E1C5E).withValues(alpha: 0.25),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white54, size: 12),
                const SizedBox(width: 4),
                const Text('Tổng ví thật',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3),
              Text(_fmtMoney(totalReal),
                style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const Text('Tiền thật đã nạp',
                style: TextStyle(color: Colors.white38, fontSize: 9)),
            ])),
            Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.15)),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.card_giftcard_rounded,
                    color: Color(0xFFF9A825), size: 12),
                  const SizedBox(width: 4),
                  const Text('Tổng bonus',
                    style: TextStyle(color: Color(0xFFF9A825), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 3),
                Text(_fmtMoney(totalBonus),
                  style: const TextStyle(color: Color(0xFFF9A825),
                    fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const Text('Phần thưởng tích luỹ',
                  style: TextStyle(color: Colors.white38, fontSize: 9)),
              ]),
            )),
          ]),
        ),
          if (withWallet.isEmpty)
            Expanded(child: _emptyState(Icons.account_balance_wallet_rounded, 'Chưa có khách nào nạp tiền')),
          if (withWallet.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: withWallet.length,
                itemBuilder: (_, i) {
                  final c = withWallet[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32), fontSize: 16, fontWeight: FontWeight.w900))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
                        if (c.phone != null)
                          Text(c.phone!, style: const TextStyle(fontSize: 11, color: _kMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          _WalletChip(
                            label: _fmtMoney(c.realBalance),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF2E7D32)),
                          if (c.bonusBalance > 0) ...[
                            const SizedBox(width: 6),
                            _WalletChip(
                              label: '+${_fmtMoney(c.bonusBalance)}',
                              icon: Icons.card_giftcard_rounded,
                              color: _kGold),
                          ],
                        ]),
                      ])),
                      TextButton.icon(
                        onPressed: () => _openTopUp(c),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Nạp',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ]),
                  ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms);
                },
              ),
            ),
        ]);
      },
    );
  }

  void _openTopUp(LoyaltyCustomerModel customer) {
    final packagesAsync = ref.read(_packagesProvider);
    final packages = packagesAsync.when(
      data: (d) => d, loading: () => <TopupPackageModel>[], error: (_, __) => <TopupPackageModel>[]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TopUpSheet(
        customer: customer,
        packages: packages,
        onTopUp: (real, bonus, months) async {
          try {
            await ref.read(_loyaltyRepoProvider).topUpWallet(
              customerId: customer.id,
              realAmount: real,
              bonusAmount: bonus,
              bonusMonths: months,
              customerName: customer.name, // để finance_records rõ tên khách
            );
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('✅ Đã nạp ${_fmtMoney(real)} cho ${customer.name}'),
                backgroundColor: const Color(0xFF2E7D32),
                behavior: SnackBarBehavior.floating,
              ));
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('Lỗi: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PACKAGES TAB — Quản lý gói nạp tiền
  // ─────────────────────────────────────────────────────────────────────────
  // Tier colors cho gói nạp
  static const _tierColors = [
    Color(0xFFB87333), // Đồng
    Color(0xFF9E9E9E), // Bạc
    Color(0xFFF9A825), // Vàng
    Color(0xFF4A148C), // Bạch Kim
    Color(0xFF00BCD4), // Kim Cương
  ];

  Widget _buildPackagesTab() {
    final async = ref.watch(_packagesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: _kMuted, size: 48),
        const SizedBox(height: 12),
        Text('Lỗi tải gói: $e', style: const TextStyle(color: _kMuted, fontSize: 13),
          textAlign: TextAlign.center),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () => ref.refresh(_packagesProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
        ),
      ])),
      data: (packages) => Column(children: [
        // ── Header thông tin ─────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kNavy.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _kNavy, size: 16),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'Khi nạp tiền, hệ thống tự động áp dụng gói phù hợp nhất và tính bonus.',
              style: TextStyle(fontSize: 12, color: _kNavy, height: 1.4))),
          ]),
        ),

        if (packages.isEmpty) ...[
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.loyalty_rounded, color: _kPurple, size: 38),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có gói nạp nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 6),
            const Text('Nhấn + để thêm gói, hoặc tải gói mặc định',
              style: TextStyle(fontSize: 13, color: _kMuted)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(_loyaltyRepoProvider).seedDefaultPackagesIfEmpty();
                ref.refresh(_packagesProvider);
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Tải gói mặc định'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPurple,
                side: const BorderSide(color: _kPurple),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ])),
        ] else ...[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: packages.length,
              itemBuilder: (_, i) {
                final pkg = packages[i];
                final tierColor = _tierColors[i.clamp(0, _tierColors.length - 1)];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(children: [
                    // Tier badge
                    Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tierColor.withValues(alpha: 0.8), tierColor],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16)),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('+${pkg.bonusPct.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w900)),
                        const Text('bonus', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ),
                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pkg.name, style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: _kInk)),
                          const SizedBox(height: 3),
                          RichText(text: TextSpan(children: [
                            const TextSpan(text: 'Nạp từ ',
                              style: TextStyle(fontSize: 12, color: _kMuted)),
                            TextSpan(text: _fmtMoney(pkg.minAmount),
                              style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: _kInk)),
                            TextSpan(text: ' → bonus ${_fmtMoney(pkg.minAmount * pkg.bonusPct / 100)}+',
                              style: TextStyle(fontSize: 12, color: tierColor,
                                fontWeight: FontWeight.w600)),
                          ])),
                        ]),
                      ),
                    ),
                    // Actions
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(Icons.edit_rounded, size: 17, color: _kPurple),
                        onPressed: () => _openEditPackage(pkg),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 17,
                          color: Colors.red.shade300),
                        onPressed: () => _confirmDeletePackage(pkg),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                  ]),
                ).animate(delay: (i * 40).ms).fadeIn(duration: 200.ms);
              },
            ),
          ),
        ],
      ]),
    );
  }

  void _openEditPackage([TopupPackageModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PackageEditSheet(
        existing: existing,
        onSave: (pkg) async {
          await ref.read(_loyaltyRepoProvider).upsertPackage(pkg);
          ref.refresh(_packagesProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDeletePackage(TopupPackageModel pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá gói nạp?'),
        content: Text('Xác nhận xoá gói "${pkg.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () async {
              await ref.read(_loyaltyRepoProvider).deletePackage(pkg.id);
              ref.refresh(_packagesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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

<<<<<<< HEAD
  void _openCustomerDetail(LoyaltyCustomerModel customer) {
=======
  void _openCustomerDetail(CoreCustomer customer) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddRewardSheet(
        onSaved: (name, pts, desc) async {
<<<<<<< HEAD
          final repo = ref.read(_loyaltyRepoProvider);
          await repo.createReward(name: name, ptsRequired: pts);
=======
          final repo = LoyaltyRepository(
            ref.read(appDatabaseProvider),
            ref.read(appEventBusProvider),
          );
          await repo.createReward(
            name: name, ptsRequired: pts);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text('✅ Đã thêm phần thưởng "$name"'),
              behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
<<<<<<< HEAD
  final LoyaltyCustomerModel customer;
=======
  final CoreCustomer customer;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
              Text('Chi: ${_fmtShort(customer.totalSpent)}',
=======
              Text('Chi: ${_fmtShort(customer.totalSpent)}đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
  final LoyaltyRewardModel reward;
=======
  final LoyaltyReward reward;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
              '-${_fmtShort(reward.discountAmount!)}',
=======
              '-${_fmtShort(reward.discountAmount!)}đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
  final LoyaltyCustomerModel customer;
=======
  final CoreCustomer customer;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);

  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
<<<<<<< HEAD
    final repo = ref.watch(_loyaltyRepoProvider);
=======
    final repo  = LoyaltyRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appEventBusProvider),
    );
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
                  value: '${_fmtShort(customer.totalSpent)}',
=======
                  value: '${_fmtShort(customer.totalSpent)}đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
                    final dt = DateTime.tryParse(t.createdAt) ?? DateTime.now();
=======
                    final dt = t.createdAt != null
                        ? DateTime.fromMillisecondsSinceEpoch(t.createdAt!)
                        : DateTime.now();
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD

=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
    BuildContext context, WidgetRef ref, LoyaltyCustomerModel customer) {
=======
    BuildContext context, WidgetRef ref, CoreCustomer customer) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditCustomerSheet(
      customer: customer,
      onSaved: (name, phone, email, note) async {
<<<<<<< HEAD
        // ‼️ FIX: chỉ update email/note khi user thực sự điền vào
        // Tránh override dữ liệu cũ trong DB khi field bị bỏ trống
        final updateMap = <String, dynamic>{
          'name':  name,
          'phone': phone.isEmpty ? null : phone,
        };
        if (email.isNotEmpty) updateMap['email'] = email;
        if (note.isNotEmpty)  updateMap['note']  = note;

        await ref.read(customerRepositoryProvider).update(
          customer.id,
          updateMap,
=======
        await ref.read(customerRepositoryProvider).update(
          customer.id,
          CoreCustomersCompanion(
            name:  Value(name),
            phone: Value(phone.isEmpty ? null : phone),
            email: Value(email.isEmpty ? null : email),
            note:  Value(note.isEmpty  ? null : note),
          ),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
  final LoyaltyCustomerModel customer;
=======
  final CoreCustomer customer;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
    // ‼️ FIX: email & note không có trong LoyaltyCustomerModel (lightweight model)
    // Giữ '' để tránh override dữ liệu cũ nếu user không điền
    // onSaved callback chỉ gửi email/note khi isNotEmpty — tránh clear dữ liệu DB
    _emailCtrl = TextEditingController(text: '');
    _noteCtrl  = TextEditingController(text: '');
=======
    _emailCtrl = TextEditingController(text: widget.customer.email ?? '');
    _noteCtrl  = TextEditingController(text: widget.customer.note  ?? '');
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
    // Lấy ref từ context — cần trong StatefulWidget của ConsumerStatefulWidget
    // _EditCustomerSheet là StatefulWidget thường, không có ref trực tiếp
    // Dùng Builder để lấy ref từ Consumer widget cha
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
            onPressed: () async {
              Navigator.pop(ctx);    // đóng dialog confirm
              // ‼️ FIX: gọi softDelete thực sự — customerRepositoryProvider từ app_providers
              try {
                // Dùng Supabase trực tiếp vì _EditCustomerSheet không có WidgetRef
                await Supabase.instance.client
                    .from('customers')
                    .update({'is_deleted': true})
                    .eq('id', widget.customer.id);
              } catch (_) {}
              if (context.mounted) Navigator.pop(context); // đóng bottomsheet
=======
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: call softDelete from ref
              Navigator.pop(context);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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

// ─────────────────────────────────────────────────────────────────────────────
// ADD REWARD SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddRewardSheet extends StatefulWidget {
  final Future<void> Function(
      String name, double ptsRequired, String description) onSaved;

  const _AddRewardSheet({required this.onSaved});

  @override
  State<_AddRewardSheet> createState() => _AddRewardSheetState();
}

class _AddRewardSheetState extends State<_AddRewardSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _ptsCtrl   = TextEditingController();
  final _descCtrl  = TextEditingController();
  bool _saving     = false;
  double _ptsPreview = 0;

  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  // Quick presets mẫu
  static const _presets = [
    _RewardPreset('☕ Cà phê miễn phí', 50),
    _RewardPreset('🥤 Nước uống miễn phí', 30),
    _RewardPreset('🎁 Giảm 10%', 100),
    _RewardPreset('🍜 Phần ăn miễn phí', 200),
    _RewardPreset('🎂 Bánh sinh nhật', 150),
  ];

  @override
  void initState() {
    super.initState();
    _ptsCtrl.addListener(() {
      final v = double.tryParse(_ptsCtrl.text) ?? 0;
      setState(() => _ptsPreview = v);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _ptsCtrl.dispose(); _descCtrl.dispose();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A148C), _kPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Thêm phần thưởng',
                    style: TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.w800))),
                  if (_ptsPreview > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kGold,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('${_ptsPreview.toStringAsFixed(0)} điểm',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800)),
                    ),
                ]),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick presets
                      const Text('Chọn mẫu nhanh:',
                        style: TextStyle(fontSize: 12, color: _kMuted,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _presets.map((p) => GestureDetector(
                          onTap: () {
                            _nameCtrl.text = p.name;
                            _ptsCtrl.text = p.pts.toString();
                            setState(() => _ptsPreview = p.pts.toDouble());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _kBorder)),
                            child: Text(p.name,
                              style: const TextStyle(
                                fontSize: 12, color: _kNavy,
                                fontWeight: FontWeight.w600)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Tên phần thưởng
                      _Field(ctrl: _nameCtrl, label: 'Tên phần thưởng *',
                        icon: Icons.card_giftcard_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên' : null),
                      const SizedBox(height: 12),

                      // Điểm yêu cầu
                      _Field(ctrl: _ptsCtrl, label: 'Điểm yêu cầu *',
                        icon: Icons.stars_rounded,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return (n == null || n <= 0) ? 'Nhập điểm > 0' : null;
                        }),
                      const SizedBox(height: 12),

                      // Mô tả
                      _Field(ctrl: _descCtrl, label: 'Mô tả (tuỳ chọn)',
                        icon: Icons.description_rounded, maxLines: 2),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.add_circle_rounded),
                          label: Text(
                            _saving ? 'Đang lưu...' : 'Thêm phần thưởng',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final pts = double.tryParse(_ptsCtrl.text) ?? 0;
    await widget.onSaved(_nameCtrl.text.trim(), pts, _descCtrl.text.trim());
    if (mounted) setState(() => _saving = false);
  }
}

class _RewardPreset {
  final String name;
  final int pts;
  const _RewardPreset(this.name, this.pts);
}
<<<<<<< HEAD

// ─────────────────────────────────────────────────────────────────────────────
// _StatPill — Compact stat badge cho header
// ─────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;
  const _StatPill({required this.value, required this.label,
    required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
          ? const Color(0xFFF9A825).withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
            ? const Color(0xFFF9A825).withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: highlight ? const Color(0xFFF9A825) : Colors.white60, size: 16),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(
          color: highlight ? const Color(0xFFF9A825) : Colors.white,
          fontSize: 15, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(
          color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _CircleIconBtn — Nút tròn transparent cho header
// ─────────────────────────────────────────────────────────────────────────────
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _WalletChip — Badge hiển thị số dư ví
// ─────────────────────────────────────────────────────────────────────────────
class _WalletChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _WalletChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopUpSheet — Sheet nạp tiền vào ví
// ─────────────────────────────────────────────────────────────────────────────
class _TopUpSheet extends StatefulWidget {
  final LoyaltyCustomerModel customer;
  final List<TopupPackageModel> packages;
  final Future<void> Function(double real, double bonus, int? months) onTopUp;
  const _TopUpSheet({
    required this.customer,
    required this.packages,
    required this.onTopUp,
  });

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  static const _kGreen  = Color(0xFF2E7D32);
  static const _kGold   = Color(0xFFF9A825);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  final _customCtrl = TextEditingController();
  int _bonusMonths = 12;
  bool _loading = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  double get _enteredAmount =>
      double.tryParse(_customCtrl.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;

  TopupPackageModel? get _applicablePkg {
    if (_enteredAmount <= 0) return null;
    final eligible = widget.packages
        .where((p) => p.minAmount <= _enteredAmount)
        .toList()
      ..sort((a, b) => b.minAmount.compareTo(a.minAmount));
    return eligible.isEmpty ? null : eligible.first;
  }

  double get _realAmount => _enteredAmount;

  double get _bonusAmount {
    final pkg = _applicablePkg;
    if (pkg == null) return 0;
    return (_enteredAmount * pkg.bonusPct / 100).floorToDouble();
  }

  Future<void> _submit() async {
    if (_realAmount <= 0) return;
    setState(() => _loading = true);
    try {
      await widget.onTopUp(_realAmount, _bonusAmount, _bonusMonths > 0 ? _bonusMonths : null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, pad + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: _kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nạp tiền — ${widget.customer.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1207))),
            Text(
              'Số dư hiện tại: ${_fmtMoney(widget.customer.realBalance)}'
              '${widget.customer.bonusBalance > 0 ? ' + ${_fmtMoney(widget.customer.bonusBalance)} bonus' : ''}',
              style: const TextStyle(fontSize: 12, color: _kMuted)),
          ])),
        ]),
        const SizedBox(height: 20),

        // Nhập số tiền
        const Text('Số tiền nạp:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1207))),
        const SizedBox(height: 10),
        TextField(
          controller: _customCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập số tiền (VD: 500000)',
            prefixIcon: const Icon(Icons.attach_money_rounded, color: _kGreen),
            suffixText: 'đ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGreen, width: 2)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Gói áp dụng tự động
        if (_enteredAmount > 0) ...[
          if (_applicablePkg != null) ...[
            Row(children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 15),
              const SizedBox(width: 6),
              Text('Áp dụng: ${_applicablePkg!.name} (+${_applicablePkg!.bonusPct.toStringAsFixed(0)}% bonus)',
                style: const TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w700)),
            ]),
          ] else ...[
            Row(children: [
              Icon(Icons.info_outline_rounded, color: _kMuted, size: 15),
              const SizedBox(width: 6),
              Text(
                widget.packages.isEmpty
                  ? 'Chưa có gói nào — nạp không có bonus'
                  : 'Nạp từ ${_fmtMoney(widget.packages.first.minAmount)} mới có bonus',
                style: const TextStyle(fontSize: 12, color: _kMuted)),
            ]),
          ],
          const SizedBox(height: 8),
        ],

        // Gói gợi ý (quick select)
        if (widget.packages.isNotEmpty) ...[
          const Text('Gợi ý nhanh:', style: TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: widget.packages.map((pkg) {
              final isApplied = _applicablePkg?.id == pkg.id;
              return GestureDetector(
                onTap: () {
                  _customCtrl.text = pkg.minAmount.toStringAsFixed(0);
                  setState(() {});
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApplied ? _kGreen : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isApplied ? _kGreen : _kBorder, width: 1.5)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(pkg.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: isApplied ? Colors.white : const Color(0xFF1A1207))),
                    Text('+${pkg.bonusPct.toStringAsFixed(0)}%', style: TextStyle(
                      fontSize: 10, color: isApplied ? Colors.white70 : _kGold,
                      fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 8),
        ],

        // Thời hạn bonus
        if (_bonusAmount > 0) ...[
          Row(children: [
            const Text('Thời hạn bonus:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            DropdownButton<int>(
              value: _bonusMonths,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 6, child: Text('6 tháng')),
                DropdownMenuItem(value: 12, child: Text('12 tháng')),
                DropdownMenuItem(value: 24, child: Text('2 năm')),
                DropdownMenuItem(value: 0, child: Text('Không hạn')),
              ],
              onChanged: (v) => setState(() => _bonusMonths = v ?? 12),
            ),
          ]),
          const SizedBox(height: 8),
        ],

        // Preview
        if (_realAmount > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Khách trả:', style: TextStyle(fontSize: 13, color: _kMuted)),
                Text(_fmtMoney(_realAmount),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1207))),
              ]),
              if (_bonusAmount > 0) ...[
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Thưởng tặng:', style: TextStyle(fontSize: 13, color: _kMuted)),
                  Text('+${_fmtMoney(_bonusAmount)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kGold)),
                ]),
              ],
              const Divider(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Tổng dùng được:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(_fmtMoney(_realAmount + _bonusAmount),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kGreen)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        // Button xác nhận
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_realAmount > 0 && !_loading) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _realAmount > 0
                        ? 'Xác nhận nạp ${_fmtMoney(_realAmount)}'
                        : 'Chọn gói hoặc nhập số tiền',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

String _fmtMoney(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

String _fmtPts(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}tr';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// _PackageEditSheet — Tạo / sửa gói nạp tiền
// ─────────────────────────────────────────────────────────────────────────────
class _PackageEditSheet extends StatefulWidget {
  final TopupPackageModel? existing;
  final Future<void> Function(TopupPackageModel pkg) onSave;
  const _PackageEditSheet({this.existing, required this.onSave});

  @override
  State<_PackageEditSheet> createState() => _PackageEditSheetState();
}

class _PackageEditSheetState extends State<_PackageEditSheet> {
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kBorder = Color(0xFFE0D8CC);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _pctCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl   = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? e.minAmount.toStringAsFixed(0) : '');
    _pctCtrl    = TextEditingController(
      text: e != null ? e.bonusPct.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final pct    = double.tryParse(_pctCtrl.text) ?? 0;
    if (name.isEmpty || amount <= 0 || pct <= 0) return;

    setState(() => _loading = true);
    try {
      final pkg = TopupPackageModel(
        id:         widget.existing?.id ?? const Uuid().v4(),
        name:       name,
        minAmount:  amount,
        bonusPct:   pct,
        sortOrder:  widget.existing?.sortOrder ?? 0,
      );
      await widget.onSave(pkg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, pad + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(
          widget.existing != null ? 'Sửa gói nạp' : 'Thêm gói nạp mới',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1207))),
        const SizedBox(height: 18),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên gói (VD: Gói Vàng)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPurple, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nạp từ (đ)',
              hintText: 'VD: 500000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPurple, width: 2)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _pctCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '% Bonus',
              hintText: 'VD: 15',
              suffixText: '%',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPurple, width: 2)),
            ),
          )),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.existing != null ? 'Lưu thay đổi' : 'Thêm gói',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Loyalty Stats Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _LoyaltyRightPanel extends StatelessWidget {
  final AsyncValue<LoyaltyStats> statsAsync;
  const _LoyaltyRightPanel({required this.statsAsync});

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kGold   = Color(0xFFF9A825);
  static const _kInk    = Color(0xFF1A1207);

  @override
  Widget build(BuildContext context) {
    final s = statsAsync.value;

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          _LRCard(
            title: 'Tổng quan',
            icon: Icons.workspace_premium_rounded,
            child: Column(children: [
              _LRRow(label: 'Tổng khách', value: '${s?.totalCustomers ?? 0}', color: _kNavy),
              const Divider(height: 1),
              _LRRow(label: 'Có điểm', value: '${s?.customersWithPts ?? 0}', color: _kPurple),
              const Divider(height: 1),
              _LRRow(label: 'Điểm active', value: '${s?.totalActivePts ?? 0}', color: _kGold),
              const Divider(height: 1),
              _LRRow(label: 'Đã đổi', value: '${s?.totalPtsRedeemed ?? 0}', color: const Color(0xFF2E7D32)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LRCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _LRCard({required this.title, required this.icon, required this.child});

  static const _kNavy = Color(0xFF1E1C5E);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: _kNavy.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _LRRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LRRow({required this.label, required this.value, required this.color});

  static const _kInk = Color(0xFF1A1207);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kInk))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
