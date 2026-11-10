# Recorded lesson speech

Updated 10 November 2026. ElevenLabs Multilingual v2 and Andy Uliczka's verified standard German voice produced all 240 final lesson recordings. The source MP3s are in `content/audio/clips/`, and their verified copies are staged for Hosting and native listening review. The CLI reads the key from the ignored `.secrets/elevenlabs-api-key` file with mode 0600. [Recording provenance](../content/audio/recordings.json).

## Plans

```sh
python3 tools/elevenlabs_audio.py plan --scope final
python3 tools/elevenlabs_audio.py plan --scope all
```

The current version 2 plans contain 240 distinct final sentences / 18,801 text characters and 1,926 distinct base/intermediate/final sentences / 98,149 characters. NFC text hashes deduplicate exact sentences while retaining every chain/step reference. Character counts are workload measurements, not a price quote. Plans are regenerated from the current source pack before generation.

The final-sentence batch used 7,523 included credits. The account went from 35,672 to 28,149 available credits. At the observed rate of roughly 0.4 credits per character, rounding up each clip's estimate and retaining 1,000 credits leaves room for about 1,556 of the shortest outstanding clips. All 1,686 outstanding clips would cost an estimated 31,746 credits at the observed rate. The live balance and voice rate determine the cap for each future batch.

The app never calls ElevenLabs. The CLI sends only authored lesson text; it does not send learner identities, answers or progress. The credential is ignored, never included in arguments or logs, and never copied into the app or Hosting files. Keep `--key-file` private if an explicitly selected alternate path is used. Do not put it into CI for content checks.

## Inspect and generate

The CLI requires Python 3 and `ffprobe` on PATH. Inspect the actual account before selecting a voice:

```sh
python3 tools/elevenlabs_audio.py inspect
```

This checks the subscription's used/available character quota, speech models and German-language voice metadata. Voice listings can be paginated; an empty first page is not evidence that no suitable voice exists. Select a German voice whose permitted use is appropriate for distribution, listen to its samples, and verify its current total credit multiplier. A German label is not a native listening approval.

The generation profile uses `eleven_multilingual_v2`, MP3 44.1 kHz / 128 kbps, stability 0.65, similarity 0.75, style 0 and speaker boost. Replace both placeholders below with the inspected voice ID and verified current total voice/model multiplier. Start with a small, reviewable batch:

```sh
python3 tools/elevenlabs_audio.py generate --scope final \
  --voice-id YOUR_VERIFIED_GERMAN_VOICE_ID \
  --credit-multiplier YOUR_VERIFIED_MULTIPLIER \
  --max-characters 500 --max-credits 1000 --max-clips 3 \
  --reserve-credits 1000
```

Every run requires explicit character and credit ceilings. The multiplier must be 1–10, and the tool uses the larger of the supplied rate and the model factor. Shared voices can cost more than one credit per character. The CLI deducts each clip's estimated cost from a recent account balance before checking the reserve. It refreshes the balance after five seconds or when the next estimate would cross the reserve. Use conservative caps when other account clients can consume credits concurrently. Review a small batch before running a larger one.

The implementation follows ElevenLabs' [text-to-speech conversion](https://elevenlabs.io/docs/api-reference/text-to-speech/convert), [models](https://elevenlabs.io/docs/api-reference/models/list) and [voice metadata](https://elevenlabs.io/docs/api-reference/voices/get) interfaces. Verify the current quote, including [custom voice rates and credit multipliers](https://elevenlabs.io/docs/help-center/product/voices/voice-library/what-are-custom-rates-and-credit-multipliers), before running a paid batch.

## English counterparts

The English set contains 240 clips voiced by Matilda in American English with ElevenLabs Multilingual v2. Each clip uses the authored `gloss.en` and shares its chain ID and final step index with the German recording. ElevenLabs reported 7,134 credits for 17,825 characters. All clips passed a full decode and hash check. [English recording provenance](../content/audio/en/recordings.json).

The English profile supports `plan`, `inspect`, `generate` and `verify` with `--language en`. Use an English voice ID and explicit credit ceilings. Sources are under `content/audio/en/`. The versioned catalog `audio-catalog-en.json` and the `audio-en/` MP3s are staged for listening review. [English catalog](../firebase/public/content/de-en/v2/audio-catalog-en.json).

```sh
python3 tools/elevenlabs_audio.py plan --language en
python3 tools/elevenlabs_audio.py verify --language en
```

## Resume and recovery

`content/audio/recordings.json` stores exact text, SHA-256, bytes, duration, voice/model/settings, request identifiers, estimated credits and all source references. Completed clips are reused rather than regenerated. A single-process lock prevents overlapping batches. A batch cannot silently change its content version or voice profile.

Before a paid request the tool writes `uncertain-request.json` in the active language's audio directory. If the response or local save is interrupted, generation stops and leaves that journal. If audio arrived, the journal includes its local filename and request ID. Check that file, its hash and decoding, and the provider's generation history. Reconcile its provenance before explicitly resolving the journal or retrying the sentence.

Rate-limited reads use exponential backoff and honor the provider’s `Retry-After` value up to 60 seconds. A generation error preserves the request journal for reconciliation. Diagnostics omit response bodies and authentication headers. Each generation response has a 2 MB cap, and the CLI checks the MP3 codec and duration before accepting the file. [ElevenLabs error handling](https://elevenlabs.io/docs/eleven-api/resources/errors).

## Assemble, listen and publish

```sh
python3 tools/elevenlabs_audio.py verify
python3 tools/export_review.py
```

`verify` requires an actual `recordings.json`. It probes recordings before assembling catalogs, checks text/content hashes and stages immutable MP3 assets under `firebase/public/content/de-en/v2/audio/<sha256>.mp3`. Only clips matching the current pack's text and version enter `App/Resources/audio-catalog.json` and the versioned Hosting catalog. Existing published bytes cannot be overwritten with different content.

Listen to every distributed recording for pronunciation, pacing, clipping and agreement with the authored text, using a German native reviewer. Keep provider provenance separate from human approval. The release compiler requires each unit's native/audio reviewer and timestamp; a nonempty recording catalog also requires its exact `audioCatalogSHA256` in every relevant unit sign-off. Regenerating a clip changes the catalog hash and requires a fresh listening sign-off.

The bundled version 2 catalog matches all 240 final sentences as rendered by Ripple. FFmpeg decoded every MP3, and AVAudioPlayer opened every staged clip after the production cache verified its bytes. Automatic voice uses verified cached recordings. A cache miss starts installed speech immediately and can download a clip for later use. Choosing an installed voice explicitly takes precedence. Playback supports the normal and slower rates, and the recording cache is limited to 20 MB. Downloads use the configured Firebase Hosting origin and verify path, expected bytes, SHA-256 and MP3 headers.

The German playback catalog ships with the application. Adding playback clips requires rebuilding and distributing that app version as well as the static assets. A future lesson without a matching recording uses installed speech. The German and English recording sets are staged locally for listening and the final hosting and privacy review.
