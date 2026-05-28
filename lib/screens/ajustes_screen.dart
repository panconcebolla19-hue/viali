import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../data/permiso_repository.dart';
import '../data/pais_repository.dart';
import '../data/idioma_repository.dart';
import '../models/pais.dart';
import 'privacidad_screen.dart';
import 'onboarding_screen.dart';

const _kYellow = Color(0xFFF5A623);
const _kDark = Color(0xFF1A1A1A);
const _kGrey = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  bool _cargando = true;
  bool _notifEnabled = false;
  TimeOfDay _hora = const TimeOfDay(hour: 19, minute: 0);
  bool _guardando = false;
  String _permiso = 'B';
  String _pais = 'ES';
  String _idioma = 'es';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final enabled = await NotificationService.isEnabled();
    final hora = await NotificationService.getTime();
    final permiso = await PermisoRepository.getPermiso();
    final pais = await PaisRepository.getPais();
    final idioma = await IdiomaRepository.getIdioma();
    setState(() {
      _notifEnabled = enabled;
      _hora = hora;
      _permiso = permiso;
      _pais = pais;
      _idioma = idioma;
      _cargando = false;
    });
  }

  Future<void> _toggleNotif(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa los permisos de notificación en Ajustes del sistema.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await NotificationService.enable(_hora.hour, _hora.minute);
    } else {
      await NotificationService.disable();
    }
    setState(() => _notifEnabled = value);
  }

  Future<void> _cambiarHora() async {
    final nueva = await showTimePicker(
      context: context,
      initialTime: _hora,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kYellow),
        ),
        child: child!,
      ),
    );
    if (nueva == null) return;
    setState(() => _hora = nueva);
    if (_notifEnabled) {
      await NotificationService.enable(nueva.hour, nueva.minute);
    }
  }

  Future<void> _resetearOnboarding() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Ver onboarding ahora?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Se borrará la marca de "completado" y se abrirá la pantalla de bienvenida ahora mismo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ver ahora',
              style: TextStyle(color: _kYellow, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completado');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  Future<void> _cambiarIdioma() async {
    final opciones = [
      _DialogOpcion(codigo: 'es', bandera: '🇪🇸', label: 'Español', disponible: true),
      _DialogOpcion(codigo: 'it', bandera: '🇮🇹', label: 'Italiano', disponible: true),
      _DialogOpcion(codigo: 'en', bandera: '🇬🇧', label: 'English', disponible: false),
      _DialogOpcion(codigo: 'fr', bandera: '🇫🇷', label: 'Français', disponible: false),
      _DialogOpcion(codigo: 'ro', bandera: '🇷🇴', label: 'Română', disponible: false),
    ];
    final nuevo = await _mostrarDialogOpciones(
      titulo: '¿En qué idioma quieres estudiar?',
      opciones: opciones,
      seleccionado: _idioma,
    );
    if (nuevo == null || nuevo == _idioma) return;
    await IdiomaRepository.setIdioma(nuevo);
    setState(() => _idioma = nuevo);
  }

  Future<void> _cambiarPais() async {
    final opciones = kPaises
        .map((p) => _DialogOpcion(
              codigo: p.codigo,
              bandera: p.bandera,
              label: p.nombre,
              disponible: p.disponible,
            ))
        .toList();
    final nuevo = await _mostrarDialogOpciones(
      titulo: '¿En qué país vas a examinarte?',
      opciones: opciones,
      seleccionado: _pais,
    );
    if (nuevo == null || nuevo == _pais) return;
    await PaisRepository.setPais(nuevo);
    if (nuevo == 'IT') {
      await IdiomaRepository.setIdioma('it');
      setState(() { _pais = nuevo; _idioma = 'it'; });
    } else if (_idioma == 'it') {
      await IdiomaRepository.setIdioma('es');
      setState(() { _pais = nuevo; _idioma = 'es'; });
    } else {
      setState(() => _pais = nuevo);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('País cambiado a ${paisPorCodigo(nuevo).nombre}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String?> _mostrarDialogOpciones({
    required String titulo,
    required List<_DialogOpcion> opciones,
    required String seleccionado,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: opciones.map((o) {
            final activo = o.codigo == seleccionado;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OpcionDialogTile(
                opcion: o,
                activo: activo,
                onTap: o.disponible ? () => Navigator.pop(ctx, o.codigo) : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _kGrey)),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarPermiso() async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Qué permiso quieres estudiar?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PermisoDialogOpcion(
              emoji: '🚗',
              label: 'Permiso B — Coche',
              activo: _permiso == 'B',
              onTap: () => Navigator.pop(ctx, 'B'),
            ),
            const SizedBox(height: 10),
            _PermisoDialogOpcion(
              emoji: '🏍️',
              label: 'Permiso A — Moto',
              activo: _permiso == 'A',
              onTap: () => Navigator.pop(ctx, 'A'),
            ),
            const SizedBox(height: 10),
            _PermisoDialogOpcion(
              emoji: '🚛',
              label: 'Permiso C — Camión',
              activo: _permiso == 'C',
              onTap: () => Navigator.pop(ctx, 'C'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _kGrey)),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo == _permiso) return;
    await PermisoRepository.setPermiso(nuevo);
    setState(() => _permiso = nuevo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (nuevo) {
            'A' => 'Cambiado a Permiso A (Moto)',
            'C' => 'Cambiado a Permiso C (Camión)',
            _ => 'Cambiado a Permiso B (Coche)',
          }),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _abrirPrivacidad() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacidadScreen()),
    );
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    if (_notifEnabled) {
      await NotificationService.enable(_hora.hour, _hora.minute);
    } else {
      await NotificationService.disable();
    }
    setState(() => _guardando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajustes guardados'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Ajustes')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kYellow))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // ── Sección notificaciones ────────────────────────────────
                const _SectionHeader(label: 'Notificaciones'),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  title: 'Recordatorio diario',
                  subtitle: 'Recibe un aviso para practicar cada día',
                  trailing: Switch(
                    value: _notifEnabled,
                    onChanged: _toggleNotif,
                    activeThumbColor: _kYellow,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _notifEnabled
                      ? Column(
                          children: [
                            const SizedBox(height: 8),
                            _SettingsTile(
                              icon: Icons.access_time_rounded,
                              title: 'Hora del recordatorio',
                              subtitle: _hora.format(context),
                              onTap: _cambiarHora,
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: _kGrey,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kYellow,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Guardar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                // ── Sección general ───────────────────────────────────────────
                const _SectionHeader(label: 'General'),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  title: 'Idioma',
                  subtitle: switch (_idioma) {
                    'it' => '🇮🇹 Italiano',
                    'en' => '🇬🇧 English',
                    'fr' => '🇫🇷 Français',
                    'ro' => '🇷🇴 Română',
                    _ => '🇪🇸 Español',
                  },
                  onTap: _cambiarIdioma,
                  trailing: const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.flag_rounded,
                  title: 'País del examen',
                  subtitle: '${paisPorCodigo(_pais).bandera} ${paisPorCodigo(_pais).nombre}',
                  onTap: _cambiarPais,
                  trailing: const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Cambiar permiso',
                  subtitle: switch (_permiso) {
                    'A' => '🏍️ Permiso A (Moto)',
                    'C' => '🚛 Permiso C (Camión)',
                    _ => '🚗 Permiso B (Coche)',
                  },
                  onTap: _cambiarPermiso,
                  trailing: const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Política de privacidad',
                  subtitle: 'Sin servidores, sin datos externos',
                  onTap: _abrirPrivacidad,
                  trailing: const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Restablecer bienvenida',
                  subtitle: 'Muestra la pantalla de bienvenida al reabrir',
                  onTap: _resetearOnboarding,
                  trailing: const Icon(Icons.chevron_right_rounded, color: _kGrey),
                ),
                const SizedBox(height: 32),
                // ── Sección créditos ──────────────────────────────────────────
                const _SectionHeader(label: 'Créditos'),
                const SizedBox(height: 12),
                const _CreditoTile(
                  bandera: '🇮🇹',
                  titulo: 'Preguntas Italia — Ed0ardo/QuizPatenteB',
                  descripcion: 'github.com/Ed0ardo/QuizPatenteB · MIT License © 2023 Edoardo',
                ),
              ],
            ),
    );
  }
}

