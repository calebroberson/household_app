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

## Do not suggest
- macOS terminal commands or Xcode steps
- SwiftUI or UIKit code
- Material Design widgets
- Windows-only workarounds when a cross-platform solution exists
