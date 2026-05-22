import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/favorites_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'library_page.dart';
import 'record_selection_page.dart';

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
    if (mounted) {
      setState(() {
        _favorites = list;
        _loading = false;
      });
    }
  }

  Future<void> _removeSong(int index) async {
    final title = _favorites[index]['title'] ?? '';
    await FavoritesService.removeFavorite(title);
    await _loadFavorites();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LibraryPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordSelectionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 26,
                    ),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent',
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: Colors.white.withValues(alpha: 0.15),
                            size: 56,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No favorites yet',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 15,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Songs you favorite will appear here',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        return _buildFavoriteItem(_favorites[index], index);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 0, onTap: _onItemTapped),
    );
  }

  Widget _buildFavoriteItem(Map<String, String> song, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipOval(
            child: (song['image'] ?? '').isNotEmpty
                ? Image.network(
                    song['image']!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey,
                        child: const Icon(Icons.music_note, color: Colors.white),
                      );
                    },
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF1E1E1E),
                    child: const Icon(
                      Icons.music_note,
                      color: AppColors.primaryCyan,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song['title'] ?? '',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song['artist'] ?? '',
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          Text(
            song['date'] ?? '',
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.grey,
              size: 22,
            ),
            onPressed: () => _removeSong(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
