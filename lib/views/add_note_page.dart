import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../view_models/note_view_model.dart';

class AddNotePage extends StatefulWidget {
  final MaterialColor color;
  final Note? oldNote;

  const AddNotePage({super.key, required this.color, this.oldNote});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final TextEditingController titleController = TextEditingController();
  List<Map<String, dynamic>> blocks = [];
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocus = [];
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    if (widget.oldNote != null) {
      titleController.text = widget.oldNote!.title;
      _loadOldContent(widget.oldNote!.content);
    } else {
      _insertBlock(type: "text");
    }
  }

  void _loadOldContent(String content) {
    for (var line in content.split("\n")) {
      if (line.startsWith("☑") || line.startsWith("☐")) {
        _insertBlock(type: "check", text: line.length > 2 ? line.substring(2) : "");
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

  void _removeBlock(int index) {
    if (blocks.length > 1) {
      setState(() {
        blocks.removeAt(index);
        _blockControllers[index].dispose();
        _blockControllers.removeAt(index);
        _blockFocus[index].dispose();
        _blockFocus.removeAt(index);
      });
    }
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

  // Fungsi untuk menyimpan catatan secara otomatis atau manual
  void _saveAndPop() {
    if (_isSaved) return;
    
    final title = titleController.text.trim();
    final content = _blocksToString().trim();

    // Hanya simpan jika ada isi atau judul
    if (title.isNotEmpty || content.isNotEmpty) {
      _isSaved = true;
      Navigator.pop(context, {
        "title": title.isEmpty ? "Tanpa Judul" : title,
        "content": content,
      });
    } else {
      Navigator.pop(context);
    }
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: widget.color[100],
          elevation: 0,
          title: Text(widget.oldNote != null ? "Edit Catatan" : "Catatan Baru",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _saveAndPop(), // Trigger auto-save saat tekan tombol back
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _saveAndPop,
            child: const Text("Simpan Catatan",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: b["done"] == true,
                            activeColor: widget.color,
                            onChanged: (val) => setState(() => b["done"] = val),
                          ),
                          Expanded(
                            child: TextField(
                              controller: c,
                              focusNode: f,
                              textInputAction: TextInputAction.done,
                              onChanged: (text) {
                                if (text.endsWith("\n")) {
                                  c.text = text.replaceAll("\n", "");
                                  _insertBlock(type: "check");
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _blockFocus.last.requestFocus();
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () => _removeBlock(i),
                          ),
                        ],
                      ),
                    );
                  }
                  return TextField(
                    controller: c,
                    focusNode: f,
                    maxLines: null,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "Mulai menulis..."),
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

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.check_box_outlined),
            onPressed: () => _insertBlock(type: "check"),
            tooltip: "Tambah Checklist",
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {}, // Notifikasi implementation can be added later
            tooltip: "Pasang Pengingat",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () {},
            tooltip: "Pilih Tanggal",
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: () {},
            tooltip: "Tambah Gambar",
          ),
        ],
      ),
    );
  }
}
