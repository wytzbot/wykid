const {json,flw}=require('./_flw');
const {saveSubscription}=require('./store');
function nextMonth(iso){const d=new Date(iso);const day=d.getUTCDate();d.setUTCMonth(d.getUTCMonth()+1);if(d.getUTCDate()!==day)d.setUTCDate(0);return d.toISOString();}
const PRICES={USD:1.99,NGN:2000};
module.exports=async function(req,res){
 if(req.method!=='GET')return json(res,405,{message:'Method not allowed'});
 try{
  const id=String(req.query.charge_id||req.query.transaction_id||req.query.id||'').trim(); if(!id)return json(res,400,{message:'Missing charge_id.'});
  const r=await flw(`/charges/${encodeURIComponent(id)}`); const d=r.data||{}; const customerId=String(d.customer?.id||d.customer||''); let customerEmail=String(d.customer?.email||'').toLowerCase(); if(!customerEmail&&customerId){try{const cr=await flw(`/customers/${encodeURIComponent(customerId)}`);customerEmail=String(cr.data?.email||'').toLowerCase();}catch(_){}} const email=customerEmail; const currency=String(d.currency||'').toUpperCase(); const expected=PRICES[currency];
  const pm=String(d.payment_method_details?.id||d.payment_method?.id||'');
  const verified=d.status==='succeeded'&&expected!=null&&Number(d.amount)===expected&&String(d.reference||'').startsWith('WK-')&&/^\S+@\S+\.\S+$/.test(email)&&Boolean(pm)&&Boolean(customerId);
  if(verified)await saveSubscription({email,customerId,paymentMethodId:pm,reference:String(d.reference),amount:Number(d.amount),currency,status:'active',nextChargeAt:nextMonth(new Date().toISOString()),failCount:0});
  return json(res,200,{verified,status:d.status,amount:d.amount,currency:d.currency,reference:d.reference,email:email||null});
 }catch(e){return json(res,500,{message:e.message||'Verification failed'});}
};
