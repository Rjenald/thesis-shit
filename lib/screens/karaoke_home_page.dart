import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'education_mode_page.dart';
import 'karaoke_song_detail_page.dart';

class KaraokeHomePage extends StatefulWidget {
  const KaraokeHomePage({super.key});

  @override
  State<KaraokeHomePage> createState() => _KaraokeHomePageState();
}

class _KaraokeHomePageState extends State<KaraokeHomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<Map<String, String>> _songs = [
    {
      'title': 'Dadalhin',
      'artist': 'Regine Velasquez',
      'image': 'https://media.philstar.com/photos/2022/04/19/regine-1_2022-04-19_17-19-51.jpg',
      'youtubeId': '_MoKs-VTBrE',
    },
    {
      'title': 'Ikaw',
      'artist': 'Yeng Constantino',
      'image': 'https://upload.wikimedia.org/wikipedia/en/b/b4/Yeng_Constantino_-_Ikaw_%28Yeng_Version%29.jpg',
      'youtubeId': 'HX1RHRQfYvo',
    },
    {
      'title': 'Kahit Maputi Na Ang Buhok Ko',
      'artist': 'Rey Valera',
      'image': 'https://i.ytimg.com/vi/UxAX0RjxBeM/maxresdefault.jpg',
      'youtubeId': 'UxAX0RjxBeM',
    },
    {
      'title': 'Narda',
      'artist': 'Kamikazee',
      'image': 'https://i.ytimg.com/vi/L8MzUHxAimI/maxresdefault.jpg',
      'youtubeId': 'L8MzUHxAimI',
    },
    {
      'title': 'Hawak Kamay',
      'artist': 'Yeng Constantino',
      'image': 'https://i.ytimg.com/vi/K4z7JFfW9b4/maxresdefault.jpg',
      'youtubeId': 'K4z7JFfW9b4',
    },
    {
      'title': 'Pare Ko',
      'artist': 'Eraserheads',
      'image': 'https://i.ytimg.com/vi/ZeO4kW4j3tI/maxresdefault.jpg',
      'youtubeId': 'ZeO4kW4j3tI',
    },
    {
      'title': 'Pag-ibig',
      'artist': 'Kyla',
      'image': 'https://i.ytimg.com/vi/JFsHZ24CQZM/maxresdefault.jpg',
      'youtubeId': 'JFsHZ24CQZM',
    },
    {
      'title': 'Magmahal Muli',
      'artist': 'Martin Nievera',
      'image': 'https://i.ytimg.com/vi/4K6X8b0v-5A/maxresdefault.jpg',
      'youtubeId': '4K6X8b0v-5A',
    },
    {
      'title': 'Paalam Muna Sandali',
      'artist': 'Darren Espanto',
      'image': 'https://tse4.mm.bing.net/th/id/OIP.X4OeqoB_8615vepJpu2zdQHaE7?rs=1&pid=ImgDetMain&o=7&rm=3',
      'youtubeId': '9D_a8PUFwAo',
    },
    {
      'title': 'Nasa Iyo Na Ang Lahat',
      'artist': 'Daniel Padilla',
      'image': 'https://images.genius.com/e817d67292e5c1ac1e72b0c8573161e5.900x900x1.jpg',
      'youtubeId': 'vXg_JzLSgTk',
    },
    {
      'title': 'Ulap',
      'artist': 'Rob Daniel',
      'image': 'https://i.ytimg.com/vi/xNbRkbMFW08/maxresdefault.jpg',
      'youtubeId': 'xNbRkbMFW08',
    },
    {
      'title': 'Fallen',
      'artist': 'Lola Amour',
      'image': 'https://images.genius.com/b62c08396330faf55dae7e6a73b26324.1000x1000x1.png',
      'youtubeId': 'JB4pWkCHEhM',
    },
    {
      'title': 'Binibini',
      'artist': 'Arthur Nery',
      'image': 'https://i.pinimg.com/736x/c4/51/fd/c451fd1b67b8e80830aaca56188e46d8.jpg',
      'youtubeId': 'l6rZoNzxXdg',
    },
    {
      'title': 'Kumpas',
      'artist': 'Moira Dela Torre',
      'image': 'https://i.ytimg.com/vi/QJqpVLHQFM8/maxresdefault.jpg',
      'youtubeId': 'QJqpVLHQFM8',
    },
    {
      'title': 'Randomantic',
      'artist': 'James Reid',
      'image': 'https://images.genius.com/f428806fd40d83f4a6f934680bdbd7e8.1000x1000x1.jpg',
      'youtubeId': 't2EMVo9RVR0',
    },
  ];

  List<Map<String, String>> get _filtered {
    if (_query.trim().isEmpty) return _songs;
    final q = _query.toLowerCase();
    return _songs
        .where(
          (s) =>
              s['title']!.toLowerCase().contains(q) ||
              s['artist']!.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

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
                      Icons.arrow_back_ios,
                      color: AppColors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Karaoke',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontFamily: 'Roboto',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for songs, artist',
                    hintStyle: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontFamily: 'Roboto',
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.grey.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Song List
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final song = results[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KaraokeSongDetailPage(
                                  songTitle: song['title']!,
                                  songArtist: song['artist']!,
                                  songImage: song['image']!,
                                  youtubeId: song['youtubeId']!,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song['image']!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.grey.withValues(
                                        alpha: 0.3,
                                      ),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song['title']!,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Roboto',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song['artist']!,
                                        style: TextStyle(
                                          color: AppColors.grey.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 13,
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.mic_none_rounded,
                                  color: AppColors.primaryCyan,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LibraryPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EducationModePage()),
            );
          }
        },
      ),
    );
  }
}
