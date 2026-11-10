#!/usr/bin/env python3
"""Validate authored snapshots, compile immutable Hosting units and app baseline.

Run `python3 tools/ripplec.py --check` in CI. `--release` additionally requires
native-speaker and audio sign-offs matching each unit's SHA-256, never a blanket
approval. JSON source is intentionally explicit so editorial diffs are reviewable.
"""
from __future__ import annotations
import argparse, collections, gzip, hashlib, json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def encoded(value): return (json.dumps(value,ensure_ascii=False,separators=(',',':'),sort_keys=True)+'\n').encode()
def digest(data): return hashlib.sha256(data).hexdigest()

def validate(pack):
    errors=[]; warnings=[]; coverage=collections.Counter(); nochange=0; steps=0
    rules={r['id']:r for r in pack['rules']}; lex={l['lemma']:set(l['forms']) for l in pack['lexicon']}
    def error(condition,message):
        if not condition: errors.append(message)
    error(len(rules)==len(pack['rules']),'Duplicate rules')
    error(len(lex)==len(pack['lexicon']),'Duplicate vocabulary lemmas')
    for lemma in pack['lexicon']:error(bool(lemma['gloss'].get('en')),'Missing vocabulary gloss: '+lemma['lemma'])
    error(len({c['chainId'] for c in pack['chains']})==len(pack['chains']),'Duplicate chains')
    visiting=set(); visited=set()
    def visit(id):
        if id in visiting: errors.append('Cyclic rule prerequisite: '+id); return
        if id in visited:return
        visiting.add(id)
        for pre in rules[id]['prerequisites']:
            error(pre in rules,'Unknown prerequisite '+pre)
            if pre in rules:visit(pre)
        visiting.remove(id);visited.add(id)
    for id in rules:visit(id)
    for chain in pack['chains']:
        cid=chain['chainId']; old={t['id']:t for t in chain['base']['tokens']}; tags=set()
        error(5<=len(chain['steps'])<=8,cid+': expected 5–8 steps')
        for i,s in enumerate(chain['steps']):
            key=f'{cid}/{i}'; steps+=1
            target={t['id']:t for t in s['tokens']}; fixes={f['token']:f for f in s['fixes']}; direct=set(s['card'].get('appliedTokens',[]))
            error(len(target)==len(s['tokens']),key+': duplicate token ID')
            error(bool(s['gloss'].get('en')),key+': missing gloss')
            error(all(len(order)==len(target) and set(order)==set(target) for order in s['acceptedOrders']),key+': invalid accepted order')
            st=set(s['card']['rules'])
            for d in s['fixes']+s['moves']:
                st.update(d['rules']);error(d['token'] in target,key+': unknown dependency token')
            error(bool(st) and st<=rules.keys(),key+': unknown or missing rule tags'); tags.update(st)
            for id,t in target.items():
                prior=old.get(id)
                if prior:
                    changed=prior['text']!=t['text']
                    if prior['lemma']!=t['lemma']:error(id in direct or id in fixes,key+': untagged lemma change')
                else: changed=t.get('initial',t['text'])!=t['text'] or t.get('spawned',False)
                if changed and id not in direct:error(id in fixes,key+': missing fix '+id)
            removed=set(old)-set(target)
            error(not removed or s['card']['type'] in ('DELETE','TRANSFORM','SUBSTITUTE'),key+': unexpected removal')
            for id,fix in fixes.items():
                if id not in target:continue
                answer=target[id]['text']; lemma=target[id]['lemma']
                error(len(set(fix.get('distractors',[])))==len(fix.get('distractors',[])),key+': repeated distractor')
                for value in fix.get('distractors',[]):
                    error(value!=answer,key+': distractor equals answer '+id)
                    error(value in lex.get(lemma,set()),key+': unknown distractor '+value)
            if not s['fixes'] and not s['moves']:
                nochange+=1;error(bool(s.get('noChangeNote')),key+': no-change step missing note')
            if len(s['fixes'])+len(s['moves'])>3:warnings.append(key+': more than three dependencies')
            old=target
        coverage.update(tags)
        if sum(t['pos']!='PUNCT' for t in chain['steps'][-1]['tokens'])>22:warnings.append(cid+': final exceeds 22 words')
    for id in rules:error(coverage[id]>=12,f'{id}: only {coverage[id]} chains; minimum 12')
    error(.1<=nochange/max(1,steps)<=.2,'No-change ratio outside 10–20%')
    counts=collections.Counter(c['cefr'] for c in pack['chains'])
    error(counts=={'A1':70,'A2':100,'B1':70},f'Wrong CEFR distribution: {counts}')
    used={t['lemma'] for c in pack['chains'] for s in [c['base']]+c['steps'] for t in s['tokens'] if t['pos']!='PUNCT'}
    error(used==set(lex),'Vocabulary must contain exactly the lemmas used in sentences')
    def sentence(s):return ' '.join(t['text'] for t in s['tokens']).replace(' ,',',')
    all_sentences={sentence(s) for c in pack['chains'] for s in [c['base']]+c['steps']}
    return errors,warnings,dict(chains=len(pack['chains']),steps=steps,rules=len(rules),lemmas=len(lex),noChangeSteps=nochange,
          noChangeRatio=round(nochange/steps,4),coverage=dict(sorted(coverage.items())),nativeReview=pack['reviewStatus'],cefr=dict(counts),
          distinctBaseSentences=len({sentence(c['base']) for c in pack['chains']}),
          distinctFinalSentences=len({sentence(c['steps'][-1]) for c in pack['chains']}),
          distinctSentences=len(all_sentences),themes=dict(sorted(collections.Counter(c['theme'] for c in pack['chains']).items())),
          vocabularyTeachingBand=dict(sorted(collections.Counter(l['cefr'] for l in pack['lexicon']).items())),
          vocabularyBandReview='provisional author assignment; native CEFR review required')

