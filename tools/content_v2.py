"""Explicit lexical scenarios for the second German curriculum.

This module is an offline authoring tool, never an app dependency. Inflections
come from authored noun/verb records and finite adjective tables, not runtime AI.
"""
from __future__ import annotations

import copy
import json
from dataclasses import dataclass
from pathlib import Path

from author_content import B, t, change, clean, ids

ROOT = Path(__file__).resolve().parents[1]
GLOSSES: dict[str, str] = {'ab':'off / away','aus':'out / off','nach':'after / to',
                         'um':'around / for','von':'from / of','weg':'away','über':'about / over'}
R = ['verb.present.regular']
V2 = ['order.v2-inversion']
MOD = ['verb.modal.present']
BR = ['order.bracket.modal']
PRES = ['verb.present.sein-haben']
FINAL = ['order.verb-final.subordinate']
GEN = ['noun.gender']


def register(lemma, gloss):
    senses=GLOSSES.get(lemma,'').split(' / ') if lemma in GLOSSES else []
    if gloss not in senses:senses.append(gloss)
    GLOSSES[lemma] = ' / '.join(senses)
    return lemma


@dataclass(frozen=True)
class Noun:
    lemma: str
    gender: str
    plural: str
    en: str
    plural_en: str
    oblique: str | None = None

    @classmethod
    def parse(cls, value):
        # lemma; gender; plural; singular English; optional English plural;
        # optional weak masculine accusative/dative singular.
        fields = value.split(';')
        if len(fields) < 4:
            raise ValueError('Invalid authored noun: ' + value)
        lemma, gender, plural, en = fields[:4]
        if gender not in ('m', 'f', 'n'):
            raise ValueError('Unknown noun gender: ' + value)
        plural_en = fields[4] if len(fields) > 4 and fields[4] else en + ('es' if en.endswith(('ch', 'sh', 's', 'x')) else 's')
        oblique = fields[5] if len(fields) > 5 and fields[5] else None
        register(lemma, en)
        return cls(lemma, gender, plural, en, plural_en, oblique)

    def form(self, case='acc', plural=False):
        if plural:
            if self.plural=='-':raise ValueError('Mass noun has no authored plural: '+self.lemma)
            return self.plural + ('n' if case == 'dat' and not self.plural.endswith(('n', 's')) else '')
        return self.oblique if self.oblique and case in ('acc', 'dat') else self.lemma


@dataclass(frozen=True)
class Verb:
    lemma: str
    first: str
    second: str
    third: str
    participle: str
    en: str
    past_en: str

    @classmethod
    def parse(cls, value):
        fields = value.split(';')
        if len(fields) != 7:
            raise ValueError('Invalid authored verb: ' + value)
        register(fields[0], fields[5])
        return cls(*fields)


def adj(value):
    parts = value.split(';')
    register(parts[0], parts[1])
    return parts[0], parts[1], parts[2] if len(parts) > 2 else parts[0] + 'er', parts[3] if len(parts) > 3 else 'more ' + parts[1]


def determinant(noun, case='acc', kind='def', plural=False):
    g = 'p' if plural else noun.gender
    definite = {'nom': {'m': 'der', 'f': 'die', 'n': 'das', 'p': 'die'},
                'acc': {'m': 'den', 'f': 'die', 'n': 'das', 'p': 'die'},
                'dat': {'m': 'dem', 'f': 'der', 'n': 'dem', 'p': 'den'}}
    if kind == 'def':
        return definite[case][g]
    endings = {'nom': {'m': '', 'f': 'e', 'n': '', 'p': 'e'},
               'acc': {'m': 'en', 'f': 'e', 'n': '', 'p': 'e'},
               'dat': {'m': 'em', 'f': 'er', 'n': 'em', 'p': 'en'}}
    if kind == 'indef':
        if plural: raise ValueError('No indefinite plural article')
        return 'ein' + endings[case][g]
    return kind + endings[case][g]


def adjective_form(stem, noun, case='acc', kind='def', plural=False):
    g = 'p' if plural else noun.gender
    if kind == 'def':
        ending = 'e' if case == 'nom' and g != 'p' or case == 'acc' and g in ('f', 'n') else 'en'
    elif kind:
        ending = 'er' if case == 'nom' and g == 'm' else 'es' if g == 'n' and case in ('nom', 'acc') else 'e' if g == 'f' and case in ('nom', 'acc') else 'en'
    else:
        ending = {'nom': {'m': 'er', 'f': 'e', 'n': 'es', 'p': 'e'},
                  'acc': {'m': 'en', 'f': 'e', 'n': 'es', 'p': 'e'},
                  'dat': {'m': 'em', 'f': 'er', 'n': 'em', 'p': 'en'}}[case][g]
    inflection_stem={'dunkel':'dunkl','flexibel':'flexibl','edel':'edl','teuer':'teur','sauer':'saur','hoch':'hoh'}.get(stem,stem[:-1] if stem.endswith('e') else stem)
    return inflection_stem + ending


def np(prefix, noun, case='acc', kind='def', adjective=None, plural=False, initial=False):
    result = []
    if kind:
        lemma = 'der' if kind == 'def' else 'ein' if kind == 'indef' else kind
        result.append(t(prefix+'d', determinant(noun, case, kind, plural), lemma, 'DET', initial=lemma if initial else None))
    if adjective:
        result.append(t(prefix+'a', adjective_form(adjective, noun, case, kind, plural), adjective, 'ADJ', initial=adjective if initial else None))
    result.append(t(prefix+'n', noun.form(case, plural), noun.lemma, 'NOUN'))
    return result


def pp(prefix, noun, preposition='mit', kind='mein', case='dat', initial=False, adjective=None):
    return [t(prefix+'p', preposition, preposition, 'ADP')] + np(prefix, noun, case, kind, adjective, initial=initial)


def replace_group(tokens, prefix, replacement):
    indexes = [i for i, z in enumerate(tokens) if z['id'].startswith(prefix)]
    if not indexes: raise ValueError('Missing group ' + prefix)
    at = min(indexes)
    return tokens[:at] + replacement + [z for z in tokens[at:] if not z['id'].startswith(prefix)]


def def_en(noun, adjective=None, plural=False, kind='the'):
    n = noun.plural_en if plural else noun.en
    value = (adjective + ' ' if adjective else '') + n
    if kind == 'a':
        kind = 'an' if value[0].lower() in 'aeiou' and not value.startswith(('university', 'uniform', 'user')) else 'a'
    return (kind+' ' if kind else '') + value


def form_fixes(tokens, previous, tags):
    old = {z['id']: z for z in previous}
    return {z['id']: (tags, [old[z['id']]['text']]) for z in tokens
            if z['id'] in old and old[z['id']]['text'] != z['text'] and z['id'].endswith(('d', 'a'))}


def context(row):
    noun = Noun.parse(row['context'])
    case = row.get('contextCase', 'dat')
    prep = row.get('contextPrep', 'in')
    tokens=pp('loc_', noun, prep, 'def', case)
    if case=='dat' and prep in ('in','an','bei','von','zu') and noun.gender in ('m','n'):
        contractions={'in':'im','an':'am','bei':'beim','von':'vom','zu':'zum'}
        tokens[0]['text']=contractions[prep]
        tokens=[z for z in tokens if z['id']!='loc_d']
    return tokens, row['contextEn']


