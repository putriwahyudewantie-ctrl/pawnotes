import 'package:flutter/material.dart';

import '../models/note_model.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';

class NoteViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final ReminderService _reminderService = ReminderService.instance;

  List<Note> _notes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  MaterialColor _themeColor = Colors.pink;
  String? _themeImagePath;
  bool _isDarkMode = false;
  String? _fontFamily;
  bool _hasPrivateVault = false;
  bool _isPrivateUnlocked = false;
  String? _privateCredentialType;
  bool _isAppLockEnabled = false;
  String? _appLockCredentialType;
  late final Future<void> _initialization;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  MaterialColor get themeColor => _themeColor;
  String? get themeImagePath => _themeImagePath;
  String get searchQuery => _searchQuery;
  bool get isDarkMode => _isDarkMode;
  String? get fontFamily => _fontFamily;
  bool get hasPrivateVault => _hasPrivateVault;
  bool get isPrivateUnlocked => _isPrivateUnlocked;
  String? get privateCredentialType => _privateCredentialType;
  bool get isAppLockEnabled => _isAppLockEnabled;
  String? get appLockCredentialType => _appLockCredentialType;
  Future<void> get initialized => _initialization;
  List<String> get folders =>
      {'Umum', ..._notes.map((note) => note.folder)}.toList()..sort();

  List<Note> get filteredNotes {
    final query = _searchQuery.toLowerCase();
    return _notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.folder.toLowerCase().contains(query);
    }).toList();
  }

  NoteViewModel() {
    _initialization = _initializeData();
  }

  Future<void> _initializeData() async {
    await loadNotes();
    final settings = await _storageService.loadSettings();
    _isDarkMode = settings.isDarkMode;
    _fontFamily = settings.fontFamily;
    _themeImagePath = await _storageService.loadThemeImage();
    _hasPrivateVault = await _storageService.hasPrivateVault();
    _privateCredentialType = await _storageService.privateCredentialType();
    _isAppLockEnabled = await _storageService.hasAppLock();
    _appLockCredentialType = await _storageService.appLockCredentialType();
    final savedColor = await _storageService.loadTheme();
    if (savedColor != null) {
      for (final color in _availableColors) {
        if (color.toARGB32() == savedColor) {
          _themeColor = color;
          break;
        }
      }
    }
    notifyListeners();
  }

  static const List<MaterialColor> _availableColors = [
    Colors.pink,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
  ];

  List<MaterialColor> get availableColors => _availableColors;

  Future<void> configureAppLock(
    String credential, {
    required bool isPin,
  }) async {
    await _storageService.configureAppLock(credential, isPin: isPin);
    _isAppLockEnabled = true;
    _appLockCredentialType = isPin ? 'pin' : 'password';
    notifyListeners();
  }

  Future<bool> verifyAppLock(String credential) =>
      _storageService.verifyAppLock(credential);

  Future<void> disableAppLock() async {
    await _storageService.disableAppLock();
    _isAppLockEnabled = false;
    _appLockCredentialType = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> updateTheme(MaterialColor color) async {
    _themeColor = color;
    await _storageService.saveTheme(color.toARGB32());
    notifyListeners();
  }

  Future<void> updateThemeImage(String? imagePath) async {
    await _storageService.saveThemeImage(imagePath);
    _themeImagePath = imagePath;
    notifyListeners();
  }

  Future<void> updateDarkMode(bool value) async {
    _isDarkMode = value;
    await _storageService.saveSettings(
      isDarkMode: _isDarkMode,
      fontFamily: _fontFamily,
    );
    notifyListeners();
  }

  Future<void> updateFont(String? value) async {
    _fontFamily = value;
    await _storageService.saveSettings(
      isDarkMode: _isDarkMode,
      fontFamily: _fontFamily,
    );
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    final unlockedPrivateNotes = _isPrivateUnlocked
        ? _notes.where((note) => note.isPrivate).toList()
        : <Note>[];
    _notes = [...await _storageService.loadNotes(), ...unlockedPrivateNotes];
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addNote(
    String title,
    String content, {
    DateTime? reminderDate,
    DateTime? selectedDate,
    String? imageUrl,
    String folder = 'Umum',
    bool isPrivate = false,
    List<String> attachments = const [],
  }) async {
    if (isPrivate && !_isPrivateUnlocked) {
      throw StateError('Buka folder pribadi sebelum membuat catatan privat.');
    }
    _notes.insert(
      0,
      Note(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        content: content,
        date: DateTime.now(),
        reminderDate: reminderDate,
        selectedDate: selectedDate,
        imageUrl: imageUrl,
        folder: folder,
        isPrivate: isPrivate,
        attachments: List.of(attachments),
      ),
    );
    await _persistNotes();
    return _syncReminder(_notes.first);
  }

  Future<String?> saveDraft(Note note) async {
    await _initialization;
    if (note.isPrivate && !_isPrivateUnlocked) {
      throw StateError('Buka folder pribadi sebelum menyimpan catatan privat.');
    }
    final index = _notes.indexWhere((savedNote) => savedNote.id == note.id);
    if (index == -1) {
      _notes.insert(0, note);
    } else {
      _notes[index] = note;
    }
    await _persistNotes();
    return _syncReminder(note);
  }

  Future<void> createPrivateVault(
    String credential, {
    required bool isPin,
  }) async {
    await _initialization;
    final privateNotes = await _storageService.createPrivateVault(
      credential,
      isPin: isPin,
    );
    _hasPrivateVault = true;
    _isPrivateUnlocked = true;
    _privateCredentialType = isPin ? 'pin' : 'password';
    _notes = [..._notes.where((note) => !note.isPrivate), ...privateNotes];
    notifyListeners();
  }

  Future<bool> unlockPrivateVault(String credential) async {
    await _initialization;
    final privateNotes = await _storageService.unlockPrivateVault(credential);
    if (privateNotes == null) return false;
    _isPrivateUnlocked = true;
    _notes = [..._notes.where((note) => !note.isPrivate), ...privateNotes];
    notifyListeners();
    return true;
  }

  void lockPrivateVault() {
    if (!_isPrivateUnlocked) return;
    _notes.removeWhere((note) => note.isPrivate);
    _isPrivateUnlocked = false;
    _storageService.lockPrivateVault();
    notifyListeners();
  }

  Future<String?> updateNote(
    String id,
    String title,
    String content, {
    DateTime? reminderDate,
    DateTime? selectedDate,
    String? imageUrl,
    String? folder,
    bool? isPrivate,
    List<String>? attachments,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) return null;
    final oldNote = _notes[index];
    _notes[index] = Note(
      id: id,
      title: title,
      content: content,
      date: oldNote.date,
      reminderDate: reminderDate,
      selectedDate: selectedDate,
      imageUrl: imageUrl,
      folder: folder ?? oldNote.folder,
      isArchived: oldNote.isArchived,
      isPrivate: isPrivate ?? oldNote.isPrivate,
      attachments: List.of(attachments ?? oldNote.attachments),
    );
    await _persistNotes();
    return _syncReminder(_notes[index]);
  }

  Future<void> toggleArchived(String id) async {
    final note = _notes.firstWhere((note) => note.id == id);
    note.isArchived = !note.isArchived;
    await _persistNotes();
  }

  Future<String?> togglePrivacy(String id) async {
    final note = _notes.firstWhere((note) => note.id == id);
    if (!note.isPrivate && !_isPrivateUnlocked) {
      throw StateError(
        'Buka folder pribadi sebelum menjadikan catatan privat.',
      );
    }
    note.isPrivate = !note.isPrivate;
    await _persistNotes();
    return _syncReminder(note);
  }

  Future<void> deleteNote(String id) async {
    await _reminderService.cancelReminder(id);
    _notes.removeWhere((note) => note.id == id);
    await _persistNotes();
  }

  Future<void> fetchTemplates() async {
    _isLoading = true;
    notifyListeners();
    try {
      final templates = await _apiService.fetchNoteTemplates();
      _notes.insertAll(0, templates);
      await _storageService.saveNotes(_notes);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistNotes() async {
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  Future<String?> _syncReminder(Note note) async {
    try {
      return await _reminderService.syncReminder(note);
    } catch (error) {
      return 'Pengingat gagal dijadwalkan: $error';
    }
  }
}
