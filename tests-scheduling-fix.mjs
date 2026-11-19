import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {uniqueStatusDefinitions,loadStatusDefinitions} from './custom-statuses.mjs';
import {createCallbackReminders} from './callback-reminders.mjs';

const values=uniqueStatusDefinitions([
 {id:'s1',name:'Schedule',kind:'processing',active:false},
 {id:'s2',name:' schedule ',kind:'processing',active:true},
 {id:'s3',name:'SCHEDULE',kind:'schedule',active:true},
 {id:'x',name:'Confirm',kind:'confirm',active:true}
]);
assert.equal(values.length,2);
assert.equal(values.filter(v=>v.name==='Schedule').length,1);
assert.equal(values[0].kind,'schedule');
assert.equal(values[0].days,0);
assert.equal(values[0].id,'s2');
const defsClient={rpc:async()=>({statuses:[{name:'Schedule',active:true},{name:'SCHEDULE',active:true}]})};
assert.equal((await loadStatusDefinitions(defsClient,'shop')).length,1);

const events=new Map(),due=[];
let currentPopup=null,beeps=0,notifications=0,scheduled=null,firstDelay=0;
const fakeAudio={state:'suspended',currentTime:3,destination:{},resume(){this.state='running';return Promise.resolve()},createOscillator(){return{frequency:{value:0},connect(){},start(){beeps++},stop(){}}},createGain(){return{gain:{setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}},connect(){}}}};
const win={AudioContext:class{constructor(){return fakeAudio}},Notification:class{static permission='granted';constructor(){notifications++}close(){}},focus(){},addEventListener(name,fn){events.set('window:'+name,fn)}};
const document={defaultView:win,visibilityState:'visible',addEventListener(name,fn){events.set(name,fn)},createElement(){const controls=new Map();return{innerHTML:'',className:'',setAttribute(){},remove(){if(currentPopup===this)currentPopup=null},querySelector(selector){if(!controls.has(selector))controls.set(selector,{onclick:null});return controls.get(selector)}}},body:{append(el){currentPopup=el}}};
const calls=[],client={rpc:async(name,payload)=>{calls.push({name,payload});if(name==='jf_callback_reminders')return{due:[...due],server_time:'2026-11-19T13:00:00Z',next_at:'2026-11-19T13:00:04Z'};return true}};
const scheduler=createCallbackReminders({client,document,navigate(){},setTimer(fn,delay){scheduled=fn;firstDelay=delay;return 1},clearTimer(){scheduled=null}});
const flush=()=>new Promise(r=>setTimeout(r,0));
scheduler.setScope({enabled:true,userId:'agent',shopId:'shop'});
await flush();
assert.equal(firstDelay,4000,'poll timed to server callback time');
assert.equal(currentPopup,null);
due.push({id:'alarm1',full_name:'Customer',phone:'000',callback_at:'2026-11-19T13:00:04Z'});
await scheduler.refresh();
assert.ok(currentPopup,'due callback displays a popup');
assert.equal(beeps,0,'audio not marked played while browser blocks it');
assert.equal(notifications,1,'granted browser notification appears');
events.get('pointerdown')();
await flush();
assert.equal(beeps,3,'audio plays on the next real browser gesture');
events.get('pointerdown')();
await flush();
assert.equal(beeps,3,'same callback must not repeat alarm');
assert.equal(notifications,1,'same callback must not duplicate notification');
currentPopup.querySelector('[data-callback-close]').onclick();
await flush();
assert.ok(calls.some(x=>x.name==='jf_callback_popup_ack'));
scheduler.stop();
assert.equal(currentPopup,null);

const online=readFileSync(new URL('./online.js',import.meta.url),'utf8');
const heartbeat=online.slice(online.indexOf('async function checkSession()'),online.indexOf("if(typeof window!=='undefined'){window.setInterval",online.indexOf('async function checkSession()')));
assert.equal(heartbeat.includes('workspaceSync152.observe('),false,'heartbeat should never re-render the workspace when data changes');
assert.equal(heartbeat.includes('render();else refreshNotificationBar()'),false,'approval updates should refresh only the inbox');
assert.ok(online.includes('window.setInterval'),'security and approval heartbeat remains active');
const status=readFileSync(new URL('./followup-status.mjs',import.meta.url),'utf8');
assert.ok(status.includes('Choose a future callback date and time.'));
console.log('Scheduling fix checks passed: duplicate Schedule removed, sound retries after unlock, desktop notification once, due polling, acknowledgement, security heartbeat retained without automatic page rerender, future time validation.');
