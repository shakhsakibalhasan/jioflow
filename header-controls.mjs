// Move existing controls, preserving their values and bound event handlers.
export function placeHeaderControls(root,controls){
 const actions=root.closest('main')?.querySelector('.heading>.row');if(!actions||!controls)return false;
 actions.querySelector('[data-header-report-controls]')?.remove();
 if(actions.querySelector('[data-section="new"]'))controls.querySelectorAll('[data-original-nav="new"]').forEach(button=>button.remove());
 controls.dataset.headerReportControls='';controls.classList.add('header-report-controls');
 const newOrder=actions.querySelector('[data-section="new"]');if(newOrder)newOrder.before(controls);else actions.prepend(controls);const refresh=actions.querySelector('#online-refresh');if(refresh)actions.append(refresh);return true;
}

export const periodChoices135=[['today','Today'],['yesterday','Yesterday'],['tomorrow','Tomorrow'],['last7','Last 7 Days'],['last30','Last 30 Days'],['month','This Month'],['lastmonth','Last Month'],['year','This Year'],['lastyear','Last Year'],['lifetime','Lifetime']];
export function periodWindow135(key,now=new Date()){
 const d=new Date(now.getTime()+21600000),end=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth(),d.getUTCDate())),start=new Date(end),day=86400000;
 if(['lifetime','all'].includes(key))return{from:'',to:''};
 if(key==='yesterday'){start.setUTCDate(start.getUTCDate()-1);end.setUTCDate(end.getUTCDate()-1)}
 else if(key==='tomorrow'){start.setUTCDate(start.getUTCDate()+1);end.setUTCDate(end.getUTCDate()+1)}
 else if(['last7','7'].includes(key))start.setUTCDate(start.getUTCDate()-6);
 else if(['last30','30'].includes(key))start.setUTCDate(start.getUTCDate()-29);
 else if(key==='month')start.setUTCDate(1);
 else if(key==='lastmonth'){start.setUTCDate(1);start.setUTCMonth(start.getUTCMonth()-1);end.setUTCDate(0)}
 else if(key==='year'){start.setUTCMonth(0,1)}
 else if(key==='lastyear'){start.setUTCFullYear(start.getUTCFullYear()-1,0,1);end.setUTCMonth(0,0)}
 return{from:start.toISOString().slice(0,10),to:end.toISOString().slice(0,10)};
}
export function periodIso135({from,to}){return{report_start:from?new Date(from+'T00:00:00+06:00').toISOString():null,report_end:to?new Date(Date.parse(to+'T00:00:00+06:00')+86400000).toISOString():null}}
export function bindPeriodPicker135(select,{onApply,from='',to='',key='lifetime'}={}){
 if(!select||select.dataset.periodBound135)return;select.dataset.periodBound135='true';
 if(key==='custom'&&from&&to){const match=periodChoices135.find(([preset])=>{if(preset==='lifetime')return false;const w=periodWindow135(preset);return w.from===from&&w.to===to});if(match)key=match[0]}
 const previous135=select.previousElementSibling,next135=select.nextElementSibling;const doc=select.ownerDocument,wrap=doc.createElement('div');wrap.className='period-picker135';
 wrap.innerHTML='<span class="bd-clock" data-clock135></span><details><summary><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M4 5h16v16H4zM8 2v6M16 2v6M4 11h16"/></svg><span data-period-label135></span><span class="period-chevron135">⌄</span></summary><div class="period-menu135"><div class="period-presets135">'+periodChoices135.map(([v,l])=>'<button type="button" data-period135="'+v+'">'+l+'</button>').join('')+'</div><label>Select a Date<div class="period-single135"><input type="date" data-single135 aria-label="Select a date"><button type="button" class="primary" data-go135>Go</button></div></label><label>Custom Date Range<div class="period-dates135"><input type="date" data-from135 aria-label="Start date"><span>–</span><input type="date" data-to135 aria-label="End date"></div></label><p role="alert" data-period-error135></p><button type="button" class="primary" data-apply135>Apply Range</button></div></details>';
 select.before(wrap);select.hidden=true;wrap.append(select);const details=wrap.querySelector('details'),label=wrap.querySelector('[data-period-label135]');
 const fmt=v=>new Date(v+'T00:00:00Z').toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric',timeZone:'UTC'});
 label.textContent=periodChoices135.find(x=>x[0]===key)?.[1]||(from&&to?(from===to?fmt(from):fmt(from)+' – '+fmt(to)):'Custom dates');
 const today=periodWindow135('today').from;wrap.querySelector('[data-single135]').value=from||today;wrap.querySelector('[data-from135]').value=from||today;wrap.querySelector('[data-to135]').value=to||today;
 const bounds135=from&&to?{from,to}:periodWindow135(key);const makeShift135=(old,direction)=>{const button=old?.matches('[data-original-shift],[data-period-prev],[data-period-next]')?old:doc.createElement('button');button.type='button';button.classList.add('period-shift135');button.textContent=direction<0?'‹':'›';button.setAttribute('aria-label',direction<0?'Previous period':'Next period');button.disabled=!bounds135.from||!bounds135.to;button.onclick=()=>{if(!bounds135.from||!bounds135.to)return;const start=Date.parse(bounds135.from+'T00:00:00Z'),end=Date.parse(bounds135.to+'T00:00:00Z'),span=end-start+86400000,delta=span*direction;apply({from:new Date(start+delta).toISOString().slice(0,10),to:new Date(end+delta).toISOString().slice(0,10)},'custom')};return button};details.before(makeShift135(previous135,-1));details.after(makeShift135(next135,1));
 function apply(window,preset){if(window.from&&window.to&&window.from>window.to){wrap.querySelector('[data-period-error135]').textContent='End date must be on or after start date.';return}details.open=false;onApply?.({...window,key:preset})}
 wrap.querySelectorAll('[data-period135]').forEach(b=>{b.setAttribute('aria-pressed',String(b.dataset.period135===key));b.onclick=()=>apply(periodWindow135(b.dataset.period135),b.dataset.period135)});
 wrap.querySelector('[data-go135]').onclick=()=>{const date=wrap.querySelector('[data-single135]').value;if(date)apply({from:date,to:date},'custom')};
 wrap.querySelector('[data-apply135]').onclick=()=>{const a=wrap.querySelector('[data-from135]').value,b=wrap.querySelector('[data-to135]').value;if(a&&b)apply({from:a,to:b},'custom');else wrap.querySelector('[data-period-error135]').textContent='Choose both dates.'};
 const tick=()=>{wrap.querySelector('[data-clock135]').textContent=new Date().toLocaleTimeString('en-BD',{hour:'numeric',minute:'2-digit',second:'2-digit',hour12:true,timeZone:'Asia/Dhaka'})+' BD'};tick();const timer=setInterval(()=>{if(!wrap.isConnected){clearInterval(timer);return}tick()},1000);timer.unref?.();
 const outside=e=>{if(!wrap.isConnected){doc.removeEventListener('pointerdown',outside);return}if(!wrap.contains(e.target))details.open=false};doc.addEventListener('pointerdown',outside);wrap.onkeydown=e=>{if(e.key==='Escape'){details.open=false;details.querySelector('summary').focus()}};
 return wrap;
}
