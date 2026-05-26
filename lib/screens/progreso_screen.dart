import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/test_historial_repository.dart';
import '../models/test_resultado.dart';
import '../data/anki_repository.dart';
import '../data/daily_streak_repository.dart';
import '../utils/tema_utils.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFE53935);

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

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _ProgresoData {
  final List<TestResultado> historial;
  final Map<String, int> respondadasPorTema;
  final Map<String, int> sinErroresPorTema;
  final int streak;
  final int maxStreak;
  final List<int> actividad7dias;
  final List<(Pregunta, int)> topFalladas;
  final List<Pregunta> dominadas;

  const _ProgresoData({
    required this.historial,
    required this.respondadasPorTema,
    required this.sinErroresPorTema,
    required this.streak,
    required this.maxStreak,
    required this.actividad7dias,
    required this.topFalladas,
    required this.dominadas,
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
    final results = await Future.wait([
      PreguntasRepository.cargarPreguntas(),
      TestHistorialRepository.cargar(),
      AnkiRepository.cargar(),
      AnkiRepository.cargarActividad(),
      DailyStreakRepository.cargar(),
    ]);

    final preguntas = results[0] as List<Pregunta>;
    final historial = results[1] as List<TestResultado>;
    final ankiMapa = results[2] as Map<int, AnkiEntry>;
    final actividadMapa = results[3] as Map<String, int>;
    final streakData = results[4] as ({int streak, int maxStreak});

    final preguntasMapa = {for (final p in preguntas) p.id: p};

    final respondadasPorTema = <String, int>{};
    final sinErroresPorTema = <String, int>{};
    for (final entry in ankiMapa.entries) {
      if (entry.value.vistas == 0) continue;
      final p = preguntasMapa[entry.key];
      if (p == null) continue;
      final tema = detectarTema(p);
      respondadasPorTema[tema] = (respondadasPorTema[tema] ?? 0) + 1;
      if (entry.value.totalFalladas == 0) {
        sinErroresPorTema[tema] = (sinErroresPorTema[tema] ?? 0) + 1;
      }
    }

    final falladasConConteo = ankiMapa.entries
        .where((e) => e.value.totalFalladas > 0 && preguntasMapa.containsKey(e.key))
        .map((e) => (preguntasMapa[e.key]!, e.value.totalFalladas))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final topFalladas = falladasConConteo.take(10).toList();

    final dominadas = ankiMapa.entries
        .where((e) => e.value.acertadasSeguidas >= 3 && preguntasMapa.containsKey(e.key))
        .map((e) => preguntasMapa[e.key]!)
        .toList();

    final hoy = DateTime.now();
    final actividad7dias = List.generate(7, (i) {
      final dia = hoy.subtract(Duration(days: 6 - i));
      return actividadMapa[_isoDate(dia)] ?? 0;
    });

    if (mounted) {
      setState(() {
        _datos = _ProgresoData(
          historial: historial,
          respondadasPorTema: respondadasPorTema,
          sinErroresPorTema: sinErroresPorTema,
          streak: streakData.streak,
          maxStreak: streakData.maxStreak,
          actividad7dias: actividad7dias,
          topFalladas: topFalladas,
          dominadas: dominadas,
        );
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mi Progreso',
          style: TextStyle(
              color: _kDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _datos!;
    final testsTotales = d.historial.length;
    final totalRespondidas =
        d.historial.fold(0, (s, r) => s + r.totalPreguntas);
    final totalCorrectas = d.historial.fold(0, (s, r) => s + r.correctas);
    final mediaAciertos =
        totalRespondidas > 0 ? totalCorrectas / totalRespondidas : 0.0;
    final sinDatosTema = d.respondadasPorTema.isEmpty;

    // ── Preparación estimada ──────────────────────────────────────────────
    final totalUnicasRespondidas =
        d.respondadasPorTema.values.fold(0, (a, b) => a + b);
    final dominadasPct =
        totalUnicasRespondidas > 0 ? d.dominadas.length / totalUnicasRespondidas : 0.0;
    final streakPct = (d.streak / 30.0).clamp(0.0, 1.0);
    final readiness =
        ((mediaAciertos * 0.5) + (dominadasPct * 0.3) + (streakPct * 0.2))
            .clamp(0.0, 1.0);

    String? peorTema;
    if (d.respondadasPorTema.isNotEmpty) {
      final sorted = d.respondadasPorTema.entries
          .map((e) {
            final sinErrores = d.sinErroresPorTema[e.key] ?? 0;
            return (key: e.key, pct: sinErrores / e.value);
          })
          .toList()
        ..sort((a, b) => a.pct.compareTo(b.pct));
      if (sorted.isNotEmpty) {
        final peorKey = sorted.first.key;
        peorTema = _temas
                .firstWhere((t) => t.$2 == peorKey,
                    orElse: () => (peorKey, peorKey))
                .$1;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // ── Preparación estimada ────────────────────────────────────────────
        _PreparacionCard(
          readiness: readiness,
          totalRespondidas: totalRespondidas,
          peorTema: peorTema,
        ),
        const SizedBox(height: 20),
        // ── Racha ──────────────────────────────────────────────────────────
        _RachaCard(streak: d.streak, maxStreak: d.maxStreak),
        const SizedBox(height: 20),

        // ── Actividad 7 días ────────────────────────────────────────────────
        _SeccionTitulo('Actividad últimos 7 días'),
        const SizedBox(height: 12),
        _ActividadChart(valores: d.actividad7dias),
        const SizedBox(height: 24),

        // ── Resumen global ──────────────────────────────────────────────────
        _SeccionTitulo('Resumen general'),
        const SizedBox(height: 12),
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
                      testsTotales == 0
                          ? 'Aún no has hecho ningún test'
                          : '$testsTotales ${testsTotales == 1 ? 'test' : 'tests'} realizados',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalRespondidas preguntas respondidas',
                      style: const TextStyle(fontSize: 13, color: _kGrey),
                    ),
                    if (totalRespondidas > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Media de aciertos: ${(mediaAciertos * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              mediaAciertos >= 0.9 ? _kGreen : _kYellow,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Top falladas ────────────────────────────────────────────────────
        if (d.topFalladas.isNotEmpty) ...[
          _SeccionTitulo('Tus 10 preguntas más falladas'),
          const SizedBox(height: 4),
          const Text(
            'Pulsa para practicarlas',
            style: TextStyle(fontSize: 13, color: _kGrey),
          ),
          const SizedBox(height: 12),
          ...d.topFalladas.map(
            (item) => _FalladaTile(
              pregunta: item.$1,
              veces: item.$2,
              onTap: () => _abrirModal(item.$1),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Dominadas ───────────────────────────────────────────────────────
        if (d.dominadas.isNotEmpty) ...[
          _SeccionTitulo('Preguntas que dominas'),
          const SizedBox(height: 4),
          Text(
            '${d.dominadas.length} ${d.dominadas.length == 1 ? 'pregunta dominada' : 'preguntas dominadas'} (3+ aciertos seguidos)',
            style: const TextStyle(fontSize: 13, color: _kGrey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: d.dominadas
                .take(20)
                .map((p) => _DominadaChip(
                      pregunta: p,
                      onTap: () => _abrirModal(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
        ],

        // ── Progreso por temas ──────────────────────────────────────────────
        _SeccionTitulo('Progreso por temática'),
        const SizedBox(height: 4),
        Text(
          sinDatosTema
              ? 'Empieza a practicar para ver tus estadísticas por tema.'
              : 'Solo incluye preguntas que has respondido.',
          style: const TextStyle(fontSize: 13, color: _kGrey),
        ),
        const SizedBox(height: 16),
        if (sinDatosTema)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Image.asset('assets/semaforo_normal.png', height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Sin datos todavía',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kDark),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Practica para ver tu progreso por temas.',
                    style: TextStyle(fontSize: 14, color: _kGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._temas.map((tema) {
            final respondidas = d.respondadasPorTema[tema.$2] ?? 0;
            final sinErrores = d.sinErroresPorTema[tema.$2] ?? 0;
            if (respondidas == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tema.$1,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kDark),
                      ),
                    ),
                    const Text(
                      'Sin datos aún',
                      style: TextStyle(fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              );
            }
            return _TemaBar(
                label: tema.$1, respondidas: respondidas, sinErrores: sinErrores);
          }),
      ],
    );
  }

  void _abrirModal(Pregunta p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreguntaModal(pregunta: p),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SeccionTitulo extends StatelessWidget {
  final String texto;
  const _SeccionTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w900, color: _kDark),
    );
  }
}

// ── Racha card ────────────────────────────────────────────────────────────────

class _RachaCard extends StatelessWidget {
  final int streak;
  final int maxStreak;

  const _RachaCard({required this.streak, required this.maxStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFFBF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE0A0), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Racha actual',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kGrey,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 6),
                    Text(
                      '$streak',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: _kDark,
                          height: 1),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'días',
                        style: TextStyle(
                            fontSize: 16,
                            color: _kGrey,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 56,
            color: const Color(0xFFFFE0A0),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mejor racha',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kGrey,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(
                      '$maxStreak',
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: _kDark,
                          height: 1),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        'días',
                        style: TextStyle(
                            fontSize: 14,
                            color: _kGrey,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actividad chart ───────────────────────────────────────────────────────────

class _ActividadChart extends StatelessWidget {
  final List<int> valores;

  const _ActividadChart({required this.valores});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final labels = List.generate(
      7,
      (i) {
        final d = hoy.subtract(Duration(days: 6 - i));
        const dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
        return dias[d.weekday - 1];
      },
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.2),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: _BarChartPainter(
                valores: valores,
                color: _kYellow,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: labels.asMap().entries.map((e) {
              final isHoy = e.key == 6;
              return Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isHoy ? FontWeight.w800 : FontWeight.w500,
                  color: isHoy ? _kYellow : _kGrey,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> valores;
  final Color color;

  const _BarChartPainter({required this.valores, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    final maxVal = valores.fold(0, math.max);
    if (maxVal == 0) {
      _drawEmpty(canvas, size);
      return;
    }

    final barWidth = size.width / (valores.length * 2 - 1);
    final paint = Paint()..color = color;
    final paintFade = Paint()..color = color.withValues(alpha: 0.25);

    for (int i = 0; i < valores.length; i++) {
      final x = i * barWidth * 2;
      final ratio = valores[i] / maxVal;
      final barHeight = ratio * (size.height - 8);
      final top = size.height - barHeight;

      final isHoy = i == valores.length - 1;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, isHoy ? paint : paintFade);
    }
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEEEEEE);
    for (int i = 0; i < valores.length; i++) {
      final barWidth = size.width / (valores.length * 2 - 1);
      final x = i * barWidth * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 12, barWidth, 12),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.valores != valores;
}

// ── Fallada tile ──────────────────────────────────────────────────────────────

class _FalladaTile extends StatelessWidget {
  final Pregunta pregunta;
  final int veces;
  final VoidCallback onTap;

  const _FalladaTile(
      {required this.pregunta, required this.veces, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1.4),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '×$veces',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pregunta.enunciado,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kDark,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: _kGrey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dominada chip ─────────────────────────────────────────────────────────────

class _DominadaChip extends StatelessWidget {
  final Pregunta pregunta;
  final VoidCallback onTap;

  const _DominadaChip({required this.pregunta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kGreen.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 14),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                pregunta.enunciado,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pregunta modal ────────────────────────────────────────────────────────────

class _PreguntaModal extends StatefulWidget {
  final Pregunta pregunta;
  const _PreguntaModal({required this.pregunta});

  @override
  State<_PreguntaModal> createState() => _PreguntaModalState();
}

class _PreguntaModalState extends State<_PreguntaModal> {
  int? _seleccion;
  bool _revelado = false;

  void _seleccionar(int idx) {
    if (_revelado) return;
    setState(() {
      _seleccion = idx;
      _revelado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pregunta;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.imagen != null && !p.imagenOculta) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/${p.imagen}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      p.enunciado,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(p.opciones.length, (i) {
                      final esCorrecta = i == p.respuestaCorrecta;
                      final esSeleccion = i == _seleccion;
                      Color bgColor = Colors.white;
                      Color borderColor = _kBorder;
                      Color textColor = _kDark;
                      IconData? trailingIcon;

                      if (_revelado) {
                        if (esCorrecta) {
                          bgColor = _kGreen.withValues(alpha: 0.10);
                          borderColor = _kGreen;
                          textColor = _kGreen;
                          trailingIcon = Icons.check_circle_rounded;
                        } else if (esSeleccion) {
                          bgColor = _kRed.withValues(alpha: 0.08);
                          borderColor = _kRed;
                          textColor = _kRed;
                          trailingIcon = Icons.cancel_rounded;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _seleccionar(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: borderColor, width: 1.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _revelado && esCorrecta
                                        ? _kGreen
                                        : _revelado && esSeleccion
                                            ? _kRed
                                            : const Color(0xFFEEEEEE),
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + i),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _revelado &&
                                              (esCorrecta || esSeleccion)
                                          ? Colors.white
                                          : _kGrey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.opciones[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (trailingIcon != null)
                                  Icon(trailingIcon,
                                      color: esCorrecta ? _kGreen : _kRed,
                                      size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_revelado) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: _kGrey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.explicacion,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: _kGrey,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _seleccion = null;
                            _revelado = false;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: _kYellow,
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          child: const Text('Intentar de nuevo'),
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'Selecciona una opción para ver la respuesta',
                            style: TextStyle(fontSize: 12, color: _kGrey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preparación estimada ──────────────────────────────────────────────────────

class _PreparacionCard extends StatelessWidget {
  final double readiness;
  final int totalRespondidas;
  final String? peorTema;

  const _PreparacionCard({
    required this.readiness,
    required this.totalRespondidas,
    this.peorTema,
  });

  Color get _color {
    if (readiness >= 0.8) return _kGreen;
    if (readiness >= 0.6) return _kYellow;
    if (readiness >= 0.4) return const Color(0xFFFF9800);
    return _kRed;
  }

  String get _mensaje {
    if (totalRespondidas == 0) {
      return 'Haz tu primer test para ver tu preparación.';
    }
    if (readiness >= 0.8) return '¡Estás listo! Sigue manteniendo el nivel.';
    if (readiness >= 0.6) {
      return peorTema != null
          ? 'Buen ritmo — mejora $peorTema.'
          : 'Buen ritmo, sigue así.';
    }
    if (readiness >= 0.4) {
      return peorTema != null
          ? 'En progreso — enfócate en $peorTema.'
          : 'Sigue practicando cada día.';
    }
    return 'Empieza fuerte — practica más cada día.';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (readiness * 100).round();
    final color = _color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: readiness.clamp(0.0, 1.0),
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preparación estimada',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _mensaje,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    height: 1.4,
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

// ── Barra por tema ────────────────────────────────────────────────────────────

class _TemaBar extends StatelessWidget {
  final String label;
  final int respondidas;
  final int sinErrores;

  const _TemaBar(
      {required this.label, required this.respondidas, required this.sinErrores});

  double get _ratio => respondidas == 0 ? 0 : sinErrores / respondidas;

  Color get _color {
    if (_ratio >= 0.7) return _kGreen;
    if (_ratio >= 0.4) return _kYellow;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_ratio * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kDark)),
              ),
              Text(
                '$sinErrores/$respondidas sin errores · $pct%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 10, color: _kBorder),
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
