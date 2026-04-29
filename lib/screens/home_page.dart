import 'package:final_thesis_ui/screens/education_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/session_storage_service.dart';
import '../services/songs_service.dart';
import '../services/class_notifications_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'favorites_page.dart';
import 'library_page.dart';
import 'record_selection_page.dart';
import 'settings_page.dart';
import 'recently_deleted_page.dart';
import 'start_page.dart';
import 'karaoke_song_detail_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  final bool showBackButton;
  const HomePage({super.key, this.showBackButton = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  String _username = 'User';
  String _searchQuery = '';
  bool _isStudent = true;

  // ── Songs (loaded async from backend, falls back to local) ─────────────────
  List<Map<String, String>> _songs = const [];
  bool _songsLoading = true;

  List<Map<String, String>> get _filtered {
    if (_searchQuery.isEmpty) return _songs;
    final q = _searchQuery.toLowerCase();
    return _songs
        .where(
          (s) =>
              (s['title'] ?? '').toLowerCase().contains(q) ||
              (s['artist'] ?? '').toLowerCase().contains(q) ||
              (s['language'] ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadRole();
    _loadSongs();
    _initializeNotifications();
  }

  Future<void> _loadUsername() async {
    final name = await SessionStorageService.loadUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _username = name);
    }
  }

  Future<void> _loadRole() async {
    final role = await SessionStorageService.loadRole();
    if (mounted) {
      setState(() => _isStudent = role == 'student');
    }
  }

  Future<void> _initializeNotifications() async {
    final service = ClassNotificationsService();
    await service.initialize();
  }

  Future<void> _loadSongs() async {
    final list = await SongsService.fetchSongs();
    if (mounted) {
      setState(() {
        _songs = list;
        _songsLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LibraryPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordSelectionPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EducationModePage()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
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
                                  color: AppColors.inputBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: AppColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Karaoke',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              Text(
                                'Welcome, $_username',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey.withValues(alpha: 0.7),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isStudent)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Stack(
                                  children: [
                                    Icon(
                                      Icons.notifications_outlined,
                                      color: AppColors.grey,
                                      size: 24,
                                    ),
                                    Consumer<ClassNotificationsService>(
                                      builder: (context, service, child) {
                                        final unread = service.unreadCount;
                                        if (unread > 0) {
                                          return Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unread > 9
                                                      ? '9+'
                                                      : unread.toString(),
                                                  style:
                                                      const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontFamily: 'Roboto',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isMenuOpen = !_isMenuOpen),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.inputBg,
                              child: Text(
                                _username.isNotEmpty
                                    ? _username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: AppColors.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search songs, artist…',
                        hintStyle: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.6),
                          fontFamily: 'Roboto',
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.grey,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppColors.grey,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
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

                // Song count + source indicator
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _songsLoading
                            ? 'Loading songs…'
                            : '${_filtered.length} songs',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_songsLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (SongsService.isFromBackend
                                        ? AppColors.primaryCyan
                                        : AppColors.grey)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                SongsService.isFromBackend
                                    ? Icons.cloud_done_outlined
                                    : Icons.offline_bolt_outlined,
                                size: 10,
                                color: SongsService.isFromBackend
                                    ? AppColors.primaryCyan
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                SongsService.isFromBackend
                                    ? 'Backend'
                                    : 'Offline',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Roboto',
                                  color: SongsService.isFromBackend
                                      ? AppColors.primaryCyan
                                      : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Song List
                Expanded(
                  child: _songsLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryCyan,
                            strokeWidth: 2,
                          ),
                        )
                      : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No songs match "$_searchQuery"'
                                : 'No songs available',
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.5),
                              fontFamily: 'Roboto',
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            return _buildSongItem(_filtered[index]);
                          },
                        ),
                ),
              ],
            ),

            // Profile Menu Overlay
            if (_isMenuOpen)
              GestureDetector(
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
                            // User Info
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
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _username,
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                        Text(
                                          'View Profile',
                                          style: TextStyle(
                                            color: AppColors.grey.withValues(
                                              alpha: 0.8,
                                            ),
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
                            const Divider(color: AppColors.inputBg, height: 1),
                            _buildMenuItem(Icons.favorite_border, 'Favorites'),
                            _buildMenuItem(Icons.settings_outlined, 'Settings'),
                            _buildMenuItem(
                              Icons.delete_outline,
                              'Recently Deleted',
                            ),
                            _buildMenuItem(
                              Icons.logout,
                              'Logout',
                              isLogout: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        isStudent: _isStudent,
      ),
    );
  }

  Widget _buildSongItem(Map<String, String> song) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => KaraokeSongDetailPage(
                songTitle: song['title']!,
                songArtist: song['artist']!,
                songImage: song['image'] ?? '',
                youtubeId: song['youtubeId'] ?? '',
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: SizedBox(
              width: 48,
              height: 48,
              child: ClipOval(
                child: Image.network(
                  song['image']!,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    color: AppColors.inputBg,
                    child: const Icon(
                      Icons.music_note,
                      color: AppColors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              song['title']!,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  song['artist']!,
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(width: 8),
                if (song['language'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      song['language']!,
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 10,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(
              Icons.play_circle_outline,
              color: AppColors.grey,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? AppColors.errorRed : AppColors.white,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isLogout ? AppColors.errorRed : AppColors.white,
          fontFamily: 'Roboto',
          fontSize: 14,
        ),
      ),
      dense: true,
      onTap: () async {
        setState(() => _isMenuOpen = false);
        if (isLogout) {
          await SessionStorageService.saveUsername('');
          await SessionStorageService.saveRole('');
          if (!context.mounted) return;
          // ignore: use_build_context_synchronously
          final nav = Navigator.of(context);
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const StartPage()),
            (route) => false,
          );
        } else if (label == 'Favorites') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          );
        } else if (label == 'Settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        } else if (label == 'Recently Deleted') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecentlyDeletedPage()),
          );
        }
      },
    );
  }
}
