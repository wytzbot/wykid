const crypto = require('crypto');
function json(res,status,body){res.status(status).setHeader('Content-Type','application/json').send(JSON.stringify(body));}
function env(name){const v=process.env[name];if(!v)throw new Error(`Missing server configuration: ${name}`);return v;}
function trace(){return crypto.randomUUID();}
function idem(){return crypto.randomUUID();}
async function accessToken(){
  const body=new URLSearchParams({client_id:env('FLW_CLIENT_ID'),client_secret:env('FLW_CLIENT_SECRET'),grant_type:'client_credentials'});
  const r=await fetch('https://idp.flutterwave.com/realms/flutterwave/protocol/openid-connect/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body});
  const d=await r.json(); if(!r.ok||!d.access_token)throw new Error(d.error_description||'Flutterwave v4 authentication failed'); return d.access_token;
}
async function flw(path,options={}){
  const token=await accessToken();
  const headers={Authorization:`Bearer ${token}`,'Content-Type':'application/json','X-Trace-Id':trace(),'X-Idempotency-Key':idem(),...(options.headers||{})};
  const base=(process.env.FLW_V4_BASE_URL||'https://f4bexperience.flutterwave.com').replace(/\/$/,'');
  const r=await fetch(`${base}${path}`,{...options,headers});
  const text=await r.text(); let d={}; try{d=text?JSON.parse(text):{};}catch{d={raw:text};}
  if(!r.ok)throw new Error(d.message||d.error||`Flutterwave v4 HTTP ${r.status}`); return d;
}
function nonce(){return crypto.randomBytes(9).toString('base64url').slice(0,12);}
function encrypt(value,keyB64,ivText){
  const key=Buffer.from(keyB64,'base64'); if(key.length!==32)throw new Error('FLW_V4_ENCRYPTION_KEY must decode to exactly 32 bytes (AES-256).');
  const iv=Buffer.from(ivText,'utf8'); if(iv.length!==12)throw new Error('Flutterwave encryption nonce must be exactly 12 bytes.');
  const cipher=crypto.createCipheriv('aes-256-gcm',key,iv); const out=Buffer.concat([cipher.update(String(value),'utf8'),cipher.final(),cipher.getAuthTag()]); return out.toString('base64');
}
module.exports={json,env,flw,nonce,encrypt};
