import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/pregunta.dart';
import '../data/preguntas_repository.dart';
import '../data/falladas_repository.dart';
import '../data/test_historial_repository.dart';
import '../data/anki_repository.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);
const _kGreen = Color(0xFF2ECC40);
const _kGreenBg = Color(0xFFF0FFF4);
const _kRedBg = Color(0xFFFFF0F0);
const _kRed = Color(0xFFFF3B30);

enum _EstadoMascota { normal, correcto, fallo }

enum _EstadoOpcion { normal, correcta, incorrecta, neutra }

class RepasoScreen extends StatefulWidget {
  const RepasoScreen({super.key});

  @override
  State<RepasoScreen> createState() => _RepasoScreenState();
}

class _RepasoScreenState extends State<RepasoScreen> {
  bool _cargando = true;
  List<Pregunta> _preguntas = [];

  int _indice = 0;
  List<String> _opcionesMezcladas = [];
  List<int> _mapaIndices = [];
  int? _respuestaSeleccionada;
  bool _respondida = false;
  _EstadoMascota _estadoMascota = _EstadoMascota.normal;
  int _correctas = 0;
  bool _finalizado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todasPreguntas = await PreguntasRepository.cargarPreguntas();
    final falladasRacha = await FalladasRepository.cargar();
    final falladasHistorial = await TestHistorialRepository.idsPreguntasFalladas();
    final todasFalladas = {...falladasRacha, ...falladasHistorial};

    final seleccionadas = todasPreguntas
        .where((p) => todasFalladas.contains(p.id))
        .toList()
      ..shuffle(Random());

    setState(() {
      _preguntas = seleccionadas;
      _cargando = false;
    });

    if (seleccionadas.isNotEmpty) _prepararPregunta();
  }

  void _prepararPregunta() {
    final p = _preguntas[_indice];
    final indices = List.generate(p.opciones.length, (i) => i)..shuffle(Random());
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
    final indiceOriginal = _mapaIndices[opcionDisplay];
    final ok = indiceOriginal == p.respuestaCorrecta;
    setState(() {
      _respuestaSeleccionada = opcionDisplay;
      _respondida = true;
      _estadoMascota = ok ? _EstadoMascota.correcto : _EstadoMascota.fallo;
      if (ok) _correctas++;
    });
    unawaited(AnkiRepository.registrarRespuesta(p.id, ok));
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
        title: const Text('Modo Repaso'),
        bottom: _preguntas.isNotEmpty && !_cargando && !_finalizado
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_indice + (_respondida ? 1 : 0)) / _preguntas.length,
                  backgroundColor: _kBorder,
                  valueColor: const AlwaysStoppedAnimation(_kYellow),
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _preguntas.isEmpty
              ? _EmptyState()
              : _finalizado
                  ? _FinalState(
                      correctas: _correctas,
                      total: _preguntas.length,
                      onReintentar: () {
                        setState(() {
                          _indice = 0;
                          _correctas = 0;
                          _finalizado = false;
                        });
                        _preguntas.shuffle(Random());
                        _prepararPregunta();
                      },
                    )
                  : _buildQuiz(),
    );
  }

  Widget _buildQuiz() {
    final p = _preguntas[_indice];
    final correctaEnDisplay =
        _respondida ? _mapaIndices.indexOf(p.respuestaCorrecta) : -1;

    return SafeArea(
      child: Column(
        children: [
          _Mascota(estado: _estadoMascota),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_indice + 1} / ${_preguntas.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    enunciado: p.enunciado,
                    imagen: p.imagen,
                    imagenOculta: p.imagenOculta,
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
                    _ExplicacionCard(
                      correcta: p.opciones[p.respuestaCorrecta],
                      explicacion: p.explicacion,
                      esCorrecta: _mapaIndices[_respuestaSeleccionada!] == p.respuestaCorrecta,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _siguiente,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kYellow,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _indice < _preguntas.length - 1 ? 'Continuar' : 'Ver resultado',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/semaforo_verde.png', height: 140),
            const SizedBox(height: 28),
            const Text(
              '¡Aún no has fallado ninguna!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sigue practicando en Modo Racha o Test Normal y aquí aparecerán las preguntas que hayas fallado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Final state ────────────────────────────────────────────────────────────────

class _FinalState extends StatelessWidget {
  final int correctas;
  final int total;
  final VoidCallback onReintentar;

  const _FinalState({
    required this.correctas,
    required this.total,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? correctas / total : 0.0;
    final asset =
        pct >= 0.8 ? 'assets/semaforo_verde.png' : 'assets/semaforo_rojo.png';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(asset, height: 140),
            const SizedBox(height: 28),
            const Text(
              '¡Repaso completado!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$correctas / $total correctas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kGrey,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onReintentar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kYellow,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Repetir repaso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      child: Image.asset(
        _asset,
        key: ValueKey(_asset),
        height: 72,
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
  const _QuestionCard({
    required this.enunciado,
    this.imagen,
    this.imagenOculta = false,
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
          if (imagen != null && !imagenOculta) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SvgPicture.asset(imagen!, height: 170, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            enunciado,
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

// ── Opción card ───────────────────────────────────────────────────────────────

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
    final (bg, border, textColor, letraColor) = switch (estado) {
      _EstadoOpcion.correcta => (_kGreenBg, _kGreen, _kDark, _kGreen),
      _EstadoOpcion.incorrecta => (_kRedBg, _kRed, _kDark, _kRed),
      _EstadoOpcion.neutra => (
          const Color(0xFFF8F8F8),
          _kBorder,
          _kGrey,
          _kGrey
        ),
      _EstadoOpcion.normal => (Colors.white, _kBorder, _kDark, _kYellow),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: letraColor.withValues(alpha: 0.12),
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
    );
  }
}

// ── Explicación card ──────────────────────────────────────────────────────────

class _ExplicacionCard extends StatelessWidget {
  final String correcta;
  final String explicacion;
  final bool esCorrecta;

  const _ExplicacionCard({
    required this.correcta,
    required this.explicacion,
    required this.esCorrecta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esCorrecta ? _kGreenBg : _kRedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esCorrecta ? _kGreen : _kRed,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esCorrecta ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: esCorrecta ? _kGreen : _kRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                esCorrecta ? '¡Correcto!' : 'Respuesta correcta:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: esCorrecta ? _kGreen : _kRed,
                ),
              ),
            ],
          ),
          if (!esCorrecta) ...[
            const SizedBox(height: 6),
            Text(
              correcta,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kGreen,
                height: 1.35,
              ),
            ),
          ],
          if (explicacion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explicacion,
              style: const TextStyle(
                fontSize: 12,
                color: _kDark,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
