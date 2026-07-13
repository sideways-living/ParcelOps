import Foundation

enum ParcelSection: String, CaseIterable, Identifiable {
  case dashboard
  case inbox
  case orders
  case workbench
  case dispatch
  case mvpSetup
  case mailbox
  case review
  case wishlist
  case integrations
  case automation
  case tracking
  case evidence
  case tasks
  case handoffNotes
  case slaPolicies
  case exceptionPlaybooks
  case communication
  case contacts
  case customerProfiles
  case destinationAddresses
  case deliveryInstructions
  case packageContents
  case costsBudgets
  case returnsClaims
  case procurement
  case receivingInspections
  case inventoryReceipts
  case storageLocations
  case custodyChain
  case labelReferences
  case scanSessions
  case shipmentManifests
  case dispatchReadiness
  case accounts
  case vendorProfiles
  case shipmentGroups
  case importQueue
  case acceptanceReview
  case reconciliation
  case timeline
  case validation
  case search
  case audit
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .inbox: "Inbox"
    case .orders: "Orders"
    case .workbench: "Operations Workbench"
    case .dispatch: "Dispatch"
    case .mvpSetup: "MVP Setup"
    case .mailbox: "Mailbox Monitor"
    case .review: "Needs Review"
    case .wishlist: "Wishlist"
    case .integrations: "Integrations"
    case .automation: "Automation Flow"
    case .tracking: "Tracking"
    case .evidence: "Evidence"
    case .tasks: "Tasks"
    case .handoffNotes: "Handoff Notes"
    case .slaPolicies: "SLA Policies"
    case .exceptionPlaybooks: "Exception Playbooks"
    case .communication: "Drafts & Templates"
    case .contacts: "Contacts"
    case .customerProfiles: "Customer Profiles"
    case .destinationAddresses: "Destination Addresses"
    case .deliveryInstructions: "Delivery Instructions"
    case .packageContents: "Package Contents"
    case .costsBudgets: "Costs & Budgets"
    case .returnsClaims: "Returns & Claims"
    case .procurement: "Procurement"
    case .receivingInspections: "Receiving Inspections"
    case .inventoryReceipts: "Inventory Receipts"
    case .storageLocations: "Storage Locations"
    case .custodyChain: "Custody Chain"
    case .labelReferences: "Label References"
    case .scanSessions: "Scan Sessions"
    case .shipmentManifests: "Shipment Manifests"
    case .dispatchReadiness: "Dispatch Readiness"
    case .accounts: "Accounts"
    case .vendorProfiles: "Vendor Profiles"
    case .shipmentGroups: "Shipment Groups"
    case .importQueue: "Import Queue"
    case .acceptanceReview: "Acceptance Review"
    case .reconciliation: "Reconciliation"
    case .timeline: "Timeline"
    case .validation: "Validation"
    case .search: "Search"
    case .audit: "Audit"
    case .settings: "Settings"
    }
  }

  var shortTitle: String {
    switch self {
    case .dashboard: "Home"
    case .inbox: "Inbox"
    case .orders: "Orders"
    case .workbench: "Workbench"
    case .dispatch: "Dispatch"
    case .mvpSetup: "Setup"
    case .mailbox: "Mailbox"
    case .review: "Review"
    case .wishlist: "Wishlist"
    case .integrations: "Sources"
    case .automation: "Flow"
    case .tracking: "Tracking"
    case .evidence: "Evidence"
    case .tasks: "Tasks"
    case .handoffNotes: "Handoff"
    case .slaPolicies: "SLA"
    case .exceptionPlaybooks: "Playbooks"
    case .communication: "Drafts"
    case .contacts: "Contacts"
    case .customerProfiles: "Customers"
    case .destinationAddresses: "Addresses"
    case .deliveryInstructions: "Instructions"
    case .packageContents: "Contents"
    case .costsBudgets: "Costs"
    case .returnsClaims: "Claims"
    case .procurement: "Procure"
    case .receivingInspections: "Inspect"
    case .inventoryReceipts: "Stock"
    case .storageLocations: "Storage"
    case .custodyChain: "Custody"
    case .labelReferences: "Labels"
    case .scanSessions: "Scans"
    case .shipmentManifests: "Manifests"
    case .dispatchReadiness: "Ready"
    case .accounts: "Accounts"
    case .vendorProfiles: "Profiles"
    case .shipmentGroups: "Groups"
    case .importQueue: "Import"
    case .acceptanceReview: "Accept"
    case .reconciliation: "Recon"
    case .timeline: "Timeline"
    case .validation: "Validate"
    case .search: "Search"
    case .audit: "Audit"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "rectangle.grid.2x2.fill"
    case .inbox: "tray.full.fill"
    case .orders: "shippingbox.fill"
    case .workbench: "rectangle.stack.badge.person.crop.fill"
    case .dispatch: "paperplane.fill"
    case .mvpSetup: "checklist"
    case .mailbox: "envelope.badge.fill"
    case .review: "checkmark.shield.fill"
    case .wishlist: "star.square.fill"
    case .integrations: "point.3.connected.trianglepath.dotted"
    case .automation: "arrow.triangle.branch"
    case .tracking: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .tasks: "checklist"
    case .handoffNotes: "arrow.left.arrow.right.square.fill"
    case .slaPolicies: "timer"
    case .exceptionPlaybooks: "book.closed.fill"
    case .communication: "bubble.left.and.text.bubble.right.fill"
    case .contacts: "person.crop.circle.badge.checkmark"
    case .customerProfiles: "person.text.rectangle.fill"
    case .destinationAddresses: "mappin.and.ellipse"
    case .deliveryInstructions: "signpost.right.and.left.fill"
    case .packageContents: "shippingbox.circle.fill"
    case .costsBudgets: "creditcard.and.123"
    case .returnsClaims: "arrow.uturn.backward.square.fill"
    case .procurement: "cart.badge.plus"
    case .receivingInspections: "checklist.checked"
    case .inventoryReceipts: "archivebox.fill"
    case .storageLocations: "cabinet.fill"
    case .custodyChain: "person.badge.shield.checkmark.fill"
    case .labelReferences: "barcode.viewfinder"
    case .scanSessions: "qrcode.viewfinder"
    case .shipmentManifests: "list.bullet.clipboard.fill"
    case .dispatchReadiness: "checkmark.rectangle.stack.fill"
    case .accounts: "key.horizontal.fill"
    case .vendorProfiles: "building.2.crop.circle.fill"
    case .shipmentGroups: "shippingbox.and.arrow.backward.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptanceReview: "checkmark.rectangle.stack.fill"
    case .reconciliation: "arrow.triangle.2.circlepath.circle.fill"
    case .timeline: "clock.badge.exclamationmark.fill"
    case .validation: "checkmark.seal.fill"
    case .search: "magnifyingglass"
    case .audit: "list.clipboard.fill"
    case .settings: "gearshape.fill"
    }
  }

  var searchKeywords: [String] {
    switch self {
    case .dashboard:
      ["home", "start", "daily", "status", "summary", "mvp", "support", "handoff", "qa"]
    case .inbox:
      ["mail", "email", "spacemail", "triage", "intake", "parser", "order email", "uncertain", "filtered"]
    case .orders:
      ["order", "tracking", "recipient", "customer", "source trail", "inbox-created", "handoff"]
    case .workbench:
      ["exception", "blocked", "validation", "reconciliation", "high priority", "follow up", "problem"]
    case .dispatch:
      ["manifest", "readiness", "ready", "outbound", "handoff", "courier", "ship", "reopened"]
    case .mvpSetup:
      ["mvp", "setup", "qa", "release", "runbook", "troubleshooting", "testing", "support"]
    case .mailbox:
      ["mail", "email", "spacemail", "imap", "microsoft", "graph", "oauth", "classifier", "parser", "uncertain", "filtered", "refresh"]
    case .review:
      ["needs review", "review queue", "attention", "blocked", "parser", "mailbox", "evidence"]
    case .wishlist:
      ["wishlist", "wanted", "purchase idea", "future order"]
    case .integrations:
      ["settings", "sources", "spacemail", "imap", "microsoft", "graph", "oauth", "shopify", "credential", "keychain", "folder"]
    case .automation:
      ["automation", "flow", "rules", "planned automation", "local rule"]
    case .tracking:
      ["carrier", "tracking", "event", "warning", "delivery", "in transit", "shipment"]
    case .evidence:
      ["attachment", "proof", "document", "file reference", "photo", "record"]
    case .tasks:
      ["task", "handoff", "follow-up", "draft", "assignee", "due", "action queue"]
    case .handoffNotes:
      ["handoff", "shift", "team note", "acknowledge", "complete", "reopen"]
    case .slaPolicies:
      ["sla", "policy", "timing", "service level", "deadline", "threshold"]
    case .exceptionPlaybooks:
      ["exception", "playbook", "procedure", "instructions", "blocked", "missing tracking"]
    case .communication:
      ["draft", "template", "message", "email", "communication", "outbound placeholder"]
    case .contacts:
      ["contact", "person", "team", "supplier", "carrier", "email"]
    case .customerProfiles:
      ["customer", "recipient", "profile", "team", "organisation", "delivery preference"]
    case .destinationAddresses:
      ["address", "destination", "recipient", "delivery location", "city", "region"]
    case .deliveryInstructions:
      ["instruction", "access", "delivery window", "constraint", "carrier note"]
    case .packageContents:
      ["package", "contents", "items", "quantity", "verification", "discrepancy"]
    case .costsBudgets:
      ["cost", "budget", "reimbursement", "expense", "approval", "gst", "tax"]
    case .returnsClaims:
      ["return", "claim", "refund", "exchange", "damage", "missing item", "carrier claim"]
    case .procurement:
      ["procurement", "purchase", "buyer", "approval", "vendor", "requested items"]
    case .receivingInspections:
      ["receiving", "inspection", "condition", "quantity", "discrepancy", "received"]
    case .inventoryReceipts:
      ["inventory", "receipt", "stock", "storage", "handoff", "accepted", "rejected"]
    case .storageLocations:
      ["storage", "location", "bin", "shelf", "cage", "locker", "capacity"]
    case .custodyChain:
      ["custody", "possession", "transfer", "returned", "location", "handoff"]
    case .labelReferences:
      ["label", "barcode", "qr", "tracking label", "shelf label", "scan"]
    case .scanSessions:
      ["scan", "session", "barcode", "qr", "verify", "mismatch", "label"]
    case .shipmentManifests:
      ["manifest", "batch", "dispatch", "courier", "handoff", "outbound"]
    case .dispatchReadiness:
      ["dispatch", "readiness", "checklist", "ready", "blocked", "handoff"]
    case .accounts:
      ["account", "credential", "login", "password", "secret placeholder", "keychain"]
    case .vendorProfiles:
      ["vendor", "supplier", "carrier", "store", "profile", "account manager"]
    case .shipmentGroups:
      ["shipment", "group", "parcel", "order group", "tracking", "risk"]
    case .importQueue:
      ["import", "queue", "staged", "csv", "mailbox import", "blocked import"]
    case .acceptanceReview:
      ["acceptance", "accept", "candidate", "review", "ready", "ignore", "reopen"]
    case .reconciliation:
      ["reconciliation", "mismatch", "duplicate", "compare", "conflict", "reconcile"]
    case .timeline:
      ["timeline", "activity", "history", "watchlist", "event"]
    case .validation:
      ["validation", "validate", "issue", "missing link", "field", "quality"]
    case .search:
      ["search", "find", "global", "lookup", "query"]
    case .audit:
      ["audit", "activity", "history", "log", "diagnostic", "trace", "event"]
    case .settings:
      ["settings", "local only", "privacy", "setup", "credential", "source", "configuration"]
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

extension TrackedOrder {
  var isInboxCreatedLocalOrder: Bool {
    source == .forwardedMailbox
      || checkedMailbox == "manual-import"
      || latestStatus.localizedCaseInsensitiveContains("import queue")
      || latestStatus.localizedCaseInsensitiveContains("acceptance")
      || latestStatus.localizedCaseInsensitiveContains("forwarded email")
  }

  var missingInboxOrderFieldCount: Int {
    [orderNumber, trackingNumber, destination]
      .filter { value in
        value == "Pending" || value == "Pending review" || value.isPlaceholderValidationValue
      }
      .count
  }
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

struct FetchedMailboxMessage: Identifiable, Hashable {
  var id: String { providerMessageID }
  var providerMessageID: String
  var sender: String
  var subject: String
  var receivedDate: String
  var plainTextBodyPreview: String
  var sourceMailboxID: UUID
}

struct SpaceMailUncertainMessage: Identifiable, Hashable, Codable {
  var id = UUID()
  var providerMessageID: String
  var sourceMailboxID: UUID
  var sender: String
  var subject: String
  var receivedDate: String
  var bodyPreview: String
  var reason: String
  var capturedDate: String
}

struct SpaceMailFilteredMessage: Identifiable, Hashable, Codable {
  var id = UUID()
  var providerMessageID: String
  var sourceMailboxID: UUID
  var sender: String
  var subject: String
  var receivedDate: String
  var bodyPreview: String
  var reason: String
  var capturedDate: String
}

struct GmailReviewMessage: Identifiable, Hashable, Codable {
  var id = UUID()
  var providerMessageID: String
  var sourceMailboxID: UUID
  var sender: String
  var subject: String
  var receivedDate: String
  var bodyPreview: String
  var reason: String
  var capturedDate: String
}

struct GmailClassifierTestResult: Identifiable, Hashable, Codable {
  var id = UUID()
  var sampleName: String
  var decision: String
  var reason: String
  var score: Int
  var subjectPreview: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var expectedDecision: String
  var decisionStatus: String
}

struct SpaceMailClassifierReasonCount: Identifiable, Hashable, Codable {
  var id = UUID()
  var decision: String
  var reason: String
  var count: Int
}

struct SpaceMailClassifierImpactPreview: Identifiable, Hashable {
  var id: String { preset.rawValue }
  var preset: SpaceMailFilterPreset
  var sampleCount: Int
  var importedCount: Int
  var uncertainCount: Int
  var filteredCount: Int
  var changedCount: Int
  var riskLabel: String
  var detail: String
  var examples: [String]
}

struct SpaceMailClassifierTestResult: Identifiable, Hashable, Codable {
  var id = UUID()
  var sampleName: String
  var decision: String
  var reason: String
  var score: Int
  var subjectPreview: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var detectedMerchant: String
  var detectedDestination: String

  var expectedDecision: String
  var decisionStatus: String
  var expectedOrderNumber: String
  var expectedTrackingNumber: String
  var parserStatus: String
  var positiveEvidenceLabels: [String]
  var cautionLabels: [String]
  var nextActionText: String

  init(
    id: UUID = UUID(),
    sampleName: String,
    decision: String,
    reason: String,
    score: Int,
    subjectPreview: String,
    detectedOrderNumber: String,
    detectedTrackingNumber: String,
    detectedMerchant: String,
    detectedDestination: String,
    expectedDecision: String = "No expected decision",
    decisionStatus: String = "No classifier expectation",
    expectedOrderNumber: String = "No expected order",
    expectedTrackingNumber: String = "No expected tracking",
    parserStatus: String = "No parser expectation",
    positiveEvidenceLabels: [String] = [],
    cautionLabels: [String] = [],
    nextActionText: String = "Review the classifier result before changing hints."
  ) {
    self.id = id
    self.sampleName = sampleName
    self.decision = decision
    self.reason = reason
    self.score = score
    self.subjectPreview = subjectPreview
    self.detectedOrderNumber = detectedOrderNumber
    self.detectedTrackingNumber = detectedTrackingNumber
    self.detectedMerchant = detectedMerchant
    self.detectedDestination = detectedDestination
    self.expectedDecision = expectedDecision
    self.decisionStatus = decisionStatus
    self.expectedOrderNumber = expectedOrderNumber
    self.expectedTrackingNumber = expectedTrackingNumber
    self.parserStatus = parserStatus
    self.positiveEvidenceLabels = positiveEvidenceLabels
    self.cautionLabels = cautionLabels
    self.nextActionText = nextActionText
  }

  enum CodingKeys: String, CodingKey {
    case id
    case sampleName
    case decision
    case reason
    case score
    case subjectPreview
    case detectedOrderNumber
    case detectedTrackingNumber
    case detectedMerchant
    case detectedDestination
    case expectedDecision
    case decisionStatus
    case expectedOrderNumber
    case expectedTrackingNumber
    case parserStatus
    case positiveEvidenceLabels
    case cautionLabels
    case nextActionText
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    sampleName = try container.decode(String.self, forKey: .sampleName)
    decision = try container.decode(String.self, forKey: .decision)
    reason = try container.decode(String.self, forKey: .reason)
    score = try container.decode(Int.self, forKey: .score)
    subjectPreview = try container.decode(String.self, forKey: .subjectPreview)
    detectedOrderNumber = try container.decode(String.self, forKey: .detectedOrderNumber)
    detectedTrackingNumber = try container.decode(String.self, forKey: .detectedTrackingNumber)
    detectedMerchant = try container.decode(String.self, forKey: .detectedMerchant)
    detectedDestination = try container.decode(String.self, forKey: .detectedDestination)
    expectedDecision = try container.decodeIfPresent(String.self, forKey: .expectedDecision) ?? "No expected decision"
    decisionStatus = try container.decodeIfPresent(String.self, forKey: .decisionStatus) ?? "No classifier expectation"
    expectedOrderNumber = try container.decodeIfPresent(String.self, forKey: .expectedOrderNumber) ?? "No expected order"
    expectedTrackingNumber = try container.decodeIfPresent(String.self, forKey: .expectedTrackingNumber) ?? "No expected tracking"
    parserStatus = try container.decodeIfPresent(String.self, forKey: .parserStatus) ?? "No parser expectation"
    positiveEvidenceLabels = try container.decodeIfPresent([String].self, forKey: .positiveEvidenceLabels) ?? []
    cautionLabels = try container.decodeIfPresent([String].self, forKey: .cautionLabels) ?? []
    nextActionText = try container.decodeIfPresent(String.self, forKey: .nextActionText) ?? "Review the classifier result before changing hints."
  }
}

struct IntakeParserDiagnostic: Identifiable, Hashable {
  var id: String
  var intakeEmailID: UUID
  var title: String
  var summary: String
  var severity: ValidationSeverity
  var capturedDate: String
  var subjectPreview: String
  var senderPreview: String
  var detectedMerchant: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var detectedDestination: String
  var recommendedAction: String
  var issueLabels: [String]
  var parserHintLabels: [String]
  var nextStepLabels: [String]
}

struct SpaceMailIMAPFetchResult: Hashable {
  var status: SpaceMailIMAPFetchStatus
  var messages: [FetchedMailboxMessage]
  var detail: String
}

enum SpaceMailIMAPFetchStatus: String, CaseIterable, Identifiable, Hashable {
  case success = "Fetch success"
  case noMessages = "No messages"
  case duplicateSkipped = "Duplicate skipped"
  case notConfigured = "Not configured"
  case credentialAvailable = "Credential available"
  case credentialMissing = "Credential missing"
  case connectionFailed = "Connection failed"
  case authFailed = "Auth failed"
  case folderNotFound = "Folder not found"
  case parseFailed = "Parse failed"
  case connectionFailedSimulated = "Connection failed simulated"
  case folderNotFoundSimulated = "Folder not found simulated"
  case parseFailedSimulated = "Parse failed simulated"

  var id: String { rawValue }
}

struct SpaceMailCredentialStoreResult: Hashable {
  var status: SpaceMailCredentialStoreStatus
  var detailText: String
}

struct SpaceMailCredentialLoadResult {
  var status: SpaceMailCredentialStoreStatus
  var password: String?
  var detailText: String
}

enum SpaceMailCredentialStoreStatus: String, CaseIterable, Identifiable, Hashable {
  case keychainNotConfigured = "Keychain not configured"
  case passwordReferenceAvailable = "Password reference available"
  case passwordMissing = "Password missing"
  case passwordCleared = "Password cleared"
  case passwordClearSimulated = "Password clear simulated"
  case storageErrorSimulated = "Storage error simulated"

  var id: String { rawValue }
}

struct MicrosoftGraphFetchedMessage: Identifiable, Hashable {
  var id: String { graphMessageID }
  var graphMessageID: String
  var sender: String
  var subject: String
  var receivedDate: String
  var plainTextBodyPreview: String
}

struct MicrosoftGraphMailboxFetchResult: Hashable {
  var status: MicrosoftGraphMailboxFetchStatus
  var messages: [MicrosoftGraphFetchedMessage]
  var detail: String
}

enum MicrosoftGraphMailboxFetchStatus: String, CaseIterable, Identifiable, Hashable {
  case success = "Fetch success"
  case duplicateSkipped = "Duplicate skipped"
  case noMessages = "No messages"
  case notConnected = "Not connected"
  case simulatedAuthPlaceholder = "Simulated auth placeholder"
  case authRequired = "Auth required"
  case consentRequired = "Consent required"
  case folderNotFound = "Folder not found"
  case networkFailed = "Network failed"
  case graphRejected = "Graph rejected"
  case parseFailed = "Parse failed"

  var id: String { rawValue }
}

struct GmailMailboxFetchResult: Hashable {
  var status: GmailMailboxFetchStatus
  var messages: [FetchedMailboxMessage]
  var detail: String
}

enum GmailMailboxFetchStatus: String, CaseIterable, Identifiable, Hashable {
  case success = "Fetch success"
  case noMessages = "No messages"
  case notConfigured = "Not configured"
  case ready = "Ready for real refresh"
  case oauthPlaceholder = "OAuth placeholder"
  case tokenMissing = "Token missing"
  case authRequired = "Auth required"
  case consentRequired = "Consent required"
  case labelNotFound = "Label not found"
  case networkFailed = "Network failed"
  case apiRejected = "Gmail API rejected"
  case parseFailed = "Parse failed"
  case labelNotFoundSimulated = "Label not found simulated"
  case parseFailedSimulated = "Parse failed simulated"

  var id: String { rawValue }
}

struct Microsoft365GraphTokenResult {
  var status: Microsoft365GraphTokenStatus
  var accessToken: String?
  var signedInAccount: String
  var detailText: String
  var tokenDiagnosticsDetail = "Token metadata: unavailable. No token value is stored or logged."
}

enum Microsoft365GraphTokenStatus: String, CaseIterable, Identifiable, Hashable {
  case success = "Token acquired"
  case authRequired = "Auth required"
  case consentRequired = "Consent required"
  case failed = "Token failed"

  var id: String { rawValue }
}

struct MailboxIngestRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var providerMessageID: String
  var sourceMailboxID: UUID
  var intakeEmailID: UUID?
  var capturedDate: String
  var status: MailboxIngestStatus
  var summary: String
}

enum MailboxIngestStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case imported = "Imported"
  case duplicateSkipped = "Duplicate skipped"
  case duplicateRefreshed = "Duplicate refreshed"
  case duplicateNoChange = "Duplicate no change"

  var id: String { rawValue }
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

struct ValidationIssue: Identifiable, Hashable {
  var id: String
  var entityType: ValidationEntityType
  var entityID: String
  var title: String
  var subtitle: String
  var detail: String
  var confidenceScore: Int
  var severity: ValidationSeverity
  var status: ValidationStatus
  var reviewState: ReviewState?
  var linkedEntityType: ReviewTaskLinkedEntityType?
  var suggestedActionText: String
}

struct ValidationIssueGroup: Identifiable, Hashable {
  var severity: ValidationSeverity
  var issues: [ValidationIssue]

  var id: ValidationSeverity { severity }
}

struct WorkbenchItem: Identifiable, Hashable {
  var id: String
  var title: String
  var summary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var prioritySeverity: String
  var status: String
  var assignee: String
  var dueDateText: String
  var reviewState: ReviewState?
  var source: WorkbenchSource
  var suggestedNextAction: String
}

struct WorkbenchItemGroup: Identifiable, Hashable {
  var title: String
  var symbol: String
  var items: [WorkbenchItem]

  var id: String { title }
}

struct ReconciliationIssue: Identifiable, Hashable {
  var id: String
  var issueType: ReconciliationIssueType
  var severity: ValidationSeverity
  var sourceEntityType: ReconciliationEntityType
  var sourceEntityID: String
  var targetEntityType: ReconciliationEntityType?
  var targetEntityID: String?
  var title: String
  var summary: String
  var detectedValue: String
  var currentOperationalValue: String
  var suggestedResolution: String
  var reviewState: ReviewState
  var createdDate: String
}

struct ReconciliationIssueGroup: Identifiable, Hashable {
  var issueType: ReconciliationIssueType
  var issues: [ReconciliationIssue]

  var id: ReconciliationIssueType { issueType }
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

extension ReviewTask {
  var isPartialInboxOrderFollowUp: Bool {
    linkedEntityType == .order
      && title.localizedCaseInsensitiveContains("Verify Inbox-created order")
      && summary.localizedCaseInsensitiveContains("Confirm missing")
  }

  var isReopenedInboxDispatchHandoff: Bool {
    linkedEntityType == .order
      && summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
  }

  var partialInboxMissingSummary: String {
    let marker = "Confirm missing "
    guard let markerRange = summary.range(of: marker, options: .caseInsensitive) else {
      return "order intake fields"
    }

    let remainder = summary[markerRange.upperBound...]
    if let endRange = remainder.range(of: " from forwarded email", options: .caseInsensitive) {
      let value = String(remainder[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
      return value.isEmpty ? "order intake fields" : value
    }

    let value = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "order intake fields" : value
  }
}

struct HandoffNote: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var summary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var priority: TaskPriority
  var assignee: String
  var createdDate: String
  var dueDate: String
  var status: TaskStatus
  var reviewState: ReviewState
  var notes: String
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

struct ExceptionPlaybook: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var issueType: ReconciliationIssueType
  var linkedEntityType: ReviewTaskLinkedEntityType
  var triggerSummary: String
  var recommendedSteps: String
  var escalationContact: String
  var priority: TaskPriority
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var usageCount: Int
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

struct CustomerRecipientProfile: Identifiable, Hashable, Codable {
  var id = UUID()
  var displayName: String
  var profileType: CustomerProfileType
  var organisationTeam: String
  var primaryEmail: String
  var phone: String
  var defaultDestinationAddress: String
  var deliveryPreference: DeliveryPreference
  var notes: String
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct DestinationAddressRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var label: String
  var customerProfileID: UUID?
  var organisationTeam: String
  var addressLineSummary: String
  var cityRegion: String
  var country: String
  var deliveryInstructions: String
  var accessNotes: String
  var preferredCarrier: String
  var riskLevel: ShipmentRiskLevel
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct DeliveryInstructionRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var destinationAddressID: UUID?
  var customerProfileID: UUID?
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var instructionType: DeliveryInstructionType
  var instructionSummary: String
  var accessConstraintSummary: String
  var preferredDeliveryWindow: String
  var restrictedDeliveryWindow: String
  var carrierNotes: String
  var riskLevel: ShipmentRiskLevel
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct PackageContentRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var destinationAddressID: UUID?
  var deliveryInstructionID: UUID?
  var customerProfileID: UUID?
  var itemSummary: String
  var expectedQuantity: Int
  var verifiedQuantity: Int
  var itemCategory: PackageItemCategory
  var valueBand: PackageValueBand
  var verificationStatus: PackageVerificationStatus
  var discrepancySummary: String
  var evidenceAttachmentIDs: [UUID]
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct CostRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var customerProfileID: UUID?
  var vendorProfileID: UUID?
  var accountID: UUID?
  var costCategory: CostCategory
  var amountText: String
  var currency: String
  var taxGSTText: String
  var reimbursementStatus: ReimbursementStatus
  var approvalStatus: CostApprovalStatus
  var budgetCode: String
  var costOwnerTeam: String
  var evidenceAttachmentIDs: [UUID]
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct ReturnClaimRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var costRecordID: UUID?
  var customerProfileID: UUID?
  var vendorProfileID: UUID?
  var accountID: UUID?
  var claimType: ReturnClaimType
  var reasonSummary: String
  var requestedOutcome: ReturnClaimOutcome
  var claimStatus: ReturnClaimStatus
  var refundReplacementAmountText: String
  var currency: String
  var evidenceAttachmentIDs: [UUID]
  var carrierTrackingEventIDs: [UUID]
  var assignedOwnerTeam: String
  var dueDate: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct ProcurementRequest: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var requesterTeam: String
  var requestedDate: String
  var neededByDate: String
  var vendorProfileID: UUID?
  var accountID: UUID?
  var customerProfileID: UUID?
  var destinationAddressID: UUID?
  var packageContentID: UUID?
  var costRecordID: UUID?
  var returnClaimID: UUID?
  var requestedItemsSummary: String
  var estimatedCostText: String
  var currency: String
  var budgetCode: String
  var approvalStatus: ProcurementApprovalStatus
  var procurementStatus: ProcurementStatus
  var assignedBuyerTeam: String
  var evidenceAttachmentIDs: [UUID]
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct ReceivingInspectionRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var procurementRequestID: UUID?
  var returnClaimID: UUID?
  var destinationAddressID: UUID?
  var customerProfileID: UUID?
  var carrierTrackingEventIDs: [UUID]
  var evidenceAttachmentIDs: [UUID]
  var inspectionType: ReceivingInspectionType
  var inspectionStatus: ReceivingInspectionStatus
  var expectedItemSummary: String
  var receivedItemSummary: String
  var quantityExpected: Int
  var quantityReceived: Int
  var conditionSummary: String
  var discrepancyType: ReceivingDiscrepancyType
  var discrepancySummary: String
  var assignedInspectorTeam: String
  var inspectionDate: String
  var dueDate: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct InventoryReceiptRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var receivingInspectionID: UUID?
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var procurementRequestID: UUID?
  var returnClaimID: UUID?
  var destinationAddressID: UUID?
  var customerProfileID: UUID?
  var evidenceAttachmentIDs: [UUID]
  var receiptType: InventoryReceiptType
  var stockHandoffStatus: InventoryStockHandoffStatus
  var itemSummary: String
  var quantityReceived: Int
  var quantityAccepted: Int
  var quantityRejected: Int
  var storageLocationSummary: String
  var assignedOwnerTeam: String
  var receivedDate: String
  var handoffDate: String
  var discrepancySummary: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct StorageLocationRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var locationType: StorageLocationType
  var locationCode: String
  var areaZone: String
  var capacitySummary: String
  var currentUsageSummary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var inventoryReceiptIDs: [UUID]
  var receivingInspectionIDs: [UUID]
  var packageContentIDs: [UUID]
  var orderIDs: [UUID]
  var shipmentGroupIDs: [UUID]
  var assignedOwnerTeam: String
  var accessNotes: String
  var riskLevel: ShipmentRiskLevel
  var isEnabled: Bool
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct CustodyRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var currentCustodianTeam: String
  var previousCustodianTeam: String
  var custodyStatus: CustodyStatus
  var custodyReason: String
  var handoffMethod: CustodyHandoffMethod
  var sourceLocationID: UUID?
  var destinationLocationID: UUID?
  var inventoryReceiptID: UUID?
  var storageLocationID: UUID?
  var receivingInspectionID: UUID?
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var evidenceAttachmentIDs: [UUID]
  var assignedOwnerTeam: String
  var transferDate: String
  var expectedReturnCloseDate: String
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct LabelReferenceRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var labelType: LabelReferenceType
  var labelValuePlaceholder: String
  var labelSource: LabelReferenceSource
  var labelStatus: LabelReferenceStatus
  var associatedCarrier: String
  var storageLocationID: UUID?
  var inventoryReceiptID: UUID?
  var custodyRecordID: UUID?
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var evidenceAttachmentIDs: [UUID]
  var assignedOwnerTeam: String
  var createdDate: String
  var lastReviewedDate: String
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var reviewState: ReviewState
}

struct ScanSessionRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var scanPurpose: ScanPurpose
  var scanMethodPlaceholder: ScanMethodPlaceholder
  var expectedLabelReferenceValue: String
  var capturedValuePlaceholder: String
  var linkedLabelReferenceID: UUID?
  var scanStatus: ScanSessionStatus
  var mismatchSummary: String
  var assignedOperatorTeam: String
  var scanLocationStorageLocationID: UUID?
  var custodyRecordID: UUID?
  var inventoryReceiptID: UUID?
  var orderID: UUID?
  var shipmentGroupID: UUID?
  var packageContentID: UUID?
  var evidenceAttachmentIDs: [UUID]
  var createdDate: String
  var completedDate: String
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var reviewState: ReviewState
}

struct ShipmentManifestRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var manifestType: ShipmentManifestType
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var carrierCourier: String
  var destinationSummary: String
  var includedOrderIDs: [UUID]
  var shipmentGroupIDs: [UUID]
  var inventoryReceiptIDs: [UUID]
  var packageContentIDs: [UUID]
  var custodyRecordIDs: [UUID]
  var labelReferenceIDs: [UUID]
  var scanSessionIDs: [UUID]
  var evidenceAttachmentIDs: [UUID]
  var assignedOwnerTeam: String
  var dispatchStatus: ShipmentManifestDispatchStatus
  var plannedDispatchDate: String
  var actualDispatchDate: String
  var handoffLocationStorageLocationID: UUID?
  var manifestReferencePlaceholder: String
  var notes: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

extension ShipmentManifestRecord {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Dispatch setup for")
          || manifestReferencePlaceholder.localizedCaseInsensitiveContains("INBOX-")
          || notes.localizedCaseInsensitiveContains("Inbox order handoff")
          || notes.localizedCaseInsensitiveContains("Inbox handoff")
      )
  }
}

struct DispatchReadinessChecklist: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var shipmentManifestID: UUID?
  var orderIDs: [UUID]
  var shipmentGroupIDs: [UUID]
  var inventoryReceiptIDs: [UUID]
  var packageContentIDs: [UUID]
  var custodyRecordIDs: [UUID]
  var labelReferenceIDs: [UUID]
  var scanSessionIDs: [UUID]
  var evidenceAttachmentIDs: [UUID]
  var checklistType: DispatchChecklistType
  var checklistStatus: DispatchChecklistStatus
  var requiredChecksSummary: String
  var completedChecksSummary: String
  var missingRequirementsSummary: String
  var assignedOwnerTeam: String
  var plannedDispatchDate: String
  var completedDate: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

extension DispatchReadinessChecklist {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Readiness for")
          || completedChecksSummary.localizedCaseInsensitiveContains("Inbox handoff")
          || missingRequirementsSummary.localizedCaseInsensitiveContains("handoff location")
      )
  }
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

struct ShipmentGroup: Identifiable, Hashable, Codable {
  var id = UUID()
  var groupName: String
  var primaryOrderID: UUID?
  var relatedOrderIDs: [UUID]
  var relatedIntakeEmailIDs: [UUID]
  var relatedTrackingEventIDs: [UUID]
  var relatedEvidenceIDs: [UUID]
  var destinationSummary: String
  var recipientCustomerSummary: String
  var carrierSummary: String
  var statusSummary: String
  var riskLevel: ShipmentRiskLevel
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
}

struct ImportQueueItem: Identifiable, Hashable, Codable {
  var id = UUID()
  var sourceType: ImportSourceType
  var sourceLabel: String
  var capturedDate: String
  var rawSummary: String
  var detectedMerchant: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var detectedDestinationAddress: String
  var suggestedLinkedOrderID: UUID?
  var suggestedShipmentGroupID: UUID?
  var confidenceScore: Int
  var importStatus: ImportStatus
  var reviewState: ReviewState
  var notes: String
}

struct AcceptanceRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var sourceType: AcceptanceSourceType
  var sourceID: UUID
  var sourceLabel: String
  var decidedDate: String
  var confidenceScore: Int
  var linkedOrderID: UUID?
  var linkedShipmentGroupID: UUID?
  var decision: AcceptanceDecision
  var reviewState: ReviewState
  var summary: String
  var notes: String
}