def compile_pack(pack):
    version=pack['version']; folder=ROOT/f'firebase/public/content/de-en/v{version}'
    files={}; refs=[]
    def add(name,value):
        data=encoded(value); path=folder/name; files[path]=data
        return dict(path='/'+str(path.relative_to(ROOT/'firebase/public')),sha256=digest(data))
    for start in range(0,len(pack['chains']),20):
        value={'chains':pack['chains'][start:start+20]}; sha=digest(encoded(value))
        refs.append(add(f'units/u{start//20+1:02}.{sha[:12]}.json',value))
    rules=add('rules.json',{'rules':pack['rules']}); lexicon=add('lexicon.json',{'lexicon':pack['lexicon']})
    index=add('index.json',dict(packId=pack['packId'],version=version,schemaVersion=1,reviewStatus=pack['reviewStatus'],units=refs))
    generated_at={1:'2026-11-07T12:00:00Z',2:'2026-11-08T12:00:00Z'}.get(version)
    if generated_at is None:raise ValueError('Set the authored manifest publication timestamp for this pack version')
    manifest=dict(schemaVersion=1,generatedAt=generated_at,packs=[dict(packId='de-en',version=version,minAppVersion='1.0.0',index=index,rules=rules,lexicon=lexicon)])
    files[ROOT/'firebase/public/content/manifest.json']=encoded(manifest)
    files[ROOT/'App/Resources/baseline.json']=encoded(pack)
    return files,refs

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true');ap.add_argument('--release',action='store_true');args=ap.parse_args()
    pack=json.loads((ROOT/'content/source/pack.json').read_text());errors,warnings,report=validate(pack)
    files,units=compile_pack(pack)
    report['compressedBytes']=len(gzip.compress(encoded(pack),mtime=0));report['warnings']=warnings
    error_review=[]
    if args.release:
        signoff_file=ROOT/'content/review/signoffs.json'; signoffs=json.loads(signoff_file.read_text()) if signoff_file.exists() else {}
        audio_catalog=ROOT/'App/Resources/audio-catalog.json'
        audio_digest=digest(audio_catalog.read_bytes()) if audio_catalog.exists() and json.loads(audio_catalog.read_text()).get('clips') else None
        for unit in units:
            record=signoffs.get(unit['sha256'],{})
            if not all(record.get(k) for k in ['nativeReviewer','nativeReviewedAt','audioReviewer','audioReviewedAt']):error_review.append('Missing native/audio sign-off: '+unit['path'])
            if audio_digest and record.get('audioCatalogSHA256')!=audio_digest:error_review.append('Missing current recording catalog listening sign-off: '+unit['path'])
        errors+=error_review
    if errors:
        print('\n'.join('ERROR '+e for e in errors),file=sys.stderr);return 1
    files[ROOT/'content/quality-report.json']=encoded(report)
    mismatch=[]
    for path,data in files.items():
        if args.check:
            if not path.exists() or path.read_bytes()!=data:mismatch.append(str(path.relative_to(ROOT)))
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    if mismatch:print('Stale compiled content: '+', '.join(mismatch),file=sys.stderr);return 1
    print(f'{report["chains"]} chains · {report["steps"]} steps · {report["rules"]} rules · {report["lemmas"]} lemmas · {report["noChangeRatio"]:.1%} no-change · {report["compressedBytes"]:,} bytes gzip')
    print(f'{len(warnings)} editorial warnings; native/audio sign-off: {pack["reviewStatus"]}')
    return 0

if __name__=='__main__':sys.exit(main())
