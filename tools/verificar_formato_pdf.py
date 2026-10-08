from pathlib import Path
from pypdf import PdfReader
logo=Path('assets/images/logo_quiromar_formato.jpg').read_bytes()
for path,count in [('output/pdf/muestra_formato_lista_empaque.pdf',1),('.dart_tool/lista-empaque/prueba.pdf',3)]:
 r=PdfReader(path)
 assert len(r.pages)==count
 for p in r.pages:
  assert list(p.mediabox)==[0,0,612,792]
  assert not any(x.get_object().get('/Width')==205 for x in p['/Resources']['/XObject'].get_object().values())
  assert any(x.get_object().get_data()==logo for x in p['/Resources']['/XObject'].get_object().values())
 t='\n'.join(p.extract_text() for p in r.pages)
 assert 'KM 2.5 VIA GALAPA –' in t, 'No conserva el guion Unicode de la dirección'
 assert 'Recepción “Principal” — Área Nº 2' in t, 'No conserva caracteres del destinatario'
 assert 'null' not in t and t.count('TOTAL / TOTAL:')==1
 assert 'TIPO DE EMPAQUE' in t and 'CODIGO' not in t and 'BOLSA' not in t
 import re
 final=r.pages[-1].extract_text()
 for label,value in [('Total de piezas',24 if count==3 else 6),
                     ('N° de cajas',23 if count==3 else 6),
                     ('N° de empaques',1 if count==3 else 0)]:
  assert re.search(re.escape(label)+r'\s+'+str(value)+r'\b',final), (label,final)
 if count==3:assert t.count('96 Kg')==1 and t.count('120 Kg')==1 and '1,906' in t
 else:assert t.count('6 Kg')==2 and '0,476' in t
 print(f'OK: {count} páginas carta, sin sellos ISO y totales correctos')
