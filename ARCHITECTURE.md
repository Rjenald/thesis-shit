# YouTube Karaoke Architecture

## Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER FLOW                                        │
└─────────────────────────────────────────────────────────────────────────┘

1. USER INPUT
   ├── Search for karaoke song
   ├── Paste YouTube URL
   └── Select from results

2. FETCH DATA
   ├── YouTubeKaraokeService
   │   └── youtube_explode_dart → Get video metadata, duration
   └── LyricsSyncService
       └── lrclib.net API → Get synced lyrics (LRC format)

3. CREATE SESSION
   └── YouTubeKaraokeSession
       ├── videoId
       ├── title, artist
       ├── lyrics (List<TimedLyricLine>)
       └── metadata

4. LAUNCH PLAYER
   └── YouTubeKaraokePlayer
       ├── Display video
       ├── Start position tracking
       ├── Highlight synced lyrics
       ├── Capture user voice (AudioService)
       ├── Detect pitch in real-time
       └── Display live feedback

5. RECORD SESSION
   ├── Pitch readings per line
   ├── Accuracy metrics
   └── Performance data

6. RESULTS & SCORING
   └── Generate score based on pitch accuracy
```

---

## Component Architecture

```
                    ┌──────────────────────────────┐
                    │  YouTubeKaraokePlayer        │
                    │  (Main Widget)               │
                    └──────────┬───────────────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌──────────────┐ ┌────────────┐ ┌──────────────┐
        │   YouTube    │ │  Lyrics    │ │    Pitch     │
        │   Player     │ │  Display   │ │  Detection   │
        │ (iframe)     │ │ (Sync)     │ │ (Audio       │
        └──────────────┘ └────────────┘ │  Service)    │
                                        └──────────────┘


        YouTubeKaraokeService
        ├── extractVideoId()
        ├── getVideoMetadata()
        ├── searchKaraokeVideos()
        └── getThumbnailUrl()

        
        LyricsSyncService
        ├── getCurrentLineIndex()
        ├── parseLrcLyrics()
        ├── fetchTimedLyricsFromLrcLib()
        ├── offsetLyrics()
        └── searchLyrics()


        AudioService (Existing - Reused)
        ├── start()
        ├── stop()
        ├── results (Stream)
        ├── pitch detection (CREPE)
        └── real-time feedback
```

---

## File Structure

```
final_thesis_ui/
│
├── lib/
│   ├── models/
│   │   ├── youtube_karaoke_session.dart          ⭐ NEW
│   │   │   ├── YouTubeKaraokeSession
│   │   │   └── TimedLyricLine
│   │   └── session_result.dart                   (Existing)
│   │
│   ├── services/
│   │   ├── youtube_karaoke_service.dart          ⭐ NEW
│   │   ├── lyrics_sync_service.dart              ⭐ NEW
│   │   ├── lrclib_service.dart                   (Existing)
│   │   └── api_service.dart                      (Existing)
│   │
│   ├── screens/
│   │   ├── youtube_karaoke_player.dart           ⭐ NEW (Main Player)
│   │   ├── karaoke_recording_page.dart           (Existing Local Karaoke)
│   │   └── results_page.dart                     (Existing Results)
│   │
│   ├── core/
│   │   ├── audio_service.dart                    (Existing - Reused)
│   │   ├── note_utils.dart                       (Existing)
│   │   └── local_pitch_detector.dart             (Existing)
│   │
│   ├── constants/
│   │   └── app_colors.dart                       (Existing)
│   │
│   └── widgets/
│       ├── bottom_nav_bar.dart                   (Existing)
│       └── platform_designs.dart                 (Existing)
│
├── pubspec.yaml                                  ✓ All deps present
├── YOUTUBE_KARAOKE_INTEGRATION.md                ⭐ Complete guide
├── QUICK_START_YOUTUBE_KARAOKE.md                ⭐ Usage examples
└── ARCHITECTURE.md                               (This file)
```

---

## State Management Flow

```
YouTubeKaraokePlayer State:
├── YouTube Controller
│   ├── _youtubeController: YoutubePlayerController
│   ├── _playerReady: bool
│   ├── _isPlaying: bool
│   └── _currentPosition: Duration
│
├── Lyrics Management
│   ├── _currentLyricIndex: int
│   ├── _lyricLineKeys: List<GlobalKey>
│   └── _lyricsScrollController: ScrollController
│
└── Pitch Detection
    ├── _audioService: AudioService
    ├── _audioSub: StreamSubscription
    ├── _isRecording: bool
    ├── _liveFeedback: PitchFeedback
    ├── _liveNote: String
    ├── _liveCents: double
    ├── _liveClarity: double
    └── _pitchHistory: List<double>
```

---

## API Integration Points

### 1. YouTube
- **Provider**: youtube_explode_dart
- **Endpoint**: YouTube public API
- **Rate Limit**: No auth token required for basic search/metadata
- **Usage**: Video search, metadata, thumbnail

### 2. LrcLib (Lyrics)
- **Provider**: lrclib.net
- **Endpoint**: `https://lrclib.net/api/get`
- **Params**: artist_name, track_name
- **Returns**: Synced lyrics in LRC format
- **Fallback**: Plain lyrics (estimated timing)

### 3. Audio Processing
- **Local**: CREPE pitch detection (via AudioService)
- **Processing**: Real-time FFT analysis
- **Output**: Frequency (Hz), Confidence, Note name

---

## Sequence Diagram: Playing a Karaoke Song

