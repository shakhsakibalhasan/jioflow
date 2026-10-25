import {showLoading} from './loading.mjs';
import {recordTarget,recordStatus,summaryTarget} from './record-routing.mjs';
import {bindCustomerImport} from './live-customer-import.mjs';
const supported=new Set(['dashboard','products','customers','followups','permanent','team','profile','shop','orders','new','import','courier','profit','agentreports','settings','platformsettings']);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function createOriginalSections({client,navigate,onLiveAction=()=>false,onReady=()=>{},bridge=()=>window.JioFlowOriginalViews}){
 let generation=0,viewContext=null;
 function bind(root){
  const active=bridge().currentSection?.();if(active)viewContext={...viewContext,section:active};
  root.querySelectorAll('[data-original-action]').forEach(b=>b.onclick=()=>{const action=JSON.parse(b.dataset.originalAction);let target=recordTarget(action,viewContext?.section);if(action.name==='openStatus')target={section:'followups',filters:{entity:'customers',status:recordStatus(b.querySelector('span')?.textContent)}};if(action.name==='sourceQueue')target={section:'followups',filters:{entity:'customers',status:'assigned',source:b.querySelector('span')?.textContent||''}};if(target){navigate(target.section,{...(target.section==='agentreports'&&viewContext?.recordFilter?.agent_id?{agent_id:viewContext.recordFilter.agent_id}:{}),...target.filters,...(target.filters.entity==='orders'?bridge().reportWindow?.()||{}:{})});return}root.innerHTML=bridge().action(action);bind(root)});
  root.querySelectorAll('[data-original-summary]').forEach(b=>b.onclick=()=>{const target=summaryTarget(b.dataset.originalSummary,viewContext?.section);navigate(target.section,target.filters)});
  root.querySelectorAll('[data-original-live]').forEach(b=>b.onclick=async()=>{const note=root.querySelector('.original-connection-notice');try{const ok=await onLiveAction(b.dataset.originalLive,b.dataset.originalId);if(!ok)throw Error('This action is unavailable for this record or your account permissions.');}catch(error){if(note){note.hidden=false;note.textContent=error.message}}});
  root.querySelectorAll('[data-original-preview]').forEach(b=>b.onclick=()=>{bridge().preview(b.dataset.originalPreview,b.dataset.originalId);const modal=root.ownerDocument.getElementById('modal');modal?.querySelectorAll('[data-original-live]').forEach(button=>button.onclick=()=>{if(onLiveAction(button.dataset.originalLive,button.dataset.originalId))modal.close()})});
  root.querySelectorAll('[data-original-nav]').forEach(b=>b.onclick=()=>navigate({customers:'followups',team:'team',stores:'shops',creator:'dashboard'}[b.dataset.originalNav]||b.dataset.originalNav));
  const update=(type,value)=>{const html=bridge().interact(type,value);if((type==='range'||type==='shift')&&viewContext?.recordFilter){const window=bridge().reportWindow?.()||{};navigate(viewContext.section,{...viewContext.recordFilter,report_start:window.report_start||null,report_end:window.report_end||null});return}root.innerHTML=html;bind(root)};
  root.querySelectorAll('[data-original-range]').forEach(input=>input.onchange=()=>update('range',input.value));
  root.querySelectorAll('[data-original-shift]').forEach(b=>b.onclick=()=>update('shift',b.dataset.originalShift));
  root.querySelectorAll('[data-original-filter]').forEach(input=>input.onchange=()=>update('filter',{key:input.dataset.originalFilter,value:input.value}));
  root.querySelectorAll('[data-original-export]').forEach(b=>b.onclick=()=>bridge().export(b.dataset.originalExport));
  root.querySelectorAll('[data-original-page]').forEach(b=>b.onclick=()=>update('page',b.dataset.originalPage));
  root.querySelectorAll('[data-original-rows]').forEach(input=>input.onchange=()=>update('rows',input.value));
  root.querySelectorAll('[data-original-chart]').forEach(b=>b.onclick=()=>update('chart',b.dataset.originalChart));
  root.querySelectorAll('[data-original-tab]').forEach(b=>b.onclick=()=>['orders','followups','customers','permanent','courier'].includes(viewContext?.section)?navigate(viewContext.section,{...(viewContext.recordFilter||{}),entity:['orders','courier'].includes(viewContext.section)?'orders':'customers',status:recordStatus(b.dataset.originalTab)}):update('tab',b.dataset.originalTab));
  root.querySelectorAll('[data-original-filters]').forEach(b=>b.onclick=()=>{const panel=root.querySelector('.filter-panel');if(panel&&root.querySelector('[data-live-record-panel]')){panel.hidden=!panel.hidden;b.setAttribute('aria-expanded',String(!panel.hidden));return}update('filters')});
  root.querySelectorAll('[data-original-search]').forEach(input=>{input.onchange=()=>update('search',input.value);input.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();update('search',input.value)}}});
  root.querySelectorAll('[data-original-form]').forEach(form=>form.onsubmit=e=>e.preventDefault());onReady(root,viewContext);bindCustomerImport(root,viewContext,client);
 }
 return {supports:section=>supported.has(section),clear(){generation++},async mount({root,section,shop,profile,shops,profiles,members,accountRole,canFinance,recordFilter=null,progressive=false,fullLoading=false}){
  const current=++generation;if(!supported.has(section))return;
  if(!shop&&!['profile','platformsettings'].includes(section)){root.innerHTML='<section class="card"><h2>Select a business</h2><p>Select a shop above to open its original workspace screen.</p></section>';return}
  const directPanel=progressive&&(['orders','courier','customers','followups','permanent','agentreports'].includes(section)||Boolean(recordFilter?.entity));
  root.classList.add('page-enter');const finishLoading=fullLoading?showLoading({scope:root}):()=>{};
  try{
   if(directPanel){const original=bridge();if(!original)throw new Error('Screen assets could not be loaded. Refresh to retry.');viewContext={section,shop,profile,shops,profiles,members,records:{},accountRole,recordFilter,fullLoading};root.innerHTML=original.render(section,viewContext);root.querySelectorAll('.metric-tile,.insight-tile,.overview-tile').forEach(el=>{const value=el.querySelector('strong');if(value)value.textContent='—';const foot=el.querySelector('.metric-context');if(foot)foot.textContent='Updating totals…';const badge=el.querySelector('.change-badge');if(badge)badge.textContent='—'});bind(root);return}
   root.innerHTML='<div class="page-loading-space" aria-busy="true"></div>';
   let records={};if(shop&&!['settings','platformsettings','import','profile','shop'].includes(section)){
    const scoped='select=*&shop_id=eq.'+encodeURIComponent(shop.id);
    const [orders,products,customers]=await Promise.all([client.query('jf_orders',scoped+'&archived_at=is.null&order=created_at.desc&limit=50'),client.query('jf_products',scoped+'&archived_at=is.null&order=created_at.desc&limit=50'),client.query('jf_customers',scoped+'&archived_at=is.null&order=updated_at.desc&limit=50')]);
    records={orders:orders||[],products:products||[],customers:customers||[],items:[],payments:[],followups:[],costs:[],finance:[]};
    if(records.orders.length){const ids=records.orders.map(o=>o.id).join(',');for(let offset=0;;offset+=1000){const items=await client.query('jf_order_items',scoped+'&order_id=in.('+ids+')&order=id.asc&limit=1000&offset='+offset);records.items.push(...(items||[]));if(!items||items.length<1000)break}for(let offset=0;;offset+=1000){const payments=await client.query('jf_payments',scoped+'&order_id=in.('+ids+')&order=id.asc&limit=1000&offset='+offset);records.payments.push(...(payments||[]));if(!payments||payments.length<1000)break}}
    if(canFinance&&records.orders.length)records.finance=await client.query('jf_order_finance',scoped+'&order_id=in.('+records.orders.map(o=>o.id).join(',')+')')||[];
    if(records.customers.length)records.followups=await client.query('jf_followups',scoped+'&customer_id=in.('+records.customers.map(c=>c.id).join(',')+')&limit=50')||[];
    if(canFinance&&records.products.length)records.costs=await client.query('jf_product_costs',scoped+'&product_id=in.('+records.products.map(p=>p.id).join(',')+')&limit=50')||[];
   }
   if(current!==generation)return;
   const original=bridge();if(!original)throw new Error('Original screen assets could not be loaded. Refresh the page.');
   viewContext={section,shop,profile,shops,profiles,members,records,accountRole,recordFilter,fullLoading};root.innerHTML=original.render(section,viewContext);bind(root);
  }catch(error){if(current===generation)root.innerHTML='<section class="card"><h2>Unable to open this screen</h2><p role="alert">'+esc(error.message)+'</p><p>Refresh to try again. No records were changed.</p></section>'}finally{finishLoading()}
 }};
}
