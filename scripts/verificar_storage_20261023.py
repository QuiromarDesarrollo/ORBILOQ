import argparse,json,hashlib,zipfile,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--snapshot',required=True);p.add_argument('--dest',required=True);a=p.parse_args()
expected={};active=False
for line in Path(a.snapshot).read_text(encoding='utf-8-sig').splitlines():
 if line.startswith('COPY storage.objects ('):
  cols=line.split('(',1)[1].split(')',1)[0].split(', ');active=True;continue
 if active and line==r'\.':break
 if active:
  r=dict(zip(cols,line.split('\t')));expected[(r['bucket_id'],r['name'])]=json.loads(r['metadata'].replace('\\\\','\\'))['size']
sources=[('documentos','importaciones',Path.home()/'Downloads'/'importaciones (2).zip')]+[('seguimiento-evidencias',i,Path.home()/'Downloads'/(i+'.zip')) for i in ['08040297-32eb-49ad-a0ea-e256582f12f6','3252ee7d-f251-4bf5-ae4c-a8357f63e34a','76f3a4bf-d731-4b4b-b6d5-cc1d1905cb3d']]
seen={};archives=[]
for bucket,prefix,path in sources:
 with zipfile.ZipFile(path) as z:
  assert z.testzip() is None,'ZIP corrupto'
  for entry in z.infolist():
   if entry.is_dir():continue
   name=entry.filename
   assert not name.startswith('/') and '..' not in Path(name).parts,'Ruta no segura'
   key=(bucket,name if name.startswith(prefix+'/') else prefix+'/'+name)
   assert key in expected and key not in seen and expected[key]==entry.file_size,'Archivo inesperado o tamaño diferente'
   seen[key]={'bucket':bucket,'ruta':key[1],'bytes':entry.file_size,'sha256':hashlib.sha256(z.read(entry)).hexdigest()}
 archives.append((path,hashlib.sha256(path.read_bytes()).hexdigest()))
assert expected.keys()==seen.keys(),'Respaldo incompleto'
dest=Path(a.dest);dest.mkdir(parents=True,exist_ok=False)
for path,h in archives:
 shutil.copy2(path,dest/path.name);assert hashlib.sha256((dest/path.name).read_bytes()).hexdigest()==h
(dest/'verificacion.json').write_text(json.dumps({'archivos':list(seen.values()),'total':len(seen),'alcance':'Rutas y tamaños contra snapshot; CRC y SHA256 locales. No compara hashes remotos.'},indent=2),encoding='utf8')
print(json.dumps({'archivos_verificados':len(seen),'destino':str(dest)}))
