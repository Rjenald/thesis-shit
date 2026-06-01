/// Maps song titles to YouTube karaoke video IDs.
/// To add a new song: search "[Song Title] karaoke" on YouTube,
/// copy the video ID from the URL (the part after "v=").
class KaraokeVideoService {
  static const Map<String, String> _videoIds = {
    'Dadalhin': 'ox_NN4usbR0',
    'Paalam Muna Sandali': 'H8YUXDulvuU',
    'Nasa Iyo Na Ang Lahat': 'ZJVelSQFTrU',
    'Ulap': 'djw1ZJJv7dI',
    'Fallen': 'VzJvV_22lHA',
    'Mula Sa Puso': 'iMh0-Ud-ndk',
    'Pangarap Ko Ang Iyo': 'JRzsGUp6ud4',
  };

  static String? getVideoId(String songTitle) {
    return _videoIds[songTitle];
  }

  static bool hasVideo(String songTitle) {
    return _videoIds.containsKey(songTitle);
  }

  static List<String> get availableSongs => _videoIds.keys.toList();
}
