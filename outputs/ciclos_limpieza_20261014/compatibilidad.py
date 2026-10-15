import zipfile, re, json, datetime
from pathlib import Path
import openpyxl

p = Path(__file__).with_name('plantilla_ciclos_reorganizada.xlsx')
with zipfile.ZipFile(p) as z:
    items = [(i, z.read(i.filename)) for i in z.infolist()]
with zipfile.ZipFile(p, 'w', zipfile.ZIP_DEFLATED) as z:
    for i, data in items:
        ns = b'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
        if i.filename.endswith('.xml') and b'xmlns:x="'+ns in data:
            data = data.replace(b'xmlns:x="'+ns+b'"', b'xmlns="'+ns+b'"').replace(b'<x:', b'<').replace(b'</x:', b'</')
        if i.filename == 'xl/_rels/workbook.xml.rels':
            data = data.replace(b'Target="/xl/', b'Target="')
        if i.filename.startswith('xl/worksheets/') and i.filename.endswith('.xml'):
            s = data.decode('utf-8-sig')
            s = re.sub(r'<c([^>]*?) t="str"\s*/>', r'<c\1 />', s)
            s = re.sub(r'<c([^>]*?) t="str"><v>(.*?)</v></c>', r'<c\1 t="inlineStr"><is><t xml:space="preserve">\2</t></is></c>', s, flags=re.S)
            data = s.encode('utf-8')
        z.writestr(i, data)

data = json.loads(p.with_name('reorganizado.json').read_text(encoding='utf-8'))
wb = openpyxl.load_workbook(p, data_only=False)
for name, records, offset in [('Historicos', data['rows'], 0)]:
    ws = wb[name]
    assert ws.max_row == len(records)+1
    for n, rec in enumerate(records, 2):
        for j, expected in enumerate(rec['values'], 1):
            actual = ws.cell(n, j+offset).value
            if isinstance(actual, datetime.datetime): actual = actual.date().isoformat()
            assert actual == expected, (name, n, j, actual, expected)
assert wb['Cambios'].max_row == len(data['changes'])+1
assert wb['Historicos'].max_row-1 == 7739
assert sum(wb['Historicos'].cell(r,3).value for r in range(2,7741)) == 653053
assert not any(c.data_type == 'f' for ws in wb for row in ws for c in row)
print('QA OK: 7739 OP, 653053 unidades, valores reconciliados, sin formulas.')
