import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../models/note_model.dart';
import '../view_models/note_view_model.dart';
import 'add_note_page.dart';
import 'note_theme_background.dart';

class DetailNotePage extends StatefulWidget {
  final Note note;
  final MaterialColor color;
  final NoteViewModel viewModel;
  final Future<bool> Function() onRequirePrivateAccess;
  final List<String> folders;

  const DetailNotePage({
    super.key,
    required this.note,
    required this.color,
    required this.viewModel,
    required this.onRequirePrivateAccess,
    this.folders = const ['Umum'],
  });

  @override
  State<DetailNotePage> createState() => _DetailNotePageState();
}

class _DetailNotePageState extends State<DetailNotePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSubscription;
  String? _playingPath;

  Note get note => widget.note;
  MaterialColor get color => widget.color;

  @override
  void initState() {
    super.initState();
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _audioCompleteSubscription?.cancel();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        actions: [
          IconButton(
            tooltip: 'Edit catatan',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _editNote,
          ),
        ],
      ),
      body: NoteThemeBackground(
        imagePath: widget.viewModel.themeImagePath,
        isDarkMode: widget.viewModel.isDarkMode,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Hero(
                        tag: note.id,
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            note.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat(
                          'EEEE, dd MMMM yyyy · HH:mm',
                        ).format(note.date),
                        style: TextStyle(
                          color: color.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (note.folder.isNotEmpty || note.isPrivate) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.folder_outlined,
                                size: 18,
                              ),
                              label: Text(note.folder),
                            ),
                            if (note.isPrivate)
                              const Chip(
                                avatar: Icon(Icons.lock_outline, size: 18),
                                label: Text('Pribadi'),
                              ),
                          ],
                        ),
                      ],
                      if (note.selectedDate != null) ...[
                        const SizedBox(height: 10),
                        _dateLine(Icons.calendar_today, note.selectedDate!),
                      ],
                      if (note.reminderDate != null) ...[
                        const SizedBox(height: 8),
                        _dateLine(
                          Icons.notifications_outlined,
                          note.reminderDate!,
                        ),
                      ],
                      if (note.imageUrl case final String imagePath
                          when imagePath.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: double.infinity,
                            height: (MediaQuery.sizeOf(context).height * 0.42)
                                .clamp(220.0, 420.0),
                            child: InkWell(
                              onTap: () => _showImagePreview(imagePath),
                              child: _imageForPath(
                                imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 36),
                      Text(
                        note.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.65,
                        ),
                      ),
                      if (note.attachments.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          'Lampiran',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...note.attachments.map(_attachmentTile),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateLine(IconData icon, DateTime date) {
    return Row(
      children: [
        Icon(icon, color: color.shade700, size: 18),
        const SizedBox(width: 8),
        Text(DateFormat('EEEE, dd MMM yyyy · HH:mm').format(date)),
      ],
    );
  }

  bool _isImagePath(String path) =>
      path.startsWith('data:image/') ||
      RegExp(
        r'\.(png|jpe?g|gif|webp|bmp)$',
        caseSensitive: false,
      ).hasMatch(path);

  Widget _imageForPath(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(path.substring(path.indexOf(',') + 1)),
          width: double.infinity,
          fit: fit,
          errorBuilder: (_, _, _) => _brokenImage(),
        );
      } on FormatException {
        return _brokenImage();
      }
    }
    if (kIsWeb || path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _brokenImage(),
      );
    }
    return Image.file(
      File(path),
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => _brokenImage(),
    );
  }

  Future<void> _showImagePreview(String path) async {
    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: (size.width * 0.9).clamp(280.0, 900.0),
          height: (size.height * 0.85).clamp(280.0, 760.0),
          child: InteractiveViewer(
            child: _imageForPath(path, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _brokenImage() => Container(
    constraints: const BoxConstraints(minHeight: 160),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Text(
        'Gambar tidak dapat dimuat',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    ),
  );

  Widget _attachmentTile(String path) {
    final isAudio =
        path.startsWith('data:audio/') ||
        RegExp(
          r'\.(m4a|aac|wav|mp3|ogg)$',
          caseSensitive: false,
        ).hasMatch(path);
    final filename = path.startsWith('data:')
        ? (isAudio ? 'Rekaman suara' : 'Lampiran')
        : p.basename(path);
    final isPlaying = _playingPath == path;
    if (_isImagePath(path)) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _showImagePreview(path),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.3).clamp(
                  160.0,
                  320.0,
                ),
                child: _imageForPath(path, fit: BoxFit.contain),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(
                filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('Foto · Ketuk untuk melihat'),
              onTap: () => _showImagePreview(path),
            ),
          ],
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isAudio ? Icons.graphic_eq_rounded : Icons.insert_drive_file_outlined,
        ),
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(isAudio ? 'Rekaman audio' : 'Tersimpan di perangkat'),
        onTap: () => isAudio ? _toggleAudio(path) : _openFile(path),
        trailing: IconButton(
          tooltip: isAudio
              ? (isPlaying ? 'Hentikan audio' : 'Putar audio')
              : 'Buka file',
          icon: Icon(
            isAudio
                ? (isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline)
                : Icons.open_in_new_rounded,
          ),
          onPressed: () => isAudio ? _toggleAudio(path) : _openFile(path),
        ),
      ),
    );
  }

  Future<void> _toggleAudio(String path) async {
    try {
      if (_playingPath == path) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingPath = null);
      } else {
        setState(() => _playingPath = path);
        if (path.startsWith('data:') || path.startsWith('blob:')) {
          await _audioPlayer.play(UrlSource(path));
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      }
    } catch (error) {
      if (mounted) setState(() => _playingPath = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio tidak dapat diputar: $error')),
        );
      }
    }
  }

  Future<void> _openFile(String path) async {
    if (path.startsWith('data:') || path.startsWith('blob:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka file tersedia di aplikasi perangkat.'),
        ),
      );
      return;
    }
    final result = await OpenFilex.open(path);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File tidak dapat dibuka: ${result.message}')),
    );
  }

  Future<void> _editNote() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNotePage(
          color: color,
          viewModel: widget.viewModel,
          onRequirePrivateAccess: widget.onRequirePrivateAccess,
          oldNote: note,
          folders: widget.folders,
        ),
      ),
    );
    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }
}
