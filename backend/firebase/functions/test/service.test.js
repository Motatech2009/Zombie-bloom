'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {operate,initial}=require('../service');
class Store{
 constructor(){this.docs=new Map();this.tail=Promise.resolve();}
 call(uid,action,data,now){const next=this.tail.then(async()=>{
  const staged=new Map();let wrote=false;
  const tx={get:async p=>{assert.equal(wrote,false,'transaction reads precede writes');return this.docs.has(p)?structuredClone(this.docs.get(p)):null;},set:(p,d)=>{wrote=true;staged.set(p,structuredClone(d));}};
  const value=await operate(tx,uid,action,data,now);for(const [k,v] of staged)this.docs.set(k,v);return value;
 });this.tail=next.catch(()=>{});return next;}
}
test('session replay and concurrent devices cannot inflate time',async()=>{
 const s=new Store(),start=1000000000;
 await s.call('one','sync',{sessions:{s1:0}},start);
 let p=await s.call('one','sync',{sessions:{s1:120}},start+120000);
 assert.equal(p.profile.active_seconds,120);
 p=await s.call('one','sync',{sessions:{s1:120}},start+120000);assert.equal(p.profile.active_seconds,120);
 p=await s.call('one','sync',{sessions:{s2:120}},start+120000);assert.equal(p.profile.active_seconds,120);
 p=await s.call('one','sync',{sessions:{s1:240}},start+240000);assert.equal(p.profile.active_seconds,240);
});
test('one horde earns exactly 100 across ten replays; no arbitrary sequence',async()=>{
 const s=new Store(),start=1000000000;
 await s.call('one','sync',{sessions:{s1:0}},start);
 await s.call('one','start',{match_id:'run',mode:'endless',baseline:0},start);
 await assert.rejects(()=>s.call('one','horde',{match_id:'run',wave:1},start+1000));
 for(let i=1;i<=5;i++)await s.call('one','sync',{sessions:{s1:i*120}},start+i*120000);
 for(let i=0;i<10;i++)assert.equal((await s.call('one','horde',{match_id:'run',wave:1},start+610000)).profile.balance,100);
 await assert.rejects(()=>s.call('one','horde',{match_id:'run',wave:3},start+2000000));
 assert.equal((await s.call('two','profile',{},start)).profile.balance,0);
});
test('concurrent purchases spend only available balance and use server catalog',async()=>{
 const s=new Store();s.docs.set('accounts16/one',{...initial(),balance:600});
 const responses=await Promise.allSettled([s.call('one','purchase',{item_id:'COS-ENG-01',operation_id:'a',price:0},1e9),s.call('one','purchase',{item_id:'COS-ENG-02',operation_id:'b'},1e9)]);
 assert.equal(responses.filter(r=>r.status==='fulfilled').length,1);
 let p=await s.call('one','purchase',{item_id:'COS-ENG-01',operation_id:'a'},1e9);assert.equal(p.profile.balance,300);assert.deepEqual(p.profile.owned,['COS-ENG-01']);
 await assert.rejects(()=>s.call('one','purchase',{item_id:'COS-ENG-02',operation_id:'a'},1e9));
 await assert.rejects(()=>s.call('one','equip',{class_id:'scout',slot:'head',item_id:'COS-ENG-01'},1e9));
 p=await s.call('one','equip',{class_id:'engineer',slot:'head',item_id:'COS-ENG-01'},1e9);assert.equal(p.profile.equipped.engineer.head,'COS-ENG-01');
 p=await s.call('one','equip',{class_id:'engineer',slot:'head',item_id:''},1e9);assert.equal(p.profile.equipped.engineer.head,'');
});
test('reject malformed requests, fake items, unauthorized fields',async()=>{
 const s=new Store();
 for(const payload of [{match_id:'a/b',mode:'endless',baseline:0},{match_id:'ok',mode:'fake',baseline:0},{match_id:'ok',mode:'endless',baseline:-1}])await assert.rejects(()=>s.call('one','start',payload,1e9));
 await assert.rejects(()=>s.call('one','sync',{sessions:{x:-1}},1e9));
 await assert.rejects(()=>s.call('one','purchase',{item_id:'fake',operation_id:'x'},1e9));
});
test('all 21 catalog items buy, equip and persist without gameplay fields',async()=>{
 const s=new Store();const catalog=require('../catalog.json');assert.equal(catalog.cosmetics.filter(item=>!item.unlock).length,21);
 s.docs.set('accounts16/one',{...initial(),balance:30000});
 let spent=0;
 for(const item of catalog.cosmetics.filter(item=>!item.unlock)){
  const p=await s.call('one','purchase',{item_id:item.id,operation_id:item.id},1e9);spent+=item.price;assert.equal(p.profile.balance,30000-spent);
  const cls=item.class_id==='all'?'engineer':item.class_id;
  const e=await s.call('one','equip',{class_id:cls,slot:item.slot,item_id:item.id},1e9);assert.equal(e.profile.equipped[cls][item.slot],item.id);
 }
 assert.equal((await s.call('one','profile',{},1e9)).profile.owned.length,21);
});

test('registration distinguishes new offline baseline from reconnect without advancing the server wave',async()=>{
 const s=new Store(),start=1000000000;
 let p=await s.call('one','start',{match_id:'saved',mode:'endless',baseline:5},start);
 assert.equal(p.new_registration,true);assert.equal(p.confirmed_wave,5);
 p=await s.call('one','start',{match_id:'saved',mode:'endless',baseline:8},start+60000);
 assert.equal(p.new_registration,false);assert.equal(p.confirmed_wave,5);
 await assert.rejects(()=>s.call('one','horde',{match_id:'saved',wave:5},start+600000));
});

test('Titan trophy is exclusive, transactional, idempotent and has no coin grant',async()=>{
 const s=new Store(),t=1e9,payload={match_id:'run',encounter_id:'a'.repeat(64)};
 s.docs.set('accounts16/one',{...initial(),balance:30000});
 await assert.rejects(()=>s.call('one','purchase',{item_id:'COS-TITAN-01',operation_id:'fake_buy'},t));
 await assert.rejects(()=>s.call('one','titan',payload,t));
 await s.call('one','start',{match_id:'run',mode:'endless',baseline:0},t);
 await assert.rejects(()=>s.call('one','titan',payload,t+1000));
 await s.call('one','sync',{sessions:{s1:120}},t+120000);
 const grants=await Promise.all(Array.from({length:10},()=>s.call('one','titan',payload,t+120000)));
 assert.equal(grants.filter(x=>!x.duplicate).length,1);
 const p=(await s.call('one','profile',{},t+120000)).profile;
 assert.equal(p.balance,30000);assert.deepEqual(p.owned,['COS-TITAN-01']);
 assert.equal((await s.call('two','profile',{},t)).profile.owned.length,0);
 for(const class_id of ['engineer','scout','shooter'])assert.equal((await s.call('one','equip',{class_id,slot:'head',item_id:'COS-TITAN-01'},t+120000)).profile.equipped[class_id].head,'COS-TITAN-01');
 await assert.rejects(()=>s.call('one','titan',{...payload,encounter_id:'../wrong'},t+120000));
});
