import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../widgets/film_fields_form.dart';

class AddEditFilmScreen extends StatefulWidget {
  const AddEditFilmScreen({
    super.key,
    this.existingFilm,
    this.existingGenreIds = const {},
  });

  final Film? existingFilm;
  final Set<int> existingGenreIds;

  @override
  State<AddEditFilmScreen> createState() => AddEditFilmScreenState();
}

class AddEditFilmScreenState extends State<AddEditFilmScreen> {
  final formKey = GlobalKey<FormState>();
  late final FilmFieldsController fieldsController;

  @override
  void initState() {
    super.initState();
    fieldsController = FilmFieldsController(
      initialTitle: widget.existingFilm?.title,
      initialYear: widget.existingFilm?.year,
      initialDirector: widget.existingFilm?.director,
      initialPosterPath: widget.existingFilm?.posterPath,
      initialGenreIds: widget.existingGenreIds,
    );
  }

  @override
  void dispose() {
    fieldsController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final repos = AppRepositories.of(context);
    if (widget.existingFilm == null) {
      await repos.filmRepository.createFilm(
        title: fieldsController.title,
        year: fieldsController.year,
        director: fieldsController.director,
        posterPath: fieldsController.posterPath.value,
        genreIds: fieldsController.selectedGenreIds.value.toList(),
      );
    } else {
      final oldPosterPath = widget.existingFilm!.posterPath;
      final newPosterPath = fieldsController.posterPath.value;
      await repos.filmRepository.updateFilm(
        id: widget.existingFilm!.id,
        title: fieldsController.title,
        year: fieldsController.year,
        director: fieldsController.director,
        posterPath: newPosterPath,
        genreIds: fieldsController.selectedGenreIds.value.toList(),
      );
      if (oldPosterPath != null && oldPosterPath != newPosterPath) {
        await repos.posterStorageService.deletePoster(oldPosterPath);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingFilm == null ? 'Add film' : 'Edit film'),
      ),
      body: StreamBuilder<List<Genre>>(
        stream: repos.filmRepository.watchAllGenres(),
        builder: (context, snapshot) {
          final allGenres = snapshot.data ?? const <Genre>[];
          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilmFieldsForm(
                  controller: fieldsController,
                  allGenres: allGenres,
                  posterStorageService: repos.posterStorageService,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('save_film_button'),
                  onPressed: save,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
