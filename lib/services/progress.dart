import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player state: unlock progress, hints, settings.
/// Load once before runApp; notifiers drive the UI everywhere.
class Progress {
  Progress._();

  static final Progress instance = Progress._();

  static const int startingHints = 3;
  static const int startingRemoves = 1;

  /// Heart-refill coupons. The player is given exactly one, ever — spending it
  /// drops the fail sheet to the ad path for good. It used to be a per-stage
  /// bool, so the "free" refill came back on every board.
  static const int startingRefillCoupons = 1;

  late SharedPreferences _prefs;

  /// Highest level index the player may enter (0-based). World Tour only —
  /// Random play never advances this.
  final ValueNotifier<int> unlocked = ValueNotifier(0);

  /// Global stage indices already served in Random play, so the next pick can
  /// avoid them. Reset (looped) once every stage has come up.
  final Set<int> playedRandom = {};
  final ValueNotifier<int> hints = ValueNotifier(startingHints);
  final ValueNotifier<int> removes = ValueNotifier(startingRemoves);
  final ValueNotifier<int> refillCoupons =
      ValueNotifier(startingRefillCoupons);
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

  /// Developer cheat: puts a "clear this stage" button on the play screen.
  /// Armed by tapping LOGAN ten times in Settings, disarmed by tapping LAND
  /// ten times. Persisted so a test session survives a restart — nothing shows
  /// it but the button itself, so it cannot be reached by accident.
  final ValueNotifier<bool> cheatOn = ValueNotifier(false);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    unlocked.value = _prefs.getInt('unlocked') ?? 0;
    hints.value = _prefs.getInt('hints') ?? startingHints;
    removes.value = _prefs.getInt('removes') ?? startingRemoves;
    refillCoupons.value =
        _prefs.getInt('refillCoupons') ?? startingRefillCoupons;
    totalClears.value = _prefs.getInt('totalClears') ?? 0;
    soundOn.value = _prefs.getBool('soundOn') ?? true;
    hapticsOn.value = _prefs.getBool('hapticsOn') ?? true;
    onboarded.value = _prefs.getBool('onboarded') ?? false;
    adsRemoved.value = _prefs.getBool('adsRemoved') ?? false;
    coachDone.value = _prefs.getBool('coachDone') ?? false;
    cheatOn.value = _prefs.getBool('cheatOn') ?? false;
    playedRandom
      ..clear()
      ..addAll(
          (_prefs.getStringList('playedRandom') ?? const []).map(int.parse));
  }

  void markCleared(int levelIndex) {
    addClear();
    if (levelIndex + 1 > unlocked.value) {
      unlocked.value = levelIndex + 1;
      _prefs.setInt('unlocked', unlocked.value);
    }
  }

  /// Counts a clear toward the lifetime total without touching World Tour
  /// unlock progress — used by Random play.
  void addClear() {
    totalClears.value++;
    _prefs.setInt('totalClears', totalClears.value);
  }

  /// Records a Random-play stage as served; loops the set once it is full.
  void markPlayedRandom(int stage, int totalStages) {
    playedRandom.add(stage);
    if (playedRandom.length >= totalStages) playedRandom.clear();
    _prefs.setStringList(
        'playedRandom', playedRandom.map((e) => e.toString()).toList());
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

  void useRefillCoupon() {
    if (refillCoupons.value <= 0) return;
    refillCoupons.value--;
    _prefs.setInt('refillCoupons', refillCoupons.value);
  }

  void setCheatOn(bool on) {
    cheatOn.value = on;
    _prefs.setBool('cheatOn', on);
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
