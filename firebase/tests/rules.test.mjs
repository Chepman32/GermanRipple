import {after, before, beforeEach, test} from 'node:test';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp} from 'firebase/firestore';

let env;
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-ripple',firestore:{rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8'),host:'127.0.0.1',port:8089}});
});
beforeEach(async()=>{await env.clearFirestore();});
after(async()=>{await env?.cleanup();});
const db=(uid)=>uid ? env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
const progress=()=>({schemaVersion:2,updatedAt:serverTimestamp(),rules:{},chains:{},streak:{recent:{},archived:{}}});
const profile=()=>({createdAt:serverTimestamp(),updatedAt:serverTimestamp(),uiLanguage:'en',schemaVersion:1});

test('a user can create, read and delete only their own progress',async()=>{
  await assertSucceeds(setDoc(doc(db('alice'),'users/alice/progress/de-en'),progress()));
  await assertSucceeds(getDoc(doc(db('alice'),'users/alice/progress/de-en')));
  await assertFails(getDoc(doc(db('bob'),'users/alice/progress/de-en')));
  await assertFails(setDoc(doc(db('bob'),'users/alice/progress/de-en'),progress()));
  await assertFails(getDoc(doc(db(),'users/alice/progress/de-en')));
  await assertSucceeds(deleteDoc(doc(db('alice'),'users/alice/progress/de-en')));
});
test('unknown fields, packs and non-server timestamps fail',async()=>{
  await assertFails(setDoc(doc(db('a'),'users/a/progress/de-en'),{...progress(),admin:true}));
  await assertFails(setDoc(doc(db('a'),'users/a/progress/fr-en'),progress()));
  await assertFails(setDoc(doc(db('a'),'users/a/progress/de-en'),{...progress(),updatedAt:Timestamp.fromMillis(1)}));
});
test('compact progress rejects old writers and bounds catalog and streak structures',async()=>{
  const ref=doc(db('a'),'users/a/progress/de-en');
  await assertFails(setDoc(ref,{...progress(),schemaVersion:1,chains:[],streak:{}}));
  await assertFails(setDoc(ref,{...progress(),chains:[]}));
  await assertFails(setDoc(ref,{...progress(),chains:Object.fromEntries(Array.from({length:1025},(_,i)=>['chain'+i,{}]))}));
  await assertFails(setDoc(ref,{...progress(),streak:{recent:{},archived:{},extra:true}}));
  await assertFails(setDoc(ref,{...progress(),streak:{recent:[],archived:{}}}));
  await assertFails(setDoc(ref,{...progress(),streak:{recent:Object.fromEntries(Array.from({length:401},(_,i)=>['day'+i,1])),archived:{}}}));
  const chain={latest:{chainID:'de.a1.read.000',completedAt:1800000000,mode:'forward',firstTryRate:0.8,durationSeconds:90},firstCompletedAt:1800000000,bestFirstTryRate:0.8,counts:{'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA':20000},legacyInstants:''};
  await assertSucceeds(setDoc(ref,{...progress(),chains:{'de.a1.read.000|forward':chain},streak:{recent:{'2026-11-08':3},archived:{}}}));
});
test('rule map shape is bounded and unknown rule IDs cannot be uploaded',async()=>{
  const rule={ruleId:'verb.present.regular',strength:0.5,intervalDays:2.2,dueDate:1800000000,attempts:2,firstTryCorrect:2,lastSeen:1800000000,unlocked:true,freeCorrectChainIDs:[]};
  const payload={...progress(),rules:{[rule.ruleId]:rule}};
  await assertSucceeds(setDoc(doc(db('a'),'users/a/progress/de-en'),payload));
  await assertFails(setDoc(doc(db('a'),'users/a/progress/de-en'),{...payload,rules:'not a map'}));
  await assertFails(setDoc(doc(db('a'),'users/a/progress/de-en'),{...payload,rules:{madeup:{...rule,ruleId:'madeup'}}}));
});
test('the complete 51-rule app snapshot fits the rules evaluation budget',async()=>{
  const pack=JSON.parse(await readFile(new URL('../../content/source/pack.json',import.meta.url),'utf8'));
  const rules=Object.fromEntries(pack.rules.map(({id})=>[id,{ruleId:id,strength:0.5,intervalDays:2.2,dueDate:1800000000,attempts:2,firstTryCorrect:2,lastSeen:1800000000,unlocked:true,freeCorrectChainIDs:[]} ]));
  await assertSucceeds(setDoc(doc(db('a'),'users/a/progress/de-en'),{...progress(),rules}));
});
test('account profile fields are typed and creation time is immutable',async()=>{
  const ref=doc(db('a'),'users/a');await assertSucceeds(setDoc(ref,profile()));
  await assertSucceeds(updateDoc(ref,{updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{createdAt:Timestamp.fromMillis(1),updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(db('b'),'users/a')));
  await assertFails(setDoc(doc(db('a'),'users/a'),{...profile(),uiLanguage:42}));
});
test('reports require authentication, ownership, bounded text and server time',async()=>{
  const report={uid:'a',chainId:'de.a1.read.000',step:0,packVersion:1,reason:'bad_translation',note:'Please check this.',createdAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('a'),'reports/valid'),report));
  await assertFails(getDoc(doc(db('a'),'reports/valid')));
  await assertFails(updateDoc(doc(db('a'),'reports/valid'),{note:'change'}));
  await assertFails(setDoc(doc(db(),'reports/no-auth'),report));
  await assertFails(setDoc(doc(db('b'),'reports/wrong-owner'),report));
  await assertFails(setDoc(doc(db('a'),'reports/long'),{...report,note:'x'.repeat(501)}));
  await assertFails(setDoc(doc(db('a'),'reports/step'),{...report,step:-1}));
  await assertFails(setDoc(doc(db('a'),'reports/time'),{...report,createdAt:Timestamp.fromMillis(1)}));
});
