"""
Genera questions.js a partir de assets/preguntas.json.
Ejecuta este script cada vez que actualices las preguntas.

  python generar_preguntas.py
"""
import json, os

SRC = os.path.join('..', 'assets', 'preguntas.json')
DST = 'questions.js'

with open(SRC, encoding='utf-8') as f:
    preguntas = json.load(f)

out = []
for q in preguntas:
    p = {
        'id':               q['id'],
        'enunciado':        q['enunciado'],
        'opciones':         q['opciones'],
        'respuesta_correcta': q['respuesta_correcta'],
        'explicacion':      q.get('explicacion', ''),
    }
    if 'imagen' in q and not q.get('imagen_oculta', False):
        p['tiene_imagen'] = True
    out.append(p)

js = 'const PREGUNTAS = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n'

with open(DST, 'w', encoding='utf-8', newline='\n') as f:
    f.write(js)

kb = os.path.getsize(DST) // 1024
print(f'questions.js generado: {len(out)} preguntas ({kb} KB)')
