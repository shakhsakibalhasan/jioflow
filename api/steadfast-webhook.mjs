import { timingSafeEqual } from 'node:crypto';
const send=(res,s,data)=>res.status(s).json(data);
const text=x=>String(x??'').trim();
const constantEqual=(a,b)=>{
  const x=Buffer.from(a), y=Buffer.from(b);
  return x.length===y.length && timingSafeEqual(x,y);
};
export default async function handler(req,res){
  res.setHeader('Cache-Control','no-store');
  if(req.method!=='POST')return send(res,405,{ok:false});
  const secret=process.env.STEADFAST_WEBHOOK_TOKEN;
  // Unauthenticated webhooks can forge orders. Exact token required in URL query
  // only if provider cannot send an authentication header.
  const token=text(req.headers['x-webhook-token'] || req.query?.token);
  if(!secret || secret.length<24 || !constantEqual(token,secret))return send(res,401,{ok:false});
  if(!text(req.headers['content-type']).startsWith('application/json'))return send(res,415,{ok:false});
  try{
    const data=typeof req.body==='string'?JSON.parse(req.body):req.body;
    if(!data || typeof data!=='object' || Array.isArray(data))return send(res,400,{ok:false});
    const invoice=text(data.invoice || data.merchant_order_id);
    const cid=text(data.consignment_id || data.consignment?.consignment_id);
    const status=text(data.delivery_status);
    if(!status || status.length>100 || (!invoice && !cid))return send(res,400,{ok:false});
    const url=text(process.env.SUPABASE_URL||process.env.VITE_SUPABASE_URL).replace(/\/$/,'');
    const key=process.env.SUPABASE_SERVICE_ROLE_KEY||process.env.SUPABASE_SECRET_KEY;
    if(!url||!key)return send(res,503,{ok:false});
    const headers={apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',Prefer:'return=minimal'};
    const r=await fetch(`${url}/rest/v1/jf_steadfast_events`,{
      method:'POST',headers,body:JSON.stringify({invoice:invoice||null,consignment_id:cid||null,delivery_status:status}),
      signal:AbortSignal.timeout(10000)
    });
    if(!r.ok)return send(res,503,{ok:false});
    // No automatic order status mutation without confirmed CRM schema and status map.
    return send(res,200,{ok:true});
  }catch(e){return send(res,503,{ok:false});}
}
