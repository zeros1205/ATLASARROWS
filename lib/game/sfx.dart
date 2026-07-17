import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import '../services/progress.dart';

/// Sound + haptic feedback, gated by the player's settings. Every call is
/// fire-and-forget and swallows platform errors (web autoplay policies,
/// missing haptics on desktop).
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
    _haptic(HapticFeedback.lightImpact);
  }

  static void block() {
    _play('block.wav', 0.8);
    _haptic(HapticFeedback.mediumImpact);
  }

  static void clear() {
    _play('clear.wav', 0.9);
    _haptic(HapticFeedback.lightImpact);
  }

  static void fail() {
    _play('fail.wav', 0.85);
    _haptic(HapticFeedback.heavyImpact);
  }

  static void _play(String file, double volume) {
    if (!Progress.instance.soundOn.value) return;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  static void _haptic(Future<void> Function() impact) {
    if (!Progress.instance.hapticsOn.value) return;
    impact().catchError((_) {});
  }
}
