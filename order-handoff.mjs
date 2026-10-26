// Unsaved form handoff, isolated to this actor/shop/session. No database write.
const prefix='jioflow.order-handoff.v1:';const memory=new Map();
const scope=context=>[context.shop?.id,context.profile?.id,context.recordFilter?.workspace_agent||''].join(':');
const key=(context,id)=>prefix+scope(context)+':'+id;
export function stageOrderHandoff(context,details,storage=globalThis.sessionStorage){const bytes=crypto.getRandomValues(new Uint8Array(16)),id=Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''),entry={until:Date.now()+3600000,details:structuredClone(details)};memory.set(key(context,id),entry);try{storage?.setItem(key(context,id),JSON.stringify(entry))}catch{}return id}
export function readOrderHandoff(context,id,storage=globalThis.sessionStorage){if(!/^[a-f0-9]{32}$/.test(id||''))return null;let entry=memory.get(key(context,id));if(!entry)try{entry=JSON.parse(storage?.getItem(key(context,id))||'null')}catch{}if(!entry||entry.until<Date.now()){clearOrderHandoff(context,id,storage);return null;}return structuredClone(entry.details)}
export function clearOrderHandoff(context,id,storage=globalThis.sessionStorage){memory.delete(key(context,id));try{storage?.removeItem(key(context,id))}catch{}}
export function clearAllOrderHandoffs(storage=globalThis.sessionStorage){memory.clear();try{for(let i=storage.length-1;i>=0;i--){const k=storage.key(i);if(k?.startsWith(prefix))storage.removeItem(k)}}catch{}}
