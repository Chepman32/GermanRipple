# Ripple agent guide

This guide applies to the entire Ripple workspace. Follow any more specific instructions for the directory being edited. Use the current user request to set the scope of the work and the connected accounts it authorizes.

## Start here

Ripple is an offline-first German grammar app for English speakers on iPhone and iPad. A learner applies a change to a sentence, fixes the resulting grammatical dependencies, then checks the new sentence. Preserve that interaction and its learning value when changing the app or the curriculum.

| Question | Source of truth |
| --- | --- |
| What experience should the learner get? | [Ripple_PDS.md](Ripple_PDS.md), especially §§5–12 for the player, learning model, accessibility and content |
| How does the current implementation work? | [Architecture](docs/ARCHITECTURE.md), package code, app composition and tests |
| What should be edited or regenerated for a curriculum change? | [Content v2](docs/CONTENT_V2.md), `content/authoring/` and `tools/author_*.py` |
| How are speech recordings planned, budgeted and verified? | [Audio authoring](docs/AUDIO_AUTHORING.md) and `tools/elevenlabs_audio.py` |
| Which cloud, signing and store resources are configured? | [Setup](docs/SETUP.md), `project.yml` and the relevant account's current state |
| What evidence is still required for distribution? | [Production readiness](docs/PRODUCTION_READINESS.md), [Privacy review](docs/PRIVACY_REVIEW.md) and `content/review/release-evidence.json` |

Use the PDS for product intent. For implementation details that have evolved, check the current code, generated schemas and tests. In particular, the deployed compact sync format has a version 1 migration path and version 2 writes. The PDS's original sync sketch predates that migration.

### Discover code before editing

1. Prefer `codebase-memory-mcp` for code discovery. Match the indexed project to the current checkout root. The index in the original workspace is named `Users-antonchepur-Ripple`. Run `index_repository` for the current root if its project is missing, and refresh a stale index when its results no longer match the workspace.
2. Use `search_graph` to find symbols, `trace_path` to inspect callers and dependencies, and `get_code_snippet` to read the exact definitions. Use `query_graph` for cross-module questions, `get_architecture` for orientation, and `search_code` for graph-assisted text search.
3. Use `rg` or `rg --files` for configuration, literal text, authoring scripts omitted from the index, and cases where graph results are insufficient. Exclude build output, dependencies, private credential directories and bulk generated artifacts from broad searches. Read large packs by selecting the relevant chain, rule or token instead of dumping the complete file.
4. Inspect the current source and the closest existing tests before editing. Trace the change through its normal entry point, including persistence, content generation or release checks where relevant. Prefer small changes that reuse the existing model and services.

Some workspaces are exported directories. Check `git rev-parse --show-toplevel` before relying on branches, diffs, worktrees or remotes. Preserve existing edits and user assets. Keep transient logs, local builds and test result bundles under the ignored `.build/` directory.

## Toolchain and local commands

- The app targets iOS 17 and uses Swift 6 with complete concurrency checking. The local `RippleCore` package also supports macOS 14. The established native verification uses Xcode 26.3.
- Open `Ripple.xcodeproj` and run the `Ripple` scheme. The bundled baseline supports local lessons in a fresh checkout. Firebase features activate when the matching optional configuration is available. `App/Resources/Ripple.storekit` provides the local purchase catalog.
- Edit `project.yml` for target, scheme, package, Info.plist and generated entitlement changes, then run `make project`. Check the regenerated Xcode project and affected derived files. Keep the Release App Attest entitlement in `App/Ripple.Release.entitlements`. Use the pinned Firebase iOS dependency and the SwiftPM lockfile for reproducible builds.
- Use Python 3 for authoring and `ffprobe` plus FFmpeg for recording verification. Firebase rules tests use the lockfile in `firebase/`. CI uses Node 24 and Java 21. Install dependencies once with `(cd firebase && npm ci --ignore-scripts)` before the rules suite.

