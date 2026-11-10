#!/usr/bin/env python3
"""Expand the curated scenario worksheet into explicit version-2 source rows."""
from __future__ import annotations
import csv
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
with (ROOT/'content/authoring/vocabulary-v2.tsv').open() as stream:
    records=list(csv.DictReader(stream,delimiter='\t'))
NOUNS={row['lemma']:';'.join(row[k] for k in ['lemma','gender','plural','en','plural_en','oblique']) for row in records}
assert len(NOUNS)==len(records),'Duplicate authored noun'

VERBS={}
for line in '''
kaufen;kaufe;kaufst;kauft;gekauft;buy;bought
üben;übe;übst;übt;geübt;practice;practiced
prüfen;prüfe;prüfst;prüft;geprüft;check;checked
notieren;notiere;notierst;notiert;notiert;note down;noted down
brauchen;brauche;brauchst;braucht;gebraucht;need;needed
vergleichen;vergleiche;vergleichst;vergleicht;verglichen;compare;compared
erklären;erkläre;erklärst;erklärt;erklärt;explain;explained
suchen;suche;suchst;sucht;gesucht;look for;looked for
zeigen;zeige;zeigst;zeigt;gezeigt;show;showed
sortieren;sortiere;sortierst;sortiert;sortiert;sort;sorted
schreiben;schreibe;schreibst;schreibt;geschrieben;write;wrote
lernen;lerne;lernst;lernt;gelernt;learn;learned
wiederholen;wiederhole;wiederholst;wiederholt;wiederholt;repeat;repeated
kopieren;kopiere;kopierst;kopiert;kopiert;copy;copied
besuchen;besuche;besuchst;besucht;besucht;visit;visited
begrüßen;begrüße;begrüßt;begrüßt;begrüßt;greet;greeted
fragen;frage;fragst;fragt;gefragt;ask;asked
fotografieren;fotografiere;fotografierst;fotografiert;fotografiert;photograph;photographed
informieren;informiere;informierst;informiert;informiert;inform;informed
begleiten;begleite;begleitest;begleitet;begleitet;accompany;accompanied
unterstützen;unterstütze;unterstützt;unterstützt;unterstützt;support;supported
verabschieden;verabschiede;verabschiedest;verabschiedet;verabschiedet;say goodbye to;said goodbye to
benachrichtigen;benachrichtige;benachrichtigst;benachrichtigt;benachrichtigt;notify;notified
erkennen;erkenne;erkennst;erkennt;erkannt;recognize;recognized
treffen;treffe;triffst;trifft;getroffen;meet;met
putzen;putze;putzt;putzt;geputzt;clean;cleaned
bezahlen;bezahle;bezahlst;bezahlt;bezahlt;pay;paid
reparieren;repariere;reparierst;repariert;repariert;repair;repaired
packen;packe;packst;packt;gepackt;pack;packed
räumen;räume;räumst;räumt;geräumt;clear;cleared
erledigen;erledige;erledigst;erledigt;erledigt;complete;completed
vorbereiten;bereite;bereitest;bereitet;vorbereitet;prepare;prepared
planen;plane;planst;plant;geplant;plan;planned
malen;male;malst;malt;gemalt;paint;painted
pflanzen;pflanze;pflanzt;pflanzt;gepflanzt;plant;planted
reservieren;reserviere;reservierst;reserviert;reserviert;reserve;reserved
öffnen;öffne;öffnest;öffnet;geöffnet;open;opened
bestellen;bestelle;bestellst;bestellt;bestellt;order;ordered
essen;esse;isst;isst;gegessen;eat;ate
trinken;trinke;trinkst;trinkt;getrunken;drink;drank
probieren;probiere;probierst;probiert;probiert;try;tried
servieren;serviere;servierst;serviert;serviert;serve;served
genießen;genieße;genießt;genießt;genossen;enjoy;enjoyed
kochen;koche;kochst;kocht;gekocht;cook;cooked
braten;brate;brätst;brät;gebraten;fry;fried
backen;backe;backst;backt;gebacken;bake;baked
grillen;grille;grillst;grillt;gegrillt;grill;grilled
freuen;freue;freust;freut;gefreut;be happy;was happy
ärgern;ärgere;ärgerst;ärgert;geärgert;be annoyed;was annoyed
wundern;wundere;wunderst;wundert;gewundert;be surprised;was surprised
entspannen;entspanne;entspannst;entspannt;entspannt;relax;relaxed
konzentrieren;konzentriere;konzentrierst;konzentriert;konzentriert;concentrate;concentrated
rasieren;rasiere;rasierst;rasiert;rasiert;shave;shaved
waschen;wasche;wäschst;wäscht;gewaschen;wash;washed
beeilen;beeile;beeilst;beeilt;beeilt;hurry;hurried
erholen;erhole;erholst;erholt;erholt;recover;recovered
bedanken;bedanke;bedankst;bedankt;bedankt;say thank you;said thank you
erinnern;erinnere;erinnerst;erinnert;erinnert;remember;remembered
interessieren;interessiere;interessierst;interessiert;interessiert;be interested;was interested
entschuldigen;entschuldige;entschuldigst;entschuldigt;entschuldigt;apologize;apologized
beschweren;beschwere;beschwerst;beschwert;beschwert;complain;complained
bewerben;bewerbe;bewirbst;bewirbt;beworben;apply;applied
verabreden;verabrede;verabredest;verabredet;verabredet;arrange to meet;arranged to meet
erkundigen;erkundige;erkundigst;erkundigt;erkundigt;inquire;inquired
gewöhnen;gewöhne;gewöhnst;gewöhnt;gewöhnt;get used;got used
unterhalten;unterhalte;unterhältst;unterhält;unterhalten;talk;talked
anmelden;melde;meldest;meldet;angemeldet;register;registered
spielen;spiele;spielst;spielt;gespielt;play;played
warten;warte;wartest;wartet;gewartet;wait;waited
trainieren;trainiere;trainierst;trainiert;trainiert;train;trained
proben;probe;probst;probt;geprobt;rehearse;rehearsed
tanzen;tanze;tanzt;tanzt;getanzt;dance;danced
arbeiten;arbeite;arbeitest;arbeitet;gearbeitet;work;worked
diskutieren;diskutiere;diskutierst;diskutiert;diskutiert;discuss;discussed
singen;singe;singst;singt;gesungen;sing;sang
zeichnen;zeichne;zeichnest;zeichnet;gezeichnet;draw;drew
laufen;laufe;läufst;läuft;gelaufen;run;ran
lachen;lache;lachst;lacht;gelacht;laugh;laughed
reden;rede;redest;redet;geredet;talk;talked
helfen;helfe;hilfst;hilft;geholfen;help;helped
forschen;forsche;forschst;forscht;geforscht;do research;did research
reisen;reise;reist;reist;gereist;travel;traveled
lesen;lese;liest;liest;gelesen;read;read
empfehlen;empfehle;empfiehlst;empfiehlt;empfohlen;recommend;recommended
entdecken;entdecke;entdeckst;entdeckt;entdeckt;discover;discovered
auswählen;wähle;wählst;wählt;ausgewählt;select;selected
beschreiben;beschreibe;beschreibst;beschreibt;beschrieben;describe;described
entwickeln;entwickle;entwickelst;entwickelt;entwickelt;develop;developed
veröffentlichen;veröffentliche;veröffentlichst;veröffentlicht;veröffentlicht;publish;published
untersuchen;untersuche;untersuchst;untersucht;untersucht;examine;examined
entwerfen;entwerfe;entwirfst;entwirft;entworfen;design;designed
organisieren;organisiere;organisierst;organisiert;organisiert;organize;organized
beobachten;beobachte;beobachtest;beobachtet;beobachtet;observe;observed
beraten;berate;berätst;berät;beraten;advise;advised
beurteilen;beurteile;beurteilst;beurteilt;beurteilt;assess;assessed
besprechen;bespreche;besprichst;bespricht;besprochen;discuss;discussed
bearbeiten;bearbeite;bearbeitest;bearbeitet;bearbeitet;work on;worked on
überarbeiten;überarbeite;überarbeitest;überarbeitet;überarbeitet;revise;revised
schildern;schildere;schilderst;schildert;geschildert;describe;described
erläutern;erläutere;erläuterst;erläutert;erläutert;explain;explained
formulieren;formuliere;formulierst;formuliert;formuliert;formulate;formulated
bewerten;bewerte;bewertest;bewertet;bewertet;evaluate;evaluated
kontrollieren;kontrolliere;kontrollierst;kontrolliert;kontrolliert;inspect;inspected
verbessern;verbessere;verbesserst;verbessert;verbessert;improve;improved
wohnen;wohne;wohnst;wohnt;gewohnt;live;lived
praktizieren;praktiziere;praktizierst;praktiziert;praktiziert;practice professionally;practiced professionally
unterrichten;unterrichte;unterrichtest;unterrichtet;unterrichtet;teach;taught
leiten;leite;leitest;leitet;geleitet;lead;led
berichten;berichte;berichtest;berichtet;berichtet;report;reported
sehen;sehe;siehst;sieht;gesehen;watch;watched
hören;höre;hörst;hört;gehört;listen to;listened to
verfolgen;verfolge;verfolgst;verfolgt;verfolgt;follow;followed
'''.strip().splitlines():
    fields=line.split(';'); assert len(fields)==7,line;VERBS[fields[0]]=line

