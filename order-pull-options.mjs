// Agent-visible choices come only from the CURRENT admin settings.
// Counts are from the server and may be zero; zero-count choices cannot be selected.
export function pullChoices(config={},counts={}){
 const groups=[['imported_status',config.imported_statuses,counts.imported_statuses],['customer_tag1',config.customer_tags,counts.customer_tags]];
 const out=[];
 for(const [type,permitted,available] of groups){
  const byValue=new Map((Array.isArray(available)?available:[]).filter(x=>x&&typeof x.value==='string').map(x=>[x.value,Math.max(0,Number(x.count)||0)]));
  const used=new Set();
  for(const v of Array.isArray(permitted)?permitted:[]){
   if(typeof v!=='string'||!v.trim()||used.has(v))continue;
   used.add(v);
   const count=byValue.get(v)||0;
   out.push({type,value:v,count,disabled:count===0});
  }
 }
 return out;
}
export function canTakeMoreOrders(config={},choices=[]){
 return Boolean(config.enabled)&&Number(config.remaining)>0&&choices.some(x=>!x.disabled);
}
export function isApprovedAvailableChoice(config,counts,type,value){
 return canTakeMoreOrders(config,pullChoices(config,counts))&&pullChoices(config,counts).some(x=>x.type===type&&x.value===value&&!x.disabled);
}
