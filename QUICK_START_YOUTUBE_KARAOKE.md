# Quick Start: YouTube Karaoke Integration

## Files Created

```
lib/
├── models/
│   └── youtube_karaoke_session.dart        (Session & lyrics models)
├── services/
│   ├── youtube_karaoke_service.dart        (YouTube API integration)
│   └── lyrics_sync_service.dart            (Lyrics parsing & syncing)
└── screens/
    └── youtube_karaoke_player.dart         (Main player widget)
```

---

## 1. LAUNCHING A KARAOKE SESSION (Basic Usage)

```dart
// From any screen where you want to launch YouTube karaoke

import 'package:final_thesis_ui/models/youtube_karaoke_session.dart';
import 'package:final_thesis_ui/services/youtube_karaoke_service.dart';
import 'package:final_thesis_ui/services/lyrics_sync_service.dart';
import 'package:final_thesis_ui/screens/youtube_karaoke_player.dart';

// Example: Launch karaoke with a YouTube video ID
void launchYouTubeKaraoke() async {
  const videoId = 'dQw4w9WgXcQ'; // Replace with actual video ID
  const title = 'Never Gonna Give You Up';
  const artist = 'Rick Astley';

  // 1. Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // 2. Fetch lyrics with timestamps
    final lyrics = await LyricsSyncService.fetchTimedLyricsFromLrcLib(
      title,
      artist,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (lyrics.isEmpty) {
      // Show warning if lyrics not found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lyrics not found. Using empty lyrics.')),
      );
    }

    // 3. Create session
    final session = YouTubeKaraokeSession(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: YouTubeKaraokeService.getThumbnailUrl(videoId),
      videoDuration: const Duration(minutes: 3, seconds: 30),
      lyrics: lyrics,
    );

    // 4. Launch player
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeKaraokePlayer(session: session),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## 2. SEARCH FOR KARAOKE VIDEOS

```dart
// Search for karaoke versions of a song

void searchAndPlayKaraoke(String query) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    final videos = await YouTubeKaraokeService.searchKaraokeVideos(query);
    
    if (!mounted) return;
    Navigator.pop(context);

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No karaoke videos found')),
      );
      return;
    }

    // Show search results
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: videos.length,
        itemBuilder: (ctx, i) {
          final video = videos[i];
          return ListTile(
            title: Text(video.title),
            subtitle: Text('${video.duration?.inMinutes}:${(video.duration?.inSeconds ?? 0) % 60}'),
            onTap: () {
              Navigator.pop(context);
              launchKaraokeWithVideo(video);
            },
          );
        },
      ),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Search error: $e')),
    );
  }
}

void launchKaraokeWithVideo(dynamic video) async {
  // Extract title and artist from video title
  // Format usually: "Song Title - Artist Name [Karaoke Version]"
  final parts = video.title.split('-').map((s) => s.trim()).toList();
  final title = parts.isNotEmpty ? parts[0] : video.title;
  final artist = parts.length > 1 ? parts[1] : 'Unknown';

  launchYouTubeKaraokeWithVideo(
    videoId: video.id.value,
    title: title,
    artist: artist,
  );
}

