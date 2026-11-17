'use strict';
const catalog = require('./catalog.json');
const classes = ['engineer', 'scout', 'shooter'];
const slots = ['head', 'outfit', 'backpack', 'effect'];
const fail = (message, status=400) => { const e = new Error(message); e.status = status; throw e; };
const integer = (v, low, high) => Number.isSafeInteger(v) && v >= low && v <= high;
const id = v => typeof v === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(v);
const initial = () => ({balance:0,owned:[],equipped:{},active_seconds:0,longest_seconds:0,last_sync_ms:0,last_reward_ms:0,active_match:'',daily_rewards:0,reward_day:''});
const publicProfile = a => ({balance:a.balance,owned:a.owned,equipped:a.equipped,active_seconds:a.active_seconds,longest_seconds:a.longest_seconds});
/** Atomic store contract: get(path), set(path,data); reads precede writes. */
async function operate(tx, uid, action, data, now) {
  if (!id(uid) || !data || Array.isArray(data) || typeof data !== 'object') fail('Pedido inválido.');
  const path = `accounts16/${uid}`;
  const a = {...initial(), ...(await tx.get(path) || {})};
  if (action === 'profile') return {profile:publicProfile(a)};
  if (action === 'sync') {
    if (!data.sessions || typeof data.sessions !== 'object' || Array.isArray(data.sessions) || Object.keys(data.sessions).length > 16) fail('Lote de sessões inválido.');
    const reads = [];
    for (const [session, seconds] of Object.entries(data.sessions)) {
      if (!id(session) || !integer(seconds,0,604800)) fail('Sessão inválida.');
      const sp = `${path}/sessions/${session}`;
      reads.push({sp,session,seconds,old: await tx.get(sp) || {seconds:0}});
    }
    let budget = Math.max(0, Math.min(604800, (a.time_credit_seconds||0)+Math.floor((now-(a.last_sync_ms || now))/1000)));
    let accepted = 0;
    for (const r of reads) {
      const delta = Math.max(0,r.seconds-r.old.seconds);
      const add = Math.min(budget,delta); budget-=add; accepted+=add;
      tx.set(r.sp,{seconds:Math.max(r.seconds,r.old.seconds),updated_ms:now,started_ms:r.old.started_ms||now,accepted_seconds:(r.old.accepted_seconds||0)+add});
      // Local session is a community metric, capped by server-observed lifetime.
      a.longest_seconds = Math.max(a.longest_seconds,(r.old.accepted_seconds||0)+add);
    }
    a.time_credit_seconds=budget; a.active_seconds+=accepted; a.last_sync_ms=Math.max(now,a.last_sync_ms);
    tx.set(path,a);
    return {profile:publicProfile(a),ack_sessions:reads.map(r=>r.session)};
  }
  if (action === 'start') {
    if (!id(data.match_id) || !['campaign','endless','rescue'].includes(data.mode) || !integer(data.baseline,0,1000000)) fail('Partida inválida.');
    const mp = `${path}/matches/${data.match_id}`;
    const match = await tx.get(mp);
    if (match) {
      if(a.active_match!==data.match_id){
        if(a.last_start_ms&&now-a.last_start_ms<60000)fail('Aguarde antes de reativar outra partida.',429);
        a.active_match=data.match_id;a.last_start_ms=now;tx.set(path,a);
      }
      return {profile:publicProfile(a),registered:true,confirmed_wave:match.wave,new_registration:false};
    }
    if (a.last_start_ms && now-a.last_start_ms<60000) fail('Aguarde antes de registrar outra partida.',429);
    a.active_match=data.match_id; a.last_start_ms=now; if(!a.last_sync_ms)a.last_sync_ms=now;
    tx.set(mp,{wave:data.baseline,mode:data.mode,started_ms:now,last_reward_ms:now,active_baseline:a.active_seconds});
    tx.set(path,a); return {profile:publicProfile(a),registered:true,confirmed_wave:data.baseline,new_registration:true};
  }
  if (action === 'horde') {
    if (!id(data.match_id) || !integer(data.wave,1,1000000)) fail('Horda inválida.');
    const mp=`${path}/matches/${data.match_id}`;
    const ledger=`${path}/ledger/horde_${data.match_id}_${data.wave}`;
    const [match, existing]=await Promise.all([tx.get(mp),tx.get(ledger)]);
    if (existing) return {profile:publicProfile(a),duplicate:true};
    if (!match || a.active_match!==data.match_id || data.wave!==match.wave+1) fail('Sequência de horda não confirmada.',409);
    const prep = match.mode==='rescue' ? 60 : data.wave<=2?600:data.wave===3?480:data.wave===4?360:data.wave===5?300:180;
    if (now-match.last_reward_ms<prep*1000 || now-a.last_reward_ms<60000 || a.active_seconds-match.active_baseline<Math.min(prep,120)) fail('Participação ou duração ainda não confirmada.',409);
    const day=new Date(now).toISOString().slice(0,10);
    if(a.reward_day!==day){a.reward_day=day;a.daily_rewards=0;}
    if(a.daily_rewards>=150) fail('Limite diário de créditos; resultado registrado para revisão.',429);
    a.balance+=catalog.currency.horde_reward; a.daily_rewards++;a.last_reward_ms=now;
    match.wave=data.wave;match.last_reward_ms=now;match.active_baseline=a.active_seconds;
    tx.set(mp,match);tx.set(ledger,{amount:100,kind:'horde',match_id:data.match_id,wave:data.wave,at_ms:now,trust:'community-rate-limited'});tx.set(path,a);
    return {profile:publicProfile(a)};
  }
  if (action === 'purchase') {
    const item=catalog.cosmetics.find(c=>c.id===data.item_id);
    if(!item || !id(data.operation_id))fail('Item/operação inválido.');
    const ledger=`${path}/ledger/buy_${data.operation_id}`;
    const previous=await tx.get(ledger);
    if(previous){if(previous.item_id!==item.id)fail('Operação já usada.',409);return {profile:publicProfile(a),duplicate:true};}
    if(a.owned.includes(item.id))return {profile:publicProfile(a),duplicate:true};
    if(a.balance<item.price)fail('Saldo insuficiente.',409);
    a.balance-=item.price;a.owned.push(item.id);
    tx.set(ledger,{kind:'purchase',amount:-item.price,item_id:item.id,at_ms:now});tx.set(path,a);return {profile:publicProfile(a)};
  }
  if (action === 'equip') {
    if(!classes.includes(data.class_id)||!slots.includes(data.slot))fail('Classe/slot inválido.');
    if(data.item_id!==''){
      const item=catalog.cosmetics.find(c=>c.id===data.item_id);
      if(!item||!a.owned.includes(item.id)||item.slot!==data.slot||!['all',data.class_id].includes(item.class_id))fail('Cosmético não disponível para esta classe.',403);
    }
    a.equipped[data.class_id]={...(a.equipped[data.class_id]||{}),[data.slot]:data.item_id};tx.set(path,a);return {profile:publicProfile(a)};
  }
  fail('Ação desconhecida.');
}
module.exports={operate,initial};
