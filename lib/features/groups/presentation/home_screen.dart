import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/firebase/firebase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validator_mixin.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
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

    return BlocConsumer<GroupCubit, GroupDashboardState>(
      listener: (context, state) {
        if (state.feedbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.feedbackMessage!),
              backgroundColor: state.isErrorFeedback
                  ? AppTheme.statusRejected
                  : AppTheme.primaryEmerald,
            ),
          );
        }
      },
      builder: (context, groupState) {
        final actionableBills = groupState.actionableBills;
        final filteredGroups = groupState.groups.where((g) {
          if (_searchQuery.trim().isEmpty) return true;
          final q = _searchQuery.trim().toLowerCase();
          return g.groupName.toLowerCase().contains(q) ||
              g.description.toLowerCase().contains(q) ||
              g.inviteCode.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.warmCream,
          body: CustomScrollView(
            slivers: [
              // 1. Header Gelombang Organik + Saldo Editorial Terbuka (bukan kotak gelap kaku)
              SliverToBoxAdapter(
                child: _buildCurvedHeroSection(
                  context,
                  currentUser,
                  groupState,
                ),
              ),

              // 2. Tombol Aksi Pil Cepat (Buat Grup & Gabung via Kode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateGroupDialog(context),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                          label: const Text('Buat Grup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppTheme.paperWhite,
                          ),
                          onPressed: () => _showJoinGroupDialog(context),
                          icon: const Icon(Icons.confirmation_num_outlined, size: 19),
                          label: const Text('Gabung Kode'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Tagihan Aktif dalam Pola Strip Tiket Horizontal (memecah ritme vertikal!)
              if (actionableBills.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Perlu Perhatian',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.butterWash,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${actionableBills.length} tagihan',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF9A6108),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 146,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: actionableBills.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, idx) =>
                              _buildActionableTicket(
                            context,
                            actionableBills[idx],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Header & Pencarian Pil untuk Daftar Grup Patungan
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lingkaran Patungan (${groupState.groups.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: AppTheme.darkSlate,
                            ),
                          ),
                        ],
                      ),
                      if (groupState.groups.length > 1) ...[
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Cari nama grup atau kode...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: AppTheme.softBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: AppTheme.softBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryEmerald,
                                width: 1.8,
                              ),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => _searchQuery = ''),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 5. Daftar Grup dalam Pola Permukaan Organik Berwarna Pastel Hangat
              if (filteredGroups.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
                    child: Column(
                      children: [
                        const OrganicPebbleBadge(
                          size: 84,
                          color: AppTheme.warmSand,
                          variant: 0,
                          child: Icon(
                            Icons.groups_2_outlined,
                            size: 40,
                            color: AppTheme.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          groupState.groups.isEmpty
                              ? 'Belum Ada Lingkaran Patungan'
                              : 'Grup Tidak Ditemukan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          groupState.groups.isEmpty
                              ? 'Bikin grup baru buat nongkrong, kos, atau liburan — atau gabung pakai kode undangan dari temanmu.'
                              : 'Tidak ada grup yang cocok dengan "$_searchQuery".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppTheme.mutedInk,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 44),
                  sliver: SliverList.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return _buildOrganicGroupBand(
                        context,
                        group: group,
                        currentUser: currentUser,
                        groupBalance: groupState.balanceForGroup(group.groupId),
                        index: index,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurvedHeroSection(
    BuildContext context,
    AppUser activeUser,
    GroupDashboardState groupState,
  ) {
    final balance = groupState.overallBalance;
    final net = balance.netBalanceIdr;
    final isPositive = net > 0;
    final isNegative = net < 0;
    final firstName = activeUser.fullName.trim().split(RegExp(r'\s+')).first;

    return OrganicWaveHeader(
      waveDepth: 30,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identitas merek BagiTigaKan + tagline kecil di puncak beranda
          Row(
            children: [
              const BagiTigaKanLogo(size: 30, showSubtleBorder: true),
              const SizedBox(width: 9),
              const BagiTigaKanWordmark(fontSize: 16.5, onDark: true),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warmCream.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '÷ split_fairly(n)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmCream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Baris sapaan manusiawi + tombol notifikasi & profil bulat
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showProfileSheet(context, activeUser),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppTheme.butterWash,
                      child: Text(
                        activeUser.initials,
                        style: const TextStyle(
                          color: AppTheme.deepForest,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${timeBasedGreeting()},',
                          style: TextStyle(
                            color: AppTheme.warmCream.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          firstName,
                          style: const TextStyle(
                            color: AppTheme.warmCream,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Kabar Patungan',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppTheme.warmCream.withValues(alpha: 0.14),
                      foregroundColor: AppTheme.warmCream,
                    ),
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  if (groupState.unreadNotifCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.terracotta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.deepForest,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${groupState.unreadNotifCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Profil & Akun',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.warmCream.withValues(alpha: 0.14),
                  foregroundColor: AppTheme.warmCream,
                ),
                onPressed: () => _showProfileSheet(context, activeUser),
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tipografi Saldo Bersih Terbuka (tanpa kotak dalam kotak!)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posisi Saldo Patunganmu',
                      style: TextStyle(
                        color: AppTheme.warmCream.withValues(alpha: 0.78),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isPositive ? "+" : ""}${net.toRupiah()}',
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF9AF0C7)
                            : isNegative
                                ? const Color(0xFFFFC1AE)
                                : AppTheme.warmCream,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: -0.04,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF2B8A68)
                        : isNegative
                            ? AppTheme.terracotta
                            : AppTheme.warmCream.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPositive
                        ? 'Surplus Piutang'
                        : isNegative
                            ? 'Perlu Dilunasi'
                            : 'Impun & Lega',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          DashedDivider(color: AppTheme.warmCream.withValues(alpha: 0.22)),
          const SizedBox(height: 14),

          // Ledger Utang & Piutang sebaris (menggantikan 2 kotak merah-hijau generik)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.terracotta.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: Color(0xFFFFC1AE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Utang Kamu',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.warmCream.withValues(alpha: 0.72),
                            ),
                          ),
                          Text(
                            balance.totalYouOweIdr.toRupiah(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warmCream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppTheme.warmCream.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9AF0C7).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.south_west_rounded,
                        size: 16,
                        color: Color(0xFF9AF0C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Piutang Teman',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.warmCream.withValues(alpha: 0.72),
                            ),
                          ),
                          Text(
                            balance.totalOwedToYouIdr.toRupiah(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warmCream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Strip tiket berlekuk samping (horizontal carousel) untuk tagihan aktif
  Widget _buildActionableTicket(
    BuildContext context,
    ActionableBillItem item,
  ) {
    final bill = item.bill;
    final bool hasPendingToVerify =
        item.isCreator && item.pendingVerificationCount > 0;
    final Color accent = item.isCreator
        ? (hasPendingToVerify ? AppTheme.honeyAmber : AppTheme.primaryEmerald)
        : AppTheme.terracotta;
    final Color topTint = item.isCreator
        ? (hasPendingToVerify ? AppTheme.butterWash : AppTheme.sageWash)
        : AppTheme.apricotWash;

    return GestureDetector(
      onTap: () => context.push('/groups/${bill.groupId}/bills/${bill.billId}'),
      child: Container(
        width: 248,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A3D2C).withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const TicketStripClipper(radius: 22, notchRadius: 8),
          child: Container(
            color: AppTheme.paperWhite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bagian atas tiket berwarna pastel hangat
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                  color: topTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.isCreator
                                ? Icons.fact_check_outlined
                                : Icons.payments_outlined,
                            size: 15,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        bill.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppTheme.darkSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: DashedDivider(),
                ),
                // Bagian bawah tiket: nominal + status ringkas
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.isCreator
                                ? (hasPendingToVerify
                                    ? '${item.pendingVerificationCount} klaim masuk'
                                    : 'Menunggu teman')
                                : item.myStatus.shortLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasPendingToVerify
                                  ? AppTheme.honeyAmber
                                  : AppTheme.mutedInk,
                            ),
                          ),
                        ),
                        Text(
                          item.amountIdr.toRupiah(),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Item Grup bergaya organik asimetris dengan warna identitas unik per grup
  Widget _buildOrganicGroupBand(
    BuildContext context, {
    required GroupModel group,
    required AppUser currentUser,
    required UserBalanceSummary groupBalance,
    required int index,
  }) {
    final isAdmin = group.adminUid == currentUser.uid;
    final memberCount =
        group.memberUids.isNotEmpty ? group.memberUids.length : 1;
    final pal = PatunginPalette.forKey(group.groupId);

    // Sudut asimetris bergantian agar ritme visual terasa hidup & organik
    final BorderRadius organicRadius = index.isEven
        ? const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(28),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.paperWhite,
        borderRadius: organicRadius,
        child: InkWell(
          borderRadius: organicRadius,
          onTap: () => context.push('/groups/${group.groupId}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: organicRadius,
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OrganicPebbleBadge(
                      size: 48,
                      color: pal.bg,
                      variant: index,
                      child: Icon(
                        Icons.groups_2_rounded,
                        color: pal.fg,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.groupName,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: AppTheme.darkSlate,
                                  ),
                                ),
                              ),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.bg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: pal.fg,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.description.isEmpty
                                ? '$memberCount anggota patungan aktif'
                                : '${group.description} · $memberCount anggota',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: pal.fg.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const DashedDivider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    DashedCouponChip(
                      label: group.inviteCode,
                      color: pal.fg,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: group.inviteCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Kode undangan ${group.inviteCode} disalin!',
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    if (groupBalance.totalYouOweIdr > 0)
                      _InlineMoneyPill(
                        label: 'Utang ${groupBalance.totalYouOweIdr.toRupiah()}',
                        bg: AppTheme.apricotWash,
                        fg: AppTheme.terracotta,
                      )
                    else if (groupBalance.totalOwedToYouIdr > 0)
                      _InlineMoneyPill(
                        label:
                            'Piutang ${groupBalance.totalOwedToYouIdr.toRupiah()}',
                        bg: AppTheme.sageWash,
                        fg: AppTheme.primaryEmerald,
                      )
                    else
                      const Text(
                        'Semua beres ✓',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.mutedInk,
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

  void _showProfileSheet(
    BuildContext context,
    AppUser activeUser,
  ) {
    final pal = PatunginPalette.forKey(activeUser.uid);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppTheme.softBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                OrganicPebbleBadge(
                  size: 56,
                  color: pal.bg,
                  variant: 0,
                  child: Text(
                    activeUser.initials,
                    style: TextStyle(
                      color: pal.fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeUser.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeUser.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DashedDivider(),
            const SizedBox(height: 14),
            Text(
              'ID Akun: ${activeUser.uid}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.mutedInk,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              FirebaseAppConfig.useEmulator
                  ? 'Terhubung ke Firebase Local Emulator (${FirebaseAppConfig.emulatorHost})'
                  : 'Terhubung ke Firebase Cloud (${FirebaseAppConfig.projectId})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryEmerald,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.statusRejected,
                side: const BorderSide(color: AppTheme.statusRejected),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<AuthCubit>().signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar dari Akun'),
            ),
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
        title: const Text('Buat Grup Patungan'),
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
                  labelText: 'Catatan Singkat (Opsional)',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kode undangan 6 karakter akan langsung disiapkan agar temanmu bisa bergabung.',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
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
        title: const Text('Gabung via Kode Undangan'),
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
                  labelText: 'Kode Undangan (6 Karakter)',
                  hintText: 'Contoh: BALI26',
                  prefixIcon: Icon(Icons.confirmation_num_outlined),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Minta kode undangan 6 karakter dari teman atau admin grup BagiTigaKan kamu.',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
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
            child: const Text('Gabung'),
          ),
        ],
      ),
    );
  }
}

class _InlineMoneyPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _InlineMoneyPill({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
