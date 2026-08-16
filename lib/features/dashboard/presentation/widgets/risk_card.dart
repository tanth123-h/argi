import 'package:flutter/material.dart';
import '../../../recommendations/domain/entities/risk_level.dart';

class RiskCard extends StatelessWidget {
  final String title;
  final String detail;
  final RiskLevel level;
  final VoidCallback onTap;

  const RiskCard({super.key, required this.title, required this.detail, required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      RiskLevel.info => Colors.blue,
      RiskLevel.watch => Colors.orange,
      RiskLevel.urgent => Colors.red,
    };
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(level == RiskLevel.urgent ? Icons.warning_amber : Icons.info_outline, color: color),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(detail),
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
