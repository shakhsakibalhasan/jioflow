import {loadStatusDefinitions} from './custom-statuses.mjs';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const advancedFilterKeys=['af_order_date','af_created_from','af_created_to','af_updated_from','af_updated_to','af_imported_status','af_agent','af_sku','af_source','af_call_status','af_customer_status','af_tag','af_tag2','af_tag3','af_payment_ranges','af_payment_basis','af_order_from','af_order_to','af_range'];
const dateValue=d=>[d.getUTCFullYear(),String(d.getUTCMonth()+1).padStart(2,'0'),String(d.getUTCDate()).padStart(2,'0')].join('-');
export function filterPeriod(range,now=new Date()){
 const today=new Date(now.getTime()+6*3600000),end=new Date(Date.UTC(today.getUTCFullYear(),today.getUTCMonth(),today.getUTCDate())),start=new Date(end);
 if(range==='lifetime'||range==='custom')return {from:'',to:''};
 if(range==='yesterday'){start.setUTCDate(start.getUTCDate()-1);end.setUTCDate(end.getUTCDate()-1)}else if(range==='last7')start.setUTCDate(start.getUTCDate()-6);else if(range==='last30')start.setUTCDate(start.getUTCDate()-29);else if(range==='month')start.setUTCDate(1);else if(range==='lastmonth'){start.setUTCDate(1);start.setUTCMonth(start.getUTCMonth()-1);end.setUTCDate(0)}
 return {from:dateValue(start),to:dateValue(end)};
}
export const paymentRanges=[['0:500','৳0–499'],['500:1000','৳500–999'],...Array.from({length:9},(_,i)=>[(i+1)*1000+':'+(i+2)*1000,'৳'+((i+1)*1000).toLocaleString('en')+'–'+((i+2)*1000-1).toLocaleString('en')])].map(([id,label])=>[id,id==='9000:10000'?'৳9,000–10,000':label]);
export function readAdvancedFilters(form,base={}){const next={...base};for(const key of advancedFilterKeys)delete next[key];for(const key of advancedFilterKeys){const value=String(form.get(key)||'').trim();if(value&&!(key==='af_range'&&value==='lifetime'))next[key]=value}const payments=form.getAll?.('af_payment_ranges')||[];if(payments.length)next.af_payment_ranges=payments.join(',');else{delete next.af_payment_ranges;delete next.af_payment_basis}for(const [from,to]of [['af_created_from','af_created_to'],['af_updated_from','af_updated_to'],['af_order_from','af_order_to']])if(next[from]&&next[to]&&next[from]>next[to])throw Error('Start date must not follow end date.');return next}
export function bindFollowupFilters({root,panel,context,client,filters,navigate}){
 if(context.section!=='followups')return;
 if(filters.af_payment_ranges)filters={...filters,af_payment_ranges:filters.af_payment_ranges.split(',').map(v=>v==='100:500'?'0:500':v).join(',')};
 root.querySelectorAll('.filter-panel,[data-original-filters],[data-advanced-followup-filters]').forEach(el=>el.remove());
 if(!['Creator','Owner','Admin','Agent'].includes(context.accountRole))return;
 const bar=root.ownerDocument.createElement('section');bar.className='followup-filter-bar';bar.dataset.advancedFollowupFilters='';
 const count=advancedFilterKeys.filter(k=>!['af_range','af_order_from','af_order_to','af_payment_basis'].includes(k)&&filters[k]).length+(filters.af_order_from||filters.af_order_to?1:0);
 const date=(key,label)=>`<label class="field">${label}<input type="date" name="${key}" value="${esc(filters[key]||'')}"></label>`;
 const select=(key,label,values)=>`<label class="field">${label}<select name="${key}"><option value="">All ${label.toLowerCase()}</option>${values.map(v=>`<option value="${esc(Array.isArray(v)?v[0]:v)}" ${(Array.isArray(v)?v[0]:v)===filters[key]?'selected':''}>${esc(Array.isArray(v)?v[1]:v)}</option>`).join('')}</select></label>`;
 const agents=(context.members||[]).filter(m=>m.shop_id===context.shop.id&&m.role==='agent'&&m.status!=='removed'&&(context.accountRole!=='Agent'||m.user_id===context.profile?.id)).map(m=>[m.id,(context.profiles||[]).find(p=>p.id===m.user_id)?.full_name||'Agent']);
 bar.innerHTML=`<form><div class="followup-filter-toolbar"><button type="button" class="followup-filter-toggle" aria-expanded="false" data-advanced-toggle><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M4 5h16M7 10h10M10 15h4M11 20h2"/></svg>Filters ${count?`<span class="badge">${count} active</span>`:''}<span data-filter-chevron>⌄</span></button><div class="followup-filter-top-actions"><button type="button" data-period-prev aria-label="Previous filter period">‹</button><select name="af_range" aria-label="Filter period">${[['lifetime','Lifetime'],['today','Today'],['yesterday','Yesterday'],['last7','Last 7 days'],['last30','Last 30 days'],['month','This month'],['lastmonth','Last month'],['custom','Custom dates']].map(([v,t])=>`<option value="${v}" ${(filters.af_range||'lifetime')===v?'selected':''}>${t}</option>`).join('')}</select><button type="button" data-period-next aria-label="Next filter period">›</button><button type="button" data-advanced-clear>Clear all</button><button type="submit" class="primary">Apply filters</button></div></div><div class="followup-filter-fields" data-advanced-fields hidden>
 ${date('af_order_date','Order date')}<div class="field"><span>Created at</span><div class="filter-date-pair">${date('af_created_from','From')}${date('af_created_to','To')}</div></div><div class="field"><span>Updated at</span><div class="filter-date-pair">${date('af_updated_from','From')}${date('af_updated_to','To')}</div></div>${select('af_imported_status','Imported status',[])}
 ${select('af_agent','Agent',agents)}<label class="field">SKU<input name="af_sku" value="${esc(filters.af_sku||'')}" maxlength="200" placeholder="Search SKU…"></label>${select('af_source','Order source',[])}${select('af_call_status','Call status',['connected','not_connected','not_attempted','no_answer','busy'].map(v=>[v,v.replaceAll('_',' ')]))}${select('af_customer_status','Customer status',[])}${select('af_tag','Custom tag 1',[])}${select('af_tag2','Custom tag 2',[])}${select('af_tag3','Custom tag 3',[])}<fieldset class="filter-payment-ranges"><legend>Payment amount</legend><select name="af_payment_basis" aria-label="Payment amount type"><option value="total">Order total</option><option value="advance" ${filters.af_payment_basis==='advance'?'selected':''}>Recorded advance</option></select><div class="filter-payment-checks">${paymentRanges.map(([v,t])=>`<label><input type="checkbox" name="af_payment_ranges" value="${v}" ${String(filters.af_payment_ranges||'').split(',').includes(v)?'checked':''}>${t}</label>`).join('')}</div></fieldset><div class="filter-custom-period">${date('af_order_from','Order date from')}${date('af_order_to','Order date to')}</div>
 </div><p class="followup-filter-message" role="status" data-filter-message></p></form>`;
 bar.classList.add('filter-premium','filter-compact81','filter-readable82');
 if(!root.ownerDocument.getElementById('followup-premium77')){const style=root.ownerDocument.createElement('style');style.id='followup-premium77';style.textContent=FILTER_DESIGN77+compact81+readable82;root.ownerDocument.head.append(style)}
 const fieldsHost=bar.querySelector('[data-advanced-fields]'),controls=[...fieldsHost.children];
 const group=(title,description,indexes,wide=false)=>{const box=root.ownerDocument.createElement('section');box.className='filter-option-group'+(wide?' filter-group-wide':'');const heading=root.ownerDocument.createElement('header');heading.innerHTML='<strong>'+title+'</strong><span>'+description+'</span>';box.append(heading);const grid=root.ownerDocument.createElement('div');grid.className='filter-group-grid';for(const i of indexes)grid.append(controls[i]);box.append(grid);fieldsHost.append(box)};
 group('Date & period','Choose when the orders were placed or updated',[0,1,2,13],true);
 group('Customer & source','Find the right customer segment',[4,6,5]);
 group('Status & response','Narrow down calls and order progress',[8,7,3]);
 group('Tags','Combine your custom labels',[9,10,11],true);
 group('Payment amount','Choose one or more amount ranges',[12],true);

 const original=panel.closest('.card');(original&&original!==root?original:panel).before(bar);
 const form=bar.querySelector('form'),range=form.querySelector('[name=af_range]'),fields=bar.querySelector('[data-advanced-fields]'),message=bar.querySelector('[data-filter-message]');let loaded=false,open=false,optionsReady=false,optionRequest=null;form.addEventListener('change',e=>{if(e.target.matches('select'))e.target.dataset.filterEdited='true'});
 const setOptions=(key,values,authoritative=false)=>{const select=form.querySelector('[name='+key+']'),unique=[...new Set(values.map(v=>String(v).trim()).filter(Boolean))];let selected=select.dataset.filterEdited==='true'?select.value:(filters[key]||select.value||'');if(authoritative&&!unique.includes(selected))selected='';else if(!authoritative&&selected&&!unique.includes(selected))unique.push(selected);select.innerHTML='<option value="">All '+select.closest('label').firstChild.textContent.toLowerCase()+'</option>'+unique.map(v=>`<option value="${esc(v)}" ${v===selected?'selected':''}>${esc(v)}</option>`).join('')};
 const fetchOptions=async()=>{if(loaded)return optionsReady;loaded=true;message.textContent='Loading imported filter choices…';const results=await Promise.allSettled([client.rpc('jf_followup_filter_options',{target_shop:context.shop.id}),loadStatusDefinitions(client,context.shop.id)]);if(!bar.isConnected)return;const options=results[0].status==='fulfilled'?results[0].value:{},statuses=results[1].status==='fulfilled'?results[1].value:[];if(results[0].status==='fulfilled'){for(const[key,list]of [['af_imported_status',options.imported_statuses||[]],['af_source',options.sources||[]],['af_tag',options.tags||[]],['af_tag2',options.tags2||[]],['af_tag3',options.tags3||[]]])setOptions(key,list,true)}setOptions('af_customer_status',['Positive','Intermediate','Negative','pending','callback','completed','cancelled',...statuses.filter(s=>s.active).map(s=>s.name)]);message.textContent=results[0].status==='rejected'?'Imported filter choices could not load. '+results[0].reason.message:'';optionsReady=results[0].status==='fulfilled'&&Array.isArray(options.sources);if(!optionsReady)loaded=false;return optionsReady};
 const loadOptions=()=>optionRequest||(optionRequest=fetchOptions().finally(()=>{optionRequest=null}));
 // Keep active values even when the collapsed form is applied before opening.
 for(const key of ['af_imported_status','af_source','af_customer_status','af_tag','af_tag2','af_tag3'])setOptions(key,[],['af_tag','af_tag2','af_tag3'].includes(key));
 const syncPeriod=()=>{if(range.value==='custom'){open=true;fields.hidden=false;bar.querySelector('[data-advanced-toggle]').setAttribute('aria-expanded','true')}bar.querySelector('.filter-custom-period').hidden=range.value!=='custom';for(const key of ['prev','next'])bar.querySelector('[data-period-'+key+']').disabled=range.value==='lifetime'};
 bar.querySelector('[data-advanced-toggle]').onclick=()=>{open=!open;fields.hidden=!open;bar.querySelector('[data-advanced-toggle]').setAttribute('aria-expanded',String(open));bar.querySelector('[data-filter-chevron]').textContent=open?'⌃':'⌄';if(open)loadOptions()};
 range.onchange=()=>{const period=filterPeriod(range.value);for(const [key,v]of [['af_order_from',period.from],['af_order_to',period.to]])form.querySelector('[name='+key+']').value=v;syncPeriod()};
 for(const direction of ['prev','next'])bar.querySelector('[data-period-'+direction+']').onclick=()=>{const from=form.querySelector('[name=af_order_from]'),to=form.querySelector('[name=af_order_to]');if(!from.value||!to.value)return;const start=new Date(from.value+'T00:00:00Z'),end=new Date(to.value+'T00:00:00Z'),days=Math.round((end-start)/86400000)+1,delta=direction==='prev'?-days:days;start.setUTCDate(start.getUTCDate()+delta);end.setUTCDate(end.getUTCDate()+delta);from.value=dateValue(start);to.value=dateValue(end);range.value='custom';syncPeriod()};
 const apply=()=>{try{const next=readAdvancedFilters(new FormData(form),filters);navigate('followups',next)}catch(e){message.textContent=e.message}};
 form.onsubmit=e=>{e.preventDefault();apply()};
 bar.querySelector('[data-advanced-clear]').onclick=()=>{const next={...filters};for(const k of advancedFilterKeys)delete next[k];for(const k of ['agent_id','source','tag','call','response','search'])delete next[k];navigate('followups',{...next,status:'all'})};syncPeriod();
}

