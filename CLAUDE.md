# Household Chore App — Claude Code Context

## Stack
- **Frontend:** Flutter (Dart) + Cupertino widgets
- **Backend:** Supabase (Postgres + Auth + Realtime + Edge Functions)
- **CI/CD:** Codemagic (cloud Mac builds for iOS)
- **Push notifications:** APNs via Supabase Edge Function

## Platform targets
- iOS primary (iPhone) — distributed via TestFlight + App Store
- Android secondary
- Dev environment: Windows PC

## UI rules
- Always use Cupertino widgets (CupertinoApp, CupertinoNavigationBar, CupertinoTabScaffold, etc.)
- Never use Material Design widgets
- iOS-first layout and interaction patterns

## Dart rules
- Always null-safe Dart
- Use async/await (not raw Futures)
- Follow effective Dart naming conventions

## Product scope
- Shared household responsibility tracker: recurring chores + shared lists (e.g. groceries)
- NOT a personal to-do app — no one-off personal reminders, no points/streaks/leaderboards, no per-task nag notifications
- Test for whether something belongs: does more than one household member care about its state?
- Building for scenario "share with friends & family" (real invite flow, tested multi-tenancy) even though only 2 users today — do not hardcode a single household

## Supabase
- URL: https://bgwzxmgrjzisyifnspyl.supabase.co
- Tables: profiles, households, household_members, household_invites, chores, chore_occurrences, lists, list_items, areas
- `chores` = recurring templates (recurrence_rule, assignment_strategy); `chore_occurrences` = individual due instances — never store due dates directly on `chores`
- `recurrence_rule` JSON shapes: `{"type":"daily"}`, `{"type":"weekly","days":[1..7]}` (ISO weekday, 1=Monday), `{"type":"every_n_weeks","n":2,"weekday":3,"anchor":"YYYY-MM-DD"}` (anchor set once at creation and preserved on edit — it's the cadence's stable reference point, never regenerate it for an existing chore), `{"type":"monthly","day_of_month":1}` (clamped to the last day of shorter months).
- Household create/join go through RPCs (`create_household`, `redeem_invite`), not direct table inserts — households/household_members have no client-side INSERT policy by design. Leaving a household is also an RPC (`leave_household()`) for the same reason — it's a multi-step conditional (delete membership, maybe auto-promote the next-longest-tenured member to owner, maybe delete the whole household if no one's left) that's much safer as one atomic security-definer function than as several new granular RLS policies.
- Chore management: chores aren't just visible via Today's occurrences — `chore_list_screen.dart` browses all active chores, `chore_detail_screen.dart` shows history ("last done by X on date", from the most recent occurrence with `completed_at` set) plus Edit/Archive. Archiving sets `active = false` (already excluded from occurrence generation) rather than deleting, to preserve history. `chore_form_screen.dart` handles both create and edit — on edit it always explicitly writes `fixed_assignee`/`assignee_order` (nulling whichever doesn't apply to the selected strategy) rather than conditionally omitting them, so switching assignment strategy on an existing chore doesn't leave stale values behind.
- Household member "fairness" data (30-day completion counts) is neutral and always-visible-on-demand, never pushed or gamified — no streaks, no comparisons, no badges. This is a deliberate product stance from the Fable design review, not just a v1 simplification — don't add gamification later without revisiting that decision explicitly.
- RLS: all household-scoped tables use the `is_household_member(household_id)` security-definer function, not inline subqueries (avoids recursive RLS bug on household_members). Cross-user profile visibility uses the same pattern via `shares_household_with(target_user_id)` — `profiles` SELECT is otherwise self-only, so any feature needing another member's display name (assignee pickers, "assigned to" labels) needs this policy, already added.
- `household_members` and `profiles` have **no direct foreign key to each other** (both separately reference `auth.users`) — PostgREST embedded selects like `household_members.select('user_id, profiles(display_name))')` will NOT resolve. Always do two plain queries (member user_ids, then `profiles.select(...).inFilter('id', userIds)`) and join manually in Dart. Hit this in the chores work; cost real review time to catch since it's a runtime failure `flutter analyze` can't see.
- Auth: Apple Sign In via Supabase Auth (P0). Email magic link deferred.
- Realtime: subscribe to list_items, lists, and chore_occurrences filtered by household_id
- Any `timestamptz` value built client-side must be `DateTime.now().toUtc().toIso8601String()`, never without `.toUtc()` — a bare local-time ISO string gets interpreted by Postgres as UTC, silently skewing the stored value by the device's UTC offset.
- Occurrence generation (creating the next `chore_occurrences` row, collapsing overdue ones) lives client-side in `lib/services/occurrence_generator.dart`, not a Postgres RPC — deliberate choice for easier iteration/debugging over eliminating a rare, harmless race condition. Revisit only if a server-side scheduled job (e.g. the deferred push digest) needs the same logic. Algorithm: at most one open (not completed, not skipped) occurrence per chore ever; a resolved occurrence's replacement is due on the next qualifying date *after today* (not after the old due date), so late completions never create a catch-up backlog.
- Push notifications (APNs) still deferred — needs its own Apple Developer/APNs setup session, plus a Supabase Edge Function for full in-app account deletion (also deferred, same infra dependency). Sentry crash reporting is live (`SentryFlutter.init` in `main.dart`); the DSN is not secret (same category as the Supabase URL/anon key) and is safe to have in the client.
- **Areas** (rooms/zones, e.g. Kitchen, Caleb's Room): `areas` table, `visibility` is `'shared'` (any household member) or `'private'` (exactly one `owner_id`, invisible to everyone else — no rows, no counts, no realtime events for non-owners). `chores.area_id` and `chore_occurrences.area_id` both nullable (`null` = "General", visible to all members, unaffected by any of this). `chore_occurrences.area_id` is populated by `occurrence_generator.dart` at insert time from the parent chore — **do not let this drift**: if it's ever null while the chore's own `area_id` isn't, that occurrence silently becomes visible to the whole household regardless of the area's privacy, since `can_view_area(null)` is defined as visible-to-all.
  - `can_view_area(target_area_id)` is the reusable security-definer helper (same pattern as `is_household_member`/`shares_household_with`) — used in RLS on `areas` itself and, ANDed with `is_household_member(household_id)`, on `chores`/`chore_occurrences` SELECT/INSERT/UPDATE.
  - A chore in a private area MUST be `assignment_strategy = 'fixed'` with `fixed_assignee = area.owner_id` — enforced by a trigger on `chores` (`enforce_chore_private_area_assignment`), not just convention. This is a correctness rule, not an extra security layer: RLS already fully hides private-area rows from non-owners regardless of `assigned_to`, so the trigger exists purely to stop a chore from being created that's structurally impossible for anyone to ever complete.
  - Flipping an area from shared→private **fails loudly** (raises an exception, via `enforce_area_visibility_change`) if it contains any chore not already fixed-assigned to the new owner — no silent auto-reassignment. Caller has to fix those chores first.
  - Creating a private area requires `owner_id = auth.uid()` (you can only make yourself the owner at creation) — enforced in the `areas` INSERT policy.
  - Verified with a real RLS test (two throwaway `auth.users` rows + `set local request.jwt.claims`, wrapped in `begin/rollback`) before any UI was built on top of it — all four assertions (private area hidden, private chore hidden, cross-area insert blocked, cross-owner reassignment blocked) passed.

## iOS testing workflow
- Write code on Windows → test on Android emulator (hot reload)
- Push to GitHub → Codemagic builds .ipa → install via TestFlight on iPhone
- APNs push notifications require a real signed iPhone build (not emulator)

## Codemagic/TestFlight gotchas (hard-won — don't relitigate)
- `xcode: latest`, not a pinned version — App Store Connect rejects uploads built with an SDK older than what Apple currently requires. Only pin a specific version if a genuine incompatibility appears, and revert once fixed.
- `ITSAppUsesNonExemptEncryption = false` must be in `ios/Runner/Info.plist`, or every uploaded build gets stuck "Missing Compliance" in App Store Connect and can't be added to any testing group (internal or external) without manually answering the encryption popup each time.
- Build number must auto-increment every build (Apple rejects re-uploading a used `CFBundleVersion`). The "Set build number" step in `codemagic.yaml` uses `app-store-connect get-latest-testflight-build-number "$APP_APPLE_ID" --platform IOS` — this command needs the **numeric App Store Connect App ID** (`APP_APPLE_ID` var, currently `6811686297`), NOT the bundle ID string. Passing the bundle ID fails silently in ways that are easy to miss.
- Do NOT set `submit_to_testflight: true` or `beta_groups` in the `publishing.app_store_connect` block. The "Internal" TestFlight group uses Automatic distribution, which grants every processed build to internal testers with zero explicit action — Apple's API rejects an explicit assignment attempt on such a group ("Cannot add internal group to a build"). `submit_to_testflight: true` separately triggers external beta review (needs Feedback Email + reviewer contact info we don't want to maintain). Plain `api_key`/`key_id`/`issuer_id` is sufficient — it uploads and waits for processing; Apple handles internal distribution automatically.
- `CM_CERTIFICATE_PRIVATE_KEY` (an RSA key we generated once via OpenSSL, stored in the `ios_credentials` group) is required for `app-store-connect fetch-signing-files --create` to generate a fresh signing certificate. Codemagic build machines are ephemeral and don't persist a certificate's private key across builds, so without this the CLI can fetch an existing cert but can't use it.
- Testers don't get a new email per build — only once, when first added to a group. New builds just appear in the TestFlight app automatically for existing testers.

## Do not suggest
- macOS terminal commands or Xcode steps
- SwiftUI or UIKit code
- Material Design widgets
- Windows-only workarounds when a cross-platform solution exists
