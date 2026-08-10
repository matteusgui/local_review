import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';

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
}
