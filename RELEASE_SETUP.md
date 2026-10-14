# Public repository and Android release checklist

## Before making GitHub public

- Review the exact staged files with `git diff --cached --stat` and `git diff --cached`. Include the app source, tests, platform resources, lockfile and documentation; exclude local data, backups, logs and signing material.
- Review Git history as well as the working tree. Commit history contains author identity metadata. Local tool checkpoint refs also retain an older QA document with machine paths; that document was not found in branch/tag/remote history. Review author details before publishing and push only the intended branch and tags, not all refs with a mirror push. Preserve the original private repository before any history changes.
- Confirm that the existing LGPL v2.1 license is the intended project license and that the branding and bundled assets can be distributed. Preserve dependency license notices.
- Desktop scaffolding is retained but unvalidated. Before a desktop release, configure publisher-owned metadata and review the remaining macOS/Linux example identifiers. Android and iOS identifiers have been preserved for compatibility.
- Do not upload the entire workspace as a ZIP. `.gitignore` does not protect files in an arbitrary ZIP or files already tracked by Git. The ignored `.local/` directory contains private review notes and an unrelated document kept out of the public source tree.
- Keep real JSON exports outside the repository (or in ignored `backups/`). A valid JSON file can contain private financial information without matching any secret scanner.

## Configure Android signing

Debug builds remain available for testing. Release builds deliberately fail if private upload signing credentials are absent; they never fall back to a debug key.

Create `android/key.properties` locally with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Use an absolute keystore path; forward slashes avoid Java properties backslash escaping on Windows. Use the existing upload key for an update. Keep this file and the keystore private; both are ignored by Git. Do not put credentials in shell history or screenshots.

Preserve the application ID `mhart.moneyflow` for updates. Check `version` in `pubspec.yaml` and select a build number greater than any previously uploaded version before submission.

With the signing credentials configured:

```sh
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build appbundle --release
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`. Install and test the release through a Play Console testing track before production rollout.

## Device acceptance checks

Use a test installation and synthetic records. Back up an existing installation before an upgrade test.

- Create accounts and a dated goal; record income, an expense and a transfer. Verify both balances, history and goal recommendations, then force-close and reopen.
- Update an existing installation without uninstalling. Confirm financial records, custom categories, photos and preferences survive.
- Test invalid amounts, insufficient funds, repeated taps, canceled dialogs, past goal dates and completed goals.
- Export and restore through Android's native file picker. Test cancellation and invalid backups; confirm existing data is unchanged. Check photo selection and interrupted-picker recovery.
- Review small screens, keyboard-open forms, larger text, TalkBack, and dark/light/system themes.
- Check offline use, cold start, scrolling and long histories in release mode. Verify Android splash appearance and backup/device-transfer exclusions on supported versions.

Android automatic cloud backup/device transfer is excluded by configuration. Users need a portable JSON backup before uninstalling or changing devices. Exports are not encrypted and include notes and goal photos. Clear all data does not remove exported files or retained older internal snapshots. Configuration alone is not proof of device-level backup behavior.

## Store submission

- Provide a publisher-owned support contact and a published privacy policy consistent with the app and its dependencies.
- Complete Play Console declarations from verified behavior, including data handling, permissions, content rating and target audience. Check the Console's current SDK and testing requirements at submission time.
- Use screenshots from the release build with clearly synthetic records. README widget renders are development previews.
- Verify the upload signature, package identity and version in the testing track. A successful debug build is not a signed-release or store-approval check.

No signing credentials are included in this repository. See [development notes](docs/DEVELOPMENT.md) for storage rules and [the dated QA fixes](docs/reviews/QA_FIXES_2026-09-27.md) for regression coverage.


## Repository preparation verification — October 14, 2026

- Flutter 3.35.7 / Dart 3.9.2: analysis passed; all 133 tests passed, including the 100 layout combinations; Android debug APK built successfully.
- Documentation links and Git whitespace checks passed. README screenshots were refreshed from isolated test fixtures.
- Candidate source files and reachable Git objects were checked for common credential/private-key patterns, private data filenames and machine paths. No recognizable credentials were found. Local checkpoint refs retain an old QA document with machine paths; that document was not found in branch/tag/remote history. Commit author metadata remains for publisher review.
- Eleven repetitive progress notes and an unrelated PDF were preserved under ignored `.local/`. The detailed QA review and fixes remain in `docs/reviews/`; current maintenance guidance is in `docs/DEVELOPMENT.md`.
- This was a pattern-based audit, not proof that every possible secret or personal detail is absent. No real app database was opened. No history was rewritten and nothing was committed, pushed or published.
- Release signing, physical-device acceptance and other native platform builds were not verified in this pass. Test logs and APKs remain under ignored `build/`.
