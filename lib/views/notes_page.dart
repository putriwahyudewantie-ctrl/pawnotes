import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/note_model.dart';
import '../view_models/note_view_model.dart';
import 'add_note_page.dart';
import 'detail_note_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  int _tabIndex = 0;
  String _selectedFolder = 'Semua';
  bool _isAppLocked = false;
  bool _isCheckingAppLock = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppLock();
  }

  Future<void> _loadAppLock() async {
    final model = context.read<NoteViewModel>();
    await model.initialized;
    if (!mounted) return;
    setState(() {
      _isAppLocked = model.isAppLockEnabled;
      _isCheckingAppLock = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    final model = context.read<NoteViewModel>();
    if (!model.isAppLockEnabled) return;
    model.lockPrivateVault();
    if (mounted) setState(() => _isAppLocked = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NoteViewModel>();
    final color = model.themeColor;
    final notes = _visibleNotes(model);
    final isPrivateTab = _tabIndex == 2;
    final isArchiveTab = _tabIndex == 1;

    if (_isCheckingAppLock) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAppLocked) return _appLockScreen(model);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color,
              child: const Icon(Icons.pets_rounded, color: Colors.white),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PawNotes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                Text(
                  'catatan kecil, ide besar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cari catatan',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            tooltip: 'Tampilan dan tema',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showAppearance(model),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_tabIndex == 0) _buildFolderFilters(model, color),
          Expanded(
            child: model.isLoading
                ? const Center(child: CircularProgressIndicator())
                : isPrivateTab && !model.isPrivateUnlocked
                ? _privateGate(color, model)
                : notes.isEmpty
                ? _emptyState(color, model.searchQuery)
                : RefreshIndicator(
                    onRefresh: model.loadNotes,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 900
                            ? 2
                            : 1;
                        final cardHeight = constraints.maxWidth < 400
                            ? 250.0
                            : 220.0;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: cardHeight,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: notes.length,
                          itemBuilder: (context, index) => _noteCard(
                            context,
                            model,
                            notes[index],
                            color,
                            isArchiveTab,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      drawer: _buildDrawer(model),
      floatingActionButton: _tabIndex == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createNote(model, color, isPrivateTab),
              icon: const Icon(Icons.add_rounded),
              label: Text(isPrivateTab ? 'Catatan privat' : 'Catatan baru'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Catatan',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive_rounded),
            label: 'Arsip',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: 'Pribadi',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(NoteViewModel model) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: model.themeColor,
                    child: const Icon(Icons.pets_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PawNotes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(
              icon: Icons.palette_outlined,
              title: 'Themes',
              onTap: () {
                Navigator.pop(context);
                _showAppearance(model);
              },
            ),
            _drawerItem(
              icon: Icons.shield_outlined,
              title: 'Privacy',
              onTap: () {
                Navigator.pop(context);
                _selectTab(2);
              },
            ),
            _drawerItem(
              icon: Icons.backup_outlined,
              title: 'Backup & restore',
              onTap: () {
                Navigator.pop(context);
                _showBackupDialog(model);
              },
            ),
            _drawerItem(
              icon: Icons.import_export_rounded,
              title: 'Import & Export',
              onTap: () {
                Navigator.pop(context);
                _showBackupDialog(model);
              },
            ),
            _drawerItem(
              icon: Icons.dashboard_customize_outlined,
              title: 'Templates',
              onTap: () {
                Navigator.pop(context);
                _showTemplates(model);
              },
            ),
            _drawerItem(
              icon: Icons.menu_book_outlined,
              title: 'Panduan penggunaan',
              onTap: () {
                Navigator.pop(context);
                _showGuide();
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            _drawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                _showSettings(model);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);

  Widget _appLockScreen(NoteViewModel model) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: model.themeColor,
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'PawNotes terkunci',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan PIN atau kata sandi aplikasi untuk melanjutkan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _unlockApp,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Buka aplikasi'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jika lupa, aplikasi tidak dapat dibuka kembali. Kunci aplikasi membatasi akses ke layar, tetapi tidak mengenkripsi catatan umum.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlockApp() async {
    final model = context.read<NoteViewModel>();
    final credential = await _privateCredentialDialog(
      setup: false,
      credentialType: model.appLockCredentialType,
      credentialLabel: 'aplikasi',
    );
    if (!mounted || credential == null) return;
    try {
      if (await model.verifyAppLock(credential.credential)) {
        setState(() => _isAppLocked = false);
      } else {
        _showMessage('PIN atau kata sandi aplikasi salah.');
      }
    } catch (error) {
      _showMessage('Aplikasi gagal dibuka: $error');
    }
  }

  Future<void> _showSettings(NoteViewModel model) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pengaturan keamanan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kunci aplikasi'),
                subtitle: Text(
                  model.isAppLockEnabled
                      ? 'Aktif: ${model.appLockCredentialType == 'pin' ? 'PIN' : 'kata sandi'}'
                      : 'Opsional, kunci saat PawNotes ditinggalkan',
                ),
                value: model.isAppLockEnabled,
                onChanged: (enabled) async {
                  if (enabled) {
                    final credential = await _privateCredentialDialog(
                      setup: true,
                      credentialType: null,
                      credentialLabel: 'aplikasi',
                      warningText:
                          'Tidak ada reset. Jika lupa, aplikasi tidak dapat dibuka.',
                    );
                    if (!mounted || credential == null) return;
                    try {
                      await model.configureAppLock(
                        credential.credential,
                        isPin: credential.type == 'pin',
                      );
                      setDialogState(() {});
                      _showMessage('Kunci aplikasi berhasil diaktifkan.');
                    } catch (error) {
                      _showMessage('Kunci aplikasi gagal diaktifkan: $error');
                    }
                    return;
                  }

                  final confirmed = await showDialog<bool>(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: const Text('Matikan kunci aplikasi?'),
                      content: const Text(
                        'PawNotes tidak akan meminta PIN atau kata sandi saat dibuka kembali.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Matikan'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await model.disableAppLock();
                  if (mounted) setDialogState(() {});
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Kunci aplikasi berbeda dari folder Pribadi. Catatan umum tidak dienkripsi oleh fitur ini.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cara menggunakan PawNotes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _guideStep(
                  '1',
                  'Buat catatan',
                  'Tekan tombol + lalu tulis judul dan isi. Catatan tersimpan otomatis.',
                ),
                _guideStep(
                  '2',
                  'Atur catatan',
                  'Gunakan folder, arsip, pencarian, dan menu titik pada kartu catatan.',
                ),
                _guideStep(
                  '3',
                  'Checklist lucu',
                  'Tekan emoji untuk menambah checklist, atau panah di sebelahnya untuk memilih hewan, bulan, bintang, atau bunga.',
                ),
                _guideStep(
                  '4',
                  'Lampiran dan pengingat',
                  'Toolbar catatan menyediakan foto, file, tanggal, pengingat, dan rekaman suara.',
                ),
                _guideStep(
                  '5',
                  'Tema',
                  'Pilih Themes untuk mengganti warna, mode gelap, font, dan gambar latar catatan.',
                ),
                _guideStep(
                  '6',
                  'Privasi',
                  'Folder Pribadi terenkripsi dengan PIN/kata sandi. Kunci aplikasi opsional ada di Settings.',
                ),
                _guideStep(
                  '7',
                  'Backup',
                  'Backup teks catatan umum dapat diekspor sebagai JSON. Media dan catatan Pribadi tidak disertakan.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _guideStep(String number, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 14, child: Text(number)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _showBackupDialog(NoteViewModel model) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup & restore'),
        content: const Text(
          'Backup mencakup catatan umum dalam format JSON. Foto, file lampiran, dan catatan Pribadi tidak disertakan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'import'),
            child: const Text('Pulihkan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'export'),
            child: const Text('Buat backup'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'export') {
      await _exportBackup(model);
    } else {
      await _importBackup(model);
    }
  }

  Future<void> _exportBackup(NoteViewModel model) async {
    try {
      final notes = model.notes.where((note) => !note.isPrivate).map((note) {
        final map = Map<String, dynamic>.from(note.toMap())
          ..['imageUrl'] = null
          ..['attachments'] = <String>[];
        return map;
      }).toList();
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'pawnotes-backup',
            'version': 1,
            'notes': notes,
          }),
        ),
      );
      final file = await FilePicker.saveFile(
        fileName: 'pawnotes-backup.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Simpan backup PawNotes',
      );
      if (file != null && mounted) _showMessage('Backup berhasil disimpan.');
    } catch (error) {
      _showMessage('Backup gagal dibuat: $error');
    }
  }

  Future<void> _importBackup(NoteViewModel model) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result.isEmpty) return;
      final bytes = await result.first.readAsBytes();

      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (data['format'] != 'pawnotes-backup' ||
          data['version'] != 1 ||
          data['notes'] is! List) {
        _showMessage('Format backup PawNotes tidak valid.');
        return;
      }
      final importedNotes = (data['notes'] as List)
          .map((note) => Note.fromMap(Map<String, dynamic>.from(note as Map)))
          .toList();
      if (importedNotes.any((note) => note.isPrivate)) {
        _showMessage('Backup tidak boleh berisi catatan Pribadi.');
        return;
      }
      for (final note in importedNotes) {
        note.imageUrl = null;
        note.attachments = [];
        await model.saveDraft(note);
      }
      if (mounted) {
        _showMessage('${importedNotes.length} catatan berhasil dipulihkan.');
      }
    } catch (error) {
      _showMessage('Backup gagal dipulihkan: $error');
    }
  }

  Future<void> _showTemplates(NoteViewModel model) async {
    const templates = <({String title, String content, IconData icon})>[
      (
        title: 'Daftar tugas',
        content: 'Prioritas hari ini:\nHal yang sudah selesai:\nCatatan:',
        icon: Icons.checklist_rounded,
      ),
      (
        title: 'Catatan kuliah',
        content: 'Mata pelajaran:\nTopik:\nPoin penting:\nPertanyaan:',
        icon: Icons.school_outlined,
      ),
      (
        title: 'Jurnal harian',
        content:
            'Hari ini aku merasa:\nHal baik hari ini:\nYang ingin kuingat:',
        icon: Icons.auto_awesome_outlined,
      ),
      (
        title: 'Rencana belanja',
        content: '🥬 Sayur:\n🥛 Kebutuhan rumah:\n🍓 Lainnya:',
        icon: Icons.shopping_basket_outlined,
      ),
      (
        title: 'Ide',
        content: 'Ide:\nKenapa menarik:\nLangkah berikutnya:',
        icon: Icons.lightbulb_outline,
      ),
    ];

    final template =
        await showModalBottomSheet<
          ({String title, String content, IconData icon})
        >(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Pilih template',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ...templates.map(
                  (item) => ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.title),
                    subtitle: Text(item.content.replaceAll('\n', ' • ')),
                    onTap: () => Navigator.pop(context, item),
                  ),
                ),
              ],
            ),
          ),
        );
    if (!mounted || template == null) return;
    try {
      await model.addNote(template.title, template.content);
      _showMessage('Template "${template.title}" ditambahkan.');
    } catch (error) {
      _showMessage('Template gagal ditambahkan: $error');
    }
  }

  List<Note> _visibleNotes(NoteViewModel model) {
    return model.filteredNotes.where((note) {
      if (_tabIndex == 1) return note.isArchived && !note.isPrivate;
      if (_tabIndex == 2) return note.isPrivate;
      return !note.isArchived &&
          !note.isPrivate &&
          (_selectedFolder == 'Semua' || note.folder == _selectedFolder);
    }).toList();
  }

  Widget _buildFolderFilters(NoteViewModel model, MaterialColor color) {
    final folders = ['Semua', ...model.folders];
    return SizedBox(
      height: 55,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return ChoiceChip(
            label: Text(folder),
            selected: _selectedFolder == folder,
            onSelected: (_) => setState(() => _selectedFolder = folder),
            selectedColor: color.withValues(alpha: 0.18),
          );
        },
      ),
    );
  }

  Widget _noteCard(
    BuildContext context,
    NoteViewModel model,
    Note note,
    MaterialColor color,
    bool isArchive,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openNote(context, model, note, color),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Aksi catatan',
                    onSelected: (action) =>
                        _handleNoteAction(context, model, note, action),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(
                            isArchive
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(
                            isArchive ? 'Keluarkan dari arsip' : 'Arsipkan',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'privacy',
                        child: ListTile(
                          leading: Icon(
                            note.isPrivate
                                ? Icons.lock_open
                                : Icons.lock_outline,
                          ),
                          title: Text(
                            note.isPrivate
                                ? 'Jadikan biasa'
                                : 'Pindah ke pribadi',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text('Hapus'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                note.content.isEmpty ? 'Catatan tanpa teks' : note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metadataChip(
                    Icons.schedule_rounded,
                    DateFormat('dd MMM, HH:mm').format(note.date),
                    color,
                  ),
                  _metadataChip(Icons.folder_outlined, note.folder, color),
                  if (note.isPrivate)
                    _metadataChip(Icons.lock_outline, 'Privat', color),
                  if (note.imageUrl != null)
                    _metadataChip(Icons.image_outlined, 'Foto', color),
                  if (note.attachments.isNotEmpty)
                    _metadataChip(
                      Icons.attach_file_rounded,
                      '${note.attachments.length} lampiran',
                      color,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadataChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color.shade800)),
        ],
      ),
    );
  }

  Widget _emptyState(MaterialColor color, String searchQuery) {
    final theme = Theme.of(context);
    final label = searchQuery.isNotEmpty
        ? 'Catatan tidak ditemukan'
        : switch (_tabIndex) {
            1 => 'Belum ada catatan di arsip',
            2 => 'Folder pribadi masih kosong',
            _ => 'Belum ada catatan nih',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.pets_rounded, size: 48, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ketuk tombol di bawah untuk mulai menulis.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privateGate(MaterialColor color, NoteViewModel model) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 72, color: color),
            const SizedBox(height: 16),
            const Text(
              'Folder pribadi terkunci',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan PIN atau kata sandi yang dibuat untuk PawNotes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _ensurePrivateAccess,
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(
                model.hasPrivateVault
                    ? 'Buka folder pribadi'
                    : 'Buat kunci pribadi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTab(int index) async {
    final model = context.read<NoteViewModel>();
    if (index == 2 && !await _ensurePrivateAccess()) return;
    if (!mounted) return;
    if (index != 2 && _tabIndex == 2) {
      model.lockPrivateVault();
    }
    setState(() => _tabIndex = index);
  }

  Future<bool> _ensurePrivateAccess() async {
    final model = context.read<NoteViewModel>();
    if (model.isPrivateUnlocked) return true;

    final setup = !model.hasPrivateVault;
    final credential = await _privateCredentialDialog(
      setup: setup,
      credentialType: model.privateCredentialType,
    );
    if (!mounted || credential == null) return false;

    try {
      if (setup) {
        await model.createPrivateVault(
          credential.credential,
          isPin: credential.type == 'pin',
        );
        return true;
      }
      final unlocked = await model.unlockPrivateVault(credential.credential);
      if (!unlocked) _showMessage('PIN atau kata sandi salah.');
      return unlocked;
    } catch (error) {
      _showMessage('Folder pribadi gagal dibuka: $error');
      return false;
    }
  }

  Future<({String credential, String type})?> _privateCredentialDialog({
    required bool setup,
    required String? credentialType,
    String credentialLabel = 'folder pribadi',
    String? warningText,
  }) async {
    var selectedType = credentialType ?? 'pin';
    final credentialController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<({String credential, String type})>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isPin = selectedType == 'pin';
          final credential = credentialController.text;
          final canSubmit = setup
              ? (isPin
                        ? RegExp(r'^\d{4}$').hasMatch(credential)
                        : credential.length >= 6) &&
                    confirmController.text == credential
              : credential.isNotEmpty;
          return AlertDialog(
            title: Text(
              setup ? 'Buat kunci $credentialLabel' : 'Buka $credentialLabel',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (setup) ...[
                    const Text('Pilih satu cara untuk mengunci catatan:'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'pin',
                          label: Text('PIN 4 angka'),
                          icon: Icon(Icons.pin_outlined),
                        ),
                        ButtonSegment(
                          value: 'password',
                          label: Text('Kata sandi'),
                          icon: Icon(Icons.password_outlined),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (selection) {
                        setDialogState(() {
                          selectedType = selection.first;
                          credentialController.clear();
                          confirmController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: credentialController,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: isPin
                        ? TextInputType.number
                        : TextInputType.visiblePassword,
                    inputFormatters: isPin
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ]
                        : [LengthLimitingTextInputFormatter(64)],
                    decoration: InputDecoration(
                      labelText: isPin ? 'PIN (4 angka)' : 'Kata sandi',
                      helperText: setup && !isPin ? 'Minimal 6 karakter' : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) {
                      if (canSubmit) {
                        Navigator.pop(dialogContext, (
                          credential: credentialController.text,
                          type: selectedType,
                        ));
                      }
                    },
                  ),
                  if (setup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: isPin
                          ? TextInputType.number
                          : TextInputType.visiblePassword,
                      inputFormatters: isPin
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ]
                          : [LengthLimitingTextInputFormatter(64)],
                      decoration: InputDecoration(
                        labelText: 'Ulangi ${isPin ? 'PIN' : 'kata sandi'}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      warningText ??
                          'Tidak ada fitur reset. Jika lupa, catatan pribadi tidak dapat dipulihkan.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final validCredential = isPin
                      ? RegExp(r'^\d{4}$').hasMatch(credentialController.text)
                      : credentialController.text.length >= 6;
                  if (setup && !validCredential) {
                    setDialogState(() {
                      errorText = isPin
                          ? 'PIN harus tepat 4 angka.'
                          : 'Kata sandi minimal 6 karakter.';
                    });
                    return;
                  }
                  if (setup &&
                      confirmController.text != credentialController.text) {
                    setDialogState(() => errorText = 'Konfirmasi tidak sama.');
                    return;
                  }
                  if (credentialController.text.isEmpty) {
                    setDialogState(
                      () => errorText = 'Masukkan PIN atau kata sandi.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    credential: credentialController.text,
                    type: selectedType,
                  ));
                },
                child: Text(setup ? 'Buat kunci' : 'Buka'),
              ),
            ],
          );
        },
      ),
    );

    // Beri waktu sampai animasi penutupan dialog selesai
    // sebelum controller dihancurkan.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    credentialController.dispose();
    confirmController.dispose();
  return result;
}

  Future<void> _createNote(
    NoteViewModel model,
    MaterialColor color,
    bool makePrivate,
  ) async {
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNotePage(
          color: color,
          viewModel: model,
          onRequirePrivateAccess: _ensurePrivateAccess,
          folders: model.folders,
          initialFolder: _selectedFolder == 'Semua' ? 'Umum' : _selectedFolder,
          makePrivate: makePrivate,
        ),
      ),
    );
  }

  Future<void> _openNote(
    BuildContext context,
    NoteViewModel model,
    Note note,
    MaterialColor color,
  ) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailNotePage(
          note: note,
          color: color,
          folders: model.folders,
          viewModel: model,
          onRequirePrivateAccess: _ensurePrivateAccess,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final reminderWarning = await model.updateNote(
      note.id,
      result['title'] as String,
      result['content'] as String,
      reminderDate: result['reminderDate'] as DateTime?,
      selectedDate: result['selectedDate'] as DateTime?,
      imageUrl: result['imageUrl'] as String?,
      folder: result['folder'] as String?,
      isPrivate: result['isPrivate'] as bool?,
      attachments: List<String>.from(result['attachments'] as List? ?? []),
    );
    if (reminderWarning != null) _showMessage(reminderWarning);
  }

  Future<void> _handleNoteAction(
    BuildContext context,
    NoteViewModel model,
    Note note,
    String action,
  ) async {
    if (action == 'archive') {
      await model.toggleArchived(note.id);
    } else if (action == 'privacy') {
      if (!note.isPrivate && !await _ensurePrivateAccess()) return;
      final reminderWarning = await model.togglePrivacy(note.id);
      if (reminderWarning != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reminderWarning)));
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus catatan?'),
          content: const Text('Catatan ini akan dihapus dari perangkat.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (confirmed == true) await model.deleteNote(note.id);
    }
  }

  Future<void> _showSearch(BuildContext context) async {
      final model = context.read<NoteViewModel>();
      final note = await showSearch<Note?>(
        context: context,
        delegate: _NoteSearchDelegate(model),
      );
      if (!context.mounted) return;
      model.setSearchQuery('');
      if (note != null) await _openNote(context, model, note, model.themeColor);
    }

  Future<void> _showAppearance(NoteViewModel model) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tampilan PawNotes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode gelap'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: model.isDarkMode,
                    onChanged: (value) async {
                      await model.updateDarkMode(value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gambar latar tema',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (model.themeImagePath case final String imagePath)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 125,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _themePreviewImage(imagePath),
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                            const Center(
                              child: Text(
                                'Pratinjau gambar tema',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await _chooseThemeImage(model);
                            if (selected) setSheetState(() {});
                          },
                          icon: const Icon(Icons.wallpaper_outlined),
                          label: const Text('Pilih tema gambar'),
                        ),
                      ),
                      if (model.themeImagePath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Hapus gambar tema',
                          onPressed: () async {
                            await model.updateThemeImage(null);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Warna aksen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: model.availableColors.map((color) {
                      return InkWell(
                        onTap: () async {
                          await model.updateTheme(color);
                          setSheetState(() {});
                        },
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 21,
                          backgroundColor: color,
                          child: model.themeColor == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: model.fontFamily ?? 'default',
                    decoration: const InputDecoration(
                      labelText: 'Font tulisan',
                      prefixIcon: Icon(Icons.text_fields_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'default',
                        child: Text('Default'),
                      ),
                      DropdownMenuItem(value: 'serif', child: Text('Serif')),
                      DropdownMenuItem(
                        value: 'monospace',
                        child: Text('Monospace'),
                      ),
                      DropdownMenuItem(
                        value: 'sans-serif-condensed',
                        child: Text('Sans Condensed'),
                      ),
                      DropdownMenuItem(
                        value: 'sans-serif-light',
                        child: Text('Sans Light'),
                      ),
                      DropdownMenuItem(value: 'casual', child: Text('Casual')),
                    ],
                    onChanged: (value) =>
                        model.updateFont(value == 'default' ? null : value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pilih salah satu tema gambar yang tersedia di aplikasi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _chooseThemeImage(NoteViewModel model) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final themes =
          manifest
              .listAssets()
              .where(
                (asset) => RegExp(
                  r'^assets/themes/\d+\.(jpg|jpeg|png|webp|gif|bmp)$',
                  caseSensitive: false,
                ).hasMatch(asset),
              )
              .toList()
            ..sort((first, second) {
              final firstNumber = int.parse(p.basenameWithoutExtension(first));
              final secondNumber = int.parse(
                p.basenameWithoutExtension(second),
              );
              return firstNumber.compareTo(secondNumber);
            });
      if (!mounted) return false;
      if (themes.isEmpty) {
        _showMessage(
          'Belum ada tema gambar. Tambahkan gambar ke folder assets/themes/.',
        );
        return false;
      }

      final selectedTheme = await showDialog<String>(
        context: context,
        builder: (context) {
          final screenSize = MediaQuery.sizeOf(context);
          final crossAxisCount = screenSize.width >= 1100
              ? 5
              : screenSize.width >= 700
              ? 4
              : 3;
          return Dialog(
            child: SizedBox(
              width: screenSize.width >= 1100
                  ? 720
                  : (screenSize.width - 48).clamp(280.0, 620.0),
              height: (screenSize.height * 0.72).clamp(320.0, 620.0),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Pilih tema gambar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        itemCount: themes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.88,
                        ),
                        itemBuilder: (context, index) {
                          final asset = themes[index];
                          final selected = model.themeImagePath == asset;
                          final themeNumber = int.parse(
                            p.basenameWithoutExtension(asset),
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context, asset),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.asset(
                                          asset,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (selected)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tema $themeNumber',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted || selectedTheme == null) return false;
      await model.updateThemeImage(selectedTheme);
      return true;
    } catch (error) {
      if (mounted) _showMessage('Tema gambar gagal dimuat: $error');
      return false;
    }
  }

  Widget _themePreviewImage(String path) {
    final ImageProvider<Object> imageProvider;
    if (path.startsWith('assets/')) {
      imageProvider = AssetImage(path);
    } else if (path.startsWith('data:image/')) {
      imageProvider = MemoryImage(
        base64Decode(path.substring(path.indexOf(',') + 1)),
      );
    } else if (kIsWeb ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      imageProvider = NetworkImage(path);
    } else {
      imageProvider = FileImage(File(path));
    }
    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 36)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoteSearchDelegate extends SearchDelegate<Note?> {
  _NoteSearchDelegate(this.model);

  final NoteViewModel model;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      onPressed: () {
        query = '';
        model.setSearchQuery('');
      },
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = model.filteredNotes
        .where(
          (note) =>
              !note.isArchived &&
              !note.isPrivate &&
              (note.title.toLowerCase().contains(query.toLowerCase()) ||
                  note.content.toLowerCase().contains(query.toLowerCase())),
        )
        .take(8)
        .toList();
    if (query.isEmpty) return const SizedBox.shrink();
    return ListView(
      children: results
          .map(
            (note) => ListTile(
              leading: Icon(
                note.isPrivate ? Icons.lock_outline : Icons.note_alt_outlined,
              ),
              title: Text(note.title),
              subtitle: Text(
                note.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => close(context, note),
            ),
          )
          .toList(),
    );
  }
}
