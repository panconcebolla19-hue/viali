import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pregunta.dart';
import 'permiso_repository.dart';
import 'pais_repository.dart';

class PreguntasRepository {
  static Future<List<Pregunta>> cargarPreguntas() async {
    final permiso = await PermisoRepository.getPermiso();
    final pais = await PaisRepository.getPais();
    final asset = switch ('${pais}_$permiso') {
      'ES_A' => 'assets/preguntas_A.json',
      'ES_C' => 'assets/preguntas_C.json',
      'IT_B' => 'assets/preguntas_IT_B.json',
      _ => 'assets/preguntas.json',
    };
    final String data = await rootBundle.loadString(asset);
    final List<dynamic> jsonList = json.decode(data) as List;
    return jsonList
        .map((e) => Pregunta.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
