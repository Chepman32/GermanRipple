#!/usr/bin/env python3
"""Deterministic authored German lesson sources. No runtime text generation.

Every template has explicit snapshots, translations, rule attribution and input
states. Vocabulary variations are curated below, not produced by a language model
at app runtime. Native and audio review are separate, recorded release gates.
"""
from __future__ import annotations
import copy
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES = ['cafe','home','travel','work','shopping','health','weather','family','city','food','free-time','plans']
EXPLAIN = {
'verb.present.regular': 'The verb ending follows the subject: ich -e, du -st, er/sie/es -t, wir -en, ihr -t, sie/Sie -en.',
'verb.present.stem-change': 'Some strong verbs change their stem with du and er/sie/es: lesen → du liest, fahren → du fährst. The plural keeps the original stem.',
'verb.present.sein-haben': 'Sein and haben have their own present forms: ich bin/habe, du bist/hast, er ist/hat, wir sind/haben.',
'verb.modal.present': 'The modal is the finite verb: ich kann, du kannst, wir können; ich muss, du musst, wir müssen. The other verb becomes an infinitive.',
'verb.separable.present': 'A separable verb splits in a main clause. Conjugate the verb and put its prefix at the end: ich kaufe ein → du kaufst ein.',
'verb.imperative': 'For a direct request to one person, use the verb stem without du: Kauf ein! To a group, use the ihr form without ihr: Kauft ein!',
'verb.perfekt.haben': 'Most verbs form the conversational past with haben plus a participle. Conjugate haben for the subject: wir haben gelernt.',
'verb.perfekt.sein': 'Many verbs describing movement or a change of state use sein in the Perfekt. Bleiben also uses sein: wir sind geblieben.',
'verb.participle.regular': 'Regular participles usually use ge- + stem + -t: lernen → gelernt, kaufen → gekauft. Verbs ending in -ieren do not add ge-.',
'verb.participle.irregular': 'Strong verbs often use ge- + a changed stem + -en: trinken → getrunken, bleiben → geblieben, sehen → gesehen.',
'verb.praeteritum.sein-haben': 'Sein and haben commonly use the simple past in speech: ich war/hatte, wir waren/hatten.',
'verb.praeteritum.modal': 'Modal verbs often use the simple past: ich musste, du musstest, wir mussten. The main verb stays in the infinitive.',
'verb.future.werden': 'To explicitly mark the future, conjugate werden and put the main verb in the infinitive at the end: ich werde kommen, wir werden kommen.',
'verb.reflexive': 'A reflexive pronoun refers back to the subject: ich freue mich, du freust dich, wir freuen uns. Change both the verb and the pronoun.',
'verb.konjunktiv2.wuerde': 'Würde plus an infinitive expresses a hypothetical action or polite wish: ich würde trinken, wir würden trinken. The infinitive closes the main clause.',
'order.v2-inversion': 'In a statement, the finite verb occupies the second unit. If time comes first, the subject follows the verb: Heute kaufen wir Brot.',
'order.question.yes-no': 'A yes/no question starts with the finite verb, followed by the subject: Können wir kommen? The infinitive or participle stays at the end.',
'order.question.w': 'A question word comes first, then the finite verb, then the subject: Warum sind die Lampen neu?',
'order.bracket.modal': 'The finite modal and the infinitive form a bracket around the other sentence parts: Du musst heute einkaufen.',
'order.bracket.perfekt': 'In a main clause, the auxiliary is finite and the participle goes at the end: Gestern haben wir Deutsch gelernt.',
'order.separable-prefix-end': 'The detached prefix closes the main clause: Morgen kaufst du ein. Keep it separate from the conjugated verb.',
'order.verb-final.subordinate': 'After weil, dass, wenn or obwohl, the finite verb goes to the end of its clause. In the Perfekt, the auxiliary follows the participle.',
'order.negation.nicht': 'Nicht normally comes before the phrase it negates, such as a location or a predicate adjective. Its position changes the focus of the sentence.',
'order.time-manner-place': 'A neutral order often puts time before manner and place. Gern normally follows the subject and finite verb, before longer phrases.',
'noun.gender': 'German nouns have grammatical gender. A replacement with the same gender and case can leave the article and adjective unchanged.',
'noun.plural': 'Learn a noun together with its plural. A plural subject normally takes die and a plural verb: das Kind spielt → die Kinder spielen.',
'article.def.nom': 'The nominative article follows the subject’s gender and number: der (masculine), die (feminine), das (neuter), die (plural).',
'article.def.acc': 'For a direct object, the masculine article changes der → den. Feminine die, neuter das and plural die stay the same.',
'article.def.dat': 'Dative definite articles are dem (masculine/neuter), der (feminine), and den (plural). Use them after a dative preposition.',
'article.indef.acc': 'A masculine direct object takes einen: einen Roman. Feminine eine and neuter ein keep their nominative forms.',
'article.kein': 'Kein takes the same endings as ein: keinen Roman, keine Lampe, kein Buch. Its ending follows gender, number and case.',
'noun.dative-plural-n': 'Most dative plural nouns add -n: die Freunde → mit den Freunden. Nouns already ending in -n or plural -s do not add another -n.',
'adj.decl.weak': 'After a definite article, adjectives usually end in -e or -en: den neuen Film, die kleinen Kinder. The article carries most grammatical information.',
'adj.decl.mixed': 'After ein, kein or a possessive, an adjective supplies an ending when needed: ein großer Tee, einen großen Tee, keinen großen Tee.',
'adj.decl.strong': 'Without an article, an adjective carries the case and gender signal: frischer Kaffee, frischen Kaffee, frisches Brot, mit frischem Kaffee.',
'adj.comparative': 'The comparative normally adds -er before the case ending: klein → kleiner → die kleineren Kinder. Gut is irregular: besser.',
'prep.dative': 'Mit, bei, von, zu, nach and aus take the dative: mit meiner Schwester, mit meinem Bruder, mit den Freunden.',
'prep.accusative': 'Für, ohne, durch, gegen and um take the accusative: für meinen Bruder, für meine Mutter.',
'prep.two-way': 'Two-way prepositions such as in, auf and unter use accusative for a destination and dative for a location: in den Park → im Park.',
'prep.contraction': 'Common preposition–article pairs contract: in dem → im, an dem → am, zu dem → zum, zu der → zur, in das → ins.',
'possessive.acc': 'Possessives follow ein endings. A masculine direct object takes -en: meinen Roman, für meinen Bruder. Feminine uses meine.',
'possessive.dat': 'In the dative, mein becomes meinem for masculine/neuter, meiner for feminine, and meinen for plural: mit meiner Schwester.',
'pronoun.personal.acc': 'A direct object can be replaced by an accusative pronoun: der Freund → ihn, die Freundin → sie, das Kind → es.',
'pronoun.personal.dat': 'A dative object uses a dative pronoun: mit den Freunden → mit ihnen. Other forms include mir, dir, ihm, ihr and uns.',
'conj.coordinating': 'Und, aber, oder and denn join equal units without sending the finite verb to the end. A modal can be shared by coordinated infinitives.',
'conj.weil': 'Weil introduces a reason. It starts a subordinate clause, separated by a comma, with its finite verb at the end.',
'conj.dass': 'Dass introduces a statement as part of another sentence: Ich weiß, dass … . The finite verb closes the dass-clause.',
'conj.wenn': 'Wenn introduces a condition or repeated situation. Its finite verb comes at the end: wenn ich genug Geld habe.',
'conj.obwohl': 'Obwohl introduces a contrast despite a fact. Separate the clause with a comma and put the finite verb last: obwohl es regnet.',
'relative.clause': 'A relative pronoun matches its noun’s gender and number, but gets its case from its role in the relative clause: der Mann, der …; der Tee, den du empfohlen hast.',
'neg.kein-vs-nicht': 'Use kein to negate a noun with an indefinite article or no article: einen Roman → keinen Roman. Use nicht for other negation.',
}

def rules():
    text = (ROOT/'Ripple_PDS.md').read_text()
    result = []
    for rule, name, level in re.findall(r'^\| `([^`]+)` \| ([^\n]+?) \| (A1|A2|B1) \|$', text, re.M):
        if rule in {r['id'] for r in result}: continue
        category = ('Verbs' if rule.startswith('verb.') else 'Word order' if rule.startswith('order.') else
                    'Articles & adjectives' if rule.startswith(('noun.','article.','adj.')) else
                    'Clauses' if rule.startswith(('conj.','relative.','neg.')) else 'Cases & pronouns')
        prereq = {
          'verb.perfekt.sein':['verb.perfekt.haben'], 'verb.future.werden':['verb.present.regular'],
          'verb.konjunktiv2.wuerde':['verb.modal.present'], 'adj.decl.mixed':['article.indef.acc'],
          'adj.decl.weak':['article.def.acc'], 'adj.decl.strong':['adj.decl.mixed'],
          'prep.dative':['article.def.nom'], 'article.def.dat':['article.def.acc'],
          'relative.clause':['order.verb-final.subordinate'], 'conj.obwohl':['conj.weil'],
        }.get(rule, [])
        result.append(dict(id=rule,category=category,cefr=level,name={'en':re.sub(r'[*`]', '',name)},prerequisites=prereq,
                           explainer={'en':EXPLAIN[rule]}))
    return result

