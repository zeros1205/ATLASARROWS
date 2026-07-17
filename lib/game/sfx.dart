import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Sound + haptic feedback. Every call is fire-and-forget and swallows
/// platform errors (web autoplay policies, missing haptics on desktop).
abstract final class Sfx {
  static const _files = [
    'pop_0.wav',
    'pop_1.wav',
    'pop_2.wav',
    'pop_3.wav',
    'pop_4.wav',
    'pop_5.wav',
    'pop_6.wav',
    'pop_7.wav',
    'block.wav',
    'clear.wav',
    'fail.wav',
  ];

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (_) {}
  }

  /// Escape pop; [comboIndex] 0..n raises the pitch a semitone per step.
  static void pop(int comboIndex) {
    _play('pop_${comboIndex.clamp(0, 7)}.wav', 0.8);
    HapticFeedback.lightImpact().catchError((_) {});
  }

  static void block() {
    _play('block.wav', 0.8);
    HapticFeedback.mediumImpact().catchError((_) {});
  }

  static void clear() {
    _play('clear.wav', 0.9);
    HapticFeedback.lightImpact().catchError((_) {});
  }

  static void fail() {
    _play('fail.wav', 0.85);
    HapticFeedback.heavyImpact().catchError((_) {});
  }

  static void _play(String file, double volume) {
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }
}
