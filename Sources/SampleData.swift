import Foundation

enum SampleData {
  static var orders: [TrackedOrder] = [
    TrackedOrder(
      orderNumber: "SP-10492",
      store: "SafetyPro Supplies",
      recipientEmail: "ops-orders@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Melbourne Operations",
      fulfillment: .delivery,
      carrier: "Australia Post",
      trackingNumber: "33AUL8841295",
      destination: "18 Collins Street, Melbourne VIC",
      eta: "Tomorrow",
      source: .forwardedMailbox,
      status: .inTransit,
      reviewState: .accepted,
      latestStatus: "Arrived at Melbourne sorting facility",
      timeline: [
        TimelineEvent(title: "Arrived at facility", detail: "Carrier scan received from Melbourne VIC.", time: "Today 9:12 AM", symbol: "shippingbox.fill"),
        TimelineEvent(title: "Shipment email parsed", detail: "Order SP-10492 was found in tracking-intake@parcelops.example and logged against recipient ops-orders@parcelops.example.", time: "Yesterday 6:10 PM", symbol: "envelope.fill"),
        TimelineEvent(title: "Order created", detail: "Supplier order number opened a new tracked order.", time: "Tue 2:18 PM", symbol: "tray.and.arrow.down.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 9:12 AM", source: .carrier, contactPoint: "Australia Post 33AUL8841295", summary: "Carrier scan placed shipment at Melbourne sorting facility.", evidence: "Carrier tracking update linked to supplier order SP-10492.", reviewState: .accepted),
        ContactHistoryEvent(time: "Yesterday 6:10 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Shipping email forwarded into checked mailbox.", evidence: "Recipient email ops-orders@parcelops.example matched the purchase identity.", reviewState: .accepted),
        ContactHistoryEvent(time: "Tue 2:18 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Order confirmation created the order record.", evidence: "Supplier order number SP-10492 extracted from forwarded message.", reviewState: .accepted)
      ]
    ),
    TrackedOrder(
      orderNumber: "SHP-8831",
      store: "Acme Parts Shopify",
      recipientEmail: "field-orders@parcelops.example",
      checkedMailbox: "field-purchasing@parcelops.example",
      customer: "Brisbane Field Team",
      fulfillment: .delivery,
      carrier: "DHL",
      trackingNumber: "JD0146000098312",
      destination: "77 Eagle Street, Brisbane QLD",
      eta: "Pending",
      source: .shopify,
      status: .exception,
      reviewState: .needsReview,
      latestStatus: "Address confirmation requested",
      timeline: [
        TimelineEvent(title: "Review required", detail: "Support email may belong to this order, but suite details differ.", time: "Today 8:05 AM", symbol: "checkmark.shield.fill"),
        TimelineEvent(title: "Fulfillment synced", detail: "Shopify OAuth connection added the shipment record.", time: "Yesterday 11:34 AM", symbol: "cart.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 8:05 AM", source: .mailbox, contactPoint: "field-purchasing@parcelops.example", summary: "DHL support email requested destination confirmation.", evidence: "Matched by tracking number, but address details differ and need user review.", reviewState: .needsReview),
        ContactHistoryEvent(time: "Yesterday 11:34 AM", source: .shopify, contactPoint: "acme-parts.myshopify.com", summary: "Shopify fulfillment added DHL shipment.", evidence: "OAuth sync mapped store order SHP-8831 to Brisbane Field Team.", reviewState: .accepted),
        ContactHistoryEvent(time: "Mon 4:22 PM", source: .shopify, contactPoint: "acme-parts.myshopify.com", summary: "Original Shopify order imported.", evidence: "Recipient email field-orders@parcelops.example linked to checked mailbox field-purchasing@parcelops.example.", reviewState: .accepted)
      ]
    ),
    TrackedOrder(
      orderNumber: "NWS-7720",
      store: "Northwind Wholesale",
      recipientEmail: "office-orders@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Perth Office",
      fulfillment: .clickAndCollect,
      carrier: "Northwind Perth counter",
      trackingNumber: "Pickup code NW7720",
      destination: "Northwind Trade Desk, Perth WA",
      eta: "Ready tomorrow",
      source: .storeLogin,
      status: .ordered,
      reviewState: .monitor,
      latestStatus: "Portal order found with no dispatch notice",
      timeline: [
        TimelineEvent(title: "Portal sync", detail: "Password-vault login found order status inside supplier account.", time: "Today 7:30 AM", symbol: "lock.shield.fill"),
        TimelineEvent(title: "Invoice matched", detail: "Forwarded invoice matched the Perth Office recipient email.", time: "Yesterday 5:01 PM", symbol: "doc.text.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 7:30 AM", source: .supplierPortal, contactPoint: "Northwind Wholesale login", summary: "Portal sync confirmed click-and-collect order status.", evidence: "Pickup code NW7720 found in supplier account.", reviewState: .monitor),
        ContactHistoryEvent(time: "Yesterday 5:01 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Invoice email matched the order.", evidence: "Recipient office-orders@parcelops.example and supplier order NWS-7720 matched.", reviewState: .accepted),
        ContactHistoryEvent(time: "Yesterday 4:54 PM", source: .watchedFolder, contactPoint: "~/Downloads", summary: "PDF invoice saved from browser was scanned.", evidence: "PDF text extraction found NWS-7720 and Northwind Wholesale.", reviewState: .monitor)
      ]
    ),
    TrackedOrder(
      orderNumber: "MAN-2194",
      store: "Regional Courier Desk",
      recipientEmail: "facilities@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Facilities",
      fulfillment: .delivery,
      carrier: "TNT",
      trackingNumber: "TNT55928103",
      destination: "Dock 4, 9 Harbour Road, Sydney NSW",
      eta: "Friday",
      source: .manual,
      status: .shipped,
      reviewState: .accepted,
      latestStatus: "Shipment created manually from supplier call",
      timeline: [
        TimelineEvent(title: "Manual order created", detail: "Operator entered supplier, carrier, destination, and tracking number.", time: "Today 10:20 AM", symbol: "square.and.pencil")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 10:20 AM", source: .manual, contactPoint: "Facilities user entry", summary: "Manual order was created from supplier phone call.", evidence: "Operator entered TNT55928103, Dock 4 destination, and supplier details.", reviewState: .accepted),
        ContactHistoryEvent(time: "Today 10:22 AM", source: .watchedFolder, contactPoint: "iCloud Drive/ParcelOps Orders", summary: "Supporting PDF was uploaded to the order folder.", evidence: "Filename Regional-Courier-MAN-2194.pdf matched the manual order number.", reviewState: .accepted)
      ]
    )
  ]

