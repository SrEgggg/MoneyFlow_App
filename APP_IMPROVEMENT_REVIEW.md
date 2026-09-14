# MoneyFlow improvement review — 14 September 2026

## Scope of this iteration

This is the first incremental implementation of the two supplied requests. The existing Flutter/Riverpod/SQLite project and account balances are retained. No schema migration, personal-data reset, demo loading, signing change, or publishing was performed. The calendar foundation and critical reliability fixes are implemented; the complete payday and scheduled savings system is not yet implemented.

## 1. Bugs found

- Streaks counted successive stored rows even when calendar dates were missing. An empty cache returned without clearing old streak values. Goal-only activity was overlooked, and goal streak iteration was reversed.
- The Performance destination and day-detail destination displayed placeholders, making existing calendar code inaccessible through normal navigation.
- Goal contributions inserted a log record and then updated progress separately using the screen's potentially stale goal value. Concurrent contributions could lose progress; a failed second write could leave inconsistent data.
- Goals had no edit/delete controls. Remaining amounts could become negative and progress was rounded to whole percentages.
- Backup restore attempted contribution inserts before parent goals. An incomplete backup envelope could trigger replacement and remove existing data without meaningful restored rows.
- The financial-day helper ignored a caller-supplied cutoff in today().
- Goal inputs did not consistently reject non-finite or oversized amounts. Monthly dashboard savings treated unspent income as goal contributions and supplied an unconfigured target.

## 2. Bugs fixed

- Tracking and goal/savings streaks now derive from source records, count distinct consecutive local dates, exclude future instants, preserve yesterday's run while today is open, and return zero for empty history. Displays refresh with activity changes, startup and a minute clock. Cached streaks use the same calculator.
- Performance now opens the financial calendar. Day details display real records instead of a placeholder.
- Contribution insertion and goal progress/status updates use one database transaction and load the current goal before updating it. Invalid and over-target contributions roll back.
- Goal edit and confirmed delete are available. Delete intentionally removes the goal contribution log too; the dialog explains this. It preserves income/expense transactions and account balances. Related reactive activity and streak displays refresh.
- Backup restores now insert goals before contributions and delete children before parents. Required core tables and one settings row are checked before replacement. Round-trip and incomplete-envelope regression checks pass.
- today() honors its cutoff. Contribution and goal forms reject non-finite values. Quick Add guards repeated saves and caps amounts. Async form errors check widget lifetime.

## 3. UI/UX improvements

- Monthly calendar with previous/next month, Today, Monday-first weekday labels, selected day, income/expense/goal indicators, screen-reader day descriptions, and a wrapping legend.
- Day and month summaries, no-activity guidance, retry states, links to transaction editing and goal details, and Add Transaction prefilled for the selected day. Empty accounts lead to account creation with an explanation.
- Dashboard Financial Activity card with monthly income, expenses, goal savings, net cash flow, tracking streak, active days and View Calendar.
- Goal edit/delete actions, explicit destructive confirmation, contribution error feedback, progress to one decimal place, nonnegative remaining amount and wrapping goal statistics.
- Added Business and Bonus income sources and Personal expense category while retaining existing categories and record identifiers.
- Calendar widget checked at 320 logical pixels wide. Physical-device and large-font visual testing remain outstanding.

## 4. Code improvements and calculation rules

The shared ActivitySummary reads existing transactions and goal_contributions. It does not persist duplicate calendar events or streak counters as an authority. The same calculator powers the calendar, dashboard activity and visible streaks.

Calendar activity follows the local date displayed in the transaction form. Legacy performance analytics still have a configurable financial-day cutoff; align or explicitly label those older analytics in a subsequent pass before release.

A goal contribution currently earmarks existing money, without an account transfer. Accordingly, goal savings is the sum of contribution records, income and expenses come only from transactions, and net cash flow = income - expenses. Subtracting contributions from cash balances would change the existing accounting behavior and requires a funded-transfer model. Deleting a goal removes its earmarking history and recalculates activity; it does not change cash.

Dashboard Goal Savings now uses actual contributions and configured monthly targets on active goals. Account balances retain their existing transaction-delta model and any historical opening values; this iteration does not reconstruct past balances.

