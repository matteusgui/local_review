import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import 'add_edit_film_screen.dart';
import 'film_detail_screen.dart';

class FilmsScreen extends StatelessWidget {
  const FilmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, snapshot) {
          final films = snapshot.data ?? const <FilmWithGenres>[];
          if (films.isEmpty) {
            return const Center(child: Text('No films yet'));
          }
          return ListView.builder(
            itemCount: films.length,
            itemBuilder: (context, index) {
              final entry = films[index];
              return ListTile(
                key: ValueKey('film_tile_${entry.film.id}'),
                leading: PosterThumbnail(posterPath: entry.film.posterPath, size: 40),
                title: Text('${entry.film.title} (${entry.film.year})'),
                subtitle: entry.film.director != null ? Text(entry.film.director!) : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FilmDetailScreen(filmId: entry.film.id),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_film_fab'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddEditFilmScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
