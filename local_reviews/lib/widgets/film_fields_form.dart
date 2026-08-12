import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../services/poster_storage_service.dart';
import 'genre_multi_select.dart';
import 'poster_thumbnail.dart';

class FilmFieldsController {
  FilmFieldsController({
    String? initialTitle,
    int? initialYear,
    String? initialDirector,
    String? initialPosterPath,
    Set<int> initialGenreIds = const {},
  }) : titleController = TextEditingController(text: initialTitle ?? ''),
       yearController = TextEditingController(
         text: initialYear?.toString() ?? '',
       ),
       directorController = TextEditingController(text: initialDirector ?? ''),
       posterPath = ValueNotifier<String?>(initialPosterPath),
       selectedGenreIds = ValueNotifier<Set<int>>(
         Set<int>.from(initialGenreIds),
       );

  final TextEditingController titleController;
  final TextEditingController yearController;
  final TextEditingController directorController;
  final ValueNotifier<String?> posterPath;
  final ValueNotifier<Set<int>> selectedGenreIds;

  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required';
    return null;
  }

  static String? validateYear(String? value) {
    if (value == null || value.trim().isEmpty) return 'Year is required';
    final year = int.tryParse(value.trim());
    final maxYear = DateTime.now().year + 1;
    if (year == null || year < 1888 || year > maxYear) {
      return 'Enter a year between 1888 and $maxYear';
    }
    return null;
  }

  String get title => titleController.text.trim();
  int get year => int.parse(yearController.text.trim());
  String? get director => directorController.text.trim().isEmpty
      ? null
      : directorController.text.trim();

  void dispose() {
    titleController.dispose();
    yearController.dispose();
    directorController.dispose();
    posterPath.dispose();
    selectedGenreIds.dispose();
  }
}

class FilmFieldsForm extends StatelessWidget {
  const FilmFieldsForm({
    super.key,
    required this.controller,
    required this.allGenres,
    required this.posterStorageService,
  });

  final FilmFieldsController controller;
  final List<Genre> allGenres;
  final PosterStorageService posterStorageService;

  Future<void> _pickPoster(BuildContext context) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      // Picker failures (permission denied, user cancels, etc.) are silently
      // ignored: posterPath stays null/unchanged, no error dialog, since the
      // poster field is optional.
      return;
    }
    if (picked == null) return;
    if (!context.mounted) return;

    final oldPosterPath = controller.posterPath.value;
    try {
      final newPosterPath = await posterStorageService.savePoster(
        File(picked.path),
      );
      controller.posterPath.value = newPosterPath;
      if (oldPosterPath != null) {
        await posterStorageService.deletePoster(oldPosterPath);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save poster image")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: controller.posterPath,
          builder: (context, posterPath, _) => GestureDetector(
            onTap: () => _pickPoster(context),
            child: PosterThumbnail(posterPath: posterPath, size: 96),
          ),
        ),
        TextFormField(
          key: const Key('film_title_field'),
          controller: controller.titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: FilmFieldsController.validateTitle,
        ),
        TextFormField(
          key: const Key('film_year_field'),
          controller: controller.yearController,
          decoration: const InputDecoration(labelText: 'Year'),
          keyboardType: TextInputType.number,
          validator: FilmFieldsController.validateYear,
        ),
        TextFormField(
          key: const Key('film_director_field'),
          controller: controller.directorController,
          decoration: const InputDecoration(labelText: 'Director (optional)'),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<int>>(
          valueListenable: controller.selectedGenreIds,
          builder: (context, selected, _) => GenreMultiSelect(
            allGenres: allGenres,
            selectedGenreIds: selected,
            onChanged: (updated) => controller.selectedGenreIds.value = updated,
          ),
        ),
      ],
    );
  }
}
