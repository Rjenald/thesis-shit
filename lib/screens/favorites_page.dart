import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/favorites_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'karaoke_recording_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, String>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final list = await FavoritesService.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = list;
      _loading = false;
    });
  }

  Future<void> _removeFavorite(String title) async {
    await FavoritesService.removeFavorite(title);
    setState(() => _favorites.removeWhere((s) => s['title'] == title));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title removed from favorites'),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _openSong(Map<String, String> song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KaraokeRecordingPage(
          songTitle: song['title'] ?? '',
          songArtist: song['artist'] ?? '',
          songImage: song['image'] ?? '',
          songYtId: song['ytId'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  Text(
                    '${_favorites.length} songs',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryCyan, strokeWidth: 2))
                  : _favorites.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),

            BottomNavBar(
              currentIndex: 0,
              onTap: (i) {
                if (i != 0) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border,
              color: AppColors.grey.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          const Text('No favorites yet',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto')),
          const SizedBox(height: 8),
          Text('Tap ♡ on any song in Karaoke\nto add it here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontFamily: 'Roboto',
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final song = _favorites[index];
        return Dismissible(
          key: Key(song['title'] ?? '$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          onDismissed: (_) => _removeFavorite(song['title'] ?? ''),
          child: GestureDetector(
            onTap: () => _openSong(song),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (song['image'] ?? '').isNotEmpty
                        ? Image.network(
                            song['image']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song['title'] ?? '',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'Roboto'),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(song['artist'] ?? '',
                            style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Roboto')),
                      ],
                    ),
                  ),
                  // Date added
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(song['date'] ?? '',
                          style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontFamily: 'Roboto')),
                      const SizedBox(height: 4),
                      const Icon(Icons.play_circle_outline,
                          color: AppColors.primaryCyan, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        width: 50,
        height: 50,
        color: AppColors.cardBg,
        child: const Icon(Icons.music_note,
            color: AppColors.grey, size: 22),
      );
}
