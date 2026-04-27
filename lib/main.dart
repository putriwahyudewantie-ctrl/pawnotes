import 'package:flutter/material.dart';

void main() {
  runApp(const PawNotesApp());
}

class PawNotesApp extends StatefulWidget {
  const PawNotesApp({super.key});

  @override
  State<PawNotesApp> createState() => _PawNotesAppState();
}

class _PawNotesAppState extends State<PawNotesApp> {
  MaterialColor themeColor = Colors.pink;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NotesPage(
        themeColor: themeColor,
        changeTheme: (newColor) {
          setState(() => themeColor = newColor);
        },
      ),
    );
  }
}

// ======================== NOTES PAGE =============================

class NotesPage extends StatefulWidget {
  final MaterialColor themeColor;
  final Function(MaterialColor) changeTheme;

  const NotesPage({
    super.key,
    required this.themeColor,
    required this.changeTheme,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Map<String, dynamic>> notes = [];
  int currentPage = 0;

  bool showThemeOptions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (showThemeOptions) {
          setState(() {
            showThemeOptions = false;
            currentPage = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: widget.themeColor[100],
          title: const Row(
            children: [
              Icon(Icons.pets, color: Colors.black),
              SizedBox(width: 5),
              Text(
                "PAWNOTES",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        body: Stack(
          children: [
            currentPage == 0 ? buildHome() : Container(),

            if (showThemeOptions)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 70),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      themeCircle(Colors.pink),
                      themeCircle(Colors.blue),
                      themeCircle(Colors.green),
                      themeCircle(Colors.orange),
                      themeCircle(Colors.purple),
                    ],
                  ),
                ),
              ),
          ],
        ),

        floatingActionButton: currentPage == 0
            ? FloatingActionButton(
                backgroundColor: widget.themeColor,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddNotePage(color: widget.themeColor),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      notes.add(result);
                    });
                  }
                },
                child: const Icon(Icons.add),
              )
            : null,

        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: widget.themeColor[100],
          ),
          child: BottomNavigationBar(
            backgroundColor: widget.themeColor[100],
            elevation: 0,
            currentIndex: currentPage,
            selectedItemColor: widget.themeColor[700],
            unselectedItemColor: Colors.black54,
            onTap: (index) {
              setState(() {
                currentPage = index;
                showThemeOptions = index == 1;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.color_lens_rounded),
                label: "Tema",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget themeCircle(MaterialColor color) {
    return GestureDetector(
      onTap: () {
        widget.changeTheme(color);
        setState(() {
          showThemeOptions = false;
          currentPage = 0;
        });
      },
      child: CircleAvatar(radius: 18, backgroundColor: color),
    );
  }

  Widget buildHome() {
    return notes.isEmpty
        ? const Center(child: Text("Belum ada catatan"))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (_, i) {
              return GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetailNotePage(note: notes[i], color: widget.themeColor),
                    ),
                  );

                  if (result != null) {
                    setState(() => notes[i] = result);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.themeColor[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${i + 1}. ",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          notes[i]["title"] ?? "",
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}

// ======================== DETAIL NOTE PAGE =============================

class DetailNotePage extends StatelessWidget {
  final Map<String, dynamic> note;
  final MaterialColor color;

  const DetailNotePage({super.key, required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color[100],
        title: const Text("Detail Catatan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddNotePage(color: color, oldNote: note),
                ),
              );

              if (result != null) Navigator.pop(context, result);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          note["content"] ?? "",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// ======================== ADD NOTE PAGE =============================

class AddNotePage extends StatefulWidget {
  final MaterialColor color;
  final Map<String, dynamic>? oldNote;

  const AddNotePage({super.key, required this.color, this.oldNote});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final TextEditingController titleController = TextEditingController();

  List<Map<String, dynamic>> blocks = [];
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocus = [];

  @override
  void initState() {
    super.initState();

    if (widget.oldNote != null) {
      titleController.text = widget.oldNote!["title"] ?? "";
      _loadOldContent(widget.oldNote!["content"] ?? "");
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

  void addChecklistBlock() {
    _insertBlock(type: "check");
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

  // ===================== DIALOG =====================

  void _showSimpleDialog(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Oke"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.color[100],
        title: Text(widget.oldNote != null ? "Edit Catatan" : "Catatan Baru"),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: widget.color[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildBottomIcon(Icons.check_box, addChecklistBlock),
            buildBottomIcon(Icons.notifications, () {
              _showSimpleDialog("Pengaturan Notifikasi");
            }),
            buildBottomIcon(Icons.calendar_month, () {
              _showSimpleDialog("Pengaturan Kalender");
            }),
            buildBottomIcon(Icons.image, _showImageOptions)
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Judul catatan...",
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: blocks.length,
                itemBuilder: (_, i) {
                  final b = blocks[i];
                  final c = _blockControllers[i];
                  final f = _blockFocus[i];

                  if (b["type"] == "check") {
                    return Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              b["done"] = !(b["done"] == true);
                            });
                          },
                          child: Text(
                            b["done"] == true ? "☑" : "☐",
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: c,
                            focusNode: f,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        )
                      ],
                    );
                  }

                  return TextField(
                    controller: c,
                    focusNode: f,
                    maxLines: null,
                    decoration:
                        const InputDecoration(border: InputBorder.none),
                  );
                },
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  "title": titleController.text,
                  "content": _blocksToString(),
                });
              },
              child: const Text(
                "Simpan Catatan",
                style: TextStyle(color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _optionButton("Kamera", Icons.photo_camera, () {
                Navigator.pop(context);
              }),
              _optionButton("Album", Icons.photo, () {
                Navigator.pop(context);
              }),
              _optionButton("Coretan", Icons.brush, () {
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _optionButton(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 26),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      onTap: onTap,
    );
  }

  Widget buildBottomIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: widget.color[200],
        child: Icon(icon, color: Colors.black),
      ),
    );
  }
}