def noun(value): return NOUNS[value]
def verb(value): return VERBS[value]
def dataset(family,columns,raw,defaults=None):
    rows=[{'retainV1':True}]
    for line in raw.strip().splitlines():
        values=line.split('|'); assert len(values)==len(columns),(family,line)
        row=dict(defaults or {}); row.update(zip(columns,values))
        for k in ['noun','context','person','event','friends','actor','place','conditionNoun','complement','reasonNoun','gift']:
            if k in row:row[k]=noun(row[k])
        for k in ['nouns','people']:
            if k in row:row[k]=[noun(n) for n in row[k].split(',')]
        for k in ['verb','relativeVerb','extraVerb']:
            if k in row:row[k]=verb(row[k])
        rows.append(row)
    DATA[family]=rows

DATA={}
dataset('read',['nouns','context','verb','title','theme'],'''
Text,Dialog|Klassenzimmer|üben|Read together in class|work
Plan,Stadtplan|Bahnhof|prüfen|Find your way around|travel
Name,Preis|Geschäft|notieren|Names and prices|shopping
Pass,Ausweis|Hotel|brauchen|At the hotel desk|travel
Kalender,Stundenplan|Schule|vergleichen|Plan the school week|plans
Bericht,Artikel|Büro|erklären|News at the office|work
Roman,Dialog|Bibliothek|suchen|Choose something to read|free-time
Prospekt,Fahrplan|Bus|zeigen|Information on the bus|city
Einkaufszettel,Kassenbon|Küche|sortieren|After the shopping trip|home
Gruß,Wunsch|Wohnzimmer|schreiben|Send a kind message|family
Liedtext,Hinweis|Musikschule|lernen|Words in a song|free-time
Text,Satz|Zug|wiederholen|Practice on the train|travel
Hinweis,Kommentar|Café|kopieren|A note at the café|cafe
''',{'contextEn':'in the classroom'})
# Each location gloss is explicit, rather than inferred from its German case.
for row,en in zip(DATA['read'][1:],['in the classroom','at the station','in the shop','at the hotel','at school','in the office','in the library','on the bus','in the kitchen','in the living room','at the music school','on the train','at the café']):row['contextEn']=en

