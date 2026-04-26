import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'library_page.dart';
import 'record_selection_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final List<Map<String, String>> favoriteSongs = [
    {
      'title': 'Dadalhin',
      'artist': 'Regine Velasquez',
      'image':
          'https://media.philstar.com/photos/2022/04/19/regine-1_2022-04-19_17-19-51.jpg',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Paalam Muna Sandali',
      'artist': 'Darren Espanto',
      'image':
          'https://tse4.mm.bing.net/th/id/OIP.X4OeqoB_8615vepJpu2zdQHaE7?rs=1&pid=ImgDetMain&o=7&rm=3',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Nasa Iyo Na Ang Lahat',
      'artist': 'Daniel Padilla',
      'image':
          'https://images.genius.com/e817d67292e5c1ac1e72b0c8573161e5.900x900x1.jpg',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Ulap',
      'artist': 'Rob Daniel',
      'image':
          'https://tse3.mm.bing.net/th/id/OIP.4AnzA3S0-AUEBFjst492KwAAAA?rs=1&pid=ImgDetMain&o=7&rm=3',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Fallen',
      'artist': 'Lola Amour',
      'image':
          'https://images.genius.com/b62c08396330faf55dae7e6a73b26324.1000x1000x1.png',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Binibini',
      'artist': 'Arthur Nery',
      'image':
          'https://i.pinimg.com/736x/c4/51/fd/c451fd1b67b8e80830aaca56188e46d8.jpg',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Kumpas',
      'artist': 'Moira Dela Torre',
      'image':
          'https://tse2.mm.bing.net/th/id/OIP.2Uaip4XK2mxVqOEL_zu4cAHaFj?rs=1&pid=ImgDetMain&o=7&rm=3',
      'date': '10-30-26', // ADDED
    },
    {
      'title': 'Randomantic',
      'artist': 'james reid',
      'image':
          'https://images.genius.com/f428806fd40d83f4a6f934680bdbd7e8.1000x1000x1.jpg',
      'date': '10-30-26', // ADDED
    },
  ];

  void _removeSong(int index) {
    setState(() {
      favoriteSongs.removeAt(index);
    });
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
            // Header
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
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: AppColors.white,
                      size: 28,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Recent Label
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

            // Favorites List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: favoriteSongs.length,
                itemBuilder: (context, index) {
                  return _buildFavoriteItem(favoriteSongs[index], index);
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
            child: Image.network(
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
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song['title']!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song['artist']!,
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
            song['date'] ?? '', // SAFER: use ?? '' instead of !
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
