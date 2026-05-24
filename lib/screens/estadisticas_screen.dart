import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_resultado.dart';
import '../data/test_historial_repository.dart';

const _kYellow = Color(0xFFF5A623);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFF44336);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  int _recordRacha = 0;
  List<TestResultado> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final historial = await TestHistorialRepository.cargar();
    setState(() {
      _recordRacha = prefs.getInt('racha_record') ?? 0;
      _historial = historial.reversed.take(10).toList();
    });
  }

  Future<void> _resetear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Resetear estadísticas',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            '¿Estás seguro de que quieres borrar todas tus estadísticas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kTextGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetear',
                style: TextStyle(
                    color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('racha_record');
      await TestHistorialRepository.limpiar();
      _cargar();
    }
  }

  String _formatFecha(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year}  $hora:$min';
  }

  bool get _hayDatos => _recordRacha > 0 || _historial.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mensajeRacha = _recordRacha == 0
        ? 'Aún no has jugado al Modo Racha'
        : _recordRacha >= 20
            ? '¡Nivel experto!'
            : _recordRacha >= 10
                ? '¡Excelente nivel!'
                : _recordRacha >= 5
                    ? '¡Buen trabajo! Sigue mejorando.'
                    : 'Intenta superar tu récord';

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
          'Estadísticas',
          style: TextStyle(
              color: _kTextDark,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        actions: [
          if (_hayDatos)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: _kTextGrey),
              onPressed: _resetear,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modo Racha record ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: _kBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(
                          Icons.local_fire_department_rounded,
                          color: _kYellow,
                          size: 38),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Récord de Racha',
                    style: TextStyle(
                        color: _kTextGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recordRacha > 0 ? '$_recordRacha' : '-',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mensajeRacha,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kTextGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // ── Test history ─────────────────────────────────────────────
            if (_historial.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Últimos tests',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark),
              ),
              const SizedBox(height: 12),
              ...(_historial.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistorialItem(
                      resultado: r,
                      fecha: _formatFecha(r.fecha),
                    ),
                  ))),
            ],
            // ── Reset button ─────────────────────────────────────────────
            if (_hayDatos) ...[
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _resetear,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Resetear estadísticas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistorialItem extends StatelessWidget {
  final TestResultado resultado;
  final String fecha;
  const _HistorialItem(
      {required this.resultado, required this.fecha});

  @override
  Widget build(BuildContext context) {
    final pct = (resultado.porcentaje * 100).round();
    final color = resultado.aprobado ? _kGreen : _kRed;
    final bgColor = resultado.aprobado
        ? const Color(0xFFF1FBF1)
        : const Color(0xFFFFF0F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultado.modo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fecha,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${resultado.correctas}/${resultado.totalPreguntas}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