dataset('visit',['nouns','context','verb','adjective','title','theme'],'''
Lehrer,Trainer|Schule|fragen|geduldig;patient|Ask someone at school|work
Nachbar,Freund|Garten|begrüßen|hilfsbereit;helpful|Meet in the garden|home
Arzt,Zahnarzt|Praxis|besuchen|aufmerksam;attentive|At the medical practice|health
Verkäufer,Kunde|Geschäft|informieren|höflich;polite|Help in the shop|shopping
Fahrer,Gast|Bahnhof|begleiten|pünktlich;punctual|Meet at the station|travel
Koch,Kellner|Restaurant|fotografieren|fröhlich;cheerful|A restaurant photograph|food
Chef,Kollege|Büro|benachrichtigen|zuverlässig;reliable|A message at work|work
Onkel,Vater|Wohnung|besuchen|liebevoll;loving|Visit the family|family
Bruder,Sohn|Sportplatz|unterstützen|sportlich;athletic|Support someone at the match|free-time
Opa,Partner|Park|begleiten|ruhig;calm|A walk in the park|family
Polizist,Tourist|Flughafen|fragen|freundlich;friendly|Ask at the airport|travel
Musiker,Sänger|Kino|verabschieden|bekannt;well-known|After the performance|free-time
Schüler,Student|Café|erkennen|nett;nice|Recognize someone at the café|cafe
''')
for row,en in zip(DATA['visit'][1:],['at school','in the garden','at the medical practice','in the shop','at the station','in the restaurant','in the office','in the apartment','at the sports ground','in the park','at the airport','at the cinema','at the café']):row['contextEn']=en

dataset('home',['nouns','adjective','title'],'''
Löffel,Gabel,Messer|sauber;clean|Set the table
Teller,Tasse,Glas|leer;empty|Clear the dishes
Schlüssel,Flasche,Dose|klein;small;kleiner;smaller|Small things at home
Schrank,Kommode,Regal|alt;old;älter;older|Furniture with a history
Spiegel,Scheibe,Fenster|schmutzig;dirty|Time to clean the glass
Schuh,Socke,Stiefel|nass;wet|After the rain
Mantel,Jacke,Hemd|trocken;dry|Laundry is ready
Teppich,Decke,Kissen|weich;soft|Make the room comfortable
Apfel,Birne,Pfirsich|reif;ripe|Fruit in the bowl
Kuchen,Torte,Keks|lecker;tasty|Something to share
Koffer,Tasche,Rucksack|schwer;heavy|Pack for the journey
Bildschirm,Tastatur,Telefon|kaputt;broken|A problem at the desk
Topf,Pfanne,Schüssel|voll;full|In the busy kitchen
''')

dataset('routine',['nouns','context','separable','title','theme'],'''
Radio,Fernseher|Wohnzimmer|einschalten;schalte;schaltest;schalte;schaltet;ein;switch on|Switch on the news|home
Licht,Lampe|Schlafzimmer|ausmachen;mache;machst;mach;macht;aus;turn off|Turn off the light|home
Fenster,Tür|Flur|aufmachen;mache;machst;mach;macht;auf;open|Let some fresh air in|home
Tor,Garage|Hof|zumachen;mache;machst;mach;macht;zu;close|Close up for the night|home
Buch,Karte|Schule|mitbringen;bringe;bringst;bring;bringt;mit;bring along|Bring it to class|work
Geschenk,Flasche|Küche|einpacken;packe;packst;pack;packt;ein;wrap|Wrap a present|family
Paket,Bestellung|Geschäft|abholen;hole;holst;hol;holt;ab;collect|Collect an order|shopping
Zimmer,Küche|Wohnung|aufräumen;räume;räumst;räum;räumt;auf;tidy|Tidy the apartment|home
Vater,Mutter|Büro|anrufen;rufe;rufst;ruf;ruft;an;call|Call home|family
Bild,Jacke|Keller|aufhängen;hänge;hängst;häng;hängt;auf;hang up|Find a place for it|home
Formular,Liste|Hotel|ausfüllen;fülle;füllst;füll;füllt;aus;fill in|Fill in the details|travel
Bruder,Schwester|Garten|einladen;lade;lädst;lade;ladet;ein;invite|Invite someone over|family
Zettel,Verpackung|Werkstatt|wegwerfen;werfe;wirfst;wirf;werft;weg;throw away|Clear the workbench|work
''')
for row,en in zip(DATA['routine'][1:],['in the living room','in the bedroom','in the hallway','in the courtyard','at school','in the kitchen','in the shop','in the apartment','in the office','in the cellar','at the hotel','in the garden','in the workshop']):row['contextEn']=en