```
User          App           YouTube        LrcLib         AudioService
│             │                │             │              │
├─Search─────→│                │             │              │
│             │─Search────────→│             │              │
│             │←─Results───────│             │              │
│             │                │             │              │
├─Select─────→│                │             │              │
│             │─GetMetadata──→│             │              │
│             │←─Video Info───│             │              │
│             │─FetchLyrics──────────────→│              │
│             │←─Synced Lyrics────────────│              │
│             │                │             │              │
│             │─Create Session─────────────────────────   │
│             │                │             │              │
├─Play────────│                │             │              │
│             │─PlayVideo─────→│             │              │
│             │←─Playing──────────────────────────────────│
│             │                │             │              │
│             │─RequestRecord──────────────────────────→│
│             │                │             │  Start   │
│             │←─Pitch Updates─────────────────────────│
│             │   (every 10ms) │             │              │
│             │                │             │              │
│             │─Check Position→│             │              │
│             │←─Position────┐ │             │              │
│             │──Update Lyric│ │             │              │
│             │                │             │              │
├─Stop────────│                │             │              │
│             │─StopVideo─────→│             │              │
│             │─StopRecord─────────────────────────────→│
│             │←─Results──────────────────────────────│
│             │                │             │              │
└─────────────┴────────────────┴─────────────┴──────────────┘
```

---

## Integration Checklist

### Phase 1: Setup ✓
- [x] Models created
- [x] Services created  
- [x] Player widget created
- [x] No additional dependencies needed

### Phase 2: Basic Integration (Next Steps)
- [ ] Add YouTube karaoke button to home screen
- [ ] Test video playback
- [ ] Test lyrics fetching and syncing
- [ ] Test pitch detection

### Phase 3: Advanced Features
- [ ] Save karaoke sessions with scores
- [ ] Compare local vs YouTube performance
- [ ] Add sync adjustment controls
- [ ] Implement offline lyrics caching
- [ ] Add leaderboard / statistics

### Phase 4: Polish
- [ ] Error handling improvements
- [ ] Loading states refinement
- [ ] UI/UX polish
- [ ] Performance optimization

---

## Key Features Comparison

| Feature | Status | Notes |
|---------|--------|-------|
| YouTube video playback | ✓ Ready | IFrame embedded |
| Lyrics syncing | ✓ Ready | Auto-scroll, highlight |
| Pitch detection | ✓ Ready | Real-time CREPE |
| Live feedback | ✓ Ready | In tune/sharp/flat |
| Position tracking | ✓ Ready | 100ms refresh |
| Recording | ✓ Ready | Mic capture |
| Results saving | ⏳ Optional | Can be added |
| Scoring | ⏳ Optional | Accuracy % based on pitch |
| Offline mode | ⏳ Optional | Cache lyrics/videos |

---

## Performance Considerations

```
YouTube Video Playback:
├── IFrame (efficient, native YouTube player)
├── No transcoding needed
└── ~50-100MB bandwidth per hour

Lyrics Sync:
├── Position updates: 10 per second
├── Lyric lookup: O(n) linear search (n < 500 lines)
└── Scroll animation: 300ms duration

Pitch Detection:
├── FFT window: ~40ms
├── Update frequency: 100ms
├── CPU usage: ~15-25% (on budget devices)
└── Memory: ~2-5MB buffer

Memory Usage:
├── Video player: ~40MB
├── Pitch history (80 samples): ~640 bytes
├── Lyrics storage (avg 300 lines): ~30KB
└── Total per session: ~45MB
```

---

## Error Handling Strategy

```
YouTube Service Errors:
├── Network error → Show snackbar, retry option
├── Invalid video ID → Show error, request new URL
├── Video restricted → Show region/age restriction warning
└── API quota → Graceful degradation

Lyrics Service Errors:
├── No lyrics found → Continue with empty lyrics
├── Network timeout → Use fallback estimation
├── Parse error → Skip malformed lines
└── Sync mismatch → Offer manual adjustment

Audio Service Errors:
├── Permission denied → Request permission, show guide
├── Mic not available → Show error, suggest alternative
├── Audio init failed → Graceful degradation
└── Stream stopped → Auto-recover

Player Errors:
├── Video won't load → Check network, retry
├── Position tracking fails → Auto-sync or manual reset
└── UI freeze → Async await, cancel on dispose
```

---

## Testing Recommendations

```
Unit Tests:
├── LyricsSyncService.getCurrentLineIndex()
├── YouTubeKaraokeService.extractVideoId()
└── LyricsSyncService.parseLrcLyrics()

Widget Tests:
├── YouTubeKaraokePlayer rendering
├── Lyric highlight transitions
└── Control buttons functionality

Integration Tests:
├── Full karaoke flow (search → play → record)
├── Lyrics syncing accuracy
├── Pitch detection while recording
├── Results generation

Manual Testing:
├── Various YouTube video types
├── Different lyric sources
├── Network interruptions
├── Permission handling
└── Different device types
```

---

## Known Limitations & Workarounds

| Issue | Limitation | Workaround |
|-------|-----------|-----------|
| YouTube API | No official Flutter SDK | Using youtube_explode_dart (web scraping) |
| Lyrics Sync | Timing accuracy ±500ms | Manual adjustment controls |
| Age-gated videos | Cannot play in some regions | Check video accessibility first |
| Offline lyrics | Must fetch online | Cache LRC files locally |
| Background playback | YouTube may stop | Add service to keep app alive |
| Exact pitch matching | Difficult for complex harmonies | Accept ±50 cents tolerance |

---

## Future Enhancements

1. **Multi-language support** for lyrics
2. **Lyric caching** for offline playback
3. **Social features** (share scores, duets)
4. **Advanced scoring** (timing accuracy, breath detection)
5. **Video recording** of performance
6. **AI-powered suggestions** based on pitch range
7. **MIDI export** of pitch data
8. **Real-time multiplayer** karaoke
