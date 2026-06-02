import Foundation

enum ParcelSection: String, CaseIterable, Identifiable {
  case dashboard
  case orders
  case mailbox
  case review
  case wishlist
  case integrations
  case automation
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .orders: "Orders"
    case .mailbox: "Mailbox Monitor"
    case .review: "Needs Review"
    case .wishlist: "Wishlist"
    case .integrations: "Integrations"
    case .automation: "Automation Flow"
    case .settings: "Settings"
    }
  }

  var shortTitle: String {
    switch self {
    case .dashboard: "Dashboard"
    case .orders: "Orders"
    case .mailbox: "Mailbox"
    case .review: "Review"
    case .wishlist: "Wishlist"
    case .integrations: "Sources"
    case .automation: "Flow"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "rectangle.grid.2x2.fill"
    case .orders: "shippingbox.fill"
    case .mailbox: "envelope.badge.fill"
    case .review: "checkmark.shield.fill"
    case .wishlist: "star.square.fill"
    case .integrations: "point.3.connected.trianglepath.dotted"
    case .automation: "arrow.triangle.branch"
    case .settings: "gearshape.fill"
    }
  }
}

struct TrackedOrder: Identifiable, Hashable, Codable {
  var id = UUID()
  var orderNumber: String
  var store: String
  var recipientEmail: String
  var checkedMailbox: String
  var customer: String
  var fulfillment: FulfillmentMethod
  var carrier: String
  var trackingNumber: String
  var destination: String
  var eta: String
  var source: IntakeSource
  var status: OrderStatus
  var reviewState: ReviewState
  var latestStatus: String
  var timeline: [TimelineEvent]
  var contactHistory: [ContactHistoryEvent]
}

struct TimelineEvent: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var detail: String
  var time: String
  var symbol: String
}

struct ContactHistoryEvent: Identifiable, Hashable, Codable {
  var id = UUID()
  var time: String
  var source: ContactSource
  var contactPoint: String
  var summary: String
  var evidence: String
  var reviewState: ReviewState
}

struct MailEvent: Identifiable, Hashable, Codable {
  var id = UUID()
  var sender: String
  var summary: String
  var receivedTime: String
  var matchedOrder: String
  var severity: Severity
  var reviewState: ReviewState
}

struct ForwardedEmailIntake: Identifiable, Hashable, Codable {
  var id = UUID()
  var sender: String
  var subject: String
  var receivedDate: String
  var rawBodyPreview: String
  var detectedMerchant: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var detectedDestinationAddress: String
  var linkedOrderID: UUID?
  var reviewState: IntakeEmailReviewState
}

struct SourceConnection: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var kind: ConnectionKind
  var account: String
  var status: String
  var lastSync: String
}

struct TrackedMailbox: Identifiable, Hashable, Codable {
  var id = UUID()
  var address: String
  var provider: MailboxProvider
  var monitoredFolders: String
  var status: String
  var lastChecked: String
  var routingRule: String
}

struct ShopifyConnection: Identifiable, Hashable, Codable {
  var id = UUID()
  var storeName: String
  var storeDomain: String
  var mappedMailbox: String
  var mappedTeam: String
  var status: String
  var lastSync: String
  var isEnabled: Bool
}

struct WatchedFolder: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var location: String
  var platform: String
  var fileTypes: String
  var cadence: String
  var status: String
  var lastScan: String
}

struct WishlistItem: Identifiable, Hashable, Codable {
  var id = UUID()
  var itemName: String
  var storefront: String
  var storefrontURL: String
  var estimatedCost: String
  var owner: String
  var pool: String
  var source: WishlistSource
  var status: String
  var capturedDetail: String
}

enum FulfillmentMethod: String, Hashable, Codable {
  case delivery = "Delivery"
  case clickAndCollect = "Click and collect"

  var symbol: String {
    switch self {
    case .delivery: "truck.box.fill"
    case .clickAndCollect: "bag.fill"
    }
  }
}

enum IntakeSource: String, CaseIterable, Hashable, Codable {
  case forwardedMailbox = "Forwarded mailbox"
  case shopify = "Shopify OAuth"
  case storeLogin = "Store login"
  case watchedFolder = "Watched folder"
  case manual = "Manual"

