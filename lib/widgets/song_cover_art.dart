import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A song's cover art, from wherever that song's art happens to live.
///
/// One widget instead of nine, because there were nine copies of
/// `Image.network(...)` with slightly different placeholders and error
/// handling, and they had to agree about something they could not: the
/// bundled songs' art is now a local asset, while an admin-added song or a
/// Search & Sing result still has a URL or a file on disk.
///
/// The bundled art being local matters beyond tidiness. This app is built
/// to work offline — that is why the backing tracks, models and ground
/// truth are all bundled — and `Image.network` for the catalogue's covers
/// quietly broke that: every song fell back to a grey placeholder with no
/// connection, on a screen that otherwise worked perfectly.
class SongCoverArt extends StatelessWidget {
  const SongCoverArt({
    super.key,
    required this.image,
    this.size = 56,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.iconSize,
    this.placeholderIcon = Icons.music_note,
  });

  /// Asset path, http(s) URL, absolute file path, or empty.
  ///
  /// Which of those it is decides the loader, and nothing upstream has to
  /// care which it handed over.
  final String image;

  /// Convenience for the common square case; [width]/[height] override it.
  final double size;
  final double? width;
  final double? height;

  final double borderRadius;

  /// Placeholder icon size. Scales with the box when not given, so a 56px
  /// thumbnail and a 300px card both look deliberate.
  final double? iconSize;

  /// What to draw when there is no image. A note suits a song; the home
  /// page's artist row passes a person instead.
  final IconData placeholderIcon;

  double get _w => width ?? size;
  double get _h => height ?? size;

  bool get _isAsset => image.startsWith('assets/');
  bool get _isUrl => image.startsWith('http://') ||
      image.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (image.isEmpty) return _placeholder();

    if (_isAsset) {
      return Image.asset(
        image,
        width: _w,
        height: _h,
        fit: BoxFit.cover,
        // A bundled asset that is missing is a build problem, not a
        // runtime one, but a broken-image box on a user's screen is the
        // wrong way to find out.
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    if (_isUrl) {
      return Image.network(
        image,
        width: _w,
        height: _h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(),
      );
    }

    // An admin upload: an absolute path on the device.
    final file = File(image);
    return Image.file(
      file,
      width: _w,
      height: _h,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: _w,
        height: _h,
        color: AppColors.primaryCyan.withValues(alpha: 0.12),
        child: Icon(
          placeholderIcon,
          color: AppColors.primaryCyan,
          size: iconSize ?? (_w < _h ? _w : _h) * 0.36,
        ),
      );
}
