# Bitrig Build Prompt

Create a native SwiftUI app called ParcelOps for a company that tracks mail, orders, and parcels across many suppliers.

The app should support:

- Multiple active orders at once.
- Orders created mostly from emails forwarded into a dedicated tracking mailbox.
- Matching every tracked order to the user or team email address used for that purchase.
- Monitoring future emails about the order so issues such as address problems, failed delivery attempts, refunds, backorders, or support requests are surfaced.
- Store account connections for suppliers where the company has separate logins.
- Shopify OAuth connections for Shopify-based suppliers.
- Carrier tracking once an order ships, including carrier name, tracking number, destination address, delivery ETA, and exception states.
- Manual order creation for orders that cannot be discovered automatically.

Main screens:

1. Dashboard with counts for active orders, exceptions, mailbox events, and connected sources.
2. Searchable order list with filters for intake, ordered, shipped, in transit, exception, and delivered.
3. Order detail page showing order number, store, tracked email, customer/team, carrier, tracking number, destination, source, latest status, and timeline.
4. Mailbox monitor page showing forwarded emails, their matched order, severity, summary, sender, and received time.
5. Integrations page for forwarded mailbox, Shopify connections, and password-vault-backed store logins.
6. Automation flow page showing mailbox parsing, account sync, order matching, and carrier tracking.

Use a professional operations-tool design: compact, clear, and fast to scan. Use SF Symbols for actions and statuses. Use review states for risky email/order matches instead of silently changing order data.