## 5. Features improved and verification

Implemented: calendar/day details, dashboard activity, daily tracking and goal-saving streak correctness, goal create/edit/delete/progress, contribution validation and atomic writes, income sources, backup ordering and envelope safeguards.

Validation: Flutter analyzer reports no issues; all 52 automated tests pass. Tests include gaps, duplicate dates, future activity, date changes/deletion, contribution-only days, month/year/leap-day boundaries, concurrent contribution progress, over-target rollback, goal deletion preserving cash/transactions, backup round-trip with foreign keys, incomplete backup rejection, narrow calendar navigation, existing reset/profile/navigation and transaction-balance regressions. git diff --check passes.

Not verified: an Android release build, physical-device restart/resume, every screen at large text scales, actual Play Console upload, or end-to-end goal edit/delete interaction on a device. No claim of production readiness is made.

## 6. Recommended new features / deferred requested features

| Priority | Improvement | Why | Needed before release? |
| --- | --- | --- | --- |
| 🟡 Recommended | Explicit no-activity check-in | Users can acknowledge a quiet day without inventing a transaction. Current daily streaks restart after an empty completed day. | Before marketing habit streaks as accommodating quiet days |
| 🟡 Recommended | Daily/weekly/payday/custom savings periods | Savings consistency should follow when users can save. Current saving streak is daily goal contributions only. | Before releasing the scheduled-streak promise |
| 🟡 Recommended | Separate expected-income schedule with Mark as Received and Skip | Expected income must not change balances; posting needs an atomic occurrence identifier to prevent duplicates. Support daily, weekly, fortnightly, twice-monthly, monthly and custom schedules. | Before releasing payday calendar features |
| 🟡 Recommended | Explicit source/destination savings transfers | Enables funded contributions and standalone savings without double-counting cash. | Before claiming goal savings reconcile to available cash |
| 🟢 Optional | Gentle reminders and subtle celebration | Useful encouragement once schedule rules are dependable. | No |
| 🟢 Optional | Light theme | Current app is deliberately dark-only; implement centrally rather than screen by screen. | No |

## 7. Things required before Play Store release

| Priority | Finding / action | Why and release importance |
| --- | --- | --- |
| 🔴 Must Fix | Release configuration uses debug signing | Configure a protected upload key and Play App Signing before distributing the release bundle. Do not commit keys. |
| Fixed in iteration 2 | Recurring posting and advancing the rule were separate writes | Posting, balance changes and schedule advancement now commit together. Concurrent runs and stale edits cannot rewind the saved posting position. The existing auto-posting rules are still not expected-income reminders. |
| 🔴 Must Fix | Backup validation remains incomplete | Envelope checks are improved; validate dates, values, row relationships, malformed optional tables and restore/merge semantics before trusting arbitrary backups. |
| 🔴 Must Fix | Demo records share the live data store | Existing demo reset replaces real records after confirmation; it is not an isolated preview. Separate demo storage before claiming demo activity cannot affect real streaks. |
| 🔴 Must Fix | Financial totals and date semantics need a final cross-screen audit | Account balances, contributions and legacy net-income caches have different meanings. Align labels and month cutoffs; avoid presenting proxy cash-flow changes as actual net-worth changes. |
| 🔴 Must Fix | Release/device validation | Test cold start, upgrade, offline use, keyboard/back navigation, dialogs, reset/restore, corrupt storage, time-zone change, large fonts and small screens on Android. Produce and test a signed AAB. |
| 🟡 Recommended | Paginate history and aggregate activity by date | Current full-history loading can become expensive as records grow. Measure with representative large datasets before changing architecture. |
| 🟡 Recommended | Consistent currency and amount validation | Several older screens still hardcode peso and differ in amount limits. Required if advertising other currencies. |
| 🟡 Recommended | Audit icon, splash, version, permissions and Android backup behavior | App ID is mhart.moneyflow; verify ownership and final identity, inspect the merged release manifest, and document user data handling. |
| 🟡 Recommended | Privacy policy and store declarations | Prepare an accurate policy, Data Safety form, content rating, screenshots, feature graphic and descriptions matching actual behavior and dependencies before submitting. |

