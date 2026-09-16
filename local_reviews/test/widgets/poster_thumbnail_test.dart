import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:local_reviews/widgets/poster_thumbnail.dart';
import 'package:path/path.dart' as p;

import '../support/pump_until.dart';

// A minimal valid 1x1 transparent PNG, used so Image.memory can decode it.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('shows a placeholder icon when posterPath is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosterThumbnail()));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when the file does not exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PosterThumbnail(posterPath: '/nonexistent/path/poster.jpg'),
    ));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('shows the decrypted image once the poster loads',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('poster_thumbnail_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final posterStorageService = PosterStorageService(
      documentsDirectory: () async => tempDir,
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );
    final sourceFile = File(p.join(tempDir.path, 'source.png'))
      ..writeAsBytesSync(_onePixelPng);

    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    late String posterPath;
    await tester.runAsync(() async {
      posterPath = await posterStorageService.savePoster(sourceFile);
      await tester.pumpWidget(
        AppRepositories(
          database: database,
          posterStorageService: posterStorageService,
          child: MaterialApp(home: PosterThumbnail(posterPath: posterPath)),
        ),
      );
      await pumpUntil(tester, find.byType(Image));
    });

    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
