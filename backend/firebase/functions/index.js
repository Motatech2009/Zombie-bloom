'use strict';
const {onRequest}=require('firebase-functions/v2/https');
const {initializeApp}=require('firebase-admin/app');
const {handler}=require('./http-handler');
initializeApp();
exports.account16Api=onRequest({region:'us-central1',maxInstances:2,timeoutSeconds:30,memory:'256MiB',cors:false},handler);
