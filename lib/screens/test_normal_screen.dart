import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/pregunta_imagen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pregunta.dart';
import '../models/test_resultado.dart';
import '../data/preguntas_repository.dart';
import '../data/test_historial_repository.dart';
import '../data/falladas_repository.dart';
import '../data/daily_streak_repository.dart';
import '../data/logros_repository.dart';
import '../data/anki_repository.dart';
import '../data/marcadas_repository.dart';
import '../services/notification_service.dart';
import '../utils/tema_utils.dart';
import '../widgets/confetti_overlay.dart';
import 'logros_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

enum _Fase { seleccion, test, resultados }

enum _EstadoMascota { normal, correcto, fallo }

enum _EstadoOpcion { normal, correcta, incorrecta, neutra }

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

class TestNormalScreen extends StatefulWidget {
  const TestNormalScreen({super.key});

  @override
  State<TestNormalScreen> createState() => _TestNormalScreenState();
}

class _TestNormalScreenState extends State<TestNormalScreen>
    with SingleTickerProviderStateMixin {
  bool _cargando = true;
  List<Pregunta> _todasPreguntas = [];
  Set<int> _falladasHistorial = {};

  // Selection state
  _Fase _fase = _Fase.seleccion;
  String _modo = 'Aleatorio';
  String _tema = 'señales';
  String _dificultad = 'Medio';
  int _cantidad = 10;

  // Test state
  List<Pregunta> _preguntasTest = [];
  int _indiceActual = 0;
  List<String> _opcionesMezcladas = [];
  List<int> _mapaIndices = [];
  int? _respuestaSeleccionada;
  bool _respondida = false;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;
  Map<int, bool> _aciertos = {};
  List<int> _falladasTest = [];

  // Timer state
  Timer? _timerCountdown;
  int _segundosRestantes = 2700;
  bool _tiempoAgotado = false;

  // Confetti
  late final AnimationController _confettiCtrl;
  List<ConfettiParticle> _confettiParticles = [];

  // Marcadas
  Set<int> _marcadas = {};

  // Results state
  TestResultado? _resultado;
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );
    _cargar();
  }

  @override
  void dispose() {
    _timerCountdown?.cancel();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _iniciarTimer() {
    _timerCountdown?.cancel();
    _segundosRestantes = 45 * 60;
    _tiempoAgotado = false;
    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosRestantes <= 1) {
        _timerCountdown?.cancel();
        _timerCountdown = null;
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
    if (_segundosRestantes > 300) return const Color(0xFFFF9800);
    return _kRed;
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      PreguntasRepository.cargarPreguntas(),
      TestHistorialRepository.idsPreguntasFalladas(),
      MarcadasRepository.cargar(),
    ]);
    setState(() {
      _todasPreguntas = results[0] as List<Pregunta>;
      _falladasHistorial = results[1] as Set<int>;
      _marcadas = results[2] as Set<int>;
      _cargando = false;
    });
  }

  Future<void> _toggleMarcada(int id) async {
    final marcada = await MarcadasRepository.alternar(id);
    if (mounted) {
      setState(() {
        if (marcada) {
          _marcadas.add(id);
        } else {
          _marcadas.remove(id);
        }
      });
    }
  }

  void _empezarTest() {
    List<Pregunta> pool = List.from(_todasPreguntas);

    switch (_modo) {
      case 'Por temática':
        final filtrado =
            _todasPreguntas.where((p) => detectarTema(p) == _tema).toList();
        if (filtrado.isNotEmpty) pool = filtrado;
      case 'Por dificultad':
        switch (_dificultad) {
          case 'Fácil':
            final filtrado = _todasPreguntas
                .where((p) => !_falladasHistorial.contains(p.id))
                .toList();
            if (filtrado.isNotEmpty) pool = filtrado;
          case 'Difícil':
            final filtrado = _todasPreguntas
                .where((p) => _falladasHistorial.contains(p.id))
                .toList();
            if (filtrado.isNotEmpty) pool = filtrado;
        }
    }

    pool.shuffle(Random());
    final n = _cantidad.clamp(1, pool.length);

    setState(() {
      _fase = _Fase.test;
      _preguntasTest = pool.take(n).toList();
      _indiceActual = 0;
      _aciertos = {};
      _falladasTest = [];
      _estadoMascota = _EstadoMascota.normal;
    });
    _prepararPregunta();
    _iniciarTimer();
  }

  void _prepararPregunta() {
    final p = _preguntasTest[_indiceActual];
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
    final p = _preguntasTest[_indiceActual];
    final idxOrig = _mapaIndices[opcionDisplay];
    final ok = idxOrig == p.respuestaCorrecta;
    setState(() {
      _respuestaSeleccionada = opcionDisplay;
      _respondida = true;
      _aciertos[p.id] = ok;
      if (!ok) _falladasTest.add(p.id);
      _estadoMascota = ok ? _EstadoMascota.correcto : _EstadoMascota.fallo;
    });
    unawaited(AnkiRepository.registrarRespuesta(p.id, ok));
  }

  void _continuar() {
    if (_indiceActual < _preguntasTest.length - 1) {
      _indiceActual++;       // mutación directa: no dispara rebuild
      _prepararPregunta();   // un solo setState que resetea todo con el índice ya actualizado
    } else {
      _finalizar();
    }
  }

  Future<void> _finalizar() async {
    _timerCountdown?.cancel();
    _timerCountdown = null;
    final correctas = _aciertos.values.where((v) => v).length;
    final streakResult = await DailyStreakRepository.registrarEstudio();
    if (streakResult.streak >= 1) {
      unawaited(NotificationService.scheduleStreakWarning(streakResult.streak));
    }
    final modoLabel = switch (_modo) {
      'Por temática' =>
        _temas.firstWhere((t) => t.$2 == _tema, orElse: () => (_tema, _tema)).$1,
      'Por dificultad' => 'Dificultad: $_dificultad',
      _ => 'Aleatorio',
    };
    final r = TestResultado(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      modo: modoLabel,
      totalPreguntas: _preguntasTest.length,
      correctas: correctas,
      preguntasFalladas: List.from(_falladasTest),
    );
    await TestHistorialRepository.guardar(r);
    await FalladasRepository.agregar(_falladasTest);
    await LogrosRepository.incrementarPreguntas(_preguntasTest.length);
    final nuevosLogros = await LogrosRepository.checkAndUpdate();
    setState(() {
      _resultado = r;
      _fase = _Fase.resultados;
      _estadoMascota = r.aprobado
          ? _EstadoMascota.correcto
          : r.porcentaje < 0.7
              ? _EstadoMascota.fallo
              : _EstadoMascota.normal;
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

  Future<void> _compartirResultado(TestResultado r) async {
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/resultado_viali.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '¿Puedes superarme? Descarga Viali 🚦',
      );
    } catch (_) {}
  }

  Widget _buildShareCard(TestResultado r) {
    final pct = (r.porcentaje * 100).round();
    final color = r.aprobado ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/semaforo_normal.png', height: 26),
              const SizedBox(width: 8),
              const Text(
                'Viali',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${r.correctas}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: '/${r.totalPreguntas}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.6),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              r.aprobado ? 'APROBADO · $pct%' : 'SUSPENSO · $pct%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '¿Puedes superarme?\nDescarga Viali 🚦',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _kTextGrey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _repetirFalladas() {
    if (_falladasTest.isEmpty) return;
    final set = Set<int>.from(_falladasTest);
    final preguntas =
        _todasPreguntas.where((p) => set.contains(p.id)).toList()
          ..shuffle(Random());
    setState(() {
      _fase = _Fase.test;
      _preguntasTest = preguntas;
      _indiceActual = 0;
      _aciertos = {};
      _falladasTest = [];
      _estadoMascota = _EstadoMascota.normal;
      _tiempoAgotado = false;
    });
    _prepararPregunta();
    _iniciarTimer();
  }

  void _nuevoTest() async {
    _confettiCtrl.stop();
    setState(() {
      _fase = _Fase.seleccion;
      _resultado = null;
    });
    final falladas = await TestHistorialRepository.idsPreguntasFalladas();
    if (mounted) setState(() => _falladasHistorial = falladas);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }
    return switch (_fase) {
      _Fase.seleccion => _buildSeleccion(),
      _Fase.test => _buildTest(),
      _Fase.resultados => Stack(
          fit: StackFit.expand,
          children: [
            _buildResultados(),
            ConfettiOverlay(
              controller: _confettiCtrl,
              particles: _confettiParticles,
            ),
          ],
        ),
    };
  }

  // ── Phase 1: Selection ────────────────────────────────────────────────────

  Widget _buildSeleccion() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kTextDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Test Normal',
          style: TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel(label: 'MODO'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final m in ['Aleatorio', 'Por temática', 'Por dificultad'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: m != 'Por dificultad' ? 8 : 0),
                      child: _ModoChip(
                        label: m,
                        activo: _modo == m,
                        onTap: () => setState(() => _modo = m),
                      ),
                    ),
                  ),
              ],
            ),
            if (_modo == 'Por temática') ...[
              const SizedBox(height: 20),
              const _SectionLabel(label: 'TEMÁTICA'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _temas
                    .map((t) => _ChipSelector(
                          label: t.$1,
                          activo: _tema == t.$2,
                          onTap: () => setState(() => _tema = t.$2),
                        ))
                    .toList(),
              ),
            ],
            if (_modo == 'Por dificultad') ...[
              const SizedBox(height: 20),
              const _SectionLabel(label: 'DIFICULTAD'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final d in ['Fácil', 'Medio', 'Difícil'])
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.only(right: d != 'Difícil' ? 8 : 0),
                        child: _DificultadChip(
                          label: d,
                          activo: _dificultad == d,
                          onTap: () => setState(() => _dificultad = d),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel(label: 'NÚMERO DE PREGUNTAS'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final n in [10, 20, 30])
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: n != 30 ? 8 : 0),
                      child: _CantidadChip(
                        cantidad: n,
                        activo: _cantidad == n,
                        onTap: () => setState(() => _cantidad = n),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            _ActionButton(
              label: 'Empezar test',
              icon: Icons.play_arrow_rounded,
              color: _kYellow,
              onTap: _empezarTest,
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 2: Test ─────────────────────────────────────────────────────────

  Widget _buildTest() {
    final pregunta = _preguntasTest[_indiceActual];
    final total = _preguntasTest.length;
    final progreso = (_indiceActual + (_respondida ? 1 : 0)) / total;
    final correctaEnDisplay =
        _respondida ? _mapaIndices.indexOf(pregunta.respuestaCorrecta) : -1;
    final esCorrecta = _respondida &&
        _respuestaSeleccionada != null &&
        _mapaIndices[_respuestaSeleccionada!] == pregunta.respuestaCorrecta;
    final esUltima = _indiceActual == total - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.close_rounded, color: _kTextDark, size: 24),
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('¿Abandonar test?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: const Text('Se perderá tu progreso actual.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continuar',
                      style: TextStyle(color: _kTextGrey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abandonar',
                      style: TextStyle(
                          color: _kRed, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ).then((v) {
            if (v == true && mounted) Navigator.pop(context);
          }),
        ),
        title: Text(
          '${_indiceActual + 1} / $total',
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
                value: progreso,
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
          _Mascota(estado: _estadoMascota),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      _QuestionCard(enunciado: pregunta.enunciado, imagen: pregunta.imagen, imagenOculta: pregunta.imagenOculta, tema: detectarTema(pregunta)),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _toggleMarcada(pregunta.id),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              _marcadas.contains(pregunta.id)
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: _marcadas.contains(pregunta.id)
                                  ? _kYellow
                                  : _kTextGrey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                    const SizedBox(height: 8),
                    _ResultadoCard(
                      esCorrecta: esCorrecta,
                      explicacion: pregunta.explicacion,
                    ),
                    const SizedBox(height: 14),
                    _ActionButton(
                      label:
                          esUltima ? 'Ver resultados' : 'Continuar',
                      icon: esUltima
                          ? Icons.bar_chart_rounded
                          : Icons.arrow_forward_rounded,
                      color: esCorrecta ? _kGreen : _kRed,
                      onTap: _continuar,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 3: Results ──────────────────────────────────────────────────────

  Widget _buildResultados() {
    final r = _resultado!;
    final falladasSet = Set<int>.from(r.preguntasFalladas);
    final preguntasFalladas =
        _preguntasTest.where((p) => falladasSet.contains(p.id)).toList();
    final pct = (r.porcentaje * 100).round();
    final mainColor = r.aprobado ? _kGreen : _kRed;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_off_rounded, color: Color(0xFFFF9800), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Tiempo agotado — el test finalizó automáticamente',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Score card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: r.aprobado
                    ? const Color(0xFFF1FBF1)
                    : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: mainColor.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                children: [
                  _Mascota(estado: _estadoMascota),
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
                        horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: mainColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      r.aprobado ? 'APROBADO · $pct%' : 'SUSPENSO · $pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r.aprobado
                        ? '¡Excelente! Puedes con el examen real.'
                        : pct >= 70
                            ? 'Casi. Repasa los fallos e inténtalo de nuevo.'
                            : 'Necesitas practicar más. ¡Tú puedes!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _kTextGrey,
                        fontSize: 14,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            // Share card
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _shareKey,
              child: _buildShareCard(r),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Compartir resultado',
              icon: Icons.share_rounded,
              color: _kTextDark,
              onTap: () => _compartirResultado(r),
            ),
            // Failed questions
            if (preguntasFalladas.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Preguntas falladas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark),
              ),
              const SizedBox(height: 12),
              ...preguntasFalladas.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PreguntaFalladaCard(pregunta: p),
                  )),
            ],
            const SizedBox(height: 24),
            if (preguntasFalladas.isNotEmpty) ...[
              _ActionButton(
                label: 'Repetir falladas',
                icon: Icons.refresh_rounded,
                color: _kRed,
                onTap: _repetirFalladas,
              ),
              const SizedBox(height: 12),
            ],
            _ActionButton(
              label: 'Nuevo test',
              icon: Icons.add_rounded,
              color: _kYellow,
              onTap: _nuevoTest,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kTextGrey,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Mode chip ─────────────────────────────────────────────────────────────────

class _ModoChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _ModoChip(
      {required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? _kYellow : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activo ? _kYellow : _kBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activo ? Colors.white : _kTextGrey,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Topic chip ────────────────────────────────────────────────────────────────

class _ChipSelector extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _ChipSelector(
      {required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? _kYellow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activo ? _kYellow : _kBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: activo ? Colors.white : _kTextDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Difficulty chip ───────────────────────────────────────────────────────────

class _DificultadChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _DificultadChip(
      {required this.label, required this.activo, required this.onTap});

  Color get _color => switch (label) {
        'Fácil' => _kGreen,
        'Difícil' => _kRed,
        _ => _kYellow,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? c : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activo ? c : _kBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activo ? Colors.white : _kTextGrey,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Count chip ────────────────────────────────────────────────────────────────

class _CantidadChip extends StatelessWidget {
  final int cantidad;
  final bool activo;
  final VoidCallback onTap;
  const _CantidadChip(
      {required this.cantidad, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? _kYellow : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activo ? _kYellow : _kBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activo ? Colors.white : _kTextGrey,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Failed question card ──────────────────────────────────────────────────────

class _PreguntaFalladaCard extends StatelessWidget {
  final Pregunta pregunta;
  const _PreguntaFalladaCard({required this.pregunta});

  @override
  Widget build(BuildContext context) {
    final correcta = pregunta.opciones[pregunta.respuestaCorrecta];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pregunta.enunciado,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextDark,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1FBF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Correcta',
                  style: TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correcta,
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (pregunta.explicacion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pregunta.explicacion,
              style: const TextStyle(
                fontSize: 12,
                color: _kTextGrey,
                height: 1.4,
              ),
            ),
          ],
        ],
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
            CurvedAnimation(
                parent: animation, curve: Curves.easeOutBack),
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
  final String? tema;
  const _QuestionCard({required this.enunciado, this.imagen, this.imagenOculta = false, this.tema});

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
          if (tema != null) ...[
            _TemaPill(tema: tema!),
            const SizedBox(height: 8),
          ],
          if (imagen != null && !imagenOculta) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PreguntaImagen(path: imagen!),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 18),
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

// ── Explanation card ──────────────────────────────────────────────────────────

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
          _ExplicacionResaltada(
            explicacion: explicacion,
            textColor: color.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

// ── Tema pill ─────────────────────────────────────────────────────────────────

class _TemaPill extends StatelessWidget {
  final String tema;
  const _TemaPill({required this.tema});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE0A0), width: 1),
        ),
        child: Text(
          '${emojiDeTema(tema)} ${nombreDeTema(tema)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE67E00),
          ),
        ),
      ),
    );
  }
}

// ── Explicación con números resaltados ────────────────────────────────────────

class _ExplicacionResaltada extends StatelessWidget {
  final String explicacion;
  final Color textColor;
  const _ExplicacionResaltada({required this.explicacion, required this.textColor});

  static final _numPattern = RegExp(
    r'\d+[\.,]?\d*\s*(?:km/h|mg/l|g/l|mg|metros?|km\b|m\b|%|días?|años?|horas?|minutos?)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in _numPattern.allMatches(explicacion)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: explicacion.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFF3CD),
          color: Color(0xFFB06000),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < explicacion.length) {
      spans.add(TextSpan(text: explicacion.substring(lastEnd)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, height: 1.55, color: textColor),
        children: spans,
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