def t(id, text, lemma=None, pos='X', initial=None, spawned=False):
    value = dict(id=id,text=text,lemma=lemma or text,pos=pos)
    if initial is not None: value['initial']=initial
    if spawned: value['spawned']=True
    return value

def word(id, text, lemma=None, pos='X'): return t(id,text,lemma,pos)
def change(tokens, id, text, lemma=None, initial=None):
    result=copy.deepcopy(tokens)
    for token in result:
        if token['id']==id:
            token['text']=text
            if lemma: token['lemma']=lemma
            if initial is not None: token['initial']=initial
    return result
def ids(tokens): return [x['id'] for x in tokens]
def clean(tokens): return [{k:v for k,v in x.items() if k not in ('initial','spawned')} for x in tokens]

class B:
    def __init__(self,id,band,title,base,gloss,theme):
        self.value=dict(chainId=id,cefr=band,title={'en':title},theme=theme,terminal='.',base=dict(tokens=base,gloss={'en':gloss}),steps=[])
        self.tokens=clean(base)
    def add(self,label,tokens,gloss,fixes=None,moves=None,kind='TRANSFORM',target=None,slot='end',rules_=None,initial_order=None,terminal='.',note=None):
        fixes=fixes or {}; moves=moves or {}
        old={x['id']:x for x in self.tokens}
        direct=[x['id'] for x in tokens if x['id'] in old and (old[x['id']]['text']!=x['text'] or old[x['id']]['lemma']!=x['lemma']) and x['id'] not in fixes]
        if target and target not in direct: direct.append(target)
        deps=[]
        for id, info in fixes.items():
            tags, options=info if isinstance(info,tuple) else (info,[])
            correct=next(t['text'] for t in tokens if t['id']==id)
            deps.append(dict(token=id,rules=tags,distractors=list(dict.fromkeys(o for o in options if o!=correct))))
        step=dict(card=dict(type=kind,label=label,cardGloss={'en':gloss_card(label)},rules=rules_ or [],appliedTokens=direct,slots=[slot],slotIsTrained=False),
                  inverseLabel='Undo: '+label,tokens=tokens,fixes=deps,moves=[dict(token=k,rules=v) for k,v in moves.items()],acceptedOrders=[ids(tokens)],gloss={'en':gloss},terminal=terminal)
        if target: step['card']['target']=target
        if initial_order: step['initialOrderOfInserted']=initial_order
        if not fixes and not moves:
            step['noChangeNote']={'en':note or 'The added or replaced words do not change the grammar of the other words.'}
        self.value['steps'].append(step); self.tokens=clean(tokens)
        return self.tokens
    def finish(self):
        self.value['lemmas']=sorted({x['lemma'] for s in [self.value['base']]+self.value['steps'] for x in s['tokens'] if x['pos']!='PUNCT'})
        return self.value

def gloss_card(label):
    return {'ich → wir':'I → we','ich → du':'I → you','wir → ich':'we → I','du → wir':'you → we',
            '+ morgen':'+ tomorrow','+ heute':'+ today','+ gestern':'+ yesterday','Ask a question':'Make a yes/no question',
            'Make it future':'Say it in the future','Make it hypothetical':'Say what you would do'}.get(label,label)

R=['verb.present.regular']; V2=['order.v2-inversion']; MOD=['verb.modal.present']; BRMOD=['order.bracket.modal']
PRES=['verb.present.sein-haben']; NOM=['article.def.nom']; ACC=['article.def.acc']; INDEF=['article.indef.acc']
DAT=['prep.dative']; PDAT=['prep.dative','possessive.dat']; FINAL=['order.verb-final.subordinate']
MIX=['adj.decl.mixed']; WEAK=['adj.decl.weak']; STRONG=['adj.decl.strong']; FUT=['verb.future.werden']; WOULD=['verb.konjunktiv2.wuerde']
GEN=['noun.gender']; COORD=['conj.coordinating']; TIME=['order.time-manner-place']

READS=[('Roman','novel'),('Bericht','report'),('Brief','letter'),('Text','text'),('Artikel','article'),('Vertrag','contract'),('Plan','plan'),('Kommentar','comment'),('Blog','blog'),('Reiseführer','travel guide'),('Stadtplan','city map'),('Prospekt','brochure'),('Kalender','calendar'),('Zettel','note')]
PEOPLE=[('Freund','friend'),('Bruder','brother'),('Vater','father'),('Lehrer','teacher'),('Nachbar','neighbor'),('Kollege','colleague'),('Onkel','uncle'),('Cousin','cousin'),('Arzt','doctor'),('Gast','guest'),('Trainer','coach'),('Opa','grandfather'),('Chef','manager'),('Partner','partner')]
THINGS=[('Tisch','table','Lampe','lamp','Lampen','lamps','Stühle','chairs'),('Stuhl','chair','Tasche','bag','Taschen','bags','Koffer','suitcases'),('Schrank','wardrobe','Uhr','clock','Uhren','clocks','Regale','shelves'),('Computer','computer','Kamera','camera','Kameras','cameras','Handys','phones'),('Fernseher','television','Zeitung','newspaper','Zeitungen','newspapers','Bücher','books'),('Teppich','rug','Decke','blanket','Decken','blankets','Kissen','cushions'),('Koffer','suitcase','Jacke','jacket','Jacken','jackets','Mäntel','coats')]
SEP=[('kaufe','kaufst','kauf','kauft','einkaufen','ein','shop'),('stehe','stehst','steh','steht','aufstehen','auf','get up'),('höre','hörst','hör','hört','zuhören','zu','listen'),('mache','machst','mach','macht','mitmachen','mit','join in'),('rufe','rufst','ruf','ruft','anrufen','an','call'),('räume','räumst','räum','räumt','aufräumen','auf','tidy up'),('packe','packst','pack','packt','einpacken','ein','pack')]
ACT=[('lerne','lernen','gelernt','Deutsch','German'),('mache','machen','gemacht','Hausaufgaben','homework'),('höre','hören','gehört','Musik','music'),('koche','kochen','gekocht','Suppe','soup'),('kaufe','kaufen','gekauft','Brot','bread'),('spiele','spielen','gespielt','Tennis','tennis'),('plane','planen','geplant','Urlaub','a vacation'),('suche','suchen','gesucht','Arbeit','work'),('übe','üben','geübt','Klavier','the piano'),('male','malen','gemalt','Bilder','pictures'),('lerne','lernen','gelernt','Englisch','English'),('koche','kochen','gekocht','Reis','rice'),('höre','hören','gehört','Radio','the radio'),('kaufe','kaufen','gekauft','Obst','fruit')]
DRINKS=[('Kaffee','coffee'),('Tee','tea'),('Saft','juice'),('Kakao','cocoa'),('Apfelsaft','apple juice'),('Orangensaft','orange juice'),('Wein','wine'),('Rotwein','red wine'),('Weißwein','white wine'),('Espresso','espresso'),('Cappuccino','cappuccino'),('Früchtetee','fruit tea'),('Kräutertee','herbal tea'),('Mokka','mocha'),('Milchkaffee','coffee with milk'),('Eistee','iced tea'),('Eiskaffee','iced coffee'),('Traubensaft','grape juice'),('Tomatensaft','tomato juice'),('Bananensaft','banana juice')]
PLACES=[('Park','park','den'),('Bahnhof','station','den'),('Supermarkt','supermarket','den'),('Garten','garden','den'),('Wald','forest','den'),('Stadtpark','city park','den'),('Hafen','harbor','den'),('Flughafen','airport','den'),('Markt','market','den'),('Stadthafen','city harbor','den'),('Theater','theater','das'),('Museum','museum','das'),('Kino','cinema','das'),('Büro','office','das'),('Café','café','das'),('Hotel','hotel','das'),('Restaurant','restaurant','das'),('Schwimmbad','swimming pool','das'),('Stadion','stadium','das'),('Einkaufszentrum','shopping center','das')]
ITEMS=[('Mantel','coat'),('Pullover','sweater'),('Schal','scarf'),('Hut','hat'),('Rucksack','backpack'),('Koffer','suitcase'),('Tisch','table'),('Stuhl','chair'),('Schrank','wardrobe'),('Teppich','rug'),('Computer','computer'),('Fernseher','television'),('Drucker','printer'),('Kühlschrank','refrigerator'),('Herd','stove'),('Spiegel','mirror'),('Sessel','armchair'),('Wecker','alarm clock'),('Kalender','calendar'),('Stadtplan','city map')]
REFLEX=[('freue','freust','freuen','be happy'),('ärgere','ärgerst','ärgern','be annoyed'),('wundere','wunderst','wundern','be surprised'),('entspanne','entspannst','entspannen','relax'),('konzentriere','konzentrierst','konzentrieren','concentrate'),('rasiere','rasierst','rasieren','shave'),('wasche','wäschst','waschen','wash'),('beeile','beeilst','beeilen','hurry'),('erhole','erholst','erholen','recover'),('bedanke','bedankst','bedanken','say thank you')]

