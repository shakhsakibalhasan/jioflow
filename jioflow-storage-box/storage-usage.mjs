// Sidebar storage box (TracklyBD-style): database storage used vs plan limit.
// Shown to Creator / Owner / Admin. Data comes from the jf_storage_usage RPC.
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let cache=null,loadedAt=0,pending=null,denied=false;
const REFRESH_MS=5*60*1000;

export function formatBytes(bytes){
 const n=Number(bytes)||0;
 if(n>=1024**3)return (n/1024**3).toFixed(2).replace(/\.?0+$/,'')+' GB';
 if(n>=1024**2)return Math.round(n/1024**2)+' MB';
 if(n>=1024)return Math.round(n/1024)+' KB';
 return n+' B';
}

export function storageBoxInner(data){
 if(!data)return `<div class="sb184-head"><span class="sb184-title">Storage</span><span class="sb184-left">Loading…</span></div><div class="sb184-bar"><i style="width:0%"></i></div>`;
 const used=Number(data.used_bytes)||0,limit=Number(data.limit_bytes)||1;
 const pct=Math.min(100,used/limit*100),left=Math.max(0,limit-used);
 const level=pct>=95?'danger':pct>=80?'warn':'ok';
 const pctText=pct<1?'<1%':Math.round(pct)+'%';
 return `<div class="sb184-head"><span class="sb184-title">Storage</span><span class="sb184-left">${esc(formatBytes(left))} left</span></div>`+
  `<div class="sb184-row"><span>Database</span><span><b>${esc(formatBytes(used))}</b>/${esc(formatBytes(limit))}</span></div>`+
  `<div class="sb184-bar" data-level="${level}" role="progressbar" aria-label="Storage used" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(pct)}"><i style="width:${Math.max(pct,1).toFixed(1)}%"></i></div>`+
  `<div class="sb184-foot">${esc(pctText)} used</div>`;
}

export function storageBoxMarkup(){
 if(denied)return '';
 return `<div class="storage-box184" data-storage-box184>${storageBoxInner(cache)}</div>`;
}

const css=`.storage-box184{display:block;background:var(--soft,#edf5e3);border-radius:16px;padding:12px 13px;margin-top:14px;font-size:11px;line-height:1.35}
.storage-box184 .sb184-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}
.storage-box184 .sb184-title{font-weight:700;letter-spacing:.06em;text-transform:uppercase;font-size:10px}
.storage-box184 .sb184-left{color:var(--muted,#61685f);font-size:10px}
.storage-box184 .sb184-row{display:flex;justify-content:space-between;gap:6px;color:var(--muted,#61685f);margin-bottom:6px}
.storage-box184 .sb184-row b{color:var(--ink,#1d211f);font-weight:600}
.storage-box184 .sb184-bar{height:6px;border-radius:99px;background:rgba(0,0,0,.08);overflow:hidden}
.storage-box184 .sb184-bar i{display:block;height:100%;border-radius:99px;background:var(--accent,#99d13e);transition:width .4s}
.storage-box184 .sb184-bar[data-level=warn] i{background:#e0a127}
.storage-box184 .sb184-bar[data-level=danger] i{background:#d0533f}
.storage-box184 .sb184-foot{margin-top:6px;color:var(--muted,#61685f);font-size:10px}
html[data-mode=dark] .storage-box184{background:var(--surface-soft,#101010);border:1px solid var(--edge,#272a28)}
html[data-mode=dark] .storage-box184 .sb184-row b{color:var(--text,#f4f5f4)}
html[data-mode=dark] .storage-box184 .sb184-bar{background:rgba(255,255,255,.1)}`;
function ensureStyle(doc){if(doc.getElementById('storage-box184-style'))return;const s=doc.createElement('style');s.id='storage-box184-style';s.textContent=css;doc.head.appendChild(s)}

function paint(root){root.querySelectorAll('[data-storage-box184]').forEach(box=>{if(denied){box.remove();return}box.innerHTML=storageBoxInner(cache)})}

export function bindStorageBox(root,{client,role}={}){
 if(!root||role==='Agent')return;
 const doc=root.ownerDocument||document;ensureStyle(doc);
 if(!root.querySelector('[data-storage-box184]'))return;
 if(cache&&Date.now()-loadedAt<REFRESH_MS)return paint(root);
 if(!pending)pending=client.rpc('jf_storage_usage',{}).then(data=>{cache=data;loadedAt=Date.now()}).catch(error=>{if(error?.status===403||error?.code==='42501')denied=true}).finally(()=>{pending=null});
 pending.then(()=>{if(root.isConnected)paint(root)});
}
