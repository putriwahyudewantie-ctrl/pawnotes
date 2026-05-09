import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../view_models/note_view_model.dart';
import '../models/note_model.dart';
import 'add_note_page.dart';
import 'detail_note_page.dart';

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
          actions: [],
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
                    viewModel.addNote(result["title"], result["content"]);
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Catatan Baru",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const Icon(Icons.pets, size: 100, color: Colors.grey), // Menggunakan icon standar untuk semua platform

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
                    viewModel.updateNote(note.id, result["title"], result["content"]);
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
