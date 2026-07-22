import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'progress.dart';

/// Play Games Services (Android) and Game Center (iOS) behind one API.
///
/// Everything here is **best-effort and never fatal**: leaderboards and
/// achievements are a side channel, so a player who declines sign-in, is
/// offline, or runs a build where the console ids aren't registered yet must
/// still get an identical game. Every call catches, and every id below is
/// inert until the matching entry exists in the console — an unknown id just
/// makes the platform call fail, which we swallow.
///
/// Console setup (both stores) is documented in `docs/FIREBASE.md`.
abstract final class GameServices {
  /// ⚠️ KILL SWITCH — leave false until Play Console › Play Games Services is
  /// configured and the real numeric id is in
  /// `android/app/src/main/res/values/games_ids.xml`.
  ///
  /// The Play Games v2 SDK reads that manifest id at process start and
  /// **crashes natively** on a missing/placeholder value — Dart cannot catch
  /// it, so the only safe guard is to not call in at all. Flip this to true in
  /// the same commit that fills in the id.
  ///
  /// Enabled 2026-07-20 with the real numeric app id (182438652200) in
  /// games_ids.xml. Sign-in is live; the leaderboard/achievement ids below are
  /// still placeholders, so those specific calls fail quietly until their real
  /// ids are pasted in — sign-in and the app are unaffected.
  static const bool androidConfigured = true;

  /// Game Center needs no app-level id: enabling the capability in Xcode and
  /// declaring leaderboards in App Store Connect is enough, and an unknown id
  /// merely fails the call. So iOS has no equivalent switch.
  static const bool iosConfigured = true;

