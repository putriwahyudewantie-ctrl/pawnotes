import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';

class ApiService {
  Future<List<Note>> fetchNoteTemplates() async {
    try {
      // Kita tetap ambil data dari API, tapi kita "Indonesiakan" isinya
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts?_limit=3'),
      );

      if (response.statusCode == 200) {
        // Daftar template Bahasa Indonesia sebagai pengganti
        List<String> judulIndo = [
          "Rencana Belanja Mingguan",
          "Daftar Tugas Hari Ini",
          "Ide Masakan Besok",
          "Catatan Kuliah/Sekolah",
          "Rencana Liburan Akhir Pekan"
        ];

        List<String> isiIndo = [
          "1. Telur\n2. Susu\n3. Sayuran\n4. Buah-buahan",
          "☐ Selesaikan tugas Flutter\n☐ Olahraga pagi\n☐ Belanja bulanan",
          "Menu: Nasi Goreng Spesial dengan topping telur mata sapi dan kerupuk.",
          "Bab 1: Pengenalan MVVM dalam Flutter. Penting untuk memisahkan logic dan UI.",
          "Tujuan: Puncak Bogor. Perlengkapan: Jaket, Kamera, Cemilan."
        ];

        List<dynamic> data = jsonDecode(response.body);
        int index = 0;
        
        return data.map((item) {
          // Kita pakai data dari list Indo agar lebih relevan
          String title = index < judulIndo.length ? judulIndo[index] : "[Template] ${item['title']}";
          String content = index < isiIndo.length ? isiIndo[index] : item['body'];
          
          index++;
          
          return Note(
            id: 'temp_${item['id']}',
            title: title,
            content: content,
            date: DateTime.now(),
          );
        }).toList();
      } else {
        throw Exception('Gagal memuat template');
      }
    } catch (e) {
      throw Exception('Error mengambil template: $e');
    }
  }
}
