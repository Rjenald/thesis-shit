import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// The picture that gets shared or saved: a fixed-size card summarising one
/// take.
///
/// Built as its own widget rather than captured from the result screen,
/// because a result screen is a tall scrolling page with buttons on it. A
/// card has a known size, no controls in it, and shows only what reads at
/// a glance on someone else's phone.
///
/// Two shapes, because the modes genuinely differ: a scored take leads
/// with its percentage, and a reference-free take has no score to lead
/// with, so it leads with what was actually detected. Inventing a score
/// for the second would be the easy way to make one card fit both and
/// would be a lie about what the app measured.
class ShareableResultCard extends StatelessWidget {
  /// Card width in logical pixels. Portrait 4:5, which is what the common
  /// social feeds crop least.
  static const width = 400.0;
  static const height = 500.0;

  final String songTitle;
  final String songArtist;

  /// 0-100, or null for a reference-free take (Freestyle / Search & Sing),
  /// which has no target melody to score against.
  final double? score;

  /// Shown under the score. Ignored when [score] is null.
  final String? scoreLabel;

  /// Up to three small stats, rendered along the bottom.
  final List<ShareStat> stats;

  /// A short excerpt of what was sung, when there is one worth showing.
  final String? excerpt;

  final DateTime completedAt;

  const ShareableResultCard({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.completedAt,
    this.score,
    this.scoreLabel,
    this.stats = const [],
    this.excerpt,
  });

  bool get _isScored => score != null;

  /// The score bands have to agree with the ones the results screen shows,
  /// or a shared card contradicts the colour the user just saw.
  @visibleForTesting
  Color get accentForTest => _accent;

  Color get _accent {
    if (!_isScored) return AppColors.primaryCyan;
    final s = score!;
    if (s >= 80) return const Color(0xFF4CAF50);
    if (s >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery is given explicitly so the card renders identically
    // regardless of the device it is captured on — otherwise a large
    // system font scale would reflow the text inside the shared image.
    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF101014),
                AppColors.bgDark,
                _accent.withValues(alpha: 0.18),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // A soft bloom behind the headline, so the card has some
              // depth rather than reading as a flat screenshot.
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _accent.withValues(alpha: 0.28),
                      _accent.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brand(),
                    const Spacer(),
                    if (_isScored) _scoreBlock() else _unscoredBlock(),
                    const SizedBox(height: 20),
                    _songBlock(),
                    if (excerpt != null && excerpt!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _excerptBlock(),
                    ],
                    const Spacer(),
                    if (stats.isNotEmpty) _statsRow(),
                    const SizedBox(height: 14),
                    _footer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand() => Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.graphic_eq,
                color: Colors.black, size: 17),
          ),
          const SizedBox(width: 9),
          const Text('Huni',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  fontFamily: 'Roboto')),
          const Spacer(),
          Text(
            _isScored ? 'SCORED KARAOKE' : 'VOICE ANALYSIS',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.85),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                fontFamily: 'Roboto'),
          ),
        ],
      );

  Widget _scoreBlock() => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${score!.round()}',
            style: TextStyle(
                color: _accent,
                fontSize: 86,
                height: 0.95,
                fontWeight: FontWeight.w800,
                fontFamily: 'Roboto'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2),
            child: Text('%',
                style: TextStyle(
                    color: _accent.withValues(alpha: 0.75),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto')),
          ),
          const SizedBox(width: 10),
          if (scoreLabel != null)
            // Flexible, not a Spacer plus fixed chip: a three-digit score
            // ("100") next to a long label ("Needs work") overflowed the
            // row, and 100% is reachable.
            Flexible(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(scoreLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: _accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Roboto')),
                  ),
                ),
              ),
            ),
        ],
      );

  /// The headline for a take with no reference melody. It says what the
  /// app did do — detect notes and words — instead of showing a number it
  /// has no basis for.
  Widget _unscoredBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.graphic_eq, color: _accent, size: 40),
          const SizedBox(height: 12),
          const Text('I just sang this',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Roboto')),
        ],
      );

  Widget _songBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            songTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 21,
                height: 1.25,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto'),
          ),
          if (songArtist.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              songArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontFamily: 'Roboto'),
            ),
          ],
        ],
      );

  Widget _excerptBlock() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(11),
          border: Border(
            left: BorderSide(color: _accent.withValues(alpha: 0.75), width: 3),
          ),
        ),
        child: Text(
          excerpt!.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
              fontStyle: FontStyle.italic,
              fontFamily: 'Roboto'),
        ),
      );

  Widget _statsRow() => Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withValues(alpha: 0.12),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 1),
                  Text(stats[i].label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.8),
                          fontSize: 8.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
          ],
        ],
      );

  Widget _footer() => Row(
        children: [
          Text(
            _formatDate(completedAt),
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 10.5,
                fontFamily: 'Roboto'),
          ),
          const Spacer(),
          Text(
            'Huni Singing Coach',
            style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 10.5,
                fontFamily: 'Roboto'),
          ),
        ],
      );

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// One small figure along the bottom of the card.
class ShareStat {
  final String label;
  final String value;
  const ShareStat(this.label, this.value);
}
