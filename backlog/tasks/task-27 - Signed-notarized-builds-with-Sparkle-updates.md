---
id: TASK-27
title: 'Signed, notarized builds with Sparkle updates'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-23 11:15'
labels:
  - ready-for-human
milestone: m-2
dependencies:
  - TASK-1
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: chore
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
External beta testers need a trusted build. Synthesising input rules out the App Store, so Developer ID, notarization and Sparkle it is. Needs a human with the Developer ID account.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GitHub Actions on macOS runners builds, signs with Developer ID, notarizes and staples
- [x] #2 Sparkle appcast publishes updates; the update check is the only network call in the default build
- [x] #3 Launch at login available and off by default
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Sparkle 2 via SwiftPM; package-app.sh embeds and signs Sparkle.framework inside-out (XPC services, helper app, binaries, framework, app), adds the rpath, and writes SUFeedURL/SUPublicEDKey only for release builds.
2. Updates: the updater starts only when the bundle has a feed and key; menu 'Check for Updates…' appears only then.
3. No-network lint rule (URLSession, NWConnection, …) so the Sparkle check stays the only network code.
4. scripts/sign-and-notarize.sh (Developer ID, hardened runtime, notarytool, staple, Gatekeeper assess), scripts/make-appcast.sh (generate_appcast), .github/workflows/release.yml on v* tags with documented secrets.
5. Launch at login via SMAppService.mainApp, a Settings toggle, off by default.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From TASK-21: run appintentsmetadataprocessor during packaging (needs -emit-const-values from the Swift compiler for HandyApp) so Shortcuts discovers PerformHandyActionIntent.

Done and verified: Sparkle 2.10.0 embedded (otool shows @rpath/Sparkle.framework), codesign --verify --deep --strict passes on the ad-hoc bundle, the dev build has no feed keys so the updater never starts, and the running app holds 0 internet sockets (lsof). Launch at login is a Settings toggle backed by SMAppService, unregistered by default. Needs a human with the Apple Developer account: create the Developer ID certificate and a notarytool profile, generate Sparkle EdDSA keys (generate_keys), set the release workflow secrets, then tag v0.1.0 to prove AC1 and AC2 end to end. Still open from TASK-21: App Intents metadata extraction for Shortcuts discovery. Note: SwiftPM can hang on a keychain prompt when resolving the Sparkle binary; --disable-keychain avoids it (documented in AGENTS.md).

App Intents metadata extraction is now part of package-app.sh (resolves the TASK-21 note).

Local Developer ID signing attempted (OUT_DIR=.build/release-app APP_IDENTITY='Developer ID Application: <name> (<team id>)' scripts/package-app.sh release): macOS asks keychain permission once per codesign call (one per nested Sparkle helper), so it was stopped. To run locally, grant codesign access to the Developer ID key once (Keychain Access › key › Access Control) or sign in CI with an imported keychain. Notarization still needs a notarytool profile (none in the keychain).

2026-10-23: local release proven. Notary profile 'handy' stored, Developer ID key usable by codesign, Sparkle EdDSA keys generated (private key in the login keychain; public key 1YMFy6B96W1xKk80RUCHrAZiLlx+CIHVm3lBEEnFrFo=). scripts/sign-and-notarize.sh built, signed, notarized (submission accepted), stapled; spctl: accepted, source=Notarized Developer ID. Fixed on the way: Sparkle's Autoupdate went unsigned (find -H) and notarytool rejections now fail the script with Apple's log. Remaining for AC1/AC2: the release environment's GitHub secrets (DEVELOPER_ID_P12 + password, NOTARY_*, SPARKLE_PRIVATE_KEY/PUBLIC_KEY), then a v0.1.0 tag to prove the workflow and appcast end to end.

2026-10-23: v0.1.0 released by the GitHub Actions release workflow (run 39944165859, macos-26): make verify, Developer ID import, notarize, staple, appcast, publish all green. https://github.com/matteo1222/handy-mac/releases/tag/v0.1.0. A fresh download marked quarantined passes spctl (accepted, source=Notarized Developer ID), stapler validate passes, and appcast.xml carries the zip URL with its EdDSA signature; the app's feed URL (releases/latest/download/appcast.xml) resolves (HTTP 200).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Signed, notarized releases with Sparkle updates: scripts/sign-and-notarize.sh and the tag-triggered release workflow build, sign with Developer ID (hardened runtime, every nested Sparkle binary), notarize (failing loudly with Apple's log on rejection), staple and publish a zip plus an EdDSA-signed appcast. Secrets live in the release environment. Launch at login is off by default. v0.1.0 is live and passes Gatekeeper as Notarized Developer ID.
<!-- SECTION:FINAL_SUMMARY:END -->
