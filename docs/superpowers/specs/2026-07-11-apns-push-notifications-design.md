# APNs Push Notifications Design

## Goal

Add end-to-end iOS remote notifications for new expenses, ledger invitations, and expense confirmation or rejection events. Business operations must remain successful when push delivery fails.

## Scope

The first release sends these notifications:

- `expense.created`: notify registered participants who need to confirm, excluding the actor.
- `ledger.invited`: notify the invited registered user, excluding the actor.
- `expense.confirmed`: notify the expense creator when another user confirms.
- `expense.rejected`: notify the expense creator when another user rejects.

Temporary ledger members cannot receive notifications. The actor never receives a notification caused by their own action.

## Architecture

The iOS app registers with APNs after an authenticated user grants notification permission. It sends the APNs device token to the authenticated backend and deletes the registration during logout. The backend stores multiple devices per user.

Business endpoints commit their database changes first. They then schedule best-effort APNs delivery outside the critical response path. Missing devices, APNs errors, and invalid tokens are logged and do not roll back the business operation. A future queue may replace in-process background delivery without changing event or payload contracts.

The backend connects directly to Apple's HTTP/2 provider API with token-based authentication. Firebase and a Redis/Celery queue are intentionally out of scope.

## Backend Data Model

Add `push_devices`:

- `id`: UUID primary key.
- `user_id`: required foreign key to `users.id`, cascade delete.
- `token`: required APNs token string, unique.
- `environment`: `sandbox` or `production`.
- `bundle_id`: required string, currently `com.yhma.Evenly`.
- `is_active`: boolean, default true.
- `created_at`: timestamp.
- `updated_at`: timestamp.
- `last_seen_at`: timestamp.

Registering an existing token transfers it to the current authenticated user and reactivates it. A user may own multiple active tokens.

## Device API

Authenticated endpoints:

- `PUT /api/users/me/push-devices/{token}` with `{ "environment": "sandbox|production", "bundle_id": "com.yhma.Evenly" }` registers or refreshes a device.
- `DELETE /api/users/me/push-devices/{token}` disables the current user's matching device.

Token values are validated as hexadecimal APNs device tokens. The backend never returns stored device tokens in general user responses.

## APNs Provider

Configuration is injected through environment-backed application settings:

- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_PRIVATE_KEY`
- `APNS_BUNDLE_ID`, default `com.yhma.Evenly`

The private key supports a PEM string with escaped newlines. No `.p8` file is committed.

The provider caches its ES256 JWT for at most 50 minutes and sends HTTP/2 requests to the sandbox or production APNs host according to each device registration. Requests use `apns-push-type: alert`, `apns-priority: 10`, and the configured bundle ID as `apns-topic`.

APNs responses marking a token invalid or unregistered disable that token. Other failures are logged with the APNs reason and event identifier, without logging full device tokens.

## Notification Contract

All payloads contain:

```json
{
  "aps": {
    "alert": { "title": "...", "body": "..." },
    "sound": "default"
  },
  "event": "expense.created",
  "ledger_id": "uuid",
  "expense_id": "uuid-or-omitted"
}
```

Invitation payloads use `event: ledger.invited`, include `ledger_id`, and omit `expense_id`. Payloads contain identifiers only, not amounts, participant lists, email addresses, or other sensitive ledger data.

Copy:

- New expense title: `有一笔新账单待确认`
- New expense body: `{actor} 在「{ledger}」添加了“{expense}”`
- Invitation title: `你收到一个账本邀请`
- Invitation body: `{actor} 邀请你加入「{ledger}」`
- Confirmation title: `账单已确认`
- Confirmation body: `{actor} 已确认“{expense}”`
- Rejection title: `账单被否决`
- Rejection body: `{actor} 已否决“{expense}”`

Names are shortened as needed to remain safely within APNs payload limits.

## iOS Integration

Add a notification manager responsible for:

- Requesting alert, badge, and sound authorization after authentication, once the app has an authenticated user.
- Calling `registerForRemoteNotifications()` when authorized.
- Receiving the device token from the app delegate bridge and registering it with the backend.
- Remembering the last registered token so it can be disabled during logout.
- Retrying backend registration on later authenticated launches when registration previously failed.
- Showing banner, sound, and badge while the app is in the foreground.
- Parsing notification response payloads into a pending destination.

Enable the Push Notifications entitlement by adding `aps-environment` through the Xcode capability/signing configuration. Debug builds register as `sandbox`; archived TestFlight and App Store builds register as `production`.

## Navigation

Notification routing produces one of two destinations:

- Expense events: open the ledger identified by `ledger_id`.
- Invitation events: open the existing pending invitations surface.

If the app is logged out, preserve the pending destination in memory, show login, and consume the destination after authentication succeeds. Invalid, missing, or inaccessible identifiers fall back to the ledger list without crashing.

## Permission and Settings Behavior

The app uses the standard iOS permission prompt only after login. A notification row in Settings shows the current authorization state and opens the system app settings when permission is denied. The app does not repeatedly prompt after denial.

## Error Handling and Privacy

- Push delivery never changes the HTTP success status of the underlying business action.
- Registration API failures are non-blocking and retried on a later authenticated launch.
- Logout attempts device deletion before clearing authentication; failure does not block logout.
- Logs redact tokens and do not include private expense amounts or member details.
- Notification bodies avoid financial amounts on the lock screen.

## Testing

Backend tests cover:

- Device registration, transfer, refresh, and disable behavior.
- Authentication and token validation.
- Recipient filtering for every event.
- Actor exclusion and temporary-member exclusion.
- Payload event identifiers and routing IDs.
- Push failure isolation and invalid-token deactivation.

iOS tests cover:

- Device token encoding and API request construction.
- Payload parsing for expense and invitation destinations.
- Invalid payload fallback.
- Login-deferred destination consumption.

Manual verification uses a physical device because the production APNs and TestFlight path cannot be fully verified in unit tests.

## Deployment

Before deployment:

1. Enable Push Notifications for App ID `com.yhma.Evenly` in the Apple Developer portal.
2. Create or reuse an APNs Auth Key and configure its Team ID, Key ID, and private key in the backend secret store.
3. Apply the backend migration before deploying application code.
4. Deploy the backend and verify sandbox delivery on a development-signed physical device.
5. Upload a TestFlight build and verify production APNs delivery.

Rollout is backward compatible: existing app versions do not register devices and simply receive no push notifications.
