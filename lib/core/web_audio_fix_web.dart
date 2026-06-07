/// Web audio ducking fix — real implementation using JS interop.
///
/// On mobile browsers, when getUserMedia() activates the microphone,
/// Chrome automatically reduces playback volume ("audio ducking").
/// This helper forces all HTML <audio> elements back to full volume.
library;

import 'dart:js_interop';

@JS('eval')
external JSAny? _jsEval(JSString code);

/// Call this AFTER the microphone has been started.
/// Finds all <audio> elements in the DOM and sets volume to 1.0,
/// plus resumes playback if the browser auto-paused them.
void fixWebAudioDucking() {
  try {
    _jsEval(
      '''
      (function() {
        var audios = document.querySelectorAll('audio');
        for (var i = 0; i < audios.length; i++) {
          audios[i].volume = 1.0;
          if (audios[i].paused && audios[i].currentTime > 0) {
            audios[i].play().catch(function(){});
          }
        }
      })();
      '''.toJS,
    );
  } catch (_) {
    // JS interop failed — silently ignore
  }
}
