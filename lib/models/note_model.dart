class Note {
  String id; // Unique identifier untuk setiap catatan, digunakan untuk update, delete, dan Hero animations
  String title; // Judul catatan, ditampilkan di list dan detail
  String content; // Isi catatan, bisa gabungan text dan checklist
  DateTime date; // Tanggal & waktu pembuatan catatan, dipakai untuk sorting dan menampilkan timestamp

  Note({
    required this.id, // Parameter wajib saat membuat Note baru
    required this.title, // Parameter wajib: judul catatan
    required this.content, // Parameter wajib: isi catatan
    required this.date, // Parameter wajib: tanggal catatan dibuat
  });

  // Convert to Map for JSON / SharedPreferences
  // Digunakan saat ingin menyimpan catatan ke storage lokal atau mengirim ke API
  Map<String, dynamic> toMap() {
    return {
      'id': id, // key 'id' akan menyimpan id catatan
      'title': title, // key 'title' akan menyimpan judul catatan
      'content': content, // key 'content' akan menyimpan isi catatan
      'date': date.toIso8601String(), // key 'date' disimpan sebagai string ISO agar mudah disimpan/load
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
    );
  }
}