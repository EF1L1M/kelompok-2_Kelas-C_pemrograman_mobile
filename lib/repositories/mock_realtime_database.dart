import 'dart:async';
import 'dart:math';
import '../core/exceptions/auth_exception.dart';
import '../core/extensions/format_extensions.dart';
import '../core/services/notification_service.dart';
import '../models/erd_models.dart';

// ============================================================================
// REAL-TIME REACTIVE DATA STORE (SIMULASI CLOUD FIRESTORE D1 - D5)
// Mendukung operasi real-time multi-koleksi (9 Entitas ERD Bab 3),
// penegakan Firestore Security Rules (Bab 2.5), dan pemicu otomatis
// Cloud Functions / Push Notification (DFD Proses 6.0).
// ============================================================================

class RealtimeDatabaseStore {
  RealtimeDatabaseStore._() {
    _seedInitialData();
  }

  static final RealtimeDatabaseStore instance = RealtimeDatabaseStore._();

  // D1: USERS & USER_DEVICES
  final Map<String, AppUser> users = {};
  final Map<String, String> userPasswords = {};
  final List<UserDevice> userDevices = [];

  // D2: GROUPS, GROUP_MEMBERS & INVITE_CODES (Transaksi Unik BR-07)
  final Map<String, GroupModel> groups = {};
  final List<GroupMember> groupMembers = [];
  final Map<String, String> inviteCodesToGroupId = {};

  // D3: BILLS & BILL_ITEMS
  final Map<String, BillModel> bills = {};
  final Map<String, List<BillItemModel>> billItems = {};

  // D4: ITEM_ASSIGNMENTS & BILL_PARTICIPANTS
  final Map<String, List<ItemAssignmentModel>> itemAssignments = {};
  final Map<String, List<BillParticipantModel>> billParticipants = {};

  // D5: NOTIFICATIONS
  final List<AppNotification> notifications = [];

  // Broadcast Stream Controller untuk memancarkan perubahan real-time seperti Firestore snapshots()
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Stream<void> get onDatabaseChanged => _changeController.stream;