dataset('past',['noun','context','verb','manner','title','theme'],'''
Bad|Erdgeschoss|putzen|gründlich;thoroughly|A clean bathroom|home
Rechnung|Restaurant|bezahlen|sofort;immediately|Pay after the meal|food
Fahrrad|Keller|reparieren|vorsichtig;carefully|Repair the bicycle|travel
Koffer|Schlafzimmer|packen|langsam;slowly|Pack without a rush|travel
Schreibtisch|Büro|räumen|schnell;quickly|A clear desk|work
Hausaufgabe|Klassenzimmer|erledigen|richtig;correctly|Finish the homework|work
Frühstück|Küche|planen|gemeinsam;together|Plan breakfast together|food
Foto|Wohnzimmer|kopieren|sorgfältig;carefully|Copy a photograph|free-time
Blume|Garten|pflanzen|behutsam;gently|Plant a flower|weather
Zimmer|Hotel|reservieren|rechtzeitig;in good time|Reserve before the trip|plans
Tür|Flur|öffnen|leise;quietly|A quiet arrival|home
Brief|Terrasse|schreiben|ordentlich;neatly|A letter on the terrace|family
Geschenk|Esszimmer|packen|spontan;spontaneously|A little surprise|shopping
''')
for row,en in zip(DATA['past'][1:],['on the ground floor','at the restaurant','in the cellar','in the bedroom','in the office','in the classroom','in the kitchen','in the living room','in the garden','at the hotel','in the hallway','on the terrace','in the dining room']):row['contextEn']=en
for row in DATA['past'][1:]:
    if row['context'].startswith('Terrasse;'):row['contextPrep']='auf'

dataset('cafe',['nouns','verb','adjective','person','event','reason','title','theme'],'''
Salat,Auflauf|essen|vegetarisch;vegetarian|Mitbewohner|Treffen|hungrig;hungry|Lunch after a meeting|food
Kuchen,Strudel|essen|hausgemacht;homemade|Schwager|Probe|zufrieden;satisfied|A homemade treat|cafe
Eintopf,Braten|essen|würzig;spicy|Schwiegervater|Vorlesung|erschöpft;exhausted|A warm meal after class|food
Fisch,Reis|essen|gedämpft;steamed|Cousin|Wanderung|müde;tired|Dinner after a hike|health
Pfannkuchen,Pudding|essen|süß;sweet|Enkel|Training|begeistert;enthusiastic|Something sweet after training|cafe
Keks,Zwieback|essen|knusprig;crisp|Vermieter|Besprechung|erleichtert;relieved|A small snack|cafe
Joghurt,Quark|essen|cremig;creamy|Neffe|Prüfung|nervös;nervous|A break after the exam|health
Saft,Smoothie|trinken|fruchtig;fruity|Bekannter|Führung|durstig;thirsty|A drink after the tour|cafe
Kakao,Cappuccino|trinken|heiß;hot|Opa|Schicht|durchgefroren;chilled through|Warm up after work|weather
Toast,Wrap|essen|gefüllt;filled|Partner|Reise|ungeduldig;impatient|A quick meal after traveling|travel
Burger,Döner|essen|saftig;juicy|Freund|Radtour|ausgehungert;famished|Lunch after cycling|free-time
Honig,Sirup|probieren|regional;local|Kollege|Konzert|neugierig;curious|Taste something local|food
Schinken,Speck|probieren|geräuchert;smoked|Onkel|Ausflug|entspannt;relaxed|Food on an excursion|food
Lachs,Thunfisch|essen|gebraten;fried|Vater|Spaziergang|froh;glad|A meal after a walk|family
Mais,Spinat|essen|frisch;fresh|Bruder|Wettbewerb|optimistisch;optimistic|Eat well after the competition|health
Brokkoli,Blumenkohl|essen|gedünstet;lightly steamed|Chef|Vorstellung|überrascht;surprised|A late supper|food
Käse,Tofu|probieren|mild;mild|Nachbar|Feier|gespannt;full of anticipation|Try a new flavor|food
Suppe,Wurst|essen|kräftig;rich|Mutter|Einkauf|krank;ill|Warm food after shopping|shopping
Brot,Gebäck|essen|ofenwarm;oven-warm|Schwester|Fahrt|unglücklich;unhappy|A comforting breakfast|cafe
''')
for row in DATA['cafe'][1:]:
    if row['verb'].split(';')[0]=='probieren':row['participleRule']='verb.participle.regular'

dataset('travel',['nouns','friends','manner','title','theme'],'''
Wartesaal,Aufenthaltsraum|Passagier|geduldig;patiently|Wait somewhere comfortable|travel
Speisesaal,Konferenzraum|Mitarbeiter|gemeinsam;together|After the work meeting|work
Lesesaal,Seminarraum|Teilnehmer|aufmerksam;attentively|A quiet place to study|work
Empfangsbereich,Ausstellungsraum|Besucher|neugierig;curiously|Explore a new building|city
Proberaum,Fitnessraum|Musiker|regelmäßig;regularly|Stay with the group|free-time
Gartenpavillon,Gemeindesaal|Helfer|freiwillig;voluntarily|A community afternoon|family
Stadtgarten,Wintergarten|Gärtner|ruhig;calmly|Enjoy a green space|weather
Campingplatz,Spielplatz|Wanderer|draußen;outside|Spend the afternoon outdoors|travel
Hafen,Wald|Radfahrer|länger;longer|Change the destination|travel
Postamt,Rathaus|Begleiter|kurz;briefly|An errand in town|city
Kulturzentrum,Jugendzentrum|Tänzer|früh;early|Meet the dance group|free-time
Besucherzentrum,Gästehaus|Tourist|bequem;comfortably|Arrive with the visitors|travel
Ferienhaus,Hostel|Freund|günstig;inexpensively|Choose accommodation|travel
Sportzentrum,Einkaufszentrum|Sportler|ausnahmsweise;for a change|A different meeting place|shopping
Verkehrsmuseum,Schloss|Schüler|nebenan;next door|A school outing|city
Gasthaus,Gemeindehaus|Betreuer|drinnen;inside|Find shelter together|weather
Stadion,Freibad|Zuschauer|heute;today|An afternoon with spectators|free-time
Hallenbad,Gewerbegebiet|Ingenieur|ausführlich;in detail|Remember where everyone stayed|work
Museum,Theater|Dolmetscher|abends;in the evenings|A cultural visit|city
''')

