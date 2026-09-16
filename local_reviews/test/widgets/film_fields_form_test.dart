import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:local_reviews/widgets/film_fields_form.dart';

PosterStorageService _testPosterStorageService() => PosterStorageService(
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );

void main() {
  testWidgets('validateTitle rejects empty and accepts non-empty', (tester) async {
    expect(FilmFieldsController.validateTitle(''), isNotNull);
    expect(FilmFieldsController.validateTitle('Alien'), isNull);
  });

  testWidgets('validateYear rejects out-of-range and non-numeric years',
      (tester) async {
    expect(FilmFieldsController.validateYear('1887'), isNotNull);
    expect(FilmFieldsController.validateYear('not a year'), isNotNull);
    expect(FilmFieldsController.validateYear('1979'), isNull);
  });

  testWidgets('typing into the title field updates the controller', (tester) async {
    final controller = FilmFieldsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilmFieldsForm(
          controller: controller,
          allGenres: const [],
          posterStorageService: _testPosterStorageService(),
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('film_title_field')), 'Alien');
    expect(controller.title, 'Alien');
  });

  testWidgets('tapping a genre chip updates selectedGenreIds', (tester) async {
    final controller = FilmFieldsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilmFieldsForm(
          controller: controller,
          allGenres: [Genre(id: 1, name: 'Horror')],
          posterStorageService: _testPosterStorageService(),
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Horror'));
    await tester.pump();

    expect(controller.selectedGenreIds.value, {1});
  });
}
