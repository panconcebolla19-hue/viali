import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pregunta.dart';

class PreguntasRepository {
  static Future<List<Pregunta>> cargarPreguntas() async {
    final String data = await rootBundle.loadString('assets/preguntas.json');
    final List<dynamic> jsonList = json.decode(data) as List;
    return jsonList
        .map((e) => Pregunta.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
