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
    final parts = fullName.trim().split(' ');
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

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String,
        fullName: map['full_name'] as String,
        email: map['email'] as String,
        photoUrl: (map['photo_url'] as String?) ?? '',
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}

// 2. Entitas USER_DEVICES (users/{uid}/devices/{deviceId})
class UserDevice {
  final String deviceId;
  final String userUid;
  final String fcmToken;
  final String platform; // android | ios
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
}

// 3. Entitas GROUPS (groups/{groupId})
class GroupModel {
  final String groupId;
  final String groupName;
  final String description;
  final String inviteCode; // UK (Unique Key)
  final String adminUid;
  final DateTime createdAt;

  const GroupModel({
    required this.groupId,
    required this.groupName,
    this.description = '',
    required this.inviteCode,
    required this.adminUid,
    required this.createdAt,
  });

  GroupModel copyWith({
    String? groupName,
    String? description,
    String? inviteCode,
  }) =>
      GroupModel(
        groupId: groupId,
        groupName: groupName ?? this.groupName,
        description: description ?? this.description,
        inviteCode: inviteCode ?? this.inviteCode,
        adminUid: adminUid,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'group_id': groupId,
        'group_name': groupName,
        'description': description,
        'invite_code': inviteCode,
        'admin_uid': adminUid,
        'created_at': createdAt.toIso8601String(),
      };
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
        createdAt: createdAt,
      );
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
}