struct AcceptanceCandidate: Identifiable, Hashable {
  var id: String
  var sourceType: AcceptanceSourceType
  var sourceID: UUID
  var sourceLabel: String
  var capturedDate: String
  var rawSummary: String
  var detectedMerchant: String
  var detectedOrderNumber: String
  var detectedTrackingNumber: String
  var detectedDestinationAddress: String
  var suggestedLinkedOrderID: UUID?
  var suggestedShipmentGroupID: UUID?
  var confidenceScore: Int
  var decision: AcceptanceDecision
  var reviewState: ReviewState
  var notes: String
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

struct Microsoft365MailboxConnection: Identifiable, Hashable, Codable {
  var id = UUID()
  var displayName: String
  var tenantDomainHint: String
  var mailboxAddress: String
  var monitoredFolderNames: String
  var connectionStatus: String
  var lastManualRefreshDate: String
  var setupNotes: String
  var reviewState: ReviewState
  var tenantIDPlaceholder: String = ""
  var clientIDPlaceholder: String = ""
  var redirectURIPlaceholder: String = ""
  var requestedScopesSummary: String = "Mail.Read, User.Read"
  var oauthReadinessStatus: String = "Not reviewed"
  var consentAdminNotes: String = "Local planning only. No OAuth flow runs and no tokens are requested."
  var oauthImplementationPlanStatus: String = "Not reviewed"

