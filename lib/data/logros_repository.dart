import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_historial_repository.dart';

class LogroDefinicion {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  const LogroDefinicion({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
  });
}

class Logro {
  final LogroDefinicion def;
  final DateTime? fechaConseguido;
  bool get conseguido => fechaConseguido != null;
  const Logro({required this.def, this.fechaConseguido});
}

class LogrosRepository {
  static const _keyLogros = 'logros_conseguidos';
  static const _keyTotal = 'preguntas_total';

  static const List<LogroDefinicion> definiciones = [
    LogroDefinicion(
      id: 'primera_racha',
      nombre: 'Primera racha',
      descripcion: 'Llega a 10 respuestas seguidas en Modo Racha',
      icono: Icons.local_fire_department_rounded,
    ),
    LogroDefinicion(
      id: 'imparable',
      nombre: 'Imparable',
      descripcion: 'Llega a 25 respuestas seguidas en Modo Racha',
      icono: Icons.flash_on_rounded,
    ),
    LogroDefinicion(
      id: 'leyenda',
      nombre: 'Leyenda',
      descripcion: 'Llega a 50 respuestas seguidas en Modo Racha',
      icono: Icons.auto_awesome_rounded,
    ),
    LogroDefinicion(
      id: 'constante',
      nombre: 'Constante',
      descripcion: '7 días seguidos estudiando',
      icono: Icons.calendar_today_rounded,
    ),
    LogroDefinicion(
      id: 'maquina',
      nombre: 'Máquina',
      descripcion: '30 días seguidos estudiando',
      icono: Icons.bolt_rounded,
    ),
    LogroDefinicion(
      id: 'centenario',
      nombre: 'Centenario',
      descripcion: '100 preguntas respondidas en total',
      icono: Icons.looks_one_rounded,
    ),
    LogroDefinicion(
      id: 'millar',
      nombre: 'Millar',
      descripcion: '1000 preguntas respondidas en total',
      icono: Icons.filter_9_plus_rounded,
    ),
    LogroDefinicion(
      id: 'aprobado',
      nombre: 'Aprobado',
      descripcion: 'Saca más del 90 % en un Test Normal',
      icono: Icons.check_circle_rounded,
    ),
    LogroDefinicion(
      id: 'perfecto',
      nombre: 'Perfecto',
      descripcion: 'Saca 30 de 30 en un test',
      icono: Icons.emoji_events_rounded,
    ),
  ];

  static Future<Map<String, DateTime>> _mapa(SharedPreferences prefs) async {
    final list = prefs.getStringList(_keyLogros) ?? [];
    final map = <String, DateTime>{};
    for (final s in list) {
      final idx = s.indexOf('|');
      if (idx < 0) continue;
      try {
        map[s.substring(0, idx)] = DateTime.parse(s.substring(idx + 1));
      } catch (e) {
        debugPrint('LogrosRepository: error al parsear logro "$s": $e');
      }
    }
    return map;
  }

  static Future<List<Logro>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _mapa(prefs);
    return definiciones
        .map((d) => Logro(def: d, fechaConseguido: map[d.id]))
        .toList();
  }

  static Future<void> incrementarPreguntas(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotal, (prefs.getInt(_keyTotal) ?? 0) + n);
  }

  static Future<List<LogroDefinicion>> checkAndUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _mapa(prefs);

    final rachaRecord = prefs.getInt('racha_record') ?? 0;
    final maxRachaDias = prefs.getInt('racha_max_dias') ?? 0;
    final total = prefs.getInt(_keyTotal) ?? 0;

    final historial = await TestHistorialRepository.cargar();
    final tieneAprobado = historial.any((r) => r.aprobado);
    final tienePerfecto = historial.any(
        (r) => r.correctas == r.totalPreguntas && r.totalPreguntas >= 30);

    final nuevos = <LogroDefinicion>[];

    void check(String id, bool cond) {
      if (!map.containsKey(id) && cond) {
        map[id] = DateTime.now();
        nuevos.add(definiciones.firstWhere((d) => d.id == id));
      }
    }

    check('primera_racha', rachaRecord >= 10);
    check('imparable', rachaRecord >= 25);
    check('leyenda', rachaRecord >= 50);
    check('constante', maxRachaDias >= 7);
    check('maquina', maxRachaDias >= 30);
    check('centenario', total >= 100);
    check('millar', total >= 1000);
    check('aprobado', tieneAprobado);
    check('perfecto', tienePerfecto);

    if (nuevos.isNotEmpty) {
      final strList = map.entries
          .map((e) => '${e.key}|${e.value.toIso8601String()}')
          .toList();
      await prefs.setStringList(_keyLogros, strList);
    }

    return nuevos;
  }
}
