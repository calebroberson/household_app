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

## Supabase
- URL: (add your Supabase project URL here)
- Tables: users, chores, households, household_members
- Auth: Apple Sign In via Supabase Auth
- Realtime: subscribe to chores table filtered by household_id

## iOS testing workflow
- Write code on Windows → test on Android emulator (hot reload)
- Push to GitHub → Codemagic builds .ipa → install via TestFlight on iPhone
- APNs push notifications require a real signed iPhone build (not emulator)

## Do not suggest
- macOS terminal commands or Xcode steps
- SwiftUI or UIKit code
- Material Design widgets
- Windows-only workarounds when a cross-platform solution exists
