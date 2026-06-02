import Foundation

enum ParcelSection: String, CaseIterable, Identifiable {
  case dashboard
  case orders
  case mailbox
  case review
  case wishlist
  case integrations
  case automation
  case tracking
  case evidence
  case tasks
  case slaPolicies
  case communication
  case contacts
  case accounts
  case vendorProfiles
  case timeline
  case search
  case audit
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
    case .tracking: "Tracking"
    case .evidence: "Evidence"
    case .tasks: "Tasks"
    case .slaPolicies: "SLA Policies"
    case .communication: "Communication"
    case .contacts: "Contacts"
    case .accounts: "Accounts"
    case .vendorProfiles: "Vendor Profiles"
    case .timeline: "Timeline"
    case .search: "Search"
    case .audit: "Audit"
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
    case .tracking: "Tracking"
    case .evidence: "Evidence"
    case .tasks: "Tasks"
    case .slaPolicies: "SLA"
    case .communication: "Comms"
    case .contacts: "Contacts"
    case .accounts: "Accounts"
    case .vendorProfiles: "Profiles"
    case .timeline: "Timeline"
    case .search: "Search"
    case .audit: "Audit"
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
    case .tracking: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .tasks: "checklist"
    case .slaPolicies: "timer"
    case .communication: "bubble.left.and.text.bubble.right.fill"
    case .contacts: "person.crop.circle.badge.checkmark"
    case .accounts: "key.horizontal.fill"
    case .vendorProfiles: "building.2.crop.circle.fill"
    case .timeline: "clock.badge.exclamationmark.fill"
    case .search: "magnifyingglass"
    case .audit: "list.clipboard.fill"
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

struct AuditEvent: Identifiable, Hashable, Codable {
  var id = UUID()
  var timestamp: String
  var actor: String
  var action: AuditAction
  var entityType: AuditEntityType
  var entityID: String
  var entityLabel: String
  var summary: String
  var beforeDetail: String?
  var afterDetail: String?
}

struct EvidenceAttachment: Identifiable, Hashable, Codable {
  var id = UUID()
  var linkedEntityType: EvidenceLinkedEntityType
  var linkedEntityID: UUID
  var fileName: String
  var fileType: String
  var source: EvidenceSource
  var addedDate: String
  var summary: String
  var reviewState: ReviewState
  var localFilePath: String
}

struct CarrierTrackingEvent: Identifiable, Hashable, Codable {
  var id = UUID()
  var orderID: UUID
  var carrier: String
  var trackingNumber: String
  var eventTime: String
  var location: String
  var status: String
  var detail: String
  var severity: Severity
  var source: TrackingEventSource
  var reviewState: ReviewState
}

struct AutomationRule: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var triggerType: AutomationTriggerType
  var conditionSummary: String
  var actionSummary: String
  var isEnabled: Bool
  var lastRunDate: String
  var reviewState: ReviewState
  var runCount: Int
}

struct SearchResult: Identifiable, Hashable {
  var id: String
  var entityType: SearchEntityType
  var title: String
  var subtitle: String
  var detail: String
  var severity: Severity?
  var reviewState: ReviewState?
  var linkedEntityID: String
}

struct SearchResultGroup: Identifiable, Hashable {
  var entityType: SearchEntityType
  var results: [SearchResult]

  var id: SearchEntityType { entityType }
}

struct TimelineActivity: Identifiable, Hashable {
  var id: String
  var timestampText: String
  var entityType: TimelineEntityType
  var entityID: String
  var title: String
  var subtitle: String
  var detail: String
  var risk: TimelineRiskLevel
  var reviewState: ReviewState?
  var source: TimelineActivitySource
  var suggestedActionText: String
}

struct TimelineActivityGroup: Identifiable, Hashable {
  var title: String
  var activities: [TimelineActivity]

  var id: String { title }
}

struct SavedFilter: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var queryText: String
  var entityTypeFilter: SearchEntityType?
  var reviewStateFilter: ReviewState?
  var createdDate: String
  var isPinned: Bool
}

struct ReviewTask: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var summary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var priority: TaskPriority
  var dueDate: String
  var assignee: String
  var status: TaskStatus
  var createdDate: String
  var completedDate: String?
  var reviewState: ReviewState
}

