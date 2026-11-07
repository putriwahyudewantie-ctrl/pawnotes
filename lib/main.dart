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
    final viewModel = context.watch<NoteViewModel>();
    final themeColor = viewModel.themeColor;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PawNotes',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: themeColor,
        fontFamily: viewModel.fontFamily,
        brightness: viewModel.isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: viewModel.isDarkMode ? Brightness.dark : Brightness.light,
        ).surface,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: themeColor,
        fontFamily: viewModel.fontFamily,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: Brightness.dark,
        ).surface,
      ),
      themeMode: viewModel.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth >= 1200
                ? 1120.0
                : constraints.maxWidth;
            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Container(
                  width: contentWidth,
                  constraints: const BoxConstraints(maxWidth: 1120),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
        );
      },
      home: const NotesPage(),
    );
  }
}