  static var mailEvents: [MailEvent] = [
    MailEvent(sender: "DHL Support", summary: "Carrier needs destination suite confirmation before delivery continues.", receivedTime: "Today 8:05 AM", matchedOrder: "SHP-8831", severity: .critical, reviewState: .needsReview),
    MailEvent(sender: "SafetyPro Supplies", summary: "Shipping confirmation parsed and tracking number attached.", receivedTime: "Yesterday 6:10 PM", matchedOrder: "SP-10492", severity: .info, reviewState: .accepted),
    MailEvent(sender: "Northwind Wholesale", summary: "Invoice matched, but no dispatch or carrier information yet.", receivedTime: "Yesterday 5:01 PM", matchedOrder: "NWS-7720", severity: .watch, reviewState: .monitor)
  ]

  static var intakeEmails: [ForwardedEmailIntake] = [
    ForwardedEmailIntake(
      sender: "shipping@safetypro.example",
      subject: "Your SafetyPro Supplies order SP-10492 has shipped",
      receivedDate: "Yesterday 6:10 PM",
      rawBodyPreview: "Thanks for your order. Your order SP-10492 has shipped with Australia Post. Tracking number 33AUL8841295. Delivery address: 18 Collins Street, Melbourne VIC.",
      detectedMerchant: "SafetyPro Supplies",
      detectedOrderNumber: "SP-10492",
      detectedTrackingNumber: "33AUL8841295",
      detectedDestinationAddress: "18 Collins Street, Melbourne VIC",
      linkedOrderID: orders[0].id,
      reviewState: .reviewed
    ),
    ForwardedEmailIntake(
      sender: "orders@officekit.example",
      subject: "Office Kit order OK-58214 confirmation",
      receivedDate: "Today 11:42 AM",
      rawBodyPreview: "Order OK-58214 is confirmed. We will ship thermal label rolls to Dock 4, 9 Harbour Road, Sydney NSW. Tracking will follow shortly.",
      detectedMerchant: "Office Kit Store",
      detectedOrderNumber: "OK-58214",
      detectedTrackingNumber: "Pending",
      detectedDestinationAddress: "Dock 4, 9 Harbour Road, Sydney NSW",
      linkedOrderID: nil,
      reviewState: .needsReview
    ),
    ForwardedEmailIntake(
      sender: "newsletter@supplier.example",
      subject: "June supplier specials",
      receivedDate: "Today 9:18 AM",
      rawBodyPreview: "Monthly promotion with no order number, tracking number, or delivery address detected.",
      detectedMerchant: "Unknown supplier",
      detectedOrderNumber: "Not detected",
      detectedTrackingNumber: "Not detected",
      detectedDestinationAddress: "Not detected",
      linkedOrderID: nil,
      reviewState: .ignored
    )
  ]

