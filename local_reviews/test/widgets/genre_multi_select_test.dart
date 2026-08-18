import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/widgets/genre_multi_select.dart';

void main() {
  testWidgets('selecting a chip adds its id to the reported set',
      (tester) async {
    Set<int>? reported;
    final genres = [
      Genre(id: 1, name: 'Action'),
      Genre(id: 2, name: 'Comedy'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GenreMultiSelect(
          allGenres: genres,
          selectedGenreIds: const {},
          onChanged: (updated) => reported = updated,
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Action'));
    await tester.pump();

    expect(reported, {1});
  });

  testWidgets('deselecting a chip removes its id', (tester) async {
    Set<int>? reported;
    final genres = [Genre(id: 1, name: 'Action')];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GenreMultiSelect(
          allGenres: genres,
          selectedGenreIds: const {1},
          onChanged: (updated) => reported = updated,
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Action'));
    await tester.pump();

    expect(reported, isEmpty);
  });
}
