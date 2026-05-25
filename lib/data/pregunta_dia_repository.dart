import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PreguntaDiaRepository {
  static const _keyFecha = 'pregunta_dia_fecha';
  static const _keyResultado = 'pregunta_dia_resultado';

  static String _hoy() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static int indiceDelDia(int total) {
    final d = DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return Random(seed).nextInt(total);
  }

  // Returns the same shuffled option order every day (seed = date+1)
  static List<int> ordenOpciones() {
    final d = DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day + 1;
    final indices = [0, 1, 2];
    indices.shuffle(Random(seed));
    return indices;
  }

  static Future<bool?> getResultadoHoy() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyFecha) != _hoy()) return null;
    final r = prefs.getString(_keyResultado);
    return r == null ? null : r == 'true';
  }

  static Future<void> guardarResultado(bool correcto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFecha, _hoy());
    await prefs.setString(_keyResultado, correcto.toString());
  }
}
