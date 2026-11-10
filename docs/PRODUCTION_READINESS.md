# Production readiness — 10 November 2026

Ripple is implemented as a working native application with a verified optimized build and deployed Firebase Spark infrastructure. It is **not yet certified for a public production release**. The remaining editorial, signing, device and distribution gates below are explicit; no reviewer signatures, device results or beta metrics have been fabricated.

## Verified implementation

| Area | Evidence |
|---|---|
| Engine, learning, content and merge | 33 tests in six suites; 87.8% source line coverage (1,508 / 1,717 lines). Every one of 240 chains solves in both directions; every authored dependency is reachable. |
| App persistence and StoreKit | Eight app tests passed: atomic completion/resume, local reset and replica rotation, persisted store migration, sync replay/vocabulary counts, 90-day attempt retention and export of attempts/reports, pending approval, subscription expiration, verified lifetime purchase/refund. |
| Native UI | Seven UI tests passed: tap-only onboarding/demo, complete lesson and main tabs, save/resume/reveal, spawned-word form and placement, largest accessibility text, selected-product paywall terms/dismissal, and two expanded long-sentence scenarios. The latter also checks the summary heading and exit action after a scroll-reset fix. |
| Content version 2 | 927 used canonical lemmas; 240 chains / 1,690 steps / 51 rules; 238 unique bases, 240 unique finals, 1,926 distinct sentences; 12 themes; at least 14 chains per rule; 14.2% no-change; zero automated editorial warnings. Source/generator/compiler checks pass. Bundled and staged locally, not remotely published. |
| Audio authoring and cache | Twelve Python tests cover authoring, language separation, credit safeguards, rate-limited reads and resume. FFmpeg decoded all 240 German finals and their 240 English counterparts. The German set matches the app's rendered sentences, passes cache integrity checks and opens with AVAudioPlayer. The staged English set matches the authored translations and German lesson IDs. Listening and physical iOS playback review remain open. |
| Firestore rules | Seven isolated emulator tests passed, including a full 51-rule payload, compact-state bounds, ownership, server timestamps and bounded report inputs. Version 2 rules are deployed. |
| Optimized device build | Xcode 26.3, Swift 6 strict concurrency; unsigned Release build succeeded; app size 36.9 MiB (37,776 KiB), below 40 MB. The provider key is absent from all bundle files. |
| Layout inspection | The expanded A2 café and B1 initial-subordinate scenarios pass on iPhone 16e and iPad Pro 13-inch, iOS 26.1; unaltered summary screenshots were inspected at both sizes. Prior six-test UI acceptance on iPhone 16 Pro and iPad, accessibility text and semantic dark appearance remains separate evidence. Physical VoiceOver and animation performance remain separate gates. |
| Live services | Legacy Auth anonymous sign-in, full 51-rule write/read, cross-account and unauthenticated access denial, report creation/read denial, and exact bytes of all 41 hosted files verified. Temporary test accounts and documents removed. |
| Firebase configuration | New project `ripple-grammar-2026`; Spark, billing disabled; Firestore `eur3`, free tier; rules/indexes, Hosting and Remote Config deployed. |
| App Check | App Attest registered for the genuine app/team; Firestore enforcement set to `ENFORCED`. No production simulator debug token was registered. Real App Attest token acceptance is not established by simulator tests. |
| Apple registration | Team `WH9D3XTKPT`; explicit bundle `app.ripple.grammar`; Sign in with Apple and App Attest enabled. App Store draft `6831985594`, manual release. |
| Apple provider and catalog | Dedicated Ripple-only key registered and configured in Firebase. Monthly $5.99, yearly $39.99 with seven-day trial, lifetime $79.99, Apple regional conversions and availability for 175 current storefronts, product review screenshots/notes saved. |
| App Store listing | English description, keywords, subtitle, Education category, support/privacy URLs and approved reused App Review contact saved. Five native screenshots uploaded to each 6.3-inch iPhone, 6.9-inch iPhone and 13-inch iPad slot. Free base app; 175 current storefronts, future storefronts disabled; iPhone/iPad only. Manual release; no submission. |
| Support and policy | English/Russian pages published on the existing developer support Site; app URLs point at the real pages. |

