import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_film_screen.dart';

class FilmDetailScreen extends StatelessWidget {
  const FilmDetailScreen({super.key, required this.filmId});

  final int filmId;

  Future<void> _confirmDelete(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final reviewCount = await repos.filmRepository.reviewCountForFilm(filmId);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete film?'),
        content: Text(reviewCount == 0
            ? 'This film has no reviews.'
            : 'This will also delete $reviewCount review${reviewCount == 1 ? '' : 's'} for this film.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_film_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await repos.filmRepository.deleteFilm(filmId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editFilm(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final entry = await repos.filmRepository.getFilmById(filmId);
    if (entry == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditFilmScreen(
        existingFilm: entry.film,
        existingGenreIds: entry.genres.map((g) => g.id).toSet(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('delete_film_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, snapshot) {
          final films = snapshot.data ?? const <FilmWithGenres>[];
          final matches = films.where((f) => f.film.id == filmId);
          if (matches.isEmpty) return const SizedBox.shrink();
          final entry = matches.first;
          return Column(
            children: [
              PosterThumbnail(posterPath: entry.film.posterPath, size: 96),
              Text('${entry.film.title} (${entry.film.year})',
                  style: Theme.of(context).textTheme.headlineSmall),
              if (entry.film.director != null) Text(entry.film.director!),
              Wrap(
                spacing: 4,
                children: entry.genres.map((g) => Chip(label: Text(g.name))).toList(),
              ),
              Expanded(
                child: StreamBuilder<List<Review>>(
                  stream: repos.reviewRepository.watchReviewsForFilm(filmId),
                  builder: (context, reviewSnapshot) {
                    final reviews = reviewSnapshot.data ?? const <Review>[];
                    return ListView.builder(
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return ListTile(
                          key: ValueKey('review_tile_${review.id}'),
                          title: StarRatingInput(rating: review.rating, size: 16),
                          subtitle: Text(review.reviewText),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('edit_film_fab'),
        onPressed: () => _editFilm(context),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
