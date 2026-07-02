# ParcelOps

ParcelOps is a SwiftUI local-first operations app for tracking company orders, mailbox intake, supplier references, wishlist items, review tasks, dispatch handoff, and audit history.

## Current Scope

- Simplified primary workflow: Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, and Settings.
- SpaceMail IMAP supports explicit manual read-only refresh with Keychain-backed password/app-password storage.
- Mixed-mailbox filtering keeps likely non-order mail out of Inbox, while uncertain messages can be reviewed locally.
- Inbox triage can create or link local orders, then show the handoff through Orders, Workbench, Tasks, Dispatch, Dashboard, and Audit.
- Microsoft 365 setup, MSAL sign-in, and Graph read diagnostics remain available as advanced/testing surfaces.
- Shopify, carrier, scanner, OCR, notification, calendar, background sync, and outbound email workflows remain placeholders only.
- JSON persistence preserves local operational records, setup records, audit history, and review state.

## Architecture

The app is split by responsibility under `Sources/`:

- `ParcelOpsApp.swift` - app entry and root navigation.
- `Models.swift` - product models and enums.
- `ParcelOpsStore.swift` - observable state and UI actions.
- `Services.swift` - service protocols plus mock, SpaceMail IMAP, Keychain credential, Microsoft auth, and Graph client boundaries.
- `Repositories.swift` - JSON persistence protocols and repository implementation.
- `SampleData.swift` - isolated mock data.
- `DashboardViews.swift`, `OrderViews.swift`, `MailboxReviewViews.swift`, `WishlistViews.swift`, `IntegrationsSettingsViews.swift`, `AutomationViews.swift`, `SharedViews.swift` - UI surfaces.

## Run Locally

```bash
swift run ParcelOps
```

SpaceMail IMAP is the current live mailbox path and remains manual/read-only. Passwords and app passwords are stored in Keychain, not JSON. Microsoft 365 Graph, Shopify OAuth, carrier APIs, browser extensions, background sync, notifications, OCR, scanners, calendars, file pickers, outbound email, and mailbox mutation are not part of the daily MVP workflow.
