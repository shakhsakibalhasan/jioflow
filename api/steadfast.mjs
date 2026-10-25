import { timingSafeEqual } from 'node:crypto';

const BASE = 'https://portal.packzy.com/api/v1';
const send = (res, status, data) => res.status(status).json(data);
const timeout = (ms=12000) => AbortSignal.timeout(ms);
const s = (v) => String(v ?? '').trim();
const env = (k) => process.env[k] || '';
const projectUrl = () => s(env('SUPABASE_URL') || env('VITE_SUPABASE_URL')).replace(/\/$/, '');
const serviceKey = () => env('SUPABASE_SERVICE_ROLE_KEY') || env('SUPABASE_SECRET_KEY');
const publicKey = () => env('SUPABASE_PUBLISHABLE_KEY') || env('SUPABASE_ANON_KEY') || env('VITE_SUPABASE_PUBLISHABLE_KEY') || env('VITE_SUPABASE_ANON_KEY');

async function jsonFetch(url, options) {
  const r = await fetch(url, { ...options, signal: timeout() });
  const body = await r.json().catch(() => null);
  return { ok: r.ok, status: r.status, body };
}
const supaHeaders = () => ({
  apikey: serviceKey(),
  Authorization: `Bearer ${serviceKey()}`,
  'Content-Type': 'application/json'
});
async function db(path, method='GET', body) {
  if (!projectUrl() || !serviceKey()) throw new Error('Database configuration incomplete');
  const result = await jsonFetch(`${projectUrl()}/rest/v1/${path}`,{
    method,
    headers:{...supaHeaders(), Prefer:'return=representation'},
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  });
  if (!result.ok) throw new Error(`Database request failed (${result.status})`);
  return result.body;
}
async function auth(req) {
  const token = /^Bearer\s+(\S+)$/i.exec(s(req.headers.authorization))?.[1];
  if (!token) return {status:401,error:'Login required'};
  if (!projectUrl() || !publicKey() || !serviceKey()) return {status:503,error:'Supabase configuration incomplete'};
  const u = await jsonFetch(`${projectUrl()}/auth/v1/user`,{
    headers: { apikey: publicKey(),Authorization:`Bearer ${token}` }
  });
  if (!u.ok || !u.body?.id) return {status:401,error:'Invalid session'};
  // Service role reads active profile; never trust role fields provided by browser.
  const rows = await db(`jf_profiles?select=id,active,deleted_at,role&id=eq.${encodeURIComponent(u.body.id)}&limit=1`);
  const p = rows?.[0];
  if (!p || p.active !== true || p.deleted_at || !['owner','admin','creator'].includes(s(p.role).toLowerCase())) {
    return {status:403,error:'Courier permission denied'};
  }
  return {userId:u.body.id};
}
function headers(){
  if (!env('STEADFAST_API_KEY') || !env('STEADFAST_SECRET_KEY')) throw new Error('Steadfast configuration incomplete');
  return {'Api-Key':env('STEADFAST_API_KEY'),'Secret-Key':env('STEADFAST_SECRET_KEY'),Accept:'application/json','Content-Type':'application/json'};
}
async function steadfast(path, method='GET', payload){
  const result=await jsonFetch(`${BASE}/${path}`,{
    method, headers:headers(),
    ...(payload===undefined?{}:{body:JSON.stringify(payload)})
  });
  if (!result.ok || !result.body) throw new Error(`Courier upstream request failed (${result.status})`);
  return result.body;
}
function bookingInput(v){
  const invoice=s(v.invoice), recipient_name=s(v.recipient_name), recipient_phone=s(v.recipient_phone),
    recipient_address=s(v.recipient_address), cod_amount=Number(v.cod_amount), note=s(v.note);
  if(!/^[A-Za-z0-9_-]{1,70}$/.test(invoice) || !recipient_name || recipient_name.length>100 ||
     !/^01[0-9]{9}$/.test(recipient_phone) || !recipient_address || recipient_address.length>250 ||
     !Number.isFinite(cod_amount) || cod_amount<0 || cod_amount>10000000 || note.length>480) return null;
  return {invoice,recipient_name,recipient_phone,recipient_address,cod_amount,...(note?{note}:{})};
}
function safeValue(v){return /^[A-Za-z0-9_-]{1,90}$/.test(s(v));}
async function handler(req,res){
  res.setHeader('Cache-Control','no-store');
  res.setHeader('Allow','POST');
  if(req.method!=='POST') return send(res,405,{success:false,error:'POST required'});
  if(!s(req.headers['content-type']).startsWith('application/json')) return send(res,415,{success:false,error:'JSON required'});
  try{
    const a=await auth(req);
    if(a.error) return send(res,a.status,{success:false,error:a.error});
    const input=typeof req.body==='string'?JSON.parse(req.body):req.body;
    if(!input || typeof input!=='object') return send(res,400,{success:false,error:'Invalid request'});
    if(input.action==='status'){
      if(!['cid','invoice','tracking'].includes(input.by)||!safeValue(input.value))return send(res,400,{success:false,error:'Invalid lookup'});
      const method={cid:'status_by_cid',invoice:'status_by_invoice',tracking:'status_by_trackingcode'}[input.by];
      const data=await steadfast(`${method}/${encodeURIComponent(s(input.value))}`);
      return send(res,200,{success:true,delivery_status:data.delivery_status??null,data});
    }
    if(input.action==='history'){
      // Steadfast merchant customer history API path can vary across merchant versions.
      // Explicitly not guessed here. View verified data stored for a specific invoice instead.
      if(!safeValue(input.invoice)) return send(res,400,{success:false,error:'Invalid invoice'});
      const history=await db(`jf_steadfast_events?select=delivery_status,received_at,invoice,consignment_id&invoice=eq.${encodeURIComponent(s(input.invoice))}&order=received_at.desc&limit=100`);
      return send(res,200,{success:true,events:history});
    }
    if(input.action==='book'){
      if(env('STEADFAST_ENABLE_BOOKING')!=='true')return send(res,403,{success:false,error:'Live booking disabled'});
      const payload=bookingInput(input);
      if(!payload) return send(res,400,{success:false,error:'Invalid booking details'});
      // This table requires a unique invoice. Insertion is attempted ONCE, before the courier call.
      // An existing invoice, including a prior failed/unknown request, must be manually reconciled.
      const record=await db('jf_steadfast_bookings','POST',{
        invoice:payload.invoice,created_by:a.userId,state:'requesting'
      }).catch(e=>null);
      if(!record?.[0])return send(res,409,{success:false,error:'Invoice already reserved or database unavailable; investigate before retrying'});
      let data;
      try {data=await steadfast('create_order','POST',payload);}
      catch(e){
        await db(`jf_steadfast_bookings?invoice=eq.${encodeURIComponent(payload.invoice)}`,'PATCH',{state:'needs_reconciliation'}).catch(()=>{});
        return send(res,502,{success:false,error:'Courier outcome uncertain. Check merchant dashboard before retrying.'});
      }
      const c=data?.consignment;
      if(data.status!==200 || !c?.consignment_id){
        await db(`jf_steadfast_bookings?invoice=eq.${encodeURIComponent(payload.invoice)}`,'PATCH',{state:'needs_reconciliation'}).catch(()=>{});
        return send(res,502,{success:false,error:'Courier did not confirm. Check merchant dashboard before retrying.'});
      }
      const recordUpdate={
        state:'booked',consignment_id:String(c.consignment_id),
        tracking_code:c.tracking_code?String(c.tracking_code):null,
        delivery_status:c.status?String(c.status):null
      };
      try {await db(`jf_steadfast_bookings?invoice=eq.${encodeURIComponent(payload.invoice)}`,'PATCH',recordUpdate);}
      catch(e){return send(res,202,{success:true,warning:'Booked with Steadfast, but CRM tracking record requires reconciliation',consignment_id:recordUpdate.consignment_id,tracking_code:recordUpdate.tracking_code});}
      return send(res,200,{success:true,invoice:payload.invoice,consignment_id:recordUpdate.consignment_id,tracking_code:recordUpdate.tracking_code,delivery_status:recordUpdate.delivery_status});
    }
    return send(res,400,{success:false,error:'Allowed actions: book, status, history'});
  }catch(e){
    if(e instanceof SyntaxError) return send(res,400,{success:false,error:'Invalid JSON'});
    return send(res,503,{success:false,error:'Courier or database temporarily unavailable'});
  }
}
export default handler;