Run commands from the repository root unless a command changes its working directory.

| Command | Use |
| --- | --- |
| `make project` | Regenerate the Xcode project with XcodeGen after a project spec change |
| `make content` | Check scenario, pack and compiled content reproducibility without rewriting it |
| `make test-authoring` | Run content checks and the Python authoring and audio tests |
| `make test-core` | Run the pure Swift package tests with source coverage, including whole-catalog solving |
| `make test-ios` | Run the app and UI suites on the configured simulator |
| `make test-rules` | Run Firestore rules tests in the isolated `demo-ripple` emulator project |
| `make verify` | Run the authoring, Swift core, native and Firestore suites for a broad change or release candidate |
| `make release-check` | Validate the current content sign-offs, environment setup and distribution evidence |

The default native test destination is iPhone 16e on iOS 26.1. Inspect available devices with `xcrun simctl list devices available` and override `IOS_DESTINATION` with an appropriate simulator ID when needed. Prefer iOS 26.1 for StoreKit tests. On the previously tested iOS 26.3 runtime, StoreKitTest failed during environment setup with `SKInternalErrorDomain Code=3` and `notEntitled`. Treat that as an environment issue and preserve the purchase assertions.

```sh
make test-ios IOS_DESTINATION='platform=iOS Simulator,id=YOUR_SIMULATOR_UDID'
swift test --package-path Packages/RippleCore --filter RecordedAudioTests
```

Use an unsigned device build to check Release compilation and bundle contents. Keep the result distinct from the signed archive used for distribution.

```sh
xcodebuild -project Ripple.xcodeproj -scheme Ripple -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/ReleaseData \
  CODE_SIGNING_ALLOWED=NO build
```

## Code map and ownership

| Area | Entry points and boundaries |
| --- | --- |
| App composition and orchestration | `App/Application/RippleApp.swift`, `AppStore.swift` and `Settings.swift` own startup, session coordination, settings and the app's persistence boundary |
| Authored grammar and player | `Packages/RippleCore/Sources/RippleEngine/Content.swift`, `Player.swift` and `Peel.swift` own token models, card semantics, validation and reverse derivation |
| Learning | `Packages/RippleCore/Sources/LearningModel/Learning.swift` owns rule strength, prerequisites, hints, placement, scheduling and streak calculations |
| Pack loading and recorded speech cache | `Packages/RippleCore/Sources/ContentKit/ContentPack.swift` and `RecordedAudio.swift` own decoding, transport, integrity checks, atomic activation and caching |
| Cloud data contracts | `Packages/RippleCore/Sources/SyncKit/ProgressSync.swift` and `CompactProgress.swift` own merge, versioned representation and validation |
| Local data | `App/Persistence/Models.swift` and `VocabularyExposureRecord.swift` hold the SwiftData models and persisted progress |
| Screen and component behavior | `App/Features/` holds onboarding, Today, practice, summaries, Rule Map, Gallery, settings, reports and paywall. `App/Design/DesignSystem.swift` supplies shared colors, typography, layouts and controls |
| Platform and cloud services | `App/Services/AudioService.swift`, `ReminderService.swift`, `PurchaseService.swift` and `FirebaseServices.swift` own the corresponding platform integrations |
| Authoring and release tooling | `tools/`, `content/authoring/`, `content/review/` and `firebase/` hold the compilation, staging, validation and publication inputs |

Keep grammar and learning calculations in the pure Swift package. Use the existing module dependencies. Pass the time and seed into deterministic calculations. Keep SwiftUI and SwiftData access at the app boundary and isolate platform or network work in the existing services. Preserve cancellation and actor isolation when moving asynchronous work, especially around audio, session changes and account changes.

### Engine and learning invariants

