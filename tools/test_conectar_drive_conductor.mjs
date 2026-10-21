import test from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { createConnectionServer, ORIGIN, FOLDER } from './conectar_drive_conductor.mjs';

test('conexión local: sesión, CSRF, state, PKCE y carpeta autorizada antes de guardar secretos', async () => {
  let saved, exchanges = 0;
  const client = { project_id: 'orbiloq-transporte', client_id: '123-test.apps.googleusercontent.com',
    client_secret: 'private-client', redirect_uris: [`${ORIGIN}/oauth/callback`] };
  const {server,entryUrl} = createConnectionServer({client,pickerKey:'test-key',saveSecrets:async s=>{saved=s;},
    fetchGoogle:async(url,options)=>{
      if(url.includes('oauth2.googleapis.com')){
        exchanges++;
        assert.ok(options.body.get('code_verifier'));
        assert.equal(options.body.get('client_secret'),'private-client');
        return Response.json({access_token:'private-access',refresh_token:'private-refresh',scope:'https://www.googleapis.com/auth/drive.file'});
      }
      assert.ok(url.includes(FOLDER));
      assert.equal(options.headers.Authorization,'Bearer private-access');
      return Response.json({id:FOLDER,name:'TRANSPORTE',mimeType:'application/vnd.google-apps.folder',capabilities:{canAddChildren:true}});
    }});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const call=(path,method='GET',headers={},body='')=>new Promise((resolve,reject)=>{
    const req=request({hostname:'127.0.0.1',port:server.address().port,path,method,headers:{Host:'localhost:8765',...headers}},res=>{
      let data='';res.on('data',c=>data+=c);res.on('end',()=>resolve({code:res.statusCode,headers:res.headers,body:data}));
    });req.on('error',reject);req.end(body);
  });
  try {
    assert.equal((await call('/')).code,403);
    assert.equal((await call('/', 'GET',{Host:'attacker.example'})).code,403);
    const initial=await call(new URL(entryUrl).pathname+new URL(entryUrl).search);
    const Cookie=initial.headers['set-cookie'][0].split(';')[0];
    const page=await call('/','GET',{Cookie});
    assert.ok(!page.body.includes('private-client'));
    const csrf=page.body.match(/csrf="([A-Za-z0-9_-]+)"/)[1];
    const headers={Cookie,Origin:ORIGIN,'X-Setup-CSRF':csrf};
    assert.equal((await call('/oauth/start','POST',{Cookie})).code,403);
    const start=await call('/oauth/start','POST',headers);
    const auth=new URL(JSON.parse(start.body).url);
    assert.equal(auth.searchParams.get('access_type'),'offline');
    assert.equal(auth.searchParams.get('code_challenge_method'),'S256');
    assert.equal((await call('/oauth/callback?state=wrong&code=fake','GET',{Cookie})).code,400);
    assert.equal(exchanges,0);
    const callback=`/oauth/callback?state=${auth.searchParams.get('state')}&code=test-code`;
    assert.equal((await call(callback,'GET',{Cookie})).code,303);
    assert.equal((await call(callback,'GET',{Cookie})).code,400);
    assert.equal((await call('/verify','POST',headers,JSON.stringify({folderId:'wrong'}))).code,400);
    assert.equal(saved,undefined);
    const verified=await call('/verify','POST',headers,JSON.stringify({folderId:FOLDER}));
    assert.equal(verified.code,200);
    assert.equal(saved.refreshToken,'private-refresh');
    assert.ok(!verified.body.includes('private-refresh'));
    assert.equal((await call('/picker-config','POST',headers)).code,409);
  }finally{await new Promise(resolve=>server.close(resolve));}
});
