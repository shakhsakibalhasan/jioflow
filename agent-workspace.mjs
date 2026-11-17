const caches=new WeakMap();
export const agentWorkspaceSections=new Set(['dashboard','followups','customers','permanent','orders','new','courier']);
export function scopedAgentClient(client,member){
 let map=caches.get(client);if(!map){map=new Map();caches.set(client,map)}const key=member.id+':'+client.sessionVersion?.();if(map.has(key))return map.get(key);
 const scoped={...client,sessionVersion:()=>String(client.sessionVersion?.())+':agent:'+member.id,
  query(table,params='select=*'){if(['jf_customers','jf_orders'].includes(table))params+='&assigned_membership_id=eq.'+encodeURIComponent(member.id);return client.query(table,params)},
  count(table,params=''){if(['jf_customers','jf_orders'].includes(table))params+='&assigned_membership_id=eq.'+encodeURIComponent(member.id);return client.count(table,params)},
  rpc(name,args={}){if(name==='jf_dashboard_kpi155')return client.rpc(name,{...args,target_agent:member.id});if(name==='jf_workspace_summary')return client.rpc('jf_agent_workspace_summary',{...args,target_agent:member.id});if(['jf_followup_page171','jf_workspace_page','jf_workspace_page_fast','jf_select_records'].includes(name))args={...args,filters:{...args.filters,agent_id:member.id}};
   if(name==='jf_save_order')args={...args,details:{...args.details,assigned_membership_id:member.id}};
   if(name==='jf_workspace_tools'&&['load','save_layout'].includes(args.tool))args={...args,details:{...args.details,page:'a:'+member.id+':'+args.details.page}};
   return client.rpc(name,args)}
 };map.set(key,scoped);while(map.size>20)map.delete(map.keys().next().value);return scoped;
}
export function clearAgentWorkspaceClients(client){caches.delete(client);layoutClients.delete(client)}
const layoutClients=new WeakMap();
export function agentLayoutClient(client,member){let map=layoutClients.get(client);if(!map){map=new Map();layoutClients.set(client,map)}const key=member.id+':'+client.sessionVersion?.();if(map.has(key))return map.get(key);const wrapped={...client,sessionVersion:()=>String(client.sessionVersion?.())+':layout:'+member.id,rpc(name,args={}){if(name==='jf_workspace_tools'&&['load','save_layout'].includes(args.tool))args={...args,details:{...args.details,page:'a:'+member.id+':'+args.details.page}};return client.rpc(name,args)}};map.set(key,wrapped);while(map.size>20)map.delete(map.keys().next().value);return wrapped;}

export const supervisorWorkspaceSections=new Set([...agentWorkspaceSections,'products','import','profit','agentreports','team','settings','deliverymethods','accounts','admins','agents','profile']);
export function inspectedWorkspaceRole(members,id){const role=members.find(m=>m.id===id&&m.status==='active')?.role;return ['owner','admin','agent'].includes(role)?role[0].toUpperCase()+role.slice(1):'Agent'}

export function agentSections118(permissions={}){const pages=new Set(['dashboard','followups','permanent','new','profile']);for(const [key,sections] of Object.entries({orders:['orders'],permanent:['permanent'],courier:['courier'],import:['import'],products:['products'],profit:['profit'],settings:['settings'],integration:['deliverymethods'],users:['team','accounts'],approval:['accounts'],logout:['accounts']}))if(permissions[key]===true)sections.forEach(s=>pages.add(s));return pages;}

export function simplifyAgentDashboard118(root){root.dataset.agentDashboard118='';const labels=['Assigned','Processing','Completed','Confirm','Purchase Rate','Connected','Not Connected','Due Callbacks','Positive','Intermediate','Negative'];root.querySelectorAll('.dashboard-panels,.source-confirmed-chart,.dashboard-grid,.original-header-actions,.filter-panel').forEach(el=>el.remove());const grid=root.querySelector('.dashboard-metrics');if(!grid)return;for(const tile of [...grid.children]){const label=tile.querySelector('.label,.tile-label');if(!label){tile.remove();continue}let name=label.textContent.replace('↗','').trim();if(name==='Pending Follow-up')name='Processing';if(/^confirm(?:ed(?: customers| orders)?)?$/i.test(name))name='Confirm';if(!labels.includes(name)){tile.remove();continue}label.textContent=name;tile.dataset.agentMetric188=name;tile.removeAttribute('style');if(name==='Processing'){tile.removeAttribute('data-original-action');tile.dataset.originalSummary='Processing'}}for(const name of labels){const tile=[...grid.children].find(el=>el.dataset.agentMetric188===name);if(tile)grid.append(tile)}}
