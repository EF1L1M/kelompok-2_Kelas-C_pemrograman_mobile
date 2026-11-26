import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/exceptions/auth_exception.dart';
import '../core/extensions/format_extensions.dart';
import '../models/erd_models.dart';

// ============================================================================
// BILL & REAL-TIME SETTLEMENT REPOSITORY (CLOUD FIRESTORE)
// Menerapkan konsep Advance Dart:
// - Stream lanjutan: StreamTransformer, penggabungan stream tagihan lintas grup,
//   participants, items, assignments, dan profil pengguna (USERS).
// - Higher-Order Functions (.fold, .where, .map) untuk menghitung saldo bersih
//   secara real-time tanpa field redundan net_balance di database.
// - Siklus status pembayaran ketat sesuai BR-04, BR-05, dan BR-06.
// ============================================================================

class ParticipantWithProfile {
  final BillParticipantModel participant;
  final AppUser user;
  final List<BillItemShareDetail> assignedItems;

  const ParticipantWithProfile({
    required this.participant,
    required this.user,
    required this.assignedItems,
  });
}

class BillItemShareDetail {
  final BillItemModel item;
  final double shareIdr;

  const BillItemShareDetail({
    required this.item,
    required this.shareIdr,
  });
}

class RichBillDetail {
  final BillModel bill;
  final AppUser creator;
  final List<BillItemModel> items;
  final Map<String, List<ItemAssignmentModel>> assignmentsByItem;
  final List<ParticipantWithProfile> participants;

  const RichBillDetail({
    required this.bill,
    required this.creator,
    required this.items,
    required this.assignmentsByItem,
    required this.participants,
  });

  int get paidCount => participants
      .where((p) => p.participant.paymentStatus == PaymentStatus.paid)
      .length;

  int get pendingCount => participants
      .where((p) => p.participant.paymentStatus == PaymentStatus.pending)
      .length;

  int get unpaidCount => participants
      .where(
        (p) =>
            p.participant.paymentStatus == PaymentStatus.unpaid ||
            p.participant.paymentStatus == PaymentStatus.rejected,
      )
      .length;
}

class UserBalanceSummary {
  final double totalYouOweIdr;
  final double totalOwedToYouIdr;

  const UserBalanceSummary({
    required this.totalYouOweIdr,
    required this.totalOwedToYouIdr,
  });

  double get netBalanceIdr => totalOwedToYouIdr - totalYouOweIdr;
}

class ActionableBillItem {
  final BillModel bill;
  final String groupName;
  final bool isCreator;
  final double amountIdr;
  final PaymentStatus myStatus;
  final int pendingVerificationCount;

  const ActionableBillItem({
    required this.bill,
    required this.groupName,
    required this.isCreator,
    required this.amountIdr,
    required this.myStatus,
    required this.pendingVerificationCount,
  });
}

class BillSettlementRepository {
  final FirebaseFirestore? _injectedFirestore;

  BillSettlementRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsCol =>
      _firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _notificationsCol =>
      _firestore.collection('notifications');

  /// StreamTransformer (Advance Dart): mengurutkan daftar tagihan dari terbaru
  StreamTransformer<List<BillModel>, List<BillModel>>
      get _billSortTransformer =>
          StreamTransformer<List<BillModel>, List<BillModel>>.fromHandlers(
            handleData: (bills, sink) {
              final sorted = List<BillModel>.from(bills)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              sink.add(sorted);
            },
          );

