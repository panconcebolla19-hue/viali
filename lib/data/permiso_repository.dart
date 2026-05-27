import 'package:shared_preferences/shared_preferences.dart';

class PermisoRepository {
  static const _key = 'permiso_activo';

  static Future<String> getPermiso() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'B';
  }

  static Future<void> setPermiso(String permiso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, permiso);
  }
}
