import 'package:flutter/material.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/falladas_repository.dart';
import '../data/test_historial_repository.dart';
import '../models/test_resultado.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);
const _kGreen = Color(0xFF2ECC40);
const _kRed = Color(0xFFFF3B30);

const _temas = [
  ('Señales', 'señales'),
  ('Velocidad', 'velocidad'),
  ('Alcohol/Drogas', 'alcohol'),
  ('Adelantamientos', 'adelantamientos'),
  ('Distancias', 'distancias'),
  ('Autopistas', 'autopista'),
  ('Medio ambiente', 'medio_ambiente'),
  ('Documentación', 'documentacion'),
  ('Otras', 'otro'),
];

String _detectarTema(Pregunta p) {
  final t = p.enunciado.toLowerCase();
  if (t.contains('señal') || t.contains('prohibi') || t.contains('advertenc') ||
      t.contains('stop') || t.contains('ceda') || t.contains('indicaci')) {
    return 'señales';
  }
  if (t.contains('velocidad') || t.contains('km/h') || t.contains('límite') ||
      t.contains('limite')) {
    return 'velocidad';
  }
  if (t.contains('alcohol') || t.contains('tasa') || t.contains('droga') ||
      t.contains('estupef')) {
    return 'alcohol';
  }
  if (t.contains('adelant') || t.contains('rebasar')) { return 'adelantamientos'; }
  if (t.contains('distancia') || t.contains('separaci') || t.contains('intervalo')) {
    return 'distancias';
  }
  if (t.contains('autopista') || t.contains('autovía') || t.contains('autovia') ||
      t.contains('vía rápida')) {
    return 'autopista';
  }
  if (t.contains('medio ambi') || t.contains('contaminac') || t.contains('emisione') ||
      t.contains('neumátic') || t.contains('neumatic')) {
    return 'medio_ambiente';
  }
  if (t.contains('documentac') || t.contains('carnet') || t.contains('permiso') ||
      t.contains('itv') || t.contains(' seguro')) {
    return 'documentacion';
  }
  return 'otro';
}

class _ProgresoData {
  final List<TestResultado> historial;
  final Map<String, int> totalPorTema;
  final Map<String, int> falladasPorTema;

  const _ProgresoData({
    required this.historial,
    required this.totalPorTema,
    required this.falladasPorTema,
  });
}

class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  bool _cargando = true;
  _ProgresoData? _datos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final preguntas = await PreguntasRepository.cargarPreguntas();
    final historial = await TestHistorialRepository.cargar();
    final falladasRacha = await FalladasRepository.cargar();
    final falladasHistorial = await TestHistorialRepository.idsPreguntasFalladas();
    final todasFalladas = {...falladasRacha, ...falladasHistorial};

    final totalPorTema = <String, int>{};
    final falladasPorTema = <String, int>{};

    for (final p in preguntas) {
      final tema = _detectarTema(p);
      totalPorTema[tema] = (totalPorTema[tema] ?? 0) + 1;
      if (todasFalladas.contains(p.id)) {
        falladasPorTema[tema] = (falladasPorTema[tema] ?? 0) + 1;
      }
    }

    setState(() {
      _datos = _ProgresoData(
        historial: historial,
        totalPorTema: totalPorTema,
        falladasPorTema: falladasPorTema,
      );
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mi Progreso')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _datos!;
    final testsTotales = d.historial.length;
    final totalRespondidas = d.historial.fold(0, (s, r) => s + r.totalPreguntas);
    final totalCorrectas = d.historial.fold(0, (s, r) => s + r.correctas);
    final mediaAciertos =
        totalRespondidas > 0 ? totalCorrectas / totalRespondidas : 0.0;

    final sinDatos = testsTotales == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ── Resumen global ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE0A0), width: 1.5),
          ),
          child: Row(
            children: [
              Image.asset('assets/semaforo_normal.png', height: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$testsTotales ${testsTotales == 1 ? 'test' : 'tests'} realizados',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalRespondidas preguntas respondidas',
                      style: const TextStyle(fontSize: 13, color: _kGrey),
                    ),
                    if (!sinDatos) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Media de aciertos: ${(mediaAciertos * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: mediaAciertos >= 0.9 ? _kGreen : _kYellow,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Progreso por temas ──────────────────────────────────────────────
        const Text(
          'Progreso por temática',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sinDatos
              ? 'Empieza a practicar para ver tus estadísticas por tema.'
              : 'Basado en preguntas falladas alguna vez.',
          style: const TextStyle(fontSize: 13, color: _kGrey),
        ),
        const SizedBox(height: 16),

        if (sinDatos)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Image.asset('assets/semaforo_normal.png', height: 100),
                  const SizedBox(height: 20),
                  const Text(
                    'Sin datos todavía',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Haz algún test para ver tu progreso por temas.',
                    style: TextStyle(fontSize: 14, color: _kGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._temas.map((tema) {
            final label = tema.$1;
            final key = tema.$2;
            final total = d.totalPorTema[key] ?? 0;
            final falladas = d.falladasPorTema[key] ?? 0;
            if (total == 0) return const SizedBox.shrink();
            return _TemaBar(
              label: label,
              total: total,
              falladas: falladas,
            );
          }),
      ],
    );
  }
}

// ── Barra por tema ─────────────────────────────────────────────────────────────

class _TemaBar extends StatelessWidget {
  final String label;
  final int total;
  final int falladas;

  const _TemaBar({
    required this.label,
    required this.total,
    required this.falladas,
  });

  double get _ratio => total == 0 ? 0 : (total - falladas) / total;

  Color get _color {
    if (_ratio >= 0.7) return _kGreen;
    if (_ratio >= 0.4) return _kYellow;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_ratio * 100).round();
    final sinErrores = total - falladas;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
              ),
              Text(
                '$sinErrores/$total sin errores · $pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: _kBorder,
                ),
                FractionallySizedBox(
                  widthFactor: _ratio.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
