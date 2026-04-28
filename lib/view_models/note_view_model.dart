import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class NoteViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  List<Note> _notes = [];
  bool _isLoading = false;
  String _searchQuery = "";
  MaterialColor _themeColor = Colors.pink;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  MaterialColor get themeColor => _themeColor;
  String get searchQuery => _searchQuery;

  List<Note> get filteredNotes {
    if (_searchQuery.isEmpty) return _notes;
    return _notes
        .where((note) =>
            note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            note.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  NoteViewModel() {
    loadNotes();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateTheme(MaterialColor color) {
    _themeColor = color;
    notifyListeners();
  }

  // Load from Local Storage
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    _notes = await _storageService.loadNotes();
    
    _isLoading = false;
    notifyListeners();
  }

  // Add Note
  Future<void> addNote(String title, String content) async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      date: DateTime.now(),
    );
    _notes.add(newNote);
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  // Update Note
  Future<void> updateNote(String id, String title, String content) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = Note(
        id: id,
        title: title,
        content: content,
        date: DateTime.now(),
      );
      await _storageService.saveNotes(_notes);
      notifyListeners();
    }
  }

  // Delete Note
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  // Fetch Templates from API
  Future<void> fetchTemplates() async {
    _isLoading = true;
    notifyListeners();

    try {
      final templates = await _apiService.fetchNoteTemplates();
      _notes.insertAll(0, templates); // Insert at the top
      await _storageService.saveNotes(_notes);
    } catch (e) {
      debugPrint("API Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}