def front(b, tokens, label, gloss):
    verb = next(z for z in b.tokens if z['id'] == 'v')
    subject = next(z for z in b.tokens if z['id'] == 's')
    rest = [z for z in b.tokens if z['id'] not in ('v', 's')]
    b.add(label, tokens+[verb, subject]+rest, gloss, moves={'v': V2}, kind='INSERT', slot='start')


def future(b, gloss, would=False):
    old = next(z for z in b.tokens if z['id'] == 'v')
    singular = next(z for z in b.tokens if z['id'] == 's')['text'] == 'ich'
    value = ('würde' if singular else 'würden') if would else ('werde' if singular else 'werden')
    rule = ['verb.konjunktiv2.wuerde'] if would else ['verb.future.werden']
    x = change(b.tokens, 'v', value, 'werden') + [t('inf', old['lemma'], old['lemma'], 'VERB', initial=old['lemma'], spawned=True)]
    b.add('Say what would happen' if would else 'Make it future', x, gloss,
          {'v': (rule, ['würdest', 'würdet'] if would else ['wirst', 'wird']), 'inf': (rule, [old['text']])},
          {'inf': rule})


def adjective_clause(b, row, gloss, conjunction='obwohl'):
    noun = Noun.parse(row['reasonNoun'])
    quality, en, _, _ = adj(row['reasonAdj'])
    value = 'waren' if row.get('reasonPast') else 'ist'
    if row.get('reasonFirst'):
        # The clause is one supplied card. Its finite verb, the main verb and
        # the time adverb are the three explicit placement dependencies.
        clause=[t('reason_j',conjunction,conjunction,'SCONJ')]+np('reason_',noun,'nom')+[t('reason_a',quality,quality,'ADJ'),t('reason_v',value,'sein','AUX'),t('reason_c',',',',','PUNCT')]
        main={z['id']:z for z in b.tokens}
        rest=[z for z in b.tokens if z['id'] not in ('v','s','time')]
        ordered=[main['v'],main['s']]+([main['time']] if 'time' in main else [])+rest
        moves={'reason_v':FINAL,'v':V2}
        if 'time' in main:moves['time']=V2
        b.add('+ '+conjunction+' · place the reason first',clause+ordered,gloss,moves=moves,kind='INSERT',slot='start',rules_=['conj.'+conjunction],initial_order=['reason_j','reason_d','reason_n','reason_v','reason_a','reason_c'])
        return
    tokens = [t('reason_c', ',', ',', 'PUNCT'), t('reason_j', conjunction, conjunction, 'SCONJ')] + np('reason_', noun, 'nom') + [t('reason_a', quality, quality, 'ADJ'), t('reason_v', value, 'sein', 'AUX', initial='sein')]
    if value == 'waren': raise ValueError('Use a singular reason noun with singular agreement')
    initial = ids(tokens[:-2]) + ['reason_v', 'reason_a']
    b.add('+ '+conjunction+' · '+noun.lemma+' · '+quality, b.tokens+tokens, gloss,
          {'reason_v': (PRES, ['sind', 'war', 'sein'])}, {'reason_v': FINAL},
          kind='INSERT', rules_=['conj.'+conjunction], initial_order=initial)


