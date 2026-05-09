import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'view_models/note_view_model.dart';
import 'views/notes_page.dart';

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
      builder: (context, child) {
        return Container(
          color: const Color(0xFFF0F0F0), // Warna background di luar area HP
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450), // Batas lebar layar HP
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      home: const NotesPage(),
    );
  }
}