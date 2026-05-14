/// Mirrors com.example.kathmanduhiker.util.RankingManager exactly so XP rules
/// match between the Android and Flutter clients.
class RankingManager {
  static const int xpPerLevel = 100;
  static const int maxLevel = 100;

  static const int xpTrailSubmitted = 15;
  static const int xpTrailApproved = 80;
  static const int xpReview = 10;
  static const int xpCommunityPhoto = 20;
  static const int xpHostHike = 30;
  static const int xpEasyHike = 50;
  static const int xpStandardHike = 100;

  static int getLevelNumber(int xp) {
    final base = xp < 0 ? 0 : xp;
    final level = (base ~/ xpPerLevel) + 1;
    return level > maxLevel ? maxLevel : level;
  }

  static String getLevelTitle(int xp) {
    final level = getLevelNumber(xp);
    if (level >= 100) return 'Trail Master';
    if (level >= 75) return 'Mountain Guide';
    if (level >= 50) return 'Explorer';
    if (level >= 25) return 'Pathfinder';
    if (level >= 10) return 'Trail Walker';
    if (level >= 2) return 'Beginner';
    return 'New Hiker';
  }

  static String getLevelLabel(int xp) =>
      'Level ${getLevelNumber(xp)} - ${getLevelTitle(xp)}';

  static int getCurrentLevelXp(int xp) => (getLevelNumber(xp) - 1) * xpPerLevel;

  static int getNextLevelXp(int xp) {
    final level = getLevelNumber(xp);
    return level >= maxLevel ? getCurrentLevelXp(xp) : level * xpPerLevel;
  }

  static double getLevelProgress(int xp) {
    final level = getLevelNumber(xp);
    if (level >= maxLevel) return 1.0;
    final current = getCurrentLevelXp(xp);
    final next = getNextLevelXp(xp);
    final progressInLevel = (xp - current).clamp(0, next - current);
    return (progressInLevel / (next - current)).clamp(0.0, 1.0);
  }
}