  init(
    id: UUID = UUID(),
    displayName: String,
    tenantDomainHint: String,
    mailboxAddress: String,
    monitoredFolderNames: String,
    connectionStatus: String,
    lastManualRefreshDate: String,
    setupNotes: String,
    reviewState: ReviewState,
    tenantIDPlaceholder: String = "",
    clientIDPlaceholder: String = "",
    redirectURIPlaceholder: String = "",
    requestedScopesSummary: String = "Mail.Read, User.Read",
    oauthReadinessStatus: String = "Not reviewed",
    consentAdminNotes: String = "Local planning only. No OAuth flow runs and no tokens are requested.",
    oauthImplementationPlanStatus: String = "Not reviewed"
  ) {
    self.id = id
    self.displayName = displayName
    self.tenantDomainHint = tenantDomainHint
    self.mailboxAddress = mailboxAddress
    self.monitoredFolderNames = monitoredFolderNames
    self.connectionStatus = connectionStatus
    self.lastManualRefreshDate = lastManualRefreshDate
    self.setupNotes = setupNotes
    self.reviewState = reviewState
    self.tenantIDPlaceholder = tenantIDPlaceholder
    self.clientIDPlaceholder = clientIDPlaceholder
    self.redirectURIPlaceholder = redirectURIPlaceholder
    self.requestedScopesSummary = requestedScopesSummary
    self.oauthReadinessStatus = oauthReadinessStatus
    self.consentAdminNotes = consentAdminNotes
    self.oauthImplementationPlanStatus = oauthImplementationPlanStatus
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    displayName = try container.decode(String.self, forKey: .displayName)
    tenantDomainHint = try container.decode(String.self, forKey: .tenantDomainHint)
    mailboxAddress = try container.decode(String.self, forKey: .mailboxAddress)
    monitoredFolderNames = try container.decode(String.self, forKey: .monitoredFolderNames)
    connectionStatus = try container.decode(String.self, forKey: .connectionStatus)
    lastManualRefreshDate = try container.decode(String.self, forKey: .lastManualRefreshDate)
    setupNotes = try container.decode(String.self, forKey: .setupNotes)
    reviewState = try container.decode(ReviewState.self, forKey: .reviewState)
    tenantIDPlaceholder = try container.decodeIfPresent(String.self, forKey: .tenantIDPlaceholder) ?? ""
    clientIDPlaceholder = try container.decodeIfPresent(String.self, forKey: .clientIDPlaceholder) ?? ""
    redirectURIPlaceholder = try container.decodeIfPresent(String.self, forKey: .redirectURIPlaceholder) ?? ""
    requestedScopesSummary = try container.decodeIfPresent(String.self, forKey: .requestedScopesSummary) ?? "Mail.Read, User.Read"
    oauthReadinessStatus = try container.decodeIfPresent(String.self, forKey: .oauthReadinessStatus) ?? "Not reviewed"
    consentAdminNotes = try container.decodeIfPresent(String.self, forKey: .consentAdminNotes) ?? "Local planning only. No OAuth flow runs and no tokens are requested."
    oauthImplementationPlanStatus = try container.decodeIfPresent(String.self, forKey: .oauthImplementationPlanStatus) ?? "Not reviewed"
  }
}

struct Microsoft365OAuthReadinessSummary: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var isReady: Bool
  var missingFields: [String]
  var statusText: String
  var detailText: String
}

