import SwiftUI

@Observable
final class ParcelOpsStore {
  var searchText = ""
  var selectedStatus: OrderStatus?
  var settings: ParcelOpsSettings {
    didSet {
      settingsRepository.saveSettings(settings)
    }
  }

  var orders: [TrackedOrder]
  var mailEvents: [MailEvent]
  var intakeEmails: [ForwardedEmailIntake]
  var mailboxIngestRecords: [MailboxIngestRecord]
  var mailboxes: [TrackedMailbox]
  var microsoft365MailboxConnections: [Microsoft365MailboxConnection]
  var spaceMailIMAPConnections: [SpaceMailIMAPConnection]
  var gmailMailboxConnections: [GmailMailboxConnection]
  var microsoft365AuthSessionStates: [UUID: Microsoft365AuthSessionState] = [:]
  var gmailAuthSessionStates: [UUID: GmailAuthSessionState] = [:]
  private var activeMicrosoft365AuthAttempts: [UUID: UUID] = [:]
  var shopifyConnections: [ShopifyConnection]
  var watchedFolders: [WatchedFolder]
  var wishlistItems: [WishlistItem]
  var deletedWishlistItems: [WishlistItem]
  var connections: [SourceConnection]
  var auditEvents: [AuditEvent]
  var evidenceAttachments: [EvidenceAttachment]
  var carrierTrackingEvents: [CarrierTrackingEvent]
  var automationRules: [AutomationRule]
  var savedFilters: [SavedFilter]
  var reviewTasks: [ReviewTask]
  var handoffNotes: [HandoffNote]
  var slaPolicies: [SLAPolicy]
  var exceptionPlaybooks: [ExceptionPlaybook]
  var communicationTemplates: [CommunicationTemplate]
  var draftMessages: [DraftMessage]
  var contactDirectoryEntries: [ContactDirectoryEntry]
  var customerRecipientProfiles: [CustomerRecipientProfile]
  var destinationAddresses: [DestinationAddressRecord]
  var deliveryInstructions: [DeliveryInstructionRecord]
  var packageContents: [PackageContentRecord]
  var costRecords: [CostRecord]
  var returnClaims: [ReturnClaimRecord]
  var procurementRequests: [ProcurementRequest]
  var receivingInspections: [ReceivingInspectionRecord]
  var inventoryReceipts: [InventoryReceiptRecord]
  var storageLocations: [StorageLocationRecord]
  var custodyRecords: [CustodyRecord]
  var labelReferenceRecords: [LabelReferenceRecord]
  var scanSessionRecords: [ScanSessionRecord]
  var shipmentManifestRecords: [ShipmentManifestRecord]
  var dispatchReadinessChecklists: [DispatchReadinessChecklist]
  var accountCredentialRecords: [AccountCredentialRecord]
  var vendorProfiles: [VendorProfile]
  var shipmentGroups: [ShipmentGroup]
  var importQueueItems: [ImportQueueItem]
  var acceptanceRecords: [AcceptanceRecord]

  private let orderRepository: OrderRepository
  private let mailEventRepository: MailEventRepository
  private let intakeEmailRepository: IntakeEmailRepository
  private let mailboxIngestRepository: MailboxIngestRepository
  private let integrationRepository: IntegrationRepository
  private let spaceMailIMAPClient: SpaceMailIMAPClient
  private let realSpaceMailIMAPClient: SpaceMailIMAPClient
  private let spaceMailCredentialStore: SpaceMailCredentialStore

  private struct MailboxRelevanceFilterResult {
    var importMessages: [FetchedMailboxMessage]
    var uncertainMessages: [SpaceMailUncertainMessage]
    var filteredMessages: [SpaceMailFilteredMessage]
    var reasonBreakdown: [SpaceMailClassifierReasonCount]
    var filteredExamples: [String]
    var uncertainExamples: [String]
    var filteredNonOrderCount: Int
    var uncertainCount: Int
    var detail: String
  }

  private enum MailboxRelevanceDecision {
    case likelyOrder
    case uncertain
    case nonOrder
  }

  private struct SpaceMailClassifierEvidence {
    var positiveLabels: [String]
    var cautionLabels: [String]
    var nextAction: String
  }
  private let wishlistRepository: WishlistRepository
  private let settingsRepository: SettingsRepository
  private let auditRepository: AuditRepository
  private let evidenceRepository: EvidenceRepository
  private let trackingRepository: TrackingRepository
  private let automationRuleRepository: AutomationRuleRepository
  private let savedFilterRepository: SavedFilterRepository
  private let reviewTaskRepository: ReviewTaskRepository
  private let handoffNoteRepository: HandoffNoteRepository
  private let slaPolicyRepository: SLAPolicyRepository
  private let exceptionPlaybookRepository: ExceptionPlaybookRepository
  private let communicationRepository: CommunicationRepository
  private let contactDirectoryRepository: ContactDirectoryRepository
  private let customerRecipientProfileRepository: CustomerRecipientProfileRepository
  private let destinationAddressRepository: DestinationAddressRepository
  private let deliveryInstructionRepository: DeliveryInstructionRepository
  private let packageContentRepository: PackageContentRepository
  private let costRecordRepository: CostRecordRepository
  private let returnClaimRepository: ReturnClaimRepository
  private let procurementRequestRepository: ProcurementRequestRepository
  private let receivingInspectionRepository: ReceivingInspectionRepository
  private let inventoryReceiptRepository: InventoryReceiptRepository
  private let storageLocationRepository: StorageLocationRepository
  private let custodyRepository: CustodyRepository
  private let labelReferenceRepository: LabelReferenceRepository
  private let scanSessionRepository: ScanSessionRepository
  private let shipmentManifestRepository: ShipmentManifestRepository
  private let dispatchReadinessRepository: DispatchReadinessRepository
  private let accountCredentialRepository: AccountCredentialRepository
  private let vendorProfileRepository: VendorProfileRepository
  private let shipmentGroupRepository: ShipmentGroupRepository
  private let importQueueRepository: ImportQueueRepository
  private let acceptanceRepository: AcceptanceRepository
  private let mailboxIngestionService: MailboxIngestionService
  private let microsoftGraphMailboxClient: MicrosoftGraphMailboxClient
  private let realMicrosoftGraphMailboxClient: MicrosoftGraphMailboxClient
  private let gmailMailboxClient: GmailMailboxClient
  private let realGmailMailboxClient: GmailMailboxClient
  private let gmailAuthClient: GmailAuthClient
  private let realGmailAuthClient: GmailAuthClient
  private let gmailTokenStore: GmailTokenStore
  private let microsoft365GraphTokenProvider: Microsoft365GraphTokenProvider
  private let microsoft365AuthClient: Microsoft365AuthClient
  private let microsoft365RealAuthClient: Microsoft365AuthClient
  private let microsoft365TokenStore: Microsoft365TokenStore
  private let orderMatchingService: OrderMatchingService
  private let shopifySyncService: ShopifySyncService
  private let carrierTrackingService: CarrierTrackingService
  private let parcelExportService: ParcelExportService
  private let workflowTemplateEngine: WorkflowTemplateEngine

  typealias Repository = OrderRepository & MailEventRepository & IntakeEmailRepository & MailboxIngestRepository & IntegrationRepository & WishlistRepository & SettingsRepository & AuditRepository & EvidenceRepository & TrackingRepository & AutomationRuleRepository & SavedFilterRepository & ReviewTaskRepository & HandoffNoteRepository & SLAPolicyRepository & ExceptionPlaybookRepository & CommunicationRepository & ContactDirectoryRepository & CustomerRecipientProfileRepository & DestinationAddressRepository & DeliveryInstructionRepository & PackageContentRepository & CostRecordRepository & ReturnClaimRepository & ProcurementRequestRepository & ReceivingInspectionRepository & InventoryReceiptRepository & StorageLocationRepository & CustodyRepository & LabelReferenceRepository & ScanSessionRepository & ShipmentManifestRepository & DispatchReadinessRepository & AccountCredentialRepository & VendorProfileRepository & ShipmentGroupRepository & ImportQueueRepository & AcceptanceRepository

  init(
    repository: any Repository = JSONParcelOpsRepository(),
    mailboxIngestionService: MailboxIngestionService = MockMailboxIngestionService(),
    spaceMailIMAPClient: SpaceMailIMAPClient = MockSpaceMailIMAPClient(),
    realSpaceMailIMAPClient: SpaceMailIMAPClient = RealSpaceMailIMAPClient(),
    spaceMailCredentialStore: SpaceMailCredentialStore = KeychainSpaceMailCredentialStore(),
    microsoftGraphMailboxClient: MicrosoftGraphMailboxClient = MockMicrosoftGraphMailboxClient(),
    realMicrosoftGraphMailboxClient: MicrosoftGraphMailboxClient = RealMicrosoftGraphMailboxClient(),
    gmailMailboxClient: GmailMailboxClient = MockGmailMailboxClient(),
    realGmailMailboxClient: GmailMailboxClient = RealGmailMailboxClient(),
    gmailAuthClient: GmailAuthClient = MockGmailAuthClient(),
    realGmailAuthClient: GmailAuthClient = GoogleGmailAuthClient(),
    gmailTokenStore: GmailTokenStore = MockGmailTokenStore(),
    microsoft365GraphTokenProvider: Microsoft365GraphTokenProvider = MSALMicrosoft365GraphTokenProvider(),
    microsoft365AuthClient: Microsoft365AuthClient = MockMicrosoft365AuthClient(),
    microsoft365RealAuthClient: Microsoft365AuthClient = MSALMicrosoft365AuthClient(),
    microsoft365TokenStore: Microsoft365TokenStore = MockMicrosoft365TokenStore(),
    orderMatchingService: OrderMatchingService = MockOrderMatchingService(),
    shopifySyncService: ShopifySyncService = MockShopifySyncService(),
    carrierTrackingService: CarrierTrackingService = MockCarrierTrackingService(),
    parcelExportService: ParcelExportService = MockParcelExportService(),
    workflowTemplateEngine: WorkflowTemplateEngine = RuleBasedWorkflowTemplateEngine()
  ) {
    self.orderRepository = repository
    self.mailEventRepository = repository
    self.intakeEmailRepository = repository
    self.mailboxIngestRepository = repository
    self.integrationRepository = repository
    self.spaceMailIMAPClient = spaceMailIMAPClient
    self.realSpaceMailIMAPClient = realSpaceMailIMAPClient
    self.spaceMailCredentialStore = spaceMailCredentialStore
    self.wishlistRepository = repository
    self.settingsRepository = repository
    self.auditRepository = repository
    self.evidenceRepository = repository
    self.trackingRepository = repository
    self.automationRuleRepository = repository
    self.savedFilterRepository = repository
    self.reviewTaskRepository = repository
    self.handoffNoteRepository = repository
    self.slaPolicyRepository = repository
    self.exceptionPlaybookRepository = repository
    self.communicationRepository = repository
    self.contactDirectoryRepository = repository
    self.customerRecipientProfileRepository = repository
    self.destinationAddressRepository = repository
    self.deliveryInstructionRepository = repository
    self.packageContentRepository = repository
    self.costRecordRepository = repository
    self.returnClaimRepository = repository
    self.procurementRequestRepository = repository
    self.receivingInspectionRepository = repository
    self.inventoryReceiptRepository = repository
    self.storageLocationRepository = repository
    self.custodyRepository = repository
    self.labelReferenceRepository = repository
    self.scanSessionRepository = repository
    self.shipmentManifestRepository = repository
    self.dispatchReadinessRepository = repository
    self.accountCredentialRepository = repository
    self.vendorProfileRepository = repository
    self.shipmentGroupRepository = repository
    self.importQueueRepository = repository
    self.acceptanceRepository = repository
    self.mailboxIngestionService = mailboxIngestionService
    self.microsoftGraphMailboxClient = microsoftGraphMailboxClient
    self.realMicrosoftGraphMailboxClient = realMicrosoftGraphMailboxClient
    self.gmailMailboxClient = gmailMailboxClient
    self.realGmailMailboxClient = realGmailMailboxClient
    self.gmailAuthClient = gmailAuthClient
    self.realGmailAuthClient = realGmailAuthClient
    self.gmailTokenStore = gmailTokenStore
    self.microsoft365GraphTokenProvider = microsoft365GraphTokenProvider
    self.microsoft365AuthClient = microsoft365AuthClient
    self.microsoft365RealAuthClient = microsoft365RealAuthClient
    self.microsoft365TokenStore = microsoft365TokenStore
    self.orderMatchingService = orderMatchingService
    self.shopifySyncService = shopifySyncService
    self.carrierTrackingService = carrierTrackingService
    self.parcelExportService = parcelExportService
    self.workflowTemplateEngine = workflowTemplateEngine
    self.orders = repository.loadOrders()
    self.mailEvents = repository.loadMailEvents()
    self.intakeEmails = repository.loadIntakeEmails()
    self.mailboxIngestRecords = repository.loadMailboxIngestRecords()
    self.mailboxes = repository.loadMailboxes()
    self.microsoft365MailboxConnections = repository.loadMicrosoft365MailboxConnections()
    self.spaceMailIMAPConnections = repository.loadSpaceMailIMAPConnections()
    self.gmailMailboxConnections = repository.loadGmailMailboxConnections()
    self.shopifyConnections = repository.loadShopifyConnections()
    self.watchedFolders = repository.loadWatchedFolders()
    self.connections = repository.loadSourceConnections()
    self.wishlistItems = repository.loadWishlistItems()
    self.deletedWishlistItems = repository.loadDeletedWishlistItems()
    self.settings = repository.loadSettings()
    self.auditEvents = repository.loadAuditEvents()
    self.evidenceAttachments = repository.loadEvidenceAttachments()
    self.carrierTrackingEvents = repository.loadCarrierTrackingEvents()
    self.automationRules = repository.loadAutomationRules()
    self.savedFilters = repository.loadSavedFilters()
    self.reviewTasks = repository.loadReviewTasks()
    self.handoffNotes = repository.loadHandoffNotes()
    self.slaPolicies = repository.loadSLAPolicies()
    self.exceptionPlaybooks = repository.loadExceptionPlaybooks()
    self.communicationTemplates = repository.loadCommunicationTemplates()
    self.draftMessages = repository.loadDraftMessages()
    self.contactDirectoryEntries = repository.loadContactDirectoryEntries()
    self.customerRecipientProfiles = repository.loadCustomerRecipientProfiles()
    self.destinationAddresses = repository.loadDestinationAddresses()
    self.deliveryInstructions = repository.loadDeliveryInstructions()
    self.packageContents = repository.loadPackageContents()
    self.costRecords = repository.loadCostRecords()
    self.returnClaims = repository.loadReturnClaims()
    self.procurementRequests = repository.loadProcurementRequests()
    self.receivingInspections = repository.loadReceivingInspections()
    self.inventoryReceipts = repository.loadInventoryReceipts()
    self.storageLocations = repository.loadStorageLocations()
    self.custodyRecords = repository.loadCustodyRecords()
    self.labelReferenceRecords = repository.loadLabelReferenceRecords()
    self.scanSessionRecords = repository.loadScanSessionRecords()
    self.shipmentManifestRecords = repository.loadShipmentManifestRecords()
    self.dispatchReadinessChecklists = repository.loadDispatchReadinessChecklists()
    self.accountCredentialRecords = repository.loadAccountCredentialRecords()
    self.vendorProfiles = repository.loadVendorProfiles()
    self.shipmentGroups = repository.loadShipmentGroups()
    self.importQueueItems = repository.loadImportQueueItems()
    self.acceptanceRecords = repository.loadAcceptanceRecords()
  }

  var activeCount: Int {
    orders.filter { $0.status != .delivered }.count
  }

  var deliveredCount: Int {
    orders.filter { $0.status == .delivered }.count
  }

  var exceptionCount: Int {
    orders.filter { $0.status == .exception || $0.reviewState == .needsReview }.count
  }

  var reviewOrders: [TrackedOrder] {
    orders.filter { $0.status == .exception || $0.reviewState != .accepted }
  }

  var reviewMailEvents: [MailEvent] {
    mailEvents.filter { $0.severity != .info || $0.reviewState != .accepted }
  }

  var reviewIntakeEmails: [ForwardedEmailIntake] {
    intakeEmails.filter { $0.reviewState == .needsReview }
  }

  var intakeParserDiagnostics: [IntakeParserDiagnostic] {
    intakeEmails.compactMap(intakeParserDiagnostic(for:))
      .sorted { lhs, rhs in
        if lhs.severity != rhs.severity {
          return lhs.severity.sortRank > rhs.severity.sortRank
        }
        return lhs.title < rhs.title
      }
  }

  var spaceMailIntakeHealthSummaries: [SpaceMailIntakeHealthSummary] {
    spaceMailIMAPConnections.map(spaceMailIntakeHealthSummary(for:))
  }

  var gmailIntakeHealthSummaries: [GmailIntakeHealthSummary] {
    gmailMailboxConnections.map(gmailIntakeHealthSummary(for:))
  }

  var mailboxProviderComparisonSummary: MailboxProviderComparisonSummary {
    let spaceMailSummaries = spaceMailIntakeHealthSummaries
    let gmailSummaries = gmailIntakeHealthSummaries

    let spaceMailFetched = spaceMailSummaries.reduce(0) { $0 + $1.fetchedCount }
    let spaceMailImported = spaceMailSummaries.reduce(0) { $0 + $1.importedCount }
    let spaceMailFiltered = spaceMailSummaries.reduce(0) { $0 + $1.filteredCount }
    let spaceMailUncertain = spaceMailSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
    let spaceMailParserIssues = spaceMailSummaries.reduce(0) { $0 + $1.parserIssueCount }
    let spaceMailCredentialBlockers = spaceMailIMAPConnections.filter { connection in
      !connection.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        && !connection.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
        && !connection.credentialStorageStatus.localizedCaseInsensitiveContains("Keychain")
    }.count
    let spaceMailSetupBlockers = spaceMailIMAPConnections.isEmpty ? 1 : 0
    let spaceMailBlocked = spaceMailSetupBlockers + spaceMailCredentialBlockers

    let gmailFetched = gmailSummaries.reduce(0) { $0 + $1.fetchedCount }
    let gmailImported = gmailSummaries.reduce(0) { $0 + $1.importedCount }
    let gmailFiltered = gmailSummaries.reduce(0) { $0 + $1.filteredCount }
    let gmailUncertain = gmailSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
    let gmailReadinessBlockers = gmailMailboxConnections.filter { !gmailOAuthReadinessSummary(for: $0).isReady }.count
    let gmailSignedInCount = gmailMailboxConnections.filter { gmailAuthSessionState(for: $0).status == .connected }.count
    let gmailSetupBlockers = gmailMailboxConnections.isEmpty ? 0 : gmailReadinessBlockers + (gmailSignedInCount == 0 ? 1 : 0)

    let spaceMailStatusTitle: String
    let spaceMailDetail: String
    let spaceMailNextAction: String
    let spaceMailTone: String
    if spaceMailIMAPConnections.isEmpty {
      spaceMailStatusTitle = "SpaceMail not configured"
      spaceMailDetail = "Add SpaceMail when the mailbox is hosted by SpaceMail or another IMAP provider."
      spaceMailNextAction = "Add SpaceMail setup and store the password reference in Keychain."
      spaceMailTone = "warning"
    } else if spaceMailCredentialBlockers > 0 {
      spaceMailStatusTitle = "SpaceMail credential needed"
      spaceMailDetail = "\(spaceMailCredentialBlockers) SpaceMail setup\(spaceMailCredentialBlockers == 1 ? "" : "s") still need a usable Keychain credential reference."
      spaceMailNextAction = "Set/check the SpaceMail credential, then run manual read-only refresh."
      spaceMailTone = "attention"
    } else if spaceMailImported > 0 || spaceMailUncertain > 0 || spaceMailParserIssues > 0 {
      spaceMailStatusTitle = "SpaceMail has operator work"
      spaceMailDetail = "\(spaceMailImported) imported, \(spaceMailUncertain) uncertain, and \(spaceMailParserIssues) parser issue\(spaceMailParserIssues == 1 ? "" : "s") across configured SpaceMail mailboxes."
      spaceMailNextAction = "Review Inbox intake, uncertain previews, and parser diagnostics."
      spaceMailTone = "attention"
    } else if spaceMailFiltered > 0 || spaceMailFetched > 0 {
      spaceMailStatusTitle = "SpaceMail filtering is active"
      spaceMailDetail = "\(spaceMailFetched) fetched with \(spaceMailFiltered) filtered non-order message\(spaceMailFiltered == 1 ? "" : "s") kept out of Inbox."
      spaceMailNextAction = "Run manual refresh when new order mail is expected."
      spaceMailTone = "success"
    } else {
      spaceMailStatusTitle = "SpaceMail ready"
      spaceMailDetail = "SpaceMail is configured, but no refresh evidence is active yet."
      spaceMailNextAction = "Run manual read-only SpaceMail refresh from Mailbox Monitor."
      spaceMailTone = "neutral"
    }

    let gmailStatusTitle: String
    let gmailDetail: String
    let gmailNextAction: String
    let gmailTone: String
    if gmailMailboxConnections.isEmpty {
      gmailStatusTitle = "Gmail optional"
      gmailDetail = "Add Gmail only for mailboxes hosted by Gmail or Google Workspace."
      gmailNextAction = "Leave Gmail alone unless an operator needs a Google-hosted mailbox."
      gmailTone = "neutral"
    } else if gmailSetupBlockers > 0 {
      gmailStatusTitle = "Gmail setup or sign-in blocked"
      gmailDetail = "\(gmailSetupBlockers) Gmail blocker\(gmailSetupBlockers == 1 ? "" : "s") need setup, callback, OAuth, or sign-in attention."
      gmailNextAction = "Open Gmail setup, run readiness checks, then test Google sign-in."
      gmailTone = "warning"
    } else if gmailImported > 0 || gmailUncertain > 0 {
      gmailStatusTitle = "Gmail has operator work"
      gmailDetail = "\(gmailImported) imported and \(gmailUncertain) uncertain Gmail message\(gmailUncertain == 1 ? "" : "s") need local review."
      gmailNextAction = "Review Gmail-origin Inbox rows and uncertain Gmail previews."
      gmailTone = "attention"
    } else if gmailFiltered > 0 || gmailFetched > 0 {
      gmailStatusTitle = "Gmail filtering is active"
      gmailDetail = "\(gmailFetched) fetched with \(gmailFiltered) filtered non-order message\(gmailFiltered == 1 ? "" : "s") kept out of Inbox."
      gmailNextAction = "Run manual Gmail refresh only when checking a Google-hosted mailbox."
      gmailTone = "success"
    } else {
      gmailStatusTitle = "Gmail ready for first refresh"
      gmailDetail = "Gmail setup is connected with no current intake evidence."
      gmailNextAction = "Run manual read-only Gmail refresh when needed."
      gmailTone = "neutral"
    }

    let anyProviderConfigured = !spaceMailIMAPConnections.isEmpty || !gmailMailboxConnections.isEmpty
    let anyProviderBlocked = spaceMailBlocked > 0 || gmailSetupBlockers > 0
    let anyOperatorWork = spaceMailImported + gmailImported + spaceMailUncertain + gmailUncertain + spaceMailParserIssues > 0
    let anyRefreshEvidence = spaceMailFetched + gmailFetched + spaceMailFiltered + gmailFiltered > 0

    let recommendedProvider: String
    if !spaceMailIMAPConnections.isEmpty && !gmailMailboxConnections.isEmpty {
      recommendedProvider = "SpaceMail + Gmail"
    } else if !spaceMailIMAPConnections.isEmpty {
      recommendedProvider = "SpaceMail"
    } else if !gmailMailboxConnections.isEmpty {
      recommendedProvider = "Gmail"
    } else {
      recommendedProvider = "Add provider"
    }

    let title: String
    let detail: String
    let tone: String
    var actionItems: [MailboxProviderActionItem] = []
    if !anyProviderConfigured {
      title = "Choose a mailbox provider"
      detail = "SpaceMail and Gmail both feed the same local Inbox intake path, but no provider setup exists yet."
      tone = "warning"
    } else if anyOperatorWork {
      title = "Mailbox intake needs operator review"
      detail = "Provider setup is working enough to surface imported, uncertain, or parser review work."
      tone = "attention"
    } else if anyProviderBlocked {
      title = "Mailbox setup has blockers"
      detail = "At least one configured provider needs credentials, readiness, or sign-in attention before it can be relied on."
      tone = "warning"
    } else if anyRefreshEvidence {
      title = "Mailbox intake is quiet"
      detail = "Manual refresh evidence exists, and current provider filters are keeping non-order mail out of Inbox."
      tone = "success"
    } else {
      title = "Mailbox providers are ready for testing"
      detail = "Provider setup exists, but the next proof point is a manual read-only refresh."
      tone = "neutral"
    }

    if spaceMailIMAPConnections.isEmpty && gmailMailboxConnections.isEmpty {
      actionItems.append(
        MailboxProviderActionItem(
          providerName: "Mailbox",
          title: "Choose SpaceMail or Gmail",
          detail: "Add the provider that hosts the mailbox you want ParcelOps to read manually.",
          priority: "1",
          tone: "warning",
          symbol: "envelope.badge.fill"
        )
      )
    }

    if !spaceMailIMAPConnections.isEmpty {
      if spaceMailCredentialBlockers > 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "SpaceMail",
            title: "Set SpaceMail credential",
            detail: "A Keychain password reference is needed before real IMAP refresh can be relied on.",
            priority: "1",
            tone: "warning",
            symbol: "key.fill"
          )
        )
      } else if spaceMailImported > 0 || spaceMailUncertain > 0 || spaceMailParserIssues > 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "SpaceMail",
            title: "Review SpaceMail intake",
            detail: "Confirm imported rows, uncertain previews, and parser diagnostics before creating orders.",
            priority: "1",
            tone: "attention",
            symbol: "tray.full.fill"
          )
        )
      } else if spaceMailFetched == 0 && spaceMailFiltered == 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "SpaceMail",
            title: "Run first SpaceMail refresh",
            detail: "Use the explicit manual read-only refresh after confirming host, folder, and credential.",
            priority: "2",
            tone: "attention",
            symbol: "arrow.clockwise.circle.fill"
          )
        )
      } else {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "SpaceMail",
            title: "Monitor SpaceMail refreshes",
            detail: "Current evidence is quiet; refresh manually when new order mail is expected.",
            priority: "3",
            tone: "success",
            symbol: "checkmark.seal.fill"
          )
        )
      }
    }

    if !gmailMailboxConnections.isEmpty {
      if gmailSetupBlockers > 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "Gmail",
            title: "Finish Gmail setup",
            detail: "Resolve readiness, callback, OAuth, or sign-in blockers before using real Gmail refresh.",
            priority: "1",
            tone: "warning",
            symbol: "person.crop.circle.badge.exclamationmark.fill"
          )
        )
      } else if gmailImported > 0 || gmailUncertain > 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "Gmail",
            title: "Review Gmail intake",
            detail: "Confirm Gmail-origin Inbox rows and uncertain previews before creating orders.",
            priority: "1",
            tone: "attention",
            symbol: "tray.full.fill"
          )
        )
      } else if gmailFetched == 0 && gmailFiltered == 0 {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "Gmail",
            title: "Run first Gmail refresh",
            detail: "Use the explicit manual read-only Gmail refresh only for Google-hosted mailboxes.",
            priority: "2",
            tone: "attention",
            symbol: "arrow.clockwise.circle.fill"
          )
        )
      } else {
        actionItems.append(
          MailboxProviderActionItem(
            providerName: "Gmail",
            title: "Monitor Gmail refreshes",
            detail: "Current evidence is quiet; refresh manually when checking the Google-hosted mailbox.",
            priority: "3",
            tone: "success",
            symbol: "checkmark.seal.fill"
          )
        )
      }
    }

    return MailboxProviderComparisonSummary(
      title: title,
      detail: detail,
      tone: tone,
      recommendedProvider: recommendedProvider,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Providers", value: "\(spaceMailIMAPConnections.count + gmailMailboxConnections.count)", tone: anyProviderConfigured ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(spaceMailFetched + gmailFetched)", tone: anyRefreshEvidence ? "neutral" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(spaceMailImported + gmailImported)", tone: (spaceMailImported + gmailImported) > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(spaceMailFiltered + gmailFiltered)", tone: (spaceMailFiltered + gmailFiltered) > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(spaceMailUncertain + gmailUncertain)", tone: (spaceMailUncertain + gmailUncertain) > 0 ? "attention" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(spaceMailBlocked + gmailSetupBlockers)", tone: (spaceMailBlocked + gmailSetupBlockers) > 0 ? "warning" : "success")
      ],
      providers: [
        MailboxProviderComparisonItem(
          providerName: "SpaceMail",
          statusTitle: spaceMailStatusTitle,
          detail: spaceMailDetail,
          nextAction: spaceMailNextAction,
          tone: spaceMailTone,
          symbol: "server.rack",
          fetchedCount: spaceMailFetched,
          importedCount: spaceMailImported,
          blockedCount: spaceMailBlocked,
          uncertainCount: spaceMailUncertain
        ),
        MailboxProviderComparisonItem(
          providerName: "Gmail",
          statusTitle: gmailStatusTitle,
          detail: gmailDetail,
          nextAction: gmailNextAction,
          tone: gmailTone,
          symbol: "envelope.badge.shield.half.filled",
          fetchedCount: gmailFetched,
          importedCount: gmailImported,
          blockedCount: gmailSetupBlockers,
          uncertainCount: gmailUncertain
        )
      ],
      actionItems: actionItems.sorted { lhs, rhs in
        if lhs.priority != rhs.priority {
          return lhs.priority < rhs.priority
        }
        return lhs.providerName < rhs.providerName
      }
    )
  }

  var mailboxOperationsHandoffSummary: MailboxOperationsHandoffSummary {
    let comparison = mailboxProviderComparisonSummary
    let spaceMailSummaries = spaceMailIntakeHealthSummaries
    let gmailSummaries = gmailIntakeHealthSummaries

    let importedCount = spaceMailSummaries.reduce(0) { $0 + $1.importedCount }
      + gmailSummaries.reduce(0) { $0 + $1.importedCount }
    let filteredCount = spaceMailSummaries.reduce(0) { $0 + $1.filteredCount }
      + gmailSummaries.reduce(0) { $0 + $1.filteredCount }
    let duplicateCount = spaceMailSummaries.reduce(0) { $0 + $1.duplicateCount }
      + gmailSummaries.reduce(0) { $0 + $1.duplicateCount }
    let uncertainCount = spaceMailSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
      + gmailSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
    let parserIssueCount = intakeParserDiagnostics.count
    let linkedOrderCount = intakeEmails.filter { $0.linkedOrderID != nil }.count
    var unresolvedIntakeCount = 0
    for email in intakeEmails where email.reviewState != .reviewed && email.reviewState != .ignored {
      unresolvedIntakeCount += 1
    }
    let providerBlockers = comparison.providers.reduce(0) { $0 + $1.blockedCount }
    let latestDates = (spaceMailSummaries.map(\.lastRefreshDate) + gmailSummaries.map(\.lastRefreshDate))
      .filter { !$0.isEmpty && $0 != "Never" }
    let lastEvidenceText = latestDates.first ?? "No real mailbox refresh evidence yet"

    var lines: [MailboxOperationsHandoffLine] = []
    if providerBlockers > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Provider setup blockers",
          detail: "\(providerBlockers) setup, credential, readiness, or sign-in blocker\(providerBlockers == 1 ? "" : "s") should be resolved before relying on live mailbox intake.",
          tone: "warning",
          symbol: "exclamationmark.triangle.fill"
        )
      )
    }
    if importedCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Imported intake ready",
          detail: "\(importedCount) imported message\(importedCount == 1 ? "" : "s") should be reviewed in Inbox and linked or converted to orders.",
          tone: "attention",
          symbol: "tray.full.fill"
        )
      )
    }
    if uncertainCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Uncertain mailbox previews",
          detail: "\(uncertainCount) uncertain mixed-mailbox preview\(uncertainCount == 1 ? "" : "s") remain out of Inbox until an operator imports or dismisses them.",
          tone: "attention",
          symbol: "questionmark.folder.fill"
        )
      )
    }
    if parserIssueCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Parser review needed",
          detail: "\(parserIssueCount) local parser diagnostic\(parserIssueCount == 1 ? "" : "s") should be checked before trusting detected order, tracking, or destination fields.",
          tone: "attention",
          symbol: "doc.text.magnifyingglass"
        )
      )
    }
    if unresolvedIntakeCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Inbox triage still open",
          detail: "\(unresolvedIntakeCount) intake row\(unresolvedIntakeCount == 1 ? "" : "s") remain open or need review in primary Inbox triage.",
          tone: "attention",
          symbol: "envelope.open.fill"
        )
      )
    }
    if linkedOrderCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Inbox-to-order trail exists",
          detail: "\(linkedOrderCount) intake row\(linkedOrderCount == 1 ? "" : "s") already link to local order context.",
          tone: "success",
          symbol: "shippingbox.fill"
        )
      )
    }
    if filteredCount > 0 || duplicateCount > 0 {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "Mailbox noise controlled",
          detail: "\(filteredCount) filtered and \(duplicateCount) duplicate message\(filteredCount + duplicateCount == 1 ? "" : "s") were kept from creating duplicate Inbox work.",
          tone: "success",
          symbol: "line.3.horizontal.decrease.circle.fill"
        )
      )
    }
    if lines.isEmpty {
      lines.append(
        MailboxOperationsHandoffLine(
          title: "No mailbox handoff work",
          detail: "No imported, uncertain, parser, provider, or duplicate mailbox work is currently promoted for operator handoff.",
          tone: "neutral",
          symbol: "checkmark.circle.fill"
        )
      )
    }

    let title: String
    let detail: String
    let tone: String
    if providerBlockers > 0 {
      title = "Mailbox handoff has setup blockers"
      detail = "Resolve provider setup before depending on live intake results."
      tone = "warning"
    } else if importedCount + uncertainCount + parserIssueCount + unresolvedIntakeCount > 0 {
      title = "Mailbox handoff has operator work"
      detail = "Inbox, uncertain review, or parser follow-up should be handled before the next refresh cycle."
      tone = "attention"
    } else if filteredCount + duplicateCount > 0 {
      title = "Mailbox handoff is stable"
      detail = "Recent mailbox activity is mostly filtered or duplicate-safe, with no promoted order work."
      tone = "success"
    } else {
      title = "Mailbox handoff is quiet"
      detail = "Provider setup is ready or optional, and there is no current mailbox work to hand over."
      tone = "neutral"
    }

    return MailboxOperationsHandoffSummary(
      title: title,
      detail: detail,
      tone: tone,
      lastEvidenceText: lastEvidenceText,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Open intake", value: "\(unresolvedIntakeCount)", tone: unresolvedIntakeCount > 0 ? "attention" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount > 0 ? "attention" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Parser", value: "\(parserIssueCount)", tone: parserIssueCount > 0 ? "attention" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(providerBlockers)", tone: providerBlockers > 0 ? "warning" : "success")
      ],
      lines: Array(lines.prefix(6))
    )
  }

  var mailboxProviderQACheckSummary: SpaceMailQACheckSummary {
    let hasSpaceMailSetup = !spaceMailIMAPConnections.isEmpty
    let hasGmailSetup = !gmailMailboxConnections.isEmpty
    let hasSpaceMailCredential = spaceMailIMAPConnections.contains { connection in
      connection.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || connection.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
        || connection.credentialStorageStatus.localizedCaseInsensitiveContains("Keychain")
    }
    let hasGmailConnectedAuth = gmailMailboxConnections.contains { gmailAuthSessionState(for: $0).status == .connected }
    let hasCredentialOrAuth = hasSpaceMailCredential || hasGmailConnectedAuth
    let hasManualRefreshEvidence = spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
    let hasDuplicateEvidence = !mailboxIngestRecords.isEmpty
      || spaceMailIMAPConnections.contains { $0.lastRefreshDuplicateCount > 0 }
      || gmailMailboxConnections.contains { $0.lastRefreshDuplicateCount > 0 }
    let hasMixedFilteringEvidence = spaceMailIMAPConnections.contains { connection in
      connection.mailboxMode == .mixedFiltered
        && (connection.lastRefreshFilteredNonOrderCount > 0
          || !connection.filteredMessages.isEmpty
          || !connection.uncertainMessages.isEmpty
          || !connection.lastRefreshReasonBreakdown.isEmpty)
    } || gmailMailboxConnections.contains { connection in
      connection.mailboxMode == .mixedFiltered
        && (connection.lastRefreshFilteredNonOrderCount > 0
          || connection.filteredMessages?.isEmpty == false
          || connection.uncertainMessages?.isEmpty == false
          || connection.lastRefreshFilteredExamples?.isEmpty == false
          || connection.lastRefreshUncertainExamples?.isEmpty == false)
    }
    let hasReadOnlyAuditEvidence = auditEvents.contains { event in
      let detail = event.afterDetail ?? ""
      return detail.localizedCaseInsensitiveContains("read-only")
        || detail.localizedCaseInsensitiveContains("No mailbox item was deleted")
        || detail.localizedCaseInsensitiveContains("No mailbox items were deleted")
        || detail.localizedCaseInsensitiveContains("No mailbox mutation")
    }
    let hasSecretBoundaryEvidence = auditEvents.contains { event in
      let detail = event.afterDetail ?? ""
      return detail.localizedCaseInsensitiveContains("No password")
        || detail.localizedCaseInsensitiveContains("No token")
        || detail.localizedCaseInsensitiveContains("not stored in JSON")
        || detail.localizedCaseInsensitiveContains("not logged")
    }
    let gmailSetupBlockers = gmailMailboxConnections.filter { !gmailOAuthReadinessSummary(for: $0).isReady }.count
    let providerSplitClear = hasSpaceMailSetup || hasGmailSetup
    let importedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let filteredCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }

    let providerEvidence: String
    if hasSpaceMailSetup && hasGmailSetup {
      providerEvidence = "SpaceMail and Gmail setup records both exist."
    } else if hasSpaceMailSetup {
      providerEvidence = "SpaceMail setup exists; Gmail remains optional unless needed."
    } else if hasGmailSetup {
      providerEvidence = "Gmail setup exists; SpaceMail remains optional unless needed."
    } else {
      providerEvidence = "No SpaceMail or Gmail provider setup exists."
    }

    let checks = [
      SpaceMailQACheck(
        title: "Provider split is explicit",
        detail: "Operators can see whether SpaceMail, Gmail, or both are the active mailbox paths.",
        evidence: providerEvidence,
        isComplete: providerSplitClear,
        tone: providerSplitClear ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Credential or sign-in boundary",
        detail: "A provider has safe credential/sign-in evidence before real refresh is expected to work.",
        evidence: hasCredentialOrAuth ? "SpaceMail credential or Gmail connected auth evidence exists." : "Set SpaceMail Keychain credential or complete Gmail sign-in before real refresh.",
        isComplete: hasCredentialOrAuth,
        tone: hasCredentialOrAuth ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Manual refresh only",
        detail: "Refresh evidence comes from explicit operator action, not background sync.",
        evidence: hasManualRefreshEvidence ? "Manual refresh evidence exists for at least one provider." : "Run one manual provider refresh to prove the boundary.",
        isComplete: hasManualRefreshEvidence,
        tone: hasManualRefreshEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Read-only mailbox boundary",
        detail: "Audit evidence should state that mailbox items are not deleted, moved, marked read, sent, or modified.",
        evidence: hasReadOnlyAuditEvidence ? "Read-only/no-mutation audit evidence exists." : "Run a refresh and confirm Audit records the no-mutation boundary.",
        isComplete: hasReadOnlyAuditEvidence,
        tone: hasReadOnlyAuditEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Secrets stay out of JSON and Audit",
        detail: "Audit evidence should state that passwords, tokens, auth strings, and secret values are not logged or persisted.",
        evidence: hasSecretBoundaryEvidence ? "Secret-boundary audit evidence exists." : "Run credential/sign-in/refresh checks and confirm safe secret-boundary copy appears.",
        isComplete: hasSecretBoundaryEvidence,
        tone: hasSecretBoundaryEvidence ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Duplicate-safe intake",
        detail: "Provider message IDs should prevent duplicate Inbox rows while preserving local refresh metadata.",
        evidence: hasDuplicateEvidence ? "\(mailboxIngestRecords.count) ingest record\(mailboxIngestRecords.count == 1 ? "" : "s") or duplicate refresh evidence exists." : "Run refresh twice against the same mailbox to prove duplicate handling.",
        isComplete: hasDuplicateEvidence,
        tone: hasDuplicateEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Mixed mailbox filtering",
        detail: "Mixed mailboxes should keep non-order messages out of Inbox and surface uncertain messages separately.",
        evidence: hasMixedFilteringEvidence ? "\(filteredCount) filtered and \(importedCount) imported message\(filteredCount + importedCount == 1 ? "" : "s") recorded across providers." : "Run refresh/classifier checks until filtered or uncertain evidence is visible.",
        isComplete: hasMixedFilteringEvidence,
        tone: hasMixedFilteringEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Gmail readiness blockers visible",
        detail: "If Gmail is configured, OAuth/readiness blockers should be visible before relying on Gmail refresh.",
        evidence: !hasGmailSetup ? "Gmail is not configured, so no Gmail blockers apply." : "\(gmailSetupBlockers) Gmail readiness blocker\(gmailSetupBlockers == 1 ? "" : "s") currently visible.",
        isComplete: !hasGmailSetup || gmailSetupBlockers == 0,
        tone: !hasGmailSetup || gmailSetupBlockers == 0 ? "success" : "warning"
      )
    ]

    let completedCount = checks.filter(\.isComplete).count
    let verdict: String
    let tone: String
    if completedCount == checks.count {
      verdict = "Mailbox provider QA boundaries complete"
      tone = "success"
    } else if completedCount >= 6 {
      verdict = "Mailbox provider QA boundaries mostly ready"
      tone = "attention"
    } else {
      verdict = "Mailbox provider QA boundaries need review"
      tone = "warning"
    }

    return SpaceMailQACheckSummary(
      verdict: verdict,
      detail: "\(completedCount) of \(checks.count) provider boundary checks are complete for SpaceMail/Gmail intake.",
      completedCount: completedCount,
      totalCount: checks.count,
      tone: tone,
      checks: checks
    )
  }

  var mailboxIntakeQualitySummary: SpaceMailQACheckSummary {
    let totalIntakeCount = intakeEmails.count
    let openReviewCount = intakeEmails.filter { $0.reviewState == .needsReview }.count
    let reviewedCount = intakeEmails.filter { $0.reviewState == .reviewed }.count
    let ignoredCount = intakeEmails.filter { $0.reviewState == .ignored }.count
    let linkedOrderCount = intakeEmails.filter { $0.linkedOrderID != nil }.count
    let parserIssueCount = intakeParserDiagnostics.count
    let criticalParserIssueCount = intakeParserDiagnostics.filter { $0.severity == .critical || $0.severity == .high }.count
    let intakeIDsWithSourceTrace = Set(mailboxIngestRecords.compactMap(\.intakeEmailID))
    let tracedIntakeCount = intakeEmails.filter { intakeIDsWithSourceTrace.contains($0.id) }.count
    let rowsWithOrderOrTracking = intakeEmails.filter { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue
        || !email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
    let rowsWithOrderAndTracking = intakeEmails.filter { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue
        && !email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
    let rowsWithDestination = intakeEmails.filter { !$0.detectedDestinationAddress.isPlaceholderValidationValue }.count
    let actionableIntakeCount = intakeEmails.filter { email in
      email.reviewState == .needsReview
        && (
          !email.detectedOrderNumber.isPlaceholderValidationValue
            || !email.detectedTrackingNumber.isPlaceholderValidationValue
            || !email.detectedDestinationAddress.isPlaceholderValidationValue
        )
    }.count
    let duplicateTraceCount = mailboxIngestRecords.count
    let allOpenRowsHaveSignals = openReviewCount == 0 || actionableIntakeCount > 0
    let reviewQueueControlled = openReviewCount <= max(3, totalIntakeCount / 2)
    let parserIssuesControlled = criticalParserIssueCount == 0

    let checks = [
      SpaceMailQACheck(
        title: "Intake rows exist",
        detail: "Mailbox imports should create local ForwardedEmailIntake rows before the operator workflow can be judged.",
        evidence: totalIntakeCount > 0 ? "\(totalIntakeCount) intake row\(totalIntakeCount == 1 ? "" : "s") captured." : "No intake rows are captured yet.",
        isComplete: totalIntakeCount > 0,
        tone: totalIntakeCount > 0 ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Provider source trace",
        detail: "Imported rows should retain local ingest metadata so duplicate refreshes can update or skip safely.",
        evidence: tracedIntakeCount > 0 ? "\(tracedIntakeCount) intake row\(tracedIntakeCount == 1 ? "" : "s") linked to provider ingest metadata." : "No intake rows have provider ingest trace yet.",
        isComplete: tracedIntakeCount > 0,
        tone: tracedIntakeCount > 0 ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Order or tracking signals",
        detail: "At least some intake rows should expose detected order or tracking fields before create-order handoff.",
        evidence: rowsWithOrderOrTracking > 0 ? "\(rowsWithOrderOrTracking) row\(rowsWithOrderOrTracking == 1 ? "" : "s") include order or tracking signals; \(rowsWithOrderAndTracking) include both." : "No intake rows currently expose an order or tracking signal.",
        isComplete: rowsWithOrderOrTracking > 0,
        tone: rowsWithOrderOrTracking > 0 ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Destination signal",
        detail: "Destination extraction is not always required, but visible destination evidence makes handoff safer.",
        evidence: rowsWithDestination > 0 ? "\(rowsWithDestination) row\(rowsWithDestination == 1 ? "" : "s") include destination signal." : "No destination signal is detected in current intake rows.",
        isComplete: rowsWithDestination > 0,
        tone: rowsWithDestination > 0 ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Open rows are actionable",
        detail: "Rows needing review should contain at least one useful local signal, not only generic or empty mailbox text.",
        evidence: allOpenRowsHaveSignals ? "\(actionableIntakeCount) open row\(actionableIntakeCount == 1 ? "" : "s") contain detected order, tracking, or destination context." : "\(openReviewCount) open row\(openReviewCount == 1 ? "" : "s") need review but no actionable signal was detected.",
        isComplete: allOpenRowsHaveSignals,
        tone: allOpenRowsHaveSignals ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Review state controlled",
        detail: "The primary Inbox should not be overwhelmed by old unresolved intake rows.",
        evidence: "\(openReviewCount) needs review, \(reviewedCount) reviewed, \(ignoredCount) ignored.",
        isComplete: reviewQueueControlled,
        tone: reviewQueueControlled ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Inbox-to-order linkage",
        detail: "At least one intake row should link to a local order before calling the intake workflow ready.",
        evidence: linkedOrderCount > 0 ? "\(linkedOrderCount) intake row\(linkedOrderCount == 1 ? "" : "s") linked to local orders." : "No intake row is linked to an order yet.",
        isComplete: linkedOrderCount > 0,
        tone: linkedOrderCount > 0 ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Parser diagnostics controlled",
        detail: "High-severity parser diagnostics should be handled before relying on automated order/tracking extraction.",
        evidence: "\(parserIssueCount) parser diagnostic\(parserIssueCount == 1 ? "" : "s"); \(criticalParserIssueCount) high priority.",
        isComplete: parserIssuesControlled,
        tone: parserIssuesControlled ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Duplicate metadata retained",
        detail: "Provider message IDs should remain available so repeated refreshes do not create duplicate Inbox work.",
        evidence: duplicateTraceCount > 0 ? "\(duplicateTraceCount) ingest metadata record\(duplicateTraceCount == 1 ? "" : "s") retained." : "No ingest metadata is retained yet.",
        isComplete: duplicateTraceCount > 0,
        tone: duplicateTraceCount > 0 ? "success" : "attention"
      )
    ]

    let completedCount = checks.filter(\.isComplete).count
    let verdict: String
    let tone: String
    if completedCount == checks.count {
      verdict = "Mailbox intake quality is ready"
      tone = "success"
    } else if completedCount >= 6 {
      verdict = "Mailbox intake quality is usable with review"
      tone = "attention"
    } else {
      verdict = "Mailbox intake quality needs attention"
      tone = "warning"
    }

    return SpaceMailQACheckSummary(
      verdict: verdict,
      detail: "\(completedCount) of \(checks.count) intake quality checks are complete across captured mailbox rows.",
      completedCount: completedCount,
      totalCount: checks.count,
      tone: tone,
      checks: checks
    )
  }

  var spaceMailRefreshTrendSummary: SpaceMailRefreshTrendSummary {
    let historyPairs = spaceMailIMAPConnections.flatMap { connection in
      connection.refreshHistory.map { entry in
        (connection.displayName, entry)
      }
    }
    let recentPairs = Array(historyPairs.prefix(12))
    let fetchedCount = recentPairs.reduce(0) { $0 + $1.1.fetchedCount }
    let importedCount = recentPairs.reduce(0) { $0 + $1.1.importedCount }
    let duplicateCount = recentPairs.reduce(0) { $0 + $1.1.duplicateCount }
    let filteredCount = recentPairs.reduce(0) { $0 + $1.1.filteredNonOrderCount }
    let uncertainCount = recentPairs.reduce(0) { $0 + $1.1.uncertainCount }
    let successCount = recentPairs.filter { pair in
      pair.1.status.localizedCaseInsensitiveContains("success")
        || pair.1.status.localizedCaseInsensitiveContains("completed")
        || pair.1.status.localizedCaseInsensitiveContains("duplicate")
    }.count
    let actionableCount = importedCount + uncertainCount

    let title: String
    let detail: String
    let tone: String
    if spaceMailIMAPConnections.isEmpty {
      title = "No SpaceMail refresh trend yet"
      detail = "Add a SpaceMail setup before trend evidence can appear."
      tone = "warning"
    } else if recentPairs.isEmpty {
      title = "SpaceMail refresh trend pending"
      detail = "Run manual refreshes to build a local trend across imports, duplicates, filtered messages, and uncertain reviews."
      tone = "attention"
    } else if actionableCount > 0 {
      title = "SpaceMail refresh trend has actionable intake"
      detail = "\(recentPairs.count) recent refresh event\(recentPairs.count == 1 ? "" : "s") include \(importedCount) import\(importedCount == 1 ? "" : "s") and \(uncertainCount) uncertain preview\(uncertainCount == 1 ? "" : "s")."
      tone = "attention"
    } else if filteredCount > 0 && importedCount == 0 {
      title = "SpaceMail filter trend is stable"
      detail = "\(recentPairs.count) recent refresh event\(recentPairs.count == 1 ? "" : "s") mostly filtered non-order mail from the mixed mailbox."
      tone = "success"
    } else {
      title = "SpaceMail refresh trend is quiet"
      detail = "\(recentPairs.count) recent refresh event\(recentPairs.count == 1 ? "" : "s") found no current Inbox intake."
      tone = "neutral"
    }

    let entries = recentPairs.prefix(6).map { pair in
      SpaceMailRefreshTrendEntry(
        id: pair.1.id,
        timestamp: pair.1.timestamp,
        displayName: pair.0,
        status: pair.1.status,
        detail: "\(pair.1.fetchedCount) fetched, \(pair.1.importedCount) imported, \(pair.1.duplicateCount) duplicates, \(pair.1.filteredNonOrderCount) filtered, \(pair.1.uncertainCount) uncertain.",
        tone: pair.1.importedCount > 0 || pair.1.uncertainCount > 0 ? "attention" : (pair.1.filteredNonOrderCount > 0 ? "success" : "neutral")
      )
    }

    return SpaceMailRefreshTrendSummary(
      title: title,
      detail: detail,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Runs", value: "\(recentPairs.count)", tone: recentPairs.isEmpty ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Successful", value: "\(successCount)", tone: successCount == recentPairs.count && !recentPairs.isEmpty ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(fetchedCount)", tone: "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Duplicates", value: "\(duplicateCount)", tone: duplicateCount > 0 ? "neutral" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount > 0 ? "attention" : "success")
      ],
      entries: entries
    )
  }

  var spaceMailShiftHandoffSummary: SpaceMailShiftHandoffSummary {
    let spaceMailMailboxIDs = Set(spaceMailIMAPConnections.map(\.id))
    let spaceMailIngestRecords = mailboxIngestRecords.filter { spaceMailMailboxIDs.contains($0.sourceMailboxID) }
    let linkedIntakeIDs = Set(spaceMailIngestRecords.compactMap(\.intakeEmailID))
    let linkedSpaceMailIntake = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }
    let reviewSpaceMailIntake = linkedSpaceMailIntake.filter { $0.reviewState == .needsReview }
    let linkedOrders = orders.filter { order in
      linkedSpaceMailIntake.contains { $0.linkedOrderID == order.id } || order.source == .forwardedMailbox || order.checkedMailbox == "manual-import"
    }
    let parserDiagnostics = intakeParserDiagnostics.filter { linkedIntakeIDs.contains($0.intakeEmailID) }
    let uncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
    let filteredCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count }
    let fetchedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let importedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let duplicateCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshDuplicateCount }
    let filteredLastRefreshCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let uncertainLastRefreshCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshUncertainCount }
    let latestRefresh = spaceMailIMAPConnections
      .filter { $0.lastManualRefreshDate != "Never" }
      .sorted { $0.lastManualRefreshDate > $1.lastManualRefreshDate }
      .first
    let lastRefreshText = latestRefresh.map {
      "\($0.displayName) refreshed \($0.lastManualRefreshDate): \($0.lastRefreshSummary.isEmpty ? $0.connectionStatus : $0.lastRefreshSummary)"
    } ?? "No real SpaceMail refresh has been recorded."

    let lines = [
      SpaceMailShiftHandoffLine(
        title: "Latest refresh",
        detail: "\(fetchedCount) fetched, \(importedCount) imported, \(duplicateCount) duplicates, \(filteredLastRefreshCount) filtered, \(uncertainLastRefreshCount) uncertain.",
        tone: fetchedCount == 0 ? "attention" : "neutral",
        symbol: "clock.arrow.circlepath"
      ),
      SpaceMailShiftHandoffLine(
        title: "Inbox review",
        detail: reviewSpaceMailIntake.isEmpty
          ? "No SpaceMail-linked intake rows currently need review."
          : "\(reviewSpaceMailIntake.count) SpaceMail-linked intake row\(reviewSpaceMailIntake.count == 1 ? "" : "s") need review.",
        tone: reviewSpaceMailIntake.isEmpty ? "success" : "attention",
        symbol: "tray.full.fill"
      ),
      SpaceMailShiftHandoffLine(
        title: "Parser checks",
        detail: parserDiagnostics.isEmpty
          ? "No SpaceMail-linked parser diagnostics are open."
          : "\(parserDiagnostics.count) parser diagnostic\(parserDiagnostics.count == 1 ? "" : "s") need field confirmation.",
        tone: parserDiagnostics.isEmpty ? "success" : "warning",
        symbol: "text.magnifyingglass"
      ),
      SpaceMailShiftHandoffLine(
        title: "Mixed mailbox review",
        detail: uncertainCount == 0 && filteredCount == 0
          ? "No uncertain or filtered preview reviews are waiting."
          : "\(uncertainCount) uncertain and \(filteredCount) filtered preview\(uncertainCount + filteredCount == 1 ? "" : "s") are available for spot review.",
        tone: uncertainCount > 0 ? "attention" : "neutral",
        symbol: "questionmark.folder.fill"
      ),
      SpaceMailShiftHandoffLine(
        title: "Order handoff",
        detail: linkedOrders.isEmpty
          ? "No SpaceMail/InBox-created orders are currently linked for follow-up."
          : "\(linkedOrders.count) Inbox-created or SpaceMail-linked order\(linkedOrders.count == 1 ? "" : "s") exist for follow-up.",
        tone: linkedOrders.isEmpty ? "neutral" : "attention",
        symbol: "shippingbox.fill"
      )
    ]

    let openLineCount = lines.filter { $0.tone == "warning" || $0.tone == "attention" }.count
    let title: String
    let detail: String
    let tone: String
    if spaceMailIMAPConnections.isEmpty {
      title = "SpaceMail handoff unavailable"
      detail = "Add a SpaceMail setup before using the handoff summary."
      tone = "warning"
    } else if openLineCount == 0 {
      title = "SpaceMail handoff is clear"
      detail = "No immediate SpaceMail intake follow-up is open."
      tone = "success"
    } else {
      title = "SpaceMail handoff needs attention"
      detail = "\(openLineCount) handoff area\(openLineCount == 1 ? "" : "s") should be checked before the next shift."
      tone = lines.contains { $0.tone == "warning" } ? "warning" : "attention"
    }

    return SpaceMailShiftHandoffSummary(
      title: title,
      detail: detail,
      tone: tone,
      lastRefreshText: lastRefreshText,
      keyCounts: [
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(fetchedCount)", tone: "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Inbox review", value: "\(reviewSpaceMailIntake.count)", tone: reviewSpaceMailIntake.isEmpty ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Parser", value: "\(parserDiagnostics.count)", tone: parserDiagnostics.isEmpty ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount == 0 ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount == 0 ? "neutral" : "attention")
      ],
      handoffLines: lines
    )
  }

  var spaceMailPostRefreshActionPlan: SpaceMailPostRefreshActionPlan {
    let spaceMailMailboxIDs = Set(spaceMailIMAPConnections.map(\.id))
    let spaceMailIngestRecords = mailboxIngestRecords.filter { spaceMailMailboxIDs.contains($0.sourceMailboxID) }
    let linkedIntakeIDs = Set(spaceMailIngestRecords.compactMap(\.intakeEmailID))
    let linkedSpaceMailIntake = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }
    let reviewSpaceMailIntake = linkedSpaceMailIntake.filter { $0.reviewState == .needsReview }
    let parserDiagnostics = intakeParserDiagnostics.filter { linkedIntakeIDs.contains($0.intakeEmailID) }
    let readyForOrder = reviewSpaceMailIntake.filter { email in
      email.linkedOrderID == nil
        && (!email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue)
    }
    let uncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
    let filteredReviewCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count }
    let latestFetchedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let latestImportedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let latestFilteredCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let latestUncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshUncertainCount }

    let items = [
      SpaceMailPostRefreshActionItem(
        title: "Review imported Inbox rows",
        count: reviewSpaceMailIntake.count,
        detail: reviewSpaceMailIntake.isEmpty
          ? "No SpaceMail intake rows currently need primary Inbox review."
          : "Confirm merchant, order, tracking, and destination before creating or linking orders.",
        actionLabel: reviewSpaceMailIntake.isEmpty ? "No Inbox review needed" : "Open detected order emails",
        tone: reviewSpaceMailIntake.isEmpty ? "success" : "attention",
        symbol: "tray.full.fill"
      ),
      SpaceMailPostRefreshActionItem(
        title: "Fix parser diagnostics",
        count: parserDiagnostics.count,
        detail: parserDiagnostics.isEmpty
          ? "No SpaceMail-linked parser diagnostics are currently blocking the flow."
          : "Reprocess or edit rows where order, tracking, sender, or destination is weak.",
        actionLabel: parserDiagnostics.isEmpty ? "Parser clear" : "Use parser review queue",
        tone: parserDiagnostics.isEmpty ? "success" : "warning",
        symbol: "text.magnifyingglass"
      ),
      SpaceMailPostRefreshActionItem(
        title: "Create or link orders",
        count: readyForOrder.count,
        detail: readyForOrder.isEmpty
          ? "No SpaceMail intake rows look ready for a new linked order right now."
          : "Rows with usable order or tracking details still need an order handoff.",
        actionLabel: readyForOrder.isEmpty ? "No order handoff waiting" : "Create or link orders",
        tone: readyForOrder.isEmpty ? "success" : "attention",
        symbol: "shippingbox.fill"
      ),
      SpaceMailPostRefreshActionItem(
        title: "Review uncertain messages",
        count: uncertainCount,
        detail: uncertainCount == 0
          ? "No ambiguous SpaceMail messages are waiting outside Inbox."
          : "Import true order mail or dismiss/filter messages that should stay out of Inbox.",
        actionLabel: uncertainCount == 0 ? "No uncertain review" : "Review uncertain previews",
        tone: uncertainCount == 0 ? "success" : "attention",
        symbol: "questionmark.folder.fill"
      ),
      SpaceMailPostRefreshActionItem(
        title: "Check filtered examples",
        count: filteredReviewCount,
        detail: filteredReviewCount == 0
          ? "No filtered examples are waiting for manual review."
          : "Spot-check filtered previews if a real order email appears to be missing.",
        actionLabel: filteredReviewCount == 0 ? "No filtered review queued" : "Spot-check filtered previews",
        tone: filteredReviewCount == 0 ? "success" : "neutral",
        symbol: "line.3.horizontal.decrease.circle.fill"
      )
    ]

    let blockingItems = items.filter { $0.tone == "warning" || $0.tone == "attention" }
    let title: String
    let detail: String
    let primaryAction: String
    let tone: String
    if spaceMailIMAPConnections.isEmpty {
      title = "SpaceMail post-refresh actions unavailable"
      detail = "Add a SpaceMail setup before using the refresh workflow."
      primaryAction = "Add SpaceMail placeholder"
      tone = "warning"
    } else if latestFetchedCount == 0 && !spaceMailIMAPConnections.contains(where: { $0.lastManualRefreshDate != "Never" }) {
      title = "SpaceMail ready for first manual refresh"
      detail = "No real refresh evidence is recorded yet. Set or check the credential, then run real refresh."
      primaryAction = "Run real SpaceMail refresh"
      tone = "attention"
    } else if blockingItems.isEmpty {
      title = "SpaceMail post-refresh queue is clear"
      detail = "Latest refresh: \(latestFetchedCount) fetched, \(latestImportedCount) imported, \(latestFilteredCount) filtered, \(latestUncertainCount) uncertain."
      primaryAction = "Wait for new order mail or run another manual refresh"
      tone = "success"
    } else {
      title = "SpaceMail post-refresh actions need review"
      detail = "Latest refresh: \(latestFetchedCount) fetched, \(latestImportedCount) imported, \(latestFilteredCount) filtered, \(latestUncertainCount) uncertain."
      primaryAction = blockingItems.first?.actionLabel ?? "Review Mailbox Monitor"
      tone = blockingItems.contains(where: { $0.tone == "warning" }) ? "warning" : "attention"
    }

    return SpaceMailPostRefreshActionPlan(
      title: title,
      detail: detail,
      tone: tone,
      primaryAction: primaryAction,
      items: items
    )
  }

  var gmailPostRefreshActionPlan: GmailPostRefreshActionPlan {
    let gmailMailboxIDs = Set(gmailMailboxConnections.map(\.id))
    let gmailIngestRecords = mailboxIngestRecords.filter { gmailMailboxIDs.contains($0.sourceMailboxID) }
    let linkedIntakeIDs = Set(gmailIngestRecords.compactMap(\.intakeEmailID))
    let linkedGmailIntake = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }
    let reviewGmailIntake = linkedGmailIntake.filter { $0.reviewState == .needsReview }
    let parserDiagnostics = intakeParserDiagnostics.filter { linkedIntakeIDs.contains($0.intakeEmailID) }
    let readyForOrder = reviewGmailIntake.filter { email in
      email.linkedOrderID == nil
        && (!email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue)
    }
    let uncertainCount = gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) }
    let filteredReviewCount = gmailMailboxConnections.reduce(0) { $0 + ($1.filteredMessages?.count ?? 0) }
    let latestFetchedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let latestImportedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let latestFilteredCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let latestUncertainCount = gmailMailboxConnections.reduce(0) { $0 + ($1.lastRefreshUncertainCount ?? 0) }
    let readinessSummaries = gmailMailboxConnections.map(gmailOAuthReadinessSummary(for:))
    let setupBlockers = readinessSummaries.filter { !$0.isReady }
    let connectedAuthCount = gmailMailboxConnections.filter { gmailAuthSessionState(for: $0).status == .connected }.count
    let setupIssueCount = setupBlockers.count
    let firstSetupBlocker = setupBlockers.first
    let setupBlockerPreview = firstSetupBlocker?.missingFields.prefix(3).joined(separator: ", ")

    let items = [
      GmailPostRefreshActionItem(
        title: "Finish setup and sign-in",
        count: setupIssueCount + max(0, gmailMailboxConnections.count - connectedAuthCount),
        detail: setupIssueCount == 0 && connectedAuthCount > 0
          ? "Gmail setup values, compiled app callback configuration, and sign-in state are ready for manual refresh."
          : "Resolve Gmail setup blockers before real refresh: \(setupBlockerPreview ?? "complete Google sign-in").",
        actionLabel: setupIssueCount == 0 && connectedAuthCount > 0 ? "Setup ready" : "Review Gmail setup",
        tone: setupIssueCount == 0 && connectedAuthCount > 0 ? "success" : "warning",
        symbol: "person.badge.key.fill"
      ),
      GmailPostRefreshActionItem(
        title: "Review imported Inbox rows",
        count: reviewGmailIntake.count,
        detail: reviewGmailIntake.isEmpty
          ? "No Gmail intake rows currently need primary Inbox review."
          : "Confirm merchant, order, tracking, and destination before creating or linking orders.",
        actionLabel: reviewGmailIntake.isEmpty ? "No Inbox review needed" : "Open detected order emails",
        tone: reviewGmailIntake.isEmpty ? "success" : "attention",
        symbol: "tray.full.fill"
      ),
      GmailPostRefreshActionItem(
        title: "Fix parser diagnostics",
        count: parserDiagnostics.count,
        detail: parserDiagnostics.isEmpty
          ? "No Gmail-linked parser diagnostics are currently blocking the flow."
          : "Reprocess or edit Gmail intake rows where order, tracking, sender, or destination is weak.",
        actionLabel: parserDiagnostics.isEmpty ? "Parser clear" : "Use parser review queue",
        tone: parserDiagnostics.isEmpty ? "success" : "warning",
        symbol: "text.magnifyingglass"
      ),
      GmailPostRefreshActionItem(
        title: "Create or link orders",
        count: readyForOrder.count,
        detail: readyForOrder.isEmpty
          ? "No Gmail intake rows look ready for a new linked order right now."
          : "Rows with usable order or tracking details still need an order handoff.",
        actionLabel: readyForOrder.isEmpty ? "No order handoff waiting" : "Create or link orders",
        tone: readyForOrder.isEmpty ? "success" : "attention",
        symbol: "shippingbox.fill"
      ),
      GmailPostRefreshActionItem(
        title: "Review uncertain messages",
        count: uncertainCount,
        detail: uncertainCount == 0
          ? "No ambiguous Gmail messages are waiting outside Inbox."
          : "Import true order mail or dismiss messages that should stay out of Inbox.",
        actionLabel: uncertainCount == 0 ? "No uncertain review" : "Review uncertain previews",
        tone: uncertainCount == 0 ? "success" : "attention",
        symbol: "questionmark.folder.fill"
      ),
      GmailPostRefreshActionItem(
        title: "Check filtered examples",
        count: filteredReviewCount,
        detail: filteredReviewCount == 0
          ? "No filtered Gmail examples are waiting for manual review."
          : "Spot-check filtered previews if a real order email appears to be missing.",
        actionLabel: filteredReviewCount == 0 ? "No filtered review queued" : "Spot-check filtered previews",
        tone: filteredReviewCount == 0 ? "success" : "neutral",
        symbol: "line.3.horizontal.decrease.circle.fill"
      )
    ]

    let blockingItems = items.filter { $0.tone == "warning" || $0.tone == "attention" }
    let title: String
    let detail: String
    let primaryAction: String
    let tone: String
    if gmailMailboxConnections.isEmpty {
      title = "Gmail post-refresh actions unavailable"
      detail = "Add a Gmail setup only when a mailbox is hosted by Gmail or Google Workspace."
      primaryAction = "Add Gmail setup"
      tone = "neutral"
    } else if let firstSetupBlocker {
      title = "Gmail setup blockers need review"
      detail = "\(firstSetupBlocker.statusText). \(firstSetupBlocker.compiledClientIDStatus). \(firstSetupBlocker.compiledCallbackSchemeStatus)."
      primaryAction = "Review Gmail setup"
      tone = "warning"
    } else if latestFetchedCount == 0 && !gmailMailboxConnections.contains(where: { $0.lastManualRefreshDate != "Never" }) {
      title = "Gmail ready for setup checks"
      detail = "No real refresh evidence is recorded yet. Finish setup, test Google sign-in, then run manual read-only refresh."
      primaryAction = blockingItems.first?.actionLabel ?? "Run real Gmail refresh"
      tone = "attention"
    } else if blockingItems.isEmpty {
      title = "Gmail post-refresh queue is clear"
      detail = "Latest refresh: \(latestFetchedCount) fetched, \(latestImportedCount) imported, \(latestFilteredCount) filtered, \(latestUncertainCount) uncertain."
      primaryAction = "Wait for new order mail or run another manual refresh"
      tone = "success"
    } else {
      title = "Gmail post-refresh actions need review"
      detail = "Latest refresh: \(latestFetchedCount) fetched, \(latestImportedCount) imported, \(latestFilteredCount) filtered, \(latestUncertainCount) uncertain."
      primaryAction = blockingItems.first?.actionLabel ?? "Review Mailbox Monitor"
      tone = blockingItems.contains(where: { $0.tone == "warning" }) ? "warning" : "attention"
    }

    return GmailPostRefreshActionPlan(
      title: title,
      detail: detail,
      tone: tone,
      primaryAction: primaryAction,
      items: items
    )
  }

  var gmailShiftHandoffSummary: GmailShiftHandoffSummary {
    let gmailMailboxIDs = Set(gmailMailboxConnections.map(\.id))
    let gmailIngestRecords = mailboxIngestRecords.filter { gmailMailboxIDs.contains($0.sourceMailboxID) }
    let linkedIntakeIDs = Set(gmailIngestRecords.compactMap(\.intakeEmailID))
    let linkedGmailIntake = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }
    let reviewGmailIntake = linkedGmailIntake.filter { $0.reviewState == .needsReview }
    let parserDiagnostics = intakeParserDiagnostics.filter { linkedIntakeIDs.contains($0.intakeEmailID) }
    let uncertainCount = gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) }
    let filteredCount = gmailMailboxConnections.reduce(0) { $0 + ($1.filteredMessages?.count ?? 0) }
    let fetchedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let importedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let duplicateCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshDuplicateCount }
    let filteredLastRefreshCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let uncertainLastRefreshCount = gmailMailboxConnections.reduce(0) { $0 + ($1.lastRefreshUncertainCount ?? 0) }
    let readinessBlockers = gmailMailboxConnections.filter { !gmailOAuthReadinessSummary(for: $0).isReady }.count
    let signedInCount = gmailMailboxConnections.filter { gmailAuthSessionState(for: $0).status == .connected }.count
    let latestRefresh = gmailMailboxConnections
      .filter { $0.lastManualRefreshDate != "Never" }
      .sorted { $0.lastManualRefreshDate > $1.lastManualRefreshDate }
      .first
    let lastRefreshText = latestRefresh.map {
      "\($0.displayName) refreshed \($0.lastManualRefreshDate): \($0.lastRefreshSummary.isEmpty ? $0.connectionStatus : $0.lastRefreshSummary)"
    } ?? "No real Gmail refresh has been recorded."

    let lines = [
      GmailShiftHandoffLine(
        title: "Setup readiness",
        detail: readinessBlockers == 0
          ? "Gmail setup fields and compiled callback checks are clear."
          : "\(readinessBlockers) Gmail setup\(readinessBlockers == 1 ? "" : "s") still have OAuth, callback, scope, or compiled app blockers.",
        tone: readinessBlockers == 0 ? "success" : "warning",
        symbol: "person.badge.key.fill"
      ),
      GmailShiftHandoffLine(
        title: "Google sign-in",
        detail: signedInCount == 0
          ? "No Gmail setup currently has a connected Google sign-in session."
          : "\(signedInCount) Gmail setup\(signedInCount == 1 ? "" : "s") have connected sign-in state for manual read-only refresh.",
        tone: signedInCount > 0 || gmailMailboxConnections.isEmpty ? "success" : "attention",
        symbol: "person.crop.circle.badge.checkmark"
      ),
      GmailShiftHandoffLine(
        title: "Latest refresh",
        detail: "\(fetchedCount) fetched, \(importedCount) imported, \(duplicateCount) duplicates, \(filteredLastRefreshCount) filtered, \(uncertainLastRefreshCount) uncertain.",
        tone: fetchedCount == 0 ? "attention" : "neutral",
        symbol: "clock.arrow.circlepath"
      ),
      GmailShiftHandoffLine(
        title: "Inbox review",
        detail: reviewGmailIntake.isEmpty
          ? "No Gmail-linked intake rows currently need primary Inbox review."
          : "\(reviewGmailIntake.count) Gmail-linked intake row\(reviewGmailIntake.count == 1 ? "" : "s") need review.",
        tone: reviewGmailIntake.isEmpty ? "success" : "attention",
        symbol: "tray.full.fill"
      ),
      GmailShiftHandoffLine(
        title: "Parser checks",
        detail: parserDiagnostics.isEmpty
          ? "No Gmail-linked parser diagnostics are open."
          : "\(parserDiagnostics.count) Gmail parser diagnostic\(parserDiagnostics.count == 1 ? "" : "s") need field confirmation.",
        tone: parserDiagnostics.isEmpty ? "success" : "warning",
        symbol: "text.magnifyingglass"
      ),
      GmailShiftHandoffLine(
        title: "Mixed mailbox review",
        detail: uncertainCount == 0 && filteredCount == 0
          ? "No uncertain or filtered Gmail preview reviews are waiting."
          : "\(uncertainCount) uncertain and \(filteredCount) filtered Gmail preview\(uncertainCount + filteredCount == 1 ? "" : "s") are available for review.",
        tone: uncertainCount > 0 ? "attention" : "neutral",
        symbol: "questionmark.folder.fill"
      )
    ]

    let openLineCount = lines.filter { $0.tone == "warning" || $0.tone == "attention" }.count
    let title: String
    let detail: String
    let tone: String
    if gmailMailboxConnections.isEmpty {
      title = "Gmail handoff unavailable"
      detail = "Add Gmail only for mailboxes hosted by Gmail or Google Workspace."
      tone = "neutral"
    } else if openLineCount == 0 {
      title = "Gmail handoff is clear"
      detail = "No immediate Gmail setup, refresh, parser, or mixed-mailbox follow-up is open."
      tone = "success"
    } else {
      title = "Gmail handoff needs attention"
      detail = "\(openLineCount) Gmail handoff area\(openLineCount == 1 ? "" : "s") should be checked before relying on Gmail intake."
      tone = lines.contains { $0.tone == "warning" } ? "warning" : "attention"
    }

    return GmailShiftHandoffSummary(
      title: title,
      detail: detail,
      tone: tone,
      lastRefreshText: lastRefreshText,
      keyCounts: [
        SpaceMailReleaseSnapshotMetric(title: "Setups", value: "\(gmailMailboxConnections.count)", tone: gmailMailboxConnections.isEmpty ? "neutral" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(readinessBlockers)", tone: readinessBlockers == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Signed in", value: "\(signedInCount)", tone: signedInCount > 0 || gmailMailboxConnections.isEmpty ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(fetchedCount)", tone: fetchedCount > 0 ? "neutral" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount > 0 ? "attention" : "success")
      ],
      handoffLines: lines
    )
  }

  var gmailRefreshTrendSummary: GmailRefreshTrendSummary {
    let gmailEvents = auditEvents.filter { event in
      event.entityType == .gmailMailboxConnection
        && (
          event.summary.localizedCaseInsensitiveContains("Gmail refresh")
            || event.summary.localizedCaseInsensitiveContains("Gmail mailbox fetch")
            || event.summary.localizedCaseInsensitiveContains("Gmail setup")
            || event.afterDetail?.localizedCaseInsensitiveContains("Gmail refresh") == true
        )
    }
    let recentEvents = Array(gmailEvents.prefix(8))
    let fetchedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let importedCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let duplicateCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshDuplicateCount }
    let filteredCount = gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let uncertainCount = gmailMailboxConnections.reduce(0) { $0 + ($1.lastRefreshUncertainCount ?? 0) }
    let pendingUncertainCount = gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) }
    let readinessBlockers = gmailMailboxConnections.filter { !gmailOAuthReadinessSummary(for: $0).isReady }.count
    let signedInCount = gmailMailboxConnections.filter { gmailAuthSessionState(for: $0).status == .connected }.count
    let actionableCount = importedCount + pendingUncertainCount

    let title: String
    let detail: String
    let tone: String
    if gmailMailboxConnections.isEmpty {
      title = "No Gmail refresh trend yet"
      detail = "Add Gmail only for mailboxes hosted by Gmail or Google Workspace."
      tone = "neutral"
    } else if readinessBlockers > 0 {
      title = "Gmail refresh trend blocked by setup"
      detail = "\(readinessBlockers) Gmail setup\(readinessBlockers == 1 ? "" : "s") need readiness fixes before real refresh should be relied on."
      tone = "warning"
    } else if signedInCount == 0 {
      title = "Gmail refresh trend waiting for sign-in"
      detail = "Gmail setup is present, but no connected Google sign-in is available for manual read-only refresh."
      tone = "attention"
    } else if recentEvents.isEmpty && fetchedCount == 0 {
      title = "Gmail refresh trend pending"
      detail = "Run a manual Gmail refresh to build local evidence across imports, duplicates, filtered messages, and uncertain reviews."
      tone = "attention"
    } else if actionableCount > 0 {
      title = "Gmail refresh trend has actionable intake"
      detail = "\(importedCount) imported and \(pendingUncertainCount) uncertain Gmail preview\(pendingUncertainCount == 1 ? "" : "s") need operator review."
      tone = "attention"
    } else if filteredCount > 0 && importedCount == 0 {
      title = "Gmail filter trend is stable"
      detail = "Latest Gmail activity mostly filtered mixed-mailbox non-order messages out of Inbox."
      tone = "success"
    } else {
      title = "Gmail refresh trend is quiet"
      detail = "Recent Gmail activity has no current Inbox intake or uncertain review work."
      tone = "neutral"
    }

    let entries = recentEvents.prefix(6).map { event in
      let afterDetail = event.afterDetail ?? ""
      let eventTone: String
      if event.summary.localizedCaseInsensitiveContains("failed")
        || event.summary.localizedCaseInsensitiveContains("blocked")
        || afterDetail.localizedCaseInsensitiveContains("Status: Auth required")
        || afterDetail.localizedCaseInsensitiveContains("Status: API rejected") {
        eventTone = "warning"
      } else if afterDetail.localizedCaseInsensitiveContains("Imported: 0")
        && afterDetail.localizedCaseInsensitiveContains("Filtered non-order:") {
        eventTone = "success"
      } else if afterDetail.localizedCaseInsensitiveContains("Imported:")
        || afterDetail.localizedCaseInsensitiveContains("Uncertain:") {
        eventTone = "attention"
      } else {
        eventTone = "neutral"
      }

      return GmailRefreshTrendEntry(
        id: event.id,
        timestamp: event.timestamp,
        displayName: event.entityLabel,
        status: event.action.rawValue,
        detail: event.summary,
        tone: eventTone
      )
    }

    return GmailRefreshTrendSummary(
      title: title,
      detail: detail,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Events", value: "\(recentEvents.count)", tone: recentEvents.isEmpty ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Setups", value: "\(gmailMailboxConnections.count)", tone: gmailMailboxConnections.isEmpty ? "neutral" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(readinessBlockers)", tone: readinessBlockers == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(fetchedCount)", tone: fetchedCount > 0 ? "neutral" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Duplicates", value: "\(duplicateCount)", tone: duplicateCount > 0 ? "neutral" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(pendingUncertainCount + uncertainCount)", tone: pendingUncertainCount + uncertainCount > 0 ? "attention" : "success")
      ],
      entries: entries
    )
  }

  var spaceMailReleaseSnapshot: SpaceMailReleaseSnapshot {
    let readiness = spaceMailMVPReadinessSummary
    let qa = spaceMailQACheckSummary
    let healthSummaries = spaceMailIntakeHealthSummaries
    let fetchedCount = healthSummaries.reduce(0) { $0 + $1.fetchedCount }
    let importedCount = healthSummaries.reduce(0) { $0 + $1.importedCount }
    let duplicateCount = healthSummaries.reduce(0) { $0 + $1.duplicateCount }
    let filteredCount = healthSummaries.reduce(0) { $0 + $1.filteredCount }
    let uncertainCount = healthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
    let parserIssueCount = intakeParserDiagnostics.count
    let reviewIntakeCount = reviewIntakeEmails.count
    let generatedDate = Date.now.formatted(date: .abbreviated, time: .shortened)
    let completedChecks = readiness.completedCount + qa.completedCount
    let totalChecks = readiness.totalCount + qa.totalCount

    let verdict: String
    let detail: String
    let tone: String
    if readiness.tone == "success" && qa.tone == "success" {
      verdict = "SpaceMail local MVP release snapshot: ready for supervised testing"
      detail = "Readiness and QA evidence are complete. Continue using manual refresh and human review before operational reliance."
      tone = "success"
    } else if completedChecks >= max(totalChecks - 2, 1) {
      verdict = "SpaceMail local MVP release snapshot: nearly ready"
      detail = "\(completedChecks) of \(totalChecks) readiness and QA checks are complete. Clear the remaining checks before tagging a release."
      tone = "attention"
    } else {
      verdict = "SpaceMail local MVP release snapshot: setup still needed"
      detail = "\(completedChecks) of \(totalChecks) readiness and QA checks are complete. Follow the next action in the readiness card."
      tone = "warning"
    }

    let latestRefresh = spaceMailIMAPConnections
      .filter { $0.lastManualRefreshDate != "Never" }
      .sorted { $0.lastManualRefreshDate > $1.lastManualRefreshDate }
      .first
    let latestRefreshLine = latestRefresh.map {
      "\($0.displayName): \($0.lastRefreshSummary.isEmpty ? $0.connectionStatus : $0.lastRefreshSummary)"
    } ?? "No real SpaceMail refresh has been recorded yet."

    let reportLines = [
      "ParcelOps SpaceMail local MVP release snapshot",
      "Generated: \(generatedDate)",
      "",
      "Verdict: \(verdict)",
      "Detail: \(detail)",
      "",
      "Readiness: \(readiness.completedCount)/\(readiness.totalCount) - \(readiness.verdict)",
      "QA evidence: \(qa.completedCount)/\(qa.totalCount) - \(qa.verdict)",
      "",
      "Latest refresh: \(latestRefreshLine)",
      "Fetched: \(fetchedCount)",
      "Imported to Inbox: \(importedCount)",
      "Duplicates: \(duplicateCount)",
      "Filtered non-order: \(filteredCount)",
      "Uncertain needing review: \(uncertainCount)",
      "Parser diagnostics: \(parserIssueCount)",
      "Inbox rows needing review: \(reviewIntakeCount)",
      "Inbox-created orders: \(orders.filter { $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" }.count)",
      "",
      "Release boundaries:",
      "- SpaceMail refresh is manual and read-only.",
      "- IMAP uses EXAMINE and BODY.PEEK; mailbox items are not deleted, moved, marked read, flagged, sent, or modified.",
      "- SpaceMail password/app-password is handled through Keychain status paths and is not stored in JSON or audit logs.",
      "- Mixed mailbox filtering runs locally from sender, subject, and preview only.",
      "- Shopify, carrier APIs, background sync, notifications, OCR, scanners, calendars, file pickers, and outbound email sending remain disconnected.",
      "",
      "Recommended hands-on test:",
      "1. Run real SpaceMail refresh.",
      "2. Review imported and uncertain messages in Mailbox Monitor.",
      "3. Create or link one order from Inbox.",
      "4. Confirm Orders, Dashboard, Workbench, Tasks, and Audit show the handoff.",
      "5. Quit and reopen to verify local persistence."
    ]

    return SpaceMailReleaseSnapshot(
      verdict: verdict,
      detail: detail,
      generatedDate: generatedDate,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Checks", value: "\(completedChecks)/\(totalChecks)", tone: tone),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(fetchedCount)", tone: "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Inbox imports", value: "\(importedCount)", tone: importedCount > 0 ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Parser checks", value: "\(parserIssueCount)", tone: parserIssueCount == 0 ? "success" : "attention")
      ],
      reportText: reportLines.joined(separator: "\n")
    )
  }

  var mailboxReleaseReadinessSnapshot: SpaceMailReleaseSnapshot {
    let providerQA = mailboxProviderQACheckSummary
    let intakeQuality = mailboxIntakeQualitySummary
    let handoff = mailboxOperationsHandoffSummary
    let comparison = mailboxProviderComparisonSummary
    let generatedDate = Date.now.formatted(date: .abbreviated, time: .shortened)
    let completedChecks = providerQA.completedCount + intakeQuality.completedCount
    let totalChecks = providerQA.totalCount + intakeQuality.totalCount
    let providerBlockers = comparison.providers.reduce(0) { $0 + $1.blockedCount }
    let handoffAttention = handoff.lines.filter { $0.tone == "attention" || $0.tone == "warning" }.count
    let totalFetched = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFetchedCount }
    let totalImported = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let totalFiltered = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let totalUncertain = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshUncertainCount + $1.uncertainMessages.count }
      + gmailMailboxConnections.reduce(0) { $0 + ($1.lastRefreshUncertainCount ?? 0) + ($1.uncertainMessages?.count ?? 0) }
    let linkedOrderCount = intakeEmails.filter { $0.linkedOrderID != nil }.count

    let verdict: String
    let detail: String
    let tone: String
    if providerQA.tone == "success" && intakeQuality.tone == "success" && providerBlockers == 0 && handoffAttention == 0 {
      verdict = "Mailbox release snapshot: ready for supervised testing"
      detail = "Provider boundaries, intake quality, and handoff status are complete enough for a focused hands-on mailbox test."
      tone = "success"
    } else if completedChecks >= max(totalChecks - 3, 1) && providerBlockers == 0 {
      verdict = "Mailbox release snapshot: usable with review"
      detail = "\(completedChecks) of \(totalChecks) provider and intake checks are complete. Clear handoff or parser review items before relying on results."
      tone = "attention"
    } else {
      verdict = "Mailbox release snapshot: not ready yet"
      detail = "\(completedChecks) of \(totalChecks) provider and intake checks are complete. Finish setup, refresh, and intake quality checks first."
      tone = "warning"
    }

    let providerLines = comparison.providers.map { provider in
      "- \(provider.providerName): \(provider.statusTitle); \(provider.fetchedCount) fetched, \(provider.importedCount) imported, \(provider.uncertainCount) uncertain, \(provider.blockedCount) blockers."
    }
    let handoffLines = handoff.lines.map { "- \($0.title): \($0.detail)" }
    let reportLines = [
      "ParcelOps mailbox release readiness snapshot",
      "Generated: \(generatedDate)",
      "",
      "Verdict: \(verdict)",
      "Detail: \(detail)",
      "",
      "Recommended provider path: \(comparison.recommendedProvider)",
      "Provider QA: \(providerQA.completedCount)/\(providerQA.totalCount) - \(providerQA.verdict)",
      "Intake quality: \(intakeQuality.completedCount)/\(intakeQuality.totalCount) - \(intakeQuality.verdict)",
      "Handoff: \(handoff.title) - \(handoff.detail)",
      "",
      "Provider status:",
      providerLines.joined(separator: "\n"),
      "",
      "Mailbox counts:",
      "Fetched: \(totalFetched)",
      "Imported: \(totalImported)",
      "Filtered non-order: \(totalFiltered)",
      "Uncertain: \(totalUncertain)",
      "Parser diagnostics: \(intakeParserDiagnostics.count)",
      "Inbox rows linked to orders: \(linkedOrderCount)",
      "",
      "Current handoff lines:",
      handoffLines.joined(separator: "\n"),
      "",
      "Release boundaries:",
      "- SpaceMail and Gmail refreshes are explicit, manual, and read-only.",
      "- No background sync, notifications, outbound email sending, Shopify, carrier APIs, OCR, scanners, calendars, or file pickers are active.",
      "- Passwords, tokens, auth strings, and full message bodies should not be stored in ParcelOps JSON or Audit.",
      "- Mixed-mailbox filtering is local only and should keep non-order mail out of primary Inbox.",
      "",
      "Recommended release-candidate test:",
      "1. Run the active provider manual refresh.",
      "2. Confirm the refresh summary, provider QA, and intake quality cards.",
      "3. Import or dismiss uncertain messages.",
      "4. Create or link one order from confirmed Inbox intake.",
      "5. Confirm Dashboard, Workbench, Tasks, and Audit show the handoff."
    ]

    return SpaceMailReleaseSnapshot(
      verdict: verdict,
      detail: detail,
      generatedDate: generatedDate,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Checks", value: "\(completedChecks)/\(totalChecks)", tone: tone),
        SpaceMailReleaseSnapshotMetric(title: "Providers", value: "\(spaceMailIMAPConnections.count + gmailMailboxConnections.count)", tone: providerBlockers == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Fetched", value: "\(totalFetched)", tone: totalFetched > 0 ? "neutral" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(totalImported)", tone: totalImported > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(totalFiltered)", tone: totalFiltered > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Handoff", value: "\(handoffAttention)", tone: handoffAttention == 0 ? "success" : "attention")
      ],
      reportText: reportLines.joined(separator: "\n")
    )
  }

  var mailboxReleaseBlockerSummary: MailboxReleaseBlockerSummary {
    let providerQA = mailboxProviderQACheckSummary
    let intakeQuality = mailboxIntakeQualitySummary
    let comparison = mailboxProviderComparisonSummary
    let handoff = mailboxOperationsHandoffSummary
    var blockers: [MailboxReleaseBlockerItem] = []

    for check in providerQA.checks where !check.isComplete {
      blockers.append(
        MailboxReleaseBlockerItem(
          source: "Provider QA",
          title: check.title,
          detail: check.evidence,
          nextAction: check.detail,
          tone: check.tone == "success" ? "neutral" : check.tone,
          symbol: check.tone == "warning" ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill"
        )
      )
    }

    for check in intakeQuality.checks where !check.isComplete {
      blockers.append(
        MailboxReleaseBlockerItem(
          source: "Intake quality",
          title: check.title,
          detail: check.evidence,
          nextAction: check.detail,
          tone: check.tone == "success" ? "neutral" : check.tone,
          symbol: check.tone == "warning" ? "exclamationmark.triangle.fill" : "doc.text.magnifyingglass"
        )
      )
    }

    for item in comparison.actionItems.prefix(4) {
      blockers.append(
        MailboxReleaseBlockerItem(
          source: item.providerName,
          title: item.title,
          detail: item.detail,
          nextAction: "Complete this provider action before treating mailbox intake as release-ready.",
          tone: item.tone,
          symbol: item.symbol
        )
      )
    }

    for line in handoff.lines where line.tone == "warning" || line.tone == "attention" {
      blockers.append(
        MailboxReleaseBlockerItem(
          source: "Operator handoff",
          title: line.title,
          detail: line.detail,
          nextAction: "Clear this handoff item or create a follow-up task from the release snapshot.",
          tone: line.tone,
          symbol: line.symbol
        )
      )
    }

    let warningCount = blockers.filter { $0.tone == "warning" }.count
    let attentionCount = blockers.filter { $0.tone == "attention" }.count
    let uniqueBlockers = Array(
      Dictionary(grouping: blockers, by: { "\($0.source)-\($0.title)-\($0.detail)" })
        .compactMap { $0.value.first }
        .sorted { lhs, rhs in
          let lhsRank = lhs.tone == "warning" ? 0 : lhs.tone == "attention" ? 1 : 2
          let rhsRank = rhs.tone == "warning" ? 0 : rhs.tone == "attention" ? 1 : 2
          if lhsRank != rhsRank { return lhsRank < rhsRank }
          return lhs.source < rhs.source
        }
    )

    let title: String
    let detail: String
    let tone: String
    if warningCount > 0 {
      title = "Mailbox release has blocking items"
      detail = "\(warningCount) high-priority blocker\(warningCount == 1 ? "" : "s") should be resolved before release-candidate testing."
      tone = "warning"
    } else if attentionCount > 0 {
      title = "Mailbox release needs operator review"
      detail = "\(attentionCount) review item\(attentionCount == 1 ? "" : "s") should be handled or tracked as follow-up before relying on mailbox results."
      tone = "attention"
    } else {
      title = "Mailbox release blockers are clear"
      detail = "Provider setup, intake quality, and handoff checks do not currently show release blockers."
      tone = "success"
    }

    return MailboxReleaseBlockerSummary(
      title: title,
      detail: detail,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(warningCount)", tone: warningCount == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Review", value: "\(attentionCount)", tone: attentionCount == 0 ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Provider QA", value: "\(providerQA.completedCount)/\(providerQA.totalCount)", tone: providerQA.tone),
        SpaceMailReleaseSnapshotMetric(title: "Intake QA", value: "\(intakeQuality.completedCount)/\(intakeQuality.totalCount)", tone: intakeQuality.tone)
      ],
      blockers: Array(uniqueBlockers.prefix(8))
    )
  }

  var mailboxRunTimelineSummary: MailboxRunTimelineSummary {
    let spaceMailEntries = spaceMailIMAPConnections.flatMap { connection in
      connection.refreshHistory.prefix(5).map { entry in
        MailboxRunTimelineEntry(
          id: "spacemail-\(entry.id.uuidString)",
          provider: "SpaceMail",
          timestamp: entry.timestamp,
          title: connection.displayName,
          detail: "\(entry.fetchedCount) fetched, \(entry.importedCount) imported, \(entry.duplicateCount) duplicates, \(entry.filteredNonOrderCount) filtered, \(entry.uncertainCount) uncertain.",
          outcome: entry.status,
          tone: entry.importedCount > 0 || entry.uncertainCount > 0 ? "attention" : (entry.status.localizedCaseInsensitiveContains("success") || entry.filteredNonOrderCount > 0 || entry.duplicateCount > 0 ? "success" : "warning"),
          symbol: "server.rack"
        )
      }
    }

    let gmailEvents = auditEvents.filter { event in
      event.entityType == .gmailMailboxConnection
        && (
          event.summary.localizedCaseInsensitiveContains("Gmail refresh")
            || event.summary.localizedCaseInsensitiveContains("Gmail mailbox fetch")
            || event.afterDetail?.localizedCaseInsensitiveContains("Gmail refresh") == true
        )
    }
    let gmailEntries = gmailEvents.prefix(8).map { event in
      let detail = event.afterDetail ?? ""
      let tone: String
      if event.summary.localizedCaseInsensitiveContains("failed")
        || event.summary.localizedCaseInsensitiveContains("blocked")
        || detail.localizedCaseInsensitiveContains("Status: Auth required")
        || detail.localizedCaseInsensitiveContains("Status: API rejected") {
        tone = "warning"
      } else if detail.localizedCaseInsensitiveContains("Imported: 0")
        && detail.localizedCaseInsensitiveContains("Filtered non-order:") {
        tone = "success"
      } else if detail.localizedCaseInsensitiveContains("Imported:")
        || detail.localizedCaseInsensitiveContains("Uncertain:") {
        tone = "attention"
      } else {
        tone = "neutral"
      }
      return MailboxRunTimelineEntry(
        id: "gmail-\(event.id.uuidString)",
        provider: "Gmail",
        timestamp: event.timestamp,
        title: event.entityLabel,
        detail: event.summary,
        outcome: event.action.rawValue,
        tone: tone,
        symbol: "envelope.badge.shield.half.filled"
      )
    }

    let entries = Array((spaceMailEntries + gmailEntries).sorted { $0.timestamp > $1.timestamp }.prefix(8))
    let importedCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshImportedCount }
    let filteredCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
      + gmailMailboxConnections.reduce(0) { $0 + $1.lastRefreshFilteredNonOrderCount }
    let uncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.lastRefreshUncertainCount + $1.uncertainMessages.count }
      + gmailMailboxConnections.reduce(0) { $0 + ($1.lastRefreshUncertainCount ?? 0) + ($1.uncertainMessages?.count ?? 0) }
    let warningCount = entries.filter { $0.tone == "warning" }.count
    let attentionCount = entries.filter { $0.tone == "attention" }.count

    let title: String
    let detail: String
    let tone: String
    if entries.isEmpty {
      title = "Mailbox run timeline is empty"
      detail = "Run a manual SpaceMail or Gmail refresh to build handoff history."
      tone = "attention"
    } else if warningCount > 0 {
      title = "Mailbox run timeline has failed or blocked runs"
      detail = "\(warningCount) recent run\(warningCount == 1 ? "" : "s") need setup or auth review before relying on mailbox intake."
      tone = "warning"
    } else if attentionCount > 0 {
      title = "Mailbox run timeline has operator work"
      detail = "\(attentionCount) recent run\(attentionCount == 1 ? "" : "s") produced imported or uncertain work for Inbox review."
      tone = "attention"
    } else {
      title = "Mailbox run timeline is stable"
      detail = "Recent refreshes show no unresolved imported or uncertain mailbox work."
      tone = "success"
    }

    return MailboxRunTimelineSummary(
      title: title,
      detail: detail,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Runs", value: "\(entries.count)", tone: entries.isEmpty ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Warnings", value: "\(warningCount)", tone: warningCount == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Review", value: "\(attentionCount)", tone: attentionCount == 0 ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Imported", value: "\(importedCount)", tone: importedCount > 0 ? "attention" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Filtered", value: "\(filteredCount)", tone: filteredCount > 0 ? "success" : "neutral"),
        SpaceMailReleaseSnapshotMetric(title: "Uncertain", value: "\(uncertainCount)", tone: uncertainCount > 0 ? "attention" : "success")
      ],
      entries: entries
    )
  }

  var mailboxReleaseTestPlanSummary: MailboxReleaseTestPlanSummary {
    let providerQA = mailboxProviderQACheckSummary
    let intakeQA = mailboxIntakeQualitySummary
    let blockers = mailboxReleaseBlockerSummary
    let timeline = mailboxRunTimelineSummary
    let handoff = mailboxOperationsHandoffSummary

    let providerReady = providerQA.tone == "success" || providerQA.completedCount >= max(providerQA.totalCount - 1, 1)
    let hasRunEvidence = !timeline.entries.isEmpty
    let hasCleanRun = timeline.entries.contains { $0.tone == "success" || $0.tone == "attention" }
    let hasImportedOrUncertain = mailboxRunTimelineSummary.metrics.contains { metric in
      (metric.title == "Imported" || metric.title == "Uncertain") && Int(metric.value) ?? 0 > 0
    }
    let hasInboxReview = !reviewIntakeEmails.isEmpty || intakeEmails.contains { $0.reviewState == .reviewed || $0.reviewState == .ignored }
    let hasOrderHandoff = orders.contains { $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" || $0.isInboxCreatedLocalOrder }
      || intakeEmails.contains { $0.linkedOrderID != nil }
    let hasAuditTrail = auditEvents.contains { event in
      [.spaceMailIMAPConnection, .gmailMailboxConnection, .intakeEmail, .order, .reviewTask].contains(event.entityType)
    }
    let hasNoReleaseBlockers = blockers.blockers.filter { $0.tone == "warning" }.isEmpty
    let intakeReady = intakeQA.tone == "success" || intakeQA.completedCount >= max(intakeQA.totalCount - 2, 1)

    let steps = [
      MailboxReleaseTestPlanStep(
        title: "1. Provider setup",
        detail: "Confirm at least one mailbox provider has setup, credential/sign-in evidence, and read-only boundaries.",
        evidence: "\(providerQA.completedCount) of \(providerQA.totalCount) provider QA checks complete.",
        nextAction: providerReady ? "Provider setup evidence is sufficient for a supervised test." : "Finish the highest-priority provider QA item.",
        isComplete: providerReady,
        tone: providerReady ? "success" : "warning",
        symbol: "server.rack"
      ),
      MailboxReleaseTestPlanStep(
        title: "2. Manual refresh run",
        detail: "Run or review one explicit read-only SpaceMail or Gmail refresh.",
        evidence: hasRunEvidence ? "\(timeline.entries.count) recent mailbox run\(timeline.entries.count == 1 ? "" : "s") available." : "No mailbox run timeline entry exists yet.",
        nextAction: hasCleanRun ? "Use the latest run to test Inbox triage." : "Run one manual provider refresh; keep mock refresh separate from real refresh.",
        isComplete: hasRunEvidence && hasCleanRun,
        tone: hasRunEvidence && hasCleanRun ? "success" : "attention",
        symbol: "clock.arrow.circlepath"
      ),
      MailboxReleaseTestPlanStep(
        title: "3. Intake quality",
        detail: "Check imported, duplicate, filtered, uncertain, and parser outcomes before creating operational work.",
        evidence: "\(intakeQA.completedCount) of \(intakeQA.totalCount) intake QA checks complete.",
        nextAction: intakeReady ? "Review any visible parser or uncertain items, then continue." : "Use Mailbox Monitor to review parser diagnostics and uncertain messages.",
        isComplete: intakeReady,
        tone: intakeReady ? "success" : "attention",
        symbol: "doc.text.magnifyingglass"
      ),
      MailboxReleaseTestPlanStep(
        title: "4. Inbox triage",
        detail: "Confirm one imported or reviewable mailbox message can be reviewed, ignored, linked, or converted locally.",
        evidence: hasImportedOrUncertain ? "Latest run has imported or uncertain review work." : "\(reviewIntakeEmails.count) Inbox row\(reviewIntakeEmails.count == 1 ? "" : "s") currently need review.",
        nextAction: hasInboxReview ? "Open Inbox or Mailbox Monitor and complete one local triage decision." : "Send or use a known test order email, refresh, then triage the row.",
        isComplete: hasInboxReview,
        tone: hasInboxReview ? "success" : "attention",
        symbol: "tray.full.fill"
      ),
      MailboxReleaseTestPlanStep(
        title: "5. Order handoff",
        detail: "Create or link one local order from confirmed intake and verify it appears in Orders, Dashboard, Workbench, and Tasks context.",
        evidence: hasOrderHandoff ? "Inbox/order source trail exists." : "No Inbox-created or linked order evidence yet.",
        nextAction: hasOrderHandoff ? "Open Orders and confirm the source trail." : "Use Inbox Create order or Link order on a confirmed intake row.",
        isComplete: hasOrderHandoff,
        tone: hasOrderHandoff ? "success" : "attention",
        symbol: "shippingbox.fill"
      ),
      MailboxReleaseTestPlanStep(
        title: "6. Release blockers",
        detail: "Confirm the release blocker queue has no high-priority warnings.",
        evidence: "\(blockers.blockers.filter { $0.tone == "warning" }.count) warning blocker\(blockers.blockers.filter { $0.tone == "warning" }.count == 1 ? "" : "s") and \(blockers.blockers.filter { $0.tone == "attention" }.count) review item\(blockers.blockers.filter { $0.tone == "attention" }.count == 1 ? "" : "s").",
        nextAction: hasNoReleaseBlockers ? "Track remaining review items as follow-up if needed." : "Resolve the warning blockers before release-candidate testing.",
        isComplete: hasNoReleaseBlockers,
        tone: hasNoReleaseBlockers ? "success" : "warning",
        symbol: "exclamationmark.octagon.fill"
      ),
      MailboxReleaseTestPlanStep(
        title: "7. Audit and persistence",
        detail: "Confirm local actions are visible in Audit and persist after reopening the app.",
        evidence: hasAuditTrail ? "\(auditEvents.count) audit event\(auditEvents.count == 1 ? "" : "s") available." : "No mailbox/intake/order audit trail evidence yet.",
        nextAction: hasAuditTrail ? "Quit and reopen the app, then confirm the same local records remain." : "Complete one triage or release follow-up action to generate audit evidence.",
        isComplete: hasAuditTrail,
        tone: hasAuditTrail ? "success" : "attention",
        symbol: "list.clipboard.fill"
      )
    ]

    let completedCount = steps.filter(\.isComplete).count
    let warningCount = steps.filter { !$0.isComplete && $0.tone == "warning" }.count
    let title: String
    let detail: String
    let tone: String
    if completedCount == steps.count {
      title = "Mailbox release test plan is ready"
      detail = "All mailbox release test steps have local evidence. Run the hands-on pass and record any real operator issues."
      tone = "success"
    } else if warningCount > 0 {
      title = "Mailbox release test plan has blockers"
      detail = "\(completedCount) of \(steps.count) steps have evidence. Resolve warning steps before treating mailbox intake as release-ready."
      tone = "warning"
    } else {
      title = "Mailbox release test plan is in progress"
      detail = "\(completedCount) of \(steps.count) steps have evidence. Complete the remaining local checks during the next hands-on pass."
      tone = "attention"
    }

    return MailboxReleaseTestPlanSummary(
      title: title,
      detail: detail,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Steps", value: "\(completedCount)/\(steps.count)", tone: tone),
        SpaceMailReleaseSnapshotMetric(title: "Warnings", value: "\(warningCount)", tone: warningCount == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Runs", value: "\(timeline.entries.count)", tone: timeline.entries.isEmpty ? "attention" : "success"),
        SpaceMailReleaseSnapshotMetric(title: "Handoff", value: handoff.tone == "success" || handoff.tone == "neutral" ? "Ready" : "Review", tone: handoff.tone),
        SpaceMailReleaseSnapshotMetric(title: "Audit", value: "\(auditEvents.count)", tone: auditEvents.isEmpty ? "attention" : "success")
      ],
      steps: steps
    )
  }

  var mailboxOperatorDecisionSummary: MailboxOperatorDecisionSummary {
    let blockers = mailboxReleaseBlockerSummary
    let timeline = mailboxRunTimelineSummary
    let testPlan = mailboxReleaseTestPlanSummary
    let providerQA = mailboxProviderQACheckSummary
    let intakeQA = mailboxIntakeQualitySummary
    let warningBlockers = blockers.blockers.filter { $0.tone == "warning" }.count
    let reviewBlockers = blockers.blockers.filter { $0.tone == "attention" }.count
    let hasProviderSetup = !spaceMailIMAPConnections.isEmpty || !gmailMailboxConnections.isEmpty
    let hasRefreshEvidence = !timeline.entries.isEmpty
    let openInboxCount = reviewIntakeEmails.count
    let uncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count + $1.lastRefreshUncertainCount }
      + gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) + ($1.lastRefreshUncertainCount ?? 0) }
    let parserIssueCount = intakeParserDiagnostics.count
    let linkedOrderCount = intakeEmails.filter { $0.linkedOrderID != nil }.count
    let inboxCreatedOrderCount = orders.filter(\.isInboxCreatedLocalOrder).count
    let openTaskCount = reviewTasksNeedingAttention.count + handoffNotesNeedingAttention.count
    let latestRunHasAction = timeline.entries.contains { $0.tone == "attention" }

    let decisions = [
      MailboxOperatorDecisionItem(
        title: "Fix setup blockers first",
        detail: "\(warningBlockers) warning blocker\(warningBlockers == 1 ? "" : "s") currently prevent a clean mailbox release pass.",
        action: "Open the blocker queue and resolve warning items before refreshing again.",
        isActive: warningBlockers > 0,
        tone: warningBlockers > 0 ? "warning" : "success",
        symbol: "exclamationmark.triangle.fill"
      ),
      MailboxOperatorDecisionItem(
        title: "Run a manual mailbox refresh",
        detail: hasRefreshEvidence ? "A refresh timeline exists; run again only when checking for new mail." : "No manual mailbox run is recorded yet.",
        action: "Use the active provider's explicit manual refresh button. Keep mock refresh separate.",
        isActive: hasProviderSetup && !hasRefreshEvidence && warningBlockers == 0,
        tone: hasProviderSetup && !hasRefreshEvidence && warningBlockers == 0 ? "attention" : "neutral",
        symbol: "clock.arrow.circlepath"
      ),
      MailboxOperatorDecisionItem(
        title: "Review imported Inbox work",
        detail: "\(openInboxCount) Inbox intake row\(openInboxCount == 1 ? "" : "s") need review; latest run action flag: \(latestRunHasAction ? "yes" : "no").",
        action: "Open Inbox or Mailbox Monitor, then review, ignore, link, or create orders from confirmed rows.",
        isActive: openInboxCount > 0 || latestRunHasAction,
        tone: openInboxCount > 0 || latestRunHasAction ? "attention" : "success",
        symbol: "tray.full.fill"
      ),
      MailboxOperatorDecisionItem(
        title: "Review uncertain or parser items",
        detail: "\(uncertainCount) uncertain preview\(uncertainCount == 1 ? "" : "s") and \(parserIssueCount) parser diagnostic\(parserIssueCount == 1 ? "" : "s") are visible.",
        action: "Import true order messages, dismiss non-order messages, and reprocess parser rows where needed.",
        isActive: uncertainCount + parserIssueCount > 0,
        tone: uncertainCount + parserIssueCount > 0 ? "attention" : "success",
        symbol: "doc.text.magnifyingglass"
      ),
      MailboxOperatorDecisionItem(
        title: "Create or verify order handoff",
        detail: "\(linkedOrderCount) linked intake row\(linkedOrderCount == 1 ? "" : "s"); \(inboxCreatedOrderCount) Inbox-created order\(inboxCreatedOrderCount == 1 ? "" : "s").",
        action: "Use Create order or Link order, then confirm Orders and order detail show the source trail.",
        isActive: linkedOrderCount == 0 && inboxCreatedOrderCount == 0 && openInboxCount > 0,
        tone: linkedOrderCount == 0 && inboxCreatedOrderCount == 0 ? "attention" : "success",
        symbol: "shippingbox.fill"
      ),
      MailboxOperatorDecisionItem(
        title: "Record release follow-up",
        detail: "\(reviewBlockers) review item\(reviewBlockers == 1 ? "" : "s"); \(openTaskCount) task or handoff follow-up\(openTaskCount == 1 ? "" : "s") currently open.",
        action: "Create a mailbox release follow-up task from the snapshot if anything remains for the next session.",
        isActive: reviewBlockers > 0 && openTaskCount == 0,
        tone: reviewBlockers > 0 && openTaskCount == 0 ? "attention" : "neutral",
        symbol: "checklist"
      )
    ]

    let activeDecisions = decisions.filter(\.isActive)
    let primaryAction: String
    let title: String
    let detail: String
    let tone: String
    if let firstWarning = activeDecisions.first(where: { $0.tone == "warning" }) {
      primaryAction = firstWarning.action
      title = "Mailbox decision: stop and fix blockers"
      detail = firstWarning.detail
      tone = "warning"
    } else if let firstActive = activeDecisions.first {
      primaryAction = firstActive.action
      title = "Mailbox decision: \(firstActive.title.lowercased())"
      detail = firstActive.detail
      tone = firstActive.tone == "success" ? "attention" : firstActive.tone
    } else if testPlan.tone == "success" {
      primaryAction = "Run the hands-on release pass, then tag or document the local MVP state."
      title = "Mailbox decision: ready for release-candidate pass"
      detail = "Provider setup, intake quality, run timeline, handoff, and blockers do not currently require action."
      tone = "success"
    } else {
      primaryAction = "Review the release test plan and complete the next incomplete step."
      title = "Mailbox decision: continue readiness checks"
      detail = testPlan.detail
      tone = testPlan.tone
    }

    return MailboxOperatorDecisionSummary(
      title: title,
      detail: detail,
      primaryAction: primaryAction,
      tone: tone,
      metrics: [
        SpaceMailReleaseSnapshotMetric(title: "Provider QA", value: "\(providerQA.completedCount)/\(providerQA.totalCount)", tone: providerQA.tone),
        SpaceMailReleaseSnapshotMetric(title: "Intake QA", value: "\(intakeQA.completedCount)/\(intakeQA.totalCount)", tone: intakeQA.tone),
        SpaceMailReleaseSnapshotMetric(title: "Blockers", value: "\(warningBlockers)", tone: warningBlockers == 0 ? "success" : "warning"),
        SpaceMailReleaseSnapshotMetric(title: "Inbox", value: "\(openInboxCount)", tone: openInboxCount == 0 ? "success" : "attention"),
        SpaceMailReleaseSnapshotMetric(title: "Orders", value: "\(linkedOrderCount + inboxCreatedOrderCount)", tone: linkedOrderCount + inboxCreatedOrderCount > 0 ? "success" : "attention")
      ],
      decisions: decisions
    )
  }

  var localDataHygieneSummary: LocalDataHygieneSummary {
    func isPlaceholder(_ value: String) -> Bool {
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let compact = normalized.replacingOccurrences(of: " ", with: "")
      return normalized.isEmpty
        || normalized == "pending"
        || normalized == "unknown"
        || normalized == "no subject"
        || normalized == "unknown sender"
        || normalized == "unknown date"
        || normalized == "unassigned"
        || compact.contains("needsreview")
        || compact.contains("unknownsender")
        || compact.contains("unknowndate")
    }

    func preview(_ value: String, limit: Int = 72) -> String {
      let cleaned = value
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard cleaned.count > limit else { return cleaned.isEmpty ? "Untitled" : cleaned }
      return String(cleaned.prefix(limit - 1)) + "..."
    }

    let intakeIDs = Set(intakeEmails.map(\.id))
    let orderIDs = Set(orders.map(\.id))
    let duplicateIngestCount = mailboxIngestRecords.filter { $0.status == .duplicateSkipped }.count
    let orphanIngestCount = mailboxIngestRecords.filter { record in
      guard let intakeEmailID = record.intakeEmailID else { return false }
      return !intakeIDs.contains(intakeEmailID)
    }.count
    let orphanLinkedIntakeCount = intakeEmails.filter { email in
      guard let linkedOrderID = email.linkedOrderID else { return false }
      return !orderIDs.contains(linkedOrderID)
    }.count
    let placeholderIntakeCount = intakeEmails.filter { email in
      isPlaceholder(email.subject)
        || isPlaceholder(email.sender)
        || isPlaceholder(email.detectedOrderNumber)
        || isPlaceholder(email.detectedTrackingNumber)
        || email.rawBodyPreview.localizedCaseInsensitiveContains("Content-Type:")
        || email.rawBodyPreview.localizedCaseInsensitiveContains("Return-Path:")
    }.count
    let ignoredIntakeCount = intakeEmails.filter { $0.reviewState == .ignored }.count
    let reviewedUnlinkedIntakeCount = intakeEmails.filter { $0.reviewState == .reviewed && $0.linkedOrderID == nil }.count
    let pendingUncertainCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
    let pendingFilteredReviewCount = spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count }
    let parserDiagnosticCount = intakeParserDiagnostics.count
    let inboxCreatedOrderCount = orders.filter { $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" }.count
    let openPartialOrderTasks = reviewTasks.filter { $0.isPartialInboxOrderFollowUp && $0.status != .completed }.count
    let activeNoiseSignals = placeholderIntakeCount
      + orphanIngestCount
      + orphanLinkedIntakeCount
      + parserDiagnosticCount
      + pendingUncertainCount
      + openPartialOrderTasks

    let verdict: String
    let detail: String
    let nextAction: String
    let tone: String
    if activeNoiseSignals == 0 && reviewIntakeEmails.isEmpty {
      verdict = "Local data looks tidy enough for routine testing"
      detail = "No obvious intake, ingest, parser, or partial-order hygiene signals are active."
      nextAction = "Continue normal Inbox-to-Orders testing"
      tone = "success"
    } else if activeNoiseSignals <= 5 {
      verdict = "Local data has a small review load"
      detail = "\(activeNoiseSignals) hygiene signal\(activeNoiseSignals == 1 ? "" : "s") are visible. They can usually be handled from Inbox, Mailbox Monitor, or Tasks."
      nextAction = "Review flagged intake rows and partial order tasks"
      tone = "attention"
    } else {
      verdict = "Local data has accumulated testing noise"
      detail = "\(activeNoiseSignals) hygiene signals are visible, mostly from mailbox testing, parser diagnostics, duplicate ingest, or partial order handoff."
      nextAction = "Use Inbox, Mailbox Monitor, Tasks, and Audit to resolve or ignore records intentionally"
      tone = "warning"
    }

    var examples: [String] = []
    examples.append(contentsOf: intakeEmails.filter {
      isPlaceholder($0.subject) || isPlaceholder($0.sender) || isPlaceholder($0.detectedOrderNumber) || isPlaceholder($0.detectedTrackingNumber)
    }.prefix(3).map { "Intake needs cleanup: \(preview($0.subject))" })
    examples.append(contentsOf: spaceMailIMAPConnections.flatMap(\.uncertainMessages).prefix(2).map { "Uncertain SpaceMail: \(preview($0.subject))" })
    examples.append(contentsOf: intakeParserDiagnostics.prefix(2).map { "Parser diagnostic: \(preview($0.title))" })
    examples.append(contentsOf: reviewTasks.filter { $0.isPartialInboxOrderFollowUp && $0.status != .completed }.prefix(2).map { "Partial order task: \(preview($0.title))" })

    return LocalDataHygieneSummary(
      verdict: verdict,
      detail: detail,
      nextAction: nextAction,
      tone: tone,
      signalCount: activeNoiseSignals,
      metrics: [
        LocalDataHygieneMetric(title: "Intake placeholders", value: "\(placeholderIntakeCount)", detail: "Rows with missing sender, subject, order, tracking, or raw header-like preview text.", tone: placeholderIntakeCount == 0 ? "success" : "attention"),
        LocalDataHygieneMetric(title: "Needs review", value: "\(reviewIntakeEmails.count)", detail: "Forwarded intake emails still waiting for operator review.", tone: reviewIntakeEmails.isEmpty ? "success" : "attention"),
        LocalDataHygieneMetric(title: "Ignored intake", value: "\(ignoredIntakeCount)", detail: "Rows already ignored locally; useful as test noise evidence, not active Inbox work.", tone: ignoredIntakeCount == 0 ? "success" : "neutral"),
        LocalDataHygieneMetric(title: "Reviewed unlinked", value: "\(reviewedUnlinkedIntakeCount)", detail: "Reviewed intake rows that were not linked to an order.", tone: reviewedUnlinkedIntakeCount == 0 ? "success" : "neutral"),
        LocalDataHygieneMetric(title: "Duplicate ingest", value: "\(duplicateIngestCount)", detail: "Duplicate provider message IDs skipped by the ingest layer.", tone: duplicateIngestCount == 0 ? "success" : "neutral"),
        LocalDataHygieneMetric(title: "Orphan ingest links", value: "\(orphanIngestCount)", detail: "Ingest records pointing at intake IDs no longer present locally.", tone: orphanIngestCount == 0 ? "success" : "warning"),
        LocalDataHygieneMetric(title: "Orphan order links", value: "\(orphanLinkedIntakeCount)", detail: "Intake rows linked to order IDs no longer present locally.", tone: orphanLinkedIntakeCount == 0 ? "success" : "warning"),
        LocalDataHygieneMetric(title: "Parser diagnostics", value: "\(parserDiagnosticCount)", detail: "Local parser checks still visible for review.", tone: parserDiagnosticCount == 0 ? "success" : "attention"),
        LocalDataHygieneMetric(title: "Uncertain SpaceMail", value: "\(pendingUncertainCount)", detail: "Ambiguous previews kept out of Inbox until imported or dismissed.", tone: pendingUncertainCount == 0 ? "success" : "attention"),
        LocalDataHygieneMetric(title: "Filtered review", value: "\(pendingFilteredReviewCount)", detail: "Filtered mixed-mailbox examples available for spot review.", tone: pendingFilteredReviewCount == 0 ? "success" : "neutral"),
        LocalDataHygieneMetric(title: "Inbox orders", value: "\(inboxCreatedOrderCount)", detail: "Orders created or linked from Inbox/import handoff.", tone: inboxCreatedOrderCount == 0 ? "neutral" : "success"),
        LocalDataHygieneMetric(title: "Partial order tasks", value: "\(openPartialOrderTasks)", detail: "Open verification tasks for incomplete Inbox-created orders.", tone: openPartialOrderTasks == 0 ? "success" : "attention")
      ],
      examples: Array(examples.prefix(6)),
      boundaries: [
        "Read-only summary: no records are deleted, merged, or rewritten.",
        "Duplicate tracking metadata remains intact.",
        "No mailbox refresh, Keychain read, network call, or mailbox mutation runs from this card.",
        "Use existing Inbox, Mailbox Monitor, Tasks, and Audit actions to resolve records deliberately."
      ]
    )
  }

  var spaceMailMVPReadinessSummary: SpaceMailMVPReadinessSummary {
    let hasConnection = !spaceMailIMAPConnections.isEmpty
    let configuredConnections = spaceMailIMAPConnections.filter { connection in
      !connection.emailAddressUsername.isPlaceholderValidationValue
        && !connection.imapHost.isPlaceholderValidationValue
        && !connection.imapPort.isPlaceholderValidationValue
        && !connection.folderName.isPlaceholderValidationValue
    }
    let credentialReady = spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus == SpaceMailCredentialStoreStatus.passwordReferenceAvailable.rawValue
    }
    let hasRealRefresh = spaceMailIMAPConnections.contains {
      $0.lastManualRefreshDate != "Never" && $0.connectionStatus.localizedCaseInsensitiveContains("real imap")
    }
    let mixedFilteringReady = spaceMailIMAPConnections.contains {
      $0.mailboxMode == .mixedFiltered && ($0.lastRefreshFilteredNonOrderCount > 0 || !$0.filteredMessages.isEmpty || !$0.lastRefreshReasonBreakdown.isEmpty)
    }
    let parserQueueClear = intakeParserDiagnostics.isEmpty
    let inboxOrderHandoffReady = orders.contains {
      $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import"
    }

    let items = [
      SpaceMailMVPReadinessItem(
        title: "SpaceMail configured",
        detail: hasConnection
          ? "\(configuredConnections.count) configured connection\(configuredConnections.count == 1 ? "" : "s") with host, folder, and mailbox address."
          : "Add a SpaceMail setup before testing real intake.",
        isComplete: hasConnection && !configuredConnections.isEmpty,
        tone: hasConnection && !configuredConnections.isEmpty ? "success" : "warning"
      ),
      SpaceMailMVPReadinessItem(
        title: "Credential ready",
        detail: credentialReady ? "A Keychain password reference is available for manual refresh." : "Set or check the SpaceMail Keychain credential.",
        isComplete: credentialReady,
        tone: credentialReady ? "success" : "warning"
      ),
      SpaceMailMVPReadinessItem(
        title: "Read-only refresh tested",
        detail: hasRealRefresh ? "At least one real manual IMAP refresh has completed or reported a real IMAP result." : "Run real SpaceMail refresh once credentials are ready.",
        isComplete: hasRealRefresh,
        tone: hasRealRefresh ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Mixed mailbox filtering visible",
        detail: mixedFilteringReady ? "Latest refresh results include filtering/reason evidence for mixed mailbox review." : "Run refresh or classifier tests until filtered/uncertain/imported outcomes are visible.",
        isComplete: mixedFilteringReady,
        tone: mixedFilteringReady ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Parser queue controlled",
        detail: parserQueueClear ? "No parser diagnostics currently need attention." : "\(intakeParserDiagnostics.count) parser check\(intakeParserDiagnostics.count == 1 ? "" : "s") still need review.",
        isComplete: parserQueueClear,
        tone: parserQueueClear ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Inbox-to-order handoff tested",
        detail: inboxOrderHandoffReady ? "At least one order exists from Inbox/import handoff." : "Create or link one order from a real intake row before calling the workflow tested.",
        isComplete: inboxOrderHandoffReady,
        tone: inboxOrderHandoffReady ? "success" : "attention"
      )
    ]

    let completedCount = items.filter(\.isComplete).count
    let tone: String
    let verdict: String
    let detail: String
    let nextAction: String

    if completedCount == items.count {
      tone = "success"
      verdict = "SpaceMail MVP ready for hands-on testing"
      detail = "Real read-only intake, filtering, parser review, and order handoff have enough local evidence for supervised use."
      nextAction = "Run a short hands-on test: refresh, review Inbox, create/link an order, then confirm Audit."
    } else if completedCount >= 4 {
      tone = "attention"
      verdict = "SpaceMail MVP nearly ready"
      detail = "\(completedCount) of \(items.count) readiness checks are complete."
      nextAction = items.first { !$0.isComplete }?.detail ?? "Review remaining checks."
    } else {
      tone = "warning"
      verdict = "SpaceMail MVP needs setup checks"
      detail = "\(completedCount) of \(items.count) readiness checks are complete."
      nextAction = items.first { !$0.isComplete }?.detail ?? "Complete SpaceMail setup first."
    }

    return SpaceMailMVPReadinessSummary(
      verdict: verdict,
      detail: detail,
      nextAction: nextAction,
      tone: tone,
      completedCount: completedCount,
      totalCount: items.count,
      items: items
    )
  }

  var liveMailboxMVPReadinessSummary: SpaceMailMVPReadinessSummary {
    let hasSpaceMailSetup = !spaceMailIMAPConnections.isEmpty
    let hasGmailSetup = !gmailMailboxConnections.isEmpty
    let providerCount = (hasSpaceMailSetup ? 1 : 0) + (hasGmailSetup ? 1 : 0)
    let hasMailboxSetup = providerCount > 0
    let hasSpaceMailCredential = spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus == SpaceMailCredentialStoreStatus.passwordReferenceAvailable.rawValue
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
    let hasGmailAuth = gmailMailboxConnections.contains { gmailAuthSessionState(for: $0).status == .connected }
    let hasCredentialOrAuth = hasSpaceMailCredential || hasGmailAuth
    let hasRealRefresh = spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
    let mixedFilteringReady = spaceMailIMAPConnections.contains {
      $0.mailboxMode == .mixedFiltered && ($0.lastRefreshFilteredNonOrderCount > 0 || !$0.filteredMessages.isEmpty || !$0.uncertainMessages.isEmpty || !$0.lastRefreshReasonBreakdown.isEmpty)
    } || gmailMailboxConnections.contains {
      $0.mailboxMode == .mixedFiltered && ($0.lastRefreshFilteredNonOrderCount > 0 || ($0.filteredMessages?.isEmpty == false) || ($0.uncertainMessages?.isEmpty == false))
    }
    let parserQueueClear = intakeParserDiagnostics.isEmpty
    let inboxOrderHandoffReady = orders.contains {
      $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" || $0.isInboxCreatedLocalOrder
    }
    let providerLabel: String
    if hasSpaceMailSetup && hasGmailSetup {
      providerLabel = "SpaceMail and Gmail"
    } else if hasGmailSetup {
      providerLabel = "Gmail"
    } else if hasSpaceMailSetup {
      providerLabel = "SpaceMail"
    } else {
      providerLabel = "No live mailbox provider"
    }

    let items = [
      SpaceMailMVPReadinessItem(
        title: "Mailbox provider configured",
        detail: hasMailboxSetup
          ? "\(providerLabel) setup exists for manual read-only intake."
          : "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes before testing real intake.",
        isComplete: hasMailboxSetup,
        tone: hasMailboxSetup ? "success" : "warning"
      ),
      SpaceMailMVPReadinessItem(
        title: "Credential or sign-in ready",
        detail: hasCredentialOrAuth
          ? "SpaceMail Keychain credential or Gmail Google sign-in evidence is available."
          : "Set/check the SpaceMail Keychain credential or complete Gmail Google sign-in.",
        isComplete: hasCredentialOrAuth,
        tone: hasCredentialOrAuth ? "success" : "warning"
      ),
      SpaceMailMVPReadinessItem(
        title: "Read-only refresh tested",
        detail: hasRealRefresh
          ? "At least one manual SpaceMail or Gmail refresh has produced local result evidence."
          : "Run one explicit manual read-only refresh after setup and credential/sign-in are ready.",
        isComplete: hasRealRefresh,
        tone: hasRealRefresh ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Mixed mailbox filtering visible",
        detail: mixedFilteringReady
          ? "Latest refresh results include filtered, uncertain, or reason evidence for mixed-mailbox review."
          : "Run refresh or classifier tests until imported, filtered, or uncertain outcomes are visible.",
        isComplete: mixedFilteringReady,
        tone: mixedFilteringReady ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Parser queue controlled",
        detail: parserQueueClear ? "No parser diagnostics currently need attention." : "\(intakeParserDiagnostics.count) parser check\(intakeParserDiagnostics.count == 1 ? "" : "s") still need review.",
        isComplete: parserQueueClear,
        tone: parserQueueClear ? "success" : "attention"
      ),
      SpaceMailMVPReadinessItem(
        title: "Inbox-to-order handoff tested",
        detail: inboxOrderHandoffReady ? "At least one order exists from Inbox/import handoff." : "Create or link one order from confirmed intake before calling the workflow tested.",
        isComplete: inboxOrderHandoffReady,
        tone: inboxOrderHandoffReady ? "success" : "attention"
      )
    ]

    let completedCount = items.filter(\.isComplete).count
    let tone: String
    let verdict: String
    let detail: String
    let nextAction: String

    if completedCount == items.count {
      tone = "success"
      verdict = "Live mailbox MVP ready for hands-on testing"
      detail = "\(providerLabel) read-only intake, filtering, parser review, and order handoff have enough local evidence for supervised use."
      nextAction = "Run a short hands-on test: refresh, review Inbox, create/link an order, then confirm Audit."
    } else if completedCount >= 4 {
      tone = "attention"
      verdict = "Live mailbox MVP nearly ready"
      detail = "\(completedCount) of \(items.count) readiness checks are complete across SpaceMail/Gmail intake."
      nextAction = items.first { !$0.isComplete }?.detail ?? "Review remaining checks."
    } else {
      tone = "warning"
      verdict = "Live mailbox MVP needs setup checks"
      detail = "\(completedCount) of \(items.count) readiness checks are complete across SpaceMail/Gmail intake."
      nextAction = items.first { !$0.isComplete }?.detail ?? "Complete mailbox setup first."
    }

    return SpaceMailMVPReadinessSummary(
      verdict: verdict,
      detail: detail,
      nextAction: nextAction,
      tone: tone,
      completedCount: completedCount,
      totalCount: items.count,
      items: items
    )
  }

  var liveMailboxQACheckSummary: SpaceMailQACheckSummary {
    let hasSpaceMailSetup = !spaceMailIMAPConnections.isEmpty
    let hasGmailSetup = !gmailMailboxConnections.isEmpty
    let providerLabel: String
    if hasSpaceMailSetup && hasGmailSetup {
      providerLabel = "SpaceMail and Gmail"
    } else if hasGmailSetup {
      providerLabel = "Gmail"
    } else if hasSpaceMailSetup {
      providerLabel = "SpaceMail"
    } else {
      providerLabel = "No live mailbox provider"
    }

    let hasSpaceMailCredentialEvidence = auditEvents.contains { event in
      event.entityType == .spaceMailIMAPConnection
        && (event.summary.localizedCaseInsensitiveContains("credential check succeeded")
          || event.summary.localizedCaseInsensitiveContains("credential saved"))
    }
    let hasGmailAuthEvidence = gmailMailboxConnections.contains { gmailAuthSessionState(for: $0).status == .connected }
      || auditEvents.contains { event in
        event.entityType == .gmailMailboxConnection
          && (event.summary.localizedCaseInsensitiveContains("real gmail sign-in succeeded")
            || event.summary.localizedCaseInsensitiveContains("mock gmail auth succeeded"))
      }
    let hasCredentialOrAuthEvidence = hasSpaceMailCredentialEvidence || hasGmailAuthEvidence

    let successfulSpaceMailRefresh = auditEvents.contains { event in
      event.entityType == .spaceMailIMAPConnection
        && event.summary.localizedCaseInsensitiveContains("real spacemail imap refresh")
        && (event.summary.localizedCaseInsensitiveContains("completed")
          || (event.afterDetail ?? "").localizedCaseInsensitiveContains("Fetch result: Fetch success"))
    }
    let successfulGmailRefresh = auditEvents.contains { event in
      event.entityType == .gmailMailboxConnection
        && event.summary.localizedCaseInsensitiveContains("gmail refresh")
        && (event.summary.localizedCaseInsensitiveContains("completed")
          || (event.afterDetail ?? "").localizedCaseInsensitiveContains("Fetch result: Fetch success"))
    } || gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
    let hasRefreshEvidence = successfulSpaceMailRefresh || successfulGmailRefresh

    let spaceMailFilteringEvidence = spaceMailIMAPConnections.contains {
      $0.mailboxMode == .mixedFiltered
        && ($0.lastRefreshFilteredNonOrderCount > 0 || !$0.lastRefreshReasonBreakdown.isEmpty || !$0.filteredMessages.isEmpty || !$0.uncertainMessages.isEmpty)
    }
    let gmailFilteringEvidence = gmailMailboxConnections.contains {
      $0.mailboxMode == .mixedFiltered
        && ($0.lastRefreshFilteredNonOrderCount > 0 || ($0.filteredMessages?.isEmpty == false) || ($0.uncertainMessages?.isEmpty == false) || ($0.lastRefreshFilteredExamples?.isEmpty == false) || ($0.lastRefreshUncertainExamples?.isEmpty == false))
    }
    let hasFilteringEvidence = spaceMailFilteringEvidence || gmailFilteringEvidence

    let parserEvidence = !intakeParserDiagnostics.isEmpty || intakeEmails.contains { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue
    }
    let inboxOrderHandoffEvidence = orders.contains {
      $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" || $0.isInboxCreatedLocalOrder
    }
    let liveMailboxAuditEvidence = auditEvents.contains { event in
      [.spaceMailIMAPConnection, .gmailMailboxConnection, .intakeEmail, .order].contains(event.entityType)
        || event.summary.localizedCaseInsensitiveContains("SpaceMail")
        || event.summary.localizedCaseInsensitiveContains("Gmail")
    }

    let checks = [
      SpaceMailQACheck(
        title: "Provider setup evidence",
        detail: "At least one live mailbox provider is configured for manual intake testing.",
        evidence: hasSpaceMailSetup || hasGmailSetup ? "\(providerLabel) setup exists." : "No SpaceMail or Gmail setup exists yet.",
        isComplete: hasSpaceMailSetup || hasGmailSetup,
        tone: hasSpaceMailSetup || hasGmailSetup ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Credential or sign-in evidence",
        detail: "SpaceMail has Keychain credential evidence or Gmail has sign-in evidence.",
        evidence: hasCredentialOrAuthEvidence ? "Credential/sign-in evidence exists without storing secrets in JSON." : "No SpaceMail credential check/save or Gmail sign-in evidence yet.",
        isComplete: hasCredentialOrAuthEvidence,
        tone: hasCredentialOrAuthEvidence ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Read-only refresh evidence",
        detail: "A manual SpaceMail or Gmail refresh completed or produced a clear safe result.",
        evidence: hasRefreshEvidence ? "Manual read-only refresh evidence exists." : "Run one real or mock manual refresh to collect evidence.",
        isComplete: hasRefreshEvidence,
        tone: hasRefreshEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Mixed-mailbox decision evidence",
        detail: "Filtering, uncertain, duplicate, or reason evidence exists for mixed-use mailbox review.",
        evidence: hasFilteringEvidence ? "Mixed-mailbox decision evidence is visible for operator review." : "Run refresh/classifier checks until filtered or uncertain decisions are visible.",
        isComplete: hasFilteringEvidence,
        tone: hasFilteringEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Parser evidence",
        detail: "Imported intake has parser output or diagnostics for order/tracking review.",
        evidence: parserEvidence ? "\(intakeParserDiagnostics.count) parser checks and \(intakeEmails.count) intake emails are available." : "No parser or extracted order/tracking evidence yet.",
        isComplete: parserEvidence,
        tone: parserEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Inbox-to-order handoff evidence",
        detail: "At least one order has been created or linked from Inbox/import work.",
        evidence: inboxOrderHandoffEvidence ? "Inbox/import-created order evidence exists." : "Create or link one order from Inbox before RC testing.",
        isComplete: inboxOrderHandoffEvidence,
        tone: inboxOrderHandoffEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Audit trail evidence",
        detail: "Audit contains mailbox, intake, or order events for traceability.",
        evidence: liveMailboxAuditEvidence ? "\(auditEvents.count) audit events available." : "No live mailbox/intake/order audit evidence yet.",
        isComplete: liveMailboxAuditEvidence,
        tone: liveMailboxAuditEvidence ? "success" : "warning"
      )
    ]

    let completedCount = checks.filter(\.isComplete).count
    let tone: String
    let verdict: String
    if completedCount == checks.count {
      tone = "success"
      verdict = "Live mailbox QA evidence complete"
    } else if completedCount >= 5 {
      tone = "attention"
      verdict = "Live mailbox QA evidence mostly ready"
    } else {
      tone = "warning"
      verdict = "Live mailbox QA evidence incomplete"
    }

    return SpaceMailQACheckSummary(
      verdict: verdict,
      detail: "\(completedCount) of \(checks.count) live mailbox QA checks are complete across SpaceMail/Gmail.",
      completedCount: completedCount,
      totalCount: checks.count,
      tone: tone,
      checks: checks
    )
  }

  var spaceMailQACheckSummary: SpaceMailQACheckSummary {
    let hasCredentialEvidence = auditEvents.contains { event in
      event.entityType == .spaceMailIMAPConnection
        && (event.summary.localizedCaseInsensitiveContains("credential check succeeded")
          || event.summary.localizedCaseInsensitiveContains("credential saved"))
    }
    let realRefreshEvents = auditEvents.filter { event in
      event.entityType == .spaceMailIMAPConnection
        && event.summary.localizedCaseInsensitiveContains("real spacemail imap refresh")
    }
    let successfulRefreshEvents = realRefreshEvents.filter {
      $0.summary.localizedCaseInsensitiveContains("completed")
        || ($0.afterDetail ?? "").localizedCaseInsensitiveContains("Fetch result: Fetch success")
    }
    let filteringEvidence = spaceMailIMAPConnections.contains {
      $0.lastRefreshFilteredNonOrderCount > 0 || !$0.lastRefreshReasonBreakdown.isEmpty
    }
    let parserEvidence = !intakeParserDiagnostics.isEmpty || intakeEmails.contains { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue
    }
    let orderHandoffEvidence = orders.contains {
      $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import"
    }
    let auditTrailEvidence = auditEvents.contains { event in
      event.entityType == .intakeEmail || event.entityType == .order || event.entityType == .spaceMailIMAPConnection
    }

    let checks = [
      SpaceMailQACheck(
        title: "Credential evidence",
        detail: "Keychain password/app-password status has been checked or saved locally.",
        evidence: hasCredentialEvidence ? "Found SpaceMail credential audit evidence." : "No successful credential check/save evidence yet.",
        isComplete: hasCredentialEvidence,
        tone: hasCredentialEvidence ? "success" : "warning"
      ),
      SpaceMailQACheck(
        title: "Read-only refresh evidence",
        detail: "A real manual SpaceMail IMAP refresh completed or returned a clear result.",
        evidence: successfulRefreshEvents.first?.summary ?? "No completed real refresh evidence yet.",
        isComplete: !successfulRefreshEvents.isEmpty,
        tone: successfulRefreshEvents.isEmpty ? "attention" : "success"
      ),
      SpaceMailQACheck(
        title: "Mixed-mailbox filter evidence",
        detail: "The latest SpaceMail state shows filtered/reasoned mixed-mailbox decisions.",
        evidence: filteringEvidence ? "Filtered count or reason breakdown exists." : "Run a real refresh or classifier suite to collect filter evidence.",
        isComplete: filteringEvidence,
        tone: filteringEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Parser evidence",
        detail: "Inbox has parser diagnostics or extracted order/tracking fields to review.",
        evidence: parserEvidence ? "\(intakeParserDiagnostics.count) parser checks, \(intakeEmails.count) intake emails." : "No parser evidence yet.",
        isComplete: parserEvidence,
        tone: parserEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Order handoff evidence",
        detail: "At least one order has been created or linked from intake/import work.",
        evidence: orderHandoffEvidence ? "Inbox/import-created order evidence exists." : "Create or link one order from Inbox before RC testing.",
        isComplete: orderHandoffEvidence,
        tone: orderHandoffEvidence ? "success" : "attention"
      ),
      SpaceMailQACheck(
        title: "Audit trail evidence",
        detail: "Audit contains SpaceMail, intake, or order events for traceability.",
        evidence: auditTrailEvidence ? "\(auditEvents.count) audit events available." : "No intake/order audit evidence yet.",
        isComplete: auditTrailEvidence,
        tone: auditTrailEvidence ? "success" : "warning"
      )
    ]

    let completedCount = checks.filter(\.isComplete).count
    let tone: String
    let verdict: String
    if completedCount == checks.count {
      tone = "success"
      verdict = "SpaceMail RC evidence complete"
    } else if completedCount >= 4 {
      tone = "attention"
      verdict = "SpaceMail RC evidence mostly ready"
    } else {
      tone = "warning"
      verdict = "SpaceMail RC evidence incomplete"
    }

    return SpaceMailQACheckSummary(
      verdict: verdict,
      detail: "\(completedCount) of \(checks.count) QA evidence checks are complete.",
      completedCount: completedCount,
      totalCount: checks.count,
      tone: tone,
      checks: checks
    )
  }

  func spaceMailIntakeHealthSummary(for connection: SpaceMailIMAPConnection) -> SpaceMailIntakeHealthSummary {
    let mailboxID = connection.id
    let ingestRecords = mailboxIngestRecords.filter { $0.sourceMailboxID == mailboxID }
    let linkedIntakeIDs = Set(ingestRecords.compactMap(\.intakeEmailID))
    let linkedIntakeCount = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }.count
    let parserIssueCount = intakeParserDiagnostics.filter { linkedIntakeIDs.contains($0.intakeEmailID) }.count
    let reasonLabels = connection.lastRefreshReasonBreakdown
      .prefix(4)
      .map { "\($0.decision): \($0.reason) x\($0.count)" }

    let status = connection.connectionStatus
    let verdict: String
    let detail: String
    let nextAction: String
    let tone: String

    if status.localizedCaseInsensitiveContains("missing") || status.localizedCaseInsensitiveContains("failed") {
      verdict = "Setup needs attention"
      detail = "The latest SpaceMail state did not reach a clean read-only refresh."
      nextAction = "Check host, folder, SSL/TLS, and Keychain credential status, then run real SpaceMail refresh."
      tone = "warning"
    } else if connection.lastRefreshFetchedCount == 0 && connection.lastManualRefreshDate == "Never" {
      verdict = "Ready for first refresh"
      detail = "SpaceMail setup exists, but no real refresh has been recorded yet."
      nextAction = "Set/check the Keychain credential, then run a manual real refresh."
      tone = "neutral"
    } else if connection.lastRefreshUncertainCount > 0 || !connection.uncertainMessages.isEmpty {
      verdict = "Uncertain messages need review"
      detail = "Some mixed-mailbox messages looked order-related but not strong enough for automatic Inbox import."
      nextAction = "Review uncertain previews, import true order mail, or dismiss/filter non-order mail locally."
      tone = "attention"
    } else if parserIssueCount > 0 {
      verdict = "Parser review needed"
      detail = "Imported intake exists, but local parsing still needs a person to confirm order or tracking fields."
      nextAction = "Open the parser review queue, reprocess if needed, or create a follow-up task."
      tone = "attention"
    } else if connection.lastRefreshImportedCount > 0 {
      verdict = "Order intake captured"
      detail = "The latest refresh imported likely order-related messages into Inbox without mailbox mutation."
      nextAction = "Review the imported Inbox rows and create or link orders where appropriate."
      tone = "success"
    } else if connection.lastRefreshFilteredNonOrderCount > 0 && connection.lastRefreshDuplicateCount == 0 {
      verdict = "Filter working"
      detail = "The mixed mailbox filter kept fetched non-order messages out of Inbox."
      nextAction = "No action needed unless filtered examples look order-related."
      tone = "success"
    } else if connection.lastRefreshDuplicateCount > 0 {
      verdict = "No new order mail"
      detail = "The latest refresh found messages ParcelOps had already captured or reviewed."
      nextAction = "Wait for new mail or review filtered/parsed examples if something looks wrong."
      tone = "neutral"
    } else {
      verdict = "Monitor mailbox"
      detail = "SpaceMail is configured, but the latest refresh did not produce actionable intake."
      nextAction = "Run a manual refresh after forwarding a known order update."
      tone = "neutral"
    }

    return SpaceMailIntakeHealthSummary(
      connectionID: connection.id,
      displayName: connection.displayName,
      verdict: verdict,
      detail: detail,
      nextAction: nextAction,
      tone: tone,
      fetchedCount: connection.lastRefreshFetchedCount,
      importedCount: connection.lastRefreshImportedCount,
      duplicateCount: connection.lastRefreshDuplicateCount,
      filteredCount: connection.lastRefreshFilteredNonOrderCount,
      uncertainCount: connection.lastRefreshUncertainCount,
      parserIssueCount: parserIssueCount,
      linkedIntakeCount: linkedIntakeCount,
      pendingFilteredReviewCount: connection.filteredMessages.count,
      pendingUncertainReviewCount: connection.uncertainMessages.count,
      lastRefreshDate: connection.lastManualRefreshDate,
      topReasonLabels: reasonLabels
    )
  }

  func gmailIntakeHealthSummary(for connection: GmailMailboxConnection) -> GmailIntakeHealthSummary {
    let mailboxID = connection.id
    let ingestRecords = mailboxIngestRecords.filter { $0.sourceMailboxID == mailboxID }
    let linkedIntakeIDs = Set(ingestRecords.compactMap(\.intakeEmailID))
    let linkedIntakeCount = intakeEmails.filter { linkedIntakeIDs.contains($0.id) }.count
    let status = connection.connectionStatus
    let readiness = gmailOAuthReadinessSummary(for: connection)
    let authState = gmailAuthSessionState(for: connection)
    let uncertainCount = connection.lastRefreshUncertainCount ?? 0
    let pendingUncertainCount = connection.uncertainMessages?.count ?? 0

    let verdict: String
    let detail: String
    let nextAction: String
    let tone: String

    if !readiness.isReady {
      verdict = "Gmail setup blocked"
      detail = "\(readiness.statusText). \(readiness.compiledClientIDStatus). \(readiness.compiledCallbackSchemeStatus)."
      nextAction = "Open Mailbox Monitor or Settings, fix the Gmail setup blockers, then run Check readiness before sign-in."
      tone = "warning"
    } else if authState.status != .connected && connection.lastRefreshFetchedCount == 0 {
      verdict = "Gmail sign-in needed"
      detail = "Gmail setup and compiled callback checks are ready, but the mailbox is not signed in for the read-only refresh path."
      nextAction = "Run Test real Google sign-in, then run manual read-only Gmail refresh."
      tone = "attention"
    } else if status.localizedCaseInsensitiveContains("Auth required") ||
      status.localizedCaseInsensitiveContains("Consent required") ||
      status.localizedCaseInsensitiveContains("API rejected") ||
      status.localizedCaseInsensitiveContains("Network failed") ||
      status.localizedCaseInsensitiveContains("not configured") {
      verdict = "Gmail setup needs attention"
      detail = "The latest Gmail state did not reach a clean read-only refresh even though setup readiness checks passed."
      nextAction = "Check Google consent, sign in again, then run manual read-only Gmail refresh."
      tone = "warning"
    } else if connection.lastRefreshFetchedCount == 0 && connection.lastManualRefreshDate == "Never" {
      verdict = "Ready for Gmail setup"
      detail = "Gmail setup exists, but no readiness check or refresh has been recorded yet."
      nextAction = "Save setup, run Test real Google sign-in, then use manual read-only Gmail refresh."
      tone = "neutral"
    } else if pendingUncertainCount > 0 || uncertainCount > 0 {
      verdict = "Gmail uncertain mail needs review"
      detail = "Some mixed Gmail messages looked order-related but not strong enough for automatic Inbox import."
      nextAction = "Review uncertain Gmail previews in Mailbox Monitor, import true order mail, or dismiss non-order mail locally."
      tone = "attention"
    } else if connection.lastRefreshImportedCount > 0 {
      verdict = "Gmail order intake captured"
      detail = "The latest Gmail refresh imported likely order-related messages into Inbox without mailbox mutation."
      nextAction = "Review imported Inbox rows and create or link orders where appropriate."
      tone = "success"
    } else if connection.lastRefreshFilteredNonOrderCount > 0 && connection.lastRefreshDuplicateCount == 0 {
      verdict = "Gmail filter working"
      detail = "The mixed mailbox filter kept fetched non-order Gmail messages out of Inbox."
      nextAction = "No action needed unless filtered examples look order-related."
      tone = "success"
    } else if connection.lastRefreshDuplicateCount > 0 {
      verdict = "No new Gmail order mail"
      detail = "The latest Gmail refresh found messages ParcelOps had already captured or reviewed. Duplicate-safe handling can refresh existing Inbox rows from newly parsed previews where fields change."
      nextAction = "Wait for new mail, review refreshed Inbox rows, or check filtered/uncertain examples if something looks wrong."
      tone = "neutral"
    } else if status.localizedCaseInsensitiveContains("Ready") || status.localizedCaseInsensitiveContains("sign-in") {
      verdict = "Gmail ready for manual refresh"
      detail = "Gmail setup has readiness or sign-in evidence, but no actionable intake is pending."
      nextAction = "Run manual read-only Gmail refresh when you want to check the mailbox."
      tone = "neutral"
    } else {
      verdict = "Monitor Gmail mailbox"
      detail = "Gmail is configured, but the latest state did not produce actionable intake."
      nextAction = "Run a readiness check or manual refresh after confirming Google setup."
      tone = "neutral"
    }

    return GmailIntakeHealthSummary(
      connectionID: connection.id,
      displayName: connection.displayName,
      verdict: verdict,
      detail: detail,
      nextAction: nextAction,
      tone: tone,
      fetchedCount: connection.lastRefreshFetchedCount,
      importedCount: connection.lastRefreshImportedCount,
      duplicateCount: connection.lastRefreshDuplicateCount,
      filteredCount: connection.lastRefreshFilteredNonOrderCount,
      uncertainCount: uncertainCount,
      linkedIntakeCount: linkedIntakeCount,
      pendingUncertainReviewCount: pendingUncertainCount,
      lastRefreshDate: connection.lastManualRefreshDate,
      lastRefreshSummary: connection.lastRefreshSummary
    )
  }

  func spaceMailAssignedFollowUpSummaries(for connection: SpaceMailIMAPConnection) -> [String] {
    let connectionID = connection.id.uuidString
    let taskSummaries = reviewTasks
      .filter { task in
        (task.status != .completed || task.reviewState != .accepted)
          && (task.linkedEntityID == connectionID
            || task.title.localizedCaseInsensitiveContains("spacemail")
            || task.summary.localizedCaseInsensitiveContains("spacemail"))
      }
      .map { task in
        "Task: \(task.title) · \(task.status.rawValue) · \(task.assignee)"
      }

    let handoffSummaries = handoffNotes
      .filter { note in
        (note.status != .completed || note.reviewState != .accepted)
          && (note.linkedEntityID == connectionID
            || note.title.localizedCaseInsensitiveContains("spacemail")
            || note.summary.localizedCaseInsensitiveContains("spacemail")
            || note.notes.localizedCaseInsensitiveContains("spacemail"))
      }
      .map { note in
        "Handoff: \(note.title) · \(note.status.rawValue) · \(note.assignee)"
      }

    return Array((handoffSummaries + taskSummaries).prefix(6))
  }

  func spaceMailClassifierImpactPreviews(for connection: SpaceMailIMAPConnection) -> [SpaceMailClassifierImpactPreview] {
    SpaceMailFilterPreset.allCases.map { preset in
      spaceMailClassifierImpactPreview(for: connection, preset: preset)
    }
  }

  var microsoft365OAuthReadinessSummaries: [Microsoft365OAuthReadinessSummary] {
    microsoft365MailboxConnections.map { microsoft365OAuthReadinessSummary(for: $0) }
  }

  var reviewQueueCount: Int {
    reviewOrders.count + reviewMailEvents.count + reviewIntakeEmails.count + intakeParserDiagnostics.count + spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count } + reviewEvidenceAttachments.count + reviewCarrierTrackingEvents.count + reviewTasksNeedingAttention.count + handoffNotesNeedingAttention.count + policiesNeedingReview.count + playbooksNeedingReview.count + enabledHighPriorityPlaybooks.count + draftMessagesNeedingReview.count + contactsNeedingReview.count + customerProfilesNeedingReview.count + disabledCustomerProfileCount + destinationAddressesNeedingReview.count + disabledDestinationAddressCount + highRiskDestinationAddresses.count + deliveryInstructionsNeedingReview.count + disabledDeliveryInstructionCount + highRiskDeliveryInstructions.count + deliveryInstructionsWithAccessConstraints.count + packageContentsNeedingReview.count + unverifiedPackageContents.count + packageContentDiscrepancies.count + highRiskPackageContents.count + highValuePackageContents.count + costRecordsNeedingReview.count + disputedCostRecords.count + unreimbursedCostRecords.count + unapprovedCostRecords.count + highRiskCostRecords.count + missingBudgetCodeCostRecords.count + returnClaimsNeedingReview.count + disputedReturnClaims.count + unresolvedReturnClaims.count + overdueReturnClaims.count + highRiskReturnClaims.count + returnClaimsMissingEvidence.count + procurementRequestsNeedingReview.count + unapprovedProcurementRequests.count + rejectedProcurementRequests.count + notYetOrderedProcurementRequests.count + overdueProcurementRequests.count + highRiskProcurementRequests.count + missingBudgetCodeProcurementRequests.count + receivingInspectionsNeedingReview.count + blockedReceivingInspections.count + unresolvedInspectionDiscrepancies.count + highRiskReceivingInspections.count + overdueReceivingInspections.count + quantityMismatchReceivingInspections.count + inventoryReceiptsNeedingReview.count + rejectedInventoryReceipts.count + partiallyAcceptedInventoryReceipts.count + highRiskInventoryReceipts.count + unassignedInventoryReceipts.count + inventoryReceiptsMissingStorage.count + storageLocationsNeedingReview.count + disabledStorageLocations.count + highRiskStorageLocations.count + storageLocationsMissingCodes.count + storageLocationsWithAccessNotes.count + storageLocationsWithCapacityWarnings.count + custodyRecordsNeedingReview.count + disputedCustodyRecords.count + openCustodyTransfers.count + overdueCustodyRecords.count + highRiskCustodyRecords.count + custodyRecordsMissingCustodians.count + custodyRecordsMissingLocations.count + labelReferencesNeedingReview.count + invalidLabelReferences.count + unverifiedLabelReferences.count + highRiskLabelReferences.count + labelReferencesMissingValues.count + labelReferencesMissingLinkedRecords.count + scanSessionsNeedingReview.count + mismatchScanSessions.count + incompleteScanSessions.count + highRiskScanSessions.count + scanSessionsMissingCapturedValues.count + scanSessionsMissingLabelReferences.count + shipmentManifestsNeedingReview.count + blockedShipmentManifests.count + undispatchedShipmentManifests.count + highRiskShipmentManifests.count + shipmentManifestsMissingIncludedOrders.count + shipmentManifestsMissingHandoffLocation.count + shipmentManifestsWithIncompleteScans.count + dispatchChecklistsNeedingReview.count + blockedDispatchChecklists.count + incompleteDispatchChecklists.count + highRiskDispatchChecklists.count + dispatchChecklistsMissingRequirements.count + dispatchChecklistsLinkedToBlockedManifests.count + accountRecordsNeedingReview.count + vendorProfilesNeedingReview.count + highRiskEnabledVendorProfiles.count + shipmentGroupsNeedingReview.count + highRiskShipmentGroups.count + importQueueItemsNeedingReview.count + blockedImportQueueItems.count + acceptanceRecordsNeedingReview.count + highSeverityReconciliationIssues.count + highSeverityValidationIssues.count
  }

  var reviewEvidenceAttachments: [EvidenceAttachment] {
    evidenceAttachments.filter { $0.reviewState != .accepted }
  }

  var reviewCarrierTrackingEvents: [CarrierTrackingEvent] {
    carrierTrackingEvents.filter { $0.severity != .info || $0.reviewState != .accepted }
  }

  var trackingWarningCount: Int {
    carrierTrackingEvents.filter { $0.severity == .watch || $0.severity == .critical }.count
  }

  var criticalTrackingCount: Int {
    carrierTrackingEvents.filter { $0.severity == .critical }.count
  }

  var enabledAutomationRuleCount: Int {
    automationRules.filter(\.isEnabled).count
  }

  var disabledAutomationRuleCount: Int {
    automationRules.filter { !$0.isEnabled }.count
  }

  var openReviewTasks: [ReviewTask] {
    reviewTasks.filter { $0.status != .completed }
  }

  var reviewTasksNeedingAttention: [ReviewTask] {
    reviewTasks.filter { task in
      task.status != .completed && (task.priority == .high || task.priority == .urgent || task.reviewState != .accepted || task.isLocallyOverdue)
    }
  }

  var overdueOpenReviewTasks: [ReviewTask] {
    openReviewTasks.filter(\.isLocallyOverdue)
  }

  var urgentOpenReviewTasks: [ReviewTask] {
    openReviewTasks.filter { $0.priority == .urgent }
  }

  var openHandoffNotes: [HandoffNote] {
    handoffNotes.filter { $0.status != .completed }
  }

  var overdueHandoffNotes: [HandoffNote] {
    openHandoffNotes.filter(\.isLocallyOverdue)
  }

  var highPriorityHandoffNotes: [HandoffNote] {
    openHandoffNotes.filter { $0.priority == .high || $0.priority == .urgent }
  }

  var handoffNotesNeedingReview: [HandoffNote] {
    handoffNotes.filter { $0.reviewState != .accepted }
  }

  var handoffNotesNeedingAttention: [HandoffNote] {
    Array(Set(overdueHandoffNotes + highPriorityHandoffNotes + handoffNotesNeedingReview + openHandoffNotes.filter { $0.status == .open }))
  }

  var policiesNeedingReview: [SLAPolicy] {
    slaPolicies.filter { $0.reviewState != .accepted }
  }

  var enabledSLAPolicyCount: Int {
    slaPolicies.filter(\.isEnabled).count
  }

  var disabledSLAPolicyCount: Int {
    slaPolicies.filter { !$0.isEnabled }.count
  }

  var recentPolicyMatches: [SLAPolicy] {
    Array(slaPolicies.filter { $0.matchCount > 0 }.sorted { lhs, rhs in
      lhs.lastEvaluatedDate > rhs.lastEvaluatedDate
    }.prefix(5))
  }

  var playbooksNeedingReview: [ExceptionPlaybook] {
    exceptionPlaybooks.filter { $0.reviewState != .accepted }
  }

  var enabledHighPriorityPlaybooks: [ExceptionPlaybook] {
    exceptionPlaybooks.filter { $0.isEnabled && ($0.priority == .high || $0.priority == .urgent) }
  }

  var enabledPlaybookCount: Int {
    exceptionPlaybooks.filter(\.isEnabled).count
  }

  var disabledPlaybookCount: Int {
    exceptionPlaybooks.filter { !$0.isEnabled }.count
  }

  var enabledCommunicationTemplateCount: Int {
    communicationTemplates.filter(\.isEnabled).count
  }

  var disabledCommunicationTemplateCount: Int {
    communicationTemplates.filter { !$0.isEnabled }.count
  }

  var draftMessagesNeedingReview: [DraftMessage] {
    draftMessages.filter { $0.reviewState != .accepted || $0.status == .draft || $0.status == .reopened }
  }

  var enabledContactCount: Int {
    contactDirectoryEntries.filter(\.isEnabled).count
  }

  var disabledContactCount: Int {
    contactDirectoryEntries.filter { !$0.isEnabled }.count
  }

  var contactsNeedingReview: [ContactDirectoryEntry] {
    contactDirectoryEntries.filter { $0.reviewState != .accepted }
  }

  var enabledCustomerProfileCount: Int {
    customerRecipientProfiles.filter(\.isEnabled).count
  }

  var disabledCustomerProfileCount: Int {
    customerRecipientProfiles.filter { !$0.isEnabled }.count
  }

  var customerProfilesNeedingReview: [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.reviewState != .accepted }
  }

  var enabledDestinationAddressCount: Int {
    destinationAddresses.filter(\.isEnabled).count
  }

  var disabledDestinationAddressCount: Int {
    destinationAddresses.filter { !$0.isEnabled }.count
  }

  var destinationAddressesNeedingReview: [DestinationAddressRecord] {
    destinationAddresses.filter { $0.reviewState != .accepted }
  }

  var highRiskDestinationAddresses: [DestinationAddressRecord] {
    destinationAddresses.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var enabledDeliveryInstructionCount: Int {
    deliveryInstructions.filter(\.isEnabled).count
  }

  var disabledDeliveryInstructionCount: Int {
    deliveryInstructions.filter { !$0.isEnabled }.count
  }

  var deliveryInstructionsNeedingReview: [DeliveryInstructionRecord] {
    deliveryInstructions.filter { $0.reviewState != .accepted }
  }

  var highRiskDeliveryInstructions: [DeliveryInstructionRecord] {
    deliveryInstructions.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var deliveryInstructionsWithAccessConstraints: [DeliveryInstructionRecord] {
    deliveryInstructions.filter { !$0.accessConstraintSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var packageContentsNeedingReview: [PackageContentRecord] {
    packageContents.filter { $0.reviewState != .accepted }
  }

  var unverifiedPackageContents: [PackageContentRecord] {
    packageContents.filter { $0.verificationStatus != .verified }
  }

  var packageContentDiscrepancies: [PackageContentRecord] {
    packageContents.filter { $0.verificationStatus == .discrepancy || !$0.discrepancySummary.localizedCaseInsensitiveContains("no discrepancy") }
  }

  var highRiskPackageContents: [PackageContentRecord] {
    packageContents.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var highValuePackageContents: [PackageContentRecord] {
    packageContents.filter { $0.valueBand == .high || $0.valueBand == .critical }
  }

  var costRecordsNeedingReview: [CostRecord] {
    costRecords.filter { $0.reviewState != .accepted }
  }

  var disputedCostRecords: [CostRecord] {
    costRecords.filter { $0.reimbursementStatus == .disputed || $0.approvalStatus == .rejected }
  }

  var unreimbursedCostRecords: [CostRecord] {
    costRecords.filter { $0.reimbursementStatus == .notSubmitted || $0.reimbursementStatus == .pending || $0.reimbursementStatus == .disputed }
  }

  var unapprovedCostRecords: [CostRecord] {
    costRecords.filter { $0.approvalStatus != .approved }
  }

  var highRiskCostRecords: [CostRecord] {
    costRecords.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var missingBudgetCodeCostRecords: [CostRecord] {
    costRecords.filter { cost in
      let budget = cost.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines)
      return budget.isEmpty || budget.localizedCaseInsensitiveContains("missing") || budget.localizedCaseInsensitiveContains("confirm")
    }
  }

  var returnClaimsNeedingReview: [ReturnClaimRecord] {
    returnClaims.filter { $0.reviewState != .accepted }
  }

  var disputedReturnClaims: [ReturnClaimRecord] {
    returnClaims.filter { $0.claimStatus == .disputed || $0.claimStatus == .blocked }
  }

  var unresolvedReturnClaims: [ReturnClaimRecord] {
    returnClaims.filter { $0.claimStatus != .resolved && $0.claimStatus != .approved }
  }

  var overdueReturnClaims: [ReturnClaimRecord] {
    returnClaims.filter { $0.dueDate.localizedCaseInsensitiveContains("overdue") || $0.dueDate.localizedCaseInsensitiveContains("today") }
  }

  var highRiskReturnClaims: [ReturnClaimRecord] {
    returnClaims.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var returnClaimsMissingEvidence: [ReturnClaimRecord] {
    returnClaims.filter { $0.evidenceAttachmentIDs.isEmpty }
  }

  var procurementRequestsNeedingReview: [ProcurementRequest] {
    procurementRequests.filter { $0.reviewState != .accepted }
  }

  var unapprovedProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { $0.approvalStatus != .approved }
  }

  var rejectedProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { $0.approvalStatus == .rejected || $0.procurementStatus == .blocked }
  }

  var notYetOrderedProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { $0.procurementStatus == .requested || $0.procurementStatus == .approvedToOrder || $0.procurementStatus == .blocked }
  }

  var overdueProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { $0.neededByDate.localizedCaseInsensitiveContains("overdue") || $0.neededByDate.localizedCaseInsensitiveContains("today") }
  }

  var highRiskProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var missingBudgetCodeProcurementRequests: [ProcurementRequest] {
    procurementRequests.filter { request in
      let budget = request.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines)
      return budget.isEmpty || budget.localizedCaseInsensitiveContains("missing") || budget.localizedCaseInsensitiveContains("confirm")
    }
  }

  var receivingInspectionsNeedingReview: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.reviewState != .accepted }
  }

  var blockedReceivingInspections: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.inspectionStatus == .blocked }
  }

  var unresolvedInspectionDiscrepancies: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.discrepancyType != .none && $0.inspectionStatus != .resolved }
  }

  var highRiskReceivingInspections: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var overdueReceivingInspections: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.dueDate.localizedCaseInsensitiveContains("overdue") || $0.dueDate.localizedCaseInsensitiveContains("today") }
  }

  var quantityMismatchReceivingInspections: [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.quantityExpected != $0.quantityReceived || $0.discrepancyType == .quantityMismatch }
  }

  var inventoryReceiptsNeedingReview: [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.reviewState != .accepted }
  }

  var rejectedInventoryReceipts: [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.stockHandoffStatus == .rejected || $0.stockHandoffStatus == .needsReview }
  }

  var partiallyAcceptedInventoryReceipts: [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.stockHandoffStatus == .partiallyAccepted || $0.quantityRejected > 0 }
  }

  var highRiskInventoryReceipts: [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var unassignedInventoryReceipts: [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.assignedOwnerTeam.localizedCaseInsensitiveContains("unassigned") }
  }

  var inventoryReceiptsMissingStorage: [InventoryReceiptRecord] {
    inventoryReceipts.filter { receipt in
      let location = receipt.storageLocationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
      return location.isEmpty || location.localizedCaseInsensitiveContains("unassigned") || location.localizedCaseInsensitiveContains("confirm")
    }
  }

  var storageLocationsNeedingReview: [StorageLocationRecord] {
    storageLocations.filter { $0.reviewState != .accepted }
  }

  var disabledStorageLocations: [StorageLocationRecord] {
    storageLocations.filter { !$0.isEnabled }
  }

  var highRiskStorageLocations: [StorageLocationRecord] {
    storageLocations.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var storageLocationsMissingCodes: [StorageLocationRecord] {
    storageLocations.filter { location in
      let code = location.locationCode.trimmingCharacters(in: .whitespacesAndNewlines)
      return code.isEmpty || code.localizedCaseInsensitiveContains("missing") || code.localizedCaseInsensitiveContains("confirm")
    }
  }

  var storageLocationsWithAccessNotes: [StorageLocationRecord] {
    storageLocations.filter { !$0.accessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var storageLocationsWithCapacityWarnings: [StorageLocationRecord] {
    storageLocations.filter { location in
      location.capacitySummary.localizedCaseInsensitiveContains("warning")
        || location.currentUsageSummary.localizedCaseInsensitiveContains("warning")
        || location.currentUsageSummary.localizedCaseInsensitiveContains("full")
    }
  }

  var custodyRecordsNeedingReview: [CustodyRecord] {
    custodyRecords.filter { $0.reviewState != .accepted }
  }

  var disputedCustodyRecords: [CustodyRecord] {
    custodyRecords.filter { $0.custodyStatus == .disputed || $0.custodyStatus == .needsReview }
  }

  var openCustodyTransfers: [CustodyRecord] {
    custodyRecords.filter { $0.custodyStatus == .pendingTransfer || $0.custodyStatus == .transferred }
  }

  var overdueCustodyRecords: [CustodyRecord] {
    custodyRecords.filter { $0.expectedReturnCloseDate.localizedCaseInsensitiveContains("overdue") || $0.expectedReturnCloseDate.localizedCaseInsensitiveContains("today") }
  }

  var highRiskCustodyRecords: [CustodyRecord] {
    custodyRecords.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var custodyRecordsMissingCustodians: [CustodyRecord] {
    custodyRecords.filter { record in
      let current = record.currentCustodianTeam.trimmingCharacters(in: .whitespacesAndNewlines)
      return current.isEmpty || current.localizedCaseInsensitiveContains("unassigned") || current.localizedCaseInsensitiveContains("unknown")
    }
  }

  var custodyRecordsMissingLocations: [CustodyRecord] {
    custodyRecords.filter { $0.sourceLocationID == nil || $0.destinationLocationID == nil }
  }

  var labelReferencesNeedingReview: [LabelReferenceRecord] {
    labelReferenceRecords.filter { $0.reviewState != .accepted }
  }

  var invalidLabelReferences: [LabelReferenceRecord] {
    labelReferenceRecords.filter { $0.labelStatus == .invalidNeedsReview }
  }

  var unverifiedLabelReferences: [LabelReferenceRecord] {
    labelReferenceRecords.filter { $0.labelStatus == .draft || $0.labelStatus == .printedLocally || $0.labelStatus == .missingValue }
  }

  var highRiskLabelReferences: [LabelReferenceRecord] {
    labelReferenceRecords.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var labelReferencesMissingValues: [LabelReferenceRecord] {
    labelReferenceRecords.filter { record in
      let value = record.labelValuePlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
      return value.isEmpty || value.localizedCaseInsensitiveContains("to assign") || value.localizedCaseInsensitiveContains("missing")
    }
  }

  var labelReferencesMissingLinkedRecords: [LabelReferenceRecord] {
    labelReferenceRecords.filter {
      $0.storageLocationID == nil
        && $0.inventoryReceiptID == nil
        && $0.custodyRecordID == nil
        && $0.orderID == nil
        && $0.shipmentGroupID == nil
        && $0.packageContentID == nil
        && $0.evidenceAttachmentIDs.isEmpty
    }
  }

  var scanSessionsNeedingReview: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.reviewState != .accepted }
  }

  var mismatchScanSessions: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.scanStatus == .mismatchNeedsReview }
  }

  var incompleteScanSessions: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.scanStatus == .planned || $0.scanStatus == .reopened || $0.scanStatus == .blocked }
  }

  var highRiskScanSessions: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var scanSessionsMissingCapturedValues: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.capturedValuePlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var scanSessionsMissingLabelReferences: [ScanSessionRecord] {
    scanSessionRecords.filter { $0.linkedLabelReferenceID == nil }
  }

  var shipmentManifestsNeedingReview: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.reviewState != .accepted }
  }

  var blockedShipmentManifests: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.dispatchStatus == .blockedNeedsReview }
  }

  var undispatchedShipmentManifests: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.dispatchStatus == .draft || $0.dispatchStatus == .prepared || $0.dispatchStatus == .reopened }
  }

  var highRiskShipmentManifests: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var shipmentManifestsMissingIncludedOrders: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.includedOrderIDs.isEmpty }
  }

  var shipmentManifestsMissingHandoffLocation: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.handoffLocationStorageLocationID == nil }
  }

  var shipmentManifestsWithIncompleteScans: [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { manifest in
      manifest.scanSessionIDs.contains { scanID in
        scanSessionRecords.contains { $0.id == scanID && ($0.scanStatus == .planned || $0.scanStatus == .reopened || $0.scanStatus == .blocked || $0.scanStatus == .mismatchNeedsReview) }
      }
    }
  }

  var dispatchChecklistsNeedingReview: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { $0.reviewState != .accepted }
  }

  var blockedDispatchChecklists: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { $0.checklistStatus == .blockedNeedsReview }
  }

  var incompleteDispatchChecklists: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { $0.checklistStatus == .draft || $0.checklistStatus == .ready || $0.checklistStatus == .reopened }
  }

  var highRiskDispatchChecklists: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var dispatchChecklistsMissingRequirements: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter {
      !$0.missingRequirementsSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !$0.missingRequirementsSummary.localizedCaseInsensitiveContains("no missing")
    }
  }

  var dispatchChecklistsLinkedToBlockedManifests: [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { checklist in
      guard let manifestID = checklist.shipmentManifestID else { return false }
      return shipmentManifestRecords.contains { $0.id == manifestID && $0.dispatchStatus == .blockedNeedsReview }
    }
  }

  var enabledAccountRecordCount: Int {
    accountCredentialRecords.filter(\.isEnabled).count
  }

  var disabledAccountRecordCount: Int {
    accountCredentialRecords.filter { !$0.isEnabled }.count
  }

  var accountRecordsNeedingReview: [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.reviewState != .accepted
        || account.credentialStorageStatus == .needsSetup
        || account.credentialStorageStatus == .accessPending
        || account.mfaStatus == .needsReview
        || account.mfaStatus == .notConfigured
    }
  }

  var vendorProfilesNeedingReview: [VendorProfile] {
    vendorProfiles.filter { $0.reviewState != .accepted }
  }

  var highRiskEnabledVendorProfiles: [VendorProfile] {
    vendorProfiles.filter { $0.isEnabled && ($0.riskLevel == .high || $0.riskLevel == .critical) }
  }

  var shipmentGroupsNeedingReview: [ShipmentGroup] {
    shipmentGroups.filter { $0.reviewState != .accepted }
  }

  var highRiskShipmentGroups: [ShipmentGroup] {
    shipmentGroups.filter { $0.riskLevel == .high || $0.riskLevel == .critical }
  }

  var importQueueItemsNeedingReview: [ImportQueueItem] {
    importQueueItems.filter { $0.reviewState != .accepted || $0.importStatus == .staged || $0.importStatus == .reopened }
  }

  var lowConfidenceImportQueueItems: [ImportQueueItem] {
    importQueueItems.filter { $0.confidenceScore < 70 }
  }

  var blockedImportQueueItems: [ImportQueueItem] {
    importQueueItems.filter { $0.importStatus == .blocked }
  }

  var acceptanceCandidates: [AcceptanceCandidate] {
    let importCandidates = importQueueItems.map { item in
      let record = acceptanceRecord(sourceType: .importQueueItem, sourceID: item.id)
      return AcceptanceCandidate(
        id: "import-\(item.id.uuidString)",
        sourceType: .importQueueItem,
        sourceID: item.id,
        sourceLabel: item.sourceLabel,
        capturedDate: item.capturedDate,
        rawSummary: item.rawSummary,
        detectedMerchant: item.detectedMerchant,
        detectedOrderNumber: item.detectedOrderNumber,
        detectedTrackingNumber: item.detectedTrackingNumber,
        detectedDestinationAddress: item.detectedDestinationAddress,
        suggestedLinkedOrderID: item.suggestedLinkedOrderID,
        suggestedShipmentGroupID: item.suggestedShipmentGroupID,
        confidenceScore: item.confidenceScore,
        decision: record?.decision ?? item.importStatus.acceptanceDecision,
        reviewState: record?.reviewState ?? item.reviewState,
        notes: record?.notes ?? item.notes
      )
    }

    let intakeCandidates = intakeEmails.map { email in
      let record = acceptanceRecord(sourceType: .intakeEmail, sourceID: email.id)
      let linkedGroup = shipmentGroups.first { $0.relatedIntakeEmailIDs.contains(email.id) }
      return AcceptanceCandidate(
        id: "intake-\(email.id.uuidString)",
        sourceType: .intakeEmail,
        sourceID: email.id,
        sourceLabel: email.subject,
        capturedDate: email.receivedDate,
        rawSummary: email.rawBodyPreview,
        detectedMerchant: email.detectedMerchant,
        detectedOrderNumber: email.detectedOrderNumber,
        detectedTrackingNumber: email.detectedTrackingNumber,
        detectedDestinationAddress: email.detectedDestinationAddress,
        suggestedLinkedOrderID: email.linkedOrderID,
        suggestedShipmentGroupID: linkedGroup?.id,
        confidenceScore: email.localAcceptanceConfidence,
        decision: record?.decision ?? email.reviewState.acceptanceDecision,
        reviewState: record?.reviewState ?? email.reviewState.searchReviewState,
        notes: record?.notes ?? "Forwarded intake email awaiting local acceptance review."
      )
    }

    return (importCandidates + intakeCandidates).sorted { lhs, rhs in
      lhs.capturedDate > rhs.capturedDate
    }
  }

  var acceptanceRecordsNeedingReview: [AcceptanceRecord] {
    acceptanceRecords.filter { record in
      record.reviewState != .accepted || record.decision == .ready || record.decision == .blocked || record.decision == .reopened
    }
  }

  var acceptedAcceptanceRecords: [AcceptanceRecord] {
    acceptanceRecords.filter { $0.decision == .accepted }
  }

  var blockedAcceptanceRecords: [AcceptanceRecord] {
    acceptanceRecords.filter { $0.decision == .blocked }
  }

  var ignoredAcceptanceRecords: [AcceptanceRecord] {
    acceptanceRecords.filter { $0.decision == .ignored }
  }

  var reopenedAcceptanceRecords: [AcceptanceRecord] {
    acceptanceRecords.filter { $0.decision == .reopened }
  }

  var enabledVendorProfileCount: Int {
    vendorProfiles.filter(\.isEnabled).count
  }

  var disabledVendorProfileCount: Int {
    vendorProfiles.filter { !$0.isEnabled }.count
  }

  var recentAuditEvents: [AuditEvent] {
    Array(auditEvents.prefix(5))
  }

  var highestRiskTrackingEvents: [CarrierTrackingEvent] {
    Array(carrierTrackingEvents.sorted { lhs, rhs in
      lhs.severity.riskRank > rhs.severity.riskRank
    }.prefix(5))
  }

  var newestIntakeEmails: [ForwardedEmailIntake] {
    Array(intakeEmails.prefix(5))
  }

  var timelineActivities: [TimelineActivity] {
    orderTimelineActivities()
      + intakeTimelineActivities()
      + trackingTimelineActivities()
      + evidenceTimelineActivities()
      + taskTimelineActivities()
      + slaTimelineActivities()
      + communicationTimelineActivities()
      + contactTimelineActivities()
      + accountTimelineActivities()
      + vendorProfileTimelineActivities()
      + shipmentGroupTimelineActivities()
      + dispatchTimelineActivities()
      + importQueueTimelineActivities()
      + acceptanceTimelineActivities()
      + automationTimelineActivities()
      + savedFilterTimelineActivities()
      + auditTimelineActivities()
  }

  var timelineWatchlist: [TimelineActivity] {
    timelineActivities.filter { activity in
      activity.risk == .high
        || activity.risk == .critical
        || activity.reviewState == .needsReview
        || activity.detail.localizedCaseInsensitiveContains("overdue")
    }
  }

  var recentTimelineActivities: [TimelineActivity] {
    Array(timelineActivities.prefix(6))
  }

  var workbenchItems: [WorkbenchItem] {
    (reviewTaskWorkbenchItems()
      + handoffNoteWorkbenchItems()
      + intakeWorkbenchItems()
      + intakeParserWorkbenchItems()
      + spaceMailIntakeWorkbenchItems()
      + gmailIntakeWorkbenchItems()
      + mailboxClassifierWorkbenchItems()
      + importQueueWorkbenchItems()
      + acceptanceWorkbenchItems()
      + reconciliationWorkbenchItems()
      + validationWorkbenchItems()
      + shipmentGroupWorkbenchItems()
      + trackingWorkbenchItems()
      + evidenceWorkbenchItems()
      + slaWorkbenchItems()
      + exceptionPlaybookWorkbenchItems()
      + draftMessageWorkbenchItems()
      + contactWorkbenchItems()
      + customerProfileWorkbenchItems()
      + destinationAddressWorkbenchItems()
      + deliveryInstructionWorkbenchItems()
      + packageContentWorkbenchItems()
      + costRecordWorkbenchItems()
      + returnClaimWorkbenchItems()
      + procurementRequestWorkbenchItems()
      + receivingInspectionWorkbenchItems()
      + inventoryReceiptWorkbenchItems()
      + storageLocationWorkbenchItems()
      + custodyRecordWorkbenchItems()
      + labelReferenceWorkbenchItems()
      + scanSessionWorkbenchItems()
      + shipmentManifestWorkbenchItems()
      + dispatchChecklistWorkbenchItems()
      + accountWorkbenchItems()
      + vendorProfileWorkbenchItems()
      + localDataHygieneWorkbenchItems()
      + setupPlaceholderWorkbenchItems())
      .sorted { lhs, rhs in
        if lhs.rank == rhs.rank {
          return lhs.reviewState == .needsReview && rhs.reviewState != .needsReview
        }
        return lhs.rank > rhs.rank
      }
  }

  var openWorkbenchItems: [WorkbenchItem] {
    workbenchItems.filter { !$0.status.localizedCaseInsensitiveContains("complete") && !$0.status.localizedCaseInsensitiveContains("sent locally") }
  }

  var overdueWorkbenchItems: [WorkbenchItem] {
    workbenchItems.filter(\.isDueOrOverdue)
  }

  var blockedWorkbenchItems: [WorkbenchItem] {
    workbenchItems.filter(\.isBlocked)
  }

  var highPriorityWorkbenchItems: [WorkbenchItem] {
    workbenchItems.filter { $0.rank >= 3 }
  }

  var workbenchItemsNeedingReview: [WorkbenchItem] {
    workbenchItems.filter { $0.reviewState == .needsReview }
  }

  func filteredWorkbenchItems(
    assignee: String?,
    linkedEntityType: ReviewTaskLinkedEntityType?,
    prioritySeverity: String?,
    status: String?,
    reviewState: ReviewState?,
    source: WorkbenchSource?
  ) -> [WorkbenchItem] {
    workbenchItems.filter { item in
      let matchesAssignee = assignee == nil || item.assignee == assignee
      let matchesEntity = linkedEntityType == nil || item.linkedEntityType == linkedEntityType
      let matchesPriority = prioritySeverity == nil || item.prioritySeverity == prioritySeverity
      let matchesStatus = status == nil || item.status == status
      let matchesReview = reviewState == nil || item.reviewState == reviewState
      let matchesSource = source == nil || item.source == source
      return matchesAssignee && matchesEntity && matchesPriority && matchesStatus && matchesReview && matchesSource
    }
  }

  func groupedWorkbenchItems(_ items: [WorkbenchItem]) -> [WorkbenchItemGroup] {
    let due = items.filter(\.isDueOrOverdue)
    let high = items.filter { $0.rank >= 3 && !due.contains($0) }
    let review = items.filter { $0.reviewState == .needsReview && !due.contains($0) && !high.contains($0) }
    let blocked = items.filter { $0.isBlocked && !due.contains($0) && !high.contains($0) && !review.contains($0) }
    let awaiting = items.filter { $0.isAwaitingAcceptance && !due.contains($0) && !high.contains($0) && !review.contains($0) && !blocked.contains($0) }
    let exceptions = items.filter { $0.isException && !due.contains($0) && !high.contains($0) && !review.contains($0) && !blocked.contains($0) && !awaiting.contains($0) }
    let recent = items.filter { !due.contains($0) && !high.contains($0) && !review.contains($0) && !blocked.contains($0) && !awaiting.contains($0) && !exceptions.contains($0) }

    return [
      WorkbenchItemGroup(title: "Due or overdue", symbol: "calendar.badge.exclamationmark", items: due),
      WorkbenchItemGroup(title: "High priority", symbol: "flame.fill", items: high),
      WorkbenchItemGroup(title: "Needs review", symbol: "checkmark.shield.fill", items: review),
      WorkbenchItemGroup(title: "Blocked", symbol: "hand.raised.fill", items: blocked),
      WorkbenchItemGroup(title: "Awaiting acceptance", symbol: "checkmark.rectangle.stack.fill", items: awaiting),
      WorkbenchItemGroup(title: "Exceptions", symbol: "exclamationmark.triangle.fill", items: exceptions),
      WorkbenchItemGroup(title: "Recently updated", symbol: "clock.fill", items: recent)
    ].filter { !$0.items.isEmpty }
  }

  func filteredTimelineActivities(
    entityType: TimelineEntityType?,
    risk: TimelineRiskLevel?,
    reviewState: ReviewState?,
    source: TimelineActivitySource?
  ) -> [TimelineActivity] {
    timelineActivities.filter { activity in
      let matchesEntity = entityType == nil || activity.entityType == entityType
      let matchesRisk = risk == nil || activity.risk == risk
      let matchesReview = reviewState == nil || activity.reviewState == reviewState
      let matchesSource = source == nil || activity.source == source
      return matchesEntity && matchesRisk && matchesReview && matchesSource
    }
  }

  func groupedTimelineActivities(_ activities: [TimelineActivity]) -> [TimelineActivityGroup] {
    let watchlist = activities.filter { timelineWatchlist.contains($0) }
    let today = activities.filter { activity in
      activity.timestampText.localizedCaseInsensitiveContains("today") && !watchlist.contains(activity)
    }
    let earlier = activities.filter { activity in
      !activity.timestampText.localizedCaseInsensitiveContains("today") && !watchlist.contains(activity)
    }

    return [
      TimelineActivityGroup(title: "Watchlist", activities: watchlist),
      TimelineActivityGroup(title: "Today", activities: today),
      TimelineActivityGroup(title: "Earlier", activities: earlier)
    ].filter { !$0.activities.isEmpty }
  }

  var validationIssues: [ValidationIssue] {
    (orderValidationIssues()
      + intakeValidationIssues()
      + trackingNumberValidationIssues()
      + destinationValidationIssues()
      + vendorProfileMatchValidationIssues()
      + accountPlaceholderValidationIssues()
      + contactSuggestionValidationIssues())
      .sorted { lhs, rhs in
        if lhs.severity.rank == rhs.severity.rank {
          return lhs.confidenceScore < rhs.confidenceScore
        }
        return lhs.severity.rank > rhs.severity.rank
      }
  }

  var highSeverityValidationIssues: [ValidationIssue] {
    validationIssues.filter { $0.severity == .high || $0.severity == .critical }
  }

  var validationNeedsCorrectionCount: Int {
    validationIssues.filter { $0.status == .needsCorrection || $0.status == .conflict }.count
  }

  var lowConfidenceValidationCount: Int {
    validationIssues.filter { $0.status == .lowConfidence }.count
  }

  var duplicateValidationCount: Int {
    validationIssues.filter { $0.status == .duplicate }.count
  }

  var validationHealthScore: Int {
    guard !validationIssues.isEmpty else { return 100 }
    let averageConfidence = validationIssues.map(\.confidenceScore).reduce(0, +) / validationIssues.count
    let severityPenalty = min(40, highSeverityValidationIssues.count * 5)
    return max(0, averageConfidence - severityPenalty)
  }

  var reconciliationIssues: [ReconciliationIssue] {
    (missingLinkReconciliationIssues()
      + orderNumberConflictReconciliationIssues()
      + trackingNumberConflictReconciliationIssues()
      + destinationConflictReconciliationIssues()
      + duplicateStagedRecordReconciliationIssues()
      + acceptedWithoutOrderReconciliationIssues()
      + shipmentGroupMissingPrimaryReconciliationIssues())
      .sorted { lhs, rhs in
        if lhs.severity.rank == rhs.severity.rank {
          return lhs.createdDate > rhs.createdDate
        }
        return lhs.severity.rank > rhs.severity.rank
      }
  }

  var unresolvedReconciliationIssues: [ReconciliationIssue] {
    reconciliationIssues.filter { $0.reviewState != .accepted }
  }

  var highSeverityReconciliationIssues: [ReconciliationIssue] {
    reconciliationIssues.filter { $0.severity == .high || $0.severity == .critical }
  }

  func filteredReconciliationIssues(
    issueType: ReconciliationIssueType?,
    severity: ValidationSeverity?,
    sourceEntityType: ReconciliationEntityType?,
    targetEntityType: ReconciliationEntityType?,
    reviewState: ReviewState?
  ) -> [ReconciliationIssue] {
    reconciliationIssues.filter { issue in
      let matchesIssue = issueType == nil || issue.issueType == issueType
      let matchesSeverity = severity == nil || issue.severity == severity
      let matchesSource = sourceEntityType == nil || issue.sourceEntityType == sourceEntityType
      let matchesTarget = targetEntityType == nil || issue.targetEntityType == targetEntityType
      let matchesReview = reviewState == nil || issue.reviewState == reviewState
      return matchesIssue && matchesSeverity && matchesSource && matchesTarget && matchesReview
    }
  }

  func groupedReconciliationIssues(_ issues: [ReconciliationIssue]) -> [ReconciliationIssueGroup] {
    ReconciliationIssueType.allCases.compactMap { issueType in
      let groupedIssues = issues.filter { $0.issueType == issueType }
      guard !groupedIssues.isEmpty else { return nil }
      return ReconciliationIssueGroup(issueType: issueType, issues: groupedIssues)
    }
  }

  func filteredExceptionPlaybooks(
    issueType: ReconciliationIssueType?,
    linkedEntityType: ReviewTaskLinkedEntityType?,
    priority: TaskPriority?,
    enabledState: Bool?,
    reviewState: ReviewState?
  ) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      let matchesIssue = issueType == nil || playbook.issueType == issueType
      let matchesEntity = linkedEntityType == nil || playbook.linkedEntityType == linkedEntityType
      let matchesPriority = priority == nil || playbook.priority == priority
      let matchesEnabled = enabledState == nil || playbook.isEnabled == enabledState
      let matchesReview = reviewState == nil || playbook.reviewState == reviewState
      return matchesIssue && matchesEntity && matchesPriority && matchesEnabled && matchesReview
    }
  }

  func filteredHandoffNotes(
    linkedEntityType: ReviewTaskLinkedEntityType?,
    priority: TaskPriority?,
    assignee: String?,
    status: TaskStatus?,
    reviewState: ReviewState?
  ) -> [HandoffNote] {
    handoffNotes.filter { note in
      let matchesEntity = linkedEntityType == nil || note.linkedEntityType == linkedEntityType
      let matchesPriority = priority == nil || note.priority == priority
      let matchesAssignee = assignee == nil || note.assignee == assignee
      let matchesStatus = status == nil || note.status == status
      let matchesReview = reviewState == nil || note.reviewState == reviewState
      return matchesEntity && matchesPriority && matchesAssignee && matchesStatus && matchesReview
    }
  }

  func filteredValidationIssues(
    entityType: ValidationEntityType?,
    severity: ValidationSeverity?,
    status: ValidationStatus?,
    reviewState: ReviewState?
  ) -> [ValidationIssue] {
    validationIssues.filter { issue in
      let matchesEntity = entityType == nil || issue.entityType == entityType
      let matchesSeverity = severity == nil || issue.severity == severity
      let matchesStatus = status == nil || issue.status == status
      let matchesReview = reviewState == nil || issue.reviewState == reviewState
      return matchesEntity && matchesSeverity && matchesStatus && matchesReview
    }
  }

  func groupedValidationIssues(_ issues: [ValidationIssue]) -> [ValidationIssueGroup] {
    ValidationSeverity.allCases.reversed().compactMap { severity in
      let groupedIssues = issues.filter { $0.severity == severity }
      guard !groupedIssues.isEmpty else { return nil }
      return ValidationIssueGroup(severity: severity, issues: groupedIssues)
    }
  }

  func filteredShipmentGroups(
    riskLevel: ShipmentRiskLevel?,
    status: String,
    carrier: String,
    reviewState: ReviewState?
  ) -> [ShipmentGroup] {
    let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedCarrier = carrier.trimmingCharacters(in: .whitespacesAndNewlines)
    return shipmentGroups.filter { group in
      let matchesRisk = riskLevel == nil || group.riskLevel == riskLevel
      let matchesStatus = normalizedStatus.isEmpty || group.statusSummary.localizedCaseInsensitiveContains(normalizedStatus)
      let matchesCarrier = normalizedCarrier.isEmpty || group.carrierSummary.localizedCaseInsensitiveContains(normalizedCarrier)
      let matchesReview = reviewState == nil || group.reviewState == reviewState
      return matchesRisk && matchesStatus && matchesCarrier && matchesReview
    }
  }

  func filteredImportQueueItems(
    sourceType: ImportSourceType?,
    status: ImportStatus?,
    confidenceRange: ImportConfidenceRange,
    reviewState: ReviewState?
  ) -> [ImportQueueItem] {
    importQueueItems.filter { item in
      let matchesSource = sourceType == nil || item.sourceType == sourceType
      let matchesStatus = status == nil || item.importStatus == status
      let matchesConfidence = confidenceRange.contains(item.confidenceScore)
      let matchesReview = reviewState == nil || item.reviewState == reviewState
      return matchesSource && matchesStatus && matchesConfidence && matchesReview
    }
  }

  func filteredAcceptanceCandidates(
    sourceType: AcceptanceSourceType?,
    decision: AcceptanceDecision?,
    confidenceRange: ImportConfidenceRange,
    reviewState: ReviewState?
  ) -> [AcceptanceCandidate] {
    acceptanceCandidates.filter { candidate in
      let matchesSource = sourceType == nil || candidate.sourceType == sourceType
      let matchesDecision = decision == nil || candidate.decision == decision
      let matchesConfidence = confidenceRange.contains(candidate.confidenceScore)
      let matchesReview = reviewState == nil || candidate.reviewState == reviewState
      return matchesSource && matchesDecision && matchesConfidence && matchesReview
    }
  }

  func groupedAcceptanceCandidates(_ candidates: [AcceptanceCandidate], by grouping: AcceptanceGrouping) -> [(title: String, candidates: [AcceptanceCandidate])] {
    let grouped = Dictionary(grouping: candidates) { candidate in
      switch grouping {
      case .confidence:
        if candidate.confidenceScore < 50 { return "Low confidence" }
        if candidate.confidenceScore < 75 { return "Medium confidence" }
        return "High confidence"
      case .linkedOrder:
        return candidate.suggestedLinkedOrderID.flatMap { orderLabel(for: $0) } ?? "No linked order"
      case .shipmentGroup:
        return candidate.suggestedShipmentGroupID.flatMap { shipmentGroupLabel(for: $0) } ?? "No shipment group"
      case .reviewState:
        return candidate.reviewState.rawValue
      }
    }

    return grouped.keys.sorted().map { key in
      (title: key, candidates: grouped[key] ?? [])
    }
  }

  func importQueueItems(for order: TrackedOrder) -> [ImportQueueItem] {
    importQueueItems.filter { item in
      item.suggestedLinkedOrderID == order.id
        || item.detectedOrderNumber.localizedCaseInsensitiveContains(order.orderNumber)
        || order.orderNumber.localizedCaseInsensitiveContains(item.detectedOrderNumber)
        || item.detectedTrackingNumber.normalizedValidationKey == order.trackingNumber.normalizedValidationKey
    }
  }

  func importQueueItems(for group: ShipmentGroup) -> [ImportQueueItem] {
    importQueueItems.filter { item in
      item.suggestedShipmentGroupID == group.id
        || item.suggestedLinkedOrderID.map { group.relatedOrderIDs.contains($0) || group.primaryOrderID == $0 } == true
        || group.destinationSummary.localizedCaseInsensitiveContains(item.detectedDestinationAddress)
        || item.detectedDestinationAddress.localizedCaseInsensitiveContains(group.destinationSummary)
    }
  }

  func importQueueItems(for activity: TimelineActivity) -> [ImportQueueItem] {
    guard let linkedEntityType = activity.reviewTaskLinkedEntityType else { return [] }
    return importQueueItems.filter { item in
      item.matches(linkedEntityType: linkedEntityType, linkedEntityID: activity.entityID)
    }
  }

  func importQueueItems(for issue: ValidationIssue) -> [ImportQueueItem] {
    guard let linkedEntityType = issue.linkedEntityType else { return [] }
    return importQueueItems.filter { item in
      item.matches(linkedEntityType: linkedEntityType, linkedEntityID: issue.entityID)
    }
  }

  func importQueueItems(for issue: ReconciliationIssue) -> [ImportQueueItem] {
    importQueueItems.filter { item in
      issue.matches(entityType: .importQueueItem, entityID: item.id.uuidString)
        || item.suggestedLinkedOrderID?.uuidString == issue.sourceEntityID
        || item.suggestedLinkedOrderID?.uuidString == issue.targetEntityID
    }
  }

  func acceptanceRecords(for order: TrackedOrder) -> [AcceptanceRecord] {
    acceptanceRecords.filter { $0.linkedOrderID == order.id }
  }

  func acceptanceRecords(for group: ShipmentGroup) -> [AcceptanceRecord] {
    acceptanceRecords.filter { $0.linkedShipmentGroupID == group.id }
  }

  func acceptanceRecords(for activity: TimelineActivity) -> [AcceptanceRecord] {
    guard let linkedEntityType = activity.reviewTaskLinkedEntityType else { return [] }
    return acceptanceRecords.filter { $0.matches(linkedEntityType: linkedEntityType, linkedEntityID: activity.entityID) }
  }

  func acceptanceRecords(for issue: ValidationIssue) -> [AcceptanceRecord] {
    guard let linkedEntityType = issue.linkedEntityType else { return [] }
    return acceptanceRecords.filter { $0.matches(linkedEntityType: linkedEntityType, linkedEntityID: issue.entityID) }
  }

  func acceptanceRecords(for issue: ReconciliationIssue) -> [AcceptanceRecord] {
    acceptanceRecords.filter { record in
      issue.matches(entityType: .acceptanceRecord, entityID: record.id.uuidString)
        || record.sourceID.uuidString == issue.sourceEntityID
        || record.sourceID.uuidString == issue.targetEntityID
        || record.linkedOrderID?.uuidString == issue.sourceEntityID
        || record.linkedOrderID?.uuidString == issue.targetEntityID
        || record.linkedShipmentGroupID?.uuidString == issue.sourceEntityID
        || record.linkedShipmentGroupID?.uuidString == issue.targetEntityID
    }
  }

  func acceptanceHistory(sourceType: AcceptanceSourceType, sourceID: UUID) -> [AcceptanceRecord] {
    acceptanceRecords.filter { $0.sourceType == sourceType && $0.sourceID == sourceID }
  }

  func orderLabel(for id: UUID) -> String? {
    orders.first { $0.id == id }.map { "\($0.store) \($0.orderNumber)" }
  }

  func shipmentGroupLabel(for id: UUID) -> String? {
    shipmentGroups.first { $0.id == id }?.groupName
  }

  func handoffNotes(for linkedEntityType: ReviewTaskLinkedEntityType, linkedEntityID: String) -> [HandoffNote] {
    handoffNotes.filter { $0.linkedEntityType == linkedEntityType && $0.linkedEntityID == linkedEntityID }
  }

  func handoffNotes(for order: TrackedOrder) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .order && note.linkedEntityID == order.id.uuidString
    }
  }

  func handoffNotes(for group: ShipmentGroup) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .shipmentGroup && note.linkedEntityID == group.id.uuidString
        || (note.linkedEntityType == .order && group.relatedOrderIDs.map(\.uuidString).contains(note.linkedEntityID))
        || (note.linkedEntityType == .intakeEmail && group.relatedIntakeEmailIDs.map(\.uuidString).contains(note.linkedEntityID))
    }
  }

  func handoffNotes(for issue: ReconciliationIssue) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .reconciliationIssue && note.linkedEntityID == issue.id
        || note.linkedEntityID == issue.sourceEntityID
        || note.linkedEntityID == issue.targetEntityID
        || issue.sourceEntityType.reviewTaskLinkedEntityType.map { note.linkedEntityType == $0 } == true
        || issue.targetEntityType?.reviewTaskLinkedEntityType.map { note.linkedEntityType == $0 } == true
    }
  }

  func handoffNotes(for issue: ValidationIssue) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityID == issue.entityID
        || note.linkedEntityType == issue.linkedEntityType
    }
  }

  func handoffNotes(for item: ImportQueueItem) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .importQueueItem && note.linkedEntityID == item.id.uuidString
        || item.suggestedLinkedOrderID?.uuidString == note.linkedEntityID
        || item.suggestedShipmentGroupID?.uuidString == note.linkedEntityID
    }
  }

  func handoffNotes(for candidate: AcceptanceCandidate) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == candidate.reviewTaskLinkedEntityType && note.linkedEntityID == candidate.sourceID.uuidString
        || candidate.suggestedLinkedOrderID?.uuidString == note.linkedEntityID
        || candidate.suggestedShipmentGroupID?.uuidString == note.linkedEntityID
    }
  }

  func handoffNotes(for playbook: ExceptionPlaybook) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .exceptionPlaybook && note.linkedEntityID == playbook.id.uuidString
        || note.linkedEntityType == playbook.linkedEntityType
    }
  }

  func handoffNotes(for task: ReviewTask) -> [HandoffNote] {
    handoffNotes.filter { note in
      note.linkedEntityType == .reviewTask && note.linkedEntityID == task.id.uuidString
        || note.linkedEntityType == task.linkedEntityType && note.linkedEntityID == task.linkedEntityID
    }
  }

  func suggestedShipmentGroups(for order: TrackedOrder) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      group.primaryOrderID == order.id
        || group.relatedOrderIDs.contains(order.id)
        || group.destinationSummary.localizedCaseInsensitiveContains(order.destination)
        || order.destination.localizedCaseInsensitiveContains(group.destinationSummary)
        || group.carrierSummary.localizedCaseInsensitiveContains(order.carrier)
        || group.recipientCustomerSummary.localizedCaseInsensitiveContains(order.customer)
    }
  }

  func suggestedShipmentGroups(for email: ForwardedEmailIntake) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      group.relatedIntakeEmailIDs.contains(email.id)
        || email.linkedOrderID.map { group.relatedOrderIDs.contains($0) || group.primaryOrderID == $0 } == true
        || group.destinationSummary.localizedCaseInsensitiveContains(email.detectedDestinationAddress)
        || email.detectedDestinationAddress.localizedCaseInsensitiveContains(group.destinationSummary)
    }
  }

  func suggestedShipmentGroups(for event: CarrierTrackingEvent) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      group.relatedTrackingEventIDs.contains(event.id)
        || group.relatedOrderIDs.contains(event.orderID)
        || group.primaryOrderID == event.orderID
        || group.carrierSummary.localizedCaseInsensitiveContains(event.carrier)
    }
  }

  func suggestedShipmentGroups(for attachment: EvidenceAttachment) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      group.relatedEvidenceIDs.contains(attachment.id)
        || (attachment.linkedEntityType == .order && group.relatedOrderIDs.contains(attachment.linkedEntityID))
        || (attachment.linkedEntityType == .intakeEmail && group.relatedIntakeEmailIDs.contains(attachment.linkedEntityID))
    }
  }

  func suggestedShipmentGroups(for task: ReviewTask) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      group.matches(linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID)
    }
  }

  func suggestedShipmentGroups(for activity: TimelineActivity) -> [ShipmentGroup] {
    guard let linkedEntityType = activity.reviewTaskLinkedEntityType else { return [] }
    return shipmentGroups.filter { group in
      group.matches(linkedEntityType: linkedEntityType, linkedEntityID: activity.entityID)
    }
  }

  func suggestedShipmentGroups(for issue: ValidationIssue) -> [ShipmentGroup] {
    guard let linkedEntityType = issue.linkedEntityType else { return [] }
    return shipmentGroups.filter { group in
      group.matches(linkedEntityType: linkedEntityType, linkedEntityID: issue.entityID)
    }
  }

  func suggestedShipmentGroups(for issue: ReconciliationIssue) -> [ShipmentGroup] {
    shipmentGroups.filter { group in
      issue.matches(entityType: .shipmentGroup, entityID: group.id.uuidString)
        || group.primaryOrderID?.uuidString == issue.sourceEntityID
        || group.primaryOrderID?.uuidString == issue.targetEntityID
        || group.relatedOrderIDs.map(\.uuidString).contains(issue.sourceEntityID)
        || group.relatedOrderIDs.map(\.uuidString).contains(issue.targetEntityID ?? "")
        || group.relatedIntakeEmailIDs.map(\.uuidString).contains(issue.sourceEntityID)
        || group.relatedIntakeEmailIDs.map(\.uuidString).contains(issue.targetEntityID ?? "")
    }
  }

  func relatedValidationIssues(for issue: ReconciliationIssue) -> [ValidationIssue] {
    validationIssues.filter { validationIssue in
      validationIssue.entityID == issue.sourceEntityID
        || validationIssue.entityID == issue.targetEntityID
        || validationIssue.linkedEntityType?.rawValue == issue.sourceEntityType.rawValue
    }
  }

  func createReviewTask(from issue: ValidationIssue) {
    guard let linkedEntityType = issue.linkedEntityType else { return }
    createReviewTask(
      linkedEntityType: linkedEntityType,
      linkedEntityID: issue.entityID,
      label: issue.title,
      summary: "Follow up validation issue: \(issue.detail)",
      priority: issue.severity.taskPriority
    )
  }

  func createDraftMessage(from issue: ValidationIssue) {
    guard let linkedEntityType = issue.linkedEntityType else { return }
    createDraftMessage(
      linkedEntityType: linkedEntityType,
      linkedEntityID: issue.entityID,
      label: issue.title,
      recipient: "operations@parcelops.example"
    )
  }

  func markReconciliationIssueReviewed(_ issue: ReconciliationIssue) {
    logAudit(
      action: .reviewed,
      entityType: .reconciliationIssue,
      entityID: issue.id,
      entityLabel: issue.title,
      summary: "Reconciliation issue marked reviewed.",
      afterDetail: issue.auditDetail
    )
  }

  func createReviewTask(from issue: ReconciliationIssue) {
    createReviewTask(
      linkedEntityType: .reconciliationIssue,
      linkedEntityID: issue.id,
      label: issue.title,
      summary: "Follow up reconciliation issue: \(issue.summary) Suggested resolution: \(issue.suggestedResolution)",
      priority: issue.severity.taskPriority
    )
  }

  func createDraftMessage(from issue: ReconciliationIssue) {
    createDraftMessage(
      linkedEntityType: .reconciliationIssue,
      linkedEntityID: issue.id,
      label: issue.title,
      recipient: "operations@parcelops.example"
    )
  }

  private func missingLinkReconciliationIssues() -> [ReconciliationIssue] {
    let intakeIssues = intakeEmails.compactMap { email -> ReconciliationIssue? in
      let hasShipmentGroup = shipmentGroups.contains { $0.relatedIntakeEmailIDs.contains(email.id) }
      guard email.linkedOrderID == nil || !hasShipmentGroup else { return nil }
      return reconciliationIssue(
        id: "recon-missing-intake-\(email.id.uuidString)",
        issueType: .missingLink,
        severity: email.linkedOrderID == nil ? .high : .warning,
        sourceEntityType: .intakeEmail,
        sourceEntityID: email.id.uuidString,
        targetEntityType: email.linkedOrderID == nil ? .order : .shipmentGroup,
        targetEntityID: email.linkedOrderID?.uuidString,
        title: email.auditLabel,
        summary: "Forwarded intake email is missing an order or shipment group link.",
        detectedValue: "\(email.detectedMerchant) \(email.detectedOrderNumber)",
        currentOperationalValue: "Order: \(email.linkedOrderID?.uuidString ?? "none"); shipment group: \(hasShipmentGroup ? "linked" : "none")",
        suggestedResolution: "Link the intake email through Acceptance Review or create the missing local operational record.",
        createdDate: email.receivedDate
      )
    }

    let importIssues = importQueueItems.compactMap { item -> ReconciliationIssue? in
      guard item.suggestedLinkedOrderID == nil || item.suggestedShipmentGroupID == nil else { return nil }
      return reconciliationIssue(
        id: "recon-missing-import-\(item.id.uuidString)",
        issueType: .missingLink,
        severity: item.importStatus == .blocked ? .high : .warning,
        sourceEntityType: .importQueueItem,
        sourceEntityID: item.id.uuidString,
        targetEntityType: item.suggestedLinkedOrderID == nil ? .order : .shipmentGroup,
        targetEntityID: item.suggestedLinkedOrderID?.uuidString ?? item.suggestedShipmentGroupID?.uuidString,
        title: item.sourceLabel,
        summary: "Import queue item is missing an order or shipment group decision.",
        detectedValue: "\(item.detectedMerchant) \(item.detectedOrderNumber)",
        currentOperationalValue: "Order: \(item.suggestedLinkedOrderID?.uuidString ?? "none"); shipment group: \(item.suggestedShipmentGroupID?.uuidString ?? "none")",
        suggestedResolution: "Use Acceptance Review to link or create the missing order and shipment group context.",
        createdDate: item.capturedDate
      )
    }

    return intakeIssues + importIssues
  }

  private func orderNumberConflictReconciliationIssues() -> [ReconciliationIssue] {
    let importIssues = importQueueItems.compactMap { item -> ReconciliationIssue? in
      guard let orderID = item.suggestedLinkedOrderID, let order = orders.first(where: { $0.id == orderID }) else { return nil }
      guard !item.detectedOrderNumber.isPlaceholderValidationValue, item.detectedOrderNumber.normalizedValidationKey != order.orderNumber.normalizedValidationKey else { return nil }
      return reconciliationConflictIssue(
        id: "recon-order-import-\(item.id.uuidString)-\(order.id.uuidString)",
        issueType: .orderNumberConflict,
        sourceEntityType: .importQueueItem,
        sourceEntityID: item.id.uuidString,
        targetEntityType: .order,
        targetEntityID: order.id.uuidString,
        title: item.sourceLabel,
        summary: "Import queue order number differs from the linked tracked order.",
        detectedValue: item.detectedOrderNumber,
        currentOperationalValue: order.orderNumber,
        createdDate: item.capturedDate
      )
    }

    let intakeIssues = intakeEmails.compactMap { email -> ReconciliationIssue? in
      guard let orderID = email.linkedOrderID, let order = orders.first(where: { $0.id == orderID }) else { return nil }
      guard !email.detectedOrderNumber.isPlaceholderValidationValue, email.detectedOrderNumber.normalizedValidationKey != order.orderNumber.normalizedValidationKey else { return nil }
      return reconciliationConflictIssue(
        id: "recon-order-intake-\(email.id.uuidString)-\(order.id.uuidString)",
        issueType: .orderNumberConflict,
        sourceEntityType: .intakeEmail,
        sourceEntityID: email.id.uuidString,
        targetEntityType: .order,
        targetEntityID: order.id.uuidString,
        title: email.auditLabel,
        summary: "Forwarded intake order number differs from the linked tracked order.",
        detectedValue: email.detectedOrderNumber,
        currentOperationalValue: order.orderNumber,
        createdDate: email.receivedDate
      )
    }

    return importIssues + intakeIssues
  }

  private func trackingNumberConflictReconciliationIssues() -> [ReconciliationIssue] {
    let importIssues = importQueueItems.compactMap { item -> ReconciliationIssue? in
      guard let orderID = item.suggestedLinkedOrderID, let order = orders.first(where: { $0.id == orderID }) else { return nil }
      guard !item.detectedTrackingNumber.isPlaceholderValidationValue, item.detectedTrackingNumber.normalizedValidationKey != order.trackingNumber.normalizedValidationKey else { return nil }
      return reconciliationConflictIssue(
        id: "recon-tracking-import-\(item.id.uuidString)-\(order.id.uuidString)",
        issueType: .trackingNumberConflict,
        sourceEntityType: .importQueueItem,
        sourceEntityID: item.id.uuidString,
        targetEntityType: .order,
        targetEntityID: order.id.uuidString,
        title: item.sourceLabel,
        summary: "Import queue tracking number differs from the linked tracked order.",
        detectedValue: item.detectedTrackingNumber,
        currentOperationalValue: order.trackingNumber,
        createdDate: item.capturedDate
      )
    }

    let eventIssues = carrierTrackingEvents.compactMap { event -> ReconciliationIssue? in
      guard let order = orders.first(where: { $0.id == event.orderID }) else { return nil }
      guard event.trackingNumber.normalizedValidationKey != order.trackingNumber.normalizedValidationKey else { return nil }
      return reconciliationConflictIssue(
        id: "recon-tracking-event-\(event.id.uuidString)-\(order.id.uuidString)",
        issueType: .trackingNumberConflict,
        sourceEntityType: .trackingEvent,
        sourceEntityID: event.id.uuidString,
        targetEntityType: .order,
        targetEntityID: order.id.uuidString,
        title: event.trackingNumber,
        summary: "Carrier tracking event number differs from the linked tracked order.",
        detectedValue: event.trackingNumber,
        currentOperationalValue: order.trackingNumber,
        createdDate: event.eventTime
      )
    }

    return importIssues + eventIssues
  }

  private func destinationConflictReconciliationIssues() -> [ReconciliationIssue] {
    let importIssues = importQueueItems.compactMap { item -> ReconciliationIssue? in
      guard let orderID = item.suggestedLinkedOrderID, let order = orders.first(where: { $0.id == orderID }) else { return nil }
      guard !item.detectedDestinationAddress.isPlaceholderValidationValue, item.detectedDestinationAddress.normalizedValidationKey != order.destination.normalizedValidationKey else { return nil }
      return reconciliationConflictIssue(
        id: "recon-destination-import-\(item.id.uuidString)-\(order.id.uuidString)",
        issueType: .destinationConflict,
        sourceEntityType: .importQueueItem,
        sourceEntityID: item.id.uuidString,
        targetEntityType: .order,
        targetEntityID: order.id.uuidString,
        title: item.sourceLabel,
        summary: "Import queue destination differs from the linked tracked order.",
        detectedValue: item.detectedDestinationAddress,
        currentOperationalValue: order.destination,
        createdDate: item.capturedDate
      )
    }

    let groupIssues = shipmentGroups.flatMap { group in
      group.relatedOrderIDs.compactMap { orderID -> ReconciliationIssue? in
        guard let order = orders.first(where: { $0.id == orderID }) else { return nil }
        guard !group.destinationSummary.isPlaceholderValidationValue, group.destinationSummary.normalizedValidationKey != order.destination.normalizedValidationKey else { return nil }
        return reconciliationConflictIssue(
          id: "recon-destination-group-\(group.id.uuidString)-\(order.id.uuidString)",
          issueType: .destinationConflict,
          sourceEntityType: .shipmentGroup,
          sourceEntityID: group.id.uuidString,
          targetEntityType: .order,
          targetEntityID: order.id.uuidString,
          title: group.groupName,
          summary: "Shipment group destination summary differs from a related tracked order.",
          detectedValue: group.destinationSummary,
          currentOperationalValue: order.destination,
          createdDate: group.createdDate
        )
      }
    }

    return importIssues + groupIssues
  }

  private func duplicateStagedRecordReconciliationIssues() -> [ReconciliationIssue] {
    importQueueItems.enumerated().flatMap { offset, item in
      importQueueItems.dropFirst(offset + 1).compactMap { other -> ReconciliationIssue? in
        let sameOrder = !item.detectedOrderNumber.isPlaceholderValidationValue && item.detectedOrderNumber.normalizedValidationKey == other.detectedOrderNumber.normalizedValidationKey
        let sameTracking = !item.detectedTrackingNumber.isPlaceholderValidationValue && item.detectedTrackingNumber.normalizedValidationKey == other.detectedTrackingNumber.normalizedValidationKey
        guard sameOrder || sameTracking else { return nil }
        guard item.importStatus == .staged || other.importStatus == .staged || item.reviewState == .needsReview || other.reviewState == .needsReview else { return nil }
        return reconciliationIssue(
          id: "recon-duplicate-import-\(item.id.uuidString)-\(other.id.uuidString)",
          issueType: .duplicateStagedRecord,
          severity: .warning,
          sourceEntityType: .importQueueItem,
          sourceEntityID: item.id.uuidString,
          targetEntityType: .importQueueItem,
          targetEntityID: other.id.uuidString,
          title: item.sourceLabel,
          summary: "Two staged import records appear to describe the same order or tracking number.",
          detectedValue: sameOrder ? item.detectedOrderNumber : item.detectedTrackingNumber,
          currentOperationalValue: sameOrder ? other.detectedOrderNumber : other.detectedTrackingNumber,
          suggestedResolution: "Compare the staged records and keep both as evidence, but accept only the correct operational link.",
          createdDate: item.capturedDate
        )
      }
    }
  }

  private func acceptedWithoutOrderReconciliationIssues() -> [ReconciliationIssue] {
    acceptanceRecords.compactMap { record in
      guard record.decision == .accepted, record.linkedOrderID == nil else { return nil }
      return reconciliationIssue(
        id: "recon-accepted-without-order-\(record.id.uuidString)",
        issueType: .acceptedWithoutOrder,
        severity: .high,
        sourceEntityType: .acceptanceRecord,
        sourceEntityID: record.id.uuidString,
        targetEntityType: .order,
        targetEntityID: nil,
        title: record.sourceLabel,
        summary: "Acceptance history says the record was accepted, but no tracked order is linked.",
        detectedValue: record.decision.rawValue,
        currentOperationalValue: "No linked order",
        suggestedResolution: "Link the accepted source to an existing tracked order or create a new order from Acceptance Review.",
        createdDate: record.decidedDate
      )
    }
  }

  private func shipmentGroupMissingPrimaryReconciliationIssues() -> [ReconciliationIssue] {
    shipmentGroups.compactMap { group in
      guard group.primaryOrderID == nil || group.primaryOrderID.flatMap({ id in orders.first { $0.id == id } }) == nil else { return nil }
      return reconciliationIssue(
        id: "recon-group-primary-\(group.id.uuidString)",
        issueType: .shipmentGroupMissingPrimary,
        severity: group.riskLevel == .critical || group.riskLevel == .high ? .high : .warning,
        sourceEntityType: .shipmentGroup,
        sourceEntityID: group.id.uuidString,
        targetEntityType: .order,
        targetEntityID: group.primaryOrderID?.uuidString,
        title: group.groupName,
        summary: "Shipment group has no valid primary tracked order.",
        detectedValue: group.statusSummary,
        currentOperationalValue: group.primaryOrderID?.uuidString ?? "No primary order",
        suggestedResolution: "Select a primary order or create one from related intake/import context.",
        createdDate: group.createdDate
      )
    }
  }

  private func reconciliationConflictIssue(
    id: String,
    issueType: ReconciliationIssueType,
    sourceEntityType: ReconciliationEntityType,
    sourceEntityID: String,
    targetEntityType: ReconciliationEntityType,
    targetEntityID: String,
    title: String,
    summary: String,
    detectedValue: String,
    currentOperationalValue: String,
    createdDate: String
  ) -> ReconciliationIssue {
    reconciliationIssue(
      id: id,
      issueType: issueType,
      severity: .high,
      sourceEntityType: sourceEntityType,
      sourceEntityID: sourceEntityID,
      targetEntityType: targetEntityType,
      targetEntityID: targetEntityID,
      title: title,
      summary: summary,
      detectedValue: detectedValue,
      currentOperationalValue: currentOperationalValue,
      suggestedResolution: "Review the detected value against the operational value before changing order or shipment records.",
      createdDate: createdDate
    )
  }

  private func reconciliationIssue(
    id: String,
    issueType: ReconciliationIssueType,
    severity: ValidationSeverity,
    sourceEntityType: ReconciliationEntityType,
    sourceEntityID: String,
    targetEntityType: ReconciliationEntityType?,
    targetEntityID: String?,
    title: String,
    summary: String,
    detectedValue: String,
    currentOperationalValue: String,
    suggestedResolution: String,
    createdDate: String
  ) -> ReconciliationIssue {
    ReconciliationIssue(
      id: id,
      issueType: issueType,
      severity: severity,
      sourceEntityType: sourceEntityType,
      sourceEntityID: sourceEntityID,
      targetEntityType: targetEntityType,
      targetEntityID: targetEntityID,
      title: title,
      summary: summary,
      detectedValue: detectedValue,
      currentOperationalValue: currentOperationalValue,
      suggestedResolution: suggestedResolution,
      reviewState: isReconciliationIssueReviewed(id) ? .accepted : .needsReview,
      createdDate: createdDate
    )
  }

  private func isReconciliationIssueReviewed(_ issueID: String) -> Bool {
    auditEvents.contains { event in
      event.entityType == .reconciliationIssue && event.entityID == issueID && event.action == .reviewed
    }
  }

  func addImportQueueItemPlaceholder() {
    let item = ImportQueueItem(
      sourceType: .manualEntry,
      sourceLabel: "Manual import \(importQueueItems.count + 1)",
      capturedDate: Self.auditTimestamp(),
      rawSummary: "Manual placeholder import staged locally for review.",
      detectedMerchant: "Pending merchant",
      detectedOrderNumber: "Pending",
      detectedTrackingNumber: "Pending",
      detectedDestinationAddress: "Pending",
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: nil,
      confidenceScore: 45,
      importStatus: .staged,
      reviewState: .needsReview,
      notes: "Edit detected fields before accepting."
    )
    importQueueItems.insert(item, at: 0)
    persistImportQueueItems()
    logAudit(action: .created, entityType: .importQueueItem, entityID: item.id.uuidString, entityLabel: item.sourceLabel, summary: "Import queue item created.", afterDetail: item.auditDetail)
  }

  func updateImportQueueItem(_ item: ImportQueueItem) {
    guard let index = importQueueItems.firstIndex(where: { $0.id == item.id }) else { return }
    let beforeDetail = importQueueItems[index].auditDetail
    importQueueItems[index] = item
    persistImportQueueItems()
    logAudit(action: .edited, entityType: .importQueueItem, entityID: item.id.uuidString, entityLabel: item.sourceLabel, summary: "Import queue item updated.", beforeDetail: beforeDetail, afterDetail: item.auditDetail)
  }

  func linkImportQueueItem(_ item: ImportQueueItem, to order: TrackedOrder) {
    guard let index = importQueueItems.firstIndex(where: { $0.id == item.id }) else { return }
    let beforeDetail = importQueueItems[index].auditDetail
    importQueueItems[index].suggestedLinkedOrderID = order.id
    importQueueItems[index].importStatus = .linked
    importQueueItems[index].reviewState = .monitor
    persistImportQueueItems()
    logAudit(action: .linked, entityType: .importQueueItem, entityID: item.id.uuidString, entityLabel: item.sourceLabel, summary: "Import item linked to tracked order \(order.orderNumber).", beforeDetail: beforeDetail, afterDetail: importQueueItems[index].auditDetail)
  }

  func linkImportQueueItem(_ item: ImportQueueItem, to group: ShipmentGroup) {
    guard let index = importQueueItems.firstIndex(where: { $0.id == item.id }) else { return }
    let beforeDetail = importQueueItems[index].auditDetail
    importQueueItems[index].suggestedShipmentGroupID = group.id
    importQueueItems[index].importStatus = .linked
    importQueueItems[index].reviewState = .monitor
    persistImportQueueItems()
    logAudit(action: .linked, entityType: .importQueueItem, entityID: item.id.uuidString, entityLabel: item.sourceLabel, summary: "Import item linked to shipment group \(group.groupName).", beforeDetail: beforeDetail, afterDetail: importQueueItems[index].auditDetail)
  }

  func createOrder(from item: ImportQueueItem) {
    let order = TrackedOrder(
      orderNumber: item.detectedOrderNumber.isPlaceholderValidationValue ? "IMP-\(1000 + orders.count + 1)" : item.detectedOrderNumber,
      store: item.detectedMerchant.isPlaceholderValidationValue ? "Imported merchant" : item.detectedMerchant,
      recipientEmail: "import-queue@parcelops.example",
      checkedMailbox: "manual-import",
      customer: "Operations",
      fulfillment: .delivery,
      carrier: item.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending" : "Imported carrier",
      trackingNumber: item.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending" : item.detectedTrackingNumber,
      destination: item.detectedDestinationAddress.isPlaceholderValidationValue ? "Pending" : item.detectedDestinationAddress,
      eta: "Pending",
      source: .manual,
      status: .intake,
      reviewState: .needsReview,
      latestStatus: "Created from manual import queue item.",
      timeline: [TimelineEvent(title: "Import accepted", detail: item.sourceLabel, time: "Now", symbol: "tray.and.arrow.down.fill")],
      contactHistory: [ContactHistoryEvent(time: "Now", source: .manual, contactPoint: item.sourceLabel, summary: "Order created from import queue.", evidence: item.rawSummary, reviewState: .needsReview)]
    )
    orders.insert(order, at: 0)
    persistOrders()
    linkImportQueueItem(item, to: order)
    logAudit(action: .created, entityType: .order, entityID: order.id.uuidString, entityLabel: order.orderNumber, summary: "Order created from import queue item.", afterDetail: order.auditDetail)
  }

  func createShipmentGroup(from item: ImportQueueItem) {
    let group = ShipmentGroup(
      groupName: item.detectedOrderNumber.isPlaceholderValidationValue ? "Imported shipment group" : "Import \(item.detectedOrderNumber)",
      primaryOrderID: item.suggestedLinkedOrderID,
      relatedOrderIDs: item.suggestedLinkedOrderID.map { [$0] } ?? [],
      relatedIntakeEmailIDs: [],
      relatedTrackingEventIDs: [],
      relatedEvidenceIDs: [],
      destinationSummary: item.detectedDestinationAddress,
      recipientCustomerSummary: "Operations",
      carrierSummary: item.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending carrier" : "Imported tracking \(item.detectedTrackingNumber)",
      statusSummary: "Created from import queue",
      riskLevel: item.confidenceScore < 50 ? .high : .medium,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    shipmentGroups.insert(group, at: 0)
    persistShipmentGroups()
    linkImportQueueItem(item, to: group)
    logAudit(action: .created, entityType: .shipmentGroup, entityID: group.id.uuidString, entityLabel: group.groupName, summary: "Shipment group created from import queue item.", afterDetail: group.auditDetail)
  }

  func markImportQueueItemAccepted(_ item: ImportQueueItem) {
    setImportQueueItem(item, status: .accepted, reviewState: .accepted, action: .reviewed, summary: "Import queue item accepted.")
  }

  func ignoreImportQueueItem(_ item: ImportQueueItem) {
    setImportQueueItem(item, status: .ignored, reviewState: .monitor, action: .ignored, summary: "Import queue item ignored.")
  }

  func reopenImportQueueItem(_ item: ImportQueueItem) {
    setImportQueueItem(item, status: .reopened, reviewState: .needsReview, action: .reopened, summary: "Import queue item reopened.")
  }

  func removeImportQueueItem(_ item: ImportQueueItem) {
    guard let index = importQueueItems.firstIndex(where: { $0.id == item.id }) else { return }
    let removed = importQueueItems.remove(at: index)
    persistImportQueueItems()
    logAudit(action: .removed, entityType: .importQueueItem, entityID: removed.id.uuidString, entityLabel: removed.sourceLabel, summary: "Import queue item removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from item: ImportQueueItem) {
    createReviewTask(linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString, label: item.sourceLabel, summary: "Review import queue item: \(item.rawSummary)", priority: item.importStatus == .blocked || item.confidenceScore < 50 ? .high : .normal)
  }

  func createDraftMessage(from item: ImportQueueItem) {
    createDraftMessage(linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString, label: item.sourceLabel, recipient: "operations@parcelops.example")
  }

  func linkAcceptanceCandidate(_ candidate: AcceptanceCandidate, to order: TrackedOrder) {
    switch candidate.sourceType {
    case .importQueueItem:
      guard let item = importQueueItems.first(where: { $0.id == candidate.sourceID }) else { return }
      linkImportQueueItem(item, to: order)
    case .intakeEmail:
      guard let email = intakeEmails.first(where: { $0.id == candidate.sourceID }) else { return }
      linkIntakeEmail(email, to: order)
    }
    upsertAcceptanceRecord(from: candidate, decision: .ready, reviewState: .monitor, linkedOrderID: order.id, linkedShipmentGroupID: candidate.suggestedShipmentGroupID, summary: "Acceptance candidate linked to tracked order \(order.orderNumber).", action: .linked)
  }

  func linkAcceptanceCandidate(_ candidate: AcceptanceCandidate, to group: ShipmentGroup) {
    switch candidate.sourceType {
    case .importQueueItem:
      guard let item = importQueueItems.first(where: { $0.id == candidate.sourceID }) else { return }
      linkImportQueueItem(item, to: group)
    case .intakeEmail:
      linkIntakeEmail(candidate.sourceID, to: group)
    }
    upsertAcceptanceRecord(from: candidate, decision: .ready, reviewState: .monitor, linkedOrderID: candidate.suggestedLinkedOrderID, linkedShipmentGroupID: group.id, summary: "Acceptance candidate linked to shipment group \(group.groupName).", action: .linked)
  }

  func createOrder(from candidate: AcceptanceCandidate) {
    let order = TrackedOrder(
      orderNumber: candidate.detectedOrderNumber.isPlaceholderValidationValue ? "ACC-\(4000 + orders.count + 1)" : candidate.detectedOrderNumber,
      store: candidate.detectedMerchant.isPlaceholderValidationValue ? "Accepted merchant" : candidate.detectedMerchant,
      recipientEmail: candidate.sourceType == .intakeEmail ? "captured-from-forward@parcelops.example" : "import-queue@parcelops.example",
      checkedMailbox: candidate.sourceType == .intakeEmail ? "tracking-intake@parcelops.example" : "manual-import",
      customer: "Operations",
      fulfillment: .delivery,
      carrier: candidate.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending" : "Carrier pending",
      trackingNumber: candidate.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending" : candidate.detectedTrackingNumber,
      destination: candidate.detectedDestinationAddress.isPlaceholderValidationValue ? "Pending" : candidate.detectedDestinationAddress,
      eta: "Pending",
      source: candidate.sourceType == .intakeEmail ? .forwardedMailbox : .manual,
      status: candidate.detectedTrackingNumber.isPlaceholderValidationValue ? .intake : .shipped,
      reviewState: .needsReview,
      latestStatus: "Created from local acceptance review.",
      timeline: [TimelineEvent(title: "Acceptance review", detail: candidate.sourceLabel, time: "Now", symbol: "checkmark.rectangle.stack.fill")],
      contactHistory: [ContactHistoryEvent(time: "Now", source: candidate.sourceType == .intakeEmail ? .mailbox : .manual, contactPoint: "Acceptance Review", summary: "Order created from acceptance workflow.", evidence: candidate.rawSummary, reviewState: .needsReview)]
    )
    orders.insert(order, at: 0)
    persistOrders()
    linkAcceptanceCandidate(candidate, to: order)
    logAudit(action: .created, entityType: .order, entityID: order.id.uuidString, entityLabel: order.orderNumber, summary: "Order created from acceptance review.", afterDetail: order.auditDetail)
  }

  func createShipmentGroup(from candidate: AcceptanceCandidate) {
    let group = ShipmentGroup(
      groupName: candidate.detectedOrderNumber.isPlaceholderValidationValue ? "Accepted shipment group" : "Acceptance \(candidate.detectedOrderNumber)",
      primaryOrderID: candidate.suggestedLinkedOrderID,
      relatedOrderIDs: candidate.suggestedLinkedOrderID.map { [$0] } ?? [],
      relatedIntakeEmailIDs: candidate.sourceType == .intakeEmail ? [candidate.sourceID] : [],
      relatedTrackingEventIDs: [],
      relatedEvidenceIDs: [],
      destinationSummary: candidate.detectedDestinationAddress,
      recipientCustomerSummary: "Operations",
      carrierSummary: candidate.detectedTrackingNumber.isPlaceholderValidationValue ? "Pending carrier" : "Accepted tracking \(candidate.detectedTrackingNumber)",
      statusSummary: "Created from acceptance review",
      riskLevel: candidate.confidenceScore < 50 ? .high : .medium,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    shipmentGroups.insert(group, at: 0)
    persistShipmentGroups()
    linkAcceptanceCandidate(candidate, to: group)
    logAudit(action: .created, entityType: .shipmentGroup, entityID: group.id.uuidString, entityLabel: group.groupName, summary: "Shipment group created from acceptance review.", afterDetail: group.auditDetail)
  }

  func acceptCandidate(_ candidate: AcceptanceCandidate) {
    setCandidateSourceState(candidate, decision: .accepted)
    upsertAcceptanceRecord(from: candidate, decision: .accepted, reviewState: .accepted, linkedOrderID: refreshedCandidate(for: candidate).suggestedLinkedOrderID, linkedShipmentGroupID: refreshedCandidate(for: candidate).suggestedShipmentGroupID, summary: "Acceptance candidate accepted into operations.", action: .reviewed)
  }

  func ignoreCandidate(_ candidate: AcceptanceCandidate) {
    setCandidateSourceState(candidate, decision: .ignored)
    upsertAcceptanceRecord(from: candidate, decision: .ignored, reviewState: .monitor, linkedOrderID: refreshedCandidate(for: candidate).suggestedLinkedOrderID, linkedShipmentGroupID: refreshedCandidate(for: candidate).suggestedShipmentGroupID, summary: "Acceptance candidate ignored locally.", action: .ignored)
  }

  func reopenCandidate(_ candidate: AcceptanceCandidate) {
    setCandidateSourceState(candidate, decision: .reopened)
    upsertAcceptanceRecord(from: candidate, decision: .reopened, reviewState: .needsReview, linkedOrderID: refreshedCandidate(for: candidate).suggestedLinkedOrderID, linkedShipmentGroupID: refreshedCandidate(for: candidate).suggestedShipmentGroupID, summary: "Acceptance candidate reopened for review.", action: .reopened)
  }

  func createReviewTask(from candidate: AcceptanceCandidate) {
    createReviewTask(linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString, label: candidate.sourceLabel, summary: "Review acceptance candidate: \(candidate.rawSummary)", priority: candidate.decision == .blocked || candidate.confidenceScore < 50 ? .high : .normal)
  }

  func createDraftMessage(from candidate: AcceptanceCandidate) {
    createDraftMessage(linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString, label: candidate.sourceLabel, recipient: "operations@parcelops.example")
  }

  private func linkIntakeEmail(_ emailID: UUID, to group: ShipmentGroup) {
    guard let groupIndex = shipmentGroups.firstIndex(where: { $0.id == group.id }) else { return }
    let beforeDetail = shipmentGroups[groupIndex].auditDetail
    if !shipmentGroups[groupIndex].relatedIntakeEmailIDs.contains(emailID) {
      shipmentGroups[groupIndex].relatedIntakeEmailIDs.append(emailID)
    }
    shipmentGroups[groupIndex].reviewState = .monitor
    persistShipmentGroups()
    logAudit(action: .linked, entityType: .shipmentGroup, entityID: group.id.uuidString, entityLabel: group.groupName, summary: "Forwarded intake email linked to shipment group.", beforeDetail: beforeDetail, afterDetail: shipmentGroups[groupIndex].auditDetail)
  }

  private func setCandidateSourceState(_ candidate: AcceptanceCandidate, decision: AcceptanceDecision) {
    switch candidate.sourceType {
    case .importQueueItem:
      guard let item = importQueueItems.first(where: { $0.id == candidate.sourceID }) else { return }
      switch decision {
      case .accepted:
        markImportQueueItemAccepted(item)
      case .ignored:
        ignoreImportQueueItem(item)
      case .reopened:
        reopenImportQueueItem(item)
      case .blocked:
        setImportQueueItem(item, status: .blocked, reviewState: .monitor, action: .edited, summary: "Import queue item blocked in acceptance review.")
      case .ready:
        break
      }
    case .intakeEmail:
      guard let email = intakeEmails.first(where: { $0.id == candidate.sourceID }) else { return }
      switch decision {
      case .accepted:
        markIntakeEmailReviewed(email)
      case .ignored:
        ignoreIntakeEmail(email)
      case .reopened:
        updateIntakeEmail(email, reviewState: .needsReview)
      case .blocked, .ready:
        break
      }
    }
  }

  private func refreshedCandidate(for candidate: AcceptanceCandidate) -> AcceptanceCandidate {
    acceptanceCandidates.first { $0.sourceType == candidate.sourceType && $0.sourceID == candidate.sourceID } ?? candidate
  }

  private func acceptanceRecord(sourceType: AcceptanceSourceType, sourceID: UUID) -> AcceptanceRecord? {
    acceptanceRecords.first { $0.sourceType == sourceType && $0.sourceID == sourceID }
  }

  private func upsertAcceptanceRecord(
    from candidate: AcceptanceCandidate,
    decision: AcceptanceDecision,
    reviewState: ReviewState,
    linkedOrderID: UUID?,
    linkedShipmentGroupID: UUID?,
    summary: String,
    action: AuditAction
  ) {
    let updatedCandidate = refreshedCandidate(for: candidate)
    let record = AcceptanceRecord(
      id: acceptanceRecord(sourceType: candidate.sourceType, sourceID: candidate.sourceID)?.id ?? UUID(),
      sourceType: candidate.sourceType,
      sourceID: candidate.sourceID,
      sourceLabel: updatedCandidate.sourceLabel,
      decidedDate: Self.auditTimestamp(),
      confidenceScore: updatedCandidate.confidenceScore,
      linkedOrderID: linkedOrderID ?? updatedCandidate.suggestedLinkedOrderID,
      linkedShipmentGroupID: linkedShipmentGroupID ?? updatedCandidate.suggestedShipmentGroupID,
      decision: decision,
      reviewState: reviewState,
      summary: summary,
      notes: updatedCandidate.notes
    )

    if let index = acceptanceRecords.firstIndex(where: { $0.sourceType == candidate.sourceType && $0.sourceID == candidate.sourceID }) {
      let beforeDetail = acceptanceRecords[index].auditDetail
      acceptanceRecords[index] = record
      persistAcceptanceRecords()
      logAudit(action: action, entityType: .acceptanceRecord, entityID: record.id.uuidString, entityLabel: record.sourceLabel, summary: summary, beforeDetail: beforeDetail, afterDetail: record.auditDetail)
    } else {
      acceptanceRecords.insert(record, at: 0)
      persistAcceptanceRecords()
      logAudit(action: action, entityType: .acceptanceRecord, entityID: record.id.uuidString, entityLabel: record.sourceLabel, summary: summary, afterDetail: record.auditDetail)
    }
  }

  private func setImportQueueItem(_ item: ImportQueueItem, status: ImportStatus, reviewState: ReviewState, action: AuditAction, summary: String) {
    guard let index = importQueueItems.firstIndex(where: { $0.id == item.id }) else { return }
    let beforeDetail = importQueueItems[index].auditDetail
    importQueueItems[index].importStatus = status
    importQueueItems[index].reviewState = reviewState
    persistImportQueueItems()
    logAudit(action: action, entityType: .importQueueItem, entityID: item.id.uuidString, entityLabel: item.sourceLabel, summary: summary, beforeDetail: beforeDetail, afterDetail: importQueueItems[index].auditDetail)
  }

  func addShipmentGroupPlaceholder() {
    let primaryOrder = orders.first
    let group = ShipmentGroup(
      groupName: "New shipment group",
      primaryOrderID: primaryOrder?.id,
      relatedOrderIDs: primaryOrder.map { [$0.id] } ?? [],
      relatedIntakeEmailIDs: [],
      relatedTrackingEventIDs: [],
      relatedEvidenceIDs: [],
      destinationSummary: primaryOrder?.destination ?? "Pending destination",
      recipientCustomerSummary: primaryOrder?.customer ?? "Unassigned",
      carrierSummary: primaryOrder?.carrier ?? "Pending carrier",
      statusSummary: "Manual grouping placeholder",
      riskLevel: .medium,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    shipmentGroups.insert(group, at: 0)
    persistShipmentGroups()
    logAudit(
      action: .created,
      entityType: .shipmentGroup,
      entityID: group.id.uuidString,
      entityLabel: group.groupName,
      summary: "Shipment group created locally.",
      afterDetail: group.auditDetail
    )
  }

  func updateShipmentGroup(_ group: ShipmentGroup) {
    guard let index = shipmentGroups.firstIndex(where: { $0.id == group.id }) else { return }
    let beforeDetail = shipmentGroups[index].auditDetail
    shipmentGroups[index] = group
    persistShipmentGroups()
    logAudit(
      action: .edited,
      entityType: .shipmentGroup,
      entityID: group.id.uuidString,
      entityLabel: group.groupName,
      summary: "Shipment group details updated.",
      beforeDetail: beforeDetail,
      afterDetail: group.auditDetail
    )
  }

  func markShipmentGroupReviewed(_ group: ShipmentGroup) {
    guard let index = shipmentGroups.firstIndex(where: { $0.id == group.id }) else { return }
    let beforeDetail = shipmentGroups[index].auditDetail
    shipmentGroups[index].reviewState = .accepted
    shipmentGroups[index].lastReviewedDate = Self.auditTimestamp()
    persistShipmentGroups()
    logAudit(
      action: .reviewed,
      entityType: .shipmentGroup,
      entityID: group.id.uuidString,
      entityLabel: group.groupName,
      summary: "Shipment group marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: shipmentGroups[index].auditDetail
    )
  }

  func removeShipmentGroup(_ group: ShipmentGroup) {
    guard let index = shipmentGroups.firstIndex(where: { $0.id == group.id }) else { return }
    let removed = shipmentGroups.remove(at: index)
    persistShipmentGroups()
    logAudit(
      action: .removed,
      entityType: .shipmentGroup,
      entityID: removed.id.uuidString,
      entityLabel: removed.groupName,
      summary: "Shipment group removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func createReviewTask(from group: ShipmentGroup) {
    createReviewTask(
      linkedEntityType: .shipmentGroup,
      linkedEntityID: group.id.uuidString,
      label: group.groupName,
      summary: "Review shipment group: \(group.statusSummary). \(group.destinationSummary)",
      priority: group.riskLevel == .critical ? .urgent : group.riskLevel == .high ? .high : .normal
    )
  }

  func createDraftMessage(from group: ShipmentGroup) {
    createDraftMessage(
      linkedEntityType: .shipmentGroup,
      linkedEntityID: group.id.uuidString,
      label: group.groupName,
      recipient: "operations@parcelops.example"
    )
  }

  private func orderValidationIssues() -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    let orderNumberCounts = Dictionary(grouping: orders, by: { $0.orderNumber.normalizedValidationKey }).mapValues(\.count)
    let trackingCounts = Dictionary(grouping: orders.filter { !$0.trackingNumber.isPlaceholderValidationValue }, by: { $0.trackingNumber.normalizedValidationKey }).mapValues(\.count)

    for order in orders {
      let missingFields = [
        ("order number", order.orderNumber),
        ("store", order.store),
        ("recipient email", order.recipientEmail),
        ("customer/team", order.customer),
        ("carrier", order.carrier),
        ("tracking number", order.trackingNumber),
        ("destination", order.destination)
      ].filter { $0.1.isPlaceholderValidationValue }.map(\.0)

      if !missingFields.isEmpty {
        issues.append(validationIssue(
          id: "validation-order-missing-\(order.id.uuidString)",
          entityType: .order,
          entityID: order.id.uuidString,
          linkedEntityType: .order,
          title: "\(order.store) \(order.orderNumber)",
          subtitle: "Missing \(missingFields.joined(separator: ", "))",
          detail: "Order has incomplete local fields: \(missingFields.joined(separator: ", ")).",
          confidenceScore: max(35, 92 - missingFields.count * 12),
          severity: missingFields.contains("tracking number") || missingFields.contains("destination") ? .high : .warning,
          status: .incomplete,
          reviewState: order.reviewState,
          suggestedActionText: "Correct the tracked order fields."
        ))
      }

      if orderNumberCounts[order.orderNumber.normalizedValidationKey, default: 0] > 1 {
        issues.append(validationIssue(
          id: "validation-order-duplicate-\(order.id.uuidString)",
          entityType: .order,
          entityID: order.id.uuidString,
          linkedEntityType: .order,
          title: order.orderNumber,
          subtitle: "\(order.store) duplicate order number",
          detail: "More than one tracked order uses order number \(order.orderNumber).",
          confidenceScore: 58,
          severity: .high,
          status: .duplicate,
          reviewState: order.reviewState,
          suggestedActionText: "Compare duplicate order records."
        ))
      }

      if trackingCounts[order.trackingNumber.normalizedValidationKey, default: 0] > 1 {
        issues.append(validationIssue(
          id: "validation-order-tracking-duplicate-\(order.id.uuidString)",
          entityType: .trackingNumber,
          entityID: order.id.uuidString,
          linkedEntityType: .order,
          title: order.trackingNumber,
          subtitle: "\(order.orderNumber) duplicate tracking number",
          detail: "More than one tracked order uses tracking number \(order.trackingNumber).",
          confidenceScore: 55,
          severity: .high,
          status: .duplicate,
          reviewState: order.reviewState,
          suggestedActionText: "Verify whether this is a split shipment or duplicate order."
        ))
      }

      if order.status == .exception && order.reviewState == .accepted {
        issues.append(validationIssue(
          id: "validation-order-stale-\(order.id.uuidString)",
          entityType: .order,
          entityID: order.id.uuidString,
          linkedEntityType: .order,
          title: order.orderNumber,
          subtitle: "Exception marked accepted",
          detail: "Order is still in exception status but its review state is accepted.",
          confidenceScore: 62,
          severity: .warning,
          status: .staleReview,
          reviewState: order.reviewState,
          suggestedActionText: "Re-check review state after exception correction."
        ))
      }
    }

    return issues
  }

  private func reviewTaskWorkbenchItems() -> [WorkbenchItem] {
    reviewTasks.filter { $0.status != .completed || $0.reviewState != .accepted }.map { task in
      let isSpaceMailFollowUp = task.title.localizedCaseInsensitiveContains("spacemail")
        || task.summary.localizedCaseInsensitiveContains("spacemail")
      return WorkbenchItem(
        id: "task-\(task.id.uuidString)",
        title: task.title,
        summary: isSpaceMailFollowUp
          ? "\(task.summary) Mailbox Monitor has the source refresh, mixed-mailbox, and classifier context."
          : task.summary,
        linkedEntityType: .reviewTask,
        linkedEntityID: task.id.uuidString,
        prioritySeverity: task.priority.rawValue,
        status: task.status.rawValue,
        assignee: task.assignee,
        dueDateText: task.isLocallyOverdue ? "Overdue: \(task.dueDate)" : task.dueDate,
        reviewState: task.reviewState,
        source: .reviewTask,
        suggestedNextAction: isSpaceMailFollowUp
          ? "Open Mailbox Monitor, then complete or draft follow-up"
          : task.status == .completed ? "Mark reviewed" : "Complete or create draft"
      )
    }
  }

  private func handoffNoteWorkbenchItems() -> [WorkbenchItem] {
    handoffNotes.filter { $0.status != .completed || $0.reviewState != .accepted }.map { note in
      let isSpaceMailFollowUp = note.title.localizedCaseInsensitiveContains("spacemail")
        || note.summary.localizedCaseInsensitiveContains("spacemail")
        || note.notes.localizedCaseInsensitiveContains("spacemail")
      return WorkbenchItem(
        id: "handoff-\(note.id.uuidString)",
        title: note.title,
        summary: isSpaceMailFollowUp
          ? "\(note.summary) Mailbox Monitor has the source refresh, mixed-mailbox, and classifier context."
          : note.summary,
        linkedEntityType: .handoffNote,
        linkedEntityID: note.id.uuidString,
        prioritySeverity: note.priority.rawValue,
        status: note.status.rawValue,
        assignee: note.assignee,
        dueDateText: note.isLocallyOverdue ? "Overdue: \(note.dueDate)" : note.dueDate,
        reviewState: note.reviewState,
        source: .handoffNote,
        suggestedNextAction: isSpaceMailFollowUp
          ? "Open Mailbox Monitor, then acknowledge or complete handoff"
          : note.status == .open ? "Acknowledge handoff" : "Complete handoff"
      )
    }
  }

  private func intakeWorkbenchItems() -> [WorkbenchItem] {
    reviewIntakeEmails.map { email in
      WorkbenchItem(
        id: "intake-\(email.id.uuidString)",
        title: email.detectedOrderNumber,
        summary: "\(email.detectedMerchant): \(email.subject)",
        linkedEntityType: .integration,
        linkedEntityID: email.id.uuidString,
        prioritySeverity: "High",
        status: email.reviewState.rawValue,
        assignee: "Mailbox team",
        dueDateText: email.receivedDate,
        reviewState: .needsReview,
        source: .intakeEmail,
        suggestedNextAction: "Link or create order"
      )
    }
  }

  private func intakeParserWorkbenchItems() -> [WorkbenchItem] {
    intakeParserDiagnostics.map { diagnostic in
      WorkbenchItem(
        id: "intake-parser-\(diagnostic.intakeEmailID.uuidString)",
        title: diagnostic.title,
        summary: diagnostic.summary,
        linkedEntityType: .intakeEmail,
        linkedEntityID: diagnostic.intakeEmailID.uuidString,
        prioritySeverity: diagnostic.severity.rawValue,
        status: "Parser review",
        assignee: "Mailbox team",
        dueDateText: diagnostic.capturedDate,
        reviewState: .needsReview,
        source: .intakeParser,
        suggestedNextAction: diagnostic.recommendedAction
      )
    }
  }

  private func spaceMailIntakeWorkbenchItems() -> [WorkbenchItem] {
    spaceMailIntakeHealthSummaries.compactMap { summary in
      guard summary.tone != "success"
        || summary.importedCount > 0
        || summary.pendingUncertainReviewCount > 0
        || summary.parserIssueCount > 0
      else { return nil }

      let priority: String
      let reviewState: ReviewState?
      if summary.tone == "warning" {
        priority = "High"
        reviewState = .needsReview
      } else if summary.pendingUncertainReviewCount > 0 || summary.parserIssueCount > 0 {
        priority = "Medium"
        reviewState = .needsReview
      } else {
        priority = "Normal"
        reviewState = .monitor
      }

      return WorkbenchItem(
        id: "spacemail-health-\(summary.connectionID.uuidString)",
        title: summary.verdict,
        summary: "\(summary.displayName): \(summary.detail)",
        linkedEntityType: .intakeEmail,
        linkedEntityID: summary.connectionID.uuidString,
        prioritySeverity: priority,
        status: summary.verdict,
        assignee: "Mailbox team",
        dueDateText: summary.lastRefreshDate,
        reviewState: reviewState,
        source: .spaceMailIntake,
        suggestedNextAction: summary.nextAction
      )
    }
  }

  private func gmailIntakeWorkbenchItems() -> [WorkbenchItem] {
    gmailIntakeHealthSummaries.compactMap { summary in
      guard summary.tone != "success"
        || summary.importedCount > 0
        || summary.pendingUncertainReviewCount > 0
      else { return nil }

      let priority: String
      let reviewState: ReviewState?
      if summary.tone == "warning" {
        priority = "High"
        reviewState = .needsReview
      } else if summary.pendingUncertainReviewCount > 0 || summary.uncertainCount > 0 {
        priority = "Medium"
        reviewState = .needsReview
      } else {
        priority = "Normal"
        reviewState = .monitor
      }

      return WorkbenchItem(
        id: "gmail-health-\(summary.connectionID.uuidString)",
        title: summary.verdict,
        summary: "\(summary.displayName): \(summary.detail)",
        linkedEntityType: .intakeEmail,
        linkedEntityID: summary.connectionID.uuidString,
        prioritySeverity: priority,
        status: summary.verdict,
        assignee: "Mailbox team",
        dueDateText: summary.lastRefreshDate,
        reviewState: reviewState,
        source: .gmailIntake,
        suggestedNextAction: summary.nextAction
      )
    }
  }

  private func mailboxClassifierWorkbenchItems() -> [WorkbenchItem] {
    let spaceMailItems = spaceMailIMAPConnections.compactMap { connection -> WorkbenchItem? in
      let decisionFailures = connection.classifierTestResults.filter {
        $0.decisionStatus.localizedCaseInsensitiveContains("needs review")
          || $0.parserStatus.localizedCaseInsensitiveContains("needs review")
      }
      guard !decisionFailures.isEmpty else { return nil }
      let examples = decisionFailures.prefix(3).map { result in
        "\(result.sampleName): \(result.decision)"
      }.joined(separator: "; ")

      return WorkbenchItem(
        id: "spacemail-classifier-\(connection.id.uuidString)",
        title: "SpaceMail classifier needs review",
        summary: "\(connection.displayName): \(decisionFailures.count) classifier/parser expectation\(decisionFailures.count == 1 ? "" : "s") need review. \(examples)",
        linkedEntityType: .integration,
        linkedEntityID: connection.id.uuidString,
        prioritySeverity: "Medium",
        status: "Classifier needs review",
        assignee: "Mailbox team",
        dueDateText: connection.lastManualRefreshDate,
        reviewState: .needsReview,
        source: .spaceMailIntake,
        suggestedNextAction: "Open Mailbox Monitor and adjust hints or parser expectations before relying on mixed-mailbox filtering."
      )
    }

    let gmailItems = gmailMailboxConnections.compactMap { connection -> WorkbenchItem? in
      let decisionFailures = (connection.classifierTestResults ?? []).filter {
        $0.decisionStatus.localizedCaseInsensitiveContains("needs review")
      }
      guard !decisionFailures.isEmpty else { return nil }
      let examples = decisionFailures.prefix(3).map { result in
        "\(result.sampleName): \(result.decision)"
      }.joined(separator: "; ")

      return WorkbenchItem(
        id: "gmail-classifier-\(connection.id.uuidString)",
        title: "Gmail classifier needs review",
        summary: "\(connection.displayName): \(decisionFailures.count) classifier expectation\(decisionFailures.count == 1 ? "" : "s") need review. \(examples)",
        linkedEntityType: .integration,
        linkedEntityID: connection.id.uuidString,
        prioritySeverity: "Medium",
        status: "Classifier needs review",
        assignee: "Mailbox team",
        dueDateText: connection.lastManualRefreshDate,
        reviewState: .needsReview,
        source: .gmailIntake,
        suggestedNextAction: "Open Mailbox Monitor and review Gmail classifier tests before using real mixed-mailbox intake."
      )
    }

    return spaceMailItems + gmailItems
  }

  private func importQueueWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(blockedImportQueueItems + lowConfidenceImportQueueItems + importQueueItemsNeedingReview)).map { item in
      WorkbenchItem(
        id: "import-\(item.id.uuidString)",
        title: item.sourceLabel,
        summary: item.rawSummary,
        linkedEntityType: .importQueueItem,
        linkedEntityID: item.id.uuidString,
        prioritySeverity: item.importStatus == .blocked ? "High" : item.confidenceScore < 55 ? "Medium" : "Normal",
        status: item.importStatus.rawValue,
        assignee: "Import team",
        dueDateText: item.capturedDate,
        reviewState: item.reviewState,
        source: .importQueue,
        suggestedNextAction: "Accept, link, or ignore import"
      )
    }
  }

  private func acceptanceWorkbenchItems() -> [WorkbenchItem] {
    acceptanceCandidates.filter { $0.reviewState == .needsReview || $0.decision == .blocked || $0.decision == .ready || $0.decision == .reopened }.map { candidate in
      WorkbenchItem(
        id: "acceptance-\(candidate.id)",
        title: candidate.sourceLabel,
        summary: candidate.rawSummary,
        linkedEntityType: candidate.reviewTaskLinkedEntityType,
        linkedEntityID: candidate.sourceID.uuidString,
        prioritySeverity: candidate.decision == .blocked ? "High" : "Normal",
        status: candidate.decision.rawValue,
        assignee: "Operations",
        dueDateText: candidate.capturedDate,
        reviewState: candidate.reviewState,
        source: .acceptanceReview,
        suggestedNextAction: "Confirm operational acceptance"
      )
    }
  }

  private func reconciliationWorkbenchItems() -> [WorkbenchItem] {
    unresolvedReconciliationIssues.map { issue in
      WorkbenchItem(
        id: "reconciliation-\(issue.id)",
        title: issue.title,
        summary: issue.summary,
        linkedEntityType: .reconciliationIssue,
        linkedEntityID: issue.id,
        prioritySeverity: issue.severity.rawValue,
        status: issue.issueType.rawValue,
        assignee: "Ops lead",
        dueDateText: issue.createdDate,
        reviewState: issue.reviewState,
        source: .reconciliation,
        suggestedNextAction: issue.suggestedResolution
      )
    }
  }

  private func validationWorkbenchItems() -> [WorkbenchItem] {
    validationIssues.filter { $0.severity == .critical || $0.severity == .high || $0.status == .needsCorrection || $0.status == .conflict || $0.reviewState == .needsReview }.map { issue in
      WorkbenchItem(
        id: "validation-\(issue.id)",
        title: issue.title,
        summary: issue.detail,
        linkedEntityType: issue.linkedEntityType ?? .auditEvent,
        linkedEntityID: issue.entityID,
        prioritySeverity: issue.severity.rawValue,
        status: issue.status.rawValue,
        assignee: "Quality team",
        dueDateText: "\(issue.confidenceScore)% confidence",
        reviewState: issue.reviewState,
        source: .validation,
        suggestedNextAction: issue.suggestedActionText
      )
    }
  }

  private func shipmentGroupWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(shipmentGroupsNeedingReview + highRiskShipmentGroups)).map { group in
      WorkbenchItem(
        id: "shipment-group-\(group.id.uuidString)",
        title: group.groupName,
        summary: "\(group.statusSummary) • \(group.destinationSummary)",
        linkedEntityType: .shipmentGroup,
        linkedEntityID: group.id.uuidString,
        prioritySeverity: group.riskLevel.rawValue,
        status: group.statusSummary,
        assignee: group.recipientCustomerSummary,
        dueDateText: group.lastReviewedDate,
        reviewState: group.reviewState,
        source: .shipmentGroup,
        suggestedNextAction: "Review grouped shipment context"
      )
    }
  }

  private func trackingWorkbenchItems() -> [WorkbenchItem] {
    reviewCarrierTrackingEvents.map { event in
      WorkbenchItem(
        id: "tracking-\(event.id.uuidString)",
        title: event.trackingNumber,
        summary: "\(event.carrier): \(event.detail)",
        linkedEntityType: .trackingEvent,
        linkedEntityID: event.id.uuidString,
        prioritySeverity: event.severity.rawValue,
        status: event.status,
        assignee: "Carrier follow-up",
        dueDateText: event.eventTime,
        reviewState: event.reviewState,
        source: .tracking,
        suggestedNextAction: event.severity == .critical ? "Escalate carrier exception" : "Review tracking update"
      )
    }
  }

  private func evidenceWorkbenchItems() -> [WorkbenchItem] {
    reviewEvidenceAttachments.map { attachment in
      WorkbenchItem(
        id: "evidence-\(attachment.id.uuidString)",
        title: attachment.fileName,
        summary: attachment.summary,
        linkedEntityType: .evidence,
        linkedEntityID: attachment.id.uuidString,
        prioritySeverity: "Normal",
        status: attachment.reviewState.rawValue,
        assignee: "Evidence review",
        dueDateText: attachment.addedDate,
        reviewState: attachment.reviewState,
        source: .evidence,
        suggestedNextAction: "Review attachment evidence"
      )
    }
  }

  private func slaWorkbenchItems() -> [WorkbenchItem] {
    policiesNeedingReview.map { policy in
      WorkbenchItem(
        id: "sla-\(policy.id.uuidString)",
        title: policy.name,
        summary: "\(policy.conditionSummary) • \(policy.resolutionTarget)",
        linkedEntityType: .slaPolicy,
        linkedEntityID: policy.id.uuidString,
        prioritySeverity: policy.priority.rawValue,
        status: policy.isEnabled ? "Enabled" : "Disabled",
        assignee: "Ops lead",
        dueDateText: policy.lastEvaluatedDate,
        reviewState: policy.reviewState,
        source: .slaPolicy,
        suggestedNextAction: "Review policy target and matches"
      )
    }
  }

  private func exceptionPlaybookWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(playbooksNeedingReview + enabledHighPriorityPlaybooks)).map { playbook in
      WorkbenchItem(
        id: "playbook-\(playbook.id.uuidString)",
        title: playbook.name,
        summary: playbook.triggerSummary,
        linkedEntityType: .exceptionPlaybook,
        linkedEntityID: playbook.id.uuidString,
        prioritySeverity: playbook.priority.rawValue,
        status: playbook.isEnabled ? "Enabled" : "Disabled",
        assignee: playbook.escalationContact,
        dueDateText: playbook.lastReviewedDate,
        reviewState: playbook.reviewState,
        source: .exceptionPlaybook,
        suggestedNextAction: "Use or review playbook"
      )
    }
  }

  private func draftMessageWorkbenchItems() -> [WorkbenchItem] {
    draftMessages.filter { $0.reviewState == .needsReview || $0.status == .draft || $0.status == .reopened }.map { draft in
      WorkbenchItem(
        id: "draft-\(draft.id.uuidString)",
        title: draft.subject,
        summary: "To \(draft.recipient) via \(draft.channel.rawValue)",
        linkedEntityType: .draftMessage,
        linkedEntityID: draft.id.uuidString,
        prioritySeverity: "Normal",
        status: draft.status.rawValue,
        assignee: draft.recipient,
        dueDateText: draft.createdDate,
        reviewState: draft.reviewState,
        source: .draftMessage,
        suggestedNextAction: "Ready or send locally"
      )
    }
  }

  private func contactWorkbenchItems() -> [WorkbenchItem] {
    contactsNeedingReview.map { contact in
      WorkbenchItem(
        id: "contact-\(contact.id.uuidString)",
        title: contact.name,
        summary: "\(contact.organisation) • \(contact.role)",
        linkedEntityType: .contact,
        linkedEntityID: contact.id.uuidString,
        prioritySeverity: "Normal",
        status: contact.isEnabled ? "Enabled" : "Disabled",
        assignee: contact.organisation,
        dueDateText: contact.lastContactedDate,
        reviewState: contact.reviewState,
        source: .contact,
        suggestedNextAction: "Review contact details"
      )
    }
  }

  private func customerProfileWorkbenchItems() -> [WorkbenchItem] {
    customerRecipientProfiles.filter { $0.reviewState != .accepted || !$0.isEnabled }.map { profile in
      WorkbenchItem(
        id: "customer-profile-\(profile.id.uuidString)",
        title: profile.displayName,
        summary: "\(profile.organisationTeam) • \(profile.defaultDestinationAddress)",
        linkedEntityType: .customerProfile,
        linkedEntityID: profile.id.uuidString,
        prioritySeverity: profile.isEnabled ? "Normal" : "High",
        status: profile.isEnabled ? "Enabled" : "Disabled",
        assignee: profile.organisationTeam,
        dueDateText: profile.lastReviewedDate,
        reviewState: profile.reviewState,
        source: .customerProfile,
        suggestedNextAction: profile.isEnabled ? "Review customer profile" : "Enable or confirm profile"
      )
    }
  }

  private func destinationAddressWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(destinationAddressesNeedingReview + destinationAddresses.filter { !$0.isEnabled } + highRiskDestinationAddresses)).map { address in
      WorkbenchItem(
        id: "destination-address-\(address.id.uuidString)",
        title: address.label,
        summary: "\(address.addressLineSummary), \(address.cityRegion) • \(address.deliveryInstructions)",
        linkedEntityType: .destinationAddress,
        linkedEntityID: address.id.uuidString,
        prioritySeverity: address.isEnabled ? address.riskLevel.rawValue : "High",
        status: address.isEnabled ? "Enabled" : "Disabled",
        assignee: address.organisationTeam,
        dueDateText: address.lastReviewedDate,
        reviewState: address.reviewState,
        source: .destinationAddress,
        suggestedNextAction: address.isEnabled ? "Review address risk and instructions" : "Enable or confirm destination"
      )
    }
  }

  private func deliveryInstructionWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(deliveryInstructionsNeedingReview + deliveryInstructions.filter { !$0.isEnabled } + highRiskDeliveryInstructions + deliveryInstructionsWithAccessConstraints.filter { $0.reviewState != .accepted })).map { instruction in
      WorkbenchItem(
        id: "delivery-instruction-\(instruction.id.uuidString)",
        title: instruction.title,
        summary: "\(instruction.instructionType.rawValue) • \(instruction.instructionSummary)",
        linkedEntityType: .deliveryInstruction,
        linkedEntityID: instruction.id.uuidString,
        prioritySeverity: instruction.isEnabled ? instruction.riskLevel.rawValue : "High",
        status: instruction.isEnabled ? "Enabled" : "Disabled",
        assignee: instruction.preferredDeliveryWindow,
        dueDateText: instruction.lastReviewedDate,
        reviewState: instruction.reviewState,
        source: .deliveryInstruction,
        suggestedNextAction: instruction.accessConstraintSummary.isEmpty ? "Review delivery instruction" : "Confirm access constraints"
      )
    }
  }

  private func packageContentWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(packageContentsNeedingReview + unverifiedPackageContents + packageContentDiscrepancies + highRiskPackageContents + highValuePackageContents)).map { content in
      WorkbenchItem(
        id: "package-content-\(content.id.uuidString)",
        title: content.title,
        summary: "\(content.itemSummary) • \(content.verifiedQuantity)/\(content.expectedQuantity) verified",
        linkedEntityType: .packageContent,
        linkedEntityID: content.id.uuidString,
        prioritySeverity: content.verificationStatus == .discrepancy ? "High" : content.riskLevel.rawValue,
        status: content.verificationStatus.rawValue,
        assignee: content.itemCategory.rawValue,
        dueDateText: content.lastReviewedDate,
        reviewState: content.reviewState,
        source: .packageContent,
        suggestedNextAction: content.verificationStatus == .verified ? "Review package contents" : "Verify package contents"
      )
    }
  }

  private func costRecordWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(costRecordsNeedingReview + disputedCostRecords + unreimbursedCostRecords + unapprovedCostRecords + highRiskCostRecords + missingBudgetCodeCostRecords)).map { cost in
      WorkbenchItem(
        id: "cost-\(cost.id.uuidString)",
        title: cost.title,
        summary: "\(cost.amountText) \(cost.currency) • \(cost.costCategory.rawValue) • \(cost.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Missing budget" : cost.budgetCode)",
        linkedEntityType: .costRecord,
        linkedEntityID: cost.id.uuidString,
        prioritySeverity: cost.approvalStatus == .rejected || cost.reimbursementStatus == .disputed ? "High" : cost.riskLevel.rawValue,
        status: "\(cost.approvalStatus.rawValue) / \(cost.reimbursementStatus.rawValue)",
        assignee: cost.costOwnerTeam,
        dueDateText: cost.lastReviewedDate,
        reviewState: cost.reviewState,
        source: .costRecord,
        suggestedNextAction: cost.approvalStatus == .approved ? "Review reimbursement status" : "Approve or dispute cost"
      )
    }
  }

  private func returnClaimWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(returnClaimsNeedingReview + disputedReturnClaims + unresolvedReturnClaims + overdueReturnClaims + highRiskReturnClaims + returnClaimsMissingEvidence)).map { claim in
      WorkbenchItem(
        id: "return-claim-\(claim.id.uuidString)",
        title: claim.title,
        summary: "\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue) • \(claim.refundReplacementAmountText) \(claim.currency)",
        linkedEntityType: .returnClaim,
        linkedEntityID: claim.id.uuidString,
        prioritySeverity: claim.claimStatus == .disputed || claim.claimStatus == .blocked ? "High" : claim.riskLevel.rawValue,
        status: claim.claimStatus.rawValue,
        assignee: claim.assignedOwnerTeam,
        dueDateText: claim.dueDate,
        reviewState: claim.reviewState,
        source: .returnClaim,
        suggestedNextAction: claim.claimStatus == .resolved ? "Review resolved claim" : "Submit, resolve, or dispute claim"
      )
    }
  }

  private func procurementRequestWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(procurementRequestsNeedingReview + unapprovedProcurementRequests + rejectedProcurementRequests + notYetOrderedProcurementRequests + overdueProcurementRequests + highRiskProcurementRequests + missingBudgetCodeProcurementRequests)).map { request in
      WorkbenchItem(
        id: "procurement-\(request.id.uuidString)",
        title: request.title,
        summary: "\(request.requestedItemsSummary) • \(request.estimatedCostText) \(request.currency)",
        linkedEntityType: .procurementRequest,
        linkedEntityID: request.id.uuidString,
        prioritySeverity: request.approvalStatus == .rejected || request.procurementStatus == .blocked ? "High" : request.riskLevel.rawValue,
        status: "\(request.approvalStatus.rawValue) / \(request.procurementStatus.rawValue)",
        assignee: request.assignedBuyerTeam,
        dueDateText: request.neededByDate,
        reviewState: request.reviewState,
        source: .procurementRequest,
        suggestedNextAction: request.procurementStatus == .received ? "Review received procurement" : "Approve, order, or unblock procurement"
      )
    }
  }

  private func receivingInspectionWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(receivingInspectionsNeedingReview + blockedReceivingInspections + unresolvedInspectionDiscrepancies + highRiskReceivingInspections + overdueReceivingInspections + quantityMismatchReceivingInspections)).map { inspection in
      WorkbenchItem(
        id: "receiving-inspection-\(inspection.id.uuidString)",
        title: inspection.title,
        summary: "\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received • \(inspection.discrepancyType.rawValue)",
        linkedEntityType: .receivingInspection,
        linkedEntityID: inspection.id.uuidString,
        prioritySeverity: inspection.inspectionStatus == .blocked || inspection.riskLevel == .critical ? "High" : inspection.riskLevel.rawValue,
        status: inspection.inspectionStatus.rawValue,
        assignee: inspection.assignedInspectorTeam,
        dueDateText: inspection.dueDate,
        reviewState: inspection.reviewState,
        source: .receivingInspection,
        suggestedNextAction: inspection.inspectionStatus == .resolved ? "Review resolved inspection" : "Inspect, resolve, or block discrepancy"
      )
    }
  }

  private func inventoryReceiptWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(inventoryReceiptsNeedingReview + rejectedInventoryReceipts + partiallyAcceptedInventoryReceipts + highRiskInventoryReceipts + unassignedInventoryReceipts + inventoryReceiptsMissingStorage)).map { receipt in
      WorkbenchItem(
        id: "inventory-receipt-\(receipt.id.uuidString)",
        title: receipt.title,
        summary: "\(receipt.receiptType.rawValue) • \(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted • \(receipt.storageLocationSummary)",
        linkedEntityType: .inventoryReceipt,
        linkedEntityID: receipt.id.uuidString,
        prioritySeverity: receipt.stockHandoffStatus == .rejected || receipt.riskLevel == .critical ? "High" : receipt.riskLevel.rawValue,
        status: receipt.stockHandoffStatus.rawValue,
        assignee: receipt.assignedOwnerTeam,
        dueDateText: receipt.handoffDate,
        reviewState: receipt.reviewState,
        source: .inventoryReceipt,
        suggestedNextAction: receipt.stockHandoffStatus == .stocked || receipt.stockHandoffStatus == .handedOff ? "Review completed stock handoff" : "Stock, hand off, or reject receipt"
      )
    }
  }

  private func storageLocationWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(storageLocationsNeedingReview + disabledStorageLocations + highRiskStorageLocations + storageLocationsMissingCodes + storageLocationsWithAccessNotes + storageLocationsWithCapacityWarnings)).map { location in
      WorkbenchItem(
        id: "storage-location-\(location.id.uuidString)",
        title: location.title,
        summary: "\(location.locationType.rawValue) • \(location.locationCode) • \(location.currentUsageSummary)",
        linkedEntityType: .storageLocation,
        linkedEntityID: location.id.uuidString,
        prioritySeverity: !location.isEnabled || location.riskLevel == .critical ? "High" : location.riskLevel.rawValue,
        status: location.isEnabled ? "Enabled" : "Disabled",
        assignee: location.assignedOwnerTeam,
        dueDateText: location.lastReviewedDate,
        reviewState: location.reviewState,
        source: .storageLocation,
        suggestedNextAction: location.isEnabled ? "Review capacity, access, and location code" : "Enable or replace disabled location"
      )
    }
  }

  private func custodyRecordWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(custodyRecordsNeedingReview + disputedCustodyRecords + openCustodyTransfers + overdueCustodyRecords + highRiskCustodyRecords + custodyRecordsMissingCustodians + custodyRecordsMissingLocations)).map { record in
      WorkbenchItem(
        id: "custody-\(record.id.uuidString)",
        title: record.title,
        summary: "\(record.custodyStatus.rawValue) • \(record.currentCustodianTeam) • \(record.custodyReason)",
        linkedEntityType: .custodyRecord,
        linkedEntityID: record.id.uuidString,
        prioritySeverity: record.custodyStatus == .disputed || record.riskLevel == .critical ? "High" : record.riskLevel.rawValue,
        status: record.custodyStatus.rawValue,
        assignee: record.assignedOwnerTeam,
        dueDateText: record.expectedReturnCloseDate,
        reviewState: record.reviewState,
        source: .custodyRecord,
        suggestedNextAction: record.custodyStatus == .returnedClosed ? "Review closed custody" : "Transfer, receive, or resolve custody"
      )
    }
  }

  private func labelReferenceWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(labelReferencesNeedingReview + invalidLabelReferences + unverifiedLabelReferences + highRiskLabelReferences + labelReferencesMissingValues + labelReferencesMissingLinkedRecords)).map { record in
      WorkbenchItem(
        id: "label-reference-\(record.id.uuidString)",
        title: record.title,
        summary: "\(record.labelType.rawValue) • \(record.labelValuePlaceholder) • \(record.associatedCarrier)",
        linkedEntityType: .labelReference,
        linkedEntityID: record.id.uuidString,
        prioritySeverity: record.labelStatus == .invalidNeedsReview || record.riskLevel == .critical ? "High" : record.riskLevel.rawValue,
        status: record.labelStatus.rawValue,
        assignee: record.assignedOwnerTeam,
        dueDateText: record.lastReviewedDate,
        reviewState: record.reviewState,
        source: .labelReference,
        suggestedNextAction: record.labelStatus == .scannedVerified ? "Review verified label reference" : "Verify, correct, or invalidate local label"
      )
    }
  }

  private func scanSessionWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(scanSessionsNeedingReview + mismatchScanSessions + incompleteScanSessions + highRiskScanSessions + scanSessionsMissingCapturedValues + scanSessionsMissingLabelReferences)).map { record in
      WorkbenchItem(
        id: "scan-session-\(record.id.uuidString)",
        title: record.title,
        summary: "\(record.scanPurpose.rawValue) • \(record.expectedLabelReferenceValue) • captured \(record.capturedValuePlaceholder.isEmpty ? "missing" : record.capturedValuePlaceholder)",
        linkedEntityType: .scanSession,
        linkedEntityID: record.id.uuidString,
        prioritySeverity: record.scanStatus == .mismatchNeedsReview || record.riskLevel == .critical ? "High" : record.riskLevel.rawValue,
        status: record.scanStatus.rawValue,
        assignee: record.assignedOperatorTeam,
        dueDateText: record.completedDate,
        reviewState: record.reviewState,
        source: .scanSession,
        suggestedNextAction: record.scanStatus == .completed ? "Review completed scan" : "Match, resolve mismatch, or complete scan"
      )
    }
  }

  private func shipmentManifestWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(shipmentManifestsNeedingReview + blockedShipmentManifests + undispatchedShipmentManifests + highRiskShipmentManifests + shipmentManifestsMissingIncludedOrders + shipmentManifestsMissingHandoffLocation + shipmentManifestsWithIncompleteScans)).map { record in
      WorkbenchItem(
        id: "shipment-manifest-\(record.id.uuidString)",
        title: record.title,
        summary: "\(record.manifestType.rawValue) • \(record.carrierCourier) • \(record.destinationSummary)",
        linkedEntityType: .shipmentManifest,
        linkedEntityID: record.id.uuidString,
        prioritySeverity: record.dispatchStatus == .blockedNeedsReview || record.riskLevel == .critical ? "High" : record.riskLevel.rawValue,
        status: record.dispatchStatus.rawValue,
        assignee: record.assignedOwnerTeam,
        dueDateText: record.plannedDispatchDate,
        reviewState: record.reviewState,
        source: .shipmentManifest,
        suggestedNextAction: record.dispatchStatus == .handedOff ? "Review completed handoff" : "Prepare, dispatch, hand off, or unblock manifest"
      )
    }
  }

  private func dispatchChecklistWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(dispatchChecklistsNeedingReview + blockedDispatchChecklists + incompleteDispatchChecklists + highRiskDispatchChecklists + dispatchChecklistsMissingRequirements + dispatchChecklistsLinkedToBlockedManifests)).map { checklist in
      WorkbenchItem(
        id: "dispatch-checklist-\(checklist.id.uuidString)",
        title: checklist.title,
        summary: "\(checklist.checklistType.rawValue) • \(checklist.requiredChecksSummary)",
        linkedEntityType: .dispatchChecklist,
        linkedEntityID: checklist.id.uuidString,
        prioritySeverity: checklist.checklistStatus == .blockedNeedsReview || checklist.riskLevel == .critical ? "High" : checklist.riskLevel.rawValue,
        status: checklist.checklistStatus.rawValue,
        assignee: checklist.assignedOwnerTeam,
        dueDateText: checklist.plannedDispatchDate,
        reviewState: checklist.reviewState,
        source: .dispatchChecklist,
        suggestedNextAction: checklist.checklistStatus == .completed ? "Review completed readiness checklist" : "Clear missing requirements or complete readiness check"
      )
    }
  }

  private func accountWorkbenchItems() -> [WorkbenchItem] {
    accountRecordsNeedingReview.map { account in
      WorkbenchItem(
        id: "account-\(account.id.uuidString)",
        title: account.accountName,
        summary: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
        linkedEntityType: .account,
        linkedEntityID: account.id.uuidString,
        prioritySeverity: account.mfaStatus == .needsReview ? "High" : "Normal",
        status: account.isEnabled ? account.mfaStatus.rawValue : "Disabled",
        assignee: account.organisation,
        dueDateText: account.renewalReviewDate,
        reviewState: account.reviewState,
        source: .account,
        suggestedNextAction: "Review account placeholder"
      )
    }
  }

  private func vendorProfileWorkbenchItems() -> [WorkbenchItem] {
    Array(Set(vendorProfilesNeedingReview + highRiskEnabledVendorProfiles)).map { profile in
      WorkbenchItem(
        id: "vendor-profile-\(profile.id.uuidString)",
        title: profile.name,
        summary: "\(profile.profileType.rawValue) • \(profile.serviceLevelNotes)",
        linkedEntityType: .vendorProfile,
        linkedEntityID: profile.id.uuidString,
        prioritySeverity: profile.riskLevel.rawValue,
        status: profile.isEnabled ? "Enabled" : "Disabled",
        assignee: profile.primaryOrganisation,
        dueDateText: profile.lastReviewedDate,
        reviewState: profile.reviewState,
        source: .vendorProfile,
        suggestedNextAction: "Review vendor risk and contacts"
      )
    }
  }

  private func setupPlaceholderWorkbenchItems() -> [WorkbenchItem] {
    let mailboxItems = mailboxes
      .filter { !$0.status.localizedCaseInsensitiveContains("reviewed") }
      .map { mailbox in
        WorkbenchItem(
          id: "setup-mailbox-\(mailbox.id.uuidString)",
          title: "Review mailbox setup: \(mailbox.address)",
          summary: "\(mailbox.provider.rawValue) placeholder monitors \(mailbox.monitoredFolders). Local setup only; no mailbox connection is implied.",
          linkedEntityType: .integration,
          linkedEntityID: mailbox.id.uuidString,
          prioritySeverity: mailbox.status.localizedCaseInsensitiveContains("needs") ? "Medium" : "Normal",
          status: mailbox.status,
          assignee: "Setup",
          dueDateText: mailbox.lastChecked,
          reviewState: .needsReview,
          source: .setupPlaceholder,
          suggestedNextAction: "Open Settings and mark reviewed or remove placeholder"
        )
      }

    let shopifyItems = shopifyConnections
      .filter { !$0.status.localizedCaseInsensitiveContains("reviewed") }
      .map { connection in
        WorkbenchItem(
          id: "setup-shopify-\(connection.id.uuidString)",
          title: "Review Shopify planning: \(connection.storeName)",
          summary: "\(connection.storeDomain) is a planning placeholder. No Shopify OAuth, API, token, order, or product access is active.",
          linkedEntityType: .integration,
          linkedEntityID: connection.id.uuidString,
          prioritySeverity: connection.status.localizedCaseInsensitiveContains("needs") ? "Medium" : "Normal",
          status: connection.isEnabled ? connection.status : "Disabled planning",
          assignee: connection.mappedTeam,
          dueDateText: connection.lastSync,
          reviewState: .needsReview,
          source: .setupPlaceholder,
          suggestedNextAction: "Open Settings and mark reviewed or remove placeholder"
        )
      }

    let folderItems = watchedFolders
      .filter { !$0.status.localizedCaseInsensitiveContains("reviewed") }
      .map { folder in
        WorkbenchItem(
          id: "setup-folder-\(folder.id.uuidString)",
          title: "Review folder planning: \(folder.name)",
          summary: "\(folder.location) is a folder setup placeholder for \(folder.fileTypes). No file picker, OCR, or background scan is active.",
          linkedEntityType: .integration,
          linkedEntityID: folder.id.uuidString,
          prioritySeverity: folder.status.localizedCaseInsensitiveContains("needs") ? "Medium" : "Normal",
          status: folder.status,
          assignee: "Setup",
          dueDateText: folder.lastScan,
          reviewState: .needsReview,
          source: .setupPlaceholder,
          suggestedNextAction: "Open Settings and mark reviewed or remove placeholder"
        )
      }

    let sourceItems = connections
      .filter { !$0.status.localizedCaseInsensitiveContains("reviewed") }
      .map { connection in
        WorkbenchItem(
          id: "setup-source-\(connection.id.uuidString)",
          title: "Review login planning: \(connection.name)",
          summary: "\(connection.kind.rawValue) placeholder for \(connection.account). No credential, Keychain item, vault login, or supplier portal access is active.",
          linkedEntityType: .integration,
          linkedEntityID: connection.id.uuidString,
          prioritySeverity: connection.status.localizedCaseInsensitiveContains("needs") ? "Medium" : "Normal",
          status: connection.status,
          assignee: "Setup",
          dueDateText: connection.lastSync,
          reviewState: .needsReview,
          source: .setupPlaceholder,
          suggestedNextAction: "Open Settings and mark reviewed or remove placeholder"
        )
      }

    return mailboxItems + shopifyItems + folderItems + sourceItems
  }

  private func localDataHygieneWorkbenchItems() -> [WorkbenchItem] {
    let summary = localDataHygieneSummary
    guard summary.signalCount > 0 else { return [] }

    let flaggedMetrics = summary.metrics
      .filter { metric in
        guard let value = Int(metric.value) else { return false }
        return value > 0 && metric.tone != "success"
      }
      .prefix(4)
      .map { "\($0.title): \($0.value)" }

    let summaryText = ([summary.detail] + flaggedMetrics).joined(separator: " • ")
    let priority: String
    if summary.tone == "warning" {
      priority = "High"
    } else if summary.signalCount > 5 {
      priority = "Medium"
    } else {
      priority = "Normal"
    }

    return [
      WorkbenchItem(
        id: "local-data-hygiene",
        title: summary.verdict,
        summary: summaryText,
        linkedEntityType: .integration,
        linkedEntityID: "local-data-hygiene",
        prioritySeverity: priority,
        status: "\(summary.signalCount) hygiene signals",
        assignee: "Operations",
        dueDateText: "Before next test pass",
        reviewState: .needsReview,
        source: .setupPlaceholder,
        suggestedNextAction: summary.nextAction
      )
    ]
  }

  private func intakeValidationIssues() -> [ValidationIssue] {
    intakeEmails.flatMap { email -> [ValidationIssue] in
      var issues: [ValidationIssue] = []
      let missingFields = [
        ("merchant", email.detectedMerchant),
        ("order number", email.detectedOrderNumber),
        ("tracking number", email.detectedTrackingNumber),
        ("destination address", email.detectedDestinationAddress)
      ].filter { $0.1.isPlaceholderValidationValue }.map(\.0)
      let score = intakeConfidenceScore(for: email, missingCount: missingFields.count)

      if !missingFields.isEmpty || score < 70 {
        issues.append(validationIssue(
          id: "validation-intake-confidence-\(email.id.uuidString)",
          entityType: .intakeEmail,
          entityID: email.id.uuidString,
          linkedEntityType: .intakeEmail,
          title: email.subject,
          subtitle: "\(email.sender) confidence \(score)%",
          detail: missingFields.isEmpty ? "Detected fields are present but local confidence is below threshold." : "Forwarded intake email is missing \(missingFields.joined(separator: ", ")).",
          confidenceScore: score,
          severity: score < 45 ? .high : .warning,
          status: missingFields.isEmpty ? .lowConfidence : .incomplete,
          reviewState: email.reviewState.searchReviewState,
          suggestedActionText: "Correct detected intake fields before accepting."
        ))
      }

      if let linkedOrderID = email.linkedOrderID, let order = orders.first(where: { $0.id == linkedOrderID }) {
        var conflicts: [String] = []
        if !email.detectedOrderNumber.isPlaceholderValidationValue && !order.orderNumber.isPlaceholderValidationValue && !order.orderNumber.localizedCaseInsensitiveContains(email.detectedOrderNumber) && !email.detectedOrderNumber.localizedCaseInsensitiveContains(order.orderNumber) {
          conflicts.append("order number")
        }
        if !email.detectedTrackingNumber.isPlaceholderValidationValue && !order.trackingNumber.isPlaceholderValidationValue && order.trackingNumber.normalizedValidationKey != email.detectedTrackingNumber.normalizedValidationKey {
          conflicts.append("tracking number")
        }
        if !email.detectedDestinationAddress.isPlaceholderValidationValue && !order.destination.isPlaceholderValidationValue && !order.destination.localizedCaseInsensitiveContains(email.detectedDestinationAddress) && !email.detectedDestinationAddress.localizedCaseInsensitiveContains(order.destination) {
          conflicts.append("destination")
        }

        if !conflicts.isEmpty {
          issues.append(validationIssue(
            id: "validation-intake-conflict-\(email.id.uuidString)",
            entityType: .intakeEmail,
            entityID: email.id.uuidString,
            linkedEntityType: .intakeEmail,
            title: email.detectedOrderNumber,
            subtitle: "Conflicts with linked order \(order.orderNumber)",
            detail: "Detected intake fields conflict with linked order for \(conflicts.joined(separator: ", ")).",
            confidenceScore: 42,
            severity: .critical,
            status: .conflict,
            reviewState: email.reviewState.searchReviewState,
            suggestedActionText: "Review the intake link before creating or updating the order."
          ))
        }
      }

      if email.reviewState == .reviewed && email.linkedOrderID == nil {
        issues.append(validationIssue(
          id: "validation-intake-stale-\(email.id.uuidString)",
          entityType: .intakeEmail,
          entityID: email.id.uuidString,
          linkedEntityType: .intakeEmail,
          title: email.subject,
          subtitle: "Reviewed without linked order",
          detail: "Forwarded intake email is reviewed but has not been linked to an order.",
          confidenceScore: 66,
          severity: .warning,
          status: .staleReview,
          reviewState: email.reviewState.searchReviewState,
          suggestedActionText: "Link the email to an order or mark it ignored."
        ))
      }

      return issues
    }
  }

  private func trackingNumberValidationIssues() -> [ValidationIssue] {
    carrierTrackingEvents.compactMap { event in
      guard let order = orders.first(where: { $0.id == event.orderID }) else {
        return validationIssue(
          id: "validation-tracking-unlinked-\(event.id.uuidString)",
          entityType: .trackingNumber,
          entityID: event.id.uuidString,
          linkedEntityType: .trackingEvent,
          title: event.trackingNumber,
          subtitle: "Tracking event has no local order",
          detail: "Carrier tracking event references an order ID that is not present locally.",
          confidenceScore: 35,
          severity: .critical,
          status: .needsCorrection,
          reviewState: event.reviewState,
          suggestedActionText: "Create a task to repair the tracking link."
        )
      }

      guard order.trackingNumber.normalizedValidationKey != event.trackingNumber.normalizedValidationKey else { return nil }
      return validationIssue(
        id: "validation-tracking-conflict-\(event.id.uuidString)",
        entityType: .trackingNumber,
        entityID: event.id.uuidString,
        linkedEntityType: .trackingEvent,
        title: event.trackingNumber,
        subtitle: "Does not match order \(order.orderNumber)",
        detail: "Tracking event number \(event.trackingNumber) differs from order tracking number \(order.trackingNumber).",
        confidenceScore: 46,
        severity: .critical,
        status: .conflict,
        reviewState: event.reviewState,
        suggestedActionText: "Verify the carrier tracking number."
      )
    }
  }

  private func destinationValidationIssues() -> [ValidationIssue] {
    orders.compactMap { order in
      let normalizedDestination = order.destination.trimmingCharacters(in: .whitespacesAndNewlines)
      guard normalizedDestination.isPlaceholderValidationValue || normalizedDestination.count < 8 else { return nil }
      return validationIssue(
        id: "validation-destination-\(order.id.uuidString)",
        entityType: .destinationAddress,
        entityID: order.id.uuidString,
        linkedEntityType: .order,
        title: order.destination,
        subtitle: "\(order.orderNumber) destination needs validation",
        detail: "Destination address is missing, placeholder-like, or too short for reliable local tracking.",
        confidenceScore: 40,
        severity: .high,
        status: .needsCorrection,
        reviewState: order.reviewState,
        suggestedActionText: "Correct destination before shipment follow-up."
      )
    }
  }

  private func vendorProfileMatchValidationIssues() -> [ValidationIssue] {
    let orderIssues = orders.compactMap { order -> ValidationIssue? in
      let matches = suggestedVendorProfiles(for: order)
      guard matches.isEmpty || order.reviewState != .accepted else { return nil }
      return validationIssue(
        id: "validation-profile-order-\(order.id.uuidString)",
        entityType: .vendorProfileMatch,
        entityID: order.id.uuidString,
        linkedEntityType: .order,
        title: order.store,
        subtitle: matches.isEmpty ? "No vendor profile match" : "\(matches.count) profile candidates need review",
        detail: "Order vendor/profile match confidence is \(matches.isEmpty ? "low" : "not yet accepted").",
        confidenceScore: matches.isEmpty ? 48 : 70,
        severity: matches.isEmpty ? .warning : .info,
        status: matches.isEmpty ? .lowConfidence : .staleReview,
        reviewState: order.reviewState,
        suggestedActionText: "Review or create a vendor profile link."
      )
    }

    let intakeIssues = intakeEmails.compactMap { email -> ValidationIssue? in
      let matches = suggestedVendorProfiles(for: email)
      guard email.reviewState == .needsReview || matches.isEmpty else { return nil }
      return validationIssue(
        id: "validation-profile-intake-\(email.id.uuidString)",
        entityType: .vendorProfileMatch,
        entityID: email.id.uuidString,
        linkedEntityType: .intakeEmail,
        title: email.detectedMerchant,
        subtitle: matches.isEmpty ? "No vendor profile match" : "\(matches.count) profile candidates",
        detail: "Forwarded email merchant profile match needs user confirmation.",
        confidenceScore: matches.isEmpty ? 45 : 68,
        severity: matches.isEmpty ? .warning : .info,
        status: matches.isEmpty ? .lowConfidence : .staleReview,
        reviewState: email.reviewState.searchReviewState,
        suggestedActionText: "Confirm merchant profile before accepting intake."
      )
    }

    return orderIssues + intakeIssues
  }

  private func accountPlaceholderValidationIssues() -> [ValidationIssue] {
    accountCredentialRecords.compactMap { account in
      guard account.reviewState != .accepted || !account.isEnabled || account.credentialStorageStatus == .needsSetup || account.credentialStorageStatus == .accessPending || account.mfaStatus == .needsReview || account.mfaStatus == .notConfigured else { return nil }
      let status: ValidationStatus = account.credentialStorageStatus == .needsSetup || account.mfaStatus == .notConfigured ? .incomplete : account.reviewState == .needsReview ? .staleReview : .needsCorrection
      return validationIssue(
        id: "validation-account-\(account.id.uuidString)",
        entityType: .accountPlaceholder,
        entityID: account.id.uuidString,
        linkedEntityType: .account,
        title: account.accountName,
        subtitle: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
        detail: "Account placeholder has MFA \(account.mfaStatus.rawValue), enabled \(account.isEnabled ? "yes" : "no"), review \(account.reviewState.rawValue).",
        confidenceScore: account.mfaStatus == .needsReview || account.credentialStorageStatus == .needsSetup ? 50 : 72,
        severity: account.mfaStatus == .needsReview || account.credentialStorageStatus == .needsSetup ? .high : .warning,
        status: status,
        reviewState: account.reviewState,
        suggestedActionText: "Review account placeholder readiness."
      )
    }
  }

  private func contactSuggestionValidationIssues() -> [ValidationIssue] {
    let orderIssues = orders.compactMap { order -> ValidationIssue? in
      let contacts = suggestedContacts(for: order)
      guard contacts.isEmpty && order.reviewState != .accepted else { return nil }
      return validationIssue(
        id: "validation-contact-order-\(order.id.uuidString)",
        entityType: .contactSuggestion,
        entityID: order.id.uuidString,
        linkedEntityType: .order,
        title: order.store,
        subtitle: "No suggested contact for order",
        detail: "Order has no local enabled contact suggestion for its store or carrier.",
        confidenceScore: 52,
        severity: .warning,
        status: .lowConfidence,
        reviewState: order.reviewState,
        suggestedActionText: "Create or select a contact before follow-up."
      )
    }

    let intakeIssues = intakeEmails.compactMap { email -> ValidationIssue? in
      let contacts = suggestedContacts(for: email)
      guard contacts.isEmpty && email.reviewState == .needsReview else { return nil }
      return validationIssue(
        id: "validation-contact-intake-\(email.id.uuidString)",
        entityType: .contactSuggestion,
        entityID: email.id.uuidString,
        linkedEntityType: .intakeEmail,
        title: email.detectedMerchant,
        subtitle: "No suggested contact for intake",
        detail: "Forwarded email has no local enabled contact suggestion from merchant or sender.",
        confidenceScore: 50,
        severity: .warning,
        status: .lowConfidence,
        reviewState: email.reviewState.searchReviewState,
        suggestedActionText: "Create or select a contact before draft follow-up."
      )
    }

    return orderIssues + intakeIssues
  }

  private func intakeConfidenceScore(for email: ForwardedEmailIntake, missingCount: Int) -> Int {
    var score = 95 - missingCount * 14
    if email.reviewState == .needsReview { score -= 10 }
    if email.linkedOrderID == nil { score -= 8 }
    if email.rawBodyPreview.count < 40 { score -= 8 }
    if !email.sender.contains("@") { score -= 10 }
    return max(10, min(100, score))
  }

  private func validationIssue(
    id: String,
    entityType: ValidationEntityType,
    entityID: String,
    linkedEntityType: ReviewTaskLinkedEntityType?,
    title: String,
    subtitle: String,
    detail: String,
    confidenceScore: Int,
    severity: ValidationSeverity,
    status: ValidationStatus,
    reviewState: ReviewState?,
    suggestedActionText: String
  ) -> ValidationIssue {
    ValidationIssue(
      id: id,
      entityType: entityType,
      entityID: entityID,
      title: title,
      subtitle: subtitle,
      detail: detail,
      confidenceScore: confidenceScore,
      severity: severity,
      status: status,
      reviewState: reviewState,
      linkedEntityType: linkedEntityType,
      suggestedActionText: suggestedActionText
    )
  }

  private func orderTimelineActivities() -> [TimelineActivity] {
    orders.map { order in
      TimelineActivity(
        id: "timeline-order-\(order.id.uuidString)",
        timestampText: order.timeline.first?.time ?? order.eta,
        entityType: .order,
        entityID: order.id.uuidString,
        title: "\(order.store) \(order.orderNumber)",
        subtitle: "\(order.status.rawValue) to \(order.destination)",
        detail: order.latestStatus,
        risk: order.status == .exception ? .critical : order.reviewState == .needsReview ? .watch : .normal,
        reviewState: order.reviewState,
        source: .order,
        suggestedActionText: order.status == .exception ? "Create exception follow-up" : "Review order context"
      )
    }
  }

  private func intakeTimelineActivities() -> [TimelineActivity] {
    intakeEmails.map { email in
      TimelineActivity(
        id: "timeline-intake-\(email.id.uuidString)",
        timestampText: email.receivedDate,
        entityType: .intakeEmail,
        entityID: email.id.uuidString,
        title: email.subject,
        subtitle: "\(email.detectedMerchant) • \(email.detectedOrderNumber)",
        detail: email.rawBodyPreview,
        risk: email.reviewState == .needsReview ? .watch : .normal,
        reviewState: email.reviewState.searchReviewState,
        source: .mailbox,
        suggestedActionText: "Review forwarded email"
      )
    }
  }

  private func trackingTimelineActivities() -> [TimelineActivity] {
    carrierTrackingEvents.map { event in
      TimelineActivity(
        id: "timeline-tracking-\(event.id.uuidString)",
        timestampText: event.eventTime,
        entityType: .trackingEvent,
        entityID: event.id.uuidString,
        title: event.status,
        subtitle: "\(event.carrier) • \(event.trackingNumber)",
        detail: "\(event.location): \(event.detail)",
        risk: event.severity.timelineRisk,
        reviewState: event.reviewState,
        source: .carrier,
        suggestedActionText: event.severity == .critical ? "Escalate carrier event" : "Review tracking update"
      )
    }
  }

  private func evidenceTimelineActivities() -> [TimelineActivity] {
    evidenceAttachments.map { attachment in
      TimelineActivity(
        id: "timeline-evidence-\(attachment.id.uuidString)",
        timestampText: attachment.addedDate,
        entityType: .evidence,
        entityID: attachment.id.uuidString,
        title: attachment.fileName,
        subtitle: "\(attachment.fileType) • \(attachment.source.rawValue)",
        detail: attachment.summary,
        risk: attachment.reviewState == .needsReview ? .watch : .normal,
        reviewState: attachment.reviewState,
        source: .evidence,
        suggestedActionText: "Review evidence"
      )
    }
  }

  private func taskTimelineActivities() -> [TimelineActivity] {
    reviewTasks.map { task in
      TimelineActivity(
        id: "timeline-task-\(task.id.uuidString)",
        timestampText: task.createdDate,
        entityType: .reviewTask,
        entityID: task.id.uuidString,
        title: task.title,
        subtitle: "\(task.assignee) • due \(task.dueDate)",
        detail: task.isLocallyOverdue ? "Overdue: \(task.summary)" : task.summary,
        risk: task.isLocallyOverdue || task.priority == .urgent ? .critical : task.priority == .high ? .high : task.reviewState == .needsReview ? .watch : .normal,
        reviewState: task.reviewState,
        source: .task,
        suggestedActionText: task.status == .completed ? "Review completed task" : "Follow up task"
      )
    }
  }

  private func slaTimelineActivities() -> [TimelineActivity] {
    slaPolicies.map { policy in
      TimelineActivity(
        id: "timeline-sla-\(policy.id.uuidString)",
        timestampText: policy.lastEvaluatedDate,
        entityType: .slaPolicy,
        entityID: policy.id.uuidString,
        title: policy.name,
        subtitle: "\(policy.priority.rawValue) • \(policy.matchCount) matches",
        detail: "\(policy.responseTarget); \(policy.resolutionTarget)",
        risk: policy.priority == .urgent ? .critical : policy.priority == .high ? .high : policy.reviewState == .needsReview ? .watch : .normal,
        reviewState: policy.reviewState,
        source: .sla,
        suggestedActionText: "Review SLA context"
      )
    }
  }

  private func communicationTimelineActivities() -> [TimelineActivity] {
    let templates = communicationTemplates.map { template in
      TimelineActivity(
        id: "timeline-template-\(template.id.uuidString)",
        timestampText: template.lastUsedDate,
        entityType: .communicationTemplate,
        entityID: template.id.uuidString,
        title: template.name,
        subtitle: "\(template.channel.rawValue) • \(template.usageCount) uses",
        detail: template.subjectTemplate,
        risk: template.reviewState == .needsReview ? .watch : .normal,
        reviewState: template.reviewState,
        source: .communication,
        suggestedActionText: "Review template"
      )
    }
    let drafts = draftMessages.map { draft in
      TimelineActivity(
        id: "timeline-draft-\(draft.id.uuidString)",
        timestampText: draft.createdDate,
        entityType: .draftMessage,
        entityID: draft.id.uuidString,
        title: draft.subject,
        subtitle: "\(draft.recipient) • \(draft.status.rawValue)",
        detail: draft.body,
        risk: draft.status == .draft || draft.status == .reopened || draft.reviewState == .needsReview ? .watch : .normal,
        reviewState: draft.reviewState,
        source: .communication,
        suggestedActionText: "Review draft message"
      )
    }
    return templates + drafts
  }

  private func contactTimelineActivities() -> [TimelineActivity] {
    contactDirectoryEntries.map { contact in
      TimelineActivity(
        id: "timeline-contact-\(contact.id.uuidString)",
        timestampText: contact.lastContactedDate,
        entityType: .contact,
        entityID: contact.id.uuidString,
        title: contact.name,
        subtitle: "\(contact.organisation) • \(contact.role)",
        detail: contact.notes,
        risk: contact.reviewState == .needsReview ? .watch : .normal,
        reviewState: contact.reviewState,
        source: .directory,
        suggestedActionText: "Review contact"
      )
    }
  }

  private func accountTimelineActivities() -> [TimelineActivity] {
    accountCredentialRecords.map { account in
      TimelineActivity(
        id: "timeline-account-\(account.id.uuidString)",
        timestampText: account.lastCheckedDate,
        entityType: .account,
        entityID: account.id.uuidString,
        title: account.accountName,
        subtitle: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
        detail: "MFA: \(account.mfaStatus.rawValue). \(account.notes)",
        risk: account.mfaStatus == .needsReview || account.reviewState == .needsReview ? .high : account.credentialStorageStatus == .needsSetup || account.credentialStorageStatus == .accessPending ? .watch : .normal,
        reviewState: account.reviewState,
        source: .account,
        suggestedActionText: "Review account placeholder"
      )
    }
  }

  private func vendorProfileTimelineActivities() -> [TimelineActivity] {
    vendorProfiles.map { profile in
      TimelineActivity(
        id: "timeline-profile-\(profile.id.uuidString)",
        timestampText: profile.lastReviewedDate,
        entityType: .vendorProfile,
        entityID: profile.id.uuidString,
        title: profile.name,
        subtitle: "\(profile.profileType.rawValue) • \(profile.primaryOrganisation)",
        detail: profile.serviceLevelNotes,
        risk: profile.riskLevel.timelineRisk,
        reviewState: profile.reviewState,
        source: .vendorProfile,
        suggestedActionText: "Review vendor profile"
      )
    }
  }

  private func shipmentGroupTimelineActivities() -> [TimelineActivity] {
    shipmentGroups.map { group in
      TimelineActivity(
        id: "timeline-shipment-group-\(group.id.uuidString)",
        timestampText: group.lastReviewedDate,
        entityType: .shipmentGroup,
        entityID: group.id.uuidString,
        title: group.groupName,
        subtitle: "\(group.carrierSummary) • \(group.statusSummary)",
        detail: "\(group.destinationSummary). \(group.recipientCustomerSummary)",
        risk: group.riskLevel.timelineRisk,
        reviewState: group.reviewState,
        source: .shipmentGroup,
        suggestedActionText: "Review shipment group context"
      )
    }
  }

  private func dispatchTimelineActivities() -> [TimelineActivity] {
    let manifests = shipmentManifestRecords.map { manifest in
      let linkedOrderLabels = manifest.includedOrderIDs.compactMap(orderLabel(for:))
      let isInboxHandoff = manifest.isInboxHandoffSetup
      return TimelineActivity(
        id: "timeline-manifest-\(manifest.id.uuidString)",
        timestampText: manifest.lastReviewedDate == "Never" ? manifest.createdDate : manifest.lastReviewedDate,
        entityType: .shipmentManifest,
        entityID: manifest.id.uuidString,
        title: manifest.title,
        subtitle: [
          manifest.dispatchStatus.rawValue,
          manifest.carrierCourier,
          isInboxHandoff ? "Inbox dispatch handoff" : ""
        ].filter { !$0.isEmpty }.joined(separator: " • "),
        detail: [
          manifest.destinationSummary,
          "Orders: \(linkedOrderLabels.isEmpty ? "\(manifest.includedOrderIDs.count) linked" : linkedOrderLabels.joined(separator: ", ")).",
          "Planned \(manifest.plannedDispatchDate); actual \(manifest.actualDispatchDate).",
          isInboxHandoff ? "Local Inbox-created order dispatch setup. No carrier booking, label printing, scanner, or mailbox mutation is implied." : manifest.notes
        ].joined(separator: " "),
        risk: manifest.dispatchStatus == .blockedNeedsReview ? .high : manifest.dispatchStatus == .reopened ? .watch : manifest.riskLevel.timelineRisk,
        reviewState: manifest.reviewState,
        source: .order,
        suggestedActionText: dispatchTimelineSuggestedAction(for: manifest)
      )
    }

    let checklists = dispatchReadinessChecklists.map { checklist in
      let linkedOrderLabels = checklist.orderIDs.compactMap(orderLabel(for:))
      let isInboxHandoff = checklist.isInboxHandoffSetup
      return TimelineActivity(
        id: "timeline-dispatch-checklist-\(checklist.id.uuidString)",
        timestampText: checklist.lastReviewedDate == "Never" ? checklist.createdDate : checklist.lastReviewedDate,
        entityType: .dispatchChecklist,
        entityID: checklist.id.uuidString,
        title: checklist.title,
        subtitle: [
          checklist.checklistStatus.rawValue,
          checklist.checklistType.rawValue,
          isInboxHandoff ? "Inbox readiness handoff" : ""
        ].filter { !$0.isEmpty }.joined(separator: " • "),
        detail: [
          "Orders: \(linkedOrderLabels.isEmpty ? "\(checklist.orderIDs.count) linked" : linkedOrderLabels.joined(separator: ", ")).",
          checklist.requiredChecksSummary,
          checklist.missingRequirementsSummary,
          isInboxHandoff ? "Local Inbox-created order readiness record. Complete or block it from Dispatch or Order detail after local checks." : ""
        ].filter { !$0.isEmpty }.joined(separator: " "),
        risk: checklist.checklistStatus == .blockedNeedsReview ? .high : checklist.checklistStatus == .reopened ? .watch : checklist.riskLevel.timelineRisk,
        reviewState: checklist.reviewState,
        source: .order,
        suggestedActionText: dispatchTimelineSuggestedAction(for: checklist)
      )
    }

    return manifests + checklists
  }

  private func dispatchTimelineSuggestedAction(for manifest: ShipmentManifestRecord) -> String {
    if manifest.isInboxHandoffSetup && manifest.dispatchStatus == .reopened {
      return "Review reopened Inbox dispatch handoff"
    }
    switch manifest.dispatchStatus {
    case .draft:
      return manifest.isInboxHandoffSetup ? "Prepare local Inbox handoff manifest" : "Prepare manifest"
    case .prepared:
      return "Move to dispatch or handoff"
    case .dispatched:
      return "Confirm handoff"
    case .handedOff:
      return "Review completed handoff"
    case .blockedNeedsReview:
      return "Resolve blocked dispatch"
    case .reopened:
      return "Review reopened dispatch"
    }
  }

  private func dispatchTimelineSuggestedAction(for checklist: DispatchReadinessChecklist) -> String {
    if checklist.isInboxHandoffSetup && checklist.checklistStatus == .reopened {
      return "Review reopened Inbox readiness handoff"
    }
    switch checklist.checklistStatus {
    case .draft:
      return checklist.isInboxHandoffSetup ? "Confirm local Inbox readiness checks" : "Complete readiness checks"
    case .ready:
      return "Complete or dispatch"
    case .blockedNeedsReview:
      return "Resolve blocked readiness"
    case .completed:
      return "Review completed readiness"
    case .reopened:
      return "Review reopened readiness"
    }
  }

  private func importQueueTimelineActivities() -> [TimelineActivity] {
    importQueueItems.map { item in
      TimelineActivity(
        id: "timeline-import-\(item.id.uuidString)",
        timestampText: item.capturedDate,
        entityType: .importQueueItem,
        entityID: item.id.uuidString,
        title: item.sourceLabel,
        subtitle: "\(item.sourceType.rawValue) • \(item.importStatus.rawValue)",
        detail: item.rawSummary,
        risk: item.importStatus == .blocked ? .high : item.confidenceScore < 50 ? .high : item.reviewState == .needsReview ? .watch : .normal,
        reviewState: item.reviewState,
        source: .importQueue,
        suggestedActionText: "Review staged import"
      )
    }
  }

  private func acceptanceTimelineActivities() -> [TimelineActivity] {
    acceptanceRecords.map { record in
      TimelineActivity(
        id: "timeline-acceptance-\(record.id.uuidString)",
        timestampText: record.decidedDate,
        entityType: .acceptanceRecord,
        entityID: record.id.uuidString,
        title: record.sourceLabel,
        subtitle: "\(record.sourceType.rawValue) • \(record.decision.rawValue)",
        detail: record.summary,
        risk: record.decision == .blocked ? .high : record.decision == .reopened || record.reviewState == .needsReview ? .watch : .normal,
        reviewState: record.reviewState,
        source: .acceptance,
        suggestedActionText: "Review acceptance history"
      )
    }
  }

  private func automationTimelineActivities() -> [TimelineActivity] {
    automationRules.map { rule in
      TimelineActivity(
        id: "timeline-automation-\(rule.id.uuidString)",
        timestampText: rule.lastRunDate,
        entityType: .automationRule,
        entityID: rule.id.uuidString,
        title: rule.name,
        subtitle: "\(rule.triggerType.rawValue) • \(rule.runCount) runs",
        detail: "\(rule.conditionSummary) \(rule.actionSummary)",
        risk: rule.reviewState == .needsReview ? .watch : .normal,
        reviewState: rule.reviewState,
        source: .automation,
        suggestedActionText: "Review automation rule"
      )
    }
  }

  private func savedFilterTimelineActivities() -> [TimelineActivity] {
    savedFilters.map { filter in
      TimelineActivity(
        id: "timeline-filter-\(filter.id.uuidString)",
        timestampText: filter.createdDate,
        entityType: .savedFilter,
        entityID: filter.id.uuidString,
        title: filter.name,
        subtitle: filter.isPinned ? "Pinned filter" : "Saved filter",
        detail: filter.queryText.isEmpty ? "No query text" : filter.queryText,
        risk: filter.reviewStateFilter == .needsReview ? .watch : .normal,
        reviewState: filter.reviewStateFilter,
        source: .search,
        suggestedActionText: "Review saved filter"
      )
    }
  }

  private func auditTimelineActivities() -> [TimelineActivity] {
    auditEvents.map { event in
      TimelineActivity(
        id: "timeline-audit-\(event.id.uuidString)",
        timestampText: event.timestamp,
        entityType: .auditEvent,
        entityID: event.id.uuidString,
        title: event.summary,
        subtitle: "\(event.entityType.rawValue) • \(event.action.rawValue)",
        detail: event.entityLabel,
        risk: event.action == .removed || event.action == .ignored ? .watch : .normal,
        reviewState: nil,
        source: .audit,
        suggestedActionText: "Review audit entry"
      )
    }
  }

  var filteredOrders: [TrackedOrder] {
    orders.filter { order in
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let matchesStatus = selectedStatus == nil || order.status == selectedStatus
      let matchesQuery = query.isEmpty
        || order.orderNumber.lowercased().contains(query)
        || order.store.lowercased().contains(query)
        || order.customer.lowercased().contains(query)
        || order.recipientEmail.lowercased().contains(query)
        || order.destination.lowercased().contains(query)
        || order.carrier.lowercased().contains(query)
        || order.checkedMailbox.lowercased().contains(query)
        || order.trackingNumber.lowercased().contains(query)
        || order.latestStatus.lowercased().contains(query)
        || order.status.rawValue.lowercased().contains(query)
        || order.reviewState.rawValue.lowercased().contains(query)
        || order.source.rawValue.lowercased().contains(query)
      return matchesStatus && matchesQuery
    }
  }

  func searchResults(
    query: String,
    entityTypeFilter: SearchEntityType?,
    reviewStateFilter: ReviewState?
  ) -> [SearchResult] {
    let normalizedQuery = query.normalizedSearchText
    let allResults = orderSearchResults()
      + intakeEmailSearchResults()
      + trackingEventSearchResults()
      + evidenceSearchResults()
      + auditEventSearchResults()
      + automationRuleSearchResults()

    return allResults.filter { result in
      let matchesEntity = entityTypeFilter == nil || result.entityType == entityTypeFilter
      let matchesReview = reviewStateFilter == nil || result.reviewState == reviewStateFilter
      let matchesQuery = normalizedQuery.isEmpty || result.searchableText.normalizedSearchText.contains(normalizedQuery)
      return matchesEntity && matchesReview && matchesQuery
    }
  }

  func groupedSearchResults(
    query: String,
    entityTypeFilter: SearchEntityType?,
    reviewStateFilter: ReviewState?
  ) -> [SearchResultGroup] {
    let results = searchResults(
      query: query,
      entityTypeFilter: entityTypeFilter,
      reviewStateFilter: reviewStateFilter
    )

    return SearchEntityType.allCases.compactMap { entityType in
      let groupedResults = results.filter { $0.entityType == entityType }
      guard !groupedResults.isEmpty else { return nil }
      return SearchResultGroup(entityType: entityType, results: groupedResults)
    }
  }

  private func orderSearchResults() -> [SearchResult] {
    orders.map { order in
      let missingFields = partialInboxOrderMissingFields(for: order)
      let manifests = suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
      let checklists = suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
      let inboxContext = inboxSearchContext(for: order, missingFields: missingFields, manifestCount: manifests.count, checklistCount: checklists.count)
      let dispatchContext = dispatchSearchContext(for: order, manifests: manifests, checklists: checklists)
      return SearchResult(
        id: "order-\(order.id.uuidString)",
        entityType: .order,
        title: "\(order.store) \(order.orderNumber)",
        subtitle: [order.status.rawValue, order.destination, inboxContext.subtitle].filter { !$0.isEmpty }.joined(separator: " • "),
        detail: [
          "Tracking \(order.trackingNumber) via \(order.carrier).",
          order.latestStatus,
          inboxContext.detail,
          dispatchContext
        ].filter { !$0.isEmpty }.joined(separator: " "),
        severity: order.status == .exception ? .critical : nil,
        reviewState: order.reviewState,
        linkedEntityID: order.id.uuidString
      )
    }
  }

  private func intakeEmailSearchResults() -> [SearchResult] {
    intakeEmails.map { email in
      let linkedOrderLabel = email.linkedOrderID.flatMap(orderLabel(for:)) ?? "No linked order"
      let source = intakeSourceSummary(for: email)
      let readiness = intakeSearchReadiness(for: email)
      return SearchResult(
        id: "intake-\(email.id.uuidString)",
        entityType: .intakeEmail,
        title: email.subject,
        subtitle: "\(readiness.label) • \(source.label) • \(email.detectedMerchant) from \(email.sender)",
        detail: [
          "Order \(email.detectedOrderNumber), tracking \(email.detectedTrackingNumber), destination \(email.detectedDestinationAddress).",
          "Inbox source: \(source.label), \(source.status), captured \(source.captured) • \(linkedOrderLabel).",
          source.detail,
          readiness.detail,
          email.rawBodyPreview
        ].joined(separator: " "),
        severity: email.reviewState == .needsReview ? .watch : nil,
        reviewState: email.reviewState.searchReviewState,
        linkedEntityID: email.id.uuidString
      )
    }
  }

  func intakeSourceSummary(for email: ForwardedEmailIntake) -> (label: String, detail: String, tone: String, status: String, captured: String) {
    guard let ingestRecord = mailboxIngestRecords.first(where: { $0.intakeEmailID == email.id }) else {
      return (
        "Manual/local",
        "No mailbox ingest record is linked to this intake row. Treat it as local/manual until a source record is linked.",
        "neutral",
        email.reviewState.rawValue,
        email.receivedDate.isEmpty ? "Date unknown" : email.receivedDate
      )
    }

    let provider = mailboxProviderSummary(for: ingestRecord.sourceMailboxID, providerMessageID: ingestRecord.providerMessageID)
    return (
      provider.label,
      provider.detail,
      provider.tone,
      ingestRecord.status.rawValue,
      ingestRecord.capturedDate
    )
  }

  private func mailboxProviderSummary(for sourceMailboxID: UUID, providerMessageID: String) -> (label: String, detail: String, tone: String) {
    if let connection = spaceMailIMAPConnections.first(where: { $0.id == sourceMailboxID }) {
      return (
        "SpaceMail IMAP",
        "Captured from \(connection.displayName) using manual read-only IMAP refresh. Search terms: SpaceMail, IMAP, mailbox source trail.",
        "spacemail"
      )
    }

    if let connection = microsoft365MailboxConnections.first(where: { $0.id == sourceMailboxID }) {
      let isMock = providerMessageID.localizedCaseInsensitiveContains("mock")
      return (
        isMock ? "Mock Graph" : "Microsoft Graph",
        isMock
          ? "Captured from \(connection.displayName) using deterministic mock Graph refresh. Search terms: Microsoft 365, mock Graph, mailbox source trail."
          : "Captured from \(connection.displayName) using manual read-only Microsoft Graph refresh. Search terms: Microsoft 365, Graph, mailbox source trail.",
        isMock ? "mock" : "microsoft"
      )
    }

    if let connection = gmailMailboxConnections.first(where: { $0.id == sourceMailboxID }) {
      let isMock = providerMessageID.localizedCaseInsensitiveContains("mock")
      return (
        isMock ? "Mock Gmail" : "Gmail",
        isMock
          ? "Captured from \(connection.displayName) using deterministic mock Gmail refresh. Search terms: Gmail, Google Workspace, mock Gmail, mailbox source trail."
          : "Captured from \(connection.displayName) using manual read-only Gmail refresh. Search terms: Gmail, Google Workspace, mailbox source trail.",
        isMock ? "mock" : "gmail"
      )
    }

    if let mailbox = mailboxes.first(where: { $0.id == sourceMailboxID }) {
      return (
        "\(mailbox.provider.rawValue) mailbox",
        "Captured from tracked mailbox \(mailbox.address) through the provider-neutral intake path. Search terms: mailbox source trail.",
        "mailbox"
      )
    }

    if providerMessageID.localizedCaseInsensitiveContains("spacemail") {
      return ("SpaceMail intake", "Captured through SpaceMail intake; the source mailbox setup is no longer present locally.", "spacemail")
    }

    if providerMessageID.localizedCaseInsensitiveContains("mock") || providerMessageID.localizedCaseInsensitiveContains("simulated") {
      return ("Local test mail", "Captured through a local simulated mailbox import.", "mock")
    }

    return ("Mailbox intake", "Captured through the provider-neutral mailbox ingestion path.", "mailbox")
  }

  private func inboxSearchContext(for order: TrackedOrder, missingFields: [String], manifestCount: Int, checklistCount: Int) -> (subtitle: String, detail: String) {
    guard isInboxCreatedOrderForSearch(order) else { return ("", "") }
    let subtitle = missingFields.isEmpty ? "Inbox-created" : "Inbox-created, verify \(missingFields.joined(separator: ", "))"
    let detail: String
    if missingFields.isEmpty {
      detail = "Inbox handoff: order fields are usable for local dispatch setup."
    } else {
      detail = "Inbox handoff: verify \(missingFields.joined(separator: ", ")) before completing dispatch setup."
    }
    let dispatchLinks = manifestCount + checklistCount
    return (subtitle, "\(detail) Linked dispatch records: \(dispatchLinks). Search terms: Inbox-created order, Inbox handoff, dispatch setup.")
  }

  private func dispatchSearchContext(for order: TrackedOrder, manifests: [ShipmentManifestRecord], checklists: [DispatchReadinessChecklist]) -> String {
    guard !manifests.isEmpty || !checklists.isEmpty || order.latestStatus.localizedCaseInsensitiveContains("dispatch handoff") else { return "" }
    let reopenedManifests = manifests.filter { $0.dispatchStatus == .reopened }.count
    let reopenedChecklists = checklists.filter { $0.checklistStatus == .reopened }.count
    let blockedManifests = manifests.filter { $0.dispatchStatus == .blockedNeedsReview }.count
    let blockedChecklists = checklists.filter { $0.checklistStatus == .blockedNeedsReview }.count
    let completedManifests = manifests.filter { $0.dispatchStatus == .handedOff }.count
    let completedChecklists = checklists.filter { $0.checklistStatus == .completed }.count

    var phrases: [String] = []
    if reopenedManifests + reopenedChecklists > 0 {
      phrases.append("reopened dispatch handoff")
    }
    if blockedManifests + blockedChecklists > 0 {
      phrases.append("blocked dispatch handoff")
    }
    if completedManifests + completedChecklists == manifests.count + checklists.count, !manifests.isEmpty || !checklists.isEmpty {
      phrases.append("completed dispatch handoff")
    }
    if phrases.isEmpty {
      phrases.append("dispatch handoff setup")
    }

    return "Dispatch handoff context: \(phrases.joined(separator: ", ")); manifests \(manifests.count), readiness \(checklists.count)."
  }

  private func intakeSearchReadiness(for email: ForwardedEmailIntake) -> (label: String, detail: String) {
    let missingFields = [
      email.detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
      email.detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
      email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
      email.detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }

    if email.reviewState == .ignored {
      return ("Ignored intake", "This message is ignored locally. Reopen from Mailbox Monitor if it should become an order signal.")
    }
    if !missingFields.isEmpty {
      return ("Inbox needs correction", "Missing detected fields: \(missingFields.joined(separator: ", ")). Search terms: parser diagnostics, order number needs review, tracking needs review.")
    }
    if email.linkedOrderID != nil {
      return ("Linked Inbox intake", "This intake email has linked order context. Search terms: Inbox linked order, source trail, order handoff.")
    }
    return ("Ready Inbox intake", "Detected order and tracking fields look usable. Link to an order or create a local order from Inbox.")
  }

  private func isInboxCreatedOrderForSearch(_ order: TrackedOrder) -> Bool {
    order.source == .forwardedMailbox
      || order.checkedMailbox == "manual-import"
      || order.latestStatus.localizedCaseInsensitiveContains("import queue")
      || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
      || order.latestStatus.localizedCaseInsensitiveContains("forwarded email")
      || order.latestStatus.localizedCaseInsensitiveContains("inbox")
  }

  private func trackingEventSearchResults() -> [SearchResult] {
    carrierTrackingEvents.map { event in
      let orderLabel = orders.first { $0.id == event.orderID }?.orderNumber ?? "Unlinked order"
      return SearchResult(
        id: "tracking-\(event.id.uuidString)",
        entityType: .trackingEvent,
        title: "\(event.carrier) \(event.trackingNumber)",
        subtitle: "\(event.status) for \(orderLabel)",
        detail: "\(event.eventTime) at \(event.location). \(event.detail)",
        severity: event.severity,
        reviewState: event.reviewState,
        linkedEntityID: event.id.uuidString
      )
    }
  }

  private func evidenceSearchResults() -> [SearchResult] {
    evidenceAttachments.map { attachment in
      SearchResult(
        id: "evidence-\(attachment.id.uuidString)",
        entityType: .evidence,
        title: attachment.fileName,
        subtitle: "\(attachment.fileType) from \(attachment.source.rawValue)",
        detail: "\(attachment.summary) Linked to \(attachment.linkedEntityType.rawValue) \(attachment.linkedEntityID.uuidString). Path \(attachment.localFilePath)",
        severity: attachment.reviewState == .needsReview ? .watch : nil,
        reviewState: attachment.reviewState,
        linkedEntityID: attachment.id.uuidString
      )
    }
  }

  private func auditEventSearchResults() -> [SearchResult] {
    auditEvents.map { event in
      SearchResult(
        id: "audit-\(event.id.uuidString)",
        entityType: .auditEvent,
        title: "\(event.action.rawValue) \(event.entityLabel)",
        subtitle: "\(event.entityType.rawValue) by \(event.actor) at \(event.timestamp)",
        detail: [event.summary, event.beforeDetail, event.afterDetail].compactMap(\.self).joined(separator: " "),
        severity: nil,
        reviewState: nil,
        linkedEntityID: event.entityID
      )
    }
  }

  private func automationRuleSearchResults() -> [SearchResult] {
    automationRules.map { rule in
      SearchResult(
        id: "automation-\(rule.id.uuidString)",
        entityType: .automationRule,
        title: rule.name,
        subtitle: rule.isEnabled ? "Enabled \(rule.triggerType.rawValue)" : "Disabled \(rule.triggerType.rawValue)",
        detail: "\(rule.conditionSummary) \(rule.actionSummary) Last run \(rule.lastRunDate), \(rule.runCount) runs.",
        severity: rule.reviewState == .needsReview ? .watch : nil,
        reviewState: rule.reviewState,
        linkedEntityID: rule.id.uuidString
      )
    }
  }

  func syncSources() {
    let actions = workflowTemplateEngine.actions(for: .manualSync).map(\.rawValue).joined(separator: ", ")
    appendSystemContact("Local test import requested", evidence: "Local workflow template actions recorded: \(actions). Simulated mailbox messages were imported through local intake only.")
    importSimulatedFetchedMailboxMessages()
  }

  func importSimulatedFetchedMailboxMessages() {
    let mailbox = mailboxes.first ?? TrackedMailbox(
      address: "tracking-intake@parcelops.example",
      provider: .microsoft365,
      monitoredFolders: "Inbox",
      status: "Local test mailbox",
      lastChecked: "Never",
      routingRule: "Simulated forwarded-order intake"
    )
    if mailboxes.isEmpty {
      mailboxes.append(mailbox)
      persistIntegrations()
    }

    let messages = simulatedFetchedMailboxMessages(for: mailbox)
    importFetchedMailboxMessages(messages)
  }

  @discardableResult
  func importClearOrderIntakeTestMessage() -> UUID? {
    let mailbox = localSampleTrackedMailbox()
    upsertTrackedMailbox(mailbox)

    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let suffix = String(timestamp % 1_000_000)
    let orderNumber = "TEST-\(suffix)"
    let trackingNumber = "ABC\(suffix)"
    let message = FetchedMailboxMessage(
      providerMessageID: "local-clear-order-\(mailbox.id.uuidString)-\(timestamp)",
      sender: "orders@example-shop.test",
      subject: "Order \(orderNumber) shipped tracking \(trackingNumber)",
      receivedDate: Self.auditTimestamp(),
      plainTextBodyPreview: "Order \(orderNumber) shipped tracking \(trackingNumber) to 24 Sample Street, Melbourne VIC. This is a local-only ParcelOps intake test message.",
      sourceMailboxID: mailbox.id
    )

    let result = importFetchedMailboxMessages([message])
    let intakeEmailID = mailboxIngestRecords.first {
      $0.providerMessageID == message.providerMessageID && $0.sourceMailboxID == mailbox.id
    }?.intakeEmailID
    logAudit(
      action: .evaluated,
      entityType: .trackedMailbox,
      entityID: mailbox.id.uuidString,
      entityLabel: mailbox.address,
      summary: "Local clear order intake sample imported.",
      afterDetail: "Order: \(orderNumber)\nTracking: \(trackingNumber)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nNo mailbox was contacted. The sample used the provider-neutral fetched mailbox ingestion path so Inbox, parser diagnostics, duplicate metadata, JSON persistence, and Audit behave like a real captured message."
    )
    return intakeEmailID
  }

  func seedLocalInboxOrderDemoWorkflow() {
    guard let intakeEmailID = importClearOrderIntakeTestMessage(),
          let intakeEmail = intakeEmails.first(where: { $0.id == intakeEmailID }) else {
      logAudit(
        action: .evaluated,
        entityType: .intakeEmail,
        entityID: "local-demo-workflow",
        entityLabel: "Local demo workflow",
        summary: "Local demo workflow could not start.",
        afterDetail: "ParcelOps could not find the locally imported sample intake email. No external service, mailbox fetch, or mailbox mutation occurred."
      )
      return
    }

    createOrder(from: intakeEmail)

    guard let refreshedEmail = intakeEmails.first(where: { $0.id == intakeEmailID }),
          let orderID = refreshedEmail.linkedOrderID,
          let order = orders.first(where: { $0.id == orderID }) else {
      logAudit(
        action: .evaluated,
        entityType: .intakeEmail,
        entityID: intakeEmailID.uuidString,
        entityLabel: intakeEmail.auditLabel,
        summary: "Local demo workflow stopped after intake import.",
        afterDetail: "The sample intake email was imported, but no linked order was found after local order creation. Check Inbox and Orders. No external service, mailbox fetch, or mailbox mutation occurred."
      )
      return
    }

    createDispatchSetup(for: order)
    createReviewTask(from: order)

    logAudit(
      action: .evaluated,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: "Local Inbox-to-Dispatch demo workflow seeded.",
      afterDetail: "Created a clear local intake email, created a linked order, added dispatch setup where missing, and added an order follow-up task using existing local workflow methods.\nOrder: \(order.orderNumber)\nTracking: \(order.trackingNumber)\nNo mailbox was contacted or mutated. No external service, carrier API, Shopify API, scanner, notification, or outbound email action occurred."
    )
  }

  func importSimulatedFetchedMailboxMessages(for connection: Microsoft365MailboxConnection) {
    Task {
      await refreshMicrosoft365MailboxConnectionThroughMockGraph(connection)
    }
  }

  func importRealMicrosoftGraphMailboxMessages(for connection: Microsoft365MailboxConnection) {
    Task {
      await refreshMicrosoft365MailboxConnectionThroughRealGraph(connection)
    }
  }

  private func refreshMicrosoft365MailboxConnectionThroughMockGraph(_ connection: Microsoft365MailboxConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)

    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Microsoft Graph mailbox fetch started.",
      afterDetail: "Mailbox: \(connection.mailboxAddress)\nFolders: \(connection.monitoredFolderNames)\nNo OAuth, token, password, network call, or real mailbox access is used."
    )

    let fetchResult = await microsoftGraphMailboxClient.fetchMessages(for: connection, accessToken: nil)
    let fetchedMessages = mapGraphMessages(fetchResult.messages, sourceMailboxID: mailbox.id)
    let result = importFetchedMailboxMessages(fetchedMessages)
    let refreshStatus = microsoftGraphRefreshStatus(fetchResult: fetchResult, ingestResult: result)

    updateMicrosoft365MailboxConnection(connection) { draft in
      draft.lastManualRefreshDate = Self.auditTimestamp()
      draft.connectionStatus = "Mock Graph: \(refreshStatus.rawValue)"
    }

    if fetchResult.status == .noMessages {
      logAudit(
        action: .evaluated,
        entityType: .microsoft365MailboxConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Mock Microsoft Graph fetch returned no messages.",
        afterDetail: fetchResult.detail
      )
    }

    if fetchResult.status == .notConnected || fetchResult.status == .simulatedAuthPlaceholder {
      logAudit(
        action: .evaluated,
        entityType: .microsoft365MailboxConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Mock Microsoft Graph fetch stopped at local connection placeholder.",
        afterDetail: fetchResult.detail
      )
    }

    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Microsoft Graph mailbox fetch completed locally.",
      afterDetail: "Status: Mock Graph: \(refreshStatus.rawValue)\nMock result: \(fetchResult.status.rawValue)\nMailbox: \(connection.mailboxAddress)\nFolders: \(connection.monitoredFolderNames)\nFetched messages: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nDuplicate skips mean ParcelOps already captured that provider message ID for this mailbox.\n\(fetchResult.detail)\nNo OAuth, token, Microsoft Graph network call, or real mailbox connection was used."
    )
  }

  private func refreshMicrosoft365MailboxConnectionThroughRealGraph(_ connection: Microsoft365MailboxConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)

    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Microsoft Graph mailbox fetch started.",
      afterDetail: "Mailbox: \(connection.mailboxAddress)\nFolders: \(connection.monitoredFolderNames)\nRequested scopes: User.Read, Mail.Read\nLimit: 10 messages\nMode: manual refresh only\nNo token values, passwords, client secrets, or raw callback URLs will be logged. Mailbox messages will not be deleted, moved, marked read, sent, or modified."
    )

    let tokenResult = await microsoft365GraphTokenProvider.acquireMailReadToken(for: connection)
    await MainActor.run {
      logAudit(
        action: .evaluated,
        entityType: .microsoft365MailboxConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: tokenResult.status == .success ? "Real Microsoft Graph token acquired in memory." : "Real Microsoft Graph token request did not complete.",
        afterDetail: "Token status: \(tokenResult.status.rawValue)\nSigned-in account: \(tokenResult.signedInAccount)\n\(tokenResult.detailText)\n\(tokenResult.tokenDiagnosticsDetail)\nToken values are not stored in ParcelOps JSON or audit logs."
      )
    }

    guard tokenResult.status == .success, let accessToken = tokenResult.accessToken else {
      await MainActor.run {
        updateMicrosoft365MailboxConnection(connection) { draft in
          draft.lastManualRefreshDate = Self.auditTimestamp()
          draft.connectionStatus = tokenResult.status == .consentRequired ? "Real Graph: \(MicrosoftGraphMailboxFetchStatus.consentRequired.rawValue)" : "Real Graph: \(MicrosoftGraphMailboxFetchStatus.authRequired.rawValue)"
        }
      }
      return
    }

    let fetchResult = await realMicrosoftGraphMailboxClient.fetchMessages(for: connection, accessToken: accessToken)
    let fetchedMessages = mapGraphMessages(fetchResult.messages, sourceMailboxID: mailbox.id)
    await MainActor.run {
      let result = importFetchedMailboxMessages(fetchedMessages)
      let refreshStatus = microsoftGraphRefreshStatus(fetchResult: fetchResult, ingestResult: result)

      updateMicrosoft365MailboxConnection(connection) { draft in
        draft.lastManualRefreshDate = Self.auditTimestamp()
        draft.connectionStatus = "Real Graph: \(refreshStatus.rawValue)"
      }

      if fetchResult.status == .noMessages {
        logAudit(
          action: .evaluated,
          entityType: .microsoft365MailboxConnection,
          entityID: connection.id.uuidString,
          entityLabel: connection.displayName,
          summary: "Real Microsoft Graph fetch returned no messages.",
          afterDetail: "\(fetchResult.detail)\nNo mailbox items were modified."
        )
      }

      if fetchResult.status != .success && fetchResult.status != .noMessages {
        logAudit(
          action: .evaluated,
          entityType: .microsoft365MailboxConnection,
          entityID: connection.id.uuidString,
          entityLabel: connection.displayName,
          summary: "Real Microsoft Graph fetch stopped before import.",
          afterDetail: "Status: Real Graph: \(fetchResult.status.rawValue)\n\(realGraphDiagnosticHint(for: fetchResult.status))\n\(fetchResult.detail)\n\(tokenResult.tokenDiagnosticsDetail)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nDuplicate skips mean ParcelOps already captured that Graph message ID for this mailbox.\nNo mailbox items were deleted, moved, marked read, sent, or modified."
        )
      }

      logAudit(
        action: .evaluated,
        entityType: .microsoft365MailboxConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Real Microsoft Graph mailbox fetch completed.",
        afterDetail: "Status: Real Graph: \(refreshStatus.rawValue)\nGraph result: \(fetchResult.status.rawValue)\nMailbox: \(connection.mailboxAddress)\nFolders: \(connection.monitoredFolderNames)\nFetched messages: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nDuplicate skips mean ParcelOps already captured that Graph message ID for this mailbox.\n\(realGraphDiagnosticHint(for: fetchResult.status))\n\(fetchResult.detail)\n\(tokenResult.tokenDiagnosticsDetail)\nNo token value was stored or logged. No mailbox items were deleted, moved, marked read, sent, or modified."
      )
    }
  }

  @discardableResult
  func importFetchedMailboxMessages(_ messages: [FetchedMailboxMessage]) -> (imported: Int, duplicates: Int) {
    var importedCount = 0
    var duplicateCount = 0

    for message in messages {
      if let existingIngestRecord = preferredDuplicateIngestRecord(for: message) {
        duplicateCount += 1
        let refreshedIntakeEmailID = refreshDuplicateIntakeEmail(from: message, existingIngestRecord: existingIngestRecord)
        let duplicateRecord = MailboxIngestRecord(
          providerMessageID: message.providerMessageID,
          sourceMailboxID: message.sourceMailboxID,
          intakeEmailID: refreshedIntakeEmailID ?? existingIngestRecord.intakeEmailID,
          capturedDate: Self.auditTimestamp(),
          status: .duplicateSkipped,
        summary: "Skipped duplicate fetched mailbox message: \(message.subject)"
      )
      mailboxIngestRecords.insert(duplicateRecord, at: 0)
      logAudit(action: .ignored, entityType: .intakeEmail, entityID: message.providerMessageID, entityLabel: message.subject, summary: "Duplicate fetched mailbox message skipped locally.", afterDetail: mailboxIngestAuditDetail(for: duplicateRecord))
        continue
      }

      let intakeEmail = makeForwardedEmailIntake(from: message)
      intakeEmails.insert(intakeEmail, at: 0)
      let ingestRecord = MailboxIngestRecord(
        providerMessageID: message.providerMessageID,
        sourceMailboxID: message.sourceMailboxID,
        intakeEmailID: intakeEmail.id,
        capturedDate: Self.auditTimestamp(),
        status: .imported,
      summary: "Imported fetched mailbox message: \(message.subject)"
      )
      mailboxIngestRecords.insert(ingestRecord, at: 0)
      importedCount += 1
      logAudit(action: .created, entityType: .intakeEmail, entityID: intakeEmail.id.uuidString, entityLabel: intakeEmail.auditLabel, summary: "Fetched mailbox message imported into forwarded email intake.", afterDetail: "\(intakeEmail.auditDetail)\nProvider message ID: \(message.providerMessageID)")
    }

    if importedCount > 0 {
      persistIntakeEmails()
    }
    if importedCount > 0 || duplicateCount > 0 {
      persistMailboxIngestRecords()
    }
    return (importedCount, duplicateCount)
  }

  private func preferredDuplicateIngestRecord(for message: FetchedMailboxMessage) -> MailboxIngestRecord? {
    let matches = mailboxIngestRecords.filter {
      $0.providerMessageID == message.providerMessageID && $0.sourceMailboxID == message.sourceMailboxID
    }
    return matches.first(where: { $0.intakeEmailID != nil && $0.status == .imported })
      ?? matches.first(where: { $0.intakeEmailID != nil })
      ?? matches.first
  }

  @discardableResult
  private func refreshDuplicateIntakeEmail(from message: FetchedMailboxMessage, existingIngestRecord: MailboxIngestRecord) -> UUID? {
    let linkedIndex = existingIngestRecord.intakeEmailID.flatMap { intakeEmailID in
      intakeEmails.firstIndex { $0.id == intakeEmailID }
    }
    let fallbackIndex = linkedIndex ?? staleDuplicateIntakeIndex(for: message)
    guard let index = fallbackIndex else {
      logAudit(
        action: .evaluated,
        entityType: .intakeEmail,
        entityID: message.providerMessageID,
        entityLabel: message.subject,
        summary: "Duplicate fetched mailbox message had no linked intake email to refresh.",
        afterDetail: "Provider message ID: \(message.providerMessageID)\nNo intake email was created or duplicated. Duplicate tracking metadata was preserved."
      )
      return nil
    }
    let usedFallback = linkedIndex == nil

    let before = intakeEmails[index]
    var refreshed = makeForwardedEmailIntake(from: message)
    refreshed.id = before.id
    refreshed.linkedOrderID = before.linkedOrderID ?? matchedOrderID(for: refreshed.detectedOrderNumber)
    if before.reviewState == .ignored {
      refreshed.reviewState = .ignored
    } else if refreshed.linkedOrderID != nil {
      refreshed.reviewState = .reviewed
    } else {
      refreshed.reviewState = .needsReview
    }

    let changes = intakeReprocessChanges(before: before, after: refreshed)
    if changes.isEmpty {
      logAudit(
        action: .evaluated,
        entityType: .intakeEmail,
        entityID: before.id.uuidString,
        entityLabel: before.auditLabel,
        summary: "Duplicate fetched mailbox message refreshed with no intake field changes.",
        afterDetail: "Provider message ID: \(message.providerMessageID)\nNo detected fields changed. No intake email was duplicated. Duplicate tracking metadata was preserved.\(usedFallback ? "\nRefresh used the older messy intake fallback because the existing ingest record did not have a usable intake link." : "")"
      )
      return before.id
    }

    intakeEmails[index] = refreshed
    persistIntakeEmails()
    logAudit(
      action: .edited,
      entityType: .intakeEmail,
      entityID: refreshed.id.uuidString,
      entityLabel: refreshed.auditLabel,
      summary: "Duplicate fetched mailbox message refreshed existing intake email.",
      beforeDetail: before.auditDetail,
      afterDetail: "\(refreshed.auditDetail)\nChanged fields: \(changes.joined(separator: ", ")).\nProvider message ID: \(message.providerMessageID)\nExisting intake email was updated from the newly parsed fetched message. No duplicate intake email was created and duplicate tracking metadata was preserved.\(usedFallback ? "\nRefresh used the older messy intake fallback because the existing ingest record did not have a usable intake link." : "")"
    )
    return refreshed.id
  }

  private func staleDuplicateIntakeIndex(for message: FetchedMailboxMessage) -> Int? {
    if let uid = imapUID(from: message.providerMessageID),
       let uidMatch = intakeEmails.firstIndex(where: { isStaleFetchedIntake($0) && $0.rawBodyPreview.contains("UID \(uid)") }) {
      return uidMatch
    }

    return intakeEmails.firstIndex { isStaleFetchedIntake($0) }
  }

  private func imapUID(from providerMessageID: String) -> String? {
    guard let range = providerMessageID.range(of: "-uid-", options: [.backwards]) else { return nil }
    let suffix = providerMessageID[range.upperBound...]
    let uid = suffix.prefix { $0.isNumber }
    return uid.isEmpty ? nil : String(uid)
  }

  private func isStaleFetchedIntake(_ email: ForwardedEmailIntake) -> Bool {
    let body = email.rawBodyPreview.lowercased()
    let hasIMAPWrapper = body.contains(" fetch ") || body.contains("body[]") || body.contains("return-path:") || body.contains("dovecot")
    let hasPlaceholderSummary = email.subject == "No subject" || email.sender == "Unknown Sender" || email.detectedMerchant == "Unknown Sender"
    return hasIMAPWrapper && hasPlaceholderSummary
  }

  private func simulatedFetchedMailboxMessages(for mailbox: TrackedMailbox) -> [FetchedMailboxMessage] {
    [
      FetchedMailboxMessage(
        providerMessageID: "simulated-\(mailbox.id.uuidString)-1001",
        sender: "orders@northline.example",
        subject: "Fwd: Northline Outfitters order NO-44918 shipped",
        receivedDate: "Today 9:15 AM",
        plainTextBodyPreview: "Forwarded order confirmation from Northline Outfitters. Order NO-44918 has shipped with tracking NL4491800123 to 12 Market Street, Melbourne VIC. Original recipient: \(mailbox.address).",
        sourceMailboxID: mailbox.id
      ),
      FetchedMailboxMessage(
        providerMessageID: "simulated-\(mailbox.id.uuidString)-1002",
        sender: "dispatch@urbancrate.example",
        subject: "Fwd: Urban Crate order UC-7812 tracking update",
        receivedDate: "Today 10:05 AM",
        plainTextBodyPreview: "Urban Crate order UC-7812 is now in transit. Tracking number UC7812AUS is headed to Level 2, 41 Collins Street, Melbourne VIC. Please review destination details.",
        sourceMailboxID: mailbox.id
      )
    ]
  }

  private func localSampleTrackedMailbox() -> TrackedMailbox {
    if let mailbox = mailboxes.first(where: { $0.address == "local-sample-intake@parcelops.example" }) {
      return mailbox
    }
    return TrackedMailbox(
      address: "local-sample-intake@parcelops.example",
      provider: .imap,
      monitoredFolders: "Local samples",
      status: "Local-only test mailbox",
      lastChecked: Self.auditTimestamp(),
      routingRule: "Clear order/tracking intake sample"
    )
  }

  private func filteredSpaceMailMessages(
    _ messages: [FetchedMailboxMessage],
    for connection: SpaceMailIMAPConnection
  ) -> MailboxRelevanceFilterResult {
    guard connection.mailboxMode == .mixedFiltered else {
      return MailboxRelevanceFilterResult(
        importMessages: messages,
        uncertainMessages: [],
        filteredMessages: [],
        reasonBreakdown: [],
        filteredExamples: [],
        uncertainExamples: [],
        filteredNonOrderCount: 0,
        uncertainCount: 0,
        detail: "Mailbox mode is dedicated order mailbox, so all fetched messages were passed to intake duplicate/import handling."
      )
    }

    var importMessages: [FetchedMailboxMessage] = []
    var uncertainMessages: [SpaceMailUncertainMessage] = []
    var filteredMessages: [SpaceMailFilteredMessage] = []
    var importedSubjects: [String] = []
    var filteredSubjects: [String] = []
    var uncertainSubjects: [String] = []
    var reasonCounts: [String: Int] = [:]

    for message in messages {
      let relevance = classifyMailboxMessageRelevance(message, for: connection)
      let decisionLabel: String
      switch relevance.decision {
      case .likelyOrder:
        decisionLabel = "Imported"
        importMessages.append(message)
        importedSubjects.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
      case .uncertain:
        decisionLabel = "Uncertain"
        uncertainSubjects.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
        uncertainMessages.append(
          SpaceMailUncertainMessage(
            providerMessageID: message.providerMessageID,
            sourceMailboxID: message.sourceMailboxID,
            sender: safeAuditPreview(message.sender, limit: 120),
            subject: safeAuditPreview(message.subject, limit: 160),
            receivedDate: message.receivedDate,
            bodyPreview: safeAuditPreview(message.plainTextBodyPreview, limit: 280),
            reason: relevance.reason,
            capturedDate: Self.auditTimestamp()
          )
        )
      case .nonOrder:
        decisionLabel = "Filtered"
        filteredSubjects.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
        filteredMessages.append(
          SpaceMailFilteredMessage(
            providerMessageID: message.providerMessageID,
            sourceMailboxID: message.sourceMailboxID,
            sender: safeAuditPreview(message.sender, limit: 120),
            subject: safeAuditPreview(message.subject, limit: 160),
            receivedDate: message.receivedDate,
            bodyPreview: safeAuditPreview(message.plainTextBodyPreview, limit: 220),
            reason: relevance.reason,
            capturedDate: Self.auditTimestamp()
          )
        )
      }
      reasonCounts["\(decisionLabel)|\(relevance.reason)", default: 0] += 1
    }

    var detailLines = [
      "Mixed mailbox filtering is enabled. Only likely order/order update messages were passed into primary Inbox intake.",
      "Filtered non-order messages are counted locally and not imported into ForwardedEmailIntake.",
      "Uncertain messages are counted for review in Audit, but are not added to primary Inbox triage in this first mixed-mailbox pass."
    ]
    if !importedSubjects.isEmpty {
      detailLines.append("Imported examples: \(importedSubjects.prefix(3).joined(separator: "; ")).")
    }
    if !filteredSubjects.isEmpty {
      detailLines.append("Filtered examples: \(filteredSubjects.prefix(3).joined(separator: "; ")).")
    }
    if !uncertainSubjects.isEmpty {
      detailLines.append("Uncertain examples: \(uncertainSubjects.prefix(3).joined(separator: "; ")).")
    }
    let reasonBreakdown = spaceMailReasonBreakdown(from: reasonCounts)
    if !reasonBreakdown.isEmpty {
      detailLines.append("Classifier reasons: \(reasonBreakdown.prefix(6).map { "\($0.decision) \($0.count)x \($0.reason)" }.joined(separator: "; ")).")
    }

    return MailboxRelevanceFilterResult(
      importMessages: importMessages,
      uncertainMessages: uncertainMessages,
      filteredMessages: filteredMessages,
      reasonBreakdown: reasonBreakdown,
      filteredExamples: Array(filteredSubjects.prefix(5)),
      uncertainExamples: Array(uncertainSubjects.prefix(5)),
      filteredNonOrderCount: filteredSubjects.count,
      uncertainCount: uncertainSubjects.count,
      detail: detailLines.joined(separator: "\n")
    )
  }

  private func filteredGmailMessages(
    _ messages: [FetchedMailboxMessage],
    for connection: GmailMailboxConnection
  ) -> (importMessages: [FetchedMailboxMessage], uncertainMessages: [GmailReviewMessage], filteredMessages: [GmailReviewMessage], filteredCount: Int, uncertainCount: Int, filteredExamples: [String], uncertainExamples: [String], detail: String) {
    guard connection.mailboxMode == .mixedFiltered else {
      return (
        messages,
        [],
        [],
        0,
        0,
        [],
        [],
        "Gmail mailbox mode is dedicated order mailbox, so all fetched messages were passed to intake duplicate/import handling."
      )
    }

    var importMessages: [FetchedMailboxMessage] = []
    var uncertainMessages: [GmailReviewMessage] = []
    var filteredMessages: [GmailReviewMessage] = []
    var filteredExamples: [String] = []
    var uncertainExamples: [String] = []
    var importedExamples: [String] = []

    for message in messages {
      let relevance = classifyGmailMessageRelevance(message)
      if relevance.decision == "Imported" {
        importMessages.append(message)
        importedExamples.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
      } else if relevance.decision == "Uncertain" {
        uncertainExamples.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
        uncertainMessages.append(
          GmailReviewMessage(
            providerMessageID: message.providerMessageID,
            sourceMailboxID: message.sourceMailboxID,
            sender: safeAuditPreview(message.sender, limit: 120),
            subject: safeAuditPreview(message.subject, limit: 160),
            receivedDate: message.receivedDate,
            bodyPreview: safeAuditPreview(message.plainTextBodyPreview, limit: 280),
            reason: relevance.reason,
            capturedDate: Self.auditTimestamp()
          )
        )
      } else {
        filteredExamples.append("\(safeAuditPreview(message.subject, limit: 80)) (\(relevance.reason))")
        filteredMessages.append(
          GmailReviewMessage(
            providerMessageID: message.providerMessageID,
            sourceMailboxID: message.sourceMailboxID,
            sender: safeAuditPreview(message.sender, limit: 120),
            subject: safeAuditPreview(message.subject, limit: 160),
            receivedDate: message.receivedDate,
            bodyPreview: safeAuditPreview(message.plainTextBodyPreview, limit: 280),
            reason: relevance.reason,
            capturedDate: Self.auditTimestamp()
          )
        )
      }
    }

    var detailLines = [
      "Mixed Gmail filtering is enabled. Only likely order/order update messages were passed into primary Inbox intake.",
      "Filtered Gmail messages are counted locally and not imported into ForwardedEmailIntake."
    ]
    if !importedExamples.isEmpty {
      detailLines.append("Imported examples: \(importedExamples.prefix(3).joined(separator: "; ")).")
    }
    if !filteredExamples.isEmpty {
      detailLines.append("Filtered examples: \(filteredExamples.prefix(3).joined(separator: "; ")).")
    }
    if !uncertainExamples.isEmpty {
      detailLines.append("Uncertain examples: \(uncertainExamples.prefix(3).joined(separator: "; ")).")
    }

    return (
      importMessages,
      uncertainMessages,
      filteredMessages,
      filteredExamples.count,
      uncertainExamples.count,
      Array(filteredExamples.prefix(5)),
      Array(uncertainExamples.prefix(5)),
      detailLines.joined(separator: "\n")
    )
  }

  private func classifyGmailMessageRelevance(_ message: FetchedMailboxMessage) -> (decision: String, reason: String, score: Int, orderNumber: String, trackingNumber: String) {
    let combined = "\(message.subject) \(message.plainTextBodyPreview)".lowercased()
    let orderNumber = detectedOrderNumber(in: combined)
    let trackingNumber = detectedTrackingNumber(in: combined, excluding: orderNumber)
    let hasOrderID = !orderNumber.localizedCaseInsensitiveContains("needs review")
    let hasTrackingID = !trackingNumber.localizedCaseInsensitiveContains("needs review")
    let hasStrongSignal = [
      "order",
      "tracking",
      "shipped",
      "shipment",
      "dispatch",
      "delivered",
      "delivery update",
      "delivery question",
      "relates to an order",
      "refund",
      "return"
    ].contains { combined.contains($0) }
    let hasMarketingOrAccountSignal = [
      "newsletter",
      "unsubscribe",
      "offer",
      "final days",
      "sale",
      "security notification",
      "sign-in",
      "password",
      "calendar",
      "social"
    ].contains { combined.contains($0) }
    let score =
      (hasStrongSignal ? 2 : 0)
      + (hasOrderID ? 2 : 0)
      + (hasTrackingID ? 2 : 0)
      - (hasMarketingOrAccountSignal ? 3 : 0)

    if hasStrongSignal && (hasOrderID || hasTrackingID) && !hasMarketingOrAccountSignal {
      return ("Imported", "strong order signal", score, orderNumber, trackingNumber)
    }
    if hasStrongSignal && !hasMarketingOrAccountSignal {
      return ("Uncertain", "order-ish, missing order/tracking id", score, orderNumber, trackingNumber)
    }
    if hasMarketingOrAccountSignal {
      return ("Filtered", "marketing/account signal", score, orderNumber, trackingNumber)
    }
    if !hasOrderID && !hasTrackingID {
      return ("Filtered", "missing order/tracking id", score, orderNumber, trackingNumber)
    }
    return ("Filtered", "weak order signal", score, orderNumber, trackingNumber)
  }

  private func classifyMailboxMessageRelevance(_ message: FetchedMailboxMessage, for connection: SpaceMailIMAPConnection) -> (decision: MailboxRelevanceDecision, score: Int, reason: String) {
    let result = SpaceMailMailboxRelevanceClassifier.classify(message: message, connection: connection)
    let decision: MailboxRelevanceDecision
    switch result.decision {
    case .likelyOrder:
      decision = .likelyOrder
    case .uncertain:
      decision = .uncertain
    case .nonOrder:
      decision = .nonOrder
    }
    return (decision, result.score, result.reason)
  }

  private func spaceMailClassifierImpactPreview(
    for connection: SpaceMailIMAPConnection,
    preset: SpaceMailFilterPreset
  ) -> SpaceMailClassifierImpactPreview {
    let samples = spaceMailClassifierImpactSamples(for: connection)
    let previewConnection = spaceMailPreviewConnection(connection, preset: preset)
    var imported = 0
    var uncertain = 0
    var filtered = 0
    var changedExamples: [String] = []

    for sample in samples {
      let current = classifyMailboxMessageRelevance(sample, for: connection)
      let preview = classifyMailboxMessageRelevance(sample, for: previewConnection)
      switch preview.decision {
      case .likelyOrder:
        imported += 1
      case .uncertain:
        uncertain += 1
      case .nonOrder:
        filtered += 1
      }
      if current.decision != preview.decision {
        changedExamples.append("\(safeAuditPreview(sample.subject, limit: 70)): \(spaceMailDecisionLabel(current.decision)) -> \(spaceMailDecisionLabel(preview.decision))")
      }
    }

    let changedCount = changedExamples.count
    let riskLabel: String
    let detail: String
    if samples.isEmpty {
      riskLabel = "No samples"
      detail = "No stored preview samples are available yet. Run a manual refresh or classifier suite before relying on preset impact."
    } else if imported > max(1, samples.count / 2) {
      riskLabel = "Import-heavy"
      detail = "This preset would import \(imported) of \(samples.count) local samples. Use only when the mailbox is mostly forwarded order mail."
    } else if uncertain > 0 {
      riskLabel = "Review-heavy"
      detail = "This preset would leave \(uncertain) sample\(uncertain == 1 ? "" : "s") for manual uncertain review."
    } else if changedCount == 0 {
      riskLabel = "Stable"
      detail = "This preset does not change the decision for the current local samples."
    } else {
      riskLabel = "Tighter filter"
      detail = "This preset changes \(changedCount) local sample\(changedCount == 1 ? "" : "s") while keeping most mail out of Inbox."
    }

    return SpaceMailClassifierImpactPreview(
      preset: preset,
      sampleCount: samples.count,
      importedCount: imported,
      uncertainCount: uncertain,
      filteredCount: filtered,
      changedCount: changedCount,
      riskLabel: riskLabel,
      detail: detail,
      examples: Array(changedExamples.prefix(3))
    )
  }

  private func spaceMailPreviewConnection(
    _ connection: SpaceMailIMAPConnection,
    preset: SpaceMailFilterPreset
  ) -> SpaceMailIMAPConnection {
    var preview = connection
    let config = spaceMailFilterPresetConfiguration(preset)
    preview.mailboxMode = .mixedFiltered
    preview.trustedSenderHints = config.trustedSenders
    preview.importKeywordHints = config.importKeywords
    preview.uncertainKeywordHints = config.uncertainKeywords
    preview.filterKeywordHints = config.filterKeywords
    return preview
  }

  private func spaceMailClassifierImpactSamples(for connection: SpaceMailIMAPConnection) -> [FetchedMailboxMessage] {
    let mailboxID = trackedMailbox(for: connection).id
    var messages: [FetchedMailboxMessage] = [
      FetchedMailboxMessage(
        providerMessageID: "impact-clear-order-\(connection.id.uuidString)",
        sender: "orders@example-shop.test",
        subject: "Order TEST-123 shipped tracking ABC123",
        receivedDate: Self.auditTimestamp(),
        plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123 to Melbourne.",
        sourceMailboxID: mailboxID
      ),
      FetchedMailboxMessage(
        providerMessageID: "impact-delivery-question-\(connection.id.uuidString)",
        sender: "customer@example.com",
        subject: "Delivery question",
        receivedDate: Self.auditTimestamp(),
        plainTextBodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
        sourceMailboxID: mailboxID
      ),
      FetchedMailboxMessage(
        providerMessageID: "impact-marketing-\(connection.id.uuidString)",
        sender: "offers@example-shop.test",
        subject: "Final days for free delivery",
        receivedDate: Self.auditTimestamp(),
        plainTextBodyPreview: "Final days to get free delivery on your next purchase. View this email or unsubscribe.",
        sourceMailboxID: mailboxID
      )
    ]

    messages.append(contentsOf: connection.uncertainMessages.prefix(5).map { message in
      FetchedMailboxMessage(
        providerMessageID: "impact-uncertain-\(message.providerMessageID)",
        sender: message.sender,
        subject: message.subject,
        receivedDate: message.receivedDate,
        plainTextBodyPreview: message.bodyPreview,
        sourceMailboxID: mailboxID
      )
    })
    messages.append(contentsOf: connection.filteredMessages.prefix(5).map { message in
      FetchedMailboxMessage(
        providerMessageID: "impact-filtered-\(message.providerMessageID)",
        sender: message.sender,
        subject: message.subject,
        receivedDate: message.receivedDate,
        plainTextBodyPreview: message.bodyPreview,
        sourceMailboxID: mailboxID
      )
    })
    return Array(messages.prefix(13))
  }

  private func spaceMailDecisionLabel(_ decision: MailboxRelevanceDecision) -> String {
    switch decision {
    case .likelyOrder:
      return "Imported"
    case .uncertain:
      return "Uncertain"
    case .nonOrder:
      return "Filtered"
    }
  }

  private func spaceMailClassifierEvidence(
    for message: FetchedMailboxMessage,
    connection: SpaceMailIMAPConnection,
    decision: MailboxRelevanceDecision,
    reason: String,
    score: Int
  ) -> SpaceMailClassifierEvidence {
    let nextAction: String
    switch decision {
    case .likelyOrder:
      nextAction = "Would import to Inbox. If this is wrong, add a filter hint or use a stricter preset."
    case .uncertain:
      nextAction = "Would stay out of Inbox and appear in Uncertain SpaceMail messages for manual import or dismissal."
    case .nonOrder:
      nextAction = "Would be filtered out of Inbox. Import manually only if the preview is actually order-related."
    }

    let result = SpaceMailMailboxRelevanceClassifier.classify(message: message, connection: connection)
    let positiveLabels = result.positiveEvidenceLabels.isEmpty ? ["Decision: \(reason)"] : result.positiveEvidenceLabels
    let cautionLabels = result.cautionLabels.isEmpty ? ["Score: \(score)"] : result.cautionLabels

    return SpaceMailClassifierEvidence(
      positiveLabels: positiveLabels,
      cautionLabels: cautionLabels,
      nextAction: nextAction
    )
  }

  private func firstConfiguredHint(in text: String, hints: [String]) -> String? {
    hints
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .first { text.contains($0.lowercased()) }
  }

  private func spaceMailReasonBreakdown(from counts: [String: Int]) -> [SpaceMailClassifierReasonCount] {
    counts
      .map { key, count in
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        return SpaceMailClassifierReasonCount(
          decision: parts.first ?? "Unknown",
          reason: parts.count > 1 ? parts[1] : "unknown reason",
          count: count
        )
      }
      .sorted {
        if $0.count != $1.count { return $0.count > $1.count }
        if $0.decision != $1.decision { return $0.decision < $1.decision }
        return $0.reason < $1.reason
      }
  }

  private func spaceMailRefreshStatus(
    fetchResult: SpaceMailIMAPFetchResult,
    ingestResult: (imported: Int, duplicates: Int)
  ) -> SpaceMailIMAPFetchStatus {
    if fetchResult.status != .success {
      return fetchResult.status
    }
    if ingestResult.imported > 0 {
      return .success
    }
    if ingestResult.duplicates > 0 {
      return .duplicateSkipped
    }
    return fetchResult.messages.isEmpty ? .noMessages : .success
  }

  private func spaceMailRefreshSummaryText(
    status: SpaceMailIMAPFetchStatus,
    connection: SpaceMailIMAPConnection,
    fetched: Int,
    imported: Int,
    duplicates: Int,
    filtered: Int,
    uncertain: Int
  ) -> String {
    var parts = [
      "Real refresh \(status.rawValue.lowercased()): \(fetched) fetched, \(imported) imported, \(duplicates) duplicates"
    ]
    if connection.mailboxMode == .mixedFiltered {
      parts.append("\(filtered) filtered non-order")
      parts.append("\(uncertain) uncertain")
      parts.append("Filtered messages were counted only and were not imported into Inbox.")
    } else {
      parts.append("Dedicated mailbox mode passed fetched messages to intake duplicate/import handling.")
    }
    return parts.joined(separator: ". ")
  }

  private func mapGraphMessages(_ messages: [MicrosoftGraphFetchedMessage], sourceMailboxID: UUID) -> [FetchedMailboxMessage] {
    messages.map { message in
      FetchedMailboxMessage(
        providerMessageID: message.graphMessageID,
        sender: message.sender,
        subject: message.subject,
        receivedDate: message.receivedDate,
        plainTextBodyPreview: message.plainTextBodyPreview,
        sourceMailboxID: sourceMailboxID
      )
    }
  }

  private func microsoftGraphRefreshStatus(
    fetchResult: MicrosoftGraphMailboxFetchResult,
    ingestResult: (imported: Int, duplicates: Int)
  ) -> MicrosoftGraphMailboxFetchStatus {
    if fetchResult.status != .success {
      return fetchResult.status
    }
    if ingestResult.imported > 0 {
      return .success
    }
    if ingestResult.duplicates > 0 {
      return .duplicateSkipped
    }
    return .noMessages
  }

  private func realGraphDiagnosticHint(for status: MicrosoftGraphMailboxFetchStatus) -> String {
    switch status {
    case .success:
      return "Real Graph read succeeded with read-only message preview fields."
    case .duplicateSkipped:
      return "Refresh succeeded, but every fetched message was already in the local intake history."
    case .noMessages:
      return "Graph returned an empty page for the configured folder."
    case .authRequired:
      return "Microsoft Graph returned an auth challenge. Token metadata can look valid, so use the Graph error code/message below as the source of truth."
    case .consentRequired:
      return "Check Microsoft Entra delegated Mail.Read consent, tenant policy, and whether admin consent is required."
    case .folderNotFound:
      return "Check the first monitored folder name. Use Inbox for the default mailbox inbox."
    case .networkFailed:
      return "Check network access and the macOS app sandbox network entitlement."
    case .graphRejected:
      return "Check the Graph HTTP response, mailbox permissions, tenant policy, and selected fields."
    case .parseFailed:
      return "Graph responded, but ParcelOps could not parse the message response shape."
    case .notConnected:
      return "Connect or configure the mailbox before refreshing."
    case .simulatedAuthPlaceholder:
      return "This status belongs to the mock/local refresh path."
    }
  }

  private func makeForwardedEmailIntake(from message: FetchedMailboxMessage) -> ForwardedEmailIntake {
    let combinedText = "\(message.subject)\n\(message.plainTextBodyPreview)"
    let orderNumber = detectedOrderNumber(in: combinedText)
    return ForwardedEmailIntake(
      sender: message.sender,
      subject: message.subject,
      receivedDate: message.receivedDate,
      rawBodyPreview: String(message.plainTextBodyPreview.prefix(280)),
      detectedMerchant: detectedMerchant(from: message),
      detectedOrderNumber: orderNumber,
      detectedTrackingNumber: detectedTrackingNumber(in: combinedText, excluding: orderNumber),
      detectedDestinationAddress: detectedDestinationAddress(in: combinedText),
      linkedOrderID: matchedOrderID(for: orderNumber),
      reviewState: .needsReview
    )
  }

  private func intakeParserDiagnostic(for email: ForwardedEmailIntake) -> IntakeParserDiagnostic? {
    let combinedText = "\(email.subject)\n\(email.rawBodyPreview)"
    let reprocessed = reprocessedIntakeEmail(from: email)
    var issues: [String] = []
    var severity: ValidationSeverity = .info

    if email.detectedOrderNumber.isPlaceholderValidationValue {
      issues.append("order number missing")
      severity = .high
    }
    if email.detectedTrackingNumber.isPlaceholderValidationValue {
      issues.append("tracking number missing")
      if severity != .high { severity = .warning }
    }
    if email.detectedMerchant.isPlaceholderValidationValue {
      issues.append("merchant missing")
      if severity == .info { severity = .warning }
    }
    if email.detectedDestinationAddress.isPlaceholderValidationValue {
      issues.append("destination missing")
      if severity == .info { severity = .warning }
    }

    var parserHints: [String] = []
    if reprocessed.detectedOrderNumber != email.detectedOrderNumber {
      parserHints.append("reprocess can update order to \(reprocessed.detectedOrderNumber)")
      severity = .high
    }
    if reprocessed.detectedTrackingNumber != email.detectedTrackingNumber {
      parserHints.append("reprocess can update tracking to \(reprocessed.detectedTrackingNumber)")
      severity = .high
    }
    if combinedText.localizedCaseInsensitiveContains("tracking") && email.detectedTrackingNumber.isPlaceholderValidationValue {
      parserHints.append("text mentions tracking but no tracking ID was accepted")
    }
    if combinedText.localizedCaseInsensitiveContains("order") && email.detectedOrderNumber.isPlaceholderValidationValue {
      parserHints.append("text mentions order but no order ID was accepted")
    }

    guard !issues.isEmpty || !parserHints.isEmpty || email.reviewState == .needsReview else { return nil }

    var nextSteps: [String] = []
    if !parserHints.isEmpty {
      nextSteps.append("Run Reprocess")
    }
    if !issues.isEmpty {
      nextSteps.append("Edit detected fields")
    }
    if email.linkedOrderID == nil {
      nextSteps.append("Link or create order")
    }
    if email.reviewState == .needsReview {
      nextSteps.append("Mark reviewed when corrected")
    }

    let emailLabel = email.detectedOrderNumber.isPlaceholderValidationValue ? safeAuditPreview(email.subject, limit: 80) : email.detectedOrderNumber
    let title: String
    if !parserHints.isEmpty {
      title = "Parser review: \(emailLabel)"
    } else {
      title = "Intake fields need review: \(emailLabel)"
    }
    let summaryParts = (issues + parserHints).prefix(5)
    return IntakeParserDiagnostic(
      id: "intake-parser-\(email.id.uuidString)",
      intakeEmailID: email.id,
      title: title,
      summary: summaryParts.joined(separator: "; "),
      severity: severity,
      capturedDate: email.receivedDate,
      subjectPreview: safeAuditPreview(email.subject, limit: 120),
      senderPreview: safeAuditPreview(email.sender, limit: 100),
      detectedMerchant: email.detectedMerchant,
      detectedOrderNumber: email.detectedOrderNumber,
      detectedTrackingNumber: email.detectedTrackingNumber,
      detectedDestination: email.detectedDestinationAddress,
      recommendedAction: parserHints.isEmpty ? "Review or edit the detected fields before accepting." : "Run Reprocess, then review the updated detected fields.",
      issueLabels: issues,
      parserHintLabels: parserHints,
      nextStepLabels: nextSteps
    )
  }

  private func reprocessedIntakeEmail(from email: ForwardedEmailIntake) -> ForwardedEmailIntake {
    let message = FetchedMailboxMessage(
      providerMessageID: email.id.uuidString,
      sender: email.sender,
      subject: email.subject,
      receivedDate: email.receivedDate,
      plainTextBodyPreview: email.rawBodyPreview,
      sourceMailboxID: UUID()
    )
    var reprocessed = makeForwardedEmailIntake(from: message)
    reprocessed.id = email.id
    reprocessed.rawBodyPreview = email.rawBodyPreview
    reprocessed.linkedOrderID = email.linkedOrderID ?? matchedOrderID(for: reprocessed.detectedOrderNumber)
    if email.reviewState == .ignored {
      reprocessed.reviewState = .ignored
    } else if reprocessed.linkedOrderID != nil {
      reprocessed.reviewState = .reviewed
    } else {
      reprocessed.reviewState = .needsReview
    }
    return reprocessed
  }

  private func intakeReprocessChanges(before: ForwardedEmailIntake, after: ForwardedEmailIntake) -> [String] {
    var changes: [String] = []
    if before.detectedMerchant != after.detectedMerchant { changes.append("merchant") }
    if before.detectedOrderNumber != after.detectedOrderNumber { changes.append("order number") }
    if before.detectedTrackingNumber != after.detectedTrackingNumber { changes.append("tracking number") }
    if before.detectedDestinationAddress != after.detectedDestinationAddress { changes.append("destination address") }
    if before.linkedOrderID != after.linkedOrderID { changes.append("linked order") }
    if before.reviewState != after.reviewState { changes.append("review state") }
    return changes
  }

  private func detectedMerchant(from message: FetchedMailboxMessage) -> String {
    let subject = message.subject.replacingOccurrences(of: "Fwd:", with: "", options: [.caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
    if let orderRange = subject.range(of: " order ", options: [.caseInsensitive]) {
      let merchant = subject[..<orderRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
      if !merchant.isEmpty { return merchant }
    }
    if let domain = message.sender.split(separator: "@").last?.split(separator: ".").first {
      return domain.replacingOccurrences(of: "-", with: " ").capitalized
    }
    return "Merchant needs review"
  }

  private func detectedOrderNumber(in text: String) -> String {
    let patterns = [
      #"(?i)\border\s+([A-Z0-9][A-Z0-9._/-]{2,30})\s+(?:has\s+)?(?:shipped|shipping|dispatched|sent)\b"#,
      #"(?i)\b(?:order|order\s+no\.?|order\s+number|order\s+id|order\s+ref(?:erence)?|purchase\s+order|po)\s*[:#-]?\s*([A-Z0-9][A-Z0-9._/-]{2,30})"#,
      #"(?i)\b(?:confirmation|receipt|invoice)\s*(?:number|no\.?|id|ref(?:erence)?)\s*[:#-]?\s*([A-Z0-9][A-Z0-9._/-]{2,30})"#,
      #"\b[A-Z]{2,8}-\d{3,12}\b"#,
      #"\b[A-Z]{2,8}\d{4,14}\b"#
    ]
    for pattern in patterns {
      if let value = firstMatch(in: text, pattern: pattern).flatMap(cleanDetectedIdentifier),
         isLikelyOrderIdentifier(value) {
        return value
      }
    }
    return "Order number needs review"
  }

  private func detectedTrackingNumber(in text: String, excluding orderNumber: String) -> String {
    let patterns = [
      #"(?i)\b(?:shipped|shipping|shipment)\s+(?:with\s+)?tracking\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"(?i)\b(?:tracking|tracking\s+number|tracking\s+no\.?|track\s+no\.?|shipment\s+number|shipment\s+id|parcel\s+number|consignment|consignment\s+number|awb|waybill)\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"(?i)\b(?:carrier|courier)\s*(?:ref(?:erence)?|number|no\.?)\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"\b(?:1Z[0-9A-Z]{16}|[A-Z]{2}\d{9}[A-Z]{2}|[A-Z]{2,6}\d{6,22}[A-Z0-9]*)\b"#
    ]
    for pattern in patterns {
      if let value = firstMatch(in: text, pattern: pattern).flatMap(cleanDetectedIdentifier),
         value.normalizedValidationKey != orderNumber.normalizedValidationKey,
         isLikelyTrackingIdentifier(value) {
        return value
      }
    }
    return "Tracking number needs review"
  }

  private func detectedDestinationAddress(in text: String) -> String {
    if let range = text.range(of: #"(?i)\bto\s+([^.\n]+)"#, options: .regularExpression) {
      let value = text[range]
        .replacingOccurrences(of: #"(?i)^\s*to\s+"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !value.isEmpty { return value }
    }
    return "Destination needs review"
  }

  private func matchedOrderID(for orderNumber: String) -> UUID? {
    orders.first { $0.orderNumber.caseInsensitiveCompare(orderNumber) == .orderedSame }?.id
  }

  private func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
    guard let swiftRange = Range(captureRange, in: text) else { return nil }
    return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func cleanDetectedIdentifier(_ value: String) -> String? {
    var cleaned = value
      .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n.,;:()[]{}<>\"'"))
    let boilerplateMarkers = ["SENTSECURELY", "SENTFROM", "FROM", "HTTPS", "HTTP", "VIEW", "CLICK"]
    for marker in boilerplateMarkers {
      if let range = cleaned.range(of: marker, options: [.caseInsensitive]),
         cleaned.distance(from: cleaned.startIndex, to: range.lowerBound) >= 5 {
        cleaned = String(cleaned[..<range.lowerBound])
      }
    }
    guard cleaned.count >= 3 else { return nil }
    return cleaned
  }

  private func isLikelyOrderIdentifier(_ value: String) -> Bool {
    let normalized = value.normalizedValidationKey
    guard normalized.count >= 4, normalized.count <= 32 else { return false }
    guard normalized.rangeOfCharacter(from: .decimalDigits) != nil else { return false }
    let blocked = ["ORDER", "ORDERS", "NUMBER", "CONFIRMATION", "RECEIPT", "INVOICE", "TRACKING", "SHIPMENT"]
    return !blocked.contains(normalized)
  }

  private func isLikelyTrackingIdentifier(_ value: String) -> Bool {
    let normalized = value.normalizedValidationKey
    guard normalized.count >= 5, normalized.count <= 34 else { return false }
    guard normalized.rangeOfCharacter(from: .decimalDigits) != nil else { return false }
    let blocked = ["TRACKING", "SHIPMENT", "CONSIGNMENT", "NUMBER", "ORDER"]
    return !blocked.contains(normalized)
  }

  private func safeAuditPreview(_ value: String, limit: Int) -> String {
    let cleaned = value
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "empty" : String(cleaned.prefix(limit))
  }

  private func mailboxIngestAuditDetail(for record: MailboxIngestRecord) -> String {
    "Provider message ID: \(record.providerMessageID)\nSource mailbox ID: \(record.sourceMailboxID.uuidString)\nStatus: \(record.status.rawValue)\nCaptured: \(record.capturedDate)\n\(record.summary)"
  }

  func createManualOrderPlaceholder() {
    let order = TrackedOrder(
      orderNumber: "MAN-\(3000 + orders.count + 1)",
      store: "Manual supplier",
      recipientEmail: "unassigned@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Unassigned",
      fulfillment: .delivery,
      carrier: "Pending",
      trackingNumber: "Pending",
      destination: "Pending",
      eta: "Pending",
      source: .manual,
      status: .intake,
      reviewState: .needsReview,
      latestStatus: "Manual draft created and awaiting review",
      timeline: [TimelineEvent(title: "Manual draft", detail: "Created from placeholder action.", time: "Now", symbol: "square.and.pencil")],
      contactHistory: [ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "Manual order", summary: "Draft order created.", evidence: "No existing order data was overwritten.", reviewState: .needsReview)]
    )
    orders.insert(order, at: 0)
    persistOrders()
    logAudit(
      action: .created,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: "Manual draft order created.",
      afterDetail: order.auditDetail
    )
  }

  func clearIssue(for orderNumber: String) {
    for index in orders.indices where orders[index].orderNumber == orderNumber {
      let beforeDetail = orders[index].auditDetail
      orders[index].reviewState = .accepted
      if orders[index].status == .exception {
        orders[index].status = .inTransit
      }
      orders[index].latestStatus = "Issue cleared by user review"
      orders[index].contactHistory.insert(ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "Needs Review", summary: "User cleared the issue.", evidence: "Related review entries were resolved together.", reviewState: .accepted), at: 0)
      logAudit(
        action: .cleared,
        entityType: .order,
        entityID: orders[index].id.uuidString,
        entityLabel: orders[index].orderNumber,
        summary: "Order review issue cleared.",
        beforeDetail: beforeDetail,
        afterDetail: orders[index].auditDetail
      )
    }

    for index in mailEvents.indices where mailEvents[index].matchedOrder == orderNumber {
      mailEvents[index].reviewState = .accepted
      mailEvents[index].severity = .info
    }
    persistOrders()
    persistMailEvents()
  }

  func discardSpam(for orderNumber: String) {
    mailEvents.removeAll { $0.matchedOrder == orderNumber }
    for index in orders.indices where orders[index].orderNumber == orderNumber {
      orders[index].reviewState = .accepted
      if orders[index].status == .exception {
        orders[index].status = .ordered
      }
      orders[index].latestStatus = "Related exception discarded as spam"
      orders[index].contactHistory.insert(ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "Needs Review", summary: "User discarded related message as spam.", evidence: "No order fields were overwritten.", reviewState: .accepted), at: 0)
    }
    persistOrders()
    persistMailEvents()
  }

  func linkIntakeEmail(_ email: ForwardedEmailIntake, to order: TrackedOrder) {
    guard let emailIndex = intakeEmails.firstIndex(where: { $0.id == email.id }) else { return }
    let beforeDetail = intakeEmails[emailIndex].auditDetail
    intakeEmails[emailIndex].linkedOrderID = order.id
    intakeEmails[emailIndex].reviewState = .reviewed

    if let orderIndex = orders.firstIndex(where: { $0.id == order.id }) {
      orders[orderIndex].contactHistory.insert(
        ContactHistoryEvent(
          time: "Now",
          source: .mailbox,
          contactPoint: "Forwarded email intake",
          summary: "Forwarded email linked to this order.",
          evidence: "\(email.subject) from \(email.sender)",
          reviewState: .accepted
        ),
        at: 0
      )
      orders[orderIndex].latestStatus = "Forwarded email evidence linked"
    }

    persistOrders()
    persistIntakeEmails()
    logAudit(
      action: .linked,
      entityType: .intakeEmail,
      entityID: intakeEmails[emailIndex].id.uuidString,
      entityLabel: intakeEmails[emailIndex].auditLabel,
      summary: "Forwarded intake email linked to order \(order.orderNumber).",
      beforeDetail: beforeDetail,
      afterDetail: intakeEmails[emailIndex].auditDetail
    )
  }

  func createOrder(from email: ForwardedEmailIntake) {
    let missingFields = missingIntakeOrderFields(email)
    let isPartialOrder = !missingFields.isEmpty
    let orderNumber = email.detectedOrderNumber.isPlaceholder ? "EMAIL-\(3000 + orders.count + 1)" : email.detectedOrderNumber
    let trackingNumber = email.detectedTrackingNumber.isPlaceholder ? "Pending" : email.detectedTrackingNumber
    let destination = email.detectedDestinationAddress.isPlaceholder ? "Pending review" : email.detectedDestinationAddress
    let latestStatus = isPartialOrder
      ? "Created from forwarded email with missing \(missingFields.joined(separator: ", "))"
      : "Created from forwarded email and awaiting review"
    let handoffDetail = isPartialOrder
      ? "Created as a partial order because \(missingFields.joined(separator: ", ")) needs confirmation."
      : "Created from forwarded email with usable detected order fields."

    let order = TrackedOrder(
      orderNumber: orderNumber,
      store: email.detectedMerchant.isPlaceholder ? "Forwarded email supplier" : email.detectedMerchant,
      recipientEmail: "captured-from-forward@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Unassigned",
      fulfillment: .delivery,
      carrier: trackingNumber == "Pending" ? "Pending" : "Carrier pending",
      trackingNumber: trackingNumber,
      destination: destination,
      eta: "Pending",
      source: .forwardedMailbox,
      status: trackingNumber == "Pending" ? .intake : .shipped,
      reviewState: .needsReview,
      latestStatus: latestStatus,
      timeline: [
        TimelineEvent(title: "Forwarded email captured", detail: email.subject, time: "Now", symbol: "envelope.open.fill"),
        TimelineEvent(title: isPartialOrder ? "Partial order created" : "Order created", detail: handoffDetail, time: "Now", symbol: isPartialOrder ? "exclamationmark.triangle.fill" : "shippingbox.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Now", source: .mailbox, contactPoint: "Forwarded email intake", summary: handoffDetail, evidence: email.rawBodyPreview, reviewState: .needsReview)
      ]
    )

    orders.insert(order, at: 0)

    if let emailIndex = intakeEmails.firstIndex(where: { $0.id == email.id }) {
      intakeEmails[emailIndex].linkedOrderID = order.id
      intakeEmails[emailIndex].reviewState = .reviewed
    }

    persistOrders()
    persistIntakeEmails()
    if isPartialOrder {
      createPartialInboxOrderFollowUp(for: order, email: email, missingFields: missingFields)
    }
    logAudit(
      action: .created,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: isPartialOrder ? "Partial tracked order created from forwarded intake email." : "Tracked order created from forwarded intake email.",
      afterDetail: "\(order.auditDetail)\nInbox handoff: \(handoffDetail)"
    )
    logAudit(
      action: .reviewed,
      entityType: .intakeEmail,
      entityID: email.id.uuidString,
      entityLabel: email.auditLabel,
      summary: "Forwarded intake email marked reviewed after order creation.",
      beforeDetail: email.auditDetail,
      afterDetail: intakeEmails.first { $0.id == email.id }?.auditDetail
    )
  }

  private func missingIntakeOrderFields(_ email: ForwardedEmailIntake) -> [String] {
    [
      email.detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
      email.detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
      email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
      email.detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }

  private func createPartialInboxOrderFollowUp(for order: TrackedOrder, email: ForwardedEmailIntake, missingFields: [String]) {
    let missingSummary = missingFields.joined(separator: ", ")
    let task = ReviewTask(
      title: "Verify Inbox-created order \(order.orderNumber)",
      summary: "Confirm missing \(missingSummary) from forwarded email '\(email.subject)' before dispatch setup.",
      linkedEntityType: .order,
      linkedEntityID: order.id.uuidString,
      priority: missingFields.contains("order number") || missingFields.contains("tracking number") ? .high : .normal,
      dueDate: "Today",
      assignee: "Mailbox team",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(task, summary: "Review task created for partial Inbox-created order.")
    logAudit(
      action: .created,
      entityType: .reviewTask,
      entityID: task.id.uuidString,
      entityLabel: task.title,
      summary: "Partial Inbox-created order follow-up task added.",
      afterDetail: "Order: \(order.orderNumber)\nMissing fields: \(missingSummary)\nSource email: \(email.subject)\nNo mailbox fetch, mailbox mutation, or external service call occurred."
    )
  }

  func updateIntakeEmail(_ email: ForwardedEmailIntake) {
    guard let index = intakeEmails.firstIndex(where: { $0.id == email.id }) else { return }
    let beforeDetail = intakeEmails[index].auditDetail
    intakeEmails[index] = email
    persistIntakeEmails()
    logAudit(
      action: .edited,
      entityType: .intakeEmail,
      entityID: email.id.uuidString,
      entityLabel: email.auditLabel,
      summary: "Forwarded intake email details corrected.",
      beforeDetail: beforeDetail,
      afterDetail: email.auditDetail
    )
  }

  func reprocessIntakeEmail(_ email: ForwardedEmailIntake) {
    guard let index = intakeEmails.firstIndex(where: { $0.id == email.id }) else { return }
    let before = intakeEmails[index]
    let reprocessed = reprocessedIntakeEmail(from: before)
    let changes = intakeReprocessChanges(before: before, after: reprocessed)

    if changes.isEmpty {
      logAudit(
        action: .evaluated,
        entityType: .intakeEmail,
        entityID: before.id.uuidString,
        entityLabel: before.auditLabel,
        summary: "Forwarded intake email reprocessed with no field changes.",
        afterDetail: "No detected fields changed. Stored subject/body preview was re-read locally.\nStored subject: \(safeAuditPreview(before.subject, limit: 160))\nStored preview: \(safeAuditPreview(before.rawBodyPreview, limit: 260))\nParser result: merchant \(reprocessed.detectedMerchant); order \(reprocessed.detectedOrderNumber); tracking \(reprocessed.detectedTrackingNumber); destination \(reprocessed.detectedDestinationAddress).\nNo mailbox fetch, duplicate metadata change, or external service call occurred."
      )
      return
    }

    intakeEmails[index] = reprocessed
    persistIntakeEmails()
    logAudit(
      action: .edited,
      entityType: .intakeEmail,
      entityID: reprocessed.id.uuidString,
      entityLabel: reprocessed.auditLabel,
      summary: "Forwarded intake email reprocessed locally.",
      beforeDetail: before.auditDetail,
      afterDetail: "\(reprocessed.auditDetail)\nChanged fields: \(changes.joined(separator: ", ")).\nReprocessed from stored subject/body preview only. No mailbox fetch, duplicate metadata change, or external service call occurred."
    )
  }

  func reprocessReviewIntakeEmails() {
    let candidates = intakeEmails.filter { $0.reviewState == .needsReview }
    logAudit(
      action: .evaluated,
      entityType: .intakeEmail,
      entityID: "bulk-intake-reprocess",
      entityLabel: "Forwarded intake reprocess",
      summary: "Bulk reprocess of intake emails needing review started.",
      afterDetail: "Candidates: \(candidates.count). Reprocessing uses stored subject/body previews only and does not fetch mailbox messages or change duplicate metadata."
    )

    var changedCount = 0
    var unchangedCount = 0
    var changedLabels: [String] = []

    for candidate in candidates {
      guard let index = intakeEmails.firstIndex(where: { $0.id == candidate.id }) else { continue }
      let before = intakeEmails[index]
      let reprocessed = reprocessedIntakeEmail(from: before)
      let changes = intakeReprocessChanges(before: before, after: reprocessed)
      if changes.isEmpty {
        unchangedCount += 1
      } else {
        intakeEmails[index] = reprocessed
        changedCount += 1
        changedLabels.append("\(reprocessed.auditLabel): \(changes.joined(separator: ", "))")
      }
    }

    if changedCount > 0 {
      persistIntakeEmails()
    }
    logAudit(
      action: changedCount > 0 ? .edited : .evaluated,
      entityType: .intakeEmail,
      entityID: "bulk-intake-reprocess",
      entityLabel: "Forwarded intake reprocess",
      summary: "Bulk reprocess of intake emails needing review completed.",
      afterDetail: "Candidates: \(candidates.count)\nChanged: \(changedCount)\nNo change: \(unchangedCount)\nChanged fields: \(changedLabels.prefix(20).joined(separator: "\n"))\nNo intake emails were deleted or duplicated. Duplicate tracking metadata was not changed. No mailbox messages were fetched or modified."
    )
  }

  func updateOrder(_ order: TrackedOrder) {
    guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
    let beforeDetail = orders[index].auditDetail
    var updatedOrder = order
    updatedOrder.latestStatus = "Order details updated by user review"
    updatedOrder.contactHistory.insert(
      ContactHistoryEvent(
        time: "Now",
        source: .manual,
        contactPoint: "Order editor",
        summary: "User corrected order details.",
        evidence: "Merchant, recipient, fulfillment, carrier, tracking, destination, status, or review state may have changed.",
        reviewState: updatedOrder.reviewState
      ),
      at: 0
    )
    orders[index] = updatedOrder
    persistOrders()
    logAudit(
      action: .edited,
      entityType: .order,
      entityID: updatedOrder.id.uuidString,
      entityLabel: updatedOrder.orderNumber,
      summary: "Tracked order details corrected.",
      beforeDetail: beforeDetail,
      afterDetail: updatedOrder.auditDetail
    )
    resolvePartialInboxOrderFollowUpIfReady(for: updatedOrder, source: "Order details updated by user review")
  }

  func partialInboxOrderMissingFields(for order: TrackedOrder) -> [String] {
    [
      order.orderNumber.isPlaceholderValidationValue ? "order number" : nil,
      order.trackingNumber == "Pending" || order.trackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
      order.destination == "Pending review" || order.destination.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }

  func unresolvedPartialInboxOrderFollowUps(for order: TrackedOrder) -> [ReviewTask] {
    reviewTasks.filter { task in
      task.linkedEntityType == .order
        && task.linkedEntityID == order.id.uuidString
        && task.isPartialInboxOrderFollowUp
        && task.status != .completed
    }
  }

  func resolvePartialInboxOrderFollowUpIfReady(for order: TrackedOrder, source: String = "Manual order verification") {
    let tasks = unresolvedPartialInboxOrderFollowUps(for: order)
    guard !tasks.isEmpty else { return }

    let missingFields = partialInboxOrderMissingFields(for: order)
    guard missingFields.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Partial Inbox-created order still needs verification.",
        afterDetail: "Open follow-up tasks: \(tasks.count)\nMissing fields: \(missingFields.joined(separator: ", "))\nSource: \(source)\nNo task was completed because the order still has placeholder details."
      )
      return
    }

    let timestamp = Self.auditTimestamp()
    var resolvedTaskLabels: [String] = []
    for task in tasks {
      guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { continue }
      let beforeDetail = reviewTasks[index].auditDetail
      reviewTasks[index].status = .completed
      reviewTasks[index].completedDate = timestamp
      reviewTasks[index].reviewState = .accepted
      resolvedTaskLabels.append(reviewTasks[index].title)
      logAudit(
        action: .completed,
        entityType: .reviewTask,
        entityID: reviewTasks[index].id.uuidString,
        entityLabel: reviewTasks[index].title,
        summary: "Partial Inbox-created order follow-up resolved.",
        beforeDetail: beforeDetail,
        afterDetail: "\(reviewTasks[index].auditDetail)\nOrder: \(order.orderNumber)\nSource: \(source)\nAll required order handoff fields are now present. No mailbox fetch, mailbox mutation, or external service call occurred."
      )
    }

    persistReviewTasks()
    logAudit(
      action: .reviewed,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: "Inbox-created order verification follow-up closed.",
      afterDetail: "Resolved tasks: \(resolvedTaskLabels.joined(separator: ", "))\nSource: \(source)\nOrder number, tracking number, and destination are no longer placeholders."
    )
  }

  func createDispatchSetup(for order: TrackedOrder) {
    guard let orderIndex = orders.firstIndex(where: { $0.id == order.id }) else { return }

    let missingFields = partialInboxOrderMissingFields(for: order)
    guard missingFields.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Dispatch setup blocked by missing Inbox handoff fields.",
        afterDetail: "Missing fields: \(missingFields.joined(separator: ", "))\nEdit the order before creating manifest and readiness context. No dispatch records were created."
      )
      return
    }

    let existingManifests = suggestedShipmentManifestRecords(for: order)
    let existingChecklists = suggestedDispatchReadinessChecklists(for: order)
    guard existingManifests.isEmpty && existingChecklists.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Dispatch setup already exists for Inbox-created order.",
        afterDetail: "Existing manifests: \(existingManifests.count)\nExisting readiness checklists: \(existingChecklists.count)\nNo duplicate dispatch records were created."
      )
      return
    }

    let timestamp = Self.auditTimestamp()
    let ownerTeam = order.customer.isPlaceholderValidationValue || order.customer == "Unassigned" ? "ParcelOps Operations" : order.customer
    let carrierCourier = order.carrier.isPlaceholderValidationValue || order.carrier == "Pending" ? "Carrier pending" : order.carrier
    let riskLevel: ShipmentRiskLevel = order.status == .exception ? .high : .medium
    let manifest = ShipmentManifestRecord(
      title: "Dispatch setup for \(order.orderNumber)",
      manifestType: .dispatchBatch,
      linkedEntityType: .order,
      linkedEntityID: order.id.uuidString,
      carrierCourier: carrierCourier,
      destinationSummary: order.destination,
      includedOrderIDs: [order.id],
      shipmentGroupIDs: [],
      inventoryReceiptIDs: [],
      packageContentIDs: [],
      custodyRecordIDs: [],
      labelReferenceIDs: [],
      scanSessionIDs: [],
      evidenceAttachmentIDs: [],
      assignedOwnerTeam: ownerTeam,
      dispatchStatus: .draft,
      plannedDispatchDate: "To schedule",
      actualDispatchDate: "Not dispatched",
      handoffLocationStorageLocationID: nil,
      manifestReferencePlaceholder: "INBOX-\(order.orderNumber)",
      notes: "Created locally from verified Inbox order handoff. No carrier booking, label printing, or mailbox mutation was performed.",
      riskLevel: riskLevel,
      createdDate: timestamp,
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    let checklist = DispatchReadinessChecklist(
      title: "Readiness for \(order.orderNumber)",
      linkedEntityType: .order,
      linkedEntityID: order.id.uuidString,
      shipmentManifestID: manifest.id,
      orderIDs: [order.id],
      shipmentGroupIDs: [],
      inventoryReceiptIDs: [],
      packageContentIDs: [],
      custodyRecordIDs: [],
      labelReferenceIDs: [],
      scanSessionIDs: [],
      evidenceAttachmentIDs: [],
      checklistType: .manifestReadiness,
      checklistStatus: .draft,
      requiredChecksSummary: "Confirm label, scan, custody, destination, and handoff before dispatch.",
      completedChecksSummary: "Order number, tracking, and destination were confirmed from Inbox handoff.",
      missingRequirementsSummary: "Label, scan, custody, and handoff location still need local confirmation.",
      assignedOwnerTeam: ownerTeam,
      plannedDispatchDate: "To schedule",
      completedDate: "Not completed",
      riskLevel: riskLevel,
      createdDate: timestamp,
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )

    shipmentManifestRecords.insert(manifest, at: 0)
    dispatchReadinessChecklists.insert(checklist, at: 0)

    let beforeDetail = orders[orderIndex].auditDetail
    orders[orderIndex].latestStatus = "Dispatch setup created from Inbox handoff"
    orders[orderIndex].contactHistory.insert(
      ContactHistoryEvent(
        time: "Now",
        source: .manual,
        contactPoint: "Inbox handoff checklist",
        summary: "Local dispatch setup records created.",
        evidence: "Manifest \(manifest.title) and readiness checklist \(checklist.title) were linked to this order.",
        reviewState: .needsReview
      ),
      at: 0
    )

    persistShipmentManifestRecords()
    persistDispatchReadinessChecklists()
    persistOrders()

    logAudit(
      action: .created,
      entityType: .shipmentManifest,
      entityID: manifest.id.uuidString,
      entityLabel: manifest.title,
      summary: "Shipment manifest created from verified Inbox order.",
      afterDetail: manifest.auditDetail
    )
    logAudit(
      action: .created,
      entityType: .dispatchChecklist,
      entityID: checklist.id.uuidString,
      entityLabel: checklist.title,
      summary: "Dispatch readiness checklist created from verified Inbox order.",
      afterDetail: checklist.auditDetail
    )
    logAudit(
      action: .linked,
      entityType: .order,
      entityID: orders[orderIndex].id.uuidString,
      entityLabel: orders[orderIndex].orderNumber,
      summary: "Inbox-created order linked to dispatch setup.",
      beforeDetail: beforeDetail,
      afterDetail: "\(orders[orderIndex].auditDetail)\nCreated manifest: \(manifest.title)\nCreated readiness checklist: \(checklist.title)\nNo external carrier, label, scanner, or mailbox action occurred."
    )
  }

  func completeInboxDispatchHandoff(for order: TrackedOrder) {
    guard let orderIndex = orders.firstIndex(where: { $0.id == order.id }) else { return }

    let linkedManifests = suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
    let linkedChecklists = suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
    guard !linkedManifests.isEmpty || !linkedChecklists.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Inbox dispatch handoff completion skipped.",
        afterDetail: "No linked Inbox dispatch manifest or readiness checklist was found. No order, dispatch, mailbox, carrier, label, scanner, or external service action occurred."
      )
      return
    }

    let blockedManifests = linkedManifests.filter { $0.dispatchStatus == .blockedNeedsReview }
    let blockedChecklists = linkedChecklists.filter { $0.checklistStatus == .blockedNeedsReview }
    guard blockedManifests.isEmpty && blockedChecklists.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Inbox dispatch handoff completion blocked.",
        afterDetail: "Blocked manifests: \(blockedManifests.map(\.title).joined(separator: ", "))\nBlocked readiness checklists: \(blockedChecklists.map(\.title).joined(separator: ", "))\nResolve blocked dispatch records before completing handoff. No mailbox, carrier, label, scanner, or external service action occurred."
      )
      return
    }

    let timestamp = Self.auditTimestamp()
    var completedManifestTitles: [String] = []
    for manifest in linkedManifests where manifest.dispatchStatus != .handedOff {
      guard let manifestIndex = shipmentManifestRecords.firstIndex(where: { $0.id == manifest.id }) else { continue }
      let beforeDetail = shipmentManifestRecords[manifestIndex].auditDetail
      shipmentManifestRecords[manifestIndex].dispatchStatus = .handedOff
      shipmentManifestRecords[manifestIndex].reviewState = .accepted
      shipmentManifestRecords[manifestIndex].lastReviewedDate = timestamp
      shipmentManifestRecords[manifestIndex].actualDispatchDate = timestamp
      completedManifestTitles.append(shipmentManifestRecords[manifestIndex].title)
      logAudit(
        action: .completed,
        entityType: .shipmentManifest,
        entityID: shipmentManifestRecords[manifestIndex].id.uuidString,
        entityLabel: shipmentManifestRecords[manifestIndex].title,
        summary: "Inbox dispatch manifest completed from order handoff.",
        beforeDetail: beforeDetail,
        afterDetail: "\(shipmentManifestRecords[manifestIndex].auditDetail)\nSource order: \(order.orderNumber)\nCompleted locally from Order detail. No carrier, label, scanner, mailbox, or external service action occurred."
      )
    }

    var completedChecklistTitles: [String] = []
    for checklist in linkedChecklists where checklist.checklistStatus != .completed {
      guard let checklistIndex = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { continue }
      let beforeDetail = dispatchReadinessChecklists[checklistIndex].auditDetail
      dispatchReadinessChecklists[checklistIndex].checklistStatus = .completed
      dispatchReadinessChecklists[checklistIndex].reviewState = .accepted
      dispatchReadinessChecklists[checklistIndex].lastReviewedDate = timestamp
      dispatchReadinessChecklists[checklistIndex].completedDate = timestamp
      completedChecklistTitles.append(dispatchReadinessChecklists[checklistIndex].title)
      logAudit(
        action: .completed,
        entityType: .dispatchChecklist,
        entityID: dispatchReadinessChecklists[checklistIndex].id.uuidString,
        entityLabel: dispatchReadinessChecklists[checklistIndex].title,
        summary: "Inbox dispatch readiness completed from order handoff.",
        beforeDetail: beforeDetail,
        afterDetail: "\(dispatchReadinessChecklists[checklistIndex].auditDetail)\nSource order: \(order.orderNumber)\nCompleted locally from Order detail. No carrier, label, scanner, mailbox, or external service action occurred."
      )
    }

    let beforeOrderDetail = orders[orderIndex].auditDetail
    if orders[orderIndex].status != .delivered {
      orders[orderIndex].status = .inTransit
    }
    orders[orderIndex].reviewState = .accepted
    orders[orderIndex].latestStatus = "Inbox dispatch handoff completed locally"
    orders[orderIndex].contactHistory.insert(
      ContactHistoryEvent(
        time: "Now",
        source: .manual,
        contactPoint: "Order dispatch handoff",
        summary: "Inbox dispatch handoff completed locally.",
        evidence: "Manifests: \(completedManifestTitles.isEmpty ? "already complete" : completedManifestTitles.joined(separator: ", ")). Readiness: \(completedChecklistTitles.isEmpty ? "already complete" : completedChecklistTitles.joined(separator: ", ")).",
        reviewState: .accepted
      ),
      at: 0
    )

    var resolvedTaskTitles: [String] = []
    for task in reviewTasks where task.linkedEntityType == .order
      && task.linkedEntityID == orders[orderIndex].id.uuidString
      && task.status != .completed
      && task.summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff") {
      guard let taskIndex = reviewTasks.firstIndex(where: { $0.id == task.id }) else { continue }
      let beforeTaskDetail = reviewTasks[taskIndex].auditDetail
      reviewTasks[taskIndex].status = .completed
      reviewTasks[taskIndex].completedDate = timestamp
      reviewTasks[taskIndex].reviewState = .accepted
      resolvedTaskTitles.append(reviewTasks[taskIndex].title)
      logAudit(
        action: .completed,
        entityType: .reviewTask,
        entityID: reviewTasks[taskIndex].id.uuidString,
        entityLabel: reviewTasks[taskIndex].title,
        summary: "Reopened Inbox dispatch handoff task resolved.",
        beforeDetail: beforeTaskDetail,
        afterDetail: "\(reviewTasks[taskIndex].auditDetail)\nOrder: \(orders[orderIndex].orderNumber)\nDispatch handoff was completed locally again. No mailbox, carrier, label, scanner, or external service action occurred."
      )
    }

    persistShipmentManifestRecords()
    persistDispatchReadinessChecklists()
    persistOrders()
    if !resolvedTaskTitles.isEmpty {
      persistReviewTasks()
    }

    logAudit(
      action: .completed,
      entityType: .order,
      entityID: orders[orderIndex].id.uuidString,
      entityLabel: orders[orderIndex].orderNumber,
      summary: "Inbox-created order dispatch handoff completed.",
      beforeDetail: beforeOrderDetail,
      afterDetail: "\(orders[orderIndex].auditDetail)\nCompleted manifests: \(completedManifestTitles.joined(separator: ", "))\nCompleted readiness: \(completedChecklistTitles.joined(separator: ", "))\nResolved follow-up tasks: \(resolvedTaskTitles.joined(separator: ", "))\nNo mailbox item was mutated and no carrier, label, scanner, or external service action occurred."
    )
  }

  func reopenInboxDispatchHandoff(for order: TrackedOrder) {
    guard let orderIndex = orders.firstIndex(where: { $0.id == order.id }) else { return }

    let linkedManifests = suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
    let linkedChecklists = suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
    guard !linkedManifests.isEmpty || !linkedChecklists.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .order,
        entityID: order.id.uuidString,
        entityLabel: order.orderNumber,
        summary: "Inbox dispatch handoff reopen skipped.",
        afterDetail: "No linked Inbox dispatch manifest or readiness checklist was found. No order, dispatch, mailbox, carrier, label, scanner, or external service action occurred."
      )
      return
    }

    let timestamp = Self.auditTimestamp()
    var reopenedManifestTitles: [String] = []
    for manifest in linkedManifests where manifest.dispatchStatus == .handedOff {
      guard let manifestIndex = shipmentManifestRecords.firstIndex(where: { $0.id == manifest.id }) else { continue }
      let beforeDetail = shipmentManifestRecords[manifestIndex].auditDetail
      shipmentManifestRecords[manifestIndex].dispatchStatus = .reopened
      shipmentManifestRecords[manifestIndex].reviewState = .needsReview
      shipmentManifestRecords[manifestIndex].lastReviewedDate = timestamp
      reopenedManifestTitles.append(shipmentManifestRecords[manifestIndex].title)
      logAudit(
        action: .reopened,
        entityType: .shipmentManifest,
        entityID: shipmentManifestRecords[manifestIndex].id.uuidString,
        entityLabel: shipmentManifestRecords[manifestIndex].title,
        summary: "Inbox dispatch manifest reopened from order handoff.",
        beforeDetail: beforeDetail,
        afterDetail: "\(shipmentManifestRecords[manifestIndex].auditDetail)\nSource order: \(order.orderNumber)\nReopened locally from Order detail. No carrier, label, scanner, mailbox, or external service action occurred."
      )
    }

    var reopenedChecklistTitles: [String] = []
    for checklist in linkedChecklists where checklist.checklistStatus == .completed {
      guard let checklistIndex = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { continue }
      let beforeDetail = dispatchReadinessChecklists[checklistIndex].auditDetail
      dispatchReadinessChecklists[checklistIndex].checklistStatus = .reopened
      dispatchReadinessChecklists[checklistIndex].reviewState = .needsReview
      dispatchReadinessChecklists[checklistIndex].lastReviewedDate = timestamp
      reopenedChecklistTitles.append(dispatchReadinessChecklists[checklistIndex].title)
      logAudit(
        action: .reopened,
        entityType: .dispatchChecklist,
        entityID: dispatchReadinessChecklists[checklistIndex].id.uuidString,
        entityLabel: dispatchReadinessChecklists[checklistIndex].title,
        summary: "Inbox dispatch readiness reopened from order handoff.",
        beforeDetail: beforeDetail,
        afterDetail: "\(dispatchReadinessChecklists[checklistIndex].auditDetail)\nSource order: \(order.orderNumber)\nReopened locally from Order detail. No carrier, label, scanner, mailbox, or external service action occurred."
      )
    }

    let beforeOrderDetail = orders[orderIndex].auditDetail
    if orders[orderIndex].status != .delivered {
      orders[orderIndex].status = .exception
    }
    orders[orderIndex].reviewState = .needsReview
    orders[orderIndex].latestStatus = "Inbox dispatch handoff reopened for review"
    orders[orderIndex].contactHistory.insert(
      ContactHistoryEvent(
        time: "Now",
        source: .manual,
        contactPoint: "Order dispatch handoff",
        summary: "Inbox dispatch handoff reopened locally.",
        evidence: "Manifests: \(reopenedManifestTitles.isEmpty ? "already open or unavailable" : reopenedManifestTitles.joined(separator: ", ")). Readiness: \(reopenedChecklistTitles.isEmpty ? "already open or unavailable" : reopenedChecklistTitles.joined(separator: ", ")).",
        reviewState: .needsReview
      ),
      at: 0
    )

    let hasOpenReopenTask = reviewTasks.contains { task in
      task.linkedEntityType == .order
        && task.linkedEntityID == orders[orderIndex].id.uuidString
        && task.status != .completed
        && task.summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
    }
    if !hasOpenReopenTask {
      let task = ReviewTask(
        title: "Review reopened dispatch handoff for \(orders[orderIndex].orderNumber)",
        summary: "Reopened Inbox dispatch handoff. Confirm why the local handoff was reopened, then complete or block the linked manifest/readiness records.",
        linkedEntityType: .order,
        linkedEntityID: orders[orderIndex].id.uuidString,
        priority: .high,
        dueDate: "Today",
        assignee: orders[orderIndex].customer.isPlaceholderValidationValue ? "Operations" : orders[orderIndex].customer,
        status: .open,
        createdDate: timestamp,
        completedDate: nil,
        reviewState: .needsReview
      )
      addReviewTask(task, summary: "Review task created for reopened Inbox dispatch handoff.")
    }

    persistShipmentManifestRecords()
    persistDispatchReadinessChecklists()
    persistOrders()

    logAudit(
      action: .reopened,
      entityType: .order,
      entityID: orders[orderIndex].id.uuidString,
      entityLabel: orders[orderIndex].orderNumber,
      summary: "Inbox-created order dispatch handoff reopened.",
      beforeDetail: beforeOrderDetail,
      afterDetail: "\(orders[orderIndex].auditDetail)\nReopened manifests: \(reopenedManifestTitles.joined(separator: ", "))\nReopened readiness: \(reopenedChecklistTitles.joined(separator: ", "))\nNo mailbox item was mutated and no carrier, label, scanner, or external service action occurred."
    )
  }

  func markIntakeEmailReviewed(_ email: ForwardedEmailIntake) {
    updateIntakeEmail(email, reviewState: .reviewed)
  }

  func ignoreIntakeEmail(_ email: ForwardedEmailIntake) {
    updateIntakeEmail(email, reviewState: .ignored)
  }

  func evidence(for linkedEntityType: EvidenceLinkedEntityType, linkedEntityID: UUID) -> [EvidenceAttachment] {
    evidenceAttachments.filter {
      $0.linkedEntityType == linkedEntityType && $0.linkedEntityID == linkedEntityID
    }
  }

  func addPlaceholderEvidence(to linkedEntityType: EvidenceLinkedEntityType, linkedEntityID: UUID, label: String) {
    let attachment = EvidenceAttachment(
      linkedEntityType: linkedEntityType,
      linkedEntityID: linkedEntityID,
      fileName: "\(label.replacingOccurrences(of: " ", with: "-"))-evidence.pdf",
      fileType: "PDF",
      source: .manualUpload,
      addedDate: Self.auditTimestamp(),
      summary: "Placeholder evidence attachment added for local review.",
      reviewState: .needsReview,
      localFilePath: "~/Library/Application Support/ParcelOps/Evidence/\(label.replacingOccurrences(of: " ", with: "-"))-evidence.pdf"
    )
    evidenceAttachments.insert(attachment, at: 0)
    persistEvidenceAttachments()
    logAudit(
      action: .created,
      entityType: .evidence,
      entityID: attachment.id.uuidString,
      entityLabel: attachment.fileName,
      summary: "Evidence attachment added.",
      afterDetail: attachment.auditDetail
    )
  }

  func markEvidenceReviewed(_ attachment: EvidenceAttachment) {
    guard let index = evidenceAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }
    let beforeDetail = evidenceAttachments[index].auditDetail
    evidenceAttachments[index].reviewState = .accepted
    persistEvidenceAttachments()
    logAudit(
      action: .reviewed,
      entityType: .evidence,
      entityID: evidenceAttachments[index].id.uuidString,
      entityLabel: evidenceAttachments[index].fileName,
      summary: "Evidence attachment marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: evidenceAttachments[index].auditDetail
    )
  }

  func removeEvidence(_ attachment: EvidenceAttachment) {
    guard let index = evidenceAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }
    let removed = evidenceAttachments.remove(at: index)
    persistEvidenceAttachments()
    logAudit(
      action: .removed,
      entityType: .evidence,
      entityID: removed.id.uuidString,
      entityLabel: removed.fileName,
      summary: "Evidence attachment removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func trackingEvents(for orderID: UUID) -> [CarrierTrackingEvent] {
    carrierTrackingEvents.filter { $0.orderID == orderID }
  }

  func addPlaceholderTrackingEvent(to order: TrackedOrder) {
    let event = CarrierTrackingEvent(
      orderID: order.id,
      carrier: order.carrier,
      trackingNumber: order.trackingNumber,
      eventTime: Self.auditTimestamp(),
      location: order.destination,
      status: "Manual tracking note",
      detail: "Placeholder carrier tracking event added for local review.",
      severity: .watch,
      source: .manual,
      reviewState: .needsReview
    )
    carrierTrackingEvents.insert(event, at: 0)
    persistCarrierTrackingEvents()
    logAudit(
      action: .created,
      entityType: .trackingEvent,
      entityID: event.id.uuidString,
      entityLabel: event.trackingNumber,
      summary: "Carrier tracking event added.",
      afterDetail: event.auditDetail
    )
  }

  func markTrackingEventReviewed(_ event: CarrierTrackingEvent) {
    guard let index = carrierTrackingEvents.firstIndex(where: { $0.id == event.id }) else { return }
    let beforeDetail = carrierTrackingEvents[index].auditDetail
    carrierTrackingEvents[index].reviewState = .accepted
    carrierTrackingEvents[index].severity = .info
    persistCarrierTrackingEvents()
    logAudit(
      action: .reviewed,
      entityType: .trackingEvent,
      entityID: carrierTrackingEvents[index].id.uuidString,
      entityLabel: carrierTrackingEvents[index].trackingNumber,
      summary: "Carrier tracking event marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: carrierTrackingEvents[index].auditDetail
    )
  }

  func removeTrackingEvent(_ event: CarrierTrackingEvent) {
    guard let index = carrierTrackingEvents.firstIndex(where: { $0.id == event.id }) else { return }
    let removed = carrierTrackingEvents.remove(at: index)
    persistCarrierTrackingEvents()
    logAudit(
      action: .removed,
      entityType: .trackingEvent,
      entityID: removed.id.uuidString,
      entityLabel: removed.trackingNumber,
      summary: "Carrier tracking event removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func addAutomationRulePlaceholder() {
    let rule = AutomationRule(
      name: "New local rule \(automationRules.count + 1)",
      triggerType: .manualReview,
      conditionSummary: "Define the local condition this rule should watch.",
      actionSummary: "Define the local action this rule should suggest.",
      isEnabled: false,
      lastRunDate: "Never",
      reviewState: .needsReview,
      runCount: 0
    )
    automationRules.insert(rule, at: 0)
    persistAutomationRules()
    logAudit(
      action: .created,
      entityType: .automationRule,
      entityID: rule.id.uuidString,
      entityLabel: rule.name,
      summary: "Automation rule placeholder added.",
      afterDetail: rule.auditDetail
    )
  }

  func toggleAutomationRule(_ rule: AutomationRule) {
    guard let index = automationRules.firstIndex(where: { $0.id == rule.id }) else { return }
    let beforeDetail = automationRules[index].auditDetail
    automationRules[index].isEnabled.toggle()
    persistAutomationRules()
    logAudit(
      action: automationRules[index].isEnabled ? .enabled : .disabled,
      entityType: .automationRule,
      entityID: automationRules[index].id.uuidString,
      entityLabel: automationRules[index].name,
      summary: automationRules[index].isEnabled ? "Automation rule enabled." : "Automation rule disabled.",
      beforeDetail: beforeDetail,
      afterDetail: automationRules[index].auditDetail
    )
  }

  func markAutomationRuleReviewed(_ rule: AutomationRule) {
    guard let index = automationRules.firstIndex(where: { $0.id == rule.id }) else { return }
    let beforeDetail = automationRules[index].auditDetail
    automationRules[index].reviewState = .accepted
    persistAutomationRules()
    logAudit(
      action: .reviewed,
      entityType: .automationRule,
      entityID: automationRules[index].id.uuidString,
      entityLabel: automationRules[index].name,
      summary: "Automation rule marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: automationRules[index].auditDetail
    )
  }

  func removeAutomationRule(_ rule: AutomationRule) {
    guard let index = automationRules.firstIndex(where: { $0.id == rule.id }) else { return }
    let removed = automationRules.remove(at: index)
    persistAutomationRules()
    logAudit(
      action: .removed,
      entityType: .automationRule,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "Automation rule removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func addSavedFilterPlaceholder(
    queryText: String,
    entityTypeFilter: SearchEntityType?,
    reviewStateFilter: ReviewState?
  ) {
    let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
    let ruleName = trimmedQuery.isEmpty ? "Saved search \(savedFilters.count + 1)" : "Search for \(trimmedQuery)"
    let filter = SavedFilter(
      name: ruleName,
      queryText: trimmedQuery,
      entityTypeFilter: entityTypeFilter,
      reviewStateFilter: reviewStateFilter,
      createdDate: Self.auditTimestamp(),
      isPinned: false
    )
    savedFilters.insert(filter, at: 0)
    persistSavedFilters()
    logAudit(
      action: .created,
      entityType: .savedFilter,
      entityID: filter.id.uuidString,
      entityLabel: filter.name,
      summary: "Saved search filter created.",
      afterDetail: filter.auditDetail
    )
  }

  func toggleSavedFilterPinned(_ filter: SavedFilter) {
    guard let index = savedFilters.firstIndex(where: { $0.id == filter.id }) else { return }
    let beforeDetail = savedFilters[index].auditDetail
    savedFilters[index].isPinned.toggle()
    persistSavedFilters()
    logAudit(
      action: savedFilters[index].isPinned ? .pinned : .unpinned,
      entityType: .savedFilter,
      entityID: savedFilters[index].id.uuidString,
      entityLabel: savedFilters[index].name,
      summary: savedFilters[index].isPinned ? "Saved search filter pinned." : "Saved search filter unpinned.",
      beforeDetail: beforeDetail,
      afterDetail: savedFilters[index].auditDetail
    )
  }

  func removeSavedFilter(_ filter: SavedFilter) {
    guard let index = savedFilters.firstIndex(where: { $0.id == filter.id }) else { return }
    let removed = savedFilters.remove(at: index)
    persistSavedFilters()
    logAudit(
      action: .removed,
      entityType: .savedFilter,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "Saved search filter removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func addReviewTaskPlaceholder() {
    let task = ReviewTask(
      title: "New follow-up task \(reviewTasks.count + 1)",
      summary: "Define the local review or escalation work required.",
      linkedEntityType: .order,
      linkedEntityID: orders.first?.id.uuidString ?? "Unlinked",
      priority: .normal,
      dueDate: "Today",
      assignee: "Operations",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(task, summary: "Review task placeholder added.")
  }

  func createReviewTask(
    linkedEntityType: ReviewTaskLinkedEntityType,
    linkedEntityID: String,
    label: String,
    summary: String,
    priority: TaskPriority = .normal,
    assignee: String = "Operations"
  ) {
    let task = ReviewTask(
      title: "Follow up \(label)",
      summary: summary,
      linkedEntityType: linkedEntityType,
      linkedEntityID: linkedEntityID,
      priority: priority,
      dueDate: priority == .urgent ? "Today" : "Tomorrow",
      assignee: assignee,
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(task, summary: "Review task created from \(linkedEntityType.rawValue.lowercased()).")
  }

  func createReviewTask(from order: TrackedOrder) {
    createReviewTask(
      linkedEntityType: .order,
      linkedEntityID: order.id.uuidString,
      label: order.orderNumber,
      summary: "Follow up \(order.store) order \(order.orderNumber): \(order.latestStatus)",
      priority: order.status == .exception ? .urgent : .high,
      assignee: order.customer
    )
  }

  func createReviewTask(from email: ForwardedEmailIntake) {
    createReviewTask(
      linkedEntityType: .intakeEmail,
      linkedEntityID: email.id.uuidString,
      label: email.auditLabel,
      summary: "Review forwarded email from \(email.sender): \(email.subject)",
      priority: email.reviewState == .needsReview ? .high : .normal
    )
  }

  func createReviewTask(from event: CarrierTrackingEvent) {
    createReviewTask(
      linkedEntityType: .trackingEvent,
      linkedEntityID: event.id.uuidString,
      label: event.trackingNumber,
      summary: "\(event.carrier) reported \(event.status) at \(event.location). \(event.detail)",
      priority: event.severity == .critical ? .urgent : .high
    )
  }

  func createReviewTask(from attachment: EvidenceAttachment) {
    createReviewTask(
      linkedEntityType: .evidence,
      linkedEntityID: attachment.id.uuidString,
      label: attachment.fileName,
      summary: "Review evidence attachment: \(attachment.summary)",
      priority: attachment.reviewState == .needsReview ? .high : .normal
    )
  }

  func createReviewTask(from rule: AutomationRule) {
    createReviewTask(
      linkedEntityType: .automationRule,
      linkedEntityID: rule.id.uuidString,
      label: rule.name,
      summary: "Review automation rule intent: \(rule.conditionSummary) \(rule.actionSummary)",
      priority: rule.reviewState == .needsReview ? .high : .normal
    )
  }

  func createReviewTask(from filter: SavedFilter) {
    createReviewTask(
      linkedEntityType: .savedFilter,
      linkedEntityID: filter.id.uuidString,
      label: filter.name,
      summary: "Review saved search filter: \(filter.auditDetail)",
      priority: filter.isPinned ? .high : .normal
    )
  }

  func createReviewTask(from auditEvent: AuditEvent) {
    createReviewTask(
      linkedEntityType: .auditEvent,
      linkedEntityID: auditEvent.id.uuidString,
      label: auditEvent.entityLabel,
      summary: "Follow up audit event: \(auditEvent.summary)",
      priority: auditEvent.action == .removed ? .high : .normal
    )
  }

  func createReviewTaskFromLocalDataHygiene() {
    let summary = localDataHygieneSummary
    let taskPriority: TaskPriority = summary.signalCount > 10 ? .high : summary.signalCount > 0 ? .normal : .low
    let metricLines = summary.metrics.map { "\($0.title): \($0.value) - \($0.detail)" }
    let exampleLines = summary.examples.isEmpty
      ? ["No example records are currently flagged."]
      : summary.examples.map { "Example: \($0)" }
    let task = ReviewTask(
      title: summary.signalCount == 0 ? "Confirm local data hygiene" : "Review local data hygiene signals",
      summary: ([summary.verdict, summary.detail, "Next: \(summary.nextAction)"] + metricLines + exampleLines + summary.boundaries).joined(separator: "\n"),
      linkedEntityType: .integration,
      linkedEntityID: "local-data-hygiene",
      priority: taskPriority,
      dueDate: taskPriority == .high ? "Today" : "Tomorrow",
      assignee: "ParcelOps Operations",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(
      task,
      summary: "Review task created from local data hygiene summary."
    )
  }

  func createReviewTaskFromOperatorTestSession() {
    let readiness = spaceMailMVPReadinessSummary
    let qa = spaceMailQACheckSummary
    let hygiene = localDataHygieneSummary
    let incompleteReadiness = readiness.items.filter { !$0.isComplete }.map { "Readiness: \($0.title) - \($0.detail)" }
    let incompleteQA = qa.checks.filter { !$0.isComplete }.map { "QA: \($0.title) - \($0.evidence)" }
    let latestSpaceMail = spaceMailIntakeHealthSummaries.first
    let refreshLine = latestSpaceMail.map {
      "Latest SpaceMail refresh: \($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.duplicateCount) duplicate, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount + $0.uncertainCount) uncertain."
    } ?? "Latest SpaceMail refresh: no summary available."
    let handoffLine = "Current handoff: \(orders.filter(\.isInboxCreatedLocalOrder).count) Inbox-created orders, \(Set(intakeEmails.compactMap(\.linkedOrderID)).count) linked intake sources, \(openWorkbenchItems.count) open Workbench items, \(reviewTasksNeedingAttention.count + handoffNotesNeedingAttention.count) task/handoff items."
    let summaryLines = [
      readiness.verdict,
      readiness.detail,
      "Next: \(readiness.nextAction)",
      "RC evidence: \(qa.completedCount)/\(qa.totalCount) checks complete.",
      refreshLine,
      handoffLine,
      "Data hygiene: \(hygiene.signalCount) signal\(hygiene.signalCount == 1 ? "" : "s"). \(hygiene.nextAction)"
    ] + incompleteReadiness + incompleteQA + hygiene.boundaries

    let taskPriority: TaskPriority
    if readiness.completedCount <= max(readiness.totalCount - 3, 0) || qa.completedCount <= max(qa.totalCount - 3, 0) {
      taskPriority = .high
    } else if readiness.completedCount < readiness.totalCount || qa.completedCount < qa.totalCount || hygiene.signalCount > 0 {
      taskPriority = .normal
    } else {
      taskPriority = .low
    }

    let task = ReviewTask(
      title: taskPriority == .low ? "Confirm operator MVP test pass" : "Complete operator MVP test follow-up",
      summary: summaryLines.joined(separator: "\n"),
      linkedEntityType: .integration,
      linkedEntityID: "operator-test-session",
      priority: taskPriority,
      dueDate: taskPriority == .high ? "Today" : "Tomorrow",
      assignee: "ParcelOps Operations",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(
      task,
      summary: "Review task created from operator MVP test-session checklist."
    )
  }

  func createReviewTaskFromSpaceMailReleaseSnapshot() {
    let snapshot = spaceMailReleaseSnapshot
    let taskPriority: TaskPriority
    switch snapshot.tone {
    case "warning":
      taskPriority = .high
    case "attention":
      taskPriority = .normal
    default:
      taskPriority = .low
    }

    let taskTitle = snapshot.tone == "success" ? "Confirm SpaceMail MVP release snapshot" : "Resolve SpaceMail MVP release snapshot gaps"
    if let existingIndex = reviewTasks.firstIndex(where: {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "spacemail-release-snapshot"
        && $0.status != .completed
    }) {
      let beforeDetail = reviewTasks[existingIndex].auditDetail
      reviewTasks[existingIndex].title = taskTitle
      reviewTasks[existingIndex].summary = snapshot.reportText
      reviewTasks[existingIndex].priority = taskPriority
      reviewTasks[existingIndex].dueDate = taskPriority == .high ? "Today" : "Tomorrow"
      reviewTasks[existingIndex].assignee = "ParcelOps Operations"
      reviewTasks[existingIndex].reviewState = .needsReview
      persistReviewTasks()
      logAudit(
        action: .edited,
        entityType: .reviewTask,
        entityID: reviewTasks[existingIndex].id.uuidString,
        entityLabel: reviewTasks[existingIndex].title,
        summary: "Existing SpaceMail MVP release snapshot review task refreshed.",
        beforeDetail: beforeDetail,
        afterDetail: "\(reviewTasks[existingIndex].auditDetail)\nRefreshed from current local release snapshot. No duplicate task was created."
      )
      return
    }

    let task = ReviewTask(
      title: taskTitle,
      summary: snapshot.reportText,
      linkedEntityType: .integration,
      linkedEntityID: "spacemail-release-snapshot",
      priority: taskPriority,
      dueDate: taskPriority == .high ? "Today" : "Tomorrow",
      assignee: "ParcelOps Operations",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(
      task,
      summary: "Review task created from SpaceMail MVP release snapshot."
    )
  }

  func createReviewTaskFromMailboxReleaseReadinessSnapshot() {
    let snapshot = mailboxReleaseReadinessSnapshot
    let taskPriority: TaskPriority
    switch snapshot.tone {
    case "warning":
      taskPriority = .high
    case "attention":
      taskPriority = .normal
    default:
      taskPriority = .low
    }

    let taskTitle = snapshot.tone == "success" ? "Confirm mailbox release readiness" : "Resolve mailbox release readiness gaps"
    if let existingIndex = reviewTasks.firstIndex(where: {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "mailbox-release-readiness"
        && $0.status != .completed
    }) {
      let beforeDetail = reviewTasks[existingIndex].auditDetail
      reviewTasks[existingIndex].title = taskTitle
      reviewTasks[existingIndex].summary = snapshot.reportText
      reviewTasks[existingIndex].priority = taskPriority
      reviewTasks[existingIndex].dueDate = taskPriority == .high ? "Today" : "Tomorrow"
      reviewTasks[existingIndex].assignee = "ParcelOps Operations"
      reviewTasks[existingIndex].reviewState = .needsReview
      persistReviewTasks()
      logAudit(
        action: .edited,
        entityType: .reviewTask,
        entityID: reviewTasks[existingIndex].id.uuidString,
        entityLabel: reviewTasks[existingIndex].title,
        summary: "Existing mailbox release readiness review task refreshed.",
        beforeDetail: beforeDetail,
        afterDetail: "\(reviewTasks[existingIndex].auditDetail)\nRefreshed from current mailbox release readiness snapshot. No duplicate task was created."
      )
      return
    }

    let task = ReviewTask(
      title: taskTitle,
      summary: snapshot.reportText,
      linkedEntityType: .integration,
      linkedEntityID: "mailbox-release-readiness",
      priority: taskPriority,
      dueDate: taskPriority == .high ? "Today" : "Tomorrow",
      assignee: "ParcelOps Operations",
      status: .open,
      createdDate: Self.auditTimestamp(),
      completedDate: nil,
      reviewState: .needsReview
    )
    addReviewTask(
      task,
      summary: "Review task created from mailbox release readiness snapshot."
    )
  }

  func updateReviewTask(_ task: ReviewTask) {
    guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { return }
    let beforeDetail = reviewTasks[index].auditDetail
    reviewTasks[index] = task
    persistReviewTasks()
    logAudit(
      action: .edited,
      entityType: .reviewTask,
      entityID: task.id.uuidString,
      entityLabel: task.title,
      summary: "Review task details updated.",
      beforeDetail: beforeDetail,
      afterDetail: task.auditDetail
    )
  }

  func completeReviewTask(_ task: ReviewTask) {
    guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { return }
    let beforeDetail = reviewTasks[index].auditDetail
    reviewTasks[index].status = .completed
    reviewTasks[index].completedDate = Self.auditTimestamp()
    reviewTasks[index].reviewState = .accepted
    persistReviewTasks()
    logAudit(
      action: .completed,
      entityType: .reviewTask,
      entityID: reviewTasks[index].id.uuidString,
      entityLabel: reviewTasks[index].title,
      summary: "Review task completed.",
      beforeDetail: beforeDetail,
      afterDetail: reviewTasks[index].auditDetail
    )
  }

  func reopenReviewTask(_ task: ReviewTask) {
    guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { return }
    let beforeDetail = reviewTasks[index].auditDetail
    reviewTasks[index].status = .open
    reviewTasks[index].completedDate = nil
    reviewTasks[index].reviewState = .needsReview
    persistReviewTasks()
    logAudit(
      action: .reopened,
      entityType: .reviewTask,
      entityID: reviewTasks[index].id.uuidString,
      entityLabel: reviewTasks[index].title,
      summary: "Review task reopened.",
      beforeDetail: beforeDetail,
      afterDetail: reviewTasks[index].auditDetail
    )
  }

  func markReviewTaskReviewed(_ task: ReviewTask) {
    guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { return }
    let beforeDetail = reviewTasks[index].auditDetail
    reviewTasks[index].reviewState = .accepted
    persistReviewTasks()
    logAudit(
      action: .reviewed,
      entityType: .reviewTask,
      entityID: reviewTasks[index].id.uuidString,
      entityLabel: reviewTasks[index].title,
      summary: "Review task marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: reviewTasks[index].auditDetail
    )
  }

  func removeReviewTask(_ task: ReviewTask) {
    guard let index = reviewTasks.firstIndex(where: { $0.id == task.id }) else { return }
    let removed = reviewTasks.remove(at: index)
    persistReviewTasks()
    logAudit(
      action: .removed,
      entityType: .reviewTask,
      entityID: removed.id.uuidString,
      entityLabel: removed.title,
      summary: "Review task removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func tasks(for linkedEntityType: ReviewTaskLinkedEntityType, linkedEntityID: String) -> [ReviewTask] {
    reviewTasks.filter { $0.linkedEntityType == linkedEntityType && $0.linkedEntityID == linkedEntityID }
  }

  func addHandoffNotePlaceholder() {
    let note = HandoffNote(
      title: "New handoff note \(handoffNotes.count + 1)",
      summary: "Describe what the next team or shift needs to know.",
      linkedEntityType: .order,
      linkedEntityID: orders.first?.id.uuidString ?? "Unlinked",
      priority: .normal,
      assignee: "Operations",
      createdDate: Self.auditTimestamp(),
      dueDate: "Tomorrow",
      status: .open,
      reviewState: .needsReview,
      notes: "Add local-only handoff details."
    )
    handoffNotes.insert(note, at: 0)
    persistHandoffNotes()
    logAudit(action: .created, entityType: .handoffNote, entityID: note.id.uuidString, entityLabel: note.title, summary: "Handoff note placeholder added.", afterDetail: note.auditDetail)
  }

  func updateHandoffNote(_ note: HandoffNote) {
    guard let index = handoffNotes.firstIndex(where: { $0.id == note.id }) else { return }
    let beforeDetail = handoffNotes[index].auditDetail
    handoffNotes[index] = note
    persistHandoffNotes()
    logAudit(action: .edited, entityType: .handoffNote, entityID: note.id.uuidString, entityLabel: note.title, summary: "Handoff note details updated.", beforeDetail: beforeDetail, afterDetail: note.auditDetail)
  }

  func acknowledgeHandoffNote(_ note: HandoffNote) {
    updateHandoffNoteState(note, status: .inProgress, reviewState: .monitor, action: .acknowledged, summary: "Handoff note acknowledged.")
  }

  func completeHandoffNote(_ note: HandoffNote) {
    updateHandoffNoteState(note, status: .completed, reviewState: .accepted, action: .completed, summary: "Handoff note completed.")
  }

  func reopenHandoffNote(_ note: HandoffNote) {
    updateHandoffNoteState(note, status: .open, reviewState: .needsReview, action: .reopened, summary: "Handoff note reopened.")
  }

  func markHandoffNoteReviewed(_ note: HandoffNote) {
    guard let index = handoffNotes.firstIndex(where: { $0.id == note.id }) else { return }
    let beforeDetail = handoffNotes[index].auditDetail
    handoffNotes[index].reviewState = .accepted
    persistHandoffNotes()
    logAudit(action: .reviewed, entityType: .handoffNote, entityID: handoffNotes[index].id.uuidString, entityLabel: handoffNotes[index].title, summary: "Handoff note marked reviewed.", beforeDetail: beforeDetail, afterDetail: handoffNotes[index].auditDetail)
  }

  func removeHandoffNote(_ note: HandoffNote) {
    guard let index = handoffNotes.firstIndex(where: { $0.id == note.id }) else { return }
    let removed = handoffNotes.remove(at: index)
    persistHandoffNotes()
    logAudit(action: .removed, entityType: .handoffNote, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Handoff note removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from note: HandoffNote) {
    createReviewTask(linkedEntityType: .handoffNote, linkedEntityID: note.id.uuidString, label: note.title, summary: "Follow up handoff note: \(note.summary)", priority: note.priority)
  }

  func createDraftMessage(from note: HandoffNote) {
    createDraftMessage(linkedEntityType: .handoffNote, linkedEntityID: note.id.uuidString, label: note.title, recipient: "operations@parcelops.example")
  }

  private func updateHandoffNoteState(_ note: HandoffNote, status: TaskStatus, reviewState: ReviewState, action: AuditAction, summary: String) {
    guard let index = handoffNotes.firstIndex(where: { $0.id == note.id }) else { return }
    let beforeDetail = handoffNotes[index].auditDetail
    handoffNotes[index].status = status
    handoffNotes[index].reviewState = reviewState
    persistHandoffNotes()
    logAudit(action: action, entityType: .handoffNote, entityID: handoffNotes[index].id.uuidString, entityLabel: handoffNotes[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: handoffNotes[index].auditDetail)
  }

  func policies(for linkedEntityType: ReviewTaskLinkedEntityType) -> [SLAPolicy] {
    slaPolicies.filter { $0.linkedEntityType == linkedEntityType && $0.isEnabled }
  }

  func addSLAPolicyPlaceholder() {
    let policy = SLAPolicy(
      name: "New SLA policy \(slaPolicies.count + 1)",
      linkedEntityType: .order,
      conditionSummary: "Define the local condition this policy should watch.",
      responseTarget: "Respond today",
      resolutionTarget: "Resolve within 1 business day",
      priority: .normal,
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastEvaluatedDate: "Never",
      matchCount: 0,
      reviewState: .needsReview
    )
    slaPolicies.insert(policy, at: 0)
    persistSLAPolicies()
    logAudit(
      action: .created,
      entityType: .slaPolicy,
      entityID: policy.id.uuidString,
      entityLabel: policy.name,
      summary: "SLA policy placeholder added.",
      afterDetail: policy.auditDetail
    )
  }

  func updateSLAPolicy(_ policy: SLAPolicy) {
    guard let index = slaPolicies.firstIndex(where: { $0.id == policy.id }) else { return }
    let beforeDetail = slaPolicies[index].auditDetail
    slaPolicies[index] = policy
    persistSLAPolicies()
    logAudit(
      action: .edited,
      entityType: .slaPolicy,
      entityID: policy.id.uuidString,
      entityLabel: policy.name,
      summary: "SLA policy details updated.",
      beforeDetail: beforeDetail,
      afterDetail: policy.auditDetail
    )
  }

  func toggleSLAPolicy(_ policy: SLAPolicy) {
    guard let index = slaPolicies.firstIndex(where: { $0.id == policy.id }) else { return }
    let beforeDetail = slaPolicies[index].auditDetail
    slaPolicies[index].isEnabled.toggle()
    persistSLAPolicies()
    logAudit(
      action: slaPolicies[index].isEnabled ? .enabled : .disabled,
      entityType: .slaPolicy,
      entityID: slaPolicies[index].id.uuidString,
      entityLabel: slaPolicies[index].name,
      summary: slaPolicies[index].isEnabled ? "SLA policy enabled." : "SLA policy disabled.",
      beforeDetail: beforeDetail,
      afterDetail: slaPolicies[index].auditDetail
    )
  }

  func markSLAPolicyReviewed(_ policy: SLAPolicy) {
    guard let index = slaPolicies.firstIndex(where: { $0.id == policy.id }) else { return }
    let beforeDetail = slaPolicies[index].auditDetail
    slaPolicies[index].reviewState = .accepted
    persistSLAPolicies()
    logAudit(
      action: .reviewed,
      entityType: .slaPolicy,
      entityID: slaPolicies[index].id.uuidString,
      entityLabel: slaPolicies[index].name,
      summary: "SLA policy marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: slaPolicies[index].auditDetail
    )
  }

  func evaluateSLAPolicyPlaceholder(_ policy: SLAPolicy) {
    guard let index = slaPolicies.firstIndex(where: { $0.id == policy.id }) else { return }
    let beforeDetail = slaPolicies[index].auditDetail
    slaPolicies[index].lastEvaluatedDate = Self.auditTimestamp()
    slaPolicies[index].matchCount += 1
    persistSLAPolicies()
    logAudit(
      action: .evaluated,
      entityType: .slaPolicy,
      entityID: slaPolicies[index].id.uuidString,
      entityLabel: slaPolicies[index].name,
      summary: "SLA policy manually evaluated locally.",
      beforeDetail: beforeDetail,
      afterDetail: slaPolicies[index].auditDetail
    )
  }

  func removeSLAPolicy(_ policy: SLAPolicy) {
    guard let index = slaPolicies.firstIndex(where: { $0.id == policy.id }) else { return }
    let removed = slaPolicies.remove(at: index)
    persistSLAPolicies()
    logAudit(
      action: .removed,
      entityType: .slaPolicy,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "SLA policy removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func playbooks(for linkedEntityType: ReviewTaskLinkedEntityType) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { $0.linkedEntityType == linkedEntityType && $0.isEnabled }
  }

  func suggestedPlaybooks(for issue: ReconciliationIssue) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.issueType == issue.issueType
          || issue.sourceEntityType.reviewTaskLinkedEntityType.map { playbook.linkedEntityType == $0 } == true
          || issue.targetEntityType?.reviewTaskLinkedEntityType.map { playbook.linkedEntityType == $0 } == true)
    }
  }

  func suggestedPlaybooks(for issue: ValidationIssue) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.linkedEntityType == issue.linkedEntityType
          || playbook.triggerSummary.localizedCaseInsensitiveContains(issue.status.rawValue)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(issue.entityType.rawValue))
    }
  }

  func suggestedPlaybooks(for item: ImportQueueItem) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.linkedEntityType == .importQueueItem
          || (item.importStatus == .blocked && playbook.priority == .high)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(item.importStatus.rawValue)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(item.detectedTrackingNumber))
    }
  }

  func suggestedPlaybooks(for candidate: AcceptanceCandidate) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.linkedEntityType == candidate.reviewTaskLinkedEntityType
          || (candidate.decision == .accepted && candidate.suggestedLinkedOrderID == nil && playbook.issueType == .acceptedWithoutOrder)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(candidate.decision.rawValue))
    }
  }

  func suggestedPlaybooks(for group: ShipmentGroup) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.linkedEntityType == .shipmentGroup
          || (group.primaryOrderID == nil && playbook.issueType == .shipmentGroupMissingPrimary)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(group.statusSummary))
    }
  }

  func suggestedPlaybooks(for order: TrackedOrder) -> [ExceptionPlaybook] {
    exceptionPlaybooks.filter { playbook in
      playbook.isEnabled
        && (playbook.linkedEntityType == .order
          || (order.trackingNumber.isPlaceholderValidationValue && playbook.issueType == .missingLink)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(order.status.rawValue)
          || playbook.triggerSummary.localizedCaseInsensitiveContains(order.latestStatus))
    }
  }

  func addExceptionPlaybookPlaceholder() {
    let playbook = ExceptionPlaybook(
      name: "New exception playbook \(exceptionPlaybooks.count + 1)",
      issueType: .missingLink,
      linkedEntityType: .order,
      triggerSummary: "Define the local exception trigger.",
      recommendedSteps: "Add the local review steps staff should follow before changing operational records.",
      escalationContact: "Operations",
      priority: .normal,
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    )
    exceptionPlaybooks.insert(playbook, at: 0)
    persistExceptionPlaybooks()
    logAudit(action: .created, entityType: .exceptionPlaybook, entityID: playbook.id.uuidString, entityLabel: playbook.name, summary: "Exception playbook placeholder added.", afterDetail: playbook.auditDetail)
  }

  func updateExceptionPlaybook(_ playbook: ExceptionPlaybook) {
    guard let index = exceptionPlaybooks.firstIndex(where: { $0.id == playbook.id }) else { return }
    let beforeDetail = exceptionPlaybooks[index].auditDetail
    exceptionPlaybooks[index] = playbook
    persistExceptionPlaybooks()
    logAudit(action: .edited, entityType: .exceptionPlaybook, entityID: playbook.id.uuidString, entityLabel: playbook.name, summary: "Exception playbook details updated.", beforeDetail: beforeDetail, afterDetail: playbook.auditDetail)
  }

  func toggleExceptionPlaybook(_ playbook: ExceptionPlaybook) {
    guard let index = exceptionPlaybooks.firstIndex(where: { $0.id == playbook.id }) else { return }
    let beforeDetail = exceptionPlaybooks[index].auditDetail
    exceptionPlaybooks[index].isEnabled.toggle()
    persistExceptionPlaybooks()
    logAudit(action: exceptionPlaybooks[index].isEnabled ? .enabled : .disabled, entityType: .exceptionPlaybook, entityID: exceptionPlaybooks[index].id.uuidString, entityLabel: exceptionPlaybooks[index].name, summary: exceptionPlaybooks[index].isEnabled ? "Exception playbook enabled." : "Exception playbook disabled.", beforeDetail: beforeDetail, afterDetail: exceptionPlaybooks[index].auditDetail)
  }

  func markExceptionPlaybookReviewed(_ playbook: ExceptionPlaybook) {
    guard let index = exceptionPlaybooks.firstIndex(where: { $0.id == playbook.id }) else { return }
    let beforeDetail = exceptionPlaybooks[index].auditDetail
    exceptionPlaybooks[index].reviewState = .accepted
    exceptionPlaybooks[index].lastReviewedDate = Self.auditTimestamp()
    persistExceptionPlaybooks()
    logAudit(action: .reviewed, entityType: .exceptionPlaybook, entityID: exceptionPlaybooks[index].id.uuidString, entityLabel: exceptionPlaybooks[index].name, summary: "Exception playbook marked reviewed.", beforeDetail: beforeDetail, afterDetail: exceptionPlaybooks[index].auditDetail)
  }

  func removeExceptionPlaybook(_ playbook: ExceptionPlaybook) {
    guard let index = exceptionPlaybooks.firstIndex(where: { $0.id == playbook.id }) else { return }
    let removed = exceptionPlaybooks.remove(at: index)
    persistExceptionPlaybooks()
    logAudit(action: .removed, entityType: .exceptionPlaybook, entityID: removed.id.uuidString, entityLabel: removed.name, summary: "Exception playbook removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from playbook: ExceptionPlaybook) {
    createReviewTask(linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString, label: playbook.name, summary: "Review exception playbook: \(playbook.triggerSummary)", priority: playbook.priority)
  }

  func createDraftMessage(from playbook: ExceptionPlaybook) {
    createDraftMessage(linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString, label: playbook.name, recipient: "operations@parcelops.example")
  }

  func addCommunicationTemplatePlaceholder() {
    let template = CommunicationTemplate(
      name: "New communication template \(communicationTemplates.count + 1)",
      linkedEntityType: .order,
      subjectTemplate: "Update for {{record}}",
      bodyTemplate: "Hi team,\n\nPlease review the latest ParcelOps update for {{record}}.\n\nThanks.",
      channel: .email,
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastUsedDate: "Never",
      usageCount: 0,
      reviewState: .needsReview
    )
    communicationTemplates.insert(template, at: 0)
    persistCommunicationTemplates()
    logAudit(
      action: .created,
      entityType: .communicationTemplate,
      entityID: template.id.uuidString,
      entityLabel: template.name,
      summary: "Communication template placeholder added.",
      afterDetail: template.auditDetail
    )
  }

  func updateCommunicationTemplate(_ template: CommunicationTemplate) {
    guard let index = communicationTemplates.firstIndex(where: { $0.id == template.id }) else { return }
    let beforeDetail = communicationTemplates[index].auditDetail
    communicationTemplates[index] = template
    persistCommunicationTemplates()
    logAudit(
      action: .edited,
      entityType: .communicationTemplate,
      entityID: template.id.uuidString,
      entityLabel: template.name,
      summary: "Communication template details updated.",
      beforeDetail: beforeDetail,
      afterDetail: template.auditDetail
    )
  }

  func toggleCommunicationTemplate(_ template: CommunicationTemplate) {
    guard let index = communicationTemplates.firstIndex(where: { $0.id == template.id }) else { return }
    let beforeDetail = communicationTemplates[index].auditDetail
    communicationTemplates[index].isEnabled.toggle()
    persistCommunicationTemplates()
    logAudit(
      action: communicationTemplates[index].isEnabled ? .enabled : .disabled,
      entityType: .communicationTemplate,
      entityID: communicationTemplates[index].id.uuidString,
      entityLabel: communicationTemplates[index].name,
      summary: communicationTemplates[index].isEnabled ? "Communication template enabled." : "Communication template disabled.",
      beforeDetail: beforeDetail,
      afterDetail: communicationTemplates[index].auditDetail
    )
  }

  func markCommunicationTemplateReviewed(_ template: CommunicationTemplate) {
    guard let index = communicationTemplates.firstIndex(where: { $0.id == template.id }) else { return }
    let beforeDetail = communicationTemplates[index].auditDetail
    communicationTemplates[index].reviewState = .accepted
    persistCommunicationTemplates()
    logAudit(
      action: .reviewed,
      entityType: .communicationTemplate,
      entityID: communicationTemplates[index].id.uuidString,
      entityLabel: communicationTemplates[index].name,
      summary: "Communication template marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: communicationTemplates[index].auditDetail
    )
  }

  func removeCommunicationTemplate(_ template: CommunicationTemplate) {
    guard let index = communicationTemplates.firstIndex(where: { $0.id == template.id }) else { return }
    let removed = communicationTemplates.remove(at: index)
    persistCommunicationTemplates()
    logAudit(
      action: .removed,
      entityType: .communicationTemplate,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "Communication template removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func addDraftMessagePlaceholder() {
    let template = communicationTemplates.first
    createDraftMessage(
      linkedEntityType: template?.linkedEntityType ?? .order,
      linkedEntityID: orders.first?.id.uuidString ?? "Unlinked",
      label: orders.first?.orderNumber ?? "Manual draft",
      recipient: "operations@parcelops.example",
      template: template
    )
  }

  func createDraftMessage(
    linkedEntityType: ReviewTaskLinkedEntityType,
    linkedEntityID: String,
    label: String,
    recipient: String,
    template: CommunicationTemplate? = nil
  ) {
    let selectedTemplate = template ?? communicationTemplates.first { $0.linkedEntityType == linkedEntityType && $0.isEnabled } ?? communicationTemplates.first
    let subject = selectedTemplate?.subjectTemplate.replacingOccurrences(of: "{{record}}", with: label) ?? "ParcelOps update for \(label)"
    let body = selectedTemplate?.bodyTemplate.replacingOccurrences(of: "{{record}}", with: label) ?? "Please review the local ParcelOps record \(label)."
    let draft = DraftMessage(
      linkedEntityType: linkedEntityType,
      linkedEntityID: linkedEntityID,
      templateID: selectedTemplate?.id,
      recipient: recipient,
      subject: subject,
      body: body,
      channel: selectedTemplate?.channel ?? .email,
      createdDate: Self.auditTimestamp(),
      status: .draft,
      reviewState: .needsReview
    )
    draftMessages.insert(draft, at: 0)
    persistDraftMessages()

    if let selectedTemplate, let index = communicationTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
      communicationTemplates[index].lastUsedDate = Self.auditTimestamp()
      communicationTemplates[index].usageCount += 1
      persistCommunicationTemplates()
    }

    logAudit(
      action: .created,
      entityType: .draftMessage,
      entityID: draft.id.uuidString,
      entityLabel: draft.subject,
      summary: "Draft message created locally.",
      afterDetail: draft.auditDetail
    )
  }

  func createDraftMessage(from order: TrackedOrder) {
    createDraftMessage(linkedEntityType: .order, linkedEntityID: order.id.uuidString, label: order.orderNumber, recipient: order.recipientEmail)
  }

  func createDraftMessage(from email: ForwardedEmailIntake) {
    createDraftMessage(linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, label: email.auditLabel, recipient: email.sender)
  }

  func createDraftMessage(from event: CarrierTrackingEvent) {
    createDraftMessage(linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString, label: event.trackingNumber, recipient: "carrier-support@parcelops.example")
  }

  func createDraftMessage(from attachment: EvidenceAttachment) {
    createDraftMessage(linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString, label: attachment.fileName, recipient: "records@parcelops.example")
  }

  func createDraftMessage(from task: ReviewTask) {
    createDraftMessage(linkedEntityType: .reviewTask, linkedEntityID: task.id.uuidString, label: task.title, recipient: task.assignee)
  }

  func createDraftMessage(from policy: SLAPolicy) {
    createDraftMessage(linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString, label: policy.name, recipient: "operations@parcelops.example")
  }

  func updateDraftMessage(_ draft: DraftMessage) {
    guard let index = draftMessages.firstIndex(where: { $0.id == draft.id }) else { return }
    let beforeDetail = draftMessages[index].auditDetail
    draftMessages[index] = draft
    persistDraftMessages()
    logAudit(
      action: .edited,
      entityType: .draftMessage,
      entityID: draft.id.uuidString,
      entityLabel: draft.subject,
      summary: "Draft message details updated.",
      beforeDetail: beforeDetail,
      afterDetail: draft.auditDetail
    )
  }

  func markDraftMessageReady(_ draft: DraftMessage) {
    updateDraftMessageState(draft, status: .ready, reviewState: .accepted, action: .reviewed, summary: "Draft message marked ready.")
  }

  func markDraftMessageSentLocally(_ draft: DraftMessage) {
    updateDraftMessageState(draft, status: .sentLocally, reviewState: .accepted, action: .completed, summary: "Draft message marked sent locally.")
  }

  func reopenDraftMessage(_ draft: DraftMessage) {
    updateDraftMessageState(draft, status: .reopened, reviewState: .needsReview, action: .reopened, summary: "Draft message reopened.")
  }

  func removeDraftMessage(_ draft: DraftMessage) {
    guard let index = draftMessages.firstIndex(where: { $0.id == draft.id }) else { return }
    let removed = draftMessages.remove(at: index)
    persistDraftMessages()
    logAudit(
      action: .removed,
      entityType: .draftMessage,
      entityID: removed.id.uuidString,
      entityLabel: removed.subject,
      summary: "Draft message removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func addContactDirectoryEntryPlaceholder() {
    let contact = ContactDirectoryEntry(
      name: "New contact \(contactDirectoryEntries.count + 1)",
      organisation: "Unassigned organisation",
      role: "Operations contact",
      email: "contact@parcelops.example",
      phone: "Not recorded",
      channelPreference: .email,
      linkedEntityType: .supplier,
      linkedEntityID: "Unlinked",
      notes: "Local placeholder contact awaiting review.",
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastContactedDate: "Never",
      reviewState: .needsReview
    )
    contactDirectoryEntries.insert(contact, at: 0)
    persistContactDirectoryEntries()
    logAudit(
      action: .created,
      entityType: .contactDirectoryEntry,
      entityID: contact.id.uuidString,
      entityLabel: contact.name,
      summary: "Contact directory entry placeholder added.",
      afterDetail: contact.auditDetail
    )
  }

  func addContactDirectoryEntry(linkedEntityType: ContactLinkedEntityType, linkedEntityID: String, label: String) {
    let contact = ContactDirectoryEntry(
      name: "\(label) contact",
      organisation: label,
      role: "Follow-up contact",
      email: "contact@parcelops.example",
      phone: "Not recorded",
      channelPreference: .email,
      linkedEntityType: linkedEntityType,
      linkedEntityID: linkedEntityID,
      notes: "Local contact created from \(linkedEntityType.rawValue.lowercased()) workflow.",
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastContactedDate: "Never",
      reviewState: .needsReview
    )
    contactDirectoryEntries.insert(contact, at: 0)
    persistContactDirectoryEntries()
    logAudit(
      action: .created,
      entityType: .contactDirectoryEntry,
      entityID: contact.id.uuidString,
      entityLabel: contact.name,
      summary: "Contact directory entry created from workflow.",
      afterDetail: contact.auditDetail
    )
  }

  func updateContactDirectoryEntry(_ contact: ContactDirectoryEntry) {
    guard let index = contactDirectoryEntries.firstIndex(where: { $0.id == contact.id }) else { return }
    let beforeDetail = contactDirectoryEntries[index].auditDetail
    contactDirectoryEntries[index] = contact
    persistContactDirectoryEntries()
    logAudit(
      action: .edited,
      entityType: .contactDirectoryEntry,
      entityID: contact.id.uuidString,
      entityLabel: contact.name,
      summary: "Contact directory entry details updated.",
      beforeDetail: beforeDetail,
      afterDetail: contact.auditDetail
    )
  }

  func toggleContactDirectoryEntry(_ contact: ContactDirectoryEntry) {
    guard let index = contactDirectoryEntries.firstIndex(where: { $0.id == contact.id }) else { return }
    let beforeDetail = contactDirectoryEntries[index].auditDetail
    contactDirectoryEntries[index].isEnabled.toggle()
    persistContactDirectoryEntries()
    logAudit(
      action: contactDirectoryEntries[index].isEnabled ? .enabled : .disabled,
      entityType: .contactDirectoryEntry,
      entityID: contactDirectoryEntries[index].id.uuidString,
      entityLabel: contactDirectoryEntries[index].name,
      summary: contactDirectoryEntries[index].isEnabled ? "Contact enabled." : "Contact disabled.",
      beforeDetail: beforeDetail,
      afterDetail: contactDirectoryEntries[index].auditDetail
    )
  }

  func markContactDirectoryEntryReviewed(_ contact: ContactDirectoryEntry) {
    guard let index = contactDirectoryEntries.firstIndex(where: { $0.id == contact.id }) else { return }
    let beforeDetail = contactDirectoryEntries[index].auditDetail
    contactDirectoryEntries[index].reviewState = .accepted
    persistContactDirectoryEntries()
    logAudit(
      action: .reviewed,
      entityType: .contactDirectoryEntry,
      entityID: contactDirectoryEntries[index].id.uuidString,
      entityLabel: contactDirectoryEntries[index].name,
      summary: "Contact directory entry marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: contactDirectoryEntries[index].auditDetail
    )
  }

  func removeContactDirectoryEntry(_ contact: ContactDirectoryEntry) {
    guard let index = contactDirectoryEntries.firstIndex(where: { $0.id == contact.id }) else { return }
    let removed = contactDirectoryEntries.remove(at: index)
    persistContactDirectoryEntries()
    logAudit(
      action: .removed,
      entityType: .contactDirectoryEntry,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "Contact directory entry removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func createDraftMessage(from contact: ContactDirectoryEntry, linkedEntityType: ReviewTaskLinkedEntityType? = nil, linkedEntityID: String? = nil, label: String? = nil) {
    createDraftMessage(
      linkedEntityType: linkedEntityType ?? .draftMessage,
      linkedEntityID: linkedEntityID ?? contact.id.uuidString,
      label: label ?? contact.organisation,
      recipient: contact.channelPreference == .phoneScript ? contact.phone : contact.email
    )
    if let index = contactDirectoryEntries.firstIndex(where: { $0.id == contact.id }) {
      let beforeDetail = contactDirectoryEntries[index].auditDetail
      contactDirectoryEntries[index].lastContactedDate = Self.auditTimestamp()
      persistContactDirectoryEntries()
      logAudit(
        action: .created,
        entityType: .contactDirectoryEntry,
        entityID: contactDirectoryEntries[index].id.uuidString,
        entityLabel: contactDirectoryEntries[index].name,
        summary: "Draft message created from contact.",
        beforeDetail: beforeDetail,
        afterDetail: contactDirectoryEntries[index].auditDetail
      )
    }
  }

  func suggestedContacts(for order: TrackedOrder) -> [ContactDirectoryEntry] {
    contactDirectoryEntries.filter { contact in
      contact.isEnabled
        && (contact.linkedEntityID == order.id.uuidString
          || contact.organisation.localizedCaseInsensitiveContains(order.store)
          || order.store.localizedCaseInsensitiveContains(contact.organisation)
          || contact.organisation.localizedCaseInsensitiveContains(order.carrier)
          || contact.linkedEntityType == .internalTeam)
    }
  }

  func suggestedContacts(for email: ForwardedEmailIntake) -> [ContactDirectoryEntry] {
    contactDirectoryEntries.filter { contact in
      contact.isEnabled
        && (contact.linkedEntityID == email.id.uuidString
          || contact.email.localizedCaseInsensitiveContains(email.sender)
          || email.sender.localizedCaseInsensitiveContains(contact.email)
          || contact.organisation.localizedCaseInsensitiveContains(email.detectedMerchant)
          || contact.linkedEntityType == .internalTeam)
    }
  }

  func suggestedContacts(for event: CarrierTrackingEvent) -> [ContactDirectoryEntry] {
    contactDirectoryEntries.filter { contact in
      contact.isEnabled
        && (contact.linkedEntityID == event.id.uuidString
          || contact.organisation.localizedCaseInsensitiveContains(event.carrier)
          || contact.linkedEntityType == .carrier
          || contact.linkedEntityType == .internalTeam)
    }
  }

  func filteredCustomerRecipientProfiles(profileType: CustomerProfileType?, organisationTeam: String?, isEnabled: Bool?, deliveryPreference: DeliveryPreference?, reviewState: ReviewState?) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { profile in
      let matchesType = profileType == nil || profile.profileType == profileType
      let matchesOrganisation = organisationTeam == nil || profile.organisationTeam == organisationTeam
      let matchesEnabled = isEnabled == nil || profile.isEnabled == isEnabled
      let matchesDelivery = deliveryPreference == nil || profile.deliveryPreference == deliveryPreference
      let matchesReview = reviewState == nil || profile.reviewState == reviewState
      return matchesType && matchesOrganisation && matchesEnabled && matchesDelivery && matchesReview
    }
  }

  func addCustomerRecipientProfilePlaceholder() {
    let profile = CustomerRecipientProfile(displayName: "New customer profile \(customerRecipientProfiles.count + 1)", profileType: .recipient, organisationTeam: "Unassigned team", primaryEmail: "recipient@example.com", phone: "Not recorded", defaultDestinationAddress: "Address to confirm", deliveryPreference: .noPreference, notes: "Define recipient, team, destination, and delivery preferences.", isEnabled: false, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    customerRecipientProfiles.insert(profile, at: 0)
    persistCustomerRecipientProfiles()
    logAudit(action: .created, entityType: .customerRecipientProfile, entityID: profile.id.uuidString, entityLabel: profile.displayName, summary: "Customer profile placeholder added.", afterDetail: profile.auditDetail)
  }

  func addCustomerRecipientProfile(displayName: String, organisationTeam: String, email: String, destination: String, profileType: CustomerProfileType = .recipient) {
    let profile = CustomerRecipientProfile(displayName: displayName, profileType: profileType, organisationTeam: organisationTeam, primaryEmail: email, phone: "Not recorded", defaultDestinationAddress: destination, deliveryPreference: .delivery, notes: "Local profile created from workflow.", isEnabled: false, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    customerRecipientProfiles.insert(profile, at: 0)
    persistCustomerRecipientProfiles()
    logAudit(action: .created, entityType: .customerRecipientProfile, entityID: profile.id.uuidString, entityLabel: profile.displayName, summary: "Customer profile created from workflow.", afterDetail: profile.auditDetail)
  }

  func updateCustomerRecipientProfile(_ profile: CustomerRecipientProfile) {
    guard let index = customerRecipientProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = customerRecipientProfiles[index].auditDetail
    customerRecipientProfiles[index] = profile
    persistCustomerRecipientProfiles()
    logAudit(action: .edited, entityType: .customerRecipientProfile, entityID: profile.id.uuidString, entityLabel: profile.displayName, summary: "Customer profile details updated.", beforeDetail: beforeDetail, afterDetail: profile.auditDetail)
  }

  func toggleCustomerRecipientProfile(_ profile: CustomerRecipientProfile) {
    guard let index = customerRecipientProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = customerRecipientProfiles[index].auditDetail
    customerRecipientProfiles[index].isEnabled.toggle()
    persistCustomerRecipientProfiles()
    logAudit(action: customerRecipientProfiles[index].isEnabled ? .enabled : .disabled, entityType: .customerRecipientProfile, entityID: customerRecipientProfiles[index].id.uuidString, entityLabel: customerRecipientProfiles[index].displayName, summary: customerRecipientProfiles[index].isEnabled ? "Customer profile enabled." : "Customer profile disabled.", beforeDetail: beforeDetail, afterDetail: customerRecipientProfiles[index].auditDetail)
  }

  func markCustomerRecipientProfileReviewed(_ profile: CustomerRecipientProfile) {
    guard let index = customerRecipientProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = customerRecipientProfiles[index].auditDetail
    customerRecipientProfiles[index].reviewState = .accepted
    customerRecipientProfiles[index].lastReviewedDate = Self.auditTimestamp()
    persistCustomerRecipientProfiles()
    logAudit(action: .reviewed, entityType: .customerRecipientProfile, entityID: customerRecipientProfiles[index].id.uuidString, entityLabel: customerRecipientProfiles[index].displayName, summary: "Customer profile marked reviewed.", beforeDetail: beforeDetail, afterDetail: customerRecipientProfiles[index].auditDetail)
  }

  func removeCustomerRecipientProfile(_ profile: CustomerRecipientProfile) {
    guard let index = customerRecipientProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let removed = customerRecipientProfiles.remove(at: index)
    persistCustomerRecipientProfiles()
    logAudit(action: .removed, entityType: .customerRecipientProfile, entityID: removed.id.uuidString, entityLabel: removed.displayName, summary: "Customer profile removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from profile: CustomerRecipientProfile) {
    createReviewTask(linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString, label: profile.displayName, summary: "Review customer profile for \(profile.organisationTeam). Destination: \(profile.defaultDestinationAddress). \(profile.notes)", priority: profile.isEnabled ? .normal : .high, assignee: profile.organisationTeam)
  }

  func createDraftMessage(from profile: CustomerRecipientProfile) {
    createDraftMessage(linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString, label: profile.displayName, recipient: profile.primaryEmail)
    logAudit(action: .created, entityType: .customerRecipientProfile, entityID: profile.id.uuidString, entityLabel: profile.displayName, summary: "Draft message created from customer profile.", afterDetail: profile.auditDetail)
  }

  func suggestedCustomerProfiles(for order: TrackedOrder) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: order.recipientEmail, team: order.customer, destination: order.destination, linkedEntityType: .order, linkedEntityID: order.id.uuidString) }
  }

  func suggestedCustomerProfiles(for email: ForwardedEmailIntake) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: email.sender, team: email.detectedMerchant, destination: email.detectedDestinationAddress, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString) }
  }

  func suggestedCustomerProfiles(for item: ImportQueueItem) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: item.detectedMerchant, destination: item.detectedDestinationAddress, linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString) }
  }

  func suggestedCustomerProfiles(for candidate: AcceptanceCandidate) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: candidate.detectedMerchant, destination: candidate.detectedDestinationAddress, linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString) }
  }

  func suggestedCustomerProfiles(for group: ShipmentGroup) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: group.recipientCustomerSummary, destination: group.destinationSummary, linkedEntityType: .shipmentGroup, linkedEntityID: group.id.uuidString) }
  }

  func suggestedCustomerProfiles(for task: ReviewTask) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: task.assignee, destination: task.summary, linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID) }
  }

  func suggestedCustomerProfiles(for note: HandoffNote) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: note.assignee, destination: note.summary, linkedEntityType: note.linkedEntityType, linkedEntityID: note.linkedEntityID) }
  }

  func suggestedCustomerProfiles(for event: CarrierTrackingEvent) -> [CustomerRecipientProfile] {
    let order = orders.first { $0.id == event.orderID }
    return customerRecipientProfiles.filter { $0.matches(email: order?.recipientEmail ?? "", team: order?.customer ?? event.carrier, destination: order?.destination ?? event.location, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString) }
  }

  func suggestedCustomerProfiles(for attachment: EvidenceAttachment) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: attachment.summary, destination: attachment.summary, linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString) }
  }

  func suggestedCustomerProfiles(for issue: ValidationIssue) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: issue.subtitle, destination: issue.detail, linkedEntityType: issue.linkedEntityType, linkedEntityID: issue.entityID) }
  }

  func suggestedCustomerProfiles(for issue: ReconciliationIssue) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: issue.summary, destination: issue.detectedValue, linkedEntityType: .reconciliationIssue, linkedEntityID: issue.id) }
  }

  func suggestedCustomerProfiles(for draft: DraftMessage) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: draft.recipient, team: draft.subject, destination: draft.body, linkedEntityType: draft.linkedEntityType, linkedEntityID: draft.linkedEntityID) }
  }

  func suggestedCustomerProfiles(for contact: ContactDirectoryEntry) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: contact.email, team: contact.organisation, destination: contact.notes, linkedEntityType: .contact, linkedEntityID: contact.id.uuidString) }
  }

  func suggestedCustomerProfiles(for account: AccountCredentialRecord) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: account.organisation, destination: account.notes, linkedEntityType: .account, linkedEntityID: account.id.uuidString) }
  }

  func suggestedCustomerProfiles(for profile: VendorProfile) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: profile.primaryOrganisation, destination: profile.serviceLevelNotes, linkedEntityType: .vendorProfile, linkedEntityID: profile.id.uuidString) }
  }

  func suggestedCustomerProfiles(for policy: SLAPolicy) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: policy.name, destination: policy.conditionSummary, linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString) }
  }

  func suggestedCustomerProfiles(for playbook: ExceptionPlaybook) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: playbook.escalationContact, destination: playbook.triggerSummary, linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString) }
  }

  func suggestedCustomerProfiles(for item: WorkbenchItem) -> [CustomerRecipientProfile] {
    customerRecipientProfiles.filter { $0.matches(email: "", team: item.assignee, destination: item.summary, linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID) }
  }

  func filteredDestinationAddresses(organisationTeam: String?, preferredCarrier: String?, riskLevel: ShipmentRiskLevel?, isEnabled: Bool?, reviewState: ReviewState?) -> [DestinationAddressRecord] {
    destinationAddresses.filter { address in
      let matchesTeam = organisationTeam == nil || address.organisationTeam == organisationTeam
      let matchesCarrier = preferredCarrier == nil || address.preferredCarrier == preferredCarrier
      let matchesRisk = riskLevel == nil || address.riskLevel == riskLevel
      let matchesEnabled = isEnabled == nil || address.isEnabled == isEnabled
      let matchesReview = reviewState == nil || address.reviewState == reviewState
      return matchesTeam && matchesCarrier && matchesRisk && matchesEnabled && matchesReview
    }
  }

  func addDestinationAddressPlaceholder() {
    let address = DestinationAddressRecord(label: "New destination \(destinationAddresses.count + 1)", customerProfileID: customerRecipientProfiles.first?.id, organisationTeam: customerRecipientProfiles.first?.organisationTeam ?? "Unassigned team", addressLineSummary: "Address to confirm", cityRegion: "City/region", country: "Australia", deliveryInstructions: "Add local delivery instructions.", accessNotes: "Add access notes.", preferredCarrier: "Any carrier", riskLevel: .medium, isEnabled: false, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    destinationAddresses.insert(address, at: 0)
    persistDestinationAddresses()
    logAudit(action: .created, entityType: .destinationAddress, entityID: address.id.uuidString, entityLabel: address.label, summary: "Destination address placeholder added.", afterDetail: address.auditDetail)
  }

  func addDestinationAddress(label: String, customerProfileID: UUID?, organisationTeam: String, addressSummary: String, cityRegion: String, preferredCarrier: String) {
    let address = DestinationAddressRecord(label: label, customerProfileID: customerProfileID, organisationTeam: organisationTeam, addressLineSummary: addressSummary, cityRegion: cityRegion, country: "Australia", deliveryInstructions: "Local address created from workflow.", accessNotes: "Access notes to confirm.", preferredCarrier: preferredCarrier, riskLevel: .medium, isEnabled: false, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    destinationAddresses.insert(address, at: 0)
    persistDestinationAddresses()
    logAudit(action: .created, entityType: .destinationAddress, entityID: address.id.uuidString, entityLabel: address.label, summary: "Destination address created from workflow.", afterDetail: address.auditDetail)
  }

  func updateDestinationAddress(_ address: DestinationAddressRecord) {
    guard let index = destinationAddresses.firstIndex(where: { $0.id == address.id }) else { return }
    let beforeDetail = destinationAddresses[index].auditDetail
    destinationAddresses[index] = address
    persistDestinationAddresses()
    logAudit(action: .edited, entityType: .destinationAddress, entityID: address.id.uuidString, entityLabel: address.label, summary: "Destination address details updated.", beforeDetail: beforeDetail, afterDetail: address.auditDetail)
  }

  func toggleDestinationAddress(_ address: DestinationAddressRecord) {
    guard let index = destinationAddresses.firstIndex(where: { $0.id == address.id }) else { return }
    let beforeDetail = destinationAddresses[index].auditDetail
    destinationAddresses[index].isEnabled.toggle()
    persistDestinationAddresses()
    logAudit(action: destinationAddresses[index].isEnabled ? .enabled : .disabled, entityType: .destinationAddress, entityID: destinationAddresses[index].id.uuidString, entityLabel: destinationAddresses[index].label, summary: destinationAddresses[index].isEnabled ? "Destination address enabled." : "Destination address disabled.", beforeDetail: beforeDetail, afterDetail: destinationAddresses[index].auditDetail)
  }

  func markDestinationAddressReviewed(_ address: DestinationAddressRecord) {
    guard let index = destinationAddresses.firstIndex(where: { $0.id == address.id }) else { return }
    let beforeDetail = destinationAddresses[index].auditDetail
    destinationAddresses[index].reviewState = .accepted
    destinationAddresses[index].lastReviewedDate = Self.auditTimestamp()
    persistDestinationAddresses()
    logAudit(action: .reviewed, entityType: .destinationAddress, entityID: destinationAddresses[index].id.uuidString, entityLabel: destinationAddresses[index].label, summary: "Destination address marked reviewed.", beforeDetail: beforeDetail, afterDetail: destinationAddresses[index].auditDetail)
  }

  func removeDestinationAddress(_ address: DestinationAddressRecord) {
    guard let index = destinationAddresses.firstIndex(where: { $0.id == address.id }) else { return }
    let removed = destinationAddresses.remove(at: index)
    persistDestinationAddresses()
    logAudit(action: .removed, entityType: .destinationAddress, entityID: removed.id.uuidString, entityLabel: removed.label, summary: "Destination address removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from address: DestinationAddressRecord) {
    createReviewTask(linkedEntityType: .destinationAddress, linkedEntityID: address.id.uuidString, label: address.label, summary: "Review destination address for \(address.organisationTeam). Risk: \(address.riskLevel.rawValue). \(address.deliveryInstructions)", priority: address.riskLevel == .critical ? .urgent : address.riskLevel == .high ? .high : .normal, assignee: address.organisationTeam)
  }

  func createDraftMessage(from address: DestinationAddressRecord) {
    let recipient = address.customerProfileID.flatMap { id in customerRecipientProfiles.first { $0.id == id }?.primaryEmail } ?? "operations@parcelops.example"
    createDraftMessage(linkedEntityType: .destinationAddress, linkedEntityID: address.id.uuidString, label: address.label, recipient: recipient)
    logAudit(action: .created, entityType: .destinationAddress, entityID: address.id.uuidString, entityLabel: address.label, summary: "Draft message created from destination address.", afterDetail: address.auditDetail)
  }

  private func suggestedDestinationAddresses(profileID: UUID?, destination: String, team: String, carrier: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [DestinationAddressRecord] {
    destinationAddresses.filter { $0.matches(profileID: profileID, destination: destination, team: team, carrier: carrier, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedDestinationAddresses(for profile: CustomerRecipientProfile) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: profile.id, destination: profile.defaultDestinationAddress, team: profile.organisationTeam, carrier: "", linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedDestinationAddresses(for order: TrackedOrder) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: order.destination, team: order.customer, carrier: order.carrier, linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedDestinationAddresses(for email: ForwardedEmailIntake) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: email.detectedDestinationAddress, team: email.detectedMerchant, carrier: "", linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString)
  }

  func suggestedDestinationAddresses(for item: ImportQueueItem) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: item.detectedDestinationAddress, team: item.detectedMerchant, carrier: "", linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString)
  }

  func suggestedDestinationAddresses(for candidate: AcceptanceCandidate) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: candidate.detectedDestinationAddress, team: candidate.detectedMerchant, carrier: "", linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString)
  }

  func suggestedDestinationAddresses(for group: ShipmentGroup) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: group.destinationSummary, team: group.recipientCustomerSummary, carrier: group.carrierSummary, linkedEntityType: .shipmentGroup, linkedEntityID: group.id.uuidString)
  }

  func suggestedDestinationAddresses(for task: ReviewTask) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: task.summary, team: task.assignee, carrier: "", linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID)
  }

  func suggestedDestinationAddresses(for note: HandoffNote) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: note.summary, team: note.assignee, carrier: "", linkedEntityType: note.linkedEntityType, linkedEntityID: note.linkedEntityID)
  }

  func suggestedDestinationAddresses(for event: CarrierTrackingEvent) -> [DestinationAddressRecord] {
    let order = orders.first { $0.id == event.orderID }
    return suggestedDestinationAddresses(profileID: nil, destination: order?.destination ?? event.location, team: order?.customer ?? "", carrier: event.carrier, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString)
  }

  func suggestedDestinationAddresses(for attachment: EvidenceAttachment) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: attachment.summary, team: attachment.summary, carrier: "", linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString)
  }

  func suggestedDestinationAddresses(for issue: ValidationIssue) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: issue.detail, team: issue.subtitle, carrier: "", linkedEntityType: issue.linkedEntityType, linkedEntityID: issue.entityID)
  }

  func suggestedDestinationAddresses(for issue: ReconciliationIssue) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: issue.detectedValue, team: issue.summary, carrier: "", linkedEntityType: .reconciliationIssue, linkedEntityID: issue.id)
  }

  func suggestedDestinationAddresses(for draft: DraftMessage) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: draft.body, team: draft.subject, carrier: "", linkedEntityType: draft.linkedEntityType, linkedEntityID: draft.linkedEntityID)
  }

  func suggestedDestinationAddresses(for contact: ContactDirectoryEntry) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: contact.notes, team: contact.organisation, carrier: "", linkedEntityType: .contact, linkedEntityID: contact.id.uuidString)
  }

  func suggestedDestinationAddresses(for account: AccountCredentialRecord) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: account.notes, team: account.organisation, carrier: "", linkedEntityType: .account, linkedEntityID: account.id.uuidString)
  }

  func suggestedDestinationAddresses(for profile: VendorProfile) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: profile.serviceLevelNotes, team: profile.primaryOrganisation, carrier: profile.primaryOrganisation, linkedEntityType: .vendorProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedDestinationAddresses(for policy: SLAPolicy) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: policy.conditionSummary, team: policy.name, carrier: "", linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString)
  }

  func suggestedDestinationAddresses(for playbook: ExceptionPlaybook) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: playbook.triggerSummary, team: playbook.escalationContact, carrier: "", linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString)
  }

  func suggestedDestinationAddresses(for item: WorkbenchItem) -> [DestinationAddressRecord] {
    suggestedDestinationAddresses(profileID: nil, destination: item.summary, team: item.assignee, carrier: "", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredDeliveryInstructions(instructionType: DeliveryInstructionType?, profileID: UUID?, carrierContext: String?, riskLevel: ShipmentRiskLevel?, isEnabled: Bool?, reviewState: ReviewState?) -> [DeliveryInstructionRecord] {
    deliveryInstructions.filter { instruction in
      let matchesType = instructionType == nil || instruction.instructionType == instructionType
      let matchesProfile = profileID == nil || instruction.customerProfileID == profileID
      let matchesCarrier = carrierContext == nil || instruction.carrierNotes.localizedCaseInsensitiveContains(carrierContext ?? "") || instruction.instructionSummary.localizedCaseInsensitiveContains(carrierContext ?? "")
      let matchesRisk = riskLevel == nil || instruction.riskLevel == riskLevel
      let matchesEnabled = isEnabled == nil || instruction.isEnabled == isEnabled
      let matchesReview = reviewState == nil || instruction.reviewState == reviewState
      return matchesType && matchesProfile && matchesCarrier && matchesRisk && matchesEnabled && matchesReview
    }
  }

  func addDeliveryInstructionPlaceholder() {
    let address = destinationAddresses.first
    let instruction = DeliveryInstructionRecord(title: "New instruction \(deliveryInstructions.count + 1)", destinationAddressID: address?.id, customerProfileID: address?.customerProfileID ?? customerRecipientProfiles.first?.id, linkedEntityType: .destinationAddress, linkedEntityID: address?.id.uuidString ?? "Unlinked", instructionType: .accessConstraint, instructionSummary: "Add local delivery instruction summary.", accessConstraintSummary: "Add access constraints to review.", preferredDeliveryWindow: "To confirm", restrictedDeliveryWindow: "To confirm", carrierNotes: "Carrier notes to confirm.", riskLevel: .medium, isEnabled: false, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    deliveryInstructions.insert(instruction, at: 0)
    persistDeliveryInstructions()
    logAudit(action: .created, entityType: .deliveryInstruction, entityID: instruction.id.uuidString, entityLabel: instruction.title, summary: "Delivery instruction placeholder added.", afterDetail: instruction.auditDetail)
  }

  func updateDeliveryInstruction(_ instruction: DeliveryInstructionRecord) {
    guard let index = deliveryInstructions.firstIndex(where: { $0.id == instruction.id }) else { return }
    let beforeDetail = deliveryInstructions[index].auditDetail
    deliveryInstructions[index] = instruction
    persistDeliveryInstructions()
    logAudit(action: .edited, entityType: .deliveryInstruction, entityID: instruction.id.uuidString, entityLabel: instruction.title, summary: "Delivery instruction details updated.", beforeDetail: beforeDetail, afterDetail: instruction.auditDetail)
  }

  func toggleDeliveryInstruction(_ instruction: DeliveryInstructionRecord) {
    guard let index = deliveryInstructions.firstIndex(where: { $0.id == instruction.id }) else { return }
    let beforeDetail = deliveryInstructions[index].auditDetail
    deliveryInstructions[index].isEnabled.toggle()
    persistDeliveryInstructions()
    logAudit(action: deliveryInstructions[index].isEnabled ? .enabled : .disabled, entityType: .deliveryInstruction, entityID: deliveryInstructions[index].id.uuidString, entityLabel: deliveryInstructions[index].title, summary: deliveryInstructions[index].isEnabled ? "Delivery instruction enabled." : "Delivery instruction disabled.", beforeDetail: beforeDetail, afterDetail: deliveryInstructions[index].auditDetail)
  }

  func markDeliveryInstructionReviewed(_ instruction: DeliveryInstructionRecord) {
    guard let index = deliveryInstructions.firstIndex(where: { $0.id == instruction.id }) else { return }
    let beforeDetail = deliveryInstructions[index].auditDetail
    deliveryInstructions[index].reviewState = .accepted
    deliveryInstructions[index].lastReviewedDate = Self.auditTimestamp()
    persistDeliveryInstructions()
    logAudit(action: .reviewed, entityType: .deliveryInstruction, entityID: deliveryInstructions[index].id.uuidString, entityLabel: deliveryInstructions[index].title, summary: "Delivery instruction marked reviewed.", beforeDetail: beforeDetail, afterDetail: deliveryInstructions[index].auditDetail)
  }

  func removeDeliveryInstruction(_ instruction: DeliveryInstructionRecord) {
    guard let index = deliveryInstructions.firstIndex(where: { $0.id == instruction.id }) else { return }
    let removed = deliveryInstructions.remove(at: index)
    persistDeliveryInstructions()
    logAudit(action: .removed, entityType: .deliveryInstruction, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Delivery instruction removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from instruction: DeliveryInstructionRecord) {
    let assignee = instruction.customerProfileID.flatMap { id in customerRecipientProfiles.first { $0.id == id }?.organisationTeam } ?? "Operations"
    createReviewTask(linkedEntityType: .deliveryInstruction, linkedEntityID: instruction.id.uuidString, label: instruction.title, summary: "Review \(instruction.instructionType.rawValue.lowercased()) instruction. \(instruction.instructionSummary) \(instruction.accessConstraintSummary)", priority: instruction.riskLevel == .critical ? .urgent : instruction.riskLevel == .high ? .high : .normal, assignee: assignee)
  }

  func createDraftMessage(from instruction: DeliveryInstructionRecord) {
    let recipient = instruction.customerProfileID.flatMap { id in customerRecipientProfiles.first { $0.id == id }?.primaryEmail } ?? "operations@parcelops.example"
    createDraftMessage(linkedEntityType: .deliveryInstruction, linkedEntityID: instruction.id.uuidString, label: instruction.title, recipient: recipient)
    logAudit(action: .created, entityType: .deliveryInstruction, entityID: instruction.id.uuidString, entityLabel: instruction.title, summary: "Draft message created from delivery instruction.", afterDetail: instruction.auditDetail)
  }

  private func suggestedDeliveryInstructions(destinationAddressID: UUID?, profileID: UUID?, context: String, carrier: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [DeliveryInstructionRecord] {
    deliveryInstructions.filter { $0.matches(destinationAddressID: destinationAddressID, profileID: profileID, context: context, carrier: carrier, riskLevel: riskLevel, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedDeliveryInstructions(for address: DestinationAddressRecord) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: address.id, profileID: address.customerProfileID, context: "\(address.addressLineSummary) \(address.deliveryInstructions) \(address.accessNotes)", carrier: address.preferredCarrier, riskLevel: address.riskLevel, linkedEntityType: .destinationAddress, linkedEntityID: address.id.uuidString)
  }

  func suggestedDeliveryInstructions(for profile: CustomerRecipientProfile) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: profile.id, context: "\(profile.defaultDestinationAddress) \(profile.deliveryPreference.rawValue) \(profile.notes)", carrier: "", riskLevel: nil, linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedDeliveryInstructions(for order: TrackedOrder) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: order).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(order.destination) \(order.customer)", carrier: order.carrier, riskLevel: nil, linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedDeliveryInstructions(for email: ForwardedEmailIntake) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: email).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(email.detectedDestinationAddress) \(email.detectedMerchant)", carrier: "", riskLevel: nil, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString)
  }

  func suggestedDeliveryInstructions(for item: ImportQueueItem) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: item).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(item.detectedDestinationAddress) \(item.detectedMerchant)", carrier: "", riskLevel: nil, linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString)
  }

  func suggestedDeliveryInstructions(for candidate: AcceptanceCandidate) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: candidate).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(candidate.detectedDestinationAddress) \(candidate.detectedMerchant)", carrier: "", riskLevel: nil, linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString)
  }

  func suggestedDeliveryInstructions(for group: ShipmentGroup) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: group).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(group.destinationSummary) \(group.recipientCustomerSummary)", carrier: group.carrierSummary, riskLevel: group.riskLevel, linkedEntityType: .shipmentGroup, linkedEntityID: group.id.uuidString)
  }

  func suggestedDeliveryInstructions(for task: ReviewTask) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: task.summary, carrier: "", riskLevel: nil, linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID)
  }

  func suggestedDeliveryInstructions(for note: HandoffNote) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(note.summary) \(note.notes)", carrier: "", riskLevel: nil, linkedEntityType: note.linkedEntityType, linkedEntityID: note.linkedEntityID)
  }

  func suggestedDeliveryInstructions(for event: CarrierTrackingEvent) -> [DeliveryInstructionRecord] {
    let address = suggestedDestinationAddresses(for: event).first
    return suggestedDeliveryInstructions(destinationAddressID: address?.id, profileID: address?.customerProfileID, context: "\(event.location) \(event.detail)", carrier: event.carrier, riskLevel: nil, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString)
  }

  func suggestedDeliveryInstructions(for attachment: EvidenceAttachment) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: attachment.summary, carrier: "", riskLevel: nil, linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString)
  }

  func suggestedDeliveryInstructions(for issue: ValidationIssue) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(issue.subtitle) \(issue.detail)", carrier: "", riskLevel: issue.severity.shipmentRiskLevel, linkedEntityType: issue.linkedEntityType, linkedEntityID: issue.entityID)
  }

  func suggestedDeliveryInstructions(for issue: ReconciliationIssue) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(issue.summary) \(issue.detectedValue) \(issue.currentOperationalValue)", carrier: "", riskLevel: issue.severity.shipmentRiskLevel, linkedEntityType: .reconciliationIssue, linkedEntityID: issue.id)
  }

  func suggestedDeliveryInstructions(for draft: DraftMessage) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(draft.subject) \(draft.body)", carrier: "", riskLevel: nil, linkedEntityType: draft.linkedEntityType, linkedEntityID: draft.linkedEntityID)
  }

  func suggestedDeliveryInstructions(for contact: ContactDirectoryEntry) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(contact.organisation) \(contact.notes)", carrier: "", riskLevel: nil, linkedEntityType: .contact, linkedEntityID: contact.id.uuidString)
  }

  func suggestedDeliveryInstructions(for account: AccountCredentialRecord) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(account.organisation) \(account.notes)", carrier: "", riskLevel: nil, linkedEntityType: .account, linkedEntityID: account.id.uuidString)
  }

  func suggestedDeliveryInstructions(for profile: VendorProfile) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(profile.primaryOrganisation) \(profile.serviceLevelNotes)", carrier: profile.primaryOrganisation, riskLevel: profile.riskLevel.shipmentRiskLevel, linkedEntityType: .vendorProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedDeliveryInstructions(for policy: SLAPolicy) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(policy.name) \(policy.conditionSummary)", carrier: "", riskLevel: nil, linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString)
  }

  func suggestedDeliveryInstructions(for playbook: ExceptionPlaybook) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(playbook.triggerSummary) \(playbook.recommendedSteps)", carrier: "", riskLevel: nil, linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString)
  }

  func suggestedDeliveryInstructions(for item: WorkbenchItem) -> [DeliveryInstructionRecord] {
    suggestedDeliveryInstructions(destinationAddressID: nil, profileID: nil, context: "\(item.summary) \(item.suggestedNextAction)", carrier: "", riskLevel: item.shipmentRiskLevel, linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredPackageContents(itemCategory: PackageItemCategory?, valueBand: PackageValueBand?, verificationStatus: PackageVerificationStatus?, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [PackageContentRecord] {
    packageContents.filter { content in
      let matchesCategory = itemCategory == nil || content.itemCategory == itemCategory
      let matchesValue = valueBand == nil || content.valueBand == valueBand
      let matchesVerification = verificationStatus == nil || content.verificationStatus == verificationStatus
      let matchesRisk = riskLevel == nil || content.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || content.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || content.reviewState == reviewState
      return matchesCategory && matchesValue && matchesVerification && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addPackageContentPlaceholder() {
    let order = orders.first
    let group = shipmentGroups.first
    let address = destinationAddresses.first
    let instruction = deliveryInstructions.first
    let content = PackageContentRecord(title: "New package content \(packageContents.count + 1)", linkedEntityType: .order, linkedEntityID: order?.id.uuidString ?? "Unlinked", orderID: order?.id, shipmentGroupID: group?.id, destinationAddressID: address?.id, deliveryInstructionID: instruction?.id, customerProfileID: address?.customerProfileID ?? customerRecipientProfiles.first?.id, itemSummary: "Items to verify locally.", expectedQuantity: 1, verifiedQuantity: 0, itemCategory: .other, valueBand: .unknown, verificationStatus: .notVerified, discrepancySummary: "No discrepancy recorded yet.", evidenceAttachmentIDs: [], riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    packageContents.insert(content, at: 0)
    persistPackageContents()
    logAudit(action: .created, entityType: .packageContent, entityID: content.id.uuidString, entityLabel: content.title, summary: "Package content placeholder added.", afterDetail: content.auditDetail)
  }

  func updatePackageContent(_ content: PackageContentRecord) {
    guard let index = packageContents.firstIndex(where: { $0.id == content.id }) else { return }
    let beforeDetail = packageContents[index].auditDetail
    packageContents[index] = content
    persistPackageContents()
    logAudit(action: .edited, entityType: .packageContent, entityID: content.id.uuidString, entityLabel: content.title, summary: "Package content details updated.", beforeDetail: beforeDetail, afterDetail: content.auditDetail)
  }

  func markPackageContentVerified(_ content: PackageContentRecord) {
    guard let index = packageContents.firstIndex(where: { $0.id == content.id }) else { return }
    let beforeDetail = packageContents[index].auditDetail
    packageContents[index].verifiedQuantity = packageContents[index].expectedQuantity
    packageContents[index].verificationStatus = .verified
    packageContents[index].discrepancySummary = "No discrepancy recorded."
    packageContents[index].reviewState = .accepted
    packageContents[index].lastReviewedDate = Self.auditTimestamp()
    persistPackageContents()
    logAudit(action: .completed, entityType: .packageContent, entityID: packageContents[index].id.uuidString, entityLabel: packageContents[index].title, summary: "Package content verified locally.", beforeDetail: beforeDetail, afterDetail: packageContents[index].auditDetail)
  }

  func markPackageContentDiscrepancy(_ content: PackageContentRecord) {
    guard let index = packageContents.firstIndex(where: { $0.id == content.id }) else { return }
    let beforeDetail = packageContents[index].auditDetail
    packageContents[index].verificationStatus = .discrepancy
    packageContents[index].reviewState = .needsReview
    packageContents[index].discrepancySummary = packageContents[index].discrepancySummary.localizedCaseInsensitiveContains("no discrepancy") ? "Quantity or item details need manual verification." : packageContents[index].discrepancySummary
    persistPackageContents()
    logAudit(action: .edited, entityType: .packageContent, entityID: packageContents[index].id.uuidString, entityLabel: packageContents[index].title, summary: "Package content discrepancy marked.", beforeDetail: beforeDetail, afterDetail: packageContents[index].auditDetail)
  }

  func markPackageContentReviewed(_ content: PackageContentRecord) {
    guard let index = packageContents.firstIndex(where: { $0.id == content.id }) else { return }
    let beforeDetail = packageContents[index].auditDetail
    packageContents[index].reviewState = .accepted
    packageContents[index].lastReviewedDate = Self.auditTimestamp()
    persistPackageContents()
    logAudit(action: .reviewed, entityType: .packageContent, entityID: packageContents[index].id.uuidString, entityLabel: packageContents[index].title, summary: "Package content marked reviewed.", beforeDetail: beforeDetail, afterDetail: packageContents[index].auditDetail)
  }

  func removePackageContent(_ content: PackageContentRecord) {
    guard let index = packageContents.firstIndex(where: { $0.id == content.id }) else { return }
    let removed = packageContents.remove(at: index)
    persistPackageContents()
    logAudit(action: .removed, entityType: .packageContent, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Package content removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from content: PackageContentRecord) {
    createReviewTask(linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString, label: content.title, summary: "Verify package contents: \(content.itemSummary). \(content.discrepancySummary)", priority: content.riskLevel == .critical ? .urgent : content.riskLevel == .high ? .high : .normal, assignee: content.itemCategory.rawValue)
  }

  func createDraftMessage(from content: PackageContentRecord) {
    let recipient = content.customerProfileID.flatMap { id in customerRecipientProfiles.first { $0.id == id }?.primaryEmail } ?? "operations@parcelops.example"
    createDraftMessage(linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString, label: content.title, recipient: recipient)
    logAudit(action: .created, entityType: .packageContent, entityID: content.id.uuidString, entityLabel: content.title, summary: "Draft message created from package content.", afterDetail: content.auditDetail)
  }

  private func suggestedPackageContents(orderID: UUID?, shipmentGroupID: UUID?, destinationAddressID: UUID?, deliveryInstructionID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [PackageContentRecord] {
    packageContents.filter { $0.matches(orderID: orderID, shipmentGroupID: shipmentGroupID, destinationAddressID: destinationAddressID, deliveryInstructionID: deliveryInstructionID, customerProfileID: customerProfileID, evidenceID: evidenceID, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedPackageContents(for order: TrackedOrder) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: order.id, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: order).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: order).first?.id, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, evidenceID: nil, context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedPackageContents(for email: ForwardedEmailIntake) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: email.linkedOrderID, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: email).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: email).first?.id, customerProfileID: suggestedCustomerProfiles(for: email).first?.id, evidenceID: nil, context: "\(email.detectedMerchant) \(email.detectedOrderNumber) \(email.detectedDestinationAddress)", linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString)
  }

  func suggestedPackageContents(for item: ImportQueueItem) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: item.suggestedLinkedOrderID, shipmentGroupID: item.suggestedShipmentGroupID, destinationAddressID: suggestedDestinationAddresses(for: item).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: item).first?.id, customerProfileID: suggestedCustomerProfiles(for: item).first?.id, evidenceID: nil, context: "\(item.rawSummary) \(item.detectedMerchant) \(item.detectedDestinationAddress)", linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString)
  }

  func suggestedPackageContents(for candidate: AcceptanceCandidate) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: candidate.suggestedLinkedOrderID, shipmentGroupID: candidate.suggestedShipmentGroupID, destinationAddressID: suggestedDestinationAddresses(for: candidate).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: candidate).first?.id, customerProfileID: suggestedCustomerProfiles(for: candidate).first?.id, evidenceID: nil, context: "\(candidate.detectedMerchant) \(candidate.detectedDestinationAddress)", linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString)
  }

  func suggestedPackageContents(for group: ShipmentGroup) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: group.primaryOrderID, shipmentGroupID: group.id, destinationAddressID: suggestedDestinationAddresses(for: group).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: group).first?.id, customerProfileID: suggestedCustomerProfiles(for: group).first?.id, evidenceID: group.relatedEvidenceIDs.first, context: "\(group.groupName) \(group.destinationSummary) \(group.statusSummary)", linkedEntityType: .shipmentGroup, linkedEntityID: group.id.uuidString)
  }

  func suggestedPackageContents(for attachment: EvidenceAttachment) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: attachment).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: attachment).first?.id, customerProfileID: suggestedCustomerProfiles(for: attachment).first?.id, evidenceID: attachment.id, context: attachment.summary, linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString)
  }

  func suggestedPackageContents(for address: DestinationAddressRecord) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: address.id, deliveryInstructionID: nil, customerProfileID: address.customerProfileID, evidenceID: nil, context: "\(address.label) \(address.deliveryInstructions)", linkedEntityType: .destinationAddress, linkedEntityID: address.id.uuidString)
  }

  func suggestedPackageContents(for instruction: DeliveryInstructionRecord) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: instruction.destinationAddressID, deliveryInstructionID: instruction.id, customerProfileID: instruction.customerProfileID, evidenceID: nil, context: "\(instruction.title) \(instruction.instructionSummary)", linkedEntityType: .deliveryInstruction, linkedEntityID: instruction.id.uuidString)
  }

  func suggestedPackageContents(for profile: CustomerRecipientProfile) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: profile).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: profile).first?.id, customerProfileID: profile.id, evidenceID: nil, context: "\(profile.displayName) \(profile.defaultDestinationAddress)", linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedPackageContents(for task: ReviewTask) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: task.summary, linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID)
  }

  func suggestedPackageContents(for note: HandoffNote) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(note.summary) \(note.notes)", linkedEntityType: note.linkedEntityType, linkedEntityID: note.linkedEntityID)
  }

  func suggestedPackageContents(for event: CarrierTrackingEvent) -> [PackageContentRecord] {
    let order = orders.first { $0.id == event.orderID }
    return suggestedPackageContents(orderID: event.orderID, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: event).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: event).first?.id, customerProfileID: order.flatMap { suggestedCustomerProfiles(for: $0).first?.id }, evidenceID: nil, context: "\(event.trackingNumber) \(event.detail)", linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString)
  }

  func suggestedPackageContents(for issue: ValidationIssue) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(issue.title) \(issue.detail)", linkedEntityType: issue.linkedEntityType, linkedEntityID: issue.entityID)
  }

  func suggestedPackageContents(for issue: ReconciliationIssue) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(issue.title) \(issue.summary) \(issue.detectedValue)", linkedEntityType: .reconciliationIssue, linkedEntityID: issue.id)
  }

  func suggestedPackageContents(for draft: DraftMessage) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(draft.subject) \(draft.body)", linkedEntityType: draft.linkedEntityType, linkedEntityID: draft.linkedEntityID)
  }

  func suggestedPackageContents(for contact: ContactDirectoryEntry) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: contact).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: contact).first?.id, customerProfileID: suggestedCustomerProfiles(for: contact).first?.id, evidenceID: nil, context: "\(contact.organisation) \(contact.notes)", linkedEntityType: .contact, linkedEntityID: contact.id.uuidString)
  }

  func suggestedPackageContents(for account: AccountCredentialRecord) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: account).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: account).first?.id, customerProfileID: suggestedCustomerProfiles(for: account).first?.id, evidenceID: nil, context: "\(account.organisation) \(account.notes)", linkedEntityType: .account, linkedEntityID: account.id.uuidString)
  }

  func suggestedPackageContents(for profile: VendorProfile) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: suggestedDestinationAddresses(for: profile).first?.id, deliveryInstructionID: suggestedDeliveryInstructions(for: profile).first?.id, customerProfileID: suggestedCustomerProfiles(for: profile).first?.id, evidenceID: nil, context: "\(profile.primaryOrganisation) \(profile.serviceLevelNotes)", linkedEntityType: .vendorProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedPackageContents(for policy: SLAPolicy) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(policy.name) \(policy.conditionSummary)", linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString)
  }

  func suggestedPackageContents(for playbook: ExceptionPlaybook) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(playbook.name) \(playbook.triggerSummary)", linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString)
  }

  func suggestedPackageContents(for item: WorkbenchItem) -> [PackageContentRecord] {
    suggestedPackageContents(orderID: nil, shipmentGroupID: nil, destinationAddressID: nil, deliveryInstructionID: nil, customerProfileID: nil, evidenceID: nil, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredCostRecords(costCategory: CostCategory?, reimbursementStatus: ReimbursementStatus?, approvalStatus: CostApprovalStatus?, budgetCode: String, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [CostRecord] {
    costRecords.filter { cost in
      let matchesCategory = costCategory == nil || cost.costCategory == costCategory
      let matchesReimbursement = reimbursementStatus == nil || cost.reimbursementStatus == reimbursementStatus
      let matchesApproval = approvalStatus == nil || cost.approvalStatus == approvalStatus
      let matchesBudget = budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cost.budgetCode.localizedCaseInsensitiveContains(budgetCode)
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cost.costOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || cost.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || cost.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || cost.reviewState == reviewState
      return matchesCategory && matchesReimbursement && matchesApproval && matchesBudget && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addCostRecordPlaceholder() {
    let order = orders.first
    let group = shipmentGroups.first
    let content = packageContents.first
    let customerProfileID = order.flatMap { suggestedCustomerProfiles(for: $0).first?.id } ?? customerRecipientProfiles.first?.id
    let cost = CostRecord(title: "New cost record \(costRecords.count + 1)", linkedEntityType: .order, linkedEntityID: order?.id.uuidString ?? "Unlinked", orderID: order?.id, shipmentGroupID: group?.id, packageContentID: content?.id, customerProfileID: customerProfileID, vendorProfileID: nil, accountID: nil, costCategory: .other, amountText: "0.00", currency: "AUD", taxGSTText: "GST to confirm", reimbursementStatus: .notSubmitted, approvalStatus: .draft, budgetCode: "To confirm", costOwnerTeam: order?.customer ?? "Operations", evidenceAttachmentIDs: [], notes: "Local placeholder for budget, approval, and reimbursement review.", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    costRecords.insert(cost, at: 0)
    persistCostRecords()
    logAudit(action: .created, entityType: .costRecord, entityID: cost.id.uuidString, entityLabel: cost.title, summary: "Cost record placeholder added.", afterDetail: cost.auditDetail)
  }

  func updateCostRecord(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let beforeDetail = costRecords[index].auditDetail
    costRecords[index] = cost
    persistCostRecords()
    logAudit(action: .edited, entityType: .costRecord, entityID: cost.id.uuidString, entityLabel: cost.title, summary: "Cost record details updated.", beforeDetail: beforeDetail, afterDetail: cost.auditDetail)
  }

  func markCostRecordApproved(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let beforeDetail = costRecords[index].auditDetail
    costRecords[index].approvalStatus = .approved
    costRecords[index].reviewState = .accepted
    costRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistCostRecords()
    logAudit(action: .completed, entityType: .costRecord, entityID: costRecords[index].id.uuidString, entityLabel: costRecords[index].title, summary: "Cost approved locally.", beforeDetail: beforeDetail, afterDetail: costRecords[index].auditDetail)
  }

  func markCostRecordReimbursed(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let beforeDetail = costRecords[index].auditDetail
    costRecords[index].reimbursementStatus = .reimbursed
    costRecords[index].reviewState = .accepted
    costRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistCostRecords()
    logAudit(action: .completed, entityType: .costRecord, entityID: costRecords[index].id.uuidString, entityLabel: costRecords[index].title, summary: "Cost marked reimbursed locally.", beforeDetail: beforeDetail, afterDetail: costRecords[index].auditDetail)
  }

  func markCostRecordDisputed(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let beforeDetail = costRecords[index].auditDetail
    costRecords[index].reimbursementStatus = .disputed
    costRecords[index].approvalStatus = .needsReview
    costRecords[index].reviewState = .needsReview
    costRecords[index].riskLevel = costRecords[index].riskLevel == .critical ? .critical : .high
    persistCostRecords()
    logAudit(action: .edited, entityType: .costRecord, entityID: costRecords[index].id.uuidString, entityLabel: costRecords[index].title, summary: "Cost marked disputed and needs review.", beforeDetail: beforeDetail, afterDetail: costRecords[index].auditDetail)
  }

  func markCostRecordReviewed(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let beforeDetail = costRecords[index].auditDetail
    costRecords[index].reviewState = .accepted
    costRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistCostRecords()
    logAudit(action: .reviewed, entityType: .costRecord, entityID: costRecords[index].id.uuidString, entityLabel: costRecords[index].title, summary: "Cost record marked reviewed.", beforeDetail: beforeDetail, afterDetail: costRecords[index].auditDetail)
  }

  func removeCostRecord(_ cost: CostRecord) {
    guard let index = costRecords.firstIndex(where: { $0.id == cost.id }) else { return }
    let removed = costRecords.remove(at: index)
    persistCostRecords()
    logAudit(action: .removed, entityType: .costRecord, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Cost record removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from cost: CostRecord) {
    createReviewTask(linkedEntityType: .costRecord, linkedEntityID: cost.id.uuidString, label: cost.title, summary: "Review cost: \(cost.amountText) \(cost.currency), \(cost.costCategory.rawValue), budget \(cost.budgetCode). \(cost.notes)", priority: cost.riskLevel == .critical ? .urgent : cost.riskLevel == .high ? .high : .normal, assignee: cost.costOwnerTeam)
  }

  func createDraftMessage(from cost: CostRecord) {
    createDraftMessage(linkedEntityType: .costRecord, linkedEntityID: cost.id.uuidString, label: cost.title, recipient: cost.costOwnerTeam)
    logAudit(action: .created, entityType: .costRecord, entityID: cost.id.uuidString, entityLabel: cost.title, summary: "Draft message created from cost record.", afterDetail: cost.auditDetail)
  }

  private func suggestedCostRecords(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, customerProfileID: UUID?, vendorProfileID: UUID?, accountID: UUID?, evidenceID: UUID?, budgetCode: String, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [CostRecord] {
    costRecords.filter { $0.matches(orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, customerProfileID: customerProfileID, vendorProfileID: vendorProfileID, accountID: accountID, evidenceID: evidenceID, budgetCode: budgetCode, ownerTeam: ownerTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedCostRecords(for order: TrackedOrder) -> [CostRecord] {
    suggestedCostRecords(orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, vendorProfileID: suggestedVendorProfiles(for: order).first?.id, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: order.customer, context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedCostRecords(for email: ForwardedEmailIntake) -> [CostRecord] {
    suggestedCostRecords(orderID: email.linkedOrderID, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: email).first?.id, customerProfileID: suggestedCustomerProfiles(for: email).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(email.detectedMerchant) \(email.detectedOrderNumber) \(email.detectedDestinationAddress)", linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString)
  }

  func suggestedCostRecords(for item: ImportQueueItem) -> [CostRecord] {
    suggestedCostRecords(orderID: item.suggestedLinkedOrderID, shipmentGroupID: item.suggestedShipmentGroupID, packageContentID: suggestedPackageContents(for: item).first?.id, customerProfileID: suggestedCustomerProfiles(for: item).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(item.rawSummary) \(item.notes)", linkedEntityType: .importQueueItem, linkedEntityID: item.id.uuidString)
  }

  func suggestedCostRecords(for candidate: AcceptanceCandidate) -> [CostRecord] {
    suggestedCostRecords(orderID: candidate.suggestedLinkedOrderID, shipmentGroupID: candidate.suggestedShipmentGroupID, packageContentID: suggestedPackageContents(for: candidate).first?.id, customerProfileID: suggestedCustomerProfiles(for: candidate).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(candidate.detectedMerchant) \(candidate.detectedDestinationAddress)", linkedEntityType: candidate.reviewTaskLinkedEntityType, linkedEntityID: candidate.sourceID.uuidString)
  }

  func suggestedCostRecords(for group: ShipmentGroup) -> [CostRecord] {
    suggestedCostRecords(orderID: group.primaryOrderID, shipmentGroupID: group.id, packageContentID: suggestedPackageContents(for: group).first?.id, customerProfileID: suggestedCustomerProfiles(for: group).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: group.relatedEvidenceIDs.first, budgetCode: "", ownerTeam: group.recipientCustomerSummary, context: "\(group.groupName) \(group.destinationSummary) \(group.statusSummary)", linkedEntityType: .shipmentGroup, linkedEntityID: group.id.uuidString)
  }

  func suggestedCostRecords(for event: CarrierTrackingEvent) -> [CostRecord] {
    suggestedCostRecords(orderID: event.orderID, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: event).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(event.carrier) \(event.trackingNumber) \(event.detail)", linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString)
  }

  func suggestedCostRecords(for attachment: EvidenceAttachment) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: attachment).first?.id, customerProfileID: suggestedCustomerProfiles(for: attachment).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: attachment.id, budgetCode: "", ownerTeam: "", context: attachment.summary, linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString)
  }

  func suggestedCostRecords(for task: ReviewTask) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: task).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: task.assignee, context: "\(task.title) \(task.summary)", linkedEntityType: task.linkedEntityType, linkedEntityID: task.linkedEntityID)
  }

  func suggestedCostRecords(for note: HandoffNote) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: note).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: note.assignee, context: "\(note.title) \(note.summary) \(note.notes)", linkedEntityType: note.linkedEntityType, linkedEntityID: note.linkedEntityID)
  }

  func suggestedCostRecords(for issue: ValidationIssue) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: issue).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(issue.title) \(issue.detail)", linkedEntityType: issue.linkedEntityType, linkedEntityID: issue.entityID)
  }

  func suggestedCostRecords(for issue: ReconciliationIssue) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: issue).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(issue.title) \(issue.summary) \(issue.detectedValue)", linkedEntityType: .reconciliationIssue, linkedEntityID: issue.id)
  }

  func suggestedCostRecords(for address: DestinationAddressRecord) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: address).first?.id, customerProfileID: address.customerProfileID, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: address.organisationTeam, context: "\(address.label) \(address.addressLineSummary)", linkedEntityType: .destinationAddress, linkedEntityID: address.id.uuidString)
  }

  func suggestedCostRecords(for instruction: DeliveryInstructionRecord) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: instruction).first?.id, customerProfileID: instruction.customerProfileID, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(instruction.title) \(instruction.instructionSummary)", linkedEntityType: .deliveryInstruction, linkedEntityID: instruction.id.uuidString)
  }

  func suggestedCostRecords(for content: PackageContentRecord) -> [CostRecord] {
    suggestedCostRecords(orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, customerProfileID: content.customerProfileID, vendorProfileID: nil, accountID: nil, evidenceID: content.evidenceAttachmentIDs.first, budgetCode: "", ownerTeam: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedCostRecords(for profile: CustomerRecipientProfile) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: profile).first?.id, customerProfileID: profile.id, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: profile.organisationTeam, context: "\(profile.displayName) \(profile.organisationTeam)", linkedEntityType: .customerProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedCostRecords(for contact: ContactDirectoryEntry) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: contact).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: contact.organisation, context: "\(contact.organisation) \(contact.notes)", linkedEntityType: .contact, linkedEntityID: contact.id.uuidString)
  }

  func suggestedCostRecords(for account: AccountCredentialRecord) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: account).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: account.id, evidenceID: nil, budgetCode: "", ownerTeam: account.organisation, context: "\(account.accountName) \(account.organisation) \(account.notes)", linkedEntityType: .account, linkedEntityID: account.id.uuidString)
  }

  func suggestedCostRecords(for profile: VendorProfile) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: profile).first?.id, customerProfileID: nil, vendorProfileID: profile.id, accountID: profile.defaultAccountID, evidenceID: nil, budgetCode: "", ownerTeam: profile.primaryOrganisation, context: "\(profile.name) \(profile.primaryOrganisation) \(profile.serviceLevelNotes)", linkedEntityType: .vendorProfile, linkedEntityID: profile.id.uuidString)
  }

  func suggestedCostRecords(for policy: SLAPolicy) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: policy).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: "", context: "\(policy.name) \(policy.conditionSummary)", linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString)
  }

  func suggestedCostRecords(for playbook: ExceptionPlaybook) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: playbook).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: playbook.escalationContact, context: "\(playbook.name) \(playbook.triggerSummary)", linkedEntityType: .exceptionPlaybook, linkedEntityID: playbook.id.uuidString)
  }

  func suggestedCostRecords(for draft: DraftMessage) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: draft).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: draft.recipient, context: "\(draft.subject) \(draft.body)", linkedEntityType: draft.linkedEntityType, linkedEntityID: draft.linkedEntityID)
  }

  func suggestedCostRecords(for item: WorkbenchItem) -> [CostRecord] {
    suggestedCostRecords(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, budgetCode: "", ownerTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredReturnClaims(claimType: ReturnClaimType?, claimStatus: ReturnClaimStatus?, requestedOutcome: ReturnClaimOutcome?, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [ReturnClaimRecord] {
    returnClaims.filter { claim in
      let matchesType = claimType == nil || claim.claimType == claimType
      let matchesStatus = claimStatus == nil || claim.claimStatus == claimStatus
      let matchesOutcome = requestedOutcome == nil || claim.requestedOutcome == requestedOutcome
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || claim.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || claim.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || claim.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || claim.reviewState == reviewState
      return matchesType && matchesStatus && matchesOutcome && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addReturnClaimPlaceholder() {
    let order = orders.first
    let group = shipmentGroups.first
    let content = packageContents.first
    let cost = costRecords.first
    let claim = ReturnClaimRecord(title: "New return or claim \(returnClaims.count + 1)", linkedEntityType: .order, linkedEntityID: order?.id.uuidString ?? "Unlinked", orderID: order?.id, shipmentGroupID: group?.id, packageContentID: content?.id, costRecordID: cost?.id, customerProfileID: order.flatMap { suggestedCustomerProfiles(for: $0).first?.id } ?? customerRecipientProfiles.first?.id, vendorProfileID: nil, accountID: nil, claimType: .returnRequest, reasonSummary: "Local placeholder for return, exchange, refund, or claim review.", requestedOutcome: .replacement, claimStatus: .draft, refundReplacementAmountText: "0.00", currency: "AUD", evidenceAttachmentIDs: [], carrierTrackingEventIDs: [], assignedOwnerTeam: order?.customer ?? "Operations", dueDate: "To schedule", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    returnClaims.insert(claim, at: 0)
    persistReturnClaims()
    logAudit(action: .created, entityType: .returnClaim, entityID: claim.id.uuidString, entityLabel: claim.title, summary: "Return or claim placeholder added.", afterDetail: claim.auditDetail)
  }

  func updateReturnClaim(_ claim: ReturnClaimRecord) {
    guard let index = returnClaims.firstIndex(where: { $0.id == claim.id }) else { return }
    let beforeDetail = returnClaims[index].auditDetail
    returnClaims[index] = claim
    persistReturnClaims()
    logAudit(action: .edited, entityType: .returnClaim, entityID: claim.id.uuidString, entityLabel: claim.title, summary: "Return or claim details updated.", beforeDetail: beforeDetail, afterDetail: claim.auditDetail)
  }

  func markReturnClaimSubmitted(_ claim: ReturnClaimRecord) {
    updateReturnClaimStatus(claim, status: .submitted, reviewState: .monitor, summary: "Return or claim submitted locally.", action: .created)
  }

  func markReturnClaimApproved(_ claim: ReturnClaimRecord) {
    updateReturnClaimStatus(claim, status: .approved, reviewState: .accepted, summary: "Return or claim approved locally.", action: .completed)
  }

  func markReturnClaimResolved(_ claim: ReturnClaimRecord) {
    updateReturnClaimStatus(claim, status: .resolved, reviewState: .accepted, summary: "Return or claim resolved locally.", action: .completed)
  }

  func markReturnClaimDisputed(_ claim: ReturnClaimRecord) {
    updateReturnClaimStatus(claim, status: .disputed, reviewState: .needsReview, summary: "Return or claim marked disputed.", action: .edited, forceHighRisk: true)
  }

  func markReturnClaimReviewed(_ claim: ReturnClaimRecord) {
    guard let index = returnClaims.firstIndex(where: { $0.id == claim.id }) else { return }
    let beforeDetail = returnClaims[index].auditDetail
    returnClaims[index].reviewState = .accepted
    returnClaims[index].lastReviewedDate = Self.auditTimestamp()
    persistReturnClaims()
    logAudit(action: .reviewed, entityType: .returnClaim, entityID: returnClaims[index].id.uuidString, entityLabel: returnClaims[index].title, summary: "Return or claim marked reviewed.", beforeDetail: beforeDetail, afterDetail: returnClaims[index].auditDetail)
  }

  func removeReturnClaim(_ claim: ReturnClaimRecord) {
    guard let index = returnClaims.firstIndex(where: { $0.id == claim.id }) else { return }
    let removed = returnClaims.remove(at: index)
    persistReturnClaims()
    logAudit(action: .removed, entityType: .returnClaim, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Return or claim removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from claim: ReturnClaimRecord) {
    createReviewTask(linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString, label: claim.title, summary: "Review \(claim.claimType.rawValue): \(claim.reasonSummary). Requested outcome: \(claim.requestedOutcome.rawValue).", priority: claim.riskLevel == .critical ? .urgent : claim.riskLevel == .high ? .high : .normal, assignee: claim.assignedOwnerTeam)
  }

  func createDraftMessage(from claim: ReturnClaimRecord) {
    createDraftMessage(linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString, label: claim.title, recipient: claim.assignedOwnerTeam)
    logAudit(action: .created, entityType: .returnClaim, entityID: claim.id.uuidString, entityLabel: claim.title, summary: "Draft message created from return or claim.", afterDetail: claim.auditDetail)
  }

  private func updateReturnClaimStatus(_ claim: ReturnClaimRecord, status: ReturnClaimStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = returnClaims.firstIndex(where: { $0.id == claim.id }) else { return }
    let beforeDetail = returnClaims[index].auditDetail
    returnClaims[index].claimStatus = status
    returnClaims[index].reviewState = reviewState
    returnClaims[index].lastReviewedDate = Self.auditTimestamp()
    if forceHighRisk {
      returnClaims[index].riskLevel = returnClaims[index].riskLevel == .critical ? .critical : .high
    }
    persistReturnClaims()
    logAudit(action: action, entityType: .returnClaim, entityID: returnClaims[index].id.uuidString, entityLabel: returnClaims[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: returnClaims[index].auditDetail)
  }

  private func suggestedReturnClaims(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, costRecordID: UUID?, customerProfileID: UUID?, vendorProfileID: UUID?, accountID: UUID?, evidenceID: UUID?, trackingEventID: UUID?, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [ReturnClaimRecord] {
    returnClaims.filter { $0.matches(orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, costRecordID: costRecordID, customerProfileID: customerProfileID, vendorProfileID: vendorProfileID, accountID: accountID, evidenceID: evidenceID, trackingEventID: trackingEventID, ownerTeam: ownerTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedReturnClaims(for order: TrackedOrder) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, costRecordID: suggestedCostRecords(for: order).first?.id, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, vendorProfileID: suggestedVendorProfiles(for: order).first?.id, accountID: nil, evidenceID: nil, trackingEventID: nil, ownerTeam: order.customer, context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedReturnClaims(for content: PackageContentRecord) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, costRecordID: suggestedCostRecords(for: content).first?.id, customerProfileID: content.customerProfileID, vendorProfileID: nil, accountID: nil, evidenceID: content.evidenceAttachmentIDs.first, trackingEventID: nil, ownerTeam: "", context: "\(content.title) \(content.itemSummary) \(content.discrepancySummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedReturnClaims(for cost: CostRecord) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: cost.orderID, shipmentGroupID: cost.shipmentGroupID, packageContentID: cost.packageContentID, costRecordID: cost.id, customerProfileID: cost.customerProfileID, vendorProfileID: cost.vendorProfileID, accountID: cost.accountID, evidenceID: cost.evidenceAttachmentIDs.first, trackingEventID: nil, ownerTeam: cost.costOwnerTeam, context: "\(cost.title) \(cost.notes)", linkedEntityType: .costRecord, linkedEntityID: cost.id.uuidString)
  }

  func suggestedReturnClaims(for item: WorkbenchItem) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, costRecordID: suggestedCostRecords(for: item).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, trackingEventID: nil, ownerTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func suggestedReturnClaims(for email: ForwardedEmailIntake) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: email.linkedOrderID, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: email).first?.id, costRecordID: suggestedCostRecords(for: email).first?.id, customerProfileID: suggestedCustomerProfiles(for: email).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: nil, trackingEventID: nil, ownerTeam: "", context: "\(email.detectedMerchant) \(email.detectedOrderNumber) \(email.rawBodyPreview)", linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString)
  }

  func suggestedReturnClaims(for event: CarrierTrackingEvent) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: event.orderID, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: event).first?.id, costRecordID: suggestedCostRecords(for: event).first?.id, customerProfileID: nil, vendorProfileID: nil, accountID: nil, evidenceID: nil, trackingEventID: event.id, ownerTeam: "", context: "\(event.carrier) \(event.trackingNumber) \(event.detail)", linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString)
  }

  func suggestedReturnClaims(for attachment: EvidenceAttachment) -> [ReturnClaimRecord] {
    suggestedReturnClaims(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: attachment).first?.id, costRecordID: suggestedCostRecords(for: attachment).first?.id, customerProfileID: suggestedCustomerProfiles(for: attachment).first?.id, vendorProfileID: nil, accountID: nil, evidenceID: attachment.id, trackingEventID: nil, ownerTeam: "", context: attachment.summary, linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString)
  }

  func filteredProcurementRequests(approvalStatus: ProcurementApprovalStatus?, procurementStatus: ProcurementStatus?, requesterTeam: String, assignedBuyerTeam: String, budgetCode: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [ProcurementRequest] {
    procurementRequests.filter { request in
      let matchesApproval = approvalStatus == nil || request.approvalStatus == approvalStatus
      let matchesStatus = procurementStatus == nil || request.procurementStatus == procurementStatus
      let matchesRequester = requesterTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.requesterTeam.localizedCaseInsensitiveContains(requesterTeam)
      let matchesBuyer = assignedBuyerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.assignedBuyerTeam.localizedCaseInsensitiveContains(assignedBuyerTeam)
      let matchesBudget = budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.budgetCode.localizedCaseInsensitiveContains(budgetCode)
      let matchesRisk = riskLevel == nil || request.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || request.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || request.reviewState == reviewState
      return matchesApproval && matchesStatus && matchesRequester && matchesBuyer && matchesBudget && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addProcurementRequestPlaceholder() {
    let content = packageContents.first
    let cost = costRecords.first
    let claim = returnClaims.first
    let request = ProcurementRequest(title: "New procurement request \(procurementRequests.count + 1)", linkedEntityType: .packageContent, linkedEntityID: content?.id.uuidString ?? "Unlinked", requesterTeam: "Operations", requestedDate: Self.auditTimestamp(), neededByDate: "To schedule", vendorProfileID: vendorProfiles.first?.id, accountID: accountCredentialRecords.first?.id, customerProfileID: customerRecipientProfiles.first?.id, destinationAddressID: destinationAddresses.first?.id, packageContentID: content?.id, costRecordID: cost?.id, returnClaimID: claim?.id, requestedItemsSummary: "Items to procure locally.", estimatedCostText: "0.00", currency: "AUD", budgetCode: "To confirm", approvalStatus: .draft, procurementStatus: .requested, assignedBuyerTeam: "Procurement Desk", evidenceAttachmentIDs: [], notes: "Local procurement placeholder. No purchasing or supplier system actions are performed.", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    procurementRequests.insert(request, at: 0)
    persistProcurementRequests()
    logAudit(action: .created, entityType: .procurementRequest, entityID: request.id.uuidString, entityLabel: request.title, summary: "Procurement request placeholder added.", afterDetail: request.auditDetail)
  }

  func updateProcurementRequest(_ request: ProcurementRequest) {
    guard let index = procurementRequests.firstIndex(where: { $0.id == request.id }) else { return }
    let beforeDetail = procurementRequests[index].auditDetail
    procurementRequests[index] = request
    persistProcurementRequests()
    logAudit(action: .edited, entityType: .procurementRequest, entityID: request.id.uuidString, entityLabel: request.title, summary: "Procurement request details updated.", beforeDetail: beforeDetail, afterDetail: request.auditDetail)
  }

  func markProcurementRequestApproved(_ request: ProcurementRequest) {
    updateProcurementRequestState(request, approvalStatus: .approved, procurementStatus: .approvedToOrder, reviewState: .accepted, summary: "Procurement request approved locally.", action: .completed)
  }

  func markProcurementRequestOrdered(_ request: ProcurementRequest) {
    updateProcurementRequestState(request, approvalStatus: .approved, procurementStatus: .ordered, reviewState: .monitor, summary: "Procurement request marked ordered locally.", action: .created)
  }

  func markProcurementRequestReceived(_ request: ProcurementRequest) {
    updateProcurementRequestState(request, approvalStatus: .approved, procurementStatus: .received, reviewState: .accepted, summary: "Procurement request marked received locally.", action: .completed)
  }

  func markProcurementRequestRejected(_ request: ProcurementRequest) {
    updateProcurementRequestState(request, approvalStatus: .rejected, procurementStatus: .blocked, reviewState: .needsReview, summary: "Procurement request rejected and needs review.", action: .edited, forceHighRisk: true)
  }

  func markProcurementRequestReviewed(_ request: ProcurementRequest) {
    guard let index = procurementRequests.firstIndex(where: { $0.id == request.id }) else { return }
    let beforeDetail = procurementRequests[index].auditDetail
    procurementRequests[index].reviewState = .accepted
    procurementRequests[index].lastReviewedDate = Self.auditTimestamp()
    persistProcurementRequests()
    logAudit(action: .reviewed, entityType: .procurementRequest, entityID: procurementRequests[index].id.uuidString, entityLabel: procurementRequests[index].title, summary: "Procurement request marked reviewed.", beforeDetail: beforeDetail, afterDetail: procurementRequests[index].auditDetail)
  }

  func removeProcurementRequest(_ request: ProcurementRequest) {
    guard let index = procurementRequests.firstIndex(where: { $0.id == request.id }) else { return }
    let removed = procurementRequests.remove(at: index)
    persistProcurementRequests()
    logAudit(action: .removed, entityType: .procurementRequest, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Procurement request removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from request: ProcurementRequest) {
    createReviewTask(linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString, label: request.title, summary: "Review procurement: \(request.requestedItemsSummary). Budget \(request.budgetCode).", priority: request.riskLevel == .critical ? .urgent : request.riskLevel == .high ? .high : .normal, assignee: request.assignedBuyerTeam)
  }

  func createDraftMessage(from request: ProcurementRequest) {
    createDraftMessage(linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString, label: request.title, recipient: request.assignedBuyerTeam)
    logAudit(action: .created, entityType: .procurementRequest, entityID: request.id.uuidString, entityLabel: request.title, summary: "Draft message created from procurement request.", afterDetail: request.auditDetail)
  }

  private func updateProcurementRequestState(_ request: ProcurementRequest, approvalStatus: ProcurementApprovalStatus, procurementStatus: ProcurementStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = procurementRequests.firstIndex(where: { $0.id == request.id }) else { return }
    let beforeDetail = procurementRequests[index].auditDetail
    procurementRequests[index].approvalStatus = approvalStatus
    procurementRequests[index].procurementStatus = procurementStatus
    procurementRequests[index].reviewState = reviewState
    procurementRequests[index].lastReviewedDate = Self.auditTimestamp()
    if forceHighRisk {
      procurementRequests[index].riskLevel = procurementRequests[index].riskLevel == .critical ? .critical : .high
    }
    persistProcurementRequests()
    logAudit(action: action, entityType: .procurementRequest, entityID: procurementRequests[index].id.uuidString, entityLabel: procurementRequests[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: procurementRequests[index].auditDetail)
  }

  private func suggestedProcurementRequests(vendorProfileID: UUID?, accountID: UUID?, customerProfileID: UUID?, destinationAddressID: UUID?, packageContentID: UUID?, costRecordID: UUID?, returnClaimID: UUID?, evidenceID: UUID?, budgetCode: String, requesterTeam: String, buyerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [ProcurementRequest] {
    procurementRequests.filter { $0.matches(vendorProfileID: vendorProfileID, accountID: accountID, customerProfileID: customerProfileID, destinationAddressID: destinationAddressID, packageContentID: packageContentID, costRecordID: costRecordID, returnClaimID: returnClaimID, evidenceID: evidenceID, budgetCode: budgetCode, requesterTeam: requesterTeam, buyerTeam: buyerTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedProcurementRequests(for order: TrackedOrder) -> [ProcurementRequest] {
    suggestedProcurementRequests(vendorProfileID: suggestedVendorProfiles(for: order).first?.id, accountID: nil, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, destinationAddressID: suggestedDestinationAddresses(for: order).first?.id, packageContentID: suggestedPackageContents(for: order).first?.id, costRecordID: suggestedCostRecords(for: order).first?.id, returnClaimID: suggestedReturnClaims(for: order).first?.id, evidenceID: nil, budgetCode: "", requesterTeam: order.customer, buyerTeam: "", context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedProcurementRequests(for content: PackageContentRecord) -> [ProcurementRequest] {
    suggestedProcurementRequests(vendorProfileID: nil, accountID: nil, customerProfileID: content.customerProfileID, destinationAddressID: content.destinationAddressID, packageContentID: content.id, costRecordID: suggestedCostRecords(for: content).first?.id, returnClaimID: suggestedReturnClaims(for: content).first?.id, evidenceID: content.evidenceAttachmentIDs.first, budgetCode: "", requesterTeam: "", buyerTeam: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedProcurementRequests(for cost: CostRecord) -> [ProcurementRequest] {
    suggestedProcurementRequests(vendorProfileID: cost.vendorProfileID, accountID: cost.accountID, customerProfileID: cost.customerProfileID, destinationAddressID: nil, packageContentID: cost.packageContentID, costRecordID: cost.id, returnClaimID: suggestedReturnClaims(for: cost).first?.id, evidenceID: cost.evidenceAttachmentIDs.first, budgetCode: cost.budgetCode, requesterTeam: cost.costOwnerTeam, buyerTeam: "", context: "\(cost.title) \(cost.notes)", linkedEntityType: .costRecord, linkedEntityID: cost.id.uuidString)
  }

  func suggestedProcurementRequests(for claim: ReturnClaimRecord) -> [ProcurementRequest] {
    suggestedProcurementRequests(vendorProfileID: claim.vendorProfileID, accountID: claim.accountID, customerProfileID: claim.customerProfileID, destinationAddressID: nil, packageContentID: claim.packageContentID, costRecordID: claim.costRecordID, returnClaimID: claim.id, evidenceID: claim.evidenceAttachmentIDs.first, budgetCode: "", requesterTeam: claim.assignedOwnerTeam, buyerTeam: "", context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedProcurementRequests(for item: WorkbenchItem) -> [ProcurementRequest] {
    suggestedProcurementRequests(vendorProfileID: nil, accountID: nil, customerProfileID: nil, destinationAddressID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, costRecordID: suggestedCostRecords(for: item).first?.id, returnClaimID: suggestedReturnClaims(for: item).first?.id, evidenceID: nil, budgetCode: "", requesterTeam: item.assignee, buyerTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredReceivingInspections(inspectionType: ReceivingInspectionType?, inspectionStatus: ReceivingInspectionStatus?, discrepancyType: ReceivingDiscrepancyType?, inspectorTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [ReceivingInspectionRecord] {
    receivingInspections.filter { inspection in
      let matchesType = inspectionType == nil || inspection.inspectionType == inspectionType
      let matchesStatus = inspectionStatus == nil || inspection.inspectionStatus == inspectionStatus
      let matchesDiscrepancy = discrepancyType == nil || inspection.discrepancyType == discrepancyType
      let matchesInspector = inspectorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inspection.assignedInspectorTeam.localizedCaseInsensitiveContains(inspectorTeam)
      let matchesRisk = riskLevel == nil || inspection.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || inspection.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || inspection.reviewState == reviewState
      return matchesType && matchesStatus && matchesDiscrepancy && matchesInspector && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addReceivingInspectionPlaceholder() {
    let content = packageContents.first
    let request = procurementRequests.first
    let claim = returnClaims.first
    let inspection = ReceivingInspectionRecord(title: "New receiving inspection \(receivingInspections.count + 1)", linkedEntityType: .packageContent, linkedEntityID: content?.id.uuidString ?? "Unlinked", orderID: content?.orderID, shipmentGroupID: content?.shipmentGroupID, packageContentID: content?.id, procurementRequestID: request?.id, returnClaimID: claim?.id, destinationAddressID: content?.destinationAddressID, customerProfileID: content?.customerProfileID, carrierTrackingEventIDs: [], evidenceAttachmentIDs: [], inspectionType: .inbound, inspectionStatus: .pending, expectedItemSummary: content?.itemSummary ?? "Expected items to inspect locally.", receivedItemSummary: "Received items not inspected yet.", quantityExpected: content?.expectedQuantity ?? 1, quantityReceived: 0, conditionSummary: "Condition not inspected yet.", discrepancyType: .none, discrepancySummary: "No discrepancy recorded yet.", assignedInspectorTeam: "Receiving Desk", inspectionDate: "Not inspected", dueDate: "To schedule", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    receivingInspections.insert(inspection, at: 0)
    persistReceivingInspections()
    logAudit(action: .created, entityType: .receivingInspection, entityID: inspection.id.uuidString, entityLabel: inspection.title, summary: "Receiving inspection placeholder added.", afterDetail: inspection.auditDetail)
  }

  func updateReceivingInspection(_ inspection: ReceivingInspectionRecord) {
    guard let index = receivingInspections.firstIndex(where: { $0.id == inspection.id }) else { return }
    let beforeDetail = receivingInspections[index].auditDetail
    receivingInspections[index] = inspection
    persistReceivingInspections()
    logAudit(action: .edited, entityType: .receivingInspection, entityID: inspection.id.uuidString, entityLabel: inspection.title, summary: "Receiving inspection details updated.", beforeDetail: beforeDetail, afterDetail: inspection.auditDetail)
  }

  func markReceivingInspectionInspected(_ inspection: ReceivingInspectionRecord) {
    updateReceivingInspectionStatus(inspection, status: .inspected, discrepancyType: .none, reviewState: .accepted, summary: "Receiving inspection marked inspected locally.", action: .completed)
  }

  func markReceivingInspectionDiscrepancy(_ inspection: ReceivingInspectionRecord) {
    updateReceivingInspectionStatus(inspection, status: .discrepancy, discrepancyType: inspection.discrepancyType == .none ? .quantityMismatch : inspection.discrepancyType, reviewState: .needsReview, summary: "Receiving inspection discrepancy marked.", action: .edited, forceHighRisk: true)
  }

  func markReceivingInspectionResolved(_ inspection: ReceivingInspectionRecord) {
    updateReceivingInspectionStatus(inspection, status: .resolved, discrepancyType: inspection.discrepancyType, reviewState: .accepted, summary: "Receiving inspection resolved locally.", action: .completed)
  }

  func markReceivingInspectionBlocked(_ inspection: ReceivingInspectionRecord) {
    updateReceivingInspectionStatus(inspection, status: .blocked, discrepancyType: inspection.discrepancyType == .none ? .other : inspection.discrepancyType, reviewState: .needsReview, summary: "Receiving inspection blocked and needs review.", action: .edited, forceHighRisk: true)
  }

  func markReceivingInspectionReviewed(_ inspection: ReceivingInspectionRecord) {
    guard let index = receivingInspections.firstIndex(where: { $0.id == inspection.id }) else { return }
    let beforeDetail = receivingInspections[index].auditDetail
    receivingInspections[index].reviewState = .accepted
    receivingInspections[index].lastReviewedDate = Self.auditTimestamp()
    persistReceivingInspections()
    logAudit(action: .reviewed, entityType: .receivingInspection, entityID: receivingInspections[index].id.uuidString, entityLabel: receivingInspections[index].title, summary: "Receiving inspection marked reviewed.", beforeDetail: beforeDetail, afterDetail: receivingInspections[index].auditDetail)
  }

  func removeReceivingInspection(_ inspection: ReceivingInspectionRecord) {
    guard let index = receivingInspections.firstIndex(where: { $0.id == inspection.id }) else { return }
    let removed = receivingInspections.remove(at: index)
    persistReceivingInspections()
    logAudit(action: .removed, entityType: .receivingInspection, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Receiving inspection removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from inspection: ReceivingInspectionRecord) {
    createReviewTask(linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString, label: inspection.title, summary: "Review receiving inspection: \(inspection.discrepancySummary). Quantity \(inspection.quantityReceived)/\(inspection.quantityExpected).", priority: inspection.riskLevel == .critical ? .urgent : inspection.riskLevel == .high ? .high : .normal, assignee: inspection.assignedInspectorTeam)
  }

  func createDraftMessage(from inspection: ReceivingInspectionRecord) {
    createDraftMessage(linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString, label: inspection.title, recipient: inspection.assignedInspectorTeam)
    logAudit(action: .created, entityType: .receivingInspection, entityID: inspection.id.uuidString, entityLabel: inspection.title, summary: "Draft message created from receiving inspection.", afterDetail: inspection.auditDetail)
  }

  private func updateReceivingInspectionStatus(_ inspection: ReceivingInspectionRecord, status: ReceivingInspectionStatus, discrepancyType: ReceivingDiscrepancyType, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = receivingInspections.firstIndex(where: { $0.id == inspection.id }) else { return }
    let beforeDetail = receivingInspections[index].auditDetail
    receivingInspections[index].inspectionStatus = status
    receivingInspections[index].discrepancyType = discrepancyType
    receivingInspections[index].reviewState = reviewState
    receivingInspections[index].lastReviewedDate = Self.auditTimestamp()
    if forceHighRisk {
      receivingInspections[index].riskLevel = receivingInspections[index].riskLevel == .critical ? .critical : .high
    }
    persistReceivingInspections()
    logAudit(action: action, entityType: .receivingInspection, entityID: receivingInspections[index].id.uuidString, entityLabel: receivingInspections[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: receivingInspections[index].auditDetail)
  }

  private func suggestedReceivingInspections(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, procurementRequestID: UUID?, returnClaimID: UUID?, destinationAddressID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, trackingEventID: UUID?, inspectorTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [ReceivingInspectionRecord] {
    receivingInspections.filter { $0.matches(orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, procurementRequestID: procurementRequestID, returnClaimID: returnClaimID, destinationAddressID: destinationAddressID, customerProfileID: customerProfileID, evidenceID: evidenceID, trackingEventID: trackingEventID, inspectorTeam: inspectorTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedReceivingInspections(for order: TrackedOrder) -> [ReceivingInspectionRecord] {
    suggestedReceivingInspections(orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, procurementRequestID: suggestedProcurementRequests(for: order).first?.id, returnClaimID: suggestedReturnClaims(for: order).first?.id, destinationAddressID: suggestedDestinationAddresses(for: order).first?.id, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, evidenceID: nil, trackingEventID: nil, inspectorTeam: "", context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedReceivingInspections(for content: PackageContentRecord) -> [ReceivingInspectionRecord] {
    suggestedReceivingInspections(orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, procurementRequestID: suggestedProcurementRequests(for: content).first?.id, returnClaimID: suggestedReturnClaims(for: content).first?.id, destinationAddressID: content.destinationAddressID, customerProfileID: content.customerProfileID, evidenceID: content.evidenceAttachmentIDs.first, trackingEventID: nil, inspectorTeam: "", context: "\(content.title) \(content.itemSummary) \(content.discrepancySummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedReceivingInspections(for request: ProcurementRequest) -> [ReceivingInspectionRecord] {
    suggestedReceivingInspections(orderID: nil, shipmentGroupID: nil, packageContentID: request.packageContentID, procurementRequestID: request.id, returnClaimID: request.returnClaimID, destinationAddressID: request.destinationAddressID, customerProfileID: request.customerProfileID, evidenceID: request.evidenceAttachmentIDs.first, trackingEventID: nil, inspectorTeam: request.assignedBuyerTeam, context: "\(request.title) \(request.requestedItemsSummary) \(request.notes)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedReceivingInspections(for claim: ReturnClaimRecord) -> [ReceivingInspectionRecord] {
    suggestedReceivingInspections(orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, packageContentID: claim.packageContentID, procurementRequestID: suggestedProcurementRequests(for: claim).first?.id, returnClaimID: claim.id, destinationAddressID: nil, customerProfileID: claim.customerProfileID, evidenceID: claim.evidenceAttachmentIDs.first, trackingEventID: claim.carrierTrackingEventIDs.first, inspectorTeam: claim.assignedOwnerTeam, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedReceivingInspections(for item: WorkbenchItem) -> [ReceivingInspectionRecord] {
    suggestedReceivingInspections(orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, procurementRequestID: suggestedProcurementRequests(for: item).first?.id, returnClaimID: suggestedReturnClaims(for: item).first?.id, destinationAddressID: nil, customerProfileID: nil, evidenceID: nil, trackingEventID: nil, inspectorTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredInventoryReceipts(receiptType: InventoryReceiptType?, stockHandoffStatus: InventoryStockHandoffStatus?, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [InventoryReceiptRecord] {
    inventoryReceipts.filter { receipt in
      let matchesType = receiptType == nil || receipt.receiptType == receiptType
      let matchesStatus = stockHandoffStatus == nil || receipt.stockHandoffStatus == stockHandoffStatus
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || receipt.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || receipt.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || receipt.reviewState == reviewState
      return matchesType && matchesStatus && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addInventoryReceiptPlaceholder() {
    let inspection = receivingInspections.first
    let content = packageContents.first
    let receipt = InventoryReceiptRecord(title: "New inventory receipt \(inventoryReceipts.count + 1)", linkedEntityType: .receivingInspection, linkedEntityID: inspection?.id.uuidString ?? "Unlinked", receivingInspectionID: inspection?.id, orderID: inspection?.orderID ?? content?.orderID, shipmentGroupID: inspection?.shipmentGroupID ?? content?.shipmentGroupID, packageContentID: inspection?.packageContentID ?? content?.id, procurementRequestID: inspection?.procurementRequestID, returnClaimID: inspection?.returnClaimID, destinationAddressID: inspection?.destinationAddressID ?? content?.destinationAddressID, customerProfileID: inspection?.customerProfileID ?? content?.customerProfileID, evidenceAttachmentIDs: inspection?.evidenceAttachmentIDs ?? [], receiptType: .stockReceipt, stockHandoffStatus: .pending, itemSummary: inspection?.receivedItemSummary ?? content?.itemSummary ?? "Items to stock or hand off locally.", quantityReceived: inspection?.quantityReceived ?? 0, quantityAccepted: 0, quantityRejected: 0, storageLocationSummary: "To assign", assignedOwnerTeam: inspection?.assignedInspectorTeam ?? "Receiving Desk", receivedDate: "Not received", handoffDate: "To schedule", discrepancySummary: "No inventory receipt discrepancy recorded yet.", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    inventoryReceipts.insert(receipt, at: 0)
    persistInventoryReceipts()
    logAudit(action: .created, entityType: .inventoryReceipt, entityID: receipt.id.uuidString, entityLabel: receipt.title, summary: "Inventory receipt placeholder added.", afterDetail: receipt.auditDetail)
  }

  func updateInventoryReceipt(_ receipt: InventoryReceiptRecord) {
    guard let index = inventoryReceipts.firstIndex(where: { $0.id == receipt.id }) else { return }
    let beforeDetail = inventoryReceipts[index].auditDetail
    inventoryReceipts[index] = receipt
    persistInventoryReceipts()
    logAudit(action: .edited, entityType: .inventoryReceipt, entityID: receipt.id.uuidString, entityLabel: receipt.title, summary: "Inventory receipt details updated.", beforeDetail: beforeDetail, afterDetail: receipt.auditDetail)
  }

  func markInventoryReceiptStocked(_ receipt: InventoryReceiptRecord) {
    updateInventoryReceiptStatus(receipt, status: .stocked, reviewState: .accepted, summary: "Inventory receipt marked stocked locally.", action: .completed)
  }

  func markInventoryReceiptHandedOff(_ receipt: InventoryReceiptRecord) {
    updateInventoryReceiptStatus(receipt, status: .handedOff, reviewState: .accepted, summary: "Inventory receipt marked handed off locally.", action: .completed)
  }

  func markInventoryReceiptPartiallyAccepted(_ receipt: InventoryReceiptRecord) {
    updateInventoryReceiptStatus(receipt, status: .partiallyAccepted, reviewState: .needsReview, summary: "Inventory receipt marked partially accepted.", action: .edited, forceHighRisk: true)
  }

  func markInventoryReceiptRejected(_ receipt: InventoryReceiptRecord) {
    updateInventoryReceiptStatus(receipt, status: .rejected, reviewState: .needsReview, summary: "Inventory receipt rejected and needs review.", action: .edited, forceHighRisk: true)
  }

  func markInventoryReceiptReviewed(_ receipt: InventoryReceiptRecord) {
    guard let index = inventoryReceipts.firstIndex(where: { $0.id == receipt.id }) else { return }
    let beforeDetail = inventoryReceipts[index].auditDetail
    inventoryReceipts[index].reviewState = .accepted
    inventoryReceipts[index].lastReviewedDate = Self.auditTimestamp()
    persistInventoryReceipts()
    logAudit(action: .reviewed, entityType: .inventoryReceipt, entityID: inventoryReceipts[index].id.uuidString, entityLabel: inventoryReceipts[index].title, summary: "Inventory receipt marked reviewed.", beforeDetail: beforeDetail, afterDetail: inventoryReceipts[index].auditDetail)
  }

  func removeInventoryReceipt(_ receipt: InventoryReceiptRecord) {
    guard let index = inventoryReceipts.firstIndex(where: { $0.id == receipt.id }) else { return }
    let removed = inventoryReceipts.remove(at: index)
    persistInventoryReceipts()
    logAudit(action: .removed, entityType: .inventoryReceipt, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Inventory receipt removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from receipt: InventoryReceiptRecord) {
    createReviewTask(linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString, label: receipt.title, summary: "Review inventory receipt: \(receipt.itemSummary). \(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted.", priority: receipt.riskLevel == .critical ? .urgent : receipt.riskLevel == .high ? .high : .normal, assignee: receipt.assignedOwnerTeam)
  }

  func createDraftMessage(from receipt: InventoryReceiptRecord) {
    createDraftMessage(linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString, label: receipt.title, recipient: receipt.assignedOwnerTeam)
    logAudit(action: .created, entityType: .inventoryReceipt, entityID: receipt.id.uuidString, entityLabel: receipt.title, summary: "Draft message created from inventory receipt.", afterDetail: receipt.auditDetail)
  }

  private func updateInventoryReceiptStatus(_ receipt: InventoryReceiptRecord, status: InventoryStockHandoffStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = inventoryReceipts.firstIndex(where: { $0.id == receipt.id }) else { return }
    let beforeDetail = inventoryReceipts[index].auditDetail
    inventoryReceipts[index].stockHandoffStatus = status
    inventoryReceipts[index].reviewState = reviewState
    inventoryReceipts[index].lastReviewedDate = Self.auditTimestamp()
    if status == .stocked || status == .handedOff {
      inventoryReceipts[index].quantityAccepted = max(inventoryReceipts[index].quantityAccepted, inventoryReceipts[index].quantityReceived - inventoryReceipts[index].quantityRejected)
    }
    if forceHighRisk {
      inventoryReceipts[index].riskLevel = inventoryReceipts[index].riskLevel == .critical ? .critical : .high
    }
    persistInventoryReceipts()
    logAudit(action: action, entityType: .inventoryReceipt, entityID: inventoryReceipts[index].id.uuidString, entityLabel: inventoryReceipts[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: inventoryReceipts[index].auditDetail)
  }

  private func suggestedInventoryReceipts(receivingInspectionID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, procurementRequestID: UUID?, returnClaimID: UUID?, destinationAddressID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [InventoryReceiptRecord] {
    inventoryReceipts.filter { $0.matches(receivingInspectionID: receivingInspectionID, orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, procurementRequestID: procurementRequestID, returnClaimID: returnClaimID, destinationAddressID: destinationAddressID, customerProfileID: customerProfileID, evidenceID: evidenceID, ownerTeam: ownerTeam, locationText: locationText, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedInventoryReceipts(for inspection: ReceivingInspectionRecord) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: inspection.id, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, packageContentID: inspection.packageContentID, procurementRequestID: inspection.procurementRequestID, returnClaimID: inspection.returnClaimID, destinationAddressID: inspection.destinationAddressID, customerProfileID: inspection.customerProfileID, evidenceID: inspection.evidenceAttachmentIDs.first, ownerTeam: inspection.assignedInspectorTeam, locationText: "", context: "\(inspection.title) \(inspection.receivedItemSummary) \(inspection.discrepancySummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedInventoryReceipts(for order: TrackedOrder) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: suggestedReceivingInspections(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, procurementRequestID: suggestedProcurementRequests(for: order).first?.id, returnClaimID: suggestedReturnClaims(for: order).first?.id, destinationAddressID: suggestedDestinationAddresses(for: order).first?.id, customerProfileID: suggestedCustomerProfiles(for: order).first?.id, evidenceID: nil, ownerTeam: order.customer, locationText: order.destination, context: "\(order.store) \(order.orderNumber) \(order.customer) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedInventoryReceipts(for content: PackageContentRecord) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: suggestedReceivingInspections(for: content).first?.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, procurementRequestID: suggestedProcurementRequests(for: content).first?.id, returnClaimID: suggestedReturnClaims(for: content).first?.id, destinationAddressID: content.destinationAddressID, customerProfileID: content.customerProfileID, evidenceID: content.evidenceAttachmentIDs.first, ownerTeam: "", locationText: "", context: "\(content.title) \(content.itemSummary) \(content.discrepancySummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedInventoryReceipts(for request: ProcurementRequest) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: suggestedReceivingInspections(for: request).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: request.packageContentID, procurementRequestID: request.id, returnClaimID: request.returnClaimID, destinationAddressID: request.destinationAddressID, customerProfileID: request.customerProfileID, evidenceID: request.evidenceAttachmentIDs.first, ownerTeam: request.assignedBuyerTeam, locationText: "", context: "\(request.title) \(request.requestedItemsSummary) \(request.notes)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedInventoryReceipts(for claim: ReturnClaimRecord) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: suggestedReceivingInspections(for: claim).first?.id, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, packageContentID: claim.packageContentID, procurementRequestID: suggestedProcurementRequests(for: claim).first?.id, returnClaimID: claim.id, destinationAddressID: nil, customerProfileID: claim.customerProfileID, evidenceID: claim.evidenceAttachmentIDs.first, ownerTeam: claim.assignedOwnerTeam, locationText: "", context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedInventoryReceipts(for item: WorkbenchItem) -> [InventoryReceiptRecord] {
    suggestedInventoryReceipts(receivingInspectionID: suggestedReceivingInspections(for: item).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, procurementRequestID: suggestedProcurementRequests(for: item).first?.id, returnClaimID: suggestedReturnClaims(for: item).first?.id, destinationAddressID: nil, customerProfileID: nil, evidenceID: nil, ownerTeam: item.assignee, locationText: item.summary, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredStorageLocations(locationType: StorageLocationType?, areaZone: String, ownerTeam: String, riskLevel: ShipmentRiskLevel?, enabledState: Bool?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [StorageLocationRecord] {
    storageLocations.filter { location in
      let matchesType = locationType == nil || location.locationType == locationType
      let matchesArea = areaZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.areaZone.localizedCaseInsensitiveContains(areaZone)
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || location.riskLevel == riskLevel
      let matchesEnabled = enabledState == nil || location.isEnabled == enabledState
      let matchesLinked = linkedEntityType == nil || location.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || location.reviewState == reviewState
      return matchesType && matchesArea && matchesOwner && matchesRisk && matchesEnabled && matchesLinked && matchesReview
    }
  }

  func addStorageLocationPlaceholder() {
    let receipt = inventoryReceipts.first
    let inspection = receivingInspections.first
    let location = StorageLocationRecord(title: "New storage location \(storageLocations.count + 1)", locationType: .bin, locationCode: "To assign", areaZone: "Unassigned", capacitySummary: "Capacity to confirm", currentUsageSummary: "No usage recorded yet.", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt?.id.uuidString ?? "Unlinked", inventoryReceiptIDs: receipt.map { [$0.id] } ?? [], receivingInspectionIDs: inspection.map { [$0.id] } ?? [], packageContentIDs: receipt?.packageContentID.map { [$0] } ?? [], orderIDs: receipt?.orderID.map { [$0] } ?? [], shipmentGroupIDs: receipt?.shipmentGroupID.map { [$0] } ?? [], assignedOwnerTeam: receipt?.assignedOwnerTeam ?? "Receiving Desk", accessNotes: "Local placeholder. No access control or warehouse system action is performed.", riskLevel: .medium, isEnabled: true, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    storageLocations.insert(location, at: 0)
    persistStorageLocations()
    logAudit(action: .created, entityType: .storageLocation, entityID: location.id.uuidString, entityLabel: location.title, summary: "Storage location placeholder added.", afterDetail: location.auditDetail)
  }

  func updateStorageLocation(_ location: StorageLocationRecord) {
    guard let index = storageLocations.firstIndex(where: { $0.id == location.id }) else { return }
    let beforeDetail = storageLocations[index].auditDetail
    storageLocations[index] = location
    persistStorageLocations()
    logAudit(action: .edited, entityType: .storageLocation, entityID: location.id.uuidString, entityLabel: location.title, summary: "Storage location details updated.", beforeDetail: beforeDetail, afterDetail: location.auditDetail)
  }

  func toggleStorageLocation(_ location: StorageLocationRecord) {
    guard let index = storageLocations.firstIndex(where: { $0.id == location.id }) else { return }
    let beforeDetail = storageLocations[index].auditDetail
    storageLocations[index].isEnabled.toggle()
    storageLocations[index].reviewState = storageLocations[index].isEnabled ? .monitor : .needsReview
    storageLocations[index].lastReviewedDate = Self.auditTimestamp()
    persistStorageLocations()
    logAudit(action: storageLocations[index].isEnabled ? .enabled : .disabled, entityType: .storageLocation, entityID: storageLocations[index].id.uuidString, entityLabel: storageLocations[index].title, summary: storageLocations[index].isEnabled ? "Storage location enabled." : "Storage location disabled.", beforeDetail: beforeDetail, afterDetail: storageLocations[index].auditDetail)
  }

  func markStorageLocationReviewed(_ location: StorageLocationRecord) {
    guard let index = storageLocations.firstIndex(where: { $0.id == location.id }) else { return }
    let beforeDetail = storageLocations[index].auditDetail
    storageLocations[index].reviewState = .accepted
    storageLocations[index].lastReviewedDate = Self.auditTimestamp()
    persistStorageLocations()
    logAudit(action: .reviewed, entityType: .storageLocation, entityID: storageLocations[index].id.uuidString, entityLabel: storageLocations[index].title, summary: "Storage location marked reviewed.", beforeDetail: beforeDetail, afterDetail: storageLocations[index].auditDetail)
  }

  func removeStorageLocation(_ location: StorageLocationRecord) {
    guard let index = storageLocations.firstIndex(where: { $0.id == location.id }) else { return }
    let removed = storageLocations.remove(at: index)
    persistStorageLocations()
    logAudit(action: .removed, entityType: .storageLocation, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Storage location removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from location: StorageLocationRecord) {
    createReviewTask(linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString, label: location.title, summary: "Review storage location \(location.locationCode): \(location.currentUsageSummary).", priority: location.riskLevel == .critical ? .urgent : location.riskLevel == .high ? .high : .normal, assignee: location.assignedOwnerTeam)
  }

  func createDraftMessage(from location: StorageLocationRecord) {
    createDraftMessage(linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString, label: location.title, recipient: location.assignedOwnerTeam)
    logAudit(action: .created, entityType: .storageLocation, entityID: location.id.uuidString, entityLabel: location.title, summary: "Draft message created from storage location.", afterDetail: location.auditDetail)
  }

  private func suggestedStorageLocations(inventoryReceiptID: UUID?, receivingInspectionID: UUID?, packageContentID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, ownerTeam: String, areaZone: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [StorageLocationRecord] {
    storageLocations.filter { $0.matches(inventoryReceiptID: inventoryReceiptID, receivingInspectionID: receivingInspectionID, packageContentID: packageContentID, orderID: orderID, shipmentGroupID: shipmentGroupID, ownerTeam: ownerTeam, areaZone: areaZone, locationText: locationText, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedStorageLocations(for receipt: InventoryReceiptRecord) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: receipt.id, receivingInspectionID: receipt.receivingInspectionID, packageContentID: receipt.packageContentID, orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, ownerTeam: receipt.assignedOwnerTeam, areaZone: "", locationText: receipt.storageLocationSummary, context: "\(receipt.title) \(receipt.itemSummary) \(receipt.storageLocationSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedStorageLocations(for inspection: ReceivingInspectionRecord) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, receivingInspectionID: inspection.id, packageContentID: inspection.packageContentID, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, ownerTeam: inspection.assignedInspectorTeam, areaZone: "", locationText: "", context: "\(inspection.title) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedStorageLocations(for order: TrackedOrder) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, receivingInspectionID: suggestedReceivingInspections(for: order).first?.id, packageContentID: suggestedPackageContents(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, ownerTeam: order.customer, areaZone: "", locationText: order.destination, context: "\(order.store) \(order.orderNumber) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedStorageLocations(for content: PackageContentRecord) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, receivingInspectionID: suggestedReceivingInspections(for: content).first?.id, packageContentID: content.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, ownerTeam: "", areaZone: "", locationText: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedStorageLocations(for request: ProcurementRequest) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, receivingInspectionID: suggestedReceivingInspections(for: request).first?.id, packageContentID: request.packageContentID, orderID: nil, shipmentGroupID: nil, ownerTeam: request.assignedBuyerTeam, areaZone: "", locationText: "", context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedStorageLocations(for claim: ReturnClaimRecord) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, receivingInspectionID: suggestedReceivingInspections(for: claim).first?.id, packageContentID: claim.packageContentID, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, ownerTeam: claim.assignedOwnerTeam, areaZone: "", locationText: "", context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedStorageLocations(for item: WorkbenchItem) -> [StorageLocationRecord] {
    suggestedStorageLocations(inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, receivingInspectionID: suggestedReceivingInspections(for: item).first?.id, packageContentID: suggestedPackageContents(for: item).first?.id, orderID: nil, shipmentGroupID: nil, ownerTeam: item.assignee, areaZone: "", locationText: item.summary, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredCustodyRecords(custodyStatus: CustodyStatus?, custodianTeam: String, ownerTeam: String, handoffMethod: CustodyHandoffMethod?, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [CustodyRecord] {
    custodyRecords.filter { record in
      let matchesStatus = custodyStatus == nil || record.custodyStatus == custodyStatus
      let matchesCustodian = custodianTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.currentCustodianTeam.localizedCaseInsensitiveContains(custodianTeam) || record.previousCustodianTeam.localizedCaseInsensitiveContains(custodianTeam)
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesMethod = handoffMethod == nil || record.handoffMethod == handoffMethod
      let matchesRisk = riskLevel == nil || record.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || record.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || record.reviewState == reviewState
      return matchesStatus && matchesCustodian && matchesOwner && matchesMethod && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addCustodyRecordPlaceholder() {
    let receipt = inventoryReceipts.first
    let location = storageLocations.first
    let record = CustodyRecord(title: "New custody record \(custodyRecords.count + 1)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt?.id.uuidString ?? "Unlinked", currentCustodianTeam: receipt?.assignedOwnerTeam ?? "Receiving Desk", previousCustodianTeam: "Unassigned", custodyStatus: .pendingTransfer, custodyReason: "Local custody placeholder for review.", handoffMethod: .manualUpdate, sourceLocationID: nil, destinationLocationID: location?.id, inventoryReceiptID: receipt?.id, storageLocationID: location?.id, receivingInspectionID: receipt?.receivingInspectionID, orderID: receipt?.orderID, shipmentGroupID: receipt?.shipmentGroupID, packageContentID: receipt?.packageContentID, evidenceAttachmentIDs: receipt?.evidenceAttachmentIDs ?? [], assignedOwnerTeam: receipt?.assignedOwnerTeam ?? "Receiving Desk", transferDate: "To schedule", expectedReturnCloseDate: "To schedule", notes: "Local placeholder only. No signature capture or access control actions are performed.", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    custodyRecords.insert(record, at: 0)
    persistCustodyRecords()
    logAudit(action: .created, entityType: .custodyRecord, entityID: record.id.uuidString, entityLabel: record.title, summary: "Custody record placeholder added.", afterDetail: record.auditDetail)
  }

  func updateCustodyRecord(_ record: CustodyRecord) {
    guard let index = custodyRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = custodyRecords[index].auditDetail
    custodyRecords[index] = record
    persistCustodyRecords()
    logAudit(action: .edited, entityType: .custodyRecord, entityID: record.id.uuidString, entityLabel: record.title, summary: "Custody record details updated.", beforeDetail: beforeDetail, afterDetail: record.auditDetail)
  }

  func markCustodyRecordTransferred(_ record: CustodyRecord) {
    updateCustodyRecordStatus(record, status: .transferred, reviewState: .monitor, summary: "Custody marked transferred locally.", action: .created)
  }

  func markCustodyRecordReceived(_ record: CustodyRecord) {
    updateCustodyRecordStatus(record, status: .received, reviewState: .accepted, summary: "Custody marked received locally.", action: .completed)
  }

  func markCustodyRecordReturnedClosed(_ record: CustodyRecord) {
    updateCustodyRecordStatus(record, status: .returnedClosed, reviewState: .accepted, summary: "Custody returned or closed locally.", action: .completed)
  }

  func markCustodyRecordDisputed(_ record: CustodyRecord) {
    updateCustodyRecordStatus(record, status: .disputed, reviewState: .needsReview, summary: "Custody disputed and needs review.", action: .edited, forceHighRisk: true)
  }

  func markCustodyRecordReviewed(_ record: CustodyRecord) {
    guard let index = custodyRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = custodyRecords[index].auditDetail
    custodyRecords[index].reviewState = .accepted
    custodyRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistCustodyRecords()
    logAudit(action: .reviewed, entityType: .custodyRecord, entityID: custodyRecords[index].id.uuidString, entityLabel: custodyRecords[index].title, summary: "Custody record marked reviewed.", beforeDetail: beforeDetail, afterDetail: custodyRecords[index].auditDetail)
  }

  func removeCustodyRecord(_ record: CustodyRecord) {
    guard let index = custodyRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let removed = custodyRecords.remove(at: index)
    persistCustodyRecords()
    logAudit(action: .removed, entityType: .custodyRecord, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Custody record removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from record: CustodyRecord) {
    createReviewTask(linkedEntityType: .custodyRecord, linkedEntityID: record.id.uuidString, label: record.title, summary: "Review custody: \(record.custodyReason). Current custodian \(record.currentCustodianTeam).", priority: record.riskLevel == .critical ? .urgent : record.riskLevel == .high ? .high : .normal, assignee: record.assignedOwnerTeam)
  }

  func createDraftMessage(from record: CustodyRecord) {
    createDraftMessage(linkedEntityType: .custodyRecord, linkedEntityID: record.id.uuidString, label: record.title, recipient: record.currentCustodianTeam)
    logAudit(action: .created, entityType: .custodyRecord, entityID: record.id.uuidString, entityLabel: record.title, summary: "Draft message created from custody record.", afterDetail: record.auditDetail)
  }

  private func updateCustodyRecordStatus(_ record: CustodyRecord, status: CustodyStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = custodyRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = custodyRecords[index].auditDetail
    custodyRecords[index].custodyStatus = status
    custodyRecords[index].reviewState = reviewState
    custodyRecords[index].lastReviewedDate = Self.auditTimestamp()
    if forceHighRisk {
      custodyRecords[index].riskLevel = custodyRecords[index].riskLevel == .critical ? .critical : .high
    }
    persistCustodyRecords()
    logAudit(action: action, entityType: .custodyRecord, entityID: custodyRecords[index].id.uuidString, entityLabel: custodyRecords[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: custodyRecords[index].auditDetail)
  }

  private func suggestedCustodyRecords(sourceLocationID: UUID?, destinationLocationID: UUID?, inventoryReceiptID: UUID?, storageLocationID: UUID?, receivingInspectionID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, custodianTeam: String, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [CustodyRecord] {
    custodyRecords.filter { $0.matches(sourceLocationID: sourceLocationID, destinationLocationID: destinationLocationID, inventoryReceiptID: inventoryReceiptID, storageLocationID: storageLocationID, receivingInspectionID: receivingInspectionID, orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, evidenceID: evidenceID, custodianTeam: custodianTeam, ownerTeam: ownerTeam, locationText: locationText, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedCustodyRecords(for location: StorageLocationRecord) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: location.id, destinationLocationID: location.id, inventoryReceiptID: location.inventoryReceiptIDs.first, storageLocationID: location.id, receivingInspectionID: location.receivingInspectionIDs.first, orderID: location.orderIDs.first, shipmentGroupID: location.shipmentGroupIDs.first, packageContentID: location.packageContentIDs.first, evidenceID: nil, custodianTeam: location.assignedOwnerTeam, ownerTeam: location.assignedOwnerTeam, locationText: "\(location.locationCode) \(location.areaZone)", context: "\(location.title) \(location.currentUsageSummary)", linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString)
  }

  func suggestedCustodyRecords(for receipt: InventoryReceiptRecord) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: receipt).first?.id, inventoryReceiptID: receipt.id, storageLocationID: suggestedStorageLocations(for: receipt).first?.id, receivingInspectionID: receipt.receivingInspectionID, orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, packageContentID: receipt.packageContentID, evidenceID: receipt.evidenceAttachmentIDs.first, custodianTeam: receipt.assignedOwnerTeam, ownerTeam: receipt.assignedOwnerTeam, locationText: receipt.storageLocationSummary, context: "\(receipt.title) \(receipt.itemSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedCustodyRecords(for inspection: ReceivingInspectionRecord) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: inspection).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, storageLocationID: suggestedStorageLocations(for: inspection).first?.id, receivingInspectionID: inspection.id, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, packageContentID: inspection.packageContentID, evidenceID: inspection.evidenceAttachmentIDs.first, custodianTeam: inspection.assignedInspectorTeam, ownerTeam: inspection.assignedInspectorTeam, locationText: "", context: "\(inspection.title) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedCustodyRecords(for order: TrackedOrder) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: order).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, storageLocationID: suggestedStorageLocations(for: order).first?.id, receivingInspectionID: suggestedReceivingInspections(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, evidenceID: nil, custodianTeam: order.customer, ownerTeam: order.customer, locationText: order.destination, context: "\(order.store) \(order.orderNumber) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedCustodyRecords(for content: PackageContentRecord) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: content).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, storageLocationID: suggestedStorageLocations(for: content).first?.id, receivingInspectionID: suggestedReceivingInspections(for: content).first?.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, evidenceID: content.evidenceAttachmentIDs.first, custodianTeam: "", ownerTeam: "", locationText: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedCustodyRecords(for request: ProcurementRequest) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: request).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, storageLocationID: suggestedStorageLocations(for: request).first?.id, receivingInspectionID: suggestedReceivingInspections(for: request).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: request.packageContentID, evidenceID: request.evidenceAttachmentIDs.first, custodianTeam: request.assignedBuyerTeam, ownerTeam: request.assignedBuyerTeam, locationText: request.requestedItemsSummary, context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedCustodyRecords(for claim: ReturnClaimRecord) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: claim).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, storageLocationID: suggestedStorageLocations(for: claim).first?.id, receivingInspectionID: suggestedReceivingInspections(for: claim).first?.id, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, packageContentID: claim.packageContentID, evidenceID: claim.evidenceAttachmentIDs.first, custodianTeam: claim.assignedOwnerTeam, ownerTeam: claim.assignedOwnerTeam, locationText: claim.reasonSummary, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedCustodyRecords(for item: WorkbenchItem) -> [CustodyRecord] {
    suggestedCustodyRecords(sourceLocationID: nil, destinationLocationID: suggestedStorageLocations(for: item).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, storageLocationID: suggestedStorageLocations(for: item).first?.id, receivingInspectionID: suggestedReceivingInspections(for: item).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, evidenceID: nil, custodianTeam: item.assignee, ownerTeam: item.assignee, locationText: item.summary, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredScanSessionRecords(scanPurpose: ScanPurpose?, scanMethod: ScanMethodPlaceholder?, scanStatus: ScanSessionStatus?, operatorTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [ScanSessionRecord] {
    scanSessionRecords.filter { record in
      let matchesPurpose = scanPurpose == nil || record.scanPurpose == scanPurpose
      let matchesMethod = scanMethod == nil || record.scanMethodPlaceholder == scanMethod
      let matchesStatus = scanStatus == nil || record.scanStatus == scanStatus
      let matchesOperator = operatorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.assignedOperatorTeam.localizedCaseInsensitiveContains(operatorTeam)
      let matchesRisk = riskLevel == nil || record.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || record.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || record.reviewState == reviewState
      return matchesPurpose && matchesMethod && matchesStatus && matchesOperator && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addScanSessionPlaceholder() {
    let label = labelReferenceRecords.first
    let record = ScanSessionRecord(title: "New scan session \(scanSessionRecords.count + 1)", linkedEntityType: .labelReference, linkedEntityID: label?.id.uuidString ?? "Unlinked", scanPurpose: .labelVerification, scanMethodPlaceholder: .manualEntry, expectedLabelReferenceValue: label?.labelValuePlaceholder ?? "To assign", capturedValuePlaceholder: "", linkedLabelReferenceID: label?.id, scanStatus: .planned, mismatchSummary: "No mismatch checked yet.", assignedOperatorTeam: label?.assignedOwnerTeam ?? "ParcelOps Operations", scanLocationStorageLocationID: label?.storageLocationID ?? storageLocations.first?.id, custodyRecordID: label?.custodyRecordID ?? custodyRecords.first?.id, inventoryReceiptID: label?.inventoryReceiptID ?? inventoryReceipts.first?.id, orderID: label?.orderID ?? orders.first?.id, shipmentGroupID: label?.shipmentGroupID ?? shipmentGroups.first?.id, packageContentID: label?.packageContentID ?? packageContents.first?.id, evidenceAttachmentIDs: label?.evidenceAttachmentIDs ?? [], createdDate: Self.auditTimestamp(), completedDate: "Not completed", notes: "Local placeholder only. No scanner hardware, camera access, or barcode scanning is performed.", riskLevel: .medium, reviewState: .needsReview)
    scanSessionRecords.insert(record, at: 0)
    persistScanSessionRecords()
    logAudit(action: .created, entityType: .scanSession, entityID: record.id.uuidString, entityLabel: record.title, summary: "Scan session placeholder added.", afterDetail: record.auditDetail)
  }

  func updateScanSessionRecord(_ record: ScanSessionRecord) {
    guard let index = scanSessionRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = scanSessionRecords[index].auditDetail
    scanSessionRecords[index] = record
    persistScanSessionRecords()
    logAudit(action: .edited, entityType: .scanSession, entityID: record.id.uuidString, entityLabel: record.title, summary: "Scan session details updated.", beforeDetail: beforeDetail, afterDetail: record.auditDetail)
  }

  func markScanSessionMatched(_ record: ScanSessionRecord) {
    updateScanSessionStatus(record, status: .matched, reviewState: .monitor, summary: "Scan session marked matched locally.", action: .edited)
  }

  func markScanSessionMismatch(_ record: ScanSessionRecord) {
    updateScanSessionStatus(record, status: .mismatchNeedsReview, reviewState: .needsReview, summary: "Scan session marked mismatch and needs review.", action: .edited, forceHighRisk: true)
  }

  func markScanSessionCompleted(_ record: ScanSessionRecord) {
    updateScanSessionStatus(record, status: .completed, reviewState: .accepted, summary: "Scan session completed locally.", action: .completed, completedDate: Self.auditTimestamp())
  }

  func reopenScanSession(_ record: ScanSessionRecord) {
    updateScanSessionStatus(record, status: .reopened, reviewState: .needsReview, summary: "Scan session reopened.", action: .reopened)
  }

  func markScanSessionReviewed(_ record: ScanSessionRecord) {
    guard let index = scanSessionRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = scanSessionRecords[index].auditDetail
    scanSessionRecords[index].reviewState = .accepted
    persistScanSessionRecords()
    logAudit(action: .reviewed, entityType: .scanSession, entityID: scanSessionRecords[index].id.uuidString, entityLabel: scanSessionRecords[index].title, summary: "Scan session marked reviewed.", beforeDetail: beforeDetail, afterDetail: scanSessionRecords[index].auditDetail)
  }

  func removeScanSessionRecord(_ record: ScanSessionRecord) {
    guard let index = scanSessionRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let removed = scanSessionRecords.remove(at: index)
    persistScanSessionRecords()
    logAudit(action: .removed, entityType: .scanSession, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Scan session removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from record: ScanSessionRecord) {
    createReviewTask(linkedEntityType: .scanSession, linkedEntityID: record.id.uuidString, label: record.title, summary: "Review scan session: expected \(record.expectedLabelReferenceValue), captured \(record.capturedValuePlaceholder.isEmpty ? "missing" : record.capturedValuePlaceholder).", priority: record.riskLevel == .critical ? .urgent : record.riskLevel == .high ? .high : .normal, assignee: record.assignedOperatorTeam)
  }

  func createDraftMessage(from record: ScanSessionRecord) {
    createDraftMessage(linkedEntityType: .scanSession, linkedEntityID: record.id.uuidString, label: record.title, recipient: record.assignedOperatorTeam)
    logAudit(action: .created, entityType: .scanSession, entityID: record.id.uuidString, entityLabel: record.title, summary: "Draft message created from scan session.", afterDetail: record.auditDetail)
  }

  private func updateScanSessionStatus(_ record: ScanSessionRecord, status: ScanSessionStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false, completedDate: String? = nil) {
    guard let index = scanSessionRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = scanSessionRecords[index].auditDetail
    scanSessionRecords[index].scanStatus = status
    scanSessionRecords[index].reviewState = reviewState
    if let completedDate { scanSessionRecords[index].completedDate = completedDate }
    if forceHighRisk {
      scanSessionRecords[index].riskLevel = scanSessionRecords[index].riskLevel == .critical ? .critical : .high
    }
    persistScanSessionRecords()
    logAudit(action: action, entityType: .scanSession, entityID: scanSessionRecords[index].id.uuidString, entityLabel: scanSessionRecords[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: scanSessionRecords[index].auditDetail)
  }

  private func suggestedScanSessionRecords(labelReferenceID: UUID?, storageLocationID: UUID?, custodyRecordID: UUID?, inventoryReceiptID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, labelValue: String, operatorTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [ScanSessionRecord] {
    scanSessionRecords.filter { $0.matches(labelReferenceID: labelReferenceID, storageLocationID: storageLocationID, custodyRecordID: custodyRecordID, inventoryReceiptID: inventoryReceiptID, orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, evidenceID: evidenceID, labelValue: labelValue, operatorTeam: operatorTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedScanSessionRecords(for label: LabelReferenceRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: label.id, storageLocationID: label.storageLocationID, custodyRecordID: label.custodyRecordID, inventoryReceiptID: label.inventoryReceiptID, orderID: label.orderID, shipmentGroupID: label.shipmentGroupID, packageContentID: label.packageContentID, evidenceID: label.evidenceAttachmentIDs.first, labelValue: label.labelValuePlaceholder, operatorTeam: label.assignedOwnerTeam, context: "\(label.title) \(label.notes)", linkedEntityType: .labelReference, linkedEntityID: label.id.uuidString)
  }

  func suggestedScanSessionRecords(for location: StorageLocationRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: location).first?.id, storageLocationID: location.id, custodyRecordID: suggestedCustodyRecords(for: location).first?.id, inventoryReceiptID: location.inventoryReceiptIDs.first, orderID: location.orderIDs.first, shipmentGroupID: location.shipmentGroupIDs.first, packageContentID: location.packageContentIDs.first, evidenceID: nil, labelValue: location.locationCode, operatorTeam: location.assignedOwnerTeam, context: "\(location.title) \(location.currentUsageSummary)", linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString)
  }

  func suggestedScanSessionRecords(for custody: CustodyRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: custody).first?.id, storageLocationID: custody.storageLocationID ?? custody.destinationLocationID ?? custody.sourceLocationID, custodyRecordID: custody.id, inventoryReceiptID: custody.inventoryReceiptID, orderID: custody.orderID, shipmentGroupID: custody.shipmentGroupID, packageContentID: custody.packageContentID, evidenceID: custody.evidenceAttachmentIDs.first, labelValue: "", operatorTeam: custody.assignedOwnerTeam, context: "\(custody.title) \(custody.custodyReason)", linkedEntityType: .custodyRecord, linkedEntityID: custody.id.uuidString)
  }

  func suggestedScanSessionRecords(for receipt: InventoryReceiptRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: receipt).first?.id, storageLocationID: suggestedStorageLocations(for: receipt).first?.id, custodyRecordID: suggestedCustodyRecords(for: receipt).first?.id, inventoryReceiptID: receipt.id, orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, packageContentID: receipt.packageContentID, evidenceID: receipt.evidenceAttachmentIDs.first, labelValue: receipt.storageLocationSummary, operatorTeam: receipt.assignedOwnerTeam, context: "\(receipt.title) \(receipt.itemSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedScanSessionRecords(for inspection: ReceivingInspectionRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: inspection).first?.id, storageLocationID: suggestedStorageLocations(for: inspection).first?.id, custodyRecordID: suggestedCustodyRecords(for: inspection).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, packageContentID: inspection.packageContentID, evidenceID: inspection.evidenceAttachmentIDs.first, labelValue: "", operatorTeam: inspection.assignedInspectorTeam, context: "\(inspection.title) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedScanSessionRecords(for order: TrackedOrder) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: order).first?.id, storageLocationID: suggestedStorageLocations(for: order).first?.id, custodyRecordID: suggestedCustodyRecords(for: order).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, evidenceID: nil, labelValue: "\(order.trackingNumber) \(order.orderNumber)", operatorTeam: order.customer, context: "\(order.store) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedScanSessionRecords(for content: PackageContentRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: content).first?.id, storageLocationID: suggestedStorageLocations(for: content).first?.id, custodyRecordID: suggestedCustodyRecords(for: content).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, evidenceID: content.evidenceAttachmentIDs.first, labelValue: content.itemSummary, operatorTeam: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedScanSessionRecords(for request: ProcurementRequest) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: request).first?.id, storageLocationID: suggestedStorageLocations(for: request).first?.id, custodyRecordID: suggestedCustodyRecords(for: request).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: request.packageContentID, evidenceID: request.evidenceAttachmentIDs.first, labelValue: request.requestedItemsSummary, operatorTeam: request.assignedBuyerTeam, context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedScanSessionRecords(for claim: ReturnClaimRecord) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: claim).first?.id, storageLocationID: suggestedStorageLocations(for: claim).first?.id, custodyRecordID: suggestedCustodyRecords(for: claim).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, packageContentID: claim.packageContentID, evidenceID: claim.evidenceAttachmentIDs.first, labelValue: claim.reasonSummary, operatorTeam: claim.assignedOwnerTeam, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedScanSessionRecords(for item: WorkbenchItem) -> [ScanSessionRecord] {
    suggestedScanSessionRecords(labelReferenceID: suggestedLabelReferenceRecords(for: item).first?.id, storageLocationID: suggestedStorageLocations(for: item).first?.id, custodyRecordID: suggestedCustodyRecords(for: item).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, evidenceID: nil, labelValue: item.summary, operatorTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredShipmentManifestRecords(manifestType: ShipmentManifestType?, carrierCourier: String, dispatchStatus: ShipmentManifestDispatchStatus?, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { record in
      let matchesType = manifestType == nil || record.manifestType == manifestType
      let matchesCarrier = carrierCourier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.carrierCourier.localizedCaseInsensitiveContains(carrierCourier)
      let matchesStatus = dispatchStatus == nil || record.dispatchStatus == dispatchStatus
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || record.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || record.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || record.reviewState == reviewState
      return matchesType && matchesCarrier && matchesStatus && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addShipmentManifestPlaceholder() {
    let order = orders.first
    let group = shipmentGroups.first
    let receipt = inventoryReceipts.first
    let content = packageContents.first
    let custody = custodyRecords.first
    let label = labelReferenceRecords.first
    let scan = scanSessionRecords.first
    let location = storageLocations.first
    let record = ShipmentManifestRecord(title: "New shipment manifest \(shipmentManifestRecords.count + 1)", manifestType: .dispatchBatch, linkedEntityType: .order, linkedEntityID: order?.id.uuidString ?? "Unlinked", carrierCourier: order?.carrier ?? "Unassigned courier", destinationSummary: order?.destination ?? location?.areaZone ?? "Destination to assign", includedOrderIDs: order.map { [$0.id] } ?? [], shipmentGroupIDs: group.map { [$0.id] } ?? [], inventoryReceiptIDs: receipt.map { [$0.id] } ?? [], packageContentIDs: content.map { [$0.id] } ?? [], custodyRecordIDs: custody.map { [$0.id] } ?? [], labelReferenceIDs: label.map { [$0.id] } ?? [], scanSessionIDs: scan.map { [$0.id] } ?? [], evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id), assignedOwnerTeam: "ParcelOps Operations", dispatchStatus: .draft, plannedDispatchDate: "To schedule", actualDispatchDate: "Not dispatched", handoffLocationStorageLocationID: location?.id, manifestReferencePlaceholder: "MNF-\(shipmentManifestRecords.count + 1)", notes: "Local placeholder only. No carrier booking, label printing, or external dispatch integration is performed.", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    shipmentManifestRecords.insert(record, at: 0)
    persistShipmentManifestRecords()
    logAudit(action: .created, entityType: .shipmentManifest, entityID: record.id.uuidString, entityLabel: record.title, summary: "Shipment manifest placeholder added.", afterDetail: record.auditDetail)
  }

  func updateShipmentManifestRecord(_ record: ShipmentManifestRecord) {
    guard let index = shipmentManifestRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = shipmentManifestRecords[index].auditDetail
    shipmentManifestRecords[index] = record
    persistShipmentManifestRecords()
    logAudit(action: .edited, entityType: .shipmentManifest, entityID: record.id.uuidString, entityLabel: record.title, summary: "Shipment manifest details updated.", beforeDetail: beforeDetail, afterDetail: record.auditDetail)
  }

  func markShipmentManifestPrepared(_ record: ShipmentManifestRecord) {
    updateShipmentManifestStatus(record, status: .prepared, reviewState: .monitor, summary: "Shipment manifest marked prepared locally.", action: .edited)
  }

  func markShipmentManifestDispatched(_ record: ShipmentManifestRecord) {
    updateShipmentManifestStatus(record, status: .dispatched, reviewState: .monitor, summary: "Shipment manifest marked dispatched locally.", action: .edited, actualDispatchDate: Self.auditTimestamp())
  }

  func markShipmentManifestHandedOff(_ record: ShipmentManifestRecord) {
    updateShipmentManifestStatus(record, status: .handedOff, reviewState: .accepted, summary: "Shipment manifest marked handed off locally.", action: .completed, actualDispatchDate: Self.auditTimestamp())
  }

  func markShipmentManifestBlocked(_ record: ShipmentManifestRecord) {
    updateShipmentManifestStatus(record, status: .blockedNeedsReview, reviewState: .needsReview, summary: "Shipment manifest blocked and needs review.", action: .edited, forceHighRisk: true)
  }

  func reopenShipmentManifest(_ record: ShipmentManifestRecord) {
    updateShipmentManifestStatus(record, status: .reopened, reviewState: .needsReview, summary: "Shipment manifest reopened.", action: .reopened)
  }

  func markShipmentManifestReviewed(_ record: ShipmentManifestRecord) {
    guard let index = shipmentManifestRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = shipmentManifestRecords[index].auditDetail
    shipmentManifestRecords[index].reviewState = .accepted
    shipmentManifestRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistShipmentManifestRecords()
    logAudit(action: .reviewed, entityType: .shipmentManifest, entityID: shipmentManifestRecords[index].id.uuidString, entityLabel: shipmentManifestRecords[index].title, summary: "Shipment manifest marked reviewed.", beforeDetail: beforeDetail, afterDetail: shipmentManifestRecords[index].auditDetail)
  }

  func removeShipmentManifestRecord(_ record: ShipmentManifestRecord) {
    guard let index = shipmentManifestRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let removed = shipmentManifestRecords.remove(at: index)
    persistShipmentManifestRecords()
    logAudit(action: .removed, entityType: .shipmentManifest, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Shipment manifest removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from record: ShipmentManifestRecord) {
    createReviewTask(linkedEntityType: .shipmentManifest, linkedEntityID: record.id.uuidString, label: record.title, summary: "Review manifest: \(record.manifestType.rawValue) for \(record.carrierCourier), status \(record.dispatchStatus.rawValue).", priority: record.riskLevel == .critical ? .urgent : record.riskLevel == .high ? .high : .normal, assignee: record.assignedOwnerTeam)
  }

  func createDraftMessage(from record: ShipmentManifestRecord) {
    createDraftMessage(linkedEntityType: .shipmentManifest, linkedEntityID: record.id.uuidString, label: record.title, recipient: record.assignedOwnerTeam)
    logAudit(action: .created, entityType: .shipmentManifest, entityID: record.id.uuidString, entityLabel: record.title, summary: "Draft message created from shipment manifest.", afterDetail: record.auditDetail)
  }

  private func updateShipmentManifestStatus(_ record: ShipmentManifestRecord, status: ShipmentManifestDispatchStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false, actualDispatchDate: String? = nil) {
    guard let index = shipmentManifestRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = shipmentManifestRecords[index].auditDetail
    shipmentManifestRecords[index].dispatchStatus = status
    shipmentManifestRecords[index].reviewState = reviewState
    shipmentManifestRecords[index].lastReviewedDate = Self.auditTimestamp()
    if let actualDispatchDate { shipmentManifestRecords[index].actualDispatchDate = actualDispatchDate }
    if forceHighRisk {
      shipmentManifestRecords[index].riskLevel = shipmentManifestRecords[index].riskLevel == .critical ? .critical : .high
    }
    persistShipmentManifestRecords()
    updateLinkedInboxOrdersForManifestStatus(shipmentManifestRecords[index], action: action, summary: summary)
    logAudit(action: action, entityType: .shipmentManifest, entityID: shipmentManifestRecords[index].id.uuidString, entityLabel: shipmentManifestRecords[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: shipmentManifestRecords[index].auditDetail)
  }

  private func updateLinkedInboxOrdersForManifestStatus(_ manifest: ShipmentManifestRecord, action: AuditAction, summary: String) {
    guard manifest.isInboxHandoffSetup else { return }

    var changedOrderIDs: [UUID] = []
    for orderID in manifest.includedOrderIDs {
      guard let index = orders.firstIndex(where: { $0.id == orderID }) else { continue }
      let beforeDetail = orders[index].auditDetail
      let statusSummary: String
      let reviewState: ReviewState
      let orderStatus: OrderStatus?

      switch manifest.dispatchStatus {
      case .draft:
        statusSummary = "Inbox dispatch setup is in draft manifest stage"
        reviewState = orders[index].reviewState
        orderStatus = nil
      case .prepared:
        statusSummary = "Inbox dispatch manifest prepared locally"
        reviewState = .monitor
        orderStatus = .shipped
      case .dispatched:
        statusSummary = "Inbox dispatch manifest marked dispatched locally"
        reviewState = .monitor
        orderStatus = .inTransit
      case .handedOff:
        statusSummary = "Inbox dispatch manifest handed off locally"
        reviewState = .accepted
        orderStatus = .inTransit
      case .blockedNeedsReview:
        statusSummary = "Inbox dispatch manifest blocked and needs review"
        reviewState = .needsReview
        orderStatus = .exception
      case .reopened:
        statusSummary = "Inbox dispatch manifest reopened for review"
        reviewState = .needsReview
        orderStatus = .exception
      }

      if let orderStatus, orders[index].status != .delivered {
        orders[index].status = orderStatus
      }
      orders[index].latestStatus = statusSummary
      orders[index].reviewState = reviewState
      orders[index].contactHistory.insert(
        ContactHistoryEvent(
          time: "Now",
          source: .manual,
          contactPoint: "Dispatch manifest",
          summary: statusSummary,
          evidence: "\(manifest.title): \(summary). Order status is \(orders[index].status.rawValue).",
          reviewState: reviewState
        ),
        at: 0
      )
      changedOrderIDs.append(orderID)
      logAudit(
        action: action,
        entityType: .order,
        entityID: orders[index].id.uuidString,
        entityLabel: orders[index].orderNumber,
        summary: "Inbox-created order updated from dispatch manifest.",
        beforeDetail: beforeDetail,
        afterDetail: "\(orders[index].auditDetail)\nManifest: \(manifest.title)\nNo external carrier, label, scanner, or mailbox action occurred."
      )
    }

    if !changedOrderIDs.isEmpty {
      persistOrders()
    }
  }

  private func suggestedShipmentManifestRecords(orderID: UUID?, shipmentGroupID: UUID?, inventoryReceiptID: UUID?, packageContentID: UUID?, custodyRecordID: UUID?, labelReferenceID: UUID?, scanSessionID: UUID?, evidenceID: UUID?, storageLocationID: UUID?, carrierCourier: String, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [ShipmentManifestRecord] {
    shipmentManifestRecords.filter { $0.matches(orderID: orderID, shipmentGroupID: shipmentGroupID, inventoryReceiptID: inventoryReceiptID, packageContentID: packageContentID, custodyRecordID: custodyRecordID, labelReferenceID: labelReferenceID, scanSessionID: scanSessionID, evidenceID: evidenceID, storageLocationID: storageLocationID, carrierCourier: carrierCourier, ownerTeam: ownerTeam, locationText: locationText, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedShipmentManifestRecords(for scan: ScanSessionRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: scan.orderID, shipmentGroupID: scan.shipmentGroupID, inventoryReceiptID: scan.inventoryReceiptID, packageContentID: scan.packageContentID, custodyRecordID: scan.custodyRecordID, labelReferenceID: scan.linkedLabelReferenceID, scanSessionID: scan.id, evidenceID: scan.evidenceAttachmentIDs.first, storageLocationID: scan.scanLocationStorageLocationID, carrierCourier: "", ownerTeam: scan.assignedOperatorTeam, locationText: scan.expectedLabelReferenceValue, context: "\(scan.title) \(scan.notes)", linkedEntityType: .scanSession, linkedEntityID: scan.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for label: LabelReferenceRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: label.orderID, shipmentGroupID: label.shipmentGroupID, inventoryReceiptID: label.inventoryReceiptID, packageContentID: label.packageContentID, custodyRecordID: label.custodyRecordID, labelReferenceID: label.id, scanSessionID: suggestedScanSessionRecords(for: label).first?.id, evidenceID: label.evidenceAttachmentIDs.first, storageLocationID: label.storageLocationID, carrierCourier: label.associatedCarrier, ownerTeam: label.assignedOwnerTeam, locationText: label.labelValuePlaceholder, context: "\(label.title) \(label.notes)", linkedEntityType: .labelReference, linkedEntityID: label.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for location: StorageLocationRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: location.orderIDs.first, shipmentGroupID: location.shipmentGroupIDs.first, inventoryReceiptID: location.inventoryReceiptIDs.first, packageContentID: location.packageContentIDs.first, custodyRecordID: suggestedCustodyRecords(for: location).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: location).first?.id, scanSessionID: suggestedScanSessionRecords(for: location).first?.id, evidenceID: nil, storageLocationID: location.id, carrierCourier: "", ownerTeam: location.assignedOwnerTeam, locationText: "\(location.locationCode) \(location.areaZone)", context: "\(location.title) \(location.currentUsageSummary)", linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for custody: CustodyRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: custody.orderID, shipmentGroupID: custody.shipmentGroupID, inventoryReceiptID: custody.inventoryReceiptID, packageContentID: custody.packageContentID, custodyRecordID: custody.id, labelReferenceID: suggestedLabelReferenceRecords(for: custody).first?.id, scanSessionID: suggestedScanSessionRecords(for: custody).first?.id, evidenceID: custody.evidenceAttachmentIDs.first, storageLocationID: custody.storageLocationID ?? custody.destinationLocationID ?? custody.sourceLocationID, carrierCourier: "", ownerTeam: custody.assignedOwnerTeam, locationText: custody.handoffMethod.rawValue, context: "\(custody.title) \(custody.custodyReason)", linkedEntityType: .custodyRecord, linkedEntityID: custody.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for receipt: InventoryReceiptRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, inventoryReceiptID: receipt.id, packageContentID: receipt.packageContentID, custodyRecordID: suggestedCustodyRecords(for: receipt).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: receipt).first?.id, scanSessionID: suggestedScanSessionRecords(for: receipt).first?.id, evidenceID: receipt.evidenceAttachmentIDs.first, storageLocationID: suggestedStorageLocations(for: receipt).first?.id, carrierCourier: "", ownerTeam: receipt.assignedOwnerTeam, locationText: receipt.storageLocationSummary, context: "\(receipt.title) \(receipt.itemSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for inspection: ReceivingInspectionRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, packageContentID: inspection.packageContentID, custodyRecordID: suggestedCustodyRecords(for: inspection).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: inspection).first?.id, scanSessionID: suggestedScanSessionRecords(for: inspection).first?.id, evidenceID: inspection.evidenceAttachmentIDs.first, storageLocationID: suggestedStorageLocations(for: inspection).first?.id, carrierCourier: "", ownerTeam: inspection.assignedInspectorTeam, locationText: inspection.discrepancySummary, context: "\(inspection.title) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for order: TrackedOrder) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: order.id, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, packageContentID: suggestedPackageContents(for: order).first?.id, custodyRecordID: suggestedCustodyRecords(for: order).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: order).first?.id, scanSessionID: suggestedScanSessionRecords(for: order).first?.id, evidenceID: nil, storageLocationID: suggestedStorageLocations(for: order).first?.id, carrierCourier: order.carrier, ownerTeam: order.customer, locationText: order.destination, context: "\(order.store) \(order.orderNumber) \(order.trackingNumber)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for content: PackageContentRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, packageContentID: content.id, custodyRecordID: suggestedCustodyRecords(for: content).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: content).first?.id, scanSessionID: suggestedScanSessionRecords(for: content).first?.id, evidenceID: content.evidenceAttachmentIDs.first, storageLocationID: suggestedStorageLocations(for: content).first?.id, carrierCourier: "", ownerTeam: "", locationText: content.itemSummary, context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for request: ProcurementRequest) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: nil, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, packageContentID: request.packageContentID, custodyRecordID: suggestedCustodyRecords(for: request).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: request).first?.id, scanSessionID: suggestedScanSessionRecords(for: request).first?.id, evidenceID: request.evidenceAttachmentIDs.first, storageLocationID: suggestedStorageLocations(for: request).first?.id, carrierCourier: "", ownerTeam: request.assignedBuyerTeam, locationText: request.requestedItemsSummary, context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for claim: ReturnClaimRecord) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, packageContentID: claim.packageContentID, custodyRecordID: suggestedCustodyRecords(for: claim).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: claim).first?.id, scanSessionID: suggestedScanSessionRecords(for: claim).first?.id, evidenceID: claim.evidenceAttachmentIDs.first, storageLocationID: suggestedStorageLocations(for: claim).first?.id, carrierCourier: "", ownerTeam: claim.assignedOwnerTeam, locationText: claim.reasonSummary, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedShipmentManifestRecords(for item: WorkbenchItem) -> [ShipmentManifestRecord] {
    suggestedShipmentManifestRecords(orderID: nil, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, packageContentID: suggestedPackageContents(for: item).first?.id, custodyRecordID: suggestedCustodyRecords(for: item).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: item).first?.id, scanSessionID: suggestedScanSessionRecords(for: item).first?.id, evidenceID: nil, storageLocationID: suggestedStorageLocations(for: item).first?.id, carrierCourier: "", ownerTeam: item.assignee, locationText: item.summary, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredDispatchReadinessChecklists(checklistType: DispatchChecklistType?, checklistStatus: DispatchChecklistStatus?, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { checklist in
      let matchesType = checklistType == nil || checklist.checklistType == checklistType
      let matchesStatus = checklistStatus == nil || checklist.checklistStatus == checklistStatus
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || checklist.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || checklist.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || checklist.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || checklist.reviewState == reviewState
      return matchesType && matchesStatus && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addDispatchReadinessChecklistPlaceholder() {
    let manifest = shipmentManifestRecords.first
    let checklist = DispatchReadinessChecklist(title: "New dispatch checklist \(dispatchReadinessChecklists.count + 1)", linkedEntityType: .shipmentManifest, linkedEntityID: manifest?.id.uuidString ?? "Unlinked", shipmentManifestID: manifest?.id, orderIDs: manifest?.includedOrderIDs ?? orders.prefix(1).map(\.id), shipmentGroupIDs: manifest?.shipmentGroupIDs ?? shipmentGroups.prefix(1).map(\.id), inventoryReceiptIDs: manifest?.inventoryReceiptIDs ?? inventoryReceipts.prefix(1).map(\.id), packageContentIDs: manifest?.packageContentIDs ?? packageContents.prefix(1).map(\.id), custodyRecordIDs: manifest?.custodyRecordIDs ?? custodyRecords.prefix(1).map(\.id), labelReferenceIDs: manifest?.labelReferenceIDs ?? labelReferenceRecords.prefix(1).map(\.id), scanSessionIDs: manifest?.scanSessionIDs ?? scanSessionRecords.prefix(1).map(\.id), evidenceAttachmentIDs: manifest?.evidenceAttachmentIDs ?? evidenceAttachments.prefix(1).map(\.id), checklistType: .manifestReadiness, checklistStatus: .draft, requiredChecksSummary: "Confirm manifest, labels, scans, custody, destination, and evidence before dispatch.", completedChecksSummary: "No readiness checks completed yet.", missingRequirementsSummary: "Readiness checks still need completion.", assignedOwnerTeam: manifest?.assignedOwnerTeam ?? "ParcelOps Operations", plannedDispatchDate: manifest?.plannedDispatchDate ?? "To schedule", completedDate: "Not completed", riskLevel: .medium, createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", reviewState: .needsReview)
    dispatchReadinessChecklists.insert(checklist, at: 0)
    persistDispatchReadinessChecklists()
    logAudit(action: .created, entityType: .dispatchChecklist, entityID: checklist.id.uuidString, entityLabel: checklist.title, summary: "Dispatch readiness checklist placeholder added.", afterDetail: checklist.auditDetail)
  }

  func updateDispatchReadinessChecklist(_ checklist: DispatchReadinessChecklist) {
    guard let index = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { return }
    let beforeDetail = dispatchReadinessChecklists[index].auditDetail
    dispatchReadinessChecklists[index] = checklist
    persistDispatchReadinessChecklists()
    logAudit(action: .edited, entityType: .dispatchChecklist, entityID: checklist.id.uuidString, entityLabel: checklist.title, summary: "Dispatch readiness checklist details updated.", beforeDetail: beforeDetail, afterDetail: checklist.auditDetail)
  }

  func markDispatchChecklistReady(_ checklist: DispatchReadinessChecklist) {
    updateDispatchChecklistStatus(checklist, status: .ready, reviewState: .monitor, summary: "Dispatch readiness checklist marked ready locally.", action: .edited)
  }

  func markDispatchChecklistBlocked(_ checklist: DispatchReadinessChecklist) {
    updateDispatchChecklistStatus(checklist, status: .blockedNeedsReview, reviewState: .needsReview, summary: "Dispatch readiness checklist blocked and needs review.", action: .edited, forceHighRisk: true)
  }

  func markDispatchChecklistCompleted(_ checklist: DispatchReadinessChecklist) {
    updateDispatchChecklistStatus(checklist, status: .completed, reviewState: .accepted, summary: "Dispatch readiness checklist completed locally.", action: .completed, completedDate: Self.auditTimestamp())
  }

  func reopenDispatchChecklist(_ checklist: DispatchReadinessChecklist) {
    updateDispatchChecklistStatus(checklist, status: .reopened, reviewState: .needsReview, summary: "Dispatch readiness checklist reopened.", action: .reopened)
  }

  func markDispatchChecklistReviewed(_ checklist: DispatchReadinessChecklist) {
    guard let index = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { return }
    let beforeDetail = dispatchReadinessChecklists[index].auditDetail
    dispatchReadinessChecklists[index].reviewState = .accepted
    dispatchReadinessChecklists[index].lastReviewedDate = Self.auditTimestamp()
    persistDispatchReadinessChecklists()
    logAudit(action: .reviewed, entityType: .dispatchChecklist, entityID: dispatchReadinessChecklists[index].id.uuidString, entityLabel: dispatchReadinessChecklists[index].title, summary: "Dispatch readiness checklist marked reviewed.", beforeDetail: beforeDetail, afterDetail: dispatchReadinessChecklists[index].auditDetail)
  }

  func removeDispatchReadinessChecklist(_ checklist: DispatchReadinessChecklist) {
    guard let index = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { return }
    let removed = dispatchReadinessChecklists.remove(at: index)
    persistDispatchReadinessChecklists()
    logAudit(action: .removed, entityType: .dispatchChecklist, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Dispatch readiness checklist removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from checklist: DispatchReadinessChecklist) {
    createReviewTask(linkedEntityType: .dispatchChecklist, linkedEntityID: checklist.id.uuidString, label: checklist.title, summary: "Review dispatch readiness: \(checklist.missingRequirementsSummary).", priority: checklist.riskLevel == .critical ? .urgent : checklist.riskLevel == .high ? .high : .normal, assignee: checklist.assignedOwnerTeam)
  }

  func createDraftMessage(from checklist: DispatchReadinessChecklist) {
    createDraftMessage(linkedEntityType: .dispatchChecklist, linkedEntityID: checklist.id.uuidString, label: checklist.title, recipient: checklist.assignedOwnerTeam)
    logAudit(action: .created, entityType: .dispatchChecklist, entityID: checklist.id.uuidString, entityLabel: checklist.title, summary: "Draft message created from dispatch readiness checklist.", afterDetail: checklist.auditDetail)
  }

  private func updateDispatchChecklistStatus(_ checklist: DispatchReadinessChecklist, status: DispatchChecklistStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false, completedDate: String? = nil) {
    guard let index = dispatchReadinessChecklists.firstIndex(where: { $0.id == checklist.id }) else { return }
    let beforeDetail = dispatchReadinessChecklists[index].auditDetail
    dispatchReadinessChecklists[index].checklistStatus = status
    dispatchReadinessChecklists[index].reviewState = reviewState
    dispatchReadinessChecklists[index].lastReviewedDate = Self.auditTimestamp()
    if let completedDate { dispatchReadinessChecklists[index].completedDate = completedDate }
    if forceHighRisk {
      dispatchReadinessChecklists[index].riskLevel = dispatchReadinessChecklists[index].riskLevel == .critical ? .critical : .high
    }
    persistDispatchReadinessChecklists()
    updateLinkedInboxOrdersForDispatchChecklistStatus(dispatchReadinessChecklists[index], action: action, summary: summary)
    logAudit(action: action, entityType: .dispatchChecklist, entityID: dispatchReadinessChecklists[index].id.uuidString, entityLabel: dispatchReadinessChecklists[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: dispatchReadinessChecklists[index].auditDetail)
  }

  private func updateLinkedInboxOrdersForDispatchChecklistStatus(_ checklist: DispatchReadinessChecklist, action: AuditAction, summary: String) {
    guard checklist.isInboxHandoffSetup else { return }

    var changedOrderIDs: [UUID] = []
    for orderID in checklist.orderIDs {
      guard let index = orders.firstIndex(where: { $0.id == orderID }) else { continue }
      let beforeDetail = orders[index].auditDetail
      let statusSummary: String
      let reviewState: ReviewState
      let orderStatus: OrderStatus?

      switch checklist.checklistStatus {
      case .draft:
        statusSummary = "Inbox dispatch readiness is in draft stage"
        reviewState = orders[index].reviewState
        orderStatus = nil
      case .ready:
        statusSummary = "Inbox dispatch readiness marked ready locally"
        reviewState = .monitor
        orderStatus = .shipped
      case .blockedNeedsReview:
        statusSummary = "Inbox dispatch readiness blocked and needs review"
        reviewState = .needsReview
        orderStatus = .exception
      case .completed:
        statusSummary = "Inbox dispatch readiness completed locally"
        reviewState = .accepted
        orderStatus = .shipped
      case .reopened:
        statusSummary = "Inbox dispatch readiness reopened for review"
        reviewState = .needsReview
        orderStatus = .exception
      }

      if let orderStatus, orders[index].status != .delivered {
        orders[index].status = orderStatus
      }
      orders[index].latestStatus = statusSummary
      orders[index].reviewState = reviewState
      orders[index].contactHistory.insert(
        ContactHistoryEvent(
          time: "Now",
          source: .manual,
          contactPoint: "Dispatch readiness",
          summary: statusSummary,
          evidence: "\(checklist.title): \(summary). Order status is \(orders[index].status.rawValue).",
          reviewState: reviewState
        ),
        at: 0
      )
      changedOrderIDs.append(orderID)
      logAudit(
        action: action,
        entityType: .order,
        entityID: orders[index].id.uuidString,
        entityLabel: orders[index].orderNumber,
        summary: "Inbox-created order updated from dispatch readiness.",
        beforeDetail: beforeDetail,
        afterDetail: "\(orders[index].auditDetail)\nChecklist: \(checklist.title)\nNo external carrier, label, scanner, or mailbox action occurred."
      )
    }

    if !changedOrderIDs.isEmpty {
      persistOrders()
    }
  }

  private func suggestedDispatchReadinessChecklists(shipmentManifestID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, inventoryReceiptID: UUID?, packageContentID: UUID?, custodyRecordID: UUID?, labelReferenceID: UUID?, scanSessionID: UUID?, evidenceID: UUID?, ownerTeam: String, dateText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [DispatchReadinessChecklist] {
    dispatchReadinessChecklists.filter { $0.matches(shipmentManifestID: shipmentManifestID, orderID: orderID, shipmentGroupID: shipmentGroupID, inventoryReceiptID: inventoryReceiptID, packageContentID: packageContentID, custodyRecordID: custodyRecordID, labelReferenceID: labelReferenceID, scanSessionID: scanSessionID, evidenceID: evidenceID, ownerTeam: ownerTeam, dateText: dateText, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedDispatchReadinessChecklists(for manifest: ShipmentManifestRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: manifest.id, orderID: manifest.includedOrderIDs.first, shipmentGroupID: manifest.shipmentGroupIDs.first, inventoryReceiptID: manifest.inventoryReceiptIDs.first, packageContentID: manifest.packageContentIDs.first, custodyRecordID: manifest.custodyRecordIDs.first, labelReferenceID: manifest.labelReferenceIDs.first, scanSessionID: manifest.scanSessionIDs.first, evidenceID: manifest.evidenceAttachmentIDs.first, ownerTeam: manifest.assignedOwnerTeam, dateText: manifest.plannedDispatchDate, context: "\(manifest.title) \(manifest.notes)", linkedEntityType: .shipmentManifest, linkedEntityID: manifest.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for scan: ScanSessionRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: scan).first?.id, orderID: scan.orderID, shipmentGroupID: scan.shipmentGroupID, inventoryReceiptID: scan.inventoryReceiptID, packageContentID: scan.packageContentID, custodyRecordID: scan.custodyRecordID, labelReferenceID: scan.linkedLabelReferenceID, scanSessionID: scan.id, evidenceID: scan.evidenceAttachmentIDs.first, ownerTeam: scan.assignedOperatorTeam, dateText: scan.completedDate, context: "\(scan.title) \(scan.notes)", linkedEntityType: .scanSession, linkedEntityID: scan.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for label: LabelReferenceRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: label).first?.id, orderID: label.orderID, shipmentGroupID: label.shipmentGroupID, inventoryReceiptID: label.inventoryReceiptID, packageContentID: label.packageContentID, custodyRecordID: label.custodyRecordID, labelReferenceID: label.id, scanSessionID: suggestedScanSessionRecords(for: label).first?.id, evidenceID: label.evidenceAttachmentIDs.first, ownerTeam: label.assignedOwnerTeam, dateText: label.lastReviewedDate, context: "\(label.title) \(label.notes)", linkedEntityType: .labelReference, linkedEntityID: label.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for order: TrackedOrder) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, packageContentID: suggestedPackageContents(for: order).first?.id, custodyRecordID: suggestedCustodyRecords(for: order).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: order).first?.id, scanSessionID: suggestedScanSessionRecords(for: order).first?.id, evidenceID: nil, ownerTeam: order.customer, dateText: "", context: "\(order.store) \(order.orderNumber) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for location: StorageLocationRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: location).first?.id, orderID: location.orderIDs.first, shipmentGroupID: location.shipmentGroupIDs.first, inventoryReceiptID: location.inventoryReceiptIDs.first, packageContentID: location.packageContentIDs.first, custodyRecordID: suggestedCustodyRecords(for: location).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: location).first?.id, scanSessionID: suggestedScanSessionRecords(for: location).first?.id, evidenceID: nil, ownerTeam: location.assignedOwnerTeam, dateText: "", context: "\(location.title) \(location.currentUsageSummary)", linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for custody: CustodyRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: custody).first?.id, orderID: custody.orderID, shipmentGroupID: custody.shipmentGroupID, inventoryReceiptID: custody.inventoryReceiptID, packageContentID: custody.packageContentID, custodyRecordID: custody.id, labelReferenceID: suggestedLabelReferenceRecords(for: custody).first?.id, scanSessionID: suggestedScanSessionRecords(for: custody).first?.id, evidenceID: custody.evidenceAttachmentIDs.first, ownerTeam: custody.assignedOwnerTeam, dateText: custody.expectedReturnCloseDate, context: "\(custody.title) \(custody.custodyReason)", linkedEntityType: .custodyRecord, linkedEntityID: custody.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for receipt: InventoryReceiptRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: receipt).first?.id, orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, inventoryReceiptID: receipt.id, packageContentID: receipt.packageContentID, custodyRecordID: suggestedCustodyRecords(for: receipt).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: receipt).first?.id, scanSessionID: suggestedScanSessionRecords(for: receipt).first?.id, evidenceID: receipt.evidenceAttachmentIDs.first, ownerTeam: receipt.assignedOwnerTeam, dateText: receipt.handoffDate, context: "\(receipt.title) \(receipt.itemSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for inspection: ReceivingInspectionRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: inspection).first?.id, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, packageContentID: inspection.packageContentID, custodyRecordID: suggestedCustodyRecords(for: inspection).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: inspection).first?.id, scanSessionID: suggestedScanSessionRecords(for: inspection).first?.id, evidenceID: inspection.evidenceAttachmentIDs.first, ownerTeam: inspection.assignedInspectorTeam, dateText: inspection.dueDate, context: "\(inspection.title) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for content: PackageContentRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: content).first?.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, packageContentID: content.id, custodyRecordID: suggestedCustodyRecords(for: content).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: content).first?.id, scanSessionID: suggestedScanSessionRecords(for: content).first?.id, evidenceID: content.evidenceAttachmentIDs.first, ownerTeam: "", dateText: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for request: ProcurementRequest) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: request).first?.id, orderID: nil, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, packageContentID: request.packageContentID, custodyRecordID: suggestedCustodyRecords(for: request).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: request).first?.id, scanSessionID: suggestedScanSessionRecords(for: request).first?.id, evidenceID: request.evidenceAttachmentIDs.first, ownerTeam: request.assignedBuyerTeam, dateText: request.neededByDate, context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for claim: ReturnClaimRecord) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: claim).first?.id, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, packageContentID: claim.packageContentID, custodyRecordID: suggestedCustodyRecords(for: claim).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: claim).first?.id, scanSessionID: suggestedScanSessionRecords(for: claim).first?.id, evidenceID: claim.evidenceAttachmentIDs.first, ownerTeam: claim.assignedOwnerTeam, dateText: claim.dueDate, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedDispatchReadinessChecklists(for item: WorkbenchItem) -> [DispatchReadinessChecklist] {
    suggestedDispatchReadinessChecklists(shipmentManifestID: suggestedShipmentManifestRecords(for: item).first?.id, orderID: nil, shipmentGroupID: nil, inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, packageContentID: suggestedPackageContents(for: item).first?.id, custodyRecordID: suggestedCustodyRecords(for: item).first?.id, labelReferenceID: suggestedLabelReferenceRecords(for: item).first?.id, scanSessionID: suggestedScanSessionRecords(for: item).first?.id, evidenceID: nil, ownerTeam: item.assignee, dateText: item.dueDateText, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func filteredLabelReferenceRecords(labelType: LabelReferenceType?, labelStatus: LabelReferenceStatus?, labelSource: LabelReferenceSource?, carrier: String, ownerTeam: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, reviewState: ReviewState?) -> [LabelReferenceRecord] {
    labelReferenceRecords.filter { record in
      let matchesType = labelType == nil || record.labelType == labelType
      let matchesStatus = labelStatus == nil || record.labelStatus == labelStatus
      let matchesSource = labelSource == nil || record.labelSource == labelSource
      let matchesCarrier = carrier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.associatedCarrier.localizedCaseInsensitiveContains(carrier)
      let matchesOwner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.assignedOwnerTeam.localizedCaseInsensitiveContains(ownerTeam)
      let matchesRisk = riskLevel == nil || record.riskLevel == riskLevel
      let matchesLinked = linkedEntityType == nil || record.linkedEntityType == linkedEntityType
      let matchesReview = reviewState == nil || record.reviewState == reviewState
      return matchesType && matchesStatus && matchesSource && matchesCarrier && matchesOwner && matchesRisk && matchesLinked && matchesReview
    }
  }

  func addLabelReferencePlaceholder() {
    let order = orders.first
    let location = storageLocations.first
    let record = LabelReferenceRecord(title: "New label reference \(labelReferenceRecords.count + 1)", linkedEntityType: .order, linkedEntityID: order?.id.uuidString ?? "Unlinked", labelType: .trackingLabel, labelValuePlaceholder: order?.trackingNumber ?? "To assign", labelSource: .manualPlaceholder, labelStatus: .draft, associatedCarrier: order?.carrier ?? "Unassigned", storageLocationID: location?.id, inventoryReceiptID: inventoryReceipts.first?.id, custodyRecordID: custodyRecords.first?.id, orderID: order?.id, shipmentGroupID: shipmentGroups.first?.id, packageContentID: packageContents.first?.id, evidenceAttachmentIDs: evidenceAttachments.prefix(1).map(\.id), assignedOwnerTeam: "ParcelOps Operations", createdDate: Self.auditTimestamp(), lastReviewedDate: "Never", notes: "Local placeholder only. No barcode scanning, QR generation, or label printing is performed.", riskLevel: .medium, reviewState: .needsReview)
    labelReferenceRecords.insert(record, at: 0)
    persistLabelReferenceRecords()
    logAudit(action: .created, entityType: .labelReference, entityID: record.id.uuidString, entityLabel: record.title, summary: "Label reference placeholder added.", afterDetail: record.auditDetail)
  }

  func updateLabelReferenceRecord(_ record: LabelReferenceRecord) {
    guard let index = labelReferenceRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = labelReferenceRecords[index].auditDetail
    labelReferenceRecords[index] = record
    persistLabelReferenceRecords()
    logAudit(action: .edited, entityType: .labelReference, entityID: record.id.uuidString, entityLabel: record.title, summary: "Label reference details updated.", beforeDetail: beforeDetail, afterDetail: record.auditDetail)
  }

  func markLabelReferencePrinted(_ record: LabelReferenceRecord) {
    updateLabelReferenceStatus(record, status: .printedLocally, reviewState: .monitor, summary: "Label reference marked printed locally.", action: .edited)
  }

  func markLabelReferenceVerified(_ record: LabelReferenceRecord) {
    updateLabelReferenceStatus(record, status: .scannedVerified, reviewState: .accepted, summary: "Label reference marked scanned or verified locally.", action: .completed)
  }

  func markLabelReferenceInvalid(_ record: LabelReferenceRecord) {
    updateLabelReferenceStatus(record, status: .invalidNeedsReview, reviewState: .needsReview, summary: "Label reference marked invalid and needs review.", action: .edited, forceHighRisk: true)
  }

  func markLabelReferenceReviewed(_ record: LabelReferenceRecord) {
    guard let index = labelReferenceRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = labelReferenceRecords[index].auditDetail
    labelReferenceRecords[index].reviewState = .accepted
    labelReferenceRecords[index].lastReviewedDate = Self.auditTimestamp()
    persistLabelReferenceRecords()
    logAudit(action: .reviewed, entityType: .labelReference, entityID: labelReferenceRecords[index].id.uuidString, entityLabel: labelReferenceRecords[index].title, summary: "Label reference marked reviewed.", beforeDetail: beforeDetail, afterDetail: labelReferenceRecords[index].auditDetail)
  }

  func removeLabelReferenceRecord(_ record: LabelReferenceRecord) {
    guard let index = labelReferenceRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let removed = labelReferenceRecords.remove(at: index)
    persistLabelReferenceRecords()
    logAudit(action: .removed, entityType: .labelReference, entityID: removed.id.uuidString, entityLabel: removed.title, summary: "Label reference removed.", beforeDetail: removed.auditDetail)
  }

  func createReviewTask(from record: LabelReferenceRecord) {
    createReviewTask(linkedEntityType: .labelReference, linkedEntityID: record.id.uuidString, label: record.title, summary: "Review label reference: \(record.labelType.rawValue), value \(record.labelValuePlaceholder), status \(record.labelStatus.rawValue).", priority: record.riskLevel == .critical ? .urgent : record.riskLevel == .high ? .high : .normal, assignee: record.assignedOwnerTeam)
  }

  func createDraftMessage(from record: LabelReferenceRecord) {
    createDraftMessage(linkedEntityType: .labelReference, linkedEntityID: record.id.uuidString, label: record.title, recipient: record.assignedOwnerTeam)
    logAudit(action: .created, entityType: .labelReference, entityID: record.id.uuidString, entityLabel: record.title, summary: "Draft message created from label reference.", afterDetail: record.auditDetail)
  }

  private func updateLabelReferenceStatus(_ record: LabelReferenceRecord, status: LabelReferenceStatus, reviewState: ReviewState, summary: String, action: AuditAction, forceHighRisk: Bool = false) {
    guard let index = labelReferenceRecords.firstIndex(where: { $0.id == record.id }) else { return }
    let beforeDetail = labelReferenceRecords[index].auditDetail
    labelReferenceRecords[index].labelStatus = status
    labelReferenceRecords[index].reviewState = reviewState
    labelReferenceRecords[index].lastReviewedDate = Self.auditTimestamp()
    if forceHighRisk {
      labelReferenceRecords[index].riskLevel = labelReferenceRecords[index].riskLevel == .critical ? .critical : .high
    }
    persistLabelReferenceRecords()
    logAudit(action: action, entityType: .labelReference, entityID: labelReferenceRecords[index].id.uuidString, entityLabel: labelReferenceRecords[index].title, summary: summary, beforeDetail: beforeDetail, afterDetail: labelReferenceRecords[index].auditDetail)
  }

  private func suggestedLabelReferenceRecords(storageLocationID: UUID?, inventoryReceiptID: UUID?, custodyRecordID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, labelValue: String, carrier: String, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> [LabelReferenceRecord] {
    labelReferenceRecords.filter { $0.matches(storageLocationID: storageLocationID, inventoryReceiptID: inventoryReceiptID, custodyRecordID: custodyRecordID, orderID: orderID, shipmentGroupID: shipmentGroupID, packageContentID: packageContentID, evidenceID: evidenceID, labelValue: labelValue, carrier: carrier, ownerTeam: ownerTeam, context: context, linkedEntityType: linkedEntityType, linkedEntityID: linkedEntityID) }
  }

  func suggestedLabelReferenceRecords(for location: StorageLocationRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: location.id, inventoryReceiptID: location.inventoryReceiptIDs.first, custodyRecordID: suggestedCustodyRecords(for: location).first?.id, orderID: location.orderIDs.first, shipmentGroupID: location.shipmentGroupIDs.first, packageContentID: location.packageContentIDs.first, evidenceID: nil, labelValue: location.locationCode, carrier: "", ownerTeam: location.assignedOwnerTeam, context: "\(location.title) \(location.areaZone) \(location.currentUsageSummary)", linkedEntityType: .storageLocation, linkedEntityID: location.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for record: CustodyRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: record.storageLocationID ?? record.destinationLocationID ?? record.sourceLocationID, inventoryReceiptID: record.inventoryReceiptID, custodyRecordID: record.id, orderID: record.orderID, shipmentGroupID: record.shipmentGroupID, packageContentID: record.packageContentID, evidenceID: record.evidenceAttachmentIDs.first, labelValue: "", carrier: "", ownerTeam: record.assignedOwnerTeam, context: "\(record.title) \(record.custodyReason)", linkedEntityType: .custodyRecord, linkedEntityID: record.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for receipt: InventoryReceiptRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: receipt).first?.id, inventoryReceiptID: receipt.id, custodyRecordID: suggestedCustodyRecords(for: receipt).first?.id, orderID: receipt.orderID, shipmentGroupID: receipt.shipmentGroupID, packageContentID: receipt.packageContentID, evidenceID: receipt.evidenceAttachmentIDs.first, labelValue: receipt.storageLocationSummary, carrier: "", ownerTeam: receipt.assignedOwnerTeam, context: "\(receipt.title) \(receipt.itemSummary)", linkedEntityType: .inventoryReceipt, linkedEntityID: receipt.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for inspection: ReceivingInspectionRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: inspection).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: inspection).first?.id, custodyRecordID: suggestedCustodyRecords(for: inspection).first?.id, orderID: inspection.orderID, shipmentGroupID: inspection.shipmentGroupID, packageContentID: inspection.packageContentID, evidenceID: inspection.evidenceAttachmentIDs.first, labelValue: "", carrier: "", ownerTeam: inspection.assignedInspectorTeam, context: "\(inspection.title) \(inspection.expectedItemSummary) \(inspection.receivedItemSummary)", linkedEntityType: .receivingInspection, linkedEntityID: inspection.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for order: TrackedOrder) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: order).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: order).first?.id, custodyRecordID: suggestedCustodyRecords(for: order).first?.id, orderID: order.id, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: order).first?.id, evidenceID: nil, labelValue: "\(order.trackingNumber) \(order.orderNumber)", carrier: order.carrier, ownerTeam: order.customer, context: "\(order.store) \(order.destination)", linkedEntityType: .order, linkedEntityID: order.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for content: PackageContentRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: content).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: content).first?.id, custodyRecordID: suggestedCustodyRecords(for: content).first?.id, orderID: content.orderID, shipmentGroupID: content.shipmentGroupID, packageContentID: content.id, evidenceID: content.evidenceAttachmentIDs.first, labelValue: content.itemSummary, carrier: "", ownerTeam: "", context: "\(content.title) \(content.itemSummary)", linkedEntityType: .packageContent, linkedEntityID: content.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for request: ProcurementRequest) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: request).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: request).first?.id, custodyRecordID: suggestedCustodyRecords(for: request).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: request.packageContentID, evidenceID: request.evidenceAttachmentIDs.first, labelValue: request.requestedItemsSummary, carrier: "", ownerTeam: request.assignedBuyerTeam, context: "\(request.title) \(request.requestedItemsSummary)", linkedEntityType: .procurementRequest, linkedEntityID: request.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for claim: ReturnClaimRecord) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: claim).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: claim).first?.id, custodyRecordID: suggestedCustodyRecords(for: claim).first?.id, orderID: claim.orderID, shipmentGroupID: claim.shipmentGroupID, packageContentID: claim.packageContentID, evidenceID: claim.evidenceAttachmentIDs.first, labelValue: claim.reasonSummary, carrier: "", ownerTeam: claim.assignedOwnerTeam, context: "\(claim.title) \(claim.reasonSummary)", linkedEntityType: .returnClaim, linkedEntityID: claim.id.uuidString)
  }

  func suggestedLabelReferenceRecords(for item: WorkbenchItem) -> [LabelReferenceRecord] {
    suggestedLabelReferenceRecords(storageLocationID: suggestedStorageLocations(for: item).first?.id, inventoryReceiptID: suggestedInventoryReceipts(for: item).first?.id, custodyRecordID: suggestedCustodyRecords(for: item).first?.id, orderID: nil, shipmentGroupID: nil, packageContentID: suggestedPackageContents(for: item).first?.id, evidenceID: nil, labelValue: item.summary, carrier: "", ownerTeam: item.assignee, context: "\(item.title) \(item.summary)", linkedEntityType: item.linkedEntityType, linkedEntityID: item.linkedEntityID)
  }

  func addAccountCredentialRecordPlaceholder() {
    let account = AccountCredentialRecord(
      accountName: "New account \(accountCredentialRecords.count + 1)",
      organisation: "Unassigned organisation",
      linkedContactID: nil,
      linkedEntityType: .supplier,
      linkedEntityID: "Unlinked",
      loginURL: "https://example.com/login",
      usernameLabel: "Username held outside ParcelOps",
      credentialStorageStatus: .needsSetup,
      mfaStatus: .unknown,
      renewalReviewDate: "Next month",
      isEnabled: false,
      notes: "Local placeholder only. Do not store passwords, tokens, or API keys here.",
      createdDate: Self.auditTimestamp(),
      lastCheckedDate: "Never",
      reviewState: .needsReview
    )
    accountCredentialRecords.insert(account, at: 0)
    persistAccountCredentialRecords()
    logAudit(
      action: .created,
      entityType: .accountCredentialRecord,
      entityID: account.id.uuidString,
      entityLabel: account.accountName,
      summary: "Account credential placeholder added.",
      afterDetail: account.auditDetail
    )
  }

  func addAccountCredentialRecord(linkedEntityType: AccountLinkedEntityType, linkedEntityID: String, organisation: String, label: String, linkedContactID: UUID? = nil) {
    let account = AccountCredentialRecord(
      accountName: "\(label) account",
      organisation: organisation,
      linkedContactID: linkedContactID,
      linkedEntityType: linkedEntityType,
      linkedEntityID: linkedEntityID,
      loginURL: "https://example.com/login",
      usernameLabel: "External vault username reference",
      credentialStorageStatus: .needsSetup,
      mfaStatus: .unknown,
      renewalReviewDate: "Next month",
      isEnabled: false,
      notes: "Local account record created from workflow. No secrets are stored in ParcelOps.",
      createdDate: Self.auditTimestamp(),
      lastCheckedDate: "Never",
      reviewState: .needsReview
    )
    accountCredentialRecords.insert(account, at: 0)
    persistAccountCredentialRecords()
    logAudit(
      action: .created,
      entityType: .accountCredentialRecord,
      entityID: account.id.uuidString,
      entityLabel: account.accountName,
      summary: "Account credential placeholder created from workflow.",
      afterDetail: account.auditDetail
    )
  }

  func updateAccountCredentialRecord(_ account: AccountCredentialRecord) {
    guard let index = accountCredentialRecords.firstIndex(where: { $0.id == account.id }) else { return }
    let beforeDetail = accountCredentialRecords[index].auditDetail
    accountCredentialRecords[index] = account
    persistAccountCredentialRecords()
    logAudit(
      action: .edited,
      entityType: .accountCredentialRecord,
      entityID: account.id.uuidString,
      entityLabel: account.accountName,
      summary: "Account credential placeholder details updated.",
      beforeDetail: beforeDetail,
      afterDetail: account.auditDetail
    )
  }

  func toggleAccountCredentialRecord(_ account: AccountCredentialRecord) {
    guard let index = accountCredentialRecords.firstIndex(where: { $0.id == account.id }) else { return }
    let beforeDetail = accountCredentialRecords[index].auditDetail
    accountCredentialRecords[index].isEnabled.toggle()
    persistAccountCredentialRecords()
    logAudit(
      action: accountCredentialRecords[index].isEnabled ? .enabled : .disabled,
      entityType: .accountCredentialRecord,
      entityID: accountCredentialRecords[index].id.uuidString,
      entityLabel: accountCredentialRecords[index].accountName,
      summary: accountCredentialRecords[index].isEnabled ? "Account placeholder enabled." : "Account placeholder disabled.",
      beforeDetail: beforeDetail,
      afterDetail: accountCredentialRecords[index].auditDetail
    )
  }

  func markAccountCredentialRecordReviewed(_ account: AccountCredentialRecord) {
    guard let index = accountCredentialRecords.firstIndex(where: { $0.id == account.id }) else { return }
    let beforeDetail = accountCredentialRecords[index].auditDetail
    accountCredentialRecords[index].reviewState = .accepted
    persistAccountCredentialRecords()
    logAudit(
      action: .reviewed,
      entityType: .accountCredentialRecord,
      entityID: accountCredentialRecords[index].id.uuidString,
      entityLabel: accountCredentialRecords[index].accountName,
      summary: "Account placeholder marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: accountCredentialRecords[index].auditDetail
    )
  }

  func markAccountCredentialRecordChecked(_ account: AccountCredentialRecord) {
    guard let index = accountCredentialRecords.firstIndex(where: { $0.id == account.id }) else { return }
    let beforeDetail = accountCredentialRecords[index].auditDetail
    accountCredentialRecords[index].lastCheckedDate = Self.auditTimestamp()
    persistAccountCredentialRecords()
    logAudit(
      action: .evaluated,
      entityType: .accountCredentialRecord,
      entityID: accountCredentialRecords[index].id.uuidString,
      entityLabel: accountCredentialRecords[index].accountName,
      summary: "Account placeholder checked locally.",
      beforeDetail: beforeDetail,
      afterDetail: accountCredentialRecords[index].auditDetail
    )
  }

  func removeAccountCredentialRecord(_ account: AccountCredentialRecord) {
    guard let index = accountCredentialRecords.firstIndex(where: { $0.id == account.id }) else { return }
    let removed = accountCredentialRecords.remove(at: index)
    persistAccountCredentialRecords()
    logAudit(
      action: .removed,
      entityType: .accountCredentialRecord,
      entityID: removed.id.uuidString,
      entityLabel: removed.accountName,
      summary: "Account credential placeholder removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func createReviewTask(from account: AccountCredentialRecord) {
    createReviewTask(
      linkedEntityType: .account,
      linkedEntityID: account.id.uuidString,
      label: account.accountName,
      summary: "Review local account placeholder for \(account.organisation). Credential status: \(account.credentialStorageStatus.rawValue). MFA: \(account.mfaStatus.rawValue).",
      priority: account.reviewState == .needsReview || account.mfaStatus == .needsReview ? .high : .normal
    )
  }

  func createDraftMessage(from account: AccountCredentialRecord) {
    let recipient = account.linkedContactID.flatMap { contactID in
      contactDirectoryEntries.first { $0.id == contactID }?.email
    } ?? "operations@parcelops.example"
    createDraftMessage(
      linkedEntityType: .account,
      linkedEntityID: account.id.uuidString,
      label: account.accountName,
      recipient: recipient
    )
    logAudit(
      action: .created,
      entityType: .accountCredentialRecord,
      entityID: account.id.uuidString,
      entityLabel: account.accountName,
      summary: "Draft message created from account placeholder.",
      afterDetail: account.auditDetail
    )
  }

  func suggestedAccounts(for order: TrackedOrder) -> [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.isEnabled
        && (account.linkedEntityID == order.id.uuidString
          || account.organisation.localizedCaseInsensitiveContains(order.store)
          || order.store.localizedCaseInsensitiveContains(account.organisation))
    }
  }

  func suggestedAccounts(for email: ForwardedEmailIntake) -> [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.isEnabled
        && (account.linkedEntityID == email.id.uuidString
          || account.organisation.localizedCaseInsensitiveContains(email.detectedMerchant)
          || email.detectedMerchant.localizedCaseInsensitiveContains(account.organisation))
    }
  }

  func suggestedAccounts(for contact: ContactDirectoryEntry) -> [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.linkedContactID == contact.id
        || account.linkedEntityID == contact.id.uuidString
        || account.organisation.localizedCaseInsensitiveContains(contact.organisation)
        || contact.organisation.localizedCaseInsensitiveContains(account.organisation)
    }
  }

  func suggestedAccounts(for connection: ShopifyConnection) -> [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.linkedEntityID == connection.id.uuidString
        || account.organisation.localizedCaseInsensitiveContains(connection.storeName)
        || connection.storeName.localizedCaseInsensitiveContains(account.organisation)
    }
  }

  func suggestedAccounts(for connection: SourceConnection) -> [AccountCredentialRecord] {
    accountCredentialRecords.filter { account in
      account.linkedEntityID == connection.id.uuidString
        || account.organisation.localizedCaseInsensitiveContains(connection.name)
        || connection.name.localizedCaseInsensitiveContains(account.organisation)
    }
  }

  func addVendorProfilePlaceholder() {
    let profile = VendorProfile(
      name: "New vendor profile \(vendorProfiles.count + 1)",
      profileType: .supplier,
      primaryOrganisation: "Unassigned organisation",
      website: "https://example.com",
      supportURL: "https://example.com/support",
      defaultContactID: nil,
      defaultAccountID: nil,
      preferredChannel: .email,
      serviceLevelNotes: "Define local service expectations and escalation notes.",
      riskLevel: .medium,
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    vendorProfiles.insert(profile, at: 0)
    persistVendorProfiles()
    logAudit(
      action: .created,
      entityType: .vendorProfile,
      entityID: profile.id.uuidString,
      entityLabel: profile.name,
      summary: "Vendor profile placeholder added.",
      afterDetail: profile.auditDetail
    )
  }

  func addVendorProfile(profileType: VendorProfileType, organisation: String, label: String, defaultContactID: UUID? = nil, defaultAccountID: UUID? = nil) {
    let profile = VendorProfile(
      name: "\(label) profile",
      profileType: profileType,
      primaryOrganisation: organisation,
      website: "https://example.com",
      supportURL: "https://example.com/support",
      defaultContactID: defaultContactID,
      defaultAccountID: defaultAccountID,
      preferredChannel: .email,
      serviceLevelNotes: "Local profile created from workflow.",
      riskLevel: .medium,
      isEnabled: false,
      createdDate: Self.auditTimestamp(),
      lastReviewedDate: "Never",
      reviewState: .needsReview
    )
    vendorProfiles.insert(profile, at: 0)
    persistVendorProfiles()
    logAudit(
      action: .created,
      entityType: .vendorProfile,
      entityID: profile.id.uuidString,
      entityLabel: profile.name,
      summary: "Vendor profile created from workflow.",
      afterDetail: profile.auditDetail
    )
  }

  func updateVendorProfile(_ profile: VendorProfile) {
    guard let index = vendorProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = vendorProfiles[index].auditDetail
    vendorProfiles[index] = profile
    persistVendorProfiles()
    logAudit(
      action: .edited,
      entityType: .vendorProfile,
      entityID: profile.id.uuidString,
      entityLabel: profile.name,
      summary: "Vendor profile details updated.",
      beforeDetail: beforeDetail,
      afterDetail: profile.auditDetail
    )
  }

  func toggleVendorProfile(_ profile: VendorProfile) {
    guard let index = vendorProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = vendorProfiles[index].auditDetail
    vendorProfiles[index].isEnabled.toggle()
    persistVendorProfiles()
    logAudit(
      action: vendorProfiles[index].isEnabled ? .enabled : .disabled,
      entityType: .vendorProfile,
      entityID: vendorProfiles[index].id.uuidString,
      entityLabel: vendorProfiles[index].name,
      summary: vendorProfiles[index].isEnabled ? "Vendor profile enabled." : "Vendor profile disabled.",
      beforeDetail: beforeDetail,
      afterDetail: vendorProfiles[index].auditDetail
    )
  }

  func markVendorProfileReviewed(_ profile: VendorProfile) {
    guard let index = vendorProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let beforeDetail = vendorProfiles[index].auditDetail
    vendorProfiles[index].reviewState = .accepted
    vendorProfiles[index].lastReviewedDate = Self.auditTimestamp()
    persistVendorProfiles()
    logAudit(
      action: .reviewed,
      entityType: .vendorProfile,
      entityID: vendorProfiles[index].id.uuidString,
      entityLabel: vendorProfiles[index].name,
      summary: "Vendor profile marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: vendorProfiles[index].auditDetail
    )
  }

  func removeVendorProfile(_ profile: VendorProfile) {
    guard let index = vendorProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
    let removed = vendorProfiles.remove(at: index)
    persistVendorProfiles()
    logAudit(
      action: .removed,
      entityType: .vendorProfile,
      entityID: removed.id.uuidString,
      entityLabel: removed.name,
      summary: "Vendor profile removed.",
      beforeDetail: removed.auditDetail
    )
  }

  func createReviewTask(from profile: VendorProfile) {
    createReviewTask(
      linkedEntityType: .vendorProfile,
      linkedEntityID: profile.id.uuidString,
      label: profile.name,
      summary: "Review vendor profile for \(profile.primaryOrganisation). Risk: \(profile.riskLevel.rawValue). \(profile.serviceLevelNotes)",
      priority: profile.riskLevel == .critical ? .urgent : profile.riskLevel == .high ? .high : .normal
    )
  }

  func createDraftMessage(from profile: VendorProfile) {
    let recipient = profile.defaultContactID.flatMap { contactID in
      contactDirectoryEntries.first { $0.id == contactID }?.email
    } ?? "operations@parcelops.example"
    createDraftMessage(
      linkedEntityType: .vendorProfile,
      linkedEntityID: profile.id.uuidString,
      label: profile.name,
      recipient: recipient
    )
    logAudit(
      action: .created,
      entityType: .vendorProfile,
      entityID: profile.id.uuidString,
      entityLabel: profile.name,
      summary: "Draft message created from vendor profile.",
      afterDetail: profile.auditDetail
    )
  }

  func createReviewTask(from activity: TimelineActivity) {
    guard let linkedEntityType = activity.reviewTaskLinkedEntityType else { return }
    createReviewTask(
      linkedEntityType: linkedEntityType,
      linkedEntityID: activity.entityID,
      label: activity.title,
      summary: "Follow up timeline activity: \(activity.detail)",
      priority: activity.risk == .critical ? .urgent : activity.risk == .high ? .high : .normal
    )
  }

  func createDraftMessage(from activity: TimelineActivity) {
    guard let linkedEntityType = activity.reviewTaskLinkedEntityType else { return }
    createDraftMessage(
      linkedEntityType: linkedEntityType,
      linkedEntityID: activity.entityID,
      label: activity.title,
      recipient: "operations@parcelops.example"
    )
  }

  func createReviewTask(from item: WorkbenchItem) {
    createReviewTask(
      linkedEntityType: item.linkedEntityType,
      linkedEntityID: item.linkedEntityID,
      label: item.title,
      summary: "Follow up workbench item from \(item.source.rawValue): \(item.summary) Next action: \(item.suggestedNextAction)",
      priority: item.rank >= 4 ? .urgent : item.rank >= 3 ? .high : .normal,
      assignee: item.assignee.isEmpty ? "Operations" : item.assignee
    )
  }

  func createDraftMessage(from item: WorkbenchItem) {
    createDraftMessage(
      linkedEntityType: item.linkedEntityType,
      linkedEntityID: item.linkedEntityID,
      label: item.title,
      recipient: "operations@parcelops.example"
    )
  }

  func markWorkbenchItemReviewed(_ item: WorkbenchItem) {
    switch item.source {
    case .reviewTask:
      if let task = reviewTasks.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markReviewTaskReviewed(task)
      }
    case .handoffNote:
      if let note = handoffNotes.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markHandoffNoteReviewed(note)
      }
    case .intakeEmail, .intakeParser:
      if let email = intakeEmails.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markIntakeEmailReviewed(email)
      }
    case .spaceMailIntake:
      if let connection = spaceMailIMAPConnections.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markSpaceMailIMAPConnectionReviewed(connection)
      }
    case .gmailIntake:
      if let connection = gmailMailboxConnections.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markGmailMailboxConnectionReviewed(connection)
      }
    case .reconciliation:
      if let issue = reconciliationIssues.first(where: { $0.id == item.linkedEntityID }) {
        markReconciliationIssueReviewed(issue)
      }
    case .shipmentGroup:
      if let group = shipmentGroups.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markShipmentGroupReviewed(group)
      }
    case .tracking:
      if let event = carrierTrackingEvents.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markTrackingEventReviewed(event)
      }
    case .evidence:
      if let attachment = evidenceAttachments.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markEvidenceReviewed(attachment)
      }
    case .slaPolicy:
      if let policy = slaPolicies.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markSLAPolicyReviewed(policy)
      }
    case .exceptionPlaybook:
      if let playbook = exceptionPlaybooks.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markExceptionPlaybookReviewed(playbook)
      }
    case .draftMessage:
      if let draft = draftMessages.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        var updatedDraft = draft
        updatedDraft.reviewState = .accepted
        updateDraftMessage(updatedDraft)
      }
    case .contact:
      if let contact = contactDirectoryEntries.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markContactDirectoryEntryReviewed(contact)
      }
    case .customerProfile:
      if let profile = customerRecipientProfiles.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markCustomerRecipientProfileReviewed(profile)
      }
    case .destinationAddress:
      if let address = destinationAddresses.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markDestinationAddressReviewed(address)
      }
    case .deliveryInstruction:
      if let instruction = deliveryInstructions.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markDeliveryInstructionReviewed(instruction)
      }
    case .packageContent:
      if let content = packageContents.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markPackageContentReviewed(content)
      }
    case .costRecord:
      if let cost = costRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markCostRecordReviewed(cost)
      }
    case .returnClaim:
      if let claim = returnClaims.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markReturnClaimReviewed(claim)
      }
    case .procurementRequest:
      if let request = procurementRequests.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markProcurementRequestReviewed(request)
      }
    case .receivingInspection:
      if let inspection = receivingInspections.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markReceivingInspectionReviewed(inspection)
      }
    case .inventoryReceipt:
      if let receipt = inventoryReceipts.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markInventoryReceiptReviewed(receipt)
      }
    case .storageLocation:
      if let location = storageLocations.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markStorageLocationReviewed(location)
      }
    case .custodyRecord:
      if let record = custodyRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markCustodyRecordReviewed(record)
      }
    case .labelReference:
      if let record = labelReferenceRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markLabelReferenceReviewed(record)
      }
    case .scanSession:
      if let record = scanSessionRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markScanSessionReviewed(record)
      }
    case .shipmentManifest:
      if let record = shipmentManifestRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markShipmentManifestReviewed(record)
      }
    case .dispatchChecklist:
      if let checklist = dispatchReadinessChecklists.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markDispatchChecklistReviewed(checklist)
      }
    case .account:
      if let account = accountCredentialRecords.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markAccountCredentialRecordReviewed(account)
      }
    case .vendorProfile:
      if let profile = vendorProfiles.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markVendorProfileReviewed(profile)
      }
    case .setupPlaceholder:
      if item.linkedEntityID == "local-data-hygiene" {
        logAudit(
          action: .reviewed,
          entityType: .settings,
          entityID: item.linkedEntityID,
          entityLabel: item.title,
          summary: "Local data hygiene workbench item reviewed locally.",
          afterDetail: "\(item.status): \(item.summary)\nNext action at review time: \(item.suggestedNextAction)\nNo records were deleted, merged, rewritten, or refreshed."
        )
      } else if let mailbox = mailboxes.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markTrackedMailboxPlaceholderReviewed(mailbox)
      } else if let connection = shopifyConnections.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markShopifyPlaceholderReviewed(connection)
      } else if let folder = watchedFolders.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markWatchedFolderPlaceholderReviewed(folder)
      } else if let connection = connections.first(where: { $0.id.uuidString == item.linkedEntityID }) {
        markStoreLoginPlaceholderReviewed(connection)
      } else {
        logAudit(
          action: .reviewed,
          entityType: .settings,
          entityID: item.linkedEntityID,
          entityLabel: item.title,
          summary: "Setup placeholder workbench item reviewed locally.",
          afterDetail: "\(item.source.rawValue): \(item.summary)\nNo matching local setup placeholder was found. No live integration action occurred."
        )
      }
    case .importQueue, .acceptanceReview, .validation:
      logAudit(
        action: .reviewed,
        entityType: .auditEvent,
        entityID: item.id,
        entityLabel: item.title,
        summary: "Workbench item marked reviewed locally.",
        afterDetail: "\(item.source.rawValue): \(item.summary)"
      )
    }
  }

  func suggestedVendorProfiles(for order: TrackedOrder) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.isEnabled
        && (profile.primaryOrganisation.localizedCaseInsensitiveContains(order.store)
          || order.store.localizedCaseInsensitiveContains(profile.primaryOrganisation)
          || profile.primaryOrganisation.localizedCaseInsensitiveContains(order.carrier)
          || order.carrier.localizedCaseInsensitiveContains(profile.primaryOrganisation))
    }
  }

  func suggestedVendorProfiles(for email: ForwardedEmailIntake) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.isEnabled
        && (profile.primaryOrganisation.localizedCaseInsensitiveContains(email.detectedMerchant)
          || email.detectedMerchant.localizedCaseInsensitiveContains(profile.primaryOrganisation)
          || email.sender.localizedCaseInsensitiveContains(profile.primaryOrganisation))
    }
  }

  func suggestedVendorProfiles(for event: CarrierTrackingEvent) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.isEnabled
        && (profile.profileType == .carrier
          || profile.primaryOrganisation.localizedCaseInsensitiveContains(event.carrier)
          || event.carrier.localizedCaseInsensitiveContains(profile.primaryOrganisation))
    }
  }

  func suggestedVendorProfiles(for contact: ContactDirectoryEntry) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.defaultContactID == contact.id
        || profile.primaryOrganisation.localizedCaseInsensitiveContains(contact.organisation)
        || contact.organisation.localizedCaseInsensitiveContains(profile.primaryOrganisation)
    }
  }

  func suggestedVendorProfiles(for account: AccountCredentialRecord) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.defaultAccountID == account.id
        || profile.primaryOrganisation.localizedCaseInsensitiveContains(account.organisation)
        || account.organisation.localizedCaseInsensitiveContains(profile.primaryOrganisation)
    }
  }

  func suggestedVendorProfiles(for connection: ShopifyConnection) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.profileType == .shopifyStore
        && (profile.primaryOrganisation.localizedCaseInsensitiveContains(connection.storeName)
          || connection.storeName.localizedCaseInsensitiveContains(profile.primaryOrganisation))
    }
  }

  func suggestedVendorProfiles(for connection: SourceConnection) -> [VendorProfile] {
    vendorProfiles.filter { profile in
      profile.primaryOrganisation.localizedCaseInsensitiveContains(connection.name)
        || connection.name.localizedCaseInsensitiveContains(profile.primaryOrganisation)
    }
  }

  func exportToParcel(order: TrackedOrder) {
    Task { try? await parcelExportService.export(order: order) }
  }

  func addTrackedMailboxPlaceholder() {
    let mailbox = TrackedMailbox(address: "new-mailbox@company.example", provider: .microsoft365, monitoredFolders: "Inbox", status: "Needs auth", lastChecked: "Never", routingRule: "New mailbox intake")
    mailboxes.append(mailbox)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .trackedMailbox,
      entityID: mailbox.id.uuidString,
      entityLabel: mailbox.address,
      summary: "Tracked mailbox placeholder added.",
      afterDetail: "\(mailbox.auditDetail)\nPlaceholder only. No mailbox was contacted and no OAuth, IMAP login, token, password, or network action occurred."
    )
  }

  func removeTrackedMailboxPlaceholder(_ mailbox: TrackedMailbox) {
    guard let index = mailboxes.firstIndex(where: { $0.id == mailbox.id }) else { return }
    let beforeDetail = mailboxes[index].auditDetail
    mailboxes.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .trackedMailbox,
      entityID: mailbox.id.uuidString,
      entityLabel: mailbox.address,
      summary: "Tracked mailbox placeholder removed.",
      beforeDetail: "\(beforeDetail)\nRemoved locally only. No mailbox, OAuth, IMAP, token, password, or network action occurred."
    )
  }

  func markTrackedMailboxPlaceholderReviewed(_ mailbox: TrackedMailbox) {
    guard let index = mailboxes.firstIndex(where: { $0.id == mailbox.id }) else { return }
    let beforeDetail = mailboxes[index].auditDetail
    mailboxes[index].status = "Reviewed locally"
    mailboxes[index].lastChecked = Self.auditTimestamp()
    persistIntegrations()
    logAudit(
      action: .reviewed,
      entityType: .trackedMailbox,
      entityID: mailboxes[index].id.uuidString,
      entityLabel: mailboxes[index].address,
      summary: "Tracked mailbox placeholder reviewed locally.",
      beforeDetail: beforeDetail,
      afterDetail: "\(mailboxes[index].auditDetail)\nReview only. No mailbox was contacted and no OAuth, IMAP login, token, password, or network action occurred."
    )
  }

  func addMicrosoft365MailboxConnectionPlaceholder() {
    let connection = Microsoft365MailboxConnection(
      displayName: "New Microsoft 365 mailbox",
      tenantDomainHint: "company.example",
      mailboxAddress: "tracking-intake@company.example",
      monitoredFolderNames: "Inbox, Forwarded Orders",
      connectionStatus: "Local setup only",
      lastManualRefreshDate: "Never",
      setupNotes: "Placeholder only. Do not enter passwords, tokens, client secrets, or OAuth codes.",
      reviewState: .needsReview,
      tenantIDPlaceholder: "",
      clientIDPlaceholder: "",
      redirectURIPlaceholder: MSALMicrosoft365AuthAdapter.redirectURI,
      requestedScopesSummary: "User.Read, Mail.Read",
      oauthReadinessStatus: "Not reviewed",
      consentAdminNotes: "Local planning only. No OAuth flow runs and no tokens are requested.",
      oauthImplementationPlanStatus: "Not reviewed"
    )
    microsoft365MailboxConnections.insert(connection, at: 0)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 mailbox setup placeholder created.",
      afterDetail: microsoft365MailboxConnectionAuditDetail(connection)
    )
  }

  func updateMicrosoft365MailboxConnection(_ connection: Microsoft365MailboxConnection) {
    guard let index = microsoft365MailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = microsoft365MailboxConnectionAuditDetail(microsoft365MailboxConnections[index])
    microsoft365MailboxConnections[index] = connection
    persistIntegrations()
    logAudit(
      action: .edited,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 mailbox setup placeholder edited.",
      beforeDetail: beforeDetail,
      afterDetail: microsoft365MailboxConnectionAuditDetail(connection)
    )
  }

  func markMicrosoft365MailboxConnectionReadyForReview(_ connection: Microsoft365MailboxConnection) {
    updateMicrosoft365MailboxConnection(connection) { draft in
      draft.connectionStatus = "Ready for review"
      draft.reviewState = .monitor
    }
    logAudit(
      action: .reviewed,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 mailbox setup placeholder marked ready for review.",
      afterDetail: "No OAuth, token, Microsoft Graph, or mailbox connection was used."
    )
  }

  func markMicrosoft365OAuthSetupReviewed(_ connection: Microsoft365MailboxConnection) {
    let summary = microsoft365OAuthReadinessSummary(for: connection)
    updateMicrosoft365MailboxConnection(connection) { draft in
      draft.oauthReadinessStatus = summary.statusText
      draft.reviewState = summary.isReady ? .monitor : .needsReview
    }
    logAudit(
      action: .reviewed,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 OAuth readiness reviewed locally.",
      afterDetail: "\(summary.detailText)\nNo OAuth flow ran, no tokens were requested, and no credentials were stored."
    )
  }

  func addSpaceMailIMAPConnectionPlaceholder() {
    let connection = SpaceMailIMAPConnection(
      displayName: "SpaceMail tracking inbox",
      emailAddressUsername: "tracking@sideways.living",
      imapHost: "imap.spacemail.example",
      imapPort: "993",
      securityMode: "SSL/TLS",
      folderName: "INBOX",
      connectionStatus: "Not connected",
      lastManualRefreshDate: "Never",
      setupNotes: "Local SpaceMail IMAP setup placeholder. Confirm the real IMAP host, folder, mixed-mailbox mode, and Keychain credential before manual refresh.",
      credentialStorageStatus: "Password not stored; Keychain ready",
      mailboxMode: .mixedFiltered,
      importKeywordHints: ["order shipped", "tracking number", "dispatch confirmation"],
      uncertainKeywordHints: ["delivery question", "relates to an order", "tracking number yet"],
      filterKeywordHints: ["newsletter", "promotion", "security alert", "calendar", "final days"],
      reviewState: .needsReview
    )
    spaceMailIMAPConnections.insert(connection, at: 0)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail IMAP setup placeholder created.",
      afterDetail: spaceMailIMAPConnectionAuditDetail(connection)
    )
  }

  func updateSpaceMailIMAPConnection(_ connection: SpaceMailIMAPConnection) {
    guard let index = spaceMailIMAPConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = spaceMailIMAPConnectionAuditDetail(spaceMailIMAPConnections[index])
    spaceMailIMAPConnections[index] = connection
    persistIntegrations()
    logAudit(
      action: .edited,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail IMAP setup placeholder edited.",
      beforeDetail: beforeDetail,
      afterDetail: spaceMailIMAPConnectionAuditDetail(connection)
    )
  }

  func applySpaceMailFilterPreset(_ preset: SpaceMailFilterPreset, to connection: SpaceMailIMAPConnection) {
    let beforeDetail = spaceMailIMAPConnectionAuditDetail(connection)
    let config = spaceMailFilterPresetConfiguration(preset)
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.mailboxMode = .mixedFiltered
      draft.trustedSenderHints = config.trustedSenders
      draft.importKeywordHints = config.importKeywords
      draft.uncertainKeywordHints = config.uncertainKeywords
      draft.filterKeywordHints = config.filterKeywords
      draft.classifierTestSummary = "\(preset.rawValue) preset applied. Run the built-in or custom classifier test to preview behavior before real refresh."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filter preset",
          status: preset.rawValue,
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.lastRefreshFilteredNonOrderCount,
          uncertainCount: draft.lastRefreshUncertainCount,
          summary: "Applied \(preset.rawValue) local hints. No mailbox fetch, import, credential, or mailbox mutation occurred."
        ),
        to: &draft
      )
    }
    if let updated = spaceMailIMAPConnections.first(where: { $0.id == connection.id }) {
      logAudit(
        action: .edited,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "SpaceMail mixed-mailbox filter preset applied.",
        beforeDetail: beforeDetail,
        afterDetail: "\(spaceMailIMAPConnectionAuditDetail(updated))\nPreset: \(preset.rawValue)\nNo mailbox fetch, import, credential, password, auth string, or mailbox mutation occurred."
      )
    }
  }

  func markSpaceMailIMAPConnectionReviewed(_ connection: SpaceMailIMAPConnection) {
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.connectionStatus = "Ready for IMAP planning"
      draft.reviewState = .accepted
    }
    logAudit(
      action: .reviewed,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail IMAP setup placeholder reviewed locally.",
      afterDetail: "No real IMAP connection was made. No password, Keychain item, or mailbox message was accessed."
    )
  }

  func removeSpaceMailIMAPConnection(_ connection: SpaceMailIMAPConnection) {
    guard let index = spaceMailIMAPConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = spaceMailIMAPConnectionAuditDetail(spaceMailIMAPConnections[index])
    spaceMailIMAPConnections.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail IMAP setup placeholder removed.",
      beforeDetail: beforeDetail,
      afterDetail: "No real IMAP connection was made and no mailbox item was changed."
    )
  }

  func addGmailMailboxConnectionPlaceholder() {
    let connection = GmailMailboxConnection(
      displayName: "Gmail order updates",
      emailAddress: "orders@gmail.example",
      monitoredLabelNames: "INBOX, Order Updates",
      connectionStatus: "OAuth not connected",
      lastManualRefreshDate: "Never",
      setupNotes: "Local Gmail setup placeholder. Confirm Google account, labels, mixed-mailbox mode, and future OAuth/token storage before real refresh.",
      oauthReadinessStatus: "Needs Google Cloud OAuth setup",
      requestedScopesSummary: "Future read-only Gmail message scope for manual refresh only",
      credentialStorageStatus: "Token storage not configured",
      mailboxMode: .mixedFiltered,
      reviewState: .needsReview
    )
    gmailMailboxConnections.insert(connection, at: 0)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail mailbox setup placeholder created.",
      afterDetail: gmailMailboxConnectionAuditDetail(connection)
    )
  }

  func updateGmailMailboxConnection(_ connection: GmailMailboxConnection) {
    guard let index = gmailMailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = gmailMailboxConnectionAuditDetail(gmailMailboxConnections[index])
    gmailMailboxConnections[index] = connection
    persistIntegrations()
    logAudit(
      action: .edited,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail mailbox setup placeholder edited.",
      beforeDetail: beforeDetail,
      afterDetail: gmailMailboxConnectionAuditDetail(connection)
    )
  }

  func markGmailMailboxConnectionReviewed(_ connection: GmailMailboxConnection) {
    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Ready for Gmail planning"
      draft.reviewState = .accepted
    }
    logAudit(
      action: .reviewed,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail mailbox setup placeholder reviewed locally.",
      afterDetail: "No OAuth flow, Gmail API call, token, Keychain item, or mailbox message access occurred."
    )
  }

  func importMockGmailMessages(for connection: GmailMailboxConnection) {
    Task { await refreshMockGmailMessages(for: connection) }
  }

  func checkRealGmailReadiness(for connection: GmailMailboxConnection) {
    Task { await refreshRealGmailReadiness(for: connection) }
  }

  func importRealGmailMessages(for connection: GmailMailboxConnection) {
    Task { await refreshRealGmailMessages(for: connection) }
  }

  private func refreshRealGmailReadiness(for connection: GmailMailboxConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)
    let timestamp = Self.auditTimestamp()
    let readiness = gmailOAuthReadinessSummary(for: connection)
    let adapterDetail = GoogleGmailAuthAdapter().setupReadinessDetail(for: connection)
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Gmail readiness check started.",
      afterDetail: "Labels: \(connection.monitoredLabelNames)\nOAuth client ID: \(gmailReadinessPresenceLabel(connection.oauthClientIDPlaceholder))\nCallback scheme: \(gmailReadinessPresenceLabel(connection.redirectURIPlaceholder))\nCompiled app readiness: \(readiness.isReady ? "ready" : "blocked")\nNo Google OAuth flow, token request, Gmail API call, Keychain token access, or mailbox mutation occurred."
    )

    let status: GmailMailboxFetchStatus = readiness.isReady ? .ready : .notConfigured
    let missing = readiness.missingFields
    let detail = readiness.isReady
      ? "Real Gmail setup and compiled callback configuration are ready. Use Test real Google sign-in, then Run real Gmail refresh for the manual read-only API path. This readiness check did not request a token, call Gmail, or access mailbox messages."
      : "Real Gmail setup is incomplete or blocked. Missing or blocked: \(missing.joined(separator: ", ")). This readiness check did not request a token, call Gmail, or access mailbox messages."
    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Real Gmail readiness: \(status.rawValue)"
      draft.oauthReadinessStatus = readiness.statusText
      draft.lastManualRefreshDate = timestamp
      draft.lastRefreshFetchedCount = 0
      draft.lastRefreshImportedCount = 0
      draft.lastRefreshDuplicateCount = 0
      draft.lastRefreshFilteredNonOrderCount = 0
      draft.lastRefreshUncertainCount = 0
      draft.lastRefreshFilteredExamples = []
      draft.lastRefreshUncertainExamples = []
      draft.lastRefreshSummary = "Real Gmail readiness check: \(status.rawValue). \(detail)"
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Gmail readiness check completed.",
      afterDetail: "Status: \(status.rawValue)\nReadiness: \(readiness.statusText)\nFetched: 0\nImported: 0\nDuplicate skips: 0\nLabels: \(connection.monitoredLabelNames)\nMailbox mode: \(connection.mailboxMode.rawValue)\nMissing or blocked setup: \(missing.isEmpty ? "none" : missing.joined(separator: ", "))\nDetail: \(detail)\nAdapter preflight: \(adapterDetail)\nNo Google OAuth flow, token request, Gmail API call, Keychain token access, Gmail API response, raw Gmail message, or mailbox mutation occurred."
    )
  }

  private func gmailReadinessPresenceLabel(_ value: String?) -> String {
    let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "missing" }
    if trimmed.localizedCaseInsensitiveContains("placeholder") { return "placeholder" }
    return "present"
  }

  private func refreshMockGmailMessages(for connection: GmailMailboxConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)
    let timestamp = Self.auditTimestamp()
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Gmail refresh started.",
      afterDetail: "Labels: \(connection.monitoredLabelNames)\nMode: Local mock client boundary only.\nNo OAuth flow, token exchange, Gmail API call, Keychain access, or mailbox mutation occurred."
    )

    let fetchResult = await gmailMailboxClient.fetchMessages(for: connection, sourceMailboxID: mailbox.id)
    let filterResult = filteredGmailMessages(fetchResult.messages, for: connection)
    let result = importFetchedMailboxMessages(filterResult.importMessages)
    let filteredExamples = filterResult.filteredExamples.joined(separator: "; ")
    let uncertainExamples = filterResult.uncertainExamples.joined(separator: "; ")
    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Mock Gmail: \(fetchResult.status.rawValue)"
      draft.lastManualRefreshDate = timestamp
      draft.lastRefreshFetchedCount = fetchResult.messages.count
      draft.lastRefreshImportedCount = result.imported
      draft.lastRefreshDuplicateCount = result.duplicates
      draft.lastRefreshFilteredNonOrderCount = filterResult.filteredCount
      draft.lastRefreshUncertainCount = filterResult.uncertainCount
      draft.lastRefreshFilteredExamples = filterResult.filteredExamples
      draft.lastRefreshUncertainExamples = filterResult.uncertainExamples
      draft.uncertainMessages = Array(filterResult.uncertainMessages.prefix(10))
      draft.filteredMessages = Array(filterResult.filteredMessages.prefix(10))
      draft.lastRefreshSummary = "Mock Gmail refresh: \(fetchResult.messages.count) fetched, \(result.imported) imported, \(result.duplicates) duplicates, \(filterResult.filteredCount) filtered, \(filterResult.uncertainCount) uncertain. Duplicate-safe handling updates existing intake rows where refreshed parsed fields differ. \(fetchResult.detail)"
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Gmail refresh completed.",
      afterDetail: "Status: \(fetchResult.status.rawValue)\nFetched: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nFiltered non-order: \(filterResult.filteredCount)\nUncertain: \(filterResult.uncertainCount)\nLabels: \(connection.monitoredLabelNames)\nMailbox mode: \(connection.mailboxMode.rawValue)\nMode: Local mock client boundary through provider-neutral intake.\nDuplicate handling: duplicate provider message IDs do not create new Inbox rows; existing linked intake rows may be refreshed from newly parsed previews when fields change.\nFilter detail: \(filterResult.detail)\nFiltered examples: \(filteredExamples)\nUncertain examples: \(uncertainExamples)\nClient detail: \(fetchResult.detail)\nNo OAuth flow, token exchange, Gmail API call, Keychain access, or mailbox mutation occurred."
    )
  }

  private func refreshRealGmailMessages(for connection: GmailMailboxConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)
    let timestamp = Self.auditTimestamp()
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Gmail refresh started.",
      afterDetail: "Labels: \(connection.monitoredLabelNames)\nMailbox mode: \(connection.mailboxMode.rawValue)\nMode: Manual read-only Gmail API refresh. ParcelOps may request an in-memory Google access token from the current GoogleSignIn session, but no token value, authorization header, raw Gmail body, full request URL, or mailbox credential is logged or stored. No Gmail message is deleted, moved, marked read, sent, or modified."
    )

    let fetchResult = await realGmailMailboxClient.fetchMessages(for: connection, sourceMailboxID: mailbox.id)
    let filterResult = filteredGmailMessages(fetchResult.messages, for: connection)
    let result = importFetchedMailboxMessages(filterResult.importMessages)
    let filteredExamples = filterResult.filteredExamples.joined(separator: "; ")
    let uncertainExamples = filterResult.uncertainExamples.joined(separator: "; ")

    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Real Gmail: \(fetchResult.status.rawValue)"
      draft.lastManualRefreshDate = timestamp
      draft.lastRefreshFetchedCount = fetchResult.messages.count
      draft.lastRefreshImportedCount = result.imported
      draft.lastRefreshDuplicateCount = result.duplicates
      draft.lastRefreshFilteredNonOrderCount = filterResult.filteredCount
      draft.lastRefreshUncertainCount = filterResult.uncertainCount
      draft.lastRefreshFilteredExamples = filterResult.filteredExamples
      draft.lastRefreshUncertainExamples = filterResult.uncertainExamples
      draft.uncertainMessages = Array(filterResult.uncertainMessages.prefix(10))
      draft.filteredMessages = Array(filterResult.filteredMessages.prefix(10))
      draft.lastRefreshSummary = "Real Gmail refresh: \(fetchResult.messages.count) fetched, \(result.imported) imported, \(result.duplicates) duplicates, \(filterResult.filteredCount) filtered, \(filterResult.uncertainCount) uncertain. Duplicate-safe handling updates existing intake rows where refreshed parsed fields differ. \(fetchResult.detail)"
    }

    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Gmail refresh completed.",
      afterDetail: "Status: \(fetchResult.status.rawValue)\nFetched: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nFiltered non-order: \(filterResult.filteredCount)\nUncertain: \(filterResult.uncertainCount)\nLabels: \(connection.monitoredLabelNames)\nMailbox mode: \(connection.mailboxMode.rawValue)\nMode: Manual read-only Gmail API refresh through provider-neutral intake.\nDuplicate handling: duplicate Gmail message IDs do not create new Inbox rows; existing linked intake rows may be refreshed from newly parsed previews when fields change.\nFilter detail: \(filterResult.detail)\nFiltered examples: \(filteredExamples)\nUncertain examples: \(uncertainExamples)\nClient detail: \(fetchResult.detail)\nNo Google access token, refresh token, auth code, authorization header, full request URL, raw Gmail body, password, client secret, or mailbox credential was logged or stored. No Gmail message was deleted, moved, marked read, sent, or modified."
    )
  }

  func removeGmailMailboxConnection(_ connection: GmailMailboxConnection) {
    guard let index = gmailMailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = gmailMailboxConnectionAuditDetail(gmailMailboxConnections[index])
    gmailMailboxConnections.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail mailbox setup placeholder removed.",
      beforeDetail: beforeDetail,
      afterDetail: "No OAuth flow, Gmail API call, token, Keychain item, or mailbox message was changed."
    )
  }

  func importUncertainGmailMessage(_ uncertainMessage: GmailReviewMessage, for connection: GmailMailboxConnection) {
    let fetchedMessage = FetchedMailboxMessage(
      providerMessageID: uncertainMessage.providerMessageID,
      sender: uncertainMessage.sender,
      subject: uncertainMessage.subject,
      receivedDate: uncertainMessage.receivedDate,
      plainTextBodyPreview: uncertainMessage.bodyPreview,
      sourceMailboxID: uncertainMessage.sourceMailboxID
    )
    let result = importFetchedMailboxMessages([fetchedMessage])
    updateGmailMailboxConnection(connection) { draft in
      var current = draft.uncertainMessages ?? []
      current.removeAll { $0.id == uncertainMessage.id || $0.providerMessageID == uncertainMessage.providerMessageID }
      draft.uncertainMessages = current
      draft.lastRefreshUncertainCount = current.count
      draft.lastRefreshUncertainExamples = current.prefix(5).map { "\($0.subject) (\($0.reason))" }
      draft.lastRefreshSummary = "Gmail uncertain preview imported locally. \(current.count) uncertain Gmail previews remain."
    }
    logAudit(
      action: .created,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Uncertain Gmail message imported into intake locally.",
      afterDetail: "Subject: \(uncertainMessage.subject)\nReason: \(uncertainMessage.reason)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nStored preview only was used. No Gmail API call, OAuth token, mailbox fetch, mailbox mutation, or full message body was logged."
    )
  }

  func dismissUncertainGmailMessage(_ uncertainMessage: GmailReviewMessage, for connection: GmailMailboxConnection) {
    updateGmailMailboxConnection(connection) { draft in
      var current = draft.uncertainMessages ?? []
      current.removeAll { $0.id == uncertainMessage.id || $0.providerMessageID == uncertainMessage.providerMessageID }
      draft.uncertainMessages = current
      draft.lastRefreshUncertainCount = current.count
      draft.lastRefreshUncertainExamples = current.prefix(5).map { "\($0.subject) (\($0.reason))" }
      draft.lastRefreshSummary = "Gmail uncertain preview dismissed locally. \(current.count) uncertain Gmail previews remain."
    }
    logAudit(
      action: .ignored,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Uncertain Gmail message dismissed locally.",
      afterDetail: "Subject: \(uncertainMessage.subject)\nReason: \(uncertainMessage.reason)\nThe message was removed from the local Gmail uncertain review list only. No Gmail API call, OAuth token, mailbox item, or full message body was changed."
    )
  }

  func importFilteredGmailMessage(_ filteredMessage: GmailReviewMessage, for connection: GmailMailboxConnection) {
    let fetchedMessage = FetchedMailboxMessage(
      providerMessageID: filteredMessage.providerMessageID,
      sender: filteredMessage.sender,
      subject: filteredMessage.subject,
      receivedDate: filteredMessage.receivedDate,
      plainTextBodyPreview: filteredMessage.bodyPreview,
      sourceMailboxID: filteredMessage.sourceMailboxID
    )
    let result = importFetchedMailboxMessages([fetchedMessage])
    updateGmailMailboxConnection(connection) { draft in
      var current = draft.filteredMessages ?? []
      current.removeAll { $0.id == filteredMessage.id || $0.providerMessageID == filteredMessage.providerMessageID }
      draft.filteredMessages = current
      draft.lastRefreshFilteredNonOrderCount = current.count
      draft.lastRefreshFilteredExamples = current.prefix(5).map { "\($0.subject) (\($0.reason))" }
      draft.lastRefreshSummary = "Gmail filtered preview imported locally. \(current.count) filtered Gmail previews remain."
    }
    logAudit(
      action: .created,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Filtered Gmail message imported into intake locally.",
      afterDetail: "Subject: \(filteredMessage.subject)\nReason: \(filteredMessage.reason)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nThis was an explicit local operator action from a filtered preview. No Gmail API call, OAuth token, mailbox fetch, mailbox mutation, or full message body was logged."
    )
  }

  func dismissFilteredGmailMessage(_ filteredMessage: GmailReviewMessage, for connection: GmailMailboxConnection) {
    updateGmailMailboxConnection(connection) { draft in
      var current = draft.filteredMessages ?? []
      current.removeAll { $0.id == filteredMessage.id || $0.providerMessageID == filteredMessage.providerMessageID }
      draft.filteredMessages = current
      draft.lastRefreshFilteredNonOrderCount = current.count
      draft.lastRefreshFilteredExamples = current.prefix(5).map { "\($0.subject) (\($0.reason))" }
      draft.lastRefreshSummary = "Gmail filtered preview dismissed locally. \(current.count) filtered Gmail previews remain."
    }
    logAudit(
      action: .ignored,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Filtered Gmail message dismissed locally.",
      afterDetail: "Subject: \(filteredMessage.subject)\nReason: \(filteredMessage.reason)\nThe message was removed from the local Gmail filtered review list only. It was not imported into Inbox, and no Gmail API call, OAuth token, mailbox item, or full message body was changed."
    )
  }

  func createReviewTask(from gmailMessage: GmailReviewMessage, connection: GmailMailboxConnection, reviewQueue: String) {
    let title = gmailMessage.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? connection.displayName : gmailMessage.subject
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: title,
      summary: "Review \(reviewQueue) Gmail preview from \(gmailMessage.sender): \(gmailMessage.reason). Provider message ID: \(gmailMessage.providerMessageID). Use Mailbox Monitor to import true order mail or dismiss local false positives.",
      priority: reviewQueue.localizedCaseInsensitiveContains("uncertain") ? .normal : .low,
      assignee: "Mailbox team"
    )
    logAudit(
      action: .created,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Review task created from \(reviewQueue) Gmail preview.",
      afterDetail: "Subject: \(gmailMessage.subject)\nReason: \(gmailMessage.reason)\nLinked provider message ID: \(gmailMessage.providerMessageID)\nThe task was created from the stored safe preview only. No Gmail API call, OAuth token, mailbox fetch, mailbox mutation, or full message body was logged."
    )
  }

  func testGmailAmbiguousClassifier(for connection: GmailMailboxConnection) {
    let sample = FetchedMailboxMessage(
      providerMessageID: "gmail-local-classifier-\(connection.id.uuidString)",
      sender: connection.emailAddress,
      subject: "Delivery question",
      receivedDate: Self.auditTimestamp(),
      plainTextBodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
      sourceMailboxID: trackedMailbox(for: connection).id
    )
    evaluateGmailClassifierSample(sample, for: connection, sampleName: "Ambiguous delivery question")
  }

  func testGmailCustomClassifier(for connection: GmailMailboxConnection, sender: String, subject: String, preview: String) {
    let sample = FetchedMailboxMessage(
      providerMessageID: "gmail-local-custom-classifier-\(connection.id.uuidString)",
      sender: safeAuditPreview(sender.isEmpty ? connection.emailAddress : sender, limit: 120),
      subject: safeAuditPreview(subject.isEmpty ? "No subject" : subject, limit: 160),
      receivedDate: Self.auditTimestamp(),
      plainTextBodyPreview: safeAuditPreview(preview, limit: 280),
      sourceMailboxID: trackedMailbox(for: connection).id
    )
    evaluateGmailClassifierSample(sample, for: connection, sampleName: "Custom Gmail classifier test")
  }

  func runGmailClassifierTestSuite(for connection: GmailMailboxConnection) {
    let mailboxID = trackedMailbox(for: connection).id
    let samples: [(String, String, FetchedMailboxMessage)] = [
      (
        "Clear shipped order",
        "Imported",
        FetchedMailboxMessage(
          providerMessageID: "gmail-suite-order-\(connection.id.uuidString)",
          sender: "orders@example-shop.test",
          subject: "Order TEST-123 shipped tracking ABC123",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123 to Melbourne.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Ambiguous delivery question",
        "Uncertain",
        FetchedMailboxMessage(
          providerMessageID: "gmail-suite-question-\(connection.id.uuidString)",
          sender: "customer@example.com",
          subject: "Delivery question",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Marketing offer",
        "Filtered",
        FetchedMailboxMessage(
          providerMessageID: "gmail-suite-marketing-\(connection.id.uuidString)",
          sender: "offers@example-shop.test",
          subject: "Final days for free delivery",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Final days to get free delivery on your next purchase. Unsubscribe here.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Security notification",
        "Filtered",
        FetchedMailboxMessage(
          providerMessageID: "gmail-suite-security-\(connection.id.uuidString)",
          sender: "security@example.com",
          subject: "Security notification",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "A sign-in notification was generated for this account. This is not an order update.",
          sourceMailboxID: mailboxID
        )
      )
    ]
    let results = samples.map { gmailClassifierTestResult(name: $0.0, message: $0.2, expectedDecision: $0.1) }
    let passed = results.filter { $0.decisionStatus.localizedCaseInsensitiveContains("passed") }.count
    let summary = "Gmail classifier suite: \(passed)/\(results.count) local expectations passed. No Gmail API call, OAuth flow, token request, mailbox fetch, or Inbox import occurred."
    updateGmailMailboxConnection(connection) { draft in
      draft.classifierTestSummary = summary
      draft.classifierTestResults = results
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail classifier test suite ran locally.",
      afterDetail: "\(summary)\n\(results.map { "\($0.sampleName): \($0.decision), \($0.reason), \($0.decisionStatus), order \($0.detectedOrderNumber), tracking \($0.detectedTrackingNumber)" }.joined(separator: "\n"))\nNo Gmail API call, OAuth token, mailbox mutation, external service call, or full message body logging occurred."
    )
  }

  private func evaluateGmailClassifierSample(_ sample: FetchedMailboxMessage, for connection: GmailMailboxConnection, sampleName: String) {
    let result = gmailClassifierTestResult(name: sampleName, message: sample, expectedDecision: "No expected decision")
    updateGmailMailboxConnection(connection) { draft in
      draft.classifierTestSummary = "\(sampleName): \(result.decision). \(result.reason). Order \(result.detectedOrderNumber), tracking \(result.detectedTrackingNumber). No Gmail API call, mailbox fetch, or import occurred."
      draft.classifierTestResults = [result]
      if result.decision == "Uncertain" {
        var current = draft.uncertainMessages ?? []
        current.removeAll { $0.providerMessageID == sample.providerMessageID }
        current.insert(
          GmailReviewMessage(
            providerMessageID: sample.providerMessageID,
            sourceMailboxID: sample.sourceMailboxID,
            sender: sample.sender,
            subject: sample.subject,
            receivedDate: sample.receivedDate,
            bodyPreview: sample.plainTextBodyPreview,
            reason: result.reason,
            capturedDate: Self.auditTimestamp()
          ),
          at: 0
        )
        draft.uncertainMessages = current
        draft.lastRefreshUncertainCount = current.count
        draft.lastRefreshUncertainExamples = current.prefix(5).map { "\($0.subject) (\($0.reason))" }
      }
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail classifier sample tested locally.",
      afterDetail: "Subject: \(result.subjectPreview)\nDecision: \(result.decision)\nReason: \(result.reason)\nDetected order: \(result.detectedOrderNumber)\nDetected tracking: \(result.detectedTrackingNumber)\nNo Gmail API call, OAuth token, mailbox fetch, mailbox mutation, or full message body was logged."
    )
  }

  private func gmailClassifierTestResult(name: String, message: FetchedMailboxMessage, expectedDecision: String) -> GmailClassifierTestResult {
    let relevance = classifyGmailMessageRelevance(message)
    return GmailClassifierTestResult(
      sampleName: name,
      decision: relevance.decision,
      reason: relevance.reason,
      score: relevance.score,
      subjectPreview: safeAuditPreview(message.subject, limit: 120),
      detectedOrderNumber: relevance.orderNumber,
      detectedTrackingNumber: relevance.trackingNumber,
      expectedDecision: expectedDecision,
      decisionStatus: expectedDecision == "No expected decision"
        ? "No classifier expectation"
        : relevance.decision.normalizedValidationKey == expectedDecision.normalizedValidationKey
          ? "Classifier passed: expected \(expectedDecision)"
          : "Classifier needs review: expected \(expectedDecision), got \(relevance.decision)"
    )
  }

  func markGmailOAuthImplementationPlanReviewed(_ connection: GmailMailboxConnection) {
    let plan = gmailOAuthImplementationPlan(for: connection)
    updateGmailMailboxConnection(connection) { draft in
      draft.oauthReadinessStatus = plan.statusText
      draft.reviewState = plan.completedCount == plan.totalCount ? .monitor : .needsReview
    }
    logAudit(
      action: .reviewed,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Gmail OAuth implementation plan reviewed locally.",
      afterDetail: gmailOAuthImplementationPlanAuditDetail(plan)
    )
  }

  func createReviewTaskFromGmailOAuthPlan(_ connection: GmailMailboxConnection) {
    let plan = gmailOAuthImplementationPlan(for: connection)
    let readiness = gmailOAuthReadinessSummary(for: connection)
    let blockers = readiness.missingFields.isEmpty ? "No current readiness blockers." : "Current readiness blockers: \(readiness.missingFields.joined(separator: ", "))."
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: "\(connection.displayName) Gmail config handoff",
      summary: "Review Gmail setup before real sign-in. \(plan.statusText). \(readiness.statusText). \(blockers) Compiled client: \(readiness.compiledClientIDStatus). Compiled callback: \(readiness.compiledCallbackSchemeStatus).",
      priority: readiness.isReady && plan.completedCount == plan.totalCount ? .normal : .high,
      assignee: "Operations"
    )
    logAudit(
      action: .created,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Review task created from Gmail setup handoff.",
      afterDetail: "\(gmailOAuthImplementationPlanAuditDetail(plan))\nReadiness: \(readiness.statusText)\nMissing or blocked setup: \(readiness.missingFields.isEmpty ? "none" : readiness.missingFields.joined(separator: ", "))\nExpected callback scheme: \(readiness.expectedCallbackScheme)\nCompiled client ID status: \(readiness.compiledClientIDStatus)\nCompiled callback scheme status: \(readiness.compiledCallbackSchemeStatus)\nNo Google sign-in, token request, Gmail API call, Keychain token access, mailbox fetch, or mailbox mutation occurred."
    )
  }

  func gmailAuthSessionState(for connection: GmailMailboxConnection) -> GmailAuthSessionState {
    gmailAuthSessionStates[connection.id] ?? GmailAuthSessionState(
      connectionID: connection.id,
      status: .notConnected,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: "Never",
      lastSuccessfulAuthDate: "Never",
      tokenStoreStatus: "Token storage not configured",
      tokenStoreDetail: "Gmail token storage is not implemented. ParcelOps does not create, read, write, delete, store, or log Google access tokens or refresh tokens.",
      detailText: "Gmail is not connected for this setup record. Mock auth can test UI states, but real Google sign-in and Gmail API access are not implemented."
    )
  }

  func connectGmailAuthMock(_ connection: GmailMailboxConnection) {
    let previousState = gmailAuthSessionState(for: connection)
    let startedState = GmailAuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: Self.auditTimestamp(),
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      tokenStoreStatus: previousState.tokenStoreStatus,
      tokenStoreDetail: previousState.tokenStoreDetail,
      detailText: "Mock Gmail auth started locally. No Google sign-in opened and no token request was made."
    )
    gmailAuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Gmail auth started.",
      afterDetail: gmailAuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await gmailAuthClient.connect(connection: connection)
      await MainActor.run {
        applyGmailAuthResult(result, to: connection)
      }
    }
  }

  func testRealGmailSignIn(_ connection: GmailMailboxConnection) {
    let previousState = gmailAuthSessionState(for: connection)
    let timestamp = Self.auditTimestamp()
    let startedState = GmailAuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: timestamp,
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      tokenStoreStatus: previousState.tokenStoreStatus,
      tokenStoreDetail: previousState.tokenStoreDetail,
      detailText: "Real Gmail sign-in test started. A browser sign-in may open, but ParcelOps will not store token values in JSON and will not fetch Gmail messages."
    )
    gmailAuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Gmail sign-in test started.",
      afterDetail: gmailAuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await realGmailAuthClient.connect(connection: connection)
      await MainActor.run {
        applyRealGmailAuthResult(result, to: connection)
      }
    }
  }

  private func applyRealGmailAuthResult(_ result: GmailAuthResult, to connection: GmailMailboxConnection) {
    let timestamp = Self.auditTimestamp()
    let previousState = gmailAuthSessionState(for: connection)
    let tokenStatus = connection.credentialStorageStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "Token storage not configured"
      : connection.credentialStorageStatus
    let state = GmailAuthSessionState(
      connectionID: connection.id,
      status: result.status,
      signedInAccount: result.signedInAccount,
      lastAuthAttemptDate: timestamp,
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      tokenStoreStatus: tokenStatus,
      tokenStoreDetail: result.status == .connected
        ? "GoogleSignIn completed sign-in and may manage its own token cache. ParcelOps did not write token values to JSON, custom Keychain storage, or audit logs."
        : "Real Gmail sign-in did not produce a connected session in ParcelOps. No Google token values were stored in JSON, custom Keychain storage, or audit logs.",
      detailText: result.detailText
    )
    gmailAuthSessionStates[connection.id] = state
    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Real Gmail sign-in: \(result.status.rawValue)"
      draft.credentialStorageStatus = result.status == .connected ? "GoogleSignIn token cache managed by SDK" : draft.credentialStorageStatus
      draft.oauthReadinessStatus = result.status == .connected ? "Real Gmail sign-in completed" : result.status.rawValue
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: result.status == .connected ? "Real Gmail sign-in succeeded." : "Real Gmail sign-in did not connect.",
      afterDetail: gmailAuthSessionAuditDetail(state)
    )
  }

  func simulateGmailAuthFailure(_ connection: GmailMailboxConnection) {
    let previousState = gmailAuthSessionState(for: connection)
    let startedState = GmailAuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: Self.auditTimestamp(),
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      tokenStoreStatus: previousState.tokenStoreStatus,
      tokenStoreDetail: previousState.tokenStoreDetail,
      detailText: "Mock Gmail auth failure test started locally. No Google sign-in opened and no token request was made."
    )
    gmailAuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Gmail auth started.",
      afterDetail: gmailAuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await gmailAuthClient.simulateFailure(connection: connection)
      await MainActor.run {
        applyGmailAuthResult(result, to: connection)
      }
    }
  }

  private func applyGmailAuthResult(_ result: GmailAuthResult, to connection: GmailMailboxConnection) {
    let timestamp = Self.auditTimestamp()
    let state = GmailAuthSessionState(
      connectionID: connection.id,
      status: result.status,
      signedInAccount: result.signedInAccount,
      lastAuthAttemptDate: timestamp,
      lastSuccessfulAuthDate: result.status == .connected ? timestamp : gmailAuthSessionState(for: connection).lastSuccessfulAuthDate,
      tokenStoreStatus: result.status == .connected ? "Mock token reference available" : "Token storage not configured",
      tokenStoreDetail: result.status == .connected
        ? "Mock Gmail auth completed. No Google token value was requested, returned, stored, or logged."
        : "Gmail token storage is not configured. No token value was requested, returned, stored, or logged.",
      detailText: result.detailText
    )
    gmailAuthSessionStates[connection.id] = state
    updateGmailMailboxConnection(connection) { draft in
      draft.connectionStatus = "Mock Gmail auth: \(result.status.rawValue)"
      draft.credentialStorageStatus = state.tokenStoreStatus
      draft.oauthReadinessStatus = result.status == .connected ? "Mock Gmail auth connected" : result.status.rawValue
    }
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: result.status == .connected ? "Mock Gmail auth succeeded." : "Mock Gmail auth did not connect.",
      afterDetail: gmailAuthSessionAuditDetail(state)
    )
  }

  func simulateGmailTokenStoreReady(_ connection: GmailMailboxConnection) {
    Task {
      let result = await gmailTokenStore.simulateReady(for: connection)
      applyGmailTokenStoreResult(result, to: connection, summary: "Mock Gmail token store marked ready.")
    }
  }

  func simulateGmailTokenMissing(_ connection: GmailMailboxConnection) {
    Task {
      let result = await gmailTokenStore.simulateMissing(for: connection)
      applyGmailTokenStoreResult(result, to: connection, summary: "Mock Gmail token reference marked missing.")
    }
  }

  func simulateGmailTokenStorageError(_ connection: GmailMailboxConnection) {
    Task {
      let result = await gmailTokenStore.simulateStorageError(for: connection)
      applyGmailTokenStoreResult(result, to: connection, summary: "Mock Gmail token storage error simulated.")
    }
  }

  func simulateGmailTokenClear(_ connection: GmailMailboxConnection) {
    Task {
      let result = await gmailTokenStore.simulateClear(for: connection)
      applyGmailTokenStoreResult(result, to: connection, summary: "Mock Gmail token reference clear simulated.")
    }
  }

  private func applyGmailTokenStoreResult(_ result: GmailTokenStoreResult, to connection: GmailMailboxConnection, summary: String) {
    let previousState = gmailAuthSessionState(for: connection)
    let state = GmailAuthSessionState(
      connectionID: connection.id,
      status: previousState.status,
      signedInAccount: previousState.signedInAccount,
      lastAuthAttemptDate: previousState.lastAuthAttemptDate,
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      tokenStoreStatus: result.status.rawValue,
      tokenStoreDetail: result.detailText,
      detailText: previousState.detailText
    )
    gmailAuthSessionStates[connection.id] = state
    updateGmailMailboxConnection(connection) { draft in
      draft.credentialStorageStatus = result.status.rawValue
    }

    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: summary,
      afterDetail: gmailTokenStoreAuditDetail(state)
    )
  }

  func importMockSpaceMailIMAPMessages(for connection: SpaceMailIMAPConnection) {
    Task { await refreshMockSpaceMailIMAPMessages(for: connection) }
  }

  func importRealSpaceMailIMAPMessages(for connection: SpaceMailIMAPConnection) {
    Task { await refreshRealSpaceMailIMAPMessages(for: connection) }
  }

  func importUncertainSpaceMailMessage(_ uncertainMessage: SpaceMailUncertainMessage, for connection: SpaceMailIMAPConnection) {
    let fetchedMessage = FetchedMailboxMessage(
      providerMessageID: uncertainMessage.providerMessageID,
      sender: uncertainMessage.sender,
      subject: uncertainMessage.subject,
      receivedDate: uncertainMessage.receivedDate,
      plainTextBodyPreview: uncertainMessage.bodyPreview,
      sourceMailboxID: uncertainMessage.sourceMailboxID
    )
    let result = importFetchedMailboxMessages([fetchedMessage])
    removeUncertainSpaceMailMessage(uncertainMessage, from: connection)
    updateSpaceMailIMAPConnection(connection) { draft in
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Uncertain import",
          status: result.imported > 0 ? "Imported to Inbox" : "Duplicate skipped",
          fetchedCount: 0,
          importedCount: result.imported,
          duplicateCount: result.duplicates,
          filteredNonOrderCount: draft.lastRefreshFilteredNonOrderCount,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Imported an uncertain preview into intake locally. \(draft.uncertainMessages.count) uncertain messages remain."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .created,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Uncertain SpaceMail message imported into intake locally.",
      afterDetail: "Subject: \(uncertainMessage.subject)\nReason: \(uncertainMessage.reason)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nStored preview only was used. No mailbox fetch, mailbox mutation, password, auth string, or full message body was logged."
    )
  }

  func importFilteredSpaceMailMessage(_ filteredMessage: SpaceMailFilteredMessage, for connection: SpaceMailIMAPConnection) {
    let fetchedMessage = FetchedMailboxMessage(
      providerMessageID: filteredMessage.providerMessageID,
      sender: filteredMessage.sender,
      subject: filteredMessage.subject,
      receivedDate: filteredMessage.receivedDate,
      plainTextBodyPreview: filteredMessage.bodyPreview,
      sourceMailboxID: filteredMessage.sourceMailboxID
    )
    let result = importFetchedMailboxMessages([fetchedMessage])
    removeFilteredSpaceMailMessage(filteredMessage, from: connection)
    updateSpaceMailIMAPConnection(connection) { draft in
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filtered import",
          status: result.imported > 0 ? "Imported to Inbox" : "Duplicate skipped",
          fetchedCount: 0,
          importedCount: result.imported,
          duplicateCount: result.duplicates,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Imported a filtered preview into intake locally. \(draft.filteredMessages.count) filtered previews remain."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .created,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Filtered SpaceMail message imported into intake locally.",
      afterDetail: "Subject: \(filteredMessage.subject)\nReason: \(filteredMessage.reason)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nStored preview only was used. No mailbox fetch, mailbox mutation, password, auth string, or full message body was logged."
    )
  }

  func createReviewTask(from uncertainMessage: SpaceMailUncertainMessage, connection: SpaceMailIMAPConnection) {
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: uncertainMessage.subject.isEmpty ? connection.displayName : uncertainMessage.subject,
      summary: "Review uncertain SpaceMail preview from \(uncertainMessage.sender): \(uncertainMessage.reason)",
      priority: .normal,
      assignee: "Mailbox team"
    )
  }

  func createReviewTasksForAllUncertainSpaceMailMessages(for connection: SpaceMailIMAPConnection) {
    guard let current = spaceMailIMAPConnections.first(where: { $0.id == connection.id }) else { return }
    let pending = current.uncertainMessages
    guard !pending.isEmpty else {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "No uncertain SpaceMail previews needed task creation.",
        afterDetail: "The local uncertain review queue is empty. No mailbox fetch, Inbox import, task creation, or mailbox mutation occurred."
      )
      return
    }

    var createdCount = 0
    var skippedCount = 0
    for message in pending {
      let hasExistingOpenTask = reviewTasks.contains { task in
        task.status != .completed
          && task.linkedEntityType == .integration
          && task.linkedEntityID == connection.id.uuidString
          && task.summary.localizedCaseInsensitiveContains(message.providerMessageID)
      }
      if hasExistingOpenTask {
        skippedCount += 1
        continue
      }

      let label = message.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? connection.displayName : message.subject
      let task = ReviewTask(
        title: "Follow up uncertain SpaceMail: \(safeAuditPreview(label, limit: 80))",
        summary: "Review uncertain SpaceMail preview from \(safeAuditPreview(message.sender, limit: 120)). Reason: \(message.reason). Provider message ID: \(message.providerMessageID). Import only if this is real order work; otherwise dismiss locally.",
        linkedEntityType: .integration,
        linkedEntityID: connection.id.uuidString,
        priority: .normal,
        dueDate: "Tomorrow",
        assignee: "Mailbox team",
        status: .open,
        createdDate: Self.auditTimestamp(),
        completedDate: nil,
        reviewState: .needsReview
      )
      addReviewTask(task, summary: "Review task created from uncertain SpaceMail preview.")
      createdCount += 1
    }

    updateSpaceMailIMAPConnection(connection) { draft in
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Uncertain task batch",
          status: createdCount > 0 ? "Tasks created" : "No new tasks",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: skippedCount,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Created \(createdCount) review task\(createdCount == 1 ? "" : "s") from uncertain previews. Skipped \(skippedCount) preview\(skippedCount == 1 ? "" : "s") with existing open tasks."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .created,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Review tasks created from uncertain SpaceMail previews.",
      afterDetail: "Created: \(createdCount)\nSkipped existing open task: \(skippedCount)\nPending uncertain previews: \(pending.count)\nNo mailbox fetch, Inbox import, duplicate metadata change, password, auth string, or mailbox mutation occurred."
    )
  }

  func createReviewTask(from filteredMessage: SpaceMailFilteredMessage, connection: SpaceMailIMAPConnection) {
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: filteredMessage.subject.isEmpty ? connection.displayName : filteredMessage.subject,
      summary: "Review filtered SpaceMail preview from \(filteredMessage.sender): \(filteredMessage.reason)",
      priority: .low,
      assignee: "Mailbox team"
    )
  }

  func createDraftMessage(from uncertainMessage: SpaceMailUncertainMessage, connection: SpaceMailIMAPConnection) {
    createDraftMessage(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: uncertainMessage.subject.isEmpty ? connection.displayName : uncertainMessage.subject,
      recipient: uncertainMessage.sender.isEmpty ? "operations@parcelops.example" : uncertainMessage.sender
    )
  }

  func createDraftMessage(from filteredMessage: SpaceMailFilteredMessage, connection: SpaceMailIMAPConnection) {
    createDraftMessage(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: filteredMessage.subject.isEmpty ? connection.displayName : filteredMessage.subject,
      recipient: filteredMessage.sender.isEmpty ? "operations@parcelops.example" : filteredMessage.sender
    )
  }

  func createSpaceMailShiftHandoffNote(for connection: SpaceMailIMAPConnection) {
    let summary = spaceMailShiftHandoffSummary
    let detail = spaceMailShiftHandoffDetail(for: connection, summary: summary)
    let note = HandoffNote(
      title: "SpaceMail shift handoff - \(connection.displayName)",
      summary: summary.detail,
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      priority: spaceMailHandoffPriority(for: summary.tone),
      assignee: "Mailbox team",
      createdDate: Self.auditTimestamp(),
      dueDate: "Next shift",
      status: .open,
      reviewState: .needsReview,
      notes: detail
    )

    handoffNotes.insert(note, at: 0)
    persistHandoffNotes()
    logAudit(
      action: .created,
      entityType: .handoffNote,
      entityID: note.id.uuidString,
      entityLabel: note.title,
      summary: "SpaceMail shift handoff note created locally.",
      afterDetail: "\(detail)\nNo mailbox fetch, mailbox mutation, password read, external service call, or parser change occurred."
    )
    logAudit(
      action: .linked,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail shift summary linked to a handoff note.",
      afterDetail: "Handoff note: \(note.title)\n\(detail)"
    )
  }

  func createSpaceMailShiftReviewTask(for connection: SpaceMailIMAPConnection) {
    let summary = spaceMailShiftHandoffSummary
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: "SpaceMail shift summary",
      summary: "\(summary.title): \(summary.detail) \(summary.lastRefreshText)",
      priority: spaceMailHandoffPriority(for: summary.tone),
      assignee: "Mailbox team"
    )
    logAudit(
      action: .linked,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail shift summary review task created locally.",
      afterDetail: "\(spaceMailShiftHandoffDetail(for: connection, summary: summary))\nNo mailbox fetch, mailbox mutation, password read, external service call, or parser change occurred."
    )
  }

  func createSpaceMailParserQAReviewTask(for connection: SpaceMailIMAPConnection) {
    let parserChecks = connection.classifierTestResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
    let parserFailures = parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
    let extractedIDs = connection.classifierTestResults.filter {
      !$0.detectedOrderNumber.isPlaceholderValidationValue || !$0.detectedTrackingNumber.isPlaceholderValidationValue
    }
    let priority: TaskPriority = parserFailures.isEmpty && !parserChecks.isEmpty ? .normal : .high
    let label = parserChecks.isEmpty ? "Run SpaceMail parser QA" : "Review SpaceMail parser QA"
    let summary: String
    if parserChecks.isEmpty {
      summary = "Run the parser/classifier suite for \(connection.displayName) before relying on live SpaceMail order and tracking extraction."
    } else if parserFailures.isEmpty {
      summary = "Review SpaceMail parser QA evidence for \(connection.displayName). \(parserChecks.count) parser expectations passed and \(extractedIDs.count) sample ID extraction result\(extractedIDs.count == 1 ? "" : "s") exist."
    } else {
      let examples = parserFailures.prefix(3).map { "\($0.sampleName): \($0.parserStatus)" }.joined(separator: "; ")
      summary = "Review SpaceMail parser QA failures for \(connection.displayName). \(parserFailures.count) parser expectation\(parserFailures.count == 1 ? "" : "s") need review. \(examples)"
    }

    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: label,
      summary: summary,
      priority: priority,
      assignee: "Mailbox team"
    )
    logAudit(
      action: .linked,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail parser QA review task created locally.",
      afterDetail: "Parser checks: \(parserChecks.count)\nParser failures: \(parserFailures.count)\nExtracted ID samples: \(extractedIDs.count)\nTask summary: \(summary)\nNo mailbox fetch, mailbox mutation, password read, external service call, parser rule change, or full body logging occurred."
    )
  }

  private func spaceMailHandoffPriority(for tone: String) -> TaskPriority {
    switch tone {
    case "warning":
      return .high
    case "attention":
      return .normal
    case "success":
      return .low
    default:
      return .normal
    }
  }

  private func spaceMailShiftHandoffDetail(for connection: SpaceMailIMAPConnection, summary: SpaceMailShiftHandoffSummary) -> String {
    let metrics = summary.keyCounts.map { "\($0.title): \($0.value)" }.joined(separator: ", ")
    let lines = summary.handoffLines.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")
    return """
    Connection: \(connection.displayName)
    Mailbox: \(connection.emailAddressUsername)
    Mode: \(connection.mailboxMode.rawValue)
    Last refresh: \(connection.lastManualRefreshDate)
    Last refresh result: \(connection.lastRefreshSummary.isEmpty ? connection.connectionStatus : connection.lastRefreshSummary)
    Handoff status: \(summary.title)
    Handoff detail: \(summary.detail)
    Latest refresh note: \(summary.lastRefreshText)
    Counts: \(metrics)
    Handoff checks:
    \(lines)
    """
  }

  func dismissUncertainSpaceMailMessage(_ uncertainMessage: SpaceMailUncertainMessage, for connection: SpaceMailIMAPConnection) {
    removeUncertainSpaceMailMessage(uncertainMessage, from: connection)
    updateSpaceMailIMAPConnection(connection) { draft in
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Uncertain dismiss",
          status: "Dismissed locally",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.lastRefreshFilteredNonOrderCount,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Dismissed one uncertain preview locally. \(draft.uncertainMessages.count) uncertain messages remain."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .ignored,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Uncertain SpaceMail message dismissed locally.",
      afterDetail: "Subject: \(uncertainMessage.subject)\nReason: \(uncertainMessage.reason)\nThe message was removed from the local uncertain review list only. No mailbox item was deleted, moved, marked read, flagged, sent, or modified."
    )
  }

  func dismissFilteredSpaceMailMessage(_ filteredMessage: SpaceMailFilteredMessage, for connection: SpaceMailIMAPConnection) {
    removeFilteredSpaceMailMessage(filteredMessage, from: connection)
    updateSpaceMailIMAPConnection(connection) { draft in
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filtered dismiss",
          status: "Dismissed locally",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Dismissed one filtered preview locally. \(draft.filteredMessages.count) filtered previews remain."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .ignored,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Filtered SpaceMail message dismissed locally.",
      afterDetail: "Subject: \(filteredMessage.subject)\nReason: \(filteredMessage.reason)\nThe message was removed from the local filtered preview list only. No mailbox item was deleted, moved, marked read, flagged, sent, or modified."
    )
  }

  func promoteFilteredSpaceMailMessageToUncertain(_ filteredMessage: SpaceMailFilteredMessage, for connection: SpaceMailIMAPConnection) {
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.filteredMessages.removeAll { $0.id == filteredMessage.id || $0.providerMessageID == filteredMessage.providerMessageID }
      if !draft.uncertainMessages.contains(where: { $0.providerMessageID == filteredMessage.providerMessageID }) {
        draft.uncertainMessages.insert(
          SpaceMailUncertainMessage(
            providerMessageID: filteredMessage.providerMessageID,
            sourceMailboxID: filteredMessage.sourceMailboxID,
            sender: filteredMessage.sender,
            subject: filteredMessage.subject,
            receivedDate: filteredMessage.receivedDate,
            bodyPreview: filteredMessage.bodyPreview,
            reason: "Promoted from filtered review: \(filteredMessage.reason)",
            capturedDate: Self.auditTimestamp()
          ),
          at: 0
        )
      }
      draft.lastRefreshFilteredNonOrderCount = draft.filteredMessages.count
      draft.lastRefreshUncertainCount = draft.uncertainMessages.count
      draft.lastRefreshSummary = "Filtered preview moved to uncertain review locally. \(draft.uncertainMessages.count) uncertain and \(draft.filteredMessages.count) filtered previews remain."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filtered promote",
          status: "Moved to uncertain",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Moved filtered preview '\(safeAuditPreview(filteredMessage.subject, limit: 80))' into uncertain review. Source reason: \(filteredMessage.reason)."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .edited,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Filtered SpaceMail preview moved to uncertain review.",
      afterDetail: "Subject: \(filteredMessage.subject)\nSource reason: \(filteredMessage.reason)\nThe preview moved between local review queues only. It was not imported into Inbox, duplicate metadata was preserved, and no mailbox item was deleted, moved, marked read, flagged, sent, or modified."
    )
  }

  func dismissAllUncertainSpaceMailMessages(for connection: SpaceMailIMAPConnection) {
    guard let current = spaceMailIMAPConnections.first(where: { $0.id == connection.id }), !current.uncertainMessages.isEmpty else { return }
    let dismissedCount = current.uncertainMessages.count
    let exampleSubjects = current.uncertainMessages.prefix(3).map { safeAuditPreview($0.subject, limit: 80) }
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.uncertainMessages = []
      draft.lastRefreshUncertainCount = 0
      draft.lastRefreshSummary = "All uncertain SpaceMail previews dismissed locally. Filtered previews remain available for spot review."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Uncertain dismiss all",
          status: "Dismissed locally",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: 0,
          summary: "Dismissed \(dismissedCount) uncertain preview\(dismissedCount == 1 ? "" : "s") from local review."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .ignored,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "All uncertain SpaceMail previews dismissed locally.",
      afterDetail: "Dismissed: \(dismissedCount)\nExamples: \(exampleSubjects.joined(separator: "; "))\nOnly the local uncertain review queue was cleared. No intake email was deleted, duplicate metadata was changed, or mailbox item was modified."
    )
  }

  func dismissAllFilteredSpaceMailMessages(for connection: SpaceMailIMAPConnection) {
    guard let current = spaceMailIMAPConnections.first(where: { $0.id == connection.id }), !current.filteredMessages.isEmpty else { return }
    let dismissedCount = current.filteredMessages.count
    let exampleSubjects = current.filteredMessages.prefix(3).map { safeAuditPreview($0.subject, limit: 80) }
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.filteredMessages = []
      draft.lastRefreshFilteredNonOrderCount = 0
      draft.lastRefreshSummary = "All filtered SpaceMail previews dismissed locally. Uncertain previews remain available for review."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filtered dismiss all",
          status: "Dismissed locally",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: 0,
          uncertainCount: draft.uncertainMessages.count,
          summary: "Dismissed \(dismissedCount) filtered preview\(dismissedCount == 1 ? "" : "s") from local review."
        ),
        to: &draft
      )
    }
    logAudit(
      action: .ignored,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "All filtered SpaceMail previews dismissed locally.",
      afterDetail: "Dismissed: \(dismissedCount)\nExamples: \(exampleSubjects.joined(separator: "; "))\nOnly the local filtered preview queue was cleared. No intake email was deleted, duplicate metadata was changed, or mailbox item was modified."
    )
  }

  func addSpaceMailHintFromUncertain(_ uncertainMessage: SpaceMailUncertainMessage, target: SpaceMailHintTarget, for connection: SpaceMailIMAPConnection) {
    addSpaceMailHint(
      target: target,
      sender: uncertainMessage.sender,
      subject: uncertainMessage.subject,
      bodyPreview: uncertainMessage.bodyPreview,
      sourceReason: uncertainMessage.reason,
      connection: connection
    )
  }

  func addSpaceMailHintFromFiltered(_ filteredMessage: SpaceMailFilteredMessage, target: SpaceMailHintTarget, for connection: SpaceMailIMAPConnection) {
    addSpaceMailHint(
      target: target,
      sender: filteredMessage.sender,
      subject: filteredMessage.subject,
      bodyPreview: filteredMessage.bodyPreview,
      sourceReason: filteredMessage.reason,
      connection: connection
    )
  }

  func testSpaceMailAmbiguousClassifier(for connection: SpaceMailIMAPConnection) {
    let sample = FetchedMailboxMessage(
      providerMessageID: "local-classifier-test-\(connection.id.uuidString)",
      sender: connection.emailAddressUsername,
      subject: "Delivery question",
      receivedDate: Self.auditTimestamp(),
      plainTextBodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
      sourceMailboxID: trackedMailbox(for: connection).id
    )
    evaluateSpaceMailClassifierSample(
      sample,
      for: connection,
      eventType: "Classifier test",
      auditSummary: "SpaceMail mixed-mailbox classifier sample tested locally."
    )
  }

  func addSpaceMailDemoUncertainMessage(for connection: SpaceMailIMAPConnection) {
    let timestamp = Self.auditTimestamp()
    let sample = SpaceMailUncertainMessage(
      providerMessageID: "local-demo-uncertain-\(connection.id.uuidString)",
      sourceMailboxID: trackedMailbox(for: connection).id,
      sender: "customer@example.com",
      subject: "Delivery question",
      receivedDate: timestamp,
      bodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
      reason: "Demo uncertain preview for local review testing",
      capturedDate: timestamp
    )
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.uncertainMessages.removeAll { $0.providerMessageID == sample.providerMessageID }
      draft.uncertainMessages.insert(sample, at: 0)
      draft.lastRefreshUncertainCount = draft.uncertainMessages.count
      draft.lastRefreshUncertainExamples = ["\(sample.subject) (\(sample.reason))"]
      draft.lastRefreshSummary = "Demo uncertain SpaceMail preview added locally. No mailbox fetch, import, or mailbox mutation occurred."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: timestamp,
          eventType: "Demo uncertain preview",
          status: "Added locally",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: draft.lastRefreshSummary
        ),
        to: &draft
      )
    }
    logAudit(
      action: .created,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Demo uncertain SpaceMail preview added locally.",
      afterDetail: "Subject: \(sample.subject)\nReason: \(sample.reason)\nThis creates a local review preview only. No mailbox fetch, Inbox import, duplicate metadata change, password, auth string, or mailbox mutation occurred."
    )
  }

  func testSpaceMailCustomClassifier(for connection: SpaceMailIMAPConnection, sender: String, subject: String, preview: String) {
    let safeSender = safeAuditPreview(sender.isEmpty ? connection.emailAddressUsername : sender, limit: 120)
    let safeSubject = safeAuditPreview(subject.isEmpty ? "No subject" : subject, limit: 160)
    let safePreview = safeAuditPreview(preview, limit: 280)
    let sample = FetchedMailboxMessage(
      providerMessageID: "local-custom-classifier-test-\(connection.id.uuidString)",
      sender: safeSender,
      subject: safeSubject,
      receivedDate: Self.auditTimestamp(),
      plainTextBodyPreview: safePreview,
      sourceMailboxID: trackedMailbox(for: connection).id
    )
    evaluateSpaceMailClassifierSample(
      sample,
      for: connection,
      eventType: "Custom classifier test",
      auditSummary: "SpaceMail custom mixed-mailbox classifier sample tested locally."
    )
  }

  func runSpaceMailClassifierTestSuite(for connection: SpaceMailIMAPConnection) {
    let mailboxID = trackedMailbox(for: connection).id
    let samples: [(name: String, expectedDecision: String, expectedOrder: String, expectedTracking: String, message: FetchedMailboxMessage)] = [
      (
        "Expected import: clear order shipped",
        "Imported",
        "TEST-123",
        "ABC123",
        FetchedMailboxMessage(
          providerMessageID: "suite-clear-order-\(connection.id.uuidString)",
          sender: "orders@example-shop.test",
          subject: "Order TEST-123 shipped tracking ABC123",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123 to Melbourne. Please watch for delivery.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected uncertain: delivery question",
        "Uncertain",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-delivery-question-\(connection.id.uuidString)",
          sender: "customer@example.com",
          subject: "Delivery question",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Can you check whether this relates to an order? I do not have the tracking number yet.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected uncertain: order follow-up missing IDs",
        "Uncertain",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-order-follow-up-\(connection.id.uuidString)",
          sender: "operations@example.com",
          subject: "Order follow-up",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Can someone check whether this customer delivery relates to an order? We do not have a tracking number yet.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected filter: marketing final days",
        "Filtered",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-marketing-\(connection.id.uuidString)",
          sender: "offers@example-shop.test",
          subject: "Final Days",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Final days for our promotion. View this email or unsubscribe.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected filter: free delivery marketing",
        "Filtered",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-delivery-marketing-\(connection.id.uuidString)",
          sender: "offers@example-shop.test",
          subject: "Final days for free delivery",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Final days to get free delivery on your next purchase. View this email or unsubscribe.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected filter: security alert",
        "Filtered",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-security-\(connection.id.uuidString)",
          sender: "security@example.com",
          subject: "Security alert",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Verification code requested for your account. This is not an order update.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected filter: generic receipt",
        "Filtered",
        "No expected order",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-generic-receipt-\(connection.id.uuidString)",
          sender: "payments@example-service.test",
          subject: "Your receipt is ready",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Your monthly receipt is ready. No order or shipment details are included in this notification.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected import: refund with order",
        "Imported",
        "REF-8821",
        "No expected tracking",
        FetchedMailboxMessage(
          providerMessageID: "suite-refund-\(connection.id.uuidString)",
          sender: "support@example-shop.test",
          subject: "Refund request for order REF-8821",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Customer requested refund for order REF-8821 after delivery issue.",
          sourceMailboxID: mailboxID
        )
      ),
      (
        "Expected import: tracking update",
        "Imported",
        "No expected order",
        "ZXCV123456789",
        FetchedMailboxMessage(
          providerMessageID: "suite-tracking-update-\(connection.id.uuidString)",
          sender: "tracking@example-carrier.test",
          subject: "Tracking update ZXCV123456789",
          receivedDate: Self.auditTimestamp(),
          plainTextBodyPreview: "Your shipment tracking number ZXCV123456789 is in transit and expected for delivery tomorrow.",
          sourceMailboxID: mailboxID
        )
      )
    ]
    let results = samples.map { sample in
      spaceMailClassifierTestResult(
        name: sample.name,
        message: sample.message,
        connection: connection,
        expectedDecision: sample.expectedDecision,
        expectedOrderNumber: sample.expectedOrder,
        expectedTrackingNumber: sample.expectedTracking
      )
    }
    let imported = results.filter { $0.decision == "Imported" }.count
    let uncertain = results.filter { $0.decision == "Uncertain" }.count
    let filtered = results.filter { $0.decision == "Filtered" }.count
    let decisionPasses = results.filter { $0.decisionStatus.lowercased().hasPrefix("classifier passed") }.count
    let decisionChecks = results.filter { !$0.decisionStatus.localizedCaseInsensitiveContains("No classifier expectation") }.count
    let parserPasses = results.filter { $0.parserStatus.lowercased().hasPrefix("parser passed") }.count
    let parserChecks = results.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }.count
    let summary = "Classifier suite: \(imported) imported, \(uncertain) uncertain, \(filtered) filtered across \(results.count) local samples. Classifier expectations: \(decisionPasses)/\(decisionChecks) passed. Parser expectations: \(parserPasses)/\(parserChecks) passed. No mailbox fetch or import occurred."
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.classifierTestResults = results
      draft.classifierTestSummary = summary
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Classifier suite",
          status: "Completed",
          fetchedCount: 0,
          importedCount: imported,
          duplicateCount: 0,
          filteredNonOrderCount: filtered,
          uncertainCount: uncertain,
          summary: summary
        ),
        to: &draft
      )
    }
    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "SpaceMail classifier test suite ran locally.",
      afterDetail: "\(summary)\n\(results.map { "\($0.sampleName): \($0.decision), \($0.reason), decision \($0.decisionStatus), order \($0.detectedOrderNumber), tracking \($0.detectedTrackingNumber), parser \($0.parserStatus)" }.joined(separator: "\n"))\nNo mailbox fetch, mailbox mutation, external service call, import, password, auth string, or full message body logging occurred."
    )
  }

  private func evaluateSpaceMailClassifierSample(
    _ sample: FetchedMailboxMessage,
    for connection: SpaceMailIMAPConnection,
    eventType: String,
    auditSummary: String
  ) {
    let relevance = classifyMailboxMessageRelevance(sample, for: connection)
    let testResult = spaceMailClassifierTestResult(name: eventType, message: sample, connection: connection)
    let decision = testResult.decision
    let parsingPreview = makeForwardedEmailIntake(from: sample)
    let linkedOrderText = parsingPreview.linkedOrderID == nil ? "No local order link" : "Would link to local order"
    let parserDetail = [
      "Detected merchant: \(testResult.detectedMerchant)",
      "Detected order: \(testResult.detectedOrderNumber)",
      "Detected tracking: \(testResult.detectedTrackingNumber)",
      "Detected destination: \(testResult.detectedDestination)",
      "Linked order preview: \(linkedOrderText)"
    ].joined(separator: "\n")
    let summary = "\(eventType) result: \(decision). Reason: \(relevance.reason). Score: \(relevance.score).\n\(parserDetail)\nNo mailbox fetch or import occurred."
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.classifierTestSummary = summary
      draft.classifierTestResults = [testResult]
      if relevance.decision == .uncertain {
        let uncertainSample = SpaceMailUncertainMessage(
          providerMessageID: sample.providerMessageID,
          sourceMailboxID: sample.sourceMailboxID,
          sender: sample.sender,
          subject: sample.subject,
          receivedDate: sample.receivedDate,
          bodyPreview: sample.plainTextBodyPreview,
          reason: relevance.reason,
          capturedDate: Self.auditTimestamp()
        )
        draft.uncertainMessages.removeAll { $0.providerMessageID == sample.providerMessageID }
        draft.uncertainMessages.insert(uncertainSample, at: 0)
        draft.lastRefreshUncertainCount = draft.uncertainMessages.count
        draft.lastRefreshUncertainExamples = ["\(uncertainSample.subject) (\(uncertainSample.reason))"]
        draft.lastRefreshSummary = "\(eventType) added one uncertain sample preview for review. No mailbox fetch or import occurred."
      }
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: eventType,
          status: decision,
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.lastRefreshFilteredNonOrderCount,
          uncertainCount: draft.uncertainMessages.count,
          summary: summary
        ),
        to: &draft
      )
    }
    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: auditSummary,
      afterDetail: "Sender: \(safeAuditPreview(sample.sender, limit: 120))\nSubject: \(safeAuditPreview(sample.subject, limit: 160))\nPreview: \(safeAuditPreview(sample.plainTextBodyPreview, limit: 280))\n\(summary)\nNo mailbox fetch, mailbox mutation, external service call, import, password, auth string, or full message body logging occurred."
    )
  }

  private func spaceMailClassifierTestResult(
    name: String,
    message: FetchedMailboxMessage,
    connection: SpaceMailIMAPConnection,
    expectedDecision: String = "No expected decision",
    expectedOrderNumber: String = "No expected order",
    expectedTrackingNumber: String = "No expected tracking"
  ) -> SpaceMailClassifierTestResult {
    let relevance = classifyMailboxMessageRelevance(message, for: connection)
    let parsingPreview = makeForwardedEmailIntake(from: message)
    let decision: String
    switch relevance.decision {
    case .likelyOrder:
      decision = "Imported"
    case .uncertain:
      decision = "Uncertain"
    case .nonOrder:
      decision = "Filtered"
    }
    let evidence = spaceMailClassifierEvidence(
      for: message,
      connection: connection,
      decision: relevance.decision,
      reason: relevance.reason,
      score: relevance.score
    )
    return SpaceMailClassifierTestResult(
      sampleName: name,
      decision: decision,
      reason: relevance.reason,
      score: relevance.score,
      subjectPreview: safeAuditPreview(message.subject, limit: 120),
      detectedOrderNumber: parsingPreview.detectedOrderNumber,
      detectedTrackingNumber: parsingPreview.detectedTrackingNumber,
      detectedMerchant: parsingPreview.detectedMerchant,
      detectedDestination: parsingPreview.detectedDestinationAddress,
      expectedDecision: expectedDecision,
      decisionStatus: spaceMailDecisionStatus(decision: decision, expectedDecision: expectedDecision),
      expectedOrderNumber: expectedOrderNumber,
      expectedTrackingNumber: expectedTrackingNumber,
      parserStatus: spaceMailParserStatus(
        detectedOrderNumber: parsingPreview.detectedOrderNumber,
        detectedTrackingNumber: parsingPreview.detectedTrackingNumber,
        expectedOrderNumber: expectedOrderNumber,
        expectedTrackingNumber: expectedTrackingNumber
      ),
      positiveEvidenceLabels: evidence.positiveLabels,
      cautionLabels: evidence.cautionLabels,
      nextActionText: evidence.nextAction
    )
  }

  private func spaceMailDecisionStatus(decision: String, expectedDecision: String) -> String {
    guard expectedDecision != "No expected decision" else {
      return "No classifier expectation"
    }
    if decision.normalizedValidationKey == expectedDecision.normalizedValidationKey {
      return "Classifier passed: expected \(expectedDecision)"
    }
    return "Classifier needs review: expected \(expectedDecision), got \(decision)"
  }

  private func spaceMailParserStatus(
    detectedOrderNumber: String,
    detectedTrackingNumber: String,
    expectedOrderNumber: String,
    expectedTrackingNumber: String
  ) -> String {
    var checks: [String] = []
    if expectedOrderNumber != "No expected order" {
      let passed = detectedOrderNumber.normalizedValidationKey == expectedOrderNumber.normalizedValidationKey
      checks.append(passed ? "order passed" : "order expected \(expectedOrderNumber), got \(detectedOrderNumber)")
    }
    if expectedTrackingNumber != "No expected tracking" {
      let passed = detectedTrackingNumber.normalizedValidationKey == expectedTrackingNumber.normalizedValidationKey
      checks.append(passed ? "tracking passed" : "tracking expected \(expectedTrackingNumber), got \(detectedTrackingNumber)")
    }
    if checks.isEmpty {
      return "No parser expectation"
    }
    if checks.allSatisfy({ $0.localizedCaseInsensitiveContains("passed") }) {
      return "Parser passed: \(checks.joined(separator: ", "))"
    }
    return "Parser needs review: \(checks.joined(separator: ", "))"
  }

  func saveSpaceMailCredential(_ password: String, for connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.savePassword(password, for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: result.status == .passwordReferenceAvailable ? "SpaceMail credential saved to Keychain." : "SpaceMail credential save failed or was skipped.")
    }
  }

  func checkSpaceMailCredential(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.checkPassword(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: result.status == .passwordReferenceAvailable ? "SpaceMail credential check succeeded." : "SpaceMail credential check did not find a usable password reference.")
    }
  }

  func clearSpaceMailCredential(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.clearPassword(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: result.status == .passwordCleared ? "SpaceMail credential cleared from Keychain." : "SpaceMail credential clear failed.")
    }
  }

  func simulateSpaceMailCredentialReady(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.simulateReady(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: "Mock SpaceMail credential reference marked ready.")
    }
  }

  func simulateSpaceMailCredentialMissing(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.simulateMissing(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: "Mock SpaceMail credential missing state recorded.")
    }
  }

  func simulateSpaceMailCredentialStorageError(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.simulateStorageError(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: "Mock SpaceMail credential storage error simulated.")
    }
  }

  func simulateSpaceMailCredentialClear(_ connection: SpaceMailIMAPConnection) {
    Task {
      let result = await spaceMailCredentialStore.simulateClear(for: connection)
      applySpaceMailCredentialStoreResult(result, to: connection, summary: "Mock SpaceMail credential reference clear simulated.")
    }
  }

  private func refreshMockSpaceMailIMAPMessages(for connection: SpaceMailIMAPConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.connectionStatus = "Mock refresh running"
      draft.lastManualRefreshDate = Self.auditTimestamp()
    }
    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock SpaceMail IMAP refresh started.",
      afterDetail: "Mailbox: \(connection.emailAddressUsername)\nHost: \(connection.imapHost)\nPort: \(connection.imapPort)\nSecurity: \(connection.securityMode)\nFolder: \(connection.folderName)\nMode: SpaceMail IMAP client boundary mock only\nNo real IMAP connection was made, no password was requested or stored, and no mailbox item will be deleted, moved, marked read, sent, or modified."
    )

    let fetchResult = await spaceMailIMAPClient.fetchMessages(for: connection, sourceMailboxID: mailbox.id, password: nil)
    let result = importFetchedMailboxMessages(fetchResult.messages)
    let refreshStatus = spaceMailRefreshStatus(fetchResult: fetchResult, ingestResult: result)
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.connectionStatus = "Mock IMAP: \(refreshStatus.rawValue)"
      draft.lastManualRefreshDate = Self.auditTimestamp()
      draft.lastRefreshFetchedCount = fetchResult.messages.count
      draft.lastRefreshImportedCount = result.imported
      draft.lastRefreshDuplicateCount = result.duplicates
      draft.lastRefreshFilteredNonOrderCount = 0
      draft.lastRefreshUncertainCount = 0
      draft.lastRefreshSummary = "Mock refresh \(refreshStatus.rawValue.lowercased()): \(fetchResult.messages.count) fetched, \(result.imported) imported, \(result.duplicates) duplicates. Mock refresh does not apply mixed-mailbox filtering."
      draft.lastRefreshFilteredExamples = []
      draft.lastRefreshUncertainExamples = []
      draft.uncertainMessages = []
      draft.filteredMessages = []
      draft.lastRefreshReasonBreakdown = []
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: draft.lastManualRefreshDate,
          eventType: "Mock refresh",
          status: refreshStatus.rawValue,
          fetchedCount: fetchResult.messages.count,
          importedCount: result.imported,
          duplicateCount: result.duplicates,
          filteredNonOrderCount: 0,
          uncertainCount: 0,
          summary: draft.lastRefreshSummary
        ),
        to: &draft
      )
    }

    if fetchResult.status == .noMessages {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Mock SpaceMail IMAP fetch returned no messages.",
        afterDetail: "Status: \(fetchResult.status.rawValue)\n\(fetchResult.detail)\nNo real IMAP network call was made and no mailbox item was modified."
      )
    } else if fetchResult.status != .success {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Mock SpaceMail IMAP fetch stopped before import.",
        afterDetail: "Status: \(fetchResult.status.rawValue)\n\(fetchResult.detail)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nNo real IMAP network call was made, no password was stored, and no mailbox item was modified."
      )
    }

    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock SpaceMail IMAP refresh completed.",
      afterDetail: "Status: \(refreshStatus.rawValue)\nFetch result: \(fetchResult.status.rawValue)\nFetched messages: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nDuplicate skips mean ParcelOps already captured that IMAP provider message ID for this mailbox.\n\(fetchResult.detail)\nNo real IMAP network call was made. No password was stored in JSON. Keychain was not used by the mock refresh. No mailbox items were deleted, moved, marked read, sent, or modified."
    )
  }

  private func refreshRealSpaceMailIMAPMessages(for connection: SpaceMailIMAPConnection) async {
    let mailbox = trackedMailbox(for: connection)
    upsertTrackedMailbox(mailbox)
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.connectionStatus = "Real refresh checking setup"
      draft.lastManualRefreshDate = Self.auditTimestamp()
    }
    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real SpaceMail IMAP refresh started.",
      afterDetail: "Mailbox: \(connection.emailAddressUsername)\nHost: \(connection.imapHost)\nPort: \(connection.imapPort)\nSecurity: \(connection.securityMode)\nFolder: \(connection.folderName)\nMode: Manual real SpaceMail IMAP boundary\nLimit: at most 10 messages when credentials are available\nCredential storage: \(connection.credentialStorageStatus)\nNo password is stored in JSON or audit logs. This refresh must not delete, move, mark read, flag, send, or modify mailbox items."
    )

    let credentialResult = await spaceMailCredentialStore.loadPassword(for: connection)
    let connectionForRefresh: SpaceMailIMAPConnection
    if credentialResult.status == .passwordReferenceAvailable {
      var updatedConnection = connection
      updatedConnection.credentialStorageStatus = SpaceMailCredentialStoreStatus.passwordReferenceAvailable.rawValue
      connectionForRefresh = updatedConnection
      applySpaceMailCredentialStoreResult(
        SpaceMailCredentialStoreResult(status: credentialResult.status, detailText: credentialResult.detailText),
        to: connection,
        summary: "SpaceMail credential check succeeded for real refresh."
      )
    } else {
      connectionForRefresh = connection
      applySpaceMailCredentialStoreResult(
        SpaceMailCredentialStoreResult(status: credentialResult.status, detailText: credentialResult.detailText),
        to: connection,
        summary: "SpaceMail credential missing for real refresh."
      )
    }

    let fetchResult = await realSpaceMailIMAPClient.fetchMessages(for: connectionForRefresh, sourceMailboxID: mailbox.id, password: credentialResult.password)
    let filterResult = filteredSpaceMailMessages(fetchResult.messages, for: connectionForRefresh)
    let result = importFetchedMailboxMessages(filterResult.importMessages)
    let refreshStatus = spaceMailRefreshStatus(fetchResult: fetchResult, ingestResult: result)
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.connectionStatus = "Real IMAP: \(refreshStatus.rawValue)"
      draft.lastManualRefreshDate = Self.auditTimestamp()
      draft.lastRefreshFetchedCount = fetchResult.messages.count
      draft.lastRefreshImportedCount = result.imported
      draft.lastRefreshDuplicateCount = result.duplicates
      draft.lastRefreshFilteredNonOrderCount = filterResult.filteredNonOrderCount
      draft.lastRefreshUncertainCount = filterResult.uncertainCount
      draft.lastRefreshFilteredExamples = filterResult.filteredExamples
      draft.lastRefreshUncertainExamples = filterResult.uncertainExamples
      draft.lastRefreshSummary = spaceMailRefreshSummaryText(
        status: refreshStatus,
        connection: connectionForRefresh,
        fetched: fetchResult.messages.count,
        imported: result.imported,
        duplicates: result.duplicates,
        filtered: filterResult.filteredNonOrderCount,
        uncertain: filterResult.uncertainCount
      )
      draft.uncertainMessages = Array(filterResult.uncertainMessages.prefix(10))
      draft.filteredMessages = Array(filterResult.filteredMessages.prefix(10))
      draft.lastRefreshReasonBreakdown = Array(filterResult.reasonBreakdown.prefix(12))
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: draft.lastManualRefreshDate,
          eventType: "Real refresh",
          status: refreshStatus.rawValue,
          fetchedCount: fetchResult.messages.count,
          importedCount: result.imported,
          duplicateCount: result.duplicates,
          filteredNonOrderCount: filterResult.filteredNonOrderCount,
          uncertainCount: filterResult.uncertainCount,
          summary: draft.lastRefreshSummary
        ),
        to: &draft
      )
    }

    if fetchResult.status == .noMessages {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Real SpaceMail IMAP fetch returned no messages.",
        afterDetail: "Status: \(fetchResult.status.rawValue)\n\(fetchResult.detail)\nFetched messages: 0\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nFiltered non-order: \(filterResult.filteredNonOrderCount)\nUncertain: \(filterResult.uncertainCount)\nNo mailbox item was deleted, moved, marked read, flagged, sent, or modified."
      )
    } else if fetchResult.status != .success {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "Real SpaceMail IMAP refresh stopped before import.",
        afterDetail: "Status: \(fetchResult.status.rawValue)\n\(fetchResult.detail)\nFetched messages: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nFiltered non-order: \(filterResult.filteredNonOrderCount)\nUncertain: \(filterResult.uncertainCount)\n\(filterResult.detail)\nNo password, app password, auth string, server credential, or Keychain item was stored in JSON or logged. No mailbox item was deleted, moved, marked read, flagged, sent, or modified."
      )
    }

    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real SpaceMail IMAP refresh completed.",
      afterDetail: "Status: \(refreshStatus.rawValue)\nFetch result: \(fetchResult.status.rawValue)\nMailbox mode: \(connectionForRefresh.mailboxMode.rawValue)\nFetched messages: \(fetchResult.messages.count)\nImported: \(result.imported)\nDuplicate skips: \(result.duplicates)\nFiltered non-order: \(filterResult.filteredNonOrderCount)\nUncertain: \(filterResult.uncertainCount)\nDuplicate skips mean ParcelOps already captured that IMAP provider message ID for this mailbox.\n\(filterResult.detail)\n\(fetchResult.detail)\nManual refresh only. Read-only boundary. Filtered non-order messages are counted only; their full bodies are not stored in intake. The SpaceMail password/app-password is loaded from Keychain only for this manual operation and is not stored in JSON or audit logs. No mailbox items were deleted, moved, marked read, flagged, sent, or modified."
    )
  }

  func resetMicrosoft365OAuthReadiness(_ connection: Microsoft365MailboxConnection) {
    updateMicrosoft365MailboxConnection(connection) { draft in
      draft.tenantIDPlaceholder = ""
      draft.clientIDPlaceholder = ""
      draft.redirectURIPlaceholder = MSALMicrosoft365AuthAdapter.redirectURI
      draft.requestedScopesSummary = "User.Read, Mail.Read"
      draft.oauthReadinessStatus = "Reset locally"
      draft.consentAdminNotes = "Local planning reset. No OAuth flow runs and no tokens are requested."
      draft.oauthImplementationPlanStatus = "Not reviewed"
      draft.reviewState = .needsReview
    }
    logAudit(
      action: .cleared,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 OAuth readiness placeholders reset locally.",
      afterDetail: "Tenant/client/redirect/scope placeholders cleared. No OAuth, token, Keychain, or network action occurred."
    )
  }

  func markMicrosoft365OAuthImplementationPlanReviewed(_ connection: Microsoft365MailboxConnection) {
    let plan = microsoft365OAuthImplementationPlan(for: connection)
    updateMicrosoft365MailboxConnection(connection) { draft in
      draft.oauthImplementationPlanStatus = plan.statusText
      draft.reviewState = plan.completedCount == plan.totalCount ? .monitor : .needsReview
    }
    logAudit(
      action: .reviewed,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 OAuth implementation plan reviewed locally.",
      afterDetail: microsoft365OAuthImplementationPlanAuditDetail(plan)
    )
  }

  func createReviewTaskFromMicrosoft365OAuthPlan(_ connection: Microsoft365MailboxConnection) {
    let plan = microsoft365OAuthImplementationPlan(for: connection)
    createReviewTask(
      linkedEntityType: .integration,
      linkedEntityID: connection.id.uuidString,
      label: "\(connection.displayName) OAuth plan",
      summary: "Review Microsoft 365 OAuth implementation plan. \(plan.statusText). \(plan.items.filter { !$0.isComplete }.map(\.title).joined(separator: ", "))",
      priority: plan.completedCount < plan.totalCount ? .high : .normal,
      assignee: "Operations"
    )
    logAudit(
      action: .created,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Review task created from Microsoft 365 OAuth implementation plan.",
      afterDetail: microsoft365OAuthImplementationPlanAuditDetail(plan)
    )
  }

  func microsoft365AuthSessionState(for connection: Microsoft365MailboxConnection) -> Microsoft365AuthSessionState {
    microsoft365AuthSessionStates[connection.id] ?? Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: .notConnected,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: "Never",
      lastSuccessfulAuthDate: "Never",
      keychainStatus: "MSAL cache entitlement ready",
      tokenStoreStatus: .keychainNotConfigured,
      tokenStoreDetail: "ParcelOps custom token store is not configured. MSAL may manage its own signed-in account cache when real sign-in succeeds, but ParcelOps does not create, read, write, delete, or log token values.",
      detailText: "Microsoft 365 is not connected for this setup record. No browser sign-in opens from this state, no tokens are requested or stored in ParcelOps JSON, and real Graph mailbox reading only runs from the separate manual refresh action after sign-in."
    )
  }

  func connectMicrosoft365AuthMock(_ connection: Microsoft365MailboxConnection) {
    let startedState = Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: Self.auditTimestamp(),
      lastSuccessfulAuthDate: microsoft365AuthSessionState(for: connection).lastSuccessfulAuthDate,
      keychainStatus: "MSAL cache entitlement ready",
      tokenStoreStatus: microsoft365AuthSessionState(for: connection).tokenStoreStatus,
      tokenStoreDetail: microsoft365AuthSessionState(for: connection).tokenStoreDetail,
      detailText: "Mock Microsoft 365 auth started locally. No browser sign-in opened and no token request was made."
    )
    microsoft365AuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Microsoft 365 auth started.",
      afterDetail: microsoft365AuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await microsoft365AuthClient.connect(connection: connection)
      await MainActor.run {
        applyMicrosoft365AuthResult(result, to: connection)
      }
    }
  }

  func simulateMicrosoft365AuthFailure(_ connection: Microsoft365MailboxConnection) {
    let startedState = Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: Self.auditTimestamp(),
      lastSuccessfulAuthDate: microsoft365AuthSessionState(for: connection).lastSuccessfulAuthDate,
      keychainStatus: "MSAL cache entitlement ready",
      tokenStoreStatus: microsoft365AuthSessionState(for: connection).tokenStoreStatus,
      tokenStoreDetail: microsoft365AuthSessionState(for: connection).tokenStoreDetail,
      detailText: "Mock Microsoft 365 auth failure test started locally. No browser sign-in opened and no token request was made."
    )
    microsoft365AuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Mock Microsoft 365 auth started.",
      afterDetail: microsoft365AuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await microsoft365AuthClient.simulateFailure(connection: connection)
      await MainActor.run {
        applyMicrosoft365AuthResult(result, to: connection)
      }
    }
  }

  func connectMicrosoft365AuthReal(_ connection: Microsoft365MailboxConnection) {
    let attemptID = UUID()
    activeMicrosoft365AuthAttempts[connection.id] = attemptID
    let previousState = microsoft365AuthSessionState(for: connection)
    let startedState = Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: .connecting,
      signedInAccount: "Not signed in",
      lastAuthAttemptDate: Self.auditTimestamp(),
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      keychainStatus: "MSAL cache entitlement ready",
      tokenStoreStatus: previousState.tokenStoreStatus,
      tokenStoreDetail: previousState.tokenStoreDetail,
      detailText: "Real Microsoft 365 sign-in test started. A browser sign-in may open, but ParcelOps will not store token values in JSON and will not fetch mailbox messages. Attempt ID: \(attemptID.uuidString)."
    )
    microsoft365AuthSessionStates[connection.id] = startedState
    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Microsoft 365 sign-in started.",
      afterDetail: microsoft365AuthSessionAuditDetail(startedState)
    )

    Task {
      let result = await microsoft365RealAuthClient.connect(connection: connection)
      await MainActor.run {
        applyMicrosoft365AuthResult(result, to: connection, isRealAuth: true, attemptID: attemptID)
      }
    }

    Task {
      try? await Task.sleep(for: .seconds(120))
      await MainActor.run {
        completeTimedOutMicrosoft365AuthAttempt(connectionID: connection.id, attemptID: attemptID)
      }
    }
  }

  @MainActor
  func handleMicrosoft365AuthCallback(_ url: URL) {
    let isMicrosoft365Callback = url.scheme == MSALMicrosoft365AuthAdapter.redirectScheme
    let status = MSALMicrosoft365AuthAdapter().callbackReadinessStatus(for: url)
    let activeConnections = activeMicrosoft365AuthAttempts.keys.compactMap { id in
      microsoft365MailboxConnections.first { $0.id == id }?.displayName
    }
    let activeDetail = activeConnections.isEmpty
      ? "No active Microsoft 365 sign-in attempt was waiting in ParcelOps when this callback was handled."
      : "Active Microsoft 365 sign-in attempts waiting for MSAL completion: \(activeConnections.joined(separator: ", "))."
    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: "microsoft-365-auth-callback",
      entityLabel: "Microsoft 365 auth callback",
      summary: isMicrosoft365Callback ? "Microsoft 365 auth callback received." : "Non-Microsoft 365 auth callback ignored.",
      afterDetail: "\(status)\n\(activeDetail)\nRaw callback URLs, auth codes, state values, access tokens, refresh tokens, and ID tokens are not logged or stored."
    )
  }

  @MainActor
  func handleGmailAuthCallback(_ url: URL) {
    let isGmailCallback = GoogleGmailAuthAdapter.isPotentialCallbackURL(url)
    guard isGmailCallback else { return }
    let status = GoogleGmailAuthAdapter().callbackReadinessStatus(for: url)
    let connection = gmailMailboxConnections.first
    logAudit(
      action: .evaluated,
      entityType: .gmailMailboxConnection,
      entityID: connection?.id.uuidString ?? "gmail-auth-callback",
      entityLabel: connection?.displayName ?? "Gmail auth callback",
      summary: "Gmail auth callback readiness evaluated.",
      afterDetail: "\(status)\nGmail callback handling accepts the placeholder scheme and real reversed Google OAuth client ID schemes registered in the compiled app. No Google access token, refresh token, auth code, client secret, password, raw callback URL, or Gmail message was stored in ParcelOps JSON or audit logs. No Gmail API mailbox call was made."
    )
  }

  func simulateMicrosoft365TokenStoreReady(_ connection: Microsoft365MailboxConnection) {
    Task {
      let result = await microsoft365TokenStore.simulateReady(for: connection)
      applyMicrosoft365TokenStoreResult(result, to: connection, summary: "Mock Microsoft 365 token store marked ready.")
    }
  }

  func simulateMicrosoft365TokenMissing(_ connection: Microsoft365MailboxConnection) {
    Task {
      let result = await microsoft365TokenStore.simulateMissing(for: connection)
      applyMicrosoft365TokenStoreResult(result, to: connection, summary: "Mock Microsoft 365 token reference marked missing.")
    }
  }

  func simulateMicrosoft365TokenStorageError(_ connection: Microsoft365MailboxConnection) {
    Task {
      let result = await microsoft365TokenStore.simulateStorageError(for: connection)
      applyMicrosoft365TokenStoreResult(result, to: connection, summary: "Mock Microsoft 365 token storage error simulated.")
    }
  }

  func simulateMicrosoft365TokenClear(_ connection: Microsoft365MailboxConnection) {
    Task {
      let result = await microsoft365TokenStore.simulateClear(for: connection)
      applyMicrosoft365TokenStoreResult(result, to: connection, summary: "Mock Microsoft 365 token reference clear simulated.")
    }
  }

  func removeMicrosoft365MailboxConnection(_ connection: Microsoft365MailboxConnection) {
    guard let index = microsoft365MailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = microsoft365MailboxConnectionAuditDetail(microsoft365MailboxConnections[index])
    microsoft365MailboxConnections.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: "Microsoft 365 mailbox setup placeholder removed.",
      beforeDetail: beforeDetail
    )
  }

  func connectShopifyPlaceholder() {
    let connection = ShopifyConnection(storeName: "New Shopify Store", storeDomain: "new-store.myshopify.com", mappedMailbox: "tracking-intake@parcelops.example", mappedTeam: "Unassigned", status: "Needs OAuth", lastSync: "Never", isEnabled: false)
    shopifyConnections.append(connection)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .shopifyConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.storeName,
      summary: "Shopify planning placeholder added.",
      afterDetail: "\(connection.auditDetail)\nPlaceholder only. No Shopify OAuth, API call, token, credential, product, order, or store data access occurred."
    )
  }

  func removeShopifyPlaceholder(_ connection: ShopifyConnection) {
    guard let index = shopifyConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = shopifyConnections[index].auditDetail
    shopifyConnections.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .shopifyConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.storeName,
      summary: "Shopify planning placeholder removed.",
      beforeDetail: "\(beforeDetail)\nRemoved locally only. No Shopify OAuth, API call, token, credential, product, order, or store data access occurred."
    )
  }

  func markShopifyPlaceholderReviewed(_ connection: ShopifyConnection) {
    guard let index = shopifyConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = shopifyConnections[index].auditDetail
    shopifyConnections[index].status = "Reviewed locally"
    shopifyConnections[index].lastSync = Self.auditTimestamp()
    persistIntegrations()
    logAudit(
      action: .reviewed,
      entityType: .shopifyConnection,
      entityID: shopifyConnections[index].id.uuidString,
      entityLabel: shopifyConnections[index].storeName,
      summary: "Shopify planning placeholder reviewed locally.",
      beforeDetail: beforeDetail,
      afterDetail: "\(shopifyConnections[index].auditDetail)\nReview only. No Shopify OAuth, API call, token, credential, product, order, or store data access occurred."
    )
  }

  func addStoreLoginPlaceholder() {
    let connection = SourceConnection(name: "New supplier login", kind: .vaultLogin, account: "Password vault", status: "Needs setup", lastSync: "Never")
    connections.append(connection)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .sourceConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.name,
      summary: "Store login planning placeholder added.",
      afterDetail: "\(connection.auditDetail)\nPlaceholder only. No password vault, credential, Keychain item, login, browser, or supplier portal action occurred."
    )
  }

  func removeStoreLoginPlaceholder(_ connection: SourceConnection) {
    guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = connections[index].auditDetail
    connections.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .sourceConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.name,
      summary: "Store login planning placeholder removed.",
      beforeDetail: "\(beforeDetail)\nRemoved locally only. No password vault, credential, Keychain item, login, browser, or supplier portal action occurred."
    )
  }

  func markStoreLoginPlaceholderReviewed(_ connection: SourceConnection) {
    guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
    let beforeDetail = connections[index].auditDetail
    connections[index].status = "Reviewed locally"
    connections[index].lastSync = Self.auditTimestamp()
    persistIntegrations()
    logAudit(
      action: .reviewed,
      entityType: .sourceConnection,
      entityID: connections[index].id.uuidString,
      entityLabel: connections[index].name,
      summary: "Store login planning placeholder reviewed locally.",
      beforeDetail: beforeDetail,
      afterDetail: "\(connections[index].auditDetail)\nReview only. No password vault, credential, Keychain item, login, browser, or supplier portal action occurred."
    )
  }

  func addWatchedFolderPlaceholder() {
    let folder = WatchedFolder(name: "Custom order folder", location: "Choose folder", platform: "iOS and macOS", fileTypes: "PDF, images", cadence: settings.folderScanCadence, status: "Needs permission", lastScan: "Never")
    watchedFolders.append(folder)
    persistIntegrations()
    logAudit(
      action: .created,
      entityType: .watchedFolder,
      entityID: folder.id.uuidString,
      entityLabel: folder.name,
      summary: "Watched folder planning placeholder added.",
      afterDetail: "\(folder.auditDetail)\nPlaceholder only. No file picker, folder permission request, background scan, OCR, import, or file access occurred."
    )
  }

  func removeWatchedFolderPlaceholder(_ folder: WatchedFolder) {
    guard let index = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
    let beforeDetail = watchedFolders[index].auditDetail
    watchedFolders.remove(at: index)
    persistIntegrations()
    logAudit(
      action: .removed,
      entityType: .watchedFolder,
      entityID: folder.id.uuidString,
      entityLabel: folder.name,
      summary: "Watched folder planning placeholder removed.",
      beforeDetail: "\(beforeDetail)\nRemoved locally only. No file picker, folder permission request, background scan, OCR, import, or file access occurred."
    )
  }

  func markWatchedFolderPlaceholderReviewed(_ folder: WatchedFolder) {
    guard let index = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
    let beforeDetail = watchedFolders[index].auditDetail
    watchedFolders[index].status = "Reviewed locally"
    watchedFolders[index].lastScan = Self.auditTimestamp()
    persistIntegrations()
    logAudit(
      action: .reviewed,
      entityType: .watchedFolder,
      entityID: watchedFolders[index].id.uuidString,
      entityLabel: watchedFolders[index].name,
      summary: "Watched folder planning placeholder reviewed locally.",
      beforeDetail: beforeDetail,
      afterDetail: "\(watchedFolders[index].auditDetail)\nReview only. No file picker, folder permission request, background scan, OCR, import, or file access occurred."
    )
  }

  func uploadWishlistPDFPlaceholder() {
    addWishlistItem(source: .pdf, name: "Parsed PDF item", detail: "PDF parsing placeholder captured supplier, item, and cost for review.")
  }

  func addWishlistScreenshotPlaceholder() {
    addWishlistItem(source: .screenshot, name: "Parsed screenshot item", detail: "Screenshot parsing placeholder captured visible item information for review.")
  }

  func addManualWishlistItemPlaceholder() {
    addWishlistItem(source: .manual, name: "Manual wishlist item", detail: "Manual placeholder item awaiting purchase details.")
  }

  func convertWishlistToOrder(_ item: WishlistItem) {
    let order = TrackedOrder(
      orderNumber: "WISH-\(1000 + orders.count + 1)",
      store: item.storefront,
      recipientEmail: "wishlist@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: item.owner,
      fulfillment: .delivery,
      carrier: "Pending",
      trackingNumber: "Pending",
      destination: "Pending",
      eta: "Pending",
      source: .manual,
      status: .intake,
      reviewState: .needsReview,
      latestStatus: "Converted from wishlist and awaiting purchase confirmation",
      timeline: [TimelineEvent(title: "Wishlist conversion", detail: item.itemName, time: "Now", symbol: "star.square.fill")],
      contactHistory: [ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "Wishlist", summary: "Wishlist item converted to order draft.", evidence: item.capturedDetail, reviewState: .needsReview)]
    )
    orders.insert(order, at: 0)
    persistOrders()
    logAudit(
      action: .created,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: "Order draft created from wishlist item.",
      afterDetail: "\(order.auditDetail)\nWishlist source: \(item.auditDetail)\nNo purchase API, payment, supplier, carrier, Shopify, or mailbox action occurred."
    )
    logAudit(
      action: .linked,
      entityType: .wishlistItem,
      entityID: item.id.uuidString,
      entityLabel: item.itemName,
      summary: "Wishlist item converted into local order draft \(order.orderNumber).",
      afterDetail: "\(item.auditDetail)\nCreated order: \(order.orderNumber) \(order.id.uuidString)"
    )
  }

  func linkWishlistItemToOrder(_ item: WishlistItem) {
    guard let index = wishlistItems.firstIndex(where: { $0.id == item.id }) else { return }
    let beforeDetail = wishlistItems[index].auditDetail
    wishlistItems[index].status = "Linked to existing order"
    persistWishlist()
    logAudit(
      action: .linked,
      entityType: .wishlistItem,
      entityID: wishlistItems[index].id.uuidString,
      entityLabel: wishlistItems[index].itemName,
      summary: "Wishlist item marked linked to an existing order.",
      beforeDetail: beforeDetail,
      afterDetail: wishlistItems[index].auditDetail
    )
  }

  func deleteWishlistItem(_ item: WishlistItem) {
    let beforeDetail = item.auditDetail
    wishlistItems.removeAll { $0.id == item.id }
    var deleted = item
    deleted.status = "Deleted now"
    deletedWishlistItems.insert(deleted, at: 0)
    persistWishlist()
    logAudit(
      action: .removed,
      entityType: .wishlistItem,
      entityID: deleted.id.uuidString,
      entityLabel: deleted.itemName,
      summary: "Wishlist item moved to deleted items.",
      beforeDetail: beforeDetail,
      afterDetail: deleted.auditDetail
    )
  }

  func restoreWishlistItem(_ item: WishlistItem) {
    let beforeDetail = item.auditDetail
    deletedWishlistItems.removeAll { $0.id == item.id }
    var restored = item
    restored.status = "Ready"
    wishlistItems.insert(restored, at: 0)
    persistWishlist()
    logAudit(
      action: .reopened,
      entityType: .wishlistItem,
      entityID: restored.id.uuidString,
      entityLabel: restored.itemName,
      summary: "Wishlist item restored from deleted items.",
      beforeDetail: beforeDetail,
      afterDetail: restored.auditDetail
    )
  }

  func permanentlyDeleteWishlistItem(_ item: WishlistItem) {
    deletedWishlistItems.removeAll { $0.id == item.id }
    persistWishlist()
    logAudit(
      action: .removed,
      entityType: .wishlistItem,
      entityID: item.id.uuidString,
      entityLabel: item.itemName,
      summary: "Wishlist item permanently removed from deleted items.",
      beforeDetail: item.auditDetail
    )
  }

  func saveSettings() {
    settingsRepository.saveSettings(settings)
    logAudit(
      action: .evaluated,
      entityType: .settings,
      entityID: "local-settings",
      entityLabel: "Settings",
      summary: "Settings saved locally.",
      afterDetail: "\(settings.auditDetail)\nSettings remain local JSON-backed planning controls. This save does not enable Shopify, carrier APIs, background sync, notifications, scanners, OCR, calendars, file pickers, or outbound email."
    )
  }

  private func addWishlistItem(source: WishlistSource, name: String, detail: String) {
    let item = WishlistItem(itemName: name, storefront: "Pending storefront", storefrontURL: "https://example.com", estimatedCost: "Pending", owner: "Current user", pool: "Personal wishlist", source: source, status: "Needs review", capturedDetail: detail)
    wishlistItems.insert(item, at: 0)
    persistWishlist()
    logAudit(
      action: .created,
      entityType: .wishlistItem,
      entityID: item.id.uuidString,
      entityLabel: item.itemName,
      summary: "Wishlist item placeholder added.",
      afterDetail: "\(item.auditDetail)\nSource action is local-only. No file picker, OCR, share extension, browser extension, purchase API, or external service was used."
    )
  }

  private func updateMicrosoft365MailboxConnection(_ connection: Microsoft365MailboxConnection, mutate: (inout Microsoft365MailboxConnection) -> Void) {
    guard let index = microsoft365MailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    var draft = microsoft365MailboxConnections[index]
    mutate(&draft)
    microsoft365MailboxConnections[index] = draft
    persistIntegrations()
  }

  private func updateSpaceMailIMAPConnection(_ connection: SpaceMailIMAPConnection, mutate: (inout SpaceMailIMAPConnection) -> Void) {
    guard let index = spaceMailIMAPConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    var draft = spaceMailIMAPConnections[index]
    mutate(&draft)
    spaceMailIMAPConnections[index] = draft
    persistIntegrations()
  }

  private func updateGmailMailboxConnection(_ connection: GmailMailboxConnection, mutate: (inout GmailMailboxConnection) -> Void) {
    guard let index = gmailMailboxConnections.firstIndex(where: { $0.id == connection.id }) else { return }
    var draft = gmailMailboxConnections[index]
    mutate(&draft)
    gmailMailboxConnections[index] = draft
    persistIntegrations()
  }

  private func removeUncertainSpaceMailMessage(_ uncertainMessage: SpaceMailUncertainMessage, from connection: SpaceMailIMAPConnection) {
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.uncertainMessages.removeAll { $0.id == uncertainMessage.id || $0.providerMessageID == uncertainMessage.providerMessageID }
      draft.lastRefreshUncertainCount = draft.uncertainMessages.count
      draft.lastRefreshSummary = "Uncertain review updated locally. \(draft.uncertainMessages.count) uncertain messages remain. Filtered messages remain out of Inbox."
    }
  }

  private func removeFilteredSpaceMailMessage(_ filteredMessage: SpaceMailFilteredMessage, from connection: SpaceMailIMAPConnection) {
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.filteredMessages.removeAll { $0.id == filteredMessage.id || $0.providerMessageID == filteredMessage.providerMessageID }
      draft.lastRefreshFilteredNonOrderCount = draft.filteredMessages.count
      draft.lastRefreshSummary = "Filtered review updated locally. \(draft.filteredMessages.count) filtered previews remain. Filtered messages remain out of Inbox unless imported manually."
    }
  }

  private func addSpaceMailHint(
    target: SpaceMailHintTarget,
    sender: String,
    subject: String,
    bodyPreview: String,
    sourceReason: String,
    connection: SpaceMailIMAPConnection
  ) {
    guard let hint = spaceMailHintCandidate(target: target, sender: sender, subject: subject, bodyPreview: bodyPreview) else {
      logAudit(
        action: .evaluated,
        entityType: .spaceMailIMAPConnection,
        entityID: connection.id.uuidString,
        entityLabel: connection.displayName,
        summary: "SpaceMail hint was not added.",
        afterDetail: "Target: \(target.rawValue)\nReason: No safe hint could be derived from the local preview. No mailbox fetch, import, credential access, or mailbox mutation occurred."
      )
      return
    }
    var added = false
    updateSpaceMailIMAPConnection(connection) { draft in
      switch target {
      case .trustedSender:
        added = appendUniqueSpaceMailHint(hint, to: &draft.trustedSenderHints)
      case .importKeyword:
        added = appendUniqueSpaceMailHint(hint, to: &draft.importKeywordHints)
      case .uncertainKeyword:
        added = appendUniqueSpaceMailHint(hint, to: &draft.uncertainKeywordHints)
      case .filterKeyword:
        added = appendUniqueSpaceMailHint(hint, to: &draft.filterKeywordHints)
      }
      draft.mailboxMode = .mixedFiltered
      draft.classifierTestSummary = added
        ? "Added \(target.rawValue.lowercased()) hint '\(hint)'. Run the classifier test suite to preview the effect."
        : "\(target.rawValue) hint '\(hint)' already exists. No duplicate hint was added."
      appendSpaceMailRefreshHistory(
        SpaceMailRefreshHistoryEntry(
          timestamp: Self.auditTimestamp(),
          eventType: "Filter hint",
          status: added ? "Added" : "Already existed",
          fetchedCount: 0,
          importedCount: 0,
          duplicateCount: 0,
          filteredNonOrderCount: draft.filteredMessages.count,
          uncertainCount: draft.uncertainMessages.count,
          summary: "\(target.rawValue): \(hint). Source reason: \(sourceReason)."
        ),
        to: &draft
      )
    }
    logAudit(
      action: added ? .edited : .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: added ? "SpaceMail filter hint added locally." : "SpaceMail filter hint already existed.",
      afterDetail: "Target: \(target.rawValue)\nHint: \(hint)\nSource reason: \(sourceReason)\nNo mailbox fetch, import, credential access, password, auth string, or mailbox mutation occurred."
    )
  }

  private func appendUniqueSpaceMailHint(_ hint: String, to hints: inout [String]) -> Bool {
    let normalized = hint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { return false }
    if hints.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) {
      return false
    }
    hints.append(hint)
    return true
  }

  private func spaceMailHintCandidate(target: SpaceMailHintTarget, sender: String, subject: String, bodyPreview: String) -> String? {
    switch target {
    case .trustedSender:
      let cleanedSender = safeAuditPreview(sender, limit: 80)
      if let domain = cleanedSender.split(separator: "@").last, domain.contains(".") {
        return String(domain).lowercased()
      }
      return cleanedSender == "empty" ? nil : cleanedSender.lowercased()
    case .importKeyword, .uncertainKeyword, .filterKeyword:
      let subjectCandidate = spaceMailPhraseCandidate(from: subject)
      if let subjectCandidate { return subjectCandidate }
      return spaceMailPhraseCandidate(from: bodyPreview)
    }
  }

  private func spaceMailPhraseCandidate(from value: String) -> String? {
    let cleaned = safeAuditPreview(value, limit: 80)
      .replacingOccurrences(of: #"[^\p{L}\p{N}\s#:/._-]+"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count >= 4, cleaned != "empty" else { return nil }
    return String(cleaned.prefix(60)).lowercased()
  }

  private func appendSpaceMailRefreshHistory(_ entry: SpaceMailRefreshHistoryEntry, to connection: inout SpaceMailIMAPConnection) {
    connection.refreshHistory.insert(entry, at: 0)
    connection.refreshHistory = Array(connection.refreshHistory.prefix(12))
  }

  private func spaceMailFilterPresetConfiguration(_ preset: SpaceMailFilterPreset) -> (trustedSenders: [String], importKeywords: [String], uncertainKeywords: [String], filterKeywords: [String]) {
    switch preset {
    case .conservative:
      return (
        trustedSenders: [],
        importKeywords: ["order shipped", "tracking number", "dispatch confirmation", "shipment confirmation"],
        uncertainKeywords: ["delivery question", "relates to an order", "tracking number yet", "missing tracking"],
        filterKeywords: ["newsletter", "promotion", "sale ends", "final days", "security alert", "calendar", "webinar", "social", "unsubscribe"]
      )
    case .balanced:
      return (
        trustedSenders: ["shop", "orders", "dispatch", "shipping", "support"],
        importKeywords: ["order shipped", "tracking number", "your order", "shipment update", "delivery update", "refund", "return"],
        uncertainKeywords: ["delivery question", "order question", "where is my order", "relates to an order", "tracking number yet", "invoice question"],
        filterKeywords: ["newsletter", "promotion", "sale ends", "final days", "security alert", "calendar", "webinar"]
      )
    case .forwardedOrders:
      return (
        trustedSenders: ["caught@", "orders@", "tracking@", "dispatch@", "shipping@"],
        importKeywords: ["fwd:", "fw:", "order", "tracking", "shipped", "dispatched", "delivered", "parcel", "package"],
        uncertainKeywords: ["delivery question", "order question", "tracking question", "missing tracking", "relates to an order"],
        filterKeywords: ["newsletter", "promotion", "calendar", "webinar", "password reset", "verification code"]
      )
    }
  }

  private func applySpaceMailCredentialStoreResult(_ result: SpaceMailCredentialStoreResult, to connection: SpaceMailIMAPConnection, summary: String) {
    updateSpaceMailIMAPConnection(connection) { draft in
      draft.credentialStorageStatus = result.status.rawValue
      if result.status == .passwordReferenceAvailable {
        draft.connectionStatus = "Credential ready for future IMAP"
      } else if result.status == .passwordMissing {
        draft.connectionStatus = "Credential missing"
      } else if result.status == .storageErrorSimulated {
        draft.connectionStatus = "Credential storage error simulated"
      } else if result.status == .passwordCleared {
        draft.connectionStatus = "Credential cleared"
      } else if result.status == .passwordClearSimulated {
        draft.connectionStatus = "Credential clear simulated"
      } else {
        draft.connectionStatus = "Keychain not configured"
      }
    }
    logAudit(
      action: .evaluated,
      entityType: .spaceMailIMAPConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: summary,
      afterDetail: spaceMailCredentialStoreAuditDetail(result, connection: connection)
    )
  }

  private func applyMicrosoft365AuthResult(_ result: Microsoft365AuthResult, to connection: Microsoft365MailboxConnection, isRealAuth: Bool = false, attemptID: UUID? = nil) {
    let completionDetail = microsoft365AuthCompletionDetail(for: connection, result: result, isRealAuth: isRealAuth, attemptID: attemptID)
    if isRealAuth {
      activeMicrosoft365AuthAttempts[connection.id] = nil
    }
    let previousState = microsoft365AuthSessionState(for: connection)
    let timestamp = Self.auditTimestamp()
    let state = Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: result.status,
      signedInAccount: result.signedInAccount,
      lastAuthAttemptDate: previousState.lastAuthAttemptDate == "Never" ? timestamp : previousState.lastAuthAttemptDate,
      lastSuccessfulAuthDate: result.status == .connected ? timestamp : previousState.lastSuccessfulAuthDate,
      keychainStatus: isRealAuth && result.status == .connected ? "MSAL token cache managed by MSAL" : previousState.keychainStatus,
      tokenStoreStatus: isRealAuth && result.status == .connected ? .mockTokenReferenceAvailable : previousState.tokenStoreStatus,
      tokenStoreDetail: isRealAuth && result.status == .connected ? "MSAL completed sign-in and manages its own token cache. ParcelOps did not write token values, auth codes, passwords, or client secrets to JSON." : previousState.tokenStoreDetail,
      detailText: completionDetail
    )
    microsoft365AuthSessionStates[connection.id] = state

    let summary: String
    switch result.status {
    case .connected:
      summary = isRealAuth ? "Real Microsoft 365 sign-in succeeded." : "Mock Microsoft 365 auth succeeded."
    case .notConfigured:
      summary = "Microsoft 365 auth not configured."
    case .authFailed:
      summary = isRealAuth ? "Real Microsoft 365 sign-in failed." : "Mock Microsoft 365 auth failed."
    case .consentRequired:
      summary = isRealAuth ? "Real Microsoft 365 sign-in requires consent or configuration review." : "Mock Microsoft 365 auth requires consent."
    case .tokenExpired:
      summary = "Microsoft 365 token state expired."
    case .notConnected:
      summary = "Microsoft 365 auth remains not connected."
    case .connecting:
      summary = isRealAuth ? "Real Microsoft 365 sign-in still in progress." : "Mock Microsoft 365 auth still in progress."
    }

    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: summary,
      afterDetail: microsoft365AuthSessionAuditDetail(state)
    )
  }

  private func completeTimedOutMicrosoft365AuthAttempt(connectionID: UUID, attemptID: UUID) {
    guard activeMicrosoft365AuthAttempts[connectionID] == attemptID,
          let connection = microsoft365MailboxConnections.first(where: { $0.id == connectionID }) else { return }

    let previousState = microsoft365AuthSessionState(for: connection)
    guard previousState.status == .connecting else {
      activeMicrosoft365AuthAttempts[connectionID] = nil
      return
    }

    activeMicrosoft365AuthAttempts[connectionID] = nil
    let state = Microsoft365AuthSessionState(
      connectionID: connectionID,
      status: .notConnected,
      signedInAccount: previousState.signedInAccount,
      lastAuthAttemptDate: previousState.lastAuthAttemptDate,
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      keychainStatus: previousState.keychainStatus,
      tokenStoreStatus: previousState.tokenStoreStatus,
      tokenStoreDetail: previousState.tokenStoreDetail,
      detailText: "Timeout: ParcelOps did not receive a final MSAL completion after the browser sign-in window returned or stalled. Try Test real Microsoft sign-in again from an active ParcelOps window. If this repeats, check callback routing, presentation window state, Xcode signing, and MSAL console diagnostics. No token values were stored in ParcelOps JSON and no Microsoft Graph mailbox call was made. Attempt ID: \(attemptID.uuidString)."
    )
    microsoft365AuthSessionStates[connectionID] = state
    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connectionID.uuidString,
      entityLabel: connection.displayName,
      summary: "Real Microsoft 365 sign-in timed out before completion.",
      afterDetail: microsoft365AuthSessionAuditDetail(state)
    )
  }

  private func microsoft365AuthCompletionDetail(for connection: Microsoft365MailboxConnection, result: Microsoft365AuthResult, isRealAuth: Bool, attemptID: UUID?) -> String {
    guard isRealAuth else { return result.detailText }

    let attemptText = attemptID.map { " Attempt ID: \($0.uuidString)." } ?? ""
    let completionText: String
    switch result.status {
    case .connected:
      completionText = "Completion: MSAL returned a real identity sign-in success for \(connection.displayName)."
    case .notConnected:
      completionText = "Completion: MSAL returned without connecting an account, usually because the user cancelled or closed the sign-in window."
    case .notConfigured:
      completionText = "Completion: ParcelOps did not start MSAL because required setup fields are missing."
    case .consentRequired:
      completionText = "Completion: MSAL returned a consent, conditional access, or tenant policy requirement."
    case .authFailed:
      completionText = "Completion: MSAL returned a sign-in failure."
    case .tokenExpired:
      completionText = "Completion: MSAL reported an expired token state."
    case .connecting:
      completionText = "Completion: MSAL still reports connecting."
    }

    return "\(completionText)\(attemptText)\n\(result.detailText)"
  }

  private func applyMicrosoft365TokenStoreResult(_ result: Microsoft365TokenStoreResult, to connection: Microsoft365MailboxConnection, summary: String) {
    let previousState = microsoft365AuthSessionState(for: connection)
    let keychainStatus: String
    switch result.status {
    case .keychainNotConfigured:
      keychainStatus = "Keychain not configured"
    case .mockTokenReferenceAvailable:
      keychainStatus = "Mock token reference available"
    case .tokenMissing:
      keychainStatus = "Token missing"
    case .tokenClearSimulated:
      keychainStatus = "Token clear simulated"
    case .storageErrorSimulated:
      keychainStatus = "Storage error simulated"
    }

    let state = Microsoft365AuthSessionState(
      connectionID: connection.id,
      status: previousState.status,
      signedInAccount: previousState.signedInAccount,
      lastAuthAttemptDate: previousState.lastAuthAttemptDate,
      lastSuccessfulAuthDate: previousState.lastSuccessfulAuthDate,
      keychainStatus: keychainStatus,
      tokenStoreStatus: result.status,
      tokenStoreDetail: result.detailText,
      detailText: previousState.detailText
    )
    microsoft365AuthSessionStates[connection.id] = state

    logAudit(
      action: .evaluated,
      entityType: .microsoft365MailboxConnection,
      entityID: connection.id.uuidString,
      entityLabel: connection.displayName,
      summary: summary,
      afterDetail: microsoft365TokenStoreAuditDetail(state)
    )
  }

  func microsoft365OAuthReadinessSummary(for connection: Microsoft365MailboxConnection) -> Microsoft365OAuthReadinessSummary {
    var missingFields: [String] = []
    if connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Tenant ID placeholder")
    }
    if connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Client ID placeholder")
    }
    if connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Redirect URI placeholder")
    }
    if connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Requested scopes summary")
    }

    let isReady = missingFields.isEmpty
    let statusText = isReady ? "Ready for future OAuth implementation" : "Missing \(missingFields.count) OAuth setup item\(missingFields.count == 1 ? "" : "s")"
    let detailText = isReady
      ? "Non-secret OAuth placeholders are complete for future implementation review."
      : "Missing: \(missingFields.joined(separator: ", "))"
    return Microsoft365OAuthReadinessSummary(
      connectionID: connection.id,
      isReady: isReady,
      missingFields: missingFields,
      statusText: statusText,
      detailText: detailText
    )
  }

  func microsoft365OAuthImplementationPlan(for connection: Microsoft365MailboxConnection) -> Microsoft365OAuthImplementationPlan {
    let trimmedTenant = connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedClient = connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedRedirect = connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedScopes = connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedNotes = connection.consentAdminNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowerScopes = trimmedScopes.lowercased()
    let hasClientID = !trimmedClient.isEmpty
    let hasTenantID = !trimmedTenant.isEmpty
    let hasRedirect = !trimmedRedirect.isEmpty
    let hasMailRead = lowerScopes.contains("mail.read")
    let hasConsentNotes = !trimmedNotes.isEmpty && !trimmedNotes.localizedCaseInsensitiveContains("local planning only")

    let items = [
      Microsoft365OAuthImplementationChecklistItem(
        title: "App registration created",
        isComplete: hasClientID,
        detail: hasClientID ? "Client ID placeholder is captured." : "Capture the app registration client ID placeholder first."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Tenant ID placeholder captured",
        isComplete: hasTenantID,
        detail: hasTenantID ? "Tenant ID placeholder is captured." : "Add a non-secret tenant ID placeholder."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Client ID placeholder captured",
        isComplete: hasClientID,
        detail: hasClientID ? "Client ID placeholder is captured." : "Add a non-secret client ID placeholder."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Redirect URI decided",
        isComplete: hasRedirect,
        detail: hasRedirect ? connection.redirectURIPlaceholder : "Choose the future redirect URI placeholder."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Mail.Read scope planned",
        isComplete: hasMailRead,
        detail: hasMailRead ? connection.requestedScopesSummary : "Add Mail.Read to the requested scopes summary."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Admin/user consent notes captured",
        isComplete: hasConsentNotes,
        detail: hasConsentNotes ? connection.consentAdminNotes : "Capture admin or user consent notes without secrets."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Token storage decision pending",
        isComplete: false,
        detail: "Pending future decision. MSAL cache entitlement is configured, but ParcelOps custom token storage is not implemented."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Refresh strategy pending",
        isComplete: false,
        detail: "Pending future decision. Background sync is not implemented yet."
      ),
      Microsoft365OAuthImplementationChecklistItem(
        title: "Error handling/audit strategy pending",
        isComplete: false,
        detail: "Pending future decision. Current audit events are local planning records only."
      )
    ]

    let completedCount = items.filter(\.isComplete).count
    let statusText = "\(completedCount)/\(items.count) OAuth implementation planning items ready"
    return Microsoft365OAuthImplementationPlan(
      connectionID: connection.id,
      statusText: statusText,
      completedCount: completedCount,
      totalCount: items.count,
      items: items
    )
  }

  func gmailOAuthReadinessSummary(for connection: GmailMailboxConnection) -> GmailOAuthReadinessSummary {
    var missingFields: [String] = []
    let clientID = (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let redirectValue = (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let redirectScheme = gmailRedirectScheme(from: redirectValue)
    let expectedScheme = gmailExpectedRedirectScheme(for: clientID)
    if connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Gmail address")
    }
    if connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Monitored labels")
    }
    if (connection.googleCloudProjectHint ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Google Cloud project hint")
    }
    if clientID.isEmpty {
      missingFields.append("Google OAuth iOS client ID")
    } else if gmailClientIDIsPlaceholder(clientID) {
      missingFields.append("Real Google OAuth iOS client ID; placeholder is still saved")
    } else if gmailExpectedRedirectScheme(for: clientID) == nil {
      missingFields.append("Google OAuth iOS client ID ending in .apps.googleusercontent.com")
    }
    if redirectScheme.isEmpty {
      missingFields.append("Reversed Google client ID URL scheme")
    } else if gmailCallbackSchemeIsPlaceholder(redirectScheme) {
      missingFields.append("Real Gmail callback URL scheme; placeholder is still saved")
    } else if !redirectScheme.hasPrefix("com.googleusercontent.apps.") {
      missingFields.append("Gmail callback URL scheme starting with com.googleusercontent.apps.")
    }
    if let expectedScheme,
       !redirectScheme.isEmpty,
       !gmailCallbackSchemeIsPlaceholder(redirectScheme),
       redirectScheme != expectedScheme {
      missingFields.append("Gmail callback URL scheme matching the reversed Google OAuth client ID")
    }
    if connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Requested scopes summary")
    }
    if (connection.consentScreenNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Consent screen notes")
    }
    if connection.credentialStorageStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Token storage decision")
    }

    let lowerScopes = connection.requestedScopesSummary.lowercased()
    if !lowerScopes.contains("gmail.readonly") && !lowerScopes.contains("gmail.metadata") {
      missingFields.append("Read-only Gmail scope")
    }
    let bundleClientID = (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let compiledClientIDStatus: String
    if bundleClientID.isEmpty {
      missingFields.append("Compiled App Info.plist GIDClientID")
      compiledClientIDStatus = "Missing compiled GIDClientID"
    } else if gmailClientIDIsPlaceholder(bundleClientID) {
      missingFields.append("Compiled App Info.plist GIDClientID replacing the placeholder")
      compiledClientIDStatus = "Compiled GIDClientID is still placeholder"
    } else if !clientID.isEmpty, !gmailClientIDIsPlaceholder(clientID), bundleClientID != clientID {
      missingFields.append("Compiled App Info.plist GIDClientID matching this Gmail setup")
      compiledClientIDStatus = "Compiled GIDClientID does not match saved setup"
    } else if !clientID.isEmpty, bundleClientID == clientID {
      compiledClientIDStatus = "Compiled GIDClientID matches saved setup"
    } else {
      compiledClientIDStatus = "Compiled GIDClientID present"
    }
    let bundleSchemes = gmailBundleURLSchemes()
    let compiledCallbackSchemeStatus: String
    if !redirectScheme.isEmpty,
       !gmailCallbackSchemeIsPlaceholder(redirectScheme),
       !bundleSchemes.contains(redirectScheme) {
      missingFields.append("Compiled App Info.plist Gmail callback URL scheme")
      compiledCallbackSchemeStatus = "Compiled callback scheme does not include saved setup scheme"
    } else if !redirectScheme.isEmpty, bundleSchemes.contains(redirectScheme) {
      compiledCallbackSchemeStatus = "Compiled callback scheme includes saved setup scheme"
    } else if bundleSchemes.isEmpty {
      compiledCallbackSchemeStatus = "No compiled callback URL schemes found"
    } else {
      compiledCallbackSchemeStatus = "Compiled callback URL schemes present"
    }
    if bundleSchemes.contains(GoogleGmailAuthAdapter.placeholderCallbackScheme),
       !bundleSchemes.contains(redirectScheme) {
      missingFields.append("Compiled App Info.plist replacing the placeholder Gmail callback scheme")
    }

    let isReady = missingFields.isEmpty
    let statusText = isReady ? "Ready for real Gmail sign-in test" : "Missing \(missingFields.count) Gmail setup item\(missingFields.count == 1 ? "" : "s")"
    let detailText = isReady
      ? "Gmail setup values and compiled app callback configuration are ready for the explicit real sign-in test."
      : "Missing: \(missingFields.joined(separator: ", "))"
    return GmailOAuthReadinessSummary(
      connectionID: connection.id,
      isReady: isReady,
      missingFields: missingFields,
      statusText: statusText,
      detailText: detailText,
      compiledClientIDStatus: compiledClientIDStatus,
      compiledCallbackSchemeStatus: bundleSchemes.contains(GoogleGmailAuthAdapter.placeholderCallbackScheme) && !bundleSchemes.contains(redirectScheme)
        ? "Compiled callback scheme is still placeholder"
        : compiledCallbackSchemeStatus,
      expectedCallbackScheme: expectedScheme ?? "Expected callback scheme unknown until a valid Google iOS client ID is saved"
    )
  }

  func gmailOAuthImplementationPlan(for connection: GmailMailboxConnection) -> GmailOAuthImplementationPlan {
    let trimmedEmail = connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLabels = connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedScopes = connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedNotes = connection.setupNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    let projectHint = (connection.googleCloudProjectHint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let clientID = (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let redirectURI = (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let consentNotes = (connection.consentScreenNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let lowerScopes = trimmedScopes.lowercased()
    let hasEmail = !trimmedEmail.isEmpty
    let hasLabels = !trimmedLabels.isEmpty
    let hasProjectHint = !projectHint.isEmpty
    let hasClientID = !clientID.isEmpty
    let hasRedirectURI = !redirectURI.isEmpty
    let hasReadonlyScope = lowerScopes.contains("gmail.readonly") || lowerScopes.contains("gmail.metadata")
    let hasConsentNotes = !consentNotes.isEmpty && !consentNotes.localizedCaseInsensitiveContains("placeholder")
    let hasCredentialPlan = !connection.credentialStorageStatus.localizedCaseInsensitiveContains("not configured")
      && !connection.credentialStorageStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let hasSetupNotes = !trimmedNotes.isEmpty && !trimmedNotes.localizedCaseInsensitiveContains("placeholder")

    let items = [
      GmailOAuthImplementationChecklistItem(
        title: "Google Cloud project identified",
        isComplete: hasProjectHint,
        detail: hasProjectHint ? projectHint : "Capture the Google Cloud project name or hint without secrets."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Google OAuth iOS client ID captured",
        isComplete: hasClientID && !gmailClientIDIsPlaceholder(clientID) && gmailExpectedRedirectScheme(for: clientID) != nil,
        detail: hasClientID ? "Use the iOS OAuth client ID from Google Cloud. It should end in .apps.googleusercontent.com. Do not enter a client secret." : "Capture the iOS OAuth client ID from Google Cloud."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Reversed client ID URL scheme registered",
        isComplete: hasRedirectURI && !gmailCallbackSchemeIsPlaceholder(gmailRedirectScheme(from: redirectURI)) && gmailExpectedRedirectScheme(for: clientID) == gmailRedirectScheme(from: redirectURI),
        detail: hasRedirectURI ? "Expected scheme: \(gmailExpectedRedirectScheme(for: clientID) ?? "unknown"). Saved scheme: \(gmailRedirectScheme(from: redirectURI))." : "Capture the reversed client ID URL scheme from the Google iOS OAuth client."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Gmail account captured",
        isComplete: hasEmail,
        detail: hasEmail ? connection.emailAddress : "Add the Gmail or Google Workspace mailbox address."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Monitored labels captured",
        isComplete: hasLabels,
        detail: hasLabels ? connection.monitoredLabelNames : "Add Gmail labels such as INBOX or Order Updates."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Read-only Gmail scope planned",
        isComplete: hasReadonlyScope,
        detail: hasReadonlyScope ? connection.requestedScopesSummary : "Plan a read-only Gmail scope such as gmail.readonly before real API work."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "OAuth consent screen notes captured",
        isComplete: hasConsentNotes || hasSetupNotes,
        detail: hasConsentNotes ? consentNotes : "Capture consent screen notes without client secrets or tokens."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Token storage decision pending",
        isComplete: hasCredentialPlan,
        detail: hasCredentialPlan ? connection.credentialStorageStatus : "Pending future decision. No Gmail token storage or Keychain token item is implemented."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Manual refresh strategy selected",
        isComplete: true,
        detail: "Manual refresh only. Background sync and notifications remain out of scope."
      ),
      GmailOAuthImplementationChecklistItem(
        title: "Mock fallback remains available",
        isComplete: true,
        detail: "Mock Gmail refresh remains available for testing local intake without Google access."
      )
    ]

    let completedCount = items.filter(\.isComplete).count
    return GmailOAuthImplementationPlan(
      connectionID: connection.id,
      statusText: "\(completedCount)/\(items.count) Gmail OAuth planning items ready",
      completedCount: completedCount,
      totalCount: items.count,
      items: items
    )
  }

  func gmailSetupTestChecklist(for connection: GmailMailboxConnection) -> GmailSetupTestChecklist {
    let authState = gmailAuthSessionState(for: connection)
    let trimmedEmail = connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLabels = connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines)
    let clientID = (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let redirectScheme = gmailRedirectScheme(from: (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    let expectedRedirectScheme = gmailExpectedRedirectScheme(for: clientID)
    let hasMailboxSettings = !trimmedEmail.isEmpty && !trimmedLabels.isEmpty
    let hasOAuthAppConfig = !gmailClientIDIsPlaceholder(clientID) &&
      expectedRedirectScheme != nil &&
      !gmailCallbackSchemeIsPlaceholder(redirectScheme) &&
      expectedRedirectScheme == redirectScheme
    let hasReadonlyScope = connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.readonly") ||
      connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.metadata")
    let hasSignedIn = authState.status == .connected
    let hasRealRefresh = connection.connectionStatus.localizedCaseInsensitiveContains("Real Gmail")
    let hasFetched = connection.lastRefreshFetchedCount > 0
    let hasUsefulResult = connection.lastRefreshImportedCount > 0 ||
      connection.lastRefreshFilteredNonOrderCount > 0 ||
      (connection.lastRefreshUncertainCount ?? 0) > 0 ||
      connection.connectionStatus.localizedCaseInsensitiveContains("No messages")
    let needsReview = connection.lastRefreshImportedCount > 0 ||
      (connection.lastRefreshUncertainCount ?? 0) > 0

    let items = [
      GmailSetupTestChecklistItem(
        title: "Confirm mailbox settings",
        isComplete: hasMailboxSettings,
        detail: hasMailboxSettings ? "\(connection.emailAddress) using labels \(connection.monitoredLabelNames)." : "Add the Gmail address and monitored label, usually INBOX.",
        nextAction: hasMailboxSettings ? "No action needed unless the label is wrong." : "Use Edit setup.",
        symbolName: "envelope.badge"
      ),
      GmailSetupTestChecklistItem(
        title: "Confirm Google app placeholders",
        isComplete: hasOAuthAppConfig && hasReadonlyScope,
        detail: hasOAuthAppConfig && hasReadonlyScope ? "Google iOS OAuth client ID, reversed callback scheme, and read-only Gmail scope are structurally ready." : "Add the real Google iOS OAuth client ID, matching reversed callback scheme, and gmail.readonly or gmail.metadata scope.",
        nextAction: hasOAuthAppConfig && hasReadonlyScope ? "Proceed to sign-in test after compiled app plist values also match." : "Use Edit setup and save non-secret values only.",
        symbolName: "gearshape.2.fill"
      ),
      GmailSetupTestChecklistItem(
        title: "Test real Google sign-in",
        isComplete: hasSignedIn,
        detail: hasSignedIn ? "Google sign-in succeeded for \(authState.signedInAccount)." : "No connected Google sign-in is recorded for this setup.",
        nextAction: hasSignedIn ? "Proceed to real refresh." : "Tap Test real Google sign-in.",
        symbolName: "person.badge.key"
      ),
      GmailSetupTestChecklistItem(
        title: "Run manual real Gmail refresh",
        isComplete: hasRealRefresh,
        detail: hasRealRefresh ? connection.connectionStatus : "Real refresh has not been run for this setup record.",
        nextAction: hasRealRefresh ? "Review the latest refresh summary." : "Tap Run real Gmail refresh.",
        symbolName: "tray.and.arrow.down"
      ),
      GmailSetupTestChecklistItem(
        title: "Review refresh result",
        isComplete: hasUsefulResult || hasFetched,
        detail: "\(connection.lastRefreshFetchedCount) fetched, \(connection.lastRefreshImportedCount) imported, \(connection.lastRefreshDuplicateCount) duplicates, \(connection.lastRefreshFilteredNonOrderCount) filtered, \(connection.lastRefreshUncertainCount ?? 0) uncertain.",
        nextAction: needsReview ? "Open Inbox/Mailbox review for imported or uncertain messages." : "If nothing imported, check label, mixed filtering, and Audit diagnostics.",
        symbolName: "line.3.horizontal.decrease.circle"
      ),
      GmailSetupTestChecklistItem(
        title: "Confirm audit trail",
        isComplete: hasRealRefresh,
        detail: hasRealRefresh ? "Audit has a real Gmail refresh event for the latest attempt." : "Audit will record sign-in and refresh actions after they run.",
        nextAction: "Open Audit when detailed diagnostics are needed.",
        symbolName: "list.clipboard.fill"
      )
    ]

    let completedCount = items.filter(\.isComplete).count
    return GmailSetupTestChecklist(
      connectionID: connection.id,
      statusText: "\(completedCount)/\(items.count) Gmail setup test steps complete",
      completedCount: completedCount,
      totalCount: items.count,
      items: items
    )
  }

  private func gmailRedirectScheme(from value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return ""
    }
    if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
      return scheme
    }
    if let scheme = trimmed.components(separatedBy: "://").first, scheme != trimmed {
      return scheme
    }
    if let scheme = trimmed.components(separatedBy: ":").first, scheme != trimmed {
      return scheme
    }
    return trimmed
  }

  private func gmailExpectedRedirectScheme(for clientID: String) -> String? {
    let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    let suffix = ".apps.googleusercontent.com"
    guard trimmed.hasSuffix(suffix), trimmed.count > suffix.count else {
      return nil
    }
    return "com.googleusercontent.apps.\(trimmed.dropLast(suffix.count))"
  }

  private func gmailClientIDIsPlaceholder(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ||
      trimmed == GoogleGmailAuthAdapter.placeholderClientID ||
      trimmed.localizedCaseInsensitiveContains("placeholder") ||
      trimmed.localizedCaseInsensitiveContains("replace_before_real")
  }

  private func gmailCallbackSchemeIsPlaceholder(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ||
      trimmed == GoogleGmailAuthAdapter.placeholderCallbackScheme ||
      trimmed.localizedCaseInsensitiveContains("parcelops-placeholder") ||
      trimmed.localizedCaseInsensitiveContains("placeholder")
  }

  private func gmailBundleURLSchemes() -> [String] {
    guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
      return []
    }
    return urlTypes.flatMap { entry -> [String] in
      (entry["CFBundleURLSchemes"] as? [String]) ?? []
    }
  }

  private func trackedMailbox(for connection: Microsoft365MailboxConnection) -> TrackedMailbox {
    TrackedMailbox(
      id: connection.id,
      address: connection.mailboxAddress,
      provider: .microsoft365,
      monitoredFolders: connection.monitoredFolderNames,
      status: "Local simulated refresh only",
      lastChecked: Self.auditTimestamp(),
      routingRule: connection.displayName
    )
  }

  private func trackedMailbox(for connection: SpaceMailIMAPConnection) -> TrackedMailbox {
    TrackedMailbox(
      id: connection.id,
      address: connection.emailAddressUsername,
      provider: .imap,
      monitoredFolders: connection.folderName,
      status: "SpaceMail IMAP manual refresh",
      lastChecked: Self.auditTimestamp(),
      routingRule: connection.displayName
    )
  }

  private func trackedMailbox(for connection: GmailMailboxConnection) -> TrackedMailbox {
    TrackedMailbox(
      id: connection.id,
      address: connection.emailAddress,
      provider: .gmail,
      monitoredFolders: connection.monitoredLabelNames,
      status: connection.connectionStatus,
      lastChecked: connection.lastManualRefreshDate,
      routingRule: "Gmail labels: \(connection.monitoredLabelNames)"
    )
  }

  private func upsertTrackedMailbox(_ mailbox: TrackedMailbox) {
    if let index = mailboxes.firstIndex(where: { $0.id == mailbox.id }) {
      mailboxes[index] = mailbox
    } else {
      mailboxes.insert(mailbox, at: 0)
    }
    persistIntegrations()
  }

  private func microsoft365MailboxConnectionAuditDetail(_ connection: Microsoft365MailboxConnection) -> String {
    let readiness = microsoft365OAuthReadinessSummary(for: connection)
    let plan = microsoft365OAuthImplementationPlan(for: connection)
    return "Display name: \(connection.displayName)\nTenant/domain hint: \(connection.tenantDomainHint)\nMailbox: \(connection.mailboxAddress)\nFolders: \(connection.monitoredFolderNames)\nStatus: \(connection.connectionStatus)\nLast manual refresh: \(connection.lastManualRefreshDate)\nReview: \(connection.reviewState.rawValue)\nNotes: \(connection.setupNotes)\nOAuth readiness: \(readiness.statusText)\nOAuth implementation plan: \(plan.statusText)\nTenant ID placeholder: \(connection.tenantIDPlaceholder)\nClient ID placeholder: \(connection.clientIDPlaceholder)\nRedirect URI placeholder: \(connection.redirectURIPlaceholder)\nScopes: \(connection.requestedScopesSummary)\nConsent/admin notes: \(connection.consentAdminNotes)\nNo OAuth, token, client secret, password, Keychain item, or Microsoft Graph connection is stored."
  }

  private func spaceMailIMAPConnectionAuditDetail(_ connection: SpaceMailIMAPConnection) -> String {
    "Display name: \(connection.displayName)\nEmail/username: \(connection.emailAddressUsername)\nIMAP host: \(connection.imapHost)\nIMAP port: \(connection.imapPort)\nSecurity: \(connection.securityMode)\nFolder: \(connection.folderName)\nMailbox mode: \(connection.mailboxMode.rawValue)\nTrusted sender hints: \(connection.trustedSenderHints.joined(separator: ", "))\nImport keyword hints: \(connection.importKeywordHints.joined(separator: ", "))\nUncertain keyword hints: \(connection.uncertainKeywordHints.joined(separator: ", "))\nFilter keyword hints: \(connection.filterKeywordHints.joined(separator: ", "))\nStatus: \(connection.connectionStatus)\nLast manual refresh: \(connection.lastManualRefreshDate)\nCredential storage: \(connection.credentialStorageStatus)\nReview: \(connection.reviewState.rawValue)\nNotes: \(connection.setupNotes)\nNo password, app password, token, Keychain item, raw IMAP session content, or full mailbox content is stored in this setup record."
  }

  private func gmailMailboxConnectionAuditDetail(_ connection: GmailMailboxConnection) -> String {
    "Display name: \(connection.displayName)\nEmail: \(connection.emailAddress)\nLabels: \(connection.monitoredLabelNames)\nMailbox mode: \(connection.mailboxMode.rawValue)\nStatus: \(connection.connectionStatus)\nLast manual refresh: \(connection.lastManualRefreshDate)\nOAuth readiness: \(connection.oauthReadinessStatus)\nGoogle Cloud project hint: \(connection.googleCloudProjectHint ?? "")\nOAuth client ID placeholder: \(connection.oauthClientIDPlaceholder ?? "")\nRedirect URI placeholder: \(connection.redirectURIPlaceholder ?? "")\nScopes: \(connection.requestedScopesSummary)\nConsent notes: \(connection.consentScreenNotes ?? "")\nCredential storage: \(connection.credentialStorageStatus)\nReview: \(connection.reviewState.rawValue)\nNotes: \(connection.setupNotes)\nLast refresh: \(connection.lastRefreshSummary)\nNo OAuth token, refresh token, auth code, client secret, password, Keychain item, Gmail API response, raw Gmail message, or full mailbox content is stored in this setup record."
  }

  private func spaceMailCredentialStoreAuditDetail(_ result: SpaceMailCredentialStoreResult, connection: SpaceMailIMAPConnection) -> String {
    "Display name: \(connection.displayName)\nEmail/username: \(connection.emailAddressUsername)\nCredential status: \(result.status.rawValue)\nDetail: \(result.detailText)\nNo passwords, app passwords, tokens, auth strings, server credentials, or Keychain items are created, read, written, deleted, stored in JSON, or logged."
  }

  private func microsoft365OAuthImplementationPlanAuditDetail(_ plan: Microsoft365OAuthImplementationPlan) -> String {
    let itemText = plan.items
      .map { item in "\(item.isComplete ? "Complete" : "Pending"): \(item.title) - \(item.detail)" }
      .joined(separator: "\n")
    return "\(plan.statusText)\n\(itemText)\nNo OAuth flow ran from this planning action, no browser auth opened, no tokens were requested or stored by ParcelOps, and no custom Keychain token store was used."
  }

  private func gmailOAuthImplementationPlanAuditDetail(_ plan: GmailOAuthImplementationPlan) -> String {
    let itemText = plan.items
      .map { item in "\(item.isComplete ? "Complete" : "Pending"): \(item.title) - \(item.detail)" }
      .joined(separator: "\n")
    return "\(plan.statusText)\n\(itemText)\nNo Google OAuth flow ran from this planning action, no browser auth opened, no access token or refresh token was requested or stored, no Gmail API call was made, and no mailbox item was changed."
  }

  private func gmailAuthSessionAuditDetail(_ state: GmailAuthSessionState) -> String {
    "Auth status: \(state.status.rawValue)\nSigned-in account: \(state.signedInAccount)\nLast auth attempt: \(state.lastAuthAttemptDate)\nLast successful auth: \(state.lastSuccessfulAuthDate)\nToken store status: \(state.tokenStoreStatus)\nToken store detail: \(state.tokenStoreDetail)\nDetail: \(state.detailText)\nNo Google access token, refresh token, auth code, callback URL, client secret, password, raw Gmail message, or mailbox content is stored in ParcelOps JSON or audit logs."
  }

  private func gmailTokenStoreAuditDetail(_ state: GmailAuthSessionState) -> String {
    "Token store status: \(state.tokenStoreStatus)\nDetail: \(state.tokenStoreDetail)\nNo Google access token, refresh token, auth code, callback URL, client secret, password, Keychain item, raw Gmail message, or mailbox content was created, read, written, deleted, stored in JSON, or logged."
  }

  private func microsoft365AuthSessionAuditDetail(_ state: Microsoft365AuthSessionState) -> String {
    "Auth status: \(state.status.rawValue)\nSigned-in account: \(state.signedInAccount)\nLast auth attempt: \(state.lastAuthAttemptDate)\nLast successful auth: \(state.lastSuccessfulAuthDate)\nKeychain status: \(state.keychainStatus)\nToken store status: \(state.tokenStoreStatus.rawValue)\nToken store detail: \(state.tokenStoreDetail)\nDetail: \(state.detailText)\nNo token values, auth codes, client secrets, passwords, or callback URLs are stored in ParcelOps JSON or audit logs. Microsoft Graph mailbox reading only runs from the separate manual refresh action."
  }

  private func microsoft365TokenStoreAuditDetail(_ state: Microsoft365AuthSessionState) -> String {
    "Token store status: \(state.tokenStoreStatus.rawValue)\nKeychain status: \(state.keychainStatus)\nDetail: \(state.tokenStoreDetail)\nNo access token, refresh token, auth code, client secret, password, or Keychain item was created, read, written, or deleted."
  }

  private func appendSystemContact(_ summary: String, evidence: String) {
    guard !orders.isEmpty else { return }
    orders[0].contactHistory.insert(ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "System action", summary: summary, evidence: evidence, reviewState: .monitor), at: 0)
    persistOrders()
  }

  private func persistOrders() {
    orderRepository.saveOrders(orders)
  }

  private func persistMailEvents() {
    mailEventRepository.saveMailEvents(mailEvents)
  }

  private func persistIntakeEmails() {
    intakeEmailRepository.saveIntakeEmails(intakeEmails)
  }

  private func persistMailboxIngestRecords() {
    mailboxIngestRepository.saveMailboxIngestRecords(mailboxIngestRecords)
  }

  private func persistIntegrations() {
    integrationRepository.saveMailboxes(mailboxes)
    integrationRepository.saveMicrosoft365MailboxConnections(microsoft365MailboxConnections)
    integrationRepository.saveSpaceMailIMAPConnections(spaceMailIMAPConnections)
    integrationRepository.saveGmailMailboxConnections(gmailMailboxConnections)
    integrationRepository.saveShopifyConnections(shopifyConnections)
    integrationRepository.saveWatchedFolders(watchedFolders)
    integrationRepository.saveSourceConnections(connections)
  }

  private func persistWishlist() {
    wishlistRepository.saveWishlistItems(wishlistItems)
    wishlistRepository.saveDeletedWishlistItems(deletedWishlistItems)
  }

  private func persistEvidenceAttachments() {
    evidenceRepository.saveEvidenceAttachments(evidenceAttachments)
  }

  private func persistCarrierTrackingEvents() {
    trackingRepository.saveCarrierTrackingEvents(carrierTrackingEvents)
  }

  private func persistAutomationRules() {
    automationRuleRepository.saveAutomationRules(automationRules)
  }

  private func persistSavedFilters() {
    savedFilterRepository.saveSavedFilters(savedFilters)
  }

  private func persistReviewTasks() {
    reviewTaskRepository.saveReviewTasks(reviewTasks)
  }

  private func persistHandoffNotes() {
    handoffNoteRepository.saveHandoffNotes(handoffNotes)
  }

  private func persistSLAPolicies() {
    slaPolicyRepository.saveSLAPolicies(slaPolicies)
  }

  private func persistExceptionPlaybooks() {
    exceptionPlaybookRepository.saveExceptionPlaybooks(exceptionPlaybooks)
  }

  private func persistCommunicationTemplates() {
    communicationRepository.saveCommunicationTemplates(communicationTemplates)
  }

  private func persistDraftMessages() {
    communicationRepository.saveDraftMessages(draftMessages)
  }

  private func persistContactDirectoryEntries() {
    contactDirectoryRepository.saveContactDirectoryEntries(contactDirectoryEntries)
  }

  private func persistCustomerRecipientProfiles() {
    customerRecipientProfileRepository.saveCustomerRecipientProfiles(customerRecipientProfiles)
  }

  private func persistDestinationAddresses() {
    destinationAddressRepository.saveDestinationAddresses(destinationAddresses)
  }

  private func persistDeliveryInstructions() {
    deliveryInstructionRepository.saveDeliveryInstructions(deliveryInstructions)
  }

  private func persistPackageContents() {
    packageContentRepository.savePackageContents(packageContents)
  }

  private func persistCostRecords() {
    costRecordRepository.saveCostRecords(costRecords)
  }

  private func persistReturnClaims() {
    returnClaimRepository.saveReturnClaims(returnClaims)
  }

  private func persistProcurementRequests() {
    procurementRequestRepository.saveProcurementRequests(procurementRequests)
  }

  private func persistReceivingInspections() {
    receivingInspectionRepository.saveReceivingInspections(receivingInspections)
  }

  private func persistInventoryReceipts() {
    inventoryReceiptRepository.saveInventoryReceipts(inventoryReceipts)
  }

  private func persistStorageLocations() {
    storageLocationRepository.saveStorageLocations(storageLocations)
  }

  private func persistCustodyRecords() {
    custodyRepository.saveCustodyRecords(custodyRecords)
  }

  private func persistLabelReferenceRecords() {
    labelReferenceRepository.saveLabelReferenceRecords(labelReferenceRecords)
  }

  private func persistScanSessionRecords() {
    scanSessionRepository.saveScanSessionRecords(scanSessionRecords)
  }

  private func persistShipmentManifestRecords() {
    shipmentManifestRepository.saveShipmentManifestRecords(shipmentManifestRecords)
  }

  private func persistDispatchReadinessChecklists() {
    dispatchReadinessRepository.saveDispatchReadinessChecklists(dispatchReadinessChecklists)
  }

  private func persistAccountCredentialRecords() {
    accountCredentialRepository.saveAccountCredentialRecords(accountCredentialRecords)
  }

  private func persistVendorProfiles() {
    vendorProfileRepository.saveVendorProfiles(vendorProfiles)
  }

  private func persistShipmentGroups() {
    shipmentGroupRepository.saveShipmentGroups(shipmentGroups)
  }

  private func persistImportQueueItems() {
    importQueueRepository.saveImportQueueItems(importQueueItems)
  }

  private func persistAcceptanceRecords() {
    acceptanceRepository.saveAcceptanceRecords(acceptanceRecords)
  }

  private func addReviewTask(_ task: ReviewTask, summary: String) {
    reviewTasks.insert(task, at: 0)
    persistReviewTasks()
    logAudit(
      action: .created,
      entityType: .reviewTask,
      entityID: task.id.uuidString,
      entityLabel: task.title,
      summary: summary,
      afterDetail: task.auditDetail
    )
  }

  private func updateDraftMessageState(
    _ draft: DraftMessage,
    status: DraftMessageStatus,
    reviewState: ReviewState,
    action: AuditAction,
    summary: String
  ) {
    guard let index = draftMessages.firstIndex(where: { $0.id == draft.id }) else { return }
    let beforeDetail = draftMessages[index].auditDetail
    draftMessages[index].status = status
    draftMessages[index].reviewState = reviewState
    persistDraftMessages()
    logAudit(
      action: action,
      entityType: .draftMessage,
      entityID: draftMessages[index].id.uuidString,
      entityLabel: draftMessages[index].subject,
      summary: summary,
      beforeDetail: beforeDetail,
      afterDetail: draftMessages[index].auditDetail
    )
  }

  private func updateIntakeEmail(_ email: ForwardedEmailIntake, reviewState: IntakeEmailReviewState) {
    guard let index = intakeEmails.firstIndex(where: { $0.id == email.id }) else { return }
    let beforeDetail = intakeEmails[index].auditDetail
    intakeEmails[index].reviewState = reviewState
    persistIntakeEmails()
    logAudit(
      action: reviewState == .ignored ? .ignored : .reviewed,
      entityType: .intakeEmail,
      entityID: intakeEmails[index].id.uuidString,
      entityLabel: intakeEmails[index].auditLabel,
      summary: reviewState == .ignored ? "Forwarded intake email ignored." : "Forwarded intake email marked reviewed.",
      beforeDetail: beforeDetail,
      afterDetail: intakeEmails[index].auditDetail
    )
  }

  private func logAudit(
    action: AuditAction,
    entityType: AuditEntityType,
    entityID: String,
    entityLabel: String,
    summary: String,
    beforeDetail: String? = nil,
    afterDetail: String? = nil
  ) {
    auditEvents.insert(
      AuditEvent(
        timestamp: Self.auditTimestamp(),
        actor: "Local user",
        action: action,
        entityType: entityType,
        entityID: entityID,
        entityLabel: entityLabel,
        summary: summary,
        beforeDetail: beforeDetail,
        afterDetail: afterDetail
      ),
      at: 0
    )
    auditRepository.saveAuditEvents(auditEvents)
  }

  private static func auditTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: Date())
  }
}

private extension String {
  var isPlaceholder: Bool {
    let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty || normalized == "pending" || normalized == "not detected"
  }

  var normalizedSearchText: String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }
}

private extension IntakeEmailReviewState {
  var searchReviewState: ReviewState {
    switch self {
    case .needsReview: .needsReview
    case .reviewed: .accepted
    case .ignored: .monitor
    }
  }

  var acceptanceDecision: AcceptanceDecision {
    switch self {
    case .needsReview: .ready
    case .reviewed: .accepted
    case .ignored: .ignored
    }
  }
}

private extension ImportStatus {
  var acceptanceDecision: AcceptanceDecision {
    switch self {
    case .staged, .linked: .ready
    case .accepted: .accepted
    case .ignored: .ignored
    case .blocked: .blocked
    case .reopened: .reopened
    }
  }
}

private extension ForwardedEmailIntake {
  var localAcceptanceConfidence: Int {
    var score = 90
    if detectedMerchant.isPlaceholder { score -= 18 }
    if detectedOrderNumber.isPlaceholder { score -= 18 }
    if detectedTrackingNumber.isPlaceholder { score -= 12 }
    if detectedDestinationAddress.isPlaceholder { score -= 16 }
    if linkedOrderID == nil { score -= 8 }
    if reviewState == .needsReview { score -= 6 }
    return max(10, min(100, score))
  }
}

private extension SearchResult {
  var searchableText: String {
    "\(entityType.rawValue) \(title) \(subtitle) \(detail) \(severity?.rawValue ?? "") \(reviewState?.rawValue ?? "") \(linkedEntityID)"
  }
}

private extension TrackedOrder {
  var auditDetail: String {
    "Store: \(store); order: \(orderNumber); customer: \(customer); recipient: \(recipientEmail); fulfillment: \(fulfillment.rawValue); carrier: \(carrier); tracking: \(trackingNumber); destination: \(destination); status: \(status.rawValue); review: \(reviewState.rawValue)."
  }
}

private extension ForwardedEmailIntake {
  var auditLabel: String {
    detectedOrderNumber.isPlaceholder ? subject : detectedOrderNumber
  }

  var auditDetail: String {
    "Sender: \(sender); subject: \(subject); merchant: \(detectedMerchant); order: \(detectedOrderNumber); tracking: \(detectedTrackingNumber); destination: \(detectedDestinationAddress); review: \(reviewState.rawValue)."
  }
}

private extension EvidenceAttachment {
  var auditDetail: String {
    "File: \(fileName); type: \(fileType); source: \(source.rawValue); linked: \(linkedEntityType.rawValue) \(linkedEntityID.uuidString); review: \(reviewState.rawValue); path: \(localFilePath)."
  }
}

private extension CarrierTrackingEvent {
  var auditDetail: String {
    "Carrier: \(carrier); tracking: \(trackingNumber); time: \(eventTime); location: \(location); status: \(status); severity: \(severity.rawValue); source: \(source.rawValue); review: \(reviewState.rawValue)."
  }
}

private extension AutomationRule {
  var auditDetail: String {
    "Name: \(name); trigger: \(triggerType.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); last run: \(lastRunDate); runs: \(runCount); condition: \(conditionSummary); action: \(actionSummary)."
  }
}

private extension SavedFilter {
  var auditDetail: String {
    "Name: \(name); query: \(queryText.isEmpty ? "any" : queryText); entity: \(entityTypeFilter?.rawValue ?? "All"); review: \(reviewStateFilter?.rawValue ?? "All"); pinned: \(isPinned ? "yes" : "no"); created: \(createdDate)."
  }
}

private extension ReviewTask {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); priority: \(priority.rawValue); due: \(dueDate); assignee: \(assignee); status: \(status.rawValue); review: \(reviewState.rawValue); created: \(createdDate); completed: \(completedDate ?? "not completed"); summary: \(summary)."
  }

}

private extension HandoffNote {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); priority: \(priority.rawValue); assignee: \(assignee); created: \(createdDate); due: \(dueDate); status: \(status.rawValue); review: \(reviewState.rawValue); summary: \(summary); notes: \(notes)."
  }
}

private extension SLAPolicy {
  var auditDetail: String {
    "Name: \(name); linked: \(linkedEntityType.rawValue); priority: \(priority.rawValue); enabled: \(isEnabled ? "yes" : "no"); response: \(responseTarget); resolution: \(resolutionTarget); review: \(reviewState.rawValue); created: \(createdDate); last evaluated: \(lastEvaluatedDate); matches: \(matchCount); condition: \(conditionSummary)."
  }
}

private extension ExceptionPlaybook {
  var auditDetail: String {
    "Name: \(name); issue: \(issueType.rawValue); linked: \(linkedEntityType.rawValue); priority: \(priority.rawValue); enabled: \(isEnabled ? "yes" : "no"); escalation: \(escalationContact); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); usage: \(usageCount); trigger: \(triggerSummary); steps: \(recommendedSteps)."
  }
}

private extension CommunicationTemplate {
  var auditDetail: String {
    "Name: \(name); linked: \(linkedEntityType.rawValue); channel: \(channel.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last used: \(lastUsedDate); uses: \(usageCount); subject: \(subjectTemplate)."
  }
}

private extension DraftMessage {
  var auditDetail: String {
    "Subject: \(subject); recipient: \(recipient); channel: \(channel.rawValue); linked: \(linkedEntityType.rawValue) \(linkedEntityID); template: \(templateID?.uuidString ?? "none"); status: \(status.rawValue); review: \(reviewState.rawValue); created: \(createdDate)."
  }
}

private extension ContactDirectoryEntry {
  var auditDetail: String {
    "Name: \(name); organisation: \(organisation); role: \(role); email: \(email); phone: \(phone); channel: \(channelPreference.rawValue); linked: \(linkedEntityType.rawValue) \(linkedEntityID); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last contacted: \(lastContactedDate); notes: \(notes)."
  }
}

private extension CustomerRecipientProfile {
  var auditDetail: String {
    "Name: \(displayName); type: \(profileType.rawValue); organisation/team: \(organisationTeam); email: \(primaryEmail); phone: \(phone); destination: \(defaultDestinationAddress); preference: \(deliveryPreference.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); notes: \(notes)."
  }

  func matches(email: String, team: String, destination: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let emailMatch = !email.isEmpty && (primaryEmail.localizedCaseInsensitiveContains(email) || email.localizedCaseInsensitiveContains(primaryEmail))
    let teamMatch = !team.isEmpty && (organisationTeam.localizedCaseInsensitiveContains(team) || team.localizedCaseInsensitiveContains(organisationTeam) || displayName.localizedCaseInsensitiveContains(team) || team.localizedCaseInsensitiveContains(displayName))
    let destinationMatch = !destination.isEmpty && (defaultDestinationAddress.localizedCaseInsensitiveContains(destination) || destination.localizedCaseInsensitiveContains(defaultDestinationAddress))
    let linkedMatch = linkedEntityType == .customerProfile && id.uuidString == linkedEntityID
    return emailMatch || teamMatch || destinationMatch || linkedMatch
  }
}

private extension DestinationAddressRecord {
  var auditDetail: String {
    "Label: \(label); customer profile: \(customerProfileID?.uuidString ?? "none"); organisation/team: \(organisationTeam); address: \(addressLineSummary); city/region: \(cityRegion); country: \(country); preferred carrier: \(preferredCarrier); risk: \(riskLevel.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); instructions: \(deliveryInstructions); access: \(accessNotes)."
  }

  func matches(profileID: UUID?, destination: String, team: String, carrier: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let profileMatch = profileID != nil && customerProfileID == profileID
    let destinationMatch = !destination.isEmpty && (addressLineSummary.localizedCaseInsensitiveContains(destination) || cityRegion.localizedCaseInsensitiveContains(destination) || destination.localizedCaseInsensitiveContains(addressLineSummary) || destination.localizedCaseInsensitiveContains(cityRegion))
    let teamMatch = !team.isEmpty && (organisationTeam.localizedCaseInsensitiveContains(team) || team.localizedCaseInsensitiveContains(organisationTeam) || label.localizedCaseInsensitiveContains(team) || team.localizedCaseInsensitiveContains(label))
    let carrierMatch = !carrier.isEmpty && (preferredCarrier.localizedCaseInsensitiveContains(carrier) || carrier.localizedCaseInsensitiveContains(preferredCarrier))
    let linkedMatch = linkedEntityType == .destinationAddress && id.uuidString == linkedEntityID
    return profileMatch || destinationMatch || teamMatch || carrierMatch || linkedMatch
  }
}

private extension DeliveryInstructionRecord {
  var auditDetail: String {
    "Title: \(title); destination address: \(destinationAddressID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); linked: \(linkedEntityType.rawValue) \(linkedEntityID); type: \(instructionType.rawValue); preferred window: \(preferredDeliveryWindow); restricted window: \(restrictedDeliveryWindow); risk: \(riskLevel.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); instruction: \(instructionSummary); access: \(accessConstraintSummary); carrier notes: \(carrierNotes)."
  }

  func matches(destinationAddressID: UUID?, profileID: UUID?, context: String, carrier: String, riskLevel: ShipmentRiskLevel?, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let addressMatch = destinationAddressID != nil && self.destinationAddressID == destinationAddressID
    let profileMatch = profileID != nil && customerProfileID == profileID
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || instructionSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(instructionSummary)
      || accessConstraintSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(accessConstraintSummary)
    )
    let carrierMatch = !carrier.isEmpty && (carrierNotes.localizedCaseInsensitiveContains(carrier) || carrier.localizedCaseInsensitiveContains(carrierNotes))
    let riskMatch = riskLevel != nil && self.riskLevel == riskLevel
    return addressMatch || profileMatch || linkedMatch || contextMatch || carrierMatch || riskMatch
  }
}

private extension PackageContentRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); destination: \(destinationAddressID?.uuidString ?? "none"); instruction: \(deliveryInstructionID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); category: \(itemCategory.rawValue); value: \(valueBand.rawValue); quantity: \(verifiedQuantity)/\(expectedQuantity); verification: \(verificationStatus.rawValue); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); items: \(itemSummary); discrepancy: \(discrepancySummary)."
  }

  func matches(orderID: UUID?, shipmentGroupID: UUID?, destinationAddressID: UUID?, deliveryInstructionID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let destinationMatch = destinationAddressID != nil && self.destinationAddressID == destinationAddressID
    let instructionMatch = deliveryInstructionID != nil && self.deliveryInstructionID == deliveryInstructionID
    let profileMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || itemSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(itemSummary)
      || discrepancySummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(discrepancySummary)
    )
    return orderMatch || groupMatch || destinationMatch || instructionMatch || profileMatch || evidenceMatch || linkedMatch || contextMatch
  }
}

private extension CostRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); vendor profile: \(vendorProfileID?.uuidString ?? "none"); account: \(accountID?.uuidString ?? "none"); category: \(costCategory.rawValue); amount: \(amountText) \(currency); tax/GST: \(taxGSTText); reimbursement: \(reimbursementStatus.rawValue); approval: \(approvalStatus.rawValue); budget: \(budgetCode); owner: \(costOwnerTeam); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); notes: \(notes)."
  }

  func matches(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, customerProfileID: UUID?, vendorProfileID: UUID?, accountID: UUID?, evidenceID: UUID?, budgetCode: String, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let customerMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let vendorMatch = vendorProfileID != nil && self.vendorProfileID == vendorProfileID
    let accountMatch = accountID != nil && self.accountID == accountID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let budget = budgetCode.trimmingCharacters(in: .whitespacesAndNewlines)
    let budgetMatch = !budget.isEmpty && (self.budgetCode.localizedCaseInsensitiveContains(budget) || budget.localizedCaseInsensitiveContains(self.budgetCode))
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (costOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(costOwnerTeam))
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || notes.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(notes)
      || amountText.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(amountText)
      || costCategory.rawValue.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(costCategory.rawValue)
    )
    return orderMatch || groupMatch || contentMatch || customerMatch || vendorMatch || accountMatch || evidenceMatch || linkedMatch || budgetMatch || ownerMatch || contextMatch
  }
}

private extension ReturnClaimRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); cost: \(costRecordID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); vendor profile: \(vendorProfileID?.uuidString ?? "none"); account: \(accountID?.uuidString ?? "none"); type: \(claimType.rawValue); outcome: \(requestedOutcome.rawValue); status: \(claimStatus.rawValue); amount: \(refundReplacementAmountText) \(currency); owner: \(assignedOwnerTeam); due: \(dueDate); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); reason: \(reasonSummary)."
  }

  func matches(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, costRecordID: UUID?, customerProfileID: UUID?, vendorProfileID: UUID?, accountID: UUID?, evidenceID: UUID?, trackingEventID: UUID?, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let costMatch = costRecordID != nil && self.costRecordID == costRecordID
    let customerMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let vendorMatch = vendorProfileID != nil && self.vendorProfileID == vendorProfileID
    let accountMatch = accountID != nil && self.accountID == accountID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let trackingMatch = trackingEventID != nil && carrierTrackingEventIDs.contains(trackingEventID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || reasonSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(reasonSummary)
      || claimType.rawValue.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(claimType.rawValue)
      || requestedOutcome.rawValue.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(requestedOutcome.rawValue)
    )
    return orderMatch || groupMatch || contentMatch || costMatch || customerMatch || vendorMatch || accountMatch || evidenceMatch || trackingMatch || linkedMatch || ownerMatch || contextMatch
  }
}

private extension ProcurementRequest {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); requester: \(requesterTeam); requested: \(requestedDate); needed by: \(neededByDate); vendor profile: \(vendorProfileID?.uuidString ?? "none"); account: \(accountID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); destination: \(destinationAddressID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); cost: \(costRecordID?.uuidString ?? "none"); return claim: \(returnClaimID?.uuidString ?? "none"); estimated cost: \(estimatedCostText) \(currency); budget: \(budgetCode); approval: \(approvalStatus.rawValue); procurement: \(procurementStatus.rawValue); buyer: \(assignedBuyerTeam); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); items: \(requestedItemsSummary); notes: \(notes)."
  }

  func matches(vendorProfileID: UUID?, accountID: UUID?, customerProfileID: UUID?, destinationAddressID: UUID?, packageContentID: UUID?, costRecordID: UUID?, returnClaimID: UUID?, evidenceID: UUID?, budgetCode: String, requesterTeam: String, buyerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let vendorMatch = vendorProfileID != nil && self.vendorProfileID == vendorProfileID
    let accountMatch = accountID != nil && self.accountID == accountID
    let customerMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let destinationMatch = destinationAddressID != nil && self.destinationAddressID == destinationAddressID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let costMatch = costRecordID != nil && self.costRecordID == costRecordID
    let claimMatch = returnClaimID != nil && self.returnClaimID == returnClaimID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let budget = budgetCode.trimmingCharacters(in: .whitespacesAndNewlines)
    let budgetMatch = !budget.isEmpty && (self.budgetCode.localizedCaseInsensitiveContains(budget) || budget.localizedCaseInsensitiveContains(self.budgetCode))
    let requester = requesterTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let requesterMatch = !requester.isEmpty && (self.requesterTeam.localizedCaseInsensitiveContains(requester) || requester.localizedCaseInsensitiveContains(self.requesterTeam))
    let buyer = buyerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let buyerMatch = !buyer.isEmpty && (assignedBuyerTeam.localizedCaseInsensitiveContains(buyer) || buyer.localizedCaseInsensitiveContains(assignedBuyerTeam))
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || requestedItemsSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(requestedItemsSummary)
      || notes.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(notes)
    )
    return vendorMatch || accountMatch || customerMatch || destinationMatch || contentMatch || costMatch || claimMatch || evidenceMatch || linkedMatch || budgetMatch || requesterMatch || buyerMatch || contextMatch
  }
}

private extension ReceivingInspectionRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); procurement: \(procurementRequestID?.uuidString ?? "none"); return claim: \(returnClaimID?.uuidString ?? "none"); destination: \(destinationAddressID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); type: \(inspectionType.rawValue); status: \(inspectionStatus.rawValue); quantity: \(quantityReceived)/\(quantityExpected); discrepancy: \(discrepancyType.rawValue); inspector: \(assignedInspectorTeam); inspection date: \(inspectionDate); due: \(dueDate); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); expected: \(expectedItemSummary); received: \(receivedItemSummary); condition: \(conditionSummary); discrepancy summary: \(discrepancySummary)."
  }

  func matches(orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, procurementRequestID: UUID?, returnClaimID: UUID?, destinationAddressID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, trackingEventID: UUID?, inspectorTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let procurementMatch = procurementRequestID != nil && self.procurementRequestID == procurementRequestID
    let claimMatch = returnClaimID != nil && self.returnClaimID == returnClaimID
    let destinationMatch = destinationAddressID != nil && self.destinationAddressID == destinationAddressID
    let customerMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let trackingMatch = trackingEventID != nil && carrierTrackingEventIDs.contains(trackingEventID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let inspector = inspectorTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let inspectorMatch = !inspector.isEmpty && (assignedInspectorTeam.localizedCaseInsensitiveContains(inspector) || inspector.localizedCaseInsensitiveContains(assignedInspectorTeam))
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || expectedItemSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(expectedItemSummary)
      || receivedItemSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(receivedItemSummary)
      || discrepancySummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(discrepancySummary)
    )
    return orderMatch || groupMatch || contentMatch || procurementMatch || claimMatch || destinationMatch || customerMatch || evidenceMatch || trackingMatch || linkedMatch || inspectorMatch || contextMatch
  }
}

private extension InventoryReceiptRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); inspection: \(receivingInspectionID?.uuidString ?? "none"); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); procurement: \(procurementRequestID?.uuidString ?? "none"); return claim: \(returnClaimID?.uuidString ?? "none"); destination: \(destinationAddressID?.uuidString ?? "none"); customer profile: \(customerProfileID?.uuidString ?? "none"); type: \(receiptType.rawValue); status: \(stockHandoffStatus.rawValue); quantity: received \(quantityReceived), accepted \(quantityAccepted), rejected \(quantityRejected); location: \(storageLocationSummary); owner: \(assignedOwnerTeam); received: \(receivedDate); handoff: \(handoffDate); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); items: \(itemSummary); discrepancy: \(discrepancySummary)."
  }

  func matches(receivingInspectionID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, procurementRequestID: UUID?, returnClaimID: UUID?, destinationAddressID: UUID?, customerProfileID: UUID?, evidenceID: UUID?, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let inspectionMatch = receivingInspectionID != nil && self.receivingInspectionID == receivingInspectionID
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let procurementMatch = procurementRequestID != nil && self.procurementRequestID == procurementRequestID
    let claimMatch = returnClaimID != nil && self.returnClaimID == returnClaimID
    let destinationMatch = destinationAddressID != nil && self.destinationAddressID == destinationAddressID
    let customerMatch = customerProfileID != nil && self.customerProfileID == customerProfileID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    let locationMatch = !location.isEmpty && (storageLocationSummary.localizedCaseInsensitiveContains(location) || location.localizedCaseInsensitiveContains(storageLocationSummary))
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(title)
      || itemSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(itemSummary)
      || discrepancySummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(discrepancySummary)
      || storageLocationSummary.localizedCaseInsensitiveContains(context)
      || context.localizedCaseInsensitiveContains(storageLocationSummary)
    )
    return inspectionMatch || orderMatch || groupMatch || contentMatch || procurementMatch || claimMatch || destinationMatch || customerMatch || evidenceMatch || linkedMatch || ownerMatch || locationMatch || contextMatch
  }
}

private extension StorageLocationRecord {
  var auditDetail: String {
    "Title: \(title); type: \(locationType.rawValue); code: \(locationCode); area: \(areaZone); linked: \(linkedEntityType.rawValue) \(linkedEntityID); inventory receipts: \(inventoryReceiptIDs.map(\.uuidString).joined(separator: ",")); inspections: \(receivingInspectionIDs.map(\.uuidString).joined(separator: ",")); package contents: \(packageContentIDs.map(\.uuidString).joined(separator: ",")); orders: \(orderIDs.map(\.uuidString).joined(separator: ",")); shipment groups: \(shipmentGroupIDs.map(\.uuidString).joined(separator: ",")); owner: \(assignedOwnerTeam); risk: \(riskLevel.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); capacity: \(capacitySummary); usage: \(currentUsageSummary); access: \(accessNotes)."
  }

  func matches(inventoryReceiptID: UUID?, receivingInspectionID: UUID?, packageContentID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, ownerTeam: String, areaZone: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let receiptMatch = inventoryReceiptID != nil && inventoryReceiptIDs.contains(inventoryReceiptID!)
    let inspectionMatch = receivingInspectionID != nil && receivingInspectionIDs.contains(receivingInspectionID!)
    let contentMatch = packageContentID != nil && packageContentIDs.contains(packageContentID!)
    let orderMatch = orderID != nil && orderIDs.contains(orderID!)
    let groupMatch = shipmentGroupID != nil && shipmentGroupIDs.contains(shipmentGroupID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let area = areaZone.trimmingCharacters(in: .whitespacesAndNewlines)
    let areaMatch = !area.isEmpty && (self.areaZone.localizedCaseInsensitiveContains(area) || area.localizedCaseInsensitiveContains(self.areaZone))
    let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    let locationMatch = !location.isEmpty && (
      title.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(title)
        || locationCode.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(locationCode)
        || self.areaZone.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(self.areaZone)
    )
    let contextMatch = !context.isEmpty && (
      title.localizedCaseInsensitiveContains(context)
        || context.localizedCaseInsensitiveContains(title)
        || locationCode.localizedCaseInsensitiveContains(context)
        || context.localizedCaseInsensitiveContains(locationCode)
        || capacitySummary.localizedCaseInsensitiveContains(context)
        || context.localizedCaseInsensitiveContains(capacitySummary)
        || currentUsageSummary.localizedCaseInsensitiveContains(context)
        || context.localizedCaseInsensitiveContains(currentUsageSummary)
    )
    return receiptMatch || inspectionMatch || contentMatch || orderMatch || groupMatch || linkedMatch || ownerMatch || areaMatch || locationMatch || contextMatch
  }
}

private extension CustodyRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); current custodian: \(currentCustodianTeam); previous custodian: \(previousCustodianTeam); status: \(custodyStatus.rawValue); reason: \(custodyReason); method: \(handoffMethod.rawValue); source location: \(sourceLocationID?.uuidString ?? "none"); destination location: \(destinationLocationID?.uuidString ?? "none"); inventory receipt: \(inventoryReceiptID?.uuidString ?? "none"); storage location: \(storageLocationID?.uuidString ?? "none"); receiving inspection: \(receivingInspectionID?.uuidString ?? "none"); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); evidence: \(evidenceAttachmentIDs.map(\.uuidString).joined(separator: ",")); owner: \(assignedOwnerTeam); transfer: \(transferDate); expected close: \(expectedReturnCloseDate); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); notes: \(notes)."
  }

  func matches(sourceLocationID: UUID?, destinationLocationID: UUID?, inventoryReceiptID: UUID?, storageLocationID: UUID?, receivingInspectionID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, custodianTeam: String, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let sourceMatch = sourceLocationID != nil && self.sourceLocationID == sourceLocationID
    let destinationMatch = destinationLocationID != nil && self.destinationLocationID == destinationLocationID
    let storageMatch = storageLocationID != nil && self.storageLocationID == storageLocationID
    let receiptMatch = inventoryReceiptID != nil && self.inventoryReceiptID == inventoryReceiptID
    let inspectionMatch = receivingInspectionID != nil && self.receivingInspectionID == receivingInspectionID
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let custodian = custodianTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let custodianMatch = !custodian.isEmpty && (currentCustodianTeam.localizedCaseInsensitiveContains(custodian) || previousCustodianTeam.localizedCaseInsensitiveContains(custodian) || custodian.localizedCaseInsensitiveContains(currentCustodianTeam))
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    let locationMatch = !location.isEmpty && (
      notes.localizedCaseInsensitiveContains(location)
        || custodyReason.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(notes)
        || location.localizedCaseInsensitiveContains(custodyReason)
    )
    let contextText = context.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextMatch = !contextText.isEmpty && (
      title.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(title)
        || custodyReason.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(custodyReason)
        || notes.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(notes)
    )
    return sourceMatch || destinationMatch || storageMatch || receiptMatch || inspectionMatch || orderMatch || groupMatch || contentMatch || evidenceMatch || linkedMatch || custodianMatch || ownerMatch || locationMatch || contextMatch
  }
}

private extension LabelReferenceRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); type: \(labelType.rawValue); value: \(labelValuePlaceholder); source: \(labelSource.rawValue); status: \(labelStatus.rawValue); carrier: \(associatedCarrier); storage location: \(storageLocationID?.uuidString ?? "none"); inventory receipt: \(inventoryReceiptID?.uuidString ?? "none"); custody record: \(custodyRecordID?.uuidString ?? "none"); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); evidence: \(evidenceAttachmentIDs.map(\.uuidString).joined(separator: ",")); owner: \(assignedOwnerTeam); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); notes: \(notes)."
  }

  func matches(storageLocationID: UUID?, inventoryReceiptID: UUID?, custodyRecordID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, labelValue: String, carrier: String, ownerTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let storageMatch = storageLocationID != nil && self.storageLocationID == storageLocationID
    let receiptMatch = inventoryReceiptID != nil && self.inventoryReceiptID == inventoryReceiptID
    let custodyMatch = custodyRecordID != nil && self.custodyRecordID == custodyRecordID
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let value = labelValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let valueMatch = !value.isEmpty && (labelValuePlaceholder.localizedCaseInsensitiveContains(value) || value.localizedCaseInsensitiveContains(labelValuePlaceholder))
    let carrierText = carrier.trimmingCharacters(in: .whitespacesAndNewlines)
    let carrierMatch = !carrierText.isEmpty && (associatedCarrier.localizedCaseInsensitiveContains(carrierText) || carrierText.localizedCaseInsensitiveContains(associatedCarrier))
    let owner = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !owner.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(owner) || owner.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let contextText = context.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextMatch = !contextText.isEmpty && (
      title.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(title)
        || notes.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(notes)
        || labelType.rawValue.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(labelType.rawValue)
    )
    return storageMatch || receiptMatch || custodyMatch || orderMatch || groupMatch || contentMatch || evidenceMatch || linkedMatch || valueMatch || carrierMatch || ownerMatch || contextMatch
  }
}

private extension ScanSessionRecord {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); purpose: \(scanPurpose.rawValue); method: \(scanMethodPlaceholder.rawValue); expected: \(expectedLabelReferenceValue); captured: \(capturedValuePlaceholder); label reference: \(linkedLabelReferenceID?.uuidString ?? "none"); status: \(scanStatus.rawValue); mismatch: \(mismatchSummary); operator: \(assignedOperatorTeam); scan location: \(scanLocationStorageLocationID?.uuidString ?? "none"); custody: \(custodyRecordID?.uuidString ?? "none"); inventory receipt: \(inventoryReceiptID?.uuidString ?? "none"); order: \(orderID?.uuidString ?? "none"); shipment group: \(shipmentGroupID?.uuidString ?? "none"); package content: \(packageContentID?.uuidString ?? "none"); evidence: \(evidenceAttachmentIDs.map(\.uuidString).joined(separator: ",")); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); completed: \(completedDate); notes: \(notes)."
  }

  func matches(labelReferenceID: UUID?, storageLocationID: UUID?, custodyRecordID: UUID?, inventoryReceiptID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, packageContentID: UUID?, evidenceID: UUID?, labelValue: String, operatorTeam: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let labelMatch = labelReferenceID != nil && linkedLabelReferenceID == labelReferenceID
    let storageMatch = storageLocationID != nil && scanLocationStorageLocationID == storageLocationID
    let custodyMatch = custodyRecordID != nil && self.custodyRecordID == custodyRecordID
    let receiptMatch = inventoryReceiptID != nil && self.inventoryReceiptID == inventoryReceiptID
    let orderMatch = orderID != nil && self.orderID == orderID
    let groupMatch = shipmentGroupID != nil && self.shipmentGroupID == shipmentGroupID
    let contentMatch = packageContentID != nil && self.packageContentID == packageContentID
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let value = labelValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let valueMatch = !value.isEmpty && (
      expectedLabelReferenceValue.localizedCaseInsensitiveContains(value)
        || capturedValuePlaceholder.localizedCaseInsensitiveContains(value)
        || value.localizedCaseInsensitiveContains(expectedLabelReferenceValue)
        || value.localizedCaseInsensitiveContains(capturedValuePlaceholder)
    )
    let operatorText = operatorTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let operatorMatch = !operatorText.isEmpty && (assignedOperatorTeam.localizedCaseInsensitiveContains(operatorText) || operatorText.localizedCaseInsensitiveContains(assignedOperatorTeam))
    let contextText = context.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextMatch = !contextText.isEmpty && (
      title.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(title)
        || notes.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(notes)
        || mismatchSummary.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(mismatchSummary)
    )
    return labelMatch || storageMatch || custodyMatch || receiptMatch || orderMatch || groupMatch || contentMatch || evidenceMatch || linkedMatch || valueMatch || operatorMatch || contextMatch
  }
}

private extension ShipmentManifestRecord {
  var auditDetail: String {
    "Title: \(title); type: \(manifestType.rawValue); linked: \(linkedEntityType.rawValue) \(linkedEntityID); carrier: \(carrierCourier); destination: \(destinationSummary); orders: \(includedOrderIDs.map(\.uuidString).joined(separator: ",")); groups: \(shipmentGroupIDs.map(\.uuidString).joined(separator: ",")); receipts: \(inventoryReceiptIDs.map(\.uuidString).joined(separator: ",")); contents: \(packageContentIDs.map(\.uuidString).joined(separator: ",")); custody: \(custodyRecordIDs.map(\.uuidString).joined(separator: ",")); labels: \(labelReferenceIDs.map(\.uuidString).joined(separator: ",")); scans: \(scanSessionIDs.map(\.uuidString).joined(separator: ",")); evidence: \(evidenceAttachmentIDs.map(\.uuidString).joined(separator: ",")); owner: \(assignedOwnerTeam); status: \(dispatchStatus.rawValue); planned: \(plannedDispatchDate); actual: \(actualDispatchDate); handoff location: \(handoffLocationStorageLocationID?.uuidString ?? "none"); reference: \(manifestReferencePlaceholder); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); reviewed: \(lastReviewedDate); notes: \(notes)."
  }

  func matches(orderID: UUID?, shipmentGroupID: UUID?, inventoryReceiptID: UUID?, packageContentID: UUID?, custodyRecordID: UUID?, labelReferenceID: UUID?, scanSessionID: UUID?, evidenceID: UUID?, storageLocationID: UUID?, carrierCourier: String, ownerTeam: String, locationText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let orderMatch = orderID != nil && includedOrderIDs.contains(orderID!)
    let groupMatch = shipmentGroupID != nil && shipmentGroupIDs.contains(shipmentGroupID!)
    let receiptMatch = inventoryReceiptID != nil && inventoryReceiptIDs.contains(inventoryReceiptID!)
    let contentMatch = packageContentID != nil && packageContentIDs.contains(packageContentID!)
    let custodyMatch = custodyRecordID != nil && custodyRecordIDs.contains(custodyRecordID!)
    let labelMatch = labelReferenceID != nil && labelReferenceIDs.contains(labelReferenceID!)
    let scanMatch = scanSessionID != nil && scanSessionIDs.contains(scanSessionID!)
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let locationMatch = storageLocationID != nil && handoffLocationStorageLocationID == storageLocationID
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let carrierText = carrierCourier.trimmingCharacters(in: .whitespacesAndNewlines)
    let carrierMatch = !carrierText.isEmpty && (self.carrierCourier.localizedCaseInsensitiveContains(carrierText) || carrierText.localizedCaseInsensitiveContains(self.carrierCourier))
    let ownerText = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !ownerText.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(ownerText) || ownerText.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    let locationTextMatch = !location.isEmpty && (
      destinationSummary.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(destinationSummary)
        || manifestReferencePlaceholder.localizedCaseInsensitiveContains(location)
        || location.localizedCaseInsensitiveContains(manifestReferencePlaceholder)
    )
    let contextText = context.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextMatch = !contextText.isEmpty && (
      title.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(title)
        || notes.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(notes)
        || manifestType.rawValue.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(manifestType.rawValue)
    )
    return orderMatch || groupMatch || receiptMatch || contentMatch || custodyMatch || labelMatch || scanMatch || evidenceMatch || locationMatch || linkedMatch || carrierMatch || ownerMatch || locationTextMatch || contextMatch
  }
}

private extension DispatchReadinessChecklist {
  var auditDetail: String {
    "Title: \(title); linked: \(linkedEntityType.rawValue) \(linkedEntityID); manifest: \(shipmentManifestID?.uuidString ?? "none"); orders: \(orderIDs.map(\.uuidString).joined(separator: ",")); groups: \(shipmentGroupIDs.map(\.uuidString).joined(separator: ",")); receipts: \(inventoryReceiptIDs.map(\.uuidString).joined(separator: ",")); contents: \(packageContentIDs.map(\.uuidString).joined(separator: ",")); custody: \(custodyRecordIDs.map(\.uuidString).joined(separator: ",")); labels: \(labelReferenceIDs.map(\.uuidString).joined(separator: ",")); scans: \(scanSessionIDs.map(\.uuidString).joined(separator: ",")); evidence: \(evidenceAttachmentIDs.map(\.uuidString).joined(separator: ",")); type: \(checklistType.rawValue); status: \(checklistStatus.rawValue); required: \(requiredChecksSummary); completed: \(completedChecksSummary); missing: \(missingRequirementsSummary); owner: \(assignedOwnerTeam); planned: \(plannedDispatchDate); completed date: \(completedDate); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); reviewed: \(lastReviewedDate)."
  }

  func matches(shipmentManifestID: UUID?, orderID: UUID?, shipmentGroupID: UUID?, inventoryReceiptID: UUID?, packageContentID: UUID?, custodyRecordID: UUID?, labelReferenceID: UUID?, scanSessionID: UUID?, evidenceID: UUID?, ownerTeam: String, dateText: String, context: String, linkedEntityType: ReviewTaskLinkedEntityType?, linkedEntityID: String) -> Bool {
    let manifestMatch = shipmentManifestID != nil && self.shipmentManifestID == shipmentManifestID
    let orderMatch = orderID != nil && orderIDs.contains(orderID!)
    let groupMatch = shipmentGroupID != nil && shipmentGroupIDs.contains(shipmentGroupID!)
    let receiptMatch = inventoryReceiptID != nil && inventoryReceiptIDs.contains(inventoryReceiptID!)
    let contentMatch = packageContentID != nil && packageContentIDs.contains(packageContentID!)
    let custodyMatch = custodyRecordID != nil && custodyRecordIDs.contains(custodyRecordID!)
    let labelMatch = labelReferenceID != nil && labelReferenceIDs.contains(labelReferenceID!)
    let scanMatch = scanSessionID != nil && scanSessionIDs.contains(scanSessionID!)
    let evidenceMatch = evidenceID != nil && evidenceAttachmentIDs.contains(evidenceID!)
    let linkedMatch = self.linkedEntityType == linkedEntityType && self.linkedEntityID == linkedEntityID
    let ownerText = ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let ownerMatch = !ownerText.isEmpty && (assignedOwnerTeam.localizedCaseInsensitiveContains(ownerText) || ownerText.localizedCaseInsensitiveContains(assignedOwnerTeam))
    let date = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
    let dateMatch = !date.isEmpty && (plannedDispatchDate.localizedCaseInsensitiveContains(date) || date.localizedCaseInsensitiveContains(plannedDispatchDate))
    let contextText = context.trimmingCharacters(in: .whitespacesAndNewlines)
    let contextMatch = !contextText.isEmpty && (
      title.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(title)
        || requiredChecksSummary.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(requiredChecksSummary)
        || completedChecksSummary.localizedCaseInsensitiveContains(contextText)
        || missingRequirementsSummary.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(missingRequirementsSummary)
        || checklistType.rawValue.localizedCaseInsensitiveContains(contextText)
        || contextText.localizedCaseInsensitiveContains(checklistType.rawValue)
    )
    return manifestMatch || orderMatch || groupMatch || receiptMatch || contentMatch || custodyMatch || labelMatch || scanMatch || evidenceMatch || linkedMatch || ownerMatch || dateMatch || contextMatch
  }
}

private extension ValidationSeverity {
  var sortRank: Int {
    switch self {
    case .critical: 4
    case .high: 3
    case .warning: 2
    case .info: 1
    }
  }

  var shipmentRiskLevel: ShipmentRiskLevel? {
    switch self {
    case .info: .low
    case .warning: .medium
    case .high: .high
    case .critical: .critical
    }
  }
}

private extension VendorRiskLevel {
  var shipmentRiskLevel: ShipmentRiskLevel {
    switch self {
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .critical: .critical
    }
  }
}

private extension WorkbenchItem {
  var shipmentRiskLevel: ShipmentRiskLevel? {
    switch prioritySeverity {
    case "Low": .low
    case "Medium", "Normal": .medium
    case "High": .high
    case "Critical", "Urgent": .critical
    default: nil
    }
  }
}

private extension AccountCredentialRecord {
  var auditDetail: String {
    "Account: \(accountName); organisation: \(organisation); contact: \(linkedContactID?.uuidString ?? "none"); linked: \(linkedEntityType.rawValue) \(linkedEntityID); login URL: \(loginURL); username label: \(usernameLabel); credential status: \(credentialStorageStatus.rawValue); MFA: \(mfaStatus.rawValue); renewal review: \(renewalReviewDate); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last checked: \(lastCheckedDate); notes: \(notes)."
  }
}

private extension VendorProfile {
  var auditDetail: String {
    "Name: \(name); type: \(profileType.rawValue); organisation: \(primaryOrganisation); website: \(website); support: \(supportURL); default contact: \(defaultContactID?.uuidString ?? "none"); default account: \(defaultAccountID?.uuidString ?? "none"); channel: \(preferredChannel.rawValue); risk: \(riskLevel.rawValue); enabled: \(isEnabled ? "yes" : "no"); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate); service notes: \(serviceLevelNotes)."
  }
}

private extension ShipmentGroup {
  var auditDetail: String {
    "Name: \(groupName); primary order: \(primaryOrderID?.uuidString ?? "none"); orders: \(relatedOrderIDs.map(\.uuidString).joined(separator: ", ")); intake: \(relatedIntakeEmailIDs.map(\.uuidString).joined(separator: ", ")); tracking: \(relatedTrackingEventIDs.map(\.uuidString).joined(separator: ", ")); evidence: \(relatedEvidenceIDs.map(\.uuidString).joined(separator: ", ")); destination: \(destinationSummary); recipient/customer: \(recipientCustomerSummary); carrier: \(carrierSummary); status: \(statusSummary); risk: \(riskLevel.rawValue); review: \(reviewState.rawValue); created: \(createdDate); last reviewed: \(lastReviewedDate)."
  }
}

private extension ImportQueueItem {
  var auditDetail: String {
    "Source: \(sourceType.rawValue) \(sourceLabel); captured: \(capturedDate); merchant: \(detectedMerchant); order: \(detectedOrderNumber); tracking: \(detectedTrackingNumber); destination: \(detectedDestinationAddress); linked order: \(suggestedLinkedOrderID?.uuidString ?? "none"); shipment group: \(suggestedShipmentGroupID?.uuidString ?? "none"); confidence: \(confidenceScore); status: \(importStatus.rawValue); review: \(reviewState.rawValue); notes: \(notes); summary: \(rawSummary)."
  }
}

private extension AcceptanceRecord {
  var auditDetail: String {
    "Source: \(sourceType.rawValue) \(sourceLabel) \(sourceID.uuidString); decided: \(decidedDate); confidence: \(confidenceScore); linked order: \(linkedOrderID?.uuidString ?? "none"); shipment group: \(linkedShipmentGroupID?.uuidString ?? "none"); decision: \(decision.rawValue); review: \(reviewState.rawValue); notes: \(notes); summary: \(summary)."
  }
}

private extension WishlistItem {
  var auditDetail: String {
    "Item: \(itemName); storefront: \(storefront); URL: \(storefrontURL); estimated cost: \(estimatedCost); owner: \(owner); pool: \(pool); source: \(source.rawValue); status: \(status); captured detail: \(capturedDetail)."
  }
}

private extension TrackedMailbox {
  var auditDetail: String {
    "Address: \(address); provider: \(provider.rawValue); folders: \(monitoredFolders); status: \(status); last checked: \(lastChecked); routing rule: \(routingRule)."
  }
}

private extension ShopifyConnection {
  var auditDetail: String {
    "Store: \(storeName); domain: \(storeDomain); mapped mailbox: \(mappedMailbox); mapped team: \(mappedTeam); status: \(status); last sync: \(lastSync); enabled: \(isEnabled ? "yes" : "no")."
  }
}

private extension SourceConnection {
  var auditDetail: String {
    "Name: \(name); kind: \(kind.rawValue); account: \(account); status: \(status); last sync: \(lastSync)."
  }
}

private extension WatchedFolder {
  var auditDetail: String {
    "Name: \(name); location: \(location); platform: \(platform); file types: \(fileTypes); cadence: \(cadence); status: \(status); last scan: \(lastScan)."
  }
}

private extension ParcelOpsSettings {
  var auditDetail: String {
    "Mailbox monitoring plan: \(mailboxMonitoringEnabled ? "on" : "off"); auto-create orders plan: \(autoCreateOrdersFromEmail ? "on" : "off"); match confidence: \(matchConfidencePolicy); folder watching plan: \(folderWatchingEnabled ? "on" : "off"); folder cadence: \(folderScanCadence); risky match review: \(requireReviewForRiskyMatches ? "required" : "not required"); delivery exception alert plan: \(notifyOnDeliveryExceptions ? "on" : "off"); exception threshold: \(exceptionThreshold); Shopify sync plan: \(shopifySyncEnabled ? "on" : "off"); store login sync plan: \(storeLoginSyncEnabled ? "on" : "off"); carrier tracking plan: \(carrierTrackingEnabled ? "on" : "off"); carrier tracking mode: \(carrierTrackingMode)."
  }
}

private extension ReconciliationIssue {
  var auditDetail: String {
    "Type: \(issueType.rawValue); severity: \(severity.rawValue); source: \(sourceEntityType.rawValue) \(sourceEntityID); target: \(targetEntityType?.rawValue ?? "none") \(targetEntityID ?? "none"); detected: \(detectedValue); operational: \(currentOperationalValue); review: \(reviewState.rawValue); created: \(createdDate); summary: \(summary); suggested: \(suggestedResolution)."
  }
}
