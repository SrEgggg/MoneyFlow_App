# Maintaining MoneyFlow

The app uses Riverpod for state, GoRouter for navigation and handwritten SQLite queries through sqflite. Keep UI changes separate from financial mutations: repositories own validation and atomic balance updates; shared utilities own money formatting and goal recommendations.

## Financial and storage rules

- Transfers subtract from one account and add to another atomically. They are excluded from income and expense totals.
- Goal contributions track allocations of existing money. They do not change account balances.
- Amount validation rejects non-finite, negative or unsupported precision values as appropriate. Money operations use integer centavos while retaining compatible SQLite REAL columns.
- Schema version 7 preserves existing records, adds duplicate account-name guards and corrects small rounding residues in goal amounts. Do not reset databases to apply future migrations.
- Legacy duplicate account names are not merged automatically. References use account names, so ambiguous historical ownership requires reconciliation. Account deletion is blocked when history depends on it.
- Calendar and Overview use calendar dates. Budgets, reviews and advanced analytics use the configured financial-day cutoff. Preserve that distinction when adding summaries.
- Transaction storage success is separate from analytics refresh success. A failed refresh must not prompt the user to insert an already-saved transaction again.
- Recurring rules catch up missed postings at startup or through Run Due, with a bounded batch. They are actual recorded transactions, not payment instructions or background notifications.

## Backups

Format 7 includes transaction revisions and goal photos. Validate the complete envelope, tables, values and references before replacing any data. Restore is atomic; cancellation must leave data unchanged. Older supported formats have version-specific missing-table rules. Export reads a consistent database snapshot.

Backups are plain JSON. Never add a real export to the repository as a fixture. Use synthetic data in isolated test databases. Settings reset does not remove user-managed exports or older internal snapshots.

## Verification

Run `flutter pub get`, `flutter analyze`, `flutter test --reporter expanded` and `flutter build apk --debug` after relevant changes. Database tests use SQLite FFI; widget tests supply controlled clocks and fixtures. The layout tests cover ten screens across five size/text-scale configurations in both themes.

Layout tests also write previews under ignored `build/qa/`. They resolve fonts from the installed Flutter SDK. The README uses selected synthetic-data renders copied into `docs/screenshots/`; refresh those files after a visible UI change.

Keep all platform source folders and `pubspec.lock`. Generated caches, build products, IDE state, local SDK paths and signing credentials belong outside version control. Do not remove native launcher assets just because multiple sizes look similar: each platform references its own resources.

The optional `tool/export-brand-icons.ps1` script uses Windows System.Drawing to export launcher sizes from `assets/brand/moneyflow-master.png`. Other platforms require their own build validation.

## Review records

The [September QA review](reviews/QA_REVIEW_2026-09-27.md) and [corresponding fixes](reviews/QA_FIXES_2026-09-27.md) preserve reproduction steps and migration decisions. Findings and test counts in those reports describe that date. Use [the release checklist](../RELEASE_SETUP.md) for outstanding publication work.

Physical-device upgrade, restart, picker recovery, TalkBack and release-performance checks remain necessary. Automated layout renders do not prove those interactions work on every device.
