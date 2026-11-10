# Connected services and distribution

## This workspace's configured resources

| Resource | Value / state |
|---|---|
| Firebase project | `ripple-grammar-2026` (`812375227752`), display name Ripple Grammar |
| Billing / Auth | Spark; `billingEnabled: false`; legacy `FIREBASE_AUTH`; anonymous provider enabled |
| iOS registration | `1:812375227752:ios:265d39233db41ba12aaadd`, bundle `app.ripple.grammar` |
| Firestore | `(default)`, `eur3`, Standard Native, `freeTier: true` |
| Hosting | `https://ripple-grammar-2026.web.app` |
| App Check | App Attest registered with a one-hour token TTL; Firestore enforcement `ENFORCED`; no simulator debug token registered |
| Apple team / App ID | `WH9D3XTKPT` / `YV7X6UAPQ5`; Sign in with Apple and App Attest enabled |
| Apple OAuth Service ID | `app.ripple.grammar.auth` (`HVPGQT94GY`); primary App ID Ripple Grammar; domain `ripple-grammar-2026.firebaseapp.com`; return URL `https://ripple-grammar-2026.firebaseapp.com/__/auth/handler` |
| App Store Connect | Ripple: German Grammar, Apple ID `6831985594`, manual-release draft |
| Base app price / availability | Free ($0.00 USD base), 175 current storefronts after release; future storefronts disabled; iPhone/iPad distribution, Mac and Vision Pro availability disabled |
| Pro subscription group | Ripple Pro, `22555712` |
| Monthly product draft | `app.ripple.pro.monthly`, Apple ID `6831987981`, one month; English metadata; $5.99 USD base with Apple's regional conversions; 175 selected storefronts |
| Yearly product draft | `app.ripple.pro.yearly`, Apple ID `6831991511`, one year; $39.99 USD base with Apple's regional conversions; seven-day free trial; 175 selected storefronts |
| Lifetime product draft | `app.ripple.pro.lifetime`, Apple ID `6832005185`, non-consumable; $79.99 USD base with Apple's regional conversions; 175 selected storefronts |
| Support / policy | Existing shared site, `/ripple/support/` and `/ripple/privacy/`; English and Russian |

The dedicated Apple sign-in key `8VMPSRRB8H` is registered for Ripple only, stored in the ignored `.secrets/` directory with mode 0600, and configured in Firebase Authentication. The provider read-back confirms the Service ID, native bundle and Apple code flow. Never bundle this key or commit it. Real-device sign-in, reauthentication, revocation and deletion remain acceptance gates. This Mac currently reports zero valid code-signing identities. Install the correct team certificate/private key through the normal Apple development workflow before making a signed archive.

The user approved monthly $5.99, yearly $39.99 with a seven-day introductory trial, lifetime $79.99, and Apple's conversions for the 175 current storefronts. All three product drafts have English display metadata, the implemented paywall screenshot and review notes. Monthly and yearly share service level 1 and the English Ripple Pro group localization. The yearly trial starts 7 November 2026 with no end date. Future storefronts are not enabled automatically. No app or product has been submitted for App Review or released. English listing copy from `docs/app-store-metadata.json` is saved, together with the user-approved reuse of an existing App Review contact. The private contact is held only in App Store Connect. Five native screenshots are saved for each required iPhone and iPad size, with a separate large iPhone set; original PNGs and test provenance are retained in `docs/app-store-screenshots/`.

`tools/firebase_setup.mjs` uses the existing Firebase CLI login for narrowly scoped setup and state checks on this exact project; it never prints tokens. `firebase/tests/live-smoke.mjs` was run before App Check enforcement and cleans up only its generated QA accounts/documents. It deliberately refuses to run against enforced Firestore. Use emulator tests for subsequent automated checks; do not weaken production enforcement for simulator testing.

The tested compact progress schema (version 2) is deployed. Version 1 documents remain readable for migration; old clients cannot overwrite compact state with unbounded event arrays. App Check remains enforced. Crashlytics and Firebase Installations APIs are enabled. A Google Analytics property has not been linked, and real-device telemetry delivery has not been certified.

The shared support Site is `appgprj_6adb646a51b88191ba130a159bdda2d4`, published version 10, source commit `6d60c775a5daa17953b6585a56d69a0149b599d1`. The local source checkout under `site-support/.sites-checkout` is ignored by the app repository. Ripple's page copy and preparation script are retained separately in `site-support/`.

## Firebase Spark

