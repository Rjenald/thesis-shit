import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class RecordedKaraokePage extends StatefulWidget {
  /// Path or URL to the recorded audio file.
  /// If null, the page shows a "no recording" state.
  final String? audioPath;
  final String title;

  const RecordedKaraokePage({
    super.key,
    this.audioPath,
    this.title = 'Recorded Karaoke',
  });

  @override
  State<RecordedKaraokePage> createState() => _RecordedKaraokePageState();
}

class _RecordedKaraokePageState extends State<RecordedKaraokePage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _loaded = false;

  late final AnimationController _waveAnim;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();

    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _posSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(
          () => _isPlaying =
              state.playing &&
              state.processingState != ProcessingState.completed,
        );
      }
    });

    _loadAudio();
  }

  Future<void> _loadAudio() async {
    if (widget.audioPath == null || widget.audioPath!.isEmpty) return;
    try {
      if (widget.audioPath!.startsWith('http')) {
        await _player.setUrl(widget.audioPath!);
      } else {
        await _player.setFilePath(widget.audioPath!);
      }
      if (mounted) setState(() => _loaded = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (!_loaded) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> _skip(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target.isNegative
        ? Duration.zero
        : (target > _duration ? _duration : target);
    await _player.seek(clamped);
  }

  Future<void> _cycleSpeed() async {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.5, 0.75];
    final idx = speeds.indexOf(_speed);
    _speed = speeds[(idx + 1) % speeds.length];
    await _player.setSpeed(_speed);
    if (mounted) setState(() {});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours.toString().padLeft(2, '0')}:' : ''}$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildWaveform()),
            _buildTimestamp(),
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  // ── Waveform ──────────────────────────────────────────────────────────────

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveAnim,
      builder: (ctx, child) {
        final progress = _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;
        return CustomPaint(
          painter: _WaveformPainter(
            progress: progress,
            animValue: _waveAnim.value,
            isPlaying: _isPlaying,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  // ── Timestamp ─────────────────────────────────────────────────────────────

  Widget _buildTimestamp() {
    return Text(
      '${_fmt(_position)} / ${_fmt(_duration)}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 14,
        fontFamily: 'Roboto',
        letterSpacing: 1,
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Repeat
        _ctrlBtn(
          icon: Icons.repeat,
          label: 'repeat',
          size: 22,
          onTap: () async {
            final mode = _player.loopMode == LoopMode.one
                ? LoopMode.off
                : LoopMode.one;
            await _player.setLoopMode(mode);
            setState(() {});
          },
          active: _player.loopMode == LoopMode.one,
        ),

        // -3s
        _ctrlBtn(
          icon: Icons.replay,
          label: '-3s',
          size: 22,
          onTap: () => _skip(-3),
        ),

        // Play / Pause (large)
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
              size: 30,
            ),
          ),
        ),

        // +3s
        _ctrlBtn(
          icon: Icons.forward_10,
          label: '+3s',
          size: 22,
          onTap: () => _skip(3),
        ),

        // Speed
        GestureDetector(
          onTap: _cycleSpeed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_speed % 1 == 0 ? _speed.toInt() : _speed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'speed',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required String label,
    required double size,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active
                ? const Color(0xFF00ACC1)
                : Colors.white.withValues(alpha: 0.85),
            size: size,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waveform painter ──────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double animValue;
  final bool isPlaying;

  _WaveformPainter({
    required this.progress,
    required this.animValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // ── Vertical centre line ─────────────────────────────────────────────
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), linePaint);

    // ── Waveform bars ────────────────────────────────────────────────────
    final rng = math.Random(42);
    const barCount = 60;
    final barSpacing = size.height / barCount;

    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fadePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.3)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final y = i * barSpacing + barSpacing / 2;

      // Amplitude based on a sinusoidal shape + random variation.
      final wave = math.sin(i * 0.4 + animValue * math.pi * 2) * 0.5 + 0.5;
      final noise = rng.nextDouble();
      final amp =
          (wave * 0.6 + noise * 0.4) *
          (size.width * 0.35) *
          (isPlaying
              ? (0.7 + math.sin(animValue * math.pi * 4 + i * 0.3) * 0.3)
              : 1.0);

      // Bars to the left and right of centre line.
      final paint = (i / barCount) < progress ? redPaint : fadePaint;
      canvas.drawLine(Offset(cx - amp, y), Offset(cx + amp * 0.6, y), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.animValue != animValue ||
      old.isPlaying != isPlaying;
}
