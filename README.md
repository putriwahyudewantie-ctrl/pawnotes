🐾 PawNotes - Flutter MVVM Notes Application
PawNotes adalah aplikasi catatan modern berbasis Flutter yang dirancang dengan arsitektur MVVM (Model-View-ViewModel). Aplikasi ini menawarkan pengalaman mencatat yang estetik, responsif, dan fungsional dengan tema unik "Paw" (jejak kaki hewan).

1. Dependencies (Library Utama)
Daftar library utama yang digunakan dalam project ini:

flutter: Framework utama UI.
cupertino_icons: Menyediakan ikon bergaya iOS.
provider: State Management untuk mengatur alur data dan tema secara reaktif.
shared_preferences: Media penyimpanan data lokal permanen (Persistence Layer).
http: Melakukan request data ke REST API eksternal untuk mengambil template.
intl: Memformat tampilan tanggal dan waktu pada catatan agar lebih rapi.

2. Description (Deskripsi Aplikasi)
PawNotes bukan sekadar aplikasi catatan biasa. Aplikasi ini dibangun dengan standar coding industri untuk memastikan performa yang stabil dan tampilan yang menarik.

Fitur Unggulan:

Arsitektur MVVM: Pemisahan kode yang bersih antara logika (ViewModel) dan tampilan (View).
Auto-Save System: Menggunakan fitur PopScope untuk menyimpan catatan secara otomatis saat user meninggalkan halaman, mencegah kehilangan data.
Responsive Web-Mobile Frame: Tampilan khusus di browser yang dibatasi seukuran layar HP dengan efek shadow premium agar tetap estetik di monitor besar.
Checklist Mode: Mendukung pembuatan daftar tugas dengan fitur centang dan hapus baris dinamis.
Real API Templates: Mengambil contoh catatan dari API publik yang di-mapping otomatis ke Bahasa Indonesia.
Theme Persistence: Pilihan tema warna tetap tersimpan meskipun aplikasi ditutup.

3. User (Target Pengguna)
Aplikasi PawNotes dirancang untuk:

Pelajar/Mahasiswa: Mencatat tugas kuliah atau ringkasan materi secara cepat.
Productivity Seekers: Membuat daftar belanja atau daftar kegiatan harian (To-Do List).
Pengguna Umum: Siapa saja yang membutuhkan aplikasi catatan sederhana dengan UI yang ramah dan estetik.

4. How to Install (Cara Instalasi)
Ikuti langkah-langkah berikut untuk menjalankan project:

Instal Flutter & Dart: Pastikan perangkat Anda sudah terinstal Flutter SDK versi terbaru.
Download/Clone Project:
bash
git clone https://github.com/putriwahyudewantie-ctrl/pawnotes.git
Instal Library: Masuk ke folder project dan jalankan:
bash
flutter pub get
Jalankan Aplikasi:
bash
flutter run
Dibuat untuk memenuhi standar kualitas aplikasi mobile modern.