EN={
 ',':',','Abenteuerfilm':'adventure film','Apfelsaft':'apple juice','Arbeit':'work','Artikel':'article','Arzt':'doctor','Bahnhof':'station','Bananensaft':'banana juice','Bericht':'report','Berlin':'Berlin','Bilder':'pictures','Blog':'blog','Brief':'letter','Brot':'bread','Bruder':'brother','Bücher':'books','Büro':'office','Café':'café','Cappuccino':'cappuccino','Chef':'manager','Computer':'computer','Cousin':'cousin','Decke':'blanket','Deutsch':'German','Dokumentarfilm':'documentary','Drucker':'printer','Einkaufszentrum':'shopping center','Eis':'ice cream','Eiskaffee':'iced coffee','Eistee':'iced tea','Englisch':'English','Espresso':'espresso','Fernseher':'television','Film':'film','Fleisch':'meat','Flughafen':'airport','Freund':'friend','Früchtetee':'fruit tea','Garten':'garden','Gast':'guest','Gebäck':'pastries','Geld':'money','Gemüse':'vegetables','Hafen':'harbor','Handys':'phones','Haus':'home','Hausaufgaben':'homework','Herd':'stove','Hotel':'hotel','Hut':'hat','Hähnchen':'chicken','Jacke':'jacket','Kaffee':'coffee','Kakao':'cocoa','Kalender':'calendar','Kamera':'camera','Kind':'child','Kino':'cinema','Kissen':'cushion','Klavier':'piano','Koffer':'suitcase','Kollege':'colleague','Kommentar':'comment','Krimi':'crime drama','Kräutertee':'herbal tea','Kurzfilm':'short film','Kühlschrank':'refrigerator','Lampe':'lamp','Lehrer':'teacher','Liebesfilm':'romantic film','Mantel':'coat','Markt':'market','Mehl':'flour','Milchkaffee':'coffee with milk','Mokka':'mocha','Morgen':'morning','Museum':'museum','Musik':'music','Mutter':'mother','Mäntel':'coats','Müsli':'muesli','Nachbar':'neighbor','Obst':'fruit','Onkel':'uncle','Opa':'grandfather','Orangensaft':'orange juice','Park':'park','Partner':'partner','Plan':'plan','Prospekt':'brochure','Pullover':'sweater','Radio':'radio','Regale':'shelves','Reis':'rice','Reiseführer':'travel guide','Restaurant':'restaurant','Roman':'novel','Rotwein':'red wine','Rucksack':'backpack','Saft':'juice','Schal':'scarf','Schrank':'wardrobe','Schwester':'sister','Schwimmbad':'swimming pool','Sessel':'armchair','Spiegel':'mirror','Spielfilm':'feature film','Stadion':'stadium','Stadthafen':'city harbor','Stadtpark':'city park','Stadtplan':'city map','Stuhl':'chair','Stühle':'chairs','Supermarkt':'supermarket','Suppe':'soup','Tasche':'bag','Tee':'tea','Tennis':'tennis','Teppich':'rug','Text':'text','Theater':'theater','Thriller':'thriller','Tisch':'table','Tomatensaft':'tomato juice','Trainer':'coach','Traubensaft':'grape juice','Uhr':'clock','Urlaub':'vacation','Vater':'father','Vertrag':'contract','Wald':'forest','Wasser':'water','Wecker':'alarm clock','Wein':'wine','Weißwein':'white wine','Western':'western','Wetter':'weather','Zeichentrickfilm':'cartoon','Zeitung':'newspaper','Zettel':'note',
 'an':'on / attached prefix','anrufen':'call','auf':'on / up','aufräumen':'tidy up','aufstehen':'get up','bedanken':'thank','beeilen':'hurry','besuchen':'visit','bitte':'please','bleiben':'stay','dass':'that','der':'the / relative pronoun','du':'you (one person)','ein':'a','einkaufen':'shop','einpacken':'pack','empfehlen':'recommend','entspannen':'relax','er':'he / him','erholen':'recover','freuen':'be happy','freundlich':'friendly','frisch':'fresh','für':'for','gehen':'go','genug':'enough','gern':'gladly','gestern':'yesterday','groß':'large','gut':'good','haben':'have','heute':'today','hören':'listen to','ich':'I','in':'in','interessant':'interesting','jeder':'every','kaufen':'buy','kein':'no / not a','klein':'small','kochen':'cook','konzentrieren':'concentrate','können':'can / be able to','lernen':'learn','lesen':'read','machen':'do / make','malen':'paint','mein':'my','mit':'with','mitmachen':'join in','morgen':'tomorrow','müde':'tired','müssen':'must / have to','neu':'new','nicht':'not','obwohl':'although','planen':'plan','rasieren':'shave','schlecht':'bad','schön':'beautiful','sehen':'see / watch','sein':'be','sich':'oneself','sie':'she / they','spielen':'play','suchen':'look for','trinken':'drink','und':'and','vor':'in front of','warum':'why','waschen':'wash','weil':'because','wenn':'if / when','werden':'will / become','wir':'we','wissen':'know','wohnen':'live','wundern':'be surprised','würden':'would','zu':'to / attached prefix','zuhören':'listen','ärgern':'be annoyed','üben':'practice'
}

FORM_LABELS={
 'ich':'first person · singular','du':'second person · singular','wir':'first person · plural',
 'der':'masculine nominative / feminine dative','die':'feminine or plural','das':'neuter nominative / accusative','den':'masculine accusative / plural dative','dem':'masculine or neuter dative',
 'ein':'masculine nominative / neuter','einen':'masculine accusative','einem':'masculine or neuter dative','eine':'feminine nominative / accusative',
 'mein':'masculine nominative / neuter','meinen':'masculine accusative / plural dative','meinem':'masculine or neuter dative','meiner':'feminine dative','meine':'feminine or plural',
 'kein':'masculine nominative / neuter','keinen':'masculine accusative / plural dative','keinem':'masculine or neuter dative','keine':'feminine or plural',
 'bin':'ich · present','bist':'du · present','ist':'er / sie / es · present','sind':'wir / sie · present','seid':'ihr · present','waren':'wir / sie · past','war':'ich / er / sie / es · past',
 'habe':'ich · present','hast':'du · present','hat':'er / sie / es · present','haben':'infinitive / wir / sie · present','hatten':'wir / sie · past',
 'trinke':'ich · present','trinkst':'du · present','trinkt':'er / sie / es / ihr · present','trinken':'infinitive / wir / sie · present','getrunken':'past participle',
 'kann':'ich / er / sie / es · present','kannst':'du · present','können':'infinitive / wir / sie · present','muss':'ich / er / sie / es · present','musst':'du · present','musstest':'du · past','mussten':'wir / sie · past',
 'werde':'ich · present','wird':'er / sie / es · present','werden':'infinitive / wir / sie · present','würde':'ich / er / sie / es · conditional','würden':'wir / sie · conditional',
 'ihn':'masculine accusative pronoun','ihm':'masculine or neuter dative pronoun','ihnen':'plural dative pronoun','mich':'ich · reflexive accusative','dich':'du · reflexive accusative','uns':'wir · reflexive accusative'
}

def person_acc(noun): return {'Nachbar':'Nachbarn','Kollege':'Kollegen'}.get(noun,noun)