  var symbol: String {
    switch self {
    case .forwardedMailbox: "envelope.open.fill"
    case .shopify: "cart.fill"
    case .storeLogin: "lock.shield.fill"
    case .watchedFolder: "folder.fill"
    case .manual: "square.and.pencil"
    }
  }
}

enum OrderStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case intake = "Intake"
  case ordered = "Ordered"
  case shipped = "Shipped"
  case inTransit = "In transit"
  case exception = "Exception"
  case delivered = "Delivered"

  var id: String { rawValue }
}

enum ReviewState: String, Hashable, Codable {
  case accepted = "Accepted"
  case needsReview = "Needs review"
  case monitor = "Monitor"
}

enum IntakeEmailReviewState: String, Hashable, Codable {
  case needsReview = "Needs review"
  case reviewed = "Reviewed"
  case ignored = "Ignored"
}

enum Severity: String, Hashable, Codable {
  case info = "Info"
  case watch = "Watch"
  case critical = "Critical"
}

enum ContactSource: String, Hashable, Codable {
  case mailbox = "Mailbox"
  case shopify = "Shopify"
  case watchedFolder = "Watched folder"
  case supplierPortal = "Supplier portal"
  case carrier = "Carrier"
  case manual = "Manual"

  var symbol: String {
    switch self {
    case .mailbox: "envelope.fill"
    case .shopify: "cart.fill"
    case .watchedFolder: "folder.fill"
    case .supplierPortal: "person.crop.circle.badge.checkmark"
    case .carrier: "truck.box.fill"
    case .manual: "square.and.pencil"
    }
  }
}

enum ConnectionKind: String, Hashable, Codable {
  case mailbox = "Forwarded mailbox"
  case shopify = "Shopify"
  case vaultLogin = "Password vault"
  case watchedFolder = "Watched folder"

  var symbol: String {
    switch self {
    case .mailbox: "envelope.fill"
    case .shopify: "cart.badge.plus"
    case .vaultLogin: "key.horizontal.fill"
    case .watchedFolder: "folder.fill.badge.gearshape"
    }
  }
}

enum MailboxProvider: String, Hashable, Codable {
  case microsoft365 = "Microsoft 365"
  case gmail = "Gmail"
  case imap = "IMAP"

  var symbol: String {
    switch self {
    case .microsoft365: "mail.stack.fill"
    case .gmail: "envelope.fill"
    case .imap: "server.rack"
    }
  }
}

enum WishlistSource: String, Hashable, Codable {
  case pdf = "PDF upload"
  case screenshot = "Screenshot"
  case shareSheet = "Share"
  case browserExtension = "Browser extension"
  case manual = "Manual"

  var symbol: String {
    switch self {
    case .pdf: "doc.richtext.fill"
    case .screenshot: "photo.fill"
    case .shareSheet: "square.and.arrow.down.fill"
    case .browserExtension: "puzzlepiece.extension.fill"
    case .manual: "square.and.pencil"
    }
  }
}

struct ParcelOpsSettings: Hashable, Codable {
  var mailboxMonitoringEnabled = true
  var autoCreateOrdersFromEmail = true
  var shopifySyncEnabled = true
  var storeLoginSyncEnabled = true
  var folderWatchingEnabled = true
  var folderScanCadence = "Every 15 minutes"
  var carrierTrackingEnabled = true
  var carrierTrackingMode = "Export to Parcel"
  var requireReviewForRiskyMatches = true
  var notifyOnDeliveryExceptions = true
  var exceptionThreshold = 3
  var matchConfidencePolicy = "Balanced"
}

enum WorkflowTrigger: Hashable {
  case manualSync
  case mailboxEventSeverity(Severity)
  case wishlistConverted
}

enum WorkflowTemplateAction: String, Hashable {
  case ingestMailboxes = "Ingest mailboxes"
  case syncShopify = "Sync Shopify"
  case scanFolders = "Scan watched folders"
  case refreshCarriers = "Refresh carrier handoff"
  case routeToNeedsReview = "Route to Needs Review"
  case appendContactHistory = "Append contact history"
}

struct WorkflowTemplateRule: Hashable {
  var trigger: WorkflowTrigger
  var actions: [WorkflowTemplateAction]
}
