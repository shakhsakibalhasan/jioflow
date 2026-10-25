// Server only. Never include server/ or environment files in dist/.
import {timingSafeEqual} from 'node:crypto';
import {configuration,RequestError} from './account-service.mjs';
const BASE='https://portal.packzy.com/api/v1';
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const STATUSES=new Set(['pending','in_review','hold','delivered_approval_pending','partial_delivered_approval_pending','cancelled_approval_pending','unknown_approval_pending','delivered','partial_delivered','cancelled','exceptional','unknown']);
export const sameSecret=(a,b)=>{if(typeof a!=='string'||typeof b!=='string')return false;const left=Buffer.from(a),right=Buffer.from(b);return left.length===right.length&&timingSafeEqual(left,right)};
export function credentials(env,shop){
 let map={};try{map=JSON.parse(env.STEADFAST_SHOPS_JSON||'{}')}catch{throw new RequestError('Courier server configuration is invalid.',503)}
 const keys=map?.[shop]||(env.STEADFAST_SHOP_ID===shop?{api_key:env.STEADFAST_API_KEY,secret_key:env.STEADFAST_SECRET_KEY,booking_enabled:env.STEADFAST_BOOKING_ENABLED==='true'}:null);
 if(!keys?.api_key||!keys?.secret_key)return null;
 if(typeof keys.api_key!=='string'||typeof keys.secret_key!=='string'||/[\r\n]/.test(keys.api_key+keys.secret_key))throw new RequestError('Courier server configuration is invalid.',503);
 return keys;
}
export function historyResult(data){
 const count=v=>Number.isSafeInteger(v)&&v>=0?v:null;
 const percent=v=>Number.isFinite(v)&&v>=0&&v<=100?v:null;
 return {id:'steadfast',name:'Steadfast',connected:true,status:'ready',delivered:count(data.delivered_count),cancelled:count(data.cancelled_count),delivery_ratio:percent(data.delivery_ratio),cancellation_ratio:percent(data.cancellation_ratio),total_reports:count(data.total_reports),volume_range:typeof data.volume_range==='string'?data.volume_range:null};
}
export function createSteadfastService({env=process.env,fetcher=fetch,now=()=>Date.now()}={}){
 const c=configuration(env);
 async function rpc(name,body,token,server=false){
  const key=server?c.secret:c.publicKey,auth=server?c.secret:token;
  const response=await fetcher(c.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(!auth.startsWith('sb_secret_')?{Authorization:'Bearer '+auth}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(7000)});
  const data=await response.json().catch(()=>null);
  if(!response.ok)throw new RequestError(data?.code==='PGRST202'?'Database update 025 is required.':data?.code==='42501'?'Courier access denied.':data?.message?.startsWith('Confirm the order')?'Confirm the order before booking.':data?.message?.startsWith('Booking is already')?'Booking is processing. Check again after 90 seconds.':data?.message?.startsWith('Check recipient')?'Check recipient name, phone, address, note and COD amount.':'Courier records could not be updated.',response.status===401?401:data?.code==='42501'?403:409);
  return data;
 }
 async function provider(keys,path,body){
  let response;try{response=await fetcher(BASE+path,{method:body?'POST':'GET',headers:{'Api-Key':keys.api_key,'Secret-Key':keys.secret_key,'Content-Type':'application/json',Accept:'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(6500)})}catch{throw new RequestError(body?'Booking outcome is uncertain. Retry this same saved order after 90 seconds; never create a replacement order.':'Steadfast did not respond. Please try again later.',503)}
  const data=await response.json().catch(()=>null);
  if(!response.ok||data?.status!==200){const code=response.ok?Number(data?.status):response.status;const error=new RequestError(code===401?'Steadfast rejected the API keys. Ask your administrator to update them.':code===403?'Steadfast has restricted booking/access. Complete ownership details in the merchant panel.':code===429?'Steadfast rate limit reached. Stop retries and try later.':body?'Steadfast did not confirm this booking. Check the same invoice in the merchant panel before retrying.':'Steadfast could not return this record.',[401,403,429].includes(code)?code:502);error.definitiveRejection=[401,403,422].includes(code);throw error}
  return data;
 }
 async function apply(shop,id,data){return rpc('jf_courier_apply',{target_shop:shop,shipment_id:id,provider_data:data},null,true)}
 async function status(keys,s){const data=await provider(keys,'/status_by_cid/'+encodeURIComponent(s.consignment_id));if(!STATUSES.has(data.delivery_status))throw new RequestError('Unrecognized courier status. The previous status was kept.',502);return apply(s.shop_id,s.id,data)}
 async function execute(token,input){
  if(!uuid.test(input.shop_id||''))throw new RequestError('Choose a business.');
  if(!['info','history','book','sync'].includes(input.action))throw new RequestError('Unsupported courier action.');
  if(['book','sync'].includes(input.action)&&!uuid.test(input.order_id||''))throw new RequestError('Choose a saved order.');
  const access=await rpc('jf_courier_access',{target_shop:input.shop_id,target_order:input.order_id||null},token),keys=credentials(env,input.shop_id);
  if(input.action==='info')return {configured:!!keys,booking_enabled:keys?.booking_enabled===true,can_book:access.can_book,shop_id:input.shop_id,polling_enabled:env.JIOFLOW_POLL_ENABLED==='true',...(access.can_configure?{callback_mode:'polling',shop_reference:input.shop_id}:{}),...(access.order?{order:access.order,shipment:access.shipment}:{})};
  if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)throw new RequestError('Please wait a minute before making more courier requests.',429);
  if(input.action==='history'){
   const local=await rpc('jf_phone_courier_overview',{target_shop:input.shop_id,phone:String(input.phone||'')},token);
   if(!keys)return local;
   const phone=String(input.phone||'').replace(/^\+?88/,'');if(!/^01\d{9}$/.test(phone))throw new RequestError('Enter an eleven-digit Bangladesh phone number.');
   let p;try{p=historyResult(await provider(keys,'/fraud_check/score/'+phone))}catch(e){p={id:'steadfast',name:'Steadfast',connected:true,status:'unavailable',error:e.message}}
   return {...local,providers:[p,...(local.providers||[]).filter(p=>p.id!=='steadfast')]};
  }
  if(!keys)throw new RequestError('Steadfast is not configured for this business.',503);
  if(input.action==='book'){
   if(!access.can_book)throw new RequestError('Courier booking permission required.',403);
   if(keys.booking_enabled!==true)throw new RequestError('Live booking is disabled. Your administrator can enable it after setup.',403);
   const reservation=await rpc('jf_courier_reserve',{target_shop:input.shop_id,target_order:input.order_id},token);
   if(reservation.already_booked)return {message:'This order is already booked.',shipment:reservation.shipment};
   let data;try{data=await provider(keys,'/create_order',reservation.payload)}catch(e){if(e.definitiveRejection)await rpc('jf_courier_reject',{target_shop:input.shop_id,shipment_id:reservation.shipment_id},null,true);throw e}
   if(String(data.consignment?.invoice)!==reservation.payload.invoice||!/^\d+$/.test(String(data.consignment?.consignment_id||'')))throw new RequestError('Booking response could not be verified. Check this invoice in Steadfast before retrying.',502);
   await apply(input.shop_id,reservation.shipment_id,data);
   return {message:'Steadfast booking confirmed.',consignment_id:String(data.consignment.consignment_id),tracking_code:data.consignment.tracking_code||null};
  }
  const s=access.shipment;if(!s?.consignment_id||s.courier!=='steadfast')throw new RequestError('No Steadfast shipment is linked to this order.');
  if(s.last_checked_at&&now()-Date.parse(s.last_checked_at)<60000)return {message:'Showing the latest saved status. Steadfast caches results for 60 seconds.',cached:true,status:s.status,provider_status:s.provider_status};
  return {message:'Courier status updated.',...await status(keys,s)};
 }
 async function poll(){
  if(env.JIOFLOW_POLL_ENABLED!=='true')return {enabled:false,checked:0,changed:0,failed:0,message:'Scheduled polling is disabled until setup is complete.'};
  const start=now(),rows=await rpc('jf_courier_poll_claim',{batch_size:20},null,true);let checked=0,changed=0,failed=0,index=0,blocked=new Map();
  await Promise.all(Array.from({length:Math.min(4,rows.length)},async()=>{while(index<rows.length&&now()-start<35000){const s=rows[index++];try{const keys=credentials(env,s.shop_id);if(!keys)throw new RequestError('Courier credentials missing for this business.',503);if(blocked.has(s.shop_id))throw new RequestError('Courier credentials or rate limit require attention.',503);let result;try{result=await status(keys,s)}catch(e){if([401,403,429].includes(e.status))blocked.set(s.shop_id,true);throw e}checked++;if(result.changed)changed++;}catch(e){failed++;await rpc('jf_courier_poll_error',{target_shop:s.shop_id,shipment_id:s.id,error_message:e instanceof RequestError?e.message:'Status refresh failed.'},null,true).catch(()=>{})}}}));
  return {enabled:true,checked,changed,failed,batch_size:20,has_more:rows.length===20};
 }
 return {execute,poll,origin:c.origin};
}
