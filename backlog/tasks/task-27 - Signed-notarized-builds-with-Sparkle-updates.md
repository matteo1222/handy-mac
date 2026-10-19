---
id: TASK-27
title: 'Signed, notarized builds with Sparkle updates'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 18:23'
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
- [ ] #1 GitHub Actions on macOS runners builds, signs with Developer ID, notarizes and staples
- [ ] #2 Sparkle appcast publishes updates; the update check is the only network call in the default build
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
<!-- SECTION:NOTES:END -->
