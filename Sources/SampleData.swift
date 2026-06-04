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

  static var evidenceAttachments: [EvidenceAttachment] = [
    EvidenceAttachment(
      linkedEntityType: .order,
      linkedEntityID: orders[0].id,
      fileName: "SafetyPro-SP-10492-shipping-confirmation.eml",
      fileType: "Email export",
      source: .forwardedEmail,
      addedDate: "Yesterday 6:12 PM",
      summary: "Shipping confirmation with Australia Post tracking number 33AUL8841295.",
      reviewState: .accepted,
      localFilePath: "~/Library/Application Support/ParcelOps/Evidence/SafetyPro-SP-10492-shipping-confirmation.eml"
    ),
    EvidenceAttachment(
      linkedEntityType: .intakeEmail,
      linkedEntityID: intakeEmails[1].id,
      fileName: "OfficeKit-OK-58214-order-confirmation.pdf",
      fileType: "PDF",
      source: .manualUpload,
      addedDate: "Today 11:44 AM",
      summary: "Forwarded confirmation rendered to PDF for review before order creation.",
      reviewState: .needsReview,
      localFilePath: "~/Library/Application Support/ParcelOps/Evidence/OfficeKit-OK-58214-order-confirmation.pdf"
    ),
    EvidenceAttachment(
      linkedEntityType: .order,
      linkedEntityID: orders[3].id,
      fileName: "Regional-Courier-MAN-2194-dock-details.png",
      fileType: "Screenshot",
      source: .screenshot,
      addedDate: "Today 10:22 AM",
      summary: "Screenshot of dock delivery details supplied by Facilities.",
      reviewState: .monitor,
      localFilePath: "~/Library/Application Support/ParcelOps/Evidence/Regional-Courier-MAN-2194-dock-details.png"
    )
  ]

  static var carrierTrackingEvents: [CarrierTrackingEvent] = [
    CarrierTrackingEvent(
      orderID: orders[0].id,
      carrier: "Australia Post",
      trackingNumber: "33AUL8841295",
      eventTime: "Today 9:12 AM",
      location: "Melbourne VIC",
      status: "In transit",
      detail: "Arrived at Melbourne sorting facility.",
      severity: .info,
      source: .carrierMock,
      reviewState: .accepted
    ),
    CarrierTrackingEvent(
      orderID: orders[1].id,
      carrier: "DHL",
      trackingNumber: "JD0146000098312",
      eventTime: "Today 8:05 AM",
      location: "Brisbane QLD",
      status: "Address confirmation required",
      detail: "Carrier needs suite or reception details before delivery can continue.",
      severity: .critical,
      source: .carrierMock,
      reviewState: .needsReview
    ),
    CarrierTrackingEvent(
      orderID: orders[2].id,
      carrier: "Northwind Perth counter",
      trackingNumber: "Pickup code NW7720",
      eventTime: "Today 7:30 AM",
      location: "Perth WA",
      status: "Awaiting dispatch confirmation",
      detail: "Portal shows order ready soon, but no collection confirmation has been received.",
      severity: .watch,
      source: .shopifyMock,
      reviewState: .monitor
    )
  ]

  static var automationRules: [AutomationRule] = [
    AutomationRule(
      name: "Create review task for uncertain forwarded emails",
      triggerType: .forwardedEmailCaptured,
      conditionSummary: "Detected order number, tracking number, or destination is missing.",
      actionSummary: "Leave intake email in Needs Review and avoid creating an order automatically.",
      isEnabled: true,
      lastRunDate: "Today 11:42 AM",
      reviewState: .accepted,
      runCount: 12
    ),
    AutomationRule(
      name: "Route tracking warnings to review",
      triggerType: .trackingWarning,
      conditionSummary: "Carrier event severity is Watch or Critical.",
      actionSummary: "Add event to Needs Review without contacting the carrier.",
      isEnabled: true,
      lastRunDate: "Today 8:05 AM",
      reviewState: .monitor,
      runCount: 4
    ),
    AutomationRule(
      name: "Require evidence review before acceptance",
      triggerType: .evidenceAdded,
      conditionSummary: "New attachment is added from placeholder, screenshot, or watched folder.",
      actionSummary: "Set evidence review state to Needs review.",
      isEnabled: false,
      lastRunDate: "Never",
      reviewState: .needsReview,
      runCount: 0
    )
  ]

  static var savedFilters: [SavedFilter] = [
    SavedFilter(
      name: "Open review workload",
      queryText: "",
      entityTypeFilter: nil,
      reviewStateFilter: .needsReview,
      createdDate: "Today 11:45 AM",
      isPinned: true
    ),
    SavedFilter(
      name: "Tracking warnings",
      queryText: "warning",
      entityTypeFilter: .trackingEvent,
      reviewStateFilter: nil,
      createdDate: "Today 10:20 AM",
      isPinned: true
    ),
    SavedFilter(
      name: "Office Kit intake",
      queryText: "Office Kit",
      entityTypeFilter: .intakeEmail,
      reviewStateFilter: .needsReview,
      createdDate: "Yesterday 4:35 PM",
      isPinned: false
    )
  ]

  static var reviewTasks: [ReviewTask] = [
    ReviewTask(
      title: "Confirm DHL delivery address",
      summary: "Contact Brisbane Field Team for suite or reception details before DHL continues delivery.",
      linkedEntityType: .order,
      linkedEntityID: orders[1].id.uuidString,
      priority: .urgent,
      dueDate: "Today 2:00 PM",
      assignee: "Brisbane Field Team",
      status: .open,
      createdDate: "Today 8:07 AM",
      completedDate: nil,
      reviewState: .needsReview
    ),
    ReviewTask(
      title: "Create Office Kit order record",
      summary: "Review forwarded confirmation and create a tracked order after merchant and destination are accepted.",
      linkedEntityType: .intakeEmail,
      linkedEntityID: intakeEmails[1].id.uuidString,
      priority: .high,
      dueDate: "Today 4:00 PM",
      assignee: "Operations",
      status: .inProgress,
      createdDate: "Today 11:45 AM",
      completedDate: nil,
      reviewState: .needsReview
    ),
    ReviewTask(
      title: "Check evidence retention path",
      summary: "Confirm placeholder evidence path is acceptable before marking the Office Kit attachment reviewed.",
      linkedEntityType: .evidence,
      linkedEntityID: evidenceAttachments[1].id.uuidString,
      priority: .normal,
      dueDate: "Tomorrow",
      assignee: "Records",
      status: .open,
      createdDate: "Today 11:50 AM",
      completedDate: nil,
      reviewState: .monitor
    )
  ]

  static var handoffNotes: [HandoffNote] = [
    HandoffNote(
      title: "Brisbane address exception handoff",
      summary: "DHL is waiting on destination clarification before the next carrier update.",
      linkedEntityType: .order,
      linkedEntityID: orders[1].id.uuidString,
      priority: .urgent,
      assignee: "Evening operations",
      createdDate: "Today 12:05 PM",
      dueDate: "Today 3:00 PM",
      status: .open,
      reviewState: .needsReview,
      notes: "Keep the order in exception until Brisbane Field Team confirms suite/reception details."
    ),
    HandoffNote(
      title: "Office Kit intake to order handoff",
      summary: "Forwarded email and PDF import need one accepted order before end of shift.",
      linkedEntityType: .shipmentGroup,
      linkedEntityID: shipmentGroups[2].id.uuidString,
      priority: .high,
      assignee: "Operations",
      createdDate: "Today 11:55 AM",
      dueDate: "Today 5:00 PM",
      status: .inProgress,
      reviewState: .needsReview,
      notes: "Compare import queue and acceptance history before creating the tracked order."
    ),
    HandoffNote(
      title: "Reconciliation watchlist handoff",
      summary: "Review any accepted source without a linked order before marking the acceptance record final.",
      linkedEntityType: .reconciliationIssue,
      linkedEntityID: "recon-accepted-without-order-sample",
      priority: .high,
      assignee: "Order control",
      createdDate: "Today 1:15 PM",
      dueDate: "Tomorrow",
      status: .open,
      reviewState: .monitor,
      notes: "Use this as the local placeholder for reconciliation shift notes."
    )
  ]

  static var slaPolicies: [SLAPolicy] = [
    SLAPolicy(
      name: "Carrier critical events same-day response",
      linkedEntityType: .trackingEvent,
      conditionSummary: "Carrier tracking event severity is Critical or task priority is Urgent.",
      responseTarget: "Respond within 2 business hours",
      resolutionTarget: "Resolve or escalate same day",
      priority: .urgent,
      isEnabled: true,
      createdDate: "Today 8:00 AM",
      lastEvaluatedDate: "Today 8:07 AM",
      matchCount: 1,
      reviewState: .accepted
    ),
    SLAPolicy(
      name: "Forwarded intake missing tracking",
      linkedEntityType: .intakeEmail,
      conditionSummary: "Forwarded email has order details but tracking is Pending or Not detected.",
      responseTarget: "Review within 4 business hours",
      resolutionTarget: "Create or link order within 1 business day",
      priority: .high,
      isEnabled: true,
      createdDate: "Yesterday 3:20 PM",
      lastEvaluatedDate: "Today 11:45 AM",
      matchCount: 2,
      reviewState: .monitor
    ),
    SLAPolicy(
      name: "Evidence retention review",
      linkedEntityType: .evidence,
      conditionSummary: "New evidence is added from placeholder upload or watched folder.",
      responseTarget: "Acknowledge by next business day",
      resolutionTarget: "Mark reviewed within 2 business days",
      priority: .normal,
      isEnabled: false,
      createdDate: "Yesterday 1:10 PM",
      lastEvaluatedDate: "Never",
      matchCount: 0,
      reviewState: .needsReview
    )
  ]

  static var exceptionPlaybooks: [ExceptionPlaybook] = [
    ExceptionPlaybook(
      name: "Address conflict review",
      issueType: .destinationConflict,
      linkedEntityType: .order,
      triggerSummary: "Detected destination differs from the tracked order or shipment group.",
      recommendedSteps: "Compare forwarded email, import record, order destination, and shipment group summary. Keep original evidence, then update only the operational record confirmed by staff.",
      escalationContact: "Address desk",
      priority: .high,
      isEnabled: true,
      createdDate: "Today 8:30 AM",
      lastReviewedDate: "Today 9:10 AM",
      usageCount: 2,
      reviewState: .accepted
    ),
    ExceptionPlaybook(
      name: "Missing tracking number",
      issueType: .missingLink,
      linkedEntityType: .intakeEmail,
      triggerSummary: "Forwarded email or import has order details but tracking is Pending or Not detected.",
      recommendedSteps: "Check the source email/import summary, create a review task for the supplier team, and keep the order in Intake until a tracking number is confirmed.",
      escalationContact: "Supplier follow-up",
      priority: .high,
      isEnabled: true,
      createdDate: "Yesterday 3:35 PM",
      lastReviewedDate: "Today 11:45 AM",
      usageCount: 1,
      reviewState: .monitor
    ),
    ExceptionPlaybook(
      name: "Duplicate staged record triage",
      issueType: .duplicateStagedRecord,
      linkedEntityType: .importQueueItem,
      triggerSummary: "Two staged local records appear to share an order number or tracking number.",
      recommendedSteps: "Compare source labels, detected order numbers, tracking numbers, and destinations. Preserve both source records as evidence, but accept only the correct operational link.",
      escalationContact: "Operations review",
      priority: .normal,
      isEnabled: true,
      createdDate: "Today 10:05 AM",
      lastReviewedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    ),
    ExceptionPlaybook(
      name: "Accepted source missing order",
      issueType: .acceptedWithoutOrder,
      linkedEntityType: .acceptanceRecord,
      triggerSummary: "Acceptance history is marked accepted but no tracked order is linked.",
      recommendedSteps: "Reopen the acceptance candidate, link it to an existing tracked order or create a new order, then mark the acceptance record reviewed again.",
      escalationContact: "Order control",
      priority: .urgent,
      isEnabled: true,
      createdDate: "Today 11:00 AM",
      lastReviewedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    ),
    ExceptionPlaybook(
      name: "Shipment group missing primary order",
      issueType: .shipmentGroupMissingPrimary,
      linkedEntityType: .shipmentGroup,
      triggerSummary: "Shipment group has related records but no valid primary tracked order.",
      recommendedSteps: "Review related intake/import records, choose the primary order if present, or create an order from the most reliable accepted source.",
      escalationContact: "Fulfilment desk",
      priority: .high,
      isEnabled: true,
      createdDate: "Today 11:50 AM",
      lastReviewedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    )
  ]

  static var communicationTemplates: [CommunicationTemplate] = [
    CommunicationTemplate(
      name: "Carrier address clarification",
      linkedEntityType: .trackingEvent,
      subjectTemplate: "Address confirmation needed for {{record}}",
      bodyTemplate: "Hello,\n\nWe are following up on tracking record {{record}}. Please confirm the delivery address details required to continue delivery.\n\nRegards,\nParcelOps",
      channel: .email,
      isEnabled: true,
      createdDate: "Today 8:12 AM",
      lastUsedDate: "Today 8:15 AM",
      usageCount: 1,
      reviewState: .accepted
    ),
    CommunicationTemplate(
      name: "Internal task escalation",
      linkedEntityType: .order,
      subjectTemplate: "ParcelOps follow-up required for {{record}}",
      bodyTemplate: "Hi team,\n\nParcelOps has flagged {{record}} for local review. Please confirm the next action and update the tracked record.\n\nThanks.",
      channel: .internalNote,
      isEnabled: true,
      createdDate: "Yesterday 4:10 PM",
      lastUsedDate: "Never",
      usageCount: 0,
      reviewState: .monitor
    ),
    CommunicationTemplate(
      name: "Evidence review request",
      linkedEntityType: .evidence,
      subjectTemplate: "Evidence review requested for {{record}}",
      bodyTemplate: "Please review the evidence attached to {{record}} and confirm whether it can be accepted locally.",
      channel: .email,
      isEnabled: false,
      createdDate: "Yesterday 1:25 PM",
      lastUsedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    )
  ]

  static var draftMessages: [DraftMessage] = [
    DraftMessage(
      linkedEntityType: .trackingEvent,
      linkedEntityID: carrierTrackingEvents[1].id.uuidString,
      templateID: communicationTemplates[0].id,
      recipient: "carrier-support@parcelops.example",
      subject: "Address confirmation needed for JD0146000098312",
      body: "Hello,\n\nWe are following up on tracking record JD0146000098312. Please confirm the delivery address details required to continue delivery.\n\nRegards,\nParcelOps",
      channel: .email,
      createdDate: "Today 8:15 AM",
      status: .draft,
      reviewState: .needsReview
    ),
    DraftMessage(
      linkedEntityType: .order,
      linkedEntityID: orders[1].id.uuidString,
      templateID: communicationTemplates[1].id,
      recipient: "Brisbane Field Team",
      subject: "ParcelOps follow-up required for SHP-8831",
      body: "Hi team,\n\nParcelOps has flagged SHP-8831 for local review. Please confirm the next action and update the tracked record.\n\nThanks.",
      channel: .internalNote,
      createdDate: "Today 8:20 AM",
      status: .ready,
      reviewState: .accepted
    )
  ]

  static var contactDirectoryEntries: [ContactDirectoryEntry] = [
    ContactDirectoryEntry(
      name: "Jade Carrier Support",
      organisation: "Jade Delivery",
      role: "Carrier exception desk",
      email: "carrier-support@parcelops.example",
      phone: "+61 2 5550 0142",
      channelPreference: .email,
      linkedEntityType: .carrier,
      linkedEntityID: "Jade Delivery",
      notes: "Use for address clarification and missed delivery exceptions.",
      isEnabled: true,
      createdDate: "Today 8:05 AM",
      lastContactedDate: "Today 8:15 AM",
      reviewState: .accepted
    ),
    ContactDirectoryEntry(
      name: "Office Kit Orders",
      organisation: "Office Kit Store",
      role: "Supplier orders team",
      email: "orders@officekit.example",
      phone: "+61 3 5550 0188",
      channelPreference: .email,
      linkedEntityType: .supplier,
      linkedEntityID: "Office Kit Store",
      notes: "Preferred contact for missing tracking numbers on forwarded invoices.",
      isEnabled: true,
      createdDate: "Yesterday 2:45 PM",
      lastContactedDate: "Never",
      reviewState: .monitor
    ),
    ContactDirectoryEntry(
      name: "Brisbane Field Team",
      organisation: "ParcelOps Field Ops",
      role: "Internal team",
      email: "brisbane-field@parcelops.example",
      phone: "Internal extension 208",
      channelPreference: .internalNote,
      linkedEntityType: .internalTeam,
      linkedEntityID: "Brisbane Field Team",
      notes: "Local owner for pickup and collection-point follow-up tasks.",
      isEnabled: true,
      createdDate: "Yesterday 9:10 AM",
      lastContactedDate: "Today 8:20 AM",
      reviewState: .accepted
    ),
    ContactDirectoryEntry(
      name: "Shopify Store Admin",
      organisation: "Shopify demo store",
      role: "Store admin",
      email: "admin@shopify-demo.example",
      phone: "Not recorded",
      channelPreference: .supplierPortal,
      linkedEntityType: .shopifyStore,
      linkedEntityID: shopifyConnections[0].id.uuidString,
      notes: "Placeholder contact until real Shopify user/contact sync is implemented.",
      isEnabled: false,
      createdDate: "Today 9:30 AM",
      lastContactedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var customerRecipientProfiles: [CustomerRecipientProfile] = [
    CustomerRecipientProfile(
      displayName: "Brisbane Field Team",
      profileType: .internalTeam,
      organisationTeam: "ParcelOps Field Ops",
      primaryEmail: "brisbane-field@parcelops.example",
      phone: "Internal extension 208",
      defaultDestinationAddress: "77 Eagle Street, Brisbane QLD",
      deliveryPreference: .internalHandoff,
      notes: "Owner for Brisbane pickup, delivery exception, and site handoff records.",
      isEnabled: true,
      createdDate: "Today 8:00 AM",
      lastReviewedDate: "Today 8:20 AM",
      reviewState: .accepted
    ),
    CustomerRecipientProfile(
      displayName: "Operations Mailbox",
      profileType: .department,
      organisationTeam: "ParcelOps Operations",
      primaryEmail: "orders@parcelops.example",
      phone: "Internal extension 100",
      defaultDestinationAddress: "Melbourne operations hub",
      deliveryPreference: .delivery,
      notes: "Default recipient profile for forwarded mailbox intake and manual imports.",
      isEnabled: true,
      createdDate: "Yesterday 9:00 AM",
      lastReviewedDate: "Yesterday 9:20 AM",
      reviewState: .monitor
    ),
    CustomerRecipientProfile(
      displayName: "Shopify demo recipient",
      profileType: .customer,
      organisationTeam: "Shopify demo store",
      primaryEmail: "customer@example.com",
      phone: "Not recorded",
      defaultDestinationAddress: "12 Market Street, Melbourne VIC",
      deliveryPreference: .delivery,
      notes: "Placeholder customer profile until real Shopify customer syncing exists.",
      isEnabled: false,
      createdDate: "Today 9:45 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var destinationAddresses: [DestinationAddressRecord] = [
    DestinationAddressRecord(
      label: "Brisbane Eagle Street field site",
      customerProfileID: customerRecipientProfiles[0].id,
      organisationTeam: "ParcelOps Field Ops",
      addressLineSummary: "77 Eagle Street",
      cityRegion: "Brisbane QLD",
      country: "Australia",
      deliveryInstructions: "Escalate address exceptions to Brisbane Field Team before carrier cut-off.",
      accessNotes: "Reception accepts parcels during business hours only.",
      preferredCarrier: "Jade Delivery",
      riskLevel: .high,
      isEnabled: true,
      createdDate: "Today 8:10 AM",
      lastReviewedDate: "Today 8:25 AM",
      reviewState: .monitor
    ),
    DestinationAddressRecord(
      label: "Melbourne operations hub",
      customerProfileID: customerRecipientProfiles[1].id,
      organisationTeam: "ParcelOps Operations",
      addressLineSummary: "Melbourne operations hub",
      cityRegion: "Melbourne VIC",
      country: "Australia",
      deliveryInstructions: "Default delivery destination for operations intake.",
      accessNotes: "Dock access by appointment.",
      preferredCarrier: "Any carrier",
      riskLevel: .medium,
      isEnabled: true,
      createdDate: "Yesterday 9:05 AM",
      lastReviewedDate: "Yesterday 9:25 AM",
      reviewState: .accepted
    ),
    DestinationAddressRecord(
      label: "Shopify demo customer address",
      customerProfileID: customerRecipientProfiles[2].id,
      organisationTeam: "Shopify demo store",
      addressLineSummary: "12 Market Street",
      cityRegion: "Melbourne VIC",
      country: "Australia",
      deliveryInstructions: "Placeholder destination until Shopify customer syncing is implemented.",
      accessNotes: "Needs manual confirmation.",
      preferredCarrier: "Jade Delivery",
      riskLevel: .high,
      isEnabled: false,
      createdDate: "Today 9:50 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var deliveryInstructions: [DeliveryInstructionRecord] = [
    DeliveryInstructionRecord(
      title: "Field site reception window",
      destinationAddressID: destinationAddresses[0].id,
      customerProfileID: customerRecipientProfiles[0].id,
      linkedEntityType: .destinationAddress,
      linkedEntityID: destinationAddresses[0].id.uuidString,
      instructionType: .deliveryWindow,
      instructionSummary: "Deliver to reception before the afternoon carrier cut-off.",
      accessConstraintSummary: "Reception only accepts parcels while the field desk is staffed.",
      preferredDeliveryWindow: "Weekdays 9:00 AM - 2:00 PM",
      restrictedDeliveryWindow: "After 3:00 PM requires team confirmation",
      carrierNotes: "Jade Delivery should call the field ops contact before failed-delivery scan.",
      riskLevel: .high,
      isEnabled: true,
      createdDate: "Today 8:20 AM",
      lastReviewedDate: "Today 8:35 AM",
      reviewState: .monitor
    ),
    DeliveryInstructionRecord(
      title: "Operations dock appointment",
      destinationAddressID: destinationAddresses[1].id,
      customerProfileID: customerRecipientProfiles[1].id,
      linkedEntityType: .destinationAddress,
      linkedEntityID: destinationAddresses[1].id.uuidString,
      instructionType: .accessConstraint,
      instructionSummary: "Use the loading dock for bulky operations orders.",
      accessConstraintSummary: "Dock access is by appointment and must be noted before dispatch.",
      preferredDeliveryWindow: "Weekdays 10:00 AM - 4:00 PM",
      restrictedDeliveryWindow: "No dock access on weekends",
      carrierNotes: "Any carrier can use front reception for small satchels.",
      riskLevel: .medium,
      isEnabled: true,
      createdDate: "Yesterday 9:20 AM",
      lastReviewedDate: "Yesterday 9:40 AM",
      reviewState: .accepted
    ),
    DeliveryInstructionRecord(
      title: "Shopify address confirmation",
      destinationAddressID: destinationAddresses[2].id,
      customerProfileID: customerRecipientProfiles[2].id,
      linkedEntityType: .destinationAddress,
      linkedEntityID: destinationAddresses[2].id.uuidString,
      instructionType: .contactRequired,
      instructionSummary: "Confirm the customer delivery notes before accepting the shipment group.",
      accessConstraintSummary: "Address is disabled until customer profile and destination are reviewed.",
      preferredDeliveryWindow: "To be confirmed",
      restrictedDeliveryWindow: "Do not dispatch until manually confirmed",
      carrierNotes: "Hold carrier selection until Shopify syncing exists.",
      riskLevel: .critical,
      isEnabled: false,
      createdDate: "Today 9:55 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var packageContents: [PackageContentRecord] = [
    PackageContentRecord(
      title: "Office equipment bundle",
      linkedEntityType: .order,
      linkedEntityID: orders[0].id.uuidString,
      orderID: orders[0].id,
      shipmentGroupID: shipmentGroups.first?.id,
      destinationAddressID: destinationAddresses[0].id,
      deliveryInstructionID: deliveryInstructions[0].id,
      customerProfileID: customerRecipientProfiles[0].id,
      itemSummary: "Laptop stand, USB-C dock, and field kit accessories.",
      expectedQuantity: 3,
      verifiedQuantity: 2,
      itemCategory: .electronics,
      valueBand: .high,
      verificationStatus: .partiallyVerified,
      discrepancySummary: "USB-C dock still needs local confirmation against evidence.",
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      riskLevel: .high,
      createdDate: "Today 8:45 AM",
      lastReviewedDate: "Today 9:05 AM",
      reviewState: .monitor
    ),
    PackageContentRecord(
      title: "Operations stationery replenishment",
      linkedEntityType: .shipmentGroup,
      linkedEntityID: shipmentGroups.first?.id.uuidString ?? "Unlinked",
      orderID: orders.indices.contains(1) ? orders[1].id : nil,
      shipmentGroupID: shipmentGroups.first?.id,
      destinationAddressID: destinationAddresses[1].id,
      deliveryInstructionID: deliveryInstructions[1].id,
      customerProfileID: customerRecipientProfiles[1].id,
      itemSummary: "Printer paper, labels, and packing tape for the operations hub.",
      expectedQuantity: 12,
      verifiedQuantity: 12,
      itemCategory: .officeSupplies,
      valueBand: .medium,
      verificationStatus: .verified,
      discrepancySummary: "No discrepancy recorded.",
      evidenceAttachmentIDs: [],
      riskLevel: .low,
      createdDate: "Yesterday 10:30 AM",
      lastReviewedDate: "Yesterday 11:00 AM",
      reviewState: .accepted
    ),
    PackageContentRecord(
      title: "Shopify customer contents to confirm",
      linkedEntityType: .destinationAddress,
      linkedEntityID: destinationAddresses[2].id.uuidString,
      orderID: nil,
      shipmentGroupID: nil,
      destinationAddressID: destinationAddresses[2].id,
      deliveryInstructionID: deliveryInstructions[2].id,
      customerProfileID: customerRecipientProfiles[2].id,
      itemSummary: "Customer order contents not verified until Shopify syncing is implemented.",
      expectedQuantity: 1,
      verifiedQuantity: 0,
      itemCategory: .other,
      valueBand: .unknown,
      verificationStatus: .discrepancy,
      discrepancySummary: "Detected content details are missing and require manual review.",
      evidenceAttachmentIDs: [],
      riskLevel: .critical,
      createdDate: "Today 10:05 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var costRecords: [CostRecord] = [
    CostRecord(
      title: "Field kit purchase cost",
      linkedEntityType: .packageContent,
      linkedEntityID: packageContents[0].id.uuidString,
      orderID: orders[0].id,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[0].id,
      customerProfileID: customerRecipientProfiles[0].id,
      vendorProfileID: vendorProfiles.first?.id,
      accountID: accountCredentialRecords.first?.id,
      costCategory: .orderCost,
      amountText: "428.90",
      currency: "AUD",
      taxGSTText: "GST included 38.99",
      reimbursementStatus: .pending,
      approvalStatus: .pendingApproval,
      budgetCode: "FIELD-OPS-2026",
      costOwnerTeam: "ParcelOps Field Ops",
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      notes: "Awaiting dock accessory verification before final approval.",
      riskLevel: .high,
      createdDate: "Today 9:10 AM",
      lastReviewedDate: "Today 9:20 AM",
      reviewState: .monitor
    ),
    CostRecord(
      title: "Operations stationery replenishment",
      linkedEntityType: .shipmentGroup,
      linkedEntityID: shipmentGroups.first?.id.uuidString ?? "Unlinked",
      orderID: orders.indices.contains(1) ? orders[1].id : nil,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[1].id,
      customerProfileID: customerRecipientProfiles[1].id,
      vendorProfileID: nil,
      accountID: nil,
      costCategory: .orderCost,
      amountText: "96.50",
      currency: "AUD",
      taxGSTText: "GST included 8.77",
      reimbursementStatus: .notRequired,
      approvalStatus: .approved,
      budgetCode: "OPS-SUPPLIES",
      costOwnerTeam: "ParcelOps Operations",
      evidenceAttachmentIDs: [],
      notes: "Verified locally against stationery replenishment content.",
      riskLevel: .low,
      createdDate: "Yesterday 11:05 AM",
      lastReviewedDate: "Yesterday 11:15 AM",
      reviewState: .accepted
    ),
    CostRecord(
      title: "Shopify customer cost to confirm",
      linkedEntityType: .packageContent,
      linkedEntityID: packageContents[2].id.uuidString,
      orderID: nil,
      shipmentGroupID: nil,
      packageContentID: packageContents[2].id,
      customerProfileID: customerRecipientProfiles[2].id,
      vendorProfileID: nil,
      accountID: nil,
      costCategory: .other,
      amountText: "Unknown",
      currency: "AUD",
      taxGSTText: "Unknown",
      reimbursementStatus: .disputed,
      approvalStatus: .needsReview,
      budgetCode: "",
      costOwnerTeam: "Shopify demo store",
      evidenceAttachmentIDs: [],
      notes: "Cost blocked until Shopify/order details are available locally.",
      riskLevel: .critical,
      createdDate: "Today 10:15 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var returnClaims: [ReturnClaimRecord] = [
    ReturnClaimRecord(
      title: "Damaged dock accessory claim",
      linkedEntityType: .packageContent,
      linkedEntityID: packageContents[0].id.uuidString,
      orderID: orders[0].id,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[0].id,
      costRecordID: costRecords[0].id,
      customerProfileID: customerRecipientProfiles[0].id,
      vendorProfileID: vendorProfiles.first?.id,
      accountID: accountCredentialRecords.first?.id,
      claimType: .damageClaim,
      reasonSummary: "Dock accessory packaging is marked damaged and content verification is still pending.",
      requestedOutcome: .replacement,
      claimStatus: .submitted,
      refundReplacementAmountText: "428.90",
      currency: "AUD",
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      carrierTrackingEventIDs: carrierTrackingEvents.prefix(1).map(\.id),
      assignedOwnerTeam: "ParcelOps Field Ops",
      dueDate: "Today",
      riskLevel: .high,
      createdDate: "Today 9:35 AM",
      lastReviewedDate: "Today 9:45 AM",
      reviewState: .monitor
    ),
    ReturnClaimRecord(
      title: "Missing stationery item follow-up",
      linkedEntityType: .shipmentGroup,
      linkedEntityID: shipmentGroups.first?.id.uuidString ?? "Unlinked",
      orderID: orders.indices.contains(1) ? orders[1].id : nil,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[1].id,
      costRecordID: costRecords[1].id,
      customerProfileID: customerRecipientProfiles[1].id,
      vendorProfileID: nil,
      accountID: nil,
      claimType: .missingItemClaim,
      reasonSummary: "Stationery count differs from the local package content verification record.",
      requestedOutcome: .credit,
      claimStatus: .draft,
      refundReplacementAmountText: "18.40",
      currency: "AUD",
      evidenceAttachmentIDs: [],
      carrierTrackingEventIDs: [],
      assignedOwnerTeam: "ParcelOps Operations",
      dueDate: "Tomorrow",
      riskLevel: .medium,
      createdDate: "Yesterday 2:20 PM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    ),
    ReturnClaimRecord(
      title: "Shopify refund details blocked",
      linkedEntityType: .costRecord,
      linkedEntityID: costRecords[2].id.uuidString,
      orderID: nil,
      shipmentGroupID: nil,
      packageContentID: packageContents[2].id,
      costRecordID: costRecords[2].id,
      customerProfileID: customerRecipientProfiles[2].id,
      vendorProfileID: nil,
      accountID: nil,
      claimType: .refund,
      reasonSummary: "Refund request cannot be reconciled until the linked Shopify order and amount are confirmed locally.",
      requestedOutcome: .refund,
      claimStatus: .disputed,
      refundReplacementAmountText: "Unknown",
      currency: "AUD",
      evidenceAttachmentIDs: [],
      carrierTrackingEventIDs: [],
      assignedOwnerTeam: "Shopify demo store",
      dueDate: "Overdue",
      riskLevel: .critical,
      createdDate: "Today 10:30 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var procurementRequests: [ProcurementRequest] = [
    ProcurementRequest(
      title: "Replacement dock accessory request",
      linkedEntityType: .returnClaim,
      linkedEntityID: returnClaims[0].id.uuidString,
      requesterTeam: "ParcelOps Field Ops",
      requestedDate: "Today 9:50 AM",
      neededByDate: "Today",
      vendorProfileID: vendorProfiles.first?.id,
      accountID: accountCredentialRecords.first?.id,
      customerProfileID: customerRecipientProfiles[0].id,
      destinationAddressID: destinationAddresses.first?.id,
      packageContentID: packageContents[0].id,
      costRecordID: costRecords[0].id,
      returnClaimID: returnClaims[0].id,
      requestedItemsSummary: "Replacement dock accessory for damaged field kit shipment.",
      estimatedCostText: "428.90",
      currency: "AUD",
      budgetCode: "FIELD-OPS-2026",
      approvalStatus: .pendingApproval,
      procurementStatus: .requested,
      assignedBuyerTeam: "Procurement Desk",
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      notes: "Hold order until claim evidence is reviewed locally.",
      riskLevel: .high,
      createdDate: "Today 9:50 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    ),
    ProcurementRequest(
      title: "Operations label roll replenishment",
      linkedEntityType: .costRecord,
      linkedEntityID: costRecords[1].id.uuidString,
      requesterTeam: "ParcelOps Operations",
      requestedDate: "Yesterday 11:20 AM",
      neededByDate: "Friday",
      vendorProfileID: nil,
      accountID: nil,
      customerProfileID: customerRecipientProfiles[1].id,
      destinationAddressID: destinationAddresses.indices.contains(1) ? destinationAddresses[1].id : nil,
      packageContentID: packageContents[1].id,
      costRecordID: costRecords[1].id,
      returnClaimID: nil,
      requestedItemsSummary: "Thermal label rolls for inbound parcel processing bench.",
      estimatedCostText: "96.50",
      currency: "AUD",
      budgetCode: "OPS-SUPPLIES",
      approvalStatus: .approved,
      procurementStatus: .ordered,
      assignedBuyerTeam: "Office Purchasing",
      evidenceAttachmentIDs: [],
      notes: "Approved locally against stationery replenishment budget.",
      riskLevel: .low,
      createdDate: "Yesterday 11:20 AM",
      lastReviewedDate: "Yesterday 11:35 AM",
      reviewState: .accepted
    ),
    ProcurementRequest(
      title: "Shopify replacement request blocked",
      linkedEntityType: .returnClaim,
      linkedEntityID: returnClaims[2].id.uuidString,
      requesterTeam: "Shopify demo store",
      requestedDate: "Today 10:40 AM",
      neededByDate: "Overdue",
      vendorProfileID: nil,
      accountID: nil,
      customerProfileID: customerRecipientProfiles[2].id,
      destinationAddressID: nil,
      packageContentID: packageContents[2].id,
      costRecordID: costRecords[2].id,
      returnClaimID: returnClaims[2].id,
      requestedItemsSummary: "Replacement or refund path cannot proceed until original order details are reconciled.",
      estimatedCostText: "Unknown",
      currency: "AUD",
      budgetCode: "",
      approvalStatus: .rejected,
      procurementStatus: .blocked,
      assignedBuyerTeam: "Procurement Desk",
      evidenceAttachmentIDs: [],
      notes: "Missing budget code and order context. Keep local-only until corrected.",
      riskLevel: .critical,
      createdDate: "Today 10:40 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var receivingInspections: [ReceivingInspectionRecord] = [
    ReceivingInspectionRecord(
      title: "Dock accessory condition inspection",
      linkedEntityType: .procurementRequest,
      linkedEntityID: procurementRequests[0].id.uuidString,
      orderID: orders[0].id,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[0].id,
      procurementRequestID: procurementRequests[0].id,
      returnClaimID: returnClaims[0].id,
      destinationAddressID: destinationAddresses.first?.id,
      customerProfileID: customerRecipientProfiles[0].id,
      carrierTrackingEventIDs: carrierTrackingEvents.prefix(1).map(\.id),
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      inspectionType: .packageCondition,
      inspectionStatus: .discrepancy,
      expectedItemSummary: "Replacement dock accessory should arrive sealed and undamaged.",
      receivedItemSummary: "Packaging shows visible corner crush and needs local evidence review.",
      quantityExpected: 1,
      quantityReceived: 1,
      conditionSummary: "Outer packaging damaged; item condition not yet confirmed.",
      discrepancyType: .damaged,
      discrepancySummary: "Damage claim evidence needs review before accepting receipt.",
      assignedInspectorTeam: "Receiving Desk",
      inspectionDate: "Today 10:05 AM",
      dueDate: "Today",
      riskLevel: .high,
      createdDate: "Today 10:05 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    ),
    ReceivingInspectionRecord(
      title: "Label roll quantity check",
      linkedEntityType: .procurementRequest,
      linkedEntityID: procurementRequests[1].id.uuidString,
      orderID: orders.indices.contains(1) ? orders[1].id : nil,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[1].id,
      procurementRequestID: procurementRequests[1].id,
      returnClaimID: nil,
      destinationAddressID: destinationAddresses.indices.contains(1) ? destinationAddresses[1].id : nil,
      customerProfileID: customerRecipientProfiles[1].id,
      carrierTrackingEventIDs: [],
      evidenceAttachmentIDs: [],
      inspectionType: .quantityCheck,
      inspectionStatus: .inspected,
      expectedItemSummary: "Thermal label rolls for operations bench.",
      receivedItemSummary: "Label rolls received and counted locally.",
      quantityExpected: 6,
      quantityReceived: 6,
      conditionSummary: "Clean receipt, no visible damage.",
      discrepancyType: .none,
      discrepancySummary: "No discrepancy recorded.",
      assignedInspectorTeam: "ParcelOps Operations",
      inspectionDate: "Yesterday 3:15 PM",
      dueDate: "Yesterday",
      riskLevel: .low,
      createdDate: "Yesterday 3:00 PM",
      lastReviewedDate: "Yesterday 3:20 PM",
      reviewState: .accepted
    ),
    ReceivingInspectionRecord(
      title: "Shopify replacement receipt blocked",
      linkedEntityType: .procurementRequest,
      linkedEntityID: procurementRequests[2].id.uuidString,
      orderID: nil,
      shipmentGroupID: nil,
      packageContentID: packageContents[2].id,
      procurementRequestID: procurementRequests[2].id,
      returnClaimID: returnClaims[2].id,
      destinationAddressID: nil,
      customerProfileID: customerRecipientProfiles[2].id,
      carrierTrackingEventIDs: [],
      evidenceAttachmentIDs: [],
      inspectionType: .exceptionReview,
      inspectionStatus: .blocked,
      expectedItemSummary: "Replacement item details are not available.",
      receivedItemSummary: "No local receipt can be confirmed.",
      quantityExpected: 1,
      quantityReceived: 0,
      conditionSummary: "Blocked until procurement and claim context are corrected.",
      discrepancyType: .documentationMissing,
      discrepancySummary: "Missing order, budget, and receipt evidence.",
      assignedInspectorTeam: "Receiving Desk",
      inspectionDate: "Never",
      dueDate: "Overdue",
      riskLevel: .critical,
      createdDate: "Today 10:50 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var inventoryReceipts: [InventoryReceiptRecord] = [
    InventoryReceiptRecord(
      title: "Dock accessory stock exception",
      linkedEntityType: .receivingInspection,
      linkedEntityID: receivingInspections[0].id.uuidString,
      receivingInspectionID: receivingInspections[0].id,
      orderID: orders[0].id,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[0].id,
      procurementRequestID: procurementRequests[0].id,
      returnClaimID: returnClaims[0].id,
      destinationAddressID: destinationAddresses.first?.id,
      customerProfileID: customerRecipientProfiles[0].id,
      evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id),
      receiptType: .stockReceipt,
      stockHandoffStatus: .partiallyAccepted,
      itemSummary: "Replacement dock accessory held pending damage review.",
      quantityReceived: 1,
      quantityAccepted: 0,
      quantityRejected: 1,
      storageLocationSummary: "Receiving cage - exception shelf",
      assignedOwnerTeam: "Receiving Desk",
      receivedDate: "Today 10:20 AM",
      handoffDate: "Not handed off",
      discrepancySummary: "Held because receiving inspection recorded visible packaging damage.",
      riskLevel: .high,
      createdDate: "Today 10:20 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    ),
    InventoryReceiptRecord(
      title: "Label rolls stocked to packing bench",
      linkedEntityType: .receivingInspection,
      linkedEntityID: receivingInspections[1].id.uuidString,
      receivingInspectionID: receivingInspections[1].id,
      orderID: orders.indices.contains(1) ? orders[1].id : nil,
      shipmentGroupID: shipmentGroups.first?.id,
      packageContentID: packageContents[1].id,
      procurementRequestID: procurementRequests[1].id,
      returnClaimID: nil,
      destinationAddressID: destinationAddresses.indices.contains(1) ? destinationAddresses[1].id : nil,
      customerProfileID: customerRecipientProfiles[1].id,
      evidenceAttachmentIDs: [],
      receiptType: .stockReceipt,
      stockHandoffStatus: .stocked,
      itemSummary: "Thermal label rolls counted and stocked for parcel bench use.",
      quantityReceived: 6,
      quantityAccepted: 6,
      quantityRejected: 0,
      storageLocationSummary: "Packing bench drawer A",
      assignedOwnerTeam: "ParcelOps Operations",
      receivedDate: "Yesterday 3:20 PM",
      handoffDate: "Yesterday 3:30 PM",
      discrepancySummary: "No discrepancy recorded.",
      riskLevel: .low,
      createdDate: "Yesterday 3:20 PM",
      lastReviewedDate: "Yesterday 3:35 PM",
      reviewState: .accepted
    ),
    InventoryReceiptRecord(
      title: "Replacement receipt rejected pending docs",
      linkedEntityType: .receivingInspection,
      linkedEntityID: receivingInspections[2].id.uuidString,
      receivingInspectionID: receivingInspections[2].id,
      orderID: nil,
      shipmentGroupID: nil,
      packageContentID: packageContents[2].id,
      procurementRequestID: procurementRequests[2].id,
      returnClaimID: returnClaims[2].id,
      destinationAddressID: nil,
      customerProfileID: customerRecipientProfiles[2].id,
      evidenceAttachmentIDs: [],
      receiptType: .exceptionReceipt,
      stockHandoffStatus: .rejected,
      itemSummary: "Replacement receipt cannot be accepted without source documentation.",
      quantityReceived: 0,
      quantityAccepted: 0,
      quantityRejected: 1,
      storageLocationSummary: "Unassigned",
      assignedOwnerTeam: "Receiving Desk",
      receivedDate: "Not received",
      handoffDate: "Blocked",
      discrepancySummary: "Missing order, receipt evidence, and storage assignment.",
      riskLevel: .critical,
      createdDate: "Today 10:55 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var accountCredentialRecords: [AccountCredentialRecord] = [
    AccountCredentialRecord(
      accountName: "Office Kit supplier portal",
      organisation: "Office Kit Store",
      linkedContactID: contactDirectoryEntries[1].id,
      linkedEntityType: .supplier,
      linkedEntityID: "Office Kit Store",
      loginURL: "https://supplier.example.com/login",
      usernameLabel: "External vault: Office Kit shared ordering username",
      credentialStorageStatus: .externalVaultReference,
      mfaStatus: .enabled,
      renewalReviewDate: "Next month",
      isEnabled: true,
      notes: "Local placeholder points to an external vault reference only. No secret is stored in ParcelOps.",
      createdDate: "Today 9:05 AM",
      lastCheckedDate: "Today 9:10 AM",
      reviewState: .accepted
    ),
    AccountCredentialRecord(
      accountName: "Shopify demo admin",
      organisation: "Shopify demo store",
      linkedContactID: contactDirectoryEntries[3].id,
      linkedEntityType: .shopifyStore,
      linkedEntityID: shopifyConnections[0].id.uuidString,
      loginURL: "https://admin.shopify.example",
      usernameLabel: "Admin user label only",
      credentialStorageStatus: .accessPending,
      mfaStatus: .needsReview,
      renewalReviewDate: "This week",
      isEnabled: false,
      notes: "Placeholder for future OAuth/account review. Do not store Shopify tokens here.",
      createdDate: "Today 9:35 AM",
      lastCheckedDate: "Never",
      reviewState: .needsReview
    ),
    AccountCredentialRecord(
      accountName: "Jade Delivery carrier portal",
      organisation: "Jade Delivery",
      linkedContactID: contactDirectoryEntries[0].id,
      linkedEntityType: .carrier,
      linkedEntityID: "Jade Delivery",
      loginURL: "https://carrier.example.com/login",
      usernameLabel: "External vault carrier support login",
      credentialStorageStatus: .rotatedExternally,
      mfaStatus: .enabled,
      renewalReviewDate: "Quarterly",
      isEnabled: true,
      notes: "Use for manual carrier portal checks only; carrier API integration is not enabled.",
      createdDate: "Yesterday 3:40 PM",
      lastCheckedDate: "Today 8:25 AM",
      reviewState: .monitor
    )
  ]

  static var vendorProfiles: [VendorProfile] = [
    VendorProfile(
      name: "Office Kit Store",
      profileType: .supplier,
      primaryOrganisation: "Office Kit Store",
      website: "https://officekit.example",
      supportURL: "https://officekit.example/support",
      defaultContactID: contactDirectoryEntries[1].id,
      defaultAccountID: accountCredentialRecords[0].id,
      preferredChannel: .email,
      serviceLevelNotes: "Missing tracking numbers should be reviewed within one business day.",
      riskLevel: .medium,
      isEnabled: true,
      createdDate: "Today 9:45 AM",
      lastReviewedDate: "Today 9:50 AM",
      reviewState: .accepted
    ),
    VendorProfile(
      name: "Jade Delivery",
      profileType: .carrier,
      primaryOrganisation: "Jade Delivery",
      website: "https://carrier.example.com",
      supportURL: "https://carrier.example.com/support",
      defaultContactID: contactDirectoryEntries[0].id,
      defaultAccountID: accountCredentialRecords[2].id,
      preferredChannel: .email,
      serviceLevelNotes: "Address exceptions and missed delivery events need same-day manual escalation.",
      riskLevel: .high,
      isEnabled: true,
      createdDate: "Yesterday 4:10 PM",
      lastReviewedDate: "Today 8:30 AM",
      reviewState: .monitor
    ),
    VendorProfile(
      name: "Shopify demo store",
      profileType: .shopifyStore,
      primaryOrganisation: "Shopify demo store",
      website: "https://shopify-demo.example",
      supportURL: "https://shopify-demo.example/support",
      defaultContactID: contactDirectoryEntries[3].id,
      defaultAccountID: accountCredentialRecords[1].id,
      preferredChannel: .supplierPortal,
      serviceLevelNotes: "OAuth and admin access remain placeholders until real Shopify integration exists.",
      riskLevel: .high,
      isEnabled: false,
      createdDate: "Today 9:40 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    ),
    VendorProfile(
      name: "ParcelOps Field Ops",
      profileType: .internalTeam,
      primaryOrganisation: "ParcelOps Field Ops",
      website: "https://parcelops.example/internal",
      supportURL: "https://parcelops.example/internal/support",
      defaultContactID: contactDirectoryEntries[2].id,
      defaultAccountID: nil,
      preferredChannel: .internalNote,
      serviceLevelNotes: "Use for collection, pickup, and field-team escalation tasks.",
      riskLevel: .low,
      isEnabled: true,
      createdDate: "Yesterday 9:15 AM",
      lastReviewedDate: "Today 8:20 AM",
      reviewState: .accepted
    )
  ]

  static var shipmentGroups: [ShipmentGroup] = [
    ShipmentGroup(
      groupName: "Brisbane DHL address exception",
      primaryOrderID: orders[1].id,
      relatedOrderIDs: [orders[1].id],
      relatedIntakeEmailIDs: [],
      relatedTrackingEventIDs: [carrierTrackingEvents[1].id],
      relatedEvidenceIDs: [],
      destinationSummary: "77 Eagle Street, Brisbane QLD",
      recipientCustomerSummary: "Brisbane Field Team",
      carrierSummary: "DHL",
      statusSummary: "Address confirmation required",
      riskLevel: .critical,
      createdDate: "Today 8:07 AM",
      lastReviewedDate: "Today 8:20 AM",
      reviewState: .needsReview
    ),
    ShipmentGroup(
      groupName: "SafetyPro Melbourne shipment",
      primaryOrderID: orders[0].id,
      relatedOrderIDs: [orders[0].id],
      relatedIntakeEmailIDs: [intakeEmails[0].id],
      relatedTrackingEventIDs: [carrierTrackingEvents[0].id],
      relatedEvidenceIDs: [evidenceAttachments[0].id],
      destinationSummary: "18 Collins Street, Melbourne VIC",
      recipientCustomerSummary: "Melbourne Operations",
      carrierSummary: "Australia Post",
      statusSummary: "In transit",
      riskLevel: .low,
      createdDate: "Yesterday 6:12 PM",
      lastReviewedDate: "Today 9:12 AM",
      reviewState: .accepted
    ),
    ShipmentGroup(
      groupName: "Office Kit split-order intake",
      primaryOrderID: nil,
      relatedOrderIDs: [],
      relatedIntakeEmailIDs: [intakeEmails[1].id],
      relatedTrackingEventIDs: [],
      relatedEvidenceIDs: [evidenceAttachments[1].id],
      destinationSummary: "Dock 4, 9 Harbour Road, Sydney NSW",
      recipientCustomerSummary: "Operations",
      carrierSummary: "Pending carrier",
      statusSummary: "Intake email needs order creation",
      riskLevel: .high,
      createdDate: "Today 11:45 AM",
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
  ]

  static var importQueueItems: [ImportQueueItem] = [
    ImportQueueItem(
      sourceType: .pdf,
      sourceLabel: "OfficeKit-OK-58214-order-confirmation.pdf",
      capturedDate: "Today 11:44 AM",
      rawSummary: "PDF confirmation staged from the local evidence placeholder before order creation.",
      detectedMerchant: "Office Kit Store",
      detectedOrderNumber: "OK-58214",
      detectedTrackingNumber: "Pending",
      detectedDestinationAddress: "Dock 4, 9 Harbour Road, Sydney NSW",
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: shipmentGroups[2].id,
      confidenceScore: 68,
      importStatus: .staged,
      reviewState: .needsReview,
      notes: "Tracking number missing; review before accepting into orders."
    ),
    ImportQueueItem(
      sourceType: .forwardedEmail,
      sourceLabel: "SafetyPro shipping email",
      capturedDate: "Yesterday 6:10 PM",
      rawSummary: "Forwarded email already linked to SafetyPro order and shipment group.",
      detectedMerchant: "SafetyPro Supplies",
      detectedOrderNumber: "SP-10492",
      detectedTrackingNumber: "33AUL8841295",
      detectedDestinationAddress: "18 Collins Street, Melbourne VIC",
      suggestedLinkedOrderID: orders[0].id,
      suggestedShipmentGroupID: shipmentGroups[1].id,
      confidenceScore: 94,
      importStatus: .accepted,
      reviewState: .accepted,
      notes: "Kept as sample accepted import history."
    ),
    ImportQueueItem(
      sourceType: .screenshot,
      sourceLabel: "Dock delivery screenshot",
      capturedDate: "Today 10:22 AM",
      rawSummary: "Screenshot captured dock details and manual TNT tracking context.",
      detectedMerchant: "Regional Courier Desk",
      detectedOrderNumber: "MAN-2194",
      detectedTrackingNumber: "TNT55928103",
      detectedDestinationAddress: "Dock 4, 9 Harbour Road, Sydney NSW",
      suggestedLinkedOrderID: orders[3].id,
      suggestedShipmentGroupID: nil,
      confidenceScore: 52,
      importStatus: .blocked,
      reviewState: .monitor,
      notes: "Needs a shipment group decision before acceptance."
    )
  ]

  static var acceptanceRecords: [AcceptanceRecord] = [
    AcceptanceRecord(
      sourceType: .importQueueItem,
      sourceID: importQueueItems[1].id,
      sourceLabel: importQueueItems[1].sourceLabel,
      decidedDate: "Yesterday 6:18 PM",
      confidenceScore: 94,
      linkedOrderID: orders[0].id,
      linkedShipmentGroupID: shipmentGroups[1].id,
      decision: .accepted,
      reviewState: .accepted,
      summary: "SafetyPro forwarded import accepted into the existing tracked order and shipment group.",
      notes: "Preserved as local acceptance history."
    ),
    AcceptanceRecord(
      sourceType: .importQueueItem,
      sourceID: importQueueItems[2].id,
      sourceLabel: importQueueItems[2].sourceLabel,
      decidedDate: "Today 10:28 AM",
      confidenceScore: 52,
      linkedOrderID: orders[3].id,
      linkedShipmentGroupID: nil,
      decision: .blocked,
      reviewState: .monitor,
      summary: "Dock screenshot is blocked until a shipment group decision is made.",
      notes: "Local placeholder only; no OCR or file access."
    ),
    AcceptanceRecord(
      sourceType: .intakeEmail,
      sourceID: intakeEmails[1].id,
      sourceLabel: intakeEmails[1].subject,
      decidedDate: "Today 11:45 AM",
      confidenceScore: 72,
      linkedOrderID: nil,
      linkedShipmentGroupID: shipmentGroups[2].id,
      decision: .ready,
      reviewState: .needsReview,
      summary: "Office Kit forwarded email is ready for acceptance review.",
      notes: "Compare with PDF import before creating the tracked order."
    )
  ]

  static var auditEvents: [AuditEvent] = [
    AuditEvent(
      timestamp: "Today 11:42 AM",
      actor: "Local user",
      action: .created,
      entityType: .intakeEmail,
      entityID: intakeEmails[1].id.uuidString,
      entityLabel: "OK-58214",
      summary: "Forwarded order email captured for review.",
      beforeDetail: nil,
      afterDetail: "Merchant Office Kit Store, order OK-58214, destination Dock 4, 9 Harbour Road, Sydney NSW."
    ),
    AuditEvent(
      timestamp: "Yesterday 6:10 PM",
      actor: "Local user",
      action: .linked,
      entityType: .intakeEmail,
      entityID: intakeEmails[0].id.uuidString,
      entityLabel: "SP-10492",
      summary: "Forwarded shipping email linked to tracked order SP-10492.",
      beforeDetail: "Intake email was not linked.",
      afterDetail: "Linked to SafetyPro Supplies order SP-10492."
    ),
    AuditEvent(
      timestamp: "Today 8:05 AM",
      actor: "Local user",
      action: .cleared,
      entityType: .mailEvent,
      entityID: mailEvents[0].id.uuidString,
      entityLabel: "DHL Support",
      summary: "Carrier address issue routed into the review queue.",
      beforeDetail: "Review state Needs review.",
      afterDetail: "Awaiting user correction before acceptance."
    )
  ]
}