Google's current phone-app target requirement is Android 16 / API 36 for new submissions and updates from 31 August 2026; this project inherits its target from Flutter, so verify the resolved release target rather than assuming compliance. [Official target API requirements](https://developer.android.com/google/play/requirements/target-sdk?hl=en).

For personal developer accounts created after 13 November 2023, plan the applicable closed test with at least 12 testers continuously opted in for 14 days, followed by the production-access application. [Official testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en). Verify account-specific requirements in Play Console at release time.

## 8. Suggested next development priority and roadmap

1. **Phase 1 — Stability:** resolve idempotent recurring posting, strict backup validation and demo separation; complete physical-device checks and the balance/date-label audit.
2. **Phase 2 — Core features:** introduce expected-income occurrences with Mark as Received/Skip, then schedule-aware savings streaks and quiet-day check-ins. Preserve every existing record during migrations. Add funded savings transfers only after defining how balances should move.
3. **Phase 3 — UI/UX:** standardize remaining forms, retry states, large-font layouts, currency display and back navigation. Measure long-history performance.
4. **Phase 4 — Production readiness:** finalize identity, API target, signing, privacy/data handling, backup behavior and a tested release bundle.
5. **Phase 5 — Play Store release:** prepare store assets and declarations, run internal and required closed testing, fix feedback, apply for production access where applicable, then stage production rollout.

Next concrete engineering priority: build the requested confirmed payday calendar on the tested atomic posting primitive. Keep expected dates separate from actual transactions and add explicit occurrence identifiers for received/skipped dates. Strict backup validation and demo separation remain release blockers.


## Iteration 2 — recurring-payment reliability

Completed after the request to continue:

- Transactions, balance adjustments and all schedule advancement in a due batch now share one SQLite transaction. A failure rolls back the whole batch, including previously processed rules. Concurrent runners read progress inside the transaction; retries do not repost successful occurrences.
- Reuses the ordinary transaction balance logic through insertInTransaction. No schema migration, duplicated calendar data or inferred changes to historical records.
- Catches up missed occurrences in date order within each rule, including eligible dates before an expired rule's end. End dates include the whole selected calendar day. Batches stop at 1,000 postings; remaining dates stay pending for a subsequent run. Startup and Run Due feedback indicate when to check for remaining dates.
- Monthly schedules retain the original start-date day: January 31 → February 28/29 → March 31. Daily and weekly schedules retain clock time; new occurrences retain timestamp precision and UTC/local representation.
- Rule edits preserve the latest saved posting position rather than accepting a stale form's next/last-run values. Changing the cadence computes its next date strictly after the latest successful occurrence. Deleting an automatically posted transaction does not cause the runner to recreate it.
- Recurring forms preserve cents, validate amounts and intervals, support clearing optional end dates/notes, guard repeated actions and handle failures. Interval limits are 1–120 units and amount limits are 0.01–999,999,999.99.
- Failed automatic posting leaves the app available and shows a dashboard recovery notice. Users can review/repair or delete the offending rule and retry. Fixed recurring and budget navigation constants to match their actual Settings routes.

Tests added cover duplicate retries, recreated runners, concurrent calls, simulated schedule-write failure, a bad second rule rolling back an entire batch, repair and retry, overdue/end-date behavior, month-end and leap-year dates, fortnightly expenses, paused/future rules, stale edits, cadence changes, deleting generated transactions, bounded catch-up, invalid input, nullable fields, backup restoration and startup recovery.

Limitations: this does not identify or automatically delete duplicate records potentially created by an older version. Historical transactions have no reliable occurrence identifier for that reconstruction. Posting progress is currently the saved rule position; confirmed payday/Skip behavior should use explicit occurrence identifiers when introduced. Existing recurring rules remain automatic actual transactions, and should only be used where that behavior is intended. Physical-device restart/process-kill testing remains outstanding.

Iteration 2 verification: Flutter analyzer reports no issues; all 65 tests pass (13 new recurring reliability tests plus the existing 52). No Android release build or physical-device validation was performed in this iteration.
