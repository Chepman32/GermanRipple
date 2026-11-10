# Architecture

`App/` is the native SwiftUI application. `Packages/RippleCore/` is a local Swift package containing four independently testable modules. Swift 6 strict concurrency is enabled. Deployment starts at iOS 17; SwiftUI Observation and SwiftData are used directly.

| Module / directory | Responsibility |
|---|---|
| RippleEngine | Codable authored content, card application, player state machine, validation, stable distractor shuffle and inverse snapshots. Pure Swift; no network, persistence or UI. |
| LearningModel | Per-rule strength and spacing, prerequisites, hints, placement, deterministic scheduler, local-calendar streaks. Time is supplied to calculations. |
| ContentKit | Schema validation, unit/manifest models, HTTPS download transport, SHA-256, content-addressed content/audio caches, staging, atomic pointer and rollback. |
| SyncKit | Versioned compact cloud state, per-replica counters, latest-rule merge, legacy event union, archived streak bitmaps and the `ProgressSyncing` protocol. |
| App/Application | Composition, observable settings, practice sessions, orchestration and the single local persistence boundary. |
| App/Persistence | SwiftData models. Rules, completions, attempts, streak days, content state, reports and a resumable session checkpoint. |
| App/Services | Optional recorded German speech with on-device TTS fallback, feedback, notifications, verified StoreKit, optional Firebase and Apple authentication. |
| App/Design | Semantic light/dark colors, typography, flow layout, controls, mastery segments and geometric ripple mark. |
| App/Features | Today, player, onboarding, placement, summaries, Rule Map, Gallery, settings, reports and paywall. |
| tools | Deterministic authoring, content compiler/lint, review exports, rule generation and release checks. |
| firebase | Hosting content, Remote Config defaults, deny-by-default Firestore rules and emulator tests. No Functions or Storage. |

The PDS's Apple-specific SPM modules are organized as application directories, sharing one composition target rather than separate packages. Their services are isolated from the pure engine and learning modules. Firebase is linked but configured only when a valid matching `GoogleService-Info.plist` exists. No runtime AI is used.

## Learning transactions

A session snapshots its chains, mode, shuffled-option seed, initial strengths and complete player state. Every interaction updates the checkpoint. Completing a chain inserts its completion, updates rule records and the practice day, saves attempts and the summary checkpoint in the same SwiftData save. The committed chain index prevents duplicate scoring after resume. Failed saves roll back the context and leave the lesson retryable.

Rule scoring preserves errors from the first check even if the learner resets or later solves the step. A first encounter is a protected exposure. Mastery additionally requires correct unaided answers in three distinct chains. Detailed attempt history is retained locally for 90 days.

## Content lifecycle

`content/source/pack.json` contains complete target snapshots with stable token IDs. `ripplec` compiles the bundled baseline and 20-chain units. Each unit filename includes its SHA-256 prefix; the manifest contains the full hash. The app validates references against the configured HTTPS origin, checks downloaded bytes, decodes and lints the full pack, writes a staging directory, then atomically changes `active.json`. `previous.json` provides one fallback. Existing sessions use their own immutable chain snapshots during updates.

The version 2 authoring sources separate curated scenarios, explicit noun/verb paradigms and sentence construction. The generator emits 927 actually used canonical lemmas and 240 complete chains; the compiler rejects unused vocabulary and missing dependency coverage. Generator checks prevent hand-edited output from silently drifting from its source. Native review still determines linguistic quality and teaching-band suitability. Version 2 is staged locally; version 1 remains the published remote content.

The hash ensures bytes match the trusted manifest; it is not a signature independent of the Hosting origin. Hosting account security and HTTPS remain part of the trust boundary.

## Recorded speech

ElevenLabs is used only by an authoring CLI. It sends authored lesson sentences, keeps its private key outside app resources, refuses redirects, checks explicit character/credit limits and the account reserve before each paid request, and journals uncertain requests to prevent automatic duplicate spending. Received MP3s are probed and addressed by SHA-256. The provenance file retains the exact normalized text, voice/model settings, request identifiers and source references. A nonempty recording catalog adds a hash-specific listening approval to the content release gate.

