// Import-backed display titles. Database/filter keys remain stable when these names change.
export const DEFAULT_FILTER_LABELS=Object.freeze({
 af_imported_status:'Imported Status',af_source:'Order Source',af_tag:'Custom Tag 1',
 af_tag2:'Custom Tag 2',af_tag3:'Taken By'
});
const cache=new Map();
const storageKey=shop=>'jioflow.filter_labels.v1:'+shop;
const clean=source=>Object.fromEntries(Object.entries(DEFAULT_FILTER_LABELS).map(([key,label])=>[
 key,typeof source?.[key]==='string'&&source[key].trim()?source[key].trim():label
]));
export function cachedFilterLabels(shop){
 if(cache.has(shop))return cache.get(shop);
 try{const stored=JSON.parse(globalThis.localStorage?.getItem(storageKey(shop))||'null');if(stored){const value=clean(stored);cache.set(shop,value);return value}}catch{}
 return clean(null);
}
export async function loadFilterLabels(client,shop,{refresh=false}={}){
 if(!refresh&&cache.has(shop))return cache.get(shop);
 const value=clean(await client.rpc('jf_filter_labels',{target_shop:shop}));
 cache.set(shop,value);try{globalThis.localStorage?.setItem(storageKey(shop),JSON.stringify(value))}catch{}
 return value;
}
export async function saveFilterLabels(client,shop,input){
 const value=clean(await client.rpc('jf_filter_labels',{target_shop:shop,proposed:clean(input)}));
 cache.set(shop,value);try{globalThis.localStorage?.setItem(storageKey(shop),JSON.stringify(value))}catch{}
 return value;
}
export function normalizeTemplateHeaders(table,labels){
 if(!Array.isArray(table)||!Array.isArray(table[0]))return table;
 const replace={af_imported_status:'Status',af_source:'Order Source',af_tag:'Custom Tags',af_tag2:'Custom Tag 2',af_tag3:'Custom Tag 3'};
 const lookup=new Map(Object.entries(replace).map(([key,standard])=>[
  String(labels?.[key]||DEFAULT_FILTER_LABELS[key]).trim().toLocaleLowerCase(),standard
 ]));
 return [table[0].map(h=>lookup.get(String(h??'').trim().toLocaleLowerCase())||h),...table.slice(1)];
}
const html=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function bindEditableFilterLabels({root,client,shop,openForm,onError=()=>{}}){
 if(!shop?.id||root.querySelector('[data-filter-name-editor]'))return;
 const host=root.querySelector('.original-restored-view')||root;
 const card=root.ownerDocument.createElement('section');card.className='card section-gap jf-filter-label-settings';card.dataset.filterNameEditor='';
 card.innerHTML='<header class="row between"><div><h2>Filter & Import Column Names</h2><p>Edit visible filter names. Upload template headings will use the same names; existing customer data is preserved.</p></div><button type="button" data-edit-filter-names>Edit names</button></header><div class="jf-filter-name-preview" data-filter-name-preview>Loading filter names…</div>';
 host.append(card);
 let labels=cachedFilterLabels(shop.id);
 const render=()=>{card.querySelector('[data-filter-name-preview]').innerHTML=Object.entries(labels).map(([key,name])=>`<div><small>${html(DEFAULT_FILTER_LABELS[key])}</small><strong>${html(name)}</strong></div>`).join('')};
 render();loadFilterLabels(client,shop.id,{refresh:true}).then(v=>{if(card.isConnected){labels=v;render()}}).catch(e=>onError(e.message));
 card.querySelector('[data-edit-filter-names]').onclick=()=>{
  const content=`<div class="jf-filter-name-edit">${Object.entries(DEFAULT_FILTER_LABELS).map(([key,title])=>`<label class="field">${html(title)}<input name="${key}" value="${html(labels[key])}" maxlength="80" required></label>`).join('')}<p class="small muted">Changing names never changes stored status, tag or customer records.</p></div>`;
  openForm('Edit Filter & Import Names',content,async form=>{
   const next=Object.fromEntries(Object.keys(DEFAULT_FILTER_LABELS).map(key=>[key,String(form.get(key)||'').trim()]));
   labels=await saveFilterLabels(client,shop.id,next);render();
  });
 };
}
export async function bindImportTemplateLabels({root,client,shop}){
 const link=root.querySelector('a[href$="order-import-template.csv"]');if(!link||!shop?.id)return;
 // A configured import name is only a column-title alias; underlying data keys stay unchanged.
 link.addEventListener('click',async event=>{
  event.preventDefault();
  try{
   const labels=await loadFilterLabels(client,shop.id,{refresh:true});
   const response=await fetch(link.href,{credentials:'same-origin'});if(!response.ok)throw Error('Template unavailable');
   const csv=await response.text();const lines=csv.split(/\r?\n/);const header=lines.shift()?.split(',')||[];
   const rename={'Status':labels.af_imported_status,'Order Source':labels.af_source,'Custom Tags':labels.af_tag,'Custom Tag 2':labels.af_tag2,'Employee':labels.af_tag3};
   const safe=v=>'"'+String(v).replaceAll('"','""')+'"';
   const first=header.map(h=>safe(rename[h]||h)).join(',');
   const blob=new Blob(['\ufeff'+[first,...lines].join('\r\n')],{type:'text/csv;charset=utf-8'});
   const url=URL.createObjectURL(blob),a=root.ownerDocument.createElement('a');a.href=url;a.download='jioflow-import-template.csv';root.ownerDocument.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),500);
  }catch(error){const note=root.querySelector('[data-import-message]');if(note)note.textContent='Cannot download named template: '+error.message;}
 });
}
