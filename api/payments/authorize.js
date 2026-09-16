const {json,env,flw,nonce,encrypt}=require('./_flw');
module.exports=async function(req,res){
 if(req.method!=='POST')return json(res,405,{message:'Method not allowed'});
 try{
  const {chargeId,type,value}=req.body||{}; if(!chargeId||!value)return json(res,400,{message:'Missing authorization details.'});
  let authorization;
  if(type==='pin'){const n=nonce();authorization={type:'pin',pin:{nonce:n,encrypted_pin:encrypt(String(value),env('FLW_V4_ENCRYPTION_KEY'),n)}};}
  else if(type==='otp')authorization={type:'otp',otp:{code:String(value)}};
  else return json(res,400,{message:'Unsupported authorization type.'});
  const r=await flw(`/charges/${encodeURIComponent(chargeId)}`,{method:'PUT',body:JSON.stringify({authorization})});
  const d=r.data||{}; return json(res,200,{chargeId:d.id,status:d.status,nextAction:d.next_action||null,redirectUrl:d.next_action?.redirect_url?.url||d.redirect_url||null});
 }catch(e){return json(res,500,{message:e.message||'Authorization failed'});}
};
