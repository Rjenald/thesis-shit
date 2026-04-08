import 'package:flutter/material.dart';

class SongDetailPage extends StatelessWidget {
  final String songImage;
  final String songTitle;

  const SongDetailPage({
    super.key,
    required this.songImage,
    required this.songTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Song Details')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(songImage),
              const SizedBox(height: 20),
              Text(
                songTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
