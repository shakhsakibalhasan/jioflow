import {createEcourierProvider,ecourierOptions} from './ecourier-provider.mjs';
import {courierDefinition,courierCapabilities} from '../courier-catalog.mjs';
import {createPathaoProvider,pathaoOptions,pathaoHistoryResult} from './pathao-provider.mjs';
// Server only. Never include server/ or environment files in dist/.
import {openKeys,sealKeys} from './courier-secrets.mjs';
import {randomUUID,timingSafeEqual,createHash} from 'node:crypto';
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
export function historyResult(raw){
 const data=raw?.data&&typeof raw.data==='object'?raw.data:raw||{};
 const number=v=>typeof v==='number'?v:typeof v==='string'&&/^\d+(?:\.\d+)?$/.test(v.trim())?Number(v):null;
 const count=v=>{const n=number(v);return Number.isSafeInteger(n)&&n>=0?n:null};
 const percent=v=>{const n=number(v);return n!==null&&Number.isFinite(n)&&n>=0&&n<=100?n:null};
 const delivered=count(data.delivered_count),cancelled=count(data.cancelled_count),ratio=percent(data.delivery_ratio),available=delivered!==null||cancelled!==null||ratio!==null;
 return {id:'steadfast',name:'Steadfast',connected:true,status:available?'ready':'unavailable',delivered,cancelled,delivery_ratio:ratio,cancellation_ratio:percent(data.cancellation_ratio),total_reports:count(data.total_reports),volume_range:typeof data.volume_range==='string'?data.volume_range:null,...(!available?{error:'Steadfast returned no recognized phone history fields. Check API access for this account.'}:{})};
}

