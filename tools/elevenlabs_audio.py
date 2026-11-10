#!/usr/bin/env python3
"""Plan, resume and verify authoring-time ElevenLabs recordings.

No redirects are followed, no secrets are logged, and uncertain paid requests
are never retried automatically. The iOS app does not call ElevenLabs.
"""
from __future__ import annotations
import argparse
import fcntl
import hashlib
import http.client
import json
import math
import re
import shutil
import subprocess
import sys
import time
import unicodedata
import urllib.parse
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'content/audio'
API_HOST='api.elevenlabs.io'
MODEL='eleven_multilingual_v2'
SETTINGS={'stability':0.65,'similarity_boost':0.75,'style':0.0,'use_speaker_boost':True}

class AudioError(Exception):pass

class RateLimited(AudioError):
    def __init__(self, retry_after):
        super().__init__('ElevenLabs HTTP 429. The provider rate-limited the request.')
        self.retry_after = retry_after

def retry_delay(header):
    if not header:
        return 0
    header = header.strip()
    if re.fullmatch(r'[0-9]+', header):
        digits = header.lstrip('0') or '0'
        return int(digits) if len(digits) <= 2 else 61
    try:
        retry_at = parsedate_to_datetime(header)
        return max(0, (retry_at - datetime.now(timezone.utc)).total_seconds())
    except (TypeError, ValueError, OverflowError):
        return 0

