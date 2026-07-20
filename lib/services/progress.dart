import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player state: unlock progress, hints, settings.
/// Load once before runApp; notifiers drive the UI everywhere.
class Progress {
  Progress._();

  static final Progress instance = Progress._();

  static const int startingHints = 3;
  static const int startingRemoves = 1;

  late SharedPreferences _prefs;

  /// Highest level index the player may enter (0-based).
  final ValueNotifier<int> unlocked = ValueNotifier(0);
  final ValueNotifier<int> hints = ValueNotifier(startingHints);
  final ValueNotifier<int> removes = ValueNotifier(startingRemoves);
  final ValueNotifier<int> totalClears = ValueNotifier(0);
  final ValueNotifier<bool> soundOn = ValueNotifier(true);
  final ValueNotifier<bool> hapticsOn = ValueNotifier(true);

  /// False until the player has finished the intro carousel — boot routes
  /// first-run players to onboarding instead of the shell.
  final ValueNotifier<bool> onboarded = ValueNotifier(false);

  /// True once the remove-ads product is owned. Every ad surface checks it.
  final ValueNotifier<bool> adsRemoved = ValueNotifier(false);

  /// False until the player has cleared their first line in-play — drives the
  /// first-stage coach overlay.
  final ValueNotifier<bool> coachDone = ValueNotifier(false);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    unlocked.value = _prefs.getInt('unlocked') ?? 0;
    hints.value = _prefs.getInt('hints') ?? startingHints;
    removes.value = _prefs.getInt('removes') ?? startingRemoves;
    totalClears.value = _prefs.getInt('totalClears') ?? 0;
    soundOn.value = _prefs.getBool('soundOn') ?? true;
    hapticsOn.value = _prefs.getBool('hapticsOn') ?? true;
    onboarded.value = _prefs.getBool('onboarded') ?? false;
    adsRemoved.value = _prefs.getBool('adsRemoved') ?? false;
    coachDone.value = _prefs.getBool('coachDone') ?? false;
  }

  void markCleared(int levelIndex) {
    totalClears.value++;
    _prefs.setInt('totalClears', totalClears.value);
    if (levelIndex + 1 > unlocked.value) {
      unlocked.value = levelIndex + 1;
      _prefs.setInt('unlocked', unlocked.value);
    }
  }

  /// Consumes one hint; returns false when none are left.
  bool useHint() {
    if (hints.value <= 0) return false;
    hints.value--;
    _prefs.setInt('hints', hints.value);
    return true;
  }

  /// Consumes one remove; returns false when none are left. Called when the
  /// item actually fires (a line is struck), not when it is armed.
  bool useRemove() {
    if (removes.value <= 0) return false;
    removes.value--;
    _prefs.setInt('removes', removes.value);
    return true;
  }

  /// Reward hook (rewarded ad / IAP call these).
  void grantHints(int count) {
    hints.value += count;
    _prefs.setInt('hints', hints.value);
  }

  void grantRemoves(int count) {
    removes.value += count;
    _prefs.setInt('removes', removes.value);
  }

  void setSound(bool on) {
    soundOn.value = on;
    _prefs.setBool('soundOn', on);
  }

  void setHaptics(bool on) {
    hapticsOn.value = on;
    _prefs.setBool('hapticsOn', on);
  }

  void setOnboarded(bool done) {
    onboarded.value = done;
    _prefs.setBool('onboarded', done);
  }

  void setCoachDone(bool done) {
    coachDone.value = done;
    _prefs.setBool('coachDone', done);
  }

  void setAdsRemoved(bool removed) {
    adsRemoved.value = removed;
    _prefs.setBool('adsRemoved', removed);
  }

  /// Settings › "튜토리얼 다시 보기": replays the intro carousel and the
  /// first-stage coach without touching campaign progress.
  void replayOnboarding() {
    setOnboarded(false);
    setCoachDone(false);
  }
}
