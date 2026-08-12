import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/film_fields_form.dart';
import '../../widgets/star_rating_input.dart';

class AddEditReviewScreen extends StatefulWidget {
  const AddEditReviewScreen({
    super.key,
    this.existingReview,
    this.preselectedFilm,
  });

  final Review? existingReview;
  final Film? preselectedFilm;

  @override
  State<AddEditReviewScreen> createState() => AddEditReviewScreenState();
}

class AddEditReviewScreenState extends State<AddEditReviewScreen> {
  final formKey = GlobalKey<FormState>();
  final textController = TextEditingController();
  late final FilmFieldsController newFilmController;
  double rating = 0;
  DateTime watchDate = DateTime.now();
  Film? selectedFilm;
  bool creatingNewFilm = false;
  bool _saveAttempted = false;

  @override
  void initState() {
    super.initState();
    selectedFilm = widget.preselectedFilm;
    textController.text = widget.existingReview?.reviewText ?? '';
    rating = widget.existingReview?.rating ?? 0;
    watchDate = widget.existingReview?.watchDate ?? DateTime.now();
    newFilmController = FilmFieldsController();
  }

  @override
  void dispose() {
    textController.dispose();
    newFilmController.dispose();
    super.dispose();
  }

  String? _validateReviewText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Review text is required';
    return null;
  }

  Future<void> _save() async {
    setState(() => _saveAttempted = true);
    final formValid = formKey.currentState!.validate();
    final filmSelected = creatingNewFilm || selectedFilm != null;
    if (!formValid || rating <= 0 || !filmSelected) return;
    final repos = AppRepositories.of(context);

    final int filmId;
    if (creatingNewFilm) {
      filmId = await repos.filmRepository.createFilm(
        title: newFilmController.title,
        year: newFilmController.year,
        director: newFilmController.director,
        posterPath: newFilmController.posterPath.value,
        genreIds: newFilmController.selectedGenreIds.value.toList(),
      );
    } else {
      filmId = selectedFilm!.id;
    }

    if (widget.existingReview == null) {
      await repos.reviewRepository.createReview(
        filmId: filmId,
        rating: rating,
        reviewText: textController.text.trim(),
        watchDate: watchDate,
      );
    } else {
      await repos.reviewRepository.updateReview(
        id: widget.existingReview!.id,
        rating: rating,
        reviewText: textController.text.trim(),
        watchDate: watchDate,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReview == null ? 'Add review' : 'Edit review',
        ),
      ),
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, filmsSnapshot) {
          final allFilms = (filmsSnapshot.data ?? const <FilmWithGenres>[])
              .map((e) => e.film)
              .toList();
          return StreamBuilder<List<Genre>>(
            stream: repos.filmRepository.watchAllGenres(),
            builder: (context, genresSnapshot) {
              final allGenres = genresSnapshot.data ?? const <Genre>[];
              return Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.existingReview == null) ...[
                      Autocomplete<Film>(
                        displayStringForOption: (film) =>
                            '${film.title} (${film.year})',
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Film>.empty();
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return allFilms.where(
                            (film) => film.title.toLowerCase().contains(query),
                          );
                        },
                        onSelected: (film) => setState(() {
                          selectedFilm = film;
                          creatingNewFilm = false;
                        }),
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                key: const Key('film_search_field'),
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Search films',
                                ),
                              );
                            },
                      ),
                      if (selectedFilm != null)
                        Text(
                          'Selected: ${selectedFilm!.title} (${selectedFilm!.year})',
                        ),
                      TextButton(
                        key: const Key('toggle_new_film_button'),
                        onPressed: () => setState(() {
                          creatingNewFilm = !creatingNewFilm;
                          if (creatingNewFilm) selectedFilm = null;
                        }),
                        child: Text(
                          creatingNewFilm ? 'Cancel new film' : '+ New film',
                        ),
                      ),
                      if (creatingNewFilm)
                        FilmFieldsForm(
                          controller: newFilmController,
                          allGenres: allGenres,
                          posterStorageService: repos.posterStorageService,
                        ),
                      if (_saveAttempted &&
                          !creatingNewFilm &&
                          selectedFilm == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Select or create a film',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ] else
                      Text(
                        '${widget.preselectedFilm?.title} (${widget.preselectedFilm?.year})',
                      ),
                    const SizedBox(height: 16),
                    StarRatingInput(
                      rating: rating,
                      onChanged: (value) => setState(() => rating = value),
                    ),
                    if (_saveAttempted && rating <= 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rating is required',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    TextFormField(
                      key: const Key('review_text_field'),
                      controller: textController,
                      decoration: const InputDecoration(labelText: 'Review'),
                      validator: _validateReviewText,
                      maxLines: 4,
                    ),
                    ListTile(
                      key: const Key('watch_date_field'),
                      title: Text(
                        'Watched on ${watchDate.toLocal().toString().split(' ').first}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: watchDate,
                          firstDate: DateTime(1888),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => watchDate = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('save_review_button'),
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
