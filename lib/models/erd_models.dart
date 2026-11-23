// ============================================================================
// MODEL DATA 9 ENTITAS ERD (BAB 3 & TABEL 3.1 PEMETAAN KOLEKSI FIRESTORE)
// 1. USERS               -> users/{uid}
// 2. USER_DEVICES        -> users/{uid}/devices/{deviceId}
// 3. GROUPS              -> groups/{groupId}
// 4. GROUP_MEMBERS       -> groups/{groupId}/members/{uid}
// 5. BILLS               -> groups/{groupId}/bills/{billId}
// 6. BILL_ITEMS          -> .../bills/{billId}/items/{itemId}
// 7. ITEM_ASSIGNMENTS    -> .../items/{itemId}/assignments/{debtorUid}
// 8. BILL_PARTICIPANTS   -> .../bills/{billId}/participants/{debtorUid}
// 9. NOTIFICATIONS       -> notifications/{notifId}
// ============================================================================

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  try {
    // Mendukung Firestore Timestamp tanpa mengikat model ke package cloud_firestore
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}

double _toDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

enum GroupRole {
  admin,
  member;

  String get label => switch (this) {
        GroupRole.admin => 'Admin Grup',
        GroupRole.member => 'Anggota',
      };

  static GroupRole fromString(String value) =>
      value.toLowerCase() == 'admin' ? GroupRole.admin : GroupRole.member;
}

enum BillStatus {
  open,
  settled;

  String get label => switch (this) {
        BillStatus.open => 'Belum Lunas',
        BillStatus.settled => 'Lunas Semua',
      };

  static BillStatus fromString(String value) =>
      value.toLowerCase() == 'settled' ? BillStatus.settled : BillStatus.open;
}

enum PaymentStatus {
  unpaid,
  pending,
  paid,
  rejected;

  String get label => switch (this) {
        PaymentStatus.unpaid => 'Belum Bayar',
        PaymentStatus.pending => 'Menunggu Verifikasi',
        PaymentStatus.paid => 'Lunas',
        PaymentStatus.rejected => 'Perlu Konfirmasi Ulang',
      };

  String get shortLabel => switch (this) {
        PaymentStatus.unpaid => 'Belum Bayar',
        PaymentStatus.pending => 'Verifikasi',
        PaymentStatus.paid => 'Lunas',
        PaymentStatus.rejected => 'Ditolak',
      };

  static PaymentStatus fromString(String value) => switch (value.toLowerCase()) {
        'pending' => PaymentStatus.pending,
        'paid' => PaymentStatus.paid,
        'rejected' => PaymentStatus.rejected,
        _ => PaymentStatus.unpaid,
      };
}

enum NotifType {
  newBill('new_bill', 'Tagihan Baru'),
  reminder('reminder', 'Pengingat Pembayaran'),
  pending('pending', 'Konfirmasi Pembayaran'),
  verified('verified', 'Pembayaran Lunas'),
  rejected('rejected', 'Pembayaran Ditolak');

  final String code;
  final String label;
  const NotifType(this.code, this.label);

  static NotifType fromCode(String code) => switch (code) {
        'reminder' => NotifType.reminder,
        'pending' => NotifType.pending,
        'verified' => NotifType.verified,
        'rejected' => NotifType.rejected,
        _ => NotifType.newBill,
      };
}

// Ringkasan ringan peserta yang ikut disimpan pada dokumen BILLS agar
// perhitungan saldo & daftar "Perlu Perhatian" real-time tanpa N+1 query.
class BillParticipantSummary {
  final String debtorUid;
  final double totalDueIdr;
  final PaymentStatus paymentStatus;

  const BillParticipantSummary({
    required this.debtorUid,
    required this.totalDueIdr,
    required this.paymentStatus,
  });

  BillParticipantSummary copyWith({
    double? totalDueIdr,
    PaymentStatus? paymentStatus,
  }) =>
      BillParticipantSummary(
        debtorUid: debtorUid,
        totalDueIdr: totalDueIdr ?? this.totalDueIdr,
        paymentStatus: paymentStatus ?? this.paymentStatus,
      );

