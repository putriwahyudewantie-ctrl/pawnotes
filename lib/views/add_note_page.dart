import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_capture_page.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/note_model.dart';
import '../view_models/note_view_model.dart';
import 'note_theme_background.dart';

class AddNotePage extends StatefulWidget {
  final MaterialColor color;
  final NoteViewModel viewModel;
  final Note? oldNote;
  final List<String> folders;
  final String initialFolder;
  final bool makePrivate;
  final Future<bool> Function() onRequirePrivateAccess;

  const AddNotePage({
    super.key,
    required this.color,
    required this.viewModel,
    this.oldNote,
    this.folders = const ['Umum'],
    this.initialFolder = 'Umum',
    this.makePrivate = false,
    required this.onRequirePrivateAccess,
  });

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

bool _isImagePath(String path) =>
    path.startsWith('data:image/') ||
    RegExp(r'\.(png|jpe?g|gif|webp|bmp)$', caseSensitive: false).hasMatch(path);

Widget _selectedImagePreview(
  BuildContext context,
  String path, {
  required VoidCallback onRemove,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final height = (MediaQuery.sizeOf(context).height * 0.28).clamp(150.0, 280.0);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image_outlined, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Foto catatan')),
            IconButton(
              tooltip: 'Hapus foto',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: _imageForPath(
                  context,
                  path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _brokenImage(context),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _imageForPath(
  BuildContext context,
  String path, {
  BoxFit fit = BoxFit.cover,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  if (path.startsWith('data:image/')) {
    try {
      return Image.memory(
        base64Decode(path.substring(path.indexOf(',') + 1)),
        fit: fit,
        errorBuilder: errorBuilder,
      );
    } on FormatException {
      return errorBuilder(
        context,
        const FormatException('Invalid image data'),
        StackTrace.current,
      );
    }
  }
  if (kIsWeb || path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(path, fit: fit, errorBuilder: errorBuilder);
  }
  return Image.file(File(path), fit: fit, errorBuilder: errorBuilder);
}

Widget _brokenImage(BuildContext context) => Center(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      'Foto tidak dapat dimuat',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
  ),
);

Future<void> _showImagePreview(BuildContext context, String path) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: InteractiveViewer(
          child: _imageForPath(
            context,
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _brokenImage(context),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openAttachment(BuildContext context, String path) async {
  if (_isImagePath(path)) {
    await _showImagePreview(context, path);
    return;
  }
  if (kIsWeb || path.startsWith('data:') || path.startsWith('blob:')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buka file tersedia di aplikasi perangkat.'),
      ),
    );
    return;
  }
  final result = await OpenFilex.open(path);
  if (!context.mounted || result.type == ResultType.done) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('File tidak dapat dibuka: ${result.message}')),
  );
}

class _AddNotePageState extends State<AddNotePage> with WidgetsBindingObserver {
  static const _checklistMarkers = [
    '✅',
    '🐱',
    '🐶',
    '🐼',
    '🐰',
    '🦊',
    '🐻',
    '🐸',
    '🐵',
    '🌙',
    '⭐',
    '🌸',
    '🌼',
    '🌷',
    '🌻',
    '💖',
    '🍓',
    '🦋',
    '☁️',
  ];

  final TextEditingController titleController = TextEditingController();
  List<Map<String, dynamic>> blocks = [];
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocus = [];
  bool _isSaved = false;
  DateTime? _selectedReminderDate;
  DateTime? _selectedDate;
  String? _selectedImageUrl;
  String _selectedFolder = 'Umum';
  bool _isPrivate = false;
  String _checklistMarker = '✅';
  final List<String> _attachments = [];
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  bool _isRecording = false;
  bool _isRecordingPaused = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  String? _previewPath;
  bool _isPreviewPlaying = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _isApplyingHistory = false;
  final List<Map<String, dynamic>> _undoHistory = [];
  final List<Map<String, dynamic>> _redoHistory = [];
  Map<String, dynamic>? _lastEditorSnapshot;
  String? _lastReminderWarning;
  Timer? _autoSaveTimer;
  Future<String?>? _pendingSave;
  late final String _draftId;
  late final DateTime _draftDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAudioPlayer();
    _draftId =
        widget.oldNote?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _draftDate = widget.oldNote?.date ?? DateTime.now();
    titleController.addListener(_recordEditorChange);
    if (widget.oldNote != null) {
      titleController.text = widget.oldNote!.title;
      _loadOldContent(widget.oldNote!.content);
      _selectedReminderDate = widget.oldNote!.reminderDate;
      _selectedDate = widget.oldNote!.selectedDate;
      _selectedImageUrl = widget.oldNote!.imageUrl;
      _selectedFolder = widget.oldNote!.folder;
      _isPrivate = widget.oldNote!.isPrivate;
      _attachments.addAll(widget.oldNote!.attachments);
    } else {
      _selectedFolder = widget.initialFolder;
      _isPrivate = widget.makePrivate;
      _insertBlock(type: "text");
    }
    _lastEditorSnapshot = _captureEditorSnapshot();
  }

  Map<String, dynamic> _captureEditorSnapshot() => {
    'title': titleController.text,
    'blocks': blocks.map((block) => <String, dynamic>{
      'type': block['type'],
      'text': block['text'],
      'done': block['done'] == true,
      'marker': block['marker'],
    }).toList(),
  };

  bool _sameEditorSnapshot(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['title'] != b['title']) return false;
    final aa = a['blocks'] as List;
    final bb = b['blocks'] as List;
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) {
      final x = aa[i] as Map;
      final y = bb[i] as Map;
      if (x['type'] != y['type'] || x['text'] != y['text'] ||
          x['done'] != y['done'] || x['marker'] != y['marker']) {
        return false;
      }
    }
    return true;
  }

