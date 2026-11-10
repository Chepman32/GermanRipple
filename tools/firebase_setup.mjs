#!/usr/bin/env node
// Scoped CLI helper for the Firebase project explicitly authorized for Ripple.
// Uses the existing firebase-tools login; never prints tokens or private keys.
import {createRequire} from 'node:module';
import {readFile,realpath,chmod} from 'node:fs/promises';
import {createPrivateKey} from 'node:crypto';
import {resolve,sep} from 'node:path';
const require=createRequire(new URL('../firebase/package.json',import.meta.url));
const auth=require('firebase-tools/lib/auth');
const {requireAuth}=require('firebase-tools/lib/requireAuth');
const {Client}=require('firebase-tools/lib/apiv2');
const {logger}=require('firebase-tools/lib/logger');
const project='ripple-grammar-2026';
const number='812375227752';
const app='1:812375227752:ios:265d39233db41ba12aaadd';
const team='WH9D3XTKPT';
const options={project,nonInteractive:true};
const account=auth.getGlobalDefaultAccount();
if(account) auth.setActiveAccount(options,account);
await requireAuth(options);
async function request(origin,version,method,path,body,queryParams){
  const result=await new Client({urlPrefix:origin,apiVersion:version}).request({method,path,body,queryParams,skipLog:{body:true,resBody:true,queryParams:true}});
  return result.body;
}
const mode=process.argv[2] ?? 'inspect';
try{
  if(mode==='enable-services'){
    const result=await request('https://serviceusage.googleapis.com','v1','POST',`/projects/${number}/services:batchEnable`,{serviceIds:['firestore.googleapis.com','identitytoolkit.googleapis.com','firebaseappcheck.googleapis.com','firebaseremoteconfig.googleapis.com','firebasehosting.googleapis.com','firebaserules.googleapis.com','firebasecrashlytics.googleapis.com','firebaseinstallations.googleapis.com']});
    let operation=result;
    for(let i=0;i<40 && !operation.done;i++){
      await new Promise(resolve=>setTimeout(resolve,1000));
      operation=await request('https://serviceusage.googleapis.com','v1','GET','/'+result.name);
    }
    if(operation.error || !operation.done)throw new Error('Service enablement did not finish successfully');
    console.log(JSON.stringify({project,requiredServicesEnabled:true}));
  }else if(mode==='inspect'){
    const billing=await request('https://cloudbilling.googleapis.com','v1','GET',`/projects/${project}/billingInfo`);
    console.log(JSON.stringify({project,billingEnabled:billing.billingEnabled ?? false}));
    for(const service of ['firebasecrashlytics.googleapis.com','firebaseinstallations.googleapis.com']){
      const state=await request('https://serviceusage.googleapis.com','v1','GET',`/projects/${number}/services/${service}`);
      console.log(JSON.stringify({service,state:state.state}));
    }
    try{
      const config=await request('https://identitytoolkit.googleapis.com','admin/v2','GET',`/projects/${project}/config`);
      console.log(JSON.stringify({authConfigured:true,subtype:config.subtype,anonymousEnabled:config.signIn?.anonymous?.enabled ?? false}));
    }catch(e){console.log(JSON.stringify({authConfigured:false,message:e.message}));}
    const appCheck=await request('https://firebaseappcheck.googleapis.com','v1','GET',`/projects/${number}/services/firestore.googleapis.com`);
    console.log(JSON.stringify({firestoreAppCheck:appCheck.enforcementMode}));
    try{
      const apple=await request('https://identitytoolkit.googleapis.com','admin/v2','GET',`/projects/${project}/defaultSupportedIdpConfigs/apple.com`);
      console.log(JSON.stringify({appleProviderEnabled:apple.enabled,serviceId:apple.clientId,bundleIds:apple.appleSignInConfig?.bundleIds,appleCodeFlowConfigured:!!apple.appleSignInConfig?.codeFlowConfig?.keyId}));
    }catch(e){console.log(JSON.stringify({appleProviderEnabled:false,status:e.status}));}
  }else if(mode==='enable-anonymous'){
    const result=await request('https://identitytoolkit.googleapis.com','admin/v2','PATCH',`/projects/${project}/config`,{signIn:{anonymous:{enabled:true}}},{updateMask:'signIn.anonymous.enabled'});
    console.log(JSON.stringify({project,anonymousEnabled:result.signIn?.anonymous?.enabled,subtype:result.subtype}));
  }else if(mode==='configure-app-attest'){
    await request('https://firebase.googleapis.com','v1beta1','PATCH',`/projects/${project}/iosApps/${app}`,{teamId:team},{updateMask:'teamId'});
    const result=await request('https://firebaseappcheck.googleapis.com','v1','PATCH',`/projects/${number}/apps/${app}/appAttestConfig`,{name:`projects/${number}/apps/${app}/appAttestConfig`,tokenTtl:'3600s'},{updateMask:'tokenTtl'});
    console.log(JSON.stringify({project,team,appAttestConfigured:!!result.name,tokenTtl:result.tokenTtl}));
  }else if(mode==='enforce-firestore-app-check'){
    const name=`projects/${number}/services/firestore.googleapis.com`;
    const result=await request('https://firebaseappcheck.googleapis.com','v1','PATCH','/'+name,{name,enforcementMode:'ENFORCED'},{updateMask:'enforcementMode'});
    console.log(JSON.stringify({project,service:'firestore.googleapis.com',enforcementMode:result.enforcementMode}));
  }else if(mode==='configure-apple'){
    // Run only after approval to create the dedicated Apple key and give it to
    // this Firebase project. Keep both CLI debug and network-error logs silent:
    // firebase-tools may otherwise include request options in transport errors.
    logger.silent=true;
    const keyId=process.argv[3];
    if(!/^[A-Z0-9]{10}$/.test(keyId??''))throw new Error('A valid dedicated Apple key ID is required');
    const keyPath=await realpath(resolve(process.argv[4]??''));
    const secretRoot=await realpath(new URL('../.secrets/',import.meta.url));
    if(!keyPath.startsWith(secretRoot+sep)||!keyPath.endsWith('.p8'))throw new Error('Use the key in Ripple’s ignored .secrets directory');
    await chmod(keyPath,0o600);
    const privateKey=await readFile(keyPath,'utf8');
    const parsed=createPrivateKey(privateKey);
    if(parsed.asymmetricKeyType!=='ec'||parsed.asymmetricKeyDetails?.namedCurve!=='prime256v1')throw new Error('A valid Apple EC signing key is required');
    const name=`projects/${project}/defaultSupportedIdpConfigs/apple.com`;
    const body={name,enabled:true,clientId:'app.ripple.grammar.auth',appleSignInConfig:{bundleIds:['app.ripple.grammar'],codeFlowConfig:{teamId:team,keyId,privateKey}}};
    let existing;
    try{existing=await request('https://identitytoolkit.googleapis.com','admin/v2','GET','/'+name);}catch(error){if(error.status!==404)throw error;}
    const result=existing
      ?await request('https://identitytoolkit.googleapis.com','admin/v2','PATCH','/'+name,body,{updateMask:'enabled,clientId,appleSignInConfig'})
      :await request('https://identitytoolkit.googleapis.com','admin/v2','POST',`/projects/${project}/defaultSupportedIdpConfigs`,body,{idpId:'apple.com'});
    console.log(JSON.stringify({project,appleProviderEnabled:result.enabled,serviceId:result.clientId,keyId,team}));
  }else{throw new Error('Unsupported operation');}
}catch(e){console.error(mode==='configure-apple'?'Apple provider setup failed; no key data has been logged. Verify the dedicated key and project settings.':'Firebase setup failed: '+e.message);process.exitCode=1;}
