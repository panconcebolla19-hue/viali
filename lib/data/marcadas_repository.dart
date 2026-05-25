import 'package:shared_preferences/shared_preferences.dart';

class MarcadasRepository {
  static const _key = 'preguntas_marcadas';

  static Future<Set<int>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toSet();
  }

  static Future<bool> alternar(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final current = raw.map(int.parse).toSet();
    final marcada = current.contains(id);
    if (marcada) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await prefs.setStringList(_key, current.map((e) => e.toString()).toList());
    return !marcada;
  }
}
