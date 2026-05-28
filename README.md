# CompanyParcelTracker

A SwiftUI prototype for a company mail and parcel tracking app designed for Bitrig-style native app generation.

## What It Covers

- Forwarded mailbox intake for order confirmations, shipping notices, and issue emails.
- Multiple supplier accounts and Shopify connections.
- Tracking by order number, store, tracked user email, carrier, tracking number, and destination address.
- Exception highlighting when a carrier or supplier email needs attention.
- A searchable operations dashboard for many active orders at once.

## Run Locally

```bash
swift run CompanyParcelTracker
```

The local project targets macOS so it can be built and previewed on this machine. The UI and data model are SwiftUI-first and can be adapted directly into Bitrig for iPhone.

## Bitrig

Use `BITRIG_PROMPT.md` as the prompt/brief inside Bitrig. The app structure in `Sources/main.swift` can also be used as implementation reference for the SwiftUI screens, models, and sample data.
