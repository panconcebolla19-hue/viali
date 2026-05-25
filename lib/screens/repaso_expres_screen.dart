import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/anki_repository.dart';
import '../data/logros_repository.dart';
import 'logros_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kAmber = Color(0xFFE67E00);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFE53935);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

enum _FaseExpres { entrada, quiz, resultado }

enum _EstadoMascota { normal, correcto, fallo }

enum _EstadoOpcion { normal, correcta, incorrecta, neutra }

class RepasoExpresScreen extends StatefulWidget {
  const RepasoExpresScreen({super.key});

  @override
  State<RepasoExpresScreen> createState() => _RepasoExpresScreenState();
}

class _RepasoExpresScreenState extends State<RepasoExpresScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Pregunta> _preguntas = [];
  int _falladasDisponibles = 0;
  bool _cargando = true;

  // ── Phase ─────────────────────────────────────────────────────────────────
  _FaseExpres _fase = _FaseExpres.entrada;

  // ── Quiz state ────────────────────────────────────────────────────────────
  int _indiceActual = 0;
  List<String> _opcionesMezcladas = [];
  List<int> _mapaIndices = [];
  int? _respuestaSeleccionada;
  bool _respondida = false;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;
  int _correctas = 0;

  // ── Timers ────────────────────────────────────────────────────────────────
  static const _kTotalSegundos = 600;
  int _segundosRestantes = _kTotalSegundos;
  Timer? _timerCountdown;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _timerCountdown?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    final results = await Future.wait([
      PreguntasRepository.cargarPreguntas(),
      AnkiRepository.cargar(),
    ]);
    final todas = results[0] as List<Pregunta>;
    final ankiData = results[1] as Map<int, AnkiEntry>;
    final preguntasMapa = {for (final p in todas) p.id: p};

    // Sort by totalFalladas desc
    final conFalladas = ankiData.entries
        .where((e) => e.value.totalFalladas > 0 && preguntasMapa.containsKey(e.key))
        .map((e) => (preguntasMapa[e.key]!, e.value.totalFalladas))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final topFalladas = conFalladas.take(20).map((e) => e.$1).toList();
    final falladasDisp = topFalladas.length;

    // Fill to 20 with randoms
    if (topFalladas.length < 20) {
      final topIds = topFalladas.map((p) => p.id).toSet();
      final restantes = todas.where((p) => !topIds.contains(p.id)).toList()
        ..shuffle();
      topFalladas.addAll(restantes.take(20 - topFalladas.length));
    }

    topFalladas.shuffle();

    if (mounted) {
      setState(() {
        _preguntas = topFalladas;
        _falladasDisponibles = falladasDisp;
        _cargando = false;
      });
    }
  }

  // ── Quiz flow ─────────────────────────────────────────────────────────────

  void _iniciarQuiz() {
    setState(() {
      _fase = _FaseExpres.quiz;
      _indiceActual = 0;
      _correctas = 0;
      _segundosRestantes = _kTotalSegundos;
    });
    _prepararPregunta();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timerCountdown?.cancel();
    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosRestantes <= 1) {
        _timerCountdown?.cancel();
        setState(() => _segundosRestantes = 0);
        _finalizar();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  void _prepararPregunta() {
    final p = _preguntas[_indiceActual];
    final mapa = List.generate(p.opciones.length, (i) => i)..shuffle(Random());
    setState(() {
      _mapaIndices = mapa;
      _opcionesMezcladas = mapa.map((i) => p.opciones[i]).toList();
      _respuestaSeleccionada = null;
      _respondida = false;
      _estadoMascota = _EstadoMascota.normal;
    });
  }

  void _responder(int opcionDisplay) {
    if (_respondida) return;
    final p = _preguntas[_indiceActual];
    final idxOrig = _mapaIndices[opcionDisplay];
    final ok = idxOrig == p.respuestaCorrecta;
    setState(() {
      _respuestaSeleccionada = opcionDisplay;
      _respondida = true;
      _estadoMascota = ok ? _EstadoMascota.correcto : _EstadoMascota.fallo;
      if (ok) _correctas++;
    });
    unawaited(AnkiRepository.registrarRespuesta(p.id, ok));
    _actualizarLogros();

    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 1800), _avanzar);
  }

  void _avanzar() {
    _autoAdvanceTimer?.cancel();
    if (!mounted) return;
    if (_indiceActual < _preguntas.length - 1) {
      setState(() => _indiceActual++);
      _prepararPregunta();
    } else {
      _finalizar();
    }
  }

  Future<void> _actualizarLogros() async {
    await LogrosRepository.incrementarPreguntas(1);
    final nuevos = await LogrosRepository.checkAndUpdate();
    if (mounted && nuevos.isNotEmpty) {
      for (final l in nuevos) {
        await mostrarLogroPopup(context, l);
      }
    }
  }

  void _finalizar() {
    _autoAdvanceTimer?.cancel();
    _timerCountdown?.cancel();
    if (mounted) setState(() => _fase = _FaseExpres.resultado);
  }

  void _repetir() {
    _preguntas.shuffle();
    setState(() {
      _fase = _FaseExpres.quiz;
      _indiceActual = 0;
      _correctas = 0;
      _segundosRestantes = _kTotalSegundos;
    });
    _prepararPregunta();
    _iniciarTimer();
  }

  // ── Timer helpers ─────────────────────────────────────────────────────────

  String get _tiempoFormato {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _colorTimer {
    if (_segundosRestantes > 180) return _kYellow;
    if (_segundosRestantes > 60) return const Color(0xFFFF9800);
    return _kRed;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }
    return switch (_fase) {
      _FaseExpres.entrada => _buildEntrada(),
      _FaseExpres.quiz => _buildQuiz(),
      _FaseExpres.resultado => _buildResultado(),
    };
  }

  // ── Phase 1: Entrada ──────────────────────────────────────────────────────

  Widget _buildEntrada() {
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/semaforo_normal.png', height: 120),
              const SizedBox(height: 20),
              const Text(
                'Repaso Exprés ⚡',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tus 20 preguntas más falladas\nen 10 minutos',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: _kGrey, height: 1.5),
              ),
              const SizedBox(height: 28),
              // Info cards
              _InfoRow(
                items: [
                  _InfoItem(
                    icon: Icons.quiz_rounded,
                    label: '20 preguntas',
                    color: _kYellow,
                  ),
                  _InfoItem(
                    icon: Icons.timer_rounded,
                    label: '10 minutos',
                    color: _kAmber,
                  ),
                  _InfoItem(
                    icon: Icons.auto_graph_rounded,
                    label: '${_falladasDisponibles > 0 ? _falladasDisponibles.clamp(0, 20) : 0} falladas',
                    color: _kRed,
                  ),
                ],
              ),
              const Spacer(),
              // Start button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kYellow, _kAmber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: _kYellow.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: _iniciarQuiz,
                      borderRadius: BorderRadius.circular(22),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '¡Empezar ahora!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phase 2: Quiz ─────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final p = _preguntas[_indiceActual];
    final total = _preguntas.length;
    final progreso = (_indiceActual + (_respondida ? 1 : 0)) / total;
    final correctaEnDisplay =
        _respondida ? _mapaIndices.indexOf(p.respuestaCorrecta) : -1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Timer header ───────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _kGrey, size: 22),
                        onPressed: () {
                          _timerCountdown?.cancel();
                          _autoAdvanceTimer?.cancel();
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      Icon(Icons.bolt_rounded,
                          color: _colorTimer, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _tiempoFormato,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _colorTimer,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_indiceActual + 1}/$total',
                        style: const TextStyle(
                            fontSize: 14,
                            color: _kGrey,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Timer bar (empties left to right)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _segundosRestantes / _kTotalSegundos,
                      backgroundColor: const Color(0xFFEEEEEE),
                      color: _colorTimer,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Question progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: const Color(0xFFEEEEEE),
                      color: _kYellow,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            // ── Mascot ───────────────────────────────────────────────────
            const SizedBox(height: 6),
            _Mascota(estado: _estadoMascota),
            // ── Question + options ─────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _respondida ? _avanzar : null,
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TarjetaPregunta(pregunta: p),
                      const SizedBox(height: 14),
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
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OpcionCard(
                            letra: String.fromCharCode(65 + i),
                            texto: _opcionesMezcladas[i],
                            estado: estado,
                            onTap: _respondida ? null : () => _responder(i),
                          ),
                        );
                      }),
                      if (_respondida) ...[
                        const SizedBox(height: 6),
                        _ExplicacionBreve(
                          correcto: _mapaIndices[_respuestaSeleccionada!] ==
                              p.respuestaCorrecta,
                          explicacion: p.explicacion,
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Toca para continuar',
                            style: TextStyle(
                                fontSize: 12,
                                color: _kGrey,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 3: Resultado ────────────────────────────────────────────────────

  Widget _buildResultado() {
    final pct = _preguntas.isNotEmpty
        ? _correctas / _preguntas.length
        : 0.0;

    final String mascotaAsset;
    final String mensaje;
    if (_correctas >= 18) {
      mascotaAsset = 'assets/semaforo_verde.png';
      mensaje = '¡Estás listo! Mañana lo vas a petar 🚀';
    } else if (_correctas >= 14) {
      mascotaAsset = 'assets/semaforo_verde.png';
      mensaje = 'Casi perfecto, tienes buena pinta 💪';
    } else if (_correctas >= 10) {
      mascotaAsset = 'assets/semaforo_normal.png';
      mensaje = 'Repasa un poco más esta noche 📚';
    } else {
      mascotaAsset = 'assets/semaforo_rojo.png';
      mensaje = 'No te preocupes, confía en ti mismo 🍀';
    }

    final color = pct >= 0.7 ? _kGreen : pct >= 0.5 ? _kYellow : _kRed;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
          child: Column(
            children: [
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Image.asset(
                  mascotaAsset,
                  key: ValueKey(mascotaAsset),
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // Score circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_correctas',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/ ${_preguntas.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    height: 1.4,
                  ),
                ),
              ),
              if (_segundosRestantes == 0) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_off_rounded,
                        color: _kGrey, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Tiempo agotado',
                      style: TextStyle(
                          fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kYellow, _kAmber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: _kYellow.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: _repetir,
                      borderRadius: BorderRadius.circular(22),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 17),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Repetir',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Volver al inicio',
                    style: TextStyle(
                      color: _kGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .expand((item) => [
                Expanded(child: item),
                if (item != items.last) const SizedBox(width: 10),
              ])
          .toList(),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withValues(alpha: 0.22), width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Mascota extends StatelessWidget {
  final _EstadoMascota estado;
  const _Mascota({required this.estado});

  String get _asset => switch (estado) {
        _EstadoMascota.correcto => 'assets/semaforo_verde.png',
        _EstadoMascota.fallo => 'assets/semaforo_rojo.png',
        _EstadoMascota.normal => 'assets/semaforo_normal.png',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
      child: Image.asset(
        _asset,
        key: ValueKey(_asset),
        height: 62,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _TarjetaPregunta extends StatelessWidget {
  final Pregunta pregunta;
  const _TarjetaPregunta({required this.pregunta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pregunta.imagen != null && !pregunta.imagenOculta) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/${pregunta.imagen}',
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            pregunta.enunciado,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kDark,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final Color letraBg;
    final Color letraColor;
    Widget? trailing;

    switch (estado) {
      case _EstadoOpcion.correcta:
        bg = _kGreen;
        textColor = Colors.white;
        borderColor = _kGreen;
        letraBg = Colors.white.withValues(alpha: 0.25);
        letraColor = Colors.white;
        trailing = const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 20);
      case _EstadoOpcion.incorrecta:
        bg = _kRed;
        textColor = Colors.white;
        borderColor = _kRed;
        letraBg = Colors.white.withValues(alpha: 0.25);
        letraColor = Colors.white;
        trailing =
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 20);
      case _EstadoOpcion.neutra:
        bg = const Color(0xFFF8F8F8);
        textColor = const Color(0xFFBDBDBD);
        borderColor = _kBorder;
        letraBg = const Color(0xFFEEEEEE);
        letraColor = const Color(0xFFBDBDBD);
        trailing = null;
      case _EstadoOpcion.normal:
        bg = Colors.white;
        textColor = _kDark;
        borderColor = _kBorder;
        letraBg = const Color(0xFFF5F5F5);
        letraColor = _kGrey;
        trailing = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: estado == _EstadoOpcion.normal
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: letraBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      letra,
                      style: TextStyle(
                        color: letraColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplicacionBreve extends StatelessWidget {
  final bool correcto;
  final String explicacion;

  const _ExplicacionBreve(
      {required this.correcto, required this.explicacion});

  @override
  Widget build(BuildContext context) {
    final color = correcto ? _kGreen : _kRed;
    final bgColor =
        correcto ? const Color(0xFFF1FBF1) : const Color(0xFFFFF0F0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correcto ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explicacion.length > 120
                  ? '${explicacion.substring(0, 117)}…'
                  : explicacion,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