  void _recordEditorChange() {
    if (_isApplyingHistory) return;
    final current = _captureEditorSnapshot();
    final previous = _lastEditorSnapshot;
    if (previous != null && !_sameEditorSnapshot(previous, current)) {
      _undoHistory.add(previous);
      if (_undoHistory.length > 100) _undoHistory.removeAt(0);
      _redoHistory.clear();
    }
    _lastEditorSnapshot = current;
    _scheduleAutoSave();
  }

  void _recordStructuralChange() {
    if (_isApplyingHistory) return;
    final previous = _lastEditorSnapshot;
    if (previous != null) {
      _undoHistory.add(previous);
      if (_undoHistory.length > 100) _undoHistory.removeAt(0);
      _redoHistory.clear();
    }
  }

  void _restoreEditorSnapshot(Map<String, dynamic> snapshot) {
    _isApplyingHistory = true;
    titleController.removeListener(_recordEditorChange);
    titleController.text = snapshot['title'] as String? ?? '';

    for (final controller in _blockControllers) {
      controller.dispose();
    }
    for (final focus in _blockFocus) {
      focus.dispose();
    }
    _blockControllers.clear();
    _blockFocus.clear();
    blocks = [];

    final savedBlocks = (snapshot['blocks'] as List?) ?? [];
    for (final saved in savedBlocks) {
      final item = Map<String, dynamic>.from(saved as Map);
      final block = <String, dynamic>{
        'type': item['type'] ?? 'text',
        'text': item['text'] ?? '',
        'done': item['done'] == true,
        'marker': item['marker'] ?? _checklistMarker,
      };
      final controller = TextEditingController(text: block['text'] as String);
      controller.addListener(() {
        block['text'] = controller.text;
        _recordEditorChange();
      });
      blocks.add(block);
      _blockControllers.add(controller);
      _blockFocus.add(FocusNode());
    }
    if (blocks.isEmpty) {
      final block = <String, dynamic>{
        'type': 'text', 'text': '', 'done': false, 'marker': _checklistMarker,
      };
      final controller = TextEditingController();
      controller.addListener(() {
        block['text'] = controller.text;
        _recordEditorChange();
      });
      blocks.add(block);
      _blockControllers.add(controller);
      _blockFocus.add(FocusNode());
    }
    titleController.addListener(_recordEditorChange);
    _lastEditorSnapshot = _captureEditorSnapshot();
    _isApplyingHistory = false;
    _scheduleAutoSave();
    if (mounted) setState(() {});
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    final current = _captureEditorSnapshot();
    final previous = _undoHistory.removeLast();
    _redoHistory.add(current);
    _restoreEditorSnapshot(previous);
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    final current = _captureEditorSnapshot();
    final next = _redoHistory.removeLast();
    _undoHistory.add(current);
    _restoreEditorSnapshot(next);
  }

