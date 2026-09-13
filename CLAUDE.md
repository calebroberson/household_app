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
- Tables: profiles, households, household_members, household_invites, chores, chore_occurrences, lists, list_items
- `chores` = recurring templates (recurrence_rule, assignment_strategy); `chore_occurrences` = individual due instances — never store due dates directly on `chores`
- Household create/join go through RPCs (`create_household`, `redeem_invite`), not direct table inserts — households/household_members have no client-side INSERT policy by design
- RLS: all household-scoped tables use the `is_household_member(household_id)` security-definer function, not inline subqueries (avoids recursive RLS bug on household_members)
- Auth: Apple Sign In via Supabase Auth (P0). Email magic link deferred.
- Realtime: subscribe to list_items and chore_occurrences filtered by household_id
- Push notifications (APNs) and Sentry crash reporting deferred until core chores/lists loop works end-to-end

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
