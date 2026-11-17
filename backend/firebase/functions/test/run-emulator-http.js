'use strict';
const {initializeApp}=require('firebase-admin/app');
const {spawn}=require('node:child_process');
const express=require('express');
initializeApp({projectId:'demo-zombie-bloom'});
const {handler}=require('../http-handler');
const app=express();app.use(express.json({limit:'20kb'}));app.post('/demo-zombie-bloom/us-central1/account16Api',handler);
const server=app.listen(5001,'127.0.0.1',()=>{
 const test=spawn(process.execPath,[require.resolve('./emulator-integration')],{stdio:'inherit',env:process.env});
 test.on('exit',code=>{
  if(code)return server.close(()=>process.exit(code));
  const {resolve}=require('node:path');
  const root=resolve(__dirname,'../../../..');
  const godot=spawn('godot',['--headless','--path',root,'--script','res://tests/release16_meta_emulator_test.gd'],{stdio:'inherit',env:process.env});
  godot.on('exit',exit=>server.close(()=>process.exit(exit||0)));
 });
});
