import 'package:flutter/material.dart'; // Flutter framework untuk UI & ChangeNotifier
import '../models/note_model.dart'; // Import model Note
import '../services/storage_service.dart'; // Import storage service untuk simpan/load lokal
import '../services/api_service.dart'; // Import API service untuk ambil template

class NoteViewModel extends ChangeNotifier { // ViewModel menggunakan ChangeNotifier (MVVM + Provider)
  final StorageService _storageService = StorageService(); // Instance service untuk CRUD lokal
  final ApiService _apiService = ApiService(); // Instance service untuk fetch template API

  List<Note> _notes = []; // List semua catatan
  bool _isLoading = false; // Status loading, dipakai untuk tampilkan progress indicator
  String _searchQuery = ""; // Query search bar
  MaterialColor _themeColor = Colors.pink; // Warna tema default

  // Getter untuk variabel private agar bisa diakses View
  List<Note> get notes => _notes; // Semua catatan
  bool get isLoading => _isLoading; // Status loading
  MaterialColor get themeColor => _themeColor; // Tema saat ini
  String get searchQuery => _searchQuery; // Query pencarian

  // Getter untuk catatan yang sudah difilter berdasarkan searchQuery
  List<Note> get filteredNotes {
    if (_searchQuery.isEmpty) return _notes; // Jika query kosong, return semua notes
    return _notes
        .where((note) =>
            note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            note.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList(); // Filter notes sesuai title/content
  }

  // Constructor, otomatis load notes & theme saat ViewModel dibuat
  NoteViewModel() {
    _initializeData();
  }

  // Gabungan inisialisasi data
  Future<void> _initializeData() async {
    await loadNotes(); // Load notes dari storage lokal
    await _loadTheme(); // Load tema dari storage lokal
  }

  // Update query search dan notifikasi view
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners(); // Memberitahu view rebuild UI
  }

  // Update theme color dan notifikasi view
  void updateTheme(MaterialColor color) {
    _themeColor = color;
    _storageService.saveTheme(color.value); // Simpan pilihan tema ke storage
    notifyListeners(); // Rebuild UI dengan warna baru
  }

  // Load tema dari storage
  Future<void> _loadTheme() async {
    final colorValue = await _storageService.loadTheme();
    if (colorValue != null) {
      // Mencari MaterialColor yang cocok berdasarkan value
      final colors = [Colors.pink, Colors.blue, Colors.green, Colors.orange, Colors.purple];
      for (var color in colors) {
        if (color.value == colorValue) {
          _themeColor = color;
          break;
        }
      }
      notifyListeners();
    }
  }

  // Load notes dari storage lokal
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners(); // Tampilkan progress indicator

    _notes = await _storageService.loadNotes(); // Ambil list Note dari SharedPreferences
    
    _isLoading = false;
    notifyListeners(); // Selesai loading, rebuild UI
  }

  // Tambah note baru
  Future<void> addNote(String title, String content) async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ID unik dari timestamp
      title: title, // Judul catatan baru
      content: content, // Isi catatan baru
      date: DateTime.now(), // Timestamp sekarang
    );
    _notes.add(newNote); // Tambah ke list notes
    await _storageService.saveNotes(_notes); // Simpan ke storage lokal
    notifyListeners(); // Rebuild UI
  }

  // Update note existing
  Future<void> updateNote(String id, String title, String content) async {
    final index = _notes.indexWhere((n) => n.id == id); // Cari index note berdasarkan id
    if (index != -1) {
      _notes[index] = Note(
        id: id, // Tetap pakai id lama
        title: title, // Update title
        content: content, // Update content
        date: DateTime.now(), // Update timestamp sekarang
      );
      await _storageService.saveNotes(_notes); // Simpan perubahan
      notifyListeners(); // Rebuild UI
    }
  }

  // Delete note
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id); // Hapus note berdasarkan id
    await _storageService.saveNotes(_notes); // Simpan perubahan
    notifyListeners(); // Rebuild UI
  }

  // Fetch templates dari API
  Future<void> fetchTemplates() async {
    _isLoading = true;
    notifyListeners(); // Tampilkan progress indicator

    try {
      final templates = await _apiService.fetchNoteTemplates(); // Ambil templates dari API
      _notes.insertAll(0, templates); // Insert template di awal list notes
      await _storageService.saveNotes(_notes); // Simpan ke storage lokal
    } catch (e) { // Tangani error API
      debugPrint("API Error: $e"); // Cetak error ke console
    }

    _isLoading = false;
    notifyListeners(); // Selesai, rebuild UI
  }
}