# Savings App reliability review — 12 September 2026

## Fixes
- Transactions: writes previously left account balances unchanged and the dashboard queried repositories without watching updates. Inserts, edits and deletes now adjust the matching balance atomically, refresh accounts, and rebuild statistics before notifying screens. Verified by isolated SQLite tests for add, edit, delete, rollback and invalid values.
- Balance input: editing rounded away cents and presented zero as editable content. Zero now starts empty; cents are retained; invalid/non-finite input is rejected.
- Profile: dialog actions used the parent navigator, settings save removed the settings subtree during loading, and startup replaced saved preferences. Dialog-local navigation, stable save state, and insert-if-missing startup prevent these failures. Widget regression verifies saving and blank-name handling; database test verifies repeated initialization preserves preferences and achievements.
- Clear data: closing the shared database and rebuilding its provider exposed loading state to synchronous consumers. Reset now keeps the handle and router alive, refreshes data providers, creates defaults in the wipe transaction, and reports failures.
- Demo reset: deletion omitted budgets and recurring rules and source replacement was not atomic. All demo source rows now replace in a single transaction, followed by statistics rebuilding. Repeated-reset tests verify stable record counts and valid defaults after clear.
- Statistics: deleting the final transaction of a day left stale cache rows. Recalculation now rebuilds the affected cache and includes older transaction history rather than a 365-day cap. Regression verifies an empty cache after deletion.
- Other fixes: preserve account links on rename; reject deleting accounts with linked activity; refresh after recurring run-now; preserve earned achievements on initialization; correct dashboard financial-month boundaries; load all transactions rather than silently truncating at 500.

## Verification and limits
44 automated tests passed in the full regression run, including six new database/widget tests. Static analysis passed. Tests use an isolated database, not personal app data.
No Android device was connected. Physical-device restart, reset-dialog interaction, every major screen, and release-build testing have not been completed. This review does not certify the app as production-ready.
Existing manually stored balances are preserved as the starting point. Historical discrepancies cannot be reconstructed reliably without an opening balance or reconciliation history. Adjust current account balances to a known correct value if necessary; subsequent transaction changes apply deltas consistently.
Remaining review areas include recurring-rule crash recovery and missed-occurrence catch-up, concurrent writes during resets, backup validation, and complete preference/currency propagation.