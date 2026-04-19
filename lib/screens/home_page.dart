import 'package:final_thesis_ui/screens/education_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';
import '../data/songs_data.dart';
import '../services/session_storage_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'favorites_page.dart';
import 'library_page.dart';
import 'record_selection_page.dart';
import 'settings_page.dart';
import 'recently_deleted_page.dart';
import 'welcome_screen.dart';
import 'karaoke_recording_page.dart';

// ── Category definitions ──────────────────────────────────────────────────────
const _kCategories = [
  {'label': 'Rock Music',  'match': 'rock'},
  {'label': 'R&B Soul',    'match': 'rnb'},
  {'label': 'Pop',         'match': 'pop'},
  {'label': 'Country',     'match': 'country'},
  {'label': 'OPM',         'match': 'opm'},
  {'label': 'Classical',   'match': 'classical'},
];

class HomePage extends StatefulWidget {
  final bool showBackButton;
  const HomePage({super.key, this.showBackButton = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex   = 0;
  bool _isMenuOpen     = false;
  String _username     = 'User';
  String _searchQuery  = '';
  String? _category;   // null = show all

  final List<Map<String, String>> songs = kAllSongs;

  // ── Filtering ───────────────────────────────────────────────────────────────

  List<Map<String, String>> get _filtered {
    var list = songs;

    // Category filter
    if (_category != null) {
      final cat = _category!.toLowerCase();
      list = list.where((s) {
        final title    = (s['title']   ?? '').toLowerCase();
        final artist   = (s['artist']  ?? '').toLowerCase();
        final language = (s['language'] ?? '').toLowerCase();
        switch (cat) {
          case 'opm':
            return language == 'tagalog' || language == 'bisaya';
          case 'rock music':
            return title.contains('rock') ||
                   artist.contains('rock') ||
                   artist.contains('eraserheads') ||
                   artist.contains('rivermaya') ||
                   artist.contains('wolfgang') ||
                   artist.contains('razorback');
          case 'r&b soul':
            return artist.contains('r&b') ||
                   artist.contains('soul') ||
                   artist.contains('kyla') ||
                   artist.contains('jaya') ||
                   artist.contains('nina');
          case 'pop':
            return language == 'tagalog' &&
                   !artist.contains('rock') &&
                   !artist.contains('eraserheads');
          case 'country':
            return title.contains('country') || artist.contains('country');
          case 'classical':
            return title.contains('classic') || artist.contains('classic');
          default:
            return true;
        }
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((s) =>
              (s['title']    ?? '').toLowerCase().contains(q) ||
              (s['artist']   ?? '').toLowerCase().contains(q) ||
              (s['language'] ?? '').toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  bool get _showCategories =>
      _searchQuery.isEmpty && _category == null;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await SessionStorageService.loadUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _username = name);
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LibraryPage()));
    } else if (index == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RecordSelectionPage()));
    } else if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EducationModePage()));
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmpty()
                      : CustomScrollView(
                          slivers: [
                            if (_showCategories) ...[
<<<<<<< HEAD
                              SliverToBoxAdapter(
                                child: _FeaturedVideoBanner(
                                  onSingTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => KaraokeRecordingPage(
                                        songTitle:
                                            'Lifetime (Reimagined)',
                                        songArtist: 'Ben&Ben',
                                        songImage: '',
                                        songYtId:
                                            'Lifetime Reimagined BenBen karaoke',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
                              _buildSectionLabel('Categories'),
                              _buildCategoriesGrid(),
                              _buildSectionLabel('Songs'),
                            ] else
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 14, 20, 6),
                                  child: Row(
                                    children: [
                                      if (_category != null) ...[
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _category = null),
                                          child: const Icon(
                                              Icons.arrow_back_ios_new,
                                              color: AppColors.primaryCyan,
                                              size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_category!,
                                            style: const TextStyle(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'Roboto')),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        '${_filtered.length} songs',
                                        style: TextStyle(
                                            color: AppColors.grey
                                                .withValues(alpha: 0.5),
                                            fontSize: 12,
                                            fontFamily: 'Roboto'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildSongRow(_filtered[index]),
                                childCount: _filtered.length,
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 16)),
                          ],
                        ),
                ),
              ],
            ),

            // Dropdown menu
            if (_isMenuOpen) _buildMenuOverlay(),
          ],
        ),
      ),
      bottomNavigationBar:
          BottomNavBar(currentIndex: _selectedIndex, onTap: _onItemTapped),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.inputBg, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Text('Karaoke',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto')),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.2),
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: AppColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(12)),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search for songs, artist',
            hintStyle: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.5),
                fontFamily: 'Roboto',
                fontSize: 14),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.grey, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: AppColors.grey, size: 18),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto')),
      ),
    );
  }

  // ── Categories grid ───────────────────────────────────────────────────────────

  Widget _buildCategoriesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final cat = _kCategories[i];
            return GestureDetector(
              onTap: () => setState(() => _category = cat['label']),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat['label']!,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Roboto'),
                ),
              ),
            );
          },
          childCount: _kCategories.length,
        ),
      ),
    );
  }

  // ── Song row ──────────────────────────────────────────────────────────────────

  Widget _buildSongRow(Map<String, String> song) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KaraokeRecordingPage(
            songTitle: song['title']!,
            songArtist: song['artist']!,
            songImage: song['image'] ?? '',
<<<<<<< HEAD
            songYtId: '${song['title']} ${song['artist']} karaoke',
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
          ),
        ),
      ),
      splashColor: AppColors.primaryCyan.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            // Thumbnail
            ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: (song['image'] ?? '').isNotEmpty
                    ? Image.network(
                        song['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song['title']!,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'Roboto'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song['artist']!,
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontFamily: 'Roboto'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Language tag
            if ((song['language'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  song['language']!,
                  style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontFamily: 'Roboto'),
                ),
              ),

            // Delete icon
            GestureDetector(
              onTap: () {},
              child: Icon(Icons.delete_outline,
                  color: AppColors.grey.withValues(alpha: 0.5), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.inputBg,
      child: const Icon(Icons.music_note, color: AppColors.grey, size: 22),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              color: AppColors.grey.withValues(alpha: 0.25), size: 56),
          const SizedBox(height: 12),
          Text('No songs found',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  // ── Menu overlay ──────────────────────────────────────────────────────────────

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 70, right: 16),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.inputBg,
                          child: Text(
                            _username.isNotEmpty
                                ? _username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: AppColors.primaryCyan,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_username,
                                  style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto')),
                              Text('View Profile',
                                  style: TextStyle(
                                      color:
                                          AppColors.grey.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontFamily: 'Roboto')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.inputBg, height: 1),
                  _buildMenuItem(Icons.favorite_border, 'Favorites'),
                  _buildMenuItem(Icons.settings_outlined, 'Settings'),
                  _buildMenuItem(Icons.delete_outline, 'Recently Deleted'),
                  _buildMenuItem(Icons.logout, 'Logout', isLogout: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label,
      {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon,
          color: isLogout ? AppColors.errorRed : AppColors.white, size: 20),
      title: Text(label,
          style: TextStyle(
              color: isLogout ? AppColors.errorRed : AppColors.white,
              fontFamily: 'Roboto',
              fontSize: 14)),
      dense: true,
      onTap: () {
        setState(() => _isMenuOpen = false);
        if (isLogout) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        } else if (label == 'Favorites') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()));
        } else if (label == 'Settings') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsPage()));
        } else if (label == 'Recently Deleted') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RecentlyDeletedPage()));
        }
      },
    );
  }
}

