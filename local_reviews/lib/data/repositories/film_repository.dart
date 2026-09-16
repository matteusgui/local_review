import 'package:drift/drift.dart';

import '../../services/poster_storage_service.dart';
import '../database.dart';

class FilmWithGenres {
  const FilmWithGenres({required this.film, required this.genres});

  final Film film;
  final List<Genre> genres;
}

class FilmRepository {
  FilmRepository(this._db, {required PosterStorageService posterStorageService})
    : _posterStorageService = posterStorageService;

  final AppDatabase _db;
  final PosterStorageService _posterStorageService;

  Stream<List<Genre>> watchAllGenres() => _db.select(_db.genres).watch();

  Stream<List<FilmWithGenres>> watchAllFilms() {
    final query = _db.select(_db.films)
      ..orderBy([(f) => OrderingTerm(expression: f.title)]);
    return query.watch().asyncMap((films) async {
      final result = <FilmWithGenres>[];
      for (final film in films) {
        result.add(
          FilmWithGenres(film: film, genres: await _genresForFilm(film.id)),
        );
      }
      return result;
    });
  }

  Future<FilmWithGenres?> getFilmById(int id) async {
    final film = await (_db.select(
      _db.films,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    if (film == null) return null;
    return FilmWithGenres(film: film, genres: await _genresForFilm(id));
  }

  Future<List<Genre>> _genresForFilm(int filmId) async {
    final query = _db.select(_db.filmGenres).join([
      innerJoin(_db.genres, _db.genres.id.equalsExp(_db.filmGenres.genreId)),
    ])..where(_db.filmGenres.filmId.equals(filmId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.genres)).toList();
  }

  Future<int> createFilm({
    required String title,
    required int year,
    String? director,
    String? posterPath,
    List<int> genreIds = const [],
  }) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.films)
          .insert(
            FilmsCompanion.insert(
              title: title,
              year: year,
              director: Value(director),
              posterPath: Value(posterPath),
            ),
          );
      await _linkGenres(id, genreIds);
      return id;
    });
  }

  Future<void> updateFilm({
    required int id,
    required String title,
    required int year,
    String? director,
    String? posterPath,
    List<int> genreIds = const [],
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.films)..where((f) => f.id.equals(id))).write(
        FilmsCompanion(
          title: Value(title),
          year: Value(year),
          director: Value(director),
          posterPath: Value(posterPath),
        ),
      );
      await (_db.delete(
        _db.filmGenres,
      )..where((fg) => fg.filmId.equals(id))).go();
      await _linkGenres(id, genreIds);
    });
  }

  Future<void> _linkGenres(int filmId, List<int> genreIds) {
    if (genreIds.isEmpty) return Future.value();
    return _db.batch((batch) {
      batch.insertAll(
        _db.filmGenres,
        genreIds.map(
          (genreId) =>
              FilmGenresCompanion.insert(filmId: filmId, genreId: genreId),
        ),
      );
    });
  }

  Future<void> deleteFilm(int id) async {
    final entry = await getFilmById(id);
    await (_db.delete(_db.films)..where((f) => f.id.equals(id))).go();
    final posterPath = entry?.film.posterPath;
    if (posterPath != null) {
      await _posterStorageService.deletePoster(posterPath);
    }
  }

  Future<int> reviewCountForFilm(int filmId) async {
    final reviews = await (_db.select(
      _db.reviews,
    )..where((r) => r.filmId.equals(filmId))).get();
    return reviews.length;
  }

  Future<List<Film>> searchFilmsByTitle(String query) {
    final likePattern = '%$query%';
    return (_db.select(
      _db.films,
    )..where((f) => f.title.like(likePattern))).get();
  }
}
