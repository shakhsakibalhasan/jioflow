// Memory only, partitioned by authenticated client/session and exact query scope.
const caches=new WeakMap(),readCaches=new WeakMap(),countCaches=new WeakMap(),workspaceCaches=new WeakMap();
export function invalidateRecordPages(client){caches.delete(client);readCaches.delete(client);countCaches.delete(client);workspaceCaches.delete(client)}
export async function recordPage(client,args){let cache=caches.get(client);if(!cache){cache=new Map();caches.set(client,cache)}const key=JSON.stringify([client.sessionVersion?.()??null,args]),old=cache.get(key);if(old&&old.until>Date.now())return old.promise;const entry={until:Date.now()+15000};entry.promise=client.rpc('jf_workspace_page',args).then(value=>{if(!value||!Array.isArray(value.rows)||!Number.isFinite(Number(value.total)))throw Error('Invalid record response. Refresh and check the database update.');if(value.counts){let counts=countCaches.get(client);if(!counts){counts=new Map();countCaches.set(client,counts)}counts.set(countScope(client,args),{until:Date.now()+15000,value:structuredClone(value.counts)});while(counts.size>30)counts.delete(counts.keys().next().value)}return value}).catch(error=>{if(cache.get(key)===entry)cache.delete(key);throw error});cache.set(key,entry);while(cache.size>30)cache.delete(cache.keys().next().value);return entry.promise}

export async function cachedReadRpc(client,name,args){
 if(!['jf_workspace_summary','jf_workspace_tools','jf_agent_workspace_context'].includes(name)||name==='jf_workspace_tools'&&args.tool!=='load')throw Error('Only workspace reads can be cached.');
 let cache=readCaches.get(client);if(!cache){cache=new Map();readCaches.set(client,cache)}
 const key=JSON.stringify([client.sessionVersion?.()??null,name,args]),old=cache.get(key);if(old&&old.until>Date.now())return structuredClone(await old.promise);
 const entry={until:Date.now()+10000};entry.promise=client.rpc(name,args).catch(e=>{if(cache.get(key)===entry)cache.delete(key);throw e});cache.set(key,entry);while(cache.size>30)cache.delete(cache.keys().next().value);return structuredClone(await entry.promise);
}

function countScope(client,args){const filters={...args.filters};delete filters.status;return JSON.stringify([client.sessionVersion?.()??null,args.target_shop,args.entity,Object.fromEntries(Object.entries(filters).sort(([a],[b])=>a.localeCompare(b)))])}
export function peekRecordCounts(client,args){const item=countCaches.get(client)?.get(countScope(client,args));return item&&item.until>Date.now()?structuredClone(item.value):null}

// Reuse dashboard hydration only within this authenticated client and exact scope.
export async function cachedWorkspaceRecords(client,scope,read){
 let cache=workspaceCaches.get(client);if(!cache){cache=new Map();workspaceCaches.set(client,cache)}
 const key=JSON.stringify([client.sessionVersion?.()??null,scope]),old=cache.get(key);if(old&&old.until>Date.now())return structuredClone(await old.promise);
 const entry={until:Date.now()+15000};entry.promise=Promise.resolve().then(read).catch(error=>{if(cache.get(key)===entry)cache.delete(key);throw error});cache.set(key,entry);while(cache.size>20)cache.delete(cache.keys().next().value);return structuredClone(await entry.promise);
}
