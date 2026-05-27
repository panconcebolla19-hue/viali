import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class NivelWizardScreen extends StatefulWidget {
  const NivelWizardScreen({super.key});

  @override
  State<NivelWizardScreen> createState() => _NivelWizardScreenState();
}

class _NivelWizardScreenState extends State<NivelWizardScreen> {
  String? _nivelSeleccionado;

  Future<void> _seleccionar(String nivel) async {
    setState(() => _nivelSeleccionado = nivel);
    await Future.delayed(const Duration(milliseconds: 250));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nivel_usuario', nivel);
    await prefs.setString('nivel_wizard_fecha', DateTime.now().toIso8601String());
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/semaforo_normal.png', height: 90),
              const SizedBox(height: 20),
              const Text(
                '¿Cuánto sabes\ndel carnet?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Te mostraremos el mejor camino\npara prepararte.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5),
              ),
              const Spacer(),
              _NivelCard(
                emoji: '🐣',
                titulo: 'Soy nuevo',
                subtitulo: 'Nunca he estudiado para el carnet',
                seleccionado: _nivelSeleccionado == 'nuevo',
                onTap: () => _seleccionar('nuevo'),
              ),
              const SizedBox(height: 12),
              _NivelCard(
                emoji: '📚',
                titulo: 'Algo sé',
                subtitulo: 'He repasado algo pero necesito practicar',
                seleccionado: _nivelSeleccionado == 'algo',
                onTap: () => _seleccionar('algo'),
              ),
              const SizedBox(height: 12),
              _NivelCard(
                emoji: '🎯',
                titulo: 'Voy avanzado',
                subtitulo: 'Conozco bien el temario, quiero afinar',
                seleccionado: _nivelSeleccionado == 'avanzado',
                onTap: () => _seleccionar('avanzado'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NivelCard extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _NivelCard({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: seleccionado ? const Color(0xFFFFF8EE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: seleccionado ? _kYellow : _kBorder,
          width: seleccionado ? 2 : 1.5,
        ),
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: seleccionado ? _kYellow : _kDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kGrey,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (seleccionado)
                  const Icon(Icons.check_circle_rounded, color: _kYellow, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
