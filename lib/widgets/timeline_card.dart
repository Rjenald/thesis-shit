import 'package:flutter/material.dart';
import '../models/analysis_model.dart';

class TimelineCard extends StatelessWidget {
  final WordAnalysis analysis;
  const TimelineCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${analysis.start}s --- ${analysis.end}s",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(analysis.word.toUpperCase(),
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: analysis.notes
                  .map((n) => Chip(label: Text("${n.note}")))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }
}
