import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NoteThemeBackground extends StatelessWidget {
  const NoteThemeBackground({
    super.key,
    required this.imagePath,
    required this.isDarkMode,
    required this.child,
  });

  final String? imagePath;
  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseColor),
        if (imagePath case final String path) _image(path),
        if (imagePath != null)
          ColoredBox(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.36 : 0.16),
          ),
        child,
      ],
    );
  }

  Widget _image(String path) {
    final ImageProvider<Object> provider;
    if (path.startsWith('assets/')) {
      provider = AssetImage(path);
    } else if (path.startsWith('data:image/')) {
      try {
        provider = MemoryImage(
          base64Decode(path.substring(path.indexOf(',') + 1)),
        );
      } on FormatException {
        return const SizedBox.shrink();
      }
    } else if (kIsWeb ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      provider = NetworkImage(path);
    } else {
      provider = FileImage(File(path));
    }

    return Image(
      image: provider,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