def read_chain(i, row):
    n, other = map(Noun.parse, row['nouns'])
    v = Verb.parse(row['verb'])
    loc, le = context(row)
    b = B(f'de.a1.read.{i:03}', 'A1', row['title'], [t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB')]+np('obj_',n)+loc,
          f'I {v.en} {def_en(n)} {le}.', row['theme'])
    b.add('ich → du', change(change(b.tokens,'s','du','du'),'v',v.second), f'You {v.en} {def_en(n)} {le}.', {'v':(R,[v.first,v.third,v.lemma])}, kind='SUBSTITUTE', target='s')
    b.add(v.lemma+' → lesen', change(b.tokens,'v','liest','lesen',initial='lesen'), f'You read {def_en(n)} {le}.', {'v':(['verb.present.stem-change'],['lese','lesen','lest'])}, kind='SUBSTITUTE', target='v')
    repl=np('obj_',n,kind='indef',initial=True)
    b.add('the → a',replace_group(b.tokens,'obj_',repl),f'You read {def_en(n,kind="a")} {le}.',{'obj_d':(['article.indef.acc'],['ein','eine','einen','einem'])},kind='SUBSTITUTE',target='obj_d')
    repl=np('obj_',other,kind='indef')
    b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'You read {def_en(other,kind="a")} {le}.',form_fixes(repl,b.tokens,['article.indef.acc']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
    x=change(b.tokens,'obj_d',determinant(other,kind='mein'),'mein',initial='mein')
    b.add('a → my',x,f'You read {def_en(other,kind="my")} {le}.',{'obj_d':(['possessive.acc'],['mein','meine','meinen','meinem'])},kind='SUBSTITUTE',target='obj_d')
    x=change(b.tokens,'obj_d',determinant(other,kind='kein'),'kein',initial='kein')
    b.add('Negate the noun',x,f'You do not read {def_en(other,kind="a")} {le}.',{'obj_d':(['article.kein','neg.kein-vs-nicht'],['kein','keine','keinen','keinem'])})
    front(b,[t('time','heute','heute','ADV')],'+ heute',f'Today you do not read {def_en(other,kind="a")} {le}.')
    return b.finish()


def visit_chain(i,row):
    n,other=map(Noun.parse,row['nouns']); v=Verb.parse(row['verb']); quality,qe,_,_=adj(row['adjective']); loc,le=context(row)
    b=B(f'de.a1.visit.{i:03}','A1',row['title'],[t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB')]+np('obj_',n)+loc,f'I {v.en} {def_en(n)} {le}.',row['theme'])
    b.add('ich → du',change(change(b.tokens,'s','du','du'),'v',v.second),f'You {v.en} {def_en(n)} {le}.',{'v':(R,[v.first,v.third,v.lemma])},kind='SUBSTITUTE',target='s')
    x=change(b.tokens,'v','kannst','können',initial='können')+[t('inf',v.lemma,v.lemma,'VERB',initial=v.second)]
    b.add('+ können',x,f'You can {v.en} {def_en(n)} {le}.',{'v':(MOD,['kann','könnt','können']),'inf':(BR,[v.second,v.first])},{'inf':BR})
    register('ihr','you (a group)')
    x=change(change(b.tokens,'s','ihr','ihr'),'v','könnt')
    b.add('Address a group',x,f'You can {v.en} {def_en(n)} {le}.',{'v':(MOD,['kannst','kann','können'])},kind='SUBSTITUTE',target='s')
    repl=np('obj_',other)
    b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'You can {v.en} {def_en(other)} {le}.',form_fixes(repl,b.tokens,['article.def.acc']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
    # Pronoun replacement removes the complete noun phrase.
    pronoun={'m':'ihn','f':'sie','n':'es'}[other.gender]
    x=replace_group(b.tokens,'obj_',[t('obj_n',pronoun,{'m':'er','f':'sie','n':'es'}[other.gender],'PRON',initial={'m':'er','f':'sie','n':'es'}[other.gender])])
    b.add('Use an object pronoun',x,f'You can {v.en} '+{'m':'him','f':'her','n':'it'}[other.gender]+f' {le}.',{'obj_n':(['pronoun.personal.acc'],['er','ihm','sie','es'])})
    front(b,[t('time','morgen','morgen','ADV')],'+ morgen',f'Tomorrow you can {v.en} '+{'m':'him','f':'her','n':'it'}[other.gender]+f' {le}.')
    x=[b.tokens[1],b.tokens[2],b.tokens[3],b.tokens[0]]+b.tokens[4:]
    b.add('Ask a question',x,f'Can you {v.en} '+{'m':'him','f':'her','n':'it'}[other.gender]+f' {le} tomorrow?',moves={'v':['order.question.yes-no'],'time':['order.question.yes-no']},terminal='?')
    return b.finish()


def home_chain(i,row):
    first,n,other=map(Noun.parse,row['nouns']); quality,qe,_,_=adj(row['adjective'])
    b=B(f'de.a1.home.{i:03}','A1',row['title'],np('obj_',first,'nom')+[t('v','ist','sein','AUX'),t('a',quality,quality,'ADJ')],f'{def_en(first).capitalize()} is {qe}.','home')
    repl=np('obj_',n,'nom'); b.add(first.lemma+' → '+n.lemma,replace_group(b.tokens,'obj_',repl),f'{def_en(n).capitalize()} is {qe}.',form_fixes(repl,b.tokens,['article.def.nom']),kind='SUBSTITUTE',target='obj_n')
    repl=np('obj_',n,'nom',plural=True)
    x=change(replace_group(b.tokens,'obj_',repl),'v','sind')
    fixes={'obj_n':(['noun.plural'],[n.lemma]),'v':(PRES,['ist','sein','seid'])}
    if determinant(n,'nom')!='die':fixes['obj_d']=(['article.def.nom'],[determinant(n,'nom')])
    b.add('Make it plural',x,f'{def_en(n,plural=True).capitalize()} are {qe}.',fixes)
    group=[t('and','und','und','CCONJ')]+np('extra_',other,'nom',plural=True)
    b.add('+ und · '+other.plural,b.tokens[:2]+group+b.tokens[2:],f'{def_en(n,plural=True).capitalize()} and {def_en(other,plural=True)} are {qe}.',kind='INSERT',slot='before:v',rules_=['conj.coordinating'])
    x=[t('time','heute','heute','ADV'),b.tokens[-2]]+b.tokens[:-2]+[b.tokens[-1]]
    b.add('+ heute',x,f'Today {def_en(n,plural=True)} and {def_en(other,plural=True)} are {qe}.',moves={'v':V2},kind='INSERT',slot='start')
    x=change(b.tokens,'a','nicht','nicht')+[t('quality',quality,quality,'ADJ')]
    b.add('Negate the description',x,f'Today {def_en(n,plural=True)} and {def_en(other,plural=True)} are not {qe}.',{'a':(['neg.kein-vs-nicht'],[quality,'kein'])})
    b.add('Ask why',change(b.tokens,'time','warum','warum'),f'Why are {def_en(n,plural=True)} and {def_en(other,plural=True)} not {qe}?',{'time':(['order.question.w'],['wer','was','wie'])},terminal='?')
    return b.finish()


def separable_chain(i,row):
    n,other=map(Noun.parse,row['nouns']); loc,le=context(row)
    lemma,first,second,imperative,group,prefix,en=row['separable'].split(';');register(lemma,en)
    b=B(f'de.a1.routine.{i:03}','A1',row['title'],[t('s','ich','ich','PRON'),t('v',first,lemma,'VERB')]+np('obj_',n)+loc+[t('p',prefix,prefix,'PART')],f'I {en} {def_en(n)} {le}.',row['theme'])
    b.add('ich → du',change(change(b.tokens,'s','du','du'),'v',second),f'You {en} {def_en(n)} {le}.',{'v':(['verb.separable.present','order.separable-prefix-end'],[first,group])},kind='SUBSTITUTE',target='s')
    repl=np('obj_',other)
    b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'You {en} {def_en(other)} {le}.',form_fixes(repl,b.tokens,['article.def.acc']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
    front(b,[t('time','morgen','morgen','ADV')],'+ morgen',f'Tomorrow you {en} {def_en(other)} {le}.')
    x=[b.tokens[1],b.tokens[2],b.tokens[0]]+b.tokens[3:]
    b.add('Ask a question',x,f'Will you {en} {def_en(other)} {le} tomorrow?',moves={'v':['order.question.yes-no'],'time':['order.question.yes-no']},terminal='?')
    x=change([z for z in b.tokens if z['id']!='s'],'v',imperative)
    b.add('Address one person',x,f'{en.capitalize()} {def_en(other)} {le} tomorrow!',{'v':(['verb.imperative'],[second,first,group])},terminal='!')
    b.add('Address a group',change(b.tokens,'v',group),f'Everyone, {en} {def_en(other)} {le} tomorrow!',{'v':(['verb.imperative'],[imperative,second,first])},terminal='!')
    x=b.tokens[:-1]+[t('please','bitte','bitte','ADV')]+b.tokens[-1:]
    b.add('+ bitte',x,f'Everyone, please {en} {def_en(other)} {le} tomorrow!',kind='INSERT',slot='before:p',rules_=['verb.imperative'],terminal='!')
    return b.finish()


def perfect_chain(i,row):
    n=Noun.parse(row['noun']); v=Verb.parse(row['verb']); loc,le=context(row); manner,me=row['manner'].split(';');register(manner,me)
    b=B(f'de.a1.past.{i:03}','A1',row['title'],[t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB')]+np('obj_',n)+[t('manner',manner,manner,'ADV')],f'I {v.en} {def_en(n)} {me}.',row['theme'])
    b.add('ich → wir',change(change(b.tokens,'s','wir','wir'),'v',v.lemma),f'We {v.en} {def_en(n)} {me}.',{'v':(R,[v.first,v.third])},kind='SUBSTITUTE',target='s')
    x=change(b.tokens,'v','haben','haben');x.insert(2,t('time','gestern','gestern','ADV'));x.append(t('part',v.participle,v.lemma,'VERB',initial=v.lemma,spawned=True))
    b.add('+ gestern · conversational past',x,f'Yesterday we {v.past_en} {def_en(n)} {me}.',{'v':(['verb.perfekt.haben'],[v.lemma,'sind','hatten']),'part':(['verb.participle.regular'],[v.lemma,v.first])},{'part':['order.bracket.perfekt']},kind='INSERT',slot='after:v')
    x=b.tokens[:-1]+loc+b.tokens[-1:]
    b.add('+ '+row['contextEn'],x,f'Yesterday we {v.past_en} {def_en(n)} {me} {le}.',kind='INSERT',slot='before:part',rules_=['order.bracket.perfekt'])
    x=[b.tokens[1],b.tokens[0]]+b.tokens[2:]
    b.add('Ask a question',x,f'Did we {v.en} {def_en(n)} {me} {le} yesterday?',moves={'v':['order.question.yes-no']},terminal='?')
    x=change([z for z in b.tokens if z['id'] not in ('time','part')],'v',v.lemma,v.lemma)
    b.add('Return to the present',x,f'Do we {v.en} {def_en(n)} {me} {le}?',{'v':(R,[v.first,v.third])},kind='DELETE',terminal='?')
    x=change(change(b.tokens,'s','ich','ich'),'v',v.first)
    b.add('wir → ich',x,f'Do I {v.en} {def_en(n)} {me} {le}?',{'v':(R,[v.lemma,v.third])},kind='SUBSTITUTE',target='s',terminal='?')
    return b.finish()


def cafe_chain(i,row):
    n,other=map(Noun.parse,row['nouns']);v=Verb.parse(row['verb']);a,ae,_,_=adj(row['adjective']);person=Noun.parse(row['person']);event=Noun.parse(row['event']);reason,re=row['reason'].split(';');register(reason,re)
    b=B(f'de.a2.cafe.{i:03}','A2',row['title'],[t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB'),t('obj_n',n.lemma,n.lemma,'NOUN')],f'I {v.en} {n.en}.',row['theme'])
    b.add('ich → wir',change(change(b.tokens,'s','wir','wir'),'v',v.lemma),f'We {v.en} {n.en}.',{'v':(R,[v.first,v.third])},kind='SUBSTITUTE',target='s')
    repl=np('obj_',n,kind='indef',adjective=a,initial=True)
    b.add('+ a portion · '+a,replace_group(b.tokens,'obj_',repl),f'We {v.en} {def_en(n,ae,kind="a")}.',{'obj_d':(['article.indef.acc'],['ein','eine','einen','einem']),'obj_a':(['adj.decl.mixed'],[a,a+'er',a+'e',a+'em'])},kind='INSERT',slot='before:obj_n')
    repl=np('obj_',other,kind='indef',adjective=a)
    b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'We {v.en} {def_en(other,ae,kind="a")}.',form_fixes(repl,b.tokens,['article.indef.acc','adj.decl.mixed']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
    time=pp('time_',event,'nach','def');front(b,time,'+ after '+event.en,f'After {def_en(event)} we {v.en} {def_en(other,ae,kind="a")}.')
    rest=[z for z in b.tokens if not z['id'].startswith('time_') and z['id']!='v'];x=[t('time','gestern','gestern','ADV'),t('v','haben','haben','AUX')]+rest+[t('part',v.participle,v.lemma,'VERB',initial=v.lemma,spawned=True)]
    b.add('Put it in the conversational past',x,f'Yesterday we {v.past_en} {def_en(other,ae,kind="a")}.',{'v':(['verb.perfekt.haben'],[v.lemma,'sind','hatten']),'part':([row.get('participleRule','verb.participle.irregular')],[v.lemma,v.first])},{'part':['order.bracket.perfekt']},slot='start')
    group=pp('with_',person,initial=True);x=b.tokens[:3]+group+b.tokens[3:]
    b.add('+ with my '+person.en,x,f'Yesterday we {v.past_en} {def_en(other,ae,kind="a")} with my {person.en}.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:s')
    clause=[t('rc',',',',','PUNCT'),t('cj','weil','weil','SCONJ'),t('cs','wir','wir','PRON'),t('ca',reason,reason,'ADJ'),t('cv','waren','sein','AUX',initial='sein')]
    b.add('+ weil · '+reason,b.tokens+clause,f'Yesterday we {v.past_en} {def_en(other,ae,kind="a")} with my {person.en} because we were {re}.',{'cv':(['verb.praeteritum.sein-haben'],['sind','war','sein'])},{'cv':FINAL},kind='INSERT',rules_=['conj.weil'],initial_order=['rc','cj','cs','cv','ca'])
    return b.finish()


def travel_chain(i,row):
    n,other=map(Noun.parse,row['nouns']);friends=Noun.parse(row['friends']);manner,me=row['manner'].split(';');register(manner,me)
    b=B(f'de.a2.travel.{i:03}','A2',row['title'],[t('s','wir','wir','PRON'),t('v','gehen','gehen','VERB')]+pp('place_',n,'in','def','acc'),f'We go into {def_en(n)}.',row['theme'])
    repl=pp('place_',n,'in','def','dat');x=change(replace_group(b.tokens,'place_',repl),'v','bleiben','bleiben')
    b.add('go there → stay there',x,f'We stay in {def_en(n)}.',form_fixes(repl,b.tokens,['prep.two-way','article.def.dat']),kind='SUBSTITUTE',target='v')
    repl=pp('place_',other,'in','def','dat');b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'place_',repl),f'We stay in {def_en(other)}.',form_fixes(repl,b.tokens,['prep.two-way','article.def.dat']),kind='SUBSTITUTE',target='place_n',rules_=GEN)
    contraction='im' if other.gender in ('m','n') else 'in der'
    if ' ' in contraction:raise ValueError('Travel contraction scenario needs masculine/neuter place')
    x=change([z for z in b.tokens if z['id']!='place_d'],'place_p',contraction,initial='in')
    b.add('Contract in dem',x,f'We stay in {def_en(other)}.',{'place_p':(['prep.contraction'],['in','ins','am'])})
    x=change(b.tokens,'v','sind','sein');x.insert(2,t('time','gestern','gestern','ADV'));x.append(t('part','geblieben','bleiben','VERB',initial='bleiben',spawned=True))
    b.add('+ yesterday · conversational past',x,f'Yesterday we stayed in {def_en(other)}.',{'v':(['verb.perfekt.sein'],['haben','bleiben','waren']),'part':(['verb.participle.irregular'],['bleiben','blieb','bleibt'])},{'part':['order.bracket.perfekt']},kind='INSERT',slot='after:v')
    group=[t('with_p','mit','mit','ADP')]+np('with_',friends,'dat',plural=True,initial=True)
    for z in group:
        if z['id']=='with_n':z['initial']=friends.plural
    x=b.tokens[:3]+group+b.tokens[3:]
    fixes={'with_d':(['prep.dative','article.def.dat'],['die','der','dem'])}
    if friends.form('dat',True)!=friends.plural:fixes['with_n']=(['noun.dative-plural-n'],[friends.plural,friends.lemma])
    b.add('+ with the '+friends.plural_en,x,f'Yesterday we stayed in {def_en(other)} with {def_en(friends,plural=True)}.',fixes,kind='INSERT',slot='after:time')
    x=replace_group(b.tokens,'with_',[t('with_p','mit','mit','ADP'),t('with_n','ihnen','sie','PRON',initial='sie')])
    b.add('Use a dative pronoun',x,f'Yesterday we stayed in {def_en(other)} with them.',{'with_n':(['pronoun.personal.dat'],['sie','ihr','ihm'])})
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='place_p');x=b.tokens[:at]+[t('neg','nicht','nicht','ADV')]+b.tokens[at:]
    b.add('Negate the location',x,f'Yesterday we did not stay in {def_en(other)} with them.',moves={'neg':['order.negation.nicht']},kind='INSERT',slot='end')
    prefix=[t('ms','ich','ich','PRON'),t('mv','weiß','wissen','VERB'),t('mc',',',',','PUNCT'),t('cj','dass','dass','SCONJ')]
    x=prefix+[z for z in b.tokens if z['id']!='v']+[next(z for z in b.tokens if z['id']=='v')]
    b.add('+ I know that …',x,f'I know that yesterday we did not stay in {def_en(other)} with them.',moves={'v':FINAL},kind='INSERT',slot='start',rules_=['conj.dass'])
    return b.finish()


def shopping_chain(i,row):
    n,other=map(Noun.parse,row['nouns']);a,ae,_,_=adj(row['adjective']);better,be,_,_=adj(row['replacementAdj']);person=Noun.parse(row['person']);need=Noun.parse(row['conditionNoun'])
    b=B(f'de.a2.shop.{i:03}','A2',row['title'],[t('s','ich','ich','PRON'),t('v','kaufe','kaufen','VERB')]+np('obj_',n),f'I buy {def_en(n)}.','shopping')
    repl=np('obj_',n,adjective=a,initial=True)
    for z in repl:
        if z['id']=='obj_d':z.pop('initial',None)
    b.add('+ '+a,replace_group(b.tokens,'obj_',repl),f'I buy {def_en(n,ae)}.',{'obj_a':(['adj.decl.weak'],[a,a+'e',a+'er'])},kind='INSERT',slot='before:obj_n')
    repl=np('obj_',n,kind='indef',adjective=a,initial=True)
    for z in repl:
        if z['id']=='obj_a':z.pop('initial',None)
    b.add('the → a',replace_group(b.tokens,'obj_',repl),f'I buy {def_en(n,ae,kind="a")}.',{'obj_d':(['article.indef.acc'],['ein','eine','einen','einem'])},kind='SUBSTITUTE',target='obj_d')
    repl=np('obj_',other,kind='indef',adjective=a)
    b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'I buy {def_en(other,ae,kind="a")}.',form_fixes(repl,b.tokens,['article.indef.acc','adj.decl.mixed']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
    x=change(b.tokens,'obj_a',adjective_form(better,other,kind='indef'),better,initial=better)
    b.add(a+' → '+better,x,f'I buy {def_en(other,be,kind="a")}.',{'obj_a':(['adj.decl.mixed'],[better,better+'e',better+'er',better+'em'])},kind='SUBSTITUTE',target='obj_a')
    group=pp('gift_',person,'für','mein','acc',initial=True)
    b.add('+ for my '+person.en,b.tokens+group,f'I buy {def_en(other,be,kind="a")} for my {person.en}.',{'gift_d':(['prep.accusative','possessive.acc'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT')
    x=change(change(b.tokens,'s','wir','wir'),'v','kaufen')
    b.add('ich → wir',x,f'We buy {def_en(other,be,kind="a")} for my {person.en}.',{'v':(R,['kaufe','kauft','kaufst'])},kind='SUBSTITUTE',target='s')
    clause=[t('rc',',',',','PUNCT'),t('cj','wenn','wenn','SCONJ'),t('cs','ich','ich','PRON'),t('enough','genug','genug','ADV'),t('cn',need.lemma,need.lemma,'NOUN'),t('cv','habe','haben','AUX',initial='haben')]
    b.add('+ if I have enough '+need.en,b.tokens+clause,f'We buy {def_en(other,be,kind="a")} for my {person.en} if I have enough {need.en}.',{'cv':(PRES,['haben','hat','hast'])},{'cv':FINAL},kind='INSERT',rules_=['conj.wenn'],initial_order=['rc','cj','cs','cv','enough','cn'])
    x=change(b.tokens,'obj_d',determinant(other,kind='kein'),'kein',initial='kein')
    b.add('Negate the purchase',x,f'We do not buy {def_en(other,be,kind="a")} for my {person.en} if I have enough {need.en}.',{'obj_d':(['article.kein','neg.kein-vs-nicht'],['kein','keine','keinen','keinem'])})
    return b.finish()


def reflexive_chain(i,row):
    if row['verb'].split(';')[0] in ('freuen','ärgern','wundern','interessieren'):
        return emotion_chain(i,row)
    v=Verb.parse(row['verb']);n=Noun.parse(row['complement']);person,other=map(Noun.parse,row['people']);event=Noun.parse(row['event'])
    complement=pp('compl_',n,row['preposition'],'def',row.get('case','acc'))
    prefix=row.get('prefix');base=[t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB'),t('r','mich','sich','PRON')]+complement+([t('prefix',prefix,prefix,'PART')] if prefix else [])
    en=row['actionEn'];first_en='am '+en[3:] if en.startswith('be ') else en;second_en='are '+en[3:] if en.startswith('be ') else en
    b=B(f'de.a2.feeling.{i:03}','A2',row['title'],base,'I '+first_en+'.',row['theme'])
    x=change(change(change(b.tokens,'s','du','du'),'v',v.second),'r','dich')
    b.add('ich → du',x,'You '+second_en+'.',{'v':(R,[v.first,v.lemma]),'r':(['verb.reflexive'],['mich','sich','uns'])},kind='SUBSTITUTE',target='s')
    x=[b.tokens[0],t('v','musst','müssen','AUX',initial='müssen'),b.tokens[2]]+[z for z in b.tokens[3:] if z['id']!='prefix']+[t('inf',v.lemma,v.lemma,'VERB',initial=v.second)]
    b.add('+ müssen',x,'You have to '+en+'.',{'v':(MOD,['muss','müssen','müsst']),'inf':(BR,[v.first,v.second])},{'inf':BR})
    b.add('Put the obligation in the past',change(b.tokens,'v','musstest'),'You had to '+en+'.',{'v':(['verb.praeteritum.modal'],['musst','musste','mussten'])})
    group=pp('with_',person,initial=True);x=b.tokens[:3]+group+b.tokens[3:]
    b.add('+ together with my '+person.en,x,'You had to '+en+' with my '+person.en+'.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:r')
    front(b,pp('time_',event,'nach','def'),'+ after '+event.en,'After '+def_en(event)+' you had to '+en+' with my '+person.en+'.')
    x=change(change(change(b.tokens,'s','wir','wir'),'v','mussten'),'r','uns')
    b.add('du → wir',x,'After '+def_en(event)+' we had to '+en+' with my '+person.en+'.',{'v':(['verb.praeteritum.modal'],['musstest','musste','müssen']),'r':(['verb.reflexive'],['mich','dich','sich'])},kind='SUBSTITUTE',target='s')
    repl=pp('with_',other);b.add(person.lemma+' → '+other.lemma,replace_group(b.tokens,'with_',repl),'After '+def_en(event)+' we had to '+en+' with my '+other.en+'.',form_fixes(repl,b.tokens,['possessive.dat']),kind='SUBSTITUTE',target='with_n',rules_=GEN)
    return b.finish()


def emotion_chain(i,row):
    # Reactions use a natural present/past narrative, rather than an artificial
    # obligation to feel an emotion. Voluntary actions retain the modal branch.
    v=Verb.parse(row['verb']);n=Noun.parse(row['complement']);person,other=map(Noun.parse,row['people']);event=Noun.parse(row['event'])
    en=row['actionEn'];first_en='am '+en[3:] if en.startswith('be ') else en
    second_en='are '+en[3:] if en.startswith('be ') else en
    past_plural='were '+en[3:] if en.startswith('be ') else v.past_en
    past_singular='was '+en[3:] if en.startswith('be ') else v.past_en
    base=[t('s','ich','ich','PRON'),t('v',v.first,v.lemma,'VERB'),t('r','mich','sich','PRON')]+pp('compl_',n,row['preposition'],'def',row.get('case','acc'))
    b=B(f'de.a2.feeling.{i:03}','A2',row['title'],base,'I '+first_en+'.',row['theme'])
    x=change(change(change(b.tokens,'s','du','du'),'v',v.second),'r','dich')
    b.add('ich → du',x,'You '+second_en+'.',{'v':(R,[v.first,v.lemma]),'r':(['verb.reflexive'],['mich','sich','uns'])},kind='SUBSTITUTE',target='s')
    x=change(change(change(b.tokens,'s','wir','wir'),'v',v.lemma),'r','uns')
    b.add('du → wir',x,'We '+second_en+'.',{'v':(R,[v.first,v.second]),'r':(['verb.reflexive'],['mich','dich','sich'])},kind='SUBSTITUTE',target='s')
    x=change(b.tokens,'v','haben','haben')+[t('part',v.participle,v.lemma,'VERB',initial=v.lemma,spawned=True)]
    b.add('Use the conversational past',x,'We '+past_plural+'.',{'v':(['verb.perfekt.haben'],[v.lemma,'sind','hatten']),'part':(['verb.participle.regular'],[v.first,v.lemma])},{'part':['order.bracket.perfekt']})
    group=pp('with_',person,initial=True);x=b.tokens[:3]+group+b.tokens[3:]
    b.add('+ together with my '+person.en,x,'We '+past_plural+' with my '+person.en+'.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:r')
    front(b,pp('time_',event,'nach','def'),'+ after '+event.en,'After '+def_en(event)+' we '+past_plural+' with my '+person.en+'.')
    repl=pp('with_',other)
    b.add(person.lemma+' → '+other.lemma,replace_group(b.tokens,'with_',repl),'After '+def_en(event)+' we '+past_plural+' with my '+other.en+'.',form_fixes(repl,b.tokens,['possessive.dat']),kind='SUBSTITUTE',target='with_n',rules_=GEN)
    x=change(change(change(b.tokens,'s','ich','ich'),'v','habe'),'r','mich')
    b.add('wir → ich',x,'After '+def_en(event)+' I '+past_singular+' with my '+other.en+'.',{'v':(PRES,['haben','hat','hast']),'r':(['verb.reflexive'],['uns','dich','sich'])},kind='SUBSTITUTE',target='s')
    return b.finish()


def outside_chain(i,row):
    actor=Noun.parse(row['actor']);place=Noun.parse(row['place']);person=Noun.parse(row['person']);v=Verb.parse(row['verb']);a,ae,comp,ce=adj(row['adjective'])
    b=B(f'de.a2.outside.{i:03}','A2',row['title'],np('actor_',actor,'nom')+[t('v',v.third,v.lemma,'VERB')]+pp('place_',place,'in','def'),f'{def_en(actor).capitalize()} {row["singularActionEn"]} in {def_en(place)}.',row['theme'])
    b.add('in → vor · keep the location',change(b.tokens,'place_p','vor','vor'),f'{def_en(actor).capitalize()} {row["singularActionEn"]} in front of {def_en(place)}.',kind='SUBSTITUTE',target='place_p',rules_=['prep.two-way'])
    repl=np('actor_',actor,'nom',plural=True);x=change(replace_group(b.tokens,'actor_',repl),'v',v.lemma)
    fixes={'actor_n':(['noun.plural'],[actor.lemma]),'v':(R,[v.first,v.third])}
    if determinant(actor,'nom')!='die':fixes['actor_d']=(['article.def.nom'],[determinant(actor,'nom')])
    b.add('Make the subject plural',x,f'{def_en(actor,plural=True).capitalize()} {v.en} in front of {def_en(place)}.',fixes)
    repl=np('actor_',actor,'nom',adjective=a,plural=True,initial=True)
    for z in repl:
        if z['id']=='actor_d':z.pop('initial',None)
    b.add('+ '+a,replace_group(b.tokens,'actor_',repl),f'{def_en(actor,ae,True).capitalize()} {v.en} in front of {def_en(place)}.',{'actor_a':(['adj.decl.weak'],[a,a+'e',a+'er'])},kind='INSERT',slot='before:actor_n')
    repl=pp('place_',place,'vor','indef',initial=True)
    b.add('the place → a place',replace_group(b.tokens,'place_',repl),f'{def_en(actor,ae,True).capitalize()} {v.en} in front of {def_en(place,kind="a")}.',{'place_d':(['article.def.dat','prep.two-way'],['ein','eine','einen','einem','einer'])},kind='SUBSTITUTE',target='place_d')
    x=change(b.tokens,'actor_a',comp+'en',a,initial=comp)
    b.add(a+' → '+comp,x,f'{def_en(actor,ce,True).capitalize()} {v.en} in front of {def_en(place,kind="a")}.',{'actor_a':(['adj.comparative','adj.decl.weak'],[comp,comp+'e',comp+'er'])},kind='SUBSTITUTE',target='actor_a')
    group=pp('with_',person,initial=True);at=next(k for k,z in enumerate(b.tokens) if z['id']=='v')+1
    b.add('+ with my '+person.en,b.tokens[:at]+group+b.tokens[at:],f'{def_en(actor,ce,True).capitalize()} {v.en} with my {person.en} in front of {def_en(place,kind="a")}.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:v')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='place_p');x=b.tokens[:at]+[t('neg','nicht','nicht','ADV')]+b.tokens[at:]
    b.add('Negate the location',x,f'{def_en(actor,ce,True).capitalize()} do not {v.en} with my {person.en} in front of {def_en(place,kind="a")}.',moves={'neg':['order.negation.nicht']},kind='INSERT',slot='end')
    return b.finish()


def b1_chain(family,i,row):
    """B1 branches share finite transformations, not a single sentence script."""
    n,other=map(Noun.parse,row['nouns']);a,ae,_,_=adj(row['adjective']);person=Noun.parse(row['person']);v=Verb.parse(row['verb'])
    would=family in ('wish','despite','weekend');mass=family in ('wish','market')
    noun_group=np('obj_',n,kind=None if mass else 'mein' if family=='weekend' else 'def')
    b=B(f'de.b1.{family}.{i:03}','B1',row['title'],[t('s','wir','wir','PRON'),t('v',v.lemma,v.lemma,'VERB')]+noun_group,f'We {v.en} {def_en(n,kind="" if mass else "my" if family=="weekend" else "the")}.',row['theme'])
    if family=='future':
        front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow',f'Tomorrow we {v.en} {def_en(n)}.')
        future(b,f'Tomorrow we will {v.en} {def_en(n)}.')
        repl=np('obj_',other);b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'Tomorrow we will {v.en} {def_en(other)}.',form_fixes(repl,b.tokens,['article.def.acc']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
        action=f'{v.en} {def_en(other)}'
        group=pp('with_',person,initial=True);at=3
        b.add('+ with my '+person.en,b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we will {action} with my {person.en}.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:s')
        manner,me=row['manner'].split(';');register(manner,me);at=3
        b.add('+ '+manner+' · neutral order',b.tokens[:at]+[t('manner',manner,manner,'ADV')]+b.tokens[at:],f'Tomorrow we will {me} {action} with my {person.en}.',moves={'manner':['order.time-manner-place']},kind='INSERT',slot='end')
        adjective_clause(b,row,f'Tomorrow we will {me} {action} with my {person.en} although {def_en(Noun.parse(row["reasonNoun"]))} is {adj(row["reasonAdj"])[1]}.')
        b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','werde'),f'Tomorrow I will {me} {action} with my {person.en} although {def_en(Noun.parse(row["reasonNoun"]))} is {adj(row["reasonAdj"])[1]}.',{'v':(['verb.future.werden'],['werden','wird','wirst'])},kind='SUBSTITUTE',target='s')
    elif family in ('wish','market'):
        future(b,f'We {"would" if would else "will"} {v.en} {n.en}.',would)
        repl=np('obj_',n,kind=None,adjective=a,initial=True)
        b.add('+ '+a+' · no article',replace_group(b.tokens,'obj_',repl),f'We {"would" if would else "will"} {v.en} {ae} {n.en}.',{'obj_a':(['adj.decl.strong'],[a,a+'er',a+'e',a+'em'])},kind='INSERT',slot='before:obj_n')
        repl=np('obj_',other,kind=None,adjective=a);b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'We {"would" if would else "will"} {v.en} {ae} {other.en}.',form_fixes(repl,b.tokens,['adj.decl.strong']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
        if family=='wish':
            recommender=Verb.parse(row['relativeVerb']);pron={'m':'den','f':'die','n':'das'}[other.gender]
            clause=[t('rc',',',',','PUNCT'),t('rp',pron,'der','PRON',initial='der'),t('rs','du','du','PRON'),t('rv',recommender.participle,recommender.lemma,'VERB'),t('ra','hast','haben','AUX')]
            b.add('+ relative clause · you '+recommender.past_en,b.tokens+clause,f'We would {v.en} {ae} {other.en} that you {recommender.past_en}.',{'rp':(['relative.clause','article.def.acc'],['der','dem','den','die','das'])},{'ra':FINAL},kind='INSERT',initial_order=['rc','rp','rs','ra','rv'])
            tail=f'{v.en} {ae} {other.en} that you {recommender.past_en}'
            front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow','Tomorrow we would '+tail+'.')
            place=Noun.parse(row['place']);contract='im' if place.gender in ('m','n') else 'zur'; prep='in' if contract=='im' else 'zu'
            group=[t('at',contract,prep,'ADP',initial=prep),t('place',place.form('dat'),place.lemma,'NOUN')]
            at=next(k for k,z in enumerate(b.tokens) if z['id']=='obj_a')
            b.add('+ '+row['placeEn'],b.tokens[:at]+group+b.tokens[at:],f'Tomorrow, {row["placeEn"]}, we would '+tail+'.',{'at':(['prep.contraction'],[prep,'ins','am'])},kind='INSERT',slot='before:obj_a')
            b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','würde'),f'Tomorrow, {row["placeEn"]}, I would '+tail+'.',{'v':(['verb.konjunktiv2.wuerde'],['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
        else:
            front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow',f'Tomorrow we will {v.en} {ae} {other.en}.')
            group=pp('gift_',person,'für','mein','acc',initial=True);at=3
            b.add('+ for my '+person.en,b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we will {v.en} {ae} {other.en} for my {person.en}.',{'gift_d':(['prep.accusative','possessive.acc'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:s')
            place=Noun.parse(row['place']);group=pp('place_',place,row.get('placePrep','auf'),'def');at=next(k for k,z in enumerate(b.tokens) if z['id']=='obj_a')
            b.add('+ '+row['placeEn']+' · neutral order',b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we will {v.en} {ae} {other.en} for my {person.en} {row["placeEn"]}.',moves={z['id']:['order.time-manner-place'] for z in group},kind='INSERT',slot='end')
            b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','werde'),f'Tomorrow I will {v.en} {ae} {other.en} for my {person.en} {row["placeEn"]}.',{'v':(['verb.future.werden'],['werden','wird','wirst'])},kind='SUBSTITUTE',target='s')
    elif family in ('relative','film'):
        if family=='film':
            x=change(b.tokens,'v','haben','haben')+[t('part',v.participle,v.lemma,'VERB',initial=v.lemma,spawned=True)]
            part_rule='verb.participle.regular' if v.lemma=='hören' else 'verb.participle.irregular'
            b.add('Use the conversational past',x,f'We {v.past_en} {def_en(n)}.',{'v':(['verb.perfekt.haben'],[v.lemma,'sind','hatten']),'part':([part_rule],[v.lemma,v.first])},{'part':['order.bracket.perfekt']})
        repl=np('obj_',n,adjective=a,initial=True)
        for z in repl:
            if z['id']=='obj_d':z.pop('initial',None)
        b.add('+ '+a,replace_group(b.tokens,'obj_',repl),f'We {v.past_en if family=="film" else v.en} {def_en(n,ae)}.',{'obj_a':(['adj.decl.weak'],[a,a+'e',a+'er'])},kind='INSERT',slot='before:obj_n')
        repl=np('obj_',other,adjective=a);b.add(n.lemma+' → '+other.lemma,replace_group(b.tokens,'obj_',repl),f'We {v.past_en if family=="film" else v.en} {def_en(other,ae)}.',form_fixes(repl,b.tokens,['article.def.acc','adj.decl.weak']),kind='SUBSTITUTE',target='obj_n',rules_=GEN)
        if family=='film':
            x=change([z for z in b.tokens if z['id']!='part'],'v','werden','werden')+[t('inf',v.lemma,v.lemma,'VERB',initial=v.participle,spawned=True)]
            b.add('Make it future',x,f'We will {v.en} {def_en(other,ae)}.',{'v':(['verb.future.werden'],['wird','werdet','würden']),'inf':(['verb.future.werden'],[v.participle,v.first])},{'inf':['verb.future.werden']})
        else:future(b,f'We will {v.en} {def_en(other,ae)}.')
        relative=Verb.parse(row['relativeVerb']);pron=determinant(other,'acc' if family=='film' else 'nom')
        if family=='film':
            clause=[t('rc',',',',','PUNCT'),t('rp',pron,'der','PRON',initial='der'),t('rs','du','du','PRON'),t('rv',relative.participle,relative.lemma,'VERB'),t('ra','hast','haben','AUX')];initial=['rc','rp','rs','ra','rv'];move='ra';tail=f'{v.en} {def_en(other,ae)} that you {relative.past_en}'
        else:
            place=Noun.parse(row['place']);clause=[t('rc',',',',','PUNCT'),t('rp',pron,'der','PRON',initial='den')]+pp('relative_place_',place,'in','def')+[t('rv',relative.third,relative.lemma,'VERB')]
            initial=['rc','rp','rv']+ids(clause[2:-1]);move='rv';tail=f'{v.en} {def_en(other,ae)} who {row["relativeActionEn"]} in {def_en(place)}'
        b.add('+ relative clause',b.tokens+clause,'We will '+tail+'.',{'rp':(['relative.clause'],['der','den','dem','die','das'])},{move:FINAL},kind='INSERT',initial_order=initial)
        front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow','Tomorrow we will '+tail+'.')
        if family=='film':
            adjective_clause(b,row,'Tomorrow we will '+tail+' although '+def_en(Noun.parse(row['reasonNoun']))+' is '+adj(row['reasonAdj'])[1]+'.')
        else:
            gift=Noun.parse(row['gift']);quality,qe,_,_=adj(row['giftAdj']);group=pp('gift_',gift,'mit',None,adjective=quality,initial=True);at=3
            b.add('+ with '+qe+' '+gift.en,b.tokens[:at]+group+b.tokens[at:],'Tomorrow we will '+tail+' with '+qe+' '+gift.en+'.',{'gift_a':(['adj.decl.strong','prep.dative'],[quality,quality+'en',quality+'er',quality+'e'])},kind='INSERT',slot='after:s')
            b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','werde'),'Tomorrow I will '+tail+' with '+qe+' '+gift.en+'.',{'v':(['verb.future.werden'],['werden','wird','wirst'])},kind='SUBSTITUTE',target='s')
    elif family=='despite':
        future(b,f'We would {v.en} {def_en(n)}.',True)
        front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow',f'Tomorrow we would {v.en} {def_en(n)}.')
        extra=Verb.parse(row['extraVerb']);group=[t('and','und','und','CCONJ'),t('extra',extra.lemma,extra.lemma,'VERB')];at=next(k for k,z in enumerate(b.tokens) if z['id']=='inf')+1
        b.add('+ und · '+extra.lemma,b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we would {v.en} {def_en(n)} and {extra.en}.',kind='INSERT',slot='after:inf',rules_=['conj.coordinating'])
        group=pp('with_',person,initial=True);at=3
        b.add('+ with my '+person.en,b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we would {v.en} {def_en(n)} and {extra.en} with my {person.en}.',{'with_d':(['prep.dative','possessive.dat'],['mein','meine','meinen','meinem','meiner'])},kind='INSERT',slot='after:s')
        manner,me=row['manner'].split(';');register(manner,me)
        b.add('+ '+manner+' · neutral order',b.tokens[:3]+[t('manner',manner,manner,'ADV')]+b.tokens[3:],f'Tomorrow we would {me} {v.en} {def_en(n)} and {extra.en} with my {person.en}.',moves={'manner':['order.time-manner-place']},kind='INSERT',slot='end')
        tail=f'{me} {v.en} {def_en(n)} and {extra.en} with my {person.en} although {def_en(Noun.parse(row["reasonNoun"]))} is {adj(row["reasonAdj"])[1]}'
        adjective_clause(b,row,'Tomorrow we would '+tail+'.')
        b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','würde'),'Tomorrow I would '+tail+'.',{'v':(['verb.konjunktiv2.wuerde'],['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
    elif family=='weekend':
        first_person=n.en if n.en!=other.en else 'male '+n.en
        second_person=other.en if n.en!=other.en else 'female '+other.en
        future(b,f'We would {v.en} {def_en(n,kind="my")}.',True)
        front(b,[t('time','morgen','morgen','ADV')],'+ tomorrow',f'Tomorrow we would {v.en} {def_en(n,kind="my")}.')
        group=[t('and','und','und','CCONJ')]+np('extra_',other,kind='mein');at=next(k for k,z in enumerate(b.tokens) if z['id']=='inf')
        b.add('+ and my '+other.en,b.tokens[:at]+group+b.tokens[at:],f'Tomorrow we would {v.en} my {first_person} and my {second_person}.',kind='INSERT',slot='before:inf',rules_=['conj.coordinating'])
        place=Noun.parse(row['place']);relative=Verb.parse(row['relativeVerb']);pron=determinant(other,'nom')
        clause=[t('rc',',',',','PUNCT'),t('rp',pron,'der','PRON',initial='der')]+pp('relative_place_',place,'in','def')+[t('rv',relative.third,relative.lemma,'VERB')]
        b.add('+ relative clause',b.tokens+clause,f'Tomorrow we would {v.en} my {first_person} and my {second_person}, who {row["relativeActionEn"]} in {def_en(place)}.',{'rp':(['relative.clause'],['der','den','dem','die','das'])},{'rv':FINAL},kind='INSERT',initial_order=['rc','rp','rv']+ids(clause[2:-1]))
        gift=Noun.parse(row['gift']);quality,qe,_,_=adj(row['giftAdj']);group=pp('gift_',gift,'mit',None,adjective=quality,initial=True);at=3
        tail=f'{v.en} my {first_person} and my {second_person}, who {row["relativeActionEn"]} in {def_en(place)}, with {qe} {gift.en}'
        b.add('+ with '+qe+' '+gift.en,b.tokens[:at]+group+b.tokens[at:],'Tomorrow we would '+tail+'.',{'gift_a':(['adj.decl.strong','prep.dative'],[quality,quality+'er',quality+'en',quality+'e'])},kind='INSERT',slot='after:s')
        manner,me=row['manner'].split(';');register(manner,me)
        b.add('+ '+manner+' · neutral order',b.tokens[:3]+[t('manner',manner,manner,'ADV')]+b.tokens[3:],'Tomorrow we would '+me+' '+tail+'.',moves={'manner':['order.time-manner-place']},kind='INSERT',slot='end')
        b.add('wir → ich',change(change(b.tokens,'s','ich','ich'),'v','würde'),'Tomorrow I would '+me+' '+tail+'.',{'v':(['verb.konjunktiv2.wuerde'],['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
    else:raise ValueError('Unknown B1 family '+family)
    return b.finish()


def build_chains(legacy):
    scenarios=json.loads((ROOT/'content/authoring/scenarios-v2.json').read_text())
    functions={'read':read_chain,'visit':visit_chain,'home':home_chain,'routine':separable_chain,'past':perfect_chain,'cafe':cafe_chain,'travel':travel_chain,'shop':shopping_chain,'feeling':reflexive_chain,'outside':outside_chain}
    chains=[]
    for family,rows in scenarios.items():
        for i,row in enumerate(rows):
            if row.get('retainV1'):
                chains.append(legacy[family](i));continue
            chain=functions[family](i,row) if family in functions else b1_chain(family,i,row)
            chain['authoringScenario']=row['title']
            chains.append(chain)
    return chains,GLOSSES
