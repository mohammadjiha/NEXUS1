import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveSessionTimerNotifier extends Notifier<int> {
  Timer? _timer;
  bool _isPaused = false;

  @override
  int build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return 0; // Elapsed seconds
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        state = state + 1;
      }
    });
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void stop() {
    _timer?.cancel();
    state = 0;
  }
}

final activeSessionTimerProvider = NotifierProvider<ActiveSessionTimerNotifier, int>(() {
  return ActiveSessionTimerNotifier();
});

final formattedTimeProvider = Provider<String>((ref) {
  final elapsedSeconds = ref.watch(activeSessionTimerProvider);
  int m = elapsedSeconds ~/ 60;
  int s = elapsedSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
});