struct Microsoft365OAuthImplementationPlan: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var statusText: String
  var completedCount: Int
  var totalCount: Int
  var items: [Microsoft365OAuthImplementationChecklistItem]
}

struct Microsoft365OAuthImplementationChecklistItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var isComplete: Bool
  var detail: String
}

struct GmailOAuthReadinessSummary: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var isReady: Bool
  var missingFields: [String]
  var statusText: String
  var detailText: String
  var compiledClientIDStatus: String = "Compiled GIDClientID not checked"
  var compiledCallbackSchemeStatus: String = "Compiled callback scheme not checked"
  var expectedCallbackScheme: String = "Expected callback scheme unknown"
}

struct GmailOAuthImplementationPlan: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var statusText: String
  var completedCount: Int
  var totalCount: Int
  var items: [GmailOAuthImplementationChecklistItem]
}

struct GmailOAuthImplementationChecklistItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var isComplete: Bool
  var detail: String
}

struct GmailSetupTestChecklist: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var statusText: String
  var completedCount: Int
  var totalCount: Int
  var items: [GmailSetupTestChecklistItem]
}

struct GmailSetupTestChecklistItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var isComplete: Bool
  var detail: String
  var nextAction: String
  var symbolName: String
}

struct GmailReleaseSelfCheckSummary: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var title: String
  var verdict: String
  var detail: String
  var nextAction: String
  var tone: String
  var completedCount: Int
  var totalCount: Int
  var items: [GmailReleaseSelfCheckItem]
}

struct GmailReleaseSelfCheckItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var nextAction: String
  var isComplete: Bool
  var tone: String
  var symbolName: String
}

struct GmailAuthSessionState: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var status: GmailAuthStatus
  var signedInAccount: String
  var lastAuthAttemptDate: String
  var lastSuccessfulAuthDate: String
  var tokenStoreStatus: String
  var tokenStoreDetail: String
  var detailText: String
}

struct GmailAuthResult: Hashable {
  var status: GmailAuthStatus
  var signedInAccount: String
  var detailText: String
}

enum GmailAuthStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notConfigured = "Not configured"
  case notConnected = "Not connected"
  case connecting = "Connecting"
  case connected = "Connected"
  case authFailed = "Auth failed"
  case consentRequired = "Consent required"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .notConfigured: "exclamationmark.triangle.fill"
    case .notConnected: "person.crop.circle.badge.questionmark"
    case .connecting: "arrow.triangle.2.circlepath"
    case .connected: "checkmark.seal.fill"
    case .authFailed: "xmark.octagon.fill"
    case .consentRequired: "person.badge.key.fill"
    }
  }
}

struct GmailTokenStoreResult: Hashable {
  var status: GmailTokenStoreStatus
  var detailText: String
}

enum GmailTokenStoreStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case keychainNotConfigured = "Keychain not configured"
  case mockTokenReferenceAvailable = "Mock token reference available"
  case tokenMissing = "Token missing"
  case tokenClearSimulated = "Token clear simulated"
  case storageErrorSimulated = "Storage error simulated"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .keychainNotConfigured: "key.slash"
    case .mockTokenReferenceAvailable: "checkmark.seal.fill"
    case .tokenMissing: "exclamationmark.triangle.fill"
    case .tokenClearSimulated: "trash.circle.fill"
    case .storageErrorSimulated: "xmark.octagon.fill"
    }
  }
}

struct Microsoft365AuthSessionState: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var status: Microsoft365AuthStatus
  var signedInAccount: String
  var lastAuthAttemptDate: String
  var lastSuccessfulAuthDate: String
  var keychainStatus: String
  var tokenStoreStatus: Microsoft365TokenStoreStatus
  var tokenStoreDetail: String
  var detailText: String
}

struct Microsoft365AuthResult: Hashable {
  var status: Microsoft365AuthStatus
  var signedInAccount: String
  var detailText: String
}

enum Microsoft365AuthStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notConfigured = "Not configured"
  case notConnected = "Not connected"
  case connecting = "Connecting"
  case connected = "Connected"
  case authFailed = "Auth failed"
  case consentRequired = "Consent required"
  case tokenExpired = "Token expired"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .notConfigured: "exclamationmark.triangle.fill"
    case .notConnected: "person.crop.circle.badge.questionmark"
    case .connecting: "arrow.triangle.2.circlepath"
    case .connected: "checkmark.seal.fill"
    case .authFailed: "xmark.octagon.fill"
    case .consentRequired: "person.badge.key.fill"
    case .tokenExpired: "clock.badge.exclamationmark.fill"
    }
  }

}

struct Microsoft365TokenStoreResult: Hashable {
  var status: Microsoft365TokenStoreStatus
  var detailText: String
}

enum Microsoft365TokenStoreStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case keychainNotConfigured = "Keychain not configured"
  case mockTokenReferenceAvailable = "Token cache reference available"
  case tokenMissing = "Token missing"
  case tokenClearSimulated = "Token clear simulated"
  case storageErrorSimulated = "Storage error simulated"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .keychainNotConfigured: "key.slash"
    case .mockTokenReferenceAvailable: "checkmark.seal.fill"
    case .tokenMissing: "exclamationmark.triangle.fill"
    case .tokenClearSimulated: "trash.circle.fill"
    case .storageErrorSimulated: "xmark.octagon.fill"
    }
  }
}

struct SpaceMailRefreshHistoryEntry: Identifiable, Hashable, Codable {
  var id = UUID()
  var timestamp: String
  var eventType: String
  var status: String
  var fetchedCount: Int
  var importedCount: Int
  var duplicateCount: Int
  var filteredNonOrderCount: Int
  var uncertainCount: Int
  var summary: String
}

struct SpaceMailIntakeHealthSummary: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var displayName: String
  var verdict: String
  var detail: String
  var nextAction: String
  var tone: String
  var fetchedCount: Int
  var importedCount: Int
  var duplicateCount: Int
  var duplicateRefreshedCount: Int
  var duplicateNoChangeCount: Int
  var filteredCount: Int
  var uncertainCount: Int
  var parserIssueCount: Int
  var linkedIntakeCount: Int
  var pendingFilteredReviewCount: Int
  var pendingUncertainReviewCount: Int
  var lastRefreshDate: String
  var topReasonLabels: [String]
}

struct GmailIntakeHealthSummary: Identifiable, Hashable {
  var id: UUID { connectionID }
  var connectionID: UUID
  var displayName: String
  var verdict: String
  var detail: String
  var nextAction: String
  var tone: String
  var fetchedCount: Int
  var importedCount: Int
  var duplicateCount: Int
  var duplicateRefreshedCount: Int
  var duplicateNoChangeCount: Int
  var filteredCount: Int
  var uncertainCount: Int
  var linkedIntakeCount: Int
  var pendingUncertainReviewCount: Int
  var lastRefreshDate: String
  var lastRefreshSummary: String
}

struct GmailRefreshHistoryEntry: Identifiable, Hashable, Codable {
  var id = UUID()
  var timestamp: String
  var eventType: String
  var status: String
  var fetchedCount: Int
  var importedCount: Int
  var duplicateCount: Int
  var filteredNonOrderCount: Int
  var uncertainCount: Int
  var summary: String
}

struct SpaceMailMVPReadinessSummary: Hashable {
  var verdict: String
  var detail: String
  var nextAction: String
  var tone: String
  var completedCount: Int
  var totalCount: Int
  var items: [SpaceMailMVPReadinessItem]
}

struct SpaceMailMVPReadinessItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var isComplete: Bool
  var tone: String
}

struct LocalDataHygieneMetric: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var value: String
  var detail: String
  var tone: String
}

struct LocalDataHygieneSummary: Hashable {
  var verdict: String
  var detail: String
  var nextAction: String
  var tone: String
  var signalCount: Int
  var metrics: [LocalDataHygieneMetric]
  var examples: [String]
  var boundaries: [String]
}

struct SpaceMailQACheckSummary: Hashable {
  var verdict: String
  var detail: String
  var completedCount: Int
  var totalCount: Int
  var tone: String
  var checks: [SpaceMailQACheck]
}

struct SpaceMailQACheck: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var evidence: String
  var isComplete: Bool
  var tone: String
}

struct SpaceMailReleaseSnapshot: Hashable {
  var verdict: String
  var detail: String
  var generatedDate: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var reportText: String
}

struct SpaceMailReleaseSnapshotMetric: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var value: String
  var tone: String
}

struct SpaceMailPostRefreshActionPlan: Hashable {
  var title: String
  var detail: String
  var tone: String
  var primaryAction: String
  var items: [SpaceMailPostRefreshActionItem]
}

struct SpaceMailPostRefreshActionItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var count: Int
  var detail: String
  var actionLabel: String
  var tone: String
  var symbol: String
}

struct GmailPostRefreshActionPlan: Hashable {
  var title: String
  var detail: String
  var tone: String
  var primaryAction: String
  var items: [GmailPostRefreshActionItem]
}

struct GmailPostRefreshActionItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var count: Int
  var detail: String
  var actionLabel: String
  var tone: String
  var symbol: String
}

struct GmailShiftHandoffSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var lastRefreshText: String
  var keyCounts: [SpaceMailReleaseSnapshotMetric]
  var handoffLines: [GmailShiftHandoffLine]
}

struct GmailShiftHandoffLine: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var tone: String
  var symbol: String
}

struct GmailRefreshTrendSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var entries: [GmailRefreshTrendEntry]
}

struct GmailRefreshTrendEntry: Identifiable, Hashable {
  var id: UUID
  var timestamp: String
  var displayName: String
  var status: String
  var detail: String
  var tone: String
}

struct GmailLabelReadinessSummary: Hashable {
  var status: String
  var primaryLabel: String
  var labelCount: Int
  var refreshMode: String
  var detail: String
  var nextAction: String
  var tone: String
}

struct MailboxProviderComparisonSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var recommendedProvider: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var decisionRules: [MailboxProviderDecisionRule]
  var providers: [MailboxProviderComparisonItem]
  var actionItems: [MailboxProviderActionItem]
}

struct MailboxProviderDecisionRule: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var tone: String
  var symbol: String
}

struct MailboxProviderComparisonItem: Identifiable, Hashable {
  var id: String { providerName }
  var providerName: String
  var statusTitle: String
  var detail: String
  var nextAction: String
  var tone: String
  var symbol: String
  var fetchedCount: Int
  var importedCount: Int
  var blockedCount: Int
  var uncertainCount: Int
}

struct MailboxProviderActionItem: Identifiable, Hashable {
  var id: String { providerName + title }
  var providerName: String
  var title: String
  var detail: String
  var priority: String
  var tone: String
  var symbol: String
}

struct MailboxOperationsHandoffSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var lastEvidenceText: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var lines: [MailboxOperationsHandoffLine]
}

struct MailboxOperationsHandoffLine: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var tone: String
  var symbol: String
}

struct MailboxReleaseBlockerSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var blockers: [MailboxReleaseBlockerItem]
}

struct MailboxReleaseBlockerItem: Identifiable, Hashable {
  var id: String { source + title + detail }
  var source: String
  var title: String
  var detail: String
  var nextAction: String
  var tone: String
  var symbol: String
}

struct MailboxRunTimelineSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var entries: [MailboxRunTimelineEntry]
}

struct MailboxRunTimelineEntry: Identifiable, Hashable {
  var id: String
  var provider: String
  var timestamp: String
  var title: String
  var detail: String
  var outcome: String
  var tone: String
  var symbol: String
}

struct MailboxReleaseTestPlanSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var steps: [MailboxReleaseTestPlanStep]
}

struct MailboxReleaseTestPlanStep: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var evidence: String
  var nextAction: String
  var isComplete: Bool
  var tone: String
  var symbol: String
}

struct MailboxOperatorDecisionSummary: Hashable {
  var title: String
  var detail: String
  var primaryAction: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var decisions: [MailboxOperatorDecisionItem]
}

struct MailboxOperatorDecisionItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var action: String
  var isActive: Bool
  var tone: String
  var symbol: String
}

struct MailboxProviderTestQueueSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var currentProvider: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var items: [MailboxProviderTestQueueItem]
}

