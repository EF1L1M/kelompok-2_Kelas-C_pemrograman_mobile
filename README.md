# kelompok-2_Kelas-C_pemrograman_mobile

## Anggota Kelompok 2
* Muh. Tsaqif Ausaf — D121241012 — @EF1L1M
* Zaky Ahmad Ghufran Azuz — D121241039 — @Stecuu25
* Andika Fauzan Sunarko — D121241091 — @Anzarko

---

## Proyek Akhir: Smart Split-Bill & Budget (Dart & Flutter SDK)

Aplikasi **Smart Split-Bill & Budget** untuk pengelolaan grup patungan, ekstraksi struk otomatis (OCR), konversi kurs mata uang asing ke Rupiah, pembagian proporsional pajak/layanan/diskon tanpa selisih pembulatan, serta pelacakan pelunasan tagihan secara *real-time*.

### Fitur Utama
1. **Autentikasi & Otorisasi Berbasis Peran (RBAC)**
   - Mendukung masuk dan registrasi pengguna, *Auth Guard* pada navigasi (`GoRouter`), serta pemisahan hak akses antara **Admin Grup**, **Anggota Grup**, dan **Pembuat/Penalang Tagihan**.
2. **Manajemen Grup & Kode Undangan Unik**
   - Pembuatan grup patungan baru dengan *invite code* unik 6 karakter otomatis, gabung grup via kode, pencarian grup, dan pengelolaan anggota grup.
3. **Pindai Struk Otomatis (Smart OCR) & Konversi Kurs**
   - Ekstraksi rincian item dan pajak dari struk belanja di *background isolate* (`Isolate.run`) serta konversi mata uang asing (`USD`, `SGD`, `EUR`, `JPY`, `MYR`) ke `IDR` melalui **Frankfurter API v2**.
4. **Pembagian Tagihan Proporsional Tanpa Selisih**
   - Penandaan anggota per item pesanan dengan kalkulasi pajak restoran (PB1), biaya layanan, dan diskon secara proporsional otomatis.
5. **Pelacakan Pelunasan Real-Time & Pengingat Pembayaran**
   - Konfirmasi pembayaran oleh peserta, verifikasi lunas/tolak oleh pembuat tagihan, indikator *progress* pelunasan, serta pengiriman notifikasi pengingat pembayaran.

### Cara Menjalankan Aplikasi
```bash
flutter pub get
flutter run -d chrome
```
Untuk menjalankan pengujian otomatis:
```bash
flutter test
```
