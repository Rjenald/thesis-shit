import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/youtube_search_service.dart';

/// Keeping the original recording out of Search & Sing.
///
/// Appending "karaoke" to a YouTube query is a hint, not a filter —
/// YouTube ranks by relevance and returns official music videos for
/// karaoke queries constantly. That matters more here than it would in
/// most apps: singing over a track that still carries the lead vocal means
/// the pitch analysis hears the original singer as much as the user, so the
/// result stops describing the user's singing at all.
///
/// The failure is also invisible until it is too late. Nothing on screen
/// says a track has a vocal on it; you find out after you have sung.
/// Hence testing the predicate directly, with the titles these searches
/// actually return.
void main() {
  group('accepts real backing tracks', () {
    const titles = [
      'Araw Araw - Ben&Ben (KARAOKE VERSION)',
      'Nasa Iyo Na Ang Lahat - Daniel Padilla | Karaoke',
      'Buwan — Juan Karlos [Minus One]',
      'Mundo - IV Of Spades (Instrumental)',
      'Kumpas - Moira Dela Torre (Backing Track)',
      'Pano - Zack Tabudlo (No Vocals)',
      'Fallen - Lola Amour | Sing Along',
      'Ikaw Lang - NOBITA (Minus-One) HD',
      'Dadalhin - Regine Velasquez (Lower Key Karaoke)',
      'Randomantic - James Reid (Off Vocal)',
    ];
    for (final t in titles) {
      test('"$t"', () => expect(
          YoutubeSearchService.looksLikeMinusOne(t), isTrue));
    }

    test('a channel that only brands itself as karaoke still counts', () {
      // Some channels put the marker in the channel name alone.
      expect(
          YoutubeSearchService.looksLikeMinusOne(
              'Araw Araw - Ben&Ben', 'Sing King Karaoke'),
          isTrue);
    });
  });

  group('rejects the original recording', () {
    const titles = [
      'Ben&Ben - Araw Araw (Official Music Video)',
      'Daniel Padilla - Nasa Iyo Na Ang Lahat (Official Audio)',
      'Juan Karlos - Buwan (Lyric Video)',
      'IV Of Spades - Mundo (Live Performance)',
      'Moira Dela Torre - Kumpas | Official MV',
      'Zack Tabudlo - Pano (Music Video)',
      'Araw Araw - Ben&Ben (Cover by Someone)',
      'How To Sing Mundo - Tutorial',
      'Buwan Reaction',
      'Fallen - Lola Amour (Acapella)',
    ];
    for (final t in titles) {
      test('"$t"', () => expect(
          YoutubeSearchService.looksLikeMinusOne(t), isFalse));
    }

    test('a plain title with no marker at all is rejected', () {
      // Strict on purpose: a maybe is treated as a no, because the cost of
      // a false accept is a ruined take and a meaningless score.
      expect(YoutubeSearchService.looksLikeMinusOne('Araw Araw'), isFalse);
      expect(
          YoutubeSearchService.looksLikeMinusOne('Ben&Ben - Araw Araw'),
          isFalse);
    });

    test('an original wearing a karaoke tag is still rejected', () {
      // The reason negatives can veto positives: these exist, and the
      // positive word alone would let them through.
      expect(
          YoutubeSearchService.looksLikeMinusOne(
              'Araw Araw (Official Music Video) karaoke'),
          isFalse);
      expect(
          YoutubeSearchService.looksLikeMinusOne(
              'Mundo Karaoke — Live Performance'),
          isFalse);
    });
  });

  group('word boundaries', () {
    test('"no vocal" is not cancelled by the word "vocal" inside it', () {
      // A naive substring check would see 'vocal only' nowhere but would
      // see 'vocal' and could be written to reject on it. The boundary
      // rule is what keeps these apart.
      expect(YoutubeSearchService.looksLikeMinusOne('Mundo (No Vocals)'),
          isTrue);
      expect(YoutubeSearchService.looksLikeMinusOne('Mundo (Vocals Only)'),
          isFalse);
    });

    test('a marker inside a longer word does not count', () {
      expect(
          YoutubeSearchService.looksLikeMinusOne('Discover the Karaokeing'),
          isFalse,
          reason: '"karaokeing" is not "karaoke"');
    });

    test('case and punctuation do not matter', () {
      for (final t in [
        'MUNDO - KARAOKE',
        'mundo (karaoke)',
        'Mundo [KaRaOkE]',
        'Mundo, karaoke!',
      ]) {
        expect(YoutubeSearchService.looksLikeMinusOne(t), isTrue,
            reason: t);
      }
    });

    test('an empty title is rejected rather than crashing', () {
      expect(YoutubeSearchService.looksLikeMinusOne(''), isFalse);
      expect(YoutubeSearchService.looksLikeMinusOne('', ''), isFalse);
    });
  });

  group('cleanSongTitle', () {
    test('strips the karaoke marker and the channel branding', () {
      expect(
          YoutubeSearchService.cleanSongTitle(
              'Araw Araw - Ben&Ben (KARAOKE VERSION) | Sing King'),
          'Araw Araw - Ben&Ben');
    });

    test('strips brackets of every kind', () {
      expect(
          YoutubeSearchService.cleanSongTitle('Mundo [Instrumental] {HD}'),
          'Mundo');
    });

    test('leaves a clean title alone', () {
      expect(YoutubeSearchService.cleanSongTitle('Araw Araw - Ben&Ben'),
          'Araw Araw - Ben&Ben');
    });

    test('does not leave dangling separators', () {
      for (final t in [
        'Mundo - (Karaoke)',
        'Mundo — Karaoke',
        'Karaoke: Mundo',
        'Mundo | Karaoke',
      ]) {
        final out = YoutubeSearchService.cleanSongTitle(t);
        expect(out, isNot(startsWith('-')), reason: t);
        expect(out, isNot(endsWith('-')), reason: t);
        expect(out.trim(), out, reason: t);
        expect(out, isNotEmpty, reason: t);
      }
    });

    test('a title that is nothing but markers comes back empty, not junk',
        () {
      // The caller falls back to the raw video title in that case rather
      // than searching lyrics for an empty string.
      expect(YoutubeSearchService.cleanSongTitle('(Karaoke Version)'), '');
    });

    test('every accepted title above still yields something searchable',
        () {
      const accepted = [
        'Araw Araw - Ben&Ben (KARAOKE VERSION)',
        'Buwan — Juan Karlos [Minus One]',
        'Mundo - IV Of Spades (Instrumental)',
        'Pano - Zack Tabudlo (No Vocals)',
        'Ikaw Lang - NOBITA (Minus-One) HD',
      ];
      for (final t in accepted) {
        final out = YoutubeSearchService.cleanSongTitle(t);
        expect(out, isNotEmpty, reason: t);
        expect(out.toLowerCase(), isNot(contains('karaoke')), reason: t);
        expect(out.toLowerCase(), isNot(contains('instrumental')),
            reason: t);
        expect(out.toLowerCase(), isNot(contains('minus')), reason: t);
      }
    });
  });

  group('search entry points', () {
    test('an empty query never reaches the network', () async {
      // Also what happens when the debounce fires on a cleared field.
      final r = await YoutubeSearchService.searchMinusOne(query: '   ');
      expect(r.status, YoutubeSearchStatus.noResults);
      expect(r.videos, isEmpty);
    });

    test('an empty title never reaches the network either', () async {
      final r = await YoutubeSearchService.searchKaraoke(title: '  ');
      expect(r.status, YoutubeSearchStatus.noResults);
    });
  });
}
