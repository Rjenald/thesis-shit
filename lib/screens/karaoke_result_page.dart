// ════════════════════════════════════════════════════════════════════════════
// karaoke_result_page.dart
// ════════════════════════════════════════════════════════════════════════════
// Spotify-style summary shown after a recording stops.
//
// Receives a saved WAV file plus the aligned word-and-note results, then
// renders a scrollable list of cards: timestamp -> word -> notes -> conf.
// ════════════════════════════════════════════════════════════════════════════
library;

import 'dart:io';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/vocal_analysis_service.dart';
import '../services/word_note_sync_service.dart';

class KaraokeResultPage extends StatelessWidget {
  final File wavFile;
  final List<WordAnalysis> words;
  final VocalSummary summary;
  final int durationSec;

  const KaraokeResultPage({
    super.key,
    required this.wavFile,
    required this.words,
    required this.summary,
    required this.durationSec,
  });

  // Group words into "lines" of ~6 words for cleaner display.
  List<List<WordAnalysis>> _groupIntoLines(List<WordAnalysis> ws,
      {int wordsPerLine = 6}) {
    if (ws.isEmpty) return const [];
    final out = <List<WordAnalysis>>[];
    for (int i = 0; i < ws.length; i += wordsPerLine) {
      out.add(ws.sublist(i, (i + wordsPerLine).clamp(0, ws.length)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _groupIntoLines(words);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your Take',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _Header(durationSec: durationSec, summary: summary),
          const SizedBox(height: 24),
          if (words.isEmpty)
            const _EmptyState()
          else
            ...lines.asMap().entries.map(
                  (e) => _LineCard(
                    index: e.key,
                    line: e.value,
                  ),
                ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int durationSec;
  final VocalSummary summary;
  const _Header({required this.durationSec, required this.summary});

  @override
  Widget build(BuildContext context) {
    String fmt(int s) {
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final r = (s % 60).toString().padLeft(2, '0');
      return '$m:$r';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1DB954), Color(0xFF1A8E45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmt(durationSec),
              style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _StatChip(label: 'Clarity',     value: '${summary.clarityPct}%'),
              _StatChip(label: 'Stability',   value: '${summary.stabilityPct}%'),
              _StatChip(label: 'Consistency', value: '${summary.consistencyPct}%'),
              _StatChip(label: 'Transitions', value: '${summary.transitions}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label · $value',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// LINE CARD (one row of words + one row of notes)
// ────────────────────────────────────────────────────────────────────────────
class _LineCard extends StatefulWidget {
  final int index;
  final List<WordAnalysis> line;
  const _LineCard({required this.index, required this.line});

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end:   Offset.zero,
    ).animate(_fade);

    // Stagger animation per line for a Spotify-like reveal.
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtTs(double s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final firstWord = widget.line.first;
    final lineText  = widget.line.map((w) => w.word).join(' ');

    // Build the notes row word-by-word with vertical bars between words:
    //   "G4 A4 | B4 | A4"
    final notesRow = widget.line
        .map((w) => w.notes.isEmpty ? '—' : w.notes.join(' '))
        .join('  |  ');

    final avgConf = widget.line.isEmpty
        ? 0.0
        : widget.line.map((w) => w.confidence).reduce((a, b) => a + b) /
            widget.line.length;
    final confPct = (avgConf * 100).round();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fmtTs(firstWord.start),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 6),
              Text(lineText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(notesRow,
                  style: TextStyle(
                      color: Colors.greenAccent.shade400,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('Confidence: $confPct%',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: const [
          Icon(Icons.mic_off, color: Colors.white24, size: 64),
          SizedBox(height: 12),
          Text('Whisper couldn\'t find any words in this take.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60)),
          SizedBox(height: 4),
          Text('Try singing louder or closer to the mic.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}