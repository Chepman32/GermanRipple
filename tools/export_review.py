#!/usr/bin/env python3
from pathlib import Path
import csv,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def sentence(tokens):
    out=''
    for t in tokens:out+=('' if not out or t['pos']=='PUNCT' else ' ')+t['text']
    return out[:1].upper()+out[1:]
def main():
    pack=json.loads((ROOT/'content/source/pack.json').read_text())
    dest=ROOT/'content/review';dest.mkdir(exist_ok=True)
    with (dest/'bases.tsv').open('w',newline='',encoding='utf-8') as handle:
        writer=csv.writer(handle,delimiter='\t');writer.writerow(['chain','band','theme','sentence','translation','native approved','audio checked','review notes'])
        for chain in pack['chains']:
            base=chain['base']
            writer.writerow([chain['chainId'],chain['cefr'],chain['theme'],sentence(base['tokens'])+base.get('terminal',chain['terminal']),base['gloss']['en'],'','',''])
    with (dest/'vocabulary.tsv').open('w',newline='',encoding='utf-8') as handle:
        writer=csv.writer(handle,delimiter='\t');writer.writerow(['lemma','provisional teaching band','English gloss','authored forms','native approved','review notes'])
        for entry in pack['lexicon']:
            writer.writerow([entry['lemma'],entry['cefr'],entry['gloss']['en'],json.dumps(entry['forms'],ensure_ascii=False),'',''])
    with (dest/'steps.tsv').open('w',newline='',encoding='utf-8') as handle:
        writer=csv.writer(handle,delimiter='\t');writer.writerow(['chain','band','theme','step','card','before','after','translation','fixes and distractors','accepted orders','native approved','audio checked','review notes'])
        for chain in pack['chains']:
            old=chain['base']['tokens'];old_terminal=chain['base'].get('terminal',chain['terminal'])
            for i,step in enumerate(chain['steps']):
                terminal=step.get('terminal',chain['terminal'])
                writer.writerow([chain['chainId'],chain['cefr'],chain['theme'],i+1,step['card']['label'],sentence(old)+old_terminal,sentence(step['tokens'])+terminal,step['gloss']['en'],json.dumps(step['fixes'],ensure_ascii=False),json.dumps(step['acceptedOrders']), '', '', ''])
                old=step['tokens'];old_terminal=terminal
    index=json.loads((ROOT/f'firebase/public/content/de-en/v{pack["version"]}/index.json').read_text())
    template={unit['sha256']:{'unit':unit['path'],'nativeReviewer':'','nativeReviewedAt':'','audioReviewer':'','audioReviewedAt':''} for unit in index['units']}
    catalog=ROOT/'App/Resources/audio-catalog.json'
    if catalog.exists() and json.loads(catalog.read_text()).get('clips'):
        audio_hash=hashlib.sha256(catalog.read_bytes()).hexdigest()
        for record in template.values():record['audioCatalogSHA256']=audio_hash
    (dest/'required-signoffs.json').write_text(json.dumps(template,indent=2)+'\n')
    existing=dest/'signoffs.json'
    if not existing.exists():existing.write_text('{}\n')
    print('Wrote base, step, vocabulary and unit-hash review worksheets. Existing approvals were preserved.')
if __name__=='__main__':main()
