# Aplikasi Smart Split-Bill & Budget (Dart & Flutter SDK)

Prototipe lengkap untuk Proyek Akhir Mata Kuliah **Pemrograman Mobile (Dart & Flutter SDK)** berdasarkan dokumen **Laporan Perancangan Sistem (Revisi 2)**.

---

## Ringkasan Pemenuhan 6 Syarat Minimum & Bukti Saat Demo/Responsi

| No | Syarat Minimum | Implementasi pada Proyek Ini | Lokasi File Utama |
|---|---|---|---|
| **1** | **Integrasi dengan Firebase** | Skema 9 koleksi Cloud Firestore (D1–D5), Firebase Auth, FCM (`USER_DEVICES`), Firestore Security Rules, dan Cloud Functions trigger notifikasi. | `firestore.rules`, `functions/index.js`, `lib/repositories/mock_realtime_database.dart` |
| **2** | **State Management** | Menggunakan **BLoC/Cubit** (`flutter_bloc`) secara konsisten untuk Auth (`AuthCubit`), Grup (`GroupCubit`), Split-Bill (`BillSplitCubit`), dan Settlement (`SettlementCubit`). | `lib/features/*/cubit/` |
| **3** | **Advance Dart** | `sealed class` & pattern matching Dart 3 (`AuthState`, `BillState`, `ApiResponse<T>`), `extension` (`CurrencyFormatter`, `DateFormatter`), `mixin` (`FormValidatorMixin`), custom exception (`AppAuthException`), higher-order function (`.fold()`, `.where()`, `.map()`), `Isolate.run` (kompresi citra & parsing JSON OCR), dan `StreamTransformer` + `async*`/`yield`. | `lib/core/extensions/format_extensions.dart`, `lib/core/network/api_response.dart`, `lib/core/utils/isolate_workers.dart`, `lib/repositories/bill_settlement_repository.dart` |
| **4** | **Push Notifications** | `firebase_messaging` + `flutter_local_notifications` untuk kondisi foreground, background, dan terminated, serta 5 skenario notifikasi (`new_bill`, `pending`, `reminder`, `verified`, `rejected`). Ketukan notifikasi langsung membuka `Bill Detail Screen`. | `lib/core/services/notification_service.dart`, `lib/features/settlement/presentation/notification_center_screen.dart` |
| **5** | **API (Open Source)** | **(a) Frankfurter API v2** (`https://api.frankfurter.dev/v2/rates?base=USD&quotes=IDR`) dengan fallback cache/manual; **(b) Open-Source OCR API** (Tesseract / Donut / TrOCR) dengan pemrosesan citra di `Isolate.run`. | `lib/repositories/open_source_api_repository.dart` |
| **6** | **Authentication & Authorization (RBAC)** | Role tetap grup (`admin` vs `member` di `group_members`) + Role kontekstual per tagihan (`Bill Creator` di `bills.creator_uid` vs `Debitur`), ditegakkan dengan **GoRouter Auth Guard**, **Conditional Widget**, dan **Firestore Security Rules**. | `lib/core/router/app_router.dart`, `firestore.rules`, `lib/features/groups/presentation/group_detail_screen.dart` |

---

## Cara Menjalankan Proyek

1. Pastikan Flutter SDK sudah terinstal dan berada pada `PATH` Anda.
2. Dari dalam direktori `d:\KLP3_MOBILE`, jalankan:
   ```bash
   flutter create . --platforms=android,ios
   flutter pub get
   flutter run
   ```
   *(Catatan: Perintah `flutter create .` hanya menambahkan folder runner platform `android/` dan `ios/` standar tanpa menimpa kode di dalam `lib/`).*
3. Untuk menjalankan pengujian aturan bisnis (`BR-01` s/d `BR-07`) dan RBAC:
   ```bash
   flutter test
   ```

---

## Panduan Demo / Responsi untuk 3 Anggota Tim

Aplikasi dilengkapi **Bar Simulasi Ganti Peran / Perangkat Real-Time** di halaman **Home** dan **Bill Detail** sehingga Anda dapat langsung mendemonstrasikan seluruh skenario tanpa perlu keluar-masuk akun berulang kali:

1. **Andi Pratama (`andi@mahasiswa.ac.id` · Sandi: `123456`)**
   - **Role**: `Group Admin` di grup *"Kos Putra/Putri Melati 4B"* (`KOS26A`) dan `Bill Creator` pada tagihan *"Makan Malam Ichiban & Kopi Kos"*.
   - Dapat mendemonstrasikan: Menu Admin (Ubah Info Grup, Keluarkan Anggota, Hapus Grup), Verifikasi Lunas (`paid`) atau Tolak (`rejected`) klaim milik Budi, serta tombol **Ingatkan (Nudge FCM)** 1 ketukan ke Citra.
2. **Budi Santoso (`budi@mahasiswa.ac.id` · Sandi: `123456`)**
   - **Role**: `Group Member` di grup *"Kos Melati"*, tetapi menjadi **`Bill Creator` kontekstual** pada tagihan *"Langganan ChatGPT Plus & Netflix (USD)"* (membuktikan pemisahan role tetap grup dan role kontekstual per tagihan sesuai Bab 2.5).
3. **Citra Lestari (`citra@mahasiswa.ac.id` · Sandi: `123456`)**
   - **Role**: `Group Member (Debitur)`.
   - Dapat mendemonstrasikan: Menandai bagiannya **"Tandai Sudah Bayar"** (`unpaid -> pending`), dan menguji tombol **"Coba Ubah Sendiri ke PAID"** yang langsung ditolak oleh Security Rules.
4. **Doni Kusuma (`doni@luar.ac.id` · Sandi: `123456`)**
   - **Role**: Pengguna terautentikasi **Non-Anggota** grup *"Kos Melati"*.
   - Dapat mendemonstrasikan: Menekan tombol **"Uji Security Rules"** di Home Screen untuk membuktikan bahwa akun non-anggota ditolak membaca data grup (`permission-denied`).