const FILTER_DESIGN77=`
.followup-filter-bar.filter-premium{border:1px solid var(--line,#e1e7df);border-radius:20px;background:var(--surface,#fff);box-shadow:0 8px 30px #23341c05}
.filter-premium .followup-filter-toolbar{padding:16px 20px;background:linear-gradient(110deg,var(--surface,#fff),var(--accent-soft,#f5faed));border-bottom:1px solid var(--line,#e8ede4)}
.filter-premium .followup-filter-toggle{border:0;background:transparent;font-weight:650;font-size:14px;padding-left:0;gap:10px}
.filter-premium .followup-filter-toggle svg{padding:9px;box-sizing:content-box;border-radius:12px;background:var(--accent-soft,#edf5e2);color:var(--text,#304623)}
.filter-premium .badge{font-size:10px;padding:4px 8px;border-radius:20px;background:var(--surface,#fff);border:1px solid var(--line,#dfe8d5)}
.filter-premium .followup-filter-fields{display:grid!important;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;padding:20px;background:var(--surface,#fff)}
.filter-premium .followup-filter-fields[hidden]{display:none!important}
.filter-premium .filter-option-group{min-width:0;border:1px solid var(--line,#e5eae1);border-radius:15px;padding:17px;background:var(--surface,#fff)}
.filter-premium .filter-group-wide{grid-column:1/-1}
.filter-premium .filter-option-group>header{display:flex;flex-direction:column;gap:4px;margin-bottom:15px}
.filter-premium .filter-option-group>header strong{font-size:13px;font-weight:650;letter-spacing:-.1px;color:var(--text,#263220)}
.filter-premium .filter-option-group>header span{font-size:11px;color:var(--text-secondary,#7d8678);line-height:1.5}
.filter-premium .filter-group-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:13px;align-items:start}
.filter-premium .filter-group-grid>.field{display:flex;flex-direction:column;gap:0;justify-content:flex-start;font-size:11px;font-weight:500;color:var(--text-secondary,#697461);line-height:1.5}
.filter-premium .filter-group-grid input:not([type=checkbox]),.filter-premium .filter-group-grid select{height:42px;min-height:42px;max-width:100%;width:100%;margin-top:7px;border-radius:9px;border-color:var(--line,#e2e8dc);background:var(--surface,#fff);font-size:12px;padding:9px 10px;box-shadow:0 1px 2px #23321c03}
.filter-premium .filter-date-pair{gap:8px}.filter-premium .filter-date-pair label{font-size:10px}
.filter-premium .filter-custom-period{grid-column:1/-1;padding-top:10px;border-top:1px dashed var(--line,#e5eadd)}
.filter-premium .filter-payment-ranges{grid-column:1/-1;min-width:0;margin:0;padding:0;border:0}
.filter-premium .filter-payment-ranges>legend{display:none}.filter-premium .filter-payment-ranges>select{max-width:230px;margin:0 0 13px}
.filter-premium .filter-payment-checks{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px}
.filter-premium .filter-payment-checks label{display:flex;align-items:center;justify-content:flex-start;gap:9px;min-height:42px;min-width:0;padding:8px 11px;border:1px solid var(--line,#e4e9de);border-radius:9px;font-size:12px;font-weight:500;cursor:pointer;transition:background .15s,border-color .15s;box-sizing:border-box}
.filter-premium .filter-payment-checks label:has(input:checked){border-color:var(--accent,#aadf60);background:var(--accent-soft,#f1f9e7);color:var(--text,#304921)}
.filter-premium .filter-payment-checks input[type=checkbox]{appearance:auto;flex:0 0 15px;width:15px;height:15px;margin:0;padding:0;accent-color:var(--accent,#a1d754)}
.filter-premium .filter-premium-footer{grid-column:1/-1;display:flex;align-items:center;justify-content:space-between;gap:14px;padding:5px 0 0}
.filter-premium .filter-premium-footer>span{font-size:11px;color:var(--text-secondary,#7d8678)}.filter-premium .filter-premium-footer>div{display:flex;gap:8px}
.filter-premium .filter-premium-footer button{font-size:12px;padding:10px 17px;border-radius:10px}
.filter-premium .followup-filter-message{color:var(--text-secondary,#7a8473);padding:0 20px 12px}
@media(max-width:1100px){.filter-premium .filter-option-group:not(.filter-group-wide) .filter-group-grid{grid-template-columns:1fr}.filter-premium .filter-payment-checks{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:650px){.filter-premium .followup-filter-toolbar{padding:12px}.filter-premium .followup-filter-fields{grid-template-columns:minmax(0,1fr)!important;padding:12px!important;gap:10px!important}.filter-premium .filter-option-group{padding:13px}.filter-premium .filter-group-grid{grid-template-columns:minmax(0,1fr)}.filter-premium .filter-payment-checks{grid-template-columns:repeat(2,minmax(0,1fr))}.filter-premium .filter-payment-checks label{font-size:11px;padding:8px}.filter-premium .filter-premium-footer{align-items:stretch;flex-direction:column}.filter-premium .filter-premium-footer>div{display:grid;grid-template-columns:1fr 1fr}.filter-premium .followup-filter-top-actions{display:flex;flex-wrap:wrap;width:100%}.filter-premium .followup-filter-top-actions button.primary{flex:1}.filter-premium .followup-filter-top-actions select{flex:1;min-width:100px}}
`;

