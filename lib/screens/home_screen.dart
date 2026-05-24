import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'modo_racha_screen.dart';
import 'test_normal_screen.dart';
import 'estadisticas_screen.dart';
import 'repaso_screen.dart';
import 'progreso_screen.dart';
import 'ajustes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AjustesScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Viali',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF5A623),
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Prepara tu examen DGT',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 28),
              Image.asset(
                'assets/semaforo_normal.png',
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              _HomeButton(
                label: 'Modo Racha',
                icon: Icons.local_fire_department_rounded,
                isPrimary: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModoRachaScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                label: 'Test Normal',
                icon: Icons.quiz_outlined,
                isPrimary: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestNormalScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                label: 'Modo Repaso',
                icon: Icons.menu_book_rounded,
                isPrimary: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RepasoScreen()),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HomeButton(
                      label: 'Progreso',
                      icon: Icons.trending_up_rounded,
                      isPrimary: false,
                      fontSize: 13,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProgresoScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeButton(
                      label: 'Estadísticas',
                      icon: Icons.bar_chart_rounded,
                      isPrimary: false,
                      fontSize: 13,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EstadisticasScreen()),
                      ),
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

class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  final double fontSize;

  const _HomeButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isPrimary ? const Color(0xFFF5A623) : Colors.white,
        border: isPrimary
            ? null
            : Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFFF5A623).withValues(alpha: 0.28)
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
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : const Color(0xFF1A1A1A),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isPrimary ? Colors.white : const Color(0xFF1A1A1A),
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
