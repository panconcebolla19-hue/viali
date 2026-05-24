import 'package:shared_preferences/shared_preferences.dart';

class FalladasRepository {
  static const _key = 'falladas_ids';

  static Future<Set<int>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toSet();
  }

  static Future<void> agregar(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? []).map(int.parse).toSet();
    current.addAll(ids);
    await prefs.setStringList(_key, current.map((e) => e.toString()).toList());
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
