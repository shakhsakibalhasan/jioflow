const caches=new WeakMap();
export const agentWorkspaceSections=new Set(['dashboard','followups','customers','permanent','orders','new','courier']);
export function scopedAgentClient(client,member){
 let map=caches.get(client);if(!map){map=new Map();caches.set(client,map)}const key=member.id+':'+client.sessionVersion?.();if(map.has(key))return map.get(key);
 const scoped={...client,sessionVersion:()=>String(client.sessionVersion?.())+':agent:'+member.id,
  query(table,params='select=*'){if(['jf_customers','jf_orders'].includes(table))params+='&assigned_membership_id=eq.'+encodeURIComponent(member.id);return client.query(table,params)},
  count(table,params=''){if(['jf_customers','jf_orders'].includes(table))params+='&assigned_membership_id=eq.'+encodeURIComponent(member.id);return client.count(table,params)},
  rpc(name,args={}){if(name==='jf_workspace_summary')return client.rpc('jf_agent_workspace_summary',{...args,target_agent:member.id});if(name==='jf_workspace_page')args={...args,filters:{...args.filters,agent_id:member.id}};
   if(name==='jf_save_order')args={...args,details:{...args.details,assigned_membership_id:member.id}};
   if(name==='jf_workspace_tools'&&['load','save_layout'].includes(args.tool))args={...args,details:{...args.details,page:'a:'+member.id+':'+args.details.page}};
   return client.rpc(name,args)}
 };map.set(key,scoped);return scoped;
}
export function clearAgentWorkspaceClients(client){caches.delete(client);layoutClients.delete(client)}
const layoutClients=new WeakMap();
export function agentLayoutClient(client,member){let map=layoutClients.get(client);if(!map){map=new Map();layoutClients.set(client,map)}const key=member.id+':'+client.sessionVersion?.();if(map.has(key))return map.get(key);const wrapped={...client,sessionVersion:()=>String(client.sessionVersion?.())+':layout:'+member.id,rpc(name,args={}){if(name==='jf_workspace_tools'&&['load','save_layout'].includes(args.tool))args={...args,details:{...args.details,page:'a:'+member.id+':'+args.details.page}};return client.rpc(name,args)}};map.set(key,wrapped);return wrapped;}
