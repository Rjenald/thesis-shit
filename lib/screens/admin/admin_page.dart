import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/admin_media_service.dart';
import '../../services/ground_truth_service.dart';
import '../../services/session_storage_service.dart';
import '../../services/song_audio_service.dart';
import '../../services/song_catalog_service.dart';
import '../../services/song_search_stats_service.dart';
import '../shared/start_page.dart';
import 'transcription_eval_page.dart';

/// Admin-only screen for managing each song's backing track and ground-truth
/// melody. Reached only by logging in with admin credentials — there's no
/// route to it from the normal user flow.
///
/// Uploads are overrides stored outside the asset bundle (see
/// [AdminMediaService]): deleting an uploaded file for a bundled song
/// restores the one shipped with the app rather than leaving it unplayable.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _usingDefaultPassword = false;
  String? _busyTitle;

  /// Which songs really have their shipped files, by title.
  ///
  /// Resolved once rather than per build: an asset's presence can only be
  /// learned by loading it, and doing that inside build() for every song
  /// on every frame would load the whole catalog repeatedly. Absent from
  /// the map means "not checked yet", which the card shows as "Checking…"
  /// instead of guessing.
  final Map<String, bool> _bundledAudio = {};
  final Map<String, bool> _bundledGroundTruth = {};

  @override
  void initState() {
    super.initState();
    _checkPassword();
    _checkBundledMedia();
  }

  /// Asks the bundle what is actually there.
  ///
  /// This is the whole point of the screen — an admin needs to know which
  /// songs are missing a backing track or a reference melody — and it was
  /// answered from the catalog instead of the bundle, so every catalogued
  /// song reported "Built-in" whether or not a file existed.
  Future<void> _checkBundledMedia() async {
    for (final song in SongCatalogService.allSongs) {
      final title = song['title'] ?? '';
      if (title.isEmpty) continue;
      final audio = await SongAudioService.bundledAudioExists(title);
      final gt = await GroundTruthService.bundledGroundTruthExists(title);
      if (!mounted) return;
      setState(() {
        _bundledAudio[title] = audio;
        _bundledGroundTruth[title] = gt;
      });
    }
  }

  Future<void> _checkPassword() async {
    final isDefault = await SessionStorageService.adminIsUsingDefaultPassword();
    if (mounted) setState(() => _usingDefaultPassword = isDefault);
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Roboto')),
        backgroundColor: isError ? AppColors.errorRed : AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Uploads ───────────────────────────────────────────────────────────────

  Future<void> _uploadAudio(String title) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busyTitle = title);
    try {
      await AdminMediaService.saveAudio(title, File(path));
      _toast('Backing track updated for "$title".');
    } catch (e) {
      _toast('Could not save the MP3: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyTitle = null);
    }
  }

  Future<void> _uploadGroundTruth(String title) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busyTitle = title);
    try {
      await AdminMediaService.saveGroundTruth(title, File(path));
      _toast('Ground truth updated for "$title".');
    } on FormatException catch (e) {
      // Rejected before storing — a malformed melody would otherwise break
      // karaoke scoring silently for this song.
      _toast('Not a valid ground-truth file. ${e.message}', isError: true);
    } catch (e) {
      _toast('Could not save the ground truth: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyTitle = null);
    }
  }

  Future<void> _deleteAudio(String title, bool hasBundledFallback) async {
    final ok = await _confirm(
      'Delete uploaded MP3?',
      hasBundledFallback
          ? 'The backing track that ships with the app will be used again.'
          : '"$title" will have no backing track until a new one is uploaded.',
    );
    if (!ok) return;
    await AdminMediaService.deleteAudio(title);
    if (mounted) setState(() {});
    _toast('Uploaded MP3 deleted.');
  }

  Future<void> _deleteGroundTruth(String title, bool hasBundledFallback) async {
    final ok = await _confirm(
      'Delete uploaded ground truth?',
      hasBundledFallback
          ? 'The ground truth that ships with the app will be used again.'
          : 'Karaoke scoring for "$title" will fall back to pitch-only '
              'results until a new one is uploaded.',
    );
    if (!ok) return;
    await AdminMediaService.deleteGroundTruth(title);
    if (mounted) setState(() {});
    _toast('Uploaded ground truth deleted.');
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600)),
        content: Text(message,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.9),
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.errorRed,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Songs ─────────────────────────────────────────────────────────────────

  Future<void> _addSong() async {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add song',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(titleCtrl, 'Song title'),
            const SizedBox(height: 12),
            _dialogField(artistCtrl, 'Artist'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add',
                style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (added != true) return;
    try {
      await AdminMediaService.addCustomSong(
        title: titleCtrl.text,
        artist: artistCtrl.text,
        titleAlreadyInCatalog:
            SongCatalogService.containsTitle(titleCtrl.text),
      );
      if (mounted) setState(() {});
      _toast('"${titleCtrl.text.trim()}" added. Upload its MP3 next.');
    } on StateError catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Widget _dialogField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.white, fontFamily: 'Roboto'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grey, fontFamily: 'Roboto'),
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _deleteSong(String title) async {
    final ok = await _confirm(
      'Delete "$title"?',
      'The song and both of its uploaded files will be removed.',
    );
    if (!ok) return;
    await AdminMediaService.deleteCustomSong(title);
    if (mounted) setState(() {});
    _toast('"$title" deleted.');
  }

  // ── Password ──────────────────────────────────────────────────────────────

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Change admin password',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(currentCtrl, 'Current password'),
            const SizedBox(height: 12),
            _dialogField(newCtrl, 'New password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (submitted != true) return;
    if (newCtrl.text.trim().length < 4) {
      _toast('Pick a password of at least 4 characters.', isError: true);
      return;
    }
    final changed = await SessionStorageService.changeAdminPassword(
        currentCtrl.text, newCtrl.text.trim());
    if (!changed) {
      _toast('That current password is incorrect.', isError: true);
      return;
    }
    await _checkPassword();
    _toast('Admin password updated.');
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartPage()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final songs = SongCatalogService.allSongs;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text('Admin',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto')),
        actions: [
          IconButton(
            tooltip: 'Transcription accuracy',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TranscriptionEvalPage()),
            ),
            icon: const Icon(Icons.science_outlined, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Change password',
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_outline, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSong,
        backgroundColor: AppColors.primaryCyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add song',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (_usingDefaultPassword) _defaultPasswordWarning(),
          _buildSearchDemand(),
          const SizedBox(height: 20),
          Text(
            '${songs.length} songs',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 12,
                fontFamily: 'Roboto'),
          ),
          const SizedBox(height: 10),
          for (final song in songs) ...[
            _SongAdminCard(
              title: song['title'] ?? '',
              artist: song['artist'] ?? '',
              busy: _busyTitle == song['title'],
              bundledAudio: _bundledAudio[song['title'] ?? ''],
              bundledGroundTruth: _bundledGroundTruth[song['title'] ?? ''],
              onUploadAudio: () => _uploadAudio(song['title'] ?? ''),
              onUploadGroundTruth: () =>
                  _uploadGroundTruth(song['title'] ?? ''),
              onDeleteAudio: (hasBundled) =>
                  _deleteAudio(song['title'] ?? '', hasBundled),
              onDeleteGroundTruth: (hasBundled) =>
                  _deleteGroundTruth(song['title'] ?? '', hasBundled),
              onDeleteSong: () => _deleteSong(song['title'] ?? ''),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  /// What people actually searched for and chose to sing in Search &
  /// Sing. This is the queue for authoring work: the songs at the top
  /// are the ones worth hand-authoring a ground truth for, so Scored
  /// Karaoke grows toward real demand instead of guesswork.
  Widget _buildSearchDemand() {
    return FutureBuilder<List<SongSearchStat>>(
      future: SongSearchStatsService.mostSearched(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const <SongSearchStat>[];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: AppColors.primaryCyan, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Most requested songs',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  if (stats.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final ok = await _confirm('Clear search history?',
                            'All request counts will be reset to zero.');
                        if (!ok) return;
                        await SongSearchStatsService.clear();
                        if (mounted) setState(() {});
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Searched and sung in Search & Sing',
                style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.65),
                  fontSize: 10.5,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 10),
              if (stats.isEmpty)
                Text(
                  'No songs requested yet.',
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                )
              else
                for (final stat in stats.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              if (stat.artist.isNotEmpty)
                                Text(
                                  stat.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        AppColors.grey.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryCyan.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryCyan
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${stat.count}×',
                            style: const TextStyle(
                              color: AppColors.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _defaultPasswordWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This account still uses the default password. '
              'Change it before anyone else uses the app.',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                  height: 1.35),
            ),
          ),
          TextButton(
            onPressed: _changePassword,
            child: const Text('Change',
                style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// One song's media management: where its MP3 and ground truth currently
/// come from, and the actions to replace or remove them.
class _SongAdminCard extends StatelessWidget {
  final String title;
  final String artist;
  final bool busy;

  /// Whether the shipped files are really present.
  ///
  /// Resolved by the parent, because an asset's presence can only be
  /// learned by trying to load it, and build() cannot await. Null while
  /// that is still in flight, which the row shows as "Checking…" rather
  /// than guessing.
  final bool? bundledAudio;
  final bool? bundledGroundTruth;

  final VoidCallback onUploadAudio;
  final VoidCallback onUploadGroundTruth;
  final void Function(bool hasBundledFallback) onDeleteAudio;
  final void Function(bool hasBundledFallback) onDeleteGroundTruth;
  final VoidCallback onDeleteSong;

  const _SongAdminCard({
    required this.title,
    required this.artist,
    required this.busy,
    required this.bundledAudio,
    required this.bundledGroundTruth,
    required this.onUploadAudio,
    required this.onUploadGroundTruth,
    required this.onDeleteAudio,
    required this.onDeleteGroundTruth,
    required this.onDeleteSong,
  });

  @override
  Widget build(BuildContext context) {
    final uploadedAudio = AdminMediaService.audioPathFor(title) != null;
    final uploadedGroundTruth =
        AdminMediaService.groundTruthPathFor(title) != null;
    final isCustom = AdminMediaService.isCustomSong(title);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto'),
                    ),
                    if (artist.isNotEmpty)
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontFamily: 'Roboto'),
                      ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryCyan),
                )
              else if (isCustom)
                IconButton(
                  tooltip: 'Delete song',
                  onPressed: onDeleteSong,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.errorRed, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _mediaRow(
            icon: Icons.audiotrack,
            label: 'MP3',
            uploaded: uploadedAudio,
            bundled: bundledAudio,
            onUpload: busy ? null : onUploadAudio,
            onDelete: busy ? null : () => onDeleteAudio(bundledAudio == true),
          ),
          const SizedBox(height: 8),
          _mediaRow(
            icon: Icons.timeline,
            label: 'Ground truth',
            uploaded: uploadedGroundTruth,
            bundled: bundledGroundTruth,
            onUpload: busy ? null : onUploadGroundTruth,
            onDelete: busy
                ? null
                : () => onDeleteGroundTruth(bundledGroundTruth == true),
          ),
        ],
      ),
    );
  }

  Widget _mediaRow({
    required IconData icon,
    required String label,
    required bool uploaded,
    required bool? bundled,
    required VoidCallback? onUpload,
    required VoidCallback? onDelete,
  }) {
    // Four states. "Built-in" used to be claimed for any catalogued song
    // whether or not the file existed, so "Missing" was unreachable and
    // this row said a melody was shipped for all ten songs while nine had
    // none. `bundled` is now the result of actually loading the asset,
    // and null while that is still resolving.
    final (String status, Color color) = uploaded
        ? ('Uploaded', AppColors.primaryCyan)
        : bundled == null
            ? ('Checking…', AppColors.grey)
            : bundled
                ? ('Built-in', const Color(0xFF4CAF50))
                : ('Missing', AppColors.errorRed);

    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.grey.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 94,
          child: Text(
            label,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontFamily: 'Roboto'),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            status,
            style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto'),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Upload',
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file,
              color: AppColors.primaryCyan, size: 19),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
        ),
        IconButton(
          tooltip: uploaded ? 'Delete upload' : 'Nothing uploaded to delete',
          onPressed: uploaded ? onDelete : null,
          icon: Icon(
            Icons.delete_outline,
            color: uploaded
                ? AppColors.errorRed
                : AppColors.grey.withValues(alpha: 0.35),
            size: 19,
          ),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
        ),
      ],
    );
  }
}
