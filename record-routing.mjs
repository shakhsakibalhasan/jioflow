export function recordStatus(value='all'){
 const key=String(value||'all').toLowerCase().replaceAll(' ','_');return ({complete:'completed',notattempted:'not_attempted',pendingqueue:'pending','due_today':'callbacks',overdue:'callbacks','not_booked':'ready_to_book','ready_to_book':'ready_to_book','call_back':'callback',attempted:'attempted',notattempted:'not_attempted'})[key]||key;
}
export function recordTarget(action,section='dashboard'){
 const {name,args=[]}=action||{};
 if(['dashboardOrders','selectOrderOverview'].includes(name))return {section:'orders',filters:{entity:'orders',status:recordStatus(args[0])}};
 if(['dashboardCustomers','selectFollowOverview','setFollowCall'].includes(name))return {section:'followups',filters:{entity:'customers',status:recordStatus(args[2]||args[1]||args[0])}};
 if(name==='setFollowUnattempted')return {section:'followups',filters:{entity:'customers',status:'not_attempted'}};
 if(name==='openFunnel')return {section:'followups',filters:{entity:'customers',status:recordStatus(args[0])}};
 if(name==='openAgentReport'||name==='openAgentMetric')return {section:'agentreports',filters:{entity:args[2]||'customers',status:name==='openAgentReport'?'all':recordStatus(args[1]),agent_id:args[0]}};
 if(name==='selectReportFilter')return {section:'agentreports',filters:{entity:args[1]||'customers',status:recordStatus(args[0])}};
 if(name==='ordersForProduct')return {section:'orders',filters:{entity:'orders',status:'confirmed',product_id:args[0]}};
 if(name==='openCourierBalance')return {section:'courier',filters:{entity:'orders',status:'delivered'}};
 if(name==='profitDetail')return {section:'profit',filters:{entity:'orders',status:'confirmed',...(args[0]==='agent'?{agent_id:args[1]}:args[0]==='product'?{product_id:args[1]}:args[0]==='source'?{source:args[1]}:{})}};
 return null;
}
export function summaryTarget(label,section='dashboard'){
 const name=String(label||'').toLowerCase();
 const customerStatus={'all customers':'all','total customers':'all','assigned':'assigned','unassigned':'unassigned','completed':'completed','complete':'completed','pending follow-up':'pending','pending follow-ups':'pending','permanent clients':'permanent','connected':'connected','not connected':'not_connected','positive':'positive','negative':'negative','intermediate':'intermediate','attempted':'attempted','not attempted':'not_attempted','never attempted':'not_attempted','failed':'failed','no answer':'no_answer','busy':'busy','due callbacks':'callbacks','overdue callbacks':'callbacks','purchase rate':'buyers'}[name];
 if(customerStatus&&!(['complete','completed'].includes(name)&&['orders','courier'].includes(section)))return {section:'followups',filters:{entity:'customers',status:customerStatus}};
 if(/cod|delivery.*return/.test(name))return {section:'courier',filters:{entity:'orders',status:name.includes('cod')?'delivered':'all'}};
 if(/profit|cost|margin/.test(name))return {section:'profit',filters:{entity:'orders',status:'confirmed'}};
 if(/agent|user/.test(name))return {section:'agentreports',filters:{entity:'customers',status:'all'}};
 const customers=/customer|assign|callback|connected|positive|negative|intermediate|follow|purchase|permanent/.test(name)||name==='completed'&&!['orders','courier'].includes(section);
 const status=name==='imported'?'imported':name.includes('unassigned')?'unassigned':name==='completed'?(customers?'completed':'delivered'):name.includes('confirmed')?'confirmed':name.includes('pending')?'pending':name.includes('callback')?'callbacks':name.includes('not connected')?'not_connected':name==='connected'?'connected':name.includes('permanent')?'permanent':name==='assigned'?'assigned':'all';
 return {section:customers?'followups':'orders',filters:{entity:customers?'customers':'orders',status}};
}
