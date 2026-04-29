import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WAV generator — pure Dart, no assets needed
// ─────────────────────────────────────────────────────────────────────────────

Uint8List _makeWav(double hz, {int ms = 700}) {
  const sr = 44100;
  final n = (sr * ms / 1000).round();
  final buf = ByteData(44 + n * 2);

  void w(int o, List<int> c) {
    for (int i = 0; i < c.length; i++) { buf.setUint8(o + i, c[i]); }
  }

  w(0, [82, 73, 70, 70]); // RIFF
  buf.setUint32(4, 36 + n * 2, Endian.little);
  w(8, [87, 65, 86, 69]); // WAVE
  w(12, [102, 109, 116, 32]); // fmt
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little); // PCM
  buf.setUint16(22, 1, Endian.little); // mono
  buf.setUint32(24, sr, Endian.little);
  buf.setUint32(28, sr * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  w(36, [100, 97, 116, 97]); // data
  buf.setUint32(40, n * 2, Endian.little);

  final atk = (sr * 0.02).round();
  final rel = (sr * 0.15).round();
  for (int i = 0; i < n; i++) {
    double env = 1.0;
    if (i < atk) {
      env = i / atk;
    } else if (i > n - rel) {
      env = (n - i) / rel;
    }
    // Piano-like timbre: fundamental + 2nd + 3rd harmonic
    final t = i / sr;
    final v = sin(2 * pi * hz * t) * 0.55 +
        sin(4 * pi * hz * t) * 0.25 +
        sin(6 * pi * hz * t) * 0.10;
    final s = (env * v * 32767 * 0.75).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, s, Endian.little);
  }
  return buf.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
//  BytesAudioSource — feeds WAV bytes to just_audio
// ─────────────────────────────────────────────────────────────────────────────

class _BytesSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesSource(this._bytes) : super(tag: 'piano');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Piano key data
// ─────────────────────────────────────────────────────────────────────────────

// Solfège map: note letter/sharp → syllable
const _kSolfege = {
  'C':  'Do',
  'C#': 'Di',
  'D':  'Re',
  'D#': 'Ri',
  'E':  'Mi',
  'F':  'Fa',
  'F#': 'Fi',
  'G':  'Sol',
  'G#': 'Si',
  'A':  'La',
  'A#': 'Li',
  'B':  'Ti',
};

class _PKey {
  final String name;
  final double freq;
  final bool isBlack;
  const _PKey(this.name, this.freq, {this.isBlack = false});

  /// Returns the solfège syllable for this key (e.g. 'Do', 'Re', 'Mi')
  String get solfege {
    // Strip octave number: 'C#4' → 'C#', 'G5' → 'G'
    final note = name.replaceAll(RegExp(r'\d'), '');
    return _kSolfege[note] ?? note;
  }
}