def a1_agreement(i):
    n,en=READS[i]; n2,en2=READS[(i+1)%14]
    plural=['Romane','Berichte','Briefe','Texte','Artikel','Verträge','Pläne','Kommentare','Blogs','Reiseführer','Stadtpläne','Prospekte','Kalender','Zettel'][i]
    english_plural=['novels','reports','letters','texts','articles','contracts','plans','comments','blogs','travel guides','city maps','brochures','calendars','notes'][i]
    b=B(f'de.a1.read.{i:03}','A1',f'Read a {en}',[t('s','ich','ich','PRON'),t('v','kaufe','kaufen','VERB'),t('n',plural,n,'NOUN')],f'I buy {english_plural}.',THEMES[i%12])
    x=change(change(b.tokens,'s','du','du'),'v','kaufst'); b.add('ich → du',x,f'You buy {english_plural}.',{'v':(R,['kaufe','kaufen','kauft'])},kind='SUBSTITUTE',target='s')
    x=change(b.tokens,'v','liest','lesen',initial='lesen'); b.add('kaufen → lesen',x,f'You read {english_plural}.',{'v':(['verb.present.stem-change'],['lese','lesen','lest'])},kind='SUBSTITUTE',target='v')
    x=change(b.tokens[:2]+[t('d','einen','ein','DET',initial='ein')]+b.tokens[2:],'n',n)
    fixes={'d':(INDEF,['ein','einem','eine'])}
    if plural!=n:fixes['n']=(['noun.plural'],[plural])
    b.add('+ ein · make it one',x,f'You read a {en}.',fixes,kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'You read a {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN,note=f'{n2} and {n} are both masculine. Einen stays the same.')
    x=change(b.tokens,'d','meinen','mein',initial='mein'); b.add('ein → mein',x,f'You read my {en2}.',{'d':(['possessive.acc'],['mein','meine','meinem'])},kind='SUBSTITUTE',target='d')
    x=change(b.tokens,'d','keinen','kein',initial='kein'); b.add('Negate the noun',x,f'You do not read a {en2}.',{'d':(['article.kein','neg.kein-vs-nicht'],['kein','keine','keinem'])})
    x=[t('time','heute','heute','ADV'),b.tokens[1],b.tokens[0]]+b.tokens[2:]; b.add('+ heute',x,f'Today you do not read a {en2}.',moves={'v':V2},kind='INSERT',slot='start')
    return b.finish()

def a1_modal(i):
    n,en=PEOPLE[i]; n2,en2=PEOPLE[(i+1)%14]
    b=B(f'de.a1.visit.{i:03}','A1',f'Visit your {en}',[t('s','ich','ich','PRON'),t('v','besuche','besuchen','VERB'),t('d','den','der','DET'),t('n',person_acc(n),n,'NOUN')],f'I visit the {en}.',THEMES[(i+3)%12])
    x=change(change(b.tokens,'s','du','du'),'v','besuchst'); b.add('ich → du',x,f'You visit the {en}.',{'v':(R,['besuche','besuchen','besucht'])},kind='SUBSTITUTE',target='s')
    x=[b.tokens[0],t('m','kannst','können','AUX',initial='können')]+b.tokens[2:]+[t('v','besuchen','besuchen','VERB')]
    b.add('+ können',x,f'You can visit the {en}.',{'m':(MOD,['kann','können','könnt']),'v':(BRMOD,['besuchst','besucht','besuche'])},{'v':BRMOD},kind='INSERT',slot='before:v')
    x=change(b.tokens,'n',person_acc(n2),n2); b.add(f'{n} → {n2}',x,f'You can visit the {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    x=[t('n','ihn','er','PRON',initial='er') if z['id']=='n' else z for z in b.tokens if z['id']!='d']; b.add('Replace the person with a pronoun',x,'You can visit him.',{'n':(['pronoun.personal.acc','article.def.acc'],['er','ihm','sie'])})
    x=[t('time','morgen','morgen','ADV'),b.tokens[1],b.tokens[0]]+b.tokens[2:]; b.add('+ morgen',x,'Tomorrow you can visit him.',moves={'m':V2},kind='INSERT',slot='start')
    x=[b.tokens[1],b.tokens[2],b.tokens[0]]+b.tokens[3:]; b.add('Ask a question',x,'Can you visit him tomorrow?',moves={'m':['order.question.yes-no'],'time':['order.question.yes-no']},terminal='?')
    return b.finish()

def a1_nouns(i):
    a,ae,n,ne,plural,pe,other,oe=THINGS[i%7]; adjective='neu' if i<7 else 'schön'; adj_en='new' if i<7 else 'beautiful'
    b=B(f'de.a1.home.{i:03}','A1',f'The {ne} is {adj_en}',[t('d','der','der','DET'),t('n',a,a,'NOUN'),t('v','ist','sein','AUX'),t('adj',adjective,adjective,'ADJ')],f'The {ae} is {adj_en}.','home')
    x=change(change(b.tokens,'n',n,n),'d','die'); b.add(f'{a} → {n}',x,f'The {ne} is {adj_en}.',{'d':(NOM,['der','das','den'])},kind='SUBSTITUTE',target='n')
    x=change(change(b.tokens,'n',plural,n),'v','sind'); b.add('Make it plural',x,f'The {pe} are {adj_en}.',{'n':(['noun.plural'],[n]),'v':(PRES,['ist','sein','seid'])})
    other_lemma={'Stühle':'Stuhl','Regale':'Regal','Handys':'Handy','Bücher':'Buch','Mäntel':'Mantel'}.get(other,other)
    x=b.tokens[:2]+[t('and','und','und','CCONJ'),t('d2','die','der','DET'),t('n2',other,other_lemma,'NOUN')]+b.tokens[2:]; b.add(f'+ und die {other}',x,f'The {pe} and {oe} are {adj_en}.',kind='INSERT',slot='before:v',rules_=COORD)
    x=[t('time','heute','heute','ADV'),b.tokens[-2]]+b.tokens[:-2]+[b.tokens[-1]]; b.add('+ heute',x,f'Today the {pe} and {oe} are {adj_en}.',moves={'v':V2},kind='INSERT',slot='start')
    x=change(b.tokens,'adj','nicht','nicht'); x.append(t('adj2',adjective,adjective,'ADJ')); b.add('Negate the description',x,f'Today the {pe} and {oe} are not {adj_en}.',{'adj':(['neg.kein-vs-nicht'],[adjective,'kein'])})
    x=change(b.tokens,'time','warum','warum'); b.add('Ask why',x,f'Why are the {pe} and {oe} not {adj_en}?',{'time':(['order.question.w'],['wer','was','wie'])},terminal='?')
    return b.finish()

def a1_separable(i):
    first,du,imp,group,lemma,prefix,en=SEP[i%7]; time='morgen' if i<7 else 'heute'; engtime='tomorrow' if i<7 else 'today'
    b=B(f'de.a1.routine.{i:03}','A1',f'{en.capitalize()} {engtime}',[t('s','ich','ich','PRON'),t('v',first,lemma,'VERB'),t('p',prefix,prefix,'PART')],f'I {en}.',THEMES[(i+1)%12])
    x=change(change(b.tokens,'s','du','du'),'v',du); b.add('ich → du',x,f'You {en}.',{'v':(['verb.separable.present','order.separable-prefix-end','verb.present.regular'],[first,group])},kind='SUBSTITUTE',target='s')
    x=[t('time',time,time,'ADV'),b.tokens[1],b.tokens[0],b.tokens[2]]; b.add('+ '+time,x,f'{engtime.capitalize()} you {en}.',moves={'v':V2},kind='INSERT',slot='start')
    x=[b.tokens[1],b.tokens[2],b.tokens[0],b.tokens[3]]; b.add('Ask a question',x,f'Do you {en} {engtime}?',moves={'v':['order.question.yes-no'],'time':['order.question.yes-no']},terminal='?')
    x=change([z for z in b.tokens if z['id']!='s'],'v',imp); b.add('Make a request to one person',x,f'{en.capitalize()} {engtime}!',{'v':(['verb.imperative'],[du,group,first])},terminal='!')
    x=change(b.tokens,'v',group); b.add('Address a group',x,f'Everyone, {en} {engtime}!',{'v':(['verb.imperative'],[imp,du,first])},terminal='!')
    x=b.tokens[:-1]+[t('please','bitte','bitte','ADV')]+b.tokens[-1:]; b.add('+ bitte',x,f'Everyone, please {en} {engtime}!',kind='INSERT',slot='before:p',rules_=['verb.imperative'],terminal='!',note='Bitte makes the request polite. The imperative and detached prefix do not change.')
    return b.finish()

def a1_perfect(i):
    first,lemma,part,obj,eng=ACT[i]
    b=B(f'de.a1.past.{i:03}','A1',f'A little {eng}',[t('s','ich','ich','PRON'),t('v',first,lemma,'VERB'),t('n',obj,obj,'NOUN')],f'I {lemma_en(lemma)} {eng}.',THEMES[(i+4)%12])
    x=change(change(b.tokens,'s','wir','wir'),'v',lemma); b.add('ich → wir',x,f'We {lemma_en(lemma)} {eng}.',{'v':(R,[first,lemma[:-2]+'t'])},kind='SUBSTITUTE',target='s')
    x=[b.tokens[0],t('v','haben','haben','AUX'),t('time','gestern','gestern','ADV'),b.tokens[2],t('p',part,lemma,'VERB',initial=lemma,spawned=True)]
    b.add('+ gestern · conversational past',x,f'Yesterday we {past_en(lemma)} {eng}.',{'v':(['verb.perfekt.haben'],[lemma,'sind','hatten']),'p':(['verb.participle.regular'],[lemma,first])},{'p':['order.bracket.perfekt']},kind='INSERT',slot='after:v')
    x=b.tokens[:3]+[t('at','zu','zu','ADP'),t('home','Hause','Haus','NOUN')]+b.tokens[3:]; b.add('+ zu Hause',x,f'Yesterday we {past_en(lemma)} {eng} at home.',kind='INSERT',slot='after:time',rules_=['order.bracket.perfekt'])
    x=[b.tokens[1],b.tokens[0],b.tokens[2]]+b.tokens[3:]; b.add('Ask a question',x,f'Did we {lemma_en(lemma)} {eng} at home yesterday?',moves={'v':['order.question.yes-no']},terminal='?')
    x=change([z for z in b.tokens if z['id'] not in ('time','p')],'v',lemma,lemma); b.add('Return to the present',x,f'Do we {lemma_en(lemma)} {eng} at home?',{'v':(R,[first,lemma[:-2]+'t'])},kind='DELETE',terminal='?')
    x=change(change(b.tokens,'s','ich','ich'),'v',first); b.add('wir → ich',x,f'Do I {lemma_en(lemma)} {eng} at home?',{'v':(R,[lemma,lemma[:-2]+'t'])},kind='SUBSTITUTE',target='s',terminal='?')
    return b.finish()

def lemma_en(v): return dict(lernen='learn',machen='do',hören='listen to',kochen='cook',kaufen='buy',spielen='play',planen='plan',suchen='look for',üben='practice',malen='paint')[v]
def past_en(v): return dict(lernen='learned',machen='did',hören='listened to',kochen='cooked',kaufen='bought',spielen='played',planen='planned',suchen='looked for',üben='practiced',malen='painted')[v]

def a2_cafe(i):
    n,en=DRINKS[i]; n2,en2=DRINKS[(i+1)%20]
    b=B(f'de.a2.cafe.{i:03}','A2',f'Morning {en2}',[t('s','ich','ich','PRON'),t('v','trinke','trinken','VERB'),t('n',n,n,'NOUN')],f'I drink {en}.','cafe')
    x=change(change(b.tokens,'s','wir','wir'),'v','trinken'); b.add('ich → wir',x,f'We drink {en}.',{'v':(R,['trinke','trinkt','trinkst'])},kind='SUBSTITUTE',target='s')
    x=b.tokens[:2]+[t('d','einen','ein','DET',initial='ein'),t('a','großen','groß','ADJ',initial='groß')]+b.tokens[2:]; b.add('+ ein · groß',x,f'We have a large {en}.',{'d':(INDEF,['ein','einem','eine']),'a':(MIX,['großer','großem','große'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'We have a large {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    x=[t('time','jeden','jeder','DET'),t('morning','Morgen','Morgen','NOUN'),b.tokens[1],b.tokens[0]]+b.tokens[2:]; b.add('+ jeden Morgen',x,f'Every morning we have a large {en2}.',moves={'v':V2},kind='INSERT',slot='start')
    x=change(change(b.tokens,'time','gestern','gestern'),'v','haben','haben')+[t('p','getrunken','trinken','VERB',initial='trinken',spawned=True)]
    b.add('jeden → gestern',x,f'Yesterday morning we had a large {en2}.',{'v':(['verb.perfekt.haben'],['trinken','sind','hatten']),'p':(['verb.participle.irregular'],['trinken','trank','tranken'])},{'p':['order.bracket.perfekt']},kind='SUBSTITUTE',target='time')
    x=b.tokens[:4]+[t('mit','mit','mit','ADP'),t('pd','meiner','mein','DET',initial='meine'),t('person','Schwester','Schwester','NOUN')]+b.tokens[4:]; b.add('+ mit · meine Schwester',x,f'Yesterday morning we had a large {en2} with my sister.',{'pd':(PDAT,['meine','meinen','meinem'])},kind='INSERT',slot='after:s')
    clause=[t('comma',',',',','PUNCT'),t('conj','weil','weil','SCONJ'),t('cs','wir','wir','PRON'),t('ca','müde','müde','ADJ'),t('cv','waren','sein','AUX',initial='sein')]
    x=b.tokens+clause; b.add('+ weil · wir · sein · müde',x,f'Yesterday morning we had a large {en2} with my sister because we were tired.',{'cv':(['verb.praeteritum.sein-haben'],['sind','war','sein'])},{'cv':FINAL},kind='INSERT',rules_=['conj.weil'],initial_order=['comma','conj','cs','cv','ca'])
    return b.finish()

def a2_travel(i):
    n,en,article=PLACES[i]; other,otheren,_=PLACES[(i+1)%10 if i<10 else 10+(i+1)%10]
    b=B(f'de.a2.travel.{i:03}','A2',f'An afternoon at the {en}',[t('s','wir','wir','PRON'),t('v','gehen','gehen','VERB'),t('in','in','in','ADP'),t('d',article,'der','DET'),t('n',n,n,'NOUN')],f'We go into the {en}.','travel')
    x=change(change(b.tokens,'v','bleiben','bleiben'),'d','dem'); b.add('gehen → bleiben · stay there',x,f'We stay in the {en}.',{'d':(['prep.two-way','article.def.dat'],[article,'der','die'])},kind='SUBSTITUTE',target='v')
    x=change(b.tokens,'n',other,other); b.add(f'{n} → {other}',x,f'We stay in the {otheren}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    x=change([z for z in b.tokens if z['id']!='d'],'in','im',initial='in'); b.add('Contract in dem',x,f'We stay in the {otheren}.',{'in':(['prep.contraction'],['in','ins','am'])})
    x=[b.tokens[0],t('v','sind','sein','AUX'),t('time','gestern','gestern','ADV')]+b.tokens[2:]+[t('p','geblieben','bleiben','VERB',initial='bleiben',spawned=True)]
    b.add('+ gestern · conversational past',x,f'Yesterday we stayed in the {otheren}.',{'v':(['verb.perfekt.sein'],['haben','bleiben','waren']),'p':(['verb.participle.irregular'],['bleiben','blieb','bleibt'])},{'p':['order.bracket.perfekt']},kind='INSERT',slot='after:v')
    x=b.tokens[:3]+[t('mit','mit','mit','ADP'),t('fd','den','der','DET',initial='die'),t('friends','Freunden','Freund','NOUN',initial='Freunde')]+b.tokens[3:]
    b.add('+ mit · die Freunde',x,f'Yesterday we stayed in the {otheren} with friends.',{'fd':(['prep.dative','article.def.dat'],['die','der','dem']),'friends':(['noun.dative-plural-n'],['Freunde','Freund'])},kind='INSERT',slot='after:time')
    x=change([z for z in b.tokens if z['id']!='fd'],'friends','ihnen','sie',initial='sie'); b.add('Replace the friends with a pronoun',x,f'Yesterday we stayed in the {otheren} with them.',{'friends':(['pronoun.personal.dat'],['sie','ihr','ihm'])})
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='in'); x=b.tokens[:at]+[t('neg','nicht','nicht','ADV')]+b.tokens[at:]; b.add('+ nicht · negate the location',x,f'Yesterday we did not stay in the {otheren} with them.',moves={'neg':['order.negation.nicht']},kind='INSERT',slot='end')
    prefix=[t('ms','ich','ich','PRON'),t('mv','weiß','wissen','VERB'),t('comma',',',',','PUNCT'),t('conj','dass','dass','SCONJ')]
    x=prefix+[z for z in b.tokens if z['id']!='v']+[next(z for z in b.tokens if z['id']=='v')]; b.add('+ ich weiß, dass …',x,f'I know that yesterday we did not stay in the {otheren} with them.',moves={'v':FINAL},kind='INSERT',slot='start',rules_=['conj.dass'])
    return b.finish()

def a2_shopping(i):
    n,en=ITEMS[i]; n2,en2=ITEMS[(i+1)%20]
    b=B(f'de.a2.shop.{i:03}','A2',f'Choose a {en}',[t('s','ich','ich','PRON'),t('v','kaufe','kaufen','VERB'),t('d','den','der','DET'),t('n',n,n,'NOUN')],f'I buy the {en}.','shopping')
    x=b.tokens[:3]+[t('a','neuen','neu','ADJ',initial='neu')]+b.tokens[3:]; b.add('+ neu',x,f'I buy the new {en}.',{'a':(WEAK,['neue','neuer','neuem'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'d','einen','ein',initial='ein'); b.add('der → ein',x,f'I buy a new {en}.',{'d':(INDEF,['ein','eine','einem'])},kind='SUBSTITUTE',target='d')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'I buy a new {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    x=change(b.tokens,'a','besseren','gut',initial='besser'); b.add('neu → besser',x,f'I buy a better {en2}.',{'a':(['adj.comparative','adj.decl.mixed'],['besser','bessere','besserem'])},kind='SUBSTITUTE',target='a')
    x=b.tokens+[t('for','für','für','ADP'),t('pd','meinen','mein','DET',initial='mein'),t('person','Bruder','Bruder','NOUN')]; b.add('+ für · mein Bruder',x,f'I buy a better {en2} for my brother.',{'pd':(['prep.accusative','possessive.acc'],['mein','meine','meinem'])},kind='INSERT')
    x=change(change(b.tokens,'s','wir','wir'),'v','kaufen'); b.add('ich → wir',x,f'We buy a better {en2} for my brother.',{'v':(R,['kaufe','kauft','kaufst'])},kind='SUBSTITUTE',target='s')
    clause=[t('comma',',',',','PUNCT'),t('conj','wenn','wenn','SCONJ'),t('cs','ich','ich','PRON'),t('enough','genug','genug','ADV'),t('money','Geld','Geld','NOUN'),t('cv','habe','haben','AUX',initial='haben')]
    x=b.tokens+clause; b.add('+ wenn · ich · haben · genug Geld',x,f'We buy a better {en2} for my brother if I have enough money.',{'cv':(PRES,['haben','hat','hast'])},{'cv':FINAL},kind='INSERT',rules_=['conj.wenn'],initial_order=['comma','conj','cs','cv','enough','money'])
    x=change(b.tokens,'d','keinen','kein',initial='kein'); b.add('Negate the purchase',x,f'We do not buy a better {en2} for my brother if I have enough money.',{'d':(['article.kein','neg.kein-vs-nicht'],['kein','keine','keinem'])})
    return b.finish()

def a2_reflexive(i):
    first,du,lemma,en=REFLEX[i%10]; time='heute' if i<10 else 'morgen'; et='today' if i<10 else 'tomorrow'
    b=B(f'de.a2.feeling.{i:03}','A2',f'Time to {en}',[t('s','ich','ich','PRON'),t('v',first,lemma,'VERB'),t('r','mich','sich','PRON')],f'I {en}.','health')
    x=change(change(change(b.tokens,'s','du','du'),'v',du),'r','dich'); b.add('ich → du',x,f'You {en}.',{'v':(R,[first,lemma]),'r':(['verb.reflexive'],['mich','sich','uns'])},kind='SUBSTITUTE',target='s')
    x=[b.tokens[0],t('m','musst','müssen','AUX',initial='müssen'),b.tokens[2],t('v',lemma,lemma,'VERB')]; b.add('+ müssen',x,f'You have to {en}.',{'m':(MOD,['muss','müssen','müsst']),'v':(BRMOD,[first,du])},{'v':BRMOD},kind='INSERT',slot='before:v')
    x=change(b.tokens,'m','musstest'); b.add('Put the obligation in the past',x,f'You had to {en}.',{'m':(['verb.praeteritum.modal'],['musst','musste','mussten'])})
    x=b.tokens[:3]+[t('mit','mit','mit','ADP'),t('pd','meiner','mein','DET',initial='meine'),t('person','Schwester','Schwester','NOUN')]+b.tokens[3:]; b.add('+ mit · meine Schwester',x,f'You had to {en} with my sister.',{'pd':(PDAT,['meine','meinen','meinem'])},kind='INSERT',slot='after:r')
    # Past-time adverbs avoid a future/past contradiction in the second variation.
    time='heute' if i<10 else 'gestern'; et='today' if i<10 else 'yesterday'
    x=[t('time',time,time,'ADV'),b.tokens[1],b.tokens[0]]+b.tokens[2:]; b.add('+ '+time,x,f'{et.capitalize()} you had to {en} with my sister.',moves={'m':V2},kind='INSERT',slot='start')
    x=change(change(change(b.tokens,'s','wir','wir'),'m','mussten'),'r','uns'); b.add('du → wir',x,f'{et.capitalize()} we had to {en} with my sister.',{'m':(['verb.praeteritum.modal'],['musstest','musste','müssen']),'r':(['verb.reflexive'],['mich','dich','sich'])},kind='SUBSTITUTE',target='s')
    x=change(b.tokens,'person','Mutter','Mutter'); b.add('Schwester → Mutter',x,f'{et.capitalize()} we had to {en} with my mother.',kind='SUBSTITUTE',target='person',rules_=GEN)
    return b.finish()

def a2_home(i):
    place,en,_=PLACES[i]; person='Kinder' if i<10 else 'Freunde'; single='Kind' if i<10 else 'Freund'; art='das' if i<10 else 'der'; pe='children' if i<10 else 'friends'; se='child' if i<10 else 'friend'
    b=B(f'de.a2.outside.{i:03}','A2',f'The {pe} in the {en}',[t('d',art,'der','DET'),t('n',single,single,'NOUN'),t('v','spielt','spielen','VERB'),t('in','in','in','ADP'),t('pd','dem','der','DET'),t('place',place,place,'NOUN')],f'The {se} plays in the {en}.','family')
    x=change(b.tokens,'in','vor','vor'); b.add('in → vor · same location case',x,f'The {se} plays in front of the {en}.',kind='SUBSTITUTE',target='in',rules_=['prep.two-way'],note='Both phrases describe a location, so both use the dative.')
    x=change(change(change(b.tokens,'d','die'),'n',person),'v','spielen'); b.add('Make the subject plural',x,f'The {pe} play in front of the {en}.',{'d':(NOM,[art,'den','dem']),'n':(['noun.plural'],[single]),'v':(R,['spielt','spiele'])})
    x=[b.tokens[0],t('a','kleinen','klein','ADJ',initial='klein')]+b.tokens[1:]; b.add('+ klein',x,f'The small {pe} play in front of the {en}.',{'a':(WEAK,['kleine','kleiner','kleinem'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'pd','einem','ein',initial='ein'); b.add('der → ein · keep the location',x,f'The small {pe} play in front of a {en}.',{'pd':(['article.def.dat','prep.two-way'],['ein','einen','eine'])},kind='SUBSTITUTE',target='pd')
    x=change(b.tokens,'a','kleineren',initial='kleiner'); b.add('klein → kleiner',x,f'The smaller {pe} play in front of a {en}.',{'a':(['adj.comparative','adj.decl.weak'],['kleiner','kleinere','kleinerem'])},kind='SUBSTITUTE',target='a')
    x=b.tokens[:4]+[t('mit','mit','mit','ADP'),t('md','meinem','mein','DET',initial='mein'),t('person','Bruder','Bruder','NOUN')]+b.tokens[4:]; b.add('+ mit · mein Bruder',x,f'The smaller {pe} play with my brother in front of a {en}.',{'md':(PDAT,['mein','meinen','meiner'])},kind='INSERT',slot='after:v')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='in'); x=b.tokens[:at]+[t('neg','nicht','nicht','ADV')]+b.tokens[at:]; b.add('+ nicht · negate the place',x,f'The smaller {pe} do not play with my brother in front of a {en}.',moves={'neg':['order.negation.nicht']},kind='INSERT',slot='end')
    return b.finish()

def add_future(b, gloss, conditional=False):
    target='würden' if conditional else 'werden'; rule=WOULD if conditional else FUT
    oldverb=next(z for z in b.tokens if z['id']=='v'); s=next(z for z in b.tokens if z['id']=='s')['text']
    if s=='ich': target='würde' if conditional else 'werde'
    x=change(b.tokens,'v',target,'werden')+[t('inf',oldverb['lemma'],oldverb['lemma'],'VERB',initial=oldverb['lemma'],spawned=True)]
    b.add('Make it hypothetical' if conditional else 'Make it future',x,gloss,{'v':(rule,['würde','würden','würdest'] if target=='werden' else ['werden','wird','wirst']),'inf':(rule,[oldverb['text']])},{'inf':rule})

def add_time(b, gloss):
    v=next(z for z in b.tokens if z['id']=='v'); s=next(z for z in b.tokens if z['id']=='s')
    x=[t('time','morgen','morgen','ADV'),v,s]+[z for z in b.tokens if z['id'] not in ('v','s')]
    b.add('+ morgen',x,gloss,moves={'v':V2},kind='INSERT',slot='start')

def add_obwohl(b, gloss):
    clause=[t('oc',',',',','PUNCT'),t('ob','obwohl','obwohl','SCONJ'),t('od','das','der','DET'),t('on','Wetter','Wetter','NOUN'),t('oa','schlecht','schlecht','ADJ'),t('ov','ist','sein','AUX',initial='sein')]
    b.add('+ obwohl · das Wetter · sein · schlecht',b.tokens+clause,gloss,{'ov':(PRES,['sind','war','sein'])},{'ov':FINAL},kind='INSERT',rules_=['conj.obwohl'],initial_order=['oc','ob','od','on','ov','oa'])

def b1_future(i):
    n,en=PEOPLE[i]
    b=B(f'de.b1.future.{i:03}','B1',f'Plans with your {en}',[t('s','wir','wir','PRON'),t('v','besuchen','besuchen','VERB'),t('d','den','der','DET'),t('n',person_acc(n),n,'NOUN')],f'We visit the {en}.','plans')
    add_time(b,f'Tomorrow we visit the {en}.'); add_future(b,f'Tomorrow we will visit the {en}.')
    n2,en2=PEOPLE[(i+1)%14]; x=change(b.tokens,'n',person_acc(n2),n2); b.add(f'{n} → {n2}',x,f'Tomorrow we will visit the {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='d'); x=b.tokens[:at]+[t('mit','mit','mit','ADP'),t('md','meiner','mein','DET',initial='meine'),t('mn','Schwester','Schwester','NOUN')]+b.tokens[at:]; b.add('+ mit · meine Schwester',x,f'Tomorrow we will visit the {en2} with my sister.',{'md':(PDAT,['meine','meinen','meinem'])},kind='INSERT',slot='after:s')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='mit'); x=b.tokens[:at]+[t('gern','gern','gern','ADV')]+b.tokens[at:]; b.add('+ gern · in neutral order',x,f'Tomorrow we will gladly visit the {en2} with my sister.',moves={'gern':TIME},kind='INSERT',slot='end')
    add_obwohl(b,f'Tomorrow we will gladly visit the {en2} with my sister although the weather is bad.')
    x=change(change(b.tokens,'s','ich','ich'),'v','werde'); b.add('wir → ich',x,f'Tomorrow I will gladly visit the {en2} with my sister although the weather is bad.',{'v':(FUT,['werden','wird','wirst'])},kind='SUBSTITUTE',target='s')
    return b.finish()

def b1_would(i):
    n,en=DRINKS[i]; n2,en2=DRINKS[(i+1)%20]
    b=B(f'de.b1.wish.{i:03}','B1',f'A wish for {en}',[t('s','wir','wir','PRON'),t('v','trinken','trinken','VERB'),t('n',n,n,'NOUN')],f'We drink {en}.','cafe')
    add_future(b,f'We would drink {en}.',True)
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='n'); x=b.tokens[:at]+[t('a','frischen','frisch','ADJ',initial='frisch')]+b.tokens[at:]; b.add('+ frisch · no article',x,f'We would drink fresh {en}.',{'a':(STRONG,['frischer','frischem','frische'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'We would drink fresh {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    clause=[t('rc',',',',','PUNCT'),t('rp','den','der','PRON',initial='der'),t('rs','du','du','PRON'),t('rv','empfohlen','empfehlen','VERB'),t('ra','hast','haben','AUX')]
    b.add('+ relative clause · you recommended it',b.tokens+clause,f'We would drink fresh {en2} that you recommended.',{'rp':(['relative.clause','article.def.acc'],['der','dem','das'])},{'ra':FINAL},kind='INSERT',initial_order=['rc','rp','rs','ra','rv'])
    add_time(b,f'Tomorrow we would drink fresh {en2} that you recommended.')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='a'); x=b.tokens[:at]+[t('im','im','in','ADP',initial='in'),t('place','Café','Café','NOUN')]+b.tokens[at:]; b.add('+ in dem Café · contract it',x,f'Tomorrow, at the café, we would drink fresh {en2} that you recommended.',{'im':(['prep.contraction'],['in','ins','am'])},kind='INSERT',slot='before:a')
    x=change(change(b.tokens,'s','ich','ich'),'v','würde'); b.add('wir → ich',x,f'Tomorrow, at the café, I would drink fresh {en2} that you recommended.',{'v':(WOULD,['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
    return b.finish()

def b1_relative(i):
    n,en=PEOPLE[i]; n2,en2=PEOPLE[(i+2)%14]
    b=B(f'de.b1.relative.{i:03}','B1',f'The {en} in Berlin',[t('s','wir','wir','PRON'),t('v','besuchen','besuchen','VERB'),t('d','den','der','DET'),t('n',person_acc(n),n,'NOUN')],f'We visit the {en}.','city')
    x=b.tokens[:3]+[t('a','freundlichen','freundlich','ADJ',initial='freundlich')]+b.tokens[3:]; b.add('+ freundlich',x,f'We visit the friendly {en}.',{'a':(WEAK,['freundliche','freundlicher','freundlichem'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',person_acc(n2),n2); b.add(f'{n} → {n2}',x,f'We visit the friendly {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    add_future(b,f'We will visit the friendly {en2}.')
    clause=[t('rc',',',',','PUNCT'),t('rp','der','der','PRON',initial='den'),t('rin','in','in','ADP'),t('city','Berlin','Berlin','NOUN'),t('rv','wohnt','wohnen','VERB')]
    b.add('+ relative clause · he lives in Berlin',b.tokens+clause,f'We will visit the friendly {en2} who lives in Berlin.',{'rp':(['relative.clause'],['den','dem','das'])},{'rv':FINAL},kind='INSERT',initial_order=['rc','rp','rv','rin','city'])
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='d'); x=b.tokens[:at]+[t('mit','mit','mit','ADP'),t('fresh','frischem','frisch','ADJ',initial='frisch'),t('coffee','Kaffee','Kaffee','NOUN')]+b.tokens[at:]; b.add('+ mit · frisch Kaffee',x,f'We will bring fresh coffee when we visit the friendly {en2} who lives in Berlin.',{'fresh':(['adj.decl.strong','prep.dative'],['frischen','frischer','frische'])},kind='INSERT',slot='after:v')
    add_time(b,f'Tomorrow we will bring fresh coffee when we visit the friendly {en2} who lives in Berlin.')
    x=change(change(b.tokens,'s','ich','ich'),'v','werde'); b.add('wir → ich',x,f'Tomorrow I will bring fresh coffee when I visit the friendly {en2} who lives in Berlin.',{'v':(FUT,['werden','wird','wirst'])},kind='SUBSTITUTE',target='s')
    return b.finish()

def b1_obwohl(i):
    act,lemma,part,obj,en=ACT[i]
    b=B(f'de.b1.despite.{i:03}','B1',f'{en.capitalize()}, despite the weather',[t('s','wir','wir','PRON'),t('v',lemma,lemma,'VERB'),t('n',obj,obj,'NOUN')],f'We {lemma_en(lemma)} {en}.','weather')
    add_future(b,f'We would {lemma_en(lemma)} {en}.',True)
    add_time(b,f'Tomorrow we would {lemma_en(lemma)} {en}.')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='inf')+1
    x=b.tokens[:at]+[t('and','und','und','CCONJ'),t('read','lesen','lesen','VERB')]+b.tokens[at:]; b.add('+ und lesen',x,f'Tomorrow we would {lemma_en(lemma)} {en} and read.',kind='INSERT',slot='after:inf',rules_=COORD,note='The two infinitives share würden. Und does not change their forms.')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='n'); x=b.tokens[:at]+[t('mit','mit','mit','ADP'),t('md','meiner','mein','DET',initial='mein'),t('mn','Schwester','Schwester','NOUN')]+b.tokens[at:]; b.add('+ mit · mein Schwester',x,f'Tomorrow we would {lemma_en(lemma)} {en} and read with my sister.',{'md':(PDAT,['mein','meine','meinem'])},kind='INSERT',slot='after:s')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='mit'); x=b.tokens[:at]+[t('gern','gern','gern','ADV')]+b.tokens[at:]; b.add('+ gern · neutral order',x,f'Tomorrow we would gladly {lemma_en(lemma)} {en} and read with my sister.',moves={'gern':TIME},kind='INSERT',slot='end')
    add_obwohl(b,f'Tomorrow we would gladly {lemma_en(lemma)} {en} and read with my sister although the weather is bad.')
    x=change(change(b.tokens,'s','ich','ich'),'v','würde'); b.add('wir → ich',x,f'Tomorrow I would gladly {lemma_en(lemma)} {en} and read with my sister although the weather is bad.',{'v':(WOULD,['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
    return b.finish()

def b1_strong(i):
    foods=[('Brot','bread'),('Obst','fruit'),('Gemüse','vegetables'),('Fleisch','meat'),('Wasser','water'),('Gebäck','pastries'),('Eis','ice cream'),('Müsli','muesli'),('Mehl','flour'),('Hähnchen','chicken')]
    n,en=foods[i]; n2,en2=foods[(i+1)%10]
    b=B(f'de.b1.market.{i:03}','B1',f'Fresh {en} at the market',[t('s','ich','ich','PRON'),t('v','kaufe','kaufen','VERB'),t('n',n,n,'NOUN')],f'I buy {en}.','food')
    x=change(change(b.tokens,'s','wir','wir'),'v','kaufen'); b.add('ich → wir',x,f'We buy {en}.',{'v':(R,['kaufe','kauft','kaufst'])},kind='SUBSTITUTE',target='s')
    x=b.tokens[:2]+[t('a','frisches','frisch','ADJ',initial='frisch')]+b.tokens[2:]; b.add('+ frisch · no article',x,f'We buy fresh {en}.',{'a':(STRONG,['frischer','frischen','frischem'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'We buy fresh {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    add_future(b,f'We will buy fresh {en2}.'); add_time(b,f'Tomorrow we will buy fresh {en2}.')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='a'); x=b.tokens[:at]+[t('for','für','für','ADP'),t('md','meine','mein','DET',initial='mein'),t('mn','Mutter','Mutter','NOUN')]+b.tokens[at:]; b.add('+ für · mein Mutter',x,f'Tomorrow we will buy fresh {en2} for my mother.',{'md':(['prep.accusative','possessive.acc'],['mein','meinen','meiner'])},kind='INSERT',slot='after:s')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='a'); group=[t('at','auf','auf','ADP'),t('d','dem','der','DET'),t('place','Markt','Markt','NOUN')]; x=b.tokens[:at]+group+b.tokens[at:]; b.add('+ auf dem Markt · neutral order',x,f'Tomorrow we will buy fresh {en2} for my mother at the market.',moves={k:TIME for k in ['at','d','place']},kind='INSERT',slot='end')
    return b.finish()

def b1_planning(i):
    n,en=PEOPLE[i]
    b=B(f'de.b1.weekend.{i:03}','B1',f'A weekend with your {en}',[t('s','wir','wir','PRON'),t('v','besuchen','besuchen','VERB'),t('d','meinen','mein','DET'),t('n',person_acc(n),n,'NOUN')],f'We visit my {en}.','free-time')
    add_future(b,f'We would visit my {en}.',True); add_time(b,f'Tomorrow we would visit my {en}.')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='inf'); x=b.tokens[:at]+[t('and','und','und','CCONJ'),t('sd','meine','mein','DET'),t('sister','Schwester','Schwester','NOUN')]+b.tokens[at:]; b.add('+ und meine Schwester',x,f'Tomorrow we would visit my {en} and my sister.',kind='INSERT',slot='before:inf',rules_=COORD)
    clause=[t('rc',',',',','PUNCT'),t('rp','die','der','PRON',initial='der'),t('rin','in','in','ADP'),t('city','Berlin','Berlin','NOUN'),t('rv','wohnt','wohnen','VERB')]
    b.add('+ relative clause · she lives in Berlin',b.tokens+clause,f'Tomorrow we would visit my {en} and my sister, who lives in Berlin.',{'rp':(['relative.clause'],['der','den','dem'])},{'rv':FINAL},kind='INSERT',initial_order=['rc','rp','rv','rin','city'])
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='d'); x=b.tokens[:at]+[t('mit','mit','mit','ADP'),t('fresh','frischem','frisch','ADJ',initial='frisch'),t('coffee','Kaffee','Kaffee','NOUN')]+b.tokens[at:]; b.add('+ mit · frisch Kaffee',x,f'Tomorrow we would bring fresh coffee when visiting my {en} and my sister, who lives in Berlin.',{'fresh':(['adj.decl.strong','prep.dative'],['frischer','frischen','frische'])},kind='INSERT',slot='after:s')
    at=next(k for k,z in enumerate(b.tokens) if z['id']=='mit'); x=b.tokens[:at]+[t('gern','gern','gern','ADV')]+b.tokens[at:]; b.add('+ gern · neutral order',x,f'Tomorrow we would gladly bring fresh coffee when visiting my {en} and my sister, who lives in Berlin.',moves={'gern':TIME},kind='INSERT',slot='end')
    x=change(change(b.tokens,'s','ich','ich'),'v','würde'); b.add('wir → ich',x,f'Tomorrow I would gladly bring fresh coffee when visiting my {en} and my sister, who lives in Berlin.',{'v':(WOULD,['würden','würdest','würdet'])},kind='SUBSTITUTE',target='s')
    return b.finish()

def b1_story(i):
    films=[('Film','film'),('Dokumentarfilm','documentary'),('Krimi','crime drama'),('Zeichentrickfilm','cartoon'),('Spielfilm','feature film'),('Kurzfilm','short film'),('Thriller','thriller'),('Liebesfilm','romantic film'),('Abenteuerfilm','adventure film'),('Western','western')]
    n,en=films[i]; n2,en2=films[(i+1)%10]
    b=B(f'de.b1.film.{i:03}','B1',f'The {en} you recommended',[t('s','wir','wir','PRON'),t('v','sehen','sehen','VERB'),t('d','den','der','DET'),t('n',n,n,'NOUN')],f'We watch the {en}.','free-time')
    x=change(b.tokens,'v','haben','haben')+[t('p','gesehen','sehen','VERB',initial='sehen',spawned=True)]; b.add('Use the conversational past',x,f'We watched the {en}.',{'v':(['verb.perfekt.haben'],['sehen','sind','hatten']),'p':(['verb.participle.irregular'],['sehen','sah','seht'])},{'p':['order.bracket.perfekt']})
    x=b.tokens[:3]+[t('a','interessanten','interessant','ADJ',initial='interessant')]+b.tokens[3:]; b.add('+ interessant',x,f'We watched the interesting {en}.',{'a':(WEAK,['interessante','interessanter','interessantem'])},kind='INSERT',slot='before:n')
    x=change(b.tokens,'n',n2,n2); b.add(f'{n} → {n2}',x,f'We watched the interesting {en2}.',kind='SUBSTITUTE',target='n',rules_=GEN)
    x=change([z for z in b.tokens if z['id']!='p'],'v','werden','werden')+[t('inf','sehen','sehen','VERB',initial='sehen',spawned=True)]; b.add('Make it future',x,f'We will watch the interesting {en2}.',{'v':(FUT,['würden','wird','werdet']),'inf':(FUT,['gesehen','sah'])},{'inf':FUT})
    add_time(b,f'Tomorrow we will watch the interesting {en2}.')
    clause=[t('rc',',',',','PUNCT'),t('rp','den','der','PRON',initial='der'),t('rs','du','du','PRON'),t('rv','empfohlen','empfehlen','VERB'),t('ra','hast','haben','AUX')]; b.add('+ relative clause · you recommended it',b.tokens+clause,f'Tomorrow we will watch the interesting {en2} that you recommended.',{'rp':(['relative.clause'],['der','dem','das'])},{'ra':FINAL},kind='INSERT',initial_order=['rc','rp','rs','ra','rv'])
    add_obwohl(b,f'Tomorrow we will watch the interesting {en2} that you recommended although the weather is bad.')
    return b.finish()

def build(check=False):
    from content_v2 import build_chains
    legacy=dict(read=a1_agreement,visit=a1_modal,home=a1_nouns,routine=a1_separable,past=a1_perfect,
                cafe=a2_cafe,travel=a2_travel,shop=a2_shopping,feeling=a2_reflexive,outside=a2_home,
                future=b1_future,wish=b1_would,relative=b1_relative,despite=b1_obwohl,
                market=b1_strong,weekend=b1_planning,film=b1_story)
    chains,glosses=build_chains(legacy)
    EN.update(glosses)
    # Compile all observed/authored paradigm forms. Distractors are explicit source
    # data; the compiler still independently checks membership and answer exclusion.
    paradigms={}; levels={}
    for chain in chains:
        for snapshot in [chain['base']]+chain['steps']:
            for token in snapshot['tokens']:
                if token['pos']=='PUNCT':continue
                lemma=token['lemma']; paradigms.setdefault(lemma,set()).add(token['text'])
                if 'initial' in token: paradigms[lemma].add(token['initial'])
                levels.setdefault(lemma,chain['cefr'])
            for fix in snapshot.get('fixes',[]):
                token=next(t for t in snapshot['tokens'] if t['id']==fix['token'])
                paradigms[token['lemma']].update(fix.get('distractors',[]))
    missing=set(paradigms)-EN.keys()
    if missing:raise ValueError('Missing authored vocabulary glosses: '+str(sorted(missing)))
    lexicon=[dict(lemma=k,cefr=levels[k],forms=sorted(v),gloss={'en':EN[k]},labels={f:FORM_LABELS[f] for f in sorted(v) if f in FORM_LABELS}) for k,v in sorted(paradigms.items())]
    for chain in chains:
        old=chain['base']['tokens']
        for step in chain['steps']:
            card=step['card'];old_by_id={t['id']:t for t in old};new_by_id={t['id']:t for t in step['tokens']}
            if card['type']=='SUBSTITUTE' and card.get('target') in old_by_id and card['target'] in new_by_id:
                a,b=old_by_id[card['target']],new_by_id[card['target']]
                card['cardGloss']={'en':EN[a['lemma']]+' → '+EN[b['lemma']]}
                step['inverseLabel']=' → '.join(reversed(card['label'].split(' → '))) if ' → ' in card['label'] else 'Undo: '+card['label']
            elif card['type']=='INSERT':
                inserted=[t for t in step['tokens'] if t['id'] not in old_by_id and not t.get('spawned') and t['pos']!='PUNCT']
                card['cardGloss']={'en':'+ '+' · '.join(EN[t['lemma']] for t in inserted)}
                step['inverseLabel']='− '+ ' '.join(t['text'] for t in inserted)
            old=step['tokens']
    pack=dict(schemaVersion=1,packId='de-en',version=2,rules=rules(),lexicon=lexicon,chains=chains,reviewStatus='pending-native-review')
    dest=ROOT/'content/source/pack.json'; dest.parent.mkdir(parents=True,exist_ok=True)
    output=json.dumps(pack,ensure_ascii=False,indent=2)+'\n'
    if check:
        if not dest.exists() or dest.read_text()!=output:raise SystemExit('Stale authored pack: run python3 tools/author_content.py')
    else:dest.write_text(output)
    print(f'{"Checked" if check else "Authored"} {len(chains)} chains, {sum(len(c["steps"]) for c in chains)} steps, {len(pack["rules"])} rules, {len(lexicon)} lemmas')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');build(parser.parse_args().check)
