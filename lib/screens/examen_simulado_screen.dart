import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/pregunta.dart';
import '../models/test_resultado.dart';
import '../data/preguntas_repository.dart';
import '../data/test_historial_repository.dart';
import '../data/falladas_repository.dart';
import '../data/daily_streak_repository.dart';
import '../data/logros_repository.dart';
import '../services/notification_service.dart';
import '../widgets/confetti_overlay.dart';
import 'logros_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kAmber = Color(0xFFFF9800);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class ExamenSimuladoScreen extends StatefulWidget {
  const ExamenSimuladoScreen({super.key});

  @override
  State<ExamenSimuladoScreen> createState() => _ExamenSimuladoScreenState();
}

class _ExamenSimuladoScreenState extends State<ExamenSimuladoScreen>
    with SingleTickerProviderStateMixin {
  bool _cargando = true;

  List<Pregunta> _preguntas = [];
  List<List<int>> _mapas = [];
  List<List<String>> _mezcladas = [];
  List<int?> _respuestas = [];
  int _indice = 0;

  Timer? _timer;
  int _segundosRestantes = 45 * 60;
  bool _tiempoAgotado = false;

  bool _enResultados = false;
  TestResultado? _resultado;

  late final AnimationController _confettiCtrl;
  List<ConfettiParticle> _confettiParticles = [];

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
        duration: const Duration(milliseconds: 3200), vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final todas = await PreguntasRepository.cargarPreguntas();
    final pool = List<Pregunta>.from(todas)..shuffle(Random());
    final seleccionadas = pool.take(30).toList();

    final mapas = <List<int>>[];
    final mezcladas = <List<String>>[];
    for (final p in seleccionadas) {
      final m = [0, 1, 2]..shuffle(Random());
      mapas.add(m);
      mezcladas.add(m.map((i) => p.opciones[i]).toList());
    }

    setState(() {
      _preguntas = seleccionadas;
      _mapas = mapas;
      _mezcladas = mezcladas;
      _respuestas = List.filled(30, null);
      _cargando = false;
    });
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosRestantes <= 1) {
        _timer?.cancel();
        _timer = null;
        setState(() {
          _segundosRestantes = 0;
          _tiempoAgotado = true;
        });
        _finalizar();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  String _formatTiempo(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color get _colorTimer {
    if (_segundosRestantes > 600) return _kTextDark;
    if (_segundosRestantes > 300) return _kAmber;
    return _kRed;
  }

  void _seleccionar(int opcionDisplay) {
    if (_enResultados) return;
    setState(() => _respuestas[_indice] = opcionDisplay);
  }

  int get _respondidas => _respuestas.where((r) => r != null).length;

  Future<void> _finalizar() async {
    _timer?.cancel();
    _timer = null;

    int correctas = 0;
    final falladas = <int>[];
    for (int i = 0; i < _preguntas.length; i++) {
      final sel = _respuestas[i];
      if (sel != null &&
          _mapas[i][sel] == _preguntas[i].respuestaCorrecta) {
        correctas++;
      } else {
        falladas.add(_preguntas[i].id);
      }
    }

    final streakResult = await DailyStreakRepository.registrarEstudio();
    if (streakResult.streak >= 1) {
      unawaited(NotificationService.scheduleStreakWarning(streakResult.streak));
    }

    final r = TestResultado(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      modo: 'Examen Simulado',
      totalPreguntas: _preguntas.length,
      correctas: correctas,
      preguntasFalladas: falladas,
    );
    await TestHistorialRepository.guardar(r);
    await FalladasRepository.agregar(falladas);
    await LogrosRepository.incrementarPreguntas(_preguntas.length);
    final nuevosLogros = await LogrosRepository.checkAndUpdate();

    setState(() {
      _resultado = r;
      _enResultados = true;
    });

    if (r.aprobado) {
      _confettiParticles = generateConfettiParticles(count: 72);
      _confettiCtrl.forward(from: 0);
    }

    if (nuevosLogros.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        for (final logro in nuevosLogros) {
          if (!mounted) break;
          await mostrarLogroPopup(context, logro);
        }
      });
    }
  }

  Future<void> _confirmarFinalizar() async {
    final noRespondidas = _respuestas.where((r) => r == null).length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Finalizar examen?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          noRespondidas > 0
              ? 'Tienes $noRespondidas ${noRespondidas == 1 ? "pregunta sin responder" : "preguntas sin responder"}. Cada una sin responder cuenta como fallo.'
              : '¿Finalizas el examen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Seguir', style: TextStyle(color: _kTextGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar',
                style: TextStyle(
                    color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar == true) _finalizar();
  }

  Future<void> _confirmarAbandonar() async {
    final abandonar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Abandonar examen?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se perderá todo el progreso del examen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Continuar', style: TextStyle(color: _kTextGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonar',
                style: TextStyle(
                    color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (abandonar == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }
    if (_enResultados) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildResultados(),
          ConfettiOverlay(
            controller: _confettiCtrl,
            particles: _confettiParticles,
          ),
        ],
      );
    }
    return _buildExamen();
  }

  Widget _buildExamen() {
    final p = _preguntas[_indice];
    final seleccionada = _respuestas[_indice];
    final total = _preguntas.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _kTextDark, size: 24),
          onPressed: _confirmarAbandonar,
        ),
        title: Text(
          '${_indice + 1} / $total',
          style: const TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _formatTiempo(_segundosRestantes),
                style: TextStyle(
                  color: _colorTimer,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_indice + 1) / total,
                backgroundColor: const Color(0xFFEEEEEE),
                color: _kYellow,
                minHeight: 4,
              ),
              LinearProgressIndicator(
                value: _segundosRestantes / (45 * 60),
                backgroundColor: const Color(0xFFEEEEEE),
                color: _colorTimer,
                minHeight: 4,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Text(
                  '$_respondidas de $total respondidas',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _confirmarFinalizar,
                  style: TextButton.styleFrom(
                    foregroundColor: _kRed,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Finalizar examen',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _kBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (p.imagen != null && !p.imagenOculta) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SvgPicture.asset(
                              p.imagen!,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          p.enunciado,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OpcionExamen(
                          letra: String.fromCharCode(65 + i),
                          texto: _mezcladas[_indice][i],
                          selected: seleccionada == i,
                          onTap: () => _seleccionar(i),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                if (_indice > 0)
                  Expanded(
                    child: _NavButton(
                      label: 'Anterior',
                      icon: Icons.arrow_back_rounded,
                      isPrimary: false,
                      onTap: () => setState(() => _indice--),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 12),
                if (_indice < total - 1)
                  Expanded(
                    child: _NavButton(
                      label: 'Siguiente',
                      icon: Icons.arrow_forward_rounded,
                      isPrimary: true,
                      onTap: () => setState(() => _indice++),
                    ),
                  )
                else
                  Expanded(
                    child: _NavButton(
                      label: 'Ver resultado',
                      icon: Icons.bar_chart_rounded,
                      isPrimary: true,
                      onTap: _confirmarFinalizar,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final r = _resultado!;
    final apto = r.aprobado;
    final mainColor = apto ? _kGreen : _kRed;
    final pct = (r.porcentaje * 100).round();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Resultado del examen',
          style: TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tiempoAgotado) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kAmber.withValues(alpha: 0.35), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_off_rounded,
                        color: _kAmber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tiempo agotado — el examen finalizó automáticamente',
                        style: TextStyle(
                          color: _kAmber,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: apto
                    ? const Color(0xFFF1FBF1)
                    : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: mainColor.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                children: [
                  Image.asset(
                    apto
                        ? 'assets/semaforo_verde.png'
                        : 'assets/semaforo_rojo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${r.correctas}',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: mainColor,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: '/${r.totalPreguntas}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: mainColor.withValues(alpha: 0.6),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      color: mainColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      apto ? 'APTO · $pct%' : 'NO APTO · $pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    apto
                        ? '¡Enhorabuena! Estás listo para el examen real. 🎉'
                        : r.correctas >= 25
                            ? '¡Muy cerca! Un poco más de práctica y lo consigues.'
                            : 'Necesitas ${27 - r.correctas} ${27 - r.correctas == 1 ? "acierto más" : "aciertos más"} para aprobar. ¡Sigue practicando!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _kTextGrey, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Revisión completa',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark),
            ),
            const SizedBox(height: 12),
            ...List.generate(_preguntas.length, (i) {
              final sel = _respuestas[i];
              final ok = sel != null &&
                  _mapas[i][sel] == _preguntas[i].respuestaCorrecta;
              final noRespondida = sel == null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RevisionCard(
                  numero: i + 1,
                  pregunta: _preguntas[i],
                  esCorrecta: ok,
                  noRespondida: noRespondida,
                  respuestaCorrecta: _preguntas[i]
                      .opciones[_preguntas[i].respuestaCorrecta],
                ),
              );
            }),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _kYellow,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _kYellow.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(22),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Volver al inicio',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.home_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option during exam (amber highlight, no correct/wrong feedback) ────────────

class _OpcionExamen extends StatelessWidget {
  final String letra;
  final String texto;
  final bool selected;
  final VoidCallback onTap;

  const _OpcionExamen({
    required this.letra,
    required this.texto,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFF3E0) : Colors.white;
    final borderColor = selected ? _kYellow : _kBorder;
    final letraBg = selected
        ? _kYellow.withValues(alpha: 0.2)
        : const Color(0xFFF5F5F5);
    final letraColor = selected ? _kYellow : _kTextGrey;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: borderColor, width: selected ? 2.0 : 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: letraBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      letra,
                      style: TextStyle(
                        color: letraColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, color: _kYellow, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Prev/Next navigation button ───────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPrimary ? _kYellow : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isPrimary ? null : Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? _kYellow.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isPrimary ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPrimary) ...[
                  Icon(icon, color: _kTextDark, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : _kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (isPrimary) ...[
                  const SizedBox(width: 6),
                  Icon(icon, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Review card shown in results ──────────────────────────────────────────────

class _RevisionCard extends StatelessWidget {
  final int numero;
  final Pregunta pregunta;
  final bool esCorrecta;
  final bool noRespondida;
  final String respuestaCorrecta;

  const _RevisionCard({
    required this.numero,
    required this.pregunta,
    required this.esCorrecta,
    required this.noRespondida,
    required this.respuestaCorrecta,
  });

  @override
  Widget build(BuildContext context) {
    final color = esCorrecta ? _kGreen : _kRed;
    final bgColor = esCorrecta
        ? const Color(0xFFF1FBF1)
        : const Color(0xFFFFF0F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              esCorrecta ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero. ${pregunta.enunciado}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextDark,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!esCorrecta) ...[
                  const SizedBox(height: 6),
                  Text(
                    noRespondida
                        ? 'Sin responder'
                        : 'Respuesta incorrecta',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Correcta: $respuestaCorrecta',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kGreen,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (pregunta.explicacion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pregunta.explicacion,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
