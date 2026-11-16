import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validator_mixin.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/group_cubit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with FormValidatorMixin {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final currentUser =
        authState is AuthAuthenticated ? authState.user : null;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final groupRepo = context.read<GroupRepository>();
    final settlementRepo = context.read<BillSettlementRepository>();

    return BlocConsumer<GroupCubit, GroupDashboardState>(
      listener: (context, state) {
        if (state.feedbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.feedbackMessage!),
              backgroundColor: state.isErrorFeedback
                  ? AppTheme.statusRejected
                  : AppTheme.primaryEmerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, groupState) {
        final actionableBills =
            settlementRepo.getActionableBillsForUser(currentUser.uid);

        final filteredGroups = groupState.groups.where((g) {
          if (_searchQuery.trim().isEmpty) return true;
          final q = _searchQuery.trim().toLowerCase();
          return g.groupName.toLowerCase().contains(q) ||
              g.description.toLowerCase().contains(q) ||
              g.inviteCode.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryEmerald,
                ),
                SizedBox(width: 10),
                Text('Smart Split-Bill'),
              ],
            ),
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Notifikasi',
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  if (groupState.unreadNotifCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.statusUnpaid,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${groupState.unreadNotifCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Profil & Ganti Akun',
                onPressed: () =>
                    _showProfileAndSwitchAccountSheet(context, currentUser),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              IconButton(
                tooltip: 'Keluar',
                onPressed: () async {
                  await context.read<AuthCubit>().signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              // 1. Kartu Profil & Saldo Bersih (Net Balance)
              _buildProfileAndNetBalanceCard(
                context,
                currentUser,
                groupState.overallBalance,
              ),
              const SizedBox(height: 14),

              // 2. Kartu Ringkasan Total Utang & Piutang
              _buildBalanceSummaryRow(groupState),
              const SizedBox(height: 16),

              // 3. Tombol Aksi Utama: Buat Grup & Gabung via Kode Undangan
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateGroupDialog(context),
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text('Buat Grup Baru'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinGroupDialog(context),
                      icon: const Icon(Icons.vpn_key_rounded),
                      label: const Text('Gabung via Kode'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 4. Tagihan Aktif yang Perlu Diselesaikan
              if (actionableBills.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tagihan Perlu Diselesaikan',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${actionableBills.length} Aktif',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...actionableBills.map(
                  (item) => _buildActionableBillCard(context, item),
                ),
              ],

              const SizedBox(height: 24),

              // 5. Header & Pencarian Daftar Grup Patungan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grup Patungan Saya (${groupState.groups.length})',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkSlate,
                    ),
                  ),
                ],
              ),
              if (groupState.groups.length > 1) ...[
                const SizedBox(height: 10),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Cari nama grup atau kode undangan...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              if (filteredGroups.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.groups_2_outlined,
                          size: 46,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          groupState.groups.isEmpty
                              ? 'Belum Ada Grup Patungan'
                              : 'Grup Tidak Ditemukan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          groupState.groups.isEmpty
                              ? 'Buat grup patungan baru atau gunakan tombol "Gabung via Kode" untuk masuk ke grup teman Anda.'
                              : 'Tidak ada grup yang cocok dengan kata kunci "$_searchQuery".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredGroups.map((group) {
                  final role = context
                      .read<GroupCubit>()
                      .getRoleInGroup(group.groupId, currentUser.uid);
                  final isAdmin = role == GroupRole.admin;
                  final memberCount = groupRepo.getMemberCount(group.groupId);
                  final groupBalance = settlementRepo.calculateUserBalance(
                    currentUser.uid,
                    groupIdFilter: group.groupId,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push('/groups/${group.groupId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryEmerald
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.groups_2_rounded,
                                      color: AppTheme.primaryEmerald,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.groupName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          group.description.isEmpty
                                              ? 'Grup patungan aktif'
                                              : group.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _BadgePill(
                                    icon: isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.person_outline_rounded,
                                    text: isAdmin ? 'Admin Grup' : 'Anggota',
                                    color: isAdmin
                                        ? AppTheme.primaryEmerald
                                        : const Color(0xFF475569),
                                  ),
                                  _BadgePill(
                                    icon: Icons.people_alt_outlined,
                                    text: '$memberCount Anggota',
                                    color: const Color(0xFF6366F1),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: group.inviteCode),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Kode undangan ${group.inviteCode} disalin ke papan klip',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: _BadgePill(
                                      icon: Icons.copy_rounded,
                                      text: 'Kode: ${group.inviteCode}',
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ),
                                  if (groupBalance.totalYouOweIdr > 0)
                                    _BadgePill(
                                      icon: Icons.arrow_upward_rounded,
                                      text:
                                          'Utang: ${groupBalance.totalYouOweIdr.toRupiah()}',
                                      color: AppTheme.statusUnpaid,
                                    )
                                  else if (groupBalance.totalOwedToYouIdr > 0)
                                    _BadgePill(
                                      icon: Icons.arrow_downward_rounded,
                                      text:
                                          'Piutang: ${groupBalance.totalOwedToYouIdr.toRupiah()}',
                                      color: AppTheme.primaryEmerald,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileAndNetBalanceCard(
    BuildContext context,
    AppUser activeUser,
    UserBalanceSummary balance,
  ) {
    final net = balance.netBalanceIdr;
    final isPositive = net > 0;
    final isNegative = net < 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryEmerald,
                child: Text(
                  activeUser.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeUser.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      activeUser.email,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () =>
                    _showProfileAndSwitchAccountSheet(context, activeUser),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text(
                  'Ganti Akun',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi Saldo Bersih Anda',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isPositive ? "+" : ""}${net.toRupiah()}',
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF34D399)
                            : isNegative
                                ? const Color(0xFFFCA5A5)
                                : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF065F46)
                        : isNegative
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPositive
                        ? 'Surplus Piutang'
                        : isNegative
                            ? 'Perlu Dilunasi'
                            : 'Impun / Lunas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryRow(GroupDashboardState groupState) {
    final balance = groupState.overallBalance;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: AppTheme.statusUnpaid,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Total Utang Saya',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  balance.totalYouOweIdr.toRupiah(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                const Text(
                  'Belum dibayarkan ke teman',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: AppTheme.primaryEmerald,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Total Piutang',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  balance.totalOwedToYouIdr.toRupiah(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF064E3B),
                  ),
                ),
                const Text(
                  'Menunggu pelunasan teman',
                  style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionableBillCard(
    BuildContext context,
    ActionableBillItem item,
  ) {
    final bill = item.bill;
    final bool hasPendingToVerify =
        item.isCreator && item.pendingVerificationCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              context.push('/groups/${bill.groupId}/bills/${bill.billId}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.isCreator
                        ? const Color(0xFFEDE9FE)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.isCreator
                        ? Icons.fact_check_outlined
                        : Icons.payments_outlined,
                    color: item.isCreator
                        ? const Color(0xFF6D28D9)
                        : AppTheme.statusUnpaid,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.isCreator
                            ? hasPendingToVerify
                                ? '${item.groupName} · ${item.pendingVerificationCount} konfirmasi bayar menunggu verifikasi Anda'
                                : '${item.groupName} · Menunggu pembayaran anggota'
                            : '${item.groupName} · Status: ${item.myStatus.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasPendingToVerify
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: hasPendingToVerify
                              ? const Color(0xFFB45309)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.amountIdr.toRupiah(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: item.isCreator
                            ? AppTheme.primaryEmerald
                            : AppTheme.statusUnpaid,
                      ),
                    ),
                    Text(
                      item.isCreator ? 'Piutang' : 'Bagian Anda',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileAndSwitchAccountSheet(
    BuildContext context,
    AppUser activeUser,
  ) {
    final authCubit = context.read<AuthCubit>();
    final users = authCubit.allUsers;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil & Beralih Akun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih akun di bawah untuk beralih sesi pengguna secara langsung:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ...users.map((u) {
              final isSelected = u.uid == activeUser.uid;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? AppTheme.primaryEmerald
                      : const Color(0xFFE2E8F0),
                  child: Text(
                    u.initials,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkSlate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  u.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(u.email),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.primaryEmerald,
                      )
                    : TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          authCubit.switchDemoUser(u.uid);
                        },
                        child: const Text('Gunakan'),
                      ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isSelected) {
                    authCubit.switchDemoUser(u.uid);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Grup Patungan Baru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                validator: (v) =>
                    validateRequiredText(v, fieldName: 'Nama grup'),
                decoration: const InputDecoration(
                  labelText: 'Nama Grup (contoh: Liburan Bali)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Singkat (Opsional)',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kode undangan unik 6 karakter akan dibuat secara otomatis agar teman Anda dapat bergabung.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                final created = await context.read<GroupCubit>().createGroup(
                      groupName: nameCtrl.text,
                      description: descCtrl.text,
                    );
                if (created != null && context.mounted) {
                  context.push('/groups/${created.groupId}');
                }
              }
            },
            child: const Text('Buat Grup'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gabung Grup via Kode Undangan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                validator: validateInviteCode,
                decoration: const InputDecoration(
                  labelText: 'Masukkan Kode Undangan (6 Karakter)',
                  hintText: 'Contoh: KOS26A',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ketuk untuk mengisi cepat kode grup yang tersedia:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text(
                      'KOS26A (Kos Melati)',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () => codeCtrl.text = 'KOS26A',
                  ),
                  ActionChip(
                    label: const Text(
                      'TIM26B (Tim Mobile)',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () => codeCtrl.text = 'TIM26B',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                final joined = await context
                    .read<GroupCubit>()
                    .joinGroupByCode(codeCtrl.text);
                if (joined != null && context.mounted) {
                  context.push('/groups/${joined.groupId}');
                }
              }
            },
            child: const Text('Gabung Grup'),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _BadgePill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
