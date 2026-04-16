/// Server URLs for the Python CREPE pitch detection backend.
///
/// Change SERVER_IP to your PC's local IP address when running on Android.
/// Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux) to find your IP.
///
/// Example: if your PC IP is 192.168.1.10, set:
///   static const serverIp = '192.168.1.10';
library;

class PitchServerConfig {
  /// Your PC's local IP address.
  /// Change this to match your network.
  // Android emulator → 10.0.2.2 (your PC's localhost)
  // Real Android device → your PC's local IP e.g. 192.168.1.10
  static const String serverIp = '10.0.2.2';
  static const int serverPort = 8000;

  /// WebSocket URL for real-time pitch streaming
  static String get wsUrl => 'ws://$serverIp:$serverPort/pitch';

  /// HTTP health check URL
  static String get healthUrl => 'http://$serverIp:$serverPort/health';
}
