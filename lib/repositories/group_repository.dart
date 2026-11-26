import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/exceptions/auth_exception.dart';
import '../models/erd_models.dart';

// ============================================================================
// GROUP & RBAC REPOSITORY (CLOUD FIRESTORE)
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
  final FirebaseFirestore _firestore;
  final Random _random = Random();

  GroupRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsCol =>
      _firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _inviteCodesCol =>
      _firestore.collection('invite_codes');

  /// Stream real-time daftar grup di mana pengguna terdaftar sebagai anggota
  Stream<List<GroupModel>> watchUserGroups(String userUid) {
    return _groupsCol
        .where('member_uids', arrayContains: userUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), docId: doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream real-time detail satu grup (dilindungi Firestore Security Rules)
  Stream<GroupModel?> watchGroup(String groupId) {
    return _groupsCol.doc(groupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GroupModel.fromMap(doc.data()!, docId: doc.id);
    });
  }

  /// Stream real-time daftar anggota grup beserta profil lengkapnya
  Stream<List<GroupMemberProfile>> watchGroupMembersWithProfiles(
    String groupId,
  ) {
    return _groupsCol
        .doc(groupId)
        .collection('members')
        .snapshots()
        .asyncMap((snapshot) async {
      final memberships = snapshot.docs
          .map((doc) => GroupMember.fromMap(doc.data(), docId: doc.id))
          .toList()
        ..sort((a, b) {
          if (a.role == GroupRole.admin && b.role != GroupRole.admin) return -1;
          if (a.role != GroupRole.admin && b.role == GroupRole.admin) return 1;
          return a.joinedAt.compareTo(b.joinedAt);
        });

      final profiles = await Future.wait(
        memberships.map((m) async {
          final userDoc = await _usersCol.doc(m.userUid).get();
          final user = userDoc.exists && userDoc.data() != null
              ? AppUser.fromMap(userDoc.data()!, docId: userDoc.id)
              : AppUser(
                  uid: m.userUid,
                  fullName: 'Anggota',
                  email: '-',
                  photoUrl: '',
                  createdAt: m.joinedAt,
                );
          return GroupMemberProfile(membership: m, user: user);
        }),
      );
      return profiles;
    });
  }

  /// Ambil daftar anggota grup sekali (untuk CreateBillScreen, dll.)
  Future<List<GroupMemberProfile>> getGroupMembersWithProfiles({
    required String groupId,
    required String requesterUid,
  }) async {
    try {
      final memberSnap = await _groupsCol
          .doc(groupId)
          .collection('members')
          .doc(requesterUid)
          .get();
      if (!memberSnap.exists) {
        throw AppAuthException.fromFirebaseCode('permission-denied');
      }

      final allMembersSnap =
          await _groupsCol.doc(groupId).collection('members').get();
      final memberships = allMembersSnap.docs
          .map((doc) => GroupMember.fromMap(doc.data(), docId: doc.id))
          .toList();

      return await Future.wait(
        memberships.map((m) async {
          final userDoc = await _usersCol.doc(m.userUid).get();
          final user = userDoc.exists && userDoc.data() != null
              ? AppUser.fromMap(userDoc.data()!, docId: userDoc.id)
              : AppUser(
                  uid: m.userUid,
                  fullName: 'Anggota',
                  email: '-',
                  photoUrl: '',
                  createdAt: m.joinedAt,
                );
          return GroupMemberProfile(membership: m, user: user);
        }),
      );
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Ambil role pengguna di dalam grup (admin / member / null)
  Future<GroupRole?> getUserRoleInGroup(String groupId, String userUid) async {
    try {
      final doc = await _groupsCol
          .doc(groupId)
          .collection('members')
          .doc(userUid)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return GroupRole.fromString((doc.data()!['role'] as String?) ?? 'member');
    } catch (_) {
      return null;
    }
  }

  /// Tambahkan anggota baru ke grup menggunakan alamat email terdaftar (khusus Admin)
  Future<AppUser> addMemberByEmail({
    required String groupId,
    required String requesterUid,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final role = await getUserRoleInGroup(groupId, requesterUid);
      if (role != GroupRole.admin) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Hanya Admin Grup yang dapat menambahkan anggota secara langsung.',
        );
      }

      final query = await _usersCol
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        throw const AppAuthException(
          code: 'user-not-found',
          message:
              'Pengguna dengan email tersebut belum terdaftar di BagiTigaKan. Minta teman Anda mendaftar terlebih dahulu atau bagikan kode undangan.',
        );
      }

      final targetUser = AppUser.fromMap(
        query.docs.first.data(),
        docId: query.docs.first.id,
      );

      final existingMember = await _groupsCol
          .doc(groupId)
          .collection('members')
          .doc(targetUser.uid)
          .get();
      if (existingMember.exists) {
        throw AppAuthException(
          code: 'already-member',
          message: '${targetUser.fullName} sudah menjadi anggota grup ini.',
        );
      }

      final batch = _firestore.batch();
      final member = GroupMember(
        memberId: targetUser.uid,
        groupId: groupId,
        userUid: targetUser.uid,
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      );

      batch.set(
        _groupsCol.doc(groupId).collection('members').doc(targetUser.uid),
        member.toMap(),
      );
      batch.update(_groupsCol.doc(groupId), {
        'member_uids': FieldValue.arrayUnion([targetUser.uid]),
      });
      await batch.commit();

      return targetUser;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Buat Grup Baru + Generate invite_code unik secara atomik (UFD-2 & BR-07)
  Future<GroupModel> createGroup({
    required String groupName,
    required String description,
    required String creatorUid,
  }) async {
    try {
      final groupRef = _groupsCol.doc();
      final groupId = groupRef.id;
      final now = DateTime.now();

      late GroupModel createdGroup;

      await _firestore.runTransaction((transaction) async {
        String? reservedCode;
        for (int attempt = 0; attempt < 6; attempt++) {
          final candidate = _generateRandomInviteCode();
          final codeSnap =
              await transaction.get(_inviteCodesCol.doc(candidate));
          if (!codeSnap.exists) {
            reservedCode = candidate;
            break;
          }
        }

        if (reservedCode == null) {
          throw const AppAuthException(
            code: 'invite-code-collision',
            message: 'Gagal menghasilkan kode undangan unik. Silakan coba lagi.',
          );
        }

        createdGroup = GroupModel(
          groupId: groupId,
          groupName: groupName.trim(),
          description: description.trim(),
          inviteCode: reservedCode,
          adminUid: creatorUid,
          memberUids: [creatorUid],
          createdAt: now,
        );

        final adminMember = GroupMember(
          memberId: creatorUid,
          groupId: groupId,
          userUid: creatorUid,
          role: GroupRole.admin,
          joinedAt: now,
        );

        transaction.set(_inviteCodesCol.doc(reservedCode), {
          'group_id': groupId,
          'created_at': now.toIso8601String(),
        });
        transaction.set(groupRef, createdGroup.toMap());
        transaction.set(
          groupRef.collection('members').doc(creatorUid),
          adminMember.toMap(),
        );
      });

      return createdGroup;
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Gabung Grup via Kode Undangan Unik (UFD-2)
  Future<GroupModel> joinGroupByInviteCode({
    required String inviteCode,
    required String userUid,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    try {
      final codeDoc = await _inviteCodesCol.doc(normalizedCode).get();
      if (!codeDoc.exists || codeDoc.data() == null) {
        throw const AppAuthException(
          code: 'invite-code-not-found',
          message:
              'Kode undangan tidak ditemukan. Periksa kembali kode dari teman Anda.',
        );
      }

      final groupId = codeDoc.data()!['group_id'] as String?;
      if (groupId == null || groupId.isEmpty) {
        throw const AppAuthException(
          code: 'invite-code-not-found',
          message: 'Kode undangan tidak valid.',
        );
      }

      final memberRef =
          _groupsCol.doc(groupId).collection('members').doc(userUid);

      // Tambahkan keanggotaan + member_uids secara atomik jika belum menjadi anggota
      bool alreadyMember = false;
      try {
        final existingMember = await memberRef.get();
        alreadyMember = existingMember.exists;
      } catch (_) {
        alreadyMember = false;
      }

      if (!alreadyMember) {
        final batch = _firestore.batch();
        final newMember = GroupMember(
          memberId: userUid,
          groupId: groupId,
          userUid: userUid,
          role: GroupRole.member,
          joinedAt: DateTime.now(),
        );
        batch.set(memberRef, newMember.toMap());
        batch.update(_groupsCol.doc(groupId), {
          'member_uids': FieldValue.arrayUnion([userUid]),
        });
        await batch.commit();
      }

      final groupDoc = await _groupsCol.doc(groupId).get();
      if (!groupDoc.exists || groupDoc.data() == null) {
        throw const AppAuthException(
          code: 'not-found',
          message: 'Grup sudah tidak tersedia atau telah dihapus.',
        );
      }
      return GroupModel.fromMap(groupDoc.data()!, docId: groupDoc.id);
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Ubah Info Grup (Hanya Group Admin - Tabel 2.5)
  Future<GroupModel> updateGroupInfo({
    required String groupId,
    required String requesterUid,
    required String newName,
    required String newDescription,
  }) async {
    try {
      final role = await getUserRoleInGroup(groupId, requesterUid);
      if (role != GroupRole.admin) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Akses ditolak: Hanya Group Admin yang dapat mengubah info grup.',
        );
      }

      await _groupsCol.doc(groupId).update({
        'group_name': newName.trim(),
        'description': newDescription.trim(),
      });

      final updatedDoc = await _groupsCol.doc(groupId).get();
      return GroupModel.fromMap(updatedDoc.data()!, docId: updatedDoc.id);
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Keluarkan Anggota dari Grup (Hanya Group Admin - Tabel 2.5)
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String requesterUid,
    required String targetUserUid,
  }) async {
    try {
      final role = await getUserRoleInGroup(groupId, requesterUid);
      if (role != GroupRole.admin) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Akses ditolak: Hanya Group Admin yang dapat mengeluarkan anggota.',
        );
      }
      if (requesterUid == targetUserUid) {
        throw const AppAuthException(
          code: 'invalid-action',
          message: 'Group Admin tidak dapat mengeluarkan dirinya sendiri.',
        );
      }

      // Cek apakah target masih memiliki tagihan aktif yang belum lunas di grup
      final openBillsSnap = await _groupsCol
          .doc(groupId)
          .collection('bills')
          .where('status', isEqualTo: BillStatus.open.name)
          .get();

      for (final billDoc in openBillsSnap.docs) {
        final bill = BillModel.fromMap(billDoc.data(), docId: billDoc.id);
        final isCreatorWithUnpaidOthers = bill.creatorUid == targetUserUid &&
            bill.participantSummaries.values.any(
              (p) =>
                  p.debtorUid != targetUserUid &&
                  p.paymentStatus != PaymentStatus.paid,
            );
        final targetSummary = bill.participantSummaries[targetUserUid];
        final hasUnpaidDebt = targetSummary != null &&
            targetSummary.paymentStatus != PaymentStatus.paid;

        if (isCreatorWithUnpaidOthers || hasUnpaidDebt) {
          throw AppAuthException(
            code: 'member-has-unsettled-bills',
            message:
                'Anggota tidak dapat dikeluarkan karena masih memiliki tanggungan/piutang yang belum lunas pada tagihan "${bill.title}".',
          );
        }
      }

      final batch = _firestore.batch();
      batch.delete(
        _groupsCol.doc(groupId).collection('members').doc(targetUserUid),
      );
      batch.update(_groupsCol.doc(groupId), {
        'member_uids': FieldValue.arrayRemove([targetUserUid]),
      });
      await batch.commit();
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Hapus Grup & Data Terkait (Hanya Group Admin - Tabel 2.5 & UFD-2)
  Future<void> deleteGroup({
    required String groupId,
    required String requesterUid,
  }) async {
    try {
      final role = await getUserRoleInGroup(groupId, requesterUid);
      if (role != GroupRole.admin) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Akses ditolak: Hanya Group Admin yang dapat menghapus grup.',
        );
      }

      final groupRef = _groupsCol.doc(groupId);
      final groupDoc = await groupRef.get();
      final inviteCode = groupDoc.data()?['invite_code'] as String?;

      // Hapus seluruh bills & subkoleksinya terlebih dahulu
      final billsSnap = await groupRef.collection('bills').get();
      for (final billDoc in billsSnap.docs) {
        final itemsSnap = await billDoc.reference.collection('items').get();
        for (final itemDoc in itemsSnap.docs) {
          final assignSnap =
              await itemDoc.reference.collection('assignments').get();
          for (final aDoc in assignSnap.docs) {
            await aDoc.reference.delete();
          }
          await itemDoc.reference.delete();
        }
        final partsSnap =
            await billDoc.reference.collection('participants').get();
        for (final pDoc in partsSnap.docs) {
          await pDoc.reference.delete();
        }
        await billDoc.reference.delete();
      }

      // Hapus invite_code sebelum menghapus anggota (agar rule isGroupAdmin tetap lolos)
      if (inviteCode != null && inviteCode.isNotEmpty) {
        await _inviteCodesCol.doc(inviteCode).delete();
      }

      // Hapus seluruh members kecuali admin, lalu hapus grup, terakhir hapus admin member
      final membersSnap = await groupRef.collection('members').get();
      for (final mDoc in membersSnap.docs) {
        if (mDoc.id != requesterUid) {
          await mDoc.reference.delete();
        }
      }

      await groupRef.delete();
      await groupRef.collection('members').doc(requesterUid).delete();
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  String _generateRandomInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
