export const REMITENTE='analistasdedatosing@gmail.com';
const utf8 = text => {
 const bytes=new TextEncoder().encode(String(text));let binary='';
 for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
 return btoa(binary);
};
const wrap = value => value.match(/.{1,76}/g)?.join('\r\n') ?? '';
const encoded = text => `=?UTF-8?B?${utf8(text)}?=`;
const safe = value => {if(/[\r\n]/.test(value))throw Error('Cabecera inválida');return value;};
export function mensajeGmail(contenido,id,logo) {
 const boundary=`orbiloq_${id}`, alt=`alternativo_${id}`;
 const lines=[`From: ORBILOQ Grupo Quiromar <${REMITENTE}>`,`To: ${contenido.to.map(safe).join(', ')}`,`Subject: ${encoded(contenido.subject)}`,`Message-ID: <entrega-${id}@orbiloq.local>`,'MIME-Version: 1.0',`Content-Type: multipart/mixed; boundary="${boundary}"`,'',`--${boundary}`,`Content-Type: multipart/alternative; boundary="${alt}"`,''];
 for(const [mime,text] of [['text/plain',contenido.text],['text/html',contenido.html]])lines.push(`--${alt}`,`Content-Type: ${mime}; charset=UTF-8`,'Content-Transfer-Encoding: base64','',wrap(utf8(text)));
 lines.push(`--${alt}--`);
 for(const a of [...contenido.attachments,{filename:'orbiloq.png',content:logo,content_id:'orbiloq-logo'}]){
  const ext=a.filename.split('.').pop().toLowerCase();
  const mime={pdf:'application/pdf',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg',webp:'image/webp'}[ext]??'application/octet-stream';
  const filename=encodeURIComponent(a.filename).replace(/'/g,'%27');
  lines.push(`--${boundary}`,`Content-Type: ${mime}`,`Content-Disposition: ${a.content_id?'inline':'attachment'}; filename*=UTF-8''${filename}`,'Content-Transfer-Encoding: base64');
  if(a.content_id)lines.push(`Content-ID: <${a.content_id}>`);
  lines.push('',wrap(a.content));
 }
 lines.push(`--${boundary}--`,'');
 // Todo el MIME ya es ASCII: evita una copia UTF-8 y arrays por byte de los adjuntos.
 const raw=btoa(lines.join('\r\n')).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
 return raw;
}
