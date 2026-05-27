import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/anki_repository.dart';
import '../data/daily_streak_repository.dart';
import '../data/logros_repository.dart';
import '../utils/tema_utils.dart';
import 'logros_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

enum _EstadoMascota { normal, correcto, fallo }
enum _EstadoOpcion { normal, correcta, incorrecta, neutra }

class RepasoAnkiScreen extends StatefulWidget {
  const RepasoAnkiScreen({super.key});

  @override
  State<RepasoAnkiScreen> createState() => _RepasoAnkiScreenState();
}

class _RepasoAnkiScreenState extends State<RepasoAnkiScreen> {
  bool _cargando = true;
  List<Pregunta> _todasPendientes = [];
  List<Pregunta> _preguntas = [];
  Map<int, AnkiEntry> _ankiData = {};

  bool _mostrarSeleccion = false;
  int? _limitePreguntas;
  DateTime? _sesionInicio;

  int _indice = 0;
  List<String> _opcionesMezcladas = [];
  List<int> _mapaIndices = [];
  int? _respuestaSeleccionada;
  bool _respondida = false;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;
  int _correctas = 0;
  bool _finalizado = false;
  int _intervalMensaje = 1;
  bool _estudiadoHoy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todasPreguntas = await PreguntasRepository.cargarPreguntas();
    final todosIds = todasPreguntas.map((p) => p.id).toList();
    final results = await Future.wait([
      AnkiRepository.pendientesHoy(todosIds),
      AnkiRepository.cargar(),
    ]);
    final pendienteIds = results[0] as List<int>;
    final ankiData = results[1] as Map<int, AnkiEntry>;
    final pendienteSet = Set<int>.from(pendienteIds);

    final seleccionadas = todasPreguntas
        .where((p) => pendienteSet.contains(p.id))
        .toList()
      ..shuffle(Random());

    if (mounted) {
      setState(() {
        _todasPendientes = seleccionadas;
        _ankiData = ankiData;
        _cargando = false;
        if (seleccionadas.isNotEmpty) _mostrarSeleccion = true;
      });
    }
  }

  void _iniciarSesion(int? limite) {
    final preguntas = limite != null
        ? _todasPendientes.take(limite).toList()
        : _todasPendientes;
    setState(() {
      _limitePreguntas = limite;
      _preguntas = preguntas;
      _mostrarSeleccion = false;
      _sesionInicio = DateTime.now();
    });
    if (preguntas.isNotEmpty) _prepararPregunta();
  }

  void _prepararPregunta() {
    final p = _preguntas[_indice];
    final indices = List.generate(p.opciones.length, (i) => i)
      ..shuffle(Random());
    setState(() {
      _mapaIndices = indices;
      _opcionesMezcladas = indices.map((i) => p.opciones[i]).toList();
      _respuestaSeleccionada = null;
      _respondida = false;
      _estadoMascota = _EstadoMascota.normal;
    });
  }

  void _responder(int opcionDisplay) {
    if (_respondida) return;
    final p = _preguntas[_indice];
    final idxOrig = _mapaIndices[opcionDisplay];
    final ok = idxOrig == p.respuestaCorrecta;
    unawaited(AnkiRepository.registrarRespuesta(p.id, ok));
    if (!mounted) return;
    if (!_estudiadoHoy) {
      _estudiadoHoy = true;
      unawaited(DailyStreakRepository.registrarEstudio());
      if (!mounted) return;
    }
    _actualizarLogros();

    final entry = _ankiData[p.id] ?? const AnkiEntry();
    final int intervalo;
    if (!ok) {
      intervalo = 1;
    } else {
      final nuevas = entry.acertadasSeguidas + 1;
      intervalo = switch (nuevas) {
        1 => 3,
        2 => 7,
        3 => 21,
        _ => 60,
      };
    }

    setState(() {
      _respuestaSeleccionada = opcionDisplay;
      _respondida = true;
      _estadoMascota = ok ? _EstadoMascota.correcto : _EstadoMascota.fallo;
      if (ok) _correctas++;
      _intervalMensaje = intervalo;
    });
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

  void _siguiente() {
    if (_indice < _preguntas.length - 1) {
      setState(() => _indice++);
      _prepararPregunta();
    } else {
      setState(() => _finalizado = true);
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
              color: _kTextDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Repaso Inteligente',
          style: TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: _preguntas.isNotEmpty && !_cargando && !_finalizado
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_indice + (_respondida ? 1 : 0)) / _preguntas.length,
                  backgroundColor: const Color(0xFFEEEEEE),
                  color: _kYellow,
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _todasPendientes.isEmpty
              ? _buildVacio()
              : _mostrarSeleccion
                  ? _buildSeleccion()
                  : _finalizado
                      ? _buildCelebracion()
                      : _buildQuiz(),
    );
  }

  Widget _buildSeleccion() {
    final opciones = [
      (label: '5 min', sublabel: '~10 preguntas', limite: 10, emoji: '⚡'),
      (label: '10 min', sublabel: '~20 preguntas', limite: 20, emoji: '🎯'),
      (label: '20 min', sublabel: '~40 preguntas', limite: 40, emoji: '📚'),
      (label: 'Sin límite', sublabel: '${_todasPendientes.length} pendientes', limite: null as int?, emoji: '🚀'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        children: [
          const Spacer(),
          Image.asset('assets/semaforo_normal.png', height: 80),
          const SizedBox(height: 20),
          const Text(
            '¿Cuánto tiempo tienes?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_todasPendientes.length} preguntas pendientes hoy',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _kTextGrey),
          ),
          const Spacer(),
          ...opciones.map((op) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SesionOpcion(
              emoji: op.emoji,
              label: op.label,
              sublabel: op.sublabel,
              onTap: () => _iniciarSesion(op.limite),
            ),
          )),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/semaforo_verde.png', height: 130),
            const SizedBox(height: 28),
            const Text(
              '¡No tienes nada pendiente!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vuelve mañana para seguir repasando. El sistema te irá mostrando las preguntas en el momento justo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: _kTextGrey, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _kYellow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Volver',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildCelebracion() {
    final minutos = _sesionInicio != null
        ? DateTime.now().difference(_sesionInicio!).inMinutes
        : 0;
    final titulo = _limitePreguntas != null
        ? '¡Sesión completada! 🎉'
        : '¡Al día! 🎉';
    final subtitulo = _limitePreguntas != null
        ? '$_correctas de ${_preguntas.length} correctas en $minutos ${minutos == 1 ? 'minuto' : 'minutos'}'
        : '$_correctas de ${_preguntas.length} correctas';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/semaforo_verde.png', height: 130),
            const SizedBox(height: 28),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kTextGrey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Has completado todas las preguntas de hoy. ¡Vuelve mañana para más!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kTextGrey, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '¡Perfecto!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildQuiz() {
    if (_indice >= _preguntas.length) return const SizedBox.shrink();
    final p = _preguntas[_indice];
    final correctaEnDisplay =
        _respondida ? _mapaIndices.indexOf(p.respuestaCorrecta) : -1;
    final esCorrecta = _respondida &&
        _respuestaSeleccionada != null &&
        _mapaIndices[_respuestaSeleccionada!] == p.respuestaCorrecta;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pregunta ${_indice + 1} de ${_preguntas.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kTextGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '📚 ${_preguntas.length - _indice} restantes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _AnkiMascota(estado: _estadoMascota),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AnkiQuestionCard(
                    enunciado: p.enunciado,
                    imagen: p.imagen,
                    imagenOculta: p.imagenOculta,
                    tema: detectarTema(p),
                  ),
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
                      child: _AnkiOpcionCard(
                        letra: String.fromCharCode(65 + i),
                        texto: _opcionesMezcladas[i],
                        estado: estado,
                        onTap: _respondida ? null : () => _responder(i),
                      ),
                    );
                  }),
                  if (_respondida) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: esCorrecta
                            ? const Color(0xFFF1FBF1)
                            : const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (esCorrecta ? _kGreen : _kRed)
                              .withValues(alpha: 0.3),
                          width: 1.5,
                        ),
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
                                color: esCorrecta ? _kGreen : _kRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                esCorrecta
                                    ? '¡Correcto! +$_intervalMensaje días'
                                    : 'Incorrecto — mañana de nuevo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: esCorrecta ? _kGreen : _kRed,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (p.explicacion.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _ExplicacionResaltada(
                              explicacion: p.explicacion,
                              textColor: (esCorrecta ? _kGreen : _kRed)
                                  .withValues(alpha: 0.85),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: esCorrecta ? _kGreen : _kYellow,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: (esCorrecta ? _kGreen : _kYellow)
                                  .withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: _siguiente,
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _indice < _preguntas.length - 1
                                    ? 'Siguiente'
                                    : '¡Terminado!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
}

