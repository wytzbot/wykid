const crypto=require('crypto');
const {json,env,flw,nonce,encrypt}=require('./_flw');
const PRICES={USD:1.99,NGN:2000};
module.exports=async function(req,res){
 if(req.method!=='POST')return json(res,405,{message:'Method not allowed'});
 try{
  const b=req.body||{}; const name=String(b.name||'').trim(); const email=String(b.email||'').trim().toLowerCase();
  const currency=String(b.currency||'NGN').toUpperCase(); const amount=PRICES[currency]; if(!amount) return json(res,400,{message:'Unsupported billing currency.'});
  const cardNumber=String(b.cardNumber||'').replace(/\s+/g,''); const expiry=String(b.expiry||'').replace(/\s|\//g,''); const cvv=String(b.cvv||'').trim();
  if(name.length<2)return json(res,400,{message:'Please enter the parent/guardian full name.'});
  if(!/^\S+@\S+\.\S+$/.test(email))return json(res,400,{message:'Please enter a valid email address.'});
  if(!/^\d{12,19}$/.test(cardNumber))return json(res,400,{message:'Please enter a valid card number.'});
  if(!/^\d{4}$/.test(expiry))return json(res,400,{message:'Expiry must be MMYY.'});
  if(!/^\d{3,4}$/.test(cvv))return json(res,400,{message:'Please enter a valid CVV.'});
  const month=expiry.slice(0,2), year=expiry.slice(2); const m=Number(month); if(m<1||m>12)return json(res,400,{message:'Expiry month is invalid.'});
  const customer=await flw('/customers',{method:'POST',body:JSON.stringify({email,name:{first:name.split(/\s+/)[0],last:name.split(/\s+/).slice(1).join(' ')||name.split(/\s+/)[0]},meta:{product:'Writing Kids Premium'}})});
  const customerId=customer.data?.id; if(!customerId)throw new Error('Flutterwave did not return a customer ID.');
  const n=nonce(); const key=env('FLW_V4_ENCRYPTION_KEY');
  const pm=await flw('/payment-methods',{method:'POST',body:JSON.stringify({type:'card',card:{encrypted_card_number:encrypt(cardNumber,key,n),encrypted_expiry_month:encrypt(month,key,n),encrypted_expiry_year:encrypt(year,key,n),encrypted_cvv:encrypt(cvv,key,n),nonce:n}})});
  const paymentMethodId=pm.data?.id; if(!paymentMethodId)throw new Error('Flutterwave did not return a payment method ID.');
  const reference=`WK-${Date.now()}-${crypto.randomBytes(5).toString('hex')}`;
  const charge=await flw('/charges',{method:'POST',body:JSON.stringify({reference,currency,customer_id:customerId,payment_method_id:paymentMethodId,amount,redirect_url:`${env('PUBLIC_APP_URL').replace(/\/$/,'')}/?wk_payment=1`,meta:{product:'Writing Kids Premium',display_price:currency==='USD'?'$1.99 monthly':'₦2,000 monthly',billing:'monthly'}})});
  const d=charge.data||{};
  return json(res,200,{chargeId:d.id,reference,customerId,paymentMethodId,status:d.status,nextAction:d.next_action||null,redirectUrl:d.next_action?.redirect_url?.url||d.redirect_url||null,amount,currency});
 }catch(e){return json(res,500,{message:e.message||'Payment initialization failed'});}
};
