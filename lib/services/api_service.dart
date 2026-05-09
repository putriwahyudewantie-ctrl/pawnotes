import 'dart:convert'; // Digunakan untuk parsing JSON dari response API
import 'package:http/http.dart' as http; // Paket http untuk request API
import '../models/note_model.dart'; // Import model Note, karena API akan diubah menjadi Note

class ApiService {
  // Fungsi utama untuk mengambil daftar template catatan dari API
  Future<List<Note>> fetchNoteTemplates() async {
    try {
      // Kita tetap ambil data dari API, tapi nanti diganti dengan template Bahasa Indonesia
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts?_limit=6'), // URL API dummy
      );

      if (response.statusCode == 200) { // Jika response sukses (HTTP 200)
        // Daftar judul template Bahasa Indonesia
        List<String> judulIndo = [
          "Rencana Belanja Mingguan",
          "Daftar Tugas Hari Ini",
          "Ide Masakan Besok",
          "Catatan Kuliah/Sekolah",
          "Rencana Liburan Akhir Pekan",
          "Daftar Buku"
        ];

        // Daftar isi template Bahasa Indonesia
List<String> isiIndo = [
  "1. Telur\n2. Susu\n3. Sayuran\n4. Buah-buahan",
  "☐ Selesaikan tugas Flutter\n☐ Olahraga pagi\n☐ Belanja bulanan",
  "Menu: Nasi Goreng Spesial dengan topping telur mata sapi dan kerupuk.",
  "Bab 1: Pengenalan MVVM dalam Flutter. Penting untuk memisahkan logic dan UI.",
  "Tujuan: Puncak Bogor. Perlengkapan: Jaket, Kamera, Cemilan.",
  "Daftar Buku yang Ingin Dibaca",
];
        List<dynamic> data = jsonDecode(response.body); // Parse JSON dari response API
        int index = 0; // Index untuk menyesuaikan judul & isi Indo

        // Mapping data API ke list Note
        return data.map((item) {
          // Gunakan template Indo jika ada, kalau tidak fallback ke data asli API
          String title = index < judulIndo.length ? judulIndo[index] : "[Template] ${item['title']}";
          String content = index < isiIndo.length ? isiIndo[index] : item['body'];
          
          index++; // Naikkan index setiap iterasi
          
          return Note(
            id: 'temp_${item['id']}', // ID sementara template, pakai prefix 'temp_'
            title: title, // Judul catatan
            content: content, // Isi catatan
            date: DateTime.now(), // Set tanggal sekarang sebagai timestamp template
          );
        }).toList();
      } else { // Jika status code bukan 200
        throw Exception('Gagal memuat template'); // Lempar exception
      }
    } catch (e) { // Tangkap error jaringan / parsing
      throw Exception('Error mengambil template: $e'); // Lempar exception dengan info error
    }
  }
}