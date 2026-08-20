# Auth And Home Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Chaona use real Supabase email authentication with confirmation messaging, remove Demo from the normal product flow, and give signed-in farmers a polished real-data empty Home screen.

**Architecture:** Keep Supabase as the authentication provider. Keep demo fixtures in the repository only for existing development tests, but remove their routes, buttons, banner, and dashboard data path from the app. Replace the dashboard's simulated state with a farmer-first empty state that leads to farm setup and soil measurement.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase Flutter, Flutter widget tests.

## Global Constraints

- Email confirmation remains enabled in Supabase; signup must explain that the user must verify email before login.
- No simulated readings appear in the signed-in Home screen.
- Sensor integration is out of scope for this change.
- Keep existing app navigation and Supabase project unless a code error requires a focused change.

### Task 1: Authentication behavior

**Files:**
- Modify: `lib/features/auth/presentation/screens/register_screen.dart`
- Modify: `lib/features/auth/presentation/screens/login_screen.dart`
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart`
- Test: `test/features/auth/presentation/register_screen_test.dart`

- [ ] Write failing widget tests for signup calling the real flow and showing email-confirmation guidance.
- [ ] Run the focused tests and confirm they fail because registration is still a TODO.
- [ ] Implement signup through `authProvider`, keep the user on an explicit verification state, and map common Supabase auth errors to readable messages.
- [ ] Run focused auth tests and confirm they pass.

### Task 2: Remove Demo from normal navigation

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/shared/widgets/main_scaffold.dart`
- Modify: `lib/features/auth/presentation/screens/login_screen.dart`
- Modify: `lib/features/auth/presentation/screens/register_screen.dart`
- Test: `test/features/auth/presentation/demo_removed_test.dart`

- [ ] Write failing tests asserting login and main navigation contain no Demo entry or simulated-data banner.
- [ ] Run focused tests and confirm they fail against current Demo controls.
- [ ] Remove Demo route guards and visible Demo controls while leaving fixture code available only for legacy tests.
- [ ] Run focused tests and confirm they pass.

### Task 3: Farmer-first Home screen

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Modify: `lib/app/theme.dart` only if existing tokens cannot support the new visual hierarchy.
- Test: `test/features/dashboard/presentation/dashboard_screen_test.dart`

- [ ] Write failing widget tests for the real-data empty Home: greeting, primary setup actions, and no simulated values.
- [ ] Run focused tests and confirm they fail against the current generic empty state.
- [ ] Implement a visually distinct Home with a compact seasonal header, large setup action, clear feature actions, and calm empty state.
- [ ] Run focused tests and confirm they pass.

### Task 4: Full verification

- [ ] Run `flutter test`.
- [ ] Run `flutter analyze` and verify no new errors.
- [ ] Run `flutter build apk --debug`.
- [ ] Inspect the final diff and confirm sensor files are untouched.

