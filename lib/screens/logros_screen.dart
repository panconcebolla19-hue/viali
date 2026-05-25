import 'package:flutter/material.dart';
import '../data/logros_repository.dart';
import '../widgets/confetti_overlay.dart';

const _kYellow = Color(0xFFF5A623);
const _kGold = Color(0xFFFFD600);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class LogrosScreen extends StatefulWidget {
  const LogrosScreen({super.key});

  @override
  State<LogrosScreen> createState() => _LogrosScreenState();
}

class _LogrosScreenState extends State<LogrosScreen> {
  List<Logro> _logros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final logros = await LogrosRepository.cargar();
    if (mounted) {
      setState(() {
        _logros = logros;
        _cargando = false;
      });
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
          'Logros',
          style: TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final conseguidos = _logros.where((l) => l.conseguido).length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              '$conseguidos de ${_logros.length} desbloqueados',
              style: const TextStyle(
                fontSize: 14,
                color: _kTextGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.80,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _LogroTile(logro: _logros[i]),
              childCount: _logros.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogroTile extends StatelessWidget {
  final Logro logro;
  const _LogroTile({required this.logro});

  @override
  Widget build(BuildContext context) {
    final got = logro.conseguido;
    return GestureDetector(
      onTap: got ? () => _showDetail(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: got ? const Color(0xFFFFFBEE) : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: got ? _kYellow.withValues(alpha: 0.5) : _kBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              logro.def.icono,
              size: 36,
              color: got ? _kGold : const Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 8),
            Text(
              logro.def.nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: got ? _kTextDark : const Color(0xFFBDBDBD),
                height: 1.3,
              ),
            ),
            if (got && logro.fechaConseguido != null) ...[
              const SizedBox(height: 4),
              Text(
                _fmt(logro.fechaConseguido!),
                style: const TextStyle(fontSize: 9, color: _kTextGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(logro.def.icono, color: _kGold, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(logro.def.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(logro.def.descripcion,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            if (logro.fechaConseguido != null) ...[
              const SizedBox(height: 12),
              Text(
                'Conseguido el ${_fmt(logro.fechaConseguido!)}',
                style: const TextStyle(fontSize: 12, color: _kTextGrey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(
                    color: _kYellow, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

Future<void> mostrarLogroPopup(
    BuildContext context, LogroDefinicion logro) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, animation, secondaryAnimation) => _LogroPopup(logro: logro),
  );
}

class _LogroPopup extends StatefulWidget {
  final LogroDefinicion logro;
  const _LogroPopup({required this.logro});

  @override
  State<_LogroPopup> createState() => _LogroPopupState();
}

class _LogroPopupState extends State<_LogroPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 2800), vsync: this);
    _particles = generateConfettiParticles(count: 60);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.logro.icono, color: _kGold, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    '¡LOGRO DESBLOQUEADO!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kTextGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.logro.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.logro.descripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                              '¡Genial!',
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
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => CustomPaint(
                painter: ConfettiPainter(
                  progress: _ctrl.value,
                  particles: _particles,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
