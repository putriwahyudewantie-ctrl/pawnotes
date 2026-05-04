# PawNotes

## 1. Dependencies

Bagian **Dependencies** berisi library atau package yang digunakan dalam project PawNotes. Library ini dapat dilihat pada file `pubspec.yaml`.

Library yang digunakan dalam project ini adalah:

- **flutter**  
  Framework utama yang digunakan untuk membuat aplikasi mobile PawNotes.

- **cupertino_icons: ^1.0.8**  
  Digunakan untuk menyediakan ikon bergaya iOS pada aplikasi Flutter.

- **provider: ^6.1.5+1**  
  Digunakan untuk state management, yaitu mengatur perubahan data pada aplikasi seperti data catatan, pencarian, dan tema.

- **shared_preferences: ^2.5.5**  
  Digunakan untuk menyimpan data catatan secara lokal di perangkat pengguna, sehingga data tetap tersimpan walaupun aplikasi ditutup.

- **http: ^1.6.0**  
  Digunakan untuk mengambil data dari API. Pada aplikasi ini, package http dipakai untuk mengambil template catatan dari internet.

- **intl: ^0.20.2**  
  Digunakan untuk memformat tanggal dan waktu agar tampilan tanggal pada catatan lebih rapi dan mudah dibaca.

Selain itu, pada bagian **dev_dependencies** terdapat:

- **flutter_test**  
  Digunakan untuk kebutuhan testing pada Flutter.

- **flutter_lints: ^5.0.0**  
  Digunakan untuk membantu menjaga kualitas penulisan kode agar sesuai standar Flutter.

## 2. Description

**PawNotes** adalah aplikasi catatan sederhana berbasis Flutter. Aplikasi ini dibuat untuk membantu pengguna membuat, menyimpan, mencari, mengedit, dan menghapus catatan.

Aplikasi ini memiliki tampilan bertema **paw** atau jejak kaki hewan, sehingga tampilannya lebih menarik dan ramah digunakan. Pengguna dapat membuat catatan biasa maupun checklist. Selain itu, aplikasi juga menyediakan pilihan tema warna seperti pink, biru, hijau, oranye, dan ungu.

Data catatan disimpan secara lokal menggunakan **SharedPreferences**, sehingga catatan tetap tersimpan walaupun aplikasi ditutup. Aplikasi ini juga memiliki fitur mengambil template catatan dari API sebagai contoh catatan awal.

## 3. User

Target pengguna aplikasi **PawNotes** adalah orang-orang yang membutuhkan aplikasi catatan sederhana untuk kegiatan sehari-hari.

Contoh pengguna aplikasi ini adalah:

- Pelajar atau mahasiswa yang ingin mencatat tugas dan materi belajar.
- Pengguna umum yang ingin membuat daftar belanja atau daftar kegiatan.
- Orang yang suka membuat checklist harian.
- Pengguna yang ingin menyimpan ide, rencana, atau catatan singkat secara cepat.

Dengan tampilan yang sederhana, aplikasi ini mudah digunakan oleh pengguna baru karena fitur-fiturnya tidak rumit.

## 4. How to Install

Untuk menjalankan project **PawNotes**, ikuti langkah-langkah berikut:

### 1. Install Flutter dan Dart

Pastikan perangkat sudah menginstall **Flutter SDK** dan **Dart SDK**.

### 2. Download atau Clone Project

Download project PawNotes atau clone repository dari GitHub.

```bash
git clone <link-repository>
```

### 3. Masuk ke Folder Project

```bash
cd pawnotes-main
```

### 4. Install Dependencies

Jalankan perintah berikut di terminal untuk menginstall semua library yang ada di `pubspec.yaml`:

```bash
flutter pub get
```

### 5. Jalankan Aplikasi

Setelah dependency selesai diinstall, jalankan aplikasi dengan perintah:

```bash
flutter run
```

### 6. Pilih Device atau Emulator

Pilih device atau emulator yang tersedia, lalu aplikasi **PawNotes** akan berjalan.