dataset('shop',['nouns','adjective','replacementAdj','person','conditionNoun','title'],'''
Regenmantel,Anorak|wasserdicht;waterproof|atmungsaktiv;breathable|Automechaniker|Geld|Stay dry on the commute
Schlafsack,Schirm|leicht;lightweight|robust;sturdy|Elektriker|Platz|Useful things for a trip
Kugelschreiber,Bleistift|praktisch;practical|ergonomisch;ergonomic|Bäcker|Zeit|Write comfortably
Füller,Ordner|preiswert;inexpensive|hochwertig;high-quality|Friseur|Geld|Choose office supplies
Notizblock,Zeichenblock|handlich;handy|stabil;sturdy|Gärtner|Platz|Something for sketches
Bohrer,Hammer|leistungsfähig;powerful|vielseitig;versatile|Hausmeister|Energie|Tools for the job
Schraubenzieher,Pinsel|schmal;narrow|breit;wide|Sekretär|Zeit|Choose the right size
Staubsauger,Besen|langlebig;durable|pflegeleicht;easy to maintain|Assistent|Geld|Keep the home clean
Eimer,Wäscheständer|günstig;affordable|platzsparend;space-saving|Erzieher|Platz|Make room at home
Wasserkocher,Toaster|sparsam;economical|sicher;safe|Pfleger|Geduld|Everyday kitchen equipment
Mixer,Entsafter|leise;quiet|effizient;efficient|Rezeptionist|Energie|A quieter kitchen
Drucker,Scanner|kompakt;compact|modern;modern|Briefträger|Geld|Equipment for a home office
Router,Lautsprecher|kabellos;wireless|tragbar;portable|Taxifahrer|Zeit|Flexible technology
Kopfhörer,Adapter|bequem;comfortable|passend;suitable|Busfahrer|Geld|Find a suitable accessory
Gürtel,Schal|elegant;elegant|farbenfroh;colorful|Programmierer|Zeit|Choose a personal gift
Handschuh,Hausschuh|warm;warm|flauschig;fluffy|Designer|Geld|A cozy present
Sessel,Hocker|gepolstert;padded|verstellbar;adjustable|Lagerarbeiter|Platz|A comfortable seat
Vorhang,Rollladen|blickdicht;opaque|lichtdurchlässig;translucent|Schneider|Geduld|Control the light
Blumentopf,Kerzenhalter|rund;round|eckig;angular|Vermieter|Geld|A detail for the room
''')

dataset('feeling',['verb','complement','preposition','case','people','event','actionEn','title','theme'],'''
ärgern|Verspätung|über|acc|Nachbarin,Kollegin|Abfahrt|be annoyed about the delay|A delay together|travel
wundern|Antwort|über|acc|Beraterin,Ärztin|Interview|be surprised by the answer|An unexpected answer|work
entspannen|Training|nach|dat|Freundin,Schulfreundin|Arbeitstag|relax after the training session|Make time to relax|health
konzentrieren|Aufgabe|auf|acc|Klassenkameradin,Kommilitonin|Pause|concentrate on the task|Back to the task|work
rasieren|Termin|vor|dat|Mitbewohner,Schwager|Frühstück|shave before the appointment|Prepare for an appointment|health
waschen|Sport|nach|dat|Bruder,Cousin|Wettbewerb|wash after sport|After being active|health
beeilen|Anmeldung|mit|dat|Reisebegleiterin,Tanzpartnerin|Ankunft|hurry with the registration|Register in good time|plans
erholen|Grippe|von|dat|Schwester,Cousine|Behandlung|recover from the flu|Recover with support|health
bedanken|Hilfe|für|acc|Nachbarin,Vermieterin|Umzug|say thank you for the help|Thank someone after moving|home
erinnern|Gespräch|an|acc|Arbeitskollegin,Beraterin|Besprechung|remember the conversation|Remember a conversation|work
interessieren|Geschichte|für|acc|Schulfreundin,Klassenkameradin|Führung|be interested in the story|A story worth hearing|free-time
entschuldigen|Fehler|für|acc|Teamkollegin,Arbeitskollegin|Präsentation|apologize for the mistake|Put a mistake right|work
beschweren|Lärm|über|acc|Mitbewohnerin,Nachbarin|Übernachtung|complain about the noise|A noisy night|home
bewerben|Stelle|um|acc|Kommilitonin,Kollegin|Beratung|apply for the job vacancy|Apply together|work
verabreden|Abfahrt|für|acc|Reisebegleiter,Tanzpartner|Anmeldung|arrange to meet for the departure|Agree when to meet|plans
erkundigen|Öffnungszeit|nach|dat|Nachhilfelehrerin,Lehrerin|Absage|inquire about the opening time|Check before going|city
gewöhnen|Rhythmus|an|acc|Pflegerin,Betreuerin|Operation|get used to the rhythm|A new daily rhythm|health
unterhalten|Ausstellung|über|acc|Schwiegermutter,Schwägerin|Besuch|talk about the exhibition|Talk after a visit|free-time
anmelden|Sprachkurs|für|acc|Dolmetscherin,Trainerin|Zusage|register for the language course|Join a course together|plans
''')
DATA['feeling'][-1]['prefix']='an'
DATA['feeling'][0]={'verb':verb('freuen'),'complement':noun('Ergebnis'),'preposition':'über','case':'acc',
    'people':[noun('Schwester'),noun('Mutter')],'event':noun('Prüfung'),
    'actionEn':'be happy about the result','title':'A result worth celebrating','theme':'work'}

