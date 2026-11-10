import contextlib
import io
import json
import sys
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import elevenlabs_audio as audio
from content_v2 import Noun, adjective_form


class AudioAuthoringTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        self.root_patch=patch.multiple(audio,ROOT=self.root,AUDIO=self.root/'content/audio')
        self.root_patch.start()
        pack={'version':2,'packId':'de-en','chains':[{'chainId':'test','terminal':'.',
            'base':{'tokens':[{'text':'wir'},{'text':'lernen'}]},
            'steps':[{'tokens':[{'text':'wir'},{'text':'lernen'},{'text':','},{'text':'weil'},{'text':'es'},{'text':'hilft'}]},
                     {'tokens':[{'text':'wir'},{'text':'lernen'}],'gloss':{'en':'We learn.'}}]}]}
        p=self.root/'content/source/pack.json';p.parent.mkdir(parents=True);p.write_text(json.dumps(pack))

    def tearDown(self):
        self.root_patch.stop();self.temp.cleanup()

    def test_plans_deduplicate_text_and_keep_all_references(self):
        plan=audio.plan('all')
        self.assertEqual(plan['uniqueSentences'],2)
        self.assertEqual(len(plan['clips'][audio.text_id('Wir lernen.')]['references']),2)
        self.assertIn('Wir lernen, weil es hilft.',[c['text'] for c in plan['clips'].values()])
        self.assertEqual(audio.text_id('Mädchen'),audio.text_id('Ma\u0308dchen'))

    def test_redirect_is_not_followed_and_never_exposes_the_key(self):
        key=self.root/'key';key.write_text('a-secret-only-in-test');key.chmod(0o600)
        class Response:
            status=302
            def getheader(self,name,default=None):return 'https://geo-restriction.elevenlabs.io/' if name=='Location' else default
        class Connection:
            count=0
            def __init__(self,*args,**kwargs):pass
            def request(self,*args,**kwargs):Connection.count+=1
            def getresponse(self):return Response()
            def close(self):pass
        captured=io.StringIO()
        with patch.object(audio.http.client,'HTTPSConnection',Connection),contextlib.redirect_stdout(captured):
            with self.assertRaises(audio.AudioError) as raised:audio.API(key).subscription()
        self.assertEqual(Connection.count,1)
        self.assertIn('Redirect was not followed',str(raised.exception))
        self.assertNotIn('a-secret-only-in-test',str(raised.exception)+captured.getvalue())

    def test_rate_limited_reads_back_off_but_paid_requests_do_not_retry(self):
        key = self.root / 'key'
        key.write_text('test-key')
        key.chmod(0o600)
        api = audio.API(key)
        limited = audio.RateLimited('5')
        quota = {'character_limit': 1000, 'character_count': 0}
        with patch.object(api, '_request', side_effect=[limited, quota]) as request, \
             patch.object(audio.time, 'sleep') as sleep, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(api.subscription(), quota)
            self.assertEqual(request.call_count, 2)
            sleep.assert_called_once_with(5)
        with patch.object(api, '_request', side_effect=limited) as request, \
             patch.object(audio.time, 'sleep') as sleep:
            with self.assertRaises(audio.RateLimited):
                api.request('POST', '/v1/text-to-speech/test', {'text': 'Guten Tag.'}, audio=True)
            self.assertEqual(request.call_count, 1)
            sleep.assert_not_called()

    def test_credit_reserve_stops_before_a_paid_request(self):
        class FakeAPI:
            posts=0
            def request(self,method,path,payload=None,audio=False):
                if method=='POST':self.posts+=1;raise AssertionError('No paid request expected')
                if path.startswith('/v1/voices/'):return {'labels':{'language':'de'}}
                return [{'model_id':'eleven_multilingual_v2','can_do_text_to_speech':True,'token_cost_factor':1}]
            def subscription(self):return {'character_limit':100,'character_count':80}
        api=FakeAPI();args=Namespace(voice_id='verified-test-voice',max_characters=100,max_clips=10,max_credits=100,
            credit_multiplier=1,reserve_credits=1000,scope='final')
        with self.assertRaisesRegex(audio.AudioError,'credit reserve'):audio.generate(api,args)
        self.assertEqual(api.posts,0)
        self.assertFalse((audio.AUDIO/'uncertain-request.json').exists())

    def test_tampered_recording_cannot_be_added_to_the_app(self):
        plan=audio.plan('final');key,clip=next(iter(plan['clips'].items()))
        folder=audio.AUDIO/'clips';folder.mkdir(parents=True);(folder/'bad.mp3').write_bytes(b'corrupt')
        source={'packVersion':2,'clips':{key:{'text':clip['text'],'sha256':'0'*64,'file':'bad.mp3'}}}
        with self.assertRaisesRegex(audio.AudioError,'integrity'):audio.publish_catalog(source)
        self.assertFalse((self.root/'App/Resources/audio-catalog.json').exists())

    def test_invalid_decoder_output_is_not_staged(self):
        audio.AUDIO.mkdir(parents=True)
        (audio.AUDIO/'recordings.json').write_text(json.dumps({'packVersion':2,'clips':{'test':{'file':'bad.mp3'}}}))
        with patch.object(audio,'probe',side_effect=audio.AudioError('Generated file failed ffprobe decoding.')), \
             patch.object(audio,'publish_catalog') as publish,contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(audio.main(['verify']),2)
            publish.assert_not_called()

    def test_nullable_voice_and_model_metadata_is_safe(self):
        self.assertFalse(audio.voice_supports({'labels':None,'verified_languages':None},'de'))
        self.assertTrue(audio.voice_supports({'labels':None,'verified_languages':[{'language':'de'}]},'de'))
        class FakeAPI:
            def subscription(self):return {}
            def request(self,method,path):
                if path=='/v1/models':return [{'model_id':'unknown','can_do_text_to_speech':True,'languages':None}]
                return {'voices':[{'labels':None,'verified_languages':None}]}
        result=audio.inspect(FakeAPI())
        self.assertEqual(result['germanVoices'],[])
        self.assertEqual(result['models'],[])

    def test_uncertain_request_is_never_repeated(self):
        audio.AUDIO.mkdir(parents=True);(audio.AUDIO/'uncertain-request.json').write_text('{}')
        class FakeAPI:
            def request(self,method,path,**kwargs):
                if method=='POST':raise AssertionError('Must not repeat a potentially charged request')
                if path.startswith('/v1/voices/'):return {'labels':{'language':'de'}}
                return [{'model_id':'eleven_multilingual_v2','can_do_text_to_speech':True,'token_cost_factor':1}]
        args=Namespace(voice_id='verified-test-voice',max_characters=100,max_clips=10,max_credits=100,
            credit_multiplier=1,reserve_credits=1000,scope='final')
        with self.assertRaisesRegex(audio.AudioError,'uncertain outcome'):audio.generate(FakeAPI(),args)

    def test_completed_batch_is_assembled_and_resumed_without_spending_again(self):
        class FakeAPI:
            posts=0
            def request(self,method,path,payload=None,audio=False):
                if method=='POST':
                    self.posts+=1
                    return b'ID3-test-fixture-'+payload['text'].encode(),{'requestId':f'test-{self.posts}','characterCost':None}
                if path.startswith('/v1/voices/'):return {'labels':{'language':'de'}}
                return [{'model_id':'eleven_multilingual_v2','can_do_text_to_speech':True,'token_cost_factor':1}]
            def subscription(self):return {'character_limit':10000,'character_count':0}
        api=FakeAPI();args=Namespace(voice_id='verified-test-voice',max_characters=1000,max_clips=10,max_credits=1000,
            credit_multiplier=1,reserve_credits=1000,scope='all')
        # Decoder behavior is tested separately. This fixture checks local
        # provenance, catalog assembly and paid-request deduplication.
        with patch.object(audio,'probe',return_value=1.2),contextlib.redirect_stdout(io.StringIO()):
            first=audio.generate(api,args)
            resumed=audio.generate(api,args)
        self.assertEqual(first['generatedThisRun'],2)
        self.assertEqual(resumed['generatedThisRun'],0)
        self.assertEqual(api.posts,2)
        self.assertFalse((audio.AUDIO/'uncertain-request.json').exists())
        catalog=json.loads((self.root/'App/Resources/audio-catalog.json').read_text())
        self.assertEqual(len(catalog['clips']),2)
        for key,clip in catalog['clips'].items():
            self.assertEqual(audio.text_id(clip['text']),key)
            staged=self.root/'firebase/public'/clip['path'].lstrip('/')
            self.assertEqual(audio.digest(staged.read_bytes()),clip['sha256'])

    def test_english_generation_matches_final_gloss_and_keeps_its_catalog_separate(self):
        class FakeAPI:
            def request(self, method, path, payload=None, audio=False):
                if method == 'POST':
                    return b'ID3-'+payload['text'].encode(), {'requestId': 'en-test', 'characterCost': '3'}
                if path.startswith('/v1/voices/'):
                    return {'labels': {'language': 'en'}}
                return [{'model_id': 'eleven_multilingual_v2', 'can_do_text_to_speech': True}]

            def subscription(self):
                return {'character_limit': 2000, 'character_count': 0}

        german_catalog = self.root / 'App/Resources/audio-catalog.json'
        audio.write_json(german_catalog, {'schemaVersion': 1, 'packVersion': 2, 'clips': {}})
        original = german_catalog.read_bytes()
        args = Namespace(voice_id='verified-test-voice', max_characters=100, max_clips=10,
                         max_credits=100, credit_multiplier=1, reserve_credits=1000,
                         scope='final', language='en')
        with patch.object(audio, 'probe', return_value=1.2), contextlib.redirect_stdout(io.StringIO()):
            result = audio.generate(FakeAPI(), args)
        self.assertEqual(result['recordings'], 1)
        record = json.loads((audio.AUDIO/'en/recordings.json').read_text())
        key = audio.text_id('We learn.')
        self.assertEqual(record['language'], 'en')
        self.assertEqual(record['clips'][key]['references'], [{'chainId': 'test', 'step': 1}])
        catalog = json.loads((self.root/'firebase/public/content/de-en/v2/audio-catalog-en.json').read_text())
        self.assertEqual(catalog['clips'][key]['text'], 'We learn.')
        staged = self.root / 'firebase/public' / catalog['clips'][key]['path'].lstrip('/')
        self.assertEqual(staged.parent.name, 'audio-en')
        self.assertEqual(staged.read_bytes(), b'ID3-We learn.')
        self.assertEqual(german_catalog.read_bytes(), original)

    def test_recent_balance_is_debited_and_refreshed_before_crossing_reserve(self):
        class FakeAPI:
            reads = 0
            posts = 0

            def subscription(self):
                self.reads += 1
                return {'character_limit': 100, 'character_count': 40 if self.reads == 1 else 65}

            def request(self, method, path, payload=None, audio=False):
                if method == 'POST':
                    self.posts += 1
                    return b'ID3-'+payload['text'].encode(), {'requestId': 'test', 'characterCost': '4'}
                if path.startswith('/v1/voices/'):
                    return {'labels': {'language': 'de'}}
                return [{'model_id': 'eleven_multilingual_v2', 'can_do_text_to_speech': True}]

        api = FakeAPI()
        args = Namespace(voice_id='verified-test-voice', max_characters=100, max_clips=10,
                         max_credits=100, credit_multiplier=1, reserve_credits=30, scope='all')
        with patch.object(audio, 'probe', return_value=1.2), \
             patch.object(audio.time, 'monotonic', return_value=0), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(audio.AudioError, 'credit reserve'):
                audio.generate(api, args)
        self.assertEqual((api.reads, api.posts), (2, 1))
        self.assertFalse((audio.AUDIO/'uncertain-request.json').exists())

    def test_adjective_elision_and_dative_noun_forms(self):
        mixer=Noun.parse('Mixer;m;Mixer;blender;blenders')
        milk=Noun.parse('Milch;f;-;milk;types of milk')
        self.assertEqual(adjective_form('leise',mixer),'leisen')
        self.assertEqual(adjective_form('dunkel',milk,kind=None),'dunkle')
        self.assertEqual(adjective_form('flexibel',mixer,'dat',None),'flexiblem')
        guest=Noun.parse('Gast;m;Gäste;guest;guests')
        self.assertEqual(guest.form('dat',True),'Gästen')
        with self.assertRaisesRegex(ValueError,'Mass noun'):milk.form('dat',True)


if __name__=='__main__':unittest.main()
