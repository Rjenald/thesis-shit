import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../data/tagalog_bisaya_songs.dart';
import '../screens/karaoke_recording_page.dart';

class KaraokeHomePage extends StatefulWidget {
  const KaraokeHomePage({super.key});

  @override
  State<KaraokeHomePage> createState() => _KaraokeHomePageState();
}

class _KaraokeHomePageState extends State<KaraokeHomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedLanguage = 'All';

  List<KaraokeSong> get _filtered {
    final allSongs = TagalogBisayaSongs.songs;

    if (_query.trim().isEmpty && _selectedLanguage == 'All') {
      return allSongs.toList();
    }

    final q = _query.toLowerCase();
    return allSongs
        .where((s) {
          final matchesQuery = q.isEmpty ||
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q);
          final matchesLanguage = _selectedLanguage == 'All' ||
              s.language == _selectedLanguage;
          return matchesQuery && matchesLanguage;
        })
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

  void _launchKaraoke(KaraokeSong song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KaraokeRecordingPage(
          songTitle: song.title,
          songArtist: song.artist,
          songImage: '',
        ),
      ),
    );
  }

  void _showSongOptions(KaraokeSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      song.language,
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchKaraoke(song);
                },
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('Start Karaoke'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${results.length}/${TagalogBisayaSongs.getTotalSongs()}',
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
                    hintText: 'Search songs or artist...',
                    hintStyle: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontFamily: 'Roboto',
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.grey.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Language Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _buildLanguageChip('All', _selectedLanguage == 'All'),
                  const SizedBox(width: 8),
                  _buildLanguageChip('Tagalog', _selectedLanguage == 'Tagalog'),
                  const SizedBox(width: 8),
                  _buildLanguageChip('Bisaya', _selectedLanguage == 'Bisaya'),
                ],
              ),
            ),

            // Song List
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.6),
                          fontFamily: 'Roboto',
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final song = results[index];
                        return GestureDetector(
                          onTap: () => _showSongOptions(song),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.inputBg,
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryCyan
                                            .withValues(alpha: 0.3),
                                        AppColors.primaryCyan
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.music_note,
                                    color: AppColors.primaryCyan,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Roboto',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song.artist,
                                        style: TextStyle(
                                          color: AppColors.grey.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 12,
                                          fontFamily: 'Roboto',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: song.language == 'Tagalog'
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Colors.purple.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    song.language == 'Tagalog' ? 'TGL' : 'BIS',
                                    style: TextStyle(
                                      color: song.language == 'Tagalog'
                                          ? Colors.blue[300]
                                          : Colors.purple[300],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.grey.withValues(
                                    alpha: 0.5,
                                  ),
                                  size: 14,
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
        onTap: (_) {},
      ),
    );
  }

  Widget _buildLanguageChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }
}
