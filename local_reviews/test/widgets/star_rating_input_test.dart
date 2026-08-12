import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/widgets/star_rating_input.dart';

void main() {
  testWidgets('shows full, half, and empty stars for a 2.5 rating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StarRatingInput(rating: 2.5),
    ));

    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.byIcon(Icons.star_half), findsNWidgets(1));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('tapping the left half of a star reports a half value',
      (tester) async {
    double? reportedRating;
    await tester.pumpWidget(MaterialApp(
      home: StarRatingInput(
        rating: 0,
        onChanged: (value) => reportedRating = value,
      ),
    ));

    final thirdStar = find.byKey(const ValueKey('star_2'));
    final topLeft = tester.getTopLeft(thirdStar);
    await tester.tapAt(topLeft + const Offset(2, 16));
    await tester.pump();

    expect(reportedRating, 2.5);
  });

  testWidgets('tapping the right half of a star reports a whole value',
      (tester) async {
    double? reportedRating;
    await tester.pumpWidget(MaterialApp(
      home: StarRatingInput(
        rating: 0,
        onChanged: (value) => reportedRating = value,
      ),
    ));

    final thirdStar = find.byKey(const ValueKey('star_2'));
    final topRight = tester.getTopRight(thirdStar);
    await tester.tapAt(topRight - const Offset(2, -16));
    await tester.pump();

    expect(reportedRating, 3.0);
  });
}
