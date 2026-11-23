import 'dart:async';
import '../core/exceptions/auth_exception.dart';
import '../core/extensions/format_extensions.dart';
import '../models/erd_models.dart';
import 'mock_realtime_database.dart';

// ============================================================================
// BILL & REAL-TIME SETTLEMENT REPOSITORY
// Penanggung Jawab: Anggota 3 (Tabel 1.3, FR-04, FR-05, FR-06, Bab 2.9, UFD-4)
// Menerapkan konsep Advance Dart:
// - Stream lanjutan: StreamTransformer, penggabungan stream tagihan,
//   participants, dan profil pengguna (USERS), serta generator async* / yield.
// - Higher-Order Functions (.fold, .where, .map) untuk menghitung saldo bersih
//   grup secara real-time dari BILL_PARTICIPANTS (Bab 3.1 Alasan Desain #2).
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
  final double totalYouOweIdr; // Total utang Anda yang belum lunas (unpaid/pending/rejected)
  final double totalOwedToYouIdr; // Total piutang dari teman pada tagihan yang Anda talangi

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
  final RealtimeDatabaseStore _store = RealtimeDatabaseStore.instance;

  /// StreamTransformer (Advance Dart - Bab 2.9 Anggota 3):
  /// Mengurutkan daftar tagihan dari yang terbaru dan memfilter tagihan aktif.
  StreamTransformer<List<BillModel>, List<BillModel>>
      get _billSortTransformer =>
          StreamTransformer<List<BillModel>, List<BillModel>>.fromHandlers(
            handleData: (bills, sink) {
              final sorted = List<BillModel>.from(bills)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              sink.add(sorted);
            },
          );

  /// Stream real-time daftar tagihan dalam satu grup menggunakan async* / yield*
  /// dan StreamTransformer (Bab 2.9 Anggota 3)
  Stream<List<BillModel>> watchGroupBills(String groupId) async* {
    Stream<List<BillModel>> rawStream() async* {
      yield _getBillsByGroup(groupId);
      await for (final _ in _store.onDatabaseChanged) {
        yield _getBillsByGroup(groupId);
      }
    }

    yield* rawStream().transform(_billSortTransformer);
  }

  List<BillModel> _getBillsByGroup(String groupId) {
    return _store.bills.values.where((b) => b.groupId == groupId).toList();
  }

  /// Penggabungan Stream Tagihan + Items + Assignments + Participants + Profil Anggota (USERS)
  /// secara real-time menggunakan generator `async*` / `yield` (Bab 2.9 Anggota 3)
  Stream<RichBillDetail?> watchRichBillDetail(String billId) async* {
    yield _buildRichBillDetail(billId);
    await for (final _ in _store.onDatabaseChanged) {
      yield _buildRichBillDetail(billId);
    }
  }

  RichBillDetail? _buildRichBillDetail(String billId) {
    final bill = _store.bills[billId];
    if (bill == null) return null;

    final creator = _store.users[bill.creatorUid] ??
        AppUser(
          uid: bill.creatorUid,
          fullName: 'Creator',
          email: '-',
          photoUrl: '',
          createdAt: DateTime.now(),
        );

    final items = _store.billItems[billId] ?? const [];
    final Map<String, List<ItemAssignmentModel>> assignmentsMap = {};
    for (final item in items) {
      assignmentsMap[item.itemId] =
          _store.itemAssignments[item.itemId] ?? const [];
    }

    final rawParticipants = _store.billParticipants[billId] ?? const [];
    final richParticipants = rawParticipants.map((part) {
      final user = _store.users[part.debtorUid] ??
          AppUser(
            uid: part.debtorUid,
            fullName: 'Anggota',
            email: '-',
            photoUrl: '',
            createdAt: DateTime.now(),
          );

      // Cari seluruh item yang ditanggung oleh anggota ini menggunakan Higher-Order Function
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

    return RichBillDetail(
      bill: bill,
      creator: creator,
      items: items,
      assignmentsByItem: assignmentsMap,
      participants: richParticipants,
    );
  }

  /// Menghitung saldo bersih (utang & piutang) pengguna dari BILL_PARTICIPANTS
  /// menggunakan Higher-Order Functions (.where, .map, .fold) tanpa menyimpan
  /// field redundan net_balance di database (Sesuai Bab 3.1 Alasan Desain #2 & Bab 2.9).
  UserBalanceSummary calculateUserBalance(
    String userUid, {
    String? groupIdFilter,
  }) {
    final relevantBills = _store.bills.values.where(
      (b) => groupIdFilter == null || b.groupId == groupIdFilter,
    );

    // 1. Hitung total utang saya kepada Bill Creator lain yang belum paid
    final double youOwe = relevantBills
        .where((b) => b.creatorUid != userUid)
        .map((b) => _store.billParticipants[b.billId] ?? const [])
        .expand((list) => list)
        .where(
          (p) =>
              p.debtorUid == userUid &&
              p.paymentStatus != PaymentStatus.paid,
        )
        .fold<double>(0.0, (sum, p) => sum + p.totalDueIdr);

    // 2. Hitung total piutang dari anggota lain pada tagihan yang saya buat (talangi)
    final double owedToYou = relevantBills
        .where((b) => b.creatorUid == userUid)
        .map((b) => _store.billParticipants[b.billId] ?? const [])
        .expand((list) => list)
        .where(
          (p) =>
              p.debtorUid != userUid &&
              p.paymentStatus != PaymentStatus.paid,
        )
        .fold<double>(0.0, (sum, p) => sum + p.totalDueIdr);

    return UserBalanceSummary(
      totalYouOweIdr: youOwe,
      totalOwedToYouIdr: owedToYou,
    );
  }

  /// Ambil daftar tagihan aktif yang membutuhkan perhatian pengguna saat ini
  /// (baik tagihan yang belum dibayar oleh pengguna maupun klaim pembayaran teman yang menunggu verifikasi)
  List<ActionableBillItem> getActionableBillsForUser(String userUid) {
    final myGroupIds = _store.groupMembers
        .where((m) => m.userUid == userUid)
        .map((m) => m.groupId)
        .toSet();

    final List<ActionableBillItem> items = [];
    final sortedBills = _store.bills.values
        .where((b) => myGroupIds.contains(b.groupId) && b.status == BillStatus.open)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final bill in sortedBills) {
      final groupName = _store.groups[bill.groupId]?.groupName ?? 'Grup Patungan';
      final parts = _store.billParticipants[bill.billId] ?? const [];

      if (bill.creatorUid == userUid) {
        final pendingClaims = parts
            .where((p) => p.debtorUid != userUid && p.paymentStatus == PaymentStatus.pending)
            .toList();
        final unpaidOthers = parts
            .where((p) => p.debtorUid != userUid && p.paymentStatus != PaymentStatus.paid)
            .fold<double>(0.0, (sum, p) => sum + p.totalDueIdr);

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

  /// Simpan Tagihan Baru beserta BILL_ITEMS, ITEM_ASSIGNMENTS, BILL_PARTICIPANTS,
  /// dan kirim Push Notification "Tagihan Baru" ke semua peserta (UFD-3b, FR-04, FR-06)
  Future<BillModel> saveNewOrUpdatedBill({
    required BillModel bill,
    required List<BillItemModel> items,
    required Map<String, List<ItemAssignmentModel>> assignmentsByItem,
    required List<BillParticipantModel> participants,
    bool isEdit = false,
  }) async {
    _store.assertMemberAccess(bill.groupId, bill.creatorUid);

    // BR-06: Cek apakah semua peserta sudah paid -> status settled, selain itu open
    final allPaid = participants.isNotEmpty &&
        participants.every((p) => p.paymentStatus == PaymentStatus.paid);
    final finalBill = bill.copyWith(
      status: allPaid ? BillStatus.settled : BillStatus.open,
    );

    _store.bills[finalBill.billId] = finalBill;
    _store.billItems[finalBill.billId] = items;
    for (final entry in assignmentsByItem.entries) {
      _store.itemAssignments[entry.key] = entry.value;
    }
    _store.billParticipants[finalBill.billId] = participants;
    _store.notifyChanges();

    // Kirim notifikasi "Tagihan Baru" (new_bill) ke seluruh debitur selain Creator (FR-06)
    final creatorName =
        _store.users[finalBill.creatorUid]?.fullName ?? 'Bill Creator';
    for (final part in participants) {
      if (part.debtorUid != finalBill.creatorUid) {
        await _store.createAndDispatchNotification(
          receiverUid: part.debtorUid,
          senderUid: finalBill.creatorUid,
          billId: finalBill.billId,
          groupId: finalBill.groupId,
          type: NotifType.newBill,
          message: isEdit
              ? 'Tagihan "${finalBill.title}" diperbarui oleh $creatorName. Bagian Anda: ${part.totalDueIdr.toRupiah()}.'
              : 'Tagihan baru "${finalBill.title}" dibuat oleh $creatorName. Bagian Anda: ${part.totalDueIdr.toRupiah()}.',
          triggerDevicePush: true,
        );
      }
    }

    return finalBill;
  }

  /// Aksi Debitur: Menandai bagiannya "Sudah Bayar" (unpaid/rejected -> pending)
  /// Sesuai BR-04, FR-05, Tabel 2.5, dan UFD-4:
  /// Member TIDAK DAPAT menetapkan status `paid` sendiri!
  Future<void> markAsPaidPending({
    required String billId,
    required String debtorUid,
  }) async {
    final bill = _store.bills[billId];
    if (bill == null) return;
    _store.assertMemberAccess(bill.groupId, debtorUid);

    final list = _store.billParticipants[billId] ?? [];
    final idx = list.indexWhere((p) => p.debtorUid == debtorUid);
    if (idx == -1) {
      throw const AppAuthException(
        code: 'not-participant',
        message: 'Anda tidak terdaftar sebagai peserta pada tagihan ini.',
      );
    }

    final current = list[idx];
    if (current.paymentStatus == PaymentStatus.paid) return;

    list[idx] = current.copyWith(
      paymentStatus: PaymentStatus.pending,
      claimedAt: DateTime.now(),
    );
    _store.notifyChanges();

    // Kirim notifikasi klaim bayar (pending) ke Bill Creator (UFD-4 & FR-06)
    final debtorName = _store.users[debtorUid]?.fullName ?? 'Anggota';
    await _store.createAndDispatchNotification(
      receiverUid: bill.creatorUid,
      senderUid: debtorUid,
      billId: bill.billId,
      groupId: bill.groupId,
      type: NotifType.pending,
      message:
          '$debtorName menandai "Sudah Bayar" sebesar ${current.totalDueIdr.toRupiah()} pada tagihan "${bill.title}". Mohon verifikasi.',
    );
  }

  /// Aksi Bill Creator: Memverifikasi (paid) atau Menolak (rejected) klaim pembayaran
  /// Sesuai BR-04, BR-06, FR-05, Tabel 2.5, dan UFD-4:
  /// Hanya Bill Creator (`bill.creatorUid`) yang diizinkan menetapkan `paid` atau `rejected`!
  Future<void> verifyOrRejectClaim({
    required String billId,
    required String requesterUid,
    required String debtorUid,
    required bool isApproved,
  }) async {
    final bill = _store.bills[billId];
    if (bill == null) return;

    // Penegakan RBAC Security Rules (Tabel 2.5 & BR-04):
    // Hanya Bill Creator yang boleh memverifikasi/menolak klaim!
    if (bill.creatorUid != requesterUid) {
      throw const AppAuthException(
        code: 'permission-denied',
        message:
            'Hanya pembuat tagihan (penalang) yang dapat memverifikasi atau menolak pelunasan.',
      );
    }

    final list = _store.billParticipants[billId] ?? [];
    final idx = list.indexWhere((p) => p.debtorUid == debtorUid);
    if (idx == -1) return;

    final current = list[idx];
    final nextStatus =
        isApproved ? PaymentStatus.paid : PaymentStatus.rejected;

    list[idx] = current.copyWith(
      paymentStatus: nextStatus,
      verifiedAt: isApproved ? DateTime.now() : null,
    );

    // BR-06: Jika seluruh peserta sudah berstatus `paid`, otomatis ubah `bills.status = settled`
    final allPaid =
        list.isNotEmpty && list.every((p) => p.paymentStatus == PaymentStatus.paid);
    _store.bills[billId] = bill.copyWith(
      status: allPaid ? BillStatus.settled : BillStatus.open,
    );

    _store.notifyChanges();

    // Kirim Push Notification hasil verifikasi / penolakan ke Debitur (UFD-4 & FR-06)
    final creatorName = _store.users[requesterUid]?.fullName ?? 'Bill Creator';
    await _store.createAndDispatchNotification(
      receiverUid: debtorUid,
      senderUid: requesterUid,
      billId: bill.billId,
      groupId: bill.groupId,
      type: isApproved ? NotifType.verified : NotifType.rejected,
      message: isApproved
          ? 'Pembayaran Anda sebesar ${current.totalDueIdr.toRupiah()} pada "${bill.title}" telah diverifikasi LUNAS oleh $creatorName!'
          : 'Klaim pembayaran Anda (${current.totalDueIdr.toRupiah()}) pada "${bill.title}" ditolak oleh $creatorName. Silakan periksa bukti transfer dan klaim ulang.',
    );
  }

  /// Aksi Debitur saat status `rejected`: Kembali ke `unpaid` untuk bayar ulang (BR-04 & UFD-4)
  Future<void> resetRejectedToUnpaid({
    required String billId,
    required String debtorUid,
  }) async {
    final list = _store.billParticipants[billId] ?? [];
    final idx = list.indexWhere((p) => p.debtorUid == debtorUid);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(paymentStatus: PaymentStatus.unpaid);
    _store.notifyChanges();
  }

  /// Aksi Bill Creator: Kirim Pengingat Otomatis (Nudge) dengan satu ketukan (BO-04, FR-06, UFD-4)
  Future<void> sendPaymentReminderNudge({
    required String billId,
    required String requesterUid,
    required String targetDebtorUid,
  }) async {
    final bill = _store.bills[billId];
    if (bill == null) return;

    if (bill.creatorUid != requesterUid) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Hanya Bill Creator yang dapat mengirim pengingat tagihan.',
      );
    }

    final list = _store.billParticipants[billId] ?? [];
    final match = list.where((p) => p.debtorUid == targetDebtorUid);
    if (match.isEmpty) return;

    final part = match.first;
    final creatorName = _store.users[requesterUid]?.fullName ?? 'Bill Creator';

    await _store.createAndDispatchNotification(
      receiverUid: targetDebtorUid,
      senderUid: requesterUid,
      billId: bill.billId,
      groupId: bill.groupId,
      type: NotifType.reminder,
      message:
          'Pengingat ramah dari $creatorName: Tagihan "${bill.title}" sebesar ${part.totalDueIdr.toRupiah()} masih menunggu pelunasan.',
    );
  }

  /// Hapus Tagihan (Tabel 2.5: Oleh Bill Creator jika belum ada debitur yang `paid`, atau oleh Group Admin)
  Future<void> deleteBill({
    required String billId,
    required String requesterUid,
  }) async {
    final bill = _store.bills[billId];
    if (bill == null) return;

    final groupRole = _store.getUserGroupRole(bill.groupId, requesterUid);
    final isCreator = bill.creatorUid == requesterUid;
    final isAdmin = groupRole == GroupRole.admin;

    if (!isCreator && !isAdmin) {
      throw const AppAuthException(
        code: 'permission-denied',
        message: 'Hanya Bill Creator atau Group Admin yang dapat menghapus tagihan.',
      );
    }

    final parts = _store.billParticipants[billId] ?? [];
    final hasOtherPaid = parts.any(
      (p) => p.debtorUid != bill.creatorUid && p.paymentStatus == PaymentStatus.paid,
    );

    if (isCreator && !isAdmin && hasOtherPaid) {
      throw const AppAuthException(
        code: 'cannot-delete-paid-bill',
        message:
            'Tagihan tidak dapat dihapus karena sudah ada anggota yang melunasi bagiannya.',
      );
    }

    _store.bills.remove(billId);
    _store.billItems.remove(billId);
    _store.billParticipants.remove(billId);
    _store.notifyChanges();
  }

  /// Stream real-time daftar notifikasi milik pengguna (FR-06)
  Stream<List<AppNotification>> watchUserNotifications(String userUid) async* {
    yield _getNotificationsForUser(userUid);
    await for (final _ in _store.onDatabaseChanged) {
      yield _getNotificationsForUser(userUid);
    }
  }

  List<AppNotification> _getNotificationsForUser(String userUid) {
    return _store.notifications
        .where((n) => n.receiverUid == userUid)
        .toList();
  }

  Future<void> markNotificationAsRead(String notifId) async {
    final idx = _store.notifications.indexWhere((n) => n.notifId == notifId);
    if (idx != -1) {
      _store.notifications[idx] =
          _store.notifications[idx].copyWith(isRead: true);
      _store.notifyChanges();
    }
  }

  Future<void> markAllNotificationsAsRead(String userUid) async {
    for (int i = 0; i < _store.notifications.length; i++) {
      if (_store.notifications[i].receiverUid == userUid) {
        _store.notifications[i] =
            _store.notifications[i].copyWith(isRead: true);
      }
    }
    _store.notifyChanges();
  }
}
