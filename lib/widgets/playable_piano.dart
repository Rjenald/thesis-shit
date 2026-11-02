import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/piano_audio.dart';

/// A one-octave keyboard that lights up from the microphone **and** plays
/// when you press it.
///
/// It previously did only the first half: both drill screens drew the keys
/// with a [CustomPaint] and no gesture handling at all, so a key lit up
/// when the mic heard that pitch but pressing one did nothing. Each screen
/// also carried its own near-identical copy of the painter, which had
/// already drifted apart.
///
/// The hit test and the drawing share one source of geometry
/// ([_whiteKeys], [_blackKeyCenters], [blackKeyWidthFactor],
/// [blackKeyHeightFactor]). Keeping them in step matters more than it
/// looks: black keys are drawn *over* the white ones, so a hit test that
/// disagreed by a few pixels would play the wrong note near every
/// accidental, which reads as the keyboard being out of tune rather than
/// mis-aimed.
class PlayablePiano extends StatefulWidget {
  const PlayablePiano({
    super.key,
    this.detectedMidi,
    this.highlightColor = AppColors.primaryCyan,
    this.isListening = false,
    this.glowIntensity = 1.0,
    this.enabled = true,
    this.onNotePressed,
    this.height = 112,
  });

  /// Pitch heard by the microphone, highlighted on the keyboard. Any
  /// octave: it is folded into this one, as before.
  final int? detectedMidi;
  final Color highlightColor;
  final bool isListening;
  final double glowIntensity;

  /// False leaves the keyboard visible but silent and unpressable — for a
  /// drill that is mid-countdown, say.
  final bool enabled;

  /// Called with the MIDI number of a pressed key, after the sound starts.
  final void Function(int midi)? onNotePressed;

  final double height;

  /// Which key is at [local] within a keyboard of [size], or null.
  ///
  /// Black keys are tested first because they are drawn on top: in the
  /// region where a black key overlaps its white neighbours, the black one
  /// is what a finger is aiming at.
  static int? midiAt(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    if (local.dy < 0 || local.dy > size.height) return null;

    final whiteW = size.width / PianoPainter.whiteKeys.length;
    final blackW = whiteW * PianoPainter.blackKeyWidthFactor;
    final blackH = size.height * PianoPainter.blackKeyHeightFactor;

    if (local.dy <= blackH) {
      for (final entry in PianoPainter.blackKeyCenters.entries) {
        final x = entry.value * whiteW - blackW / 2;
        if (local.dx >= x && local.dx <= x + blackW) return entry.key;
      }
    }

    final i = (local.dx / whiteW).floor();
    if (i < 0 || i >= PianoPainter.whiteKeys.length) return null;
    return PianoPainter.whiteKeys[i];
  }

  @override
  State<PlayablePiano> createState() => _PlayablePianoState();
}

class _PlayablePianoState extends State<PlayablePiano> {
  /// One pool per keyboard. Rendering the octave costs well under a
  /// second and the files are cached across launches, so this is cheaper
  /// than it looks.
  final PianoSoundPool _pool = PianoSoundPool();

  /// The key currently under a finger, drawn pressed. Separate from
  /// [PlayablePiano.detectedMidi] so a key you are holding and a pitch the
  /// mic hears can be shown at the same time without one masking the
  /// other.
  int? _pressed;

  @override
  void initState() {
    super.initState();
    // Off the first frame: a drill screen should appear immediately and
    // the keyboard become playable a moment later, rather than the whole
    // screen waiting on audio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pool.ready().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  Future<void> _press(Offset local) async {
    if (!widget.enabled) return;
    // Taken from this widget's own render box at gesture time rather than
    // from a LayoutBuilder. See build() for why that matters; by the time
    // a gesture arrives the box is laid out, so this is always available.
    final size = context.size;
    if (size == null) return;
    final midi = PlayablePiano.midiAt(local, size);
    if (midi == null || midi == _pressed) return;
    setState(() => _pressed = midi);
    final sounded = await _pool.play(midi);
    if (sounded && mounted) widget.onNotePressed?.call(midi);
  }

