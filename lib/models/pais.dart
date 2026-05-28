class ExamenConfig {
  final int numPreguntas;
  final int tiempoMinutos;
  final double porcentajeCorte;

  const ExamenConfig({
    required this.numPreguntas,
    required this.tiempoMinutos,
    required this.porcentajeCorte,
  });
}

class Pais {
  final String codigo;
  final String nombre;
  final String bandera;
  final List<String> permisos;
  final ExamenConfig examen;
  final bool disponible;

  const Pais({
    required this.codigo,
    required this.nombre,
    required this.bandera,
    required this.permisos,
    required this.examen,
    required this.disponible,
  });
}

const kPaises = [
  Pais(
    codigo: 'ES',
    nombre: 'España',
    bandera: '🇪🇸',
    permisos: ['B', 'A', 'C'],
    examen: ExamenConfig(numPreguntas: 30, tiempoMinutos: 30, porcentajeCorte: 0.9),
    disponible: true,
  ),
  Pais(
    codigo: 'IT',
    nombre: 'Italia',
    bandera: '🇮🇹',
    permisos: ['B'],
    examen: ExamenConfig(numPreguntas: 40, tiempoMinutos: 30, porcentajeCorte: 0.9),
    disponible: true,
  ),
  Pais(
    codigo: 'FR',
    nombre: 'France',
    bandera: '🇫🇷',
    permisos: ['B'],
    examen: ExamenConfig(numPreguntas: 40, tiempoMinutos: 40, porcentajeCorte: 0.875),
    disponible: false,
  ),
  Pais(
    codigo: 'DE',
    nombre: 'Deutschland',
    bandera: '🇩🇪',
    permisos: ['B'],
    examen: ExamenConfig(numPreguntas: 30, tiempoMinutos: 45, porcentajeCorte: 0.9),
    disponible: false,
  ),
  Pais(
    codigo: 'GB',
    nombre: 'United Kingdom',
    bandera: '🇬🇧',
    permisos: ['B'],
    examen: ExamenConfig(numPreguntas: 50, tiempoMinutos: 57, porcentajeCorte: 0.86),
    disponible: false,
  ),
  Pais(
    codigo: 'MX',
    nombre: 'México',
    bandera: '🇲🇽',
    permisos: ['B'],
    examen: ExamenConfig(numPreguntas: 30, tiempoMinutos: 30, porcentajeCorte: 0.7),
    disponible: false,
  ),
];

Pais paisPorCodigo(String codigo) =>
    kPaises.firstWhere((p) => p.codigo == codigo, orElse: () => kPaises.first);
