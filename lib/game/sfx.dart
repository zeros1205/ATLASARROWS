import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import '../services/progress.dart';

/// The escape sound "instruments". Each stage plays a single, randomly chosen
/// voice so the game doesn't sound the same twice in a row; within a stage the
/// voice's pitch still climbs a semitone per combo step (see [Sfx.pop]).
enum EscapeVoice { marimba, pluck, blip, bubble, whoosh }

/// Sound + haptic feedback, gated by the player's settings. Every call is
/// fire-and-forget and swallows platform errors (web autoplay policies,
/// missing haptics on desktop).
abstract final class Sfx {
  /// How many pre-rendered semitone steps each voice ships (esc_<voice>_0..7).
  static const _comboSteps = 8;

  static final _rng = math.Random();
  static EscapeVoice _voice = EscapeVoice.marimba;

  static final List<String> _files = [
    for (final v in EscapeVoice.values)
      for (var i = 0; i < _comboSteps; i++) 'esc_${v.name}_$i.wav',
    'block.wav',
    'clear.wav',
    'fail.wav',
  ];

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (_) {}
  }

  /// Picks the escape voice for the stage about to start. Called once per level
  /// load, so the whole stage speaks with one instrument.
  static void pickStageVoice() {
    _voice = EscapeVoice.values[_rng.nextInt(EscapeVoice.values.length)];
  }

  /// Escape pop. [comboIndex] walks the voice's semitone ladder up and then
  /// back down, over and over: 0..7, 6..1, 0..7. Clamping instead — which is
  /// what this did — parks a long combo on the top note and hammers it, which
  /// is where the sound stops being a reward and starts being a nuisance.
  static void pop(int comboIndex) {
    _play('esc_${_voice.name}_${_ladder(comboIndex)}.wav', 0.8);
    _haptic(HapticFeedback.lightImpact);
  }

  /// Triangle wave over the [_comboSteps] pre-rendered pitches.
  static int _ladder(int i) {
    if (i < 0) return 0;
    final period = (_comboSteps - 1) * 2; // up, then back down
    final pos = i % period;
    return pos < _comboSteps ? pos : period - pos;
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