struct SLAPolicy: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var conditionSummary: String
  var responseTarget: String
  var resolutionTarget: String
  var priority: TaskPriority
  var isEnabled: Bool
  var createdDate: String
  var lastEvaluatedDate: String
  var matchCount: Int
  var reviewState: ReviewState
}

struct CommunicationTemplate: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var subjectTemplate: String
  var bodyTemplate: String
  var channel: CommunicationChannel
  var isEnabled: Bool
  var createdDate: String
  var lastUsedDate: String
  var usageCount: Int
  var reviewState: ReviewState
}

struct DraftMessage: Identifiable, Hashable, Codable {
  var id = UUID()
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var templateID: UUID?
  var recipient: String
  var subject: String
  var body: String
  var channel: CommunicationChannel
  var createdDate: String
  var status: DraftMessageStatus
  var reviewState: ReviewState
}

struct ContactDirectoryEntry: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var organisation: String
  var role: String
  var email: String
  var phone: String
  var channelPreference: CommunicationChannel
  var linkedEntityType: ContactLinkedEntityType
  var linkedEntityID: String
  var notes: String
  var isEnabled: Bool
  var createdDate: String
  var lastContactedDate: String
  var reviewState: ReviewState
}

struct AccountCredentialRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var accountName: String
  var organisation: String
  var linkedContactID: UUID?
  var linkedEntityType: AccountLinkedEntityType
  var linkedEntityID: String
  var loginURL: String
  var usernameLabel: String
  var credentialStorageStatus: CredentialStorageStatus
  var mfaStatus: MFAStatus
  var renewalReviewDate: String
  var isEnabled: Bool
  var notes: String
  var createdDate: String
  var lastCheckedDate: String
  var reviewState: ReviewState
}

struct VendorProfile: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var profileType: VendorProfileType
  var primaryOrganisation: String
  var website: String
  var supportURL: String
  var defaultContactID: UUID?
  var defaultAccountID: UUID?
  var preferredChannel: CommunicationChannel
  var serviceLevelNotes: String
  var riskLevel: VendorRiskLevel
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
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

enum AuditAction: String, CaseIterable, Identifiable, Hashable, Codable {
  case created = "Created"
  case edited = "Edited"
  case enabled = "Enabled"
  case disabled = "Disabled"
  case linked = "Linked"
  case reviewed = "Reviewed"
  case ignored = "Ignored"
  case cleared = "Cleared"
  case pinned = "Pinned"
  case unpinned = "Unpinned"
  case completed = "Completed"
  case reopened = "Reopened"
  case evaluated = "Evaluated"
  case removed = "Removed"

  var id: String { rawValue }
}

enum AuditEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case mailEvent = "Mailbox event"
  case evidence = "Evidence"
  case trackingEvent = "Tracking event"
  case automationRule = "Automation rule"
  case savedFilter = "Saved filter"
  case reviewTask = "Review task"
  case slaPolicy = "SLA policy"
  case communicationTemplate = "Communication template"
  case draftMessage = "Draft message"
  case contactDirectoryEntry = "Contact"
  case accountCredentialRecord = "Account"
  case vendorProfile = "Vendor profile"

  var id: String { rawValue }
}

enum VendorProfileType: String, CaseIterable, Identifiable, Hashable, Codable {
  case store = "Store"
  case supplier = "Supplier"
  case carrier = "Carrier"
  case shopifyStore = "Shopify store"
  case internalTeam = "Internal team"
  case marketplace = "Marketplace"

  var id: String { rawValue }
}

enum VendorRiskLevel: String, CaseIterable, Identifiable, Hashable, Codable {
  case low = "Low"
  case medium = "Medium"
  case high = "High"
  case critical = "Critical"

  var id: String { rawValue }
}

enum TimelineEntityType: String, CaseIterable, Identifiable, Hashable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case reviewTask = "Review task"
  case slaPolicy = "SLA policy"
  case communicationTemplate = "Communication template"
  case draftMessage = "Draft message"
  case contact = "Contact"
  case account = "Account"
  case vendorProfile = "Vendor profile"
  case automationRule = "Automation rule"
  case savedFilter = "Saved filter"
  case auditEvent = "Audit event"

  var id: String { rawValue }
}

enum TimelineRiskLevel: String, CaseIterable, Identifiable, Hashable {
  case normal = "Normal"
  case watch = "Watch"
  case high = "High"
  case critical = "Critical"

