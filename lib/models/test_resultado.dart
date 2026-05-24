class TestResultado {
  final String id;
  final DateTime fecha;
  final String modo;
  final int totalPreguntas;
  final int correctas;
  final List<int> preguntasFalladas;

  const TestResultado({
    required this.id,
    required this.fecha,
    required this.modo,
    required this.totalPreguntas,
    required this.correctas,
    required this.preguntasFalladas,
  });

  double get porcentaje =>
      totalPreguntas > 0 ? correctas / totalPreguntas : 0;

  bool get aprobado => porcentaje >= 0.9; // DGT: máximo 3 fallos en 30

  Map<String, dynamic> toJson() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'modo': modo,
        'totalPreguntas': totalPreguntas,
        'correctas': correctas,
        'preguntasFalladas': preguntasFalladas,
      };

  factory TestResultado.fromJson(Map<String, dynamic> json) => TestResultado(
        id: json['id'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        modo: json['modo'] as String,
        totalPreguntas: json['totalPreguntas'] as int,
        correctas: json['correctas'] as int,
        preguntasFalladas:
            (json['preguntasFalladas'] as List).cast<int>(),
      );
}
