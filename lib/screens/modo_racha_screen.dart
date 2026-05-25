import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/falladas_repository.dart';
import '../data/daily_streak_repository.dart';
import '../services/notification_service.dart';
import '../widgets/confetti_overlay.dart';

const _kYellow = Color(0xFFF5A623);
const _kGold = Color(0xFFFFD600);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

enum _EstadoMascota { normal, correcto, fallo }

enum _EstadoOpcion { normal, correcta, incorrecta, neutra }

class ModoRachaScreen extends StatefulWidget {
  const ModoRachaScreen({super.key});

  @override
  State<ModoRachaScreen> createState() => _ModoRachaScreenState();
}

class _ModoRachaScreenState extends State<ModoRachaScreen>
    with TickerProviderStateMixin {
  // ── Data ────────────────────────────────────────────────────────────────────
  List<Pregunta> _preguntas = [];
  List<int> _indicesPendientes = [];
  Pregunta? _preguntaActual;
  List<String> _opcionesMezcladas = [];
  List<int> _mapaIndices = [];
  int _rachaActual = 0;
  int _recordPersonal = 0;
  int? _respuestaSeleccionada;
  bool _respondida = false;
  bool _cargando = true;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;

  // ── Tension / record state ───────────────────────────────────────────────────
  bool _isNewRecord = false;
  bool _showRecordBanner = false;
  List<ConfettiParticle> _confettiParticles = [];
  bool _estudiadoHoy = false;

  // ── Animation controllers ────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;   // loops: counter pulse
  late AnimationController _borderCtrl; // loops: question card border
  late AnimationController _vibrateCtrl;// loops: 20+ counter tremor
  late AnimationController _boingCtrl;  // one-shot: counter boing on correct
  late AnimationController _flashCtrl;  // one-shot: green screen flash
  late AnimationController _shakeCtrl;  // one-shot: screen shake on wrong
  late AnimationController _recordCtrl; // one-shot: record banner + confetti

  late Animation<double> _pulseAnim;
  late Animation<double> _borderAnim;
  late Animation<double> _vibrateAnim;
  late Animation<double> _boingAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _recordSlideAnim;
  late Animation<double> _recordFadeAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _init();
  }

  void _setupAnimations() {
    // Pulse (looping, speed changes with racha level)
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Border shimmer (always looping, only drawn at tension ≥ 3)
    _borderCtrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _borderAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _borderCtrl, curve: Curves.easeInOut));

    // Vibration for 20+
    _vibrateCtrl = AnimationController(
        duration: const Duration(milliseconds: 80), vsync: this);
    _vibrateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_vibrateCtrl);

    // Boing on correct answer (1.0 → 1.3 → 0.92 → 1.0)
    _boingCtrl = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _boingAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.92), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _boingCtrl, curve: Curves.easeOut));

    // Green flash overlay
    _flashCtrl = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    _flashAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 75),
    ]).animate(_flashCtrl);

    // Screen shake
    _shakeCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim =
        Tween<double>(begin: 0.0, end: 1.0).animate(_shakeCtrl);

    // Record banner + confetti
    _recordCtrl = AnimationController(
        duration: const Duration(milliseconds: 2800), vsync: this);
    _recordSlideAnim = Tween<double>(begin: -72.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _recordCtrl,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack),
      ),
    );
    _recordFadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_recordCtrl);
    _recordCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showRecordBanner = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _borderCtrl.dispose();
    _vibrateCtrl.dispose();
    _boingCtrl.dispose();
    _flashCtrl.dispose();
    _shakeCtrl.dispose();
    _recordCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    final preguntas = await PreguntasRepository.cargarPreguntas();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preguntas = preguntas;
      _indicesPendientes =
          List.generate(preguntas.length, (i) => i)..shuffle();
      _recordPersonal = prefs.getInt('racha_record') ?? 0;
      _cargando = false;
    });
    _siguientePregunta();
  }

  // ── Game logic ────────────────────────────────────────────────────────────────

  void _siguientePregunta() {
    if (_indicesPendientes.isEmpty) {
      _indicesPendientes =
          List.generate(_preguntas.length, (i) => i)..shuffle();
    }
    final idx = _indicesPendientes.removeLast();
    final pregunta = _preguntas[idx];
    final mapa = [0, 1, 2]..shuffle(Random());
    setState(() {
      _preguntaActual = pregunta;
      _mapaIndices = mapa;
      _opcionesMezcladas = mapa.map((i) => pregunta.opciones[i]).toList();
      _respuestaSeleccionada = null;
      _respondida = false;
      _estadoMascota = _EstadoMascota.normal;
      _isNewRecord = false;
    });
    if (_showRecordBanner) {
      _recordCtrl.reset();
      setState(() => _showRecordBanner = false);
    }
  }

  void _updatePulseForRacha(int racha) {
    if (racha < 5) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
      _vibrateCtrl.stop();
      _vibrateCtrl.value = 0;
      return;
    }

    final newDuration = racha >= 20
        ? const Duration(milliseconds: 350)
        : racha >= 15
            ? const Duration(milliseconds: 450)
            : racha >= 10
                ? const Duration(milliseconds: 650)
                : const Duration(milliseconds: 900);

    if (_pulseCtrl.duration != newDuration) {
      _pulseCtrl.stop();
      _pulseCtrl.duration = newDuration;
    }
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);

    if (racha >= 20) {
      if (!_vibrateCtrl.isAnimating) _vibrateCtrl.repeat(reverse: true);
    } else {
      _vibrateCtrl.stop();
      _vibrateCtrl.value = 0;
    }
  }

  Future<void> _responder(int opcionDisplay) async {
    if (_respondida) return;

    final indiceOriginal = _mapaIndices[opcionDisplay];
    final esCorrecta = indiceOriginal == _preguntaActual!.respuestaCorrecta;

    setState(() {
      _respuestaSeleccionada = opcionDisplay;
      _respondida = true;
      _estadoMascota =
          esCorrecta ? _EstadoMascota.correcto : _EstadoMascota.fallo;
    });

    if (esCorrecta) {
      final nuevaRacha = _rachaActual + 1;
      final esNuevoRecord = nuevaRacha > _recordPersonal;

      if (esNuevoRecord) {
        _confettiParticles = generateConfettiParticles();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('racha_record', nuevaRacha);
      }

      if (!_estudiadoHoy) {
        _estudiadoHoy = true;
        unawaited(
          DailyStreakRepository.registrarEstudio().then((r) {
            if (r.streak >= 1 && mounted) {
              NotificationService.scheduleStreakWarning(r.streak);
            }
          }),
        );
      }

      setState(() {
        _rachaActual = nuevaRacha;
        if (esNuevoRecord) {
          _recordPersonal = nuevaRacha;
          _isNewRecord = true;
          _showRecordBanner = true;
        }
      });

      _updatePulseForRacha(nuevaRacha);
      if (esNuevoRecord) _recordCtrl.forward(from: 0);

      _boingCtrl.forward(from: 0);
      _flashCtrl.forward(from: 0);
    } else {
      FalladasRepository.agregar([_preguntaActual!.id]);
      _shakeCtrl.forward(from: 0).then((_) {
        if (mounted) _shakeCtrl.value = 0;
      });
    }
  }

  void _continuar() => _siguientePregunta();

  void _reiniciarRacha() {
    setState(() => _rachaActual = 0);
    _updatePulseForRacha(0);
    _siguientePregunta();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando || _preguntaActual == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }

    final int tension = _rachaActual < 5
        ? 0
        : _rachaActual < 10
            ? 1
            : _rachaActual < 15
                ? 2
                : _rachaActual < 20
                    ? 3
                    : 4;

    final bgColor = switch (tension) {
      2 => const Color(0xFFFFFDF5),
      3 => const Color(0xFFFFFBEE),
      4 => const Color(0xFFFFF8E0),
      _ => Colors.white,
    };

    final correctaEnDisplay = _respondida
        ? _mapaIndices.indexOf(_preguntaActual!.respuestaCorrecta)
        : -1;
    final esCorrecta = _respondida &&
        _respuestaSeleccionada != null &&
        _mapaIndices[_respuestaSeleccionada!] ==
            _preguntaActual!.respuestaCorrecta;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(sin(_shakeAnim.value * 4 * pi) * 8.0, 0),
        child: child,
      ),
      child: Stack(
        children: [
          // Animated background tint
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            color: bgColor,
            width: double.infinity,
            height: double.infinity,
          ),
          // Main scaffold
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(),
            body: Column(
              children: [
                if (_showRecordBanner) _buildRecordBanner(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildRachaRow(tension),
                ),
                _Mascota(estado: _estadoMascota),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildQuestionCard(tension),
                        const SizedBox(height: 20),
                        ...List.generate(_opcionesMezcladas.length, (i) {
                          _EstadoOpcion estado;
                          if (!_respondida) {
                            estado = _EstadoOpcion.normal;
                          } else if (i == correctaEnDisplay) {
                            estado = _EstadoOpcion.correcta;
                          } else if (i == _respuestaSeleccionada) {
                            estado = _EstadoOpcion.incorrecta;
                          } else {
                            estado = _EstadoOpcion.neutra;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OpcionCard(
                              letra: String.fromCharCode(65 + i),
                              texto: _opcionesMezcladas[i],
                              estado: estado,
                              onTap: _respondida ? null : () => _responder(i),
                            ),
                          );
                        }),
                        if (_respondida) ...[
                          const SizedBox(height: 8),
                          _ResultadoCard(
                            esCorrecta: esCorrecta,
                            explicacion: _preguntaActual!.explicacion,
                          ),
                          const SizedBox(height: 16),
                          _ActionButton(
                            label: esCorrecta
                                ? 'Continuar'
                                : 'Intentar de nuevo',
                            icon: esCorrecta
                                ? Icons.arrow_forward_rounded
                                : Icons.refresh_rounded,
                            color: esCorrecta ? _kGreen : _kRed,
                            onTap: esCorrecta ? _continuar : _reiniciarRacha,
                          ),
                          if (!esCorrecta && _rachaActual > 0) ...[
                            const SizedBox(height: 12),
                            _ShareButton(racha: _rachaActual),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Green flash overlay
          AnimatedBuilder(
            animation: _flashAnim,
            builder: (_, _) => IgnorePointer(
              child: Container(
                color: _kGreen.withValues(alpha: _flashAnim.value),
              ),
            ),
          ),
          // Confetti overlay
          if (_showRecordBanner)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _recordCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: ConfettiPainter(
                      progress: _recordCtrl.value,
                      particles: _confettiParticles,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _kTextDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Modo Racha',
        style: TextStyle(
            color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: _kYellow, size: 20),
              const SizedBox(width: 4),
              Text(
                '$_recordPersonal',
                style: const TextStyle(
                  color: _kYellow,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordBanner() {
    return AnimatedBuilder(
      animation: _recordCtrl,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _recordSlideAnim.value),
        child: Opacity(
          opacity: _recordFadeAnim.value.clamp(0.0, 1.0),
          child: Center(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFFFD600)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _kYellow.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '¡Nuevo récord!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRachaRow(int tension) {
    final counterColor = _isNewRecord
        ? _kGold
        : tension >= 4
            ? const Color(0xFFFF8C00)
            : _kTextDark;
    final fontSize =
        tension >= 4 ? 34.0 : tension >= 3 ? 32.0 : 28.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _boingAnim, _vibrateAnim]),
      builder: (context, _) {
        final scale = _boingCtrl.isAnimating
            ? _boingAnim.value
            : (tension >= 1 ? _pulseAnim.value : 1.0);

        final vibrateX = tension >= 4
            ? sin(_vibrateAnim.value * 2 * pi) * 2.5
            : 0.0;

        // Extra flame opacity pulses with the scale animation (0 at min, 1 at max)
        final extraFlameOpacity =
            tension >= 4 ? ((_pulseAnim.value - 1.0) * 12.5).clamp(0.0, 1.0) : 0.0;

        return Transform.translate(
          offset: Offset(vibrateX, 0),
          child: Transform.scale(
            scale: scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: _kYellow, size: 28),
                const SizedBox(width: 6),
                Text(
                  '$_rachaActual',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: counterColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'racha',
                  style: TextStyle(
                      fontSize: 14,
                      color: _kTextGrey,
                      fontWeight: FontWeight.w500),
                ),
                if (tension >= 4) ...[
                  const SizedBox(width: 4),
                  Opacity(
                    opacity: extraFlameOpacity,
                    child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _kYellow,
                        size: 22),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(int tension) {
    // Plain card for tension < 3
    if (tension < 3) {
      return _QuestionCard(enunciado: _preguntaActual!.enunciado, imagen: _preguntaActual!.imagen, imagenOculta: _preguntaActual!.imagenOculta);
    }

    // Animated glowing border for tension 3+
    final borderColor =
        tension >= 4 ? const Color(0xFFFF8C00) : _kYellow;

    return AnimatedBuilder(
      animation: _borderAnim,
      builder: (_, _) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: borderColor.withValues(alpha: _borderAnim.value),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  borderColor.withValues(alpha: _borderAnim.value * 0.18),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
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
            if (_preguntaActual!.imagen != null && !_preguntaActual!.imagenOculta) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SvgPicture.asset(
                  _preguntaActual!.imagen!,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              _preguntaActual!.enunciado,
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
    );
  }
}

// ── Mascota ───────────────────────────────────────────────────────────────────

class _Mascota extends StatelessWidget {
  final _EstadoMascota estado;
  const _Mascota({required this.estado});

  String get _asset => switch (estado) {
        _EstadoMascota.normal => 'assets/semaforo_normal.png',
        _EstadoMascota.correcto => 'assets/semaforo_verde.png',
        _EstadoMascota.fallo => 'assets/semaforo_rojo.png',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      child: Image.asset(
        _asset,
        key: ValueKey(_asset),
        height: 76,
        fit: BoxFit.contain,
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final String enunciado;
  final String? imagen;
  final bool imagenOculta;
  const _QuestionCard({required this.enunciado, this.imagen, this.imagenOculta = false});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (imagen != null && !imagenOculta) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SvgPicture.asset(
                imagen!,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            enunciado,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kTextDark,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _OpcionCard extends StatelessWidget {
  final String letra;
  final String texto;
  final _EstadoOpcion estado;
  final VoidCallback? onTap;

  const _OpcionCard({
    required this.letra,
    required this.texto,
    required this.estado,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final Color borderColor;
    final Color letraColor;
    final Color letraBg;
    Widget? trailingIcon;

    switch (estado) {
      case _EstadoOpcion.correcta:
        bg = _kGreen;
        textColor = Colors.white;
        borderColor = _kGreen;
        letraBg = Colors.white.withValues(alpha: 0.25);
        letraColor = Colors.white;
        trailingIcon = const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 22);
      case _EstadoOpcion.incorrecta:
        bg = _kRed;
        textColor = Colors.white;
        borderColor = _kRed;
        letraBg = Colors.white.withValues(alpha: 0.25);
        letraColor = Colors.white;
        trailingIcon =
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 22);
      case _EstadoOpcion.neutra:
        bg = const Color(0xFFF9F9F9);
        textColor = const Color(0xFFBDBDBD);
        borderColor = _kBorder;
        letraBg = const Color(0xFFEEEEEE);
        letraColor = const Color(0xFFBDBDBD);
        trailingIcon = null;
      case _EstadoOpcion.normal:
        bg = Colors.white;
        textColor = _kTextDark;
        borderColor = _kBorder;
        letraBg = const Color(0xFFF5F5F5);
        letraColor = _kTextGrey;
        trailingIcon = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: estado == _EstadoOpcion.normal
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
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
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 10),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultadoCard extends StatelessWidget {
  final bool esCorrecta;
  final String explicacion;
  const _ResultadoCard(
      {required this.esCorrecta, required this.explicacion});

  @override
  Widget build(BuildContext context) {
    final color = esCorrecta ? _kGreen : _kRed;
    final bgColor =
        esCorrecta ? const Color(0xFFF1FBF1) : const Color(0xFFFFF0F0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esCorrecta
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                esCorrecta ? '¡Correcto!' : 'Respuesta incorrecta',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            explicacion,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share button ──────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final int racha;
  const _ShareButton({required this.racha});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kYellow, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => Share.share(
            '¡He llegado a $racha preguntas seguidas en el test de la DGT con Viali! 🚦 ¿Puedes superarme?',
          ),
          borderRadius: BorderRadius.circular(22),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Compartir racha',
                  style: TextStyle(
                    color: _kYellow,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.share_rounded, color: _kYellow, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
