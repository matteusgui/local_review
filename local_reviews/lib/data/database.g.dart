// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FilmsTable extends Films with TableInfo<$FilmsTable, Film> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterPathMeta = const VerificationMeta(
    'posterPath',
  );
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
    'poster_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, year, director, posterPath];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'films';
  @override
  VerificationContext validateIntegrity(
    Insertable<Film> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('poster_path')) {
      context.handle(
        _posterPathMeta,
        posterPath.isAcceptableOrUnknown(data['poster_path']!, _posterPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Film map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Film(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      posterPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_path'],
      ),
    );
  }

  @override
  $FilmsTable createAlias(String alias) {
    return $FilmsTable(attachedDatabase, alias);
  }
}

class Film extends DataClass implements Insertable<Film> {
  final int id;
  final String title;
  final int year;
  final String? director;
  final String? posterPath;
  const Film({
    required this.id,
    required this.title,
    required this.year,
    this.director,
    this.posterPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    return map;
  }

  FilmsCompanion toCompanion(bool nullToAbsent) {
    return FilmsCompanion(
      id: Value(id),
      title: Value(title),
      year: Value(year),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
    );
  }

  factory Film.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Film(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      year: serializer.fromJson<int>(json['year']),
      director: serializer.fromJson<String?>(json['director']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'year': serializer.toJson<int>(year),
      'director': serializer.toJson<String?>(director),
      'posterPath': serializer.toJson<String?>(posterPath),
    };
  }

  Film copyWith({
    int? id,
    String? title,
    int? year,
    Value<String?> director = const Value.absent(),
    Value<String?> posterPath = const Value.absent(),
  }) => Film(
    id: id ?? this.id,
    title: title ?? this.title,
    year: year ?? this.year,
    director: director.present ? director.value : this.director,
    posterPath: posterPath.present ? posterPath.value : this.posterPath,
  );
  Film copyWithCompanion(FilmsCompanion data) {
    return Film(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      year: data.year.present ? data.year.value : this.year,
      director: data.director.present ? data.director.value : this.director,
      posterPath: data.posterPath.present
          ? data.posterPath.value
          : this.posterPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Film(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('director: $director, ')
          ..write('posterPath: $posterPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, year, director, posterPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Film &&
          other.id == this.id &&
          other.title == this.title &&
          other.year == this.year &&
          other.director == this.director &&
          other.posterPath == this.posterPath);
}

class FilmsCompanion extends UpdateCompanion<Film> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> year;
  final Value<String?> director;
  final Value<String?> posterPath;
  const FilmsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.year = const Value.absent(),
    this.director = const Value.absent(),
    this.posterPath = const Value.absent(),
  });
  FilmsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required int year,
    this.director = const Value.absent(),
    this.posterPath = const Value.absent(),
  }) : title = Value(title),
       year = Value(year);
  static Insertable<Film> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? year,
    Expression<String>? director,
    Expression<String>? posterPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (year != null) 'year': year,
      if (director != null) 'director': director,
      if (posterPath != null) 'poster_path': posterPath,
    });
  }

  FilmsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int>? year,
    Value<String?>? director,
    Value<String?>? posterPath,
  }) {
    return FilmsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      director: director ?? this.director,
      posterPath: posterPath ?? this.posterPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilmsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('director: $director, ')
          ..write('posterPath: $posterPath')
          ..write(')'))
        .toString();
  }
}

class $GenresTable extends Genres with TableInfo<$GenresTable, Genre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<Genre> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Genre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Genre(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $GenresTable createAlias(String alias) {
    return $GenresTable(attachedDatabase, alias);
  }
}

