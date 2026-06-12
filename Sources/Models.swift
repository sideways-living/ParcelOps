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
    case .communication: "Communication"
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
    case .dashboard: "Dashboard"
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
    case .communication: "Comms"
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

struct FetchedMailboxMessage: Identifiable, Hashable {
  var id: String { providerMessageID }
  var providerMessageID: String
  var sender: String
  var subject: String
  var receivedDate: String
  var plainTextBodyPreview: String
  var sourceMailboxID: UUID
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
  case reconciliationIssue = "Reconciliation issue"
  case microsoft365MailboxConnection = "Microsoft 365 mailbox"

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