dataset('outside',['actor','place','person','verb','singularActionEn','adjective','title','theme'],'''
Schüler|Schule|Lehrer|warten|waits|jung;young;jünger;younger|Wait outside school|work
Student|Bibliothek|Dozent|lernen|studies|fleißig;hard-working;fleißiger;more hard-working|A study group outside|work
Sportler|Turnhalle|Trainer|trainieren|trains|kräftig;strong;kräftiger;stronger|Training with a coach|health
Musiker|Musikschule|Dirigent|proben|rehearses|erfahren;experienced;erfahrener;more experienced|Rehearse together|free-time
Tänzer|Sporthalle|Tanzpartner|tanzen|dances|beweglich;flexible;beweglicher;more flexible|Space to dance|free-time
Rentner|Gemeindehaus|Betreuer|reden|talks|gesellig;sociable;geselliger;more sociable|A sociable afternoon|family
Lehrling|Berufsschule|Ausbilder|arbeiten|works|geschickt;skillful;geschickter;more skillful|Learn from an instructor|work
Anfänger|Kunstschule|Künstler|zeichnen|draws|talentiert;talented;talentierter;more talented|A drawing lesson|free-time
Profi|Stadion|Sportler|trainieren|trains|ausdauernd;persistent;ausdauernder;more persistent|Keep training|health
Chor|Musikhalle|Chorleiter|singen|sings|laut;loud;lauter;louder|Listen to the choir|free-time
Mannschaft|Festhalle|Teamkollege|warten|waits|ruhig;calm;ruhiger;calmer|A team waiting together|plans
Schulklasse|Museum|Schulleiter|warten|waits|neugierig;curious;neugieriger;more curious|Before the museum visit|city
Orchester|Theater|Musikpädagoge|proben|rehearses|berühmt;famous;berühmter;more famous|Rehearse at the theater|free-time
Schauspieler|Schauspielschule|Regisseur|proben|rehearses|mutig;brave;mutiger;braver|Try a new role|free-time
Künstler|Atelier|Designer|arbeiten|works|kreativ;creative;kreativer;more creative|Work at the studio|work
Handwerker|Geschäftshaus|Meister|arbeiten|works|selbstständig;independent;selbstständiger;more independent|Independent work|work
Feuerwehrmann|Feuerwache|Einsatzleiter|warten|waits|wachsam;alert;wachsamer;more alert|Ready for a call|city
Sanitäter|Rettungswache|Pfleger|warten|waits|umsichtig;prudent;umsichtiger;more prudent|A careful team|health
Bergführer|Berghütte|Reisebegleiter|lachen|laughs|fröhlich;cheerful;fröhlicher;more cheerful|A cheerful rest in the mountains|travel
''')

# B1 rows contain distinct professional, cultural, household and outdoor contexts.
dataset('future',['nouns','person','verb','adjective','manner','reasonNoun','reasonAdj','title','theme'],'''
Journalist,Redakteur|Übersetzer|besuchen|kompetent;competent|ausdrücklich;expressly|Weg|rutschig;slippery|Plans with an editor|work
Autor,Professor|Dozent|begrüßen|anerkannt;respected|persönlich;personally|Straße|gesperrt;closed|Welcome a guest speaker|work
Experte,Spezialist|Ingenieur|begleiten|erfolgreich;successful|trotzdem;nevertheless|Verkehr|dicht;heavy|Keep an appointment|city
Geschäftspartner,Auftraggeber|Geschäftsführer|informieren|erreichbar;reachable|direkt;directly|Entfernung|beträchtlich;considerable|A message to a client|work
Abteilungsleiter,Architekt|Projektleiter|besuchen|engagiert;committed|gezielt;purposefully|Strecke|unübersichtlich;hard to navigate|Visit a project team|plans
Anwalt,Notar|Steuerberater|fragen|zuständig;responsible|vorsichtshalber;as a precaution|Verbindung|unterbrochen;interrupted|Ask the responsible person|work
Wissenschaftler,Forscher|Nachwuchsforscher|fotografieren|international;international|anschließend;afterward|Zugang|versperrt;blocked|Meet the researchers|work
Psychologe,Therapeut|Sozialarbeiter|begrüßen|einfühlsam;empathetic|diskret;discreetly|Aufzug|defekt;out of order|Arrive at the advice center|health
Reiseleiter,Stadtführer|Ehrenamtlicher|begleiten|ortskundig;familiar with the area|rechtzeitig;in good time|Fahrkarte|teuer;expensive|Meet a local guide|travel
''')