const historyCache=new Map();
export function createSteadfastService({env=process.env,fetcher=fetch,now=()=>Date.now(),cache=historyCache}={}){
 const c=configuration(env);
 async function rpc(name,body,token,server=false){
  const key=server?c.secret:c.publicKey,auth=server?c.secret:token;
  const response=await fetcher(c.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,'Content-Type':'application/json',...(!auth.startsWith('sb_secret_')?{Authorization:'Bearer '+auth}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(7000)});
  const data=await response.json().catch(()=>null);
  if(!response.ok)throw new RequestError(data?.code==='PGRST202'?'Apply Database58.sql to enable courier branding and history settings.':data?.code==='42501'?'Courier access denied.':data?.message?.startsWith('Confirm the order')?'Confirm the order before booking.':data?.message?.startsWith('Booking is already')?'Booking is processing. Check again after 90 seconds.':data?.message?.startsWith('Check recipient')?'Check recipient name, phone, address, note and COD amount.':/^(Pathao |Choose a verified|Add a separate|Check Pathao|Check the courier|This method has open shipments|Choose an active courier|This order already uses another delivery method|Courier method unavailable|Enter both API keys)/.test(data?.message||'')?data.message:'Courier records could not be updated.',response.status===401?401:data?.code==='42501'?403:409);
  return data;
 }
 async function provider(keys,path,body){
  let response;try{response=await fetcher(BASE+path,{method:body?'POST':'GET',headers:{'Api-Key':keys.api_key,'Secret-Key':keys.secret_key,'Content-Type':'application/json',Accept:'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(6500)})}catch{throw new RequestError(body?'Booking outcome is uncertain. Retry this same saved order after 90 seconds; never create a replacement order.':'Steadfast did not respond. Please try again later.',503)}
  const data=await response.json().catch(()=>null);
  if(!response.ok||Number(data?.status)!==200){const code=response.ok?Number(data?.status):response.status;const error=new RequestError(code===401?'Steadfast rejected the API keys. Ask your administrator to update them.':code===403?'Steadfast has restricted booking/access. Complete ownership details in the merchant panel.':code===429?'Steadfast rate limit reached. Stop retries and try later.':body?'Steadfast did not confirm this booking. Check the same invoice in the merchant panel before retrying.':'Steadfast could not return this record.',[401,403,429].includes(code)?code:502);if(code===429){const header=response.headers?.get?.('retry-after');const delay=header&&/^\d+$/.test(header)?Number(header):header?Math.ceil((Date.parse(header)-now())/1000):3600;error.retryAfter=Math.max(60,Math.min(3600,Number.isFinite(delay)?delay:3600));}error.definitiveRejection=[401,403,422].includes(code);throw error}
  return data;
 }
 async function apply(shop,id,data){return rpc('jf_courier_apply',{target_shop:shop,shipment_id:id,provider_data:data},null,true)}
 async function status(keys,s){const data=await provider(keys,'/status_by_cid/'+encodeURIComponent(s.consignment_id));if(!STATUSES.has(data.delivery_status))throw new RequestError('Unrecognized courier status. The previous status was kept.',502);return apply(s.shop_id,s.id,data)}
 async function savedMethods(shop,token){const result=await rpc('jf_delivery_methods',{target_shop:shop},token);return {...result,methods:(result.methods||[]).map(m=>{const preset=courierDefinition(m.provider==='custom'?m.provider_options?.courier_type:m.provider);return {...m,...(preset.preset_id?{preset_id:preset.preset_id,logo_asset:preset.logo_asset,brand_color:m.brand_color||preset.brand_color}:{})}})}}
 async function savedKey(shop,id){const rows=await rpc('jf_delivery_method_secrets',{target_shop:shop,target_method:id},null,true),m=rows.find(x=>x.id===id);if(!m)throw new RequestError('Courier method unavailable.',404);return {...m,...openKeys(env,shop,id,m.sealed)}}
 async function selectedKey(shop,id,methods){if(id)return savedKey(shop,id);const active=methods.methods.filter(m=>m.active&&(m.provider!=='custom'||String(m.provider_options?.courier_type).toLowerCase()==='ecourier'));const m=active.find(m=>m.preferred)||active[0];return m?savedKey(shop,m.id):methods.has_methods?null:credentials(env,shop)}
 const ecourier=createEcourierProvider({fetcher});
 const isEcourier=k=>k?.provider==='custom'&&String(k.provider_options?.courier_type).toLowerCase()==='ecourier';
 const isInstalled=k=>!!k&&(k.provider!=='custom'||isEcourier(k));
 async function ecourierSync(keys,s){return rpc('jf_ecourier_apply',{target_shop:s.shop_id,shipment_id:s.id,provider_data:await ecourier.track(keys,s.consignment_id,s.provider_invoice)},null,true)}
 const pathao=createPathaoProvider({fetcher,now,persist:async keys=>{const {api_key,secret_key,username,password,access_token,refresh_token,expires_at}=keys;const encrypted=sealKeys(env,keys.shop_id,keys.id,{api_key,secret_key,username,password,access_token,refresh_token,expires_at});await rpc('jf_delivery_method_token_store',{target_shop:keys.shop_id,target_method:keys.id,expected_cipher:keys.sealed,encrypted},null,true);keys.sealed=encrypted}});
 async function pathaoSync(keys,s){const data=await pathao.track(keys,s.consignment_id);return rpc('jf_pathao_apply',{target_shop:s.shop_id,shipment_id:s.id,provider_data:data},null,true)}
 async function execute(token,input){
  if(!uuid.test(input.shop_id||''))throw new RequestError('Choose a business.');
  if(!['info','history','book','sync','methods','method_save','method_remove','method_check','reconcile'].includes(input.action))throw new RequestError('Unsupported courier action.');
  if(['book','sync','reconcile'].includes(input.action)&&!uuid.test(input.order_id||''))throw new RequestError('Choose a saved order.');
  const access=await rpc('jf_courier_access',{target_shop:input.shop_id,target_order:input.order_id||null},token);
  if(input.order_id&&['info','reconcile'].includes(input.action))access.can_configure=(await rpc('jf_courier_access',{target_shop:input.shop_id,target_order:null},token)).can_configure===true;
  if(input.action==='methods'){let result=await savedMethods(input.shop_id,token);result={...result,methods:result.methods.map(m=>({...m,capabilities:courierCapabilities(m)}))};if(!result.can_configure)return result;return {...result,methods:await Promise.all(result.methods.map(async m=>{let email=m.auth_email||'';if(m.provider==='pathao'&&!email){try{email=(await savedKey(input.shop_id,m.id)).username||''}catch{}}return {...m,credentials_saved:true,...(m.provider==='pathao'?{auth_email:email}:{})}}))}}
  if(input.action.startsWith('method_')){
   if(access.can_configure!==true)throw new RequestError('Integration permission required.',403);
   if(input.method_id&&!uuid.test(input.method_id))throw new RequestError('Choose a courier method.');
   if(input.action==='method_save'){
    const id=input.method_id||randomUUID(),api=String(input.api_key||'').trim(),secret=String(input.secret_key||'').trim(),providerName=input.details?.provider||'steadfast';let sealed=null;
    if(!['steadfast','pathao','custom'].includes(providerName))throw new RequestError('Choose a supported API courier.');
    if(providerName==='custom'){const entries={api_key:api,secret_key:secret,access_token:String(input.access_token||''),username:String(input.username||''),password:String(input.password||''),client_context:String(input.client_context||''),user_id:String(input.user_id||'')};if(Object.values(entries).some(Boolean)){if(Object.values(entries).some(v=>v.length>2000||/[\r\n]/.test(v)))throw new RequestError('Use API credentials up to 2000 characters without newlines.');sealed=sealKeys(env,input.shop_id,id,{kind:'custom',credentials:entries})}const options=input.details?.provider_options||{},base=String(options.base_url||'').trim();if(base){try{const u=new URL(base);if(u.protocol!=='https:'||u.username||u.password||base.length>500)throw Error()}catch{throw new RequestError('Use a valid HTTPS API base URL.')}}if(!String(options.courier_type||'').trim()||String(options.courier_type).length>80)throw new RequestError('Enter the courier name.');input.details={...input.details,booking_enabled:options.courier_type.toLowerCase()==='ecourier'&&input.details.booking_enabled===true,preferred:options.courier_type.toLowerCase()==='ecourier'&&input.details.preferred===true,provider_options:options.courier_type.toLowerCase()==='ecourier'?ecourierOptions(options):{courier_type:String(options.courier_type).trim(),base_url:base}};}
    else if(api||secret||input.username||input.password){if(!api||!secret||api.length>512||secret.length>512||/[\r\n]/.test(api+secret))throw new RequestError('Enter both API credentials (up to 512 characters each).');let values={api_key:api,secret_key:secret};if(providerName==='pathao'){const username=String(input.username||'').trim(),password=String(input.password||'');if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(username)||!password||username.length>254||password.length>512)throw new RequestError('Enter Pathao merchant email and password with Client ID and Client Secret.');values={...values,username,password}}sealed=sealKeys(env,input.shop_id,id,values)}
    if(providerName==='pathao')input.details={...input.details,provider_options:pathaoOptions(input.details?.provider_options)};
    if(input.method_id){const existing=(await savedMethods(input.shop_id,token)).methods.find(m=>m.id===input.method_id);if(!existing||existing.provider!==providerName||providerName==='custom'&&courierDefinition(existing.provider_options?.courier_type).id!==courierDefinition(input.details?.provider_options?.courier_type).id)throw new RequestError('Add a separate courier method to change provider.');}
    if(providerName==='pathao'){let email=String(input.username||'').trim();if(!email&&input.method_id)email=(await savedKey(input.shop_id,input.method_id)).username||'';input.details={...input.details,auth_email:email}}
    const logo=input.details?.logo_path,color=input.details?.brand_color;if(logo!==undefined&&(typeof logo!=='string'||logo.length>360000||logo!==''&&!/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(logo)))throw new RequestError('Upload a PNG, JPEG or WebP courier logo under 250 KB.');if(color!==undefined&&!/^#[a-f\d]{6}$/i.test(color))throw new RequestError('Choose a valid brand color.');
    if(providerName==='custom'&&isEcourier({provider:'custom',provider_options:input.details.provider_options})&&sealed){const v=openKeys(env,input.shop_id,id,sealed).credentials;if(!v.api_key||!v.secret_key||!v.user_id)throw new RequestError('Enter eCourier API Key, API Secret and User ID.');}
    if(!input.method_id&&!sealed)throw new RequestError('Enter the courier API credentials.');
    const saved=await rpc('jf_delivery_method_save',{target_shop:input.shop_id,method_id:id,details:input.details,encrypted_keys:sealed},token);return {id:saved,message:'Courier method saved.'};
   }
   if(!input.method_id)throw new RequestError('Choose a courier method.');
   if(input.action==='method_remove'){await rpc('jf_delivery_method_remove',{target_shop:input.shop_id,method_id:input.method_id},token);return {message:'Courier removed from available delivery methods. Existing parcel tracking is preserved.'};}
   const method=(await savedMethods(input.shop_id,token)).methods.find(m=>m.id===input.method_id);if(!method)throw new RequestError('Courier method unavailable.',404);
   if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)throw new RequestError('Please wait a minute before more connection checks.',429);
   const k=await savedKey(input.shop_id,input.method_id);if(k.provider==='custom'&&!isEcourier(k))throw new RequestError('API credentials are saved. Backend adapter is not installed for this courier yet.',409);try{if(isEcourier(k))await ecourier.check(k);else if(k.provider==='pathao'){k.provider_options=pathaoOptions(k.provider_options);await pathao.check(k)}else await provider(k,'/get_balance');await rpc('jf_delivery_method_checked',{target_shop:input.shop_id,target_method:input.method_id,result:'verified'},null,true);return {message:'Connection verified. No parcel was booked.'}}catch(e){await rpc('jf_delivery_method_checked',{target_shop:input.shop_id,target_method:input.method_id,result:'failed'},null,true);throw e}
  }
  const methods=await savedMethods(input.shop_id,token),preferred=methods.methods.find(m=>m.id===access.order?.preferred_method_id&&m.active),selectedId=access.shipment?.method_id||input.method_id||preferred?.id;
  if(input.method_id&&!uuid.test(input.method_id))throw new RequestError('Choose a courier method.');
  if(!access.shipment?.method_id&&input.method_id&&!methods.methods.some(m=>m.id===input.method_id&&m.active))throw new RequestError('Choose an active courier method.',403);
  let keys=access.shipment?.consignment_id&&!access.shipment.method_id?credentials(env,input.shop_id):await selectedKey(input.shop_id,selectedId,methods);
  if(input.action==='info')return {provider:isEcourier(keys)?'ecourier':keys?.provider||'steadfast',can_configure:access.can_configure===true,configured:isInstalled(keys),booking_enabled:keys?.booking_enabled===true,can_book:access.can_book,methods:methods.methods.filter(m=>m.active).map(m=>({...m,capabilities:courierCapabilities(m)})),selected_method_id:keys?.id||null,shop_id:input.shop_id,polling_enabled:env.JIOFLOW_POLL_ENABLED==='true',...(access.can_configure?{callback_mode:'polling',shop_reference:input.shop_id}:{}),...(access.order?{order:access.order,shipment:access.shipment}:{})};
  if(input.action==='history'){
   const phone=String(input.phone||'').replace(/^\+?88/,'');if(!/^01\d{9}$/.test(phone))throw new RequestError('Enter an eleven-digit Bangladesh phone number.');
   const only=input.history_only_method_id;if(only&&(!uuid.test(only)||!methods.methods.some(m=>m.id===only&&m.active)))throw new RequestError('Choose an active courier method.',403);
   const candidates=methods.methods.filter(m=>!only||m.id===only),pathaoMethod=candidates.find(m=>m.provider==='pathao'&&m.active&&m.check_status==='verified'&&m.history_enabled!==false),sf=candidates.find(m=>m.provider==='steadfast'&&m.active&&m.preferred&&m.history_enabled!==false)||candidates.find(m=>m.provider==='steadfast'&&m.active&&m.history_enabled!==false);
   keys=sf?await savedKey(input.shop_id,sf.id):methods.has_methods||only?null:credentials(env,input.shop_id);
   const ecMethod=candidates.find(m=>isEcourier(m)&&m.active&&m.check_status==='verified'&&m.history_enabled!==false);
   const ecTask=(async()=>{if(!ecMethod)return null;const k=await savedKey(input.shop_id,ecMethod.id),key='ec:'+createHash('sha256').update(JSON.stringify([input.shop_id,k.id,k.sealed,phone])).digest('hex');let entry=cache.get(key);if(!entry||entry.until<=now()){if(cache.size>=500)cache.delete(cache.keys().next().value);entry={until:now()+60000,promise:(async()=>{try{if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)throw new RequestError('Please wait before checking history again.',429);return await ecourier.history(k,phone)}catch(e){return {id:'ecourier',name:'eCourier',connected:true,status:'unavailable',error:e.message}}})()};cache.set(key,entry)}return {...await entry.promise,logo_path:ecMethod.logo_path||'',brand_color:ecMethod.brand_color}})();
   const ownTask=rpc('jf_phone_own_record',{target_shop:input.shop_id,phone:String(input.phone||'')},token);
   const pathaoTask=(async()=>{if(!pathaoMethod)return null;const k=await savedKey(input.shop_id,pathaoMethod.id),brand={logo_path:pathaoMethod.logo_path||'',brand_color:pathaoMethod.brand_color},base={id:'pathao',name:'Pathao',connected:true,...brand};
    if(k.provider_options?.environment!=='production')return {...base,status:'unavailable',error:'Use a production Pathao connection for live customer history.'};
    const account='pathao-account:'+createHash('sha256').update(JSON.stringify([input.shop_id,k.id,k.api_key,k.secret_key,k.username])).digest('hex'),key='pathao-phone:'+createHash('sha256').update(account+phone).digest('hex');let entry=cache.get(key);
    if(!entry||entry.until<=now()){for(const [key,v]of cache)if(v.until<=now())cache.delete(key);if(cache.size>=500)cache.delete(cache.keys().next().value);entry={until:now()+60000,promise:(async()=>{const block=cache.get(account);if(block&&block.until>now())return block.provider;if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)return {id:'pathao',name:'Pathao',connected:true,status:'unavailable',error:'Please wait one minute before checking history again.'};try{return {...pathaoHistoryResult(await pathao.history({...k,provider_options:pathaoOptions(k.provider_options)},phone)),checked_at:new Date(now()).toISOString()}}catch(e){const p={id:'pathao',name:'Pathao',connected:true,status:'unavailable',error:[401,403].includes(e.status)?'Pathao denied customer-history access. Verify production credentials and merchant history permission.':e.status===429?'Pathao history rate limit reached. Please wait before retrying.':'Pathao could not return customer history. Try again later.'};if([401,403,429].includes(e.status))cache.set(account,{until:now()+60000,provider:p});return p}})()};cache.set(key,entry)}
    return {...await entry.promise,...brand};
   })();
   if(!keys){const [own,p,e]=await Promise.all([ownTask,pathaoTask,ecTask]);return {own,providers:[...(p?[p]:[]),...(e?[e]:[])]}}
   const accountKey='account:'+createHash('sha256').update(JSON.stringify([input.shop_id,keys.id||'',keys.api_key,keys.secret_key])).digest('hex');
   const cacheKey='phone:'+createHash('sha256').update(accountKey+phone).digest('hex');
   let entry=cache.get(cacheKey);
   if(!entry||entry.until<=now()){
    for(const [key,value]of cache)if(value.until<=now())cache.delete(key);
    if(cache.size>=500)cache.delete(cache.keys().next().value);
    entry={until:now()+60000};
    entry.promise=(async()=>{
     if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)return {id:'steadfast',name:'Steadfast',connected:true,status:'unavailable',error:'Please wait one minute before checking again.',retry_at:new Date(now()+60000).toISOString()};
     const block=cache.get(accountKey);if(block&&block.until>now())return block.provider;
     try{return {...historyResult(await provider(keys,'/fraud_check/score/'+phone)),checked_at:new Date(now()).toISOString()}}
     catch(e){const wait=(e.retryAfter||3600)*1000,p={id:'steadfast',name:'Steadfast',connected:true,status:'unavailable',error:e.status===429?'Steadfast has temporarily blocked API requests. Check the saved API credentials; repeated authentication failures may block requests for up to 60 minutes.':e.message,...(e.status===429?{error_code:'provider_rate_limit',retry_at:new Date(now()+wait).toISOString()}:{} )};if(e.status===429)cache.set(accountKey,{until:now()+wait,provider:p});return p;}
    })();cache.set(cacheKey,entry);
    entry.promise.catch(()=>{if(cache.get(cacheKey)===entry)cache.delete(cacheKey)});
   }
   const [p,own,pathaoResult,ecResult]=await Promise.all([entry.promise,ownTask,pathaoTask,ecTask]);
   return {own,providers:[{...p,logo_path:sf?.logo_path||'',brand_color:sf?.brand_color},...(pathaoResult?[pathaoResult]:[]),...(ecResult?[ecResult]:[])]};
  }
  if(await rpc('jf_courier_rate',{target_shop:input.shop_id},token)!==true)throw new RequestError('Please wait a minute before making more courier requests.',429);
  if(keys?.provider==='custom'&&!isEcourier(keys))throw new RequestError('This courier needs a backend adapter before booking or tracking.',409);
  if(!keys)throw new RequestError('Steadfast is not configured for this business.',503);
  if(isEcourier(keys)){
   if(input.action==='book'){
    if(!access.can_book||!keys.booking_enabled)throw new RequestError('eCourier booking permission is required.',403);
    const r=await rpc('jf_ecourier_reserve',{target_shop:input.shop_id,target_order:input.order_id,target_method:keys.id,delivery:input.delivery||{}},token);if(r.already_booked)return {message:'This order is already booked.',shipment:r.shipment};let data;
    try{data=await ecourier.book(keys,r.payload)}catch(e){if(e.definitiveRejection)await rpc('jf_ecourier_reject',{target_shop:input.shop_id,shipment_id:r.shipment_id},null,true);throw e}
    return {...await rpc('jf_ecourier_apply',{target_shop:input.shop_id,shipment_id:r.shipment_id,provider_data:data},null,true),message:'eCourier booking confirmed.'};
   }
   const s=access.shipment;if(!s||s.courier!=='ecourier'||s.method_id!==keys.id)throw new RequestError('No eCourier parcel is linked to this order.');
   if(input.action==='reconcile'){if(!access.can_configure)throw new RequestError('Integration permission required.',403);if(s.consignment_id)throw new RequestError('Parcel already attached.');if(!/^ECR[A-Za-z0-9-]{1,97}$/.test(input.consignment_id||''))throw new RequestError('Enter the eCourier parcel ID.');return {...await rpc('jf_ecourier_apply',{target_shop:input.shop_id,shipment_id:s.id,provider_data:await ecourier.track(keys,input.consignment_id,s.provider_invoice)},null,true),message:'eCourier parcel matched and attached.'}}
   if(!s.consignment_id)throw new RequestError('Check the eCourier merchant panel and attach its parcel ID before retrying.');
   return {message:'eCourier status updated.',...await ecourierSync(keys,s)};
  }
  if(keys.provider==='pathao'){
   keys.provider_options=pathaoOptions(keys.provider_options);
   if(input.action==='book'){
    if(!access.can_book||keys.booking_enabled!==true)throw new RequestError('Pathao booking permission and live booking are required.',403);
    const r=await rpc('jf_pathao_reserve',{target_shop:input.shop_id,target_order:input.order_id,target_method:keys.id},token);if(r.already_booked)return {message:'This order is already booked.',shipment:r.shipment};
    let data;try{data=await pathao.book(keys,r.payload)}catch(e){if(e.definitiveRejection)await rpc('jf_pathao_reject',{target_shop:input.shop_id,shipment_id:r.shipment_id},null,true);throw e}
    const result=await rpc('jf_pathao_apply',{target_shop:input.shop_id,shipment_id:r.shipment_id,provider_data:data},null,true);return {...result,message:'Pathao booking confirmed.'};
   }
   const s=access.shipment;if(!s||s.courier!=='pathao'||s.method_id!==keys.id)throw new RequestError('No Pathao shipment is linked to this order.');
   if(input.action==='reconcile'){
    if(access.can_configure!==true)throw new RequestError('Integration permission required to reconcile a parcel.',403);
    if(s.consignment_id)throw new RequestError('This parcel already has a Consignment ID. Refresh its status instead.');
    if(!/^[a-z0-9-]{1,100}$/i.test(input.consignment_id||''))throw new RequestError('Enter the Pathao Consignment ID from the merchant panel.');
    const data=await pathao.track(keys,input.consignment_id);return {...await rpc('jf_pathao_apply',{target_shop:input.shop_id,shipment_id:s.id,provider_data:data},null,true),message:'Pathao parcel matched and attached.'};
   }
   if(!s.consignment_id)throw new RequestError('Check Pathao merchant panel and attach the Consignment ID before retrying.');
   if(s.last_checked_at&&now()-Date.parse(s.last_checked_at)<60000)return {message:'Showing the latest saved Pathao status.',cached:true,status:s.status,provider_status:s.provider_status};
   return {message:'Pathao status updated.',...await pathaoSync(keys,s)};
  }
  if(input.action==='book'){
   if(!access.can_book)throw new RequestError('Courier booking permission required.',403);
   if(keys.booking_enabled!==true)throw new RequestError('Live booking is disabled. Your administrator can enable it after setup.',403);
   const reservation=await rpc('jf_courier_reserve',{target_shop:input.shop_id,target_order:input.order_id,...(keys.id?{target_method:keys.id}:{})},token);
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
  await Promise.all(Array.from({length:Math.min(4,rows.length)},async()=>{while(index<rows.length&&now()-start<35000){const s=rows[index++];try{const keys=s.method_id?await savedKey(s.shop_id,s.method_id):credentials(env,s.shop_id),blockedKey=s.shop_id+':'+(s.method_id||'legacy');if(!keys)throw new RequestError('Courier credentials missing for this business.',503);if(blocked.has(blockedKey))throw new RequestError('Courier credentials or rate limit require attention.',503);let result;try{result=isEcourier(keys)?await ecourierSync(keys,s):keys.provider==='pathao'?await pathaoSync({...keys,provider_options:pathaoOptions(keys.provider_options)},s):await status(keys,s)}catch(e){if([401,403,429].includes(e.status))blocked.set(blockedKey,true);throw e}checked++;if(result.changed)changed++;}catch(e){failed++;await rpc('jf_courier_poll_error',{target_shop:s.shop_id,shipment_id:s.id,error_message:e instanceof RequestError?e.message:'Status refresh failed.'},null,true).catch(()=>{})}}}));
  return {enabled:true,checked,changed,failed,batch_size:20,has_more:rows.length===20};
 }
 return {execute,poll,origin:c.origin};
}
