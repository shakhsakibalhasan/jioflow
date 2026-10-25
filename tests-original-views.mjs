import assert from 'node:assert/strict';import vm from 'node:vm';import {readFile} from 'node:fs/promises';
const {parseHTML}=await import(process.env.LINKEDOM_MODULE||'linkedom');const {document}=parseHTML('<html><body><main id="app"></main><dialog id="modal"></dialog><div id="toast"></div></body></html>');
const context={__JIOFLOW_TEST__:true,document,console,setTimeout,clearTimeout,location:{hash:'',origin:'https://example.test'},crypto:globalThis.crypto};context.window=context;vm.createContext(context);vm.runInContext(await readFile('original-views.js','utf8'),context);
const profile={id:'creator',platform_role:'creator',full_name:'Creator',active:true,email:'creator@example.test'},shop={id:'shop',name:'Live Business',active:true},records={products:[{id:'product',name:'Real Product',sale_price:690,active:true}],customers:[{id:'customer',full_name:'Real Customer',phone:'+8801712345678',source:'facebook'}],orders:[{id:'order',order_number:'REAL-001',customer_id:'customer',recipient_name:'Real Customer',recipient_phone:'+8801712345678',status:'confirmed',subtotal:690,discount:0,delivery_charge:60,created_at:new Date().toISOString(),source:'facebook'}],items:[{order_id:'order',product_id:'product',product_name:'Real Product',quantity:1,unit_price:690}]};
const input={profile,shop,shops:[shop],profiles:[profile],members:[],records,accountRole:'Creator'};
for(const route of ['dashboard','products','customers','followups','permanent','team','orders','new','import','courier','profit','agentreports','settings','platformsettings','profile','shop']){
 const html=context.JioFlowOriginalViews.render(route,input);document.getElementById('app').innerHTML=html;assert.ok(html.includes('original-restored-view'),route);assert.equal(document.querySelector('[onclick]'),null,route);assert.equal(document.querySelector('[onsubmit]'),null,route);assert.equal(document.querySelector('script'),null,route);assert.equal(html.includes('This section is being connected to your workspace.'),false,route);assert.equal(html.includes('Karim Hasan'),false,route);
 if(['dashboard','customers','followups','permanent','orders','courier','agentreports'].includes(route)){
  const top=document.querySelector('.original-restored-view .stats');assert.ok(top,route+' summary');
  const labels=[...top.children].map(el=>(el.querySelector('.label,.tile-label')?.textContent||'').replace('↗','').trim());
  assert.ok(labels.includes('Unassigned'),route+' Unassigned');assert.ok(labels.indexOf('Completed')>=0&&labels.indexOf('Completed')<3,route+' Completed at top');
 }
 if(route==='orders'){assert.ok(html.includes('REAL-001'));assert.ok(html.includes('Real Customer'));assert.ok(document.querySelector('[data-original-tab="Confirmed"]'));const filtered=context.JioFlowOriginalViews.interact('tab','Cancelled');assert.equal(filtered.includes('REAL-001'),false)}
 if(route==='new'){assert.ok(document.querySelector('#order-form'));assert.ok(document.querySelector('#order-phone').disabled)}
}
console.log('Original screens passed: sixteen retained views render, real rows appear, order tabs filter, no sample people or executable local mutations.');

// Exercise actual allowlisted click transitions, without running legacy mutations.
const bridge=context.JioFlowOriginalViews;
bridge.render('dashboard',input);
let drill=bridge.action({name:'dashboardOrders',args:['Confirmed']});assert.ok(drill.includes('REAL-001'));assert.equal(bridge.currentSection(),'orders');
drill=bridge.action({name:'dashboardOrders',args:['Cancelled']});assert.equal(drill.includes('REAL-001'),false);
bridge.render('dashboard',input);drill=bridge.action({name:'dashboardCustomers',args:['Unassigned']});assert.ok(drill.includes('Real Customer'));assert.equal(bridge.currentSection(),'followups');
bridge.render('dashboard',input);document.getElementById('app').innerHTML=bridge.render('dashboard',input);assert.ok(document.querySelector('[data-original-action]'));
const before=JSON.stringify(records);bridge.action({name:'deleteProduct',args:['product']});assert.equal(JSON.stringify(records),before);
const member={id:'member',shop_id:'shop',user_id:'agent-user',role:'agent',status:'active'};const person={id:'agent-user',full_name:'Report Agent',email:'report@example.test',active:true};const reportInput={...input,members:[member],profiles:[profile,person]};
bridge.render('agentreports',reportInput);drill=bridge.action({name:'openAgentReport',args:['member']});assert.equal(bridge.currentSection(),'agentdetail');assert.ok(drill.includes('Report Agent'));
console.log('Click regression checks passed: confirmed/cancelled order drill-down, unassigned queue, Agent full report and mutation allowlist.');
bridge.render('profit',input);drill=bridge.action({name:'profitDetail',args:['source','facebook']});assert.equal(bridge.currentSection(),'profitdetail');assert.ok(drill.includes('REAL-001'));
bridge.render('profit',input);drill=bridge.action({name:'profitDetail',args:['source','whatsapp']});assert.equal(drill.includes('REAL-001'),false);
bridge.render('followups',input);document.getElementById('app').innerHTML=bridge.render('followups',input);assert.ok(document.querySelector('[data-original-live="followupForm"]'));assert.ok(document.querySelector('[data-original-live="showCustomer"]'));
const {createOriginalSections}=await import('./original-sections.mjs');let activeContext,opened=[],navigation;const region=document.getElementById('app');
const client={query:async table=>({jf_orders:records.orders,jf_products:records.products,jf_customers:records.customers,jf_order_items:records.items}[table]||[])};
const sections=createOriginalSections({client,navigate:(section,filters)=>{navigation={section,filters}},bridge:()=>bridge,onLiveAction:async(action,id)=>{opened.push([action,id]);return true},onReady:(_,ctx)=>{activeContext=ctx}});
await sections.mount({...input,root:region,section:'dashboard',canFinance:false});
const confirmedButton=[...region.querySelectorAll('[data-original-action]')].find(b=>JSON.parse(b.dataset.originalAction).name==='dashboardOrders');assert.ok(confirmedButton);confirmedButton.onclick();assert.equal(navigation.section,'orders');assert.equal(navigation.filters.status,'confirmed');
await sections.mount({...input,root:region,section:'followups',canFinance:false});await region.querySelector('[data-original-live="showCustomer"]').onclick();assert.deepEqual(opened.at(-1),['showCustomer','customer']);
console.log('DOM click checks passed: bound summary click opens order list; customer opens live action; profit source filters exclude unrelated records.');