struct MailboxProviderTestQueueItem: Identifiable, Hashable {
  var id: String { "\(providerName)-\(title)-\(phase)" }
  var providerName: String
  var phase: String
  var title: String
  var detail: String
  var nextAction: String
  var evidence: String
  var isComplete: Bool
  var tone: String
  var symbol: String
}

struct MailboxProviderHandoffPacketSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var generatedDate: String
  var reportText: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var sections: [MailboxProviderHandoffPacketSection]
}

struct MailboxProviderHandoffPacketSection: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var tone: String
  var symbol: String
  var lines: [String]
}

struct MailboxProviderTroubleshootingSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var reportText: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var issues: [MailboxProviderTroubleshootingIssue]
}

struct MailboxProviderTroubleshootingIssue: Identifiable, Hashable {
  var id: String { "\(providerName)-\(title)-\(symptom)" }
  var providerName: String
  var title: String
  var symptom: String
  var likelyCause: String
  var nextAction: String
  var evidence: String
  var tone: String
  var symbol: String
}

struct MailboxProviderReleaseGateSummary: Hashable {
  var title: String
  var detail: String
  var verdict: String
  var tone: String
  var generatedDate: String
  var reportText: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var gates: [MailboxProviderReleaseGateItem]
}

struct MailboxProviderReleaseGateItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var requirement: String
  var evidence: String
  var nextAction: String
  var isPassed: Bool
  var tone: String
  var symbol: String
}

struct MailboxProviderSetupChecklistSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var providers: [MailboxProviderSetupChecklistProvider]
}

struct MailboxProviderSetupChecklistProvider: Identifiable, Hashable {
  var id: String { providerName }
  var providerName: String
  var status: String
  var detail: String
  var nextAction: String
  var tone: String
  var symbol: String
  var checks: [MailboxProviderSetupChecklistItem]
}

struct MailboxProviderSetupChecklistItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var isComplete: Bool
  var tone: String
  var symbol: String
}

struct SpaceMailShiftHandoffSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var lastRefreshText: String
  var keyCounts: [SpaceMailReleaseSnapshotMetric]
  var handoffLines: [SpaceMailShiftHandoffLine]
}

struct SpaceMailShiftHandoffLine: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var tone: String
  var symbol: String
}

struct SpaceMailRefreshTrendSummary: Hashable {
  var title: String
  var detail: String
  var tone: String
  var metrics: [SpaceMailReleaseSnapshotMetric]
  var entries: [SpaceMailRefreshTrendEntry]
}

struct SpaceMailRefreshTrendEntry: Identifiable, Hashable {
  var id: UUID
  var timestamp: String
  var displayName: String
  var status: String
  var detail: String
  var tone: String
}

struct SpaceMailIMAPConnection: Identifiable, Hashable, Codable {
  var id = UUID()
  var displayName: String
  var emailAddressUsername: String
  var imapHost: String
  var imapPort: String
  var securityMode: String
  var folderName: String
  var connectionStatus: String
  var lastManualRefreshDate: String
  var setupNotes: String
  var credentialStorageStatus: String
  var mailboxMode: SpaceMailMailboxMode
  var trustedSenderHints: [String]
  var importKeywordHints: [String]
  var uncertainKeywordHints: [String]
  var filterKeywordHints: [String]
  var lastRefreshFetchedCount: Int
  var lastRefreshImportedCount: Int
  var lastRefreshDuplicateCount: Int
  var lastRefreshFilteredNonOrderCount: Int
  var lastRefreshUncertainCount: Int
  var lastRefreshSummary: String
  var lastRefreshFilteredExamples: [String]
  var lastRefreshUncertainExamples: [String]
  var classifierTestSummary: String
  var uncertainMessages: [SpaceMailUncertainMessage]
  var filteredMessages: [SpaceMailFilteredMessage]
  var lastRefreshReasonBreakdown: [SpaceMailClassifierReasonCount]
  var classifierTestResults: [SpaceMailClassifierTestResult]
  var refreshHistory: [SpaceMailRefreshHistoryEntry]
  var reviewState: ReviewState

  init(
    id: UUID = UUID(),
    displayName: String,
    emailAddressUsername: String,
    imapHost: String,
    imapPort: String,
    securityMode: String,
    folderName: String,
    connectionStatus: String,
    lastManualRefreshDate: String,
    setupNotes: String,
    credentialStorageStatus: String,
    mailboxMode: SpaceMailMailboxMode = .mixedFiltered,
    trustedSenderHints: [String] = [],
    importKeywordHints: [String] = [],
    uncertainKeywordHints: [String] = [],
    filterKeywordHints: [String] = [],
    lastRefreshFetchedCount: Int = 0,
    lastRefreshImportedCount: Int = 0,
    lastRefreshDuplicateCount: Int = 0,
    lastRefreshFilteredNonOrderCount: Int = 0,
    lastRefreshUncertainCount: Int = 0,
    lastRefreshSummary: String = "No refresh has run yet.",
    lastRefreshFilteredExamples: [String] = [],
    lastRefreshUncertainExamples: [String] = [],
    classifierTestSummary: String = "Classifier test has not run.",
    uncertainMessages: [SpaceMailUncertainMessage] = [],
    filteredMessages: [SpaceMailFilteredMessage] = [],
    lastRefreshReasonBreakdown: [SpaceMailClassifierReasonCount] = [],
    classifierTestResults: [SpaceMailClassifierTestResult] = [],
    refreshHistory: [SpaceMailRefreshHistoryEntry] = [],
    reviewState: ReviewState
  ) {
    self.id = id
    self.displayName = displayName
    self.emailAddressUsername = emailAddressUsername
    self.imapHost = imapHost
    self.imapPort = imapPort
    self.securityMode = securityMode
    self.folderName = folderName
    self.connectionStatus = connectionStatus
    self.lastManualRefreshDate = lastManualRefreshDate
    self.setupNotes = setupNotes
    self.credentialStorageStatus = credentialStorageStatus
    self.mailboxMode = mailboxMode
    self.trustedSenderHints = trustedSenderHints
    self.importKeywordHints = importKeywordHints
    self.uncertainKeywordHints = uncertainKeywordHints
    self.filterKeywordHints = filterKeywordHints
    self.lastRefreshFetchedCount = lastRefreshFetchedCount
    self.lastRefreshImportedCount = lastRefreshImportedCount
    self.lastRefreshDuplicateCount = lastRefreshDuplicateCount
    self.lastRefreshFilteredNonOrderCount = lastRefreshFilteredNonOrderCount
    self.lastRefreshUncertainCount = lastRefreshUncertainCount
    self.lastRefreshSummary = lastRefreshSummary
    self.lastRefreshFilteredExamples = lastRefreshFilteredExamples
    self.lastRefreshUncertainExamples = lastRefreshUncertainExamples
    self.classifierTestSummary = classifierTestSummary
    self.uncertainMessages = uncertainMessages
    self.filteredMessages = filteredMessages
    self.lastRefreshReasonBreakdown = lastRefreshReasonBreakdown
    self.classifierTestResults = classifierTestResults
    self.refreshHistory = refreshHistory
    self.reviewState = reviewState
  }

  enum CodingKeys: String, CodingKey {
    case id
    case displayName
    case emailAddressUsername
    case imapHost
    case imapPort
    case securityMode
    case folderName
    case connectionStatus
    case lastManualRefreshDate
    case setupNotes
    case credentialStorageStatus
    case mailboxMode
    case trustedSenderHints
    case importKeywordHints
    case uncertainKeywordHints
    case filterKeywordHints
    case lastRefreshFetchedCount
    case lastRefreshImportedCount
    case lastRefreshDuplicateCount
    case lastRefreshFilteredNonOrderCount
    case lastRefreshUncertainCount
    case lastRefreshSummary
    case lastRefreshFilteredExamples
    case lastRefreshUncertainExamples
    case classifierTestSummary
    case uncertainMessages
    case filteredMessages
    case lastRefreshReasonBreakdown
    case classifierTestResults
    case refreshHistory
    case reviewState
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    displayName = try container.decode(String.self, forKey: .displayName)
    emailAddressUsername = try container.decode(String.self, forKey: .emailAddressUsername)
    imapHost = try container.decode(String.self, forKey: .imapHost)
    imapPort = try container.decode(String.self, forKey: .imapPort)
    securityMode = try container.decode(String.self, forKey: .securityMode)
    folderName = try container.decode(String.self, forKey: .folderName)
    connectionStatus = try container.decode(String.self, forKey: .connectionStatus)
    lastManualRefreshDate = try container.decode(String.self, forKey: .lastManualRefreshDate)
    setupNotes = try container.decode(String.self, forKey: .setupNotes)
    credentialStorageStatus = try container.decode(String.self, forKey: .credentialStorageStatus)
    mailboxMode = try container.decodeIfPresent(SpaceMailMailboxMode.self, forKey: .mailboxMode) ?? .mixedFiltered
    trustedSenderHints = try container.decodeIfPresent([String].self, forKey: .trustedSenderHints) ?? []
    importKeywordHints = try container.decodeIfPresent([String].self, forKey: .importKeywordHints) ?? []
    uncertainKeywordHints = try container.decodeIfPresent([String].self, forKey: .uncertainKeywordHints) ?? []
    filterKeywordHints = try container.decodeIfPresent([String].self, forKey: .filterKeywordHints) ?? []
    lastRefreshFetchedCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshFetchedCount) ?? 0
    lastRefreshImportedCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshImportedCount) ?? 0
    lastRefreshDuplicateCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshDuplicateCount) ?? 0
    lastRefreshFilteredNonOrderCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshFilteredNonOrderCount) ?? 0
    lastRefreshUncertainCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshUncertainCount) ?? 0
    lastRefreshSummary = try container.decodeIfPresent(String.self, forKey: .lastRefreshSummary) ?? "No refresh has run yet."
    lastRefreshFilteredExamples = try container.decodeIfPresent([String].self, forKey: .lastRefreshFilteredExamples) ?? []
    lastRefreshUncertainExamples = try container.decodeIfPresent([String].self, forKey: .lastRefreshUncertainExamples) ?? []
    classifierTestSummary = try container.decodeIfPresent(String.self, forKey: .classifierTestSummary) ?? "Classifier test has not run."
    uncertainMessages = try container.decodeIfPresent([SpaceMailUncertainMessage].self, forKey: .uncertainMessages) ?? []
    filteredMessages = try container.decodeIfPresent([SpaceMailFilteredMessage].self, forKey: .filteredMessages) ?? []
    lastRefreshReasonBreakdown = try container.decodeIfPresent([SpaceMailClassifierReasonCount].self, forKey: .lastRefreshReasonBreakdown) ?? []
    classifierTestResults = try container.decodeIfPresent([SpaceMailClassifierTestResult].self, forKey: .classifierTestResults) ?? []
    refreshHistory = try container.decodeIfPresent([SpaceMailRefreshHistoryEntry].self, forKey: .refreshHistory) ?? []
    reviewState = try container.decode(ReviewState.self, forKey: .reviewState)
  }
}

enum SpaceMailMailboxMode: String, CaseIterable, Identifiable, Hashable, Codable {
  case dedicatedOrderMailbox = "Dedicated order mailbox"
  case mixedFiltered = "Mixed mailbox, filter likely order emails only"

  var id: String { rawValue }
}

enum SpaceMailFilterPreset: String, CaseIterable, Identifiable, Hashable, Codable {
  case conservative = "Conservative mixed mailbox"
  case balanced = "Balanced order triage"
  case forwardedOrders = "Forwarded order updates"

  var id: String { rawValue }
}

enum SpaceMailHintTarget: String, CaseIterable, Identifiable, Hashable {
  case trustedSender = "Trusted sender"
  case importKeyword = "Import keyword"
  case uncertainKeyword = "Uncertain keyword"
  case filterKeyword = "Filter keyword"

  var id: String { rawValue }
}

struct GmailMailboxConnection: Identifiable, Hashable, Codable {
  var id = UUID()
  var displayName: String
  var emailAddress: String
  var monitoredLabelNames: String
  var connectionStatus: String
  var lastManualRefreshDate: String
  var setupNotes: String
  var oauthReadinessStatus: String
  var googleCloudProjectHint: String?
  var oauthClientIDPlaceholder: String?
  var redirectURIPlaceholder: String?
  var requestedScopesSummary: String
  var consentScreenNotes: String?
  var credentialStorageStatus: String
  var mailboxMode: SpaceMailMailboxMode
  var lastRefreshFetchedCount: Int
  var lastRefreshImportedCount: Int
  var lastRefreshDuplicateCount: Int
  var lastRefreshFilteredNonOrderCount: Int
  var lastRefreshUncertainCount: Int?
  var lastRefreshSummary: String
  var lastRefreshFilteredExamples: [String]?
  var lastRefreshUncertainExamples: [String]?
  var lastRefreshReasonBreakdown: [SpaceMailClassifierReasonCount]?
  var uncertainMessages: [GmailReviewMessage]?
  var filteredMessages: [GmailReviewMessage]?
  var classifierTestSummary: String?
  var classifierTestResults: [GmailClassifierTestResult]?
  var refreshHistory: [GmailRefreshHistoryEntry]?
  var trustedSenderHints: [String]?
  var importKeywordHints: [String]?
  var uncertainKeywordHints: [String]?
  var filterKeywordHints: [String]?
  var reviewState: ReviewState