- Preserve token identity across a chain. Duplicate visible words can have distinct IDs. Resolve forms and positions by token ID and use the authored snapshots as targets.
- Keep SUBSTITUTE, INSERT, DELETE and TRANSFORM deterministic. A valid step requires the authored forms, an accepted token order and placement of every spawned token. Compare Unicode NFC text and preserve meaningful German capitalization. Use the shared sentence renderer for capitalization and punctuation in display and speech.
- Keep option order stable across retries and resume. Preserve authored distractor forms, complete accepted permutations and explicit rule tags for cards, fixes and moves. Derive Peel from the forward snapshots and test both directions when changing the engine or a chain.
- Preserve the guided, counted and free hint contract. Use the weakest applicable rule, first-encounter guidance and the user's Always guided preference to determine help. Keep no-change steps explicit and solvable.
- Attribute mistakes to the applicable rule tags and retain first-check errors through retries, reveal and reset. Preserve first-encounter protection within a chain and the requirement for correct unaided answers in three distinct chains before mastery.
- Keep Today scheduling, prerequisites, placement and streak calculations deterministic for the same input. Use the product's local-calendar semantics for practice days and injected dates in tests.

### Persistence and resume

- Treat `AppStore` as the write boundary for learning state. A chain completion, its rule updates, attempts, vocabulary, practice day, compact counters and summary checkpoint belong in one save. Keep the committed position guard and rollback behavior so retrying or reopening the app cannot score a chain twice.
- Save enough session state to replay the exact chain and option order after reopening. Retain saved chain snapshots and recorded history when a new content pack installs. Preserve separate forward, Peel, demo and placement behavior.
- Keep detailed attempts local and apply the 90-day retention policy. Preserve recent attempts and reports in user exports as documented. Reset learning through the existing reset path, which also rotates the local replica identity and preserves purchases.
- Treat persisted SwiftData and sync schemas as compatibility contracts. When editing them, exercise a real older persisted fixture as well as a fresh store. Verify rollback, checkpoints and replayed imports for any change that could double-count progress.

### Interface and accessibility

- Use the shared design system for colors, typography, spacing, buttons and layouts. Preserve semantic light and dark appearance and visible state cues in addition to color.
- Give every drag action a tap path. Preserve accessible labels, move actions, the Changed words rotor, and the learner-facing step announcements. Keep token and control hit regions at least 44 × 44 pt where required by the PDS.
- Keep long sentences, token pickers and translations reachable at AX5 and on compact phones. Check the summary heading and exit action after a long lesson and on iPad. Preserve the summary scroll reset and stable word hit regions while decorative animations run.
- Respect Reduce Motion and user feedback settings. Keep focus, action ordering and scroll behavior stable across validation, reveal and sheet dismissal. Retain existing UI test identifiers when the action still means the same thing.
- Keep the first lesson usable offline and without account or purchase setup. Place purchase prompts at the product's natural stopping points and keep the active lesson available to finish.

## Curriculum and generated content

### Edit the inputs

| Path | Role |
| --- | --- |
| `content/authoring/vocabulary-v2.tsv` | Editable noun bank and English vocabulary glosses |
| `tools/author_scenarios.py` | Curated scenarios, family rows and verb inputs |
| `tools/content_v2.py` and `tools/author_content.py` | Morphology, explicit paradigms, sentence construction and pack assembly |
| `content/authoring/scenarios-v2.json` and `content/source/pack.json` | Deterministic outputs to inspect during review |
| `App/Resources/baseline.json`, `content/quality-report.json` and `firebase/public/content/` | Compiler outputs and staged versioned units |
| `content/review/` | Review worksheets, required hashes, actual approvals and release evidence |

Make lasting edits in the owning authoring input or generator. Regenerate in dependency order and review the resulting sentence, translation and dependency changes before broadening the edit.

```sh
python3 tools/author_scenarios.py
python3 tools/author_content.py
python3 tools/ripplec.py
make content
python3 tools/export_review.py
```

### Preserve content contracts

