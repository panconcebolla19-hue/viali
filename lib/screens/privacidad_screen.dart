import 'package:flutter/material.dart';

const _kDark = Color(0xFF1A1A1A);
const _kBody = Color(0xFF555555);
const _kBorder = Color(0xFFE8E8E8);

class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Política de privacidad',
          style: TextStyle(color: _kDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              titulo: 'Última actualización',
              contenido: 'Mayo de 2026',
            ),
            _Section(
              titulo: '¿Qué datos recopila Viali?',
              contenido:
                  'Viali no recopila ningún dato personal. '
                  'Toda la información generada al usar la app — '
                  'historial de tests, preguntas falladas y racha récord — '
                  'se almacena exclusivamente en tu dispositivo, '
                  'de forma local y privada.',
            ),
            _Section(
              titulo: '¿Hay servidores o conexión a Internet?',
              contenido:
                  'No. Viali funciona completamente sin conexión a Internet. '
                  'Las preguntas, las imágenes y todos los recursos de la app '
                  'están incluidos dentro de la propia aplicación. '
                  'No se realiza ninguna comunicación con servidores externos.',
            ),
            _Section(
              titulo: '¿Se comparten datos con terceros?',
              contenido:
                  'No. Viali no comparte ningún dato con terceros. '
                  'La app no utiliza servicios de analítica, publicidad '
                  'ni rastreo de ningún tipo.',
            ),
            _Section(
              titulo: 'Notificaciones',
              contenido:
                  'Si activas el recordatorio diario, la app programa una '
                  'notificación local en tu dispositivo. '
                  'Esta notificación no requiere conexión a Internet '
                  'y no envía ningún dato fuera de tu dispositivo.',
            ),
            _Section(
              titulo: 'Almacenamiento local',
              contenido:
                  'Viali usa SharedPreferences de Android para guardar '
                  'tu progreso, historial y preferencias de forma local. '
                  'Estos datos desaparecen al desinstalar la aplicación '
                  'y en ningún momento salen de tu dispositivo.',
            ),
            _Section(
              titulo: 'Contacto',
              contenido:
                  'Si tienes alguna pregunta sobre esta política de privacidad '
                  'puedes escribirnos a: hola@viali.app',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titulo;
  final String contenido;
  const _Section({required this.titulo, required this.contenido});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 1.5),
            ),
            child: Text(
              contenido,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _kBody,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
