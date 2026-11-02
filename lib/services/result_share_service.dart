import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns a result card into a PNG and either shares it or saves it to the
/// device gallery.
///
/// The card is a purpose-built widget rather than a screenshot of the
/// result screen: a result screen is a tall scrolling page with buttons on
/// it, which makes a poor image. Rendering a dedicated card means the
/// shared picture is a fixed size, has no controls in it, and shows the
/// parts worth showing.
class ResultShareService {
  /// Pixel ratio to rasterize at. 3.0 gives a card that still looks sharp
  /// re-compressed by a social app, without producing a file so large that
  /// sharing it is slow.
  static const pixelRatio = 3.0;

  /// Renders the widget inside [boundaryKey] to PNG bytes.
  ///
  /// Returns null when the boundary isn't on screen yet or has nothing
  /// painted — callers treat that as "try again", never as a silent
  /// success, because an empty share is worse than a visible failure.
  static Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    try {
      final object = boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) {
        debugPrint('share: no repaint boundary behind the key yet');
        return null;
      }

      // Deliberately no wait here. An earlier version slept 40ms when the
      // boundary still needed paint, which was both unnecessary and
      // untestable: the card is already visible in the share sheet by the
      // time anyone can tap Share, and a wall-clock delay never resolves
      // under the test binding's fake clock, so it hung every widget test
      // that captured. If a boundary somehow is unpainted the capture is
      // blank rather than wrong, the user is looking at the same card in
      // the preview, and this logs it.
      if (object.debugNeedsPaint) {
        debugPrint('share: boundary still needs paint; '
            'capture may come back blank');
      }

      final image = await object.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      return data.buffer.asUint8List();
    } catch (e, st) {
      debugPrint('share: capture failed: $e\n$st');
      return null;
    }
  }

  /// Writes [png] to a temp file so it can be handed to another app.
  ///
  /// The name is what some social apps show as the attachment caption, so
  /// it is built from the song rather than left as a timestamp.
  static Future<File> _stage(Uint8List png, String baseName) async {
    final dir = await getTemporaryDirectory();
    final safe = baseName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final stem = safe.isEmpty ? 'huni_result' : 'huni_$safe';
    final file = File('${dir.path}/$stem.png');
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  /// Shares the captured card through the system share sheet, which is
  /// what puts the social apps the user actually has in front of them —
  /// rather than this app guessing at a list of networks.
  ///
  /// [text] rides along as the suggested caption. Apps that take only an
  /// image ignore it, which is why the image has to stand on its own.
  static Future<ShareOutcome> shareImage({
    required GlobalKey boundaryKey,
    required String baseName,
    String? text,
  }) async {
    final png = await capture(boundaryKey);
    if (png == null) return ShareOutcome.captureFailed;

    try {
      final file = await _stage(png, baseName);
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
      );
      // A dismissed share sheet is a normal choice, not an error, so it
      // gets its own outcome and no error message.
      return result.status == ShareResultStatus.dismissed
          ? ShareOutcome.dismissed
          : ShareOutcome.shared;
    } catch (e) {
      debugPrint('share: share sheet failed: $e');
      return ShareOutcome.failed;
    }
  }

  /// Saves the captured card to the device gallery.
  ///
  /// `gal` asks for the gallery permission itself, so a refusal surfaces
  /// here as [ShareOutcome.permissionDenied] and is reported as something
  /// the user can fix in Settings, not as a bug.
  static Future<ShareOutcome> saveToGallery({
    required GlobalKey boundaryKey,
    required String baseName,
  }) async {
    final png = await capture(boundaryKey);
    if (png == null) return ShareOutcome.captureFailed;

    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          return ShareOutcome.permissionDenied;
        }
      }
      // Album name groups the saves together in the user's gallery
      // instead of scattering them through Pictures.
      await Gal.putImageBytes(png, album: 'Huni');
      return ShareOutcome.saved;
    } on GalException catch (e) {
      debugPrint('share: gallery save failed: ${e.type}');
      return e.type == GalExceptionType.accessDenied
          ? ShareOutcome.permissionDenied
          : ShareOutcome.failed;
    } catch (e) {
      debugPrint('share: gallery save failed: $e');
      return ShareOutcome.failed;
    }
  }
}

/// What came of a share or save, so the caller can say something true.
enum ShareOutcome {
  shared,
  saved,

  /// The user closed the share sheet without picking anything.
  dismissed,

  /// Nothing was painted to capture — worth retrying, not worth an alarm.
  captureFailed,

  /// Gallery access was refused; only Settings can change that.
  permissionDenied,

  failed;

  /// Message to show, or null when there is nothing worth saying (the
  /// user dismissing their own share sheet needs no feedback).
  String? get message => switch (this) {
        ShareOutcome.shared => null,
        ShareOutcome.saved => 'Saved to your gallery, in the Huni album.',
        ShareOutcome.dismissed => null,
        ShareOutcome.captureFailed =>
          'Could not render the result card. Try again.',
        ShareOutcome.permissionDenied =>
          'Huni needs photo access to save. Enable it in Settings.',
        ShareOutcome.failed => 'Something went wrong. Try again.',
      };

  bool get isError =>
      this == ShareOutcome.captureFailed ||
      this == ShareOutcome.permissionDenied ||
      this == ShareOutcome.failed;
}
