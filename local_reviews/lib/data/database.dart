import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Films extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get year => integer()();
  TextColumn get director => text().nullable()();
  TextColumn get posterPath => text().nullable()();
}

class Genres extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class FilmGenres extends Table {
  IntColumn get filmId =>
      integer().references(Films, #id, onDelete: KeyAction.cascade)();
  IntColumn get genreId =>
      integer().references(Genres, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {filmId, genreId};
}

class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get filmId =>
      integer().references(Films, #id, onDelete: KeyAction.cascade)();
  RealColumn get rating => real()();
  TextColumn get reviewText => text()();
  DateTimeColumn get watchDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

const seedGenreNames = [
  'Action',
  'Comedy',
  'Drama',
  'Horror',
  'Sci-Fi',
  'Documentary',
  'Animation',
  'Thriller',
  'Romance',
  'Fantasy',
];

Future<File> resolveDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'local_reviews.sqlite'));
}

QueryExecutor openEncryptedExecutor({
  required File file,
  required Uint8List key,
}) {
  final keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = \"x'$keyHex'\";");
      if (rawDb.select('PRAGMA cipher;').isEmpty) {
        throw StateError(
          'SQLite3MultipleCiphers is not active — refusing to open the '
          'database unencrypted. Check the sqlite3mc build hook in '
          'pubspec.yaml.',
        );
      }
    },
  );
}

@DriftDatabase(tables: [Films, Genres, FilmGenres, Reviews])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await batch((batch) {
            batch.insertAll(
              genres,
              seedGenreNames.map((name) => GenresCompanion.insert(name: name)),
            );
          });
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
