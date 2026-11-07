import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
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
  bool _isRecording = false;
  bool _hasSavedDraft = false;
  String? _lastReminderWarning;
  Timer? _autoSaveTimer;
  Future<String?>? _pendingSave;
  late final String _draftId;
  late final DateTime _draftDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftId =
        widget.oldNote?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _draftDate = widget.oldNote?.date ?? DateTime.now();
    _hasSavedDraft = widget.oldNote != null;
    titleController.addListener(_scheduleAutoSave);
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
  }

  void _insertBlock({
    required String type,
    String text = "",
    String? marker,
    int? index,
  }) {
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
      _scheduleAutoSave();
    });
    setState(() {});
  }

  void _removeBlock(int index) {
    if (blocks.length > 1) {
      setState(() {
        blocks.removeAt(index);
        _blockControllers[index].dispose();
        _blockControllers.removeAt(index);
        _blockFocus[index].dispose();
        _blockFocus.removeAt(index);
      });
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
    _hasSavedDraft = false;
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
      _hasSavedDraft = true;
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.oldNote != null ? "Edit Catatan" : "Catatan Baru",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _hasSavedDraft ? 'Tersimpan otomatis' : 'Simpan otomatis aktif',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                _saveAndPop(), // Trigger auto-save saat tekan tombol back
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // Sudut lebih membulat
              ),
              elevation: 0,
            ),
            onPressed: _saveAndPop,
            child: const Text(
              "Simpan Catatan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        body: NoteThemeBackground(
          imagePath: widget.viewModel.themeImagePath,
          isDarkMode: widget.viewModel.isDarkMode,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.42),
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
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.58),
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
                          if (_attachments.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                children: _attachments
                                    .map(
                                      (path) => InputChip(
                                        avatar: Icon(
                                          _isImagePath(path)
                                              ? Icons.image_outlined
                                              : path.toLowerCase().endsWith(
                                                  '.m4a',
                                                )
                                              ? Icons.mic
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
                                          setState(
                                            () => _attachments.remove(path),
                                          );
                                          _scheduleAutoSave();
                                        },
                                      ),
                                    )
                                    .toList(),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.42),
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
                                  setState(() => _selectedReminderDate = null);
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
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: blocks.length,
                      itemBuilder: (_, i) {
                        final b = blocks[i];
                        final c = _blockControllers[i];
                        final f = _blockFocus[i];

                        if (b["type"] == "check") {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.46),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: b["done"] == true
                                        ? 'Tandai belum selesai'
                                        : 'Tandai selesai',
                                    onPressed: () {
                                      setState(
                                        () => b["done"] = !(b["done"] == true),
                                      );
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
                                      textInputAction: TextInputAction.newline,
                                      onChanged: (text) {
                                        final lines = text.split('\n');
                                        if (lines.length > 1) {
                                          c.value = TextEditingValue(
                                            text: lines.first,
                                            selection: TextSelection.collapsed(
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
                                                    _blockFocus.length >
                                                        i + 1) {
                                                  _blockFocus[i + 1]
                                                      .requestFocus();
                                                }
                                              });
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
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
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.46),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        );
                      },
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
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;
      final savedPath = await _savePickedFile(files.first);
      if (!mounted) return;
      setState(() => _selectedImageUrl = savedPath);
      _scheduleAutoSave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gambar gagal ditambahkan: $error')),
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
      if (_isRecording) {
        final recordedPath = await _recorder.stop();
        if (mounted) {
          setState(() {
            if (recordedPath != null) _attachments.add(recordedPath);
            _isRecording = false;
          });
          _scheduleAutoSave();
        }
        return;
      }

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
      if (mounted) setState(() => _isRecording = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rekaman gagal: $error')));
      }
    }
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
              onPressed: () =>
                  _insertBlock(type: "check", marker: _checklistMarker),
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
              icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_none),
              color: _isRecording ? Colors.red : null,
              onPressed: _toggleRecording,
              tooltip: _isRecording ? 'Stop Rekaman' : 'Rekam Suara',
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
    titleController.removeListener(_scheduleAutoSave);
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