  void _loadOldContent(String content) {
    for (var line in content.split("\n")) {
      if (line.startsWith("☑") || line.startsWith("☐")) {
        var checklistText = line.length > 2 ? line.substring(2) : "";
        var marker = '✅';
        for (final candidate in _checklistMarkers) {
          if (checklistText.startsWith('$candidate ')) {
            marker = candidate;
            checklistText = checklistText.substring(candidate.length + 1);
            break;
          }
        }
        _insertBlock(type: "check", text: checklistText, marker: marker);
        blocks.last["done"] = line.startsWith("☑");
      } else {
        _insertBlock(type: "text", text: line);
      }
    }
    if (blocks.isNotEmpty && blocks.last["type"] == "check") {
      _insertBlock(type: "text");
    }
  }

  void _insertBlock({
    required String type,
    String text = "",
    String? marker,
    int? index,
  }) {
    _recordStructuralChange();
    final block = {
      "type": type,
      "text": text,
      "done": false,
      "marker": marker ?? _checklistMarker,
    };
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    final insertAt = index ?? blocks.length;
    blocks.insert(insertAt, block);
    _blockControllers.insert(insertAt, controller);
    _blockFocus.insert(insertAt, focus);
    controller.addListener(() {
      block["text"] = controller.text;
      _recordEditorChange();
    });
    _lastEditorSnapshot = _captureEditorSnapshot();
    setState(() {});
  }