  /// Stream real-time daftar tagihan dalam satu grup
  Stream<List<BillModel>> watchGroupBills(String groupId) {
    return _groupsCol
        .doc(groupId)
        .collection('bills')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => BillModel.fromMap(doc.data(), docId: doc.id))
              .toList(),
        )
        .transform(_billSortTransformer);
  }

  /// Gabungan stream tagihan lintas seluruh grup milik pengguna secara real-time
  Stream<List<BillModel>> watchBillsForGroups(List<GroupModel> groups) {
    if (groups.isEmpty) {
      return Stream<List<BillModel>>.value(const []);
    }

    late StreamController<List<BillModel>> controller;
    final Map<String, List<BillModel>> billsByGroup = {};
    final List<StreamSubscription<List<BillModel>>> subs = [];

    controller = StreamController<List<BillModel>>(
      onListen: () {
        for (final group in groups) {
          final sub = watchGroupBills(group.groupId).listen(
            (groupBills) {
              billsByGroup[group.groupId] = groupBills;
              final combined = billsByGroup.values
                  .expand((list) => list)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (!controller.isClosed) {
                controller.add(combined);
              }
            },
            onError: (Object err) {
              if (!controller.isClosed) controller.addError(err);
            },
          );
          subs.add(sub);
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  /// Stream real-time rincian tagihan lengkap (Bill + Items + Assignments + Participants + Profiles)
  Stream<RichBillDetail?> watchRichBillDetail({
    required String groupId,
    required String billId,
  }) {
    final billRef = _groupsCol.doc(groupId).collection('bills').doc(billId);

    late StreamController<RichBillDetail?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? billSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? itemsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? partSub;
    DocumentSnapshot<Map<String, dynamic>>? latestBillSnap;
    QuerySnapshot<Map<String, dynamic>>? latestItemsSnap;
    QuerySnapshot<Map<String, dynamic>>? latestPartSnap;

    Future<void> emitCombined() async {
      final bSnap = latestBillSnap;
      if (bSnap == null || !bSnap.exists || bSnap.data() == null) {
        if (!controller.isClosed) controller.add(null);
        return;
      }

      try {
        final bill = BillModel.fromMap(bSnap.data()!, docId: bSnap.id);

        final items = (latestItemsSnap?.docs ?? const [])
            .map((d) => BillItemModel.fromMap(d.data(), docId: d.id))
            .toList();

        final Map<String, List<ItemAssignmentModel>> assignmentsMap = {};
        await Future.wait(
          items.map((item) async {
            final assignSnap = await billRef
                .collection('items')
                .doc(item.itemId)
                .collection('assignments')
                .get();
            assignmentsMap[item.itemId] = assignSnap.docs
                .map((d) => ItemAssignmentModel.fromMap(d.data(), docId: d.id))
                .toList();
          }),
        );

        final rawParticipants = (latestPartSnap?.docs ?? const [])
            .map((d) => BillParticipantModel.fromMap(d.data(), docId: d.id))
            .toList();

        // Kumpulkan semua UID yang perlu diambil profilnya
        final Set<String> uidsToFetch = {
          bill.creatorUid,
          ...rawParticipants.map((p) => p.debtorUid),
        };
        final Map<String, AppUser> userMap = {};
        await Future.wait(
          uidsToFetch.map((uid) async {
            final uDoc = await _usersCol.doc(uid).get();
            if (uDoc.exists && uDoc.data() != null) {
              userMap[uid] = AppUser.fromMap(uDoc.data()!, docId: uDoc.id);
            }
          }),
        );

        final creator = userMap[bill.creatorUid] ??
            AppUser(
              uid: bill.creatorUid,
              fullName: 'Penalang',
              email: '-',
              photoUrl: '',
              createdAt: bill.createdAt,
            );

        final richParticipants = rawParticipants.map((part) {
          final user = userMap[part.debtorUid] ??
              AppUser(
                uid: part.debtorUid,
                fullName: 'Anggota',
                email: '-',
                photoUrl: '',
                createdAt: bill.createdAt,
              );

          final assignedItems = items
              .map((item) {
                final matches = (assignmentsMap[item.itemId] ?? const [])
                    .where((a) => a.debtorUid == part.debtorUid);
                if (matches.isEmpty) return null;
                return BillItemShareDetail(
                  item: item,
                  shareIdr: matches.first.shareIdr,
                );
              })
              .whereType<BillItemShareDetail>()
              .toList();

          return ParticipantWithProfile(
            participant: part,
            user: user,
            assignedItems: assignedItems,
          );
        }).toList();

        if (!controller.isClosed) {
          controller.add(
            RichBillDetail(
              bill: bill,
              creator: creator,
              items: items,
              assignmentsByItem: assignmentsMap,
              participants: richParticipants,
            ),
          );
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    void forwardError(Object err) {
      if (!controller.isClosed) controller.addError(err);
    }

    controller = StreamController<RichBillDetail?>(
      onListen: () {
        billSub = billRef.snapshots().listen(
          (snap) {
            latestBillSnap = snap;
            emitCombined();
          },
          onError: forwardError,
        );
        itemsSub = billRef.collection('items').snapshots().listen(
          (snap) {
            latestItemsSnap = snap;
            if (latestBillSnap != null) emitCombined();
          },
          onError: forwardError,
        );
        partSub = billRef.collection('participants').snapshots().listen(
          (snap) {
            latestPartSnap = snap;
            if (latestBillSnap != null) emitCombined();
          },
          onError: forwardError,
        );
      },
      onCancel: () async {
        await billSub?.cancel();
        await itemsSub?.cancel();
        await partSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Menghitung saldo bersih (utang & piutang) pengguna dari daftar tagihan live
  /// menggunakan Higher-Order Functions (.where, .expand, .fold).
  UserBalanceSummary calculateUserBalanceFromBills({
    required String userUid,
    required List<BillModel> bills,
    String? groupIdFilter,
  }) {
    final relevantBills = bills.where(
      (b) => groupIdFilter == null || b.groupId == groupIdFilter,
    );

    final double youOwe = relevantBills
        .where((b) => b.creatorUid != userUid)
        .expand((b) => b.participantSummaries.values)
        .where(
          (p) =>
              p.debtorUid == userUid &&
              p.paymentStatus != PaymentStatus.paid,
        )
        .fold<double>(0.0, (acc, p) => acc + p.totalDueIdr);

    final double owedToYou = relevantBills
        .where((b) => b.creatorUid == userUid)
        .expand((b) => b.participantSummaries.values)
        .where(
          (p) =>
              p.debtorUid != userUid &&
              p.paymentStatus != PaymentStatus.paid,
        )
        .fold<double>(0.0, (acc, p) => acc + p.totalDueIdr);

    return UserBalanceSummary(
      totalYouOweIdr: youOwe,
      totalOwedToYouIdr: owedToYou,
    );
  }

  /// Menghasilkan daftar tagihan aktif yang perlu perhatian pengguna (Beranda)
  List<ActionableBillItem> buildActionableBills({
    required String userUid,
    required List<GroupModel> groups,
    required List<BillModel> bills,
  }) {
    final Map<String, String> groupNames = {
      for (final g in groups) g.groupId: g.groupName,
    };

    final List<ActionableBillItem> items = [];
    final sortedOpenBills = bills
        .where((b) => b.status == BillStatus.open)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final bill in sortedOpenBills) {
      final groupName = groupNames[bill.groupId] ?? 'Grup Patungan';
      final parts = bill.participantSummaries.values.toList();

      if (bill.creatorUid == userUid) {
        final pendingClaims = parts
            .where(
              (p) =>
                  p.debtorUid != userUid &&
                  p.paymentStatus == PaymentStatus.pending,
            )
            .toList();
        final unpaidOthers = parts
            .where(
              (p) =>
                  p.debtorUid != userUid &&
                  p.paymentStatus != PaymentStatus.paid,
            )
            .fold<double>(0.0, (acc, p) => acc + p.totalDueIdr);

        if (unpaidOthers > 0) {
          items.add(
            ActionableBillItem(
              bill: bill,
              groupName: groupName,
              isCreator: true,
              amountIdr: unpaidOthers,
              myStatus: PaymentStatus.paid,
              pendingVerificationCount: pendingClaims.length,
            ),
          );
        }
      } else {
        final myPart = parts.where((p) => p.debtorUid == userUid).firstOrNull;
        if (myPart != null && myPart.paymentStatus != PaymentStatus.paid) {
          items.add(
            ActionableBillItem(
              bill: bill,
              groupName: groupName,
              isCreator: false,
              amountIdr: myPart.totalDueIdr,
              myStatus: myPart.paymentStatus,
              pendingVerificationCount: 0,
            ),
          );
        }
      }
    }

    return items;
  }

  /// Simpan Tagihan Baru / Perbarui Tagihan di Cloud Firestore + kirim notifikasi
  Future<BillModel> saveNewOrUpdatedBill({
    required BillModel bill,
    required List<BillItemModel> items,
    required Map<String, List<ItemAssignmentModel>> assignmentsByItem,
    required List<BillParticipantModel> participants,
    bool isEdit = false,
  }) async {
    try {
      final allPaid = participants.isNotEmpty &&
          participants.every((p) => p.paymentStatus == PaymentStatus.paid);

      final Map<String, BillParticipantSummary> summaries = {
        for (final p in participants)
          p.debtorUid: BillParticipantSummary(
            debtorUid: p.debtorUid,
            totalDueIdr: p.totalDueIdr,
            paymentStatus: p.paymentStatus,
          ),
      };

      final finalBill = bill.copyWith(
        status: allPaid ? BillStatus.settled : BillStatus.open,
        participantSummaries: summaries,
      );

      final billRef = _groupsCol
          .doc(finalBill.groupId)
          .collection('bills')
          .doc(finalBill.billId);

      // Simpan dokumen bill terlebih dahulu agar rule isBillCreator(gid, bid) terpenuhi
      await billRef.set(finalBill.toMap());

      final newItemIds = items.map((e) => e.itemId).toSet();
      final newParticipantUids = participants.map((e) => e.debtorUid).toSet();

      // Tulis item, assignment, dan participant baru terlebih dahulu (hindari jendela kosong)
      final writeBatch = _firestore.batch();
      for (final item in items) {
        final itemRef = billRef.collection('items').doc(item.itemId);
        writeBatch.set(itemRef, item.toMap());
        final itemAssigns = assignmentsByItem[item.itemId] ?? const [];
        for (final assign in itemAssigns) {
          writeBatch.set(
            itemRef.collection('assignments').doc(assign.debtorUid),
            assign.toMap(),
          );
        }
      }
      for (final part in participants) {
        writeBatch.set(
          billRef.collection('participants').doc(part.debtorUid),
          part.toMap(),
        );
      }
      await writeBatch.commit();

      // Jika mode edit, hapus hanya dokumen lama yang sudah tidak dipakai
      if (isEdit) {
        final existingItems = await billRef.collection('items').get();
        for (final doc in existingItems.docs) {
          final itemId = doc.id;
          if (!newItemIds.contains(itemId)) {
            final oldAssigns =
                await doc.reference.collection('assignments').get();
            for (final a in oldAssigns.docs) {
              await a.reference.delete();
            }
            await doc.reference.delete();
          } else {
            final activeAssignUids = (assignmentsByItem[itemId] ?? const [])
                .map((a) => a.debtorUid)
                .toSet();
            final oldAssigns =
                await doc.reference.collection('assignments').get();
            for (final a in oldAssigns.docs) {
              if (!activeAssignUids.contains(a.id)) {
                await a.reference.delete();
              }
            }
          }
        }
        final existingParts = await billRef.collection('participants').get();
        for (final p in existingParts.docs) {
          if (!newParticipantUids.contains(p.id)) {
            await p.reference.delete();
          }
        }
      }

      // Kirim notifikasi ke debitur yang belum berstatus paid selain pembuat tagihan
      final creatorDoc = await _usersCol.doc(finalBill.creatorUid).get();
      final creatorName =
          (creatorDoc.data()?['full_name'] as String?) ?? 'Penalang';

      for (final part in participants) {
        if (part.debtorUid != finalBill.creatorUid &&
            part.paymentStatus != PaymentStatus.paid) {
          await _createAndDispatchNotification(
            receiverUid: part.debtorUid,
            senderUid: finalBill.creatorUid,
            billId: finalBill.billId,
            groupId: finalBill.groupId,
            type: NotifType.newBill,
            message: isEdit
                ? 'Tagihan "${finalBill.title}" diperbarui oleh $creatorName. Bagian Anda: ${part.totalDueIdr.toRupiah()}.'
                : 'Tagihan baru "${finalBill.title}" dibuat oleh $creatorName. Bagian Anda: ${part.totalDueIdr.toRupiah()}.',
          );
        }
      }

      return finalBill;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Aksi Debitur: Menandai bagiannya "Sudah Bayar" (unpaid/rejected -> pending)
  Future<void> markAsPaidPending({
    required String groupId,
    required String billId,
    required String debtorUid,
  }) async {
    try {
      final billRef = _groupsCol.doc(groupId).collection('bills').doc(billId);
      final billSnap = await billRef.get();
      if (!billSnap.exists || billSnap.data() == null) return;
      final bill = BillModel.fromMap(billSnap.data()!, docId: billSnap.id);

      final partRef = billRef.collection('participants').doc(debtorUid);
      final partSnap = await partRef.get();
      if (!partSnap.exists || partSnap.data() == null) {
        throw const AppAuthException(
          code: 'not-participant',
          message: 'Anda tidak terdaftar sebagai peserta pada tagihan ini.',
        );
      }

      final current =
          BillParticipantModel.fromMap(partSnap.data()!, docId: partSnap.id);
      if (current.paymentStatus == PaymentStatus.paid) return;

      final now = DateTime.now().toIso8601String();
      final batch = _firestore.batch();
      batch.update(partRef, {
        'payment_status': PaymentStatus.pending.name,
        'claimed_at': now,
      });
      batch.update(billRef, {
        'participant_summaries.$debtorUid.payment_status':
            PaymentStatus.pending.name,
      });
      await batch.commit();

      final debtorDoc = await _usersCol.doc(debtorUid).get();
      final debtorName =
          (debtorDoc.data()?['full_name'] as String?) ?? 'Anggota';

      await _createAndDispatchNotification(
        receiverUid: bill.creatorUid,
        senderUid: debtorUid,
        billId: bill.billId,
        groupId: bill.groupId,
        type: NotifType.pending,
        message:
            '$debtorName menandai "Sudah Bayar" sebesar ${current.totalDueIdr.toRupiah()} pada tagihan "${bill.title}". Mohon verifikasi.',
      );
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Aksi Bill Creator: Memverifikasi (paid) atau Menolak (rejected) klaim pembayaran
  Future<void> verifyOrRejectClaim({
    required String groupId,
    required String billId,
    required String requesterUid,
    required String debtorUid,
    required bool isApproved,
  }) async {
    try {
      final billRef = _groupsCol.doc(groupId).collection('bills').doc(billId);
      final billSnap = await billRef.get();
      if (!billSnap.exists || billSnap.data() == null) return;
      final bill = BillModel.fromMap(billSnap.data()!, docId: billSnap.id);

      if (bill.creatorUid != requesterUid) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Hanya pembuat tagihan (penalang) yang dapat memverifikasi atau menolak pelunasan.',
        );
      }

      final partRef = billRef.collection('participants').doc(debtorUid);
      final partSnap = await partRef.get();
      if (!partSnap.exists || partSnap.data() == null) return;
      final current =
          BillParticipantModel.fromMap(partSnap.data()!, docId: partSnap.id);

      final nextStatus =
          isApproved ? PaymentStatus.paid : PaymentStatus.rejected;

      // Periksa status semua peserta untuk BR-06 (otomatis settled jika semua paid)
      final allPartsSnap = await billRef.collection('participants').get();
      final allPaid = allPartsSnap.docs.isNotEmpty &&
          allPartsSnap.docs.every((doc) {
            if (doc.id == debtorUid) return nextStatus == PaymentStatus.paid;
            return (doc.data()['payment_status'] as String?) ==
                PaymentStatus.paid.name;
          });

      final batch = _firestore.batch();
      batch.update(partRef, {
        'payment_status': nextStatus.name,
        'verified_at': isApproved ? DateTime.now().toIso8601String() : null,
      });
      batch.update(billRef, {
        'status': allPaid ? BillStatus.settled.name : BillStatus.open.name,
        'participant_summaries.$debtorUid.payment_status': nextStatus.name,
      });
      await batch.commit();

      final creatorDoc = await _usersCol.doc(requesterUid).get();
      final creatorName =
          (creatorDoc.data()?['full_name'] as String?) ?? 'Penalang';

      await _createAndDispatchNotification(
        receiverUid: debtorUid,
        senderUid: requesterUid,
        billId: bill.billId,
        groupId: bill.groupId,
        type: isApproved ? NotifType.verified : NotifType.rejected,
        message: isApproved
            ? 'Pembayaran Anda sebesar ${current.totalDueIdr.toRupiah()} pada "${bill.title}" telah diverifikasi LUNAS oleh $creatorName!'
            : 'Klaim pembayaran Anda (${current.totalDueIdr.toRupiah()}) pada "${bill.title}" ditolak oleh $creatorName. Silakan periksa bukti transfer dan klaim ulang.',
      );
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Aksi Debitur saat status `rejected`: Kembali ke `unpaid` untuk bayar ulang
  Future<void> resetRejectedToUnpaid({
    required String groupId,
    required String billId,
    required String debtorUid,
  }) async {
    try {
      final billRef = _groupsCol.doc(groupId).collection('bills').doc(billId);
      final batch = _firestore.batch();
      batch.update(billRef.collection('participants').doc(debtorUid), {
        'payment_status': PaymentStatus.unpaid.name,
      });
      batch.update(billRef, {
        'participant_summaries.$debtorUid.payment_status':
            PaymentStatus.unpaid.name,
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Aksi Bill Creator: Kirim Pengingat Otomatis (Nudge)
  Future<void> sendPaymentReminderNudge({
    required String groupId,
    required String billId,
    required String requesterUid,
    required String targetDebtorUid,
  }) async {
    try {
      final billRef = _groupsCol.doc(groupId).collection('bills').doc(billId);
      final billSnap = await billRef.get();
      if (!billSnap.exists || billSnap.data() == null) return;
      final bill = BillModel.fromMap(billSnap.data()!, docId: billSnap.id);

      if (bill.creatorUid != requesterUid) {
        throw const AppAuthException(
          code: 'permission-denied',
          message: 'Hanya pembuat tagihan yang dapat mengirim pengingat.',
        );
      }

      final partSnap =
          await billRef.collection('participants').doc(targetDebtorUid).get();
      if (!partSnap.exists || partSnap.data() == null) return;
      final part =
          BillParticipantModel.fromMap(partSnap.data()!, docId: partSnap.id);

      final creatorDoc = await _usersCol.doc(requesterUid).get();
      final creatorName =
          (creatorDoc.data()?['full_name'] as String?) ?? 'Penalang';

      await _createAndDispatchNotification(
        receiverUid: targetDebtorUid,
        senderUid: requesterUid,
        billId: bill.billId,
        groupId: bill.groupId,
        type: NotifType.reminder,
        message:
            'Pengingat ramah dari $creatorName: Tagihan "${bill.title}" sebesar ${part.totalDueIdr.toRupiah()} masih menunggu pelunasan.',
      );
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Hapus Tagihan (Oleh Bill Creator jika belum ada debitur yang `paid`, atau oleh Group Admin)
  Future<void> deleteBill({
    required String groupId,
    required String billId,
    required String requesterUid,
  }) async {
    try {
      final groupRef = _groupsCol.doc(groupId);
      final billRef = groupRef.collection('bills').doc(billId);
      final billSnap = await billRef.get();
      if (!billSnap.exists || billSnap.data() == null) return;
      final bill = BillModel.fromMap(billSnap.data()!, docId: billSnap.id);

      final memberDoc =
          await groupRef.collection('members').doc(requesterUid).get();
      final isAdmin =
          (memberDoc.data()?['role'] as String?) == GroupRole.admin.name;
      final isCreator = bill.creatorUid == requesterUid;

      if (!isCreator && !isAdmin) {
        throw const AppAuthException(
          code: 'permission-denied',
          message:
              'Hanya pembuat tagihan atau Admin Grup yang dapat menghapus tagihan.',
        );
      }

      final partsSnap = await billRef.collection('participants').get();
      final hasOtherPaid = partsSnap.docs.any((doc) {
        return doc.id != bill.creatorUid &&
            (doc.data()['payment_status'] as String?) ==
                PaymentStatus.paid.name;
      });

      if (isCreator && !isAdmin && hasOtherPaid) {
        throw const AppAuthException(
          code: 'cannot-delete-paid-bill',
          message:
              'Tagihan tidak dapat dihapus karena sudah ada anggota yang melunasi bagiannya.',
        );
      }

      final itemsSnap = await billRef.collection('items').get();
      for (final itemDoc in itemsSnap.docs) {
        final assignSnap =
            await itemDoc.reference.collection('assignments').get();
        for (final aDoc in assignSnap.docs) {
          await aDoc.reference.delete();
        }
        await itemDoc.reference.delete();
      }
      for (final pDoc in partsSnap.docs) {
        await pDoc.reference.delete();
      }
      await billRef.delete();
    } on AppAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Stream real-time daftar notifikasi milik pengguna (FR-06)
  Stream<List<AppNotification>> watchUserNotifications(String userUid) {
    return _notificationsCol
        .where('receiver_uid', isEqualTo: userUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => AppNotification.fromMap(doc.data(), docId: doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> markNotificationAsRead(String notifId) async {
    try {
      await _notificationsCol.doc(notifId).update({'is_read': true});
    } catch (_) {}
  }

  Future<void> markAllNotificationsAsRead(String userUid) async {
    try {
      final unreadSnap = await _notificationsCol
          .where('receiver_uid', isEqualTo: userUid)
          .where('is_read', isEqualTo: false)
          .get();
      if (unreadSnap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _createAndDispatchNotification({
    required String receiverUid,
    required String senderUid,
    required String billId,
    required String groupId,
    required NotifType type,
    required String message,
  }) async {
    final docRef = _notificationsCol.doc();
    final notif = AppNotification(
      notifId: docRef.id,
      receiverUid: receiverUid,
      senderUid: senderUid,
      billId: billId,
      groupId: groupId,
      type: type,
      message: message,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await docRef.set(notif.toMap());
  }
}