Future<void> launchYouTubeKaraokeWithVideo({
  required String videoId,
  required String title,
  required String artist,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final lyrics = await LyricsSyncService.fetchTimedLyricsFromLrcLib(
      title,
      artist,
    );

    if (!mounted) return;
    Navigator.pop(context);

    final session = YouTubeKaraokeSession(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: YouTubeKaraokeService.getThumbnailUrl(videoId),
      videoDuration: const Duration(minutes: 3),
      lyrics: lyrics.isNotEmpty 
          ? lyrics 
          : [TimedLyricLine(
              text: 'Loading lyrics...',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
            )],
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeKaraokePlayer(session: session),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## 3. HANDLE URL INPUT

```dart
// Allow users to paste YouTube URLs

void launchKaraokeFromUrl(String url) async {
  try {
    // Extract video ID
    final videoId = YouTubeKaraokeService.extractVideoId(url);

    // Show input dialog for song info
    String? title;
    String? artist;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF0A0A0A),
        title: const Text('Enter Song Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Song Title',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (v) => title = v,
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Artist Name',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (v) => artist = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (title != null && artist != null) {
                launchYouTubeKaraokeWithVideo(
                  videoId: videoId,
                  title: title ?? 'Unknown',
                  artist: artist ?? 'Unknown',
                );
              }
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid URL: $e')),
    );
  }
}
```

---

## 4. ADD TO EXISTING KARAOKE FLOW

If you want to add YouTube karaoke as an option alongside your existing karaoke:

```dart
// In your song selection or home screen

// Option 1: YouTube URL input button
ElevatedButton(
  onPressed: () => _showUrlInputDialog(),
  child: const Text('YouTube Karaoke'),
),

// Option 2: Search button
ElevatedButton(
  onPressed: () => _showSearchDialog(),
  child: const Text('Search Karaoke'),
),

// Existing karaoke remains unchanged
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => KaraokeRecordingPage(
        songTitle: selectedSong.title,
        songArtist: selectedSong.artist,
      ),
    ),
  ),
  child: const Text('Local Karaoke'),
),
```

---

## 5. KEY DIFFERENCES: Local vs YouTube Karaoke

| Feature | Local Karaoke | YouTube Karaoke |
|---------|---------------|-----------------|
| Video Source | Local asset/upload | YouTube iframe |
| Lyrics Source | Hardcoded/Backend | LrcLib API |
| Sync | Manual timer | YouTube position |
| Pitch Detection | ✓ Integrated | ✓ Integrated |
| Results Tracking | ✓ Full session | ✓ Can be added |

---

## 6. TROUBLESHOOTING

### Lyrics not syncing?
```dart
// Adjust lyrics by offset (in seconds)
final offset = Duration(seconds: 2); // Delay by 2 seconds
final adjustedLyrics = LyricsSyncService.offsetLyrics(
  widget.session.lyrics,
  offset,
);
```

### YouTube video not loading?
- Check internet connection
- Verify video ID is valid
- Some videos may be region-restricted or age-gated

### Lyrics not found?
- LrcLib may not have the song
- You can provide empty lyrics and just sing along
- Manual LRC files can be loaded instead

### Microphone not working?
- Check permissions in `AndroidManifest.xml` and `Info.plist`
- Test with existing KaraokeRecordingPage first
- Ensure user grants permission when prompted

---

## 7. NEXT STEPS

1. **Test the integration** with various YouTube videos
2. **Add results saving** to compare local vs YouTube karaoke
3. **Implement sync adjustment UI** with +/- buttons
4. **Add offline lyrics support** for cached LRC files
5. **Create karaoke library** tracking all performances
6. **Add social sharing** of scores

---

## 8. EXAMPLE FULL SCREEN

```dart
import 'package:flutter/material.dart';
import 'package:final_thesis_ui/constants/app_colors.dart';

class YouTubeKaraokeHomeScreen extends StatefulWidget {
  @override
  State<YouTubeKaraokeHomeScreen> createState() => _YouTubeKaraokeHomeScreenState();
}

class _YouTubeKaraokeHomeScreenState extends State<YouTubeKaraokeHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('YouTube Karaoke'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search section
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search karaoke songs...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => searchAndPlayKaraoke(_searchController.text),
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            
            const SizedBox(height: 24),
            const Divider(color: Colors.grey),
            const SizedBox(height: 24),
            
            // URL input section
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste YouTube URL...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.link, color: Colors.grey),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => launchKaraokeFromUrl(_urlController.text),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }

  // Copy methods from examples above
  void searchAndPlayKaraoke(String query) { /* ... */ }
  void launchKaraokeFromUrl(String url) { /* ... */ }
}
```

---

## Files to Update in pubspec.yaml (Already Done ✓)

All required packages are already in your `pubspec.yaml`:
- ✓ youtube_player_iframe
- ✓ youtube_explode_dart  
- ✓ record
- ✓ http

No additional dependencies needed!
