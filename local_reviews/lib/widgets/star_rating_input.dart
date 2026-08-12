import 'package:flutter/material.dart';

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 32,
  });

  final double rating;
  final ValueChanged<double>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _buildStar(context, index)),
    );
  }

  Widget _buildStar(BuildContext context, int index) {
    final starValue = index + 1;
    final IconData icon;
    if (rating >= starValue) {
      icon = Icons.star;
    } else if (rating >= starValue - 0.5) {
      icon = Icons.star_half;
    } else {
      icon = Icons.star_border;
    }

    final star = Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
    final handler = onChanged;
    if (handler == null) {
      return star;
    }

    return GestureDetector(
      key: ValueKey('star_$index'),
      onTapUp: (details) {
        final isLeftHalf = details.localPosition.dx < size / 2;
        handler(isLeftHalf ? index + 0.5 : index + 1.0);
      },
      child: SizedBox(width: size, height: size, child: star),
    );
  }
}
