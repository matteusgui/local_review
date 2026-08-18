import 'package:flutter/material.dart';

import '../data/database.dart';

class GenreMultiSelect extends StatelessWidget {
  const GenreMultiSelect({
    super.key,
    required this.allGenres,
    required this.selectedGenreIds,
    required this.onChanged,
  });

  final List<Genre> allGenres;
  final Set<int> selectedGenreIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: allGenres.map((genre) {
        final selected = selectedGenreIds.contains(genre.id);
        return FilterChip(
          label: Text(genre.name),
          selected: selected,
          onSelected: (isSelected) {
            final updated = Set<int>.from(selectedGenreIds);
            if (isSelected) {
              updated.add(genre.id);
            } else {
              updated.remove(genre.id);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
