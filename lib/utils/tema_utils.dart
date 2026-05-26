import '../models/pregunta.dart';

String detectarTema(Pregunta p) {
  final t = p.enunciado.toLowerCase();
  if (t.contains('señal') || t.contains('prohibi') || t.contains('advertenc') ||
      t.contains('stop') || t.contains('ceda') || t.contains('indicaci')) {
    return 'señales';
  }
  if (t.contains('velocidad') || t.contains('km/h') || t.contains('límite') ||
      t.contains('limite')) {
    return 'velocidad';
  }
  if (t.contains('alcohol') || t.contains('tasa') || t.contains('droga') ||
      t.contains('estupef')) {
    return 'alcohol';
  }
  if (t.contains('adelant') || t.contains('rebasar')) {
    return 'adelantamientos';
  }
  if (t.contains('distancia') || t.contains('separaci') || t.contains('intervalo')) {
    return 'distancias';
  }
  if (t.contains('autopista') || t.contains('autovía') || t.contains('autovia') ||
      t.contains('vía rápida')) {
    return 'autopista';
  }
  if (t.contains('medio ambi') || t.contains('contaminac') || t.contains('emisione') ||
      t.contains('neumátic') || t.contains('neumatic')) {
    return 'medio_ambiente';
  }
  if (t.contains('documentac') || t.contains('carnet') || t.contains('permiso') ||
      t.contains('itv') || t.contains(' seguro')) {
    return 'documentacion';
  }
  return 'otro';
}
