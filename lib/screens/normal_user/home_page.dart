import 'dart:async';
import 'package:final_thesis_ui/screens/normal_user/education_mode_page.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/session_result.dart';
import '../../services/session_storage_service.dart';
import '../../services/song_audio_service.dart';
import '../../services/song_catalog_service.dart';
import '../../services/class_notifications_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/profile_avatar.dart';
import 'favorites_page.dart';
import 'library_page.dart';
import 'song_player_page.dart';
import 'settings_page.dart';
import 'recently_deleted_page.dart';
import '../shared/start_page.dart';

class HomePage extends StatefulWidget {
  final bool showBackButton;
  const HomePage({
    super.key,
    this.showBackButton = false,
    required bool forceNormalUser,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Profile ────────────────────────────────────────────────────────────────
  String _username = 'User';
  bool _isMenuOpen = false;

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  Timer? _debounce;

  // ── Recent sessions ────────────────────────────────────────────────────────
  List<SessionResult> _recent = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadRecent();
    _initNotifications();
  }

  Future<void> _loadUsername() async {
    final name = await SessionStorageService.loadUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _username = name);
    }
  }

  Future<void> _loadRecent() async {
    final sessions = await SessionStorageService.loadSessions();
    if (mounted) setState(() => _recent = sessions);
  }

  Future<void> _initNotifications() async {
    await ClassNotificationsService().initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Search logic ───────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(value),
    );
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) return;
    final results = SongCatalogService.search(query.trim());
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LibraryPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EducationModePage()),
      );
    } else {
      setState(() {});
    }
  }

  void _openSong(Map<String, String> song) {
    final title = song['title'] ?? '';
    final artist = song['artist'] ?? '';
    final image = song['image'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongPlayerPage(
          songTitle: title,
          songArtist: artist,
          songImage: image,
        ),
      ),
    );
  }

  void _openSession(SessionResult s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongPlayerPage(
          songTitle: s.songTitle,
          songArtist: s.songArtist,
          songImage: s.songImage,
        ),
      ),
    );
  }

  Future<void> _deleteSession(SessionResult s) async {
    final sessions = await SessionStorageService.loadSessions();
    final idx = sessions.indexWhere(
      (e) =>
          e.songTitle == s.songTitle &&
          e.songArtist == s.songArtist &&
          e.completedAt == s.completedAt,
    );
    if (idx >= 0) await SessionStorageService.deleteSession(idx);
    _loadRecent();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: _isSearching ? _buildSearchBody() : _buildRecentBody(),
                ),
              ],
            ),
            if (_isMenuOpen) _buildMenuOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 0, onTap: _onItemTapped),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: back button (optional) + title
          Row(
            children: [
              if (widget.showBackButton) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Karaoke',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  Text(
                    'Welcome, $_username',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: notifications + profile avatar
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
                child: ProfileAvatar(username: _username, radius: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: _runSearch,
          decoration: InputDecoration(
            hintText: 'Search for songs, artist...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchResults = [];
                      });
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
    );
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchBody() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No songs found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) => _buildSongCard(_searchResults[i]),
    );
  }

  Widget _buildSongCard(Map<String, String> song) {
    final image = song['image'] ?? '';
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
            if (SongAudioService.hasAudio(song['title'] ?? ''))
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
                    Icon(
                      Icons.volume_up,
                      color: AppColors.primaryCyan,
                      size: 12,
                    ),
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
                SongAudioService.hasAudio(song['title'] ?? '')
                    ? Icons.play_circle_filled
                    : Icons.mic,
                color: AppColors.primaryCyan,
                size: 22,
              ),
              tooltip: SongAudioService.hasAudio(song['title'] ?? '')
                  ? 'Play'
                  : 'Sing',
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
    child: const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 26),
  );

  // ── Recently visited ───────────────────────────────────────────────────────

  Widget _buildRecentBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recently Visited',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              if (_recent.isNotEmpty)
                Text(
                  '${_recent.length} sessions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _recent.isEmpty
              ? _buildEmptyRecent()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _recent.length,
                  itemBuilder: (ctx, i) => _buildRecentRow(_recent[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyRecent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            color: Colors.white.withValues(alpha: 0.15),
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            'No recent sessions yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search a song above and start singing!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRow(SessionResult s) {
    final date =
        '${s.completedAt.month.toString().padLeft(2, '0')}-'
        '${s.completedAt.day.toString().padLeft(2, '0')}-'
        '${s.completedAt.year.toString().substring(2)}';

    return GestureDetector(
      onTap: () => _openSession(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          children: [
            // Circle image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E),
                image: s.songImage.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(s.songImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: s.songImage.isEmpty
                  ? const Icon(
                      Icons.music_note,
                      color: AppColors.primaryCyan,
                      size: 22,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.songArtist,
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

            // Date
            Text(
              date,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 8),

            // Delete
            GestureDetector(
              onTap: () => _deleteSession(s),
              child: Icon(
                Icons.delete_outline,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile menu overlay ───────────────────────────────────────────────────

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 72, right: 16),
            child: Container(
              width: 210,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ProfileAvatar(username: _username, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              Text(
                                'View Profile',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                  _menuItem(
                    Icons.favorite_border,
                    'Favorites',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesPage()),
                    ),
                  ),
                  _menuItem(
                    Icons.settings_outlined,
                    'Settings',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                  _menuItem(
                    Icons.delete_outline,
                    'Recently Deleted',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecentlyDeletedPage(),
                      ),
                    ),
                  ),
                  _menuItem(Icons.logout, 'Logout', () async {
                    await SessionStorageService.saveUsername('');
                    await SessionStorageService.saveRole('');
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const StartPage()),
                      (r) => false,
                    );
                  }, isLogout: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? Colors.red : Colors.white,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isLogout ? Colors.red : Colors.white,
          fontSize: 14,
          fontFamily: 'Roboto',
        ),
      ),
      dense: true,
      onTap: () {
        setState(() => _isMenuOpen = false);
        onTap();
      },
    );
  }
}