dataset('wish',['nouns','person','verb','adjective','relativeVerb','place','placeEn','title','theme'],'''
Milch,Sahne|Freund|bestellen|laktosefrei;lactose-free|empfehlen|Café|at the café|A suitable drink|cafe
Butter,Margarine|Partner|kaufen|pflanzlich;plant-based|beschreiben|Bioladen|at the organic shop|A plant-based choice|food
Marmelade,Konfitüre|Schwester|probieren|zuckerarm;low-sugar|entdecken|Hofladen|at the farm shop|A preserve to try|food
Schokolade,Kuvertüre|Mutter|bestellen|dunkel;dark|vergleichen|Feinkostladen|at the delicatessen|Choose baking chocolate|food
Zucker,Rohrzucker|Vater|kaufen|unraffiniert;unrefined|empfehlen|Reformhaus|at the health food shop|Ingredients you recommended|shopping
Pfeffer,Kümmel|Bruder|probieren|gemahlen;ground|bestellen|Restaurant|at the restaurant|Try a seasoning|food
Essig,Balsamico|Onkel|kaufen|aromatisch;aromatic|entdecken|Großmarkt|at the wholesale market|A different flavor|shopping
Öl,Olivenöl|Tante|bestellen|kaltgepresst;cold-pressed|beschreiben|Naturkostladen|at the natural food shop|Choose an oil|food
Salz,Gewürz|Cousine|probieren|grob;coarse|empfehlen|Gasthaus|at the inn|Season a meal|food
''')

dataset('relative',['nouns','person','verb','adjective','relativeVerb','relativeActionEn','place','gift','giftAdj','title','theme'],'''
Ingenieur,Techniker|Kollege|besuchen|sachkundig;knowledgeable|arbeiten|works|Labor|Kaffee|duftend;fragrant|Visit someone at the laboratory|work
Journalist,Redakteur|Freund|begrüßen|kritisch;critical|arbeiten|works|Verlag|Gebäck|hausgemacht;homemade|Meet someone at the publishing house|work
Autor,Übersetzer|Partner|besuchen|zweisprachig;bilingual|arbeiten|works|Archiv|Brot|selbstgebacken;home-baked|Visit a bilingual colleague|work
Professor,Dozent|Student|fotografieren|beliebt;popular|unterrichten|teaches|Bildungszentrum|Obst|reif;ripe|Meet a favorite lecturer|work
Psychologe,Therapeut|Bruder|besuchen|qualifiziert;qualified|praktizieren|practices professionally|Therapiezentrum|Tee|wohltuend;soothing|A visit to the therapy center|health
Musiker,Sänger|Cousin|begrüßen|begabt;gifted|proben|rehearses|Studio|Wasser|gekühlt;chilled|Meet at the recording studio|free-time
Künstler,Designer|Nachbar|besuchen|einfallsreich;inventive|arbeiten|works|Atelier|Schokolade|fein;fine|Visit a creative studio|free-time
Pädagoge,Sozialarbeiter|Vater|begleiten|geduldig;patient|arbeiten|works|Jugendzentrum|Gemüse|saisonal;seasonal|A colleague at the youth center|family
Reiseleiter,Stadtführer|Onkel|besuchen|hilfsbereit;helpful|arbeiten|works|Besucherzentrum|Saft|naturtrüb;cloudy and unfiltered|Visit the visitor center|travel
''')

dataset('despite',['nouns','person','verb','adjective','extraVerb','manner','reasonNoun','reasonAdj','title','theme'],'''
Auftrag,Vorschlag|Geschäftspartner|bearbeiten|dringend;urgent|diskutieren|konzentriert;intently|Verbindung|schwach;weak|Work despite a weak connection|work
Entwurf,Abschnitt|Architekt|überarbeiten|übersichtlich;clearly arranged|zeichnen|unabhängig;independently|Raum|eng;cramped|Revise a draft|work
Beitrag,Aufsatz|Redakteur|veröffentlichen|ausführlich;detailed|berichten|sachlich;objectively|Zeit|knapp;short|Publish under time pressure|work
Versuch,Beweis|Forscher|untersuchen|sorgfältig;careful|forschen|gewissenhaft;conscientiously|Labor|überfüllt;overcrowded|Continue an experiment|work
Fall,Vortrag|Experte|besprechen|kompliziert;complicated|reden|offen;openly|Termin|ungünstig;inconvenient|Discuss a difficult case|work
Antrag,Vertrag|Anwalt|formulieren|verständlich;understandable|lesen|präzise;precisely|Ton|undeutlich;unclear|Find precise words|work
Entschluss,Beschluss|Abteilungsleiter|erläutern|eindeutig;unambiguous|diskutieren|ausnahmsweise;as an exception|Wetter|stürmisch;stormy|Explain a decision|plans
Terminplan,Arbeitsplan|Projektleiter|verbessern|flexibel;flexible|planen|vorausschauend;proactively|Schicht|lang;long|Improve the schedule|plans
Haushalt,Gartenplan|Mitbewohner|organisieren|nachhaltig;sustainable|kochen|verantwortungsvoll;responsibly|Energie|teuer;expensive|Organize everyday life|home
''')