// ── Widgets de apoyo ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kGrey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _kYellow, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Datos para opciones de diálogo genérico ───────────────────────────────────

class _DialogOpcion {
  final String codigo;
  final String bandera;
  final String label;
  final bool disponible;
  const _DialogOpcion({
    required this.codigo,
    required this.bandera,
    required this.label,
    required this.disponible,
  });
}

class _OpcionDialogTile extends StatelessWidget {
  final _DialogOpcion opcion;
  final bool activo;
  final VoidCallback? onTap;

  const _OpcionDialogTile({
    required this.opcion,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = opcion.disponible;
    final bg = activo ? _kYellow.withValues(alpha: 0.12) : const Color(0xFFF9F9F9);
    final borderColor = activo ? _kYellow : _kBorder;
    final textColor = activo ? _kYellow : (enabled ? _kDark : _kGrey);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: activo ? 2 : 1),
          ),
          child: Row(
            children: [
              Text(opcion.bandera, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opcion.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (activo)
                const Icon(Icons.check_circle_rounded, color: _kYellow, size: 20)
              else if (!enabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pronto',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGrey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermisoDialogOpcion extends StatelessWidget {
  final String emoji;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _PermisoDialogOpcion({
    required this.emoji,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? _kYellow.withValues(alpha: 0.12) : const Color(0xFFF9F9F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activo ? _kYellow : _kBorder,
              width: activo ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: activo ? _kYellow : _kDark,
                  ),
                ),
              ),
              if (activo)
                const Icon(Icons.check_circle_rounded, color: _kYellow, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditoTile extends StatelessWidget {
  final String bandera;
  final String titulo;
  final String descripcion;
  const _CreditoTile({
    required this.bandera,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bandera, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 11, color: _kGrey, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
