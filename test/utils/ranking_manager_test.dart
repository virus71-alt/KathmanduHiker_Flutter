// Per ULTIMATE.md §13 — domain logic gets the highest coverage. RankingManager
// is pure functions, so it's an easy starting point that should run in ms.

import 'package:flutter_test/flutter_test.dart';
import 'package:kathmanduhiker/utils/ranking_manager.dart';

void main() {
  group('getLevelNumber', () {
    test('zero XP returns level 1', () {
      expect(RankingManager.getLevelNumber(0), 1);
    });

    test('negative XP is clamped to level 1', () {
      expect(RankingManager.getLevelNumber(-50), 1);
    });

    test('exactly one level worth of XP advances by one', () {
      expect(RankingManager.getLevelNumber(100), 2);
      expect(RankingManager.getLevelNumber(200), 3);
    });

    test('partial XP within a level stays on that level', () {
      expect(RankingManager.getLevelNumber(99), 1);
      expect(RankingManager.getLevelNumber(150), 2);
    });

    test('XP beyond maxLevel saturates at 100', () {
      expect(RankingManager.getLevelNumber(99999), 100);
      expect(
        RankingManager.getLevelNumber(RankingManager.maxLevel * 200),
        100,
      );
    });
  });

  group('getLevelTitle', () {
    test('boundary titles map correctly', () {
      // Level 1 → 'New Hiker' (level < 2)
      expect(RankingManager.getLevelTitle(0), 'New Hiker');
      // Level 2 → 'Beginner' (level >= 2)
      expect(RankingManager.getLevelTitle(100), 'Beginner');
      // Level 10 → 'Trail Walker'
      expect(RankingManager.getLevelTitle(900), 'Trail Walker');
      // Level 25 → 'Pathfinder'
      expect(RankingManager.getLevelTitle(2400), 'Pathfinder');
      // Level 50 → 'Explorer'
      expect(RankingManager.getLevelTitle(4900), 'Explorer');
      // Level 75 → 'Mountain Guide'
      expect(RankingManager.getLevelTitle(7400), 'Mountain Guide');
      // Level 100 → 'Trail Master'
      expect(RankingManager.getLevelTitle(9900), 'Trail Master');
    });
  });

  group('getLevelLabel', () {
    test('formats as "Level N - Title"', () {
      expect(RankingManager.getLevelLabel(0), 'Level 1 - New Hiker');
      expect(RankingManager.getLevelLabel(150), 'Level 2 - Beginner');
    });
  });

  group('getLevelProgress', () {
    test('progress is 0.0 at exact level boundary', () {
      expect(RankingManager.getLevelProgress(0), 0.0);
      expect(RankingManager.getLevelProgress(100), 0.0);
      expect(RankingManager.getLevelProgress(200), 0.0);
    });

    test('progress is 0.5 halfway through a level', () {
      expect(RankingManager.getLevelProgress(50), 0.5);
      expect(RankingManager.getLevelProgress(150), 0.5);
    });

    test('progress is clamped to [0.0, 1.0]', () {
      final p = RankingManager.getLevelProgress(150);
      expect(p, inInclusiveRange(0.0, 1.0));
    });

    test('max level returns full progress', () {
      expect(RankingManager.getLevelProgress(999999), 1.0);
    });
  });

  group('XP constants are stable', () {
    // These values are mirrored in the Android Kotlin client. If a test
    // here fails, the Kotlin side must be updated too — keep them in
    // lockstep or scoring will diverge between clients.
    test('XP rewards match the Kotlin contract', () {
      expect(RankingManager.xpPerLevel, 100);
      expect(RankingManager.xpTrailSubmitted, 15);
      expect(RankingManager.xpTrailApproved, 80);
      expect(RankingManager.xpReview, 10);
      expect(RankingManager.xpCommunityPhoto, 20);
      expect(RankingManager.xpHostHike, 30);
      expect(RankingManager.xpEasyHike, 50);
      expect(RankingManager.xpStandardHike, 100);
    });
  });
}
