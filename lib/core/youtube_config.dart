/// Configuration for YouTube Data API search, used by Search & Sing to
/// find a "minus one" backing track for the song the singer picked.
///
/// The key is read from a --dart-define first and falls back to the
/// constant below, so you can either:
///
///   flutter run --dart-define=YOUTUBE_API_KEY=AIza...
///
/// or paste it into [_pastedApiKey] for convenience while developing.
///
/// Prefer the --dart-define route for anything you'll commit or hand in:
/// a key pasted into source gets committed to git, and a key in a public
/// repo gets scraped and your daily quota burned by strangers. The
/// restrictions below limit the damage but don't prevent it.
///
/// The whole feature is optional — with no key configured, Search & Sing
/// still works, just a cappella, with no backing track.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class YoutubeConfig {
  /// Paste a key here for local development, or leave empty and use
  /// --dart-define=YOUTUBE_API_KEY=...
  static const String _pastedApiKey = 'AIzaSyBoFamo4M_WphWjWRL8PnmKIPp6ZDyNhjg';

  static const String _envApiKey =
      String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');

  static String get apiKey =>
      _envApiKey.isNotEmpty ? _envApiKey : _pastedApiKey;

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Identifies this app to Google so an Android-restricted key is
  /// accepted. Google's own Android client libraries attach these two
  /// headers automatically; a plain Dart http call does not, and the
  /// request comes back 403 "requests from this Android client application
  /// are blocked" even when the package and fingerprint are registered
  /// correctly. So we send them ourselves.
  ///
  /// [androidCertSha1] is the SHA-1 from `gradlew signingReport`, uppercase
  /// with the colons stripped. It changes with the signing keystore — a
  /// release build signed with a different key needs its own fingerprint
  /// registered on the API key and set here.
  static const String androidPackageName = 'com.example.final_thesis_ui';
  static const String androidCertSha1 =
      '7970A95E4C8C055DEA05C8115D4B17DB4F7E2B4D';

  /// Headers for an API request, empty off Android where the restriction
  /// doesn't apply.
  static Map<String, String> get restrictionHeaders {
    if (kIsWeb || !Platform.isAndroid) return const {};
    return {
      'X-Android-Package': androidPackageName,
      'X-Android-Cert': androidCertSha1,
    };
  }
}