  Map<String, dynamic> toMap() => {
        'debtor_uid': debtorUid,
        'total_due_idr': totalDueIdr,
        'payment_status': paymentStatus.name,
      };

  factory BillParticipantSummary.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) =>
      BillParticipantSummary(
        debtorUid: (map['debtor_uid'] as String?) ?? uid,
        totalDueIdr: _toDouble(map['total_due_idr']),
        paymentStatus: PaymentStatus.fromString(
          (map['payment_status'] as String?) ?? 'unpaid',
        ),
      );
}

// 1. Entitas USERS (users/{uid})
class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.photoUrl,
    required this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'full_name': fullName,
        'email': email,
        'photo_url': photoUrl,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map, {String? docId}) => AppUser(
        uid: (map['uid'] as String?) ?? docId ?? '',
        fullName: (map['full_name'] as String?) ?? 'Pengguna',
        email: (map['email'] as String?) ?? '',
        photoUrl: (map['photo_url'] as String?) ?? '',
        createdAt: _parseDateTime(map['created_at']),
      );
}

// 2. Entitas USER_DEVICES (users/{uid}/devices/{deviceId})
class UserDevice {
  final String deviceId;
  final String userUid;
  final String fcmToken;
  final String platform; // android | ios | web
  final DateTime updatedAt;

  const UserDevice({
    required this.deviceId,
    required this.userUid,
    required this.fcmToken,
    required this.platform,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'device_id': deviceId,
        'user_uid': userUid,
        'fcm_token': fcmToken,
        'platform': platform,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserDevice.fromMap(Map<String, dynamic> map, {String? docId}) =>
      UserDevice(
        deviceId: (map['device_id'] as String?) ?? docId ?? '',
        userUid: (map['user_uid'] as String?) ?? '',
        fcmToken: (map['fcm_token'] as String?) ?? '',
        platform: (map['platform'] as String?) ?? 'android',
        updatedAt: _parseDateTime(map['updated_at']),
      );
}

// 3. Entitas GROUPS (groups/{groupId})
class GroupModel {
  final String groupId;
  final String groupName;
  final String description;
  final String inviteCode; // UK (Unique Key)
  final String adminUid;
  final List<String> memberUids;
  final DateTime createdAt;

  const GroupModel({
    required this.groupId,
    required this.groupName,
    this.description = '',
    required this.inviteCode,
    required this.adminUid,
    this.memberUids = const [],
    required this.createdAt,
  });

  GroupModel copyWith({
    String? groupName,
    String? description,
    String? inviteCode,
    List<String>? memberUids,
  }) =>
      GroupModel(
        groupId: groupId,
        groupName: groupName ?? this.groupName,
        description: description ?? this.description,
        inviteCode: inviteCode ?? this.inviteCode,
        adminUid: adminUid,
        memberUids: memberUids ?? this.memberUids,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'group_id': groupId,
        'group_name': groupName,
        'description': description,
        'invite_code': inviteCode,
        'admin_uid': adminUid,
        'member_uids': memberUids,
        'created_at': createdAt.toIso8601String(),
      };

  factory GroupModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawMembers = map['member_uids'];
    final memberList = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList()
        : <String>[];
    return GroupModel(
      groupId: (map['group_id'] as String?) ?? docId ?? '',
      groupName: (map['group_name'] as String?) ?? 'Grup Patungan',
      description: (map['description'] as String?) ?? '',
      inviteCode: (map['invite_code'] as String?) ?? '',
      adminUid: (map['admin_uid'] as String?) ?? '',
      memberUids: memberList,
      createdAt: _parseDateTime(map['created_at']),
    );
  }
}

// 4. Entitas GROUP_MEMBERS (groups/{groupId}/members/{uid})
class GroupMember {
  final String memberId;
  final String groupId;
  final String userUid;
  final GroupRole role; // admin | member (Role tetap pada grup)
  final DateTime joinedAt;