dataset('market',['nouns','person','verb','adjective','place','placeEn','placePrep','title','theme'],'''
Mehl,Getreide|Bäcker|kaufen|biologisch;organic|Wochenmarkt|at the weekly market|auf|Choose organic ingredients|food
Fleisch,Geflügel|Koch|bestellen|mager;lean|Hofladen|at the farm shop|in|Order lean ingredients|food
Wasser,Mineralwasser|Sportler|kaufen|sprudelnd;sparkling|Bioladen|at the organic shop|in|Something refreshing|health
Öl,Olivenöl|Kellner|bestellen|hochwertig;high-quality|Feinkostladen|at the delicatessen|in|Choose good cooking oil|food
Salz,Gewürz|Bruder|kaufen|jodiert;iodized|Naturkostladen|at the natural food shop|in|Read the ingredient label|shopping
Müsli,Hafermehl|Enkel|bestellen|glutenfrei;gluten-free|Reformhaus|at the health food shop|in|A breakfast that suits you|health
Hackfleisch,Rindfleisch|Schwiegervater|kaufen|regional;local|Bauernmarkt|at the farmers' market|auf|Buy from local producers|food
Eis,Sorbet|Neffe|bestellen|fruchtig;fruity|Gasthaus|at the inn|in|Choose a dessert|cafe
Hähnchen,Lammfleisch|Onkel|kaufen|tiefgekühlt;frozen|Großmarkt|at the wholesale market|auf|Plan the family meal|food
''')

dataset('weekend',['nouns','person','verb','adjective','relativeVerb','relativeActionEn','place','gift','giftAdj','manner','title','theme'],'''
Schwager,Schwägerin|Partner|besuchen|herzlich;warm-hearted|arbeiten|works|Beratungszentrum|Kaffee|fair;fair-trade|vielleicht;perhaps|Visit the in-laws|family
Neffe,Nichte|Mutter|begrüßen|aufgeschlossen;open-minded|lernen|studies|Jugendclub|Gebäck|knusprig;crisp|wahrscheinlich;probably|See the younger family members|family
Großvater,Oma|Vater|besuchen|gastfreundlich;hospitable|wohnen|lives|Gästehaus|Tee|mild;mild|regelmäßig;regularly|A family visit away from home|family
Lehrer,Lehrerin|Freund|besuchen|verständnisvoll;understanding|unterrichten|teaches|Musikverein|Schokolade|bitter;dark and bitter|gelegentlich;occasionally|Visit former teachers|free-time
Trainer,Trainerin|Bruder|begrüßen|motiviert;motivated|arbeiten|works|Sportverein|Saft|frisch;fresh|bestimmt;certainly|A visit to the sports club|free-time
Berater,Beraterin|Kollege|besuchen|erfahren;experienced|arbeiten|works|Nachbarschaftshaus|Brot|knusprig;crisp|vermutlich;presumably|An appointment in the neighborhood|city
Nachhilfelehrer,Nachhilfelehrerin|Schwester|besuchen|zugewandt;attentive and caring|unterrichten|teaches|Institut|Obst|saftig;juicy|üblicherweise;usually|Meet a former tutor|work
Tanzpartner,Tanzpartnerin|Cousine|besuchen|lebhaft;lively|proben|rehearses|Kulturverein|Wasser|still;still|abermals;once again|See a dance partner|free-time
Reisebegleiter,Reisebegleiterin|Freund|begleiten|unternehmungslustig;adventurous|arbeiten|works|Tourismusbüro|Käse|würzig;full-flavored|hoffentlich;hopefully|Visit a travel companion|travel
''')

dataset('film',['nouns','person','verb','adjective','relativeVerb','reasonNoun','reasonAdj','title','theme'],'''
Krimi,Zeichentrickfilm|Freund|sehen|spannend;exciting|empfehlen|Saal|voll;full|Choose an evening film|free-time
Kurzfilm,Spielfilm|Partner|sehen|preisgekrönt;award-winning|entdecken|Eintritt|teuer;expensive|Watch an award-winning film|free-time
Thriller,Liebesfilm|Cousine|sehen|berührend;moving|beschreiben|Weg|weit;long|Follow a recommendation|free-time
Abenteuerfilm,Western|Bruder|sehen|unterhaltsam;entertaining|auswählen|Wetter|regnerisch;rainy|An evening at the cinema|weather
Podcast,Audiobeitrag|Kollege|hören|informativ;informative|veröffentlichen|Empfang|schlecht;poor|Listen to an informative piece|work
Radiobericht,Reisebericht|Vater|hören|anschaulich;vivid|schildern|Akku|leer;empty|Listen to a travel story|travel
Hörspiel,Hörbuch|Schwester|hören|fesselnd;gripping|empfehlen|Ton|leise;quiet|An absorbing audio story|free-time
Sachbuch,Tagebuch|Freundin|lesen|aufschlussreich;insightful|beurteilen|Licht|schwach;dim|Read something insightful|free-time
Gedicht,Märchen|Mutter|lesen|fantasievoll;imaginative|entdecken|Wind|stark;strong|A story for a windy day|weather
''')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    expected={'read':14,'visit':14,'home':14,'routine':14,'past':14,'cafe':20,'travel':20,'shop':20,'feeling':20,'outside':20,'future':10,'wish':10,'relative':10,'despite':10,'market':10,'weekend':10,'film':10}
    assert {k:len(v) for k,v in DATA.items()}==expected
    for family in ('future','despite','film'):
        for i,row in enumerate(DATA[family]):
            if i and i%2==0:row['reasonFirst']=True
    dest=ROOT/'content/authoring/scenarios-v2.json';output=json.dumps(DATA,ensure_ascii=False,indent=2)+'\n'
    if args.check:
        if not dest.exists() or dest.read_text()!=output:raise SystemExit('Stale scenario rows: run python3 tools/author_scenarios.py')
    else:dest.write_text(output)
    print(f'{"Checked" if args.check else "Authored"} {sum(map(len,DATA.values()))} scenario rows in {len(DATA)} grammar families')

if __name__=='__main__':main()
