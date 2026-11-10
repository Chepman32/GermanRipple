# Content and recorded speech, version 2

The bundled and locally staged version 2 expands the library from 223 to **927 canonical lemmas**, all used in actual sentences, while preserving the 240-chain A1:70 / A2:100 / B1:70 curriculum. Existing chain IDs remain stable. Saved sessions retain their original snapshots; a new replay uses the installed pack. Published version 1 and the live Remote Config version have not been changed.

## Measured result

| Measure | Version 2 |
|---|---|
| Chains / steps / rules | 240 / 1,690 / 51 |
| Used canonical lemmas | 927; unused dictionary entries rejected |
| Distinct base / final sentences | 238 / 240 |
| Distinct sentences including intermediate states | 1,926 |
| Themes | 12 |
| Minimum chains covering one rule | 14 |
| No-change steps | 240, or 14.2% |
| Final sentence budget | At most 22 words |
| Full pack gzip | 111,750 bytes |
| Automated editorial warnings | 0; this is not native approval |

The themes cover cafés, city life, family, food, free time, health, home, plans, shopping, travel, weather and work. Curated scenarios vary activities, objects, professions, companions, adjectives and time/manner/place phrases. Explicit paradigms cover noun gender/plural, weak masculine forms, mass nouns, regular/irregular and separable verbs, adjective elision and participles. Emotion narratives replace repeated obligation wording, and B1 contrast scenarios vary the position of the subordinate clause. Inflected `Stühle` belongs to `Stuhl`, and `würden` belongs to `werden` rather than counting as separate vocabulary.

For example, `de.a2.cafe.001` grows “Ich esse Salat.” into “Gestern haben wir mit meinem Mitbewohner einen vegetarischen Auflauf gegessen, weil wir hungrig waren.” B1 scenarios also include initial `Obwohl …` clauses with the corresponding main-clause inversion. These authored constructions and translations still need native review for naturalness and teaching suitability.

Vocabulary teaching bands are provisional author assignments: A1 253, A2 418, B1 256. Automated counts do not establish externally certified CEFR levels.

## Sources and reproducibility

- `content/authoring/vocabulary-v2.tsv`: explicit noun bank and English glosses.
- `tools/author_scenarios.py`: curated scenario/verb rows; emits `content/authoring/scenarios-v2.json`.
- `tools/content_v2.py`: deterministic morphology and sentence/dependency construction, using canonical helpers from `tools/author_content.py`.
- `content/source/pack.json`: generated complete snapshots; compiled into `App/Resources/baseline.json` and twelve version 2 Hosting units by `tools/ripplec.py`.

Run `make content` to check every generated layer. `python3 tools/export_review.py` emits 240 base sentences, 1,690 steps and 927 vocabulary rows plus the twelve current unit hashes. Existing reviewer approvals are preserved separately; none has been entered for these units.

## Constraints

- Every vocabulary entry must occur in a sentence, with a canonical lemma, English gloss and authored forms. Inflections, proper-name variations and unused dictionary entries do not establish vocabulary breadth.
- Each rule occurs in at least 12 chains. Chains have 5–8 changes, no-change steps remain 10–20%, and final sentences stay within the phone layout budget.
- All chains must solve in both directions, using only their declared dependencies. Editorial review covers naturalness, translation, CEFR placement, distractors and alternative orders.
- Version 1 published files are immutable. Version 2 has new unit hashes; old review signatures cannot be reused. Native and listening approvals remain explicit human release gates.
- ElevenLabs is an authoring-time service. Only authored lesson text is sent to it. No learner text, progress or identity is sent to ElevenLabs by the app.
- The supplied key stays in the ignored, permission-restricted secrets directory. It is never bundled, written to logs or embedded in command arguments.
- Generated audio is content-addressed, tied to exact text and voice/model settings, reusable without another paid request, and checked before playback. Missing or invalid recordings use on-device speech.
- Generation must stay within the account's available credits and an explicit task limit. No billing upgrade, additional credit purchase or change to overage settings is authorized by this workflow.

## Acceptance

All 240 chains solve forward and in Peel with every declared dependency reachable. The 33 core tests pass with 87.8% source line coverage. Native tests exercise the expanded A2 café and B1 initial-subordinate scenarios on phone and tablet, including long sentences, heading visibility and the summary exit action. A summary scroll reset fixes a retained offset exposed by those checks; unaltered screenshots and provenance are in `docs/screenshots/content-v2/`.

The recording plan deduplicates exact NFC text across 240 German final sentences and 1,926 total German sentences. ElevenLabs generated all 240 German finals and the 240 matching English translations. Twelve authoring tests cover normalization, language separation, credits, rate limits, integrity and recovery. Both sets pass full decoding. The German clips also match Ripple's sentence renderer and pass the app cache's integrity checks. Native-speaker listening approval remains a release gate. [Audio authoring](AUDIO_AUTHORING.md).

## Open release gates

Native editorial and audio listening reviewers, physical-device acceptance, signing, real Apple authentication and sandbox billing, privacy review and beta evidence remain required. This content/audio pass does not certify those results.
