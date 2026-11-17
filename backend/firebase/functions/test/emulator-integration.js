'use strict';
const assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
initializeApp({projectId:'demo-zombie-bloom'});
const db=getFirestore();
let checks=0;
const check=(condition,message)=>{checks++;assert.ok(condition,message);console.log('PASS:',message);};
async function signup(tag){
 const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${tag}-${Date.now()}@example.test`,password:'SafeTestPassword17',returnSecureToken:true})});
 assert.equal(r.status,200);return r.json();
}
async function api(user,action,data={}){
 const r=await fetch('http://127.0.0.1:5001/demo-zombie-bloom/us-central1/account16Api',{method:'POST',headers:{'Content-Type':'application/json',...(user?{'Authorization':`Bearer ${user.idToken}`}:{})},body:JSON.stringify({action,data})});
 return {status:r.status,body:await r.json()};
}
(async()=>{
 const a=await signup('alpha'),b=await signup('beta');
 check((await api(null,'profile')).status===401,'service rejects unauthenticated requests');
 check((await api(a,'profile')).body.profile.balance===0,'new account receives no invented currency');
 const now=Date.now();const account=`accounts16/${a.localId}`;
 await db.doc(account).set({balance:0,owned:[],equipped:{},active_seconds:600,longest_seconds:600,last_sync_ms:now,active_match:'real-run',last_reward_ms:0});
 await db.doc(`${account}/matches/real-run`).set({wave:0,mode:'endless',started_ms:now-620000,last_reward_ms:now-620000,active_baseline:0});
 const credits=await Promise.all(Array.from({length:10},()=>api(a,'horde',{match_id:'real-run',wave:1})));
 check(credits.every(r=>r.status===200&&r.body.profile.balance===100),'ten concurrent retries grant exactly 100 through Firestore transaction');
 check((await db.collection(`${account}/ledger`).get()).size===1,'one ledger entry is stored for repeated victory');
 check((await api(b,'horde',{match_id:'real-run',wave:1,uid:a.localId})).status!==200,'another account cannot claim the first account match');
 check((await api(a,'horde',{match_id:'real-run',wave:3})).status===409,'sequence gaps are rejected');
 await db.doc(account).update({balance:600});
 const buys=await Promise.all([api(a,'purchase',{item_id:'COS-ENG-01',operation_id:'buy-a',price:0}),api(a,'purchase',{item_id:'COS-ENG-02',operation_id:'buy-b'})]);
 check(buys.filter(r=>r.status===200).length===1,'concurrent purchases do not overspend');
 const p=(await api(a,'profile')).body.profile;
 check(p.balance>=0&&p.owned.length===1,'debit and ownership are committed together');
 const cls=p.owned[0];
 check((await api(a,'equip',{class_id:'scout',slot:'head',item_id:cls})).status===403,'wrong-class equip is rejected by backend');
 check((await api(a,'equip',{class_id:'engineer',slot:'head',item_id:cls})).status===200,'owned item can be equipped in correct class');
 const rest=`http://127.0.0.1:8080/v1/projects/demo-zombie-bloom/databases/(default)/documents/accounts16/${a.localId}`;
 const direct=await fetch(rest,{method:'PATCH',headers:{Authorization:`Bearer ${a.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({fields:{balance:{integerValue:'999999'}}})});
 check(direct.status===403,'Firestore rules reject direct wallet writes even by owner');
 const leak=await fetch(rest,{headers:{Authorization:`Bearer ${b.idToken}`}});
 check(leak.status===403,'another authenticated player cannot read private wallet document');
 const bob=(await api(b,'profile',{uid:a.localId})).body.profile;
 check(bob.balance===0&&bob.owned.length===0,'profile response remains bound to authenticated UID');
 console.log(`ACCOUNT16 EMULATOR RESULT: ${checks} checks, 0 failures`);
})().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1);});