def encoded(value):return (json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode()
def digest(data):return hashlib.sha256(data).hexdigest()
def text_id(text):return digest(unicodedata.normalize('NFC',text).encode())
def write_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_suffix(path.suffix+'.tmp');temporary.write_bytes(encoded(value));temporary.replace(path)

def sentence(snapshot,terminal='.'):
    text=' '.join(t['text'] for t in snapshot['tokens'])
    text=re.sub(r'\s+([,.;:!?])',r'\1',text)
    return unicodedata.normalize('NFC',text[:1].upper()+text[1:]+snapshot.get('terminal',terminal))

def audio_directory(language):
    if language == 'de':
        return AUDIO
    if language == 'en':
        return AUDIO / 'en'
    raise AudioError('Unsupported recording language.')

def plan(scope='final', language='de'):
    directory = audio_directory(language)
    if language == 'en' and scope != 'final':
        raise AudioError('English recordings use the final lesson translations.')
    pack=json.loads((ROOT/'content/source/pack.json').read_text())
    clips={}
    for chain in pack['chains']:
        snapshots=list(enumerate(chain['steps'])) if scope=='all' else [(len(chain['steps'])-1,chain['steps'][-1])]
        if scope=='all':snapshots=[(-1,chain['base'])]+snapshots
        for index,snapshot in snapshots:
            if language == 'en':
                text = unicodedata.normalize('NFC', snapshot['gloss']['en'].strip())
                if not text:
                    raise AudioError('Missing final English translation for '+chain['chainId'])
            else:
                text = sentence(snapshot, chain['terminal'])
            key = text_id(text)
            clip=clips.setdefault(key,{'text':text,'characters':len(text),'references':[]})
            clip['references'].append({'chainId':chain['chainId'],'step':index})
    value={'schemaVersion':1,'packId':pack['packId'],'packVersion':pack['version'],'scope':scope,
           'uniqueSentences':len(clips),'characters':sum(c['characters'] for c in clips.values()),'clips':clips}
    if language == 'en':
        value['language'] = language
    write_json(directory/f'plan-{scope}.json',value)
    return value

class API:
    def __init__(self,key_file):
        if key_file.stat().st_mode & 0o077:
            raise AudioError('Credential file must be private (chmod 600).')
        self.key=key_file.read_text().strip()
        if not self.key or '\n' in self.key:raise AudioError('Invalid credential file.')

    def request(self, method, path, payload=None, audio=False):
        delays = iter((2, 4, 8, 16, 32) if method == 'GET' else ())
        while True:
            try:
                return self._request(method, path, payload, audio)
            except RateLimited as error:
                delay = next(delays, None)
                if delay is None:
                    raise
                delay = max(delay, retry_delay(error.retry_after))
                if delay > 60:
                    raise
                print(f'ElevenLabs rate-limited a read. Retrying in {delay:.0f} seconds.',
                      file=sys.stderr, flush=True)
                time.sleep(delay)

    def _request(self,method,path,payload=None,audio=False):
        connection=http.client.HTTPSConnection(API_HOST,timeout=40)
        headers={'xi-api-key':self.key,'Accept':'audio/mpeg' if audio else 'application/json','Accept-Encoding':'identity'}
        if payload is not None:headers['Content-Type']='application/json'
        try:
            connection.request(method,path,body=encoded(payload) if payload is not None else None,headers=headers)
            response=connection.getresponse()
            if 300<=response.status<400:
                host=urllib.parse.urlsplit(response.getheader('Location','')).hostname
                raise AudioError('ElevenLabs redirected to '+(host or 'an unverified destination')+'. Redirect was not followed.')
            if response.status==429:
                raise RateLimited(response.getheader('Retry-After'))
            if response.status!=200:
                raise AudioError(f'ElevenLabs HTTP {response.status}. Response body omitted; no automatic retry.')
            limit=2_000_000 if audio else 4_000_000
            data=response.read(limit+1)
            if len(data)>limit:raise AudioError('ElevenLabs response exceeded the bounded size.')
            metadata={'requestId':response.getheader('request-id') or response.getheader('x-request-id'),
                      'characterCost':response.getheader('character-cost')}
            if audio:
                if response.getheader('Content-Type','').split(';')[0] not in ('audio/mpeg','audio/mp3','application/octet-stream'):
                    raise AudioError('ElevenLabs returned an unexpected audio content type.')
                return data,metadata
            try:return json.loads(data)
            except (ValueError,UnicodeError):raise AudioError('ElevenLabs returned a non-JSON response; body omitted.') from None
        except (OSError,http.client.HTTPException):
            raise AudioError('ElevenLabs connection failed. An uncertain generation is not retried automatically.') from None
        finally:connection.close()

    def subscription(self):return self.request('GET','/v1/user/subscription')

def voice_supports(voice, language):
    labels = {'de': {'de', 'german', 'deutsch'}, 'en': {'en', 'english'}}
    primary_language = str((voice.get('labels') or {}).get('language', '')).lower()
    return primary_language in labels[language] or any(
        entry.get('language') == language for entry in (voice.get('verified_languages') or [])
    )

def inspect(api, language='de'):
    sub=api.subscription();models=api.request('GET','/v1/models');voices=api.request('GET','/v2/voices?page_size=100&include_total_count=true')
    value={'subscription':{k:sub.get(k) for k in ['tier','status','character_count','character_limit']},
           ('germanVoices' if language == 'de' else 'englishVoices'):[{k:v.get(k) for k in ['voice_id','name','category','labels']} for v in voices.get('voices',[]) if voice_supports(v, language)],
           'models':[{k:m.get(k) for k in ['model_id','name','token_cost_factor']} for m in models if m.get('can_do_text_to_speech') and any(l.get('language_id')==language for l in (m.get('languages') or []))],
           'moreVoicesAvailable':voices.get('has_more',False)}
    return value

def probe(path):
    if shutil.which('ffprobe') is None:raise AudioError('ffprobe is required to verify generated audio.')
    result=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,sample_rate,channels','-of','json',str(path)],capture_output=True,text=True)
    if result.returncode:raise AudioError('Generated file failed ffprobe decoding.')
    info=json.loads(result.stdout);duration=float(info.get('format',{}).get('duration',0))
    if not 0.2<=duration<=180 or not any(s.get('codec_name')=='mp3' for s in info.get('streams',[])):
        raise AudioError('Recording has an unexpected codec or duration.')
    return round(duration,3)

def publish_catalog(source, language='de'):
    directory = audio_directory(language)
    if source.get('language', 'de') != language:
        raise AudioError('The recording manifest belongs to another language.')
    version=source['packVersion'];clips={}
    active=plan('all' if language == 'de' else 'final', language)
    asset_folder = 'audio' if language == 'de' else 'audio-en'
    if active['packVersion']!=version:raise AudioError('The recordings belong to another content version.')
    for key,record in source['clips'].items():
        if key not in active['clips']:continue
        file=directory/'clips'/record['file']
        data=file.read_bytes()
        if text_id(record['text'])!=key or digest(data)!=record['sha256']:
            raise AudioError('Recording provenance/integrity mismatch.')
        path=f'/content/de-en/v{version}/{asset_folder}/{record["sha256"]}.mp3'
        target=ROOT/'firebase/public'/path.lstrip('/')
        if target.exists() and target.read_bytes()!=data:raise AudioError('Refusing to overwrite an immutable audio asset.')
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():target.write_bytes(data)
        clips[key]={'text':record['text'],'sha256':record['sha256'],'bytes':len(data),'path':path}
    catalog={'schemaVersion':1,'packVersion':version,'clips':clips}
    if language == 'de':
        write_json(ROOT/'App/Resources/audio-catalog.json',catalog)
        catalog_name = 'audio-catalog.json'
    else:
        catalog['language'] = language
        catalog_name = 'audio-catalog-en.json'
    write_json(ROOT/f'firebase/public/content/de-en/v{version}/{catalog_name}',catalog)
    return len(clips)

def generate(api,args):
    if not re.fullmatch(r'[A-Za-z0-9_-]{10,100}',args.voice_id):raise AudioError('Invalid voice ID.')
    if args.max_characters<=0 or args.max_clips<=0 or args.max_credits<=0:raise AudioError('Generation requires positive, explicit limits.')
    language = getattr(args, 'language', 'de')
    directory = audio_directory(language)
    current_plan=plan(args.scope, language)
    voice=api.request('GET','/v1/voices/'+args.voice_id)
    if not voice_supports(voice, language):
        raise AudioError(f'Select a voice with verified {language} language metadata before generation.')
    # This controlled profile uses the stable Multilingual v2 model. Refuse an
    # unexpected multiplier instead of silently consuming a different budget.
    models=api.request('GET','/v1/models');model=next((m for m in models if m.get('model_id')==MODEL),None)
    if model is None or not model.get('can_do_text_to_speech'):raise AudioError('Required speech model is unavailable.')
    factor=float(model.get('token_cost_factor') or 1)
    if factor<=0 or factor>2:raise AudioError('Unexpected model credit multiplier; inspect pricing before proceeding.')
    # Shared voices may have a separate multiplier. The operator must verify
    # the current voice quote; an absent API field is not evidence of a 1x rate.
    factor=max(factor,args.credit_multiplier)
    source_path = directory / 'recordings.json'
    profile = {'packVersion': current_plan['packVersion'], 'modelId': MODEL,
               'voiceId': args.voice_id, 'voiceSettings': SETTINGS}
    if source_path.exists():
        source = json.loads(source_path.read_text())
    else:
        source = {'schemaVersion': 1, 'provider': 'ElevenLabs', **profile, 'clips': {}}
        if language == 'en':
            source['language'] = language
    if source.get('language', 'de') != language or any(
        source.get(key) != value for key, value in profile.items()
    ):
        raise AudioError('The existing recording batch has another content/voice profile. Keep its provenance separate.')
    uncertain=directory/'uncertain-request.json'
    if uncertain.exists():raise AudioError(f'An earlier request has an uncertain outcome. Check provider history before explicitly resolving {uncertain.relative_to(ROOT)}.')
    used=0;used_credits=0;completed=0
    remaining = None
    refresh_balance_at = 0.0
    for key,clip in current_plan['clips'].items():
        if key in source['clips']:
            file=directory/'clips'/source['clips'][key]['file']
            if not file.exists() or digest(file.read_bytes())!=source['clips'][key]['sha256']:
                raise AudioError('An existing recording is missing or corrupt; restore it before resuming.')
            continue
        if completed>=args.max_clips or used+clip['characters']>args.max_characters:break
        estimate=math.ceil(clip['characters']*factor)
        if used_credits+estimate>args.max_credits:break
        # Reserve each clip's estimated credits against a recent balance read.
        # A short reuse window keeps subscription checks below their rate limit.
        if remaining is None or time.monotonic() >= refresh_balance_at or remaining - estimate < args.reserve_credits:
            sub = api.subscription()
            remaining = int(sub.get('character_limit', 0)) - int(sub.get('character_count', 0))
            refresh_balance_at = time.monotonic() + 5
        if remaining-estimate<args.reserve_credits:raise AudioError('Stopped before exhausting the account credit reserve; no billing setting was changed.')
        write_json(uncertain,{'textId':key,'characters':clip['characters'],'voiceId':args.voice_id,'modelId':MODEL,'reason':'Request may have been charged if the connection is interrupted. Check provider history before retrying.'})
        data,metadata=api.request('POST','/v1/text-to-speech/'+args.voice_id+'?output_format=mp3_44100_128',{'text':clip['text'],'model_id':MODEL,'voice_settings':SETTINGS},audio=True)
        sha=digest(data);folder=directory/'clips';folder.mkdir(parents=True,exist_ok=True);file=folder/(sha+'.mp3')
        if file.exists() and file.read_bytes()!=data:raise AudioError('Audio hash collision or local corruption.')
        file.write_bytes(data)
        write_json(uncertain,{'textId':key,'audioFile':file.name,'requestId':metadata['requestId'],'reason':'Audio received; verify this local file before retrying any generation.'})
        duration=probe(file)
        source['clips'][key]={'text':clip['text'],'sha256':sha,'file':file.name,'bytes':len(data),'durationSeconds':duration,'references':clip['references'],'estimatedCredits':estimate,'quotedCreditMultiplier':args.credit_multiplier,**metadata}
        write_json(source_path,source);uncertain.unlink();used+=clip['characters'];used_credits+=estimate;completed+=1
        remaining -= estimate
        print(f'Recorded {len(source["clips"])}/{len(current_plan["clips"])} sentences; this run used {used} text characters.',flush=True)
    published=publish_catalog(source, language)
    return {'recordings':published,'generatedThisRun':completed,'textCharactersThisRun':used,'estimatedCreditsThisRun':used_credits,'reviewStatus':'pending-listening-review'}

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['plan','inspect','generate','verify'])
    parser.add_argument('--scope',choices=['final','all'],default='final')
    parser.add_argument('--language', choices=['de', 'en'], default='de')
    parser.add_argument('--key-file',type=Path,default=ROOT/'.secrets/elevenlabs-api-key')
    parser.add_argument('--voice-id')
    parser.add_argument('--max-characters',type=int)
    parser.add_argument('--max-credits',type=int)
    parser.add_argument('--credit-multiplier',type=float,help='Verified current total voice/model multiplier; required, not inferred.')
    parser.add_argument('--max-clips',type=int,default=240)
    parser.add_argument('--reserve-credits',type=int,default=1000)
    args=parser.parse_args(argv)
    try:
        directory = audio_directory(args.language)
        if args.command=='plan':
            result=plan(args.scope, args.language);print(json.dumps({k:v for k,v in result.items() if k!='clips'}));return 0
        if args.command=='verify':
            source=json.loads((directory/'recordings.json').read_text())
            for record in source['clips'].values():probe(directory/'clips'/record['file'])
            count=publish_catalog(source, args.language)
            print(json.dumps({'verifiedRecordings':count}));return 0
        if args.command=='generate' and (not args.voice_id or args.max_characters is None or args.max_credits is None or args.credit_multiplier is None or not 1<=args.credit_multiplier<=10 or args.reserve_credits<0):
            raise AudioError('Generation requires --voice-id, --max-characters, --max-credits and a verified --credit-multiplier (1–10), with a nonnegative credit reserve.')
        api=API(args.key_file)
        if args.command=='inspect':print(json.dumps(inspect(api, args.language),ensure_ascii=False,indent=2));return 0
        AUDIO.mkdir(parents=True,exist_ok=True)
        with (AUDIO/'.generation.lock').open('w') as lock:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:raise AudioError('Another recording batch is already running.') from None
            print(json.dumps(generate(api,args),ensure_ascii=False,indent=2))
        return 0
    except (AudioError,OSError,ValueError,KeyError) as error:
        # Do not interpolate transport exceptions, request headers or provider
        # response bodies. AudioError messages are controlled strings above.
        message=str(error) if isinstance(error,AudioError) else 'Local audio configuration or artifact is invalid.'
        print('Audio generation stopped: '+message,file=sys.stderr);return 2

if __name__=='__main__':sys.exit(main())
