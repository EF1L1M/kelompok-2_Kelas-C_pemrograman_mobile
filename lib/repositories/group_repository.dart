import 'dart:async';
import '../core/exceptions/auth_exception.dart';
import '../models/erd_models.dart';
import 'mock_realtime_database.dart';

// ============================================================================
// GROUP & RBAC REPOSITORY (FR-02, BR-07, UFD-2, BAB 6 ANGGOTA 1)
// Mengelola grup patungan, kode undangan unik (transaksi invite_codes/{kode}),
// pemeriksaan role tetap (admin | member), dan penolakan akses non-anggota.
// ============================================================================

class GroupMemberProfile {
  final GroupMember membership;
  final AppUser user;

  const GroupMemberProfile({
    required this.membership,
    required this.user,
  });
}

class GroupRepository {
  final RealtimeDatabaseStore _store = RealtimeDatabaseStore.instance;

  /// Stream real-time daftar grup di mana pengguna terdaftar sebagai anggota
  Stream<List<GroupModel>> watchUserGroups(String userUid) async* {
    yield _getGroupsForUser(userUid);
    await for (final _ in _store.onDatabaseChanged) {
      yield _getGroupsForUser(userUid);
    }
  }

  List<GroupModel> _getGroupsForUser(String userUid) {
    final myGroupIds = _store.groupMembers
        .where((m) => m.userUid == userUid)
        .map((m) => m.groupId)
        .toSet();

    final list = _store.groups.values
        .where((g) => myGroupIds.contains(g.groupId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Ambil detail grup dengan penegakan Security Rules (FR-02, BR-07):
  /// Non-anggota ditolak membaca grup!
  GroupModel getGroupGuarded({
    required String groupId,
    required String requesterUid,
  }) {
    final group = _store.groups[groupId];
    if (group == null) {
      throw const AppAuthException(
        code: 'not-found',
        message: 'Grup tidak ditemukan atau telah dihapus.',
      );
    }
    // Penegakan RBAC Lapis Security Rules: Cek keanggotaan di group_members
    _store.assertMemberAccess(groupId, requesterUid);
    return group;
  }

  /// Ambil role pengguna di dalam grup (admin / member / null)
  GroupRole? getUserRoleInGroup(String groupId, String userUid) {
    return _store.getUserGroupRole(groupId, userUid);
  }

  /// Ambil jumlah anggota dalam grup
  int getMemberCount(String groupId) {
    return _store.groupMembers.where((m) => m.groupId == groupId).length;
  }

  /// Ambil daftar pengguna terdaftar yang belum menjadi anggota grup ini
  List<AppUser> getNonMembersForGroup(String groupId) {
    final existingUids = _store.groupMembers
        .where((m) => m.groupId == groupId)
        .map((m) => m.userUid)
        .toSet();
    return _store.users.values
        .where((u) => !existingUids.contains(u.uid))
        .toList();
  }

  /// Tambahkan anggota baru ke grup oleh Admin
  Future<void> addMemberToGroup({
    required String groupId,
    required String requesterUid,
    required String targetUserUid,
  }) async {
    final role = _store.getUserGroupRole(groupId, requesterUid);
    if (role != GroupRole.admin) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Hanya Admin Grup yang dapat menambahkan anggota secara langsung.',
      );
    }
    if (!_store.isGroupMember(groupId, targetUserUid)) {
      _store.groupMembers.add(
        GroupMember(
          memberId: 'm_${DateTime.now().microsecondsSinceEpoch}',
          groupId: groupId,
          userUid: targetUserUid,
          role: GroupRole.member,
          joinedAt: DateTime.now(),
        ),
      );
      _store.notifyChanges();
    }
  }

  /// Ambil daftar anggota grup beserta profil lengkapnya
  List<GroupMemberProfile> getGroupMembersWithProfiles({
    required String groupId,
    required String requesterUid,
  }) {
    _store.assertMemberAccess(groupId, requesterUid);
    return _store.groupMembers
        .where((m) => m.groupId == groupId)
        .map((m) {
          final user = _store.users[m.userUid];
          if (user == null) return null;
          return GroupMemberProfile(membership: m, user: user);
        })
        .whereType<GroupMemberProfile>()
        .toList();
  }

  /// Buat Grup Baru + Generate invite_code unik dalam transaksi (UFD-2 & BR-07)
  Future<GroupModel> createGroup({
    required String groupName,
    required String description,
    required String creatorUid,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final groupId = 'g_${DateTime.now().millisecondsSinceEpoch}';
    final inviteCode = _store.generateUniqueInviteCode();
    final now = DateTime.now();

    final group = GroupModel(
      groupId: groupId,
      groupName: groupName.trim(),
      description: description.trim(),
      inviteCode: inviteCode,
      adminUid: creatorUid,
      createdAt: now,
    );

    // Transaksi penyimpanan grup + reservasi invite_codes/{kode} + tambah admin
    _store.groups[groupId] = group;
    _store.inviteCodesToGroupId[inviteCode] = groupId;
    _store.groupMembers.add(
      GroupMember(
        memberId: 'm_${DateTime.now().microsecondsSinceEpoch}',
        groupId: groupId,
        userUid: creatorUid,
        role: GroupRole.admin,
        joinedAt: now,
      ),
    );

    _store.notifyChanges();
    return group;
  }

  /// Gabung Grup via Kode Undangan Unik (UFD-2: Cek kode valid & apakah sudah jadi anggota)
  Future<GroupModel> joinGroupByInviteCode({
    required String inviteCode,
    required String userUid,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final normalizedCode = inviteCode.trim().toUpperCase();
    final groupId = _store.inviteCodesToGroupId[normalizedCode];

    if (groupId == null || !_store.groups.containsKey(groupId)) {
      throw const AppAuthException(
        code: 'invite-code-not-found',
        message: 'Error: Kode undangan tidak ditemukan. Periksa kembali kode Anda.',
      );
    }

    final alreadyMember = _store.isGroupMember(groupId, userUid);
    if (!alreadyMember) {
      _store.groupMembers.add(
        GroupMember(
          memberId: 'm_${DateTime.now().microsecondsSinceEpoch}',
          groupId: groupId,
          userUid: userUid,
          role: GroupRole.member,
          joinedAt: DateTime.now(),
        ),
      );
      _store.notifyChanges();
    }

    return _store.groups[groupId]!;
  }

  /// Ubah Info Grup (Hanya Group Admin - Tabel 2.5)
  Future<GroupModel> updateGroupInfo({
    required String groupId,
    required String requesterUid,
    required String newName,
    required String newDescription,
  }) async {
    final role = _store.getUserGroupRole(groupId, requesterUid);
    if (role != GroupRole.admin) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Akses ditolak: Hanya Group Admin yang dapat mengubah info grup.',
      );
    }

    final existing = _store.groups[groupId]!;
    final updated = existing.copyWith(
      groupName: newName.trim(),
      description: newDescription.trim(),
    );
    _store.groups[groupId] = updated;
    _store.notifyChanges();
    return updated;
  }

  /// Keluarkan Anggota dari Grup (Hanya Group Admin - Tabel 2.5)
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String requesterUid,
    required String targetUserUid,
  }) async {
    final role = _store.getUserGroupRole(groupId, requesterUid);
    if (role != GroupRole.admin) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Akses ditolak: Hanya Group Admin yang dapat mengeluarkan anggota.',
      );
    }
    if (requesterUid == targetUserUid) {
      throw const AppAuthException(
        code: 'invalid-action',
        message: 'Group Admin tidak dapat mengeluarkan dirinya sendiri.',
      );
    }

    _store.groupMembers.removeWhere(
      (m) => m.groupId == groupId && m.userUid == targetUserUid,
    );
    _store.notifyChanges();
  }

  /// Hapus Grup & Data Terkait (Hanya Group Admin - Tabel 2.5 & UFD-2)
  Future<void> deleteGroup({
    required String groupId,
    required String requesterUid,
  }) async {
    final role = _store.getUserGroupRole(groupId, requesterUid);
    if (role != GroupRole.admin) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Akses ditolak: Hanya Group Admin yang dapat menghapus grup.',
      );
    }

    final group = _store.groups.remove(groupId);
    if (group != null) {
      _store.inviteCodesToGroupId.remove(group.inviteCode);
    }
    _store.groupMembers.removeWhere((m) => m.groupId == groupId);

    final billIds = _store.bills.values
        .where((b) => b.groupId == groupId)
        .map((b) => b.billId)
        .toList();

    for (final bid in billIds) {
      _store.bills.remove(bid);
      _store.billItems.remove(bid);
      _store.billParticipants.remove(bid);
    }
    _store.notifyChanges();
  }
}