  init(
    id: UUID = UUID(),
    displayName: String,
    emailAddress: String,
    monitoredLabelNames: String,
    connectionStatus: String,
    lastManualRefreshDate: String,
    setupNotes: String,
    oauthReadinessStatus: String,
    googleCloudProjectHint: String? = nil,
    oauthClientIDPlaceholder: String? = nil,
    redirectURIPlaceholder: String? = nil,
    requestedScopesSummary: String,
    consentScreenNotes: String? = nil,
    credentialStorageStatus: String,
    mailboxMode: SpaceMailMailboxMode = .mixedFiltered,
    lastRefreshFetchedCount: Int = 0,
    lastRefreshImportedCount: Int = 0,
    lastRefreshDuplicateCount: Int = 0,
    lastRefreshFilteredNonOrderCount: Int = 0,
    lastRefreshUncertainCount: Int? = nil,
    lastRefreshSummary: String = "No Gmail refresh has run yet.",
    lastRefreshFilteredExamples: [String]? = nil,
    lastRefreshUncertainExamples: [String]? = nil,
    lastRefreshReasonBreakdown: [SpaceMailClassifierReasonCount]? = nil,
    uncertainMessages: [GmailReviewMessage]? = nil,
    filteredMessages: [GmailReviewMessage]? = nil,
    classifierTestSummary: String? = nil,
    classifierTestResults: [GmailClassifierTestResult]? = nil,
    refreshHistory: [GmailRefreshHistoryEntry]? = nil,
    trustedSenderHints: [String]? = nil,
    importKeywordHints: [String]? = nil,
    uncertainKeywordHints: [String]? = nil,
    filterKeywordHints: [String]? = nil,
    reviewState: ReviewState
  ) {
    self.id = id
    self.displayName = displayName
    self.emailAddress = emailAddress
    self.monitoredLabelNames = monitoredLabelNames
    self.connectionStatus = connectionStatus
    self.lastManualRefreshDate = lastManualRefreshDate
    self.setupNotes = setupNotes
    self.oauthReadinessStatus = oauthReadinessStatus
    self.googleCloudProjectHint = googleCloudProjectHint
    self.oauthClientIDPlaceholder = oauthClientIDPlaceholder
    self.redirectURIPlaceholder = redirectURIPlaceholder
    self.requestedScopesSummary = requestedScopesSummary
    self.consentScreenNotes = consentScreenNotes
    self.credentialStorageStatus = credentialStorageStatus
    self.mailboxMode = mailboxMode
    self.lastRefreshFetchedCount = lastRefreshFetchedCount
    self.lastRefreshImportedCount = lastRefreshImportedCount
    self.lastRefreshDuplicateCount = lastRefreshDuplicateCount
    self.lastRefreshFilteredNonOrderCount = lastRefreshFilteredNonOrderCount
    self.lastRefreshUncertainCount = lastRefreshUncertainCount
    self.lastRefreshSummary = lastRefreshSummary
    self.lastRefreshFilteredExamples = lastRefreshFilteredExamples
    self.lastRefreshUncertainExamples = lastRefreshUncertainExamples
    self.lastRefreshReasonBreakdown = lastRefreshReasonBreakdown
    self.uncertainMessages = uncertainMessages
    self.filteredMessages = filteredMessages
    self.classifierTestSummary = classifierTestSummary
    self.classifierTestResults = classifierTestResults
    self.refreshHistory = refreshHistory
    self.trustedSenderHints = trustedSenderHints
    self.importKeywordHints = importKeywordHints
    self.uncertainKeywordHints = uncertainKeywordHints
    self.filterKeywordHints = filterKeywordHints
    self.reviewState = reviewState
  }

  enum CodingKeys: String, CodingKey {
    case id
    case displayName
    case emailAddress
    case monitoredLabelNames
    case connectionStatus
    case lastManualRefreshDate
    case setupNotes
    case oauthReadinessStatus
    case googleCloudProjectHint
    case oauthClientIDPlaceholder
    case redirectURIPlaceholder
    case requestedScopesSummary
    case consentScreenNotes
    case credentialStorageStatus
    case mailboxMode
    case lastRefreshFetchedCount
    case lastRefreshImportedCount
    case lastRefreshDuplicateCount
    case lastRefreshFilteredNonOrderCount
    case lastRefreshUncertainCount
    case lastRefreshSummary
    case lastRefreshFilteredExamples
    case lastRefreshUncertainExamples
    case lastRefreshReasonBreakdown
    case uncertainMessages
    case filteredMessages
    case classifierTestSummary
    case classifierTestResults
    case refreshHistory
    case trustedSenderHints
    case importKeywordHints
    case uncertainKeywordHints
    case filterKeywordHints
    case reviewState
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    displayName = try container.decode(String.self, forKey: .displayName)
    emailAddress = try container.decode(String.self, forKey: .emailAddress)
    monitoredLabelNames = try container.decode(String.self, forKey: .monitoredLabelNames)
    connectionStatus = try container.decode(String.self, forKey: .connectionStatus)
    lastManualRefreshDate = try container.decode(String.self, forKey: .lastManualRefreshDate)
    setupNotes = try container.decode(String.self, forKey: .setupNotes)
    oauthReadinessStatus = try container.decodeIfPresent(String.self, forKey: .oauthReadinessStatus) ?? "Needs review"
    googleCloudProjectHint = try container.decodeIfPresent(String.self, forKey: .googleCloudProjectHint)
    oauthClientIDPlaceholder = try container.decodeIfPresent(String.self, forKey: .oauthClientIDPlaceholder)
    redirectURIPlaceholder = try container.decodeIfPresent(String.self, forKey: .redirectURIPlaceholder)
    requestedScopesSummary = try container.decodeIfPresent(String.self, forKey: .requestedScopesSummary) ?? "openid email profile https://www.googleapis.com/auth/gmail.readonly"
    consentScreenNotes = try container.decodeIfPresent(String.self, forKey: .consentScreenNotes)
    credentialStorageStatus = try container.decodeIfPresent(String.self, forKey: .credentialStorageStatus) ?? "GoogleSignIn cache pending"
    mailboxMode = try container.decodeIfPresent(SpaceMailMailboxMode.self, forKey: .mailboxMode) ?? .mixedFiltered
    lastRefreshFetchedCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshFetchedCount) ?? 0
    lastRefreshImportedCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshImportedCount) ?? 0
    lastRefreshDuplicateCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshDuplicateCount) ?? 0
    lastRefreshFilteredNonOrderCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshFilteredNonOrderCount) ?? 0
    lastRefreshUncertainCount = try container.decodeIfPresent(Int.self, forKey: .lastRefreshUncertainCount)
    lastRefreshSummary = try container.decodeIfPresent(String.self, forKey: .lastRefreshSummary) ?? "No Gmail refresh has run yet."
    lastRefreshFilteredExamples = try container.decodeIfPresent([String].self, forKey: .lastRefreshFilteredExamples)
    lastRefreshUncertainExamples = try container.decodeIfPresent([String].self, forKey: .lastRefreshUncertainExamples)
    lastRefreshReasonBreakdown = try container.decodeIfPresent([SpaceMailClassifierReasonCount].self, forKey: .lastRefreshReasonBreakdown)
    uncertainMessages = try container.decodeIfPresent([GmailReviewMessage].self, forKey: .uncertainMessages)
    filteredMessages = try container.decodeIfPresent([GmailReviewMessage].self, forKey: .filteredMessages)
    classifierTestSummary = try container.decodeIfPresent(String.self, forKey: .classifierTestSummary)
    classifierTestResults = try container.decodeIfPresent([GmailClassifierTestResult].self, forKey: .classifierTestResults)
    refreshHistory = try container.decodeIfPresent([GmailRefreshHistoryEntry].self, forKey: .refreshHistory)
    trustedSenderHints = try container.decodeIfPresent([String].self, forKey: .trustedSenderHints)
    importKeywordHints = try container.decodeIfPresent([String].self, forKey: .importKeywordHints)
    uncertainKeywordHints = try container.decodeIfPresent([String].self, forKey: .uncertainKeywordHints)
    filterKeywordHints = try container.decodeIfPresent([String].self, forKey: .filterKeywordHints)
    reviewState = try container.decode(ReviewState.self, forKey: .reviewState)
  }
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
  var comparisonStatus: String?
  var comparisonNotes: String?
  var purchaseReadiness: String?
  var preferredOptionID: UUID?
  var comparisonOptions: [WishlistComparisonOption]?
  var purchaseChecks: [WishlistPurchaseCheck]?
  var purchaseDecision: WishlistPurchaseDecision?
  var purchaseHandoff: WishlistPurchaseHandoff?
}

struct WishlistComparisonOption: Identifiable, Hashable, Codable {
  var id = UUID()
  var sellerName: String
  var productURL: String
  var listedPrice: String
  var currency: String
  var estimatedAUDTotal: String
  var postageCost: String
  var postageTime: String
  var sellerRegion: String
  var trustRating: String
  var trustNotes: String
  var recommendation: String
  var lastChecked: String
  var localScore: Int?
  var riskLevel: String?
  var decisionReason: String?
}

struct WishlistPurchaseCheck: Identifiable, Hashable, Codable {
  var id = UUID()
  var title: String
  var status: String
  var detail: String
  var severity: String
}

struct WishlistPurchaseDecision: Identifiable, Hashable, Codable {
  var id = UUID()
  var selectedOptionID: UUID?
  var selectedSellerName: String
  var decisionStatus: String
  var totalAUDSummary: String
  var postageSummary: String
  var trustSummary: String
  var rejectedOptionsSummary: String
  var decisionNotes: String
  var decidedBy: String
  var decidedDate: String
  var reviewState: ReviewState
}

struct WishlistPurchaseHandoff: Identifiable, Hashable, Codable {
  var id = UUID()
  var sellerName: String
  var accountLabel: String
  var purchaseStatus: String
  var expectedOrderSignals: String
  var orderWatchStatus: String
  var linkedOrderID: UUID?
  var notes: String
  var updatedAt: String
}

struct WishlistCaptureCandidate: Identifiable, Hashable, Codable {
  var id = UUID()
  var source: WishlistSource
  var pageTitle: String
  var pageURL: String
  var detectedStorefront: String
  var detectedPrice: String
  var productSummary: String
  var captureStatus: String
  var reviewState: ReviewState
  var capturedDate: String
  var notes: String
}

extension WishlistItem {
  var operatorPurchaseBlockers: [String] {
    let options = comparisonOptions ?? []
    let preferred = preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    }
    let failedChecks = (purchaseChecks ?? []).filter { $0.status != "Passed" }
    var blockers: [String] = []

    if options.isEmpty {
      blockers.append("add seller options")
    }
    if preferred == nil {
      blockers.append("choose preferred seller")
    }
    if let preferred {
      let gaps = preferred.operatorSellerEvidenceGaps
      if !gaps.isEmpty {
        blockers.append("confirm \(gaps.joined(separator: ", "))")
      }
    }
    if purchaseChecks?.isEmpty != false {
      blockers.append("run readiness check")
    } else if !failedChecks.isEmpty {
      blockers.append("clear \(failedChecks.count) readiness item\(failedChecks.count == 1 ? "" : "s")")
    }
    if purchaseDecision == nil {
      blockers.append("draft purchase decision")
    } else if purchaseDecision?.reviewState != .accepted {
      blockers.append("review purchase decision")
    }
    if purchaseHandoff == nil {
      blockers.append("prepare handoff")
    } else if purchaseHandoff?.linkedOrderID == nil {
      blockers.append("link order after confirmation")
    }

    return blockers
  }

  var operatorPurchaseNextAction: String {
    if operatorPurchaseBlockers.isEmpty {
      return "Use linked order or final manual verification as the source of truth."
    }
    return "Next: \(operatorPurchaseBlockers.prefix(2).joined(separator: "; "))."
  }
}

extension WishlistComparisonOption {
  var operatorSellerEvidenceGaps: [String] {
    let searchable = [
      productURL,
      listedPrice,
      currency,
      estimatedAUDTotal,
      postageCost,
      postageTime,
      sellerRegion,
      trustRating,
      trustNotes,
      recommendation
    ]
      .joined(separator: " ")
      .localizedLowercase

    var gaps: [String] = []
    if productURL.isPlaceholderValidationValue || !productURL.localizedCaseInsensitiveContains("http") {
      gaps.append("product link")
    }
    if !estimatedAUDTotal.localizedCaseInsensitiveContains("aud") || estimatedAUDTotal.localizedCaseInsensitiveContains("pending") {
      gaps.append("AUD total")
    }
    if postageCost.localizedCaseInsensitiveContains("pending") || postageCost.isPlaceholderValidationValue {
      gaps.append("postage cost")
    }
    if postageTime.localizedCaseInsensitiveContains("pending") || postageTime.isPlaceholderValidationValue {
      gaps.append("postage time")
    }
    if trustRating.localizedCaseInsensitiveContains("unknown") || trustRating.localizedCaseInsensitiveContains("review") {
      gaps.append("seller trust")
    }
    if !searchable.contains("return") && !searchable.contains("warranty") {
      gaps.append("returns/warranty")
    }
    return gaps
  }