class Genre extends DataClass implements Insertable<Genre> {
  final int id;
  final String name;
  const Genre({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  GenresCompanion toCompanion(bool nullToAbsent) {
    return GenresCompanion(id: Value(id), name: Value(name));
  }

  factory Genre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Genre(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Genre copyWith({int? id, String? name}) =>
      Genre(id: id ?? this.id, name: name ?? this.name);
  Genre copyWithCompanion(GenresCompanion data) {
    return Genre(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Genre(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Genre && other.id == this.id && other.name == this.name);
}

class GenresCompanion extends UpdateCompanion<Genre> {
  final Value<int> id;
  final Value<String> name;
  const GenresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  GenresCompanion.insert({this.id = const Value.absent(), required String name})
    : name = Value(name);
  static Insertable<Genre> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  GenresCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return GenresCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $FilmGenresTable extends FilmGenres
    with TableInfo<$FilmGenresTable, FilmGenre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilmGenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filmIdMeta = const VerificationMeta('filmId');
  @override
  late final GeneratedColumn<int> filmId = GeneratedColumn<int>(
    'film_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES films (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _genreIdMeta = const VerificationMeta(
    'genreId',
  );
  @override
  late final GeneratedColumn<int> genreId = GeneratedColumn<int>(
    'genre_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES genres (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [filmId, genreId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'film_genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<FilmGenre> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('film_id')) {
      context.handle(
        _filmIdMeta,
        filmId.isAcceptableOrUnknown(data['film_id']!, _filmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_filmIdMeta);
    }
    if (data.containsKey('genre_id')) {
      context.handle(
        _genreIdMeta,
        genreId.isAcceptableOrUnknown(data['genre_id']!, _genreIdMeta),
      );
    } else if (isInserting) {
      context.missing(_genreIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filmId, genreId};
  @override
  FilmGenre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FilmGenre(
      filmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}film_id'],
      )!,
      genreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}genre_id'],
      )!,
    );
  }

  @override
  $FilmGenresTable createAlias(String alias) {
    return $FilmGenresTable(attachedDatabase, alias);
  }
}

class FilmGenre extends DataClass implements Insertable<FilmGenre> {
  final int filmId;
  final int genreId;
  const FilmGenre({required this.filmId, required this.genreId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['film_id'] = Variable<int>(filmId);
    map['genre_id'] = Variable<int>(genreId);
    return map;
  }

  FilmGenresCompanion toCompanion(bool nullToAbsent) {
    return FilmGenresCompanion(filmId: Value(filmId), genreId: Value(genreId));
  }

  factory FilmGenre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FilmGenre(
      filmId: serializer.fromJson<int>(json['filmId']),
      genreId: serializer.fromJson<int>(json['genreId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filmId': serializer.toJson<int>(filmId),
      'genreId': serializer.toJson<int>(genreId),
    };
  }

  FilmGenre copyWith({int? filmId, int? genreId}) => FilmGenre(
    filmId: filmId ?? this.filmId,
    genreId: genreId ?? this.genreId,
  );
  FilmGenre copyWithCompanion(FilmGenresCompanion data) {
    return FilmGenre(
      filmId: data.filmId.present ? data.filmId.value : this.filmId,
      genreId: data.genreId.present ? data.genreId.value : this.genreId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FilmGenre(')
          ..write('filmId: $filmId, ')
          ..write('genreId: $genreId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filmId, genreId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilmGenre &&
          other.filmId == this.filmId &&
          other.genreId == this.genreId);
}

class FilmGenresCompanion extends UpdateCompanion<FilmGenre> {
  final Value<int> filmId;
  final Value<int> genreId;
  final Value<int> rowid;
  const FilmGenresCompanion({
    this.filmId = const Value.absent(),
    this.genreId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilmGenresCompanion.insert({
    required int filmId,
    required int genreId,
    this.rowid = const Value.absent(),
  }) : filmId = Value(filmId),
       genreId = Value(genreId);
  static Insertable<FilmGenre> custom({
    Expression<int>? filmId,
    Expression<int>? genreId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filmId != null) 'film_id': filmId,
      if (genreId != null) 'genre_id': genreId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilmGenresCompanion copyWith({
    Value<int>? filmId,
    Value<int>? genreId,
    Value<int>? rowid,
  }) {
    return FilmGenresCompanion(
      filmId: filmId ?? this.filmId,
      genreId: genreId ?? this.genreId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filmId.present) {
      map['film_id'] = Variable<int>(filmId.value);
    }
    if (genreId.present) {
      map['genre_id'] = Variable<int>(genreId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilmGenresCompanion(')
          ..write('filmId: $filmId, ')
          ..write('genreId: $genreId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FilmsTable films = $FilmsTable(this);
  late final $GenresTable genres = $GenresTable(this);
  late final $FilmGenresTable filmGenres = $FilmGenresTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    films,
    genres,
    filmGenres,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'films',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('film_genres', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'genres',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('film_genres', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FilmsTableCreateCompanionBuilder =
    FilmsCompanion Function({
      Value<int> id,
      required String title,
      required int year,
      Value<String?> director,
      Value<String?> posterPath,
    });
typedef $$FilmsTableUpdateCompanionBuilder =
    FilmsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> year,
      Value<String?> director,
      Value<String?> posterPath,
    });

final class $$FilmsTableReferences
    extends BaseReferences<_$AppDatabase, $FilmsTable, Film> {
  $$FilmsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FilmGenresTable, List<FilmGenre>>
  _filmGenresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.filmGenres,
    aliasName: 'films__id__film_genres__film_id',
  );

  $$FilmGenresTableProcessedTableManager get filmGenresRefs {
    final manager = $$FilmGenresTableTableManager(
      $_db,
      $_db.filmGenres,
    ).filter((f) => f.filmId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_filmGenresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FilmsTableFilterComposer extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> filmGenresRefs(
    Expression<bool> Function($$FilmGenresTableFilterComposer f) f,
  ) {
    final $$FilmGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.filmGenres,
      getReferencedColumn: (t) => t.filmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmGenresTableFilterComposer(
            $db: $db,
            $table: $db.filmGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FilmsTableOrderingComposer
    extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FilmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => column,
  );

  Expression<T> filmGenresRefs<T extends Object>(
    Expression<T> Function($$FilmGenresTableAnnotationComposer a) f,
  ) {
    final $$FilmGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.filmGenres,
      getReferencedColumn: (t) => t.filmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.filmGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FilmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilmsTable,
          Film,
          $$FilmsTableFilterComposer,
          $$FilmsTableOrderingComposer,
          $$FilmsTableAnnotationComposer,
          $$FilmsTableCreateCompanionBuilder,
          $$FilmsTableUpdateCompanionBuilder,
          (Film, $$FilmsTableReferences),
          Film,
          PrefetchHooks Function({bool filmGenresRefs})
        > {
  $$FilmsTableTableManager(_$AppDatabase db, $FilmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
              }) => FilmsCompanion(
                id: id,
                title: title,
                year: year,
                director: director,
                posterPath: posterPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required int year,
                Value<String?> director = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
              }) => FilmsCompanion.insert(
                id: id,
                title: title,
                year: year,
                director: director,
                posterPath: posterPath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FilmsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({filmGenresRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filmGenresRefs) db.filmGenres],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filmGenresRefs)
                    await $_getPrefetchedData<Film, $FilmsTable, FilmGenre>(
                      currentTable: table,
                      referencedTable: $$FilmsTableReferences
                          ._filmGenresRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FilmsTableReferences(db, table, p0).filmGenresRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.filmId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FilmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilmsTable,
      Film,
      $$FilmsTableFilterComposer,
      $$FilmsTableOrderingComposer,
      $$FilmsTableAnnotationComposer,
      $$FilmsTableCreateCompanionBuilder,
      $$FilmsTableUpdateCompanionBuilder,
      (Film, $$FilmsTableReferences),
      Film,
      PrefetchHooks Function({bool filmGenresRefs})
    >;
typedef $$GenresTableCreateCompanionBuilder =
    GenresCompanion Function({Value<int> id, required String name});
typedef $$GenresTableUpdateCompanionBuilder =
    GenresCompanion Function({Value<int> id, Value<String> name});

final class $$GenresTableReferences
    extends BaseReferences<_$AppDatabase, $GenresTable, Genre> {
  $$GenresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FilmGenresTable, List<FilmGenre>>
  _filmGenresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.filmGenres,
    aliasName: 'genres__id__film_genres__genre_id',
  );

  $$FilmGenresTableProcessedTableManager get filmGenresRefs {
    final manager = $$FilmGenresTableTableManager(
      $_db,
      $_db.filmGenres,
    ).filter((f) => f.genreId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_filmGenresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GenresTableFilterComposer
    extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> filmGenresRefs(
    Expression<bool> Function($$FilmGenresTableFilterComposer f) f,
  ) {
    final $$FilmGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.filmGenres,
      getReferencedColumn: (t) => t.genreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmGenresTableFilterComposer(
            $db: $db,
            $table: $db.filmGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GenresTableOrderingComposer
    extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GenresTableAnnotationComposer
    extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> filmGenresRefs<T extends Object>(
    Expression<T> Function($$FilmGenresTableAnnotationComposer a) f,
  ) {
    final $$FilmGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.filmGenres,
      getReferencedColumn: (t) => t.genreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.filmGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GenresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GenresTable,
          Genre,
          $$GenresTableFilterComposer,
          $$GenresTableOrderingComposer,
          $$GenresTableAnnotationComposer,
          $$GenresTableCreateCompanionBuilder,
          $$GenresTableUpdateCompanionBuilder,
          (Genre, $$GenresTableReferences),
          Genre,
          PrefetchHooks Function({bool filmGenresRefs})
        > {
  $$GenresTableTableManager(_$AppDatabase db, $GenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => GenresCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  GenresCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GenresTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({filmGenresRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filmGenresRefs) db.filmGenres],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filmGenresRefs)
                    await $_getPrefetchedData<Genre, $GenresTable, FilmGenre>(
                      currentTable: table,
                      referencedTable: $$GenresTableReferences
                          ._filmGenresRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GenresTableReferences(db, table, p0).filmGenresRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.genreId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GenresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GenresTable,
      Genre,
      $$GenresTableFilterComposer,
      $$GenresTableOrderingComposer,
      $$GenresTableAnnotationComposer,
      $$GenresTableCreateCompanionBuilder,
      $$GenresTableUpdateCompanionBuilder,
      (Genre, $$GenresTableReferences),
      Genre,
      PrefetchHooks Function({bool filmGenresRefs})
    >;
typedef $$FilmGenresTableCreateCompanionBuilder =
    FilmGenresCompanion Function({
      required int filmId,
      required int genreId,
      Value<int> rowid,
    });
typedef $$FilmGenresTableUpdateCompanionBuilder =
    FilmGenresCompanion Function({
      Value<int> filmId,
      Value<int> genreId,
      Value<int> rowid,
    });

final class $$FilmGenresTableReferences
    extends BaseReferences<_$AppDatabase, $FilmGenresTable, FilmGenre> {
  $$FilmGenresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilmsTable _filmIdTable(_$AppDatabase db) =>
      db.films.createAlias('film_genres__film_id__films__id');

  $$FilmsTableProcessedTableManager get filmId {
    final $_column = $_itemColumn<int>('film_id')!;

    final manager = $$FilmsTableTableManager(
      $_db,
      $_db.films,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_filmIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GenresTable _genreIdTable(_$AppDatabase db) =>
      db.genres.createAlias('film_genres__genre_id__genres__id');

  $$GenresTableProcessedTableManager get genreId {
    final $_column = $_itemColumn<int>('genre_id')!;

    final manager = $$GenresTableTableManager(
      $_db,
      $_db.genres,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_genreIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FilmGenresTableFilterComposer
    extends Composer<_$AppDatabase, $FilmGenresTable> {
  $$FilmGenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FilmsTableFilterComposer get filmId {
    final $$FilmsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.filmId,
      referencedTable: $db.films,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmsTableFilterComposer(
            $db: $db,
            $table: $db.films,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GenresTableFilterComposer get genreId {
    final $$GenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.genres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GenresTableFilterComposer(
            $db: $db,
            $table: $db.genres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilmGenresTableOrderingComposer
    extends Composer<_$AppDatabase, $FilmGenresTable> {
  $$FilmGenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FilmsTableOrderingComposer get filmId {
    final $$FilmsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.filmId,
      referencedTable: $db.films,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmsTableOrderingComposer(
            $db: $db,
            $table: $db.films,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GenresTableOrderingComposer get genreId {
    final $$GenresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.genres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GenresTableOrderingComposer(
            $db: $db,
            $table: $db.genres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilmGenresTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilmGenresTable> {
  $$FilmGenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FilmsTableAnnotationComposer get filmId {
    final $$FilmsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.filmId,
      referencedTable: $db.films,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilmsTableAnnotationComposer(
            $db: $db,
            $table: $db.films,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GenresTableAnnotationComposer get genreId {
    final $$GenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.genres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GenresTableAnnotationComposer(
            $db: $db,
            $table: $db.genres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilmGenresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilmGenresTable,
          FilmGenre,
          $$FilmGenresTableFilterComposer,
          $$FilmGenresTableOrderingComposer,
          $$FilmGenresTableAnnotationComposer,
          $$FilmGenresTableCreateCompanionBuilder,
          $$FilmGenresTableUpdateCompanionBuilder,
          (FilmGenre, $$FilmGenresTableReferences),
          FilmGenre,
          PrefetchHooks Function({bool filmId, bool genreId})
        > {
  $$FilmGenresTableTableManager(_$AppDatabase db, $FilmGenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilmGenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilmGenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilmGenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> filmId = const Value.absent(),
                Value<int> genreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilmGenresCompanion(
                filmId: filmId,
                genreId: genreId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int filmId,
                required int genreId,
                Value<int> rowid = const Value.absent(),
              }) => FilmGenresCompanion.insert(
                filmId: filmId,
                genreId: genreId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FilmGenresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({filmId = false, genreId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (filmId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.filmId,
                                referencedTable: $$FilmGenresTableReferences
                                    ._filmIdTable(db),
                                referencedColumn: $$FilmGenresTableReferences
                                    ._filmIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (genreId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.genreId,
                                referencedTable: $$FilmGenresTableReferences
                                    ._genreIdTable(db),
                                referencedColumn: $$FilmGenresTableReferences
                                    ._genreIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FilmGenresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilmGenresTable,
      FilmGenre,
      $$FilmGenresTableFilterComposer,
      $$FilmGenresTableOrderingComposer,
      $$FilmGenresTableAnnotationComposer,
      $$FilmGenresTableCreateCompanionBuilder,
      $$FilmGenresTableUpdateCompanionBuilder,
      (FilmGenre, $$FilmGenresTableReferences),
      FilmGenre,
      PrefetchHooks Function({bool filmId, bool genreId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FilmsTableTableManager get films =>
      $$FilmsTableTableManager(_db, _db.films);
  $$GenresTableTableManager get genres =>
      $$GenresTableTableManager(_db, _db.genres);
  $$FilmGenresTableTableManager get filmGenres =>
      $$FilmGenresTableTableManager(_db, _db.filmGenres);
}
