import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';

void main() {
  testWidgets('AppRepositories.of exposes the repositories to descendants',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final repos = AppRepositories.of(capturedContext);
    expect(repos.database, database);
    expect(repos.filmRepository, isNotNull);
    expect(repos.reviewRepository, isNotNull);
    expect(repos.posterStorageService, isNotNull);
  });
}