// Compact overrides retain the selected theme and all existing field semantics.
const compact81=`
.filter-premium.filter-compact81{border-radius:14px}.filter-compact81 .followup-filter-toolbar{padding:9px 13px;gap:8px}.filter-compact81 .followup-filter-toolbar button,.filter-compact81 .followup-filter-toolbar select{min-height:34px;padding:6px 10px;font-size:12px}.filter-compact81 .followup-filter-toggle svg{width:15px;height:15px;padding:5px;border-radius:8px}
.filter-premium.filter-compact81 .followup-filter-fields{padding:13px!important;gap:12px!important}.filter-compact81 .filter-option-group{border:0;border-radius:0;padding:0 0 10px;border-bottom:1px solid var(--line,#e7ecdf)}.filter-compact81 .filter-option-group>header{margin-bottom:8px}.filter-compact81 .filter-option-group>header strong{font-size:11px}.filter-compact81 .filter-option-group>header span{display:none}
.filter-compact81 .filter-group-grid{gap:9px}.filter-compact81 .filter-group-grid input:not([type=checkbox]),.filter-compact81 .filter-group-grid select{height:34px;min-height:34px;font-size:11px;padding:6px 9px;margin-top:4px;border-radius:8px}.filter-compact81 .filter-group-grid>.field{font-size:10px}
.filter-compact81 .filter-payment-ranges>select{max-width:190px;margin-bottom:8px}.filter-compact81 .filter-payment-checks{grid-template-columns:repeat(6,minmax(0,1fr));gap:6px}.filter-compact81 .filter-payment-checks label{min-height:31px;padding:5px 8px;gap:6px;font-size:11px;border-radius:7px}.filter-compact81 .filter-payment-checks input[type=checkbox]{width:13px;height:13px;flex-basis:13px}.filter-compact81 .followup-filter-message:empty{display:none}.filter-compact81 .followup-filter-message{padding:0 13px 9px;font-size:11px}
@media(min-width:851px) and (max-width:1100px){.filter-compact81 .filter-option-group:not(.filter-group-wide) .filter-group-grid{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:850px){.filter-compact81 .filter-payment-checks{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:650px){.filter-premium.filter-compact81 .followup-filter-fields{padding:10px!important}.filter-compact81 .filter-payment-checks{grid-template-columns:repeat(2,minmax(0,1fr))}.filter-compact81 .followup-filter-top-actions{gap:5px}.filter-compact81 .filter-group-grid{gap:8px}}
`;

