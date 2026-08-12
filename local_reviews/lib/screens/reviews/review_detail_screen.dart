import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_review_screen.dart';

class ReviewDetailScreen extends StatelessWidget {
  const ReviewDetailScreen({super.key, required this.reviewId});

  final int reviewId;

  Future<void> _confirmDelete(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_review_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repos.reviewRepository.deleteReview(reviewId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editReview(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final entry = (await repos.reviewRepository.watchAllReviews().first).where(
      (r) => r.review.id == reviewId,
    );
    if (entry.isEmpty || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditReviewScreen(
          existingReview: entry.first.review,
          preselectedFilm: entry.first.film,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('delete_review_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ReviewWithFilm>>(
        stream: repos.reviewRepository.watchAllReviews(),
        builder: (context, snapshot) {
          final matches = (snapshot.data ?? const <ReviewWithFilm>[]).where(
            (r) => r.review.id == reviewId,
          );
          if (matches.isEmpty) return const SizedBox.shrink();
          final entry = matches.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.film.title} (${entry.film.year})',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                StarRatingInput(rating: entry.review.rating),
                Text(
                  'Watched: ${entry.review.watchDate.toLocal().toString().split(' ').first}',
                ),
                const SizedBox(height: 8),
                Text(entry.review.reviewText),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('edit_review_fab'),
        onPressed: () => _editReview(context),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
