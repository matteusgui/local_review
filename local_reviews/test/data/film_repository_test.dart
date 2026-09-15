import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:path/path.dart' as p;

import 'database_test.dart' show openTestDatabase;

void main() {
  late AppDatabase database;
  late FilmRepository repository;

  setUp(() {
    database = openTestDatabase();
    repository = FilmRepository(
      database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
    );
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

  test('deleteFilm also deletes its poster file from disk', () async {
    final tempDir = Directory.systemTemp.createTempSync('poster_storage_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final posterStorageService = PosterStorageService(
      documentsDirectory: () async => tempDir,
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );
    final posterSource = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final posterPath = await posterStorageService.savePoster(posterSource);
    final repositoryWithPosters = FilmRepository(
      database,
      posterStorageService: posterStorageService,
    );

    final id = await repositoryWithPosters.createFilm(
      title: 'Deletable',
      year: 2005,
      posterPath: posterPath,
    );
    expect(File(posterPath).existsSync(), isTrue);

    await repositoryWithPosters.deleteFilm(id);

    expect(await repository.getFilmById(id), isNull);
    expect(File(posterPath).existsSync(), isFalse);
  });

  test('reviewCountForFilm counts reviews for that film only', () async {
    final filmId = await repository.createFilm(title: 'Counted', year: 2010);
    final otherFilmId = await repository.createFilm(title: 'Other', year: 2011);
    await database
        .into(database.reviews)
        .insert(
          ReviewsCompanion.insert(
            filmId: filmId,
            rating: 3,
            reviewText: 'Fine.',
            watchDate: DateTime(2026, 1, 1),
          ),
        );
    await database
        .into(database.reviews)
        .insert(
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
