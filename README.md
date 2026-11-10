# Ripple

A native, offline-first German learning app for iPhone and iPad. Written in Swift 6 and SwiftUI, with SwiftData, on-device speech, StoreKit 2, and optional Firebase Spark services. The product specification is [Ripple_PDS.md](Ripple_PDS.md).

## Run

Requirements: Xcode 26.3 or later, an iOS 17+ deployment target, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The included Xcode project can be opened without XcodeGen.

```sh
open Ripple.xcodeproj
```

Choose **Ripple**, select an iPhone simulator, and Run. No credentials or network connection are needed for lessons. The scheme uses `App/Resources/Ripple.storekit` for local purchase testing. The app never invents a successful sign-in, sync, purchase or report submission when its service is unavailable.

To regenerate the project:

```sh
xcodegen generate
```

## Implemented

- Deterministic sentence engine: SUBSTITUTE, INSERT, DELETE and TRANSFORM; authored forms and alternative word orders; stable picker shuffles; Unicode NFC; explicit spawned placement; first-attempt rule attribution; two-error reveal; step reset; automatically derived Peel.
- Three help levels, introductory rule explanations, prerequisite graph, mastery, spaced rule updates, deterministic three-chain scheduling and optional A1–B1 placement.
- Interactive onboarding; Today; complete chain player with drag and tap paths; chain and session summaries; local sentence-image sharing; Rule Map and details; searchable Gallery and sentence timelines.
- SwiftData progress, local 90-day attempt history, saved/resumable sessions, streak calculations, JSON export and local reset.
- Offline German speech and voice selection; haptics/sounds; local daily reminders after the first session; semantic light/dark colors, Dynamic Type, VoiceOver actions and a changed-words rotor.
- StoreKit product loading, verified current entitlements and transaction updates, pending/canceled/error handling, restoring purchases, subscription management, and contextual Pro access.
- Optional Sign in with Apple, nonce protection, Firestore transactions, replay-safe per-device completion counters and compact streak history; reauthenticated account deletion and Apple token revocation; opt-in analytics/crash collection; locally persisted content reports.
- Bundled lessons; immutable versioned Hosting units; SHA-256 checks; same-origin HTTPS downloads; bounded responses; staging and atomic activation; one-version rollback; a 12-hour update window and deterministic seven-day rollout.

## Content

The bundled version 2 pack has **240 chains, 1,690 steps, 51 rules and 927 canonical lemmas**, distributed A1:70 / A2:100 / B1:70. Every lemma occurs in an actual sentence. Each rule appears in at least 14 chains; no-change steps make up 14.2%. The compressed full pack is 111,750 bytes.

The authored scenarios cover 12 themes, with 238 distinct starting sentences, 240 distinct final sentences and 1,926 distinct sentences overall. Explicit noun/verb paradigms, varied activities and people, emotion narratives, separable verbs and fronted subordinate clauses improve variety while retaining declared grammar dependencies. Vocabulary teaching bands are provisional. **Native-speaker review and listening sign-off are pending.** Version 2 is bundled and staged locally; published version 1 and the live Remote Config content version remain unchanged.

```sh
python3 tools/author_scenarios.py      # regenerate the curated scenario worksheet
python3 tools/author_content.py        # regenerate explicit snapshots and vocabulary
python3 tools/ripplec.py               # validate and compile app + Hosting files
make content                          # check all generated content against its sources
python3 tools/export_review.py         # base, step, vocabulary and unit-hash worksheets
python3 tools/ripplec.py --check --release  # requires real per-unit sign-offs
```

Edit `content/authoring/vocabulary-v2.tsv` and the curated rows in `tools/author_scenarios.py`; sentence construction and morphology live in `tools/content_v2.py`. `content/authoring/scenarios-v2.json` and `content/source/pack.json` are generated, reviewable outputs. Preserve editorial corrections in these authoring sources before regenerating. Never overwrite versioned Hosting files after publishing. See [the content report](docs/CONTENT_V2.md).

ElevenLabs produced 240 German recordings and 240 matching English recordings for the final lesson sentences. Each set has a version 2 catalog and verified MP3s staged for listening review. Ripple uses the German playback catalog with a bounded recording cache and on-device speech fallback. [Audio authoring and budget](docs/AUDIO_AUTHORING.md).

## Verify

```sh
swift test --package-path Packages/RippleCore --enable-code-coverage
xcodebuild -project Ripple.xcodeproj -scheme Ripple \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
cd firebase
npm ci --ignore-scripts
npm run test:rules
```

`RippleCore` tests auto-solve every chain in both directions and verify every authored dependency. Additional tests cover validation, learning, scheduler behavior, merge properties, interrupted content updates, SwiftData completion/checkpoint behavior, StoreKit refund handling, and the tap-only demo. Firebase tests use an isolated `demo-ripple` emulator project, never production data.

The complete StoreKit suite was verified on iOS 26.1. The installed iOS 26.3 simulator returns `SKInternalErrorDomain Code=3` and `notEntitled` before purchase tests can configure their local environment. Use 26.1 for those tests; this is recorded separately from app assertions. `make verify` runs authoring, core, native and Firestore suites (install Firebase test dependencies first).

## Service setup and release

See [docs/SETUP.md](docs/SETUP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and [docs/PRODUCTION_READINESS.md](docs/PRODUCTION_READINESS.md).

The authorized Firebase project **`ripple-grammar-2026`** is created on Spark with billing disabled. Its EU `eur3` Firestore database, owner-only rules, anonymous report authentication, Hosting content and Remote Config are deployed. App Attest is registered and Firestore App Check is enforced. The genuine matching `GoogleService-Info.plist` is present locally and excluded from git. A fresh clone can still run all lessons offline without it.

Apple team **`WH9D3XTKPT`** and bundle **`app.ripple.grammar`** are configured. The App ID has Sign in with Apple and App Attest capabilities. The dedicated Apple key is registered and configured in Firebase Authentication; its private material is stored only in the ignored secrets directory. App Store Connect contains the **Ripple: German Grammar** draft (Apple ID `6831985594`) and the three approved Pro product drafts, with manual release selected. Apple authentication and revocation still need a real-device end-to-end test. This Mac has no code-signing identity.

[Support](https://app-support.anton-chepur.chatgpt.site/ripple/support/) and [privacy policy](https://app-support.anton-chepur.chatgpt.site/ripple/privacy/) are published on the existing developer support website and configured in the app.

```sh
python3 tools/release_check.py
```

This command is expected to fail until the remaining editorial sign-offs, device checks and release evidence are supplied. Simulator tests cannot establish real-device performance, VoiceOver quality, App Attest acceptance, App Store review compliance, learning efficacy, or beta retention.

The content/audio pass passed **33 core tests (87.8% source line coverage), 15 native app/UI tests and 12 authoring/audio-tool tests**, with separate long-sentence summary checks on phone and iPad. The unchanged Firestore rules retain seven passing emulator tests from the prior verification. The optimized unsigned device application is **36.9 MiB**. Tests also cover 20,000-session compaction, legacy event migration, thirty years of streaks, cross-device replay, a persisted SwiftData store upgrade, 90-day attempt retention and complete local data export. The tested version 2 Firestore rules are deployed. Earlier live service checks confirmed full 51-rule writes/reads, ownership denial, authenticated reports and exact version 1 Hosting bytes; their temporary accounts and documents were removed. The listing and five native screenshots for each required phone/tablet slot remain saved in the manual-release App Store draft. See the readiness document for exact evidence and remaining gates.