const readable82=`
.filter-premium.filter-readable82 .followup-filter-toolbar{padding:10px 14px;align-items:center}
.filter-premium.filter-readable82 .filter-option-group>header strong{font-size:13px;line-height:1.5;font-weight:600}
.filter-premium.filter-readable82 .filter-group-grid>.field,.filter-premium.filter-readable82 .filter-group-grid>label{font-size:12px;line-height:1.5;color:var(--text-secondary,#5e6857)}
.filter-premium.filter-readable82 .filter-date-pair label{font-size:11px;line-height:1.5}
.filter-premium.filter-readable82 .filter-option-group:first-child .filter-group-grid{align-items:end}
.filter-readable82 select,.filter-readable82 input:not([type=checkbox]){box-sizing:border-box!important;height:42px!important;min-height:42px!important;max-height:none!important;font-size:13px!important;line-height:normal!important;letter-spacing:normal!important;padding:0 11px!important;vertical-align:middle!important;text-indent:0!important}
.filter-readable82 select{padding-right:28px!important}.filter-readable82 select option{font-size:13px!important;line-height:normal!important;padding:4px 8px!important}
.filter-premium.filter-readable82 .filter-group-grid input:not([type=checkbox]),.filter-premium.filter-readable82 .filter-group-grid select{margin-top:5px;border-radius:9px}
.filter-premium.filter-readable82 .followup-filter-toolbar button{min-height:40px;font-size:13px;line-height:1.35;padding:8px 12px}
.filter-premium.filter-readable82 .filter-payment-checks{grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}
.filter-premium.filter-readable82 .filter-payment-checks label{min-height:37px;font-size:12px;line-height:1.5;padding:7px 10px;gap:8px}
.filter-premium.filter-readable82 .filter-payment-checks input[type=checkbox]{width:14px;height:14px;flex-basis:14px}
.filter-premium.filter-readable82 .followup-filter-message{font-size:12px;line-height:1.5}
@media(max-width:1050px){.filter-premium.filter-readable82 .filter-option-group:not(.filter-group-wide) .filter-group-grid{grid-template-columns:minmax(0,1fr)}}
@media(max-width:650px){.filter-premium.filter-readable82 .filter-payment-checks{grid-template-columns:repeat(2,minmax(0,1fr))}.filter-readable82 select,.filter-readable82 input:not([type=checkbox]){font-size:16px!important;height:44px!important;min-height:44px!important}.filter-premium.filter-readable82 .filter-group-grid>.field{font-size:12px}}
`;
