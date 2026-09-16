import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

void main() {
  testWidgets('AppRepositories.of exposes the repositories to descendants',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final posterStorageService = PosterStorageService(
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      AppRepositories(
        database: database,
        posterStorageService: posterStorageService,
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
    expect(repos.posterStorageService, posterStorageService);
  });
}
