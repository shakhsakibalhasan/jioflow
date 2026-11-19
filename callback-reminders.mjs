const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// The reminder is sourced from the authenticated agent's server-side callback
// queue. It is only shown for due, still-assigned, approved-agent follow-ups.
export function createCallbackReminders({client,document:doc=globalThis.document,navigate,onInbox=()=>{},setTimer=setTimeout,clearTimer=clearTimeout}){
 let audio=null,scope=null,version=0,timer=null,busy=false,popup=null,current=null,due=[],inboxSignature='';
 const sounded=new Set(),notified=new Set(),muted=new Set();

 function playAlarm(id){
  if(!id||sounded.has(id)||!audio||audio.state!=='running')return;
  try{
   for(let i=0;i<3;i++){
    const oscillator=audio.createOscillator(),gain=audio.createGain(),t=audio.currentTime+i*.3;
    oscillator.connect(gain);gain.connect(audio.destination);
    oscillator.frequency.value=i%2?660:880;
    gain.gain.setValueAtTime(0,t);
    gain.gain.linearRampToValueAtTime(.12,t+.02);
    gain.gain.exponentialRampToValueAtTime(.001,t+.22);
    oscillator.start(t);oscillator.stop(t+.24);
   }
   // Do not consume the sound attempt before the browser has allowed audio.
   sounded.add(id);
  }catch{/* Keep the popup visible; a user gesture can unlock audio later. */}
 }
 function unlockAudio(){
  try{
   const Context=doc?.defaultView?.AudioContext||doc?.defaultView?.webkitAudioContext;
   if(!Context)return;
   audio??=new Context();
   const resumed=audio.resume?.();
   Promise.resolve(resumed).then(()=>{if(current?.id&&popup)playAlarm(current.id)}).catch(()=>{});
  }catch{/* Unsupported or blocked audio must not prevent visual reminders. */}
 }
 doc?.addEventListener?.('pointerdown',unlockAudio);
 doc?.addEventListener?.('keydown',unlockAudio);

 function desktopNotification(row){
  if(!row?.id||notified.has(row.id))return;
  const Notification=doc?.defaultView?.Notification;
  if(!Notification||Notification.permission!=='granted')return;
  try{
   const n=new Notification('JioFlow · Scheduled follow-up',{
    body:`It's time to follow up with ${row.full_name||'your customer'}.`,tag:'jioflow-callback-'+row.id
   });
   notified.add(row.id);
   n.onclick=()=>{doc.defaultView?.focus?.();n.close?.();};
  }catch{/* Browser/OS notification may be unavailable. The popup remains. */}
 }
 function remove(){popup?.remove();popup=null;current=null}
 function stop(){
  version++;scope=null;if(timer)clearTimer(timer);timer=null;busy=false;due=[];
  inboxSignature='';muted.clear();sounded.clear();notified.clear();remove();
 }
 async function acknowledge(row,open=false){
  const own=scope,turn=version;muted.add(row.id);remove();
  try{
   await client.rpc('jf_callback_popup_ack',{notification:row.id});
   if(open)await client.rpc('jf_notification_read',{notification:row.id});
  }catch{/* A failed network acknowledgement must not lock the popup. */}
  if(turn!==version||scope!==own)return;
  if(open&&scope)navigate('followups',{entity:'customers',search:row.phone,open_customer_id:row.customer_id});
  Promise.resolve(onInbox()).catch(()=>{});
 }
 function show(row){
  if(!row?.id||popup||!scope||muted.has(row.id))return;
  current=row;
  popup=doc.createElement('aside');
  popup.className='callback-reminder-popup';
  popup.setAttribute('role','alertdialog');
  popup.setAttribute('aria-label','Scheduled follow-up reminder');
  const localTime=Number.isFinite(Date.parse(row.callback_at))?
   new Date(row.callback_at).toLocaleString('en-GB',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit',timeZone:'Asia/Dhaka'}):'';
  popup.innerHTML=`<button type="button" data-callback-close aria-label="Close follow-up reminder">×</button><span class="callback-reminder-icon" aria-hidden="true">◷</span><div><small>Scheduled follow-up</small><h3>It’s time to follow up</h3><strong>${esc(row.full_name||'Customer')}</strong><p>${esc(row.phone)}</p><time datetime="${esc(row.callback_at)}">${esc(localTime)}</time><button type="button" class="primary" data-callback-open>Open follow-up</button></div>`;
  doc.body.append(popup);
  playAlarm(row.id);
  desktopNotification(row);
  popup.querySelector('[data-callback-close]').onclick=()=>acknowledge(row);
  popup.querySelector('[data-callback-open]').onclick=()=>acknowledge(row,true);
 }
 async function refresh(){
  if(!scope||busy)return;
  const own=scope,turn=version;busy=true;
  if(timer)clearTimer(timer);timer=null;
  try{
   const result=await client.rpc('jf_callback_reminders',{target_shop:own.shopId});
   if(turn!==version||scope!==own)return;
   due=Array.isArray(result?.due)?result.due:[];
   if(current&&!due.some(r=>r.id===current.id))remove();
   if(!popup)show(due.find(r=>!r.popup_seen_at&&!muted.has(r.id))||{});
   const signature=due.map(r=>r.id).join(',');
   if(signature!==inboxSignature){inboxSignature=signature;Promise.resolve(onInbox()).catch(()=>{})}
   // The callback time is calculated by the database, avoiding PC clock drift.
   // Poll every <=5 seconds as a fallback for throttled/background browser tabs.
   const next=Date.parse(result?.next_at)-Date.parse(result?.server_time);
   const delay=Number.isFinite(next)&&next>0?Math.min(5000,Math.max(50,next)):5000;
   timer=setTimer(refresh,delay);
  }catch(error){
   if(turn===version&&scope===own){
    console.warn('JioFlow callback reminder check failed:',error?.message||error);
    timer=setTimer(refresh,10000);
   }
  }finally{if(turn===version)busy=false}
 }
 function setScope(next){
  if(!next?.enabled||!next.userId||!next.shopId){if(scope)stop();return}
  if(scope?.userId===next.userId&&scope?.shopId===next.shopId)return;
  stop();scope={userId:next.userId,shopId:next.shopId};refresh();
 }
 doc?.addEventListener?.('jioflow-callback-changed',refresh);
 doc?.addEventListener?.('visibilitychange',()=>{if(doc.visibilityState==='visible')refresh()});
 doc?.defaultView?.addEventListener?.('focus',refresh);
 return {setScope,stop,refresh};
}