  void _addChecklistBlock() {
    var insertAt = blocks.length;

    // Jika blok terakhir adalah area tulisan kosong, letakkan checklist
    // tepat di atasnya agar area tulisan tetap tersedia di bagian bawah.
    if (blocks.isNotEmpty &&
        blocks.last["type"] == "text" &&
        _blockControllers.last.text.trim().isEmpty) {
      insertAt = blocks.length - 1;
    }

    _insertBlock(
      type: "check",
      marker: _checklistMarker,
      index: insertAt,
    );

    // Selalu sediakan area teks biasa setelah checklist.
    final hasTrailingText = blocks.isNotEmpty &&
        blocks.last["type"] == "text";
    if (!hasTrailingText) {
      _insertBlock(type: "text", index: insertAt + 1);
    }

    final focusIndex = blocks.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || focusIndex >= _blockFocus.length) return;
      _blockFocus[focusIndex].requestFocus();
    });
  }

  void _removeBlock(int index) {
    if (blocks.length > 1) {
      _recordStructuralChange();
      setState(() {
        blocks.removeAt(index);
        _blockControllers[index].dispose();
        _blockControllers.removeAt(index);
        _blockFocus[index].dispose();
        _blockFocus.removeAt(index);
      });
      _lastEditorSnapshot = _captureEditorSnapshot();
      _scheduleAutoSave();
    }
  }

  String _blocksToString() {
    final list = <String>[];
    for (var b in blocks) {
      if (b["type"] == "check") {
        final done = b["done"] == true ? "☑" : "☐";
        list.add("$done ${b["marker"]} ${b["text"]}");
      } else {
        list.add(b["text"]);
      }
    }
    return list.join("\n");
  }

  bool get _hasContentToSave =>
      widget.oldNote != null ||
      titleController.text.trim().isNotEmpty ||
      _blocksToString().trim().isNotEmpty ||
      _selectedReminderDate != null ||
      _selectedDate != null ||
      _selectedImageUrl != null ||
      _attachments.isNotEmpty;

  Note _currentNote() => Note(
    id: _draftId,
    title: titleController.text.trim().isEmpty
        ? 'Tanpa Judul'
        : titleController.text.trim(),
    content: _blocksToString().trim(),
    date: _draftDate,
    reminderDate: _selectedReminderDate,
    selectedDate: _selectedDate,
    imageUrl: _selectedImageUrl,
    folder: _selectedFolder,
    isPrivate: _isPrivate,
    attachments: List<String>.of(_attachments),
    isArchived: widget.oldNote?.isArchived ?? false,
  );

  Map<String, dynamic> _editorResult() => {
    'title': _currentNote().title,
    'content': _currentNote().content,
    'reminderDate': _selectedReminderDate,
    'selectedDate': _selectedDate,
    'imageUrl': _selectedImageUrl,
    'folder': _selectedFolder,
    'isPrivate': _isPrivate,
    'attachments': List<String>.of(_attachments),
  };

  void _scheduleAutoSave() {
    if (!mounted) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        _persistDraft().catchError((Object error) {
          if (mounted) _showSaveError(error);
        }),
      );
    });
    setState(() {});
  }

  Future<void> _persistDraft() async {
    if (!_hasContentToSave) return;
    final previousSave = _pendingSave;
    if (previousSave != null) await previousSave;
    final save = widget.viewModel.saveDraft(_currentNote());
    _pendingSave = save;
    try {
      final reminderWarning = await save;
      if (reminderWarning == null) {
        _lastReminderWarning = null;
      } else if (_lastReminderWarning != reminderWarning) {
        _lastReminderWarning = reminderWarning;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(reminderWarning)));
        }
      }
      if (mounted) setState(() {});
    } finally {
      if (identical(_pendingSave, save)) _pendingSave = null;
    }
  }

  void _showSaveError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Catatan gagal disimpan otomatis: $error')),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autoSaveTimer?.cancel();
      unawaited(
        _persistDraft().catchError((Object error) {
          if (mounted) _showSaveError(error);
        }),
      );
    }
  }

  Future<void> _saveAndPop() async {
    if (_isSaved) return;
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hentikan rekaman sebelum menyimpan.')),
      );
      return;
    }

    _autoSaveTimer?.cancel();
    try {
      await _persistDraft();
    } catch (error) {
      if (mounted) _showSaveError(error);
      return;
    }
    if (!mounted) return;
    _isSaved = true;
    Navigator.pop(context, _hasContentToSave ? _editorResult() : null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Kita handle pop sendiri untuk auto-save
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          elevation: 0,
          title: null,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveAndPop,
            tooltip: 'Kembali',
          ),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: _undoHistory.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: _redoHistory.isEmpty ? null : _redo,
              icon: const Icon(Icons.redo_rounded),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _saveAndPop,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 19),
                label: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
