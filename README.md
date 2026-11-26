# kelompok-2_Kelas-C_pemrograman_mobile

## Anggota Kelompok 2
* Muh. Tsaqif Ausaf — D121241012 — @EF1L1M
* Zaky Ahmad Ghufran Azuz — D121241039 — @Stecuu25
* Andika Fauzan Sunarko — D121241091 — @Anzarko

---

## Proyek Akhir: BagiTigaKan (`÷ split_fairly(n)`) — Smart Split-Bill & Budget (Dart & Flutter SDK)

Aplikasi **BagiTigaKan** untuk pengelolaan grup patungan, ekstraksi struk otomatis (OCR), konversi kurs mata uang asing ke Rupiah, pembagian proporsional pajak/layanan/diskon tanpa selisih pembulatan, serta pelacakan pelunasan tagihan secara *real-time* berbasis **Firebase Authentication** dan **Cloud Firestore**.

### Fitur Utama
1. **Autentikasi Sungguhan & Otorisasi Berbasis Peran (RBAC)**
   - Registrasi akun baru, Login, Reset Kata Sandi, dan sesi persisten menggunakan **Firebase Auth**, *Auth Guard* (`GoRouter`), serta Firestore Security Rules untuk pemisahan hak akses **Admin Grup**, **Anggota Grup**, dan **Pembuat/Penalang Tagihan**.
2. **Manajemen Grup & Kode Undangan Unik**
   - Pembuatan grup patungan baru dengan transaksi atomik *invite code* unik 6 karakter, gabung grup via kode, tambah anggota melalui email terdaftar, pencarian grup, dan pengelolaan anggota grup secara *real-time*.
3. **Pindai Struk Otomatis (Smart OCR) & Konversi Kurs**
   - Ekstraksi rincian item dan pajak dari struk belanja di *background isolate* (`Isolate.run`) serta konversi mata uang asing (`USD`, `SGD`, `EUR`, `JPY`, `MYR`) ke `IDR` melalui **Frankfurter API v2**.
4. **Pembagian Tagihan Proporsional Tanpa Selisih**
   - Penandaan anggota per item pesanan dengan kalkulasi pajak restoran (PB1), biaya layanan, dan diskon secara proporsional otomatis (selisih pembulatan Rp 0).
5. **Pelacakan Pelunasan Real-Time & Pengingat Pembayaran**
   - Konfirmasi pembayaran oleh peserta, verifikasi lunas/tolak oleh pembuat tagihan, indikator *progress* pelunasan, serta notifikasi pengingat pembayaran tersimpan di Firestore.

---

### Cara Menjalankan Aplikasi (Tahap Awal: Firebase Local Emulator Suite)

#### 1. Jalankan Firebase Emulator Suite
Pastikan Node.js dan Java (JDK) sudah terpasang, lalu jalankan di terminal pertama:
```bash
firebase emulators:start --project demo-bagitigakan
```
*(Atau gunakan `npx firebase-tools emulators:start --project demo-bagitigakan` jika tidak menginstal global, atau cukup tekan **F5** di VS Code agar emulator otomatis menyala dan ikut mati saat debugging selesai.)*

Layanan yang aktif:
- **Emulator UI (Dashboard):** `http://127.0.0.1:4000`
- **Auth Emulator:** `127.0.0.1:9099`
- **Firestore Emulator:** `127.0.0.1:8080` (menggunakan [firestore.rules](firestore.rules))

#### 2. Jalankan Aplikasi Flutter (Web & Android)
Di terminal kedua:
```bash
flutter pub get

# Untuk Web (Chrome) — otomatis terhubung ke localhost:9099 & localhost:8080
flutter run -d chrome

# Untuk Android Emulator — otomatis terhubung ke 10.0.2.2:9099 & 10.0.2.2:8080
flutter run -d android

# Untuk HP Android fisik (ganti IP dengan IP Wi-Fi komputer Anda)
flutter run --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10
```

#### 3. Beralih ke Firebase Cloud Produksi (Tahap Lanjutan)
Saat siap menggunakan project Firebase Cloud asli:
1. Jalankan `flutterfire configure` untuk menghasilkan `lib/firebase_options.dart`.
2. Hubungkan `DefaultFirebaseOptions.currentPlatform` di `lib/core/firebase/firebase_config.dart`.
3. Jalankan aplikasi dengan `--dart-define=USE_FIREBASE_EMULATOR=false`.

### Pengujian Otomatis
```bash
flutter analyze
flutter test
```
