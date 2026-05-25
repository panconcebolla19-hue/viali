import 'package:flutter/material.dart';
import '../data/marcadas_repository.dart';
import '../data/preguntas_repository.dart';
import '../models/pregunta.dart';

const _kYellow = Color(0xFFF5A623);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFE53935);

class MarcadasScreen extends StatefulWidget {
  const MarcadasScreen({super.key});

  @override
  State<MarcadasScreen> createState() => _MarcadasScreenState();
}

class _MarcadasScreenState extends State<MarcadasScreen> {
  List<Pregunta> _marcadas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todas = await PreguntasRepository.cargarPreguntas();
    final ids = await MarcadasRepository.cargar();
    if (mounted) {
      setState(() {
        _marcadas = todas.where((p) => ids.contains(p.id)).toList();
        _cargando = false;
      });
    }
  }

  Future<void> _desmarcar(int id) async {
    await MarcadasRepository.alternar(id);
    if (mounted) {
      setState(() {
        _marcadas.removeWhere((p) => p.id == id);
      });
    }
  }

  void _abrirModal(Pregunta p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarcadaModal(
        pregunta: p,
        onDesmarcar: () {
          Navigator.pop(context);
          _desmarcar(p.id);
        },
      ),
    );
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
          'Preguntas marcadas',
          style: TextStyle(
              color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : _marcadas.isEmpty
              ? _buildVacio()
              : _buildLista(),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border_rounded,
                size: 72, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 20),
            const Text(
              'Sin preguntas marcadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pulsa el icono 🚩 en cualquier pregunta para marcarla y repasarla aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kTextGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '${_marcadas.length} ${_marcadas.length == 1 ? 'pregunta' : 'preguntas'}',
            style: const TextStyle(
                fontSize: 13, color: _kTextGrey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: _marcadas.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _MarcadaTile(
              pregunta: _marcadas[i],
              onTap: () => _abrirModal(_marcadas[i]),
              onDesmarcar: () => _desmarcar(_marcadas[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarcadaTile extends StatelessWidget {
  final Pregunta pregunta;
  final VoidCallback onTap;
  final VoidCallback onDesmarcar;

  const _MarcadaTile({
    required this.pregunta,
    required this.onTap,
    required this.onDesmarcar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  color: _kYellow, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pregunta.enunciado,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kTextDark,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDesmarcar,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.bookmark_remove_rounded,
                      color: Colors.grey[400], size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarcadaModal extends StatefulWidget {
  final Pregunta pregunta;
  final VoidCallback onDesmarcar;

  const _MarcadaModal({required this.pregunta, required this.onDesmarcar});

  @override
  State<_MarcadaModal> createState() => _MarcadaModalState();
}

class _MarcadaModalState extends State<_MarcadaModal> {
  int? _seleccion;
  bool _revelado = false;

  void _seleccionar(int idx) {
    if (_revelado) return;
    setState(() {
      _seleccion = idx;
      _revelado = true;
    });
  }

  Color _colorOpcion(int idx) {
    if (!_revelado) {
      return _seleccion == idx
          ? _kYellow.withValues(alpha: 0.12)
          : Colors.white;
    }
    if (idx == widget.pregunta.respuestaCorrecta) return _kGreen.withValues(alpha: 0.12);
    if (idx == _seleccion) return _kRed.withValues(alpha: 0.10);
    return Colors.white;
  }

  Color _borderOpcion(int idx) {
    if (!_revelado) {
      return _seleccion == idx ? _kYellow : _kBorder;
    }
    if (idx == widget.pregunta.respuestaCorrecta) return _kGreen;
    if (idx == _seleccion) return _kRed;
    return _kBorder;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pregunta;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark_rounded,
                            color: _kYellow, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Pregunta marcada',
                          style: TextStyle(
                              fontSize: 12,
                              color: _kTextGrey,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: widget.onDesmarcar,
                          icon: const Icon(Icons.bookmark_remove_rounded,
                              size: 16),
                          label: const Text('Desmarcar'),
                          style: TextButton.styleFrom(
                            foregroundColor: _kTextGrey,
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (p.imagen != null && !p.imagenOculta) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/${p.imagen}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      p.enunciado,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(p.opciones.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _seleccionar(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _colorOpcion(i),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: _borderOpcion(i), width: 1.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _revelado && i == p.respuestaCorrecta
                                        ? _kGreen
                                        : _revelado && i == _seleccion
                                            ? _kRed
                                            : _seleccion == i
                                                ? _kYellow
                                                : const Color(0xFFEEEEEE),
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + i),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: (_revelado &&
                                                  i == p.respuestaCorrecta) ||
                                              (_revelado && i == _seleccion) ||
                                              _seleccion == i
                                          ? Colors.white
                                          : _kTextGrey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.opciones[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _revelado && i == p.respuestaCorrecta
                                          ? _kGreen
                                          : _revelado && i == _seleccion
                                              ? _kRed
                                              : _kTextDark,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (_revelado && i == p.respuestaCorrecta)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _kGreen, size: 20)
                                else if (_revelado && i == _seleccion)
                                  const Icon(Icons.cancel_rounded,
                                      color: _kRed, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_revelado) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: _kTextGrey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.explicacion,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _kTextGrey,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _seleccion = null;
                            _revelado = false;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: _kYellow,
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          child: const Text('Intentar de nuevo'),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Selecciona una opción para ver la respuesta',
                          style: TextStyle(fontSize: 12, color: _kTextGrey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
