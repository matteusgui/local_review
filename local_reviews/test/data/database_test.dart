import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:path/path.dart' as p;

AppDatabase openTestDatabase() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  test('genres are seeded on creation', () async {
    final genres = await database.select(database.genres).get();
    expect(genres.map((g) => g.name).toList(), seedGenreNames);
  });

  test('a film can be inserted and read back', () async {
    final id = await database.into(database.films).insert(
          FilmsCompanion.insert(title: 'Paprika', year: 2006),
        );
    final film = await (database.select(database.films)
          ..where((f) => f.id.equals(id)))
        .getSingle();
    expect(film.title, 'Paprika');
    expect(film.year, 2006);
    expect(film.director, isNull);
  });

  test('deleting a film cascades to delete its reviews', () async {
    final filmId = await database.into(database.films).insert(
          FilmsCompanion.insert(title: 'Perfect Blue', year: 1997),
        );
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: filmId,
            rating: 4.5,
            reviewText: 'Tense and beautifully animated.',
            watchDate: DateTime(2026, 1, 5),
          ),
        );

    await (database.delete(database.films)..where((f) => f.id.equals(filmId)))
        .go();

    final remainingReviews = await database.select(database.reviews).get();
    expect(remainingReviews, isEmpty);
  });

  test('opens an encrypted database file and rejects the wrong key', () async {
    final tempDir = Directory.systemTemp.createTempSync('db_encryption_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));
    final keyA = Uint8List.fromList(List.generate(32, (i) => i));
    final keyB = Uint8List.fromList(List.generate(32, (i) => 255 - i));

    final dbA = AppDatabase(openEncryptedExecutor(file: dbFile, key: keyA));
    await dbA
        .into(dbA.films)
        .insert(FilmsCompanion.insert(title: 'Paprika', year: 2006));
    await dbA.close();

    final dbAReopened =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: keyA));
    final films = await dbAReopened.select(dbAReopened.films).get();
    expect(films.map((f) => f.title), contains('Paprika'));
    await dbAReopened.close();

    final dbWrongKey =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: keyB));
    await expectLater(
      dbWrongKey.select(dbWrongKey.films).get(),
      throwsA(anything),
    );
    await dbWrongKey.close();
  });
}
