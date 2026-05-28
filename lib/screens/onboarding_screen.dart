import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nivel_wizard_screen.dart';
import '../data/permiso_repository.dart';
import '../data/pais_repository.dart';
import '../data/idioma_repository.dart';
import '../models/pais.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF999999);

// ── Idiomas disponibles ───────────────────────────────────────────────────────

class _IdiomaData {
  final String codigo;
  final String nombre;
  final String bandera;
  final bool disponible;
  const _IdiomaData({
    required this.codigo,
    required this.nombre,
    required this.bandera,
    required this.disponible,
  });
}

const _idiomas = [
  _IdiomaData(codigo: 'es', nombre: 'Español', bandera: '🇪🇸', disponible: true),
  _IdiomaData(codigo: 'it', nombre: 'Italiano', bandera: '🇮🇹', disponible: true),
  _IdiomaData(codigo: 'en', nombre: 'English', bandera: '🇬🇧', disponible: false),
  _IdiomaData(codigo: 'fr', nombre: 'Français', bandera: '🇫🇷', disponible: false),
  _IdiomaData(codigo: 'ro', nombre: 'Română', bandera: '🇷🇴', disponible: false),
];

// ── Páginas del onboarding ────────────────────────────────────────────────────

class _PageData {
  final String asset;
  final String title;
  final String subtitle;
  const _PageData({required this.asset, required this.title, required this.subtitle});
}

const _pages = [
  _PageData(
    asset: 'assets/semaforo_normal.png',
    title: 'Hola, soy Viali',
    subtitle: 'Tu compañero para aprobar el teórico a la primera',
  ),
  _PageData(
    asset: 'assets/semaforo_verde.png',
    title: 'Modo Racha',
    subtitle: 'Responde preguntas seguidas sin fallar. ¿Hasta cuánto llegas?',
  ),
  _PageData(
    asset: 'assets/semaforo_normal.png',
    title: 'Test Oficial',
    subtitle: 'Simula el examen real con preguntas y ve tu progreso',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  bool _idiomaElegido = false;
  bool _paisElegido = false;
  bool _permisoElegido = false;

  Future<void> _elegirIdioma(String idioma) async {
    await IdiomaRepository.setIdioma(idioma);
    setState(() => _idiomaElegido = true);
  }

  Future<void> _elegirPais(String pais) async {
    await PaisRepository.setPais(pais);
    if (pais == 'IT') await IdiomaRepository.setIdioma('it');
    setState(() => _paisElegido = true);
  }

  Future<void> _elegirPermiso(String permiso) async {
    await PermisoRepository.setPermiso(permiso);
    setState(() => _permisoElegido = true);
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completado', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NivelWizardScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_idiomaElegido) {
      return _IdiomaSelectorScreen(onElegir: _elegirIdioma);
    }
    if (!_paisElegido) {
      return _PaisSelectorScreen(onElegir: _elegirPais);
    }
    if (!_permisoElegido) {
      return _PermisoSelectorScreen(onElegir: _elegirPermiso);
    }

    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  _DotsIndicator(count: _pages.length, current: _page),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: SizedBox(
                      key: ValueKey(isLast),
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kYellow,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          isLast ? '¡Empezar!' : 'Siguiente',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Idioma selector ───────────────────────────────────────────────────────────

class _IdiomaSelectorScreen extends StatelessWidget {
  final Future<void> Function(String idioma) onElegir;
  const _IdiomaSelectorScreen({required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Text(
                '¿En qué idioma\nquieres estudiar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Usaremos este idioma en toda la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _kGrey, height: 1.5),
              ),
              const SizedBox(height: 32),
              Flexible(
                flex: 10,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _idiomas
                        .map((idioma) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SelectorOpcion(
                                bandera: idioma.bandera,
                                titulo: idioma.nombre,
                                disponible: idioma.disponible,
                                onTap: idioma.disponible
                                    ? () => onElegir(idioma.codigo)
                                    : null,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── País selector ─────────────────────────────────────────────────────────────

class _PaisSelectorScreen extends StatelessWidget {
  final Future<void> Function(String pais) onElegir;
  const _PaisSelectorScreen({required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Text(
                '¿En qué país vas\na examinarte?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Adaptamos las preguntas y el formato del examen a cada país.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _kGrey, height: 1.5),
              ),
              const SizedBox(height: 32),
              Flexible(
                flex: 10,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: kPaises
                        .map((pais) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SelectorOpcion(
                                bandera: pais.bandera,
                                titulo: pais.nombre,
                                disponible: pais.disponible,
                                onTap: pais.disponible
                                    ? () => onElegir(pais.codigo)
                                    : null,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Opción genérica (idioma y país comparten el mismo widget) ─────────────────

class _SelectorOpcion extends StatelessWidget {
  final String bandera;
  final String titulo;
  final bool disponible;
  final VoidCallback? onTap;

  const _SelectorOpcion({
    required this.bandera,
    required this.titulo,
    required this.disponible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = disponible ? _kYellow : const Color(0xFFE0E0E0);
    final bgColor = disponible ? const Color(0xFFFFF8EE) : const Color(0xFFF9F9F9);
    final titleColor = disponible ? _kDark : _kGrey;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: disponible ? 2 : 1.5),
          ),
          child: Row(
            children: [
              Text(bandera, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
              if (disponible)
                const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 24)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Próximamente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kGrey,
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

// ── Permiso selector ──────────────────────────────────────────────────────────

class _PermisoSelectorScreen extends StatelessWidget {
  final Future<void> Function(String permiso) onElegir;
  const _PermisoSelectorScreen({required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Text(
                '¿Qué permiso\nquieres sacar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Elige el tipo de carnet que quieres preparar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _kGrey, height: 1.5),
              ),
              const Spacer(flex: 2),
              _PermisoOpcion(
                emoji: '🚗',
                titulo: 'Permiso B',
                subtitulo: 'Coche y vehículos ligeros',
                onTap: () => onElegir('B'),
              ),
              const SizedBox(height: 16),
              _PermisoOpcion(
                emoji: '🏍️',
                titulo: 'Permiso A',
                subtitulo: 'Motocicletas',
                onTap: () => onElegir('A'),
              ),
              const SizedBox(height: 16),
              _PermisoOpcion(
                emoji: '🚛',
                titulo: 'Permiso C',
                subtitulo: 'Camiones y vehículos pesados',
                onTap: () => onElegir('C'),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermisoOpcion extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _PermisoOpcion({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8EE),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kYellow, width: 2),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(fontSize: 14, color: _kGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Onboarding page ───────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Image.asset(
            data.asset,
            height: 180,
            fit: BoxFit.contain,
          ),
          const Spacer(flex: 1),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _kDark,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: _kGrey,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kYellow : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