  var operatorSellerMatrixScore: Int {
    if let localScore {
      return localScore
    }

    var score = 50
    let searchable = [
      sellerName,
      productURL,
      listedPrice,
      currency,
      estimatedAUDTotal,
      postageCost,
      postageTime,
      sellerRegion,
      trustRating,
      trustNotes,
      recommendation
    ].joined(separator: " ").localizedLowercase

    if estimatedAUDTotal.localizedCaseInsensitiveContains("aud") && !estimatedAUDTotal.localizedCaseInsensitiveContains("pending") {
      score += 14
    } else {
      score -= 16
    }

    if !postageCost.localizedCaseInsensitiveContains("pending")
      && !postageCost.isPlaceholderValidationValue
      && !postageTime.localizedCaseInsensitiveContains("pending")
      && !postageTime.isPlaceholderValidationValue {
      score += 12
    } else {
      score -= 14
    }

    if trustRating.localizedCaseInsensitiveContains("trusted")
      || trustRating.localizedCaseInsensitiveContains("high")
      || trustRating.localizedCaseInsensitiveContains("accepted") {
      score += 18
    } else if trustRating.localizedCaseInsensitiveContains("unknown")
      || trustRating.localizedCaseInsensitiveContains("needs")
      || trustRating.localizedCaseInsensitiveContains("review")
      || trustRating.localizedCaseInsensitiveContains("low") {
      score -= 22
    }

    if sellerRegion.localizedCaseInsensitiveContains("australia")
      || sellerRegion.localizedCaseInsensitiveContains("au") {
      score += 6
    } else if sellerRegion.localizedCaseInsensitiveContains("overseas")
      || sellerRegion.localizedCaseInsensitiveContains("international")
      || sellerRegion.localizedCaseInsensitiveContains("global") {
      score -= 4
    }

    if searchable.contains("return") || searchable.contains("warranty") {
      score += 6
    } else {
      score -= 6
    }

    return min(100, max(0, score))
  }

  var operatorSellerMatrixRisk: String {
    if let riskLevel, !riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return riskLevel
    }
    let score = operatorSellerMatrixScore
    if score >= 75 { return "Lower risk" }
    if score >= 55 { return "Review recommended" }
    return "High risk"
  }

  var operatorSellerMatrixRecommendation: String {
    let gaps = operatorSellerEvidenceGaps
    if gaps.isEmpty && operatorSellerMatrixScore >= 75 {
      return "Good local candidate. Verify live price, stock, postage, returns, and account readiness before purchase."
    }
    if gaps.isEmpty {
      return "Evidence fields are complete, but score still needs operator review before purchase."
    }
    return "Resolve: \(gaps.prefix(3).joined(separator: ", "))."
  }
}

struct WishlistResearchRequest: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sourceURL: String
  var regionScope: String
  var sellerCriteria: String
  var maxBudgetAUD: String
  var postageRequirements: String
  var trustRequirements: String
  var requestStatus: String
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistPriceSnapshot: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sellerName: String
  var productURL: String
  var observedPrice: String
  var currency: String
  var estimatedAUDTotal: String
  var postageCost: String
  var postageTime: String
  var availabilityStatus: String
  var trustSignal: String
  var snapshotSource: String
  var capturedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistSellerQuote: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sellerName: String
  var productURL: String
  var listedPrice: String
  var currency: String
  var estimatedAUDTotal: String
  var postageCost: String
  var postageTime: String
  var sellerRegion: String
  var trustSummary: String
  var returnsWarrantySummary: String
  var quoteSource: String
  var quoteStatus: String
  var capturedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistPriceWatchRule: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var targetAUDTotal: String
  var maxPostageCost: String
  var maximumDeliveryTime: String
  var requiredTrustLevel: String
  var allowedRegions: String
  var ruleStatus: String
  var createdDate: String
  var lastEvaluatedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistSellerTrustRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var sellerQuoteID: UUID?
  var itemName: String
  var sellerName: String
  var checkType: String
  var evidenceSummary: String
  var resultStatus: String
  var riskLevel: String
  var sourceURL: String
  var checkedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistPurchaseAccountRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sellerName: String
  var accountLabel: String
  var accountReadinessStatus: String
  var paymentReadinessStatus: String
  var deliveryAddressStatus: String
  var expectedOrderEmailSignals: String
  var credentialStorageNote: String
  var purchaseBoundaryNote: String
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistPurchaseApprovalRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sellerName: String
  var requestedBy: String
  var approver: String
  var approvalStatus: String
  var approvedAUDLimit: String
  var budgetCode: String
  var paymentMethodSummary: String
  var approvalReason: String
  var createdDate: String
  var lastReviewedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistPurchaseLinkRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var itemName: String
  var sellerName: String
  var productURL: String
  var linkType: String
  var estimatedAUDTotal: String
  var postageSummary: String
  var trustSummary: String
  var readinessStatus: String
  var accountContext: String
  var selectedForPurchase: Bool
  var createdDate: String
  var lastCheckedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistOrderWatchRecord: Identifiable, Hashable, Codable {
  var id = UUID()
  var wishlistItemID: UUID?
  var linkedOrderID: UUID?
  var itemName: String
  var sellerName: String
  var accountLabel: String
  var expectedOrderSignals: String
  var expectedMailboxOrSource: String
  var watchStatus: String
  var matchedOrderSummary: String
  var nextCheckSummary: String
  var createdDate: String
  var lastCheckedDate: String
  var reviewState: ReviewState
  var notes: String
}

struct WishlistAgentReadinessItem: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var status: String
  var detail: String
  var tone: String
  var nextAction: String
}

struct WishlistAgentReadinessSummary: Identifiable, Hashable {
  var id = "wishlist-agent-readiness"
  var title: String
  var verdict: String
  var detail: String
  var tone: String
  var readyBriefCount: Int
  var scopeGapCount: Int
  var sellerOptionGapCount: Int
  var trustReviewCount: Int
  var purchaseHandoffGapCount: Int
  var orderWatchGapCount: Int
  var operationsClosureGapCount: Int
  var items: [WishlistAgentReadinessItem]
}

extension WishlistResearchRequest {
  var agentBriefGaps: [String] {
    var gaps: [String] = []
    if itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || itemName.isPlaceholderValidationValue {
      gaps.append("item name")
    }
    if sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sourceURL.isPlaceholderValidationValue {
      gaps.append("source URL")
    }
    if maxBudgetAUD.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || maxBudgetAUD.localizedCaseInsensitiveContains("confirm")
      || maxBudgetAUD.localizedCaseInsensitiveContains("pending") {
      gaps.append("AUD budget")
    }
    if regionScope.trimmingCharacters(in: .whitespacesAndNewlines).count < 12 {
      gaps.append("region scope")
    }
    if sellerCriteria.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
      gaps.append("seller criteria")
    }
    if postageRequirements.trimmingCharacters(in: .whitespacesAndNewlines).count < 16 {
      gaps.append("postage requirements")
    }
    if trustRequirements.trimmingCharacters(in: .whitespacesAndNewlines).count < 16 {
      gaps.append("seller trust requirements")
    }
    if reviewState != .accepted {
      gaps.append("operator review")
    }
    return gaps
  }

  var isAgentBriefReady: Bool {
    agentBriefGaps.isEmpty
  }

  var agentBriefStatus: String {
    if requestStatus.localizedCaseInsensitiveContains("blocked") {
      return "Blocked"
    }
    if isAgentBriefReady {
      return "Agent-ready"
    }
    return "Needs scope"
  }

  var agentBriefNextAction: String {
    let gaps = agentBriefGaps
    if gaps.isEmpty {
      return "Ready for future comparison agent handoff after live integration exists."
    }
    return "Clarify: \(gaps.prefix(3).joined(separator: ", "))."
  }

  var agentInstructionPacket: String {
    """
    Compare item: \(itemName)
    Source URL: \(sourceURL)
    Region scope: \(regionScope)
    Budget: \(maxBudgetAUD)
    Seller criteria: \(sellerCriteria)
    Postage requirements: \(postageRequirements)
    Trust requirements: \(trustRequirements)
    Required output: product URL, seller, listed price/currency, estimated AUD landed total, postage cost/time, seller region, returns/warranty notes, trust evidence, recommendation.
    Boundaries: do not buy, log in, store credentials, enter payment details, mutate mailboxes, book carriers, or run background monitoring.
    """
  }
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
  case acknowledged = "Acknowledged"
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
  case auditEvent = "Audit event"
  case reviewTask = "Review task"
  case handoffNote = "Handoff note"
  case slaPolicy = "SLA policy"
  case exceptionPlaybook = "Exception playbook"
  case communicationTemplate = "Communication template"
  case draftMessage = "Draft message"
  case contactDirectoryEntry = "Contact"
  case customerRecipientProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case accountCredentialRecord = "Account"
  case vendorProfile = "Vendor profile"
  case shipmentGroup = "Shipment group"
  case importQueueItem = "Import queue item"
  case acceptanceRecord = "Acceptance record"
  case wishlistItem = "Wishlist item"
  case reconciliationIssue = "Reconciliation issue"
  case microsoft365MailboxConnection = "Microsoft 365 mailbox"
  case spaceMailIMAPConnection = "SpaceMail IMAP mailbox"
  case gmailMailboxConnection = "Gmail mailbox"
  case trackedMailbox = "Tracked mailbox"
  case shopifyConnection = "Shopify connection"
  case sourceConnection = "Source connection"
  case watchedFolder = "Watched folder"
  case settings = "Settings"

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

enum CustomerProfileType: String, CaseIterable, Identifiable, Hashable, Codable {
  case customer = "Customer"
  case recipient = "Recipient"
  case internalTeam = "Internal team"
  case department = "Department"
  case site = "Site"

  var id: String { rawValue }
}

enum DeliveryPreference: String, CaseIterable, Identifiable, Hashable, Codable {
  case delivery = "Delivery"
  case clickAndCollect = "Click and collect"
  case pickup = "Pickup"
  case internalHandoff = "Internal handoff"
  case noPreference = "No preference"

  var id: String { rawValue }
}

enum VendorRiskLevel: String, CaseIterable, Identifiable, Hashable, Codable {
  case low = "Low"
  case medium = "Medium"
  case high = "High"
  case critical = "Critical"

  var id: String { rawValue }
}

enum ShipmentRiskLevel: String, CaseIterable, Identifiable, Hashable, Codable {
  case low = "Low"
  case medium = "Medium"
  case high = "High"
  case critical = "Critical"

  var id: String { rawValue }
}

enum DeliveryInstructionType: String, CaseIterable, Identifiable, Hashable, Codable {
  case deliveryWindow = "Delivery window"
  case accessConstraint = "Access constraint"
  case carrierNote = "Carrier note"
  case handling = "Handling"
  case security = "Security"
  case contactRequired = "Contact required"

  var id: String { rawValue }
}

enum PackageItemCategory: String, CaseIterable, Identifiable, Hashable, Codable {
  case officeSupplies = "Office supplies"
  case electronics = "Electronics"
  case furniture = "Furniture"
  case samples = "Samples"
  case documents = "Documents"
  case apparel = "Apparel"
  case other = "Other"

  var id: String { rawValue }
}

enum PackageValueBand: String, CaseIterable, Identifiable, Hashable, Codable {
  case low = "Low value"
  case medium = "Medium value"
  case high = "High value"
  case critical = "Critical value"
  case unknown = "Unknown value"

  var id: String { rawValue }
}

enum PackageVerificationStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notVerified = "Not verified"
  case partiallyVerified = "Partially verified"
  case verified = "Verified"
  case discrepancy = "Discrepancy"
  case blocked = "Blocked"

  var id: String { rawValue }
}

enum CostCategory: String, CaseIterable, Identifiable, Hashable, Codable {
  case orderCost = "Order cost"
  case shipping = "Shipping"
  case taxGST = "Tax/GST"
  case reimbursement = "Reimbursement"
  case adjustment = "Adjustment"
  case serviceFee = "Service fee"
  case other = "Other"

  var id: String { rawValue }
}

enum ReimbursementStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case notRequired = "Not required"
  case notSubmitted = "Not submitted"
  case pending = "Pending"
  case reimbursed = "Reimbursed"
  case disputed = "Disputed"

  var id: String { rawValue }
}

enum CostApprovalStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case pendingApproval = "Pending approval"
  case approved = "Approved"
  case rejected = "Rejected"
  case needsReview = "Needs review"

  var id: String { rawValue }
}

enum ReturnClaimType: String, CaseIterable, Identifiable, Hashable, Codable {
  case returnRequest = "Return request"
  case exchange = "Exchange"
  case refund = "Refund"
  case damageClaim = "Damage claim"
  case missingItemClaim = "Missing item claim"
  case carrierClaim = "Carrier claim"

  var id: String { rawValue }
}

enum ReturnClaimOutcome: String, CaseIterable, Identifiable, Hashable, Codable {
  case returnGoods = "Return goods"
  case replacement = "Replacement"
  case refund = "Refund"
  case credit = "Credit"
  case carrierInvestigation = "Carrier investigation"
  case noAction = "No action"

  var id: String { rawValue }
}

enum ReturnClaimStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case readyToSubmit = "Ready to submit"
  case submitted = "Submitted"
  case approved = "Approved"
  case disputed = "Disputed"
  case resolved = "Resolved"
  case blocked = "Blocked"

  var id: String { rawValue }
}

enum ProcurementApprovalStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case pendingApproval = "Pending approval"
  case approved = "Approved"
  case rejected = "Rejected"
  case needsReview = "Needs review"

  var id: String { rawValue }
}

