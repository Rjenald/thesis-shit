import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class MusicLessonsPage extends StatelessWidget {
  const MusicLessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Music Lessons',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      Text(
                        'Learn vocal techniques & music theory',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lesson list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _LessonCard(
                    icon: Icons.air,
                    color: const Color(0xFF4FC3F7),
                    title: 'Breathing Technique',
                    subtitle: 'Diaphragmatic breathing for singers',
                    onTap: () => _openLesson(context, _breathingLesson),
                  ),
                  _LessonCard(
                    icon: Icons.record_voice_over,
                    color: const Color(0xFFFF8A65),
                    title: 'Vocal Warm-Up',
                    subtitle: 'Prepare your voice before singing',
                    onTap: () => _openLesson(context, _vocalWarmUpLesson),
                  ),
                  _LessonCard(
                    icon: Icons.tune,
                    color: const Color(0xFF81C784),
                    title: 'Pitch Control',
                    subtitle: 'Sing in tune with accuracy',
                    onTap: () => _openLesson(context, _pitchControlLesson),
                  ),
                  _LessonCard(
                    icon: Icons.accessibility_new,
                    color: const Color(0xFFBA68C8),
                    title: 'Posture & Support',
                    subtitle: 'Body alignment for better singing',
                    onTap: () => _openLesson(context, _postureLesson),
                  ),
                  _LessonCard(
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFFFFD54F),
                    title: 'Articulation & Diction',
                    subtitle: 'Pronounce words clearly while singing',
                    onTap: () => _openLesson(context, _articulationLesson),
                  ),
                  _LessonCard(
                    icon: Icons.graphic_eq,
                    color: const Color(0xFF4DD0E1),
                    title: 'Vocal Registers',
                    subtitle: 'Chest voice, head voice & mixed voice',
                    onTap: () => _openLesson(context, _vocalRegistersLesson),
                  ),
                  _LessonCard(
                    icon: Icons.music_note,
                    color: const Color(0xFFE57373),
                    title: 'Rhythm & Timing',
                    subtitle: 'Stay on beat and feel the groove',
                    onTap: () => _openLesson(context, _rhythmLesson),
                  ),
                  _LessonCard(
                    icon: Icons.self_improvement,
                    color: const Color(0xFF9FA8DA),
                    title: 'Vocal Health',
                    subtitle: 'Protect and care for your voice',
                    onTap: () => _openLesson(context, _vocalHealthLesson),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLesson(BuildContext context, _LessonContent lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _LessonDetailPage(lesson: lesson)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LESSON CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _LessonCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LessonCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LESSON DETAIL PAGE
// ═══════════════════════════════════════════════════════════════════════════

class _LessonDetailPage extends StatelessWidget {
  final _LessonContent lesson;
  const _LessonDetailPage({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero icon
                    Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: lesson.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(lesson.icon, color: lesson.color, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        lesson.title,
                        style: TextStyle(
                          color: lesson.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        lesson.overview,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontFamily: 'Roboto',
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sections
                    ...lesson.sections.map((section) => _buildSection(section)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_LessonSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: lesson.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.heading,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Section body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              section.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontFamily: 'Roboto',
                height: 1.6,
              ),
            ),
          ),
          // Tips
          if (section.tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...section.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('  •  ', style: TextStyle(color: lesson.color, fontSize: 14)),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LESSON DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════

class _LessonContent {
  final String title;
  final String overview;
  final IconData icon;
  final Color color;
  final List<_LessonSection> sections;

  const _LessonContent({
    required this.title,
    required this.overview,
    required this.icon,
    required this.color,
    required this.sections,
  });
}

class _LessonSection {
  final String heading;
  final String body;
  final List<String> tips;

  const _LessonSection({
    required this.heading,
    required this.body,
    this.tips = const [],
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// LESSON CONTENT DATA
// ═══════════════════════════════════════════════════════════════════════════

const _breathingLesson = _LessonContent(
  title: 'Breathing Technique',
  overview: 'Proper breathing is the foundation of good singing. Learn diaphragmatic breathing to support your voice with steady, controlled airflow.',
  icon: Icons.air,
  color: Color(0xFF4FC3F7),
  sections: [
    _LessonSection(
      heading: 'What is Diaphragmatic Breathing?',
      body: 'Diaphragmatic breathing (also called belly breathing) uses the diaphragm — a dome-shaped muscle below your lungs — to draw air deep into your lungs. Unlike shallow chest breathing, this technique gives you more air capacity and better control over your exhale, which is essential for sustaining notes and phrases.',
      tips: [
        'Place one hand on your chest and one on your belly',
        'When you inhale, your belly should expand outward',
        'Your chest should stay relatively still',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: 4-4-8 Breathing',
      body: 'This exercise builds breath control and lung capacity:\n\n1. Inhale slowly through your nose for 4 counts\n2. Hold your breath for 4 counts\n3. Exhale slowly through your mouth on a "sss" sound for 8 counts\n\nRepeat 5-10 times. As you improve, try extending the exhale to 12 or 16 counts.',
      tips: [
        'Keep your shoulders relaxed and down',
        'Imagine filling a balloon in your belly',
        'The exhale should be steady — no bursts of air',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: Panting',
      body: 'Quick panting helps you feel where the diaphragm is:\n\n1. Pant like a dog — short, quick breaths\n2. Place your hand on your belly and feel it bounce\n3. Now slow the panting down to controlled inhale/exhale\n\nThis connects your brain to the diaphragm muscle so you can control it when singing.',
    ),
    _LessonSection(
      heading: 'Applying to Singing',
      body: 'When singing a phrase, take a quick deep belly breath before starting. As you sing, slowly release air. Never force the air out — let the diaphragm provide steady support. Plan your breaths at natural phrase breaks in the lyrics.',
      tips: [
        'Mark breath spots in your lyrics with a pencil',
        'Never sing until you run completely out of air',
        'Practice long sustained notes (5+ seconds) to build endurance',
      ],
    ),
  ],
);

const _vocalWarmUpLesson = _LessonContent(
  title: 'Vocal Warm-Up',
  overview: 'Just like athletes stretch before exercise, singers need to warm up their vocal cords to prevent strain and sing their best.',
  icon: Icons.record_voice_over,
  color: Color(0xFFFF8A65),
  sections: [
    _LessonSection(
      heading: 'Why Warm Up?',
      body: 'Your vocal cords are small muscles that need blood flow and gentle stretching before heavy use. Singing without warming up can lead to vocal strain, hoarseness, and long-term damage. A 5-10 minute warm-up prepares your voice for its full range.',
    ),
    _LessonSection(
      heading: 'Exercise: Lip Trills (Lip Bubbles)',
      body: 'Lip trills are one of the best warm-ups:\n\n1. Close your lips loosely\n2. Blow air through them to make a "brrr" motorboat sound\n3. While trilling, slide your pitch up and down like a siren\n4. Go from your lowest comfortable note to your highest\n\nDo this for 1-2 minutes. It relaxes tension in your lips, jaw, and throat.',
      tips: [
        'If your lips stop vibrating, relax your face more',
        'Use a gentle, easy amount of air — don\'t force it',
        'Hold your cheeks lightly with your fingers if needed',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: Humming Scales',
      body: 'Humming gently warms up your resonance:\n\n1. Hum on "mmm" with your lips closed\n2. Feel the buzzing vibration in your nose and face\n3. Hum up and down a 5-note scale (Do-Re-Mi-Fa-Sol-Fa-Mi-Re-Do)\n4. Move the starting note up by half-step each time\n\nHum for 1-2 minutes before moving to open-mouth exercises.',
    ),
    _LessonSection(
      heading: 'Exercise: Vocal Sirens',
      body: 'Sirens stretch your full range smoothly:\n\n1. Start at your lowest comfortable note on "ooo"\n2. Slide smoothly up to your highest note\n3. Slide back down without breaks\n4. Repeat 5 times, gradually expanding your range\n\nThis connects your chest voice to your head voice.',
      tips: [
        'Keep the sound light and easy — no pushing',
        'Think of the sound going over your head like a rainbow',
        'If you crack, that\'s okay — go lighter through that spot',
      ],
    ),
  ],
);

const _pitchControlLesson = _LessonContent(
  title: 'Pitch Control',
  overview: 'Singing in tune requires training your ear and voice to match specific pitches. Learn techniques to improve your pitch accuracy.',
  icon: Icons.tune,
  color: Color(0xFF81C784),
  sections: [
    _LessonSection(
      heading: 'How Pitch Works',
      body: 'Pitch is determined by how fast your vocal cords vibrate. Higher notes = faster vibration. Your brain must hear the target note, then send precise signals to your vocal cords to match it. This ear-to-voice connection improves with practice.',
    ),
    _LessonSection(
      heading: 'Exercise: Matching Single Notes',
      body: '1. Play a note on a piano, keyboard app, or pitch pipe\n2. Listen to the note for 2-3 seconds\n3. Sing the note on "lah" and hold it\n4. Check if you matched (use the Solfège Pitch module in this app!)\n5. Adjust up or down until you match\n\nStart with comfortable middle-range notes, then expand higher and lower.',
      tips: [
        'Listen carefully before singing — hear it in your head first',
        'Start with notes in your easy speaking range',
        'If you\'re always flat, think of aiming slightly higher',
        'If you\'re always sharp, relax your throat and jaw',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: Scale Singing',
      body: 'Singing scales trains interval recognition:\n\n1. Sing Do-Re-Mi-Fa-Sol-La-Ti-Do going up\n2. Then come back down: Do-Ti-La-Sol-Fa-Mi-Re-Do\n3. Start slowly, making each note precise\n4. Speed up only once you can do it cleanly\n\nUse a piano or the Practice Drills module to guide you.',
    ),
    _LessonSection(
      heading: 'Common Pitch Problems',
      body: '• Singing flat (too low): Usually caused by insufficient breath support or tired voice. Solution: better diaphragmatic breathing and don\'t sing when exhausted.\n\n• Singing sharp (too high): Usually caused by tension in the throat or jaw. Solution: relax your neck, drop your jaw, and think of the sound going forward, not up.\n\n• Wavering pitch: Lack of steady airflow. Solution: practice the 4-4-8 breathing exercise.',
    ),
  ],
);

const _postureLesson = _LessonContent(
  title: 'Posture & Support',
  overview: 'Good posture opens up your airway and allows your diaphragm to work freely, giving you better tone and more power.',
  icon: Icons.accessibility_new,
  color: Color(0xFFBA68C8),
  sections: [
    _LessonSection(
      heading: 'The Ideal Singing Posture',
      body: 'Whether standing or sitting, aim for:\n\n• Feet shoulder-width apart (if standing)\n• Knees slightly soft — never locked\n• Hips level, not tilted\n• Spine tall and straight (imagine a string pulling you up from the top of your head)\n• Shoulders back and relaxed — not hunched\n• Chin parallel to the floor (not tilted up or down)\n• Jaw relaxed and free to drop open',
    ),
    _LessonSection(
      heading: 'Why Posture Matters',
      body: 'Bad posture compresses your lungs and restricts your diaphragm. Slouching reduces your air capacity by up to 30%. Tilting your chin up tightens your throat. Locked knees create tension that travels up your body to your voice.',
      tips: [
        'Check your posture in a mirror while singing',
        'Stand against a wall: head, shoulders, butt should touch it',
        'Practice singing while walking to develop natural alignment',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: Wall Alignment',
      body: '1. Stand with your back against a wall\n2. Your head, shoulder blades, and butt should touch the wall\n3. There should be a small natural curve in your lower back\n4. Step one foot length away from the wall\n5. Maintain this same posture without the wall\n6. Now sing a phrase — notice how open it feels',
    ),
    _LessonSection(
      heading: 'Sitting Posture',
      body: 'If you must sing sitting (like in a phone recording):\n\n• Sit on the front half of the chair\n• Don\'t lean against the backrest\n• Feet flat on the floor\n• Same upright spine and relaxed shoulders as standing\n• This keeps your diaphragm free to move',
    ),
  ],
);

const _articulationLesson = _LessonContent(
  title: 'Articulation & Diction',
  overview: 'Clear pronunciation ensures your audience understands every word you sing while maintaining beautiful tone quality.',
  icon: Icons.chat_bubble_outline,
  color: Color(0xFFFFD54F),
  sections: [
    _LessonSection(
      heading: 'Vowels vs Consonants in Singing',
      body: 'Singing happens on vowels — they carry the tone and sustain. Consonants are quick and precise, used to separate words clearly.\n\n• Vowels: A, E, I, O, U — open your mouth tall and round\n• Consonants: Quick, crisp, and placed at the front of your mouth\n\nThink of vowels as the road and consonants as speed bumps.',
    ),
    _LessonSection(
      heading: 'Exercise: Tongue Twisters',
      body: 'Speak these slowly, then faster, then sing them on one note:\n\n• "The lips, the teeth, the tip of the tongue"\n• "Red leather, yellow leather"\n• "Unique New York, unique New York"\n• "Mee-may-mah-moh-moo"\n\nFocus on crisp consonants without tensing your jaw.',
      tips: [
        'Over-exaggerate mouth movements during practice',
        'Record yourself and listen for muddy words',
        'Practice in front of a mirror watching your lips and jaw',
      ],
    ),
    _LessonSection(
      heading: 'Exercise: Vowel Modification',
      body: 'On high notes, pure vowels can sound strained. Slightly modify them:\n\n• "ee" → more towards "ih"\n• "ah" → more towards "uh"\n• "oo" → more towards "oh"\n\nThis is called vowel modification. It keeps your throat open on high notes while still being understood.',
    ),
    _LessonSection(
      heading: 'Singing in Filipino/Tagalog',
      body: 'Tagalog is naturally vowel-rich, which is great for singing! Tips:\n\n• Open vowels (a, o) are naturally resonant — don\'t close them\n• "Ng" sounds should buzz in the nose (nasal resonance)\n• Roll or flip the "r" lightly\n• Keep "t" and "d" sounds at the tip of your tongue\n• Avoid swallowing word endings — finish each syllable clearly',
    ),
  ],
);

const _vocalRegistersLesson = _LessonContent(
  title: 'Vocal Registers',
  overview: 'Understanding chest voice, head voice, and mixed voice helps you sing across your full range smoothly and powerfully.',
  icon: Icons.graphic_eq,
  color: Color(0xFF4DD0E1),
  sections: [
    _LessonSection(
      heading: 'What Are Vocal Registers?',
      body: 'A vocal register is a range of notes produced by the same vibration pattern:\n\n• Chest Voice: Lower notes that resonate in your chest. Feels full and powerful. This is your normal speaking voice range.\n\n• Head Voice: Higher notes that resonate in your head/skull. Feels lighter and more floaty.\n\n• Mixed Voice: A blend of both — the "bridge" between chest and head voice. Sounds powerful but can go high.',
    ),
    _LessonSection(
      heading: 'Finding Your Chest Voice',
      body: '1. Place your hand on your chest\n2. Speak in a low, relaxed voice: "Hey, how are you?"\n3. Feel the vibration under your hand\n4. Now sing a low, comfortable note on "mah"\n5. That buzzing chest feeling = chest voice\n\nChest voice is strong and bold. Most pop songs use chest voice for verses.',
      tips: [
        'Don\'t push chest voice too high — it becomes shouting',
        'Most males transition out of chest around E4-G4',
        'Most females transition out of chest around A4-C5',
      ],
    ),
    _LessonSection(
      heading: 'Finding Your Head Voice',
      body: '1. Make a gentle "hooo" sound like an owl\n2. Go higher — feel the resonance shift to behind your eyes/forehead\n3. It should feel light, airy, and free\n4. Sing a high note on "ooo" and feel where it resonates\n\nHead voice is essential for high notes without straining.',
    ),
    _LessonSection(
      heading: 'Connecting Them: Mixed Voice',
      body: 'Mixed voice is the key to modern singing — powerful high notes without strain:\n\n1. Start on a comfortable chest voice note on "nay" (like "nay-nay")\n2. Slide up slowly\n3. As you go higher, DON\'T flip into airy head voice\n4. Instead, allow the sound to stay strong but shift resonance upward\n5. Think of keeping the power of chest but the ease of head\n\nThis takes weeks/months of practice. Be patient!',
      tips: [
        'The "bratty nay" exercise is great for finding mix',
        'Think of the sound projecting forward, not up',
        'Record yourself to hear progress over time',
      ],
    ),
  ],
);

const _rhythmLesson = _LessonContent(
  title: 'Rhythm & Timing',
  overview: 'Staying on beat is just as important as singing in tune. Learn to feel the rhythm and lock in with the music.',
  icon: Icons.music_note,
  color: Color(0xFFE57373),
  sections: [
    _LessonSection(
      heading: 'Understanding Beat & Tempo',
      body: 'Every song has a steady pulse called the beat. Tempo is how fast or slow that beat goes (measured in BPM — beats per minute).\n\n• Slow songs: 60-80 BPM (ballads)\n• Medium songs: 90-120 BPM (pop)\n• Fast songs: 120-160 BPM (dance/upbeat)\n\nYour job as a singer is to place each syllable exactly where it belongs on the beat.',
    ),
    _LessonSection(
      heading: 'Exercise: Clap & Count',
      body: '1. Play any song you like\n2. Clap along to the beat (the steady pulse)\n3. Count out loud: "1-2-3-4, 1-2-3-4"\n4. Try to feel where beat 1 (the strongest beat) falls\n5. Now sing the melody while tapping your foot on the beat\n\nIf you lose the beat, stop, find it again, and rejoin.',
      tips: [
        'Tap your foot or bob your head to feel the pulse',
        'Listen to the drums/bass — they outline the beat',
        'Practice with a metronome app at slow tempos first',
      ],
    ),
    _LessonSection(
      heading: 'Syncopation',
      body: 'Syncopation means singing between the beats — emphasizing the "and" counts:\n\n"1 AND 2 AND 3 AND 4 AND"\n\nMany pop/R&B songs use syncopation. The melody falls on "and" instead of the number. Practice by:\n1. Clapping on the numbers only\n2. Singing the melody\n3. Notice where words fall between your claps',
    ),
    _LessonSection(
      heading: 'Exercise: Delayed Singing',
      body: 'This builds rhythmic independence:\n\n1. Play a song you know well\n2. Sing it normally for 4 bars\n3. Now sing it exactly one beat LATE on purpose\n4. Then try singing it one beat EARLY\n\nThis forces your brain to separate rhythm from autopilot, making you more rhythmically aware.',
    ),
  ],
);

const _vocalHealthLesson = _LessonContent(
  title: 'Vocal Health',
  overview: 'Your voice is your instrument — protect it! Learn habits that keep your vocal cords healthy and prevent damage.',
  icon: Icons.self_improvement,
  color: Color(0xFF9FA8DA),
  sections: [
    _LessonSection(
      heading: 'Hydration',
      body: 'Water is the #1 thing your voice needs. Your vocal cords vibrate hundreds of times per second — they need lubrication!\n\n• Drink 8+ glasses of water daily\n• Room temperature water is best (cold can tighten muscles)\n• Sip water throughout the day, not just before singing\n• Avoid caffeine and alcohol before singing (they dehydrate)',
      tips: [
        'Keep a water bottle with you during practice',
        'If your pee is dark yellow, you\'re not drinking enough',
        'Herbal tea (no caffeine) is great for the voice',
      ],
    ),
    _LessonSection(
      heading: 'Vocal Rest',
      body: 'Your voice needs recovery time, especially after heavy use:\n\n• After a long singing session, rest your voice for at least 1-2 hours\n• If your voice feels hoarse or tired, STOP singing immediately\n• Take a full vocal rest day once a week (minimal talking)\n• Never whisper when resting — whispering is harder on your cords than soft speaking',
    ),
    _LessonSection(
      heading: 'What to Avoid',
      body: '• Screaming or yelling — extreme strain on vocal cords\n• Clearing your throat aggressively — slams cords together\n• Singing through pain — pain means damage is happening\n• Smoking — irritates and dries out vocal tissue\n• Very spicy food before singing — causes acid reflux\n• Dairy before singing — increases mucus for some people\n• Cold air without a scarf — muscles tighten in cold',
    ),
    _LessonSection(
      heading: 'Warning Signs',
      body: 'See a doctor (ENT specialist) if you experience:\n\n• Hoarseness lasting more than 2 weeks\n• Pain while singing or speaking\n• Loss of your high range that doesn\'t come back\n• Feeling of a lump in your throat\n• Voice breaking unexpectedly\n• Frequent voice loss\n\nEarly treatment prevents permanent damage. Your voice is worth protecting!',
      tips: [
        'Never push through vocal pain',
        'A good warm-up prevents most strain injuries',
        'Sleep 7-8 hours — your voice recovers during sleep',
      ],
    ),
  ],
);