  var id: String { rawValue }
}

enum TimelineActivitySource: String, CaseIterable, Identifiable, Hashable {
  case order = "Order"
  case mailbox = "Mailbox"
  case carrier = "Carrier"
  case evidence = "Evidence"
  case task = "Task"
  case sla = "SLA"
  case communication = "Communication"
  case directory = "Directory"
  case account = "Account"
  case vendorProfile = "Vendor profile"
  case automation = "Automation"
  case search = "Search"
  case audit = "Audit"

  var id: String { rawValue }
}

enum AccountLinkedEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case store = "Store"
  case supplier = "Supplier"
  case carrier = "Carrier"
  case shopifyStore = "Shopify store"
  case internalTeam = "Internal team"
  case contact = "Contact"
  case order = "Order"
  case intakeEmail = "Intake email"
  case integration = "Integration"
  case sourceConnection = "Source connection"

  var id: String { rawValue }
}

enum ContactLinkedEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case store = "Store"
  case supplier = "Supplier"
  case carrier = "Carrier"
  case shopifyStore = "Shopify store"
  case internalTeam = "Internal team"
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case reviewTask = "Review task"
  case slaPolicy = "SLA policy"
  case draftMessage = "Draft message"

  var id: String { rawValue }
}

enum ReviewTaskLinkedEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case automationRule = "Automation rule"
  case savedFilter = "Saved filter"
  case auditEvent = "Audit event"
  case reviewTask = "Review task"
  case slaPolicy = "SLA policy"
  case draftMessage = "Draft message"
  case contact = "Contact"
  case account = "Account"
  case vendorProfile = "Vendor profile"

  var id: String { rawValue }
}

enum TaskPriority: String, CaseIterable, Identifiable, Hashable, Codable {
  case low = "Low"
  case normal = "Normal"
  case high = "High"
  case urgent = "Urgent"

  var id: String { rawValue }
}

enum TaskStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case open = "Open"
  case inProgress = "In progress"
  case blocked = "Blocked"
  case completed = "Completed"

  var id: String { rawValue }
}

enum CommunicationChannel: String, CaseIterable, Identifiable, Hashable, Codable {
  case email = "Email"
  case phoneScript = "Phone script"
  case internalNote = "Internal note"
  case supplierPortal = "Supplier portal"

  var id: String { rawValue }
}

enum DraftMessageStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case ready = "Ready"
  case sentLocally = "Sent locally"
  case reopened = "Reopened"

  var id: String { rawValue }
}

enum CredentialStorageStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notStored = "Not stored"
  case externalVaultReference = "External vault reference"
  case needsSetup = "Needs setup"
  case accessPending = "Access pending"
  case rotatedExternally = "Rotated externally"

  var id: String { rawValue }
}

enum MFAStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notConfigured = "Not configured"
  case enabled = "Enabled"
  case needsReview = "Needs review"
  case sharedDevice = "Shared device"
  case unknown = "Unknown"

  var id: String { rawValue }
}

enum SearchEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case auditEvent = "Audit event"
  case automationRule = "Automation rule"

  var id: String { rawValue }
}

enum AutomationTriggerType: String, CaseIterable, Identifiable, Hashable, Codable {
  case forwardedEmailCaptured = "Forwarded email captured"
  case orderNeedsReview = "Order needs review"
  case trackingWarning = "Tracking warning"
  case evidenceAdded = "Evidence added"
  case manualReview = "Manual review"

  var id: String { rawValue }
}

enum EvidenceLinkedEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case order = "Order"
  case intakeEmail = "Intake email"

  var id: String { rawValue }
}

enum EvidenceSource: String, CaseIterable, Identifiable, Hashable, Codable {
  case forwardedEmail = "Forwarded email"
  case manualUpload = "Manual upload"
  case watchedFolder = "Watched folder"
  case screenshot = "Screenshot"
  case supplierPortal = "Supplier portal"

  var id: String { rawValue }
}

enum TrackingEventSource: String, CaseIterable, Identifiable, Hashable, Codable {
  case manual = "Manual"
  case forwardedEmail = "Forwarded email"
  case carrierMock = "Carrier mock"
  case shopifyMock = "Shopify mock"

  var id: String { rawValue }
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
