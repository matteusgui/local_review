import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/widgets/poster_thumbnail.dart';

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
}
