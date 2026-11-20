'use strict';
// REST-only adversarial tests: no paid Functions or Admin SDK dependency.
const assert=require('node:assert/strict');
const BASE='http://127.0.0.1:8080/v1/projects/demo-zombie-bloom/databases/(default)/documents';
const PREFIX='projects/demo-zombie-bloom/databases/(default)/documents/';
let checks=0;
function check(ok,message){checks++;assert.ok(ok,message);console.log('PASS:',message);}
function enc(v){if(v&&v.timestampValue)return v;if(Array.isArray(v))return {arrayValue:{values:v.map(enc)}};if(v&&typeof v==='object')return {mapValue:{fields:Object.fromEntries(Object.entries(v).filter(([,x])=>x!==undefined).map(([k,x])=>[k,enc(x)]))}};return typeof v==='number'?{integerValue:String(v)}:{stringValue:v};}
function dec(v){if(v.mapValue)return Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,x])=>[k,dec(x)]));if(v.arrayValue)return(v.arrayValue.values||[]).map(dec);if(v.timestampValue)return v;return v.integerValue!==undefined?Number(v.integerValue):v.stringValue;}
async function call(user,suffix,method='GET',body){const r=await fetch(BASE+suffix,{method,headers:{'Content-Type':'application/json',...(user?{Authorization:'Bearer '+user.idToken}:{})},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,data:await r.json()};}
async function signup(tag){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:tag+Date.now()+'@example.test',password:'safe-test-password',returnSecureToken:true})});return r.json();}
const epoch={timestampValue:'1970-01-01T00:00:00Z'};
const ago=(s)=>({timestampValue:new Date(Date.now()-s*1000).toISOString()});
const stamp=(fieldPath)=>({fieldPath,setToServerValue:'REQUEST_TIME'});
function blank(){return {balance:0,owned:[],equipped:Object.fromEntries(['engineer','scout','shooter'].map(c=>[c,{head:'',outfit:'',backpack:'',effect:''}])),active_seconds:0,longest_seconds:0,created_at:epoch,updated_at:epoch,last_reward_at:epoch,reward_day:epoch,reward_count:0,active_match:'',action:'init',item_id:'',session_id:''};}
function write(p,d,remote,stamps=[]){return {update:{name:PREFIX+p,fields:enc(d).mapValue.fields},currentDocument:remote?{updateTime:remote.updateTime}:{exists:false},...(stamps.length?{updateTransforms:stamps.map(stamp)}:{})};}
async function commit(u,writes){return call(u,':commit','POST',{writes});}
async function get(u,p){const r=await call(u,'/'+p);assert.equal(r.status,200,JSON.stringify(r));return {doc:r.data,value:dec({mapValue:{fields:r.data.fields}})};}
const admin={idToken:'owner'};
async function seed(p,d){const r=await call(admin,'/'+p,'PATCH',{fields:enc(d).mapValue.fields});assert.equal(r.status,200,JSON.stringify(r));}
(async()=>{
 const a=await signup('spark-a'),b=await signup('spark-b');const p='community16/'+a.localId;const m=p+'/matches/run_1';
 check((await commit(a,[write(p,blank(),null,['created_at','updated_at'])])).status===200,'zero-balance wallet initializes with server timestamps');
 check((await call(null,'/'+p)).status===403,'unauthenticated private read denied');
 check((await call(b,'/'+p)).status===403,'another user cannot read wallet');
 check((await call(a,':runQuery','POST',{structuredQuery:{from:[{collectionId:'community16'}],limit:25}})).status===403,'wallet collection listing denied');
 let r=await get(a,p);let initial=r.value;
 async function denied(label,patch){const s=await get(a,p);const w={...s.value,...patch};check((await commit(a,[write(p,w,s.doc,['updated_at'])])).status===403,label);}
 await denied('arbitrary balance inflation denied',{balance:999999,action:'equip'});
 await denied('negative balance denied',{balance:-1});
 await denied('undefined privilege field denied',{admin:true});
 await denied('required field cannot be omitted',{owned:undefined});
 await denied('wrong field type denied',{balance:'100'});
 await denied('oversized metadata denied',{item_id:'a'.repeat(20000)});
 await denied('created timestamp cannot be rewritten',{created_at:ago(999999)});
 await denied('unowned equipment denied',{action:'equip',equipped:{...initial.equipped,engineer:{head:'COS-ENG-01',outfit:'',backpack:'',effect:''}}});
 await denied('unknown inventory entry denied',{action:'equip',owned:['hacked']});
 check((await call(a,'/'+p,'DELETE')).status===403,'wallet cannot be deleted to reset limits');
 check((await commit(b,[write('community16/'+a.localId,blank(),null,['created_at','updated_at'])])).status===403,'ownership hijacking denied');
 const match={mode:'endless',baseline:0,wave:0,created_at:epoch,rewarded_at:epoch};r=await get(a,p);let start={...r.value,action:'start',active_match:'run_1'};
 check((await commit(a,[write(p,start,r.doc,['updated_at']),write(m,match,null,['created_at','rewarded_at'])])).status===200,'match registration is atomic with wallet');
 check((await commit(a,[write(p+'/matches/orphan',match,null,['created_at','rewarded_at'])])).status===403,'orphan match creation denied');
 async function reward(wave=1,omit=false){const w=await get(a,p),mt=await get(a,m);let target={...w.value,action:'horde',balance:w.value.balance+100,reward_count:1};const writes=[write(p,target,w.doc,['updated_at','last_reward_at','reward_day'])];if(!omit)writes.push(write(m,{...mt.value,wave},mt.doc,['rewarded_at']));return commit(a,writes);}
 check((await reward()).status===403,'premature victory cannot mint coins');
 await seed(m,{...match,created_at:ago(1000),rewarded_at:ago(1000)});
 check((await reward(1,true)).status===403,'reward without advancing its match is denied');
 check((await reward(3)).status===403,'skipping horde sequence denied');
 const rewards=await Promise.all(Array.from({length:10},()=>reward()));
 check(rewards.filter(x=>x.status===200).length===1,'ten concurrent victory writes credit only once');
 r=await get(a,p);check(r.value.balance===100,'single horde pays exactly 100');
 check((await reward()).status!==200,'replaying completed horde cannot mint again');
 await seed(p,{...r.value,balance:600});
 async function buy(id,cost){const w=await get(a,p);return commit(a,[write(p,{...w.value,action:'purchase',item_id:id,balance:w.value.balance-cost,owned:[...w.value.owned,id]},w.doc,['updated_at'])]);}
 check((await buy('COS-ENG-01',0)).status===403,'client price spoofing denied');
 check((await buy('COS-TITAN-01',0)).status===403,'Titan trophy cannot be bought');
 const buys=await Promise.all([buy('COS-ENG-01',300),buy('COS-ENG-02',550)]);
 check(buys.filter(x=>x.status===200).length===1,'concurrent purchases do not overspend');
 r=await get(a,p);check(r.value.balance>=0&&r.value.owned.length===1,'ownership and debit commit together');
 const item=r.value.owned[0];const price=item==='COS-ENG-01'?300:550;
 check((await buy(item,price)).status===403,'duplicate purchase cannot debit twice');
 const eq=structuredClone(r.value.equipped);eq.engineer.head=item;
 check((await commit(a,[write(p,{...r.value,action:'equip',item_id:'',equipped:eq},r.doc,['updated_at'])])).status===200,'owned cosmetic equips in its class');
 r=await get(a,p);eq.scout.head=item;
 await denied('wrong-class equipment denied',{action:'equip',equipped:eq});
 r=await get(a,p);await seed(p,{...r.value,last_reward_at:ago(1000),reward_day:ago(0),reward_count:150});await seed(m,{...match,created_at:ago(1000),rewarded_at:ago(1000)});
 check((await reward()).status===403,'daily reward limit cannot be reset by client');
 r=await get(a,p);check((await commit(a,[write(p,{...r.value,action:'sync',session_id:'abc',active_seconds:999999,longest_seconds:999999},r.doc,['updated_at']),write(p+'/sessions/abc',{seconds:999999},null)])).status===403,'invented hours beyond server-observed account age denied');
 await seed(p,{...r.value,created_at:ago(200)});r=await get(a,p);
 check((await commit(a,[write(p,{...r.value,action:'sync',session_id:'abc',active_seconds:120,longest_seconds:120},r.doc,['updated_at']),write(p+'/sessions/abc',{seconds:120},null)])).status===200,'session hours synchronize atomically');
 check((await call(b,'/'+p+'/sessions/abc')).status===403,'private session documents cannot leak');
 check((await commit(a,[write(p+'/sessions/orphan',{seconds:1},null)])).status===403,'orphan time counter denied');
 const player='players/'+a.localId;
 check((await commit(a,[write(player,{nickname:'Player',kills:3},null)])).status===200,'older client can still create its ranking profile');
 let ranking=await get(a,player);
 check((await commit(a,[write(player,{...ranking.value,active_seconds:121},ranking.doc)])).status===403,'published time must match the synchronized total');
 check((await commit(a,[write(player,{...ranking.value,active_seconds:120},ranking.doc)])).status===200,'owner publishes synchronized time');
 ranking=await get(a,player);
 check((await commit(a,[write(player,{...ranking.value,kills:4},ranking.doc)])).status===200,'score updates preserve published playtime');
 ranking=await get(a,player);
 check((await commit(a,[write(player,{nickname:'Player',kills:4},ranking.doc)])).status===403,'publishing profile cannot erase the synchronized total');
 const byTime=await call(b,':runQuery','POST',{structuredQuery:{from:[{collectionId:'players'}],orderBy:[{field:{fieldPath:'active_seconds'},direction:'DESCENDING'}],limit:25}});
 check(byTime.status===200&&byTime.data.some(x=>x.document?.name===PREFIX+player&&x.document.fields.active_seconds.integerValue==='120'),'ranking exposes synchronized seconds to signed-in readers');
 r=await get(a,p);check((await commit(a,[write(p,{...r.value,action:'titan',item_id:'COS-TITAN-01',owned:[...r.value.owned,'COS-TITAN-01']},r.doc,['updated_at'])])).status===200,'eligible Titan entitlement grants without currency');
 r=await get(a,p);check(r.value.owned.includes('COS-TITAN-01')&&r.value.balance>=0,'Titan trophy persists independently of purchases');
 console.log('SPARK ECONOMY RESULT: '+checks+' checks, 0 failures');
})().catch(e=>{console.error(e);process.exitCode=1;});
