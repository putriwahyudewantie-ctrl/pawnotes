import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/note_model.dart';
import 'package:flutter_application_1/services/storage_service.dart';
import 'package:flutter_application_1/view_models/note_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'autosaved notes survive reopening and remain until explicitly deleted',
    () async {
      final note = Note(
        id: 'draft-1',
        title: 'Catatan otomatis',
        content: 'Tetap tersimpan',
        date: DateTime(2026, 11, 7),
      );
      final model = NoteViewModel();

      await model.saveDraft(note);

      final reopenedModel = NoteViewModel();
      await reopenedModel.loadNotes();
      expect(reopenedModel.notes.map((item) => item.id), contains(note.id));
      expect(reopenedModel.notes.single.content, note.content);

      await reopenedModel.deleteNote(note.id);
      final modelAfterDelete = NoteViewModel();
      await modelAfterDelete.loadNotes();
      expect(modelAfterDelete.notes, isEmpty);
    },
  );

  test(
    'private vault encrypts legacy notes and requires the right password',
    () async {
      final note = Note(
        id: 'legacy-private',
        title: 'Private title',
        content: 'Secret content that must be encrypted',
        date: DateTime(2026, 11, 7),
        isPrivate: true,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('user_notes', jsonEncode([note.toMap()]));

      final storage = StorageService();
      expect(await storage.loadNotes(), isEmpty);
      final migratedNotes = await storage.createPrivateVault(
        'secure password',
        isPin: false,
      );

      expect(migratedNotes.single.id, note.id);
      expect(preferences.getString('legacy_private_notes'), isNull);
      final encrypted = preferences.getString('private_notes_encrypted');
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(contains(note.content)));
      storage.lockPrivateVault();

      expect(await storage.unlockPrivateVault('incorrect password'), isNull);
      final unlockedNotes = await storage.unlockPrivateVault('secure password');
      expect(unlockedNotes?.single.content, note.content);
    },
  );

  test('private notes stay hidden until the vault is unlocked', () async {
    final model = NoteViewModel();
    await model.createPrivateVault('1234', isPin: true);
    final note = Note(
      id: 'private-note',
      title: 'Private',
      content: 'Only after unlock',
      date: DateTime(2026, 11, 7),
      isPrivate: true,
    );
    await model.saveDraft(note);
    model.lockPrivateVault();

    expect(model.notes.where((item) => item.isPrivate), isEmpty);

    final reopenedModel = NoteViewModel();
    await reopenedModel.loadNotes();
    expect(reopenedModel.notes.where((item) => item.isPrivate), isEmpty);
    expect(await reopenedModel.unlockPrivateVault('9999'), isFalse);
    expect(await reopenedModel.unlockPrivateVault('1234'), isTrue);
    expect(reopenedModel.notes.single.content, note.content);
  });

  test('optional app lock stores a verifier and can be disabled', () async {
    final storage = StorageService();

    expect(await storage.hasAppLock(), isFalse);
    await storage.configureAppLock('2468', isPin: true);
    expect(await storage.hasAppLock(), isTrue);
    expect(await storage.appLockCredentialType(), 'pin');
    expect(await storage.verifyAppLock('1111'), isFalse);
    expect(await storage.verifyAppLock('2468'), isTrue);

    await storage.disableAppLock();
    expect(await storage.hasAppLock(), isFalse);
    expect(await storage.verifyAppLock('anything'), isTrue);
  });
}