enum ProcurementStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case requested = "Requested"
  case approvedToOrder = "Approved to order"
  case ordered = "Ordered"
  case received = "Received"
  case blocked = "Blocked"
  case cancelled = "Cancelled"

  var id: String { rawValue }
}

enum ReceivingInspectionType: String, CaseIterable, Identifiable, Hashable, Codable {
  case inbound = "Inbound"
  case packageCondition = "Package condition"
  case quantityCheck = "Quantity check"
  case returnInspection = "Return inspection"
  case procurementReceipt = "Procurement receipt"
  case exceptionReview = "Exception review"

  var id: String { rawValue }
}

enum ReceivingInspectionStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case pending = "Pending"
  case inspected = "Inspected"
  case discrepancy = "Discrepancy"
  case resolved = "Resolved"
  case blocked = "Blocked"

  var id: String { rawValue }
}

enum ReceivingDiscrepancyType: String, CaseIterable, Identifiable, Hashable, Codable {
  case none = "None"
  case quantityMismatch = "Quantity mismatch"
  case damaged = "Damaged"
  case wrongItem = "Wrong item"
  case missingItem = "Missing item"
  case documentationMissing = "Documentation missing"
  case other = "Other"

  var id: String { rawValue }
}

enum ImportSourceType: String, CaseIterable, Identifiable, Hashable, Codable {
  case forwardedEmail = "Forwarded email"
  case manualEntry = "Manual entry"
  case pdf = "PDF"
  case screenshot = "Screenshot"
  case watchedFolder = "Watched folder"
  case supplierPortal = "Supplier portal"
  case shopify = "Shopify"

  var id: String { rawValue }
}

enum ImportStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case staged = "Staged"
  case linked = "Linked"
  case accepted = "Accepted"
  case ignored = "Ignored"
  case blocked = "Blocked"
  case reopened = "Reopened"

  var id: String { rawValue }
}

enum ImportConfidenceRange: String, CaseIterable, Identifiable, Hashable {
  case all = "All confidence"
  case low = "Low"
  case medium = "Medium"
  case high = "High"

  var id: String { rawValue }
}

enum AcceptanceSourceType: String, CaseIterable, Identifiable, Hashable, Codable {
  case importQueueItem = "Import queue item"
  case intakeEmail = "Forwarded intake email"

  var id: String { rawValue }
}

enum AcceptanceDecision: String, CaseIterable, Identifiable, Hashable, Codable {
  case ready = "Ready"
  case accepted = "Accepted"
  case ignored = "Ignored"
  case reopened = "Reopened"
  case blocked = "Blocked"

  var id: String { rawValue }
}

enum AcceptanceGrouping: String, CaseIterable, Identifiable, Hashable {
  case confidence = "Confidence"
  case linkedOrder = "Linked order"
  case shipmentGroup = "Shipment group"
  case reviewState = "Review state"

  var id: String { rawValue }
}

enum TimelineEntityType: String, CaseIterable, Identifiable, Hashable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case reviewTask = "Review task"
  case handoffNote = "Handoff note"
  case slaPolicy = "SLA policy"
  case communicationTemplate = "Communication template"
  case draftMessage = "Draft message"
  case contact = "Contact"
  case customerProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case account = "Account"
  case vendorProfile = "Vendor profile"
  case integration = "Integration"
  case shipmentGroup = "Shipment group"
  case importQueueItem = "Import queue item"
  case acceptanceRecord = "Acceptance record"
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
  case shipmentGroup = "Shipment group"
  case importQueue = "Import queue"
  case acceptance = "Acceptance"
  case automation = "Automation"
  case search = "Search"
  case audit = "Audit"

  var id: String { rawValue }
}

enum WorkbenchSource: String, CaseIterable, Identifiable, Hashable {
  case reviewTask = "Review task"
  case handoffNote = "Handoff note"
  case intakeEmail = "Forwarded email"
  case intakeParser = "Intake parser"
  case spaceMailIntake = "SpaceMail intake"
  case gmailIntake = "Gmail intake"
  case importQueue = "Import queue"
  case acceptanceReview = "Acceptance review"
  case reconciliation = "Reconciliation"
  case validation = "Validation"
  case shipmentGroup = "Shipment group"
  case tracking = "Tracking"
  case evidence = "Evidence"
  case slaPolicy = "SLA policy"
  case exceptionPlaybook = "Exception playbook"
  case draftMessage = "Draft message"
  case contact = "Contact"
  case customerProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case account = "Account"
  case vendorProfile = "Vendor profile"
  case mailboxProviderGate = "Mailbox provider gate"
  case setupPlaceholder = "Setup placeholder"

  var id: String { rawValue }
}

enum ValidationEntityType: String, CaseIterable, Identifiable, Hashable {
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingNumber = "Tracking number"
  case destinationAddress = "Destination address"
  case vendorProfileMatch = "Vendor/profile match"
  case accountPlaceholder = "Account placeholder"
  case contactSuggestion = "Contact suggestion"

  var id: String { rawValue }
}

enum ValidationSeverity: String, CaseIterable, Identifiable, Hashable {
  case info = "Info"
  case warning = "Warning"
  case high = "High"
  case critical = "Critical"

  var id: String { rawValue }
}

enum ValidationStatus: String, CaseIterable, Identifiable, Hashable {
  case valid = "Valid"
  case incomplete = "Incomplete"
  case conflict = "Conflict"
  case lowConfidence = "Low confidence"
  case duplicate = "Duplicate"
  case staleReview = "Stale review"
  case needsCorrection = "Needs correction"

  var id: String { rawValue }
}

enum ReconciliationIssueType: String, CaseIterable, Identifiable, Hashable, Codable {
  case missingLink = "Missing link"
  case orderNumberConflict = "Order number conflict"
  case trackingNumberConflict = "Tracking number conflict"
  case destinationConflict = "Destination conflict"
  case duplicateStagedRecord = "Duplicate staged record"
  case acceptedWithoutOrder = "Accepted without order"
  case shipmentGroupMissingPrimary = "Shipment group missing primary"

  var id: String { rawValue }
}

enum ReconciliationEntityType: String, CaseIterable, Identifiable, Hashable {
  case intakeEmail = "Intake email"
  case importQueueItem = "Import queue item"
  case acceptanceRecord = "Acceptance record"
  case order = "Order"
  case shipmentGroup = "Shipment group"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case validationIssue = "Validation issue"

  var id: String { rawValue }
}

enum AccountLinkedEntityType: String, CaseIterable, Identifiable, Hashable, Codable {
  case store = "Store"
  case supplier = "Supplier"
  case carrier = "Carrier"
  case shopifyStore = "Shopify store"
  case internalTeam = "Internal team"
  case contact = "Contact"
  case customerProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
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
  case customerProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case order = "Order"
  case intakeEmail = "Intake email"
  case trackingEvent = "Tracking event"
  case evidence = "Evidence"
  case reviewTask = "Review task"
  case slaPolicy = "SLA policy"
  case exceptionPlaybook = "Exception playbook"
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
  case handoffNote = "Handoff note"
  case slaPolicy = "SLA policy"
  case exceptionPlaybook = "Exception playbook"
  case draftMessage = "Draft message"
  case contact = "Contact"
  case customerProfile = "Customer profile"
  case destinationAddress = "Destination address"
  case deliveryInstruction = "Delivery instruction"
  case packageContent = "Package content"
  case costRecord = "Cost record"
  case returnClaim = "Return/claim"
  case procurementRequest = "Procurement request"
  case receivingInspection = "Receiving inspection"
  case inventoryReceipt = "Inventory receipt"
  case storageLocation = "Storage location"
  case custodyRecord = "Custody record"
  case labelReference = "Label reference"
  case scanSession = "Scan session"
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case account = "Account"
  case vendorProfile = "Vendor profile"
  case integration = "Integration"
  case shipmentGroup = "Shipment group"
  case importQueueItem = "Import queue item"
  case acceptanceRecord = "Acceptance record"
  case wishlistItem = "Wishlist item"
  case reconciliationIssue = "Reconciliation issue"

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

enum InventoryReceiptType: String, CaseIterable, Identifiable, Hashable, Codable {
  case stockReceipt = "Stock receipt"
  case teamHandoff = "Team handoff"
  case returnReceipt = "Return receipt"
  case replacementReceipt = "Replacement receipt"
  case sampleReceipt = "Sample receipt"
  case exceptionReceipt = "Exception receipt"

  var id: String { rawValue }
}

enum InventoryStockHandoffStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case pending = "Pending"
  case stocked = "Stocked"
  case handedOff = "Handed off"
  case partiallyAccepted = "Partially accepted"
  case rejected = "Rejected"
  case needsReview = "Needs review"

  var id: String { rawValue }
}

enum StorageLocationType: String, CaseIterable, Identifiable, Hashable, Codable {
  case shelf = "Shelf"
  case bin = "Bin"
  case cage = "Cage"
  case desk = "Desk"
  case locker = "Locker"
  case handoffArea = "Handoff area"
  case stagingArea = "Staging area"

  var id: String { rawValue }
}

enum CustodyStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case pendingTransfer = "Pending transfer"
  case transferred = "Transferred"
  case received = "Received"
  case returnedClosed = "Returned/closed"
  case disputed = "Disputed"
  case needsReview = "Needs review"

  var id: String { rawValue }
}

enum CustodyHandoffMethod: String, CaseIterable, Identifiable, Hashable, Codable {
  case directHandoff = "Direct handoff"
  case storageMove = "Storage move"
  case courierHandoff = "Courier handoff"
  case internalCollection = "Internal collection"
  case evidenceReview = "Evidence review"
  case manualUpdate = "Manual update"

  var id: String { rawValue }
}

enum LabelReferenceType: String, CaseIterable, Identifiable, Hashable, Codable {
  case barcode = "Barcode"
  case qrCode = "QR code"
  case trackingLabel = "Tracking label"
  case shelfBinLabel = "Shelf/bin label"
  case returnLabel = "Return label"
  case procurementLabel = "Procurement label"
  case receivingLabel = "Receiving label"
  case inventoryLabel = "Inventory label"
  case custodyLabel = "Custody label"
  case evidenceLabel = "Evidence label"

  var id: String { rawValue }
}

enum LabelReferenceSource: String, CaseIterable, Identifiable, Hashable, Codable {
  case manualPlaceholder = "Manual placeholder"
  case forwardedEmail = "Forwarded email"
  case supplierPortal = "Supplier portal"
  case carrierLabel = "Carrier label"
  case storageLocation = "Storage location"
  case custodyChain = "Custody chain"
  case evidenceRecord = "Evidence record"

  var id: String { rawValue }
}

enum LabelReferenceStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case printedLocally = "Printed locally"
  case scannedVerified = "Scanned/verified"
  case invalidNeedsReview = "Invalid/needs review"
  case missingValue = "Missing value"
  case archived = "Archived"

  var id: String { rawValue }
}

enum ScanPurpose: String, CaseIterable, Identifiable, Hashable, Codable {
  case labelVerification = "Label verification"
  case orderCheck = "Order check"
  case receivingCheck = "Receiving check"
  case inventoryHandoff = "Inventory handoff"
  case custodyTransfer = "Custody transfer"
  case returnClaimCheck = "Return/claim check"
  case evidenceCheck = "Evidence check"

  var id: String { rawValue }
}

enum ScanMethodPlaceholder: String, CaseIterable, Identifiable, Hashable, Codable {
  case manualEntry = "Manual entry"
  case handheldScannerPlaceholder = "Scanner placeholder"
  case cameraPlaceholder = "Camera placeholder"
  case labelReview = "Label review"
  case operatorAttestation = "Operator attestation"

  var id: String { rawValue }
}

enum ScanSessionStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case planned = "Planned"
  case matched = "Matched"
  case mismatchNeedsReview = "Mismatch/needs review"
  case completed = "Completed"
  case reopened = "Reopened"
  case blocked = "Blocked"

  var id: String { rawValue }
}

enum ShipmentManifestType: String, CaseIterable, Identifiable, Hashable, Codable {
  case shipmentManifest = "Shipment manifest"
  case dispatchChecklist = "Dispatch checklist"
  case dispatchBatch = "Dispatch batch"
  case courierHandoff = "Courier handoff"
  case internalDeliveryRun = "Internal delivery run"
  case outboundTransferGroup = "Outbound transfer group"

  var id: String { rawValue }
}

enum ShipmentManifestDispatchStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case prepared = "Prepared"
  case dispatched = "Dispatched"
  case handedOff = "Handed off"
  case blockedNeedsReview = "Blocked/needs review"
  case reopened = "Reopened"

  var id: String { rawValue }
}

enum DispatchChecklistType: String, CaseIterable, Identifiable, Hashable, Codable {
  case manifestReadiness = "Manifest readiness"
  case labelAndScan = "Label and scan"
  case custodyHandoff = "Custody handoff"
  case destinationReview = "Destination review"
  case exceptionClearance = "Exception clearance"
  case outboundTransfer = "Outbound transfer"

  var id: String { rawValue }
}

enum DispatchChecklistStatus: String, CaseIterable, Identifiable, Hashable, Codable {
  case draft = "Draft"
  case ready = "Ready"
  case blockedNeedsReview = "Blocked/needs review"
  case completed = "Completed"
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
