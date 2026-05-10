import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../services/downloads_service.dart';
import '../services/youtube_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'karaoke_recording_page.dart';

class KaraokeHomePage extends StatefulWidget {
  const KaraokeHomePage({super.key});

  @override
  State<KaraokeHomePage> createState() => _KaraokeHomePageState();
}

class _KaraokeHomePageState extends State<KaraokeHomePage> {
  final TextEditingController _searchCtrl = TextEditingController();

  // ── View mode ──────────────────────────────────────────────────────────────
  /// 'search' = YouTube results  |  'downloaded' = saved songs
  String _mode = 'search';

  // ── YouTube search state ───────────────────────────────────────────────────
  List<Map<String, String>> _results   = [];
  bool                      _searching = false;
  bool                      _searched  = false;   // true once user hit Search
  Timer?                    _debounce;

  // ── Downloaded songs ───────────────────────────────────────────────────────
  List<Map<String, String>> _downloads = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final list = await DownloadsService.loadAll();
    if (mounted) setState(() => _downloads = list);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results  = [];
        _searched = false;
      });
      return;
    }
    // Auto-search after 700 ms of no typing
    _debounce = Timer(const Duration(milliseconds: 700), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    final results = await YouTubeService.searchKaraokeVideos(query: query.trim());
    if (!mounted) return;
    setState(() {
      _results   = results;
      _searching = false;
      _searched  = true;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _launchKaraoke(Map<String, String> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KaraokeRecordingPage(
          songTitle:      video['title']   ?? '',
          songArtist:     video['channel'] ?? '',
          songImage:      video['thumbnail'] ?? '',
          youtubeVideoId: video['videoId'] ?? '',
        ),
      ),
    );
  }

  void _launchDownloaded(Map<String, String> song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KaraokeRecordingPage(
          songTitle:  song['title']  ?? '',
          songArtist: song['artist'] ?? '',
          songImage:  '',
        ),
      ),
    );
  }

  void _shareVideo(Map<String, String> video) {
    final text =
        '🎤 "${video['title']}" on Huni Karaoke!\n'
        'Watch: https://www.youtube.com/watch?v=${video['videoId']}\n\n'
        'Shared via Huni Karaoke App 🎵';
    Share.share(text, subject: video['title'] ?? 'Karaoke Song');
  }

  Future<void> _removeDownload(Map<String, String> song) async {
    await DownloadsService.remove(song['title'] ?? '', song['artist'] ?? '');
    _loadDownloads();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${song['title']}" removed from downloads'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cardBg,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildModeTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, onTap: (_) {}),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Karaoke',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
                fontFamily: 'Roboto'),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                    color: AppColors.white, fontFamily: 'Roboto'),
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  setState(() {}); // refresh clear button
                  _onSearchChanged(v);
                },
                onSubmitted: (v) => _runSearch(v),
                decoration: InputDecoration(
                  hintText: 'Search karaoke songs...',
                  hintStyle: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.6),
                      fontFamily: 'Roboto'),
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.grey.withValues(alpha: 0.6)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _results  = [];
                              _searched = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _runSearch(_searchCtrl.text),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search, color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode tabs ──────────────────────────────────────────────────────────────

  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _modeTab('search',     Icons.youtube_searched_for, 'Search'),
          const SizedBox(width: 8),
          _modeTab('downloaded', Icons.download_done_rounded, 'Downloaded'),
        ],
      ),
    );
  }

  Widget _modeTab(String mode, IconData icon, String label) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = mode);
        if (mode == 'downloaded') _loadDownloads();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primaryCyan
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.black : AppColors.white),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.black : AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_mode == 'downloaded') return _buildDownloadedList();
    return _buildSearchBody();
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchBody() {
    if (_searching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 14),
            Text('Searching YouTube…',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    if (!_searched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_external_on_outlined,
                color: AppColors.grey.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            Text('Search for a karaoke song',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 6),
            Text('Type a song name or artist above',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                color: AppColors.grey.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text('No karaoke videos found',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, i) => _buildVideoCard(_results[i]),
    );
  }

  Widget _buildVideoCard(Map<String, String> video) {
    final thumb = video['thumbnail'] ?? '';
    return GestureDetector(
      onTap: () => _launchKaraoke(video),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: 110,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),

            // ── Info ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video['channel'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontFamily: 'Roboto'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Actions ────────────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play / sing
                IconButton(
                  icon: const Icon(Icons.mic,
                      color: AppColors.primaryCyan, size: 22),
                  tooltip: 'Sing',
                  onPressed: () => _launchKaraoke(video),
                ),
                // Share
                IconButton(
                  icon: Icon(Icons.share_outlined,
                      color: AppColors.grey.withValues(alpha: 0.6),
                      size: 18),
                  tooltip: 'Share',
                  onPressed: () => _shareVideo(video),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 110,
        height: 72,
        color: AppColors.cardBg,
        child: const Icon(Icons.music_video_outlined,
            color: AppColors.primaryCyan, size: 28),
      );

  // ── Downloaded list ────────────────────────────────────────────────────────

  Widget _buildDownloadedList() {
    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined,
                color: AppColors.grey.withValues(alpha: 0.3), size: 56),
            const SizedBox(height: 16),
            Text('No downloaded songs yet',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 6),
            Text('Songs auto-save here after you finish singing',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _downloads.length,
      itemBuilder: (context, i) => _buildDownloadedRow(_downloads[i]),
    );
  }

  Widget _buildDownloadedRow(Map<String, String> song) {
    return GestureDetector(
      onTap: () => _launchDownloaded(song),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
              width: 0.5),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(colors: [
                  AppColors.primaryCyan.withValues(alpha: 0.3),
                  AppColors.primaryCyan.withValues(alpha: 0.1),
                ]),
              ),
              child: const Icon(Icons.music_note,
                  color: AppColors.primaryCyan, size: 20),
            ),
            const SizedBox(width: 12),

            // Title + Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song['title'] ?? '',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song['artist'] ?? '',
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Roboto'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),

            // Language badge
            if ((song['language'] ?? '').isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _langLabel(song['language'] ?? ''),
                  style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 4),

            // Remove download
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.withValues(alpha: 0.7), size: 20),
              tooltip: 'Remove',
              onPressed: () => _removeDownload(song),
            ),

            // Play/sing
            IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.mic,
                  color: AppColors.primaryCyan, size: 22),
              tooltip: 'Sing',
              onPressed: () => _launchDownloaded(song),
            ),
          ],
        ),
      ),
    );
  }

  String _langLabel(String language) {
    switch (language) {
      case 'Tagalog': return 'TGL';
      case 'Bisaya':  return 'BIS';
      default:        return 'ENG';
    }
  }
}
