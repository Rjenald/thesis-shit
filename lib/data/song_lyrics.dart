import '../services/lyrics_service.dart';

/// Local lyrics for featured songs (fallback when lrclib.net doesn't have them).
/// Timestamps are synced to the karaoke MP3 files in web/audio/.
class LocalSongLyrics {
  static List<LrcLine>? getLyrics(String title) {
    switch (title.toLowerCase()) {
      case 'dadalhin':
        return _dadalhinLyrics;
      case 'nasa iyo na ang lahat':
        return _nasaIyoLyrics;
      case 'paalam muna sandali':
        return _paalamMunaSandaliLyrics;
      case 'ulap':
        return _ulapLyrics;
      case 'fallen':
        return _fallenLyrics;
      default:
        return null;
    }
  }

  // ── Dadalhin - Regine Velasquez (4:43) ────────────────────────────────────
  static final List<LrcLine> _dadalhinLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 0), text: '♪ Intro ♪'),
    LrcLine(timestamp: Duration(milliseconds: 14620), text: 'Ang pangarap ko\'y nagmula sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 20930), text: 'Sa \'yong ganda, ang puso\'y \'di makalimot'),
    LrcLine(timestamp: Duration(milliseconds: 27790), text: 'Tuwing kapiling ka, tanging nadarama'),
    LrcLine(timestamp: Duration(milliseconds: 34190), text: 'Ang pagsilip ng bituin sa \'yong mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 42370), text: 'Ang saya nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 48860), text: 'Sana ay \'di na mag-iiba'),
    LrcLine(timestamp: Duration(milliseconds: 54800), text: 'Ang pangarap ko ang \'yong binubuhay'),
    LrcLine(timestamp: Duration(milliseconds: 61430), text: 'Ngayong nagmamahal ka sa \'kin nang tunay'),
    LrcLine(timestamp: Duration(milliseconds: 67650), text: 'At ang tinig mo\'y parang musika'),
    LrcLine(timestamp: Duration(milliseconds: 74470), text: 'Nagpapaligaya sa munting nagwawala'),
    LrcLine(timestamp: Duration(milliseconds: 82190), text: 'Ang sarap nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 88780), text: 'Lalo pa no\'ng sinabi mong'),
    LrcLine(timestamp: Duration(milliseconds: 94400), text: 'Dadalhin kita sa \'king palasyo'),
    LrcLine(timestamp: Duration(milliseconds: 100590), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 107670), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 115840), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
    LrcLine(timestamp: Duration(milliseconds: 130600), text: 'Nang mawalay ka sa aking pagsinta'),
    LrcLine(timestamp: Duration(milliseconds: 136690), text: 'Bawat saglit, gabing lamig ang himig ko'),
    LrcLine(timestamp: Duration(milliseconds: 143040), text: 'Hanap ang yakap mo, haplos ng iyong puso'),
    LrcLine(timestamp: Duration(milliseconds: 149610), text: 'Parang walang ligtas kundi ang lumuha'),
    LrcLine(timestamp: Duration(milliseconds: 156970), text: 'Ang hapdi din nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 163990), text: 'Umasa pa sa sinabi mong'),
    LrcLine(timestamp: Duration(milliseconds: 169370), text: 'Dadalhin kita sa \'king palasyo'),
    LrcLine(timestamp: Duration(milliseconds: 176090), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 182550), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 190600), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
    LrcLine(timestamp: Duration(milliseconds: 198810), text: 'Umiiyak, umiiyak ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 205790), text: 'Alaala pa ang sinabi mo noong nadarama pa ang pag-ibig mo, oh'),
    LrcLine(timestamp: Duration(milliseconds: 214920), text: 'Dadalhin kita sa \'king palasyo, ooh'),
    LrcLine(timestamp: Duration(milliseconds: 221620), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 227800), text: 'Ang lahat ng ito\'y pinangako mo, whoa'),
    LrcLine(timestamp: Duration(milliseconds: 239130), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
    LrcLine(timestamp: Duration(milliseconds: 247550), text: 'Dadalhin kita sa \'king palasyo'),
    LrcLine(timestamp: Duration(milliseconds: 253510), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 260220), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 268420), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
  ];

  // ── Paalam Muna Sandali - Darren Espanto (3:54) ──────────────────────────
  // Not on lrclib.net — timestamps estimated from karaoke MP3 structure
  static final List<LrcLine> _paalamMunaSandaliLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 5000), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 10000), text: 'Namamaalam sandali, paalam muna'),
    LrcLine(timestamp: Duration(milliseconds: 17000), text: 'Hindi naman maitatangging ako\'y nasasaktan'),
    LrcLine(timestamp: Duration(milliseconds: 24000), text: 'Pero kahit na mahirap man, kailangan nating pagdaanan'),
    LrcLine(timestamp: Duration(milliseconds: 31000), text: 'Hanggang sa muling pagkikita, \'di kakalimutan pangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 39000), text: 'Paalam muna sandali'),
    LrcLine(timestamp: Duration(milliseconds: 43000), text: 'Kailan ba naging madali?'),
    LrcLine(timestamp: Duration(milliseconds: 47000), text: 'Kahit ayaw kong sa akin mawalay ka, walang magagawa'),
    LrcLine(timestamp: Duration(milliseconds: 54000), text: 'Oh, ipangako mong walang magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 59000), text: 'Hanggang muling magkita tayo, oh'),
    LrcLine(timestamp: Duration(milliseconds: 64000), text: 'Paalam muna, sana sandali lang'),
    LrcLine(timestamp: Duration(milliseconds: 72000), text: 'Habang nag-eempake na'),
    LrcLine(timestamp: Duration(milliseconds: 76000), text: 'Ng mga gamit ko'),
    LrcLine(timestamp: Duration(milliseconds: 80000), text: 'Naisip ko na magdala ng mga gamit mong magpapaalala sa\'yo'),
    LrcLine(timestamp: Duration(milliseconds: 89000), text: 'Mabigat na ang maleta, at parang \'di ko nga makakaya'),
    LrcLine(timestamp: Duration(milliseconds: 96000), text: 'Ikaw ay kalimutan sa puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 103000), text: 'Paalam muna sandali'),
    LrcLine(timestamp: Duration(milliseconds: 107000), text: 'Kailan ba naging madali?'),
    LrcLine(timestamp: Duration(milliseconds: 111000), text: 'Kahit ayaw kong sa akin mawalay ka, walang magagawa'),
    LrcLine(timestamp: Duration(milliseconds: 118000), text: 'Oh, ipangako mong walang magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 123000), text: 'Hanggang muling magkita tayo'),
    LrcLine(timestamp: Duration(milliseconds: 128000), text: 'Paalam muna, sana sandali lang, oh'),
    LrcLine(timestamp: Duration(milliseconds: 135000), text: 'Paalam muna sandali'),
    LrcLine(timestamp: Duration(milliseconds: 139000), text: 'Kailan ba naging madali?'),
    LrcLine(timestamp: Duration(milliseconds: 143000), text: 'Kahit ayaw kong sa akin mawalay ka, walang magagawa'),
    LrcLine(timestamp: Duration(milliseconds: 150000), text: 'Oh, ipangako mong walang magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 155000), text: 'Hanggang muling magkita tayo, oh'),
    LrcLine(timestamp: Duration(milliseconds: 160000), text: 'Paalam muna, sana sandali lang'),
    LrcLine(timestamp: Duration(milliseconds: 167000), text: 'Paalam muna sandali'),
    LrcLine(timestamp: Duration(milliseconds: 171000), text: 'Tayo\'y magkikitang muli'),
    LrcLine(timestamp: Duration(milliseconds: 175000), text: 'Kahit ayaw kong sa akin mawalay ka, walang magagawa'),
    LrcLine(timestamp: Duration(milliseconds: 182000), text: 'Oh, ipangako mong walang magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 187000), text: 'Hanggang muling magkita tayo, oh'),
    LrcLine(timestamp: Duration(milliseconds: 192000), text: 'Paalam muna, sana sandali lang'),
  ];

  // ── Nasa Iyo Na Ang Lahat - Daniel Padilla (3:27) ────────────────────────
  static final List<LrcLine> _nasaIyoLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 0), text: '♪ Intro ♪'),
    LrcLine(timestamp: Duration(milliseconds: 12110), text: 'Nasa \'yo na ang lahat, minamahal kita'),
    LrcLine(timestamp: Duration(milliseconds: 16800), text: '\'Pagka\'t nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 24210), text: 'Nasa \'yo na ang lahat, minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 30230), text: 'Nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 36200), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 42230), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 48150), text: 'Lahat na mismo nasa \'yo, ang ganda, ang bait, ang talino'),
    LrcLine(timestamp: Duration(milliseconds: 54110), text: 'Inggit lahat sila sa \'yo kahit pa itapat man kanino'),
    LrcLine(timestamp: Duration(milliseconds: 59830), text: 'Kaya nu\'ng lumapit ka sa \'kin ay bigla akong nahilo'),
    LrcLine(timestamp: Duration(milliseconds: 65720), text: 'Hindi akalaing sabihin mong ako na \'yon, ang hinahanap mo'),
    LrcLine(timestamp: Duration(milliseconds: 75250), text: 'Nasa \'yo na ang lahat, minamahal kita'),
    LrcLine(timestamp: Duration(milliseconds: 79720), text: '\'Pagka\'t nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 87170), text: 'Nasa \'yo na ang lahat, minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 93110), text: 'Nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 99400), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 105060), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 111280), text: 'Kinikilig pa rin ako, ang sarap magmahal \'pag panalo'),
    LrcLine(timestamp: Duration(milliseconds: 117190), text: 'Nag-iisa sa puso ko, ito\'y kaya \'di na ba magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 122860), text: 'Ako ang pinili sa dami ng ibang nirereto'),
    LrcLine(timestamp: Duration(milliseconds: 128750), text: 'Hindi akalaing sabihin mong ako na lang ang kulang sa iyo, oh'),
    LrcLine(timestamp: Duration(milliseconds: 138250), text: 'Nasa \'yo na ang lahat, minamahal kita'),
    LrcLine(timestamp: Duration(milliseconds: 142750), text: '\'Pagka\'t nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 150240), text: 'Nasa \'yo na ang lahat, minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 156280), text: 'Nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 162150), text: 'Nasa \'yo na ang lahat, minamahal kita'),
    LrcLine(timestamp: Duration(milliseconds: 166720), text: '\'Pagka\'t nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 174170), text: 'Nasa \'yo na ang lahat, minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 180230), text: 'Nasa \'yo na ang lahat pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 186120), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 192240), text: 'Oh-oh-oh-oh-oh, na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 198260), text: 'Nasa \'yo na ang lahat'),
  ];

  // ── Ulap - Rob Deniel (7:00) ──────────────────────────────────────────────
  static final List<LrcLine> _ulapLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 5500), text: 'Nag-iisa, nakadungaw'),
    LrcLine(timestamp: Duration(milliseconds: 21710), text: 'Sa bintana; ako ba\'y nagkulang?'),
    LrcLine(timestamp: Duration(milliseconds: 37790), text: 'Nakaupo, lumalayo'),
    LrcLine(timestamp: Duration(milliseconds: 53610), text: 'Sa tukso, upang \'di na magulo'),
    LrcLine(timestamp: Duration(milliseconds: 69520), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 85600), text: 'At mag-uusap, hindi manghuhula'),
    LrcLine(timestamp: Duration(milliseconds: 101730), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 117650), text: 'Hindi hahayaang mahulog nang tuluyan'),
    LrcLine(timestamp: Duration(milliseconds: 133500), text: 'Nagkamali ba ako sa \'yo?'),
    LrcLine(timestamp: Duration(milliseconds: 149620), text: 'Nananatiling blangko ito'),
    LrcLine(timestamp: Duration(milliseconds: 165720), text: 'Naririnig ang tinig mo'),
    LrcLine(timestamp: Duration(milliseconds: 181750), text: 'Nabubuong muli ang pag-ibig ko'),
    LrcLine(timestamp: Duration(milliseconds: 197620), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 213660), text: 'At mag-uusap, hindi manghuhula'),
    LrcLine(timestamp: Duration(milliseconds: 229600), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 245690), text: 'Hindi hahayaang mahulog nang tuluyan'),
    LrcLine(timestamp: Duration(milliseconds: 262150), text: 'Oh, gusto kang makasama'),
    LrcLine(timestamp: Duration(milliseconds: 272780), text: 'Ako na ang bahala'),
    LrcLine(timestamp: Duration(milliseconds: 280800), text: 'Huwag ka lang mawalay'),
    LrcLine(timestamp: Duration(milliseconds: 284950), text: 'Atin nang kulayan ang ating mundo'),
    LrcLine(timestamp: Duration(milliseconds: 296940), text: 'Tumingin sa akin'),
    LrcLine(timestamp: Duration(milliseconds: 304840), text: 'Langhapin ang hangin'),
    LrcLine(timestamp: Duration(milliseconds: 313040), text: 'Bakit ba nasanay?'),
    LrcLine(timestamp: Duration(milliseconds: 316940), text: 'Isip ay nadadamay sa puso'),
    LrcLine(timestamp: Duration(milliseconds: 325480), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 341840), text: 'At mag-uusap, hindi manghuhula'),
    LrcLine(timestamp: Duration(milliseconds: 357610), text: 'Isasayaw ka sa ulap'),
    LrcLine(timestamp: Duration(milliseconds: 373770), text: 'Hindi hahayaang mahulog nang tuluyan'),
    LrcLine(timestamp: Duration(milliseconds: 389620), text: 'Nag-iisa, nakadungaw'),
  ];

  // ── Fallen - Lola Amour (3:25) ────────────────────────────────────────────
  static final List<LrcLine> _fallenLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 0), text: '♪ Intro ♪'),
    LrcLine(timestamp: Duration(milliseconds: 18420), text: 'What if I told you that I\'ve fallen'),
    LrcLine(timestamp: Duration(milliseconds: 22870), text: 'And I like the way you say my name?'),
    LrcLine(timestamp: Duration(milliseconds: 27980), text: 'My heart skips a beat when I hear you calling'),
    LrcLine(timestamp: Duration(milliseconds: 32800), text: 'And I like that it won\'t go away'),
    LrcLine(timestamp: Duration(milliseconds: 39040), text: 'But never mind, don\'t wanna give you any trouble'),
    LrcLine(timestamp: Duration(milliseconds: 44300), text: 'Never mind, never mind'),
    LrcLine(timestamp: Duration(milliseconds: 49170), text: 'I\'m OK with being by your side for as long as I can hide'),
    LrcLine(timestamp: Duration(milliseconds: 54960), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 77070), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 81970), text: 'The heart-shaped arrow through my chest'),
    LrcLine(timestamp: Duration(milliseconds: 86730), text: 'I\'ll make your breakfast every morning'),
    LrcLine(timestamp: Duration(milliseconds: 91600), text: 'And pick you up when you\'re a mess'),
    LrcLine(timestamp: Duration(milliseconds: 99130), text: 'But I know that it won\'t ever stop'),
    LrcLine(timestamp: Duration(milliseconds: 102700), text: 'You know I\'ll be there when you call me whether you like it or not'),
    LrcLine(timestamp: Duration(milliseconds: 107520), text: 'Without a warning, now I\'m falling for this picture on my phone'),
    LrcLine(timestamp: Duration(milliseconds: 112730), text: 'But don\'t mind me, I\'m just falling, I\'ll be back up on my own'),
    LrcLine(timestamp: Duration(milliseconds: 117740), text: 'Please don\'t say my name, help me put out this flame'),
    LrcLine(timestamp: Duration(milliseconds: 127140), text: 'I\'d rather hold onto this feeling that you don\'t even believe in'),
    LrcLine(timestamp: Duration(milliseconds: 133310), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 155360), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 158180), text: 'Nevermind, nevermind, nevermind'),
    LrcLine(timestamp: Duration(milliseconds: 160260), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 162990), text: 'Nevermind, nevermind, nevermind'),
    LrcLine(timestamp: Duration(milliseconds: 165170), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 168050), text: 'Nevermind, nevermind, nevermind'),
    LrcLine(timestamp: Duration(milliseconds: 170180), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 172940), text: 'Nevermind, nevermind, nevermind'),
    LrcLine(timestamp: Duration(milliseconds: 175120), text: 'What if I told you that I\'ve fallen? (Nevermind)'),
    LrcLine(timestamp: Duration(milliseconds: 179820), text: 'What if I told you that I\'ve fallen? (Oh, nevermind)'),
    LrcLine(timestamp: Duration(milliseconds: 184880), text: 'What if I told you that I\'ve fallen? (Oh, nevermind)'),
    LrcLine(timestamp: Duration(milliseconds: 189770), text: 'What if I told you that I\'ve fallen? (Oh, nevermind, I said nevermind)'),
    LrcLine(timestamp: Duration(milliseconds: 194440), text: 'I shouldn\'t tell you that I\'ve fallen'),
  ];
}
