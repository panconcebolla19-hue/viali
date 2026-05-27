import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pregunta.dart';
import 'permiso_repository.dart';

class PreguntasRepository {
  static Future<List<Pregunta>> cargarPreguntas() async {
    final permiso = await PermisoRepository.getPermiso();
    final asset = permiso == 'A'
        ? 'assets/preguntas_A.json'
        : 'assets/preguntas.json';
    final String data = await rootBundle.loadString(asset);
    final List<dynamic> jsonList = json.decode(data) as List;
    return jsonList
        .map((e) => Pregunta.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
