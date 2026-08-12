import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';

import 'database_test.dart' show openTestDatabase;

void main() {
  late AppDatabase database;
  late FilmRepository repository;

  setUp(() {
    database = openTestDatabase();
    repository = FilmRepository(database);
  });
  tearDown(() => database.close());

  test('createFilm stores the film and its genres', () async {
    final allGenres = await repository.watchAllGenres().first;
    final action = allGenres.firstWhere((g) => g.name == 'Action');
    final scifi = allGenres.firstWhere((g) => g.name == 'Sci-Fi');

    final id = await repository.createFilm(
      title: 'Akira',
      year: 1988,
      director: 'Katsuhiro Otomo',
      genreIds: [action.id, scifi.id],
    );

    final result = await repository.getFilmById(id);
    expect(result, isNotNull);
    expect(result!.film.title, 'Akira');
    expect(result.genres.map((g) => g.name).toSet(), {'Action', 'Sci-Fi'});
  });

  test('updateFilm replaces fields and genre associations', () async {
    final allGenres = await repository.watchAllGenres().first;
    final drama = allGenres.firstWhere((g) => g.name == 'Drama');
    final comedy = allGenres.firstWhere((g) => g.name == 'Comedy');

    final id = await repository.createFilm(
      title: 'Working Title',
      year: 2000,
      genreIds: [drama.id],
    );

    await repository.updateFilm(
      id: id,
      title: 'Final Title',
      year: 2001,
      genreIds: [comedy.id],
    );

    final result = await repository.getFilmById(id);
    expect(result!.film.title, 'Final Title');
    expect(result.film.year, 2001);
    expect(result.genres.map((g) => g.name).toList(), ['Comedy']);
  });

  test('deleteFilm removes the film', () async {
    final id = await repository.createFilm(title: 'Throwaway', year: 2020);
    await repository.deleteFilm(id);
    expect(await repository.getFilmById(id), isNull);
  });

  test('reviewCountForFilm counts reviews for that film only', () async {
    final filmId = await repository.createFilm(title: 'Counted', year: 2010);
    final otherFilmId = await repository.createFilm(title: 'Other', year: 2011);
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: filmId,
            rating: 3,
            reviewText: 'Fine.',
            watchDate: DateTime(2026, 1, 1),
          ),
        );
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: otherFilmId,
            rating: 5,
            reviewText: 'Great.',
            watchDate: DateTime(2026, 1, 2),
          ),
        );

    expect(await repository.reviewCountForFilm(filmId), 1);
  });

  test('searchFilmsByTitle matches a case-insensitive substring', () async {
    await repository.createFilm(title: 'Spirited Away', year: 2001);
    await repository.createFilm(title: 'Princess Mononoke', year: 1997);

    final results = await repository.searchFilmsByTitle('spirit');
    expect(results.map((f) => f.title).toList(), ['Spirited Away']);
  });
}
