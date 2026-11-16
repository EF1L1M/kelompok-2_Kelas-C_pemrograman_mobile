import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
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

    late final GroupModel group;
    try {
      group = groupRepo.getGroupGuarded(
        groupId: widget.groupId,
        requesterUid: currentUser.uid,
      );
    } on AppAuthException catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Grup Ditolak')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_person_rounded,
                  size: 64,
                  color: AppTheme.statusRejected,
                ),
                const SizedBox(height: 16),
                Text(
                  e.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
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

    final GroupRole? myRole =
        groupRepo.getUserRoleInGroup(widget.groupId, currentUser.uid);
    final bool isAdmin = myRole == GroupRole.admin;
    final members = groupRepo.getGroupMembersWithProfiles(
      groupId: widget.groupId,
      requesterUid: currentUser.uid,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group.groupName),
        actions: [
          IconButton(
            tooltip: 'Anggota & Kode Undangan',
            onPressed: () => _showMembersBottomSheet(
              context,
              group: group,
              members: members,
              isAdmin: isAdmin,
              currentUid: currentUser.uid,
            ),
            icon: const Icon(Icons.people_alt_outlined),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Pengaturan Grup',
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditGroupDialog(context, group, currentUser.uid);
                } else if (value == 'delete') {
                  _showDeleteGroupConfirmation(context, group, currentUser.uid);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Ubah Informasi Grup'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: AppTheme.statusRejected,
                    ),
                    title: Text(
                      'Hapus Grup',
                      style: TextStyle(color: AppTheme.statusRejected),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/groups/${widget.groupId}/create-bill'),
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text(
          'Buat Tagihan Baru',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<BillModel>>(
        stream: settlementRepo.watchGroupBills(widget.groupId),
        builder: (context, snapshot) {
          final allBills = snapshot.data ?? const [];
          final filteredBills = allBills.where((b) {
            if (_statusFilter == 'open') return b.status == BillStatus.open;
            if (_statusFilter == 'settled') {
              return b.status == BillStatus.settled;
            }
            return true;
          }).toList();

          final groupBalance = settlementRepo.calculateUserBalance(
            currentUser.uid,
            groupIdFilter: widget.groupId,
          );
          final totalGroupSpendingIdr = allBills.fold<double>(
            0.0,
            (sum, b) => sum + b.grandTotalIdr,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // 1. Kartu Header Grup, Statistik Pengeluaran & Saldo Grup
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppTheme.primaryEmerald.withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAdmin ? 'Peran: Admin Grup' : 'Peran: Anggota',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isAdmin
                                  ? AppTheme.primaryEmerald
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: group.inviteCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Kode undangan ${group.inviteCode} disalin ke papan klip',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Color(0xFF0369A1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Kode: ${group.inviteCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        group.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Pengeluaran',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                totalGroupSpendingIdr.toRupiah(),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Utang Anda',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                groupBalance.totalYouOweIdr.toRupiah(),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.statusUnpaid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Piutang Anda',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                groupBalance.totalOwedToYouIdr.toRupiah(),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Header & Filter Daftar Tagihan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Tagihan (${filteredBills.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showMembersBottomSheet(
                      context,
                      group: group,
                      members: members,
                      isAdmin: isAdmin,
                      currentUid: currentUser.uid,
                    ),
                    icon: const Icon(Icons.group_outlined, size: 17),
                    label: Text('${members.length} Anggota'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipItem(
                      label: 'Semua (${allBills.length})',
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label:
                          'Belum Lunas (${allBills.where((b) => b.status == BillStatus.open).length})',
                      selected: _statusFilter == 'open',
                      onTap: () => setState(() => _statusFilter = 'open'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label:
                          'Lunas (${allBills.where((b) => b.status == BillStatus.settled).length})',
                      selected: _statusFilter == 'settled',
                      onTap: () => setState(() => _statusFilter = 'settled'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (filteredBills.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        allBills.isEmpty
                            ? 'Belum ada tagihan di grup ini. Tekan tombol "Buat Tagihan Baru" di bawah untuk mulai mencatat pengeluaran.'
                            : 'Tidak ada tagihan pada filter ini.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                )
              else
                ...filteredBills.map((bill) {
                  final isCreator = bill.creatorUid == currentUser.uid;
                  final isSettled = bill.status == BillStatus.settled;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(
                          '/groups/${widget.groupId}/bills/${bill.billId}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSettled
                                          ? AppTheme.statusPaid
                                              .withValues(alpha: 0.14)
                                          : AppTheme.statusPending
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isSettled ? 'LUNAS' : 'BELUM LUNAS',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSettled
                                            ? AppTheme.statusPaid
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCreator
                                          ? const Color(0xFFEDE9FE)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCreator
                                          ? 'Ditalangi Anda'
                                          : 'Peserta Patungan',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCreator
                                            ? const Color(0xFF6D28D9)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    bill.createdAt.toIndoDate(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                bill.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      bill.currencyCode == 'IDR'
                                          ? 'Mata Uang: Rupiah (IDR)'
                                          : 'Kurs: 1 ${bill.currencyCode} = ${bill.exchangeRate.toRupiah()} (${bill.rateDate.toIndoDate()})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    bill.grandTotalIdr.toRupiah(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryEmerald,
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
                }),
            ],
          );
        },
      ),
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
    final nonMembers = groupRepo.getNonMembersForGroup(group.groupId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Anggota Grup (${members.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Kode undangan ${group.inviteCode} berhasil disalin!',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text('Salin Kode: ${group.inviteCode}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...members.map((m) {
              final canKick = isAdmin && m.user.uid != currentUid;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryEmerald.withValues(alpha: 0.15),
                  child: Text(
                    m.user.initials,
                    style: const TextStyle(
                      color: AppTheme.primaryEmerald,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  m.user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${m.user.email} · ${m.membership.role.label}'),
                trailing: canKick
                    ? IconButton(
                        tooltip: 'Keluarkan dari grup',
                        icon: const Icon(
                          Icons.person_remove_rounded,
                          color: AppTheme.statusRejected,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await groupRepo.removeMemberFromGroup(
                            groupId: group.groupId,
                            requesterUid: currentUid,
                            targetUserUid: m.user.uid,
                          );
                          if (mounted) setState(() {});
                        },
                      )
                    : null,
              );
            }),
            if (isAdmin && nonMembers.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Tambahkan Anggota Terdaftar:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: nonMembers.map((user) {
                  return ActionChip(
                    avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: Text('Tambah ${user.fullName}'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await groupRepo.addMemberToGroup(
                        groupId: group.groupId,
                        requesterUid: currentUid,
                        targetUserUid: user.uid,
                      );
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user.fullName} berhasil ditambahkan ke grup!',
                            ),
                            backgroundColor: AppTheme.primaryEmerald,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ],
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
              await context.read<GroupRepository>().updateGroupInfo(
                    groupId: group.groupId,
                    requesterUid: requesterUid,
                    newName: nameCtrl.text,
                    newDescription: descCtrl.text,
                  );
              if (mounted) setState(() {});
            },
            child: const Text('Simpan Perubahan'),
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
        title: const Text('Konfirmasi Hapus Grup'),
        content: Text(
          'Apakah Anda yakin ingin menghapus grup "${group.groupName}" beserta seluruh riwayat tagihan di dalamnya?',
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
              await context.read<GroupRepository>().deleteGroup(
                    groupId: group.groupId,
                    requesterUid: requesterUid,
                  );
              if (context.mounted) context.go('/home');
            },
            child: const Text('Ya, Hapus Grup'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppTheme.darkSlate,
        ),
      ),
      selected: selected,
      selectedColor: AppTheme.primaryEmerald,
      backgroundColor: Colors.white,
      onSelected: (_) => onTap(),
    );
  }
}
