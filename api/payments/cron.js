const crypto=require('crypto');
const {json,env,flw}=require('./_flw');
const {listSubscriptions,saveSubscription}=require('./store-cron');
const PRICES={USD:1.99,NGN:2000};
// After this many consecutive failed renewal attempts (roughly this many days,
// since the cron runs daily and only retries the next day on failure), stop
// retrying and mark the subscription cancelled instead of charging forever
// against a card that will never succeed.
const MAX_CONSECUTIVE_FAILURES=3;
module.exports=async function(req,res){
 if(req.method!=='GET')return json(res,405,{message:'Method not allowed'});
 if(req.headers.authorization!==`Bearer ${env('CRON_SECRET')}`)return json(res,401,{message:'Unauthorized'});
 try{
  const now=Date.now(),items=await listSubscriptions();let processed=0,failed=0,cancelled=0;
  for(const s of items){
   if(s.status!=='active'||!s.nextChargeAt||new Date(s.nextChargeAt).getTime()>now)continue;
   try{
    const reference=`WK-R-${Date.now()}-${crypto.randomBytes(5).toString('hex')}`;
    const amount=PRICES[s.currency];if(amount==null)throw new Error('Unsupported subscription currency');
    const r=await flw('/charges',{method:'POST',body:JSON.stringify({reference,currency:s.currency,customer_id:s.customerId,payment_method_id:s.paymentMethodId,recurring:true,amount,meta:{product:'Writing Kids Premium',billing:'monthly'}})});
    const d=r.data||{};
    if(d.status==='succeeded'){
      s.nextChargeAt=nextMonth(s.nextChargeAt);s.lastChargeReference=reference;s.lastStatus='succeeded';s.failCount=0;await saveSubscription(s);
      processed++;
    }else{
      failed++;s.lastStatus=d.status||'failed';s.failCount=(s.failCount||0)+1;
      if(s.failCount>=MAX_CONSECUTIVE_FAILURES){s.status='cancelled';cancelled++;}
      else s.nextChargeAt=new Date(Date.now()+24*60*60*1000).toISOString();
      await saveSubscription(s);
    }
   }catch(e){
    failed++;s.lastStatus='failed';s.failCount=(s.failCount||0)+1;
    if(s.failCount>=MAX_CONSECUTIVE_FAILURES){s.status='cancelled';cancelled++;}
    else s.nextChargeAt=new Date(Date.now()+24*60*60*1000).toISOString();
    await saveSubscription(s);
   }
  }
  return json(res,200,{ok:true,processed,failed,cancelled});
 }catch(e){return json(res,500,{message:e.message||'Recurring billing job failed'});}
};
function nextMonth(iso){const d=new Date(iso);const day=d.getUTCDate();d.setUTCMonth(d.getUTCMonth()+1);if(d.getUTCDate()!==day)d.setUTCDate(0);return d.toISOString();}
