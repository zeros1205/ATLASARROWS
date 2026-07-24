import 'package:atlas_arrows/services/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the player-state rules the shop, the boosters and the onboarding
/// gate all depend on. Progress is a singleton, so each test seeds the mock
/// store and reloads it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final progress = Progress.instance;

  Future<void> loadWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    await progress.load();
  }

  group('inventory', () {
    test('useRemove debits one and refuses at zero', () async {
      await loadWith({'removes': 2});
      expect(progress.useRemove(), isTrue);
      expect(progress.removes.value, 1);
      expect(progress.useRemove(), isTrue);
      expect(progress.removes.value, 0);
      // The empty state must not go negative — the UI routes to the shop here.
      expect(progress.useRemove(), isFalse);
      expect(progress.removes.value, 0);
    });

    test('useHint debits one and refuses at zero', () async {
      await loadWith({'hints': 1});
      expect(progress.useHint(), isTrue);
      expect(progress.hints.value, 0);
      expect(progress.useHint(), isFalse);
    });

    test('grants add to the existing stock', () async {
      await loadWith({'hints': 3, 'removes': 1});
      progress.grantHints(10);
      progress.grantRemoves(5);
      expect(progress.hints.value, 13);
      expect(progress.removes.value, 6);
    });

    test('a fresh player starts with the seeded stock', () async {
      await loadWith({});
      expect(progress.hints.value, Progress.startingHints);
      expect(progress.removes.value, Progress.startingRemoves);
    });
  });

  group('onboarding gate', () {
    test('a fresh install is not onboarded', () async {
      await loadWith({});
      expect(progress.onboarded.value, isFalse);
      expect(progress.coachDone.value, isFalse);
    });

    test('flags persist across a reload', () async {
      await loadWith({});
      progress.setOnboarded(true);
      progress.setCoachDone(true);
      await progress.load();
      expect(progress.onboarded.value, isTrue);
      expect(progress.coachDone.value, isTrue);
    });

    test('replay re-arms both the carousel and the coach', () async {
      await loadWith({'onboarded': true, 'coachDone': true, 'unlocked': 42});
      progress.replayOnboarding();
      expect(progress.onboarded.value, isFalse);
      expect(progress.coachDone.value, isFalse);
      // Replaying the tutorial must never cost the player their campaign.
      expect(progress.unlocked.value, 42);
    });
  });

  group('remove-ads', () {
    test('defaults off and persists once bought', () async {
      await loadWith({});
      expect(progress.adsRemoved.value, isFalse);
      progress.setAdsRemoved(true);
      await progress.load();
      expect(progress.adsRemoved.value, isTrue);
    });
  });

  group('markCleared', () {
    test('advances the unlock frontier but never rewinds it', () async {
      await loadWith({'unlocked': 5, 'totalClears': 0});
      progress.markCleared(5);
      expect(progress.unlocked.value, 6);
      expect(progress.totalClears.value, 1);
      // Replaying an old stage still counts as a clear, but can't lower the
      // frontier.
      progress.markCleared(1);
      expect(progress.unlocked.value, 6);
      expect(progress.totalClears.value, 2);
    });
  });
}