The optional bundled catalog maps an NFC text hash to a same-origin, versioned MP3 path, expected byte count and content hash. `RecordedAudioCache` shares in-flight requests, validates bytes/hash/MP3 headers, writes atomically and retains at most 20 MB using LRU eviction. `AudioService` plays a verified cached recording when Automatic voice is selected. An absent, invalid or uncached clip uses installed German speech immediately; a download may populate the cache for a later request. An explicit installed voice takes precedence. Playback generations and cancellation prevent stale asynchronous callbacks from starting old speech. Automated native tests disable recording downloads.

The version 2 catalog contains 240 final-sentence recordings. Each staged file passed an exact text, byte count, SHA-256 and decoder check. Installed German speech covers intermediate steps and cache misses. The recorded set is awaiting native listening review. [Audio authoring](AUDIO_AUTHORING.md).

## Optional sync

The device remains the source of truth. A Firestore transaction reads one progress document, merges, and writes once. Per-rule state uses the later `lastSeen`; exact-time conflicts use a stable tie breaker. Version 2 groups completions by chain and mode, keeps the latest result, earliest completion and best first-try rate, and merges per-replica counters by `max`. Independent offline practice adds across replicas; replaying shared history does not add again. A random replica identity and its counters live in SwiftData and are committed atomically with each completion/checkpoint. Local reset discards that identity and creates a fresh one.

Streaks keep exact daily counts in the most recent 400-day window. Earlier practiced-day presence is stored as a 46-byte bitmap per year and merged with bitwise OR. The window is anchored to the latest recorded practice day, so results are deterministic without a wall-clock dependency. Detailed local history remains on the device and in its export; a new device receives aggregate history and the latest completion for each chain/mode. Vocabulary exposures import only the added completion count, so repeated sync does not inflate them. Signing out during an in-flight sync prevents its response from being imported.

Firestore enforces authenticated ownership, the typed root schema, server timestamps, the authored rule-ID allowlist and bounded collection sizes. Detailed nested rule values are validated by `ProgressSnapshot.validated()` on upload and import. Fully expanding all 51 nested rules exceeded Firestore's 1,000-expression evaluation budget; the deployed schema has a test using the complete app payload. A malicious owner can damage only their own learning document. Cloud progress never grants StoreKit access. Reports have strict server-side field, reason, note-length and ownership checks, and clients cannot read submitted reports.

Detailed attempts and sentence snapshots are not uploaded. A remote completion is matched to the local content catalog when imported. Existing version 1 documents are read and migrated: exact timestamp bit patterns retain overlapping legacy event identities without storing their full event objects. New writes require version 2. The local store migration preserves detailed history. The cloud format bounds catalog groups to 1,024, replica components per group to 128, archived years to 256, and the encoded document to 800,000 bytes. These are structural safeguards, rather than a limit on ordinary daily completion history. Tests verify 20,000 new completions in under 2 KB, exact migration of 20,000 legacy events, offline replay, thirty years of streaks, and persisted SwiftData migration.

## Entitlements and privacy

Only StoreKit `verified` current entitlements grant Pro access. Revocation, expiration and upgrades are respected, and transactions are finished only after verification. A cached status is display-only. StoreKit's local signed transaction database supports offline entitlement validation.

Analytics and crash upload default to off in the Info.plist and remain disabled until consent. Advertising storage and personalization consent remain denied. The project links Firebase Analytics Core without identity/ad support. Account deletion reauthenticates through Apple, revokes authorization, deletes the known `de-en` progress document and user document, and deletes the Auth user. Local reset is separate.

Automated app tests explicitly disable the cloud layer and content downloads, even when a genuine Firebase configuration is present. SwiftData uses isolated in-memory containers. Reusing an app-store instance reuses the default Firebase app instead of configuring it twice. Simulator debug App Check tokens are not authorized against production.
