'use strict';
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
const {operate}=require('./service');
exports.handler=async(req,res)=>{
  res.set('Cache-Control','no-store');
  if(req.method!=='POST')return res.status(405).json({error:'Use POST.'});
  if(JSON.stringify(req.body||{}).length>20000)return res.status(413).json({error:'Pedido muito grande.'});
  let uid='';
  try{
    const bearer=req.get('authorization')||'';
    if(!bearer.startsWith('Bearer '))return res.status(401).json({error:'Entre na conta.'});
    const user=await getAuth().verifyIdToken(bearer.slice(7),true);uid=user.uid;
    const db=getFirestore();const now=Date.now();
    const result=await db.runTransaction(async transaction=>operate({
      get:async path=>{const snap=await transaction.get(db.doc(path));return snap.exists?snap.data():null;},
      set:(path,data)=>transaction.set(db.doc(path),data)
    },user.uid,req.body.action,req.body.data||{},now));
    return res.json(result);
  }catch(e){
    const status=e.status||(String(e.code||'').startsWith('auth/')?401:500);
    if(status===500)console.error('account16 transaction failed',e.code||'internal');
    else if(status===409||status===429)console.warn('account16 rejected',{uid,action:String(req.body.action||'').slice(0,24),status});
    return res.status(status).json({error:status===500?'Serviço temporariamente indisponível.':status===401?'Sessão inválida.':e.message});
  }
};
