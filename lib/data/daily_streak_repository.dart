import 'package:shared_preferences/shared_preferences.dart';

class DailyStreakResult {
  final int streak;
  final int maxStreak;
  final bool isNewRecord;
  final bool isMilestone;
  final bool alreadyStudiedToday;

  const DailyStreakResult({
    required this.streak,
    required this.maxStreak,
    required this.isNewRecord,
    required this.isMilestone,
    required this.alreadyStudiedToday,
  });
}

class DailyStreakRepository {
  static const _keyStreak = 'racha_dias';
  static const _keyMaxStreak = 'racha_max_dias';
  static const _keyLastDate = 'racha_ultima_fecha';

  static const _milestones = {3, 7, 14, 30, 60, 100};

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<({int streak, int maxStreak})> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyLastDate);
    final stored = prefs.getInt(_keyStreak) ?? 0;
    final max = prefs.getInt(_keyMaxStreak) ?? 0;

    if (lastDate == null) return (streak: 0, maxStreak: max);

    final today = _isoDate(DateTime.now());
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final active = lastDate == today || lastDate == yesterday;

    return (streak: active ? stored : 0, maxStreak: max);
  }

  static Future<DailyStreakResult> registrarEstudio() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _isoDate(DateTime.now());
    final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final lastDate = prefs.getString(_keyLastDate);
    final stored = prefs.getInt(_keyStreak) ?? 0;
    final max = prefs.getInt(_keyMaxStreak) ?? 0;

    if (lastDate == today) {
      return DailyStreakResult(
        streak: stored,
        maxStreak: max,
        isNewRecord: false,
        isMilestone: false,
        alreadyStudiedToday: true,
      );
    }

    final newStreak = (lastDate == yesterday) ? stored + 1 : 1;
    final newMax = newStreak > max ? newStreak : max;

    await prefs.setInt(_keyStreak, newStreak);
    await prefs.setInt(_keyMaxStreak, newMax);
    await prefs.setString(_keyLastDate, today);

    return DailyStreakResult(
      streak: newStreak,
      maxStreak: newMax,
      isNewRecord: newStreak > max,
      isMilestone: _milestones.contains(newStreak),
      alreadyStudiedToday: false,
    );
  }
}
