from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from xml.sax.saxutils import escape
from pypdf import PdfReader

root=Path.cwd()
for name,file in [('Regular','LiberationSans-Regular.ttf'),('Bold','LiberationSans-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(root/'assets/fonts'/file)))
out=root/'output/pdf/vista_previa_rotulos_10x10.pdf'
c=canvas.Canvas(str(out),pagesize=(100*mm,100*mm))
c.setTitle('Vista previa — rótulos de empaque 10 × 10 cm')
c.setAuthor('ORBILOQ · Ejemplo con datos ficticios')
style=ParagraphStyle('producto',fontName='Regular',fontSize=6.8,leading=8)
rows=[('BLUSA MUJER MANGA 3/4','S / 8',25),('BLUSA MUJER MANGA 3/4','M / 10',5),('BLUSA MUJER MANGA 3/4','L / 12',5),('BLUSA MUJER MANGA 3/4','XL / 14',5),('CAMISA HOMBRE MANGA LARGA','S',5),('CAMISA HOMBRE MANGA LARGA','M',10),('PANTALÓN HOMBRE DRIL AZUL OSCURO','32',8),('PANTALÓN HOMBRE DRIL AZUL OSCURO','34',6),('CHAQUETA IMPERMEABLE CON CAPUCHA','L',4)]
# Mismo empaque. El corte depende del alto real del texto, no de su cantidad de unidades.
prepared=[]
for desc,size,qty in rows:
    p=Paragraph(escape(desc),style); _,h=p.wrap(56*mm,200)
    prepared.append((p,max(3.9*mm,h+3),size,qty))
cap=37*mm
pages=[]; page=[]; used=0
for row in prepared:
    if page and used+row[1]>cap: pages.append(page);page=[];used=0
    page.append(row);used+=row[1]
if page:pages.append(page)

def text(x,y,t,size=8,bold=False):
    c.setFont('Bold' if bold else 'Regular',size);c.drawString(x*mm,y*mm,t)
def paragraph(x,y,w,t,size=8,bold=False):
    st=ParagraphStyle('field',fontName='Bold' if bold else 'Regular',fontSize=size,leading=size+1)
    p=Paragraph(escape(t),st);_,h=p.wrap(w*mm,200);p.drawOn(c,x*mm,y*mm-h)

for idx,page in enumerate(pages,1):
    c.setLineWidth(.6);c.rect(4*mm,4*mm,92*mm,92*mm)
    # Logo Quiromar utilizado en la lista de empaque nacional.
    text(8,92,'REMITE:',6.3,True)
    c.drawImage(str(root/'assets/images/logo_quiromar_formato.jpg'),8*mm,79*mm,width=58*mm,height=11*mm,preserveAspectRatio=True,anchor='c')
    text(8,76,'AV CRA 50 # 29B - 19 SUR',6.4)
    text(8,72.8,'NIT: 830055605-3  ·  TEL: 7136381',6.4)
    c.rect(72*mm,74*mm,21*mm,19*mm)
    text(75.5,87,'PIEZA',11,True)
    text(74.5,79,'1 DE ____',10,True)
    c.line(4*mm,70.5*mm,96*mm,70.5*mm)
    text(7,66,'CLIENTE:',7,True);text(26,66,'CLIENTE DE EJEMPLO S.A.S.',8,True)
    text(7,61,'ORDEN DE COMPRA:',6.6,True);text(37,61,'OC-5153',8)
    text(7,56,'CIUDAD:',7,True);text(26,56,'BARRANQUILLA',8)
    # Contenido exclusivo de la caja seleccionada.
    c.setFillGray(0);c.rect(4*mm,49*mm,92*mm,5*mm,stroke=0,fill=1)
    c.setFillGray(1);text(7,50.6,'DESCRIPCIÓN DEL PRODUCTO',6.6,True);text(66,50.6,'TALLA',6.6,True);text(83,50.6,'CANT.',6.6,True);c.setFillGray(0)
    # La tabla conserva espacio para el empacador, con capacidad medida a continuación.
    y=49*mm
    for p,h,size,qty in page:
        p.drawOn(c,7*mm,y-(h-p.height)/2-p.height)
        c.setFont('Regular',7);c.drawCentredString(72*mm,y-h/2-2,size)
        c.setFont('Bold',7.5);c.drawCentredString(87*mm,y-h/2-2,str(qty))
        y-=h;c.setLineWidth(.35);c.line(4*mm,y,96*mm,y)
    c.setLineWidth(.5)
    c.line(63*mm,49*mm,63*mm,y);c.line(80*mm,49*mm,80*mm,y)
    text(7,10,'EMPACADO POR:',6.7,True);text(32,10,'ANDREA · EJEMPLO',8)
    c.setFont('Regular',6.2);c.drawRightString(93*mm,5.8*mm,f'RÓTULO {idx} DE {len(pages)} · MISMA PIEZA 1')
    c.showPage()
c.save()
r=PdfReader(out)
assert len(r.pages)==1
for page in r.pages:
    assert abs(float(page.mediabox.width)-100*mm)<.01
    assert '1 DE ____' in page.extract_text()
    assert 'PIEZA' in page.extract_text()
    assert 'CAJA' not in page.extract_text()
    assert 'OBSERVACIÓN' not in page.extract_text()
print(out)


