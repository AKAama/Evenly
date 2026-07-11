# APNs Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver APNs notifications for new expenses, ledger invitations, and expense confirmation/rejection, with notification taps routed into the iOS app.

**Architecture:** The backend owns device registrations and sends best-effort APNs alerts after business commits. The iOS app requests permission after login, registers its device token, displays foreground alerts, and converts notification payloads into deferred navigation destinations.

**Tech Stack:** SwiftUI, UIKit application delegate bridge, UserNotifications, FastAPI, SQLAlchemy, Alembic, HTTPX, python-jose, pytest, XCTest

## Global Constraints

- Bundle ID is `com.yhma.Evenly`.
- Events are `expense.created`, `ledger.invited`, `expense.confirmed`, and `expense.rejected`.
- Never notify the actor or temporary members.
- Push failure must not fail the underlying business operation.
- Payloads contain routing identifiers but no amounts, emails, or participant lists.
- APNs secrets are environment configuration and are never committed.

---

### Task 1: Persist and manage push devices

**Files:**
- Create: `evenly-backend-service/alembic/versions/20260711_0012_add_push_devices.py`
- Modify: `evenly-backend-service/app/models/user.py`
- Modify: `evenly-backend-service/app/models/__init__.py`
- Modify: `evenly-backend-service/app/schemas/user.py`
- Modify: `evenly-backend-service/app/routers/users.py`
- Test: `evenly-backend-service/tests/test_push_notifications.py`

**Interfaces:**
- Produces: `PushDevice`, `PushDeviceRegistration`, `register_push_device()`, `delete_push_device()`.

- [ ] Add failing tests proving an authenticated user can register, refresh, transfer, and disable a valid 64-character hexadecimal token, while invalid tokens return HTTP 422.
- [ ] Run `uv run pytest tests/test_push_notifications.py -q` and confirm imports or assertions fail because push-device support is absent.
- [ ] Add the migration/model with UUID id, user foreign key, unique token, environment, bundle ID, active flag, and timestamps; add authenticated PUT/DELETE routes under `/users/me/push-devices/{token}`.
- [ ] Run `uv run pytest tests/test_push_notifications.py -q` and confirm the device tests pass.

### Task 2: Build the APNs provider and notification payloads

**Files:**
- Modify: `evenly-backend-service/app/config.py`
- Modify: `evenly-backend-service/config/config.defaults.yaml`
- Modify: `evenly-backend-service/pyproject.toml`
- Create: `evenly-backend-service/app/services/push.py`
- Test: `evenly-backend-service/tests/test_push_notifications.py`

**Interfaces:**
- Consumes: `PushDevice` records and APNs environment settings.
- Produces: `PushEvent`, `build_payload(event, ...)`, `send_push_to_users(db, user_ids, payload)`.

- [ ] Add failing tests for the four exact event payloads, actor-safe recipient selection, missing-configuration no-op behavior, and invalid-token deactivation.
- [ ] Run the focused test file and confirm failures identify the missing push service.
- [ ] Add optional APNs settings, HTTP/2 client dependency, cached ES256 provider JWT, payload builders, redacted logging, sandbox/production host selection, and invalid-token disabling.
- [ ] Run the focused tests and the complete backend suite.

### Task 3: Emit notifications from business events

**Files:**
- Modify: `evenly-backend-service/app/routers/expenses.py`
- Modify: `evenly-backend-service/app/routers/ledgers.py`
- Test: `evenly-backend-service/tests/test_push_notifications.py`

**Interfaces:**
- Consumes: `send_push_to_users` and committed expense/invitation state.
- Produces: event dispatch after create expense, create/add invitation, confirm, and reject operations.

- [ ] Add failing tests asserting new expenses notify pending registered participants, invitations notify invitees, and confirm/reject notify the expense creator; assert actor and temporary members are excluded.
- [ ] Run focused tests and confirm each event assertion fails before integration.
- [ ] Schedule best-effort notification dispatch only after each database commit and isolate all provider failures from API responses.
- [ ] Run focused and complete backend tests.

### Task 4: Register the iOS app with APNs

**Files:**
- Create: `Evenly/Evenly/NotificationManager.swift`
- Modify: `Evenly/Evenly/EvenlyApp.swift`
- Modify: `Evenly/Evenly/AuthManager.swift`
- Modify: `Evenly/Evenly/API/APIEndpoints.swift`
- Modify: `Evenly/Evenly/API/APIClient.swift`
- Modify: `Evenly/Evenly/Evenly.entitlements`
- Modify: `Evenly/Evenly.xcodeproj/project.pbxproj`
- Test: `Evenly/EvenlyTests/EvenlyTests.swift`

**Interfaces:**
- Consumes: authenticated API client and APNs device token callbacks.
- Produces: `NotificationManager`, `NotificationDestination`, device register/delete requests, foreground presentation.

- [ ] Add failing XCTest cases for device-token hexadecimal encoding, registration request construction, and payload parsing into ledger or invitation destinations.
- [ ] Run `xcodebuild test -project Evenly.xcodeproj -scheme Evenly -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` and confirm the new tests fail for missing notification types.
- [ ] Add the notification-center delegate and application-delegate bridge, request authorization after authentication, register/delete tokens through the API, add `aps-environment`, and preserve failed registrations for later retry.
- [ ] Run the iOS tests and confirm they pass.

### Task 5: Route notification taps and expose settings state

**Files:**
- Modify: `Evenly/Evenly/ContentView.swift`
- Modify: `Evenly/Evenly/SettingsView.swift`
- Modify: `Evenly/Evenly/NotificationManager.swift`
- Test: `Evenly/EvenlyTests/EvenlyTests.swift`

**Interfaces:**
- Consumes: `NotificationManager.pendingDestination`.
- Produces: ledger selection, pending-invitations presentation, login-deferred routing, and a system-settings link when permission is denied.

- [ ] Add failing tests for invalid-payload fallback and destination retention until authentication.
- [ ] Run focused iOS tests and confirm failures.
- [ ] Observe pending destinations in the root view, open the target ledger or invitations surface, consume only after successful routing, and add notification authorization status to Settings.
- [ ] Run the complete iOS test suite and a Debug simulator build.

### Task 6: Verify deployment readiness

**Files:**
- Modify: `evenly-backend-service/README.md`
- Modify: `Evenly/DEVELOPMENT.md`

**Interfaces:**
- Consumes: final backend settings and iOS entitlement behavior.
- Produces: exact Apple Developer, backend secret, migration, physical-device, and TestFlight verification steps.

- [ ] Document `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID`, App ID capability setup, migration ordering, sandbox verification, and TestFlight production verification.
- [ ] Run backend tests, iOS tests/build, migration syntax checks, and `git diff --check` in both repositories.