Current content/audio evidence is in `.build/content-v2-final-core-tests.log`, `.build/content-v2-coverage.json`, `.build/content-v2-final-regression.log`, `.build/ContentV2FinalRegression.xcresult`, `.build/ContentV2ScrollPhone.xcresult`, `.build/ContentV2ScrollPad.xcresult`, `.build/content-v2-reproducibility.log`, `.build/audio-authoring-2026-11-10-tests.log`, `.build/elevenlabs-finals-validation-2026-11-10.json`, `.build/ripple-audio-validation-2026-11-10.log` and `.build/audio-release-build-2026-11-10.log`. Version 2 summary screenshots and source manifests are retained in `docs/screenshots/content-v2/`. Earlier service/rule, persistence, large-phone/tablet and fresh-checkout evidence remains in `.build/final-firestore-tests.log`, `.build/firestore-v2-deploy.log`, `.build/live-services.json`, `.build/PrivacyAndSyncAcceptance.xcresult`, `.build/StorePhoneMedium.xcresult`, `.build/StorePadFinal.xcresult` and `.build/fresh-checkout-build.log`. `.build` is intentionally ignored. Unaltered store images and provenance are in `docs/app-store-screenshots/`. These are local runs; no remote CI run is claimed.

A follow-up run exposed a quick-tap race after insertion: a moving word button could open its neighbor's picker. The ripple now animates only a decorative overlay, with stable word hit regions. Subsequent complete native runs passed, including three repeated onboarding runs. New-word glosses are included in the card's accessible name, and the largest text size keeps the gloss in the scrollable lesson area. Build-script sandboxing remains enabled; the optional Firebase copy declares its exact input/output and supports an absent environment file.

The StoreKit suite passes on iOS 26.1. This machine's iOS 26.3 simulator fails to initialize StoreKitTest with `SKInternalErrorDomain Code=3` / `notEntitled`; those environmental failures were retained separately, not converted into passing assertions. CI and the documented command use 26.1.

## Required before release

1. **Editorial content and listening.** The pack covers 927 lemmas and 51 rules across 240 chains and 1,690 steps. A German native reviewer needs to approve the sentences, translations, teaching bands, distractors and accepted orders. The default on-device voice and all 240 ElevenLabs final recordings also need a listening review. The current worksheets in `content/review/` bind approvals to twelve content-unit hashes and the recording catalog hash. The version 2 recordings are staged for review and distribution.
2. **Apple authentication and deletion.** The dedicated key and Firebase Apple provider are configured. Verify native sign-in, account switching, reauthentication, token revocation and deletion with real Apple accounts. The ignored private key must never enter app resources or source control.
3. **Signing and distribution.** This Mac has no valid signing identity. Install the team's legitimate signing certificate/private key and provisioning, create a signed archive, and validate it. Finish the App Store age rating, content-rights/export declarations and privacy disclosures against the reviewed final build; recheck the saved listing, screenshots and product drafts, then submit the products with the first app version. An App Store draft is not a published app.
4. **Real-device App Check.** Verify production App Attest on physical devices under the distribution entitlement with Firestore enforcement enabled. The code has a DeviceCheck fallback; its server-side private-key configuration still needs to be supplied and tested for devices without App Attest support. Do not authorize simulator debug tokens in production.
5. **Sandbox billing.** Exercise the live product catalog and seven-day yearly trial eligibility, restore, renewal, expiration, billing retry, cancellation, pending approval and revocation in Apple's sandbox/TestFlight. Local StoreKitTest success does not establish catalog approval or sandbox behavior.
6. **Privacy operations and diagnostics.** Review the published policy and Apple privacy label against the final build. Confirm the developer's applicable Google processing terms and legal disclosures. Link a real Google Analytics property if product analytics will be used, configure its retention, and verify opt-in/withdrawal. Integrate dSYM upload into the signing/release pipeline and confirm a symbolicated opt-in crash from a real device. Define a regular manual report/support deletion process; no paid TTL or Cloud Function was enabled.
7. **Accessibility and performance.** Complete physical VoiceOver reading/focus, Switch Control, Reduce Motion, all text sizes/orientations and iOS 17 compatibility. Measure the PDS's iPhone 12 cold start, local chain load, iPhone 11+ frame rate and player memory budgets. Simulator screenshots cannot establish those measurements.
8. **Beta evidence.** Run TestFlight with real learners and reviewers; measure crash-free sessions, content defects, learning outcomes and the PDS's beta targets before public release. No such cohort or retention data exists yet.

## Compact sync

Version 2 removes the old daily-history ceiling. Per-chain/mode counters merge independently recorded sessions without counting shared history twice. Recent day counts and archived yearly bitmaps retain streak history. Detailed completion events remain local and exportable; cloud restoration supplies totals and the latest result for each chain/mode. Tests cover 20,000 new sessions in under 2 KB, exact migration of 20,000 legacy events, overlapping old-client histories, thirty years of streaks, persisted database migration and repeated cross-device imports without vocabulary inflation. See the architecture document for structural bounds and the version 1 migration policy.

## Release commands

```sh
make verify
python3 tools/ripplec.py --check --release
python3 tools/release_check.py
```

The final two commands are expected to fail while real editorial sign-offs and release evidence are missing. Do not fill evidence fields with assumptions. A passing compiler or simulator suite does not replace the manual gates above.
