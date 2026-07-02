# Bitrig Build Prompt

ParcelOps is a native SwiftUI local-first operations app for tracking company orders, mailbox intake, review work, dispatch handoff, tasks, and audit history.

## Current MVP Shape

The everyday operator workflow is intentionally narrow:

1. Dashboard
2. Inbox
3. Orders
4. Operations Workbench
5. Dispatch
6. Tasks
7. Audit
8. Settings

Detailed review, supporting records, and admin/reference screens remain available as secondary routes. Do not expose every internal record type as a primary daily screen.

## Live Provider Boundary

SpaceMail IMAP is the current live mailbox intake path.

- Refresh is explicit, manual, and read-only.
- Credentials are stored through Keychain-backed SpaceMail credential actions.
- Passwords, app passwords, auth strings, access tokens, refresh tokens, client secrets, and raw callback URLs must not be stored in JSON or Audit.
- IMAP refresh must use read-only behavior and must not delete, move, mark read, flag, send, or modify mailbox messages.
- Mixed-mailbox filtering is required because the mailbox may contain mostly non-order email.
- Likely order/order-update messages enter Inbox triage.
- Uncertain messages stay out of Inbox and are reviewed from Mailbox Monitor.
- Clearly non-order messages are counted and surfaced as safe previews/reason labels only.

## Local Data

ParcelOps persists operational state as local JSON under the app support ParcelOps folder. Local JSON stores records, setup status, review state, audit events, and non-secret metadata only.

The app should keep showing:

- Local JSON storage path and record counts.
- Manual backup boundaries.
- That JSON backup does not include Keychain secrets.
- Corrupt JSON handling behavior.

## Microsoft 365

Microsoft 365 remains an advanced/testing surface.

- MSAL sign-in and manual Graph read diagnostics exist.
- Real Graph refresh is manual/read-only and separate from mock Graph refresh.
- Microsoft 365 must not become the default daily provider unless explicitly requested.
- Do not store Microsoft tokens or callback URLs in JSON or Audit.

## Not Active In The MVP

Do not add or imply live behavior for:

- Shopify OAuth/API calls.
- Carrier APIs or carrier booking.
- Store login automation.
- Background sync.
- Notifications.
- Calendars/reminders.
- OCR.
- Scanner/camera workflows.
- File pickers.
- Outbound email sending.
- Mailbox mutation.

These may exist only as local planning placeholders unless explicitly implemented in a later approved slice.

## Product Direction

Prioritize pragmatic operator usability over exposing data-model breadth. Keep screens compact, readable, and task-focused. Use SF Symbols for actions and statuses. Risky or uncertain matches should require review instead of silently changing order data.
