import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/daily_streak_repository.dart';
import '../data/preguntas_repository.dart';
import '../data/pregunta_dia_repository.dart';
import '../data/anki_repository.dart';
import '../models/pregunta.dart';
import 'modo_racha_screen.dart';
import 'test_normal_screen.dart';
import 'examen_simulado_screen.dart';
import 'estadisticas_screen.dart';
import 'repaso_screen.dart';
import 'progreso_screen.dart';
import 'ajustes_screen.dart';
import 'logros_screen.dart';
import 'marcadas_screen.dart';
import 'repaso_anki_screen.dart';
import 'flashcards_screen.dart';
import 'repaso_expres_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kAmber = Color(0xFFE67E00);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

const _kMensajes = [
  '¡Vamos! Cada pregunta te acerca al carnet. 💪',
  'Un día más de práctica, un paso más cerca. 🚗',
  '¡Buenos días! Hoy es un buen día para estudiar. 🌟',
  'La constancia es la clave del éxito. ¡Tú puedes! 🔑',
  'Recuerda: la DGT no perdona los errores. ¡Practica! 🚦',
  '¡Ánimo! Cada acierto cuenta. 🎯',
  'Hoy también puedes aprender algo nuevo. 📚',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _racha = 0;
  int _ankiPendientes = 0;
  int _falladasCount = 0;
  String? _mensajeHoy;

  // Pregunta del día
  Pregunta? _preguntaDia;
  bool? _resultadoDia;
  bool _cargandoPregunta = true;

  late final AnimationController _flameCtrl;
  late final Animation<double> _flameAnim;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _flameAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );
    _cargar();
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    await Future.wait([_cargarRacha(), _cargarPreguntaDia(), _cargarMensaje(), _cargarFalladas()]);
  }

  Future<void> _cargarRacha() async {
    final r = await DailyStreakRepository.cargar();
    if (mounted) setState(() => _racha = r.streak);
  }

  Future<void> _cargarPreguntaDia() async {
    final preguntas = await PreguntasRepository.cargarPreguntas();
    final idx = PreguntaDiaRepository.indiceDelDia(preguntas.length);
    final resultado = await PreguntaDiaRepository.getResultadoHoy();
    final todosIds = preguntas.map((p) => p.id).toList();
    final pendientes = await AnkiRepository.pendientesHoy(todosIds);
    if (mounted) {
      setState(() {
        _preguntaDia = preguntas[idx];
        _resultadoDia = resultado;
        _ankiPendientes = pendientes.length;
        _cargandoPregunta = false;
      });
    }
  }

  Future<void> _cargarFalladas() async {
    final mapa = await AnkiRepository.cargar();
    final count = mapa.values.where((e) => e.totalFalladas > 0).length;
    if (mounted) setState(() => _falladasCount = count);
  }

  Future<void> _cargarMensaje() async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = _isoHoy();
    final ultima = prefs.getString('ultima_apertura_dia');
    if (ultima != hoy) {
      await prefs.setString('ultima_apertura_dia', hoy);
      final d = DateTime.now();
      final idx = (d.day + d.month) % _kMensajes.length;
      if (mounted) setState(() => _mensajeHoy = _kMensajes[idx]);
    }
  }

  String _isoHoy() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ir(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _cargarRacha();
    _cargarPreguntaDia();
    _cargarFalladas();
  }

  Future<void> _abrirPreguntaDia() async {
    if (_preguntaDia == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PreguntaDiaModal(
        pregunta: _preguntaDia!,
        yaRespondida: _resultadoDia != null,
        resultadoPrevio: _resultadoDia,
      ),
    );
    final resultado = await PreguntaDiaRepository.getResultadoHoy();
    if (mounted) setState(() => _resultadoDia = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Viali',
                    style: GoogleFonts.nunito(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _kYellow,
                      letterSpacing: -1.2,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded,
                        color: Color(0xFFBDBDBD)),
                    onPressed: () => _ir(const AjustesScreen()),
                  ),
                ],
              ),
              Center(
                child: Text(
                  'Prepara tu examen DGT',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: _StreakBadge(racha: _racha, flameAnim: _flameAnim)),
              const SizedBox(height: 10),
              Center(
                child: Image.asset(
                  'assets/semaforo_normal.png',
                  height: 76,
                  fit: BoxFit.contain,
                ),
              ),
              if (_mensajeHoy != null) ...[
                const SizedBox(height: 8),
                _MensajeMotivacional(mensaje: _mensajeHoy!),
              ],
              if (!_cargandoPregunta && _preguntaDia != null) ...[
                const SizedBox(height: 14),
                _PreguntaDiaCard(
                  pregunta: _preguntaDia!,
                  resultado: _resultadoDia,
                  onTap: _abrirPreguntaDia,
                ),
              ],
              const SizedBox(height: 24),

              // ── Sección: Practicar ────────────────────────────────────────
              _SectionLabel('PRACTICAR'),
              const SizedBox(height: 10),
              _HomeButton(
                label: 'Modo Racha',
                icon: Icons.local_fire_department_rounded,
                isPrimary: true,
                onTap: () => _ir(const ModoRachaScreen()),
              ),
              const SizedBox(height: 10),
              _HomeButton(
                label: 'Test Normal',
                icon: Icons.quiz_outlined,
                onTap: () => _ir(const TestNormalScreen()),
              ),
              const SizedBox(height: 10),
              _HomeButton(
                label: 'Examen Simulado',
                icon: Icons.assignment_outlined,
                onTap: () => _ir(const ExamenSimuladoScreen()),
              ),
              const SizedBox(height: 24),

              // ── Sección: Repasar ──────────────────────────────────────────
              _SectionLabel('REPASAR'),
              const SizedBox(height: 10),
              _RepasoInteligenteButton(
                pendientes: _ankiPendientes,
                cargando: _cargandoPregunta,
                onTap: () => _ir(const RepasoAnkiScreen()),
              ),
              const SizedBox(height: 10),
              _RepasoExpresButton(
                falladasCount: _falladasCount,
                onTap: () => _ir(const RepasoExpresScreen()),
              ),
              const SizedBox(height: 10),
              _HomeButton(
                label: 'Modo Repaso',
                icon: Icons.menu_book_rounded,
                onTap: () => _ir(const RepasoScreen()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HomeButton(
                      label: 'Flashcards',
                      icon: Icons.style_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const FlashcardsScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HomeButton(
                      label: 'Marcadas',
                      icon: Icons.bookmark_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const MarcadasScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Sección: Ver progreso ─────────────────────────────────────
              _SectionLabel('VER PROGRESO'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HomeButton(
                      label: 'Progreso',
                      icon: Icons.trending_up_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const ProgresoScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HomeButton(
                      label: 'Estadísticas',
                      icon: Icons.bar_chart_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const EstadisticasScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HomeButton(
                      label: 'Logros',
                      icon: Icons.emoji_events_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const LogrosScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: const Text(
                  'Basado en los tests oficiales de la DGT',
                  style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pregunta del día card ─────────────────────────────────────────────────────

class _PreguntaDiaCard extends StatelessWidget {
  final Pregunta pregunta;
  final bool? resultado;
  final VoidCallback onTap;

  const _PreguntaDiaCard({
    required this.pregunta,
    required this.resultado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final respondida = resultado != null;
    final correcta = resultado == true;

    Color borderColor;
    Color bgColor;
    Color iconBg;
    IconData iconData;

    if (respondida) {
      if (correcta) {
        bgColor = const Color(0xFFF1FBF1);
        borderColor = _kGreen.withValues(alpha: 0.35);
        iconBg = _kGreen;
        iconData = Icons.check_rounded;
      } else {
        bgColor = const Color(0xFFFFF0F0);
        borderColor = _kRed.withValues(alpha: 0.35);
        iconBg = _kRed;
        iconData = Icons.close_rounded;
      }
    } else {
      bgColor = const Color(0xFFFFFBEE);
      borderColor = _kYellow.withValues(alpha: 0.45);
      iconBg = _kYellow;
      iconData = Icons.today_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PREGUNTA DEL DÍA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kGrey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (respondida) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: correcta ? _kGreen : _kRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            correcta ? '✓ Correcta' : '✗ Fallada',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pregunta.enunciado,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kDark,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Pregunta del día modal (bottom sheet) ─────────────────────────────────────

class _PreguntaDiaModal extends StatefulWidget {
  final Pregunta pregunta;
  final bool yaRespondida;
  final bool? resultadoPrevio;

  const _PreguntaDiaModal({
    required this.pregunta,
    required this.yaRespondida,
    required this.resultadoPrevio,
  });

  @override
  State<_PreguntaDiaModal> createState() => _PreguntaDiaModalState();
}

class _PreguntaDiaModalState extends State<_PreguntaDiaModal> {
  late final List<int> _orden;
  late final List<String> _opciones;
  int? _seleccionada;
  bool _respondida = false;
  bool _esCorrecta = false;

  @override
  void initState() {
    super.initState();
    _orden = PreguntaDiaRepository.ordenOpciones();
    _opciones = _orden.map((i) => widget.pregunta.opciones[i]).toList();
    _respondida = widget.yaRespondida;
    if (widget.yaRespondida) {
      _esCorrecta = widget.resultadoPrevio == true;
    }
  }

  void _responder(int displayIdx) {
    if (_respondida) return;
    final idxOriginal = _orden[displayIdx];
    final ok = idxOriginal == widget.pregunta.respuestaCorrecta;
    setState(() {
      _seleccionada = displayIdx;
      _respondida = true;
      _esCorrecta = ok;
    });
    PreguntaDiaRepository.guardarResultado(ok);
  }

  int get _correctaEnDisplay =>
      _orden.indexOf(widget.pregunta.respuestaCorrecta);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today_rounded,
                        color: _kYellow, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'PREGUNTA DEL DÍA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGrey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Image.asset(
                  _respondida
                      ? (_esCorrecta
                          ? 'assets/semaforo_verde.png'
                          : 'assets/semaforo_rojo.png')
                      : 'assets/semaforo_normal.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _kBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.pregunta.enunciado,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(3, (i) {
                  final Color bg;
                  final Color border;
                  final Color text;

                  if (_respondida) {
                    if (i == _correctaEnDisplay) {
                      bg = const Color(0xFFF1FBF1);
                      border = _kGreen;
                      text = _kGreen;
                    } else if (i == _seleccionada) {
                      bg = const Color(0xFFFFF0F0);
                      border = _kRed;
                      text = _kRed;
                    } else {
                      bg = const Color(0xFFF9F9F9);
                      border = _kBorder;
                      text = _kGrey;
                    }
                  } else {
                    bg = Colors.white;
                    border = _kBorder;
                    text = _kDark;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _responder(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border, width: 1.5),
                        ),
                        child: Text(
                          _opciones[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: text,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_respondida) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _esCorrecta
                          ? const Color(0xFFF1FBF1)
                          : const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_esCorrecta ? _kGreen : _kRed)
                            .withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _esCorrecta ? '¡Correcto!' : 'Respuesta incorrecta',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _esCorrecta ? _kGreen : _kRed,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.pregunta.explicacion,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: (_esCorrecta ? _kGreen : _kRed)
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (widget.yaRespondida)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: const Text(
                      'Ya respondiste la pregunta de hoy. ¡Vuelve mañana!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: _kGrey, height: 1.4),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mensaje motivacional ──────────────────────────────────────────────────────

class _MensajeMotivacional extends StatelessWidget {
  final String mensaje;
  const _MensajeMotivacional({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _kGrey,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Streak badge ──────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int racha;
  final Animation<double> flameAnim;
  const _StreakBadge({required this.racha, required this.flameAnim});

  @override
  Widget build(BuildContext context) {
    if (racha == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '🚦 Empieza tu racha hoy',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kGrey,
          ),
        ),
      );
    }

    final label = racha == 1 ? '1 día seguido' : '$racha días seguidos';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kYellow.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: flameAnim,
            builder: (_, child) => Transform.scale(
              scale: flameAnim.value,
              child: child,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kYellow,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kGrey,
        letterSpacing: 0.9,
      ),
    );
  }
}

// ── Repaso Inteligente button (always visible) ─────────────────────────────────

class _RepasoInteligenteButton extends StatelessWidget {
  final int pendientes;
  final bool cargando;
  final VoidCallback onTap;

  const _RepasoInteligenteButton({
    required this.pendientes,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hayPendientes = !cargando && pendientes > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: hayPendientes ? const Color(0xFFFFFBEE) : Colors.white,
        border: Border.all(
          color: hayPendientes
              ? _kYellow.withValues(alpha: 0.6)
              : _kBorder,
          width: 1.8,
        ),
        boxShadow: hayPendientes
            ? [
                BoxShadow(
                  color: _kYellow.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: hayPendientes ? _kYellow : _kGrey,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repaso Inteligente',
                        style: TextStyle(
                          color: hayPendientes ? _kDark : _kGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cargando
                            ? 'Cargando…'
                            : pendientes > 0
                                ? '$pendientes ${pendientes == 1 ? 'pregunta pendiente' : 'preguntas pendientes'} hoy'
                                : '0 pendientes hoy — vuelve mañana',
                        style: TextStyle(
                          color: hayPendientes ? _kYellow : _kGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: hayPendientes ? _kGrey : const Color(0xFFDDDDDD),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Repaso Exprés button ──────────────────────────────────────────────────────

class _RepasoExpresButton extends StatelessWidget {
  final int falladasCount;
  final VoidCallback onTap;

  const _RepasoExpresButton({required this.falladasCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [_kYellow, _kAmber],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kYellow.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Repaso Exprés',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (falladasCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$falladasCount falladas',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Para el día antes del examen',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Home button ───────────────────────────────────────────────────────────────

class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  final double fontSize;

  const _HomeButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isPrimary ? _kYellow : Colors.white,
        border: isPrimary ? null : Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? _kYellow.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isPrimary ? 18 : 8,
            offset: const Offset(0, 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : _kDark,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPrimary ? Colors.white : _kDark,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.7)
                      : const Color(0xFFBDBDBD),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
