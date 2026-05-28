import 'package:shared_preferences/shared_preferences.dart';

class IdiomaRepository {
  static const _key = 'idioma_activo';

  static Future<String> getIdioma() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'es';
  }

  static Future<void> setIdioma(String idioma) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, idioma);
  }
}
