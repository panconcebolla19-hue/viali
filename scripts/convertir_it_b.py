"""
Convierte quizPatenteB2023.json al formato Viali.
Incluye TODAS las preguntas: con y sin imagen.
Las que tienen imagen usan assets/imagenes_it/FILENAME.
IDs empiezan en 20001.

  python scripts/convertir_it_b.py
"""
import json, os, tempfile

SRC = os.path.join(tempfile.gettempdir(), 'quizPatenteB2023.json')
DST = os.path.join('assets', 'preguntas_IT_B.json')
IMG_DIR = os.path.join('assets', 'imagenes_it')

with open(SRC, encoding='utf-8') as f:
    data = json.load(f)

out = []
next_id = 20001

for topic_key, subtopics in data.items():
    for subtopic_key, questions in subtopics.items():
        for q in questions:
            enunciado = q['q'].strip()
            answer = q['a']  # True o False
            entry = {
                'id': next_id,
                'enunciado': enunciado,
                'opciones': ['Vero', 'Falso'],
                'respuesta_correcta': 0 if answer else 1,
                'explicacion': '',
            }
            if q.get('img'):
                fname = os.path.basename(q['img'])
                img_path = os.path.join(IMG_DIR, fname)
                if os.path.exists(img_path):
                    entry['imagen'] = f'assets/imagenes_it/{fname}'
                else:
                    entry['imagen_oculta'] = True
            out.append(entry)
            next_id += 1

with open(DST, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(out, f, ensure_ascii=False, indent=4)

kb = os.path.getsize(DST) // 1024
con_img = sum(1 for q in out if 'imagen' in q)
ocultas = sum(1 for q in out if q.get('imagen_oculta'))
sin_img = len(out) - con_img - ocultas
print(f'preguntas_IT_B.json generado: {len(out)} preguntas ({kb} KB)')
print(f'  Con imagen: {con_img} | imagen_oculta: {ocultas} | solo texto: {sin_img}')