- The current pack is `de-en`. Its curriculum contract is 240 chains across A1 (70), A2 (100) and B1 (70), with 5–8 steps per chain. Every rule appears in at least 12 distinct chains. Keep no-change steps within 10–20% and include an explanation for each.
- Keep chain, token and rule IDs stable where their identity still applies. Changes to IDs affect sessions, replays, sync, reports, rule coverage and audio references. Plan migrations for genuine identity changes.
- Validate every transition from the previous snapshot, with declared form and position dependencies. Keep prerequisites acyclic and distractors distinct from the answer. Use complete token permutations for alternate accepted orders and include only defensible German sentences.
- Count canonical lemmas actually used in sentences. Keep the lexicon aligned with those tokens and preserve English glosses and authored forms. Use `content/quality-report.json` for measured counts, compressed size and compiler warnings. The compiler flags more than three dependencies in a step and final sentences above 22 words for editorial attention.
- Keep generated JSON deterministic so reviewers can compare real changes. The compiler assigns each unit a SHA-256 and groups chains into 20-chain units. Assign a deliberate manifest timestamp when introducing a new pack version.
- Track the app's marketing and build versions, pack version, content schema and sync schema independently. Use the relevant validator and migration for each change.
- Treat released version directories as immutable. Stage changes under a new version and preserve the previous published assets for clients and rollback. Validate same-origin HTTPS paths, payload sizes, schemas and hashes before activation. Preserve the 12-hour update window, deterministic rollout, atomic active pointer and previous-version fallback.

### Editorial evidence

Use `bases.tsv`, `steps.tsv` and `vocabulary.tsv` for native review. Review naturalness, translations, provisional CEFR placement, distractors, allowed orders and pronunciation. Automated solving and lint establish structural correctness and reproducibility. A native reviewer supplies the editorial and listening approvals.

`required-signoffs.json` is a template keyed by the current unit hashes. Record actual reviewer names and ISO timestamps in `signoffs.json` for the exact units reviewed. When the bundled audio catalog has clips, include its exact `audioCatalogSHA256`. Regenerate the worksheet after a change to the reviewed bytes and obtain approvals for the new hashes. Preserve existing signed records when exporting templates.

## Recorded speech

Use ElevenLabs only for authoring lesson assets. The app reads static German recordings and uses on-device German speech. Keep learner data, app credentials and cloud identifiers out of provider requests. The intended provider input is the authored lesson sentence.

| Set | Text and identity | Local source and staging |
| --- | --- | --- |
| German | Exact rendered sentence text, normalized to NFC. `final` plans final sentences and `all` includes base and intermediate steps | `content/audio/recordings.json` and `content/audio/clips/`. Staged `audio/` and `audio-catalog.json` under the versioned Hosting pack. The German playback catalog is also `App/Resources/audio-catalog.json` |
| English | Exact final `gloss.en` with the same chain ID and final step index as its German counterpart | `content/audio/en/recordings.json` and `content/audio/en/clips/`. Separate staged `audio-en/` and `audio-catalog-en.json` under the same pack version |

Use `--language en` for the English final-sentence set. The version 2 assets include 240 final clips in each language. Use `chainId` and `step` in the recording manifests to match them. Text hashes identify the spoken text and file hashes identify the resulting MP3 bytes.

```sh
python3 tools/elevenlabs_audio.py plan --scope final
python3 tools/elevenlabs_audio.py plan --language en
python3 tools/elevenlabs_audio.py verify
python3 tools/elevenlabs_audio.py verify --language en
```