body: NoteThemeBackground(
  imagePath: widget.viewModel.themeImagePath,
  isDarkMode: widget.viewModel.isDarkMode,
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme.surface
                          .withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: titleController,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Judul catatan...',
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme.surface
                                .withValues(alpha: 0.58),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedFolder,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                items: _folderOptions()
                                    .map(
                                      (folder) => DropdownMenuItem(
                                        value: folder,
                                        child: Text(folder),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == '+ folder') {
                                    _createFolder();
                                  } else if (value != null) {
                                    setState(() => _selectedFolder = value);
                                    _scheduleAutoSave();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.lock_outline, size: 18),
                            Switch(
                              value: _isPrivate,
                              activeTrackColor: widget.color,
                              onChanged: (value) async {
                                if (value &&
                                    !widget.viewModel.isPrivateUnlocked) {
                                  final allowed = await widget
                                      .onRequirePrivateAccess();
                                  if (!mounted || !allowed) return;
                                }
                                setState(() => _isPrivate = value);
                                _scheduleAutoSave();
                              },
                            ),
                          ],
                        ),
                        if (_isRecording) _buildRecordingCard(),
                        if (_attachments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _attachments.map((path) {
                                if (_isAudioPath(path)) {
                                  return SizedBox(
                                    width: (MediaQuery.sizeOf(context).width - 100)
                                        .clamp(200.0, 700.0)
                                        .toDouble(),
                                    child: _buildAudioPreview(path),
                                  );
                                }

                                return InputChip(
                                  avatar: Icon(
                                    _isImagePath(path)
                                        ? Icons.image_outlined
                                        : Icons.attach_file,
                                    size: 16,
                                  ),
                                  label: SizedBox(
                                    width: 140,
                                    child: Text(
                                      p.basename(path),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _openAttachment(context, path),
                                  onDeleted: () {
                                    setState(() {
                                      _attachments.remove(path);
                                    });
                                    _scheduleAutoSave();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_selectedReminderDate != null ||
                    _selectedDate != null ||
                    _selectedImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme.surface
                            .withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          if (_selectedReminderDate != null)
                            _buildMetadataRow(
                              icon: Icons.notifications,
                              label:
                                  "Pengingat: ${DateFormat('dd MMM yyyy, HH:mm').format(_selectedReminderDate!)}",
                              onClear: () {
                                setState(
                                  () => _selectedReminderDate = null,
                                );
                                _scheduleAutoSave();
                              },
                            ),
                          if (_selectedDate != null)
                            _buildMetadataRow(
                              icon: Icons.calendar_today,
                              label:
                                  "Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(_selectedDate!)}",
                              onClear: () {
                                setState(() => _selectedDate = null);
                                _scheduleAutoSave();
                              },
                            ),
                          if (_selectedImageUrl != null)
                            _selectedImagePreview(
                              context,
                              _selectedImageUrl!,
                              onRemove: () {
                                setState(() => _selectedImageUrl = null);
                                _scheduleAutoSave();
                              },
                              onTap: () => _showImagePreview(
                                context,
                                _selectedImageUrl!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: List.generate(blocks.length, (i) {
                      final b = blocks[i];
                      final c = _blockControllers[i];
                      final f = _blockFocus[i];

                      if (b["type"] == "check") {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme.surface
                                  .withValues(alpha: 0.46),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: b["done"] == true
                                      ? 'Tandai belum selesai'
                                      : 'Tandai selesai',
                                  onPressed: () {
                                    setState(() {
                                      b["done"] = !(b["done"] == true);
                                    });
                                    _scheduleAutoSave();
                                  },
                                  icon: Text(
                                    b["marker"] as String? ?? '✅',
                                    style: TextStyle(
                                      fontSize: 24,
                                      decoration: b["done"] == true
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: c,
                                    focusNode: f,
                                    maxLines: null,
                                    style: TextStyle(
                                      decoration: b["done"] == true
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    textInputAction:
                                        TextInputAction.newline,
                                    onChanged: (text) {
                                      final lines = text.split('\n');
                                      if (lines.length > 1) {
                                        c.value = TextEditingValue(
                                          text: lines.first,
                                          selection:
                                              TextSelection.collapsed(
                                            offset: lines.first.length,
                                          ),
                                        );
                                        for (
                                          var lineIndex = 1;
                                          lineIndex < lines.length;
                                          lineIndex++
                                        ) {
                                          _insertBlock(
                                            type: "text",
                                            text: lines[lineIndex],
                                            index: i + lineIndex,
                                          );
                                        }
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted &&
                                              _blockFocus.length > i + 1) {
                                            _blockFocus[i + 1]
                                                .requestFocus();
                                          }
                                        });
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _removeBlock(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return TextField(
                        controller: c,
                        focusNode: f,
                        maxLines: null,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Mulai menulis...',
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme.surface
                              .withValues(alpha: 0.46),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          _buildToolbar(),
        ],
      ),
    ),
  ),
),

      ),
    );
  }

  Future<void> _pickReminderDate() async {
    final localContext = context;
    final date = await showDatePicker(
      context: localContext,
      initialDate: _selectedReminderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;
    if (!localContext.mounted) return;

    final time = await showTimePicker(
      context: localContext,
      initialTime: _selectedReminderDate != null
          ? TimeOfDay.fromDateTime(_selectedReminderDate!)
          : TimeOfDay.now(),
    );

    if (time == null) return;
    if (!localContext.mounted) return;

    setState(() {
      _selectedReminderDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _scheduleAutoSave();
  }

  Future<void> _pickNoteDate() async {
    final localContext = context;
    final date = await showDatePicker(
      context: localContext,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;
    if (!localContext.mounted) return;

    final time = await showTimePicker(
      context: localContext,
      initialTime: _selectedDate != null
          ? TimeOfDay.fromDateTime(_selectedDate!)
          : TimeOfDay.now(),
    );

    if (time == null) return;
    if (!localContext.mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _scheduleAutoSave();
  }

Future<void> _pickImageUrl() async {
  try {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambahkan Foto'),
        content: const Text('Pilih sumber foto yang ingin digunakan.'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Kamera'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, ImageSource.gallery);
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeri'),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      // Buka halaman kamera langsung di dalam PawNotes.
      final XFile? photo = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(),
        ),
      );

      if (photo == null || !mounted) return;

      final savedPath = await _saveCapturedImage(photo);

      if (!mounted) return;

      setState(() {
        _selectedImageUrl = savedPath;
      });

      _scheduleAutoSave();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto kamera berhasil ditambahkan!'),
        ),
      );
    } else {
      // Galeri tetap menggunakan image_picker.
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image == null || !mounted) return;

      final savedPath = await _saveCapturedImage(image);

      if (!mounted) return;

      setState(() {
        _selectedImageUrl = savedPath;
      });

      _scheduleAutoSave();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto galeri berhasil ditambahkan!'),
        ),
      );
    }
  } catch (error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gambar gagal ditambahkan: $error'),
        ),
      );
    }
  }
}


  List<String> _folderOptions() {
    final folders = <String>{'Umum', ...widget.folders, _selectedFolder};
    folders.add('+ folder');
    return folders.toList();
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final folder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama folder'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || folder == null || folder.isEmpty) return;
    setState(() => _selectedFolder = folder);
    _scheduleAutoSave();
  }

  Future<String> _saveCapturedImage(XFile image) async {
  final extension = p.extension(image.name).toLowerCase();

  if (kIsWeb) {
    final bytes = await image.readAsBytes();

    final mimeType = switch (extension) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };

    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  final directory = await getApplicationDocumentsDirectory();

  final attachmentDirectory = Directory(
    p.join(directory.path, 'pawnotes_attachments'),
  );

  await attachmentDirectory.create(recursive: true);

  final safeExtension = extension.isEmpty ? '.jpg' : extension;

  final destination = p.join(
    attachmentDirectory.path,
    'camera_${DateTime.now().microsecondsSinceEpoch}$safeExtension',
  );

  await File(image.path).copy(destination);

  return destination;
}

  Future<String> _savePickedFile(PlatformFile pickedFile) async {
    if (kIsWeb) {
      final bytes = await pickedFile.xFile.readAsBytes();
      final mimeType = switch (pickedFile.extension?.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'm4a' => 'audio/mp4',
        _ => 'application/octet-stream',
      };
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    final sourcePath = pickedFile.path;
    if (sourcePath == null) {
      throw StateError('File yang dipilih tidak memiliki lokasi lokal.');
    }
    final directory = await getApplicationDocumentsDirectory();
    final attachmentDirectory = Directory(
      p.join(directory.path, 'pawnotes_attachments'),
    );
    await attachmentDirectory.create(recursive: true);
    final safeName = p.basename(pickedFile.name);
    final destination = p.join(
      attachmentDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await File(sourcePath).copy(destination);
    return destination;
  }

  Future<void> _pickFile() async {
    try {
      final pickedFile = await FilePicker.pickFile(type: FileType.any);
      if (pickedFile == null || !mounted) return;
      final path = await _savePickedFile(pickedFile);
      if (!mounted) return;
      setState(() => _attachments.add(path));
      _scheduleAutoSave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File gagal dilampirkan: $error')),
        );
      }
    }
  }

  bool _isAudioPath(String path) {
    return path.startsWith('data:audio/') ||
        RegExp(
          r'\.(m4a|aac|wav|mp3|ogg|flac)$',
          caseSensitive: false,
        ).hasMatch(path);
  }

  void _setupAudioPlayer() {
    _positionSubscription =
        _previewPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _audioPosition = position);
    });

    _durationSubscription =
        _previewPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _audioDuration = duration);
    });

    _completeSubscription = _previewPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPreviewPlaying = false;
        _audioPosition = Duration.zero;
      });
    });

    _playerStateSubscription =
        _previewPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPreviewPlaying = state == PlayerState.playing;
      });
    });
  }

  String _formatAudioDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleRecording() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rekaman suara tersedia di aplikasi perangkat.'),
          ),
        );
        return;
      }

      if (_isRecording) return;

      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan.')),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final attachmentDirectory = Directory(
        p.join(directory.path, 'pawnotes_attachments'),
      );
      await attachmentDirectory.create(recursive: true);

      final outputPath = p.join(
        attachmentDirectory.path,
        'voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
      );

      await _recorder.start(const RecordConfig(), path: outputPath);

      if (!mounted) return;

      _recordingTimer?.cancel();
      setState(() {
        _isRecording = true;
        _isRecordingPaused = false;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording || _isRecordingPaused) return;
        setState(() => _recordingSeconds++);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rekaman gagal: $error')),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      if (!_isRecording) return;

      if (_isRecordingPaused) {
        await _recorder.resume();
      } else {
        await _recorder.pause();
      }

      if (!mounted) return;
      setState(() {
        _isRecordingPaused = !_isRecordingPaused;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengatur rekaman: $error')),
        );
      }
    }
  }

  Future<void> _finishRecording() async {
    try {
      if (!_isRecording) return;

      _recordingTimer?.cancel();
      final recordedPath = await _recorder.stop();

      if (!mounted) return;

      setState(() {
        if (recordedPath != null && recordedPath.isNotEmpty) {
          _attachments.add(recordedPath);
          _previewPath = null;
          _audioPosition = Duration.zero;
          _audioDuration = Duration.zero;
        }
        _isRecording = false;
        _isRecordingPaused = false;
      });

      _scheduleAutoSave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan rekaman: $error')),
        );
      }
    }
  }

  Future<void> _togglePreviewAudio(String path) async {
    try {
      if (_previewPath == path && _isPreviewPlaying) {
        await _previewPlayer.pause();
        return;
      }

      if (_previewPath != path) {
        await _previewPlayer.stop();

        if (path.startsWith('data:audio/')) {
          final encodedData = path.substring(path.indexOf(',') + 1);
          await _previewPlayer.setSource(
            BytesSource(base64Decode(encodedData)),
          );
        } else if (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('blob:')) {
          await _previewPlayer.setSource(UrlSource(path));
        } else {
          await _previewPlayer.setSource(DeviceFileSource(path));
        }

        final duration = await _previewPlayer.getDuration();

        if (!mounted) return;
        setState(() {
          _previewPath = path;
          _audioPosition = Duration.zero;
          _audioDuration = duration ?? Duration.zero;
        });

        await _previewPlayer.resume();
      } else {
        if (_audioDuration > Duration.zero &&
            _audioPosition >= _audioDuration) {
          await _previewPlayer.seek(Duration.zero);
        }
        await _previewPlayer.resume();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio tidak dapat diputar: $error')),
        );
      }
    }
  }

  Widget _buildRecordingCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: widget.color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _formatAudioDuration(
                Duration(seconds: _recordingSeconds),
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: _isRecordingPaused ? 'Lanjutkan' : 'Jeda',
            onPressed: _pauseRecording,
            icon: Icon(
              _isRecordingPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 30,
            ),
          ),
          IconButton(
            tooltip: 'Selesai merekam',
            onPressed: _finishRecording,
            icon: const Icon(Icons.check_rounded, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview(String path) {
    final theme = Theme.of(context);
    final isCurrent = _previewPath == path;
    final isPlaying = isCurrent && _isPreviewPlaying;
    final duration = isCurrent ? _audioDuration : Duration.zero;
    final position = isCurrent ? _audioPosition : Duration.zero;

    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file_rounded, color: widget.color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.basename(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatAudioDuration(position)} / '
                  '${_formatAudioDuration(duration)}',
                  style: theme.textTheme.labelSmall,
                ),
                SizedBox(
                  height: 24,
                  child: Slider(
                    value: progress,
                    onChanged: duration.inMilliseconds <= 0
                        ? null
                        : (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).round(),
                            );
                            _previewPlayer.seek(newPosition);
                          },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isPlaying ? 'Jeda audio' : 'Putar audio',
            onPressed: () => _togglePreviewAudio(path),
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: widget.color,
              size: 32,
            ),
          ),
          IconButton(
            tooltip: 'Hapus rekaman',
            onPressed: () async {
              if (_previewPath == path) {
                await _previewPlayer.stop();
                if (!mounted) return;
                setState(() {
                  _previewPath = null;
                  _isPreviewPlaying = false;
                  _audioPosition = Duration.zero;
                  _audioDuration = Duration.zero;
                });
              }
              if (!mounted) return;
              setState(() => _attachments.remove(path));
              _scheduleAutoSave();
            },
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow({
    required IconData icon,
    required String label,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: widget.color[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: widget.color[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: Text(
                _checklistMarker,
                style: const TextStyle(fontSize: 22),
              ),
              onPressed: _addChecklistBlock,
              tooltip: 'Tambah checklist ($_checklistMarker)',
            ),
            PopupMenuButton<String>(
              tooltip: 'Pilih emoji checklist',
              icon: const Icon(Icons.arrow_drop_down_rounded),
              onSelected: (marker) => setState(() => _checklistMarker = marker),
              itemBuilder: (context) => _checklistMarkers
                  .map(
                    (marker) => PopupMenuItem(
                      value: marker,
                      child: Text(
                        '$marker  ${marker == '✅' ? 'Checklist biasa' : 'Emoji checklist'}',
                      ),
                    ),
                  )
                  .toList(),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: _pickReminderDate,
              tooltip: "Pasang Pengingat",
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded),
              onPressed: _pickNoteDate,
              tooltip: "Pilih Tanggal",
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined),
              onPressed: _pickImageUrl,
              tooltip: "Tambah Gambar",
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickFile,
              tooltip: 'Lampirkan File',
            ),
            IconButton(
              icon: const Icon(Icons.mic_none),
              color: widget.color,
              onPressed: _isRecording ? null : _toggleRecording,
              tooltip: 'Rekam Suara',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _recordingTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _playerStateSubscription?.cancel();
    unawaited(_previewPlayer.dispose());
    titleController.removeListener(_recordEditorChange);
    titleController.dispose();
    for (final controller in _blockControllers) {
      controller.dispose();
    }
    for (final focus in _blockFocus) {
      focus.dispose();
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
