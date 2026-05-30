# ParcelOps

ParcelOps is a SwiftUI product skeleton for tracking company orders, mail intake, supplier connections, wishlist items, and delivery handoff workflows.

## Current Scope

- Dashboard, Orders, Mailbox Monitor, Needs Review, Wishlist, Integrations, Automation Flow, and Settings.
- Mock orders created from forwarded mailboxes, Shopify syncs, store logins, watched folders, manual entry, and wishlist conversion.
- Review-safe matching: risky email/order matches go to Needs Review and keep contact history/evidence instead of silently overwriting order data.
- Multiple tracked mailboxes, Shopify accounts, watched folders, and wishlist sources.
- Service protocols and in-memory repository protocols are defined for Xcode implementation work.

## Architecture

The app is split by responsibility under `Sources/`:

- `ParcelOpsApp.swift` - app entry and root navigation.
- `Models.swift` - product models and enums.
- `ParcelOpsStore.swift` - observable state and UI actions.
- `Services.swift` - service protocols with mock implementations.
- `Repositories.swift` - persistence protocols with in-memory implementation.
- `SampleData.swift` - isolated mock data.
- `DashboardViews.swift`, `OrderViews.swift`, `MailboxReviewViews.swift`, `WishlistViews.swift`, `IntegrationsSettingsViews.swift`, `AutomationViews.swift`, `SharedViews.swift` - UI surfaces.

## Run Locally

```bash
swift run ParcelOps
```

Real email login, Shopify OAuth, password-vault access, carrier API credentials, browser extensions, and durable persistence are intentionally not implemented yet.
