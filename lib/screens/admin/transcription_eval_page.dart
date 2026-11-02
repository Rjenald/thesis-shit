import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/eval_batch_service.dart';

/// Runs the app's own Whisper transcription over a folder of WAV clips and
/// writes the results out, so transcription accuracy can be measured
/// instead of asserted.
///
/// Admin-only, and deliberately a measurement tool rather than a feature:
/// nothing here changes how the app transcribes. It exists because
/// backend/evaluate_transcription.py scores the app's real output, and
/// feeding it a thousand clips by hand is not possible.
class TranscriptionEvalPage extends StatefulWidget {
  const TranscriptionEvalPage({super.key});

  @override
  State<TranscriptionEvalPage> createState() => _TranscriptionEvalPageState();
}

class _TranscriptionEvalPageState extends State<TranscriptionEvalPage> {
  /// Languages worth measuring. 'auto' is included because Search & Sing
  /// uses it, so it is a condition that ships.
  static const _languages = ['tl', 'en', 'auto'];

  String _lang = 'tl';
  List<File> _clips = [];
  String? _clipsPath;
  bool _loading = true;
  bool _running = false;
  bool _cancelRequested = false;
  EvalBatchProgress? _progress;
  EvalBatchReport? _report;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final dir = await EvalBatchService.clipsDir();
      final clips = await EvalBatchService.listClips();
      if (!mounted) return;
      setState(() {
        _clips = clips;
        _clipsPath = dir?.path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not read the clips folder: $e', isError: true);
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _cancelRequested = false;
      _progress = null;
      _report = null;
    });