- Use the local `plan` command to count unique text and workload before accessing the provider. Use `inspect` on the authorized account to read its current balance, available model and language metadata. Keep the API key in the ignored private key file with mode 0600 and pass credentials through the CLI's supported path.
- Before a paid batch, choose the voice and model, verify the current rate, and set explicit maximum characters, credits and clips plus a credit reserve. Check a small sample first. Reuse completed recordings, keep the existing voice profile for a resumed batch, and use the generation lock to keep a single writer. See [Audio authoring](docs/AUDIO_AUTHORING.md) for the exact `generate` options.
- Treat estimates as caps for planning. The generator checks each estimate against a recent balance minus prior reservations and refreshes the balance after five seconds or when needed to protect the reserve. Reconcile actual `characterCost` receipts and the settled account balance before reporting remaining capacity. Use a conservative round-up for future clip estimates.
- Honor bounded backoff for rate-limited reads and preserve the redirect guard. If a generation fails after it may have reached the provider, retain the language directory's `uncertain-request.json`. Reconcile the request, local file, provider history and charge before resolving that journal or repeating the request. Keep provider request IDs and text, voice, model and content provenance with the assets.
- Check the MP3 codec, duration and full decoding for the generated set. Verify text and file hashes, byte counts, source-to-stage equality and references to the exact lesson snapshot. Verify the German catalog against the app's renderer and cache when changing playback. Refresh the listening-review hash for changes to the bundled German catalog.
- Keep German playback offline-capable. Automatic voice can use a verified cached recording. A cache miss starts installed speech immediately and may fetch the static clip for future playback. A user-selected installed voice takes precedence. Preserve the 20 MB cache limit, integrity checks and stale-playback cancellation. Stage the audio files for Hosting to protect the app size budget.

## Sync, Firebase and privacy

- SwiftData owns local learning state. Sync is an optional background merge through `ProgressSyncing`. Read, merge and write the signed-in user's progress document in one Firestore transaction. Drop responses from a signed-out or replaced account.
- Keep compact merges deterministic and replay-safe. Rule state uses the latest `lastSeen` with a stable tie break. Completions merge per chain and mode, with per-replica counters merged by maximum. Preserve recent daily streak counts and archived yearly bitmaps. A legacy version 1 document can be read and migrated. Version 2 is the current write contract.
- Keep `ProgressSnapshot.validated()`, Firestore rules and the clients aligned. Preserve bounds on catalog groups, replicas, archived years and encoded bytes. Detailed attempt records and authored session snapshots belong in local storage. Import only the added completion count into vocabulary exposures so repeated sync preserves totals.
- Keep `firebase/firestore.rules` deny-by-default. Enforce ownership, allowed document shapes, timestamps and the rule-ID allowlist. Reports require authentication and bounded fields, and use a create-only client path. Exercise a complete 51-rule payload when editing the rules so changes stay within Firestore's expression budget. Review `tools/generate_rules.py` when changing the rule taxonomy.
- Run rules tests with the isolated `demo-ripple` emulator. Keep ordinary app and UI tests on their isolated in-memory and cloud-disabled paths. The historical live smoke tool targets a restricted pre-enforcement scenario. Use the documented live environment and authorization for any real service test.
- Read `docs/SETUP.md` before connected-service changes. Use the explicit `ripple-grammar-2026` target for authorized work on the configured Spark project and scope deployments to the affected services. Inspect both the staged Hosting tree and the live Remote Config value because a Hosting deployment uploads the configured public tree. Preserve App Check enforcement and use simulator debug tokens only in a dedicated development project.
- Bundle Firebase configuration only through the existing optional build script and use the matching iOS registration. Keep nonce validation, reauthentication, Apple token revocation and known-document deletion in the account flow. Preserve local reset as a separate action.
- Keep analytics and diagnostics off by default and tied to explicit consent. Preserve consent withdrawal, local export, retention and report handling. Verify privacy disclosures against actual enabled SDK behavior before release.
- Keep provider keys and signing material in private ignored locations such as `.secrets/`. Keep the real Firebase plist in its ignored local path for the optional build script. Keep private review contact details in App Store Connect. Use bounded, sanitized diagnostics and exclude credentials and private data from logs, screenshots and replies.

## Purchases and distribution

