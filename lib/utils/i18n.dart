const Map<String, Map<String, String>> _translations = {
  'es': {
    'modo_racha': 'Modo Racha',
    'test_normal': 'Test Normal',
    'examen_simulado': 'Examen Simulado',
    'volver': 'Volver',
    'continuar': 'Continuar',
    'correcto': '¡Correcto!',
    'incorrecto': 'Incorrecto',
    'respuesta_incorrecta': 'Respuesta incorrecta',
    'ver_resultados': 'Ver resultados',
    'volver_inicio': 'Volver al inicio',
    'continuar_examen': 'Continuar examen',
  },
  'it': {
    'modo_racha': 'Modalità Streak',
    'test_normal': 'Test Normale',
    'examen_simulado': 'Esame Simulato',
    'volver': 'Torna',
    'continuar': 'Continua',
    'correcto': 'Corretto!',
    'incorrecto': 'Sbagliato',
    'respuesta_incorrecta': 'Risposta sbagliata',
    'ver_resultados': 'Vedi risultati',
    'volver_inicio': 'Torna all\'inizio',
    'continuar_examen': 'Continua esame',
  },
};

String t(String key, String idioma) {
  return _translations[idioma]?[key] ?? _translations['es']![key] ?? key;
}
