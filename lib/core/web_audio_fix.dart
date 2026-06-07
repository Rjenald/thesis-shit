/// Web audio ducking fix — conditional export.
/// Routes to the stub (no-op) on native platforms,
/// and to the real JS-interop implementation on web.
export 'web_audio_fix_stub.dart'
    if (dart.library.html) 'web_audio_fix_web.dart';
