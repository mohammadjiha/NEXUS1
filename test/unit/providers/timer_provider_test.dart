// test/unit/providers/timer_provider_test.dart
//
// Unit tests for ActiveSessionTimerNotifier and formattedTimeProvider.
// Uses flutter_riverpod's ProviderContainer — no Firebase, no widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/smart_workout/providers/active_session_timer_provider.dart';

void main() {
  // ── ActiveSessionTimerNotifier ────────────────────────────────────────────

  group('ActiveSessionTimerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is 0', () {
      expect(container.read(activeSessionTimerProvider), equals(0));
    });

    test('stop() resets state to 0', () {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      notifier.stop();
      expect(container.read(activeSessionTimerProvider), equals(0));
    });

    test('start() then stop() leaves state at 0', () {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      notifier.stop();
      expect(container.read(activeSessionTimerProvider), equals(0));
    });

    test('pause() and resume() do not crash', () {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      notifier.pause();
      notifier.resume();
      notifier.stop();
      expect(container.read(activeSessionTimerProvider), equals(0));
    });

    test('multiple stop() calls are idempotent', () {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.stop();
      notifier.stop();
      expect(container.read(activeSessionTimerProvider), equals(0));
    });

    test('timer increments after 1 second', () async {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      await Future.delayed(const Duration(milliseconds: 1100));
      final value = container.read(activeSessionTimerProvider);
      expect(value, greaterThanOrEqualTo(1));
      notifier.stop();
    });

    test('timer pauses and does not increment while paused', () async {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      await Future.delayed(const Duration(milliseconds: 1100));
      notifier.pause();
      final valueAtPause = container.read(activeSessionTimerProvider);
      await Future.delayed(const Duration(milliseconds: 1100));
      final valueAfterPause = container.read(activeSessionTimerProvider);
      expect(valueAfterPause, equals(valueAtPause));
      notifier.stop();
    });

    test('timer resumes incrementing after resume()', () async {
      final notifier = container.read(activeSessionTimerProvider.notifier);
      notifier.start();
      await Future.delayed(const Duration(milliseconds: 1100));
      notifier.pause();
      final atPause = container.read(activeSessionTimerProvider);
      notifier.resume();
      await Future.delayed(const Duration(milliseconds: 1100));
      final afterResume = container.read(activeSessionTimerProvider);
      expect(afterResume, greaterThan(atPause));
      notifier.stop();
    });
  });

  // ── formattedTimeProvider ─────────────────────────────────────────────────

  group('formattedTimeProvider', () {
    ProviderContainer containerWithSeconds(int seconds) {
      return ProviderContainer(
        overrides: [
          activeSessionTimerProvider.overrideWith(() {
            final notifier = ActiveSessionTimerNotifier();
            return notifier;
          }),
        ],
      );
    }

    test('formats 0 seconds as "0:00"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('0:00'));
    });

    test('formats 59 seconds as "0:59"', () {
      final container = ProviderContainer(
        overrides: [
          activeSessionTimerProvider.overrideWith(() => _FakeTimerNotifier(59)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('0:59'));
    });

    test('formats 60 seconds as "1:00"', () {
      final container = ProviderContainer(
        overrides: [
          activeSessionTimerProvider.overrideWith(() => _FakeTimerNotifier(60)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('1:00'));
    });

    test('formats 90 seconds as "1:30"', () {
      final container = ProviderContainer(
        overrides: [
          activeSessionTimerProvider.overrideWith(() => _FakeTimerNotifier(90)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('1:30'));
    });

    test('formats 3661 seconds as "61:01"', () {
      final container = ProviderContainer(
        overrides: [
          activeSessionTimerProvider
              .overrideWith(() => _FakeTimerNotifier(3661)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('61:01'));
    });

    test('seconds < 10 are zero-padded', () {
      final container = ProviderContainer(
        overrides: [
          activeSessionTimerProvider.overrideWith(() => _FakeTimerNotifier(65)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(formattedTimeProvider), equals('1:05'));
    });
  });
}

// ── Helper: notifier that starts at a fixed seconds value ─────────────────

class _FakeTimerNotifier extends ActiveSessionTimerNotifier {
  final int _fixedSeconds;
  _FakeTimerNotifier(this._fixedSeconds);

  @override
  int build() => _fixedSeconds;
}
