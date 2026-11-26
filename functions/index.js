/**
 * ============================================================================
 * FIREBASE CLOUD FUNCTIONS - BAGITIGAKAN
 * Penanggung Jawab: Anggota 3 (Real-Time Settlement, Firestore Sync & FCM)
 * Menangani pengiriman Push Notification FCM secara aman dari sisi server
 * tanpa menyimpan server key di klien (NFR-01, FR-06, DFD Proses 6.0).
 *
 * Lima Skenario Trigger:
 * 1. new_bill   : Tagihan baru dibuat -> kirim ke seluruh peserta (debitur)
 * 2. pending    : Debitur menandai "Sudah Bayar" -> kirim ke Bill Creator
 * 3. reminder   : Bill Creator menekan tombol "Ingatkan (Nudge)" -> kirim ke debitur unpaid
 * 4. verified   : Bill Creator memverifikasi klaim (paid) -> kirim ke debitur
 * 5. rejected   : Bill Creator menolak klaim (rejected) -> kirim ke debitur
 * ============================================================================
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * Trigger otomatis setiap kali dokumen baru ditambahkan ke koleksi `notifications/{notifId}`.
 * Mengambil seluruh `fcm_token` penerima dari subkoleksi `users/{receiver_uid}/devices`
 * dan mengirimkan payload FCM ke perangkat terkait.
 */
exports.onNotificationCreated = functions.firestore
  .document("notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    if (!notif || !notif.receiver_uid) return null;

    const receiverUid = notif.receiver_uid;
    const devicesSnap = await db
      .collection("users")
      .doc(receiverUid)
      .collection("devices")
      .get();

    if (devicesSnap.empty) {
      console.log(`Tidak ada fcm_token terdaftar untuk user ${receiverUid}`);
      return null;
    }

    const tokens = [];
    devicesSnap.forEach((doc) => {
      const data = doc.data();
      if (data.fcm_token) tokens.push(data.fcm_token);
    });

    if (tokens.length === 0) return null;

    const titleMap = {
      new_bill: "Tagihan Patungan Baru",
      pending: "Klaim Pembayaran Masuk",
      reminder: "Pengingat Tagihan (Nudge)",
      verified: "Pembayaran Diverifikasi Lunas!",
      rejected: "Klaim Pembayaran Ditolak",
    };

    const messagePayload = {
      notification: {
        title: titleMap[notif.type] || "BagiTigaKan",
        body: notif.message || "Ada pembaruan pada tagihan grup Anda.",
      },
      data: {
        notif_id: context.params.notifId,
        bill_id: notif.bill_id || "",
        group_id: notif.group_id || "",
        type: notif.type || "new_bill",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(messagePayload);
    console.log(
      `FCM terkirim untuk notif ${context.params.notifId}: ${response.successCount} sukses, ${response.failureCount} gagal.`
    );
    return response;
  });
