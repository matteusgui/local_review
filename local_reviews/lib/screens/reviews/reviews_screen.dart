import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_review_screen.dart';
import 'review_detail_screen.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      body: StreamBuilder<List<ReviewWithFilm>>(
        stream: repos.reviewRepository.watchAllReviews(),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <ReviewWithFilm>[];
          if (reviews.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }
          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final entry = reviews[index];
              return ListTile(
                key: ValueKey('review_tile_${entry.review.id}'),
                leading: PosterThumbnail(posterPath: entry.film.posterPath, size: 40),
                title: Text('${entry.film.title} (${entry.film.year})'),
                subtitle: StarRatingInput(rating: entry.review.rating, size: 16),
                trailing: Text(entry.review.watchDate.toLocal().toString().split(' ').first),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReviewDetailScreen(reviewId: entry.review.id),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_review_fab'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddEditReviewScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
