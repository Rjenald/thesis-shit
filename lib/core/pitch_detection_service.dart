/// Common shape shared by AudioService (local YIN) and CrepePitchService
/// (real CREPE model over the network), so callers can swap between them
/// without caring which one is actually running.
library;

import 'note_utils.dart';

abstract class PitchDetectionService {
  Future<bool> start({double? targetFreq, bool enableMonitoring = true});
  Future<void> stop();
  void dispose();
  Stream<NoteResult?> get results;
  Stream<List<int>> get rawBytes;
}
