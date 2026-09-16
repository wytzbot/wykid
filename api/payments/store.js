function env(n){const v=process.env[n];if(!v)throw new Error(`Missing server configuration: ${n}`);return v;}
function base(){return env('SUPABASE_URL').replace(/\/$/,'')+'/rest/v1';}
function headers(extra={}){return {apikey:env('SUPABASE_SERVICE_ROLE_KEY'),Authorization:`Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`,'Content-Type':'application/json',...extra};}
function row(s){return {email:s.email,customer_id:s.customerId,payment_method_id:s.paymentMethodId,reference:s.reference||null,amount:Number(s.amount),currency:s.currency,status:s.status,next_charge_at:s.nextChargeAt,last_charge_reference:s.lastChargeReference||null,last_status:s.lastStatus||null,fail_count:Number(s.failCount||0)};}
function fromRow(r){return r?{email:r.email,customerId:r.customer_id,paymentMethodId:r.payment_method_id,reference:r.reference,amount:Number(r.amount),currency:r.currency,status:r.status,nextChargeAt:r.next_charge_at,lastChargeReference:r.last_charge_reference,lastStatus:r.last_status,failCount:Number(r.fail_count||0)}:null;}
async function request(path,options={}){const r=await fetch(base()+path,{...options,headers:headers(options.headers||{})});const text=await r.text();let d=null;try{d=text?JSON.parse(text):null}catch{}if(!r.ok)throw new Error(d?.message||d?.error_description||d?.hint||text||`Supabase HTTP ${r.status}`);return d;}
async function saveSubscription(s){await request('/writing_kids_subscriptions?on_conflict=email',{method:'POST',headers:{Prefer:'resolution=merge-duplicates,return=minimal'},body:JSON.stringify(row(s))});}
async function getSubscription(email){const d=await request(`/writing_kids_subscriptions?select=*&email=eq.${encodeURIComponent(email)}&limit=1`);return fromRow(d?.[0]);}
async function deleteSubscription(email){await request(`/writing_kids_subscriptions?email=eq.${encodeURIComponent(email)}`,{method:'DELETE',headers:{Prefer:'return=minimal'}});}
async function listSubscriptions(){const d=await request('/writing_kids_subscriptions?select=*');return Array.isArray(d)?d.map(fromRow).filter(Boolean):[];}
module.exports={saveSubscription,getSubscription,deleteSubscription,listSubscriptions};
