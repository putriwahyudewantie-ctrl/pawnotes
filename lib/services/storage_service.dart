import 'dart:convert'; // Digunakan untuk encoding/decoding data JSON saat simpan/load

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Package untuk storage lokal key-value

import '../models/note_model.dart'; // Import model Note, karena kita simpan Note ke storage

class StorageService {
  static const String _key =
      'user_notes'; // Key untuk SharedPreferences, semua catatan disimpan di sini
  static const String _legacyPrivateNotesKey = 'legacy_private_notes';
  static const String _privateVaultKey = 'private_notes_vault';
  static const String _privateDataKey = 'private_notes_encrypted';
  static const String _appLockKey = 'app_lock_credentials';
  static const String _themeKey =
      'user_theme'; // Key untuk menyimpan warna tema
  static const String _themeImageKey = 'user_theme_image';
  static const String _darkModeKey = 'user_dark_mode';
  static const String _fontKey = 'user_font_family';
  static const String _verificationText = 'PawNotes private vault v1';
  static const int _kdfIterations = 180000;
  SecretKey? _unlockedKey;
  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _kdf = Pbkdf2.hmacSha256(iterations: _kdfIterations, bits: 256);

  // Fungsi untuk menyimpan list Note ke storage lokal
  Future<void> saveNotes(List<Note> notes) async {
    final privateNotes = notes.where((note) => note.isPrivate).toList();
    if (privateNotes.isNotEmpty && _unlockedKey == null) {
      throw StateError('Buka folder pribadi sebelum mengubah catatan privat.');
    }
    final prefs =
        await SharedPreferences.getInstance(); // Ambil instance SharedPreferences
    final publicNotes = notes.where((note) => !note.isPrivate).toList();
    final String encodedData = jsonEncode(
      publicNotes
          .map((note) => note.toMap())
          .toList(), // Convert setiap Note ke Map, lalu encode ke JSON
    );
    await prefs.setString(_key, encodedData);
    if (_unlockedKey != null) {
      await prefs.setString(
        _privateDataKey,
        await _encryptText(
          jsonEncode(privateNotes.map((n) => n.toMap()).toList()),
        ),
      );
    }
  }

  // Fungsi untuk load list Note dari storage lokal
  Future<List<Note>> loadNotes() async {
    final prefs =
        await SharedPreferences.getInstance(); // Ambil instance SharedPreferences
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) {
      return [];
    }

    final notes = _decodeNotes(encodedData);
    if (prefs.getString(_privateVaultKey) != null) {
      return notes.where((note) => !note.isPrivate).toList();
    }

