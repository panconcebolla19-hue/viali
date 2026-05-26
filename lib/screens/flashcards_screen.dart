import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/anki_repository.dart';
import '../data/daily_streak_repository.dart';
import '../data/marcadas_repository.dart';
import '../data/falladas_repository.dart';
import '../data/test_historial_repository.dart';
import '../data/logros_repository.dart';
import '../utils/tema_utils.dart';
import 'logros_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFE53935);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

const _temas = [
  ('Señales', 'señales'),
  ('Velocidad', 'velocidad'),
  ('Alcohol/Drogas', 'alcohol'),
  ('Adelantamientos', 'adelantamientos'),
  ('Distancias', 'distancias'),
  ('Autopistas', 'autopista'),
  ('Medio ambiente', 'medio_ambiente'),
  ('Documentación', 'documentacion'),
];

enum _FaseFlash { seleccion, cartas, resumen }

enum _EstadoMascota { normal, bien, mal }

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with TickerProviderStateMixin {
  // ── Data ───────────────────────────────────────────────────────────────────
  List<Pregunta> _todasPreguntas = [];
  List<Pregunta> _cartas = [];
  Set<int> _marcadasIds = {};
  Set<int> _falladasIds = {};
  bool _cargando = true;

  // ── Selection ───────────────────────────────────────────────────────────────
  _FaseFlash _fase = _FaseFlash.seleccion;
  String _filtro = 'todas'; // 'todas','marcadas','falladas','tema'
  String _temaSeleccionado = 'señales';

  bool _estudiadoHoy = false;

  // ── Card state ──────────────────────────────────────────────────────────────
  int _indiceActual = 0;
  int _sabias = 0;
  int _casi = 0;
  int _noSabias = 0;
  bool _revelado = false;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;

  // ── Flip animation ──────────────────────────────────────────────────────────
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  // ── Exit animation (swipe out) ──────────────────────────────────────────────
  late final AnimationController _exitCtrl;
  late final void Function(AnimationStatus) _exitStatusListener;
  double _exitFromX = 0;
  double _exitToX = 0;

  // ── Drag state ──────────────────────────────────────────────────────────────
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _flipAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    _exitCtrl = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _exitStatusListener = (status) {
      if (status == AnimationStatus.completed) {
        final calificacion = _exitToX > 0 ? 2 : 0;
        _registrarYavanzar(calificacion);
        _exitCtrl.reset();
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _exitFromX = 0;
            _exitToX = 0;
          });
        }
      }
    };
    _exitCtrl.addStatusListener(_exitStatusListener);

    _cargar();
  }

  @override
  void dispose() {
    _exitCtrl.removeStatusListener(_exitStatusListener);
    _flipCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    final results = await Future.wait([
      PreguntasRepository.cargarPreguntas(),
      MarcadasRepository.cargar(),
      FalladasRepository.cargar(),
      TestHistorialRepository.idsPreguntasFalladas(),
    ]);
    final todas = results[0] as List<Pregunta>;
    final marcadas = results[1] as Set<int>;
    final falladasRacha = results[2] as Set<int>;
    final falladasHistorial = results[3] as Set<int>;
    if (mounted) {
      setState(() {
        _todasPreguntas = todas;
        _marcadasIds = marcadas;
        _falladasIds = {...falladasRacha, ...falladasHistorial};
        _cargando = false;
      });
    }
  }

  void _empezar() {
    List<Pregunta> pool;
    switch (_filtro) {
      case 'marcadas':
        pool = _todasPreguntas.where((p) => _marcadasIds.contains(p.id)).toList();
        if (pool.isEmpty) pool = List.from(_todasPreguntas);
      case 'falladas':
        pool = _todasPreguntas.where((p) => _falladasIds.contains(p.id)).toList();
        if (pool.isEmpty) pool = List.from(_todasPreguntas);
      case 'tema':
        pool = _todasPreguntas
            .where((p) => detectarTema(p) == _temaSeleccionado)
            .toList();
        if (pool.isEmpty) pool = List.from(_todasPreguntas);
      default:
        pool = List.from(_todasPreguntas);
    }
    pool.shuffle();
    setState(() {
      _cartas = pool;
      _indiceActual = 0;
      _sabias = 0;
      _casi = 0;
      _noSabias = 0;
      _revelado = false;
      _estadoMascota = _EstadoMascota.normal;
      _dragOffset = 0;
      _fase = _FaseFlash.cartas;
    });
    _flipCtrl.reset();
  }

  // ── Card interaction ──────────────────────────────────────────────────────────

  void _flip() {
    if (_revelado || _exitCtrl.isAnimating) return;
    _flipCtrl.forward();
    setState(() => _revelado = true);
  }

  void _responderBoton(int calificacion) {
    if (!_revelado || _exitCtrl.isAnimating) return;
    _registrarYavanzar(calificacion);
  }

  void _registrarYavanzar(int calificacion) {
    if (!mounted) return;
    if (_indiceActual >= _cartas.length) return;
    final p = _cartas[_indiceActual];
    unawaited(AnkiRepository.registrarFlashcard(p.id, calificacion));
    if (!mounted) return;
    if (!_estudiadoHoy) {
      _estudiadoHoy = true;
      unawaited(DailyStreakRepository.registrarEstudio());
      if (!mounted) return;
    }
    _actualizarLogros();

    _EstadoMascota mascota;
    if (calificacion == 2) {
      mascota = _EstadoMascota.bien;
    } else if (calificacion == 0) {
      mascota = _EstadoMascota.mal;
    } else {
      mascota = _EstadoMascota.normal;
    }

    if (_indiceActual < _cartas.length - 1) {
      setState(() {
        if (calificacion == 2) {
          _sabias++;
        } else if (calificacion == 1) {
          _casi++;
        } else {
          _noSabias++;
        }
        _estadoMascota = mascota;
        _indiceActual++;
        _revelado = false;
        _dragOffset = 0;
      });
      _flipCtrl.reset();
    } else {
      setState(() {
        if (calificacion == 2) {
          _sabias++;
        } else if (calificacion == 1) {
          _casi++;
        } else {
          _noSabias++;
        }
        _fase = _FaseFlash.resumen;
      });
    }
  }

  Future<void> _actualizarLogros() async {
    await LogrosRepository.incrementarPreguntas(1);
    final nuevos = await LogrosRepository.checkAndUpdate();
    if (mounted && nuevos.isNotEmpty) {
      for (final l in nuevos) {
        if (!mounted) break;
        await mostrarLogroPopup(context, l);
      }
    }
  }

  // ── Swipe gesture ─────────────────────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_revelado || _exitCtrl.isAnimating) return;
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_revelado || _exitCtrl.isAnimating) return;
    if (_dragOffset.abs() > 100) {
      _triggerSwipeExit(_dragOffset > 0);
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  void _triggerSwipeExit(bool right) {
    final screenW = MediaQuery.sizeOf(context).width;
    _exitFromX = _dragOffset;
    _exitToX = right ? screenW * 1.8 : -screenW * 1.8;
    _exitCtrl.forward(from: 0);
  }

  double get _currentCardX {
    if (_exitCtrl.isAnimating) {
      return _exitFromX + (_exitToX - _exitFromX) * _exitCtrl.value;
    }
    return _dragOffset;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }
    return switch (_fase) {
      _FaseFlash.seleccion => _buildSeleccion(),
      _FaseFlash.cartas => _buildCartas(),
      _FaseFlash.resumen => _buildResumen(),
    };
  }

  // ── Phase 1: Selection ────────────────────────────────────────────────────────

  Widget _buildSeleccion() {
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
          'Flashcards',
          style: TextStyle(
              color: _kDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header illustration
            Center(
              child: Column(
                children: [
                  Image.asset('assets/semaforo_normal.png', height: 80),
                  const SizedBox(height: 12),
                  const Text(
                    'Repasa con Flashcards',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Voltea la carta para ver la respuesta.\nDesliza o usa los botones para calificar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: _kGrey, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SecLabel('FILTRO DE PREGUNTAS'),
            const SizedBox(height: 12),
            _FiltroTile(
              icon: Icons.dashboard_rounded,
              label: 'Todas las preguntas',
              subtitle: '${_todasPreguntas.length} preguntas',
              activo: _filtro == 'todas',
              onTap: () => setState(() => _filtro = 'todas'),
            ),
            const SizedBox(height: 8),
            _FiltroTile(
              icon: Icons.bookmark_rounded,
              label: 'Marcadas con banderita',
              subtitle: '${_marcadasIds.length} preguntas',
              activo: _filtro == 'marcadas',
              onTap: () => setState(() => _filtro = 'marcadas'),
            ),
            const SizedBox(height: 8),
            _FiltroTile(
              icon: Icons.cancel_rounded,
              label: 'Preguntas falladas',
              subtitle: '${_falladasIds.length} preguntas',
              activo: _filtro == 'falladas',
              onTap: () => setState(() => _filtro = 'falladas'),
            ),
            const SizedBox(height: 8),
            _FiltroTile(
              icon: Icons.category_rounded,
              label: 'Por temática',
              subtitle: _filtro == 'tema'
                  ? _temas
                      .firstWhere((t) => t.$2 == _temaSeleccionado,
                          orElse: () => (_temaSeleccionado, _temaSeleccionado))
                      .$1
                  : 'Elige un tema',
              activo: _filtro == 'tema',
              onTap: () => setState(() => _filtro = 'tema'),
            ),
            if (_filtro == 'tema') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _temas
                    .map((t) => _TemaChip(
                          label: t.$1,
                          activo: _temaSeleccionado == t.$2,
                          onTap: () =>
                              setState(() => _temaSeleccionado = t.$2),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            _StartButton(onTap: _empezar),
          ],
        ),
      ),
    );
  }

  // ── Phase 2: Cards ────────────────────────────────────────────────────────────

  Widget _buildCartas() {
    if (_indiceActual >= _cartas.length) return const SizedBox.shrink();
    final p = _cartas[_indiceActual];
    final total = _cartas.length;
    final cardX = _currentCardX;
    final swipeRatio = (cardX / 300).clamp(-1.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _kDark, size: 24),
          onPressed: () => setState(() => _fase = _FaseFlash.seleccion),
        ),
        title: Column(
          children: [
            Text(
              'Carta ${_indiceActual + 1} de $total',
              style: const TextStyle(
                  color: _kDark, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_indiceActual + 1) / total,
                backgroundColor: const Color(0xFFEEEEEE),
                color: _kYellow,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Mascot (small, reactive)
            _MascotaFlash(estado: _estadoMascota),
            const SizedBox(height: 8),
            // Swipe hint labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Opacity(
                    opacity: _revelado
                        ? ((-swipeRatio).clamp(0.0, 1.0) * 0.9)
                        : 0,
                    child: Row(
                      children: [
                        Icon(Icons.sentiment_dissatisfied_rounded,
                            color: _kRed, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'No lo sabía',
                          style: TextStyle(
                              color: _kRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: _revelado
                        ? (swipeRatio.clamp(0.0, 1.0) * 0.9)
                        : 0,
                    child: Row(
                      children: [
                        const Text(
                          'Lo sabía',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.sentiment_very_satisfied_rounded,
                            color: _kGreen, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Card (swipeable + flippable)
            Expanded(
              child: GestureDetector(
                onTap: _revelado ? null : _flip,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_flipAnim, _exitCtrl]),
                  builder: (context, child) {
                    final double flipAngle =
                        _flipAnim.value * math.pi;
                    final double dx = _currentCardX;
                    final double rot = dx / 1800.0;

                    // Color overlay strength based on drag
                    final swipeR = (dx / 300).clamp(-1.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Transform.translate(
                        offset: Offset(dx, dx.abs() * 0.06),
                        child: Transform.rotate(
                          angle: rot,
                          child: Stack(
                          children: [
                            // 3D flip card
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(flipAngle),
                              child: flipAngle <= math.pi / 2
                                  ? _buildFront(p)
                                  : Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.rotationY(math.pi),
                                      child: _buildBack(p),
                                    ),
                            ),
                            // Swipe color overlay
                            if (_revelado && dx.abs() > 20)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: (swipeR > 0 ? _kGreen : _kRed)
                                          .withValues(
                                              alpha: swipeR.abs() * 0.22),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    );
                  },
                ),
              ),
            ),
            // Buttons (visible after flip)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _revelado
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Toca la carta para ver la respuesta',
                      style: TextStyle(
                          color: _kGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              secondChild: _buildBotones(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFront(Pregunta p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kYellow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PREGUNTA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kYellow,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (p.imagen != null && !p.imagenOculta) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/${p.imagen}',
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Center(
                child: Text(
                  p.enunciado,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: _kGrey),
                  SizedBox(width: 6),
                  Text(
                    'Toca para voltear',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kGrey,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(Pregunta p) {
    final respuesta = p.opciones[p.respuestaCorrecta];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kYellow.withValues(alpha: 0.5), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'RESPUESTA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _kGreen.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: _kGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            respuesta,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.explicacion.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 16, color: _kGrey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.explicacion,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _kGrey,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swipe_rounded, size: 16, color: _kGrey),
                  SizedBox(width: 6),
                  Text(
                    'Desliza ← no lo sabía · lo sabía →',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kGrey,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: _BotonRespuesta(
              label: 'No lo sabía',
              emoji: '😞',
              color: _kRed,
              onTap: () => _responderBoton(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BotonRespuesta(
              label: 'Casi',
              emoji: '🤔',
              color: _kYellow,
              onTap: () => _responderBoton(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BotonRespuesta(
              label: 'Lo sabía',
              emoji: '💪',
              color: _kGreen,
              onTap: () => _responderBoton(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 3: Results ──────────────────────────────────────────────────────────

  Widget _buildResumen() {
    final total = _cartas.length;
    final sabiasPct = total > 0 ? _sabias / total : 0.0;

    final String mascotaAsset;
    final String titulo;
    final String subtitulo;
    if (sabiasPct >= 0.8) {
      mascotaAsset = 'assets/semaforo_verde.png';
      titulo = '¡Excelente repaso!';
      subtitulo = 'Tienes muy buena memoria. ¡Sigue así!';
    } else if (sabiasPct >= 0.5) {
      mascotaAsset = 'assets/semaforo_normal.png';
      titulo = 'Buen intento';
      subtitulo = 'Vas por buen camino. Repasa las que fallaste.';
    } else {
      mascotaAsset = 'assets/semaforo_rojo.png';
      titulo = 'Necesitas repasar más';
      subtitulo = 'No te rindas. La práctica hace al maestro.';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Resultado',
          style: TextStyle(
              color: _kDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          children: [
            Image.asset(mascotaAsset, height: 100),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: _kDark),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: _kGrey, height: 1.5),
            ),
            const SizedBox(height: 32),
            // Stats grid
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                  emoji: '💪',
                  label: 'Lo sabía',
                  count: _sabias,
                  color: _kGreen,
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                  emoji: '🤔',
                  label: 'Casi',
                  count: _casi,
                  color: _kYellow,
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                  emoji: '😞',
                  label: 'No lo sabía',
                  count: _noSabias,
                  color: _kRed,
                )),
              ],
            ),
            const SizedBox(height: 24),
            // Progress bar
            Container(
              height: 14,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  if (_sabias > 0)
                    Flexible(
                      flex: _sabias,
                      child: Container(color: _kGreen),
                    ),
                  if (_casi > 0)
                    Flexible(
                      flex: _casi,
                      child: Container(color: _kYellow),
                    ),
                  if (_noSabias > 0)
                    Flexible(
                      flex: _noSabias,
                      child: Container(color: _kRed),
                    ),
                  if (_sabias + _casi + _noSabias < total)
                    Flexible(
                      flex: total - _sabias - _casi - _noSabias,
                      child: Container(color: Colors.transparent),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _BigButton(
              label: 'Repetir sesión',
              icon: Icons.refresh_rounded,
              color: _kYellow,
              onTap: _empezar,
            ),
            const SizedBox(height: 12),
            _BigButton(
              label: 'Elegir filtro',
              icon: Icons.tune_rounded,
              color: const Color(0xFFF5F5F5),
              textColor: _kDark,
              onTap: () => setState(() => _fase = _FaseFlash.seleccion),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Volver al inicio',
                style: TextStyle(color: _kGrey, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kGrey,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FiltroTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? const Color(0xFFFFFBEE) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activo ? _kYellow.withValues(alpha: 0.6) : _kBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: activo ? _kYellow : _kGrey, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: activo ? _kDark : _kDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              ),
              if (activo)
                const Icon(Icons.check_circle_rounded,
                    color: _kYellow, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemaChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _TemaChip(
      {required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? _kYellow : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? _kYellow : _kBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : _kDark,
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¡Empezar Flashcards!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                SizedBox(width: 8),
                Text('🃏', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotaFlash extends StatelessWidget {
  final _EstadoMascota estado;
  const _MascotaFlash({required this.estado});

  String get _asset => switch (estado) {
        _EstadoMascota.bien => 'assets/semaforo_verde.png',
        _EstadoMascota.mal => 'assets/semaforo_rojo.png',
        _EstadoMascota.normal => 'assets/semaforo_normal.png',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Image.asset(
        _asset,
        key: ValueKey(_asset),
        height: 48,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _BotonRespuesta extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _BotonRespuesta({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
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
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