  static var mailboxes: [TrackedMailbox] = [
    TrackedMailbox(address: "tracking-intake@parcelops.example", provider: .microsoft365, monitoredFolders: "Inbox, Forwarded Orders", status: "Watching", lastChecked: "2 min ago", routingRule: "Default order intake and carrier alerts"),
    TrackedMailbox(address: "field-purchasing@parcelops.example", provider: .gmail, monitoredFolders: "Purchases, Shipping", status: "Watching", lastChecked: "5 min ago", routingRule: "Field team purchases"),
    TrackedMailbox(address: "ap-invoices@parcelops.example", provider: .imap, monitoredFolders: "Orders", status: "Needs auth", lastChecked: "Yesterday", routingRule: "Invoice-only matching")
  ]

  static var shopifyConnections: [ShopifyConnection] = [
    ShopifyConnection(storeName: "Acme Parts", storeDomain: "acme-parts.myshopify.com", mappedMailbox: "field-purchasing@parcelops.example", mappedTeam: "Brisbane Field Team", status: "Synced", lastSync: "6 min ago", isEnabled: true),
    ShopifyConnection(storeName: "SafetyPro Direct", storeDomain: "safetypro-direct.myshopify.com", mappedMailbox: "tracking-intake@parcelops.example", mappedTeam: "Melbourne Operations", status: "Synced", lastSync: "12 min ago", isEnabled: true),
    ShopifyConnection(storeName: "Office Kit Store", storeDomain: "office-kit.myshopify.com", mappedMailbox: "ap-invoices@parcelops.example", mappedTeam: "Perth Office", status: "Needs reauth", lastSync: "Yesterday", isEnabled: false)
  ]

  static var watchedFolders: [WatchedFolder] = [
    WatchedFolder(name: "Desktop screenshots", location: "~/Desktop", platform: "macOS", fileTypes: "PNG, JPG, PDF", cadence: "Every 15 minutes", status: "Watching", lastScan: "3 min ago"),
    WatchedFolder(name: "Downloads invoices", location: "~/Downloads", platform: "macOS", fileTypes: "PDF, CSV", cadence: "Every 15 minutes", status: "Watching", lastScan: "8 min ago"),
    WatchedFolder(name: "Order uploads", location: "iCloud Drive/ParcelOps Orders", platform: "iOS and macOS", fileTypes: "PDF, images, email exports", cadence: "Hourly", status: "Watching", lastScan: "23 min ago")
  ]

  static var wishlistItems: [WishlistItem] = [
    WishlistItem(itemName: "Compact barcode scanner", storefront: "SafetyPro Direct", storefrontURL: "https://safetypro.example/scanner-compact", estimatedCost: "$189.00", owner: "Mia Chen", pool: "Shared company pool", source: .shareSheet, status: "Ready", capturedDetail: "Shared from Safari with item URL, visible price, and supplier page title."),
    WishlistItem(itemName: "Thermal label rolls", storefront: "Office Kit Store", storefrontURL: "https://officekit.example/thermal-rolls", estimatedCost: "$42.50", owner: "Jordan Lee", pool: "Personal wishlist", source: .screenshot, status: "Needs review", capturedDetail: "Screenshot parser found item title and price, but storefront URL needs confirmation."),
    WishlistItem(itemName: "Dock safety cones", storefront: "Northwind Wholesale", storefrontURL: "https://northwind.example/cones", estimatedCost: "$76.00", owner: "Priya Shah", pool: "Facilities team", source: .browserExtension, status: "Ready", capturedDetail: "Captured through Chrome/Firefox extension path for cross-device wishlist intake.")
  ]

  static var deletedWishlistItems: [WishlistItem] = [
    WishlistItem(itemName: "Old label printer cable", storefront: "Office Kit Store", storefrontURL: "https://officekit.example/old-cable", estimatedCost: "$18.40", owner: "Jordan Lee", pool: "Personal wishlist", source: .manual, status: "Deleted 12 days ago", capturedDetail: "Moved to deleted items. It will be retained for 90 days before permanent removal.")
  ]

  static var connections: [SourceConnection] = [
    SourceConnection(name: "3 tracked mailboxes", kind: .mailbox, account: "Microsoft 365, Gmail, IMAP", status: "2 watching", lastSync: "2 min ago"),
    SourceConnection(name: "3 Shopify stores", kind: .shopify, account: "OAuth connections", status: "2 active", lastSync: "6 min ago"),
    SourceConnection(name: "3 watched folders", kind: .watchedFolder, account: "Desktop, Downloads, iCloud Drive", status: "Watching", lastSync: "3 min ago"),
    SourceConnection(name: "Northwind Wholesale", kind: .vaultLogin, account: "Password vault", status: "Needs 2FA soon", lastSync: "1 hr ago"),
    SourceConnection(name: "SafetyPro Supplies", kind: .vaultLogin, account: "Password vault", status: "Synced", lastSync: "14 min ago")
  ]
}
