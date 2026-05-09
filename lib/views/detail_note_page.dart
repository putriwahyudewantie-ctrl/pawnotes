import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note_model.dart';
import 'add_note_page.dart';

class DetailNotePage extends StatelessWidget {
  final Note note;
  final MaterialColor color;

  const DetailNotePage({super.key, required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color[100],
        elevation: 0,
        title: const Text("Detail Catatan", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 28),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: note.id,
              child: Material(
                color: Colors.transparent,
                child: Text(
                  note.title,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(note.date),
              style: TextStyle(color: color[700], fontWeight: FontWeight.w500),
            ),
            const Divider(height: 40),
            Text(
              note.content,
              style: const TextStyle(fontSize: 18, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
