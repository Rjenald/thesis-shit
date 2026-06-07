import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/song_audio_service.dart';
import '../../services/song_catalog_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'song_player_page.dart';

/// Song catalog page for "With Karaoke" recording.
/// Shows search bar + full song list — like the home page but without profile.
class KaraokeSongCatalogPage extends StatefulWidget {
  const KaraokeSongCatalogPage({super.key});

  @override
  State<KaraokeSongCatalogPage> createState() =>
      _KaraokeSongCatalogPageState();
}

class _KaraokeSongCatalogPageState extends State<KaraokeSongCatalogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  Timer? _debounce;

  // Show popular songs by default
  List<Map<String, String>> _popularSongs = [];

  @override
  void initState() {
    super.initState();
    _loadPopularSongs();
  }

  void _loadPopularSongs() {
    // Show songs that have audio available as "popular" / featured
    final all = SongCatalogService.search('');
    // Prioritize songs with audio
    final withAudio =
        all.where((s) => SongAudioService.hasAudio(s['title'] ?? '')).toList();
    final withoutAudio =
        all.where((s) => !SongAudioService.hasAudio(s['title'] ?? '')).toList();
    _popularSongs = [...withAudio, ...withoutAudio];
    if (_popularSongs.length > 50) {
      _popularSongs = _popularSongs.sublist(0, 50);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        final results = SongCatalogService.search(value.trim());
        if (mounted) setState(() => _searchResults = results);
      },
    );
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  void _openSong(Map<String, String> song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongPlayerPage(
          songTitle: song['title'] ?? '',
          songArtist: song['artist'] ?? '',
          songImage: song['image'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildSongList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, onTap: (_) {}),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Karaoke',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              Text(
                'Choose a song to sing',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
        decoration: InputDecoration(
          hintText: 'Search songs or artists...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontFamily: 'Roboto',
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          suffixIcon: _isSearching
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchResults = []);
                    FocusScope.of(context).unfocus();
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No songs found',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) => _buildSongRow(_searchResults[i]),
    );
  }

  Widget _buildSongList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'Songs',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _popularSongs.length,
            itemBuilder: (ctx, i) => _buildSongRow(_popularSongs[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSongRow(Map<String, String> song) {
    final image = song['image'] ?? '';
    final hasAudio = SongAudioService.hasAudio(song['title'] ?? '');

    return GestureDetector(
      onTap: () => _openSong(song),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _songPlaceholder(),
                    )
                  : _songPlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song['artist'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasAudio)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, color: AppColors.primaryCyan, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Audio',
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: Icon(
                hasAudio ? Icons.play_circle_filled : Icons.mic,
                color: AppColors.primaryCyan,
                size: 22,
              ),
              tooltip: hasAudio ? 'Play' : 'Sing',
              onPressed: () => _openSong(song),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _songPlaceholder() => Container(
        width: 70,
        height: 70,
        color: const Color(0xFF1E1E1E),
        child: const Icon(
          Icons.music_note,
          color: AppColors.primaryCyan,
          size: 26,
        ),
      );
}