  /// Only Android/iOS have a native games backend, and only once that
  /// platform's console setup is actually done.
  static bool get supported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidConfigured,
      TargetPlatform.iOS => iosConfigured,
      _ => false,
    };
  }

  /// Whether the player is signed in. Drives the optional UI affordances
  /// (leaderboard / achievements buttons) — never gates gameplay.
  static final ValueNotifier<bool> signedIn = ValueNotifier(false);

  // ── Console ids ────────────────────────────────────────────────────────
  // Android ids come from Play Console › Play Games Services; iOS ids are
  // whatever you type in App Store Connect › Game Center. They do NOT have to
  // match across stores, which is why every entry carries both.

  /// Total stages cleared — the campaign's headline ranking.
  static const _leaderboardStages = (
    android: 'CgkI_atlsars_stages',
    ios: 'atlsars.leaderboard.stages',
  );

  /// Countries fully completed — rewards breadth over grinding one round.
  static const _leaderboardCountries = (
    android: 'CgkI_atlsars_countries',
    ios: 'atlsars.leaderboard.countries',
  );

  /// Continent-completion achievements (all countries of a continent cleared),
  /// keyed by the `continent` string in bank.json. Android ids are placeholders
  /// until the Play Console import mints the real CgkI… values (see
  /// docs/FIREBASE.md); an unknown id just makes the call no-op.
  static const _continentAchievements = <String, ({String android, String ios})>{
    'Europe': (android: 'CgkI_atlsars_europe', ios: 'atlsars.achievement.europe'),
    'Asia': (android: 'CgkI_atlsars_asia', ios: 'atlsars.achievement.asia'),
    'Africa': (android: 'CgkI_atlsars_africa', ios: 'atlsars.achievement.africa'),
    'North America':
        (android: 'CgkI_atlsars_north_america', ios: 'atlsars.achievement.north_america'),
    'South America':
        (android: 'CgkI_atlsars_south_america', ios: 'atlsars.achievement.south_america'),
    'Oceania': (android: 'CgkI_atlsars_oceania', ios: 'atlsars.achievement.oceania'),
  };

  static const _achievements = <String, ({String android, String ios})>{
    'first_clear': (
      android: 'CgkI_atlsars_first_clear',
      ios: 'atlsars.achievement.first_clear',
    ),
    'first_country': (
      android: 'CgkI_atlsars_first_country',
      ios: 'atlsars.achievement.first_country',
    ),
    'stages_50': (
      android: 'CgkI_atlsars_stages_50',
      ios: 'atlsars.achievement.stages_50',
    ),
    'stages_250': (
      android: 'CgkI_atlsars_stages_250',
      ios: 'atlsars.achievement.stages_250',
    ),
    'flawless': (
      android: 'CgkI_atlsars_flawless',
      ios: 'atlsars.achievement.flawless',
    ),
  };

  /// Attempts a silent sign-in during boot. Called from the boot sequence and
  /// allowed to fail — a declined or unavailable sign-in must not delay the
  /// player or surface an error.
  ///
  /// Checks [GameAuth.isSignedIn] first rather than calling [GameAuth.signIn]
  /// unconditionally: an already-authenticated player gets the platform's own
  /// silent restore (Play Games shows its small "signed in" banner at the top
  /// on its own) instead of the interactive account-picker sheet, which
  /// [GameAuth.signIn] pops up every time regardless of whether the player
  /// was already signed in.
  static Future<void> init() async {
    if (!supported) return;
    try {
      if (await GameAuth.isSignedIn) {
        signedIn.value = true;
        return;
      }
      await GameAuth.signIn();
      signedIn.value = await GameAuth.isSignedIn;
    } catch (_) {
      signedIn.value = false;
    }
  }

  /// Explicit sign-in from a UI affordance (Settings). Returns whether the
  /// player ended up signed in, so the caller can report the outcome.
  static Future<bool> signIn() async {
    if (!supported) return false;
    try {
      await GameAuth.signIn();
      signedIn.value = await GameAuth.isSignedIn;
    } catch (_) {
      signedIn.value = false;
    }
    return signedIn.value;
  }

  /// Pushes the player's campaign standing. Both boards take a plain count,
  /// so re-submitting the same value is harmless — the platform keeps the max.
  static Future<void> submitProgress({
    required int stagesCleared,
    required int countriesCompleted,
  }) async {
    if (!supported || !signedIn.value) return;
    await _quietly(() => Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: _leaderboardStages.android,
            iOSLeaderboardID: _leaderboardStages.ios,
            value: stagesCleared,
          ),
        ));
    await _quietly(() => Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: _leaderboardCountries.android,
            iOSLeaderboardID: _leaderboardCountries.ios,
            value: countriesCompleted,
          ),
        ));
  }

  /// Unlocks the achievement registered under [key] in [_achievements].
  static Future<void> unlock(String key) async {
    final ids = _achievements[key];
    if (!supported || !signedIn.value || ids == null) return;
    await _quietly(() => Achievements.unlock(
          achievement: Achievement(
            androidID: ids.android,
            iOSID: ids.ios,
            percentComplete: 100,
          ),
        ));
  }

  /// Milestone rules, evaluated after each clear. Kept here rather than in the
  /// game screen so the thresholds live next to the ids they unlock.
  static Future<void> reportClear({
    required int totalClears,
    required bool countryCompleted,
    required bool flawless,
  }) async {
    if (!supported || !signedIn.value) return;
    if (totalClears >= 1) await unlock('first_clear');
    if (totalClears >= 50) await unlock('stages_50');
    if (totalClears >= 250) await unlock('stages_250');
    if (countryCompleted) await unlock('first_country');
    if (flawless) await unlock('flawless');
  }

  /// Unlocks the continent-completion achievement for each fully-cleared
  /// continent. Idempotent — an already-unlocked achievement is a no-op — so
  /// the caller can pass every completed continent on each country finish.
  static Future<void> unlockContinents(List<String> continents) async {
    if (!supported || !signedIn.value) return;
    for (final c in continents) {
      final ids = _continentAchievements[c];
      if (ids == null) continue;
      await _quietly(() => Achievements.unlock(
            achievement: Achievement(
              androidID: ids.android,
              iOSID: ids.ios,
              percentComplete: 100,
            ),
          ));
    }
  }

  static Future<void> showLeaderboards() async {
    if (!supported) return;
    if (!signedIn.value && !await signIn()) return;
    await _quietly(() => Leaderboards.showLeaderboards(
          androidLeaderboardID: _leaderboardStages.android,
          iOSLeaderboardID: _leaderboardStages.ios,
        ));
  }

  static Future<void> showAchievements() async {
    if (!supported) return;
    if (!signedIn.value && !await signIn()) return;
    await _quietly(Achievements.showAchievements);
  }

  /// Runs a platform call, swallowing anything it throws. Failures here are
  /// expected in normal operation (offline, id not registered yet, player
  /// signed out mid-session) and must never reach the player.
  static Future<void> _quietly(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (e) {
      if (kDebugMode) debugPrint('GameServices call failed (ignored): $e');
    }
  }
}

/// Convenience: submit whatever the local [Progress] currently holds.
Future<void> syncProgressToGameServices({required int countriesCompleted}) =>
    GameServices.submitProgress(
      stagesCleared: Progress.instance.totalClears.value,
      countriesCompleted: countriesCompleted,
    );
