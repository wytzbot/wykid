const {json}=require('./_flw'); const {getSubscription}=require('./store');
// Billing runs on a once-a-day Vercel Cron job, so a subscription can sit for up
// to ~24h past its exact next_charge_at before the renewal charge actually runs.
// Gating premium access strictly on "nextChargeAt > now" would silently lock a
// paying child out of Premium for up to a day every single month even though
// nothing failed. A short grace window keeps access smooth through that window;
// the cron/webhook still moves nextChargeAt forward (or the status to
// 'cancelled') once it actually processes the renewal.
const GRACE_MS=2*24*60*60*1000;
module.exports=async function(req,res){if(req.method!=='GET')return json(res,405,{message:'Method not allowed'});try{const email=String(req.query.email||'').trim().toLowerCase();if(!/^\S+@\S+\.\S+$/.test(email))return json(res,400,{message:'Valid email is required.'});const s=await getSubscription(email);const active=Boolean(s&&s.status==='active'&&s.nextChargeAt&&(new Date(s.nextChargeAt).getTime()+GRACE_MS)>Date.now());return json(res,200,{active,email,status:s?.status||'none',nextChargeAt:s?.nextChargeAt||null});}catch(e){return json(res,500,{message:e.message||'Subscription check failed'});}};