    final legacyPrivateNotes = notes.where((note) => note.isPrivate).toList();
    if (legacyPrivateNotes.isNotEmpty) {
      await prefs.setString(
        _legacyPrivateNotesKey,
        jsonEncode(legacyPrivateNotes.map((note) => note.toMap()).toList()),
      );
      final publicNotes = notes.where((note) => !note.isPrivate).toList();
      await prefs.setString(
        _key,
        jsonEncode(publicNotes.map((note) => note.toMap()).toList()),
      );
      return publicNotes;
    }
    return notes;
  }

  Future<bool> hasPrivateVault() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_privateVaultKey) != null;
  }

  Future<String?> privateCredentialType() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_privateVaultKey);
    if (encoded == null) return null;
    return (jsonDecode(encoded) as Map<String, dynamic>)['type'] as String?;
  }

  Future<bool> hasAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appLockKey) != null;
  }

  Future<String?> appLockCredentialType() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_appLockKey);
    if (encoded == null) return null;
    return (jsonDecode(encoded) as Map<String, dynamic>)['type'] as String?;
  }

  Future<void> configureAppLock(
    String credential, {
    required bool isPin,
  }) async {
    if (isPin
        ? !RegExp(r'^\d{4}$').hasMatch(credential)
        : credential.length < 6) {
      throw ArgumentError(
        'PIN harus 4 angka atau kata sandi minimal 6 karakter.',
      );
    }

    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(credential, salt);
    final verifier = await _encryptText('PawNotes app lock v1', key: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _appLockKey,
      jsonEncode({
        'type': isPin ? 'pin' : 'password',
        'salt': base64Encode(salt),
        'verifier': verifier,
      }),
    );
  }

  Future<bool> verifyAppLock(String credential) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_appLockKey);
    if (encoded == null) return true;

    final lock = jsonDecode(encoded) as Map<String, dynamic>;
    final key = await _deriveKey(
      credential,
      base64Decode(lock['salt'] as String),
    );
    try {
      return await _decryptText(lock['verifier'] as String, key: key) ==
          'PawNotes app lock v1';
    } on SecretBoxAuthenticationError {
      return false;
    }
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appLockKey);
  }

  Future<List<Note>> createPrivateVault(
    String credential, {
    required bool isPin,
  }) async {
    if (isPin
        ? !RegExp(r'^\d{4}$').hasMatch(credential)
        : credential.length < 6) {
      throw ArgumentError(
        'PIN harus 4 angka atau kata sandi minimal 6 karakter.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_privateVaultKey) != null) {
      throw StateError('Kunci folder pribadi sudah dibuat.');
    }

    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(credential, salt);
    final verifier = await _encryptText(_verificationText, key: key);
    final oldPrivate = _decodeNotes(
      prefs.getString(_legacyPrivateNotesKey) ?? '[]',
    );
    final encryptedPrivate = await _encryptText(
      jsonEncode(oldPrivate.map((note) => note.toMap()).toList()),
      key: key,
    );
    await prefs.setString(
      _privateVaultKey,
      jsonEncode({
        'type': isPin ? 'pin' : 'password',
        'salt': base64Encode(salt),
        'verifier': verifier,
      }),
    );
    await prefs.setString(_privateDataKey, encryptedPrivate);
    await prefs.remove(_legacyPrivateNotesKey);
    _unlockedKey = key;
    return oldPrivate;
  }

  Future<List<Note>?> unlockPrivateVault(String credential) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedVault = prefs.getString(_privateVaultKey);
    if (encodedVault == null) return null;
    final vault = jsonDecode(encodedVault) as Map<String, dynamic>;
    final salt = base64Decode(vault['salt'] as String);
    final key = await _deriveKey(credential, salt);
    try {
      final verifier = await _decryptText(
        vault['verifier'] as String,
        key: key,
      );
      if (verifier != _verificationText) return null;
      final encryptedNotes = prefs.getString(_privateDataKey);
      final notes = encryptedNotes == null
          ? <Note>[]
          : _decodeNotes(await _decryptText(encryptedNotes, key: key));
      _unlockedKey = key;
      return notes;
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  void lockPrivateVault() {
    _unlockedKey = null;
  }

  Future<SecretKey> _deriveKey(String credential, List<int> salt) =>
      _kdf.deriveKeyFromPassword(password: credential, nonce: salt);

  Future<String> _encryptText(String value, {SecretKey? key}) async {
    final secretKey = key ?? _unlockedKey;
    if (secretKey == null) {
      throw StateError('Folder pribadi belum dibuka.');
    }
    final box = await _cipher.encrypt(utf8.encode(value), secretKey: secretKey);
    return jsonEncode({
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _decryptText(String encoded, {required SecretKey key}) async {
    final box = jsonDecode(encoded) as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(box['cipherText'] as String),
      nonce: base64Decode(box['nonce'] as String),
      mac: Mac(base64Decode(box['mac'] as String)),
    );
    return utf8.decode(await _cipher.decrypt(secretBox, secretKey: key));
  }

  List<Note> _decodeNotes(String encoded) {
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => Note.fromMap(item as Map<String, dynamic>))
        .toList();
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

  Future<void> saveThemeImage(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    if (imagePath == null) {
      await prefs.remove(_themeImageKey);
    } else {
      await prefs.setString(_themeImageKey, imagePath);
    }
  }

  Future<String?> loadThemeImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeImageKey);
  }

  Future<({bool isDarkMode, String? fontFamily})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      isDarkMode: prefs.getBool(_darkModeKey) ?? false,
      fontFamily: prefs.getString(_fontKey),
    );
  }

  Future<void> saveSettings({
    required bool isDarkMode,
    required String? fontFamily,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
    if (fontFamily == null) {
      await prefs.remove(_fontKey);
    } else {
      await prefs.setString(_fontKey, fontFamily);
    }
  }
}
