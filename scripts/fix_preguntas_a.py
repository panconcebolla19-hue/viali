"""
Apply image classification fixes to preguntas_A.json:
  - Delete 25 questions whose answers depend on missing images
  - Mark 7 questions as imagen_oculta: true
"""
import json
import sys

ASSET = '../assets/preguntas_A.json'

DELETE_IDS = {
    10057, 10152, 10162, 10224, 10236, 10249, 10263, 10283, 10305,
    10323, 10335, 10403, 10438, 10499, 10562, 10564, 10587, 10604,
    10612, 10648, 10651, 10772, 10799, 10807, 10818,
}

IMAGEN_OCULTA_IDS = {10133, 10138, 10286, 10289, 10428, 10671, 10740}

with open(ASSET, encoding='utf-8-sig') as f:
    data = json.load(f)

original_count = len(data)
deleted = []
marked = []

result = []
for q in data:
    qid = q['id']
    if qid in DELETE_IDS:
        deleted.append(qid)
        continue
    if qid in IMAGEN_OCULTA_IDS:
        q['imagen_oculta'] = True
        marked.append(qid)
    result.append(q)

# Validate
assert len(deleted) == len(DELETE_IDS), f"Expected {len(DELETE_IDS)} deletions, got {len(deleted)}"
assert len(marked) == len(IMAGEN_OCULTA_IDS), f"Expected {len(IMAGEN_OCULTA_IDS)} marks, got {len(marked)}"

# Check no duplicate IDs
ids = [q['id'] for q in result]
assert len(ids) == len(set(ids)), "Duplicate IDs found!"

# Check all required fields
for q in result:
    for field in ('id', 'enunciado', 'opciones', 'respuesta_correcta', 'explicacion'):
        assert field in q, f"Missing field '{field}' in question {q.get('id')}"
    assert 0 <= q['respuesta_correcta'] < len(q['opciones']), \
        f"respuesta_correcta out of range in question {q['id']}"

with open(ASSET, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(result, f, ensure_ascii=False, indent=4)
    f.write('\n')

print(f"Original: {original_count} questions")
print(f"Deleted {len(deleted)}: {sorted(deleted)}")
print(f"Marked imagen_oculta {len(marked)}: {sorted(marked)}")
print(f"Final: {len(result)} questions")
print("Done.")