  void notifyChanges() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  void _seedInitialData() {
    final now = DateTime.now();

    // 1. Seed 4 Akun Pengguna
    final uAndi = AppUser(
      uid: 'u_andi',
      fullName: 'Andi Pratama',
      email: 'andi@mahasiswa.ac.id',
      photoUrl: '',
      createdAt: now.subtract(const Duration(days: 30)),
    );
    final uBudi = AppUser(
      uid: 'u_budi',
      fullName: 'Budi Santoso',
      email: 'budi@mahasiswa.ac.id',
      photoUrl: '',
      createdAt: now.subtract(const Duration(days: 28)),
    );
    final uCitra = AppUser(
      uid: 'u_citra',
      fullName: 'Citra Lestari',
      email: 'citra@mahasiswa.ac.id',
      photoUrl: '',
      createdAt: now.subtract(const Duration(days: 25)),
    );
    final uDoni = AppUser(
      uid: 'u_doni',
      fullName: 'Doni Kusuma',
      email: 'doni@luar.ac.id',
      photoUrl: '',
      createdAt: now.subtract(const Duration(days: 10)),
    );

    for (final u in [uAndi, uBudi, uCitra, uDoni]) {
      users[u.uid] = u;
      userPasswords[u.email.toLowerCase()] = '123456';
      userDevices.add(
        UserDevice(
          deviceId: 'dev_${u.uid}_android',
          userUid: u.uid,
          fcmToken: 'fcm_token_${u.uid}_pixel8_pro',
          platform: 'android',
          updatedAt: now,
        ),
      );
    }

    // 2. Seed 2 Grup Patungan (D2)
    const gKosId = 'g_kos_melati';
    final gKos = GroupModel(
      groupId: gKosId,
      groupName: 'Kos Putra/Putri Melati 4B',
      description: 'Patungan makan malam, listrik, galon, dan belanja kos bulanan',
      inviteCode: 'KOS26A',
      adminUid: uAndi.uid,
      createdAt: now.subtract(const Duration(days: 20)),
    );

    const gSaasId = 'g_tim_mobile';
    final gSaas = GroupModel(
      groupId: gSaasId,
      groupName: 'Tim Proyek Mobile & SaaS',
      description: 'Patungan langganan berbasis USD (ChatGPT, Cloud, makan bareng)',
      inviteCode: 'TIM26B',
      adminUid: uBudi.uid,
      createdAt: now.subtract(const Duration(days: 14)),
    );

    groups[gKosId] = gKos;
    groups[gSaasId] = gSaas;
    inviteCodesToGroupId['KOS26A'] = gKosId;
    inviteCodesToGroupId['TIM26B'] = gSaasId;

    // Keanggotaan Grup 1 (Andi = Admin, Budi = Member, Citra = Member; Doni BUKAN anggota)
    groupMembers.addAll([
      GroupMember(
        memberId: 'm_1',
        groupId: gKosId,
        userUid: uAndi.uid,
        role: GroupRole.admin,
        joinedAt: now.subtract(const Duration(days: 20)),
      ),
      GroupMember(
        memberId: 'm_2',
        groupId: gKosId,
        userUid: uBudi.uid,
        role: GroupRole.member,
        joinedAt: now.subtract(const Duration(days: 19)),
      ),
      GroupMember(
        memberId: 'm_3',
        groupId: gKosId,
        userUid: uCitra.uid,
        role: GroupRole.member,
        joinedAt: now.subtract(const Duration(days: 18)),
      ),
      // Keanggotaan Grup 2 (Budi = Admin, Andi = Member, Citra = Member)
      GroupMember(
        memberId: 'm_4',
        groupId: gSaasId,
        userUid: uBudi.uid,
        role: GroupRole.admin,
        joinedAt: now.subtract(const Duration(days: 14)),
      ),
      GroupMember(
        memberId: 'm_5',
        groupId: gSaasId,
        userUid: uAndi.uid,
        role: GroupRole.member,
        joinedAt: now.subtract(const Duration(days: 13)),
      ),
      GroupMember(
        memberId: 'm_6',
        groupId: gSaasId,
        userUid: uCitra.uid,
        role: GroupRole.member,
        joinedAt: now.subtract(const Duration(days: 13)),
      ),
    ]);

    // 3. Seed Tagihan 1: Makan Malam Resto Jepang (IDR, dengan PB1 10%, Service 5%, Diskon)
    // Creator: Andi (u_andi)
    // Subtotal:
    // - Item 1: Salmon Mentai Roll (Rp 90.000) -> dibagi Andi, Budi, Citra (@ Rp 30.000)
    // - Item 2: Beef Ramen Spesial (Rp 60.000) -> Budi sendiri (Rp 60.000)
    // - Item 3: Chicken Katsu Curry (Rp 50.000) -> Citra sendiri (Rp 50.000)
    // Total Subtotal = Rp 200.000 (Andi: 30.000 [15%], Budi: 90.000 [45%], Citra: 80.000 [40%])
    // Pajak PB1 (10%) = Rp 20.000 | Biaya Layanan (5%) = Rp 10.000 | Diskon Promo = Rp 10.000
    // Grand Total = 200.000 + 20.000 + 10.000 - 10.000 = Rp 220.000
    // Proporsi per anggota (BR-01):
    // - Andi  (15%): 30.000 + 3.000 + 1.500 - 1.500 = Rp 33.000 (Otomatis PAID - BR-05)
    // - Budi  (45%): 90.000 + 9.000 + 4.500 - 4.500 = Rp 99.000 (Status: PENDING - menunggu verifikasi Andi)
    // - Citra (40%): 80.000 + 8.000 + 4.000 - 4.000 = Rp 88.000 (Status: UNPAID)
    // Total semua peserta = 33.000 + 99.000 + 88.000 = Rp 220.000 (Selisih Rp0 - BO-02 & BR-03!)
    const b1Id = 'bill_makan_jepang';
    bills[b1Id] = BillModel(
      billId: b1Id,
      groupId: gKosId,
      creatorUid: uAndi.uid,
      title: 'Makan Malam Ichiban & Kopi Kos',
      currencyCode: 'IDR',
      exchangeRate: 1.0,
      rateDate: now.subtract(const Duration(hours: 6)),
      subtotalIdr: 200000,
      taxAmountIdr: 20000,
      serviceAmountIdr: 10000,
      discountAmountIdr: 10000,
      grandTotalIdr: 220000,
      receiptUrl: 'struk_ichiban_ocr.jpg',
      status: BillStatus.open,
      createdAt: now.subtract(const Duration(hours: 6)),
    );

    billItems[b1Id] = const [
      BillItemModel(
        itemId: 'item_b1_1',
        billId: b1Id,
        itemName: 'Salmon Mentai Sushi Platter (Sharing)',
        qty: 1,
        unitPrice: 90000,
        priceIdr: 90000,
      ),
      BillItemModel(
        itemId: 'item_b1_2',
        billId: b1Id,
        itemName: 'Toripaitan Beef Ramen + Ocha',
        qty: 1,
        unitPrice: 60000,
        priceIdr: 60000,
      ),
      BillItemModel(
        itemId: 'item_b1_3',
        billId: b1Id,
        itemName: 'Chicken Katsu Curry Rice',
        qty: 1,
        unitPrice: 50000,
        priceIdr: 50000,
      ),
    ];

    itemAssignments['item_b1_1'] = const [
      ItemAssignmentModel(
        assignmentId: 'asg_1',
        itemId: 'item_b1_1',
        debtorUid: 'u_andi',
        shareIdr: 30000,
      ),
      ItemAssignmentModel(
        assignmentId: 'asg_2',
        itemId: 'item_b1_1',
        debtorUid: 'u_budi',
        shareIdr: 30000,
      ),
      ItemAssignmentModel(
        assignmentId: 'asg_3',
        itemId: 'item_b1_1',
        debtorUid: 'u_citra',
        shareIdr: 30000,
      ),
    ];
    itemAssignments['item_b1_2'] = const [
      ItemAssignmentModel(
        assignmentId: 'asg_4',
        itemId: 'item_b1_2',
        debtorUid: 'u_budi',
        shareIdr: 60000,
      ),
    ];
    itemAssignments['item_b1_3'] = const [
      ItemAssignmentModel(
        assignmentId: 'asg_5',
        itemId: 'item_b1_3',
        debtorUid: 'u_citra',
        shareIdr: 50000,
      ),
    ];

    billParticipants[b1Id] = [
      BillParticipantModel(
        participantId: 'part_b1_andi',
        billId: b1Id,
        debtorUid: uAndi.uid,
        itemsSubtotalIdr: 30000,
        taxShareIdr: 3000,
        serviceShareIdr: 1500,
        discountShareIdr: 1500,
        totalDueIdr: 33000,
        paymentStatus: PaymentStatus.paid, // BR-05: Bill Creator otomatis paid
        claimedAt: now.subtract(const Duration(hours: 6)),
        verifiedAt: now.subtract(const Duration(hours: 6)),
      ),
      BillParticipantModel(
        participantId: 'part_b1_budi',
        billId: b1Id,
        debtorUid: uBudi.uid,
        itemsSubtotalIdr: 90000,
        taxShareIdr: 9000,
        serviceShareIdr: 4500,
        discountShareIdr: 4500,
        totalDueIdr: 99000,
        paymentStatus: PaymentStatus.pending, // Menunggu verifikasi dari Andi
        claimedAt: now.subtract(const Duration(hours: 2)),
      ),
      BillParticipantModel(
        participantId: 'part_b1_citra',
        billId: b1Id,
        debtorUid: uCitra.uid,
        itemsSubtotalIdr: 80000,
        taxShareIdr: 8000,
        serviceShareIdr: 4000,
        discountShareIdr: 4000,
        totalDueIdr: 88000,
        paymentStatus: PaymentStatus.unpaid, // Belum bayar (bisa di-nudge oleh Andi)
      ),
    ];

    // 4. Seed Tagihan 2: Langganan SaaS Berbasis USD di Grup Kos (Mendemonstrasikan Budi sebagai Bill Creator kontekstual meskipun role grupnya 'member'!)
    // Mata Uang: USD | Kurs Terkunci: Rp 16.000 / USD (BR-02)
    // Item 1: ChatGPT Plus Shared ($20.00 = Rp 320.000) -> dibagi Andi, Budi, Citra
    // Item 2: Netflix 4K UHD ($10.00 = Rp 160.000) -> dibagi Andi & Citra
    // Pajak Digital PPN (10% = $3.00 = Rp 48.000)
    // Grand Total = Rp 528.000
    const b2Id = 'bill_langganan_usd';
    bills[b2Id] = BillModel(
      billId: b2Id,
      groupId: gKosId,
      creatorUid: uBudi.uid, // Budi adalah Creator di tagihan ini!
      title: 'Langganan ChatGPT Plus & Netflix (USD)',
      currencyCode: 'USD',
      exchangeRate: 16000.0,
      rateDate: now.subtract(const Duration(days: 2)),
      subtotalIdr: 480000,
      taxAmountIdr: 48000,
      serviceAmountIdr: 0,
      discountAmountIdr: 0,
      grandTotalIdr: 528000,
      receiptUrl: 'invoice_openai_usd.png',
      status: BillStatus.open,
      createdAt: now.subtract(const Duration(days: 2)),
    );

    billItems[b2Id] = const [
      BillItemModel(
        itemId: 'item_b2_1',
        billId: b2Id,
        itemName: 'OpenAI ChatGPT Plus Subscription (USD 20.00)',
        qty: 1,
        unitPrice: 20.0,
        priceIdr: 320000,
      ),
      BillItemModel(
        itemId: 'item_b2_2',
        billId: b2Id,
        itemName: 'Netflix Premium 4K Add-on (USD 10.00)',
        qty: 1,
        unitPrice: 10.0,
        priceIdr: 160000,
      ),
    ];

    itemAssignments['item_b2_1'] = const [
      ItemAssignmentModel(
        assignmentId: 'asg_b2_1',
        itemId: 'item_b2_1',
        debtorUid: 'u_budi',
        shareIdr: 106667,
      ),
      ItemAssignmentModel(
        assignmentId: 'asg_b2_2',
        itemId: 'item_b2_1',
        debtorUid: 'u_andi',
        shareIdr: 106667,
      ),
      ItemAssignmentModel(
        assignmentId: 'asg_b2_3',
        itemId: 'item_b2_1',
        debtorUid: 'u_citra',
        shareIdr: 106666,
      ),
    ];
    itemAssignments['item_b2_2'] = const [
      ItemAssignmentModel(
        assignmentId: 'asg_b2_4',
        itemId: 'item_b2_2',
        debtorUid: 'u_andi',
        shareIdr: 80000,
      ),
      ItemAssignmentModel(
        assignmentId: 'asg_b2_5',
        itemId: 'item_b2_2',
        debtorUid: 'u_citra',
        shareIdr: 80000,
      ),
    ];

    // Subtotal Budi: 106.667, Andi: 186.667, Citra: 186.666 (Total 480.000)
    // + Pajak 10%: Budi = 117.333, Andi = 205.334, Citra = 205.333 (Total = 528.000, Selisih Rp0!)
    billParticipants[b2Id] = [
      BillParticipantModel(
        participantId: 'part_b2_budi',
        billId: b2Id,
        debtorUid: uBudi.uid,
        itemsSubtotalIdr: 106667,
        taxShareIdr: 10666,
        serviceShareIdr: 0,
        discountShareIdr: 0,
        totalDueIdr: 117333,
        paymentStatus: PaymentStatus.paid, // Budi = Creator
        claimedAt: now.subtract(const Duration(days: 2)),
        verifiedAt: now.subtract(const Duration(days: 2)),
      ),
      BillParticipantModel(
        participantId: 'part_b2_andi',
        billId: b2Id,
        debtorUid: uAndi.uid,
        itemsSubtotalIdr: 186667,
        taxShareIdr: 18667,
        serviceShareIdr: 0,
        discountShareIdr: 0,
        totalDueIdr: 205334,
        paymentStatus: PaymentStatus.unpaid, // Andi adalah Debitur di tagihan milik Budi
      ),
      BillParticipantModel(
        participantId: 'part_b2_citra',
        billId: b2Id,
        debtorUid: uCitra.uid,
        itemsSubtotalIdr: 186666,
        taxShareIdr: 18667,
        serviceShareIdr: 0,
        discountShareIdr: 0,
        totalDueIdr: 205333,
        paymentStatus: PaymentStatus.paid,
        claimedAt: now.subtract(const Duration(days: 1)),
        verifiedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    // 5. Seed Riwayat Notifikasi (D5)
    notifications.addAll([
      AppNotification(
        notifId: 'notif_1',
        receiverUid: uAndi.uid,
        senderUid: uBudi.uid,
        billId: b1Id,
        groupId: gKosId,
        type: NotifType.pending,
        message:
            'Budi Santoso mengklaim sudah membayar ${99000.toRupiah()} pada tagihan "Makan Malam Ichiban & Kopi Kos". Ketuk untuk verifikasi.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        notifId: 'notif_2',
        receiverUid: uAndi.uid,
        senderUid: uBudi.uid,
        billId: b2Id,
        groupId: gKosId,
        type: NotifType.newBill,
        message:
            'Tagihan baru "Langganan ChatGPT Plus & Netflix (USD)" dibuat oleh Budi Santoso. Bagian Anda: ${205334.toRupiah()}.',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AppNotification(
        notifId: 'notif_3',
        receiverUid: uCitra.uid,
        senderUid: uAndi.uid,
        billId: b1Id,
        groupId: gKosId,
        type: NotifType.newBill,
        message:
            'Tagihan baru "Makan Malam Ichiban & Kopi Kos" dibuat oleh Andi Pratama. Bagian Anda: ${88000.toRupiah()}.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ]);
  }

  // Helper RBAC: Cek apakah userUid adalah anggota grup
  bool isGroupMember(String groupId, String userUid) {
    return groupMembers.any(
      (m) => m.groupId == groupId && m.userUid == userUid,
    );
  }

  // Helper RBAC: Ambil role tetap pengguna di grup (admin / member / null)
  GroupRole? getUserGroupRole(String groupId, String userUid) {
    for (final m in groupMembers) {
      if (m.groupId == groupId && m.userUid == userUid) {
        return m.role;
      }
    }
    return null;
  }

  // Helper RBAC: Penegakan Security Rules saat membaca grup (Tabel 2.5 & BR-07)
  void assertMemberAccess(String groupId, String userUid) {
    if (!isGroupMember(groupId, userUid)) {
      throw AppAuthException.fromFirebaseCode('permission-denied');
    }
  }

  // Generate kode undangan unik 6 karakter dengan transaksi pada invite_codes/{kode} (BR-07)
  String generateUniqueInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    while (true) {
      final code = List.generate(
        6,
        (_) => chars[rnd.nextInt(chars.length)],
      ).join();
      if (!inviteCodesToGroupId.containsKey(code)) {
        return code;
      }
    }
  }

  // Buat dan kirim notifikasi (DFD Proses 6.0 + Trigger Push Notification Lokal)
  Future<void> createAndDispatchNotification({
    required String receiverUid,
    required String senderUid,
    required String billId,
    required String groupId,
    required NotifType type,
    required String message,
    bool triggerDevicePush = true,
  }) async {
    final notif = AppNotification(
      notifId: 'notif_${DateTime.now().microsecondsSinceEpoch}',
      receiverUid: receiverUid,
      senderUid: senderUid,
      billId: billId,
      groupId: groupId,
      type: type,
      message: message,
      isRead: false,
      createdAt: DateTime.now(),
    );
    notifications.insert(0, notif);
    notifyChanges();

    if (triggerDevicePush) {
      await NotificationService.instance.showPushNotification(
        title: 'Smart Split-Bill · ${type.label}',
        body: message,
        groupId: groupId,
        billId: billId,
        type: type.code,
      );
    }
  }
}
