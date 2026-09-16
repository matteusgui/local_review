import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_repositories.dart';

class PosterThumbnail extends StatelessWidget {
  const PosterThumbnail({super.key, this.posterPath, this.size = 56});

  final String? posterPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = posterPath;
    if (path == null || !File(path).existsSync()) {
      return _placeholder(context);
    }
    final posterStorageService = AppRepositories.of(context).posterStorageService;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: FutureBuilder<Uint8List>(
        future: posterStorageService.loadDecrypted(path),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _placeholder(context);
          }
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size * 1.5,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.movie_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
