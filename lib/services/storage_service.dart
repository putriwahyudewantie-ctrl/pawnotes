import 'dart:convert'; // Digunakan untuk encoding/decoding data JSON saat simpan/load
import 'package:shared_preferences/shared_preferences.dart'; // Package untuk storage lokal key-value
import '../models/note_model.dart'; // Import model Note, karena kita simpan Note ke storage

class StorageService {
  static const String _key = 'user_notes'; // Key untuk SharedPreferences, semua catatan disimpan di sini
  static const String _themeKey = 'user_theme'; // Key untuk menyimpan warna tema


  // Fungsi untuk menyimpan list Note ke storage lokal
  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance(); // Ambil instance SharedPreferences
    final String encodedData = jsonEncode(
      notes.map((note) => note.toMap()).toList(), // Convert setiap Note ke Map, lalu encode ke JSON
    );
    await prefs.setString(_key, encodedData); // Simpan JSON string ke SharedPreferences
  }

  // Fungsi untuk load list Note dari storage lokal
  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance(); // Ambil instance SharedPreferences
    final String? encodedData = prefs.getString(_key); // Ambil data string JSON sesuai key
    
    if (encodedData == null) return []; // Jika belum ada data, kembalikan list kosong

    final List<dynamic> decodedData = jsonDecode(encodedData); // Decode JSON ke List<dynamic>
    return decodedData.map((item) => Note.fromMap(item)).toList(); // Ubah tiap Map menjadi Note
  }

  // Fungsi untuk menyimpan tema pilihan user
  Future<void> saveTheme(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, colorValue);
  }

  // Fungsi untuk mengambil tema yang disimpan
  Future<int?> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey);
  }
}