    try {
      final report = await EvalBatchService.runBatch(
        defaultLang: _lang,
        shouldCancel: () => _cancelRequested,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _report = report;
      });
      _toast(report.incomplete
          ? 'Stopped after ${report.transcribed} of ${report.totalClips}.'
          : 'Transcribed ${report.transcribed} clips.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      _toast('Batch failed: $e', isError: true);
    }
  }

  Future<void> _share() async {
    final path = _report?.outputPath;
    if (path == null) return;
    try {
      await Share.shareXFiles([XFile(path)],
          subject: 'Huni transcription hypotheses');
    } catch (e) {
      _toast('Could not share the file: $e', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Roboto')),
        backgroundColor: isError ? AppColors.errorRed : AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: const Text('Transcription accuracy',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto')),
        actions: [
          IconButton(
            tooltip: 'Rescan folder',
            onPressed: _running ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _explainer(),
          const SizedBox(height: 16),
          _clipsCard(),
          const SizedBox(height: 16),
          _languageCard(),
          const SizedBox(height: 16),
          _runCard(),
          if (_progress != null) ...[
            const SizedBox(height: 16),
            _progressCard(),
          ],
          if (_report != null) ...[
            const SizedBox(height: 16),
            _reportCard(),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto'));

  Widget _body(String text) => Text(text,
      style: TextStyle(
          color: AppColors.grey.withValues(alpha: 0.9),
          fontSize: 12,
          height: 1.45,
          fontFamily: 'Roboto'));

  Widget _explainer() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined,
                    color: AppColors.primaryCyan, size: 18),
                const SizedBox(width: 8),
                _label('What this measures'),
              ],
            ),
            const SizedBox(height: 10),
            _body('Each clip goes through the same on-device Whisper call '
                'the result screens use — same bundled model, same decode '
                'settings, same phone. The output is the decoder\'s raw '
                'text, so the figure describes what ships.\n\n'
                'A clip\'s reference transcript is never given to the '
                'model. Scoring against text the decoder was handed would '
                'measure nothing.'),
          ],
        ),
      );

  Widget _clipsCard() {
    if (_loading) {
      return _card(
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryCyan),
            ),
            const SizedBox(width: 12),
            _body('Reading the clips folder…'),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('Clips found'),
              Text('${_clips.length}',
                  style: TextStyle(
                      color: _clips.isEmpty
                          ? AppColors.errorRed
                          : AppColors.primaryCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 10),
          if (_clips.isEmpty)
            _body('No .wav files yet. Put them in the folder below — '
                'adb push can write to it without root:\n\n'
                'adb push clips/. "<folder>/"\n\n'
                'backend/fetch_eval_datasets.py builds that folder, '
                'including the clips.json that sets each clip\'s language.')
          else
            _body('${_clips.length} clip${_clips.length == 1 ? '' : 's'} '
                'queued, in filename order so two runs stay comparable.'),
          const SizedBox(height: 10),
          SelectableText(
            _clipsPath ?? 'No external storage available',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.75),
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _languageCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Default language'),
            const SizedBox(height: 6),
            _body('Used for any clip clips.json does not name. The language '
                'token conditions the whole decode, so this is itself worth '
                'measuring rather than assuming.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final lang in _languages)
                  ChoiceChip(
                    label: Text(lang,
                        style: TextStyle(
                            color: _lang == lang
                                ? Colors.black
                                : AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto')),
                    selected: _lang == lang,
                    onSelected: _running
                        ? null
                        : (_) => setState(() => _lang = lang),
                    backgroundColor: AppColors.inputBg,
                    selectedColor: AppColors.primaryCyan,
                    showCheckmark: false,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _runCard() {
    final canRun = !_running && _clips.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canRun ? _run : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              disabledBackgroundColor: AppColors.inputBg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(_running ? Icons.hourglass_top : Icons.play_arrow,
                color: canRun ? Colors.black : AppColors.grey),
            label: Text(
              _running ? 'Transcribing…' : 'Transcribe all clips',
              style: TextStyle(
                  color: canRun ? Colors.black : AppColors.grey,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto'),
            ),
          ),
        ),
        if (_running) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _cancelRequested
                ? null
                : () => setState(() => _cancelRequested = true),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: const BorderSide(color: AppColors.errorRed),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_cancelRequested ? 'Stopping…' : 'Stop',
                style: const TextStyle(
                    color: AppColors.errorRed, fontFamily: 'Roboto')),
          ),
        ],
      ],
    );
  }

  Widget _progressCard() {
    final p = _progress!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('${p.done} / ${p.total}'),
              if (p.failures > 0)
                Text('${p.failures} failed',
                    style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 12,
                        fontFamily: 'Roboto')),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.total == 0 ? 0 : p.done / p.total,
              minHeight: 6,
              backgroundColor: AppColors.inputBg,
              color: AppColors.primaryCyan,
            ),
          ),
          const SizedBox(height: 12),
          _body(p.currentId),
          const SizedBox(height: 4),
          Text(
            p.lastHypothesis.isEmpty ? '(nothing recognized)' : p.lastHypothesis,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: p.lastHypothesis.isEmpty
                    ? AppColors.errorRed
                    : AppColors.white,
                fontSize: 12,
                height: 1.4,
                fontFamily: 'Roboto'),
          ),
        ],
      ),
    );
  }

  Widget _reportCard() {
    final r = _report!;
    final seconds = r.elapsedMs / 1000;
    final perClip = r.transcribed == 0 ? 0.0 : seconds / r.transcribed;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.failures > 0 ? Icons.warning_amber : Icons.check_circle,
                  color: r.failures > 0
                      ? AppColors.errorRed
                      : AppColors.primaryCyan,
                  size: 18),
              const SizedBox(width: 8),
              _label(r.incomplete ? 'Stopped early' : 'Done'),
            ],
          ),
          const SizedBox(height: 10),
          _body('${r.transcribed} of ${r.totalClips} clips in '
              '${seconds.toStringAsFixed(1)}s '
              '(${perClip.toStringAsFixed(2)}s per clip)'
              '${r.failures > 0 ? '\n${r.failures} returned nothing — '
                  'written as empty hypotheses, not dropped.' : ''}'),
          const SizedBox(height: 10),
          SelectableText(
            r.outputPath,
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.75),
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          _body('Score it with:\n'
              'python evaluate_transcription.py clips.json '
              '--merge hypotheses.json'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _share,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryCyan),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.ios_share,
                color: AppColors.primaryCyan, size: 18),
            label: const Text('Export hypotheses.json',
                style: TextStyle(
                    color: AppColors.primaryCyan, fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }
}
