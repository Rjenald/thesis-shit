/// Server URLs for the Python CREPE pitch detection backend.
///
/// Change SERVER_IP to your PC's local IP address when running on Android.
/// Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux) to find your IP.
///
/// Example: if your PC IP is 192.168.1.10, set:
///   static const serverIp = '192.168.1.10';
library;

class PitchServerConfig {
  /// The machine running the Python pitch server.
  ///
  /// Overridable without editing code, because a laptop's LAN address
  /// changes every time it joins a different network — editing a constant
  /// and rebuilding for each one is how this ends up silently pointing at
  /// an address nobody is listening on:
  ///
  ///   flutter run --dart-define=PITCH_SERVER_IP=192.168.1.10
  ///
  /// Android emulator → 10.0.2.2 (the host's localhost).
  /// Real device → the host's LAN address, from `ipconfig`.
  /// The default is this machine's Wi-Fi address on "Its me ryry 3" as of 2026-11-04. It WILL go
  /// stale the next time the laptop joins a different network, and the
  /// symptom is not an error but a 10-second silence followed by a
  /// timeout, because an address on another network drops packets rather
  /// than refusing them. Prefer the --dart-define; .vscode/launch.json
  /// already passes it.
  static const String serverIp = String.fromEnvironment(
    'PITCH_SERVER_IP',
    defaultValue: '192.168.43.49',
  );

  static const int serverPort =
      int.fromEnvironment('PITCH_SERVER_PORT', defaultValue: 8000);

  static String get _base => 'http://$serverIp:$serverPort';

  /// WebSocket URL for real-time pitch streaming
  static String get wsUrl => 'ws://$serverIp:$serverPort/pitch';

  /// HTTP health check URL
  static String get healthUrl => '$_base/health';

  /// Song catalog endpoint — returns JSON: {songs: [...], count: N}
  /// Served by crepe_server.py; app.py doesn't implement it.
  static String get songsUrl => '$_base/songs';
}
