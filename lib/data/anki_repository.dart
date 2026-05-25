import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnkiEntry {
  final int vistas;
  final int totalFalladas;
  final int acertadasSeguidas;
  final String? ultimoRepaso;
  final int intervaloDias;

  const AnkiEntry({
    this.vistas = 0,
    this.totalFalladas = 0,
    this.acertadasSeguidas = 0,
    this.ultimoRepaso,
    this.intervaloDias = 0,
  });

  bool get pendienteHoy {
    if (ultimoRepaso == null) return false;
    final last = DateTime.parse(ultimoRepaso!);
    final hoy = DateTime.now();
    final lastDate = DateTime(last.year, last.month, last.day);
    final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
    return hoyDate.difference(lastDate).inDays >= intervaloDias;
  }

  AnkiEntry copyWith({
    int? vistas,
    int? totalFalladas,
    int? acertadasSeguidas,
    String? ultimoRepaso,
    int? intervaloDias,
  }) {
    return AnkiEntry(
      vistas: vistas ?? this.vistas,
      totalFalladas: totalFalladas ?? this.totalFalladas,
      acertadasSeguidas: acertadasSeguidas ?? this.acertadasSeguidas,
      ultimoRepaso: ultimoRepaso ?? this.ultimoRepaso,
      intervaloDias: intervaloDias ?? this.intervaloDias,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': vistas,
        'f': totalFalladas,
        'as': acertadasSeguidas,
        'ur': ultimoRepaso,
        'id': intervaloDias,
      };

  factory AnkiEntry.fromJson(Map<String, dynamic> json) => AnkiEntry(
        vistas: (json['v'] as int?) ?? 0,
        totalFalladas: (json['f'] as int?) ?? 0,
        acertadasSeguidas: (json['as'] as int?) ?? 0,
        ultimoRepaso: json['ur'] as String?,
        intervaloDias: (json['id'] as int?) ?? 0,
      );
}

class AnkiRepository {
  static const _keyData = 'anki_data';
  static const _keyActividad = 'anki_actividad';

  static String _hoy() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<int, AnkiEntry>> _cargarMapa(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyData);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(int.parse(k), AnkiEntry.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _guardarMapa(SharedPreferences prefs, Map<int, AnkiEntry> mapa) async {
    final encoded = jsonEncode(mapa.map((k, v) => MapEntry(k.toString(), v.toJson())));
    await prefs.setString(_keyData, encoded);
  }

  static Future<void> registrarRespuesta(int preguntaId, bool correcto) async {
    final prefs = await SharedPreferences.getInstance();
    final mapa = await _cargarMapa(prefs);
    final entry = mapa[preguntaId] ?? const AnkiEntry();

    AnkiEntry updated;
    if (!correcto) {
      updated = entry.copyWith(
        acertadasSeguidas: 0,
        totalFalladas: entry.totalFalladas + 1,
        intervaloDias: 1,
        vistas: entry.vistas + 1,
        ultimoRepaso: _hoy(),
      );
    } else {
      final nuevasAcertadas = entry.acertadasSeguidas + 1;
      final int nuevoIntervalo;
      switch (nuevasAcertadas) {
        case 1:
          nuevoIntervalo = 3;
          break;
        case 2:
          nuevoIntervalo = 7;
          break;
        case 3:
          nuevoIntervalo = 21;
          break;
        default:
          nuevoIntervalo = 60;
      }
      updated = entry.copyWith(
        acertadasSeguidas: nuevasAcertadas,
        intervaloDias: nuevoIntervalo,
        vistas: entry.vistas + 1,
        ultimoRepaso: _hoy(),
      );
    }

    mapa[preguntaId] = updated;
    await _guardarMapa(prefs, mapa);
    await _incrementarActividad(prefs);
  }

  static Future<void> _incrementarActividad(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyActividad);
    Map<String, int> actividad;
    try {
      actividad = raw == null
          ? {}
          : (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      actividad = {};
    }

    final hoy = _hoy();
    actividad[hoy] = (actividad[hoy] ?? 0) + 1;

    final limite = DateTime.now().subtract(const Duration(days: 13));
    actividad.removeWhere((fecha, _) {
      try {
        return DateTime.parse(fecha).isBefore(limite);
      } catch (_) {
        return true;
      }
    });

    await prefs.setString(_keyActividad, jsonEncode(actividad));
  }

  // calificacion: 0=no sabía (→1d), 1=casi (→3d), 2=lo sabía (→7/21/60d)
  static Future<void> registrarFlashcard(int preguntaId, int calificacion) async {
    final prefs = await SharedPreferences.getInstance();
    final mapa = await _cargarMapa(prefs);
    final entry = mapa[preguntaId] ?? const AnkiEntry();
    final AnkiEntry updated;
    switch (calificacion) {
      case 0:
        updated = entry.copyWith(
          acertadasSeguidas: 0,
          totalFalladas: entry.totalFalladas + 1,
          intervaloDias: 1,
          vistas: entry.vistas + 1,
          ultimoRepaso: _hoy(),
        );
        break;
      case 1:
        updated = entry.copyWith(
          acertadasSeguidas: entry.acertadasSeguidas > 0 ? entry.acertadasSeguidas : 1,
          intervaloDias: 3,
          vistas: entry.vistas + 1,
          ultimoRepaso: _hoy(),
        );
        break;
      default:
        final nuevasAcertadas = entry.acertadasSeguidas + 1;
        final int nuevoIntervalo;
        switch (nuevasAcertadas) {
          case 1: nuevoIntervalo = 7; break;
          case 2: nuevoIntervalo = 21; break;
          default: nuevoIntervalo = 60;
        }
        updated = entry.copyWith(
          acertadasSeguidas: nuevasAcertadas,
          intervaloDias: nuevoIntervalo,
          vistas: entry.vistas + 1,
          ultimoRepaso: _hoy(),
        );
    }
    mapa[preguntaId] = updated;
    await _guardarMapa(prefs, mapa);
    await _incrementarActividad(prefs);
  }

  static Future<List<int>> pendientesHoy(List<int> todosIds) async {
    final prefs = await SharedPreferences.getInstance();
    final mapa = await _cargarMapa(prefs);
    return todosIds.where((id) {
      final entry = mapa[id];
      return entry != null && entry.pendienteHoy;
    }).toList();
  }

  static Future<Map<int, AnkiEntry>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    return _cargarMapa(prefs);
  }

  static Future<Map<String, int>> cargarActividad() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActividad);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }
}
