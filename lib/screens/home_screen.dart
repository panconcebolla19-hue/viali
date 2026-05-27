import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/daily_streak_repository.dart';
import '../data/falladas_repository.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _racha = 0;
  int _ankiPendientes = 0;
  int _falladasCount = 0;
  int _totalPreguntas = 0;

  Pregunta? _preguntaDia;
  bool? _resultadoDia;
  bool _cargandoPregunta = true;

  String? _nivelUsuario;
  int _diasDesdeWizard = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([_cargarRacha(), _cargarPreguntaDia(), _cargarExtras()]);
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

  Future<void> _cargarExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final falladasIds = await FalladasRepository.cargar();
    final nivel = prefs.getString('nivel_usuario');
    final wizardFechaStr = prefs.getString('nivel_wizard_fecha');
    int diasDesde = 0;
    if (wizardFechaStr != null) {
      final wizardFecha = DateTime.tryParse(wizardFechaStr);
      if (wizardFecha != null) {
        diasDesde = DateTime.now().difference(wizardFecha).inDays;
      }
    }
    if (mounted) {
      setState(() {
        _falladasCount = falladasIds.length;
        _totalPreguntas = prefs.getInt('preguntas_total') ?? 0;
        _nivelUsuario = nivel;
        _diasDesdeWizard = diasDesde;
      });
    }
  }

  Future<void> _ir(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _cargarRacha();
    _cargarPreguntaDia();
    _cargarExtras();
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

  Future<void> _abrirSeleccionTema() async {
    await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SeleccionTemaSheet(
        onTemaSeleccionado: (tema) {
          Navigator.pop(ctx);
          _ir(RepasoExpresScreen(temaInicial: tema));
        },
      ),
    );
  }

  bool get _mostrarRutaHoy =>
      _nivelUsuario == 'nuevo' && _diasDesdeWizard < 21;

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _kYellow,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => _ir(const AjustesScreen()),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Viali',
                        style: GoogleFonts.nunito(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => _ir(const LogrosScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PillBadge(
                    text: _racha == 0 ? '🚦 Empieza hoy' : '🔥 $_racha días',
                  ),
                  const SizedBox(width: 10),
                  _PillBadge(text: '📚 $_totalPreguntas respondidas'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_cargandoPregunta && _preguntaDia != null) ...[
                    _PreguntaDiaCard(
                      pregunta: _preguntaDia!,
                      resultado: _resultadoDia,
                      onTap: _abrirPreguntaDia,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_mostrarRutaHoy) ...[
                    _RutaHoyCard(
                      diasDesdeInicio: _diasDesdeWizard,
                      onTap: () {
                        if (_diasDesdeWizard < 7) {
                          _ir(const TestNormalScreen());
                        } else if (_diasDesdeWizard < 14) {
                          _ir(const RepasoExpresScreen());
                        } else {
                          _ir(const ExamenSimuladoScreen());
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  _ModoRachaButton(onTap: () => _ir(const ModoRachaScreen())),
                  const SizedBox(height: 28),
                  const _SectionTitle('PRACTICAR'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _PracticarCard(
                          label: 'Test Normal',
                          icon: Icons.quiz_outlined,
                          onTap: () => _ir(const TestNormalScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PracticarCard(
                          label: 'Examen Simulado',
                          icon: Icons.assignment_outlined,
                          onTap: () => _ir(const ExamenSimuladoScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('REPASAR'),
                  const SizedBox(height: 4),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _RepasoCard(
                        label: 'Repaso Inteligente',
                        icon: Icons.auto_stories_rounded,
                        badge: _ankiPendientes > 0 ? '$_ankiPendientes' : null,
                        onTap: () => _ir(const RepasoAnkiScreen()),
                      ),
                      _RepasoCard(
                        label: 'Repaso Exprés',
                        icon: Icons.bolt_rounded,
                        badge: _falladasCount > 0
                            ? '$_falladasCount falladas'
                            : null,
                        onTap: () => _ir(const RepasoExpresScreen()),
                      ),
                      _RepasoCard(
                        label: 'Flashcards',
                        icon: Icons.style_rounded,
                        onTap: () => _ir(const FlashcardsScreen()),
                      ),
                      _RepasoCard(
                        label: 'Modo Repaso',
                        icon: Icons.menu_book_rounded,
                        onTap: () => _ir(const RepasoScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EstudiarTemaTile(onTap: _abrirSeleccionTema),
                  const SizedBox(height: 8),
                  _MarcadasTile(onTap: () => _ir(const MarcadasScreen())),
                  const SizedBox(height: 28),
                  const _SectionTitle('VER PROGRESO'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _ProgresoCard(
                          label: 'Progreso',
                          icon: Icons.trending_up_rounded,
                          onTap: () => _ir(const ProgresoScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProgresoCard(
                          label: 'Estadísticas',
                          icon: Icons.bar_chart_rounded,
                          onTap: () => _ir(const EstadisticasScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProgresoCard(
                          label: 'Logros',
                          icon: Icons.emoji_events_rounded,
                          onTap: () => _ir(const LogrosScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Basado en los tests oficiales de la DGT',
                      style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill badge ────────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String text;
  const _PillBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _kDark,
      ),
    );
  }
}

// ── Modo Racha hero button ────────────────────────────────────────────────────

class _ModoRachaButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ModoRachaButton({required this.onTap});

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
            blurRadius: 20,
            offset: const Offset(0, 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Racha',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Responde seguidas sin fallar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Practicar card (2-col grid) ───────────────────────────────────────────────

class _PracticarCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PracticarCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _kYellow, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Repaso card (2×2 grid) ────────────────────────────────────────────────────

class _RepasoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _RepasoCard({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _kYellow, size: 20),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kYellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kDark,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Marcadas tile ─────────────────────────────────────────────────────────────

class _MarcadasTile extends StatelessWidget {
  final VoidCallback onTap;
  const _MarcadasTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.bookmark_rounded, color: _kYellow, size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Marcadas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Progreso card (row of 3) ──────────────────────────────────────────────────

class _ProgresoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ProgresoCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kYellow, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ruta hoy card ─────────────────────────────────────────────────────────────

class _RutaHoyCard extends StatelessWidget {
  final int diasDesdeInicio;
  final VoidCallback onTap;
  const _RutaHoyCard({required this.diasDesdeInicio, required this.onTap});

  String get _titulo {
    if (diasDesdeInicio < 7) return 'Semana 1: Descúbrete';
    if (diasDesdeInicio < 14) return 'Semana 2: Refuerza lo fallado';
    return 'Semana 3: Simula el examen';
  }

  String get _subtitulo {
    if (diasDesdeInicio < 7) return 'Empieza con un Test Normal para ver tu nivel real.';
    if (diasDesdeInicio < 14) return 'Repasa con Exprés las preguntas que más te cuestan.';
    return 'Simula el examen oficial y comprueba si estás listo.';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8EE), Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE0A0), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🗺️', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TU RUTA DE HOY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitulo,
                    style: const TextStyle(
                        fontSize: 12, color: _kGrey, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Estudiar por tema tile ────────────────────────────────────────────────────

class _EstudiarTemaTile extends StatelessWidget {
  final VoidCallback onTap;
  const _EstudiarTemaTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.category_rounded, color: _kYellow, size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Estudiar por tema',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _kGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Selección tema bottom sheet ───────────────────────────────────────────────

class _SeleccionTemaSheet extends StatelessWidget {
  final void Function(String? tema) onTemaSeleccionado;
  const _SeleccionTemaSheet({required this.onTemaSeleccionado});

  static const _temas = [
    (null, 'Todas las temáticas', '📚'),
    ('señales', 'Señales', '🚦'),
    ('velocidad', 'Velocidad', '🚀'),
    ('alcohol', 'Alcohol/Drogas', '🍺'),
    ('adelantamientos', 'Adelantamientos', '🔀'),
    ('distancias', 'Distancias', '📏'),
    ('autopista', 'Autopistas', '🛣️'),
    ('medio_ambiente', 'Medio ambiente', '🌱'),
    ('documentacion', 'Documentación', '📋'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Estudiar por tema',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona una temática para el Repaso Exprés.',
            style: TextStyle(fontSize: 13, color: _kGrey),
          ),
          const SizedBox(height: 16),
          ..._temas.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFFFF8EE),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onTemaSeleccionado(t.$1),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(t.$3, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            t.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: _kGrey, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      bgColor = const Color(0xFFFFF8EE);
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
                    const Icon(Icons.today_rounded, color: _kYellow, size: 18),
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
                      style: TextStyle(fontSize: 13, color: _kGrey, height: 1.4),
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