  void _release() {
    if (_pressed != null) setState(() => _pressed = null);
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately NO LayoutBuilder around the GestureDetector.
    //
    // RawGestureDetector reads `MediaQuery.maybeGestureSettingsOf(context)`
    // in its build, so putting it inside a LayoutBuilder registers an
    // inherited dependency during LAYOUT rather than build. When that
    // subtree is then removed, the dependency can outlive the element
    // holding it, and Flutter asserts
    // `'_dependents.isEmpty': is not true` from
    // InheritedElement.debugDeactivated — which is what a device threw
    // while the drills were being used.
    //
    // The size the hit test needs comes from `context.size` in the
    // gesture callback instead, which is simpler and avoids rebuilding
    // this subtree on every layout pass.
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // onTapDown rather than onTap: a note has to sound on the way
        // down. Waiting for the tap to complete is audibly late.
        onTapDown: (d) => _press(d.localPosition),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        // Dragging across the keys plays them, which is how anyone tries
        // a keyboard within five seconds of seeing one.
        onHorizontalDragStart: (d) => _press(d.localPosition),
        onHorizontalDragUpdate: (d) => _press(d.localPosition),
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        child: CustomPaint(
          painter: PianoPainter(
            detectedMidi: widget.detectedMidi,
            pressedMidi: _pressed,
            highlightColor: widget.highlightColor,
            isListening: widget.isListening,
            glowIntensity: widget.glowIntensity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

}

/// Draws the one-octave keyboard.
///
/// Public, and the only copy: both drill screens had their own, and they
/// had already drifted (4021 vs 3803 characters) so the two keyboards did
/// not look the same.
class PianoPainter extends CustomPainter {
  const PianoPainter({
    required this.detectedMidi,
    this.pressedMidi,
    required this.highlightColor,
    required this.isListening,
    this.glowIntensity = 1.0,
  });

  /// Pitch heard by the microphone, in any octave.
  final int? detectedMidi;

  /// Key currently held down, drawn differently from a detected pitch so
  /// "what I played" and "what it heard" stay distinguishable.
  final int? pressedMidi;

  final Color highlightColor;
  final bool isListening;
  final double glowIntensity;

  static const List<int> whiteKeys = [60, 62, 64, 65, 67, 69, 71, 72];
  static const List<String> solfegeLabels = [
    'Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti', 'Do',
  ];

  /// Black keys, by MIDI, positioned at a multiple of the white-key width.
  static const Map<int, double> blackKeyCenters = {
    61: 1.0,
    63: 2.0,
    66: 4.0,
    68: 5.0,
    70: 6.0,
  };

  static const double blackKeyWidthFactor = 0.56;
  static const double blackKeyHeightFactor = 0.60;

  /// Folds any octave into the drawn one.
  static int? normalise(int? midi) => midi == null ? null : 60 + midi % 12;

  @override
  void paint(Canvas canvas, Size size) {
    final heard = normalise(detectedMidi);
    final whiteW = size.width / whiteKeys.length;
    final whiteH = size.height;
    final blackW = whiteW * blackKeyWidthFactor;
    final blackH = whiteH * blackKeyHeightFactor;

    for (int i = 0; i < whiteKeys.length; i++) {
      final midi = whiteKeys[i];
      final isHeard = isListening && midi == heard;
      final isDown = midi == pressedMidi;

      final rect = Rect.fromLTWH(i * whiteW + 1, 0, whiteW - 2, whiteH - 1);
      final rRect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );

      if (isHeard) {
        canvas.drawRRect(
          rRect.inflate(2),
          Paint()
            ..style = PaintingStyle.fill
            ..color = highlightColor.withValues(alpha: 0.3 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          // A pressed key darkens, which is what a real one does and
          // reads instantly as "I did that". A detected pitch tints in
          // the status colour instead, so the two never look alike.
          ..color = isDown
              ? const Color(0xFFBDBDBD)
              : isHeard
                  ? highlightColor.withValues(alpha: 0.88)
                  : Colors.white,
      );

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = isHeard ? highlightColor : Colors.black38
          ..strokeWidth = isHeard ? 2 : 1,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: solfegeLabels[i],
          style: TextStyle(
            color: isHeard || isDown ? Colors.black : Colors.black45,
            fontSize: whiteW * 0.26,
            fontWeight: isHeard ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: whiteW);
      tp.paint(
        canvas,
        Offset(i * whiteW + (whiteW - tp.width) / 2, whiteH - tp.height - 4),
      );
    }

    blackKeyCenters.forEach((midi, centerFrac) {
      final isHeard = isListening && midi == heard;
      final isDown = midi == pressedMidi;
      final x = centerFrac * whiteW - blackW / 2;
      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, 0, blackW, blackH),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );

      if (isHeard) {
        canvas.drawRRect(
          rRect.inflate(2),
          Paint()
            ..style = PaintingStyle.fill
            ..color = highlightColor.withValues(alpha: 0.4 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          // A black key pressed has to go LIGHTER; darkening black shows
          // nothing.
          ..color = isDown
              ? const Color(0xFF4A4A4A)
              : isHeard
                  ? highlightColor
                  : Colors.black,
      );

      if (isHeard || isDown) {
        canvas.drawRRect(
          rRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = (isHeard ? highlightColor : Colors.white)
                .withValues(alpha: 0.6)
            ..strokeWidth = 1.5,
        );
      }
    });
  }

  @override
  bool shouldRepaint(PianoPainter old) =>
      old.detectedMidi != detectedMidi ||
      old.pressedMidi != pressedMidi ||
      old.highlightColor != highlightColor ||
      old.isListening != isListening ||
      old.glowIntensity != glowIntensity;
}
