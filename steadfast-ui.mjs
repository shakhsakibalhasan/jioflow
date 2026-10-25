const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=v=>'৳'+Number(v||0).toLocaleString('en-BD');
export async function bindSteadfastOrder({dialog,client,shop,order,reload}){
 if(!client.courier)return;
 const host=dialog.ownerDocument.createElement('section');host.className='card section-gap steadfast-order';host.innerHTML='<h3>Steadfast courier</h3><p role="status">Loading shipment details…</p>';
 dialog.querySelector('.online-dialog-actions')?.before(host);
 try{
  const info=await client.courier({action:'info',shop_id:shop.id,order_id:order.id});if(!host.isConnected)return;
  const shipment=info.shipment,booked=!!shipment?.consignment_id;
  let url='';try{const u=new URL(shipment?.tracking_url);if(u.protocol==='https:'&&['steadfast.com.bd','www.steadfast.com.bd','portal.packzy.com'].includes(u.hostname))url=u.href}catch{}
  host.innerHTML=`<h3>Steadfast courier</h3><div class="detail-kv"><div><small>Shipment status</small><strong>${esc(shipment?.provider_status||shipment?.status||(info.configured?'Not booked':'Not configured'))}</strong></div><div><small>COD after recorded advance</small><strong>${money(Number(info.order.total)-Number(info.order.advance))}</strong></div>${booked?`<div><small>Consignment ID</small><strong>${esc(shipment.consignment_id)}</strong></div><div><small>Tracking code</small><strong>${esc(shipment.tracking_code||'—')}</strong></div>`:''}</div>${shipment?.provider_invoice?`<p class="small muted">Courier invoice: ${esc(shipment.provider_invoice)}</p>`:''}${shipment?.last_synced_at?`<p class="small muted">Last synced: ${esc(new Date(shipment.last_synced_at).toLocaleString('en-GB',{timeZone:'Asia/Dhaka'}))}</p>`:''}${shipment?.last_error?`<p role="status">${esc(shipment.last_error)}</p>`:''}<div class="row section-gap">${url?`<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">Track parcel ↗</a>`:''}${booked?'<button type="button" data-steadfast-sync>Refresh courier status</button>':info.can_book&&info.booking_enabled&&['confirmed','ready_to_book'].includes(info.order.status)?'<button type="button" class="primary" data-steadfast-book>Book with Steadfast</button>':'<p class="small muted">'+esc(!info.configured?'Steadfast is not configured for this business.':!info.booking_enabled?'Live booking has not been enabled.':'Confirm the order and enable booking permission to book.')+'</p>'}</div><p role="status" data-steadfast-message></p>`;
  for(const action of ['book','sync']){const b=host.querySelector('[data-steadfast-'+action+']');if(b)b.onclick=async()=>{
   if(action==='book'&&!globalThis.confirm(`Book a real Steadfast parcel for ${order.order_number}? COD ${money(Number(info.order.total)-Number(info.order.advance))}.`))return;
   b.disabled=true;const message=host.querySelector('[data-steadfast-message]');message.textContent=action==='book'?'Booking parcel…':'Refreshing courier status…';
   try{const result=await client.courier({action,shop_id:shop.id,order_id:order.id});message.textContent=result.message;if(action==='book'){dialog.close();await reload();return}await reload();host.remove();if(dialog.isConnected)await bindSteadfastOrder({dialog,client,shop,order,reload});}catch(e){message.textContent=e.message;b.disabled=false}
  }}
 }catch(e){host.querySelector('[role=status]').textContent=e.message}
}
export function bindSteadfastPanel({root,context,client}){
 if(!client.courier||!context.shop||!['courier','settings'].includes(context.section))return;
 const host=root.ownerDocument.createElement('section');host.className='card section-gap steadfast-settings';
 host.innerHTML='<div class="row between"><div><h2>Steadfast</h2><p class="small muted">Shipment updates sync through status polling.</p></div><span class="badge" data-steadfast-state>Checking configuration…</span></div><p role="status" data-steadfast-info></p>';
 (root.querySelector('.original-restored-view')||root).prepend(host);
 client.courier({action:'info',shop_id:context.shop.id}).then(info=>{if(!host.isConnected)return;host.querySelector('[data-steadfast-state]').textContent=info.configured?'Configured':'Not configured';host.querySelector('[data-steadfast-info]').textContent=(info.booking_enabled?'Live booking enabled. ':'Live booking disabled. ')+(info.polling_enabled?'Scheduled polling enabled; updates depend on the scheduler.':'Scheduled polling has not been enabled.')+(info.shop_reference?' Business reference: '+info.shop_reference:'')}).catch(e=>{if(host.isConnected){host.querySelector('[data-steadfast-state]').textContent='Unavailable';host.querySelector('[data-steadfast-info]').textContent=e.message}});
}
