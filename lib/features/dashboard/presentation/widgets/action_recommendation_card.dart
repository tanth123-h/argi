import 'package:flutter/material.dart';
import '../../../recommendations/domain/entities/recommendation.dart';

class ActionRecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback onSourceTap;

  const ActionRecommendationCard({super.key, required this.recommendation, required this.onSourceTap});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recommendation.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(recommendation.action),
            const SizedBox(height: 8),
            Text(recommendation.value, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: onSourceTap,
              icon: const Icon(Icons.link, size: 16),
              label: Text('แหล่งอ้างอิง: ${recommendation.source.publisher}'),
            ),
          ]),
        ),
      );
}
