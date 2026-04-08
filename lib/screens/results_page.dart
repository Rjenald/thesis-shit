import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'karaoke_home_page.dart';

class ResultsPage extends StatelessWidget {
  final String songTitle;
  final String songArtist;

  const ResultsPage({
    super.key,
    this.songTitle = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
  });

  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFF44336);

  // Each entry: [lyric line, color] — green=correct, red=wrong, null=spacer
  static final List<(String, Color?)> _resultLyrics = [
    ("Nag-iisa at hindi mapakali", _green),
    ("Ibang-iba pala 'pag wala ka sa aking tabi", _green),
    ("Pinipillit kong limutin ka nguni't di magawa", _green),
    ("Sa bawat kong galaw ay laging hanap ka", _red),
    ("", null),
    ("Nag-iisa ang isang kagaya mo", _green),
    ("Na nagmahal at nagt'yaga sa isang katulad ko", _green),
    ("Bakit nga ba di ko man lang nabigyan ng halaga?", _red),
    ("Nagsisisi ngayong wala ka na", _green),
    ("", null),
    ("Kulang ako kung wala ka", _green),
    ("Di ako mabubuo kung di kita kasama", _green),
    ("Nasanay na ako na lagi kang nariyan", _red),
    ("Di ko kayang mag-isa, puso ay pagbigyan", _green),
    ("Kulang ako, kulang ako kung wala ka", _green),
    ("", null),
    ("Nag-iisa sa bawat sandali", _green),
    ("At tila ba biglang nahati ang aking daigdig", _red),
    ("Umaasa na sana'y maging tayong dalawa muli", _green),
    ("Sa puso ko'y wala kang kapalit", _green),
    ("", null),
    ("Kulang ako kung wala ka", _green),
    ("Di ako mabubuo kung di kita kasama", _green),
    ("Nasanay na ako na lagi kang nariyan", _green),
    ("Di ko kayang mag-isa, puso ay pagbigyan", _red),
    ("Kulang ako, kulang ako kung wala ka, oh", _green),
  ];

  int get _correctCount =>
      _resultLyrics.where((l) => l.$1.isNotEmpty && l.$2 == _green).length;
  int get _wrongCount =>
      _resultLyrics.where((l) => l.$1.isNotEmpty && l.$2 == _red).length;
  double get _scorePercent =>
      _correctCount / (_correctCount + _wrongCount).clamp(1, 9999);
  int get _score => (_scorePercent * 100).round();
  int get _stars {
    if (_score >= 95) return 5;
    if (_score >= 80) return 4;
    if (_score >= 65) return 3;
    if (_score >= 50) return 2;
    return 1;
  }

  void _onSave(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Saved Successfully',
              style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 26,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Results',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            // Song info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: AppColors.primaryCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            songTitle,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Roboto',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            songArtist,
                            style: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Score circle
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _scorePercent,
                    strokeWidth: 9,
                    backgroundColor: AppColors.inputBg,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryCyan,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'pts',
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < _stars
                      ? Colors.amber
                      : AppColors.grey.withValues(alpha: 0.35),
                  size: 26,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard(_correctCount, 'Correct', _green),
                const SizedBox(width: 12),
                _buildStatCard(_wrongCount, 'Wrong', _red),
              ],
            ),

            const SizedBox(height: 16),

            // Result Lyrics label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Result Lyrics',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Correct',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Wrong',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Color-coded lyrics
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _resultLyrics.length,
                  itemBuilder: (context, index) {
                    final item = _resultLyrics[index];
                    if (item.$1.isEmpty) return const SizedBox(height: 10);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: item.$2 ?? AppColors.white,
                          fontSize: 13,
                          fontFamily: 'Roboto',
                          height: 1.6,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Try Again + Save buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KaraokeHomePage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.inputBg,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onSave(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.8),
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}
