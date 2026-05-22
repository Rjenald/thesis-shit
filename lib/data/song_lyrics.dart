import '../services/lyrics_service.dart';

/// Local lyrics for featured songs (fallback when lrclib.net doesn't have them).
class LocalSongLyrics {
  static List<LrcLine>? getLyrics(String title) {
    switch (title.toLowerCase()) {
      case 'dadalhin':
        return _dadalhinLyrics;
      case 'nasa iyo na ang lahat':
        return _nasaIyoLyrics;
      default:
        return null;
    }
  }

  static final List<LrcLine> _dadalhinLyrics = [
    LrcLine(timestamp: Duration(seconds: 0), text: '♪ Intro ♪'),
    LrcLine(timestamp: Duration(seconds: 12), text: 'Dadalhin ang init ng pag-ibig ko'),
    LrcLine(timestamp: Duration(seconds: 18), text: 'Sa bawat sandali ng buhay mo'),
    LrcLine(timestamp: Duration(seconds: 24), text: 'Dadalhin ang lahat ng pangarap'),
    LrcLine(timestamp: Duration(seconds: 30), text: 'Sa \'yo lamang ibibigay'),
    LrcLine(timestamp: Duration(seconds: 37), text: 'Kahit saan man ako dalhin ng hangin'),
    LrcLine(timestamp: Duration(seconds: 43), text: 'Ikaw pa rin ang aking hahanapin'),
    LrcLine(timestamp: Duration(seconds: 50), text: 'Dadalhin kita sa langit'),
    LrcLine(timestamp: Duration(seconds: 56), text: 'Dadalhin kita sa ulap'),
    LrcLine(timestamp: Duration(seconds: 63), text: 'Saan man magpunta'),
    LrcLine(timestamp: Duration(seconds: 68), text: 'Ikaw lang ang kasama'),
    LrcLine(timestamp: Duration(seconds: 75), text: 'Dadalhin ang puso ko sa iyo'),
    LrcLine(timestamp: Duration(seconds: 82), text: 'Hanggang sa dulo ng panahon'),
    LrcLine(timestamp: Duration(seconds: 90), text: 'Dadalhin ang lahat ng aking mayroon'),
    LrcLine(timestamp: Duration(seconds: 97), text: 'Para sa iyong ngiti lamang'),
    LrcLine(timestamp: Duration(seconds: 105), text: 'Kahit anong mangyari'),
    LrcLine(timestamp: Duration(seconds: 112), text: 'Di kita iiwan'),
    LrcLine(timestamp: Duration(seconds: 118), text: 'Dadalhin kita sa pangarap natin'),
    LrcLine(timestamp: Duration(seconds: 125), text: 'Magkasama habang buhay'),
    LrcLine(timestamp: Duration(seconds: 135), text: '♪ Outro ♪'),
  ];

  static final List<LrcLine> _nasaIyoLyrics = [
    LrcLine(timestamp: Duration(seconds: 0), text: '♪ Intro ♪'),
    LrcLine(timestamp: Duration(seconds: 10), text: 'Nasa iyo na ang lahat'),
    LrcLine(timestamp: Duration(seconds: 16), text: 'Wala na akong hihilingin pa'),
    LrcLine(timestamp: Duration(seconds: 22), text: 'Ang puso ko\'y sa iyo lamang'),
    LrcLine(timestamp: Duration(seconds: 28), text: 'Hindi na magbabago pa'),
    LrcLine(timestamp: Duration(seconds: 35), text: 'Kahit ano\'ng mangyari'),
    LrcLine(timestamp: Duration(seconds: 41), text: 'Ikaw pa rin ang pipiliin ko'),
    LrcLine(timestamp: Duration(seconds: 48), text: 'Nasa iyo na ang lahat'),
    LrcLine(timestamp: Duration(seconds: 54), text: 'Ang buhay ko\'y sa kamay mo'),
    LrcLine(timestamp: Duration(seconds: 62), text: 'Hindi ko na kailangan'),
    LrcLine(timestamp: Duration(seconds: 68), text: 'Ng iba pang kayamanan'),
    LrcLine(timestamp: Duration(seconds: 75), text: 'Kung ikaw ay nasa akin'),
    LrcLine(timestamp: Duration(seconds: 82), text: 'Sapat na ang lahat'),
    LrcLine(timestamp: Duration(seconds: 90), text: 'Nasa iyo na ang lahat ng puso ko'),
    LrcLine(timestamp: Duration(seconds: 97), text: 'Ang bawat tibok nito'),
    LrcLine(timestamp: Duration(seconds: 104), text: 'Para sa iyo lamang'),
    LrcLine(timestamp: Duration(seconds: 112), text: 'Hanggang sa huli'),
    LrcLine(timestamp: Duration(seconds: 118), text: 'Ikaw lang ang mamahalin'),
    LrcLine(timestamp: Duration(seconds: 125), text: 'Nasa iyo na ang lahat'),
    LrcLine(timestamp: Duration(seconds: 135), text: '♪ Outro ♪'),
  ];
}
