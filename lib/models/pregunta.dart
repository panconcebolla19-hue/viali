class Pregunta {
  final int id;
  final String enunciado;
  final List<String> opciones;
  final int respuestaCorrecta;
  final String explicacion;
  final String? imagen;
  final bool imagenOculta;

  const Pregunta({
    required this.id,
    required this.enunciado,
    required this.opciones,
    required this.respuestaCorrecta,
    required this.explicacion,
    this.imagen,
    this.imagenOculta = false,
  });

  factory Pregunta.fromJson(Map<String, dynamic> json) {
    return Pregunta(
      id: json['id'] as int,
      enunciado: json['enunciado'] as String,
      opciones: List<String>.from(json['opciones'] as List),
      respuestaCorrecta: json['respuesta_correcta'] as int,
      explicacion: json['explicacion'] as String,
      imagen: json['imagen'] as String?,
      imagenOculta: json['imagen_oculta'] == true,
    );
  }
}
