import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/daily_streak_repository.dart';
import 'modo_racha_screen.dart';
import 'test_normal_screen.dart';
import 'estadisticas_screen.dart';
import 'repaso_screen.dart';
import 'progreso_screen.dart';
import 'ajustes_screen.dart';

const _kYellow = Color(0xFFF5A623);
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

  @override
  void initState() {
    super.initState();
    _cargarRacha();
  }

  Future<void> _cargarRacha() async {
    final r = await DailyStreakRepository.cargar();
    if (mounted) setState(() => _racha = r.streak);
  }

  Future<void> _ir(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _cargarRacha();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Color(0xFFBDBDBD)),
                  onPressed: () => _ir(const AjustesScreen()),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Viali',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _kYellow,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Prepara tu examen DGT',
                style: TextStyle(
                  fontSize: 15,
                  color: _kGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),
              _StreakBadge(racha: _racha),
              const SizedBox(height: 14),
              Image.asset(
                'assets/semaforo_normal.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              _HomeButton(
                label: 'Modo Racha',
                icon: Icons.local_fire_department_rounded,
                isPrimary: true,
                onTap: () => _ir(const ModoRachaScreen()),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                label: 'Test Normal',
                icon: Icons.quiz_outlined,
                onTap: () => _ir(const TestNormalScreen()),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                label: 'Modo Repaso',
                icon: Icons.menu_book_rounded,
                onTap: () => _ir(const RepasoScreen()),
              ),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeButton(
                      label: 'Estadísticas',
                      icon: Icons.bar_chart_rounded,
                      fontSize: 13,
                      onTap: () => _ir(const EstadisticasScreen()),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'Basado en los tests oficiales de la DGT',
                style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Streak badge ──────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int racha;
  const _StreakBadge({required this.racha});

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
          const Text('🔥', style: TextStyle(fontSize: 18)),
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