1. Use the existing project above for Ripple; do not create another by default. For a deliberately separate development environment, create a Spark project and add its distinct iOS bundle ID. Choose an EU Firestore location before creating the database.
2. Download the project's genuine `GoogleService-Info.plist` into `App/Resources/`. It is ignored by git. Regenerate the project with `xcodegen generate`. The app checks that its bundle ID matches the configuration.
3. Enable Apple sign-in and anonymous authentication. Configure the Apple Team ID, key and Service ID in the Firebase console as required by [Firebase's Apple authentication guide](https://firebase.google.com/docs/auth/ios/apple). Anonymous authentication is used only when a signed-out user sends a content report.
4. Register App Attest (DeviceCheck fallback) with App Check. Register a simulator debug token only in a development project. Enforce App Check for Firestore after testing physical devices. Never register debug tokens in a production release.
5. In `firebase/`, explicitly select your real project when deploying. No `.firebaserc` points at a production account. Run emulator tests before deployment:

   ```sh
   npm ci --ignore-scripts
   npm run test:rules
   firebase deploy --project YOUR_PROJECT_ID --only firestore:rules,firestore:indexes,hosting,remoteconfig
   ```

6. Set `RippleContentBaseURL` in the generated Info.plist configuration (`project.yml`) to the project's HTTPS Hosting origin. Set real `RipplePrivacyURL` and `RippleSupportURL` values. Re-run XcodeGen after editing. Do not use example domains in a release.
7. Confirm owner-only reads/writes with two real Apple accounts, sign-out during sync, offline sign-in errors, anonymous reports, Apple reauthentication, token revocation and complete account deletion.
8. After creating the real signed archive, run `sh tools/upload_symbols.sh /absolute/path/Ripple.xcarchive` in release CI. Set `RIPPLE_FIREBASE_SDK_PATH` if the SDK checkout is elsewhere, and `RIPPLE_FIREBASE_CONFIG_PATH` for a CI-injected plist. The helper validates the matching bundle without printing configuration secrets. Collection remains opt-in in the app. Symbolicated crash delivery requires a real project and device test.

Firebase 13.1.1 is pinned in `project.yml`; the included SwiftPM lockfile pins transitive dependencies. This release includes the October 2026 Firestore certificate-trust correction described in the [official SDK release notes](https://firebase.google.com/support/release-notes/ios).

Only Hosting, Remote Config, Auth, Firestore, Analytics, Crashlytics and App Check are used. No Cloud Functions, Cloud Storage or receipt server is required. Verify current [Firebase quotas and pricing](https://firebase.google.com/pricing) in the real project before launch. Do not enable a billing plan or deploy resources implicitly.

## Apple and StoreKit

1. Select a real development team in Xcode, and register the bundle ID with Sign in with Apple and App Attest capabilities. Use a production App Attest entitlement in the distribution configuration.
2. Create the subscription group and these product IDs in App Store Connect:

   - `app.ripple.pro.monthly` — auto-renewing monthly.
   - `app.ripple.pro.yearly` — auto-renewing yearly; configure an eligible seven-day free trial if desired.
   - `app.ripple.pro.lifetime` — non-consumable.

3. Prices displayed by the app come exclusively from StoreKit's localized product metadata. The `.storekit` file is a local test catalog matching the approved USD draft values; it does not establish App Store approval or live sandbox availability. Trial copy requires an actual free-trial offer on the selected product and StoreKit eligibility.
4. Use the included StoreKit configuration in Debug for purchases, refunds and failures. Disable the local configuration for sandbox/TestFlight validation. Test trial eligibility, renewal, expiration, billing retry, family sharing policy, pending approval, cancellation, restore and revoked transactions on real sandbox accounts.
5. Publish the complete privacy policy on the developer's actual website, with the data-controller identity, contact details, retention, Google processing terms and deletion rights. The local in-app privacy explanation is not a substitute for this legal document.
6. Fill App Store privacy disclosures for optional linked progress/account data, reports, product analytics and diagnostics. No microphone, location, photos, contacts, IDFA or cross-app tracking is requested. Include optional collection in the label even though it defaults to off.
7. Complete native content and audio sign-off, physical-device accessibility and performance checks, TestFlight beta and the release checklist before archiving for submission.

## Content publishing

Version 2 is bundled and staged locally with 927 used lemmas, 240 chains and 1,690 steps. Published version 1 assets and the live Remote Config version remain unchanged. Run `python3 tools/author_scenarios.py`, `python3 tools/author_content.py` and `python3 tools/ripplec.py` after changing authored scenarios or paradigms; `make content` checks reproducibility. The inputs and measurements are documented in [CONTENT_V2.md](CONTENT_V2.md).

`python3 tools/export_review.py` writes base-sentence, step and vocabulary TSVs plus unit-hash worksheets. Review every sentence, translation, teaching band, distractor and accepted order; listen to final sentences on the default German voice. Fill `content/review/signoffs.json` using actual reviewer names and ISO timestamps under the exact immutable unit SHA-256. Any content edit changes the hash and requires a new sign-off. A nonempty recording catalog also requires `audioCatalogSHA256` matching the reviewed catalog. Do not fabricate reviewer approval.

The ElevenLabs pipeline staged 240 MP3s under `firebase/public/content/de-en/v2/audio/` for native listening review. The application reads the static recording catalog, and the CLI keeps the provider key in its ignored private file. [Audio authoring](AUDIO_AUTHORING.md).

Run `python3 tools/ripplec.py --check --release`, upload the new versioned Hosting directory, verify its manifest, then update the Remote Config content version. Never overwrite a published version. The client spreads updates across seven days, uses immutable cached units and retains its installed pack on any failure.
