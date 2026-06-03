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
