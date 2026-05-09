# 🐾 PawNotes - Modern Flutter MVVM Notes Application

### 1. Dependencies (Library Utama)
Daftar teknologi utama yang memastikan **PawNotes** berjalan dengan mulus dan reaktif:

| Library | Kegunaan |
| :--- | :--- |
| **Provider** | State Management untuk mengatur alur data dan tema secara reaktif. |
| **Shared Preferences** | Media penyimpanan data lokal permanen (*Persistence Layer*). |
| **HTTP** | Melakukan request data ke REST API eksternal untuk mengambil template. |
| **Intl** | Memformat tampilan tanggal dan waktu pada catatan agar lebih rapi. |
| **Cupertino Icons** | Menyediakan ikon bergaya iOS untuk mempercantik UI. |

---

### 2. Description (Deskripsi Aplikasi)
**PawNotes** bukan sekadar aplikasi catatan biasa. Aplikasi ini dibangun dengan standar coding industri menggunakan arsitektur **MVVM (Model-View-ViewModel)** untuk memastikan performa yang stabil dan tampilan yang menarik dengan tema unik "Paw".

**Fitur Unggulan:**
*   🏛️ **Arsitektur MVVM**: Pemisahan kode yang bersih antara logika (*ViewModel*) dan tampilan (*View*).
*   💾 **Auto-Save System**: Menyimpan catatan secara otomatis saat user meninggalkan halaman menggunakan fitur `PopScope`.
*   📱 **Responsive Web-Mobile Frame**: Tampilan browser yang dibatasi seukuran layar HP dengan efek *shadow premium*.
*   ✅ **Checklist Mode**: Mendukung pembuatan daftar tugas dengan fitur centang dan hapus baris dinamis.
*   🌐 **Real API Templates**: Mengambil inspirasi catatan dari API publik yang di-*mapping* otomatis ke Bahasa Indonesia.
*   🎨 **Theme Persistence**: Pilihan tema warna tetap tersimpan meskipun aplikasi ditutup.

---

### 3. User (Target Pengguna)
Aplikasi PawNotes dirancang untuk memenuhi berbagai kebutuhan:
*   🎓 **Pelajar/Mahasiswa**: Mencatat tugas kuliah atau ringkasan materi secara cepat.
*   🚀 **Productivity Seekers**: Membuat daftar belanja atau daftar kegiatan harian (*To-Do List*).
*   🐾 **Pengguna Umum**: Siapa saja yang membutuhkan aplikasi catatan sederhana dengan UI yang ramah dan estetik.

---

### 4. How to Install (Cara Instalasi)
Ikuti langkah-langkah berikut untuk menjalankan project di perangkat lokal Anda:

1.  **Instal Flutter & Dart**: Pastikan perangkat Anda sudah terinstal Flutter SDK versi terbaru.
2.  **Clone Project**:
    ```bash
    git clone https://github.com/putriwahyudewantie-ctrl/pawnotes.git
    ```
3.  **Instal Library**:
    ```bash
    flutter pub get
    ```
4.  **Jalankan Aplikasi**:
    ```bash
    flutter run
    ```

---

**📐 Arsitektur Folder Proyek:**
```text
lib/
├── models/         # Struktur data (Note Model)
├── view_models/    # Logika bisnis & state (NoteViewModel)
├── views/          # Halaman UI (NotesPage, AddPage, DetailPage)
├── services/       # Komunikasi luar (API & Storage)
└── main.dart       # Entry point aplikasi
```
