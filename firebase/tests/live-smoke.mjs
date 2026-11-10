// Explicit, scoped verification for the new Ripple project. Creates only temporary
// anonymous test accounts and QA documents, then removes exactly those records.
// Run before App Check enforcement; never disable enforcement to rerun this test.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {randomUUID, createHash} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase/app';
import {initializeAuth, inMemoryPersistence, signInAnonymously, deleteUser} from 'firebase/auth';
import {initializeFirestore, doc, getDocFromServer, setDoc, deleteDoc, serverTimestamp, terminate, setLogLevel} from 'firebase/firestore';

const require=createRequire(import.meta.url);
const cliAuth=require('firebase-tools/lib/auth');
const {requireAuth}=require('firebase-tools/lib/requireAuth');
const {Client}=require('firebase-tools/lib/apiv2');
const project='ripple-grammar-2026';
const root=new URL('../../',import.meta.url);
const plist=JSON.parse(execFileSync('/usr/bin/plutil',['-convert','json','-o','-',new URL('App/Resources/GoogleService-Info.plist',root).pathname],{encoding:'utf8'}));
assert.equal(plist.PROJECT_ID,project);
assert.equal(plist.BUNDLE_ID,'app.ripple.grammar');
const options={project,nonInteractive:true};
const account=cliAuth.getGlobalDefaultAccount();
if(account)cliAuth.setActiveAccount(options,account);
await requireAuth(options);
const admin=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'});
const appcheck=new Client({urlPrefix:'https://firebaseappcheck.googleapis.com',apiVersion:'v1'});
const service=(await appcheck.request({method:'GET',path:'/projects/812375227752/services/firestore.googleapis.com'})).body;
assert.notEqual(service.enforcementMode,'ENFORCED','Use emulator tests after enforcement; do not weaken protection.');
setLogLevel('silent');
const apps=[];
const reportID='ripple-qa-'+randomUUID();
let reportCreated=false;
const evidence={project,verifiedAt:new Date().toISOString(),checks:{},cleanup:false};
const runID=randomUUID();
function makeClient(label){
  const app=initializeApp({apiKey:plist.API_KEY,appId:plist.GOOGLE_APP_ID,projectId:project},'qa-'+runID+'-'+label);
  const auth=initializeAuth(app,{persistence:inMemoryPersistence});
  const db=initializeFirestore(app,{});
  const client={app,auth,db};apps.push(client);return client;
}
async function denied(operation){
  await assert.rejects(operation,error=>error.code==='permission-denied');
}
async function checkedFetch(url){
  const response=await fetch(url,{signal:AbortSignal.timeout(20000)});
  assert.equal(response.status,200,url);
  return Buffer.from(await response.arrayBuffer());
}
try{
  const pack=JSON.parse(await readFile(new URL('content/source/pack.json',root),'utf8'));
  const alice=makeClient('a'),bob=makeClient('b'),guest=makeClient('guest');
  const userA=(await signInAnonymously(alice.auth)).user;
  const userB=(await signInAnonymously(bob.auth)).user;
  evidence.checks.anonymousAuthentication=true;
  const profile={schemaVersion:1,uiLanguage:'en',createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await setDoc(doc(alice.db,'users',userA.uid),profile);
  const rules=Object.fromEntries(pack.rules.map(({id})=>[id,{ruleId:id,strength:0.5,intervalDays:2.2,dueDate:1800000000,attempts:2,firstTryCorrect:2,lastSeen:1800000000,unlocked:true,freeCorrectChainIDs:[]}]));
  const progress={schemaVersion:2,updatedAt:serverTimestamp(),rules,chains:{},streak:{recent:{},archived:{}}};
  const ownerPath=['users',userA.uid,'progress','de-en'];
  await setDoc(doc(alice.db,...ownerPath),progress);
  assert.equal(Object.keys((await getDocFromServer(doc(alice.db,...ownerPath))).data().rules).length,51);
  evidence.checks.fullRuleSnapshotWriteAndRead=true;
  await denied(getDocFromServer(doc(bob.db,...ownerPath)));
  await denied(setDoc(doc(bob.db,...ownerPath),progress));
  await denied(getDocFromServer(doc(guest.db,...ownerPath)));
  evidence.checks.crossAccountAndUnauthenticatedAccessDenied=true;
  await setDoc(doc(alice.db,'reports',reportID),{uid:userA.uid,chainId:pack.chains[0].chainId,step:0,packVersion:pack.version,reason:'other',note:'Temporary automated service verification.',createdAt:serverTimestamp()});
  reportCreated=true;
  await denied(getDocFromServer(doc(alice.db,'reports',reportID)));
  evidence.checks.authenticatedReportCreateAndReadDenial=true;
  const base='https://ripple-grammar-2026.web.app/';
  const manifestBytes=await checkedFetch(base+'content/manifest.json');
  assert.deepEqual(JSON.parse(manifestBytes),JSON.parse(await readFile(new URL('firebase/public/content/manifest.json',root),'utf8')));
  const manifest=JSON.parse(manifestBytes);
  // Verify every referenced hosted file using the compiler's own manifest tree.
  const publicRoot=new URL('firebase/public/',root);
  const walk=async directory=>{
    const {readdir}=await import('node:fs/promises');
    let files=[];
    for(const entry of await readdir(directory,{withFileTypes:true})){
      const path=new URL(entry.name+(entry.isDirectory()?'/':''),directory);
      if(entry.isDirectory())files.push(...await walk(path));else files.push(path);
    }
    return files;
  };
  const files=await walk(publicRoot);
  for(const file of files){
    const relative=file.pathname.slice(publicRoot.pathname.length);
    const hosted=await checkedFetch(base+relative);
    const local=await readFile(file);
    assert.equal(createHash('sha256').update(hosted).digest('hex'),createHash('sha256').update(local).digest('hex'),relative);
  }
  evidence.checks.hostedContentExactBytes={files:files.length,packVersion:pack.version};
}finally{
  const cleanupFailures=[];
  if(reportCreated){
    try{await admin.request({method:'DELETE',path:`/projects/${project}/databases/(default)/documents/reports/${reportID}`});}
    catch(error){cleanupFailures.push('temporary report');}
  }
  for(const {app,auth,db} of apps){
    const user=auth.currentUser;
    if(user){
      try{
        await deleteDoc(doc(db,'users',user.uid,'progress','de-en'));
        await deleteDoc(doc(db,'users',user.uid));
        await deleteUser(user);
      }catch(error){cleanupFailures.push('temporary QA account '+user.uid);}
    }
    await terminate(db);await deleteApp(app);
  }
  evidence.cleanup=cleanupFailures.length===0;
  await mkdir(new URL('.build/',root),{recursive:true});
  await writeFile(new URL('.build/live-services.json',root),JSON.stringify(evidence,null,2)+'\n');
  assert.deepEqual(cleanupFailures,[],'Cleanup must finish: '+cleanupFailures.join(', '));
}
console.log(JSON.stringify(evidence));
