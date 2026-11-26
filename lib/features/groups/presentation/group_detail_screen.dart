import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../auth/cubit/auth_cubit.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String _statusFilter = 'all'; // all | open | settled

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groupRepo = context.read<GroupRepository>();
    final settlementRepo = context.read<BillSettlementRepository>();

    return StreamBuilder<GroupModel?>(
      stream: groupRepo.watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        if (groupSnap.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.warmCream,
            appBar: AppBar(title: const Text('Akses Grup Ditolak')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const OrganicPebbleBadge(
                      size: 86,
                      color: AppTheme.apricotWash,
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 42,
                        color: AppTheme.statusRejected,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Kamu belum terdaftar di grup ini atau terjadi kesalahan (${groupSnap.error}).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Kembali ke Beranda'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (groupSnap.connectionState == ConnectionState.waiting &&
            !groupSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final group = groupSnap.data;
        if (group == null) {
          return Scaffold(
            backgroundColor: AppTheme.warmCream,
            appBar: AppBar(title: const Text('Grup Tidak Ditemukan')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Grup tidak ditemukan atau sudah dihapus.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            ),
          );
        }

        final groupPalette = PatunginPalette.forKey(group.groupId);

        return StreamBuilder<List<GroupMemberProfile>>(
          stream: groupRepo.watchGroupMembersWithProfiles(widget.groupId),
          builder: (context, membersSnap) {
            final members = membersSnap.data ?? const [];
            final myProfile =
                members.where((m) => m.user.uid == currentUser.uid).firstOrNull;
            final bool isAdmin =
                myProfile?.membership.role == GroupRole.admin ||
                    group.adminUid == currentUser.uid;

            return Scaffold(
              backgroundColor: AppTheme.warmCream,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () =>
                    context.push('/groups/${widget.groupId}/create-bill'),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Catat Tagihan',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              body: StreamBuilder<List<BillModel>>(
                stream: settlementRepo.watchGroupBills(widget.groupId),
                builder: (context, snapshot) {
                  final allBills = snapshot.data ?? const [];
                  final filteredBills = allBills.where((b) {
                    if (_statusFilter == 'open') {
                      return b.status == BillStatus.open;
                    }
                    if (_statusFilter == 'settled') {
                      return b.status == BillStatus.settled;
                    }
                    return true;
                  }).toList();

                  final groupBalance =
                      settlementRepo.calculateUserBalanceFromBills(
                    userUid: currentUser.uid,
                    bills: allBills,
                    groupIdFilter: widget.groupId,
                  );
                  final totalGroupSpendingIdr = allBills.fold<double>(
                    0.0,
                    (acc, b) => acc + b.grandTotalIdr,
                  );

                  return CustomScrollView(
                    slivers: [
                      // 1. Header Gelombang Organik dengan Identitas Warna Grup
                      SliverToBoxAdapter(
                        child: ClipPath(
                          clipper: const BottomWaveClipper(waveDepth: 26),
                          child: Container(
                            color: groupPalette.bg,
                            child: CustomPaint(
                              painter: OrganicCanvasPainter(
                                blobColor:
                                    groupPalette.fg.withValues(alpha: 0.08),
                                dotColor:
                                    groupPalette.fg.withValues(alpha: 0.11),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  MediaQuery.of(context).padding.top + 10,
                                  18,
                                  42,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppTheme.paperWhite
                                                .withValues(alpha: 0.8),
                                            foregroundColor: AppTheme.darkSlate,
                                          ),
                                          icon: const Icon(
                                            Icons.arrow_back_rounded,
                                          ),
                                          onPressed: () => context.pop(),
                                        ),
                                        const Spacer(),
                                        DashedCouponChip(
                                          label: 'Kode: ${group.inviteCode}',
                                          color: groupPalette.fg,
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: group.inviteCode,
                                              ),
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Kode ${group.inviteCode} disalin! Tinggal kirim ke teman.',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 6),
                                          PopupMenuButton<String>(
                                            tooltip: 'Pengaturan Grup',
                                            icon: CircleAvatar(
                                              radius: 19,
                                              backgroundColor: AppTheme
                                                  .paperWhite
                                                  .withValues(alpha: 0.8),
                                              child: const Icon(
                                                Icons.more_horiz_rounded,
                                                color: AppTheme.darkSlate,
                                              ),
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditGroupDialog(
                                                  context,
                                                  group,
                                                  currentUser.uid,
                                                );
                                              } else if (value == 'delete') {
                                                _showDeleteGroupConfirmation(
                                                  context,
                                                  group,
                                                  currentUser.uid,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: ListTile(
                                                  leading:
                                                      Icon(Icons.edit_outlined),
                                                  title: Text(
                                                    'Ubah Info Grup',
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  dense: true,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons
                                                        .delete_forever_rounded,
                                                    color:
                                                        AppTheme.statusRejected,
                                                  ),
                                                  title: Text(
                                                    'Hapus Grup',
                                                    style: TextStyle(
                                                      color: AppTheme
                                                          .statusRejected,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  dense: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        OrganicPebbleBadge(
                                          size: 54,
                                          color: AppTheme.paperWhite,
                                          variant: 1,
                                          child: Icon(
                                            Icons.groups_2_rounded,
                                            size: 28,
                                            color: groupPalette.fg,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                group.groupName,
                                                style: const TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.6,
                                                  color: AppTheme.darkSlate,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                group.description.isEmpty
                                                    ? 'Ruang patungan bareng lingkaranmu'
                                                    : group.description,
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
                                    const SizedBox(height: 16),
                                    // Baris anggota (Overlapping Avatar Stack) + Role
                                    InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => _showMembersBottomSheet(
                                        context,
                                        group: group,
                                        members: members,
                                        isAdmin: isAdmin,
                                        currentUid: currentUser.uid,
                                      ),
                                      child: Row(
                                        children: [
                                          OverlappingAvatarStack(
                                            labels: members
                                                .map((m) => m.user.initials)
                                                .toList(),
                                            radius: 15,
                                            borderColor: groupPalette.bg,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${members.length} anggota · Kelola',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: groupPalette.fg,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.paperWhite
                                                  .withValues(alpha: 0.78),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isAdmin
                                                  ? 'Admin Grup'
                                                  : 'Anggota',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: groupPalette.fg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    // Strip Statistik Editorial Terbuka (tanpa kotak)
                                    DashedDivider(
                                      color: groupPalette.fg
                                          .withValues(alpha: 0.25),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _EditorialStat(
                                            label: 'Total Grup',
                                            value: totalGroupSpendingIdr
                                                .toRupiah(),
                                            valueColor: AppTheme.darkSlate,
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 30,
                                          color: groupPalette.fg
                                              .withValues(alpha: 0.2),
                                        ),
                                        Expanded(
                                          child: _EditorialStat(
                                            label: 'Utang Kamu',
                                            value: groupBalance.totalYouOweIdr
                                                .toRupiah(),
                                            valueColor: AppTheme.terracotta,
                                            align: CrossAxisAlignment.center,
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 30,
                                          color: groupPalette.fg
                                              .withValues(alpha: 0.2),
                                        ),
                                        Expanded(
                                          child: _EditorialStat(
                                            label: 'Piutang',
                                            value: groupBalance
                                                .totalOwedToYouIdr
                                                .toRupiah(),
                                            valueColor: AppTheme.primaryEmerald,
                                            align: CrossAxisAlignment.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Filter Pil & Header Riwayat Tagihan
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Jejak Tagihan (${filteredBills.length})',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                      color: AppTheme.darkSlate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _CapsuleFilterTab(
                                      label: 'Semua (${allBills.length})',
                                      selected: _statusFilter == 'all',
                                      onTap: () =>
                                          setState(() => _statusFilter = 'all'),
                                    ),
                                    const SizedBox(width: 8),
                                    _CapsuleFilterTab(
                                      label:
                                          'Belum Lunas (${allBills.where((b) => b.status == BillStatus.open).length})',
                                      selected: _statusFilter == 'open',
                                      onTap: () => setState(
                                        () => _statusFilter = 'open',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _CapsuleFilterTab(
                                      label:
                                          'Lunas (${allBills.where((b) => b.status == BillStatus.settled).length})',
                                      selected: _statusFilter == 'settled',
                                      onTap: () => setState(
                                        () => _statusFilter = 'settled',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Timeline Struk Tagihan (Pola Timeline + Struk, bukan kotak datar)
                      if (filteredBills.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 36, 28, 100),
                            child: Column(
                              children: [
                                const OrganicPebbleBadge(
                                  size: 76,
                                  color: AppTheme.warmSand,
                                  variant: 2,
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 36,
                                    color: AppTheme.mutedInk,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  allBills.isEmpty
                                      ? 'Belum ada struk dicatat'
                                      : 'Tidak ada tagihan di filter ini',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkSlate,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  allBills.isEmpty
                                      ? 'Tekan tombol "Catat Tagihan" di kanan bawah setelah nongkrong atau belanja bareng.'
                                      : 'Coba pilih tab filter lain untuk melihat riwayat tagihan grup.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.mutedInk,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 18, 110),
                          sliver: SliverList.builder(
                            itemCount: filteredBills.length,
                            itemBuilder: (context, index) {
                              final bill = filteredBills[index];
                              final isLast = index == filteredBills.length - 1;
                              return _TimelineReceiptTile(
                                bill: bill,
                                isCreator: bill.creatorUid == currentUser.uid,
                                isLast: isLast,
                                onTap: () => context.push(
                                  '/groups/${widget.groupId}/bills/${bill.billId}',
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showMembersBottomSheet(
    BuildContext context, {
    required GroupModel group,
    required List<GroupMemberProfile> members,
    required bool isAdmin,
    required String currentUid,
  }) {
    final groupRepo = context.read<GroupRepository>();
    final emailCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Anggota Grup (${members.length})',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  DashedCouponChip(
                    label: group.inviteCode,
                    color: AppTheme.primaryEmerald,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: group.inviteCode));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Kode undangan ${group.inviteCode} berhasil disalin!',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...members.map((m) {
                final canKick = isAdmin && m.user.uid != currentUid;
                final pal = PatunginPalette.forKey(m.user.uid);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: pal.bg,
                    child: Text(
                      m.user.initials,
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    m.user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle:
                      Text('${m.user.email} · ${m.membership.role.label}'),
                  trailing: canKick
                      ? IconButton(
                          tooltip: 'Keluarkan dari grup',
                          icon: const Icon(
                            Icons.person_remove_rounded,
                            color: AppTheme.statusRejected,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await groupRepo.removeMemberFromGroup(
                                groupId: group.groupId,
                                requesterUid: currentUid,
                                targetUserUid: m.user.uid,
                              );
                            } on AppAuthException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.message),
                                    backgroundColor: AppTheme.statusRejected,
                                  ),
                                );
                              }
                            }
                          },
                        )
                      : null,
                );
              }),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                const DashedDivider(),
                const SizedBox(height: 14),
                const Text(
                  'Tambah Anggota via Email Terdaftar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'email.teman@domain.com',
                          isDense: true,
                          prefixIcon:
                              Icon(Icons.alternate_email_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final addedUser = await groupRepo.addMemberByEmail(
                            groupId: group.groupId,
                            requesterUid: currentUid,
                            email: email,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${addedUser.fullName} berhasil ditambahkan ke grup!',
                                ),
                                backgroundColor: AppTheme.primaryEmerald,
                              ),
                            );
                          }
                        } on AppAuthException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: AppTheme.statusRejected,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGroupDialog(
    BuildContext context,
    GroupModel group,
    String requesterUid,
  ) {
    final nameCtrl = TextEditingController(text: group.groupName);
    final descCtrl = TextEditingController(text: group.description);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Informasi Grup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Grup'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Deskripsi Grup'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<GroupRepository>().updateGroupInfo(
                      groupId: group.groupId,
                      requesterUid: requesterUid,
                      newName: nameCtrl.text,
                      newDescription: descCtrl.text,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informasi grup berhasil diperbarui.'),
                      backgroundColor: AppTheme.primaryEmerald,
                    ),
                  );
                }
              } on AppAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppTheme.statusRejected,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memperbarui grup: $e'),
                      backgroundColor: AppTheme.statusRejected,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupConfirmation(
    BuildContext context,
    GroupModel group,
    String requesterUid,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Grup Ini?'),
        content: Text(
          'Semua riwayat tagihan di "${group.groupName}" akan ikut terhapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<GroupRepository>().deleteGroup(
                      groupId: group.groupId,
                      requesterUid: requesterUid,
                    );
                if (context.mounted) context.go('/home');
              } on AppAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppTheme.statusRejected,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus grup: $e'),
                      backgroundColor: AppTheme.statusRejected,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}

class _EditorialStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment align;

  const _EditorialStat({
    required this.label,
    required this.value,
    required this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleFilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CapsuleFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.darkSlate : AppTheme.paperWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.darkSlate : AppTheme.softBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.warmCream : AppTheme.mutedInk,
          ),
        ),
      ),
    );
  }
}

class _TimelineReceiptTile extends StatelessWidget {
  final BillModel bill;
  final bool isCreator;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineReceiptTile({
    required this.bill,
    required this.isCreator,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = bill.status == BillStatus.settled;
    final statusColor =
        isSettled ? AppTheme.statusPaid : AppTheme.statusPending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Jalur timeline vertikal di sisi kiri
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.softBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Permukaan struk mini bergerigi bawah (bukan kartu kotak seragam)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: onTap,
                child: ScallopedReceiptSurface(
                  topEdge: false,
                  bottomEdge: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bill.createdAt.toIndoDate(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                          const Spacer(),
                          InkStampBadge(
                            text: isSettled ? 'Lunas' : 'Berjalan',
                            color: statusColor,
                            angleRadians: isSettled ? -0.05 : 0.04,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: AppTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isCreator
                                  ? AppTheme.lavenderWash
                                  : AppTheme.warmSand,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              isCreator ? 'Kamu yang talangi' : 'Ikut patungan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCreator
                                    ? const Color(0xFF5B3FA8)
                                    : AppTheme.mutedInk,
                              ),
                            ),
                          ),
                          if (bill.currencyCode != 'IDR') ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${bill.currencyCode}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F638C),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const DashedDivider(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${bill.participantSummaries.length} peserta patungan',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                          Text(
                            bill.grandTotalIdr.toRupiah(),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryEmerald,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