const _kKeys = [
  _PKey('C4', 261.63),
  _PKey('C#4', 277.18, isBlack: true),
  _PKey('D4', 293.66),
  _PKey('D#4', 311.13, isBlack: true),
  _PKey('E4', 329.63),
  _PKey('F4', 349.23),
  _PKey('F#4', 369.99, isBlack: true),
  _PKey('G4', 392.00),
  _PKey('G#4', 415.30, isBlack: true),
  _PKey('A4', 440.00),
  _PKey('A#4', 466.16, isBlack: true),
  _PKey('B4', 493.88),
  _PKey('C5', 523.25),
  _PKey('C#5', 554.37, isBlack: true),
  _PKey('D5', 587.33),
  _PKey('D#5', 622.25, isBlack: true),
  _PKey('E5', 659.25),
  _PKey('F5', 698.46),
  _PKey('F#5', 739.99, isBlack: true),
  _PKey('G5', 783.99),
  _PKey('G#5', 830.61, isBlack: true),
  _PKey('A5', 880.00),
  _PKey('A#5', 932.33, isBlack: true),
  _PKey('B5', 987.77),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Recorded note event
// ─────────────────────────────────────────────────────────────────────────────

class _NoteEvent {
  final _PKey key;
  _NoteEvent(this.key);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PianoModePage
// ─────────────────────────────────────────────────────────────────────────────

class PianoModePage extends StatefulWidget {
  const PianoModePage({super.key});

  @override
  State<PianoModePage> createState() => _PianoModePageState();
}

class _PianoModePageState extends State<PianoModePage> {
  // ── Piano ──────────────────────────────────────────────────────────────────
  String? _pressedKey;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _wavCache = {};

  // ── Recording ──────────────────────────────────────────────────────────────
  bool _isRecording = false;
  final List<_NoteEvent> _sequence = [];

  // ── Student Follow ─────────────────────────────────────────────────────────
  bool _isStudentMode = false;
  int _studentStep = 0;
  bool _isListening = false;
  int _correctFrames = 0;
  String _studentFeedback = '';
  bool _stepDone = false;
  double _currentCents = 0; // live deviation from target in cents
  double _detectedHz = 0;   // live detected frequency

  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  static const _framesNeeded = 8; // hold ~0.5s in tune to advance

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _player.dispose();
    _audioSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Sound playback ─────────────────────────────────────────────────────────

  Future<void> _pressKey(_PKey key) async {
    setState(() => _pressedKey = key.name);

    _wavCache[key.name] ??= _makeWav(key.freq);
    try {
      await _player.stop();
      await _player.setAudioSource(_BytesSource(_wavCache[key.name]!));
      await _player.play();
    } catch (_) {
      // ignore playback errors on unsupported platforms
    }

    if (_isRecording) {
      setState(() => _sequence.add(_NoteEvent(key)));
    }

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _pressedKey == key.name) {
        setState(() => _pressedKey = null);
      }
    });
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
      } else {
        _sequence.clear();
        _isRecording = true;
      }
    });
  }

  // ── Student pitch detection ────────────────────────────────────────────────

  Future<void> _startListening() async {
    final ok = await _audioService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
      return;
    }
    setState(() {
      _isListening = true;
      _correctFrames = 0;
      _studentFeedback = 'Sing into the mic…';
      _stepDone = false;
    });

    _audioSub = _audioService.results.listen((result) {
      if (!mounted || _studentStep >= _sequence.length) return;
      final target = _sequence[_studentStep].key;

      if (result == null || result.frequency <= 0) {
        if (mounted) {
          setState(() {
            _studentFeedback = 'Sing into the mic…';
            _currentCents = 0;
            _detectedHz = 0;
          });
        }
        _correctFrames = 0;
        return;
      }

      final cents = 1200 * log(result.frequency / target.freq) / log(2);

      if (cents.abs() <= 60) {
        _correctFrames++;
        if (mounted) {
          setState(() {
            _studentFeedback = '✓  ${target.name}  —  in tune!';
            _currentCents = cents;
            _detectedHz = result.frequency;
          });
        }
        if (_correctFrames >= _framesNeeded) {
          _correctFrames = 0;
          if (mounted) {
            setState(() {
              _studentStep++;
              _stepDone = _studentStep >= _sequence.length;
              _studentFeedback = _stepDone ? '🎉  Sequence complete!' : '';
              _currentCents = 0;
              _detectedHz = 0;
            });
          }
          if (_stepDone) _stopListening();
        }
      } else {
        _correctFrames = 0;
        final dir = cents > 0 ? '↑ Too high' : '↓ Too low';
        if (mounted) {
          setState(() {
            _studentFeedback =
                '$dir  (${cents.abs().toStringAsFixed(0)}¢ off)';
            _currentCents = cents;
            _detectedHz = result.frequency;
          });
        }
      }
    });
  }

  Future<void> _stopListening() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _resetStudent() {
    setState(() {
      _studentStep = 0;
      _correctFrames = 0;
      _studentFeedback = '';
      _stepDone = false;
      _currentCents = 0;
      _detectedHz = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.white,
        title: const Text('Piano Mode',
            style: TextStyle(
                fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                _chip('Piano', !_isStudentMode, () {
                  setState(() => _isStudentMode = false);
                  if (_isListening) _stopListening();
                }),
                const SizedBox(width: 6),
                _chip('Student Follow', _isStudentMode, () {
                  if (_sequence.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Record a sequence first!')));
                    return;
                  }
                  setState(() {
                    _isStudentMode = true;
                    _resetStudent();
                  });
                }),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNoteDisplay(),
          const SizedBox(height: 4),
          _buildKeyboard(),
          Expanded(
            child: _isStudentMode
                ? _buildStudentPanel()
                : _buildTeacherPanel(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryCyan : AppColors.inputBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.black : AppColors.grey,
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Roboto')),
      ),
    );
  }

  // ── Note display ───────────────────────────────────────────────────────────

  Widget _buildNoteDisplay() {
    // Find the active key object for solfège lookup
    final _PKey? activeKey = _pressedKey != null
        ? _kKeys.firstWhere((k) => k.name == _pressedKey,
            orElse: () => _kKeys.first)
        : (_isStudentMode && _studentStep < _sequence.length
            ? _sequence[_studentStep].key
            : null);

    final noteLabel = activeKey?.name ?? '—';
    final solfegeLabel = activeKey?.solfege ?? '';

    Color feedbackColor = const Color(0xFF4CAF50);
    if (_studentFeedback.startsWith('↑') ||
        _studentFeedback.startsWith('↓')) {
      feedbackColor = const Color(0xFFF44336);
    } else if (_studentFeedback.startsWith('Sing')) {
      feedbackColor = AppColors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.inputBg,
      child: Column(
        children: [
          if (solfegeLabel.isNotEmpty)
            Text(
              solfegeLabel,
              style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                  letterSpacing: 1.5),
            ),
          Text(noteLabel,
              style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
          if (_isStudentMode && _studentFeedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_studentFeedback,
                  style: TextStyle(
                      color: feedbackColor,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  // ── Piano keyboard ─────────────────────────────────────────────────────────

  Widget _buildKeyboard() {
    const ww = 46.0; // white key width
    const wh = 148.0; // white key height
    const bw = 28.0; // black key width
    const bh = 94.0; // black key height

    final whites = <(_PKey, double)>[];
    final blacks = <(_PKey, double)>[];
    int wi = -1;

    for (final key in _kKeys) {
      if (!key.isBlack) {
        wi++;
        whites.add((key, wi * ww));
      } else {
        blacks.add((key, wi * ww + ww - bw / 2));
      }
    }

    final totalW = whites.length * ww;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: totalW,
        height: wh,
        child: Stack(children: [
          // White keys (bottom layer)
          ...whites.map((rec) {
            final key = rec.$1;
            final x = rec.$2;
            final pressed = _pressedKey == key.name;
            final isTarget = _isStudentMode &&
                _studentStep < _sequence.length &&
                _sequence[_studentStep].key.name == key.name;
            return Positioned(
              left: x,
              top: 0,
              child: GestureDetector(
                onTapDown: (_) => _pressKey(key),
                child: Container(
                  width: ww - 1.5,
                  height: wh,
                  decoration: BoxDecoration(
                    color: pressed
                        ? AppColors.primaryCyan.withValues(alpha: 0.55)
                        : isTarget
                            ? AppColors.primaryCyan.withValues(alpha: 0.22)
                            : Colors.white,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(5),
                        bottomRight: Radius.circular(5)),
                    border:
                        Border.all(color: Colors.black26, width: 1),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          key.solfege,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: pressed || isTarget
                                ? AppColors.primaryCyan
                                : const Color(0xFF1565C0),
                            fontFamily: 'Roboto',
                          ),
                        ),
                        Text(
                          key.name.replaceAll(RegExp(r'\d'), ''),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: pressed || isTarget
                                ? AppColors.primaryCyan
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Black keys (top layer)
          ...blacks.map((rec) {
            final key = rec.$1;
            final x = rec.$2;
            final pressed = _pressedKey == key.name;
            final isTarget = _isStudentMode &&
                _studentStep < _sequence.length &&
                _sequence[_studentStep].key.name == key.name;
            return Positioned(
              left: x,
              top: 0,
              child: GestureDetector(
                onTapDown: (_) => _pressKey(key),
                child: Container(
                  width: bw,
                  height: bh,
                  decoration: BoxDecoration(
                    color: pressed
                        ? AppColors.primaryCyan
                        : isTarget
                            ? AppColors.primaryCyan.withValues(alpha: 0.65)
                            : Colors.black87,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4)),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      key.solfege,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: pressed || isTarget
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
        ]),
      ),
    );
  }

  // ── Teacher panel ──────────────────────────────────────────────────────────

  Widget _buildTeacherPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Record row
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : Icons.fiber_manual_record,
                    color: Colors.white,
                    size: 18),
                label: Text(
                    _isRecording
                        ? 'Stop Recording'
                        : 'Record Sequence',
                    style: const TextStyle(fontFamily: 'Roboto')),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isRecording ? Colors.red : AppColors.inputBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            if (_sequence.isNotEmpty) ...[
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFF44336)),
                onPressed: () => setState(() => _sequence.clear()),
                tooltip: 'Clear',
              ),
            ],
          ]),

          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Recording… tap keys above',
                    style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontFamily: 'Roboto')),
              ]),
            ),

          // Recorded sequence chips
          if (_sequence.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
                'Sequence  (${_sequence.length} notes)',
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _sequence.asMap().entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: e.key.isEven
                        ? AppColors.primaryCyan.withValues(alpha: 0.15)
                        : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            AppColors.primaryCyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${e.key + 1}. ${e.value.key.name}',
                    style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _isStudentMode = true;
                  _resetStudent();
                }),
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Switch to Student Follow',
                    style: TextStyle(fontFamily: 'Roboto')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],

          if (_sequence.isEmpty && !_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Column(children: [
                  Icon(Icons.piano,
                      color: AppColors.grey.withValues(alpha: 0.25),
                      size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Tap "Record Sequence" then\npress piano keys to create\na student exercise.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontFamily: 'Roboto',
                        height: 1.5),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Student panel ──────────────────────────────────────────────────────────

  Widget _buildStudentPanel() {
    if (_stepDone) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF4CAF50), size: 80),
            const SizedBox(height: 16),
            const Text('Sequence Complete!',
                style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 8),
            Text('${_sequence.length} / ${_sequence.length} notes correct',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontFamily: 'Roboto')),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _resetStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inputBg,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontFamily: 'Roboto')),
            ),
          ],
        ),
      );
    }

    final current = _sequence[_studentStep].key;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          // Step progress dots (smaller)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 5,
            children: _sequence.asMap().entries.map((e) {
              final idx = e.key;
              final state = idx < _studentStep
                  ? 'done'
                  : idx == _studentStep
                      ? 'current'
                      : 'pending';
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: state == 'done'
                      ? const Color(0xFF4CAF50)
                      : state == 'current'
                          ? AppColors.primaryCyan
                          : AppColors.inputBg,
                  shape: BoxShape.circle,
                  border: state == 'current'
                      ? Border.all(color: AppColors.primaryCyan, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    e.value.key.solfege,
                    style: TextStyle(
                        color: state == 'pending'
                            ? AppColors.grey
                            : Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Step counter
          Text(
            '${_studentStep + 1} / ${_sequence.length}  •  ${current.solfege} (${current.name})',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.55),
                fontSize: 12,
                fontFamily: 'Roboto'),
          ),

          const SizedBox(height: 14),

          // Mic button + label inline
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red
                        : Colors.red.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.red,
                      size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isListening ? 'Listening…' : 'Tap mic to start',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isListening
                        ? 'Sing into the mic'
                        : 'Then sing the note shown above',
                    style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontFamily: 'Roboto'),
                  ),
                ],
              ),
            ],
          ),

          if (_isListening) ...[
            const SizedBox(height: 14),
            _buildPitchGauge(),
          ],
        ],
      ),
    );
  }

  // ── Pitch gauge ────────────────────────────────────────────────────────────

  Widget _buildPitchGauge() {
    final clampedCents = _currentCents.clamp(-200.0, 200.0);
    // FractionalOffset x: 0 = left edge, 1 = right edge
    final needleX = (clampedCents + 200) / 400;
    final inTune = _currentCents.abs() <= 60;
    final close = _currentCents.abs() <= 120;
    final hasSignal = _detectedHz > 0;

    final needleColor = !hasSignal
        ? AppColors.grey
        : inTune
            ? const Color(0xFF4CAF50)
            : close
                ? const Color(0xFFFFA726)
                : const Color(0xFFF44336);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Direction labels ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('↓ Lower',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
            Text(
              hasSignal ? '${_detectedHz.toStringAsFixed(1)} Hz' : '— Hz',
              style: TextStyle(
                  color: needleColor,
                  fontSize: 11,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600),
            ),
            Text('↑ Higher',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Roboto')),
          ],
        ),
        const SizedBox(height: 4),

        // ── Gauge bar (fixed height, no LayoutBuilder) ──────────────────────
        SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Color zone track
              Positioned.fill(
                top: 10,
                bottom: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Container(
                            color: const Color(0xFFF44336)
                                .withValues(alpha: 0.20))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.22))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFF4CAF50)
                                .withValues(alpha: 0.28))),
                    Expanded(
                        flex: 1,
                        child: Container(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.22))),
                    Expanded(
                        flex: 2,
                        child: Container(
                            color: const Color(0xFFF44336)
                                .withValues(alpha: 0.20))),
                  ]),
                ),
              ),

              // Center target line (using Align — no pixel math)
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // TARGET label below center
              Align(
                alignment: const Alignment(0, 1),
                child: Text(
                  'TARGET',
                  style: TextStyle(
                      color:
                          const Color(0xFF4CAF50).withValues(alpha: 0.7),
                      fontSize: 7,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),

              // Needle — uses FractionalOffset, no pixel calculation
              Align(
                alignment: FractionalOffset(needleX, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(10, 8),
                        painter: _TrianglePainter(needleColor),
                      ),
                      Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(
                          color: needleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Cents readout ────────────────────────────────────────────────────
        Center(
          child: Text(
            hasSignal
                ? inTune
                    ? '${_currentCents.toStringAsFixed(0)}¢  —  in tune!'
                    : '${_currentCents > 0 ? '+' : ''}${_currentCents.toStringAsFixed(0)}¢  ${_currentCents > 0 ? '(sing lower)' : '(sing higher)'}'
                : 'Waiting for signal…',
            style: TextStyle(
                color: needleColor,
                fontSize: 12,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 10),

        // ── Hold progress bar ────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _correctFrames / _framesNeeded,
            minHeight: 5,
            backgroundColor: AppColors.inputBg,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
        ),
        const SizedBox(height: 3),
        Center(
          child: Text('Hold in tune to advance',
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontFamily: 'Roboto')),
        ),
      ],
    );
  }
}

// ── Triangle painter for needle tip ───────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
