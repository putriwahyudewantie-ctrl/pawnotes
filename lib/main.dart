import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Tambahkan ini
import 'view_models/note_view_model.dart';
import 'models/note_model.dart';
import 'dart:io';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NoteViewModel(),
      child: const PawNotesApp(),
    ),
  );
}

class PawNotesApp extends StatelessWidget {
  const PawNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<NoteViewModel>().themeColor;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PawNotes',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: themeColor,
        fontFamily: 'Inter',
      ),
      home: const NotesPage(),
    );
  }
}

// ======================== NOTES PAGE =============================

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int currentPage = 0;
  bool showThemeOptions = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NoteViewModel>();
    final themeColor = viewModel.themeColor;

    return GestureDetector(
      onTap: () {
        if (showThemeOptions) {
          setState(() {
            showThemeOptions = false;
            currentPage = 0;
          });
        }
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: themeColor[100],
          centerTitle: false,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "PAWNOTES",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: themeColor[800]),
              onPressed: () {
                // Focus search or show/hide search bar
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (currentPage == 0) _buildSearchBar(viewModel, themeColor),
                Expanded(
                  child: currentPage == 0 ? buildHome(viewModel, themeColor) : Container(),
                ),
              ],
            ),
            if (showThemeOptions) _buildThemePicker(viewModel),
          ],
        ),
        floatingActionButton: currentPage == 0
            ? FloatingActionButton.extended(
                backgroundColor: themeColor,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddNotePage(color: themeColor),
                    ),
                  );

                  if (result != null && context.mounted) {
                    viewModel.addNote(
                    result["title"],
                    result["content"],
                    result["background"],
                  );
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Catatan Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
        bottomNavigationBar: _buildBottomNav(themeColor),
      ),
    );
  }

  Widget _buildSearchBar(NoteViewModel viewModel, MaterialColor themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: themeColor[100],
      child: TextField(
        controller: _searchController,
        onChanged: (v) => viewModel.setSearchQuery(v),
        decoration: InputDecoration(
          hintText: "Cari catatan...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildThemePicker(NoteViewModel viewModel) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Pilih Tema Favorit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _themeCircle(viewModel, Colors.pink),
                _themeCircle(viewModel, Colors.blue),
                _themeCircle(viewModel, Colors.green),
                _themeCircle(viewModel, Colors.orange),
                _themeCircle(viewModel, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeCircle(NoteViewModel viewModel, MaterialColor color) {
    final isSelected = viewModel.themeColor == color;
    return GestureDetector(
      onTap: () {
        viewModel.updateTheme(color);
        setState(() {
          showThemeOptions = false;
          currentPage = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: CircleAvatar(radius: 18, backgroundColor: color),
      ),
    );
  }

  Widget _buildBottomNav(MaterialColor themeColor) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        currentIndex: currentPage,
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          setState(() {
            currentPage = index;
            showThemeOptions = index == 1;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.palette_rounded), label: "Tema"),
        ],
      ),
    );
  }

  Widget buildHome(NoteViewModel viewModel, MaterialColor themeColor) {
    final notes = viewModel.filteredNotes;

    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Perbaikan di sini: Cek apakah kIsWeb atau bukan
            if (kIsWeb)
              Icon(Icons.pets, size: 100, color: themeColor[200])
            else
              Image.file(
                File("C:/Users/Lenovo/.gemini/antigravity/brain/b9b34c97-3690-4b85-9171-cd47704b9779/cute_paw_empty_state_1777311702584.png"),
                height: 200,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.pets, size: 100, color: themeColor[200]),
              ),
            const SizedBox(height: 16),
            Text(
              viewModel.searchQuery.isEmpty ? "Belum ada catatan nih..." : "Catatan tidak ditemukan",
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            if (viewModel.searchQuery.isEmpty)
              TextButton(
                onPressed: () => viewModel.fetchTemplates(),
                child: Text("Ambil Template dari API", style: TextStyle(color: themeColor)),
              )
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (_, i) {
        final note = notes[i];
        return Hero(
          tag: note.id,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: themeColor[300]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM, HH:mm').format(note.date),
                          style: TextStyle(fontSize: 12, color: themeColor[300], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(viewModel, note),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailNotePage(note: note, color: themeColor),
                    ),
                  );

                  if (result != null && context.mounted) {
                    viewModel.updateNote(note.id, result["title"], result["content"], result["background"]);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(NoteViewModel viewModel, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Catatan?"),
        content: const Text("Catatan yang dihapus tidak bisa dikembalikan lho."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              viewModel.deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ======================== DETAIL NOTE PAGE =============================
class DetailNotePage extends StatelessWidget {
  final Note note;
  final MaterialColor color;

  const DetailNotePage({
    super.key,
    required this.note,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: note.background != null
            ? DecorationImage(
                image: AssetImage(note.background!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,

        appBar: AppBar(
          backgroundColor: color[100],
          elevation: 0,
          title: const Text("Detail Catatan"),

          // 🔥 INI YANG KAMU BUTUH (TOMBOL EDIT)
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddNotePage(
                      color: color,
                      oldNote: note, // kirim data lama
                    ),
                  ),
                );

                // 🔥 kirim balik hasil edit ke halaman sebelumnya
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
          ],
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(note.content),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================== ADD NOTE PAGE =============================

class AddNotePage extends StatefulWidget {
  final MaterialColor color;
  final Note? oldNote;

  const AddNotePage({super.key, required this.color, this.oldNote});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {

  String? selectedBackground;

  final List<String> wallpapers = [
    'assets/wallpaper1.jpg',
    'assets/wallpaper2.jpg',
    'assets/wallpaper3.jpg',
    'assets/wallpaper4.jpg',
    'assets/wallpaper5.jpg',
  ];

  final TextEditingController titleController = TextEditingController();
  List<Map<String, dynamic>> blocks = [];
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocus = [];

  @override
  void initState() {
    super.initState();
    if (widget.oldNote != null) {
      titleController.text = widget.oldNote!.title;
      selectedBackground = widget.oldNote!.background; // penting
      _loadOldContent(widget.oldNote!.content);
    } else {
      _insertBlock(type: "text");
    }
  }

  void _loadOldContent(String content) {
    for (var line in content.split("\n")) {
      if (line.startsWith("☑") || line.startsWith("☐")) {
        _insertBlock(type: "check", text: line.substring(2));
        blocks.last["done"] = line.startsWith("☑");
      } else {
        _insertBlock(type: "text", text: line);
      }
    }
  }

  void _insertBlock({required String type, String text = ""}) {
    final block = {"type": type, "text": text, "done": false};
    final controller = TextEditingController(text: text);
    final focus = FocusNode();

    blocks.add(block);
    _blockControllers.add(controller);
    _blockFocus.add(focus);

    controller.addListener(() {
      block["text"] = controller.text;
    });

    setState(() {});
  }

  String _blocksToString() {
    final list = <String>[];
    for (var b in blocks) {
      if (b["type"] == "check") {
        final done = b["done"] == true ? "☑" : "☐";
        list.add("$done ${b["text"]}");
      } else {
        list.add(b["text"]);
      }
    }
    return list.join("\n");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: selectedBackground != null
            ? DecorationImage(
                image: AssetImage(selectedBackground!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // WAJIB

        appBar: AppBar(
          backgroundColor: widget.color[100],
          elevation: 0,
          title: Text(
            widget.oldNote != null ? "Edit Catatan" : "Catatan Baru",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(context, {
                "title": titleController.text,
                "content": _blocksToString(),
                "background": selectedBackground, // penting
              });
            },
            child: const Text(
              "Simpan Catatan",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: titleController,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Judul catatan...",
                  border: InputBorder.none,
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
                    return Row(
                      children: [
                        Checkbox(
                          value: b["done"] == true,
                          onChanged: (val) =>
                              setState(() => b["done"] = val),
                        ),
                        Expanded(
                          child: TextField(
                            controller: c,
                            focusNode: f,
                            decoration: const InputDecoration(
                                border: InputBorder.none),
                          ),
                        )
                      ],
                    );
                  }

                  return TextField(
                    controller: c,
                    focusNode: f,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Mulai menulis...",
                    ),
                  );
                },
              ),
            ),

            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  // ================= TOOLBAR =================
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.check_box_outlined),
            onPressed: () => _insertBlock(type: "check"),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text("Jam: ${time.format(context)}")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          DateFormat('dd MMM yyyy').format(date))),
                );
              }
            },
          ),
         IconButton(
            icon: const Icon(Icons.brush),
            onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _buildWallpaperPicker(),
            );
          },
        ),

        ],
      ),
    );
  }

  // ================= PICKER =================
  Widget _buildWallpaperPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: GridView.builder(
        itemCount: wallpapers.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemBuilder: (context, index) {
          final bg = wallpapers[index];

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedBackground = bg;
              });
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedBackground == bg
                      ? Colors.pink
                      : Colors.transparent,
                  width: 2,
                ),
                image: DecorationImage(
                  image: AssetImage(bg),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
