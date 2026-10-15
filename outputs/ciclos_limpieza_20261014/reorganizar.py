import json, collections, datetime
from pathlib import Path
import openpyxl

base = Path(__file__).parent
wb = openpyxl.load_workbook(r'D:\DESCARGAS\plantilla_ciclos EJEMPLO REAL.xlsx', data_only=True)
ws = wb['Historicos']
rows, changes = [], []
headers = ['OP','CLIENTE','CANTIDAD','FECHA DE INICIO','COMPRAS','TRAZO','CORTE','SEPARADO','ALIADOS','TERMINADO','LOGISTICA','FECHA COMPROMETIDA']
def log(row, col, old, new, rule):
    changes.append([str(row['source_row']),str(row['values'][0]),headers[col],str(old) if old is not None else '',str(new) if new is not None else '',rule])

for n in range(4, ws.max_row+1):
    original = [ws.cell(n,c).value for c in range(1,13)]
    v = original.copy()
    v[0] = str(v[0])
    row = dict(source_row=str(n), values=v)
    prev = None
    for i in range(3,12):
        x = v[i]
        if isinstance(x, datetime.datetime):
            v[i] = x.date().isoformat()
        elif x == 0 or isinstance(x,datetime.time):
            v[i] = None
            log(row,i,x,None,'Cero convertido a vacío')
        elif isinstance(x,str) and x.strip():
            v[i] = prev if i < 11 else None
            log(row,i,x,v[i],'Texto sustituido por fecha válida anterior' if i < 11 else 'Texto en fecha comprometida: sin fecha')
        elif x is None or x == '':
            v[i] = None
        else:
            raise ValueError((n,i,x))
        if i < 11 and v[i]: prev = v[i]
    rows.append(row)

original_quantity = sum(r['values'][2] for r in rows)
future_next = future_prev = 0
for r in rows:
    v = r['values']
    if v[8] and v[8] > '2026-10-14':
        old = v[8]
        if v[9]:
            v[8] = v[9]
            future_next += 1
            rule = 'Aliados futuro sustituido por Terminado'
        else:
            v[8] = next((x for x in reversed(v[3:8]) if x),None)
            future_prev += 1
            rule = 'Aliados futuro sustituido por última fecha válida anterior'
        log(r,8,old,v[8],rule)

groups = collections.OrderedDict()
for r in rows: groups.setdefault(r['values'][0],[]).append(r)
merged = []
for op, group in groups.items():
    r = dict(source_row=', '.join(x['source_row'] for x in group),values=group[0]['values'].copy())
    if len(group)>1:
        assert len({x['values'][1] for x in group}) == 1
        r['values'][2] = sum(x['values'][2] for x in group)
        log(r,2,' + '.join(str(x['values'][2]) for x in group),r['values'][2],'Suma de cantidades de OP duplicada')
        for i in range(3,12):
            dates = [x['values'][i] for x in group if x['values'][i]]
            value = (min(dates) if i == 3 else max(dates)) if dates else None
            if len(set(x['values'][i] for x in group))>1:
                log(r,i,' | '.join(x['values'][i] or 'vacío' for x in group),value,'Consolidación: inicio más antiguo; cierre más reciente por proceso')
            r['values'][i] = value
    merged.append(r)

sorted_rows = 0
for r in merged:
    v = r['values']
    indices = [i for i in range(3,11) if v[i]]
    dates = sorted(v[i] for i in indices)
    if dates != [v[i] for i in indices]:
        sorted_rows += 1
        for i, new in zip(indices, dates):
            if v[i] != new:
                log(r,i,v[i],new,'Intercambio cronológico de fechas; casillas vacías conservadas')
                v[i] = new
    assert [v[i] for i in indices] == sorted(v[i] for i in indices)
assert len(rows)==7741 and len(merged)==7739
assert sum(r['values'][2] for r in merged)==original_quantity
assert not any(r['values'][8] and r['values'][8]>'2026-10-14' for r in merged)
stats=dict(original_rows=len(rows),import_rows=len(merged),quantity=original_quantity,aliados_terminado=future_next,aliados_anterior=future_prev,ordenadas=sorted_rows,cambios=len(changes))
(base/'reorganizado.json').write_text(json.dumps(dict(rows=merged,changes=changes,stats=stats),ensure_ascii=False),encoding='utf-8')
print(json.dumps(stats))
