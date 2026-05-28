import 'package:shared_preferences/shared_preferences.dart';
import '../models/pais.dart';

class PaisRepository {
  static const _key = 'pais_activo';

  static Future<String> getPais() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'ES';
  }

  static Future<void> setPais(String pais) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pais);
  }

  static Future<ExamenConfig> getExamenConfig() async {
    final codigo = await getPais();
    return paisPorCodigo(codigo).examen;
  }
}
