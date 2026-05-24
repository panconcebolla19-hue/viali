import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_resultado.dart';

class TestHistorialRepository {
  static const _key = 'test_historial';
  static const _maxEntradas = 50;

  static Future<List<TestResultado>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) =>
            TestResultado.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> guardar(TestResultado resultado) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(json.encode(resultado.toJson()));
    if (raw.length > _maxEntradas) raw.removeAt(0);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<Set<int>> idsPreguntasFalladas() async {
    final historial = await cargar();
    final ids = <int>{};
    for (final r in historial) {
      ids.addAll(r.preguntasFalladas);
    }
    return ids;
  }
}
