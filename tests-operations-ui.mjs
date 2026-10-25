// DOM behavior checks with mock records; no live Supabase data is touched.
import assert from 'node:assert/strict';
const {parseHTML}=await import(process.env.LINKEDOM_MODULE||'linkedom');
import {createOperations} from './online-operations.mjs';
const {document}=parseHTML('<html><body><div id="region"></div></body></html>');globalThis.document=document;
const shop={id:'shop-one',name:'Business One'},root=document.getElementById('region');let form,queries=[],rpcs=[];
let products=[{id:'product-one',name:'Sample <script>bad</script>',sku:'S1',sale_price:500,active:true,description:'Description'}],customers=[{id:'customer-one',full_name:'Test Customer',phone:'+8801712345678',source:'manual',address:'Dhaka'}];
const client={async query(table,params){queries.push({table,params});if(table==='jf_products')return products;if(table==='jf_product_costs')return [{product_id:'product-one',unit_cost:123}];if(table==='jf_followups')return [{id:'follow-one',customer_id:'customer-one',status:'pending'}];if(table==='jf_followup_events')return [{outcome:'busy',note:'Call <again>',created_at:'2026-10-22T00:00:00Z'}];return []},async rpc(name,body){rpcs.push({name,body});if(name==='jf_customer_page')return customers;if(name==='jf_set_product_active'){products[0].active=body.is_active;return products[0].id}return 'saved-id'}};
const openForm=(title,body,submit)=>{const d=document.createElement('div');d.innerHTML=body;form={title,body,submit,dialog:d};return d};
const ops=createOperations({client,openForm});const context={root,section:'products',shop,canEdit:true,canFinance:false,profiles:[],members:[]};
await ops.mount(context);assert.ok(root.textContent.includes('Sample <script>bad</script>'));assert.equal(root.querySelector('script'),null);assert.equal(root.textContent.includes('Cost'),false);assert.equal(queries.some(q=>q.table==='jf_product_costs'),false);
root.querySelector('[data-op-edit]').onclick();assert.equal(form.title,'Edit Product');assert.equal(form.body.includes('name="unit_cost"'),false);await form.submit(new Map([['name','New Name'],['sku','S1'],['sale_price','750'],['active','on'],['description','Test']]));assert.equal(rpcs.at(-1).name,'jf_save_product');assert.equal(rpcs.at(-1).body.details.active,true);assert.equal(rpcs.at(-1).body.details.unit_cost,undefined);
await root.querySelector('[data-op-toggle]').onclick();assert.equal(rpcs.at(-1).body.is_active,false);assert.ok(root.textContent.includes('Inactive'));
await ops.mount({...context,canEdit:false,canFinance:true});assert.equal(root.querySelector('[data-op-add]'),null);assert.equal(root.querySelector('[data-op-edit]'),null);assert.ok(root.textContent.includes('123'));
await ops.mount({...context,section:'customers'});assert.equal(rpcs.at(-1).name,'jf_customer_page');assert.equal(rpcs.at(-1).body.page_offset,0);assert.ok(root.textContent.includes('Test Customer'));assert.ok(root.textContent.includes('Notes & history'));
await root.querySelector('[data-op-history]').onclick();assert.equal(form.title,'Notes & follow-up history');assert.ok(form.body.includes('Call &lt;again&gt;'));
root.querySelector('[data-op-edit]').onclick();assert.equal(form.title,'Edit Customer');await form.submit(new Map([['full_name','Changed'],['phone','01712345678'],['assigned_membership_id','']]));const saved=rpcs.findLast(r=>r.name==='jf_save_customer');assert.equal(saved.body.customer_id,'customer-one');assert.equal(saved.body.details.permanent,false);
await ops.mount({...context,shop:null});assert.ok(root.textContent.includes('Select one business'));assert.equal(root.querySelector('table'),null);
// A late response for a previous shop cannot replace the latest business view.
let resolveOld;const late=new Promise(r=>resolveOld=r),race=createOperations({openForm,client:{...client,query(table,p){return p.includes('old-shop')?late:client.query(table,p)}}});
const first=race.mount({...context,shop:{id:'old-shop',name:'Old Shop'}});await race.mount({...context,shop});resolveOld([{id:'old',name:'Leaked old record',sale_price:1}]);await first;assert.equal(root.textContent.includes('Leaked old record'),false);assert.ok(root.textContent.includes('Business One'));
console.log('Operational UI checks passed: escaped content, edit forms, cost privacy, activation, customer save, history, one-shop requirement and stale-response isolation.');
