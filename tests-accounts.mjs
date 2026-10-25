import assert from 'node:assert/strict';
import {createHandler} from './api/manage.mjs';
import {configuration} from './server/account-service.mjs';
const actor='11111111-1111-4111-8111-111111111111',shop='22222222-2222-4222-8222-222222222222',invited='33333333-3333-4333-8333-333333333333';
const env={SUPABASE_URL:'https://project.supabase.co',SUPABASE_PUBLISHABLE_KEY:'sb_publishable_test',SUPABASE_SECRET_KEY:'sb_secret_test',JIOFLOW_APP_ORIGIN:'https://app.example'};
let mode='ok',calls=[];
const fetcher=async(url,o)=>{calls.push({url,o});const response=(d,status=200)=>({ok:status<400,status,json:async()=>d});if(url.endsWith('/auth/v1/user'))return response({id:actor,email_confirmed_at:mode==='unverified'?null:'2026-01-01'});if(url.includes('/jf_profiles?'))return response([{id:actor,active:mode!=='inactive'}]);if(url.endsWith('jf_prepare_invitation'))return mode==='denied'?response({code:'42501'},403):response('request-id');if(url.includes('/invite?'))return mode==='emailfail'?response({error_code:'email_address_not_authorized'},400):response({id:invited});if(url.endsWith('jf_finish_invitation'))return mode==='conflict'?response({code:'23505'},409):response(invited);if(url.endsWith('jf_create_shop'))return response(shop);if(url.includes('/admin/users/'))return mode==='passwordfail'?response({code:'oops'},400):response({id:invited});throw new Error('Unexpected route '+url)};
const handler=createHandler({env,fetcher});
async function invoke(body={},headers={},method='POST'){const req={method,body,headers:{origin:env.JIOFLOW_APP_ORIGIN,'content-type':'application/json',authorization:'Bearer test-user-token',...headers}},res={headers:{},setHeader(k,v){this.headers[k]=v},status(n){this.statusCode=n;return this},json(d){this.data=d;return this}};await handler(req,res);return res}
const input={action:'invite_account',shop_id:shop,role:'admin',name:'A Person',email:'PERSON@EXAMPLE.COM',password:'long-password-1234'};
assert.equal((await invoke({}, {},'GET')).statusCode,405);
for(const headers of [{origin:'https://evil.example'},{authorization:''},{'content-type':'text/plain'}])assert.ok((await invoke(input,headers)).statusCode>=400);
assert.equal(calls.length,0);
assert.equal((await invoke({...input,role:'creator'})).statusCode,400);assert.equal(calls.some(x=>x.url.includes('/invite?')),false);calls=[];
for(mode of ['unverified','inactive','denied']){assert.equal((await invoke(input)).statusCode,403);assert.equal(calls.some(x=>x.url.includes('/invite?')),false);calls=[]}
mode='ok';const ok=await invoke(input);assert.equal(ok.statusCode,200);assert.equal(ok.data.user_id,invited);const invite=calls.find(x=>x.url.includes('/invite?'));assert.equal(invite.o.headers.apikey,'sb_secret_test');assert.equal(invite.o.headers.Authorization,undefined);assert.equal(JSON.parse(invite.o.body).email,'person@example.com');assert.equal(JSON.parse(invite.o.body).data.platform_role,undefined);assert.ok(calls.filter(x=>x.url.includes('/rest/')).every(x=>x.o.headers.Authorization==='Bearer test-user-token'));assert.equal(JSON.stringify(ok.data).includes('sb_secret_'),false);
mode='emailfail';calls=[];assert.equal((await invoke(input)).statusCode,400);assert.equal(calls.some(x=>x.url.endsWith('jf_finish_invitation')),false);
mode='conflict';calls=[];assert.equal((await invoke(input)).statusCode,409);assert.equal(calls.some(x=>x.url.includes('/admin/users/')),false);
mode='passwordfail';const partial=await invoke(input);assert.equal(partial.statusCode,200);assert.ok(partial.data.warning.includes('not saved'));
mode='ok';assert.equal((await invoke({action:'create_shop',name:'Business'})).data.shop_id,shop);
assert.throws(()=>configuration({...env,SUPABASE_SECRET_KEY:env.SUPABASE_PUBLISHABLE_KEY}),/server credential/);
const broken=createHandler({env:{}});const result={setHeader(){},status(n){this.code=n;return this},json(d){this.data=d}};await broken({method:'POST',headers:{},body:{}},result);assert.equal(result.code,503);assert.equal(JSON.stringify(result.data).includes('undefined'),false);
console.log('Account API tests passed: request validation, origin, verified identity, inactive rejection, RPC authorization, mail failure, role spoofing, no secret exposure, conflict handling and password fallback.');
