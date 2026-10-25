export function loadingMarkup(){return '<div class="jioflow-loader" role="status" aria-label="Loading"><div class="jioflow-loader-ring"><img class="brandmark supplied-icon" src="assets/jioflow-icon-light.png" alt="" width="695" height="895" aria-hidden="true"></div><span class="sr-only">Loading</span></div>'}
const loadingOwners=new Map();let loadingObserver=null;
export function showLoading({scope=null}={}){
 const doc=scope?.ownerDocument||document;
 const token=Symbol('loading');let finished=false;loadingOwners.set(token,scope);
 let overlay=doc.getElementById('jioflow-busy');if(!overlay){overlay=doc.createElement('div');overlay.id='jioflow-busy';overlay.innerHTML=loadingMarkup();doc.body.append(overlay)}
 const cleanup=()=>{if(loadingOwners.size)return;doc.getElementById('jioflow-busy')?.remove();loadingObserver?.disconnect();loadingObserver=null};
 if(!loadingObserver&&typeof MutationObserver!=='undefined'){loadingObserver=new MutationObserver(()=>{for(const[key,owner]of loadingOwners)if(owner&&!owner.isConnected)loadingOwners.delete(key);cleanup()});loadingObserver.observe(doc.body,{childList:true,subtree:true})}
 return ()=>{if(finished)return;finished=true;loadingOwners.delete(token);cleanup()};
}
export function isAuthenticationError(error){return error?.status===401||['refresh_token_not_found','refresh_token_already_used','session_not_found','user_banned'].includes(error?.code)}
