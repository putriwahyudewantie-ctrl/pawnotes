import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/note_model.dart';

void main() {
  group('Note storage fields', () {
    test('round trips folder, archive, privacy, and attachments', () {
      final note = Note(
        id: 'note-1',
        title: 'Rencana',
        content: 'Beli buku',
        date: DateTime(2026, 11, 7, 12),
        folder: 'Kuliah',
        isArchived: true,
        isPrivate: true,
        attachments: const ['/documents/voice.m4a', '/documents/slides.pdf'],
      );

      final restored = Note.fromMap(note.toMap());

      expect(restored.folder, 'Kuliah');
      expect(restored.isArchived, isTrue);
      expect(restored.isPrivate, isTrue);
      expect(restored.attachments, note.attachments);
    });

    test('loads notes saved before folders and attachments existed', () {
      final note = Note.fromMap({
        'id': 'old-note',
        'title': 'Catatan lama',
        'content': 'Tetap ada',
        'date': '2026-01-02T03:04:00.000',
        'reminderDate': null,
        'selectedDate': null,
        'imageUrl': null,
      });

      expect(note.folder, 'Umum');
      expect(note.isArchived, isFalse);
      expect(note.isPrivate, isFalse);
      expect(note.attachments, isEmpty);
    });
  });
}
