class Note {
  String
  id; // Unique identifier untuk setiap catatan, digunakan untuk update, delete, dan Hero animations
  String title; // Judul catatan, ditampilkan di list dan detail
  String content; // Isi catatan, bisa gabungan text dan checklist
  DateTime
  date; // Tanggal & waktu pembuatan catatan, dipakai untuk sorting dan menampilkan timestamp
  DateTime? reminderDate; // Tanggal pengingat opsional untuk catatan
  DateTime? selectedDate; // Tanggal tambahan yang dipilih lewat tombol kalender
  String? imageUrl; // URL atau path gambar catatan

  Note({
    required this.id, // Parameter wajib saat membuat Note baru
    required this.title, // Parameter wajib: judul catatan
    required this.content, // Parameter wajib: isi catatan
    required this.date, // Parameter wajib: tanggal catatan dibuat
    this.reminderDate, // Parameter opsional: tanggal pengingat
    this.selectedDate, // Parameter opsional: tanggal yang dipilih
    this.imageUrl, // Parameter opsional: path/URL gambar
  });

  // Convert to Map for JSON / SharedPreferences
  // Digunakan saat ingin menyimpan catatan ke storage lokal atau mengirim ke API
  Map<String, dynamic> toMap() {
    return {
      'id': id, // key 'id' akan menyimpan id catatan
      'title': title, // key 'title' akan menyimpan judul catatan
      'content': content, // key 'content' akan menyimpan isi catatan
      'date': date
          .toIso8601String(), // key 'date' disimpan sebagai string ISO agar mudah disimpan/load
      'reminderDate': reminderDate
          ?.toIso8601String(), // key 'reminderDate' untuk reminder opsional
      'selectedDate': selectedDate
          ?.toIso8601String(), // key 'selectedDate' untuk tanggal tambahan
      'imageUrl': imageUrl, // key 'imageUrl' untuk gambar opsional
    };
  }

  // Create Note from Map
  // Digunakan saat mengambil data dari storage/API dan mengubahnya menjadi objek Note
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'], // Ambil id dari map
      title: map['title'], // Ambil title dari map
      content: map['content'], // Ambil content dari map
      date: DateTime.parse(map['date']), // Parse string ISO menjadi DateTime
      reminderDate: map['reminderDate'] != null
          ? DateTime.parse(map['reminderDate'])
          : null, // Parse reminderDate jika ada
      selectedDate: map['selectedDate'] != null
          ? DateTime.parse(map['selectedDate'])
          : null, // Parse selectedDate jika ada
      imageUrl: map['imageUrl'] as String?, // Ambil imageUrl jika ada
    );
  }
}
