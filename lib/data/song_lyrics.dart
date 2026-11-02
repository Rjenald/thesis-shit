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
      case 'araw-araw':
        return _arawArawLyrics;
      case 'ere':
        return _ereLyrics;
      case 'tahanan':
        return _tahananLyrics;
      case 'binibini':
        return _binibiniLyrics;
      case 'buwan':
        return _buwanLyrics;
      case 'ikaw lang':
        return _ikawLangLyrics;
      case 'kumpas':
        return _kumpasLyrics;
      case 'mundo':
        return _mundoLyrics;
      case 'pano':
        return _panoLyrics;
      case 'randomantic':
        return _randomanticLyrics;
      default:
        return null;
    }
  }

  // ── Dadalhin - Regine Velasquez (4:43) ────────────────────────────────────
  static final List<LrcLine> _dadalhinLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Dadalhin - Regine Velasquez"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Dadalhin - Regine Velasquez.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Dadalhin - Regine Velasquez.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 15217), text: 'Ang pangarap ko\'y'),
    LrcLine(timestamp: Duration(milliseconds: 18499), text: 'Nagmula sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 21640), text: 'Sa \'yong ganda ang puso\'y di makalimot'),
    LrcLine(timestamp: Duration(milliseconds: 28444), text: 'Tuwing kapiling ka'),
    LrcLine(timestamp: Duration(milliseconds: 31565), text: 'Tanging nadarama'),
    LrcLine(timestamp: Duration(milliseconds: 35027), text: 'Ang pagsilip ng bituin sa \'yong mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 43071), text: 'Ang saya nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 49574), text: 'Sana ay \'di na mag-iiba'),
    LrcLine(timestamp: Duration(milliseconds: 55537), text: 'Ang pangarap ko ang \'yong binubuhay'),
    LrcLine(timestamp: Duration(milliseconds: 61921), text: 'Ngayong nagmamahal ka sa akin ng tunay'),
    LrcLine(timestamp: Duration(milliseconds: 68864), text: 'At ang himig mo\'y'),
    LrcLine(timestamp: Duration(milliseconds: 72146), text: 'Parang musika'),
    LrcLine(timestamp: Duration(milliseconds: 75107), text: 'Nagpapaligaya sa munting nagwawala'),
    LrcLine(timestamp: Duration(milliseconds: 83011), text: 'Ang sarap nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 89634), text: 'Lalo na noong sinabi mong'),
    LrcLine(timestamp: Duration(milliseconds: 95417), text: 'Dadalhin kita sa \'king palasyo'),
    LrcLine(timestamp: Duration(milliseconds: 101881), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 108504), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 116488), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
    LrcLine(timestamp: Duration(milliseconds: 126180), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 130995), text: 'Nang mawalay ka'),
    LrcLine(timestamp: Duration(milliseconds: 134057), text: 'Sa aking pagsinta'),
    LrcLine(timestamp: Duration(milliseconds: 137178), text: 'Bawat saglit gabing lamig ang himig ko'),
    LrcLine(timestamp: Duration(milliseconds: 143621), text: 'Hanap ay yakap mo'),
    LrcLine(timestamp: Duration(milliseconds: 146883), text: 'Haplos ng \'yong puso'),
    LrcLine(timestamp: Duration(milliseconds: 150145), text: 'Parang walang ligtas kundi ang lumuha'),
    LrcLine(timestamp: Duration(milliseconds: 157789), text: 'Ang hapdi din nitong pag-ibig'),
    LrcLine(timestamp: Duration(milliseconds: 164112), text: 'Umasa pa sa sinabi mong'),
    LrcLine(timestamp: Duration(milliseconds: 170015), text: 'Dadalhin kita sa \'king palasyo'),
    LrcLine(timestamp: Duration(milliseconds: 176498), text: 'Dadalhin hanggang langit ay manibago'),
    LrcLine(timestamp: Duration(milliseconds: 182941), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 191085), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
    LrcLine(timestamp: Duration(milliseconds: 199149), text: 'Umiiyak umiiyak ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 206093), text: 'Alaala pa ang sinabi mo'),
    LrcLine(timestamp: Duration(milliseconds: 209134), text: 'Noong nadarama pa ang pag-ibig mo'),
    LrcLine(timestamp: Duration(milliseconds: 217098), text: 'Ang lahat ng ito\'y pinangako mo ohh'),
    LrcLine(timestamp: Duration(milliseconds: 239750), text: 'Dadalhin lang pala ng hangin ang pangarap ko oohh'),
    LrcLine(timestamp: Duration(milliseconds: 252440), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 260780), text: 'Ang lahat ng ito\'y pinangako mo'),
    LrcLine(timestamp: Duration(milliseconds: 268964), text: 'Dadalhin lang pala ng hangin ang pangarap ko'),
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
  // Re-timed +3.74s on 2026-10-31. These timings were authored against
  // a different recording; against the backing track the app now ships,
  // every line appeared 3.74s before anybody sang it, so a singer
  // following the screen would sing early and score badly for reasons
  // that have nothing to do with their pitch.
  //
  // The offset is measured, not guessed. Three independent pieces of
  // evidence agree: the first ground-truth note is at 15.85s while the
  // first line was at 12.11s (+3.74); a cross-correlation of "someone is
  // singing" against "a line is on screen" peaks at +3.75s; and after
  // the shift, 15 of 31 lines land within 0.10s of a vocal onset,
  // spread across the whole track. Residual drift is +2.5 ms per second,
  // about half a second end to end, which is why the last lines are
  // looser than the first.
  //
  // Derived from assets/ground_truth/Nasa Iyo Na Ang Lahat - Daniel
  // Padilla.json. If that backing track is ever replaced, this is wrong
  // again.
  static final List<LrcLine> _nasaIyoLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Nasa Iyo Na Ang Lahat - Daniel Padilla"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Nasa Iyo Na Ang Lahat - Daniel Padilla.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Nasa Iyo Na Ang Lahat - Daniel Padilla.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 15821), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 18722), text: 'Minamahal kita \'pagkat'),
    LrcLine(timestamp: Duration(milliseconds: 21844), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 24325), text: 'Pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 27827), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 30688), text: 'Minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 33830), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 36371), text: 'Pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 39733), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 42874), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 45936), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 48857), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 51899), text: 'Lahat na mismo nasa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 54880), text: 'Ang ganda, ang bait, ang talino'),
    LrcLine(timestamp: Duration(milliseconds: 57902), text: 'Inggit lahat sila sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 60843), text: 'Kahit pa tapat man kanino'),
    LrcLine(timestamp: Duration(milliseconds: 63285), text: 'Kaya nung lumapit ka sa \'kin'),
    LrcLine(timestamp: Duration(milliseconds: 67127), text: 'Ay, bigla akong nahilo'),
    LrcLine(timestamp: Duration(milliseconds: 69488), text: 'Di akalaing sabihin mong ako na \'yon'),
    LrcLine(timestamp: Duration(milliseconds: 75171), text: 'Ang hinahanap mo'),
    LrcLine(timestamp: Duration(milliseconds: 78852), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 81694), text: 'Minamahal kita \'pagkat'),
    LrcLine(timestamp: Duration(milliseconds: 84855), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 87297), text: 'Pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 90858), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 93680), text: 'Minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 96821), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 99303), text: 'Pati ang puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 102925), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 105866), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 108948), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 111849), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 114870), text: 'Kinikilig pa rin ako'),
    LrcLine(timestamp: Duration(milliseconds: 117872), text: 'Ang sarap magmahal \'pag panalo'),
    LrcLine(timestamp: Duration(milliseconds: 120853), text: 'Nag-iisa sa puso ko'),
    LrcLine(timestamp: Duration(milliseconds: 123815), text: 'Ito\'y kaya \'di na ba magbabago'),
    LrcLine(timestamp: Duration(milliseconds: 126376), text: 'Ako ang pinili sa dami'),
    LrcLine(timestamp: Duration(milliseconds: 130038), text: 'Ng ibang nirereto'),
    LrcLine(timestamp: Duration(milliseconds: 132299), text: 'Hindi akalaing'),
    LrcLine(timestamp: Duration(milliseconds: 135061), text: 'Sabihin mong ako na lang'),
    LrcLine(timestamp: Duration(milliseconds: 138122), text: 'Ang kulang sa iyo Ohh'),
    LrcLine(timestamp: Duration(milliseconds: 141844), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 144725), text: 'Minamahal kita \'pagkat'),
    LrcLine(timestamp: Duration(milliseconds: 147887), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 150288), text: 'Pati ang puso kohhh'),
    LrcLine(timestamp: Duration(milliseconds: 153850), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 156711), text: 'Minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 159893), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 162314), text: 'Pati ang puso kohhh'),
    LrcLine(timestamp: Duration(milliseconds: 165876), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 168677), text: 'Minamahal kita \'pagkat'),
    LrcLine(timestamp: Duration(milliseconds: 171359), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 174300), text: 'Pati ang puso kohhh'),
    LrcLine(timestamp: Duration(milliseconds: 177862), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 180684), text: 'Minamahal kitang tapat'),
    LrcLine(timestamp: Duration(milliseconds: 183826), text: 'Nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 186287), text: 'Pati ang puso kohhh'),
    LrcLine(timestamp: Duration(milliseconds: 189929), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 192891), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 195933), text: 'Oh Oh Oh Ohh Ohhh'),
    LrcLine(timestamp: Duration(milliseconds: 198874), text: 'Na-nasa \'yo na ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 201856), text: 'Nasa \'yo na ang lahat'),
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
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Fallen - Lola Amour"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Fallen - Lola Amour.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Fallen - Lola Amour.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 18469), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 23172), text: 'And I like the way you say my name'),
    LrcLine(timestamp: Duration(milliseconds: 28014), text: 'My heart skips a beat when I hear you calling'),
    LrcLine(timestamp: Duration(milliseconds: 32996), text: 'And I like that it won\'t go away'),
    LrcLine(timestamp: Duration(milliseconds: 39240), text: 'But never mind, don\'t wanna give you any trouble'),
    LrcLine(timestamp: Duration(milliseconds: 44402), text: 'Never mind, never mind'),
    LrcLine(timestamp: Duration(milliseconds: 49385), text: 'I\'m okay with being by your side for as long as I can hide'),
    LrcLine(timestamp: Duration(milliseconds: 55168), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 58449), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 82561), text: 'A heart shaped arrow through my chest'),
    LrcLine(timestamp: Duration(milliseconds: 87064), text: 'I\'ll make you breakfast every morning'),
    LrcLine(timestamp: Duration(milliseconds: 91946), text: 'And pick you up when you\'re a mess'),
    LrcLine(timestamp: Duration(milliseconds: 99410), text: 'I know that it won\'t ever stop'),
    LrcLine(timestamp: Duration(milliseconds: 102931), text: 'You know I\'ll be there when you call me whether you like it or not'),
    LrcLine(timestamp: Duration(milliseconds: 107874), text: 'Without a warning, now I\'m falling for this picture on my phone'),
    LrcLine(timestamp: Duration(milliseconds: 113017), text: 'But don\'t mind me I\'m just falling, I\'ll get back up on my own'),
    LrcLine(timestamp: Duration(milliseconds: 117879), text: 'Please don\'t say my name, help me put out this flame'),
    LrcLine(timestamp: Duration(milliseconds: 127584), text: 'I\'d rather hold onto this feeling that you don\'t even believe in'),
    LrcLine(timestamp: Duration(milliseconds: 133547), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 136828), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 163262), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 168144), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 169825), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 171046), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 180430), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 181131), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 182051), text: 'What if I told you that I\'ve fallen?'),
    LrcLine(timestamp: Duration(milliseconds: 193477), text: 'I said never mind'),
  ];

  // ── Araw-Araw - Ben&Ben ─────────────────────────────────────
  // From lrclib, nearest-duration master (263.0s
  // against our 285s karaoke track). Timings follow the
  // studio original, so they may need an offset for this backing
  // track - see the ground-truth alignment note.
  static final List<LrcLine> _arawArawLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Araw-Araw - Ben&Ben"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Araw-Araw - Ben&Ben.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Araw-Araw - Ben&Ben.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 200), text: 'Umaga na sa ating duyan'),
    LrcLine(timestamp: Duration(milliseconds: 8924), text: '\'Wag nang mawawala'),
    LrcLine(timestamp: Duration(milliseconds: 14407), text: 'Umaga na sa ating duyan'),
    LrcLine(timestamp: Duration(milliseconds: 23132), text: 'Magmamahal o mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 31960), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 55148), text: 'Matang magkakilala'),
    LrcLine(timestamp: Duration(milliseconds: 61951), text: 'Sa unang pagtagpo'),
    LrcLine(timestamp: Duration(milliseconds: 68794), text: 'Paano dahan-dahang'),
    LrcLine(timestamp: Duration(milliseconds: 75598), text: 'Sinuyo ang puso'),
    LrcLine(timestamp: Duration(milliseconds: 84242), text: 'Kay tagal ko nang nag-iisa'),
    LrcLine(timestamp: Duration(milliseconds: 90885), text: 'Andiyan ka lang pala'),
    LrcLine(timestamp: Duration(milliseconds: 97869), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 101351), text: 'Pipiliin ka sa araw-araw'),
    LrcLine(timestamp: Duration(milliseconds: 111496), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 115038), text: 'Ang nadarama sa \'yo\'y malinaw'),
    LrcLine(timestamp: Duration(milliseconds: 123442), text: 'Higit pa sa ligayang'),
    LrcLine(timestamp: Duration(milliseconds: 130045), text: 'Hatid sa damdamin'),
    LrcLine(timestamp: Duration(milliseconds: 136848), text: 'Lahat naunawaan'),
    LrcLine(timestamp: Duration(milliseconds: 143632), text: 'Sa lalim ng tingin'),
    LrcLine(timestamp: Duration(milliseconds: 152376), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 155798), text: 'Pipiliin ka sa araw-araw'),
    LrcLine(timestamp: Duration(milliseconds: 165923), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 169485), text: 'Ang nadarama sa \'yo\'y malinaw'),
    LrcLine(timestamp: Duration(milliseconds: 182531), text: 'Sa minsang pagbali ng hangin'),
    LrcLine(timestamp: Duration(milliseconds: 189335), text: 'Hinila patungo sa akin'),
    LrcLine(timestamp: Duration(milliseconds: 196638), text: 'Tanging ika\'y iibiging wagas at buo'),
    LrcLine(timestamp: Duration(milliseconds: 208084), text: 'Payapa sa yakap ng iyong hiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 221691), text: 'Payapa sa yakap ng iyong'),
    LrcLine(timestamp: Duration(milliseconds: 234360), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 247684), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 251126), text: 'Pipiliin ka sa araw-araw'),
    LrcLine(timestamp: Duration(milliseconds: 261231), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 264772), text: 'Ang nadarama sa \'yo\'y malinaw'),
    LrcLine(timestamp: Duration(milliseconds: 274857), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 278299), text: '\'Wag nang mawala araw-araw oh'),
    LrcLine(timestamp: Duration(milliseconds: 288447), text: 'Mahiwaga'),
    LrcLine(timestamp: Duration(milliseconds: 291970), text: 'Pipiliin ka araw-araw'),
  ];

  // ── Ere - Juan Karlos ─────────────────────────────────────
  // From lrclib, nearest-duration master (280.0s
  // against our 276s karaoke track). Timings follow the
  // studio original, so they may need an offset for this backing
  // track - see the ground-truth alignment note.
  static final List<LrcLine> _ereLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 780), text: 'Lahat ng pagmamahal'),
    LrcLine(timestamp: Duration(milliseconds: 6250), text: 'At oras na aking binigay'),
    LrcLine(timestamp: Duration(milliseconds: 14050), text: 'Parang \'di mo pansin'),
    LrcLine(timestamp: Duration(milliseconds: 18870), text: 'Ang sama ko sa \'yong paningin'),
    LrcLine(timestamp: Duration(milliseconds: 25020), text: 'Hmm, hmm'),
    LrcLine(timestamp: Duration(milliseconds: 28410), text: 'Oh, \'di ba? Nakakaputang ina'),
    LrcLine(timestamp: Duration(milliseconds: 35910), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 41640), text: 'Oh, \'di ba? Pinagmukha mo \'kong tanga'),
    LrcLine(timestamp: Duration(milliseconds: 48960), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 56420), text: '\'Di mo agad sinabi'),
    LrcLine(timestamp: Duration(milliseconds: 61720), text: 'Na may duda na sa \'yong isip (duda, duda)'),
    LrcLine(timestamp: Duration(milliseconds: 70030), text: 'Pinalalim mo pa'),
    LrcLine(timestamp: Duration(milliseconds: 74410), text: 'Ang sugat dito sa aking dibdib'),
    LrcLine(timestamp: Duration(milliseconds: 81170), text: 'Oh, shit'),
    LrcLine(timestamp: Duration(milliseconds: 84420), text: 'Hmm, \'di ba? Nakakaputang ina'),
    LrcLine(timestamp: Duration(milliseconds: 91630), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 97430), text: 'Oh, \'di ba? Pinagmukha mo \'kong tanga'),
    LrcLine(timestamp: Duration(milliseconds: 104880), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 110550), text: 'Sa ere, ere, ere'),
    LrcLine(timestamp: Duration(milliseconds: 121390), text: 'At ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 123740), text: 'Sa ere, ere, oh, ere, ooh-ooh'),
    LrcLine(timestamp: Duration(milliseconds: 134590), text: 'At ako\'y iniwan mo, ooh-ooh-ooh'),
    LrcLine(timestamp: Duration(milliseconds: 140870), text: 'Tatlong bilyon, ikaw lang nga ang aking gusto'),
    LrcLine(timestamp: Duration(milliseconds: 147680), text: 'Pasensiya na kung ngayon ako\'y \'di para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 154190), text: 'Tayo ay papunta na sa \'ting bagong yugto'),
    LrcLine(timestamp: Duration(milliseconds: 160800), text: '\'Yokong mabuhay sa isang mundong walang tayo'),
    LrcLine(timestamp: Duration(milliseconds: 167230), text: 'Tatlong bilyon, ikaw lang nga ang aking gusto'),
    LrcLine(timestamp: Duration(milliseconds: 174070), text: 'Pasensiya na kung ngayon ako\'y \'di para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 180560), text: 'Tayo ay papunta na sa \'ting bagong yugto'),
    LrcLine(timestamp: Duration(milliseconds: 187160), text: '\'Yokong mabuhay sa isang mundong walang tayo'),
    LrcLine(timestamp: Duration(milliseconds: 193810), text: '\'Di ba? Nakakaputang ina'),
    LrcLine(timestamp: Duration(milliseconds: 200240), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 205720), text: 'Oh, \'di ba? \'Di ba? \'Di ba? Pinagmukha mo \'kong tanga'),
    LrcLine(timestamp: Duration(milliseconds: 213370), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 219110), text: 'Sa ere, ere, ere (oh, \'di ba? Nakakaputang ina)'),
    LrcLine(timestamp: Duration(milliseconds: 226560), text: '(Tayo\'y lumilipad) at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 232280), text: 'Sa ere, ere, oh, ere (oh, \'di ba? Pinagmukha mo \'kong tanga)'),
    LrcLine(timestamp: Duration(milliseconds: 239730), text: '(Tayo\'y lumilipad) at ako\'y iniwan mo'),
    LrcLine(timestamp: Duration(milliseconds: 245490), text: 'Oh, \'di ba? Nakakaputang ina'),
    LrcLine(timestamp: Duration(milliseconds: 252850), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo pa'),
    LrcLine(timestamp: Duration(milliseconds: 259660), text: '\'Di ba? Ginawa mo pa akong tanga'),
    LrcLine(timestamp: Duration(milliseconds: 265910), text: 'Tayo\'y lumilipad, at ako\'y iniwan mo, hmm'),
  ];

  // ── Tahanan - Adie ─────────────────────────────────────
  // From lrclib, nearest-duration master (293.0s
  // against our 292s karaoke track). Timings follow the
  // studio original, so they may need an offset for this backing
  // track - see the ground-truth alignment note.
  static final List<LrcLine> _tahananLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 18540), text: 'Sa araw-araw'),
    LrcLine(timestamp: Duration(milliseconds: 21480), text: 'Tanging ikaw ang palagi kong hinahangad'),
    LrcLine(timestamp: Duration(milliseconds: 27880), text: 'Laging tanaw'),
    LrcLine(timestamp: Duration(milliseconds: 29580), text: 'Sa \'yo ang ilaw na nagsisilbi kong liwanag'),
    LrcLine(timestamp: Duration(milliseconds: 36940), text: 'Labis ang ngiti kapag ika\'y kaharap'),
    LrcLine(timestamp: Duration(milliseconds: 41140), text: 'Ramdam ko ang pagmamahal, giliw'),
    LrcLine(timestamp: Duration(milliseconds: 45590), text: 'Namumukod-tangi ka at walang katulad'),
    LrcLine(timestamp: Duration(milliseconds: 49770), text: 'Ikaw lang ang para sa \'kin'),
    LrcLine(timestamp: Duration(milliseconds: 62530), text: 'Sa \'yo lang, sa \'yo lang ako uuwi'),
    LrcLine(timestamp: Duration(milliseconds: 68970), text: 'Kaya naman'),
    LrcLine(timestamp: Duration(milliseconds: 70820), text: 'Dito ka sa piling ko'),
    LrcLine(timestamp: Duration(milliseconds: 74470), text: 'Oh, dito ka lang, dito ka lang'),
    LrcLine(timestamp: Duration(milliseconds: 79210), text: 'Bumabagal ang ikot ng mundo'),
    LrcLine(timestamp: Duration(milliseconds: 82880), text: 'Kapag ika\'y nariyan, oh, aking tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 88330), text: 'Ta, ta-ta-ta-ta, tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 95670), text: 'Dito ka lang, dito ka lang, dito ka lang'),
    LrcLine(timestamp: Duration(milliseconds: 104360), text: 'Oh, aking tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 114410), text: 'Sa bawat sandali'),
    LrcLine(timestamp: Duration(milliseconds: 117390), text: 'Na tayo ay magkayakap nang mahigpit'),
    LrcLine(timestamp: Duration(milliseconds: 123930), text: 'Taglay mong init'),
    LrcLine(timestamp: Duration(milliseconds: 125520), text: 'Ang bumabalot sa \'king nilalamig na damdamin'),
    LrcLine(timestamp: Duration(milliseconds: 132970), text: 'Tayong dalawa\'y pinagtagpo'),
    LrcLine(timestamp: Duration(milliseconds: 138120), text: 'Ng tamang pagkakataon'),
    LrcLine(timestamp: Duration(milliseconds: 141830), text: 'Hindi maitatanggi'),
    LrcLine(timestamp: Duration(milliseconds: 144240), text: 'Na sa akin, ikaw ang tanging tiyak, ah'),
    LrcLine(timestamp: Duration(milliseconds: 158930), text: 'Ikaw lang, ikaw lang ang tinatangi'),
    LrcLine(timestamp: Duration(milliseconds: 162800), text: '(Ikaw lamang ang tinatangi ko)'),
    LrcLine(timestamp: Duration(milliseconds: 166800), text: 'Ikaw lang at ako ang naaaninag (naaaninag)'),
    LrcLine(timestamp: Duration(milliseconds: 174890), text: 'Sa gitna ng paraiso na ating sinimulan'),
    LrcLine(timestamp: Duration(milliseconds: 181460), text: 'Oh, aking tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 186770), text: 'Pinapawi lahat ng iyong mga ngiti'),
    LrcLine(timestamp: Duration(milliseconds: 190340), text: 'Negatibo na nakadikit sa \'king labi'),
    LrcLine(timestamp: Duration(milliseconds: 195150), text: 'Huli ng iyong ngiti ang aking kiliti'),
    LrcLine(timestamp: Duration(milliseconds: 199350), text: 'Katotohanan na hindi ko maitatanggi'),
    LrcLine(timestamp: Duration(milliseconds: 203420), text: 'Na mahal kita, walang iba'),
    LrcLine(timestamp: Duration(milliseconds: 210870), text: 'Kaya naman'),
    LrcLine(timestamp: Duration(milliseconds: 212490), text: 'Dito ka sa piling ko'),
    LrcLine(timestamp: Duration(milliseconds: 216000), text: 'Oh, dito ka lang, dito ka lang'),
    LrcLine(timestamp: Duration(milliseconds: 221050), text: 'Bumabagal ang ikot ng mundo'),
    LrcLine(timestamp: Duration(milliseconds: 224910), text: 'Kapag ika\'y nariyan, oh, aking tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 229970), text: 'Ta, ta-ta-ta-ta, tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 237870), text: 'Dito ka lang, dito ka lang, dito ka lang'),
    LrcLine(timestamp: Duration(milliseconds: 247270), text: 'Dito ka sa piling ko'),
    LrcLine(timestamp: Duration(milliseconds: 247880), text: '(Pinapawi lahat ng iyong mga ngiti)'),
    LrcLine(timestamp: Duration(milliseconds: 251730), text: '(Negatibo na nakadikit sa \'king labi)'),
    LrcLine(timestamp: Duration(milliseconds: 256200), text: 'Bumabagal ang ikot ng mundo'),
    LrcLine(timestamp: Duration(milliseconds: 257240), text: '(Huli ng iyong ngiti ang aking kiliti)'),
    LrcLine(timestamp: Duration(milliseconds: 260310), text: '(Katotohanan na hindi ko maitatanggi)'),
    LrcLine(timestamp: Duration(milliseconds: 264820), text: 'Ta, ta-ta-ta-ta, tahanan'),
    LrcLine(timestamp: Duration(milliseconds: 272630), text: 'Dito ka lang, dito ka lang, dito ka lang'),
    LrcLine(timestamp: Duration(milliseconds: 280850), text: 'Oh, aking tahanan'),
  ];

  // ── Binibini - Zack Tabudlo ─────────────────────────────────────
  // From lrclib, nearest-duration master (214.0s
  // against our 214s karaoke track). Timings follow the
  // studio original, so they may need an offset for this backing
  // track - see the ground-truth alignment note.
  static final List<LrcLine> _binibiniLyrics = [
    LrcLine(timestamp: Duration(milliseconds: 480), text: 'Binibini'),
    LrcLine(timestamp: Duration(milliseconds: 5150), text: 'Alam mo ba kung pa\'no nahulog sa \'yo?'),
    LrcLine(timestamp: Duration(milliseconds: 11710), text: 'Naramdaman lang bigla ng puso'),
    LrcLine(timestamp: Duration(milliseconds: 19430), text: 'Aking sinta, ikaw lang nagparamdam nito'),
    LrcLine(timestamp: Duration(milliseconds: 27310), text: 'Kaya sabihin mo sa akin'),
    LrcLine(timestamp: Duration(milliseconds: 31770), text: 'Ang tumatakbo sa isip mo'),
    LrcLine(timestamp: Duration(milliseconds: 38100), text: 'Kung mahal mo na rin ba ako'),
    LrcLine(timestamp: Duration(milliseconds: 43200), text: 'Isayaw mo ako'),
    LrcLine(timestamp: Duration(milliseconds: 48990), text: 'Sa gitna ng ulan, mahal ko'),
    LrcLine(timestamp: Duration(milliseconds: 56330), text: 'Kapalit man nito\'y buhay ko'),
    LrcLine(timestamp: Duration(milliseconds: 64140), text: 'Gagawin ang lahat para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 71390), text: 'Alam kong mahal mo na rin ako'),
    LrcLine(timestamp: Duration(milliseconds: 77550), text: 'Binibini'),
    LrcLine(timestamp: Duration(milliseconds: 82540), text: 'Sabi mo noon sa \'kin, ayaw mo pa'),
    LrcLine(timestamp: Duration(milliseconds: 89710), text: 'Pero ang yakap ngayo\'y kakaiba'),
    LrcLine(timestamp: Duration(milliseconds: 97300), text: 'Hindi ka ba nalilito? Totoo na bang gusto ko?'),
    LrcLine(timestamp: Duration(milliseconds: 104520), text: '\'Wag nang lalabanan ang puso'),
    LrcLine(timestamp: Duration(milliseconds: 109280), text: 'Alam kong mahal mo na \'ko'),
    LrcLine(timestamp: Duration(milliseconds: 116150), text: 'Kung gano\'n, halika na\'t huwag lumayo'),
    LrcLine(timestamp: Duration(milliseconds: 121520), text: 'Isayaw mo ako'),
    LrcLine(timestamp: Duration(milliseconds: 126910), text: 'Sa gitna ng ulan, mahal ko'),
    LrcLine(timestamp: Duration(milliseconds: 134420), text: 'Kapalit man nito\'y buhay ko'),
    LrcLine(timestamp: Duration(milliseconds: 141700), text: 'Gagawin ang lahat para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 148870), text: 'Alam kong mahal mo na rin ako, whoa'),
    LrcLine(timestamp: Duration(milliseconds: 161160), text: 'Ooh-'),
    LrcLine(timestamp: Duration(milliseconds: 171840), text: 'Yeah'),
    LrcLine(timestamp: Duration(milliseconds: 180220), text: 'Isayaw mo ako'),
    LrcLine(timestamp: Duration(milliseconds: 185950), text: 'Sa gitna ng ulan, mahal ko'),
    LrcLine(timestamp: Duration(milliseconds: 193110), text: 'Kapalit man nito\'y buhay ko'),
    LrcLine(timestamp: Duration(milliseconds: 201380), text: 'Gagawin ang lahat para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 208660), text: 'Alam kong mahal mo na rin ako'),
  ];

  // ── Buwan - Juan Karlos ──
  // Filled by `python backend/sync_lyrics.py "Buwan - Juan Karlos" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Buwan - Juan Karlos.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _buwanLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Buwan - Juan Karlos"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Buwan - Juan Karlos.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Buwan - Juan Karlos.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 28384), text: 'Ako\'y sa \'yo, ikaw ay akin'),
    LrcLine(timestamp: Duration(milliseconds: 36168), text: 'Ganda mo sa paningin'),
    LrcLine(timestamp: Duration(milliseconds: 43612), text: 'Ako ngayo\'y nag-iisa'),
    LrcLine(timestamp: Duration(milliseconds: 51396), text: 'Sana ay tabihan na'),
    LrcLine(timestamp: Duration(milliseconds: 59019), text: 'Sa ilalim ng puting ilaw'),
    LrcLine(timestamp: Duration(milliseconds: 66883), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 74327), text: 'Pakinggan mo ang aking sigaw'),
    LrcLine(timestamp: Duration(milliseconds: 82111), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 89355), text: 'Ayokong mabuhay nang malungkot'),
    LrcLine(timestamp: Duration(milliseconds: 96978), text: 'Ikaw ang nagpapasaya'),
    LrcLine(timestamp: Duration(milliseconds: 104322), text: 'At makakasama hanggang sa pagtanda'),
    LrcLine(timestamp: Duration(milliseconds: 112146), text: 'Halina\'t tayo\'y humiga'),
    LrcLine(timestamp: Duration(milliseconds: 120470), text: 'Sa ilalim ng puting ilaw'),
    LrcLine(timestamp: Duration(milliseconds: 127794), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 135238), text: 'Pakinggan mo ang aking sigaw'),
    LrcLine(timestamp: Duration(milliseconds: 143121), text: 'Sa dilaw na buwan, oh'),
    LrcLine(timestamp: Duration(milliseconds: 182501), text: 'Ang iyong ganda\'y umaabot sa buwan'),
    LrcLine(timestamp: Duration(milliseconds: 197649), text: 'Ang tibok ng puso\'y dinig sa kalawakan'),
    LrcLine(timestamp: Duration(milliseconds: 211035), text: 'At bumabalik dito sa akin'),
    LrcLine(timestamp: Duration(milliseconds: 218679), text: 'Ikaw ang mahal, ikaw lang ang mamahalin'),
    LrcLine(timestamp: Duration(milliseconds: 228564), text: 'Pakinggan ang puso\'t damdamin'),
    LrcLine(timestamp: Duration(milliseconds: 234767), text: 'Damdamin aking damdamin'),
    LrcLine(timestamp: Duration(milliseconds: 242271), text: 'Sa ilalim ng puting ilaw'),
    LrcLine(timestamp: Duration(milliseconds: 249515), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 257379), text: 'Pakinggan mo ang aking sigaw'),
    LrcLine(timestamp: Duration(milliseconds: 264982), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 269330), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 274967), text: 'Ta-ta-ah'),
    LrcLine(timestamp: Duration(milliseconds: 281851), text: 'Sa ilalim ng puting ilaw'),
    LrcLine(timestamp: Duration(milliseconds: 289695), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 295738), text: 'La-ah, pakinggan mo ang aking sigaw'),
    LrcLine(timestamp: Duration(milliseconds: 304942), text: 'Sa dilaw na buwan'),
    LrcLine(timestamp: Duration(milliseconds: 309024), text: 'La-ah'),
    LrcLine(timestamp: Duration(milliseconds: 316888), text: 'La-la-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 320050), text: 'La-la-la-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 327854), text: 'Pakinggan, pakingan, pakingan'),
    LrcLine(timestamp: Duration(milliseconds: 331616), text: 'Pakinggan mo ang aking sigaw o sinta'),
    LrcLine(timestamp: Duration(milliseconds: 336339), text: 'Sa dilaw na buwan'),
  ];

  // ── Ikaw Lang - NOBITA ──
  // Filled by `python backend/sync_lyrics.py "Ikaw Lang - NOBITA" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Ikaw Lang - NOBITA.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _ikawLangLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Ikaw Lang - NOBITA"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Ikaw Lang - NOBITA.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Ikaw Lang - NOBITA.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 7843), text: 'Oh, kay gandang pagmasdan'),
    LrcLine(timestamp: Duration(milliseconds: 12405), text: 'Ang iyong mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 16667), text: 'Kumikinang-kinang'),
    LrcLine(timestamp: Duration(milliseconds: 20309), text: '\'Di ko maintindihan'),
    LrcLine(timestamp: Duration(milliseconds: 24391), text: 'Ang iyong mga tingin'),
    LrcLine(timestamp: Duration(milliseconds: 28353), text: 'Labis ang mga ningning'),
    LrcLine(timestamp: Duration(milliseconds: 32315), text: 'Langit ay bumaba'),
    LrcLine(timestamp: Duration(milliseconds: 36157), text: 'Bumababa pala ang tala'),
    LrcLine(timestamp: Duration(milliseconds: 42120), text: 'Tumingin ka sa \'king mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 46202), text: 'At hindi mo na kailangan pang'),
    LrcLine(timestamp: Duration(milliseconds: 50364), text: 'Magtanong nang paulit-ulit'),
    LrcLine(timestamp: Duration(milliseconds: 54246), text: 'Ikaw lang ang iniibig'),
    LrcLine(timestamp: Duration(milliseconds: 58148), text: 'At kung \'di kumbinsido\'y magtiwala ka'),
    LrcLine(timestamp: Duration(milliseconds: 62630), text: 'Hawakan ang puso\'t maniwala'),
    LrcLine(timestamp: Duration(milliseconds: 65312), text: 'Na ikaw lang ang s\'yang inibig'),
    LrcLine(timestamp: Duration(milliseconds: 70214), text: 'Ikaw lang ang iibigin'),
    LrcLine(timestamp: Duration(milliseconds: 73736), text: 'At sa iyong paglalambing'),
    LrcLine(timestamp: Duration(milliseconds: 78398), text: 'Ako ay nahulog din'),
    LrcLine(timestamp: Duration(milliseconds: 82100), text: '\'Di ko alam kung ano ang gagawin'),
    LrcLine(timestamp: Duration(milliseconds: 86162), text: '\'Di ko alam kung saan titingin'),
    LrcLine(timestamp: Duration(milliseconds: 90684), text: 'Halik sa labi'),
    LrcLine(timestamp: Duration(milliseconds: 94646), text: 'Tinginan natin'),
    LrcLine(timestamp: Duration(milliseconds: 98128), text: '\'Di akalaing'),
    LrcLine(timestamp: Duration(milliseconds: 101570), text: 'Mahuhulog ka sa \'kin'),
    LrcLine(timestamp: Duration(milliseconds: 106112), text: 'Tumingin ka sa aking mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 110194), text: 'At hindi mo na kailangan pang'),
    LrcLine(timestamp: Duration(milliseconds: 114396), text: 'Magtanong nang paulit-ulit'),
    LrcLine(timestamp: Duration(milliseconds: 118218), text: 'Ikaw lang ang iniibig'),
    LrcLine(timestamp: Duration(milliseconds: 122160), text: 'At kung \'di kumbinsido\'y magtiwala ka'),
    LrcLine(timestamp: Duration(milliseconds: 126622), text: 'Hawakan ang puso\'t maniwala'),
    LrcLine(timestamp: Duration(milliseconds: 129304), text: 'Na ikaw lang ang s\'yang inibig'),
    LrcLine(timestamp: Duration(milliseconds: 134166), text: 'Ikaw lang ang iibigin, sinta'),
    LrcLine(timestamp: Duration(milliseconds: 141150), text: 'At sa paglisan ng araw, akala\'y \'di ka mahal'),
    LrcLine(timestamp: Duration(milliseconds: 161720), text: 'At ang nadarama\'y hindi magtatagal'),
    LrcLine(timestamp: Duration(milliseconds: 169904), text: 'Malay ko bang hindi magpapagal'),
    LrcLine(timestamp: Duration(milliseconds: 177268), text: 'Iibigin kita kahit ga\'no pa katagal'),
    LrcLine(timestamp: Duration(milliseconds: 188593), text: 'Tumingin ka sa \'king mga mata'),
    LrcLine(timestamp: Duration(milliseconds: 192595), text: 'At hindi mo na kailangan pang'),
    LrcLine(timestamp: Duration(milliseconds: 196617), text: 'Magtanong nang paulit-ulit'),
    LrcLine(timestamp: Duration(milliseconds: 200419), text: 'Ikaw lang ang iniibig'),
    LrcLine(timestamp: Duration(milliseconds: 204301), text: 'At kung \'di kumbinsido\'y magtiwala ka'),
    LrcLine(timestamp: Duration(milliseconds: 208663), text: 'Hawakan ang puso\'t maniwala'),
    LrcLine(timestamp: Duration(milliseconds: 211305), text: 'Na ikaw lang ang s\'yang inibig'),
    LrcLine(timestamp: Duration(milliseconds: 215927), text: 'Ikaw lang ang iibigin'),
    LrcLine(timestamp: Duration(milliseconds: 220449), text: 'La-la-la-la-la-la, la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 225352), text: 'La-la-la-la-la-la, la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 232155), text: 'La-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 235997), text: 'La-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 238478), text: 'La-la-la-la-la-la, la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 243341), text: 'Siya lang, la-la, la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 244082), text: 'La-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 247565), text: 'La-la-la-la'),
    LrcLine(timestamp: Duration(milliseconds: 248120), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 254570), text: 'Sinta'),
  ];

  // ── Kumpas - Moira Dela Torre ──
  // Filled by `python backend/sync_lyrics.py "Kumpas - Moira Dela Torre" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Kumpas - Moira Dela Torre.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _kumpasLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Kumpas - Moira Dela Torre"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Kumpas - Moira Dela Torre.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Kumpas - Moira Dela Torre.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 10745), text: 'Pa\'no bang mababawi'),
    LrcLine(timestamp: Duration(milliseconds: 14407), text: 'Lahat ng mga nasabi'),
    LrcLine(timestamp: Duration(milliseconds: 22391), text: 'Di naman inakalang'),
    LrcLine(timestamp: Duration(milliseconds: 26073), text: 'Siya\'y aalis lang bigla ng walang babala'),
    LrcLine(timestamp: Duration(milliseconds: 34437), text: 'Sa isang iglap'),
    LrcLine(timestamp: Duration(milliseconds: 37399), text: 'Nagbago ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 40420), text: 'Susuko na dapat nang dumating ka'),
    LrcLine(timestamp: Duration(milliseconds: 49265), text: 'Ikaw ang kumpas pag naliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 55068), text: 'Ikaw ang kulay sa langit na bughaw'),
    LrcLine(timestamp: Duration(milliseconds: 60870), text: 'Sa bawat bagyo na dumadayo'),
    LrcLine(timestamp: Duration(milliseconds: 66733), text: 'Ikaw ang kanlungan na kailangan ko'),
    LrcLine(timestamp: Duration(milliseconds: 72656), text: 'Kahit hindi ko alam'),
    LrcLine(timestamp: Duration(milliseconds: 76618), text: 'Ilang beses mo akong niligtas'),
    LrcLine(timestamp: Duration(milliseconds: 82641), text: 'Dito sa hantungan ng aming wagas'),
    LrcLine(timestamp: Duration(milliseconds: 90360), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 99310), text: 'Pa\'nong maniniwala'),
    LrcLine(timestamp: Duration(milliseconds: 103172), text: 'Wala na sa \'king harapan'),
    LrcLine(timestamp: Duration(milliseconds: 107394), text: 'Wala naman to sa plano ako\'y masaktan ng gan\'to'),
    LrcLine(timestamp: Duration(milliseconds: 118699), text: 'Pa\'no na eto'),
    LrcLine(timestamp: Duration(milliseconds: 122981), text: 'Sa isang iglap'),
    LrcLine(timestamp: Duration(milliseconds: 125943), text: 'Nalunod ako'),
    LrcLine(timestamp: Duration(milliseconds: 129005), text: 'Hindi ko na kayang inahon mo ako'),
    LrcLine(timestamp: Duration(milliseconds: 137829), text: 'Ikaw ang kumpas \'pag naliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 143672), text: 'Ikaw ang kulay sa langit na bughaw'),
    LrcLine(timestamp: Duration(milliseconds: 149455), text: 'Sa bawat bagyo na dumadayo'),
    LrcLine(timestamp: Duration(milliseconds: 155338), text: 'Ikaw ang kanlungan na kailangan ko'),
    LrcLine(timestamp: Duration(milliseconds: 160680), text: 'At kahit nung di ko alam'),
    LrcLine(timestamp: Duration(milliseconds: 165183), text: 'Ilang beses ko akong niligtas'),
    LrcLine(timestamp: Duration(milliseconds: 170725), text: 'Dito sa hantungan ng aming wakas ah'),
    LrcLine(timestamp: Duration(milliseconds: 183132), text: 'At nung akala ko ubos na'),
    LrcLine(timestamp: Duration(milliseconds: 203062), text: 'Ikaw ang naging pahinga'),
    LrcLine(timestamp: Duration(milliseconds: 207960), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 219050), text: 'Ikaw \'yung kumpas no\'ng naliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 224992), text: 'Ikaw kulay ka sa langit na bughaw'),
    LrcLine(timestamp: Duration(milliseconds: 230675), text: 'Sa bawat bagyo na dumayo'),
    LrcLine(timestamp: Duration(milliseconds: 236558), text: 'Ikaw ang kanlungan na nahanap ko'),
    LrcLine(timestamp: Duration(milliseconds: 242482), text: 'Kahit no\'ng \'di ko alam ilang beses mo akong niligtas'),
    LrcLine(timestamp: Duration(milliseconds: 255271), text: 'Dito sa hantungan at aking wakas'),
  ];

  // ── Mundo - IV Of Spades ──
  // Filled by `python backend/sync_lyrics.py "Mundo - IV Of Spades" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Mundo - IV Of Spades.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _mundoLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Mundo - IV Of Spades"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Mundo - IV Of Spades.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Mundo - IV Of Spades.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 34357), text: 'San darating ang mga salita'),
    LrcLine(timestamp: Duration(milliseconds: 41950), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 48104), text: 'Na nanggagaling sa aming dalawa'),
    LrcLine(timestamp: Duration(milliseconds: 54520), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 61811), text: 'Kung lumisan ka wag naman sana'),
    LrcLine(timestamp: Duration(milliseconds: 69380), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 75358), text: 'Ika\'y kumapit na nang di makawala'),
    LrcLine(timestamp: Duration(milliseconds: 88084), text: 'Aking sinta ikaw na ang tahanan at mundo'),
    LrcLine(timestamp: Duration(milliseconds: 101651), text: 'Sa pagbalik mananatili na sa piling mo'),
    LrcLine(timestamp: Duration(milliseconds: 113697), text: 'Mundo\'y magiging ikaw'),
    LrcLine(timestamp: Duration(milliseconds: 117850), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 123482), text: 'Wag mag-alala kung nahihirapan ka'),
    LrcLine(timestamp: Duration(milliseconds: 136168), text: 'Halika na sumama ka'),
    LrcLine(timestamp: Duration(milliseconds: 141971), text: 'Pagmasdan ang mga tala'),
    LrcLine(timestamp: Duration(milliseconds: 149795), text: 'Aking sinta ikaw na ang tahanan at mundo'),
    LrcLine(timestamp: Duration(milliseconds: 163362), text: 'Sa pagbalik mananatili na sa piling mo'),
    LrcLine(timestamp: Duration(milliseconds: 175408), text: 'Mundo\'y magiging ikaw'),
    LrcLine(timestamp: Duration(milliseconds: 178829), text: 'Limutin na ang mundo'),
    LrcLine(timestamp: Duration(milliseconds: 185633), text: 'Nang magkasama tayo'),
    LrcLine(timestamp: Duration(milliseconds: 192496), text: 'Sunod sa bawat galaw'),
    LrcLine(timestamp: Duration(milliseconds: 199360), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 201541), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 213187), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 220010), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 226893), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 236278), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 247884), text: 'Di na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 250885), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 254307), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 257749), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 260910), text: 'Aking sinta ikaw na ang tahanan at mundo'),
    LrcLine(timestamp: Duration(milliseconds: 273097), text: 'Sa pagbalik mananatili na sa piling mo'),
    LrcLine(timestamp: Duration(milliseconds: 287764), text: 'Aking sinta'),
    LrcLine(timestamp: Duration(milliseconds: 292046), text: 'Ikaw na ang tahanan at mundo'),
    LrcLine(timestamp: Duration(milliseconds: 300510), text: 'Sa pagbalik'),
    LrcLine(timestamp: Duration(milliseconds: 304832), text: 'Mananatili na sa piling mo'),
    LrcLine(timestamp: Duration(milliseconds: 314677), text: 'Limutin na ang mundo'),
    LrcLine(timestamp: Duration(milliseconds: 322841), text: 'Nang magkasama tayo'),
    LrcLine(timestamp: Duration(milliseconds: 329664), text: 'Sunod sa bawat galaw'),
    LrcLine(timestamp: Duration(milliseconds: 336566), text: 'Hindi na maliligaw'),
    LrcLine(timestamp: Duration(milliseconds: 343269), text: 'Mundo\'y magiging ikaw'),
  ];

  // ── Pano - Zack Tabudlo ──
  // Filled by `python backend/sync_lyrics.py "Pano - Zack Tabudlo" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Pano - Zack Tabudlo.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _panoLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Pano - Zack Tabudlo"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Pano - Zack Tabudlo.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Pano - Zack Tabudlo.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 0), text: '\u266a Intro \u266a'),
    LrcLine(timestamp: Duration(milliseconds: 880), text: 'Oh giliw naririnig mo ba ng \'yong sarili'),
    LrcLine(timestamp: Duration(milliseconds: 9185), text: 'Nakakabaliw lumalabas sa \'yong bibig'),
    LrcLine(timestamp: Duration(milliseconds: 17509), text: 'Alam kong uto uto ako'),
    LrcLine(timestamp: Duration(milliseconds: 21571), text: 'Alam ko na marupok'),
    LrcLine(timestamp: Duration(milliseconds: 25813), text: 'Tao lang din naman kasi ako'),
    LrcLine(timestamp: Duration(milliseconds: 34397), text: 'May nararamdaman din ako'),
    LrcLine(timestamp: Duration(milliseconds: 38159), text: 'Di kasi manhid na tulad mo'),
    LrcLine(timestamp: Duration(milliseconds: 42201), text: 'Alam kong sanay bumitaw'),
    LrcLine(timestamp: Duration(milliseconds: 45083), text: 'Ang isang tulad mo'),
    LrcLine(timestamp: Duration(milliseconds: 47424), text: 'Lalayo na ba ako'),
    LrcLine(timestamp: Duration(milliseconds: 50525), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 54587), text: 'Nahulog na sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 58789), text: 'Binitawan mo lang ba talaga ako'),
    LrcLine(timestamp: Duration(milliseconds: 66973), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 71076), text: 'Naghintay ng matagal sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 75038), text: 'Wala lang ba talaga lahat ng \'yon sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 82301), text: 'Ano na bang gagawin ko'),
    LrcLine(timestamp: Duration(milliseconds: 87504), text: 'Hmm'),
    LrcLine(timestamp: Duration(milliseconds: 91626), text: 'Na na na na na oh oh oh'),
    LrcLine(timestamp: Duration(milliseconds: 99730), text: 'Sinasadya mo ba ang lahat'),
    LrcLine(timestamp: Duration(milliseconds: 103932), text: 'O trip mo lang ba ako saktan'),
    LrcLine(timestamp: Duration(milliseconds: 107974), text: 'Pagtapos kong ibigay balikat ko'),
    LrcLine(timestamp: Duration(milliseconds: 112596), text: 'Pag ika\'y umiiyak'),
    LrcLine(timestamp: Duration(milliseconds: 116278), text: 'Ano bang tingin mo sa akin'),
    LrcLine(timestamp: Duration(milliseconds: 120380), text: 'Isa ba akong alipin'),
    LrcLine(timestamp: Duration(milliseconds: 124422), text: 'Wala ka bang modo'),
    LrcLine(timestamp: Duration(milliseconds: 126543), text: 'Anong ginawa mo'),
    LrcLine(timestamp: Duration(milliseconds: 128344), text: 'Nagtiwala naman sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 132786), text: 'May nararamdaman din ako'),
    LrcLine(timestamp: Duration(milliseconds: 136908), text: 'Di kasi manhid na tulad mo'),
    LrcLine(timestamp: Duration(milliseconds: 140970), text: 'Alam kong sanay bumitaw'),
    LrcLine(timestamp: Duration(milliseconds: 143852), text: 'Ang isang tulad mo'),
    LrcLine(timestamp: Duration(milliseconds: 146193), text: 'Lalayo na ba ako'),
    LrcLine(timestamp: Duration(milliseconds: 149275), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 153337), text: 'Nahulog na sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 157559), text: 'Binitawan mo lang ba talaga ako'),
    LrcLine(timestamp: Duration(milliseconds: 165703), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 169805), text: 'Naghintay ng matagal sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 173787), text: 'Wala lang ba talaga lahat ng \'yon sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 181011), text: 'Ano na bang gagawin ko'),
    LrcLine(timestamp: Duration(milliseconds: 186333), text: 'Yah yah yah yah'),
    LrcLine(timestamp: Duration(milliseconds: 195438), text: 'Oh'),
    LrcLine(timestamp: Duration(milliseconds: 195698), text: 'Oh'),
    LrcLine(timestamp: Duration(milliseconds: 200740), text: 'Oh'),
    LrcLine(timestamp: Duration(milliseconds: 201081), text: 'Uh'),
    LrcLine(timestamp: Duration(milliseconds: 206950), text: '♪'),
    LrcLine(timestamp: Duration(milliseconds: 215068), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 219210), text: 'Nahulog na sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 223312), text: 'Binitawan mo lang ba talaga ako oh'),
    LrcLine(timestamp: Duration(milliseconds: 231576), text: 'Pano naman ako'),
    LrcLine(timestamp: Duration(milliseconds: 235678), text: 'Naghintay ng matagal sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 239700), text: 'Wala lang ba talaga lahat ng \'yon sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 246951), text: 'Ano na bang gagawin ko'),
  ];

  // ── Randomantic - James Reid ──
  // Filled by `python backend/sync_lyrics.py "Randomantic - James Reid" --write`, which
  // times each line from the measured word onsets in
  // assets/ground_truth/Randomantic - James Reid.words.json. Empty until then: a guessed
  // timestamp is worse than no lyric line at all.
  static final List<LrcLine> _randomanticLyrics = [
    // Timed from the vocal stem via
    // `python backend/sync_lyrics.py "Randomantic - James Reid"`. Every
    // timestamp below is the measured onset of that line's
    // first word, from forced alignment against the isolated
    // vocal in assets/ground_truth/Randomantic - James Reid.words.json — not a
    // guess from word count, line length or tempo.
    //
    // A ♪ line marks a stretch that is sung but missing
    // from backend/lyrics/Randomantic - James Reid.txt; add the real words
    // there and re-run to replace it.
    //
    // Regenerate if that ground truth or the backing track
    // ever changes; hand edits here will be overwritten.
    LrcLine(timestamp: Duration(milliseconds: 280), text: 'Kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 3462), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 9785), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 10285), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 10945), text: 'Pa\'no kung bigla na lamang'),
    LrcLine(timestamp: Duration(milliseconds: 13707), text: 'I\'ll wrap my arms on your hips? Baby, yeah'),
    LrcLine(timestamp: Duration(milliseconds: 21271), text: '\'Pag \'di mo inaasahan'),
    LrcLine(timestamp: Duration(milliseconds: 23572), text: 'I\'ll kiss you right on the lips, baby, yeah'),
    LrcLine(timestamp: Duration(milliseconds: 30335), text: 'Write little love notes on a post-it'),
    LrcLine(timestamp: Duration(milliseconds: 33217), text: 'Then I post it on your front door'),
    LrcLine(timestamp: Duration(milliseconds: 35438), text: 'Show up in suit and tie with a brooch'),
    LrcLine(timestamp: Duration(milliseconds: 38139), text: 'And with the roses on your front yard, oh-whoa'),
    LrcLine(timestamp: Duration(milliseconds: 40940), text: 'Doo-doo-doo-doo-doo, doo, yeah'),
    LrcLine(timestamp: Duration(milliseconds: 46163), text: 'Ang daming paraan, ikaw ang tanging dahilan, oh babe'),
    LrcLine(timestamp: Duration(milliseconds: 52226), text: 'Haharanahin kita sa\'n man tayo magpunta'),
    LrcLine(timestamp: Duration(milliseconds: 57369), text: '\'Yong tipong kahit wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 61951), text: 'O kaya biglang may breakfast in bed'),
    LrcLine(timestamp: Duration(milliseconds: 65113), text: 'Just to keep you interested'),
    LrcLine(timestamp: Duration(milliseconds: 67734), text: 'Lahat ay dahil wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 72416), text: 'I just wanna do simple random things to say "I love you"'),
    LrcLine(timestamp: Duration(milliseconds: 79060), text: 'Kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 80000), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 84262), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 90145), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 90945), text: 'Pilit kang patatawanin'),
    LrcLine(timestamp: Duration(milliseconds: 93527), text: 'Kahit na ang sungit mo , oh, yeah'),
    LrcLine(timestamp: Duration(milliseconds: 101271), text: 'Kahit \'di gano\'ng kawangis'),
    LrcLine(timestamp: Duration(milliseconds: 103992), text: 'Ika\'y iguguhit ko, whoa-oh, oh, oh'),
    LrcLine(timestamp: Duration(milliseconds: 110055), text: 'I\'ll probably take you to a private little island'),
    LrcLine(timestamp: Duration(milliseconds: 114157), text: 'Baby, that\'s right'),
    LrcLine(timestamp: Duration(milliseconds: 115518), text: 'And maybe share a snack that I like'),
    LrcLine(timestamp: Duration(milliseconds: 118199), text: 'And, baby, I\'ll give you the last bite, oh-oh'),
    LrcLine(timestamp: Duration(milliseconds: 121561), text: 'Doo-doo-doo-doo-doo, doo'),
    LrcLine(timestamp: Duration(milliseconds: 125823), text: 'Oh, ang daming paraan, ikaw ang tanging dahilan, oh babe'),
    LrcLine(timestamp: Duration(milliseconds: 132226), text: 'Haharanahin kita sa\'n man tayo magpunta'),
    LrcLine(timestamp: Duration(milliseconds: 137369), text: '\'Yong tipong kahit wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 141931), text: 'O kaya may on-the-spot dinner date'),
    LrcLine(timestamp: Duration(milliseconds: 145193), text: 'And this time, I won\'t be late'),
    LrcLine(timestamp: Duration(milliseconds: 147714), text: 'Lahat ay dahil wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 151036), text: 'I just wanna do simple random things to say "I love you"'),
    LrcLine(timestamp: Duration(milliseconds: 160340), text: 'Randomantic, so romantic'),
    LrcLine(timestamp: Duration(milliseconds: 162541), text: 'Baby, I\'ma let you have it, uh'),
    LrcLine(timestamp: Duration(milliseconds: 166723), text: 'Doo, ooh'),
    LrcLine(timestamp: Duration(milliseconds: 169765), text: 'Oh, ang daming paraan, ikaw ang tanging dahilan, oh babe'),
    LrcLine(timestamp: Duration(milliseconds: 176088), text: 'Haharanahin kita sa\'n man tayo magpunta'),
    LrcLine(timestamp: Duration(milliseconds: 181251), text: '\'Yong tipong kahit wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 185813), text: 'O kaya \'lilibre ka ng sine'),
    LrcLine(timestamp: Duration(milliseconds: 189015), text: 'Kahit \'di ko trip ay sige'),
    LrcLine(timestamp: Duration(milliseconds: 191616), text: 'Lahat ay dahil wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 196158), text: 'I just wanna do simple random things to say'),
    LrcLine(timestamp: Duration(milliseconds: 201921), text: 'Haharanahin kita sa\'n man tayo magpunta'),
    LrcLine(timestamp: Duration(milliseconds: 207044), text: '\'Yong tipong kahit wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 211606), text: 'O kaya iaalay ang kantang \'to'),
    LrcLine(timestamp: Duration(milliseconds: 214787), text: 'Na sinulat para sa \'yo'),
    LrcLine(timestamp: Duration(milliseconds: 217429), text: 'Lahat ay dahil wala lang'),
    LrcLine(timestamp: Duration(milliseconds: 221311), text: 'I just wanna do simple random things to say "I love you"'),
    LrcLine(timestamp: Duration(milliseconds: 231776), text: 'Kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 233517), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 240080), text: 'Kahit, kahit wala na'),
    LrcLine(timestamp: Duration(milliseconds: 240462), text: 'Kahit, kahit wala na'),
  ];
}