// ── Mascota ───────────────────────────────────────────────────────────────────

class _AnkiMascota extends StatelessWidget {
  final _EstadoMascota estado;
  const _AnkiMascota({required this.estado});

  String get _asset => switch (estado) {
        _EstadoMascota.normal => 'assets/semaforo_normal.png',
        _EstadoMascota.correcto => 'assets/semaforo_verde.png',
        _EstadoMascota.fallo => 'assets/semaforo_rojo.png',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.asset(
        _asset,
        key: ValueKey(_asset),
        height: 70,
        fit: BoxFit.contain,
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _AnkiQuestionCard extends StatelessWidget {
  final String enunciado;
  final String? imagen;
  final bool imagenOculta;
  final String? tema;
  const _AnkiQuestionCard({
    required this.enunciado,
    this.imagen,
    this.imagenOculta = false,
    this.tema,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/$imagen',
                height: 170,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            enunciado,
            style: const TextStyle(
              fontSize: 16,
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

class _AnkiOpcionCard extends StatelessWidget {
  final String letra;
  final String texto;
  final _EstadoOpcion estado;
  final VoidCallback? onTap;

  const _AnkiOpcionCard({
    required this.letra,
    required this.texto,
    required this.estado,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color borderColor;
    final Color textColor;
    final Color letraColor;

    switch (estado) {
      case _EstadoOpcion.correcta:
        bg = _kGreen;
        borderColor = _kGreen;
        textColor = Colors.white;
        letraColor = Colors.white;
      case _EstadoOpcion.incorrecta:
        bg = _kRed;
        borderColor = _kRed;
        textColor = Colors.white;
        letraColor = Colors.white;
      case _EstadoOpcion.neutra:
        bg = const Color(0xFFF9F9F9);
        borderColor = _kBorder;
        textColor = _kTextGrey;
        letraColor = _kTextGrey;
      case _EstadoOpcion.normal:
        bg = Colors.white;
        borderColor = _kBorder;
        textColor = _kTextDark;
        letraColor = _kTextGrey;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: letraColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letra,
                    style: TextStyle(
                      color: letraColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.35,
                    ),
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

// ── Sesión opción card ────────────────────────────────────────────────────────

class _SesionOpcion extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _SesionOpcion({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
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
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        sublabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9E9E9E), size: 20),
              ],
            ),
          ),
        ),
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
  const _ExplicacionResaltada(
      {required this.explicacion, required this.textColor});

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
        style: TextStyle(fontSize: 12, height: 1.5, color: textColor),
        children: spans,
      ),
    );
  }
}
