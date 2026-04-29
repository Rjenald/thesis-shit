/// Reusable piano keyboard widget with real WAV sound synthesis.
/// Drop it anywhere — it manages its own AudioPlayer and WAV cache.
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/app_colors.dart';
import '../core/piano_audio.dart';

export '../core/piano_audio.dart' show PianoKey, pianoOctaveKeys;

/// A horizontally-scrollable, one-octave piano keyboard (C4–C5) with
/// pure-Dart WAV synthesis. Tap any key to play its note.
///
/// [onKeyPressed] is called every time a key is tapped.
/// [highlightedNote] optionally highlights a specific note name (e.g. 'E4').
class PianoKeyboardWidget extends StatefulWidget {
  final void Function(PianoKey key)? onKeyPressed;
  final String? highlightedNote;

  /// Height of white keys (default 140).
  final double keyHeight;

  /// Width of each white key (default 46).
  final double whiteKeyWidth;

  const PianoKeyboardWidget({
    super.key,
    this.onKeyPressed,
    this.highlightedNote,
    this.keyHeight = 140.0,
    this.whiteKeyWidth = 46.0,
  });

  @override
  State<PianoKeyboardWidget> createState() => _PianoKeyboardWidgetState();
}

class _PianoKeyboardWidgetState extends State<PianoKeyboardWidget> {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};
  String? _pressedKey;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pressKey(PianoKey key) async {
    setState(() => _pressedKey = key.name);
    widget.onKeyPressed?.call(key);

    // Generate WAV on first press, then cache
    _cache[key.name] ??= makePianoWav(key.freq);
    try {
      await _player.stop();
      await _player.setAudioSource(PianoWavSource(_cache[key.name]!));
      await _player.play();
    } catch (_) {
      // Ignore playback errors (e.g. on emulators)
    }

    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted && _pressedKey == key.name) {
        setState(() => _pressedKey = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ww = widget.whiteKeyWidth;
    final wh = widget.keyHeight;
    final bw = ww * 0.60;
    final bh = wh * 0.62;

    // Lay out white and black keys
    final whites = <(PianoKey, double)>[];
    final blacks = <(PianoKey, double)>[];
    int wi = -1;

    for (final key in pianoOctaveKeys) {
      if (!key.isBlack) {
        wi++;
        whites.add((key, wi * ww));
      } else {
        blacks.add((key, wi * ww + ww - bw / 2));
      }
    }

    final totalW = whites.length * ww;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          height: wh,
          child: Stack(
            children: [
              // ── White keys ───────────────────────────────────────────────
              ...whites.map((rec) {
                final key = rec.$1;
                final x = rec.$2;
                final pressed = _pressedKey == key.name;
                final highlighted = widget.highlightedNote == key.name;
                return Positioned(
                  left: x,
                  top: 0,
                  child: GestureDetector(
                    onTapDown: (_) => _pressKey(key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: ww - 1.5,
                      height: wh,
                      decoration: BoxDecoration(
                        color: pressed
                            ? AppColors.primaryCyan.withValues(alpha: 0.55)
                            : highlighted
                                ? AppColors.primaryCyan.withValues(alpha: 0.22)
                                : Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        border:
                            Border.all(color: Colors.black26, width: 1),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              key.solfege,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: (pressed || highlighted)
                                    ? AppColors.primaryCyan
                                    : const Color(0xFF1565C0),
                                fontFamily: 'Roboto',
                              ),
                            ),
                            Text(
                              key.note,
                              style: TextStyle(
                                fontSize: 9,
                                color: (pressed || highlighted)
                                    ? AppColors.primaryCyan
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Black keys ───────────────────────────────────────────────
              ...blacks.map((rec) {
                final key = rec.$1;
                final x = rec.$2;
                final pressed = _pressedKey == key.name;
                final highlighted = widget.highlightedNote == key.name;
                return Positioned(
                  left: x,
                  top: 0,
                  child: GestureDetector(
                    onTapDown: (_) => _pressKey(key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: bw,
                      height: bh,
                      decoration: BoxDecoration(
                        color: pressed
                            ? AppColors.primaryCyan
                            : highlighted
                                ? AppColors.primaryCyan.withValues(alpha: 0.65)
                                : Colors.black87,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          key.solfege,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: (pressed || highlighted)
                                ? Colors.black
                                : Colors.white54,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
