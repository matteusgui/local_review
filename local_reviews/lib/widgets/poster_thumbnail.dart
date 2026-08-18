import 'dart:io';

import 'package:flutter/material.dart';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path),
        width: size,
        height: size * 1.5,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
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
