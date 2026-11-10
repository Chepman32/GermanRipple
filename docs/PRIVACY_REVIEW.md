# Privacy and store-disclosure review

Prepared 8 November 2026. Owner review is pending; this worksheet is not a completed legal sign-off or a published App Store privacy label.

Apple asks for app-level answers covering the developer and integrated SDKs. Firebase's SDK manifests and disclosure guide must be checked against the features actually used. The candidate categories below are inferences from Ripple's implemented flows, for review against [Apple's current definitions](https://developer.apple.com/app-store/app-privacy-details/) and [Firebase's Apple-platform disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection).

| Implemented flow | Off-device data and trigger | Candidate label categories / purpose |
|---|---|---|
| Optional Apple authentication | Apple provider identifier and Firebase account identifier when the user signs in; anonymous identifier when a signed-out report is sent. The app requests no name or email scopes. | User ID; app functionality. Verify the actual federated Auth record on a real account before ruling out an email claim returned by Apple. |
| Optional progress sync | Rule strengths, dates and counters; latest per-chain/mode result; per-store random replica identifiers and completion counters; recent practice-day counts and older practiced-day bitmaps. Migration can retain packed timestamps from the old format. | User ID, device/installation-level identifier where applicable, product interaction or other usage data; app functionality; linked to the sync account. |
| Content reports | Authenticated identifier, chain, step, pack version, reason and optional note, submitted deliberately by the user. | Customer support / other user content, user ID; app functionality. Do not omit the report flow merely because sending it is optional. |
| Opt-in analytics | App-instance and app/device metadata, lesson/rule events, durations, hint/error counts, paywall events, purchase product IDs and outcomes. | Product interaction, identifiers, purchase history where applicable; analytics. Determine linkage from the real SDK output, rather than assuming anonymous collection. |
| Opt-in crash reporting | Crash traces, associated app/device state and SDK diagnostics. | Crash data and other diagnostics; app functionality / analytics as actually used. Verify the final linked SDKs and a symbolicated device report. |
| Content delivery, Remote Config and App Check | Connection/app metadata, installation-related metadata and device attestation needed to deliver and protect services. Remote Config also uses platform/locale targeting metadata. | Review diagnostic, identifier and other applicable categories against the final SDK behavior and retention. |
| Optional static recorded speech | The staged version 2 catalog maps 240 final sentences to MP3 assets at the same Firebase Hosting origin. With Automatic voice selected, a cache miss can request an asset. | Include Hosting connection metadata in the final delivery review. The authoring CLI sends authored lesson text to ElevenLabs. |

The app has no advertising, IDFA request, cross-app tracking integration, microphone recording, contacts access, photo-library access or location permission. On-device StoreKit verification does not send receipts to a developer receipt server. Opted-in purchase analytics must still be considered separately from Apple's payment processing.

Firebase documents authentication identifiers, provider-dependent contact fields, App Attest/DeviceCheck objects, crash diagnostics, Remote Config targeting metadata and transitive SDK behavior. Review the installed targets, including Firebase Sessions and Google Data Transport, before finalizing the answers. [Firebase disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection)

## Verify against the release build

1. Sign in with a real Apple test account and inspect which Auth fields exist. Verify sync, account switching, reauthentication, revocation and deletion with App Check enforced.
2. Observe a clean launch with analytics/diagnostics off, opt in, then withdraw consent. Confirm the actual SDK requests and retained data. A Google Analytics property is not yet linked.
3. Check the generated privacy report/manifests from the signed archive, including transitive SDKs and required-reason APIs. Match the questionnaire to the final binary and actual service settings.
4. Review the published English/Russian policy, controller identity, applicable processing terms, retention and support/report deletion process. App Store disclosures have not been published.

## Local controls and retention

Detailed step attempts are removed after 90 days on opening/resuming the app, when completing a chain, and before exporting. The export includes current learning progress, compact sync state, recent attempts, vocabulary counts and local content reports. The Settings screen explains that reports are included. A persisted-store test verifies that expired attempts are deleted on launch and that recent attempts/report notes appear in the export.

Local learning reset signs out and rotates the local replica identity. It preserves purchases and does not claim to delete submitted editorial reports. Cloud account deletion requires Apple reauthentication and revocation. Submitted reports can require a separate support deletion request, as explained in the published policy.

## Other store declarations

Complete age-rating and content-rights answers against the final reviewed content. Version 2 replaces the earlier vocabulary and requires a fresh content audit; no alcohol-specific lemma was found in its automated vocabulary check. This does not establish the final age-rating answers. Confirm the selected generated voice's permitted use before distributing recordings. Do not assert physical VoiceOver, Switch Control or performance support as verified until the device checks in the readiness report are complete. No new legal agreement has been accepted as part of this setup.
