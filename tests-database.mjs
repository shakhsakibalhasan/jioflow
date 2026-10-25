// Run with PGLITE_MODULE pointing to an installed @electric-sql/pglite module.
// Uses an in-memory PostgreSQL-compatible database. No remote project is touched.
import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const {PGlite}=await import(process.env.PGLITE_MODULE||'@electric-sql/pglite');const db=new PGlite();
await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,invited_at timestamptz);create table auth.sessions(id uuid primary key,user_id uuid not null);create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;`);
for(const f of ['001_identity_and_shops.sql','002_crm_foundation.sql','003_account_provisioning.sql','004_products_customers_followups.sql'])await db.exec(await readFile(new URL('./supabase/migrations/'+f,import.meta.url),'utf8'));
const creator='11111111-1111-4111-8111-111111111111',owner='22222222-2222-4222-8222-222222222222',admin='33333333-3333-4333-8333-333333333333',agent='44444444-4444-4444-8444-444444444444',owner2='55555555-5555-4555-8555-555555555555',outsider='66666666-6666-4666-8666-666666666666';
async function identity(id){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:id})]);await db.exec('set role authenticated')}
async function q(sql,params=[]){return (await db.query(sql,params)).rows}
async function denied(sql,params=[]){await assert.rejects(()=>db.query(sql,params))}
await db.query(`insert into auth.users values($1,'creator@test.example',now(),null)`,[creator]);await db.query(`insert into public.jf_profiles(id,full_name,email,platform_role)values($1,'Creator','creator@test.example','creator')`,[creator]);await identity(creator);
const shop=(await q("select public.jf_create_shop('Business One') as id"))[0].id;
const shop2=(await q("select public.jf_create_shop('Business Two') as id"))[0].id;
async function attach(actor,shop,role,id,email){await identity(actor);const request=(await q("select public.jf_prepare_invitation($1,$2,'Test User',$3) as id",[shop,role,email]))[0].id;await db.exec('reset role');await db.query('insert into auth.users values($1,$2,now(),now())',[id,email]);await identity(actor);await q('select public.jf_finish_invitation($1,$2)',[request,id]);return request}
const ownerRequest=await attach(creator,shop,'owner',owner,'owner@test.example');await attach(creator,shop2,'owner',owner2,'owner2@test.example');
await identity(owner);await denied("select public.jf_create_shop('Forbidden')");await denied("select public.jf_prepare_invitation($1,'owner','Forbidden','another@test.example')",[shop]);await denied("select public.jf_prepare_invitation($1,'admin','Forbidden','another@test.example')",[shop2]);
await attach(owner,shop,'admin',admin,'admin@test.example');await attach(admin,shop,'agent',agent,'agent@test.example');
await identity(admin);await denied("select public.jf_prepare_invitation($1,'admin','Forbidden','another@test.example')",[shop]);await denied("update public.jf_shops set owner_id=$1 where id=$2",[admin,shop]);
const visible=await q('select email from public.jf_profiles');assert.ok(visible.some(p=>p.email==='owner@test.example'));assert.equal(visible.some(p=>p.email==='owner2@test.example'),false);
await db.exec('reset role');assert.equal((await q('select status from public.jf_memberships where user_id=$1',[agent]))[0].status,'pending');
await db.query("insert into public.jf_customers(shop_id,phone)values($1,'01700000001'),($2,'01700000001')",[shop,shop2]);
const customer=(await q('select id from public.jf_customers where shop_id=$1',[shop]))[0].id;
await denied("insert into public.jf_customers(shop_id,phone)values($1,'01700000001')",[shop]);
await denied("insert into public.jf_followups(shop_id,customer_id)values($1,$2)",[shop2,customer]);
await db.query('insert into public.jf_followups(shop_id,customer_id)values($1,$2)',[shop,customer]);await denied('insert into public.jf_followups(shop_id,customer_id)values($1,$2)',[shop,customer]);
await db.query("insert into public.jf_products(shop_id,name)values($1,'Product')",[shop]);const product=(await q('select id from public.jf_products where shop_id=$1',[shop]))[0].id;await db.query('insert into public.jf_product_costs(shop_id,product_id,unit_cost)values($1,$2,123)',[shop,product]);
await identity(admin);assert.equal((await q('select * from public.jf_customers')).length,1);assert.equal((await q('select * from public.jf_product_costs')).length,0);await denied("insert into public.jf_customers(shop_id,phone)values($1,'01711111111')",[shop]);
await db.exec('reset role');await db.query(`update public.jf_memberships set permissions=permissions||'{"profit":true}'::jsonb where user_id=$1`,[admin]);await identity(admin);assert.equal((await q('select * from public.jf_product_costs')).length,1);
await identity(agent);assert.equal((await q('select * from public.jf_customers')).length,0);await denied("select public.jf_prepare_invitation($1,'agent','Forbidden','another@test.example')",[shop]);
await db.exec('reset role');await db.query("update public.jf_memberships set status='active' where user_id=$1",[agent]);await identity(agent);assert.equal((await q('select * from public.jf_customers')).length,0);
await db.exec('reset role');await db.query('update auth.users set email_confirmed_at=null where id=$1',[admin]);await identity(admin);assert.equal((await q('select * from public.jf_customers')).length,0);await identity(owner);assert.equal((await q('select * from public.jf_product_costs')).length,1);await db.exec('reset role');await db.query('update public.jf_profiles set active=false where id=$1',[owner]);await identity(owner);assert.equal((await q('select * from public.jf_customers')).length,0);
await db.exec('reset role');await db.exec('set role anon');await denied('select * from public.jf_profiles');await denied("select public.jf_create_shop('Anonymous')");await denied('select * from public.jf_customers');
await db.exec('reset role');const versionCount=(await q('select count(*)::int as n from public.jf_schema_versions'))[0].n;assert.equal(versionCount,4);
await db.query('update public.jf_profiles set active=true where id=$1',[owner]);await db.query('update auth.users set email_confirmed_at=now() where id=$1',[admin]);await identity(owner);
const productPayload={name:'A Product',sku:'SKU-004',sale_price:'690.50',unit_cost:'120.25',active:true};
const savedProduct=(await q('select public.jf_save_product($1,null,$2::jsonb) as id',[shop,JSON.stringify(productPayload)]))[0].id;
await q('select public.jf_set_product_active($1,$2,false)',[shop,savedProduct]);assert.equal((await q('select active from public.jf_products where id=$1',[savedProduct]))[0].active,false);
await q('select public.jf_save_product($1,$2,$3::jsonb)',[shop,savedProduct,JSON.stringify({...productPayload,sale_price:'700.00',active:true})]);
assert.equal(Number((await q('select sale_price from public.jf_products where id=$1',[savedProduct]))[0].sale_price),700);
await denied('select public.jf_save_product($1,$2,$3::jsonb)',[shop2,savedProduct,JSON.stringify(productPayload)]);
for(const price of ['-1','NaN','1.234'])await denied('select public.jf_save_product($1,null,$2::jsonb)',[shop,JSON.stringify({...productPayload,sale_price:price})]);
const customerPayload={full_name:'Saved Customer',phone:'01712345678',source:'facebook',address:'Dhaka'};
const savedCustomer=(await q('select public.jf_save_customer($1,null,$2::jsonb) as id',[shop,JSON.stringify(customerPayload)]))[0].id;
assert.equal((await q('select phone from public.jf_customers where id=$1',[savedCustomer]))[0].phone,'+8801712345678');
const sameCustomer=(await q('select public.jf_save_customer($1,null,$2::jsonb) as id',[shop,JSON.stringify({...customerPayload,phone:'+8801712345678',full_name:'Updated Customer'})]))[0].id;assert.equal(sameCustomer,savedCustomer);
assert.equal((await q('select count(*)::int as n from public.jf_followups where customer_id=$1',[savedCustomer]))[0].n,1);
await denied('select public.jf_save_customer($1,null,$2::jsonb)',[shop,JSON.stringify({...customerPayload,permanent:true})]);
await denied('select public.jf_save_customer($1,null,$2::jsonb)',[shop,JSON.stringify({...customerPayload,assigned_membership_id:'99999999-9999-4999-8999-999999999999'})]);
await denied("select public.jf_record_followup($1,$2,'callback','busy')",[shop,savedCustomer]);
await q("select public.jf_record_followup($1,$2,'callback','busy',now()+interval '1 day','Call tomorrow')",[shop,savedCustomer]);
await q("select public.jf_record_followup($1,$2,'completed','positive',null,'Purchased')",[shop,savedCustomer]);
assert.equal((await q('select count(*)::int as n from public.jf_notes where customer_id=$1',[savedCustomer]))[0].n,2);
assert.equal((await q('select callback_at from public.jf_followups where customer_id=$1',[savedCustomer]))[0].callback_at,null);
assert.ok((await q("select * from public.jf_customer_page($1,'completed','+8801712',0)",[shop])).some(r=>r.id===savedCustomer));
assert.equal((await q("select * from public.jf_customer_page($1,'callback','+8801712',0)",[shop])).length,0);
await identity(admin);await denied('select public.jf_save_product($1,null,$2::jsonb)',[shop,JSON.stringify(productPayload)]);
await db.exec('reset role');await db.query(`update public.jf_memberships set permissions=permissions||'{"products":true,"profit":false}'::jsonb where user_id=$1`,[admin]);await identity(admin);
await denied('select public.jf_save_product($1,null,$2::jsonb)',[shop,JSON.stringify(productPayload)]);
const publicProduct={...productPayload,sku:'ADMIN-004'};delete publicProduct.unit_cost;await q('select public.jf_save_product($1,null,$2::jsonb)',[shop,JSON.stringify(publicProduct)]);
await identity(agent);await denied('select public.jf_save_customer($1,null,$2::jsonb)',[shop,JSON.stringify(customerPayload)]);assert.equal((await q('select * from public.jf_customer_page($1)',[shop])).length,0);
await db.exec('reset role');await db.exec('set role anon');await denied('select public.jf_save_customer($1,null,$2::jsonb)',[shop,JSON.stringify(customerPayload)]);
await db.exec('reset role');
await db.query('insert into auth.sessions(id,user_id)select id,id from public.jf_profiles');
await db.exec(await readFile(new URL('./supabase/migrations/005_account_management.sql',import.meta.url),'utf8'));
await identity(creator);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,true);
await q("select public.jf_manage_account($1,'edit',$2::jsonb)",[admin,JSON.stringify({full_name:'Renamed Admin',phone:'01712345678'})]);assert.equal((await q('select full_name from public.jf_profiles where id=$1',[admin]))[0].full_name,'Renamed Admin');
await denied("select public.jf_manage_account($1,'edit',$2::jsonb)",[admin,JSON.stringify({platform_role:'creator'})]);
await denied("select public.jf_manage_account($1,'remove')",[creator]);
await identity(owner);await denied("select public.jf_manage_account($1,'remove')",[admin]);
await identity(agent);await denied("select public.jf_manage_account($1,'edit','{}')",[admin]);
await identity(creator);await q("select public.jf_manage_account($1,'force_logout')",[admin]);
await identity(admin);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,false);assert.equal((await q('select * from public.jf_profiles')).length,0);assert.equal((await q('select * from public.jf_customers')).length,0);await denied('select public.jf_save_product($1,null,$2::jsonb)',[shop,JSON.stringify(publicProduct)]);
// Refreshing the old session retains its ID; a new password login creates a new ID.
await db.exec('reset role');const freshSession='77777777-7777-4777-8777-777777777777';await db.query('insert into auth.sessions values($1,$2)',[freshSession,admin]);await identity(admin);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:freshSession})]);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,true);assert.ok((await q('select * from public.jf_customers')).length>0);
await db.exec('reset role');const agentMembership=(await q('select id from public.jf_memberships where user_id=$1',[agent]))[0].id;await db.query('update public.jf_customers set assigned_membership_id=$1,permanent=true where id=$2',[agentMembership,savedCustomer]);
await db.exec(await readFile(new URL('./supabase/migrations/006_account_activation.sql',import.meta.url),'utf8'));
await identity(owner);await denied("select public.jf_manage_account($1,'deactivate')",[admin]);
await identity(creator);await denied("select public.jf_manage_account($1,'deactivate')",[creator]);
await q("select public.jf_manage_account($1,'deactivate')",[agent]);
await db.exec('reset role');assert.equal((await q('select active from public.jf_profiles where id=$1',[agent]))[0].active,false);assert.equal((await q('select assigned_membership_id from public.jf_customers where id=$1',[savedCustomer]))[0].assigned_membership_id,agentMembership);
await identity(agent);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,false);
await identity(creator);await q("select public.jf_manage_account($1,'activate')",[agent]);
await identity(agent);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,false);
await db.exec('reset role');const agentNew='88888888-8888-4888-8888-888888888888';await db.query('insert into auth.sessions values($1,$2)',[agentNew,agent]);await identity(agent);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:agentNew})]);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,true);
await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/007_live_orders.sql',import.meta.url),'utf8'));
await identity(creator);
const orderInput={full_name:'Order Buyer',phone:'01723456789',address:'Dhaka address',source:'facebook',status:'confirmed',discount:'10',delivery_charge:'60',advance:'100',payment_method:'bKash',transaction_id:'ORDER-TX-1',items:[{product_id:savedProduct,quantity:2,unit_price:'700'}]};
const requestKey='99999999-9999-4999-8999-999999999999';
const savedOrder=(await q('select public.jf_save_order($1,$2,$3::jsonb) as id',[shop,requestKey,JSON.stringify(orderInput)]))[0].id;
assert.equal((await q('select public.jf_save_order($1,$2,$3::jsonb) as id',[shop,requestKey,JSON.stringify(orderInput)]))[0].id,savedOrder);
assert.equal(Number((await q('select total from public.jf_orders where id=$1',[savedOrder]))[0].total),1450);
assert.equal((await q('select count(*)::int n from public.jf_order_items where order_id=$1',[savedOrder]))[0].n,1);
assert.equal((await q('select status from public.jf_payments where order_id=$1',[savedOrder]))[0].status,'pending');
await denied('select public.jf_save_order($1,gen_random_uuid(),$2::jsonb)',[shop2,JSON.stringify(orderInput)]);
for(const change of [{discount:'99999'},{advance:'99999'},{items:[]},{items:[{product_id:savedProduct,quantity:0,unit_price:'5'}]},{items:[{product_id:null,quantity:1,unit_price:'5'}]}])await denied('select public.jf_save_order($1,gen_random_uuid(),$2::jsonb)',[shop,JSON.stringify({...orderInput,...change})]);
await denied('select public.jf_save_order($1,gen_random_uuid(),$2::jsonb)',[shop,JSON.stringify(orderInput)]);
assert.equal((await q('select count(*)::int n from public.jf_orders'))[0].n,1);
await q("select public.jf_update_order($1,$2,$3::jsonb)",[shop,savedOrder,JSON.stringify({status:'ready_to_book',note:'Call before delivery',assigned_membership_id:agentMembership})]);
assert.equal((await q('select shipping_note from public.jf_orders where id=$1',[savedOrder]))[0].shipping_note,'Call before delivery');
await denied("select public.jf_update_order($1,$2,$3::jsonb)",[shop2,savedOrder,JSON.stringify({status:'cancelled'})]);
await denied("select public.jf_update_order($1,$2,$3::jsonb)",[shop,savedOrder,JSON.stringify({status:'delivered'})]);
await identity(agent);await denied('select public.jf_save_order($1,gen_random_uuid(),$2::jsonb)',[shop,JSON.stringify(orderInput)]);
console.log('Order checks passed: atomic creation, idempotency, totals, pending payments, validation, cross-shop denial, status/note/assignment updates and no fake delivery.');
await db.exec('reset role');await db.exec("alter table auth.users add column email_change text not null default ''");await db.exec(await readFile(new URL('./supabase/migrations/008_creator_profile_edit.sql',import.meta.url),'utf8'));
await identity(creator);await q('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({full_name:'Detailed Admin',phone:'01712345678',job_title:'Sales',address:'Dhaka',user_code:'AG-12',avatar_path:'data:image/png;base64,aGVsbG8='})]);
assert.equal((await q('select job_title from public.jf_profiles where id=$1',[admin]))[0].job_title,'Sales');
await denied('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({email:'bypass@example.test'})]);
await denied('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({avatar_path:'https://tracker.invalid/image'})]);
await denied('select public.jf_save_profile($1,$2::jsonb)',[creator,JSON.stringify({role:'owner',shop_id:shop})]);
await q('select public.jf_save_profile($1,$2::jsonb)',[creator,JSON.stringify({full_name:'Updated Creator',phone:'01700000000'})]);
await q('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({role:'admin',shop_id:shop2,permissions:{assign:true}})]);
assert.equal((await q("select shop_id from public.jf_memberships where user_id=$1 and status<>'removed'",[admin]))[0].shop_id,shop2);
assert.equal((await q("select count(*)::int n from public.jf_memberships where user_id=$1 and status='removed'",[admin]))[0].n,1);
await denied('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({role:'owner',shop_id:shop})]);
await denied('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({role:'agent',shop_id:shop2,permissions:{profit:true}})]);
await q('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({role:'admin',shop_id:shop,permissions:{assign:true,products:true}})]);
assert.equal((await q("select count(*)::int n from public.jf_memberships where user_id=$1 and status<>'removed'",[admin]))[0].n,1);
await identity(owner);await denied('select public.jf_save_profile($1,$2::jsonb)',[admin,JSON.stringify({full_name:'Hijack'})]);
await q('select public.jf_save_profile($1,$2::jsonb)',[owner,JSON.stringify({job_title:'Business Owner'})]);
await denied('select public.jf_account_email_target($1)',[admin]);
await identity(creator);assert.equal((await q('select public.jf_account_email_target($1) as x',[admin]))[0].x.email,'admin@test.example');await denied('select public.jf_account_email_target($1)',[creator]);
await db.exec('reset role');await db.query("update auth.users set email='changed@test.example',email_change='' where id=$1",[admin]);assert.equal((await q('select email from public.jf_profiles where id=$1',[admin]))[0].email,'changed@test.example');
console.log('Profile checks passed: Creator/self editing, image limits, role/shop transitions, historical memberships, permission validation, protected Creator, email action authorization and Auth email sync.');
await identity(creator);await q("select public.jf_manage_account($1,'remove')",[agent]);
await db.exec('reset role');const removed=(await q('select active,deleted_at from public.jf_profiles where id=$1',[agent]))[0];assert.equal(removed.active,false);assert.ok(removed.deleted_at);assert.equal((await q('select status from public.jf_memberships where user_id=$1',[agent]))[0].status,'removed');const unassigned=(await q('select assigned_membership_id,permanent from public.jf_customers where id=$1',[savedCustomer]))[0];assert.equal(unassigned.assigned_membership_id,null);assert.equal(unassigned.permanent,false);assert.equal((await q('select count(*)::int as n from public.jf_followup_events where followup_id=(select id from public.jf_followups where customer_id=$1)',[savedCustomer]))[0].n,2);
await identity(creator);await q("select public.jf_manage_account($1,'remove')",[owner]);assert.equal((await q('select owner_id from public.jf_shops where id=$1',[shop]))[0].owner_id,null);
await identity(owner);assert.equal((await q('select public.jf_session_status() as ok'))[0].ok,false);assert.equal((await q('select * from public.jf_customers')).length,0);
await db.exec('reset role');assert.ok((await q('select count(*)::int as n from jioflow_private.account_audit'))[0].n>=4);await db.exec('set role authenticated');await denied('select * from jioflow_private.account_audit');await denied('delete from jioflow_private.revoked_sessions');await db.exec('reset role');await db.exec('set role anon');await denied('select public.jf_session_status()');await denied("select public.jf_manage_account($1,'remove')",[admin]);
console.log('Account management checks passed: Creator-only edits/removal, self/role protection, revoked session RLS and RPC denial, fresh login, unassignment, preserved history, Owner detachment and private audits.');
await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/009_agent_sessions_shops.sql',import.meta.url),'utf8'));
await identity(creator);const testShop=(await q("select public.jf_create_shop('Approval Test') id"))[0].id;
const aid='77777777-7777-4777-8777-777777777777',session1='88888888-8888-4888-8888-888888888881',session2='88888888-8888-4888-8888-888888888882';
const req=(await q("select public.jf_prepare_invitation($1,'agent','Managed Agent','random@example.test') id",[testShop]))[0].id;
await db.exec('reset role');await db.query("insert into auth.users(id,email,email_confirmed_at) values($1,'random@example.test',now())",[aid]);await db.query('insert into auth.sessions values($1,$2)',[session1,aid]);await identity(creator);
await q("select public.jf_finish_agent($1,$2,'JIO-001')",[req,aid]);await denied("select public.jf_validate_agent_id('jio-001')");await denied('select public.jf_save_profile($1,$2)',[aid,JSON.stringify({role:'admin',shop_id:testShop,permissions:{}})]);
const tp=(await q('select public.jf_save_product($1,null,$2) id',[testShop,JSON.stringify({name:'Agent product',sale_price:'100',unit_cost:'50'})]))[0].id;
const otherCustomer=(await q('select public.jf_save_customer($1,null,$2) id',[testShop,JSON.stringify({full_name:'Other queue',phone:'01711112222'})]))[0].id;
async function agentIdentity(s){await identity(aid);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:s})])}
await agentIdentity(session1);const device='test-device-123456789';assert.equal((await q('select public.jf_agent_session($1) a',[device]))[0].a.status,'pending');assert.equal((await q('select * from public.jf_products')).length,0);await denied('select public.jf_approve_agent($1,true)',[session1]);
await identity(creator);await q('select public.jf_approve_agent($1,true)',[session1]);await agentIdentity(session1);assert.equal((await q('select public.jf_agent_session($1) a',[device]))[0].a.status,'approved');assert.equal((await q('select * from public.jf_products')).length,1);assert.equal((await q('select * from public.jf_product_costs')).length,0);assert.equal((await q('select * from public.jf_customers')).length,0);
await denied('select public.jf_save_customer($1,$2,$3)',[testShop,otherCustomer,JSON.stringify({full_name:'Steal',phone:'01711112222'})]);
const ac=(await q('select public.jf_save_customer($1,null,$2) id',[testShop,JSON.stringify({full_name:'My customer',phone:'01711113333'})]))[0].id;assert.equal((await q('select * from public.jf_customers')).length,1);
await q("select public.jf_record_followup($1,$2,'completed','positive')",[testShop,ac]);await denied("select public.jf_record_followup($1,$2,'cancelled')",[testShop,otherCustomer]);
const ao=(await q('select public.jf_save_order($1,gen_random_uuid(),$2) id',[testShop,JSON.stringify({full_name:'My customer',phone:'01711113333',address:'Dhaka',items:[{product_id:tp,quantity:1,unit_price:'100'}],status:'confirmed'})]))[0].id;assert.equal((await q('select * from public.jf_orders')).length,1);assert.equal((await q('select * from public.jf_order_items')).length,1);
await denied('select public.jf_manage_shop($1,\'archive\',\'{"confirmation":"Approval Test"}\')',[testShop]);
await db.exec('reset role');await db.query('insert into auth.sessions values($1,$2)',[session2,aid]);await agentIdentity(session2);assert.equal((await q('select public.jf_agent_session($1) a',['another-device-123456']))[0].a.status,'pending');assert.equal((await q('select * from public.jf_orders')).length,0);
await identity(creator);await q('select public.jf_approve_agent($1,true)',[session2]);await agentIdentity(session1);assert.equal((await q('select public.jf_session_status() ok'))[0].ok,false);await agentIdentity(session2);assert.equal((await q('select * from public.jf_orders')).length,1);await q('select public.jf_end_agent_session()');assert.equal((await q('select public.jf_session_status() ok'))[0].ok,false);
await identity(creator);await denied('select public.jf_manage_shop($1,\'archive\',\'{"confirmation":"Wrong"}\')',[testShop]);await q('select public.jf_manage_shop($1,\'edit\',\'{"name":"Renamed Shop","phone":"01700000000"}\')',[testShop]);await q('select public.jf_manage_shop($1,\'archive\',\'{"confirmation":"Renamed Shop"}\')',[testShop]);assert.equal((await q('select active from public.jf_shops where id=$1',[testShop]))[0].active,false);assert.equal((await q('select * from public.jf_orders where id=$1',[ao])).length,1);await q('select public.jf_manage_shop($1,\'restore\',\'{"confirmation":"Renamed Shop"}\')',[testShop]);
await q("select public.jf_creator_archive($1,'order',$2,false)",[testShop,ao]);assert.ok((await q('select archived_at from public.jf_orders where id=$1',[ao]))[0].archived_at);assert.equal((await q('select * from public.jf_order_items where order_id=$1',[ao])).length,1);await q("select public.jf_creator_archive($1,'order',$2,true)",[testShop,ao]);
console.log('009 checks passed: managed Agent ID uniqueness, promotion protection, per-session approval, pending data blockade, own-queue reads/writes, cost privacy, single session, logout revocation, shop edit/archive/restore and retained history.');

await db.exec('reset role');await db.exec("alter table auth.users add column encrypted_password text default 'old-hash'");await db.exec(await readFile(new URL('./supabase/migrations/010_notifications_passwords.sql',import.meta.url),'utf8'));
await identity(creator);assert.equal((await q('select public.jf_password_self_service() ok'))[0].ok,true);
const bd={name:'Third business',email:'third@example.test',phone:'01712345678',address:'Dhaka office',district:'Dhaka',business_type:'Retail',website:'https://example.test',facebook_url:'https://facebook.com/example',logo_path:'data:image/png;base64,aGVsbG8='};
const business=(await q('select public.jf_save_business(null,$1::jsonb) id',[JSON.stringify(bd)]))[0].id;
const business2=(await q('select public.jf_save_business(null,$1::jsonb) id',[JSON.stringify({...bd,name:'Fourth business'})]))[0].id;assert.notEqual(business,business2);assert.equal((await q('select district from public.jf_shops where id=$1',[business]))[0].district,'Dhaka');await denied('select public.jf_save_business(null,$1::jsonb)',[JSON.stringify({...bd,email:'bad'})]);
const session3='88888888-8888-4888-8888-888888888883';await db.exec('reset role');await db.query('insert into auth.sessions values($1,$2)',[session3,aid]);await agentIdentity(session3);await q('select public.jf_agent_session($1)',['third-device-123456']);assert.equal((await q('select public.jf_password_self_service() ok'))[0].ok,false);await denied('select public.jf_save_business(null,$1::jsonb)',[JSON.stringify(bd)]);
const pwreq=(await q('select public.jf_request_password_reset() id'))[0].id;assert.equal((await q('select public.jf_request_password_reset() id'))[0].id,pwreq);await denied('select public.jf_decide_password_reset($1,true)',[pwreq]);await denied('select public.jf_authorize_agent_reset($1)',[pwreq]);assert.equal((await q('select public.jf_can_reset_password() ok'))[0].ok,false);
await db.exec('reset role');await denied("update auth.users set encrypted_password='unapproved' where id=$1",[aid]);await identity(creator);let feed=(await q('select public.jf_notifications_feed() x'))[0].x;assert.ok(feed.items.some(n=>n.kind==='agent_login'));assert.ok(feed.items.some(n=>n.kind==='password_request'));const notification=feed.items.find(n=>n.kind==='password_request');await q('select public.jf_notification_read($1)',[notification.id]);assert.ok((await q('select public.jf_notifications_feed() x'))[0].x.items.find(n=>n.id===notification.id).is_read);
await q('select public.jf_decide_password_reset($1,true)',[pwreq]);assert.equal((await q('select public.jf_authorize_agent_reset($1) x',[pwreq]))[0].x.email,'random@example.test');await denied('select public.jf_authorize_agent_reset($1)',[pwreq]);
await agentIdentity(session3);feed=(await q('select public.jf_notifications_feed() x'))[0].x;assert.equal(feed.items.some(n=>n.kind==='shop'),false);assert.equal(feed.items.some(n=>n.kind==='password_request'),false);assert.ok(feed.items.some(n=>n.kind==='password_decision'));await denied('select public.jf_notification_read($1)',[notification.id]);assert.equal((await q('select public.jf_can_reset_password() ok'))[0].ok,true);
await db.exec('reset role');await db.query("update auth.users set encrypted_password='approved-new-hash' where id=$1",[aid]);assert.equal((await q('select status from public.jf_password_requests where id=$1',[pwreq]))[0].status,'used');await denied("update auth.users set encrypted_password='reuse-rejected' where id=$1",[aid]);
// Staff can change their own password without Agent approval. No production hash is used.
for(const [id,sid] of [[owner2,'99999999-9999-4999-8999-999999999991'],[admin,'99999999-9999-4999-8999-999999999992']]){await db.exec('reset role');await db.query('insert into auth.sessions values($1,$2)',[sid,id]);await identity(id);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:sid})]);assert.equal((await q('select public.jf_password_self_service() ok'))[0].ok,true);await db.exec('reset role');await db.query("update auth.users set encrypted_password='staff-new-hash' where id=$1",[id]);}
await identity(creator);await q('select public.jf_save_business($1,$2::jsonb)',[business,JSON.stringify({...bd,name:'Third updated'})]);assert.equal((await q('select name from public.jf_shops where id=$1',[business]))[0].name,'Third updated');
console.log('010 checks passed: notification visibility/read receipts, Agent login events, approval-only one-use password updates at Auth storage, staff self-service, reset mail authorization and atomic multi-shop details.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/011_shop_pause_delete.sql',import.meta.url),'utf8'));
await identity(creator);const preserved=(await q('select count(*)::int n from public.jf_orders where shop_id=$1',[testShop]))[0].n;
await q("select public.jf_set_shop_paused($1,true,'Payment pending')",[testShop]);assert.equal((await q('select active from public.jf_shops where id=$1',[testShop]))[0].active,false);assert.equal((await q('select count(*)::int n from public.jf_orders where shop_id=$1',[testShop]))[0].n,preserved);
const session4='88888888-8888-4888-8888-888888888884';await db.exec('reset role');await db.query('insert into auth.sessions values($1,$2)',[session4,aid]);await agentIdentity(session4);const blocked=(await q('select public.jf_workspace_status() x'))[0].x;assert.equal(blocked.blocked,true);assert.equal(blocked.reason,'Payment pending');assert.equal((await q('select * from public.jf_orders')).length,0);await denied('select public.jf_agent_session($1)',['fourth-device-123456']);await denied('select public.jf_set_shop_paused($1,false)',[testShop]);await denied('select public.jf_delete_shop($1)',[testShop]);
await identity(creator);assert.equal((await q('select active from public.jf_shops where id=$1',[business]))[0].active,true);await q('select public.jf_set_shop_paused($1,false)',[testShop]);await agentIdentity(session4);assert.equal((await q('select public.jf_workspace_status() x'))[0].x.blocked,false);await q('select public.jf_agent_session($1)',['fourth-device-123456']);await identity(creator);await q('select public.jf_approve_agent($1,true)',[session4]);await agentIdentity(session4);assert.equal((await q('select count(*)::int n from public.jf_orders'))[0].n,preserved);
await db.exec('reset role');const shipment=(await q("insert into public.jf_shipments(shop_id,order_id,courier) values($1,$2,'Test courier') returning id",[testShop,ao]))[0].id;await q("insert into public.jf_courier_events(shop_id,shipment_id,status) values($1,$2,'pending')",[testShop,shipment]);await q('insert into public.jf_order_finance(shop_id,order_id,product_cost) values($1,$2,10)',[testShop,ao]);await q("insert into public.jf_notes(shop_id,customer_id,order_id,body) values($1,$2,$3,'Delete fixture')",[testShop,ac,ao]);const group=(await q("insert into public.jf_groups(shop_id,name) values($1,'Group fixture') returning id",[testShop]))[0].id;await q('insert into public.jf_group_members select shop_id,$2,id from public.jf_memberships where shop_id=$1 and user_id=$3',[testShop,group,aid]);
await identity(creator);await q('select public.jf_delete_shop($1)',[testShop]);assert.equal((await q('select * from public.jf_shops where id=$1',[testShop])).length,0);assert.equal((await q('select count(*)::int n from public.jf_orders where shop_id=$1',[testShop]))[0].n,0);assert.equal((await q('select count(*)::int n from public.jf_shipments where shop_id=$1',[testShop]))[0].n,0);assert.equal((await q('select count(*)::int n from public.jf_memberships where shop_id=$1',[testShop]))[0].n,0);assert.equal((await q('select active from public.jf_profiles where id=$1',[aid]))[0].active,false);assert.ok((await q('select * from public.jf_shops where id=$1',[business])).length);assert.ok((await q('select public.jf_notifications_feed() x'))[0].x.items.some(n=>n.title==='Shop deleted'));
for(const [person,sid,ws] of [[owner2,'abababab-abab-4bab-8bab-ababababab01',shop2],[admin,'abababab-abab-4bab-8bab-ababababab02',shop]]){await identity(creator);await q("select public.jf_set_shop_paused($1,true,'Billing hold')",[ws]);await db.exec('reset role');await db.query('insert into auth.sessions values($1,$2)',[sid,person]);await identity(person);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:sid})]);assert.equal((await q('select public.jf_workspace_status() x'))[0].x.blocked,true);assert.equal((await q('select * from public.jf_products')).length,0);await denied('select public.jf_save_customer($1,null,$2::jsonb)',[ws,JSON.stringify({full_name:'Blocked',phone:'01712345678'})]);await identity(creator);await q('select public.jf_set_shop_paused($1,false)',[ws]);}
console.log('011 checks passed: Creator-only pause/resume/delete, blocked Agent business reads/actions, retained pause data, unaffected other shops, resume approval and permanent child-first deletion of populated records.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/012_account_recovery.sql',import.meta.url),'utf8'));await identity(creator);
const removedOwner=(await q("select public.jf_lookup_account('owner@test.example') x"))[0].x;assert.equal(removedOwner.exists,true);assert.equal(removedOwner.state,'removed');assert.equal(removedOwner.shop_id,null);
await denied('select public.jf_recover_account($1,$2,$3,$4,false)',['owner@test.example',business,'owner','Restored Owner']);
await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['owner@test.example',shop2,'owner','Collision rejected']);assert.equal((await q("select public.jf_lookup_account('owner@test.example') x"))[0].x.state,'removed');
await q('select public.jf_recover_account($1,$2,$3,$4,true)',['owner@test.example',business,'owner','Restored Owner']);assert.equal((await q('select owner_id from public.jf_shops where id=$1',[business]))[0].owner_id,owner);assert.equal((await q('select active from public.jf_profiles where id=$1',[owner]))[0].active,true);assert.equal((await q("select public.jf_lookup_account('owner@test.example') x"))[0].x.state,'assigned');await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['owner@test.example',business2,'owner','Move forbidden']);
const orphan='edededed-eded-4ded-8ded-ededededed01';await db.exec('reset role');await db.query("insert into auth.users(id,email,email_confirmed_at,invited_at,encrypted_password) values($1,'pending-owner@example.test',null,now(),'unchanged-private-hash')",[orphan]);await identity(creator);assert.equal((await q("select public.jf_lookup_account('pending-owner@example.test') x"))[0].x.state,'profile_missing');await q('select public.jf_recover_account($1,$2,$3,$4,true)',['pending-owner@example.test',business2,'owner','Pending Owner']);assert.equal((await q('select email_verified_at from public.jf_profiles where id=$1',[orphan]))[0].email_verified_at,null);await db.exec('reset role');assert.equal((await q('select encrypted_password from auth.users where id=$1',[orphan]))[0].encrypted_password,'unchanged-private-hash');
await db.exec('reset role');const ownerLogin='cccccccc-cccc-4ccc-8ccc-cccccccccc01';await db.query('insert into auth.sessions values($1,$2)',[ownerLogin,owner]);await identity(owner);await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({session_id:ownerLogin})]);assert.equal((await q('select public.jf_session_status() ok'))[0].ok,true);assert.equal((await q('select public.jf_workspace_status() x'))[0].x.blocked,false);assert.ok((await q('select id from public.jf_shops')).some(x=>x.id===business));
await identity(creator);assert.equal((await q("select public.jf_lookup_account('not-found@example.test') x"))[0].x.exists,false);await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['creator@test.example',business2,'admin','Creator protected']);
// Managed Agent identity cannot be recovered as an Owner using internal Auth confirmation.
await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['random@example.test',shop2,'owner','Agent promotion forbidden']);
await identity(owner2);await denied("select public.jf_lookup_account('owner@test.example')");await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['owner@test.example',shop2,'admin','Unauthorized']);
await db.exec('reset role');await db.exec("alter table auth.users add column raw_app_meta_data jsonb default '{}'::jsonb");const managedOrphan='edededed-eded-4ded-8ded-ededededed02';await db.query("insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data) values($1,'managed-orphan@example.test',now(),'{\"jioflow_managed_agent\":true}')",[managedOrphan]);await identity(creator);await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['managed-orphan@example.test',shop2,'agent','Managed orphan']);await denied('select public.jf_recover_account($1,$2,$3,$4,true)',['managed-orphan@example.test',shop2,'admin','Managed orphan']);
console.log('012 checks passed: Creator-only lookup/recovery, removed Owner restore, missing profile repair, password hash unchanged, email verification preserved, assigned-account protection and managed-Agent promotion denial.');


await db.exec('reset role');
await db.exec(await readFile(new URL('./supabase/migrations/013_product_images.sql',import.meta.url),'utf8'));
await identity(creator);
const ecoryShop=(await q("select public.jf_create_shop('Ecory') as id"))[0].id;
assert.equal((await q('select public.jf_add_ecory_catalog($1) as n',[ecoryShop]))[0].n,14);
assert.equal((await q('select public.jf_add_ecory_catalog($1) as n',[ecoryShop]))[0].n,0);
await denied('select public.jf_add_ecory_catalog($1)',[shop2]);
const ep=(await q('select * from public.jf_products where shop_id=$1 limit 1',[ecoryShop]))[0];
assert.ok(ep.image_path.startsWith('assets/'));
await q('select public.jf_save_product($1,$2,$3)',[ecoryShop,ep.id,{name:ep.name,sku:ep.sku,sale_price:'123',image_path:'data:image/png;base64,aGVsbG8='}]);
assert.equal((await q('select image_path from public.jf_products where id=$1',[ep.id]))[0].image_path,'data:image/png;base64,aGVsbG8=');
await q('select public.jf_save_product($1,$2,$3)',[ecoryShop,ep.id,{name:ep.name,sku:ep.sku,sale_price:'124'}]);
assert.equal((await q('select image_path from public.jf_products where id=$1',[ep.id]))[0].image_path,'data:image/png;base64,aGVsbG8=');
await denied('select public.jf_save_product($1,$2,$3)',[ecoryShop,ep.id,{name:ep.name,sale_price:'123',image_path:'javascript:alert(1)'}]);
await q('select public.jf_save_product($1,$2,$3)',[ecoryShop,ep.id,{name:ep.name,sku:ep.sku,sale_price:'124',image_path:''}]);
assert.equal((await q('select image_path from public.jf_products where id=$1',[ep.id]))[0].image_path,null);
await q('select public.jf_add_ecory_catalog($1)',[ecoryShop]);
assert.equal(Number((await q('select sale_price from public.jf_products where id=$1',[ep.id]))[0].sale_price),124);
await identity(agent);await denied('select public.jf_add_ecory_catalog($1)',[ecoryShop]);
console.log('013 passed: Ecory-only catalog, idempotency, existing price retention, image save/preserve/remove and unsafe/Agent denial.');

await db.exec('reset role');
await db.exec(await readFile(new URL('./supabase/migrations/014_workspace_tools.sql',import.meta.url),'utf8'));
await identity(creator);
await q('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'save_settings',{value:{inside:60,outside:120,pull_count:3,sources:['website'],statuses:['Interested']}}]);
let tools=(await q('select public.jf_workspace_tools($1,$2,$3) value',[ecoryShop,'load',{page:'dashboard'}]))[0].value;assert.equal(tools.settings.inside,60);
await q('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'save_layout',{page:'dashboard',value:{title:'My dashboard',hidden:['x']}}]);
tools=(await q('select public.jf_workspace_tools($1,$2,$3) value',[ecoryShop,'load',{page:'dashboard'}]))[0].value;assert.equal(tools.layout.title,'My dashboard');
await denied('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'save_settings',{value:{api_secret:'never'}}]);
await denied('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'save_settings',{value:{inside:-1}}]);
await q('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'products',{ids:[ep.id],action:'deactivate'}]);assert.equal((await q('select active from public.jf_products where id=$1',[ep.id]))[0].active,false);
let g=(await q('select public.jf_workspace_tools($1,$2,$3) value',[ecoryShop,'save_group',{name:'New group',members:[]}]))[0].value;
await q('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'delete_group',{id:g.id}]);
await identity(outsider);await denied('select public.jf_workspace_tools($1,$2,$3)',[ecoryShop,'load',{}]);
console.log('014 passed: durable settings/layout, product bulk action, group CRUD, invalid settings and cross-tenant denial.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/015_reporting_pages.sql',import.meta.url),'utf8'));
await identity(creator);let full=(await q('select public.jf_workspace_summary($1) v',[ecoryShop]))[0].v;assert.equal(typeof full.customers,'number');
let paged=(await q('select public.jf_workspace_page($1,$2,$3,$4) v',[ecoryShop,'customers',{status:'unassigned'},0]))[0].v;assert.equal(paged.total,full.unassigned);
await identity(outsider);full=(await q('select public.jf_workspace_summary($1) v',[ecoryShop]))[0].v;assert.equal(full.customers,0);assert.equal(full.orders,0);
console.log('015 passed: database totals, filtered page/count agreement and RLS tenant isolation.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/016_delegated_accounts.sql',import.meta.url),'utf8'));
await identity(creator);await q('select public.jf_save_profile($1,$2)',[creator,{full_name:'Creator'}]);
await identity(outsider);await denied('select public.jf_save_profile($1,$2)',[creator,{full_name:'Attempt'}]);await denied('select public.jf_manage_account($1,$2,$3)',[creator,'deactivate',{}]);
console.log('016 passed: delegated account migration, retained Creator self edit and outsider/Creator protection.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/017_history_import.sql',import.meta.url),'utf8'));
await identity(creator);let job=(await q('select public.jf_history_import($1,$2,$3) v',[ecoryShop,'create',{file_name:'history.csv'}]))[0].v;
const historicalRows=[{external_id:'OLD-1',customer:{full_name:'History Customer',phone:'01700006666'},products:'Product A',total:'100'},{external_id:'OLD-2',customer:{full_name:'History Customer',phone:'01700006666'},products:'Product B',total:'200'},{external_id:'BAD',customer:{full_name:'',phone:'bad'}}];
await q('select public.jf_history_import($1,$2,$3)',[ecoryShop,'stage',{job_id:job.id,offset:0,rows:historicalRows}]);await q('select public.jf_history_import($1,$2,$3)',[ecoryShop,'stage',{job_id:job.id,offset:0,rows:historicalRows}]);await q('select public.jf_history_import($1,$2,$3)',[ecoryShop,'ready',{job_id:job.id}]);
job=(await q('select public.jf_history_import($1,$2,$3) v',[ecoryShop,'process',{job_id:job.id}]))[0].v;assert.equal(job.status,'completed');assert.equal(job.staged,3);assert.equal(job.processed,3);assert.equal(job.rejected,1);
assert.equal((await q('select * from public.jf_order_history where shop_id=$1',[ecoryShop])).length,2);
await identity(outsider);await denied('select public.jf_history_import($1,$2,$3)',[ecoryShop,'list',{}]);assert.equal((await q('select * from public.jf_order_history where shop_id=$1',[ecoryShop])).length,0);
console.log('017 passed: durable job staging retry, same-phone multiple invoices, row error isolation and cross-shop denial.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/018_finance_agent_totals.sql',import.meta.url),'utf8'));
await identity(creator);assert.ok(Array.isArray((await q('select public.jf_agent_totals($1) v',[ecoryShop]))[0].v));assert.equal(typeof (await q('select public.jf_finance_totals($1) v',[ecoryShop]))[0].v.revenue,'number');
await identity(outsider);await denied('select public.jf_finance_totals($1)',[ecoryShop]);
console.log('018 passed: all-record Agent aggregation, finance totals and finance permission denial.');

// Exercise the newly delegated hierarchy and distribution on an isolated tenant.
await identity(creator);const toolkitShop=(await q("select public.jf_create_shop('Toolkit acceptance') id"))[0].id;
const toolOwner='aaaa1111-1111-4111-8111-111111111111',toolAdmin='aaaa2222-2222-4222-8222-222222222222',toolAgent='aaaa3333-3333-4333-8333-333333333333';
await db.exec('reset role');for(const [id,label] of [[toolOwner,'Owner'],[toolAdmin,'Admin'],[toolAgent,'Agent']]){await q('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id,label+'@toolkit.test']);await q('insert into public.jf_profiles(id,full_name,email) values($1,$2,$3)',[id,label,label+'@toolkit.test']);await q('insert into auth.sessions values($1,$1)',[id])}
await q('update public.jf_shops set owner_id=$1 where id=$2',[toolOwner,toolkitShop]);
const toolAdminMembership=(await q("insert into public.jf_memberships(shop_id,user_id,role,status,permissions) values($1,$2,'admin','active',$3) returning id",[toolkitShop,toolAdmin,{users:true,assign:true,settings:true,logout:true}]))[0].id;
const toolAgentMembership=(await q("insert into public.jf_memberships(shop_id,user_id,role,status,permissions) values($1,$2,'agent','active',$3) returning id",[toolkitShop,toolAgent,{assign:true,pull:true}]))[0].id;
await identity(toolOwner);await q('select public.jf_save_profile($1,$2)',[toolAdmin,{full_name:'Updated Admin'}]);await q('select public.jf_save_profile($1,$2)',[toolAgent,{full_name:'Updated Agent'}]);await denied('select public.jf_save_profile($1,$2)',[creator,{full_name:'Blocked'}]);
await identity(toolAdmin);await q('select public.jf_save_profile($1,$2)',[toolAgent,{full_name:'Admin edited Agent'}]);await denied('select public.jf_save_profile($1,$2)',[toolOwner,{full_name:'Blocked'}]);await denied('select public.jf_save_profile($1,$2)',[toolAgent,{permissions:{profit:true}}]);
await identity(toolOwner);const tc1=(await q('select public.jf_save_customer($1,null,$2) id',[toolkitShop,{full_name:'Queue One',phone:'01722223331'}]))[0].id;const tc2=(await q('select public.jf_save_customer($1,null,$2) id',[toolkitShop,{full_name:'Queue Two',phone:'01722223332'}]))[0].id;
const tg=(await q('select public.jf_workspace_tools($1,$2,$3) v',[toolkitShop,'save_group',{name:'Sales group',members:[toolAgentMembership]}]))[0].v.id;
await q('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'distribute',{ids:[tc1,tc2],group_id:tg}]);assert.equal((await q('select assigned_membership_id from public.jf_customers where id=$1',[tc1]))[0].assigned_membership_id,toolAgentMembership);
await denied('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'distribute',{ids:[tc1],membership_id:toolAdminMembership}]);
await q('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'distribute',{ids:[tc1,tc2]}]);await q('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'save_settings',{value:{pull_count:1}}]);
await identity(toolAgent);await q('select public.jf_agent_session($1)',['toolkit-device-123456']);await identity(toolOwner);await q('select public.jf_approve_agent($1,true)',[toolAgent]);await identity(toolAgent);
let pull=(await q('select public.jf_workspace_tools($1,$2,$3) v',[toolkitShop,'pull',{}]))[0].v;assert.equal(pull.count,1);assert.equal((await q('select * from public.jf_customers where shop_id=$1',[toolkitShop])).length,1);
await denied('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'save_layout',{page:'dashboard',value:{}}]);await denied('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'distribute',{ids:[tc1]}]);await denied('select public.jf_finance_totals($1)',[toolkitShop]);

await identity(toolOwner);const financeProduct=(await q('select public.jf_save_product($1,null,$2) id',[toolkitShop,{name:'Finance product',sale_price:200,unit_cost:25}]))[0].id;
const financeOrder=(await q('select public.jf_save_order($1,gen_random_uuid(),$2) id',[toolkitShop,{full_name:'Finance buyer',phone:'01722223339',address:'Dhaka',status:'confirmed',delivery_charge:10,items:[{product_id:financeProduct,quantity:1,unit_price:200}]}]))[0].id;
await q('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'save_finance',{order_id:financeOrder,product_cost:100,courier_charge:10,cod_fee:5,packaging_cost:2,return_cost:0,other_cost:3,cod_expected:200,cod_received:150}]);
let ft=(await q('select public.jf_finance_totals($1) v',[toolkitShop]))[0].v;assert.equal(ft.profit,90);assert.equal(ft.cod_pending,0);
await db.exec('reset role');await q("update public.jf_orders set status='delivered' where id=$1",[financeOrder]);await identity(toolOwner);ft=(await q('select public.jf_finance_totals($1) v',[toolkitShop]))[0].v;assert.equal(ft.cod_pending,50);
await identity(toolAdmin);await denied('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'save_finance',{order_id:financeOrder}]);
await identity(toolOwner);await q('select public.jf_manage_account($1,$2,$3)',[toolAgent,'deactivate',{}]);await identity(toolAgent);await denied('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'pull',{}]);
console.log('Toolkit acceptance passed: Owner/Admin delegated hierarchy, no Agent privilege escalation, same-shop group distribution, atomic one-record pull, own-queue RLS and deactivated-session denial.');

{
await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/019_import_notifications.sql',import.meta.url),'utf8'));
await identity(toolOwner);let batch=(await q('select public.jf_save_customer_batch($1,$2) v',[toolkitShop,[{full_name:'Batch one',phone:'01733334441'},{full_name:'Batch two',phone:'01733334442'}]]))[0].v;assert.equal(batch.saved,2);const hundred=Array.from({length:100},(_,i)=>({full_name:'Batch '+i,phone:'017'+String(50000000+i)}));assert.equal((await q('select public.jf_save_customer_batch($1,$2) v',[toolkitShop,hundred]))[0].v.saved,100);await denied('select public.jf_save_customer_batch($1,$2)',[toolkitShop,[...hundred,hundred[0]]]);
await denied('select public.jf_save_customer_batch($1,$2)',[toolkitShop,[{full_name:'Rollback',phone:'01733334443'},{full_name:'Bad',phone:'bad'}]]);assert.equal((await q("select * from public.jf_customers where phone='+8801733334443'")).length,0);
const negativeCustomer=(await q("select id from public.jf_customers where phone='+8801733334441'"))[0].id;
await q('select public.jf_record_followup($1,$2,$3,$4,null,$5)',[toolkitShop,negativeCustomer,'completed','negative','Not interested']);
let feed=(await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v;assert.equal(feed.items.filter(n=>n.kind==='negative_followup').length,1);
await q('select public.jf_record_followup($1,$2,$3,$4,null,$5)',[toolkitShop,negativeCustomer,'completed','negative','Same outcome']);feed=(await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v;assert.equal(feed.items.filter(n=>n.kind==='negative_followup').length,1);
let overview=(await q('select public.jf_phone_courier_overview($1,$2) v',[toolkitShop,'01733334441']))[0].v;assert.equal(overview.providers.length,2);assert.equal(overview.providers.some(p=>p.connected),false);
await q('select public.jf_manage_account($1,$2,$3)',[toolAgent,'activate',{}]);
await db.exec('reset role');await q('update public.jf_orders set assigned_membership_id=$1 where id=$2',[toolAgentMembership,financeOrder]);await q('update public.jf_profiles set email_verified_at=now() where id=$1',[toolOwner]);
await identity(toolOwner);feed=(await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v;assert.ok(feed.items.some(n=>n.kind==='verification'));assert.equal(feed.items.filter(n=>n.kind==='top_performer').length,1);
await identity(creator);await q('select public.jf_platform_layout($1,$2)',['dashboard:all',{items:{a:{order:1}}}]);assert.equal((await q('select public.jf_platform_layout($1) v',['dashboard:all']))[0].v.items.a.order,1);
await identity(toolOwner);await denied('select public.jf_platform_layout($1,$2)',['dashboard:all',{}]);
await identity(outsider);await denied('select public.jf_save_customer_batch($1,$2)',[toolkitShop,[{full_name:'No',phone:'01733334444'}]]);await denied('select public.jf_phone_courier_overview($1,$2)',[toolkitShop,'01733334441']);
console.log('019 passed: 100-row import RPC, atomic rollback, negative/verification/top-performer events, honest disconnected courier overview and tenant denial.');
}

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/020_direct_record_panels.sql',import.meta.url),'utf8'));
await identity(toolOwner);let inlineRows=(await q('select public.jf_workspace_page($1,$2,$3,0) v',[toolkitShop,'customers',{status:'negative'}]))[0].v;assert.equal(inlineRows.total,1);assert.ok(inlineRows.rows[0].latest_note);
const labelCustomer=inlineRows.rows[0].id;await q('select public.jf_workspace_tools($1,$2,$3)',[toolkitShop,'customer_labels',{customer_id:labelCustomer,label:'Interested Again',tag:'Return'}]);inlineRows=(await q('select public.jf_workspace_page($1,$2,$3,0) v',[toolkitShop,'customers',{status:'interested_again',tag:'Return',source:'MANUAL'}]))[0].v;assert.equal(inlineRows.total,1);
inlineRows=(await q('select public.jf_workspace_page($1,$2,$3,0) v',[toolkitShop,'orders',{status:'confirmed',product_id:financeProduct}]))[0].v;assert.equal(inlineRows.total,1);assert.equal(inlineRows.rows[0].id,financeOrder);
await identity(outsider);assert.equal((await q('select public.jf_workspace_page($1,$2,$3,0) v',[toolkitShop,'customers',{status:'all'}]))[0].v.total,0);
console.log('020 passed: full inline panels retain tenant isolation, custom labels/tags/source/product filters and latest notes.');
await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/021_inline_tab_counts.sql',import.meta.url),'utf8'));
await identity(creator);
const counted=(await q("select public.jf_workspace_page($1,'customers','{\"status\":\"unassigned\"}'::jsonb,0) as v",[shop]))[0].v;
assert.equal(counted.counts.unassigned,counted.total);assert.ok(counted.counts.all>=counted.total);assert.equal(counted.counts.assigned+counted.counts.unassigned,counted.counts.all);
const customCounts=(await q("select public.jf_workspace_page($1,'customers','{}'::jsonb,0) as v",[toolkitShop]))[0].v;assert.equal(customCounts.counts.interested_again,1);
const orderCounts=(await q("select public.jf_workspace_page($1,'orders','{\"status\":\"all\"}'::jsonb,0) as v",[shop]))[0].v;
assert.equal(orderCounts.counts.all,orderCounts.total);
const importedRows=(await q("select public.jf_workspace_page($1,'orders','{\"status\":\"imported\"}'::jsonb,0) as v",[shop]))[0].v;assert.equal(importedRows.counts.imported,importedRows.total);assert.ok(importedRows.rows.every(r=>r.is_imported));assert.equal(orderCounts.counts.draft+orderCounts.counts.cancelled+orderCounts.counts.confirmed,orderCounts.total);
await identity(owner2);const isolatedCounts=(await q("select public.jf_workspace_page($1,'customers','{}'::jsonb,0) as v",[shop]))[0].v;assert.equal(isolatedCounts.counts.all,0);
console.log('Inline tab counts passed: all-status totals, selected-list consistency and cross-business RLS isolation.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/022_notification_inbox_actions.sql',import.meta.url),'utf8'));
const inboxNote=(await q("insert into public.jf_notifications(shop_id,kind,title,body) values($1,'order','Inbox acceptance','Body') returning id",[toolkitShop]))[0].id;
await db.query("insert into public.jf_notifications(shop_id,kind,title,body) select $1,'order','Bulk read','Body' from generate_series(1,60)",[toolkitShop]);
await q("update public.jf_notifications set created_at=now()+interval '1 second' where id=$1",[inboxNote]);
await identity(creator);await q("select public.jf_notification_action('read_all',null,$1)",[toolkitShop]);let inbox=(await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v;assert.equal(inbox.unread_count,0);
await q("select public.jf_notification_action('delete',$1,$2)",[inboxNote,toolkitShop]);assert.equal((await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v.items.some(n=>n.id===inboxNote),false);
await db.exec('reset role');assert.equal((await q('select count(*)::int n from public.jf_notification_dismissals where user_id=$1 and notification_id=$2',[creator,inboxNote]))[0].n,1);
await identity(toolOwner);assert.ok((await q('select public.jf_notifications_feed($1) v',[toolkitShop]))[0].v.items.some(n=>n.id===inboxNote));await q("select public.jf_notification_read($1)",[inboxNote]);await q("select public.jf_notification_action('delete',$1,$2)",[inboxNote,toolkitShop]);await identity(outsider);await denied("select public.jf_notification_action('delete',$1,$2)",[inboxNote,toolkitShop]);
await identity(creator);await denied("select public.jf_notification_action('unknown',null,null)");console.log('022 passed: bulk read includes more than 50, dismissals are personal and inaccessible notifications cannot be deleted.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/023_unified_order_lists.sql',import.meta.url),'utf8'));
await db.query("insert into public.jf_order_history(shop_id,customer_id,external_id,details) values($1,$2,'UNIFIED-PENDING','{\"status\":\"Pending\",\"total\":\"200\"}'),($1,$2,'UNIFIED-DELIVERED','{\"status\":\"Delivered\",\"total\":\"300\"}')",[toolkitShop,tc1]);
await identity(creator);const unified=(await q("select public.jf_workspace_page($1,'orders','{}'::jsonb,0) v",[toolkitShop]))[0].v;assert.equal(unified.total,unified.counts.all);assert.ok(unified.rows.some(r=>r.order_number==='UNIFIED-PENDING'));assert.ok(unified.rows.some(r=>r.id===financeOrder));
const pendingUnified=(await q("select public.jf_workspace_page($1,'orders','{\"status\":\"draft\"}'::jsonb,0) v",[toolkitShop]))[0].v;assert.equal(pendingUnified.total,pendingUnified.counts.draft);assert.ok(pendingUnified.rows.some(r=>r.order_number==='UNIFIED-PENDING'));
const deliveredUnified=(await q("select public.jf_workspace_page($1,'orders','{\"status\":\"delivered\"}'::jsonb,0) v",[toolkitShop]))[0].v;assert.equal(deliveredUnified.total,deliveredUnified.counts.delivered);assert.ok(deliveredUnified.rows.some(r=>r.order_number==='UNIFIED-DELIVERED'));
await identity(outsider);assert.equal((await q("select public.jf_workspace_page($1,'orders','{}'::jsonb,0) v",[toolkitShop]))[0].v.total,0);console.log('023 passed: All contains live + imported history, status counts match lists and tenant isolation remains enforced.');

await db.exec('reset role');await db.exec(await readFile(new URL('./supabase/migrations/024_agent_report_dashboard.sql',import.meta.url),'utf8'));
await identity(creator);let report=(await q('select public.jf_agent_report($1,$2) v',[toolkitShop,toolAgentMembership]))[0].v;assert.equal(report.agents.length,1);assert.equal(report.agents[0].id,toolAgentMembership);assert.equal(typeof report.agents[0].pending,'number');assert.equal(report.agents[0].name,'Admin edited Agent');assert.ok(Array.isArray(report.activity));
const reportCounts=(await q("select public.jf_workspace_page($1,'customers',$2,0) v",[toolkitShop,{agent_id:toolAgentMembership,status:'pending'}]))[0].v;assert.equal(report.agents[0].pending,reportCounts.total);
await identity(toolOwner);assert.equal((await q('select public.jf_agent_report($1,$2) v',[toolkitShop,toolAgentMembership]))[0].v.agents.length,1);
await identity(toolAdmin);assert.equal((await q('select public.jf_agent_report($1,$2) v',[toolkitShop,toolAgentMembership]))[0].v.agents.length,1);
await identity(toolAgent);await denied('select public.jf_agent_report($1,$2)',[toolkitShop,toolAgentMembership]);await identity(owner2);await denied('select public.jf_agent_report($1,$2)',[toolkitShop,toolAgentMembership]);
await identity(creator);await denied('select public.jf_agent_report($1,$2)',[shop2,toolAgentMembership]);console.log('024 passed: Creator/Owner/authorized Admin views, Agent/other-business denial, matching workload counts and recorded activity.');

await db.close();console.log('Operational checks passed: product CRUD/activation/cost privacy, normalized phone upserts, one follow-up, notes/history, callback validation, server-side filtering and denied Agent/anonymous writes.');
console.log('Database checks passed: all migrations execute; Creator/Owner/Admin/Agent hierarchy, same-shop profile reads, tenant foreign keys, duplicate phone/follow-up constraints, Agent data blockade, Admin finance permission, inactive rejection and anonymous denial.');