// ── Featured Video Banner ─────────────────────────────────────────────────────
// Autoplay-muted looping video card that sits above Categories on the home page.

class _FeaturedVideoBanner extends StatefulWidget {
  final VoidCallback onSingTap;
  const _FeaturedVideoBanner({required this.onSingTap});

  @override
  State<_FeaturedVideoBanner> createState() => _FeaturedVideoBannerState();
}

class _FeaturedVideoBannerState extends State<_FeaturedVideoBanner> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/videos/lifetime_benben.mp4')
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _initialized = true);
            _controller
              ..setLooping(true)
              ..setVolume(0) // autoplay muted (browser policy)
              ..play();
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video background ───────────────────────────────────────────
              if (_initialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                Container(
                  color: AppColors.cardBg,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryCyan, strokeWidth: 2),
                  ),
                ),

              // ── Dark gradient overlay (bottom-heavy) ───────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),

              // ── FEATURED badge (top-left) ──────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('FEATURED',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontFamily: 'Roboto')),
                ),
              ),

              // ── Mute toggle (top-right) ────────────────────────────────────
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // ── Song info + Sing button (bottom) ───────────────────────────
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Lifetime (Reimagined)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(0, 1))
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ben&Ben',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Sing button — solid cyan, matches home page chip style
                    GestureDetector(
                      onTap: widget.onSingTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryCyan.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, color: Colors.black, size: 16),
                            SizedBox(width: 5),
                            Text('Sing',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Roboto')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