  const GroupMember({
    required this.memberId,
    required this.groupId,
    required this.userUid,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'member_id': memberId,
        'group_id': groupId,
        'user_uid': userUid,
        'role': role.name,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory GroupMember.fromMap(Map<String, dynamic> map, {String? docId}) =>
      GroupMember(
        memberId: (map['member_id'] as String?) ?? docId ?? '',
        groupId: (map['group_id'] as String?) ?? '',
        userUid: (map['user_uid'] as String?) ?? docId ?? '',
        role: GroupRole.fromString((map['role'] as String?) ?? 'member'),
        joinedAt: _parseDateTime(map['joined_at']),
      );
}

// 5. Entitas BILLS (groups/{groupId}/bills/{billId})
class BillModel {
  final String billId;
  final String groupId;
  final String creatorUid; // Bill Creator kontekstual per tagihan
  final String title;
  final String currencyCode; // IDR | USD | SGD | EUR | JPY | MYR
  final double exchangeRate; // 1 untuk IDR, atau nilai kurs Frankfurter yang dikunci (BR-02)
  final DateTime rateDate; // Tanggal kurs dikunci (BR-02)
  final double subtotalIdr;
  final double taxAmountIdr;
  final double serviceAmountIdr;
  final double discountAmountIdr;
  final double grandTotalIdr;
  final String receiptUrl;
  final BillStatus status; // open | settled (BR-06)
  final Map<String, BillParticipantSummary> participantSummaries;
  final DateTime createdAt;

  const BillModel({
    required this.billId,
    required this.groupId,
    required this.creatorUid,
    required this.title,
    required this.currencyCode,
    required this.exchangeRate,
    required this.rateDate,
    required this.subtotalIdr,
    required this.taxAmountIdr,
    required this.serviceAmountIdr,
    required this.discountAmountIdr,
    required this.grandTotalIdr,
    this.receiptUrl = '',
    required this.status,
    this.participantSummaries = const {},
    required this.createdAt,
  });

  BillModel copyWith({
    String? title,
    String? currencyCode,
    double? exchangeRate,
    DateTime? rateDate,
    double? subtotalIdr,
    double? taxAmountIdr,
    double? serviceAmountIdr,
    double? discountAmountIdr,
    double? grandTotalIdr,
    String? receiptUrl,
    BillStatus? status,
    Map<String, BillParticipantSummary>? participantSummaries,
  }) =>
      BillModel(
        billId: billId,
        groupId: groupId,
        creatorUid: creatorUid,
        title: title ?? this.title,
        currencyCode: currencyCode ?? this.currencyCode,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        rateDate: rateDate ?? this.rateDate,
        subtotalIdr: subtotalIdr ?? this.subtotalIdr,
        taxAmountIdr: taxAmountIdr ?? this.taxAmountIdr,
        serviceAmountIdr: serviceAmountIdr ?? this.serviceAmountIdr,
        discountAmountIdr: discountAmountIdr ?? this.discountAmountIdr,
        grandTotalIdr: grandTotalIdr ?? this.grandTotalIdr,
        receiptUrl: receiptUrl ?? this.receiptUrl,
        status: status ?? this.status,
        participantSummaries: participantSummaries ?? this.participantSummaries,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'bill_id': billId,
        'group_id': groupId,
        'creator_uid': creatorUid,
        'title': title,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'rate_date': rateDate.toIso8601String(),
        'subtotal_idr': subtotalIdr,
        'tax_amount_idr': taxAmountIdr,
        'service_amount_idr': serviceAmountIdr,
        'discount_amount_idr': discountAmountIdr,
        'grand_total_idr': grandTotalIdr,
        'receipt_url': receiptUrl,
        'status': status.name,
        'participant_summaries': participantSummaries.map(
          (k, v) => MapEntry(k, v.toMap()),
        ),
        'created_at': createdAt.toIso8601String(),
      };

  factory BillModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final Map<String, BillParticipantSummary> summaries = {};
    final rawSummaries = map['participant_summaries'];
    if (rawSummaries is Map) {
      for (final entry in rawSummaries.entries) {
        if (entry.value is Map) {
          final uid = entry.key.toString();
          summaries[uid] = BillParticipantSummary.fromMap(
            uid,
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    return BillModel(
      billId: (map['bill_id'] as String?) ?? docId ?? '',
      groupId: (map['group_id'] as String?) ?? '',
      creatorUid: (map['creator_uid'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Tagihan Patungan',
      currencyCode: (map['currency_code'] as String?) ?? 'IDR',
      exchangeRate: _toDouble(map['exchange_rate'], fallback: 1.0),
      rateDate: _parseDateTime(map['rate_date']),
      subtotalIdr: _toDouble(map['subtotal_idr']),
      taxAmountIdr: _toDouble(map['tax_amount_idr']),
      serviceAmountIdr: _toDouble(map['service_amount_idr']),
      discountAmountIdr: _toDouble(map['discount_amount_idr']),
      grandTotalIdr: _toDouble(map['grand_total_idr']),
      receiptUrl: (map['receipt_url'] as String?) ?? '',
      status: BillStatus.fromString((map['status'] as String?) ?? 'open'),
      participantSummaries: summaries,
      createdAt: _parseDateTime(map['created_at']),
    );
  }
}

// 6. Entitas BILL_ITEMS (.../bills/{billId}/items/{itemId})
class BillItemModel {
  final String itemId;
  final String billId;
  final String itemName;
  final int qty;
  final double unitPrice; // Harga satuan dalam mata uang asal
  final double priceIdr; // Total harga item (qty * unitPrice * exchangeRate) dalam IDR (BR-02)

  const BillItemModel({
    required this.itemId,
    required this.billId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.priceIdr,
  });

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'bill_id': billId,
        'item_name': itemName,
        'qty': qty,
        'unit_price': unitPrice,
        'price_idr': priceIdr,
      };

  factory BillItemModel.fromMap(Map<String, dynamic> map, {String? docId}) =>
      BillItemModel(
        itemId: (map['item_id'] as String?) ?? docId ?? '',
        billId: (map['bill_id'] as String?) ?? '',
        itemName: (map['item_name'] as String?) ?? 'Item',
        qty: _toInt(map['qty'], fallback: 1),
        unitPrice: _toDouble(map['unit_price']),
        priceIdr: _toDouble(map['price_idr']),
      );
}

// 7. Entitas ITEM_ASSIGNMENTS (.../items/{itemId}/assignments/{debtorUid})
class ItemAssignmentModel {
  final String assignmentId;
  final String itemId;
  final String debtorUid;
  final double shareIdr; // Bagian harga item (IDR) yang ditanggung oleh debtorUid

  const ItemAssignmentModel({
    required this.assignmentId,
    required this.itemId,
    required this.debtorUid,
    required this.shareIdr,
  });

  Map<String, dynamic> toMap() => {
        'assignment_id': assignmentId,
        'item_id': itemId,
        'debtor_uid': debtorUid,
        'share_idr': shareIdr,
      };

  factory ItemAssignmentModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) =>
      ItemAssignmentModel(
        assignmentId: (map['assignment_id'] as String?) ?? docId ?? '',
        itemId: (map['item_id'] as String?) ?? '',
        debtorUid: (map['debtor_uid'] as String?) ?? docId ?? '',
        shareIdr: _toDouble(map['share_idr']),
      );
}

// 8. Entitas BILL_PARTICIPANTS (.../bills/{billId}/participants/{debtorUid})
class BillParticipantModel {
  final String participantId;
  final String billId;
  final String debtorUid;
  final double itemsSubtotalIdr;
  final double taxShareIdr;
  final double serviceShareIdr;
  final double discountShareIdr;
  final double totalDueIdr; // Dibulatkan ke Rupiah; selisih pembulatan Rp0 (BR-03)
  final PaymentStatus paymentStatus; // unpaid | pending | paid | rejected (BR-04)
  final DateTime? claimedAt;
  final DateTime? verifiedAt;

  const BillParticipantModel({
    required this.participantId,
    required this.billId,
    required this.debtorUid,
    required this.itemsSubtotalIdr,
    required this.taxShareIdr,
    required this.serviceShareIdr,
    required this.discountShareIdr,
    required this.totalDueIdr,
    required this.paymentStatus,
    this.claimedAt,
    this.verifiedAt,
  });

  BillParticipantModel copyWith({
    double? itemsSubtotalIdr,
    double? taxShareIdr,
    double? serviceShareIdr,
    double? discountShareIdr,
    double? totalDueIdr,
    PaymentStatus? paymentStatus,
    DateTime? claimedAt,
    DateTime? verifiedAt,
  }) =>
      BillParticipantModel(
        participantId: participantId,
        billId: billId,
        debtorUid: debtorUid,
        itemsSubtotalIdr: itemsSubtotalIdr ?? this.itemsSubtotalIdr,
        taxShareIdr: taxShareIdr ?? this.taxShareIdr,
        serviceShareIdr: serviceShareIdr ?? this.serviceShareIdr,
        discountShareIdr: discountShareIdr ?? this.discountShareIdr,
        totalDueIdr: totalDueIdr ?? this.totalDueIdr,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        claimedAt: claimedAt ?? this.claimedAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );

  Map<String, dynamic> toMap() => {
        'participant_id': participantId,
        'bill_id': billId,
        'debtor_uid': debtorUid,
        'items_subtotal_idr': itemsSubtotalIdr,
        'tax_share_idr': taxShareIdr,
        'service_share_idr': serviceShareIdr,
        'discount_share_idr': discountShareIdr,
        'total_due_idr': totalDueIdr,
        'payment_status': paymentStatus.name,
        'claimed_at': claimedAt?.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
      };

  factory BillParticipantModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) =>
      BillParticipantModel(
        participantId: (map['participant_id'] as String?) ?? docId ?? '',
        billId: (map['bill_id'] as String?) ?? '',
        debtorUid: (map['debtor_uid'] as String?) ?? docId ?? '',
        itemsSubtotalIdr: _toDouble(map['items_subtotal_idr']),
        taxShareIdr: _toDouble(map['tax_share_idr']),
        serviceShareIdr: _toDouble(map['service_share_idr']),
        discountShareIdr: _toDouble(map['discount_share_idr']),
        totalDueIdr: _toDouble(map['total_due_idr']),
        paymentStatus: PaymentStatus.fromString(
          (map['payment_status'] as String?) ?? 'unpaid',
        ),
        claimedAt: _parseNullableDateTime(map['claimed_at']),
        verifiedAt: _parseNullableDateTime(map['verified_at']),
      );
}

// 9. Entitas NOTIFICATIONS (notifications/{notifId})
class AppNotification {
  final String notifId;
  final String receiverUid;
  final String senderUid;
  final String billId;
  final String groupId;
  final NotifType type; // new_bill | reminder | pending | verified | rejected
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.notifId,
    required this.receiverUid,
    required this.senderUid,
    required this.billId,
    required this.groupId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        notifId: notifId,
        receiverUid: receiverUid,
        senderUid: senderUid,
        billId: billId,
        groupId: groupId,
        type: type,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'notif_id': notifId,
        'receiver_uid': receiverUid,
        'sender_uid': senderUid,
        'bill_id': billId,
        'group_id': groupId,
        'type': type.code,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) =>
      AppNotification(
        notifId: (map['notif_id'] as String?) ?? docId ?? '',
        receiverUid: (map['receiver_uid'] as String?) ?? '',
        senderUid: (map['sender_uid'] as String?) ?? '',
        billId: (map['bill_id'] as String?) ?? '',
        groupId: (map['group_id'] as String?) ?? '',
        type: NotifType.fromCode((map['type'] as String?) ?? 'new_bill'),
        message: (map['message'] as String?) ?? '',
        isRead: (map['is_read'] as bool?) ?? false,
        createdAt: _parseDateTime(map['created_at']),
      );
}