- Use `PurchaseService` and StoreKit 2 as the entitlement boundary. Grant Pro from verified current entitlements, with expiration and revocation respected. Handle pending, canceled, failed and refunded purchases through their existing paths. Use cached state for display and revalidate through StoreKit.
- Keep the product IDs stable. `app.ripple.pro.monthly` and `app.ripple.pro.yearly` are subscriptions. `app.ripple.pro.lifetime` is non-consumable. Read localized prices and offer eligibility from the selected StoreKit product. Show trial terms only for a real eligible offer. Preserve restore, subscription management and paywall dismissal.
- Use `App/Resources/Ripple.storekit` and StoreKitTest for local tests. Use Apple sandbox or TestFlight for the live catalog, introductory eligibility, restore, renewal, expiration, retry and revocation. Keep store pricing, availability and release mode within the approved changes.
- Use `docs/app-store-metadata.json` and `docs/app-store-screenshots/` as the sources for draft metadata and verified capture provenance. Use `site-support/ripple-pages.json` and its preparation tool for support or policy changes. Coordinate real store and website updates with the user's release scope.

### Release sequence

1. Establish the exact target pack, app build, service project and authorized scope. Read the current readiness and setup docs. Prepare a reviewable local result before requesting any required approval for an external action.
2. Run the relevant test suites and verify the Release bundle. Check resources, size, bundle ID, package pins, entitlement configuration and credential handling. Use the performance budgets in PDS §13.6, including the 40 MB app budget and 400 KB compressed lesson pack budget.
3. Export the content and listening worksheets and collect actual native approvals tied to the current hashes. Run `python3 tools/ripplec.py --check --release` against the reviewed pack and catalog.
4. For an authorized content release, upload the reviewed versioned assets first and verify the served manifest and asset bytes. Advance Remote Config only after the remote pack is valid and available. Keep the previous version usable for the app's rollback path.
5. Verify signing and the distribution archive, physical App Attest, real Apple sign-in and deletion, sandbox purchases, privacy/legal review, opt-in symbolicated crash delivery and the physical accessibility and performance checks. Upload dSYMs with `tools/upload_symbols.sh` against the actual signed archive where required. Collect the TestFlight evidence defined by the PDS and readiness document.
6. Record the artifacts and measured outcomes in `content/review/release-evidence.json`. Run `make release-check` before app distribution and investigate any missing gate it reports. Use the actual validation scope when reporting readiness. Submit or publish only as part of the authorized release action.

## Verification and handoff

Choose checks based on the behavior changed. Add a test when it captures a specific regression or contract the existing suites would miss. Reuse existing fixtures and stable test IDs.

| Change | Check before handing it back |
| --- | --- |
| Authoring inputs or compiler | `make test-authoring` for reproducibility and authoring tests. Use the core whole-catalog tests for new transitions, accepted orders, coverage or Peel behavior |
| Player, learning, catalog or sync code | Relevant `RippleCoreTests` and `make test-core`. Test the real app path if the change crosses composition, caching or persistence |
| App state, SwiftData, sync import or StoreKit | `Tests/AppTests/AppTests.swift` and the relevant native suite. Cover an older store, interrupted save or replay when the change affects compatibility |
| Layout, onboarding or interaction | `Tests/UITests/RippleUITests.swift`, the relevant iPhone or iPad size and appropriate text and appearance settings. Test the tap-only route when gestures change |
| Firestore rules, schema or rule allowlist | `make test-rules` and the corresponding SyncKit tests. Test accepted and rejected cases using the emulator |
| Speech assets or audio tooling | Verify the language's plan, local/staged hashes and full decode. Run authoring tests and check the app's cache and fallback for playback changes |
| Project configuration or release | Regenerate if needed, build the affected configuration, and verify bundle contents and size. Use the signed archive and release checks for distribution work |
| Documentation only | Verify local links, command names and descriptions against the files and tooling they reference |

Report the resulting behavior, exact checks and any material pending gate. Keep automated decoding separate from human listening approval, simulator evidence separate from real-device results, and a local draft or build separate from a published release. Cite the relevant artifact or source file so the next agent can resume from evidence.
