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
  var mailboxes: [TrackedMailbox]
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
  var slaPolicies: [SLAPolicy]
  var communicationTemplates: [CommunicationTemplate]
  var draftMessages: [DraftMessage]
  var contactDirectoryEntries: [ContactDirectoryEntry]
  var accountCredentialRecords: [AccountCredentialRecord]
  var vendorProfiles: [VendorProfile]
  var shipmentGroups: [ShipmentGroup]
  var importQueueItems: [ImportQueueItem]
  var acceptanceRecords: [AcceptanceRecord]

  private let orderRepository: OrderRepository
  private let mailEventRepository: MailEventRepository
  private let intakeEmailRepository: IntakeEmailRepository
  private let integrationRepository: IntegrationRepository
  private let wishlistRepository: WishlistRepository
  private let settingsRepository: SettingsRepository
  private let auditRepository: AuditRepository
  private let evidenceRepository: EvidenceRepository
  private let trackingRepository: TrackingRepository
  private let automationRuleRepository: AutomationRuleRepository
  private let savedFilterRepository: SavedFilterRepository
  private let reviewTaskRepository: ReviewTaskRepository
  private let slaPolicyRepository: SLAPolicyRepository
  private let communicationRepository: CommunicationRepository
  private let contactDirectoryRepository: ContactDirectoryRepository
  private let accountCredentialRepository: AccountCredentialRepository
  private let vendorProfileRepository: VendorProfileRepository
  private let shipmentGroupRepository: ShipmentGroupRepository
  private let importQueueRepository: ImportQueueRepository
  private let acceptanceRepository: AcceptanceRepository
  private let mailboxIngestionService: MailboxIngestionService
  private let orderMatchingService: OrderMatchingService
  private let shopifySyncService: ShopifySyncService
  private let carrierTrackingService: CarrierTrackingService
  private let parcelExportService: ParcelExportService
  private let workflowTemplateEngine: WorkflowTemplateEngine

  typealias Repository = OrderRepository & MailEventRepository & IntakeEmailRepository & IntegrationRepository & WishlistRepository & SettingsRepository & AuditRepository & EvidenceRepository & TrackingRepository & AutomationRuleRepository & SavedFilterRepository & ReviewTaskRepository & SLAPolicyRepository & CommunicationRepository & ContactDirectoryRepository & AccountCredentialRepository & VendorProfileRepository & ShipmentGroupRepository & ImportQueueRepository & AcceptanceRepository

  init(
    repository: any Repository = JSONParcelOpsRepository(),
    mailboxIngestionService: MailboxIngestionService = MockMailboxIngestionService(),
    orderMatchingService: OrderMatchingService = MockOrderMatchingService(),
    shopifySyncService: ShopifySyncService = MockShopifySyncService(),
    carrierTrackingService: CarrierTrackingService = MockCarrierTrackingService(),
    parcelExportService: ParcelExportService = MockParcelExportService(),
    workflowTemplateEngine: WorkflowTemplateEngine = RuleBasedWorkflowTemplateEngine()
  ) {
    self.orderRepository = repository
    self.mailEventRepository = repository
    self.intakeEmailRepository = repository
    self.integrationRepository = repository
    self.wishlistRepository = repository
    self.settingsRepository = repository
    self.auditRepository = repository
    self.evidenceRepository = repository
    self.trackingRepository = repository
    self.automationRuleRepository = repository
    self.savedFilterRepository = repository
    self.reviewTaskRepository = repository
    self.slaPolicyRepository = repository
    self.communicationRepository = repository
    self.contactDirectoryRepository = repository
    self.accountCredentialRepository = repository
    self.vendorProfileRepository = repository
    self.shipmentGroupRepository = repository
    self.importQueueRepository = repository
    self.acceptanceRepository = repository
    self.mailboxIngestionService = mailboxIngestionService
    self.orderMatchingService = orderMatchingService
    self.shopifySyncService = shopifySyncService
    self.carrierTrackingService = carrierTrackingService
    self.parcelExportService = parcelExportService
    self.workflowTemplateEngine = workflowTemplateEngine
    self.orders = repository.loadOrders()
    self.mailEvents = repository.loadMailEvents()
    self.intakeEmails = repository.loadIntakeEmails()
    self.mailboxes = repository.loadMailboxes()
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
    self.slaPolicies = repository.loadSLAPolicies()
    self.communicationTemplates = repository.loadCommunicationTemplates()
    self.draftMessages = repository.loadDraftMessages()
    self.contactDirectoryEntries = repository.loadContactDirectoryEntries()
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

  var reviewQueueCount: Int {
    reviewOrders.count + reviewMailEvents.count + reviewIntakeEmails.count + reviewEvidenceAttachments.count + reviewCarrierTrackingEvents.count + reviewTasksNeedingAttention.count + policiesNeedingReview.count + draftMessagesNeedingReview.count + contactsNeedingReview.count + accountRecordsNeedingReview.count + vendorProfilesNeedingReview.count + highRiskEnabledVendorProfiles.count + shipmentGroupsNeedingReview.count + highRiskShipmentGroups.count + importQueueItemsNeedingReview.count + blockedImportQueueItems.count + acceptanceRecordsNeedingReview.count + highSeverityReconciliationIssues.count + highSeverityValidationIssues.count
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
        || order.recipientEmail.lowercased().contains(query)
        || order.checkedMailbox.lowercased().contains(query)
        || order.trackingNumber.lowercased().contains(query)
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
      SearchResult(
        id: "order-\(order.id.uuidString)",
        entityType: .order,
        title: "\(order.store) \(order.orderNumber)",
        subtitle: "\(order.status.rawValue) to \(order.destination)",
        detail: "Tracking \(order.trackingNumber) via \(order.carrier). \(order.latestStatus)",
        severity: order.status == .exception ? .critical : nil,
        reviewState: order.reviewState,
        linkedEntityID: order.id.uuidString
      )
    }
  }

  private func intakeEmailSearchResults() -> [SearchResult] {
    intakeEmails.map { email in
      SearchResult(
        id: "intake-\(email.id.uuidString)",
        entityType: .intakeEmail,
        title: email.subject,
        subtitle: "\(email.detectedMerchant) from \(email.sender)",
        detail: "Order \(email.detectedOrderNumber), tracking \(email.detectedTrackingNumber), destination \(email.detectedDestinationAddress). \(email.rawBodyPreview)",
        severity: email.reviewState == .needsReview ? .watch : nil,
        reviewState: email.reviewState.searchReviewState,
        linkedEntityID: email.id.uuidString
      )
    }
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
    appendSystemContact("Sync requested", evidence: "Workflow template actions queued: \(actions).")
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
    let orderNumber = email.detectedOrderNumber.isPlaceholder ? "EMAIL-\(3000 + orders.count + 1)" : email.detectedOrderNumber
    let trackingNumber = email.detectedTrackingNumber.isPlaceholder ? "Pending" : email.detectedTrackingNumber
    let destination = email.detectedDestinationAddress.isPlaceholder ? "Pending review" : email.detectedDestinationAddress

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
      latestStatus: "Created from forwarded email and awaiting review",
      timeline: [
        TimelineEvent(title: "Forwarded email captured", detail: email.subject, time: "Now", symbol: "envelope.open.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Now", source: .mailbox, contactPoint: "Forwarded email intake", summary: "Order draft created from forwarded email.", evidence: email.rawBodyPreview, reviewState: .needsReview)
      ]
    )

    orders.insert(order, at: 0)

    if let emailIndex = intakeEmails.firstIndex(where: { $0.id == email.id }) {
      intakeEmails[emailIndex].linkedOrderID = order.id
      intakeEmails[emailIndex].reviewState = .reviewed
    }

    persistOrders()
    persistIntakeEmails()
    logAudit(
      action: .created,
      entityType: .order,
      entityID: order.id.uuidString,
      entityLabel: order.orderNumber,
      summary: "Tracked order created from forwarded intake email.",
      afterDetail: order.auditDetail
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
    mailboxes.append(TrackedMailbox(address: "new-mailbox@company.example", provider: .microsoft365, monitoredFolders: "Inbox", status: "Needs auth", lastChecked: "Never", routingRule: "New mailbox intake"))
    persistIntegrations()
  }

  func connectShopifyPlaceholder() {
    shopifyConnections.append(ShopifyConnection(storeName: "New Shopify Store", storeDomain: "new-store.myshopify.com", mappedMailbox: "tracking-intake@parcelops.example", mappedTeam: "Unassigned", status: "Needs OAuth", lastSync: "Never", isEnabled: false))
    persistIntegrations()
  }

  func addStoreLoginPlaceholder() {
    connections.append(SourceConnection(name: "New supplier login", kind: .vaultLogin, account: "Password vault", status: "Needs setup", lastSync: "Never"))
    persistIntegrations()
  }

  func addWatchedFolderPlaceholder() {
    watchedFolders.append(WatchedFolder(name: "Custom order folder", location: "Choose folder", platform: "iOS and macOS", fileTypes: "PDF, images", cadence: settings.folderScanCadence, status: "Needs permission", lastScan: "Never"))
    persistIntegrations()
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
  }

  func linkWishlistItemToOrder(_ item: WishlistItem) {
    markWishlist(item, status: "Linked to existing order")
  }

  func deleteWishlistItem(_ item: WishlistItem) {
    wishlistItems.removeAll { $0.id == item.id }
    var deleted = item
    deleted.status = "Deleted now"
    deletedWishlistItems.insert(deleted, at: 0)
    persistWishlist()
  }

  func restoreWishlistItem(_ item: WishlistItem) {
    deletedWishlistItems.removeAll { $0.id == item.id }
    var restored = item
    restored.status = "Ready"
    wishlistItems.insert(restored, at: 0)
    persistWishlist()
  }

  func permanentlyDeleteWishlistItem(_ item: WishlistItem) {
    deletedWishlistItems.removeAll { $0.id == item.id }
    persistWishlist()
  }

  func saveSettings() {
    settingsRepository.saveSettings(settings)
  }

  private func addWishlistItem(source: WishlistSource, name: String, detail: String) {
    wishlistItems.insert(WishlistItem(itemName: name, storefront: "Pending storefront", storefrontURL: "https://example.com", estimatedCost: "Pending", owner: "Current user", pool: "Personal wishlist", source: source, status: "Needs review", capturedDetail: detail), at: 0)
    persistWishlist()
  }

  private func markWishlist(_ item: WishlistItem, status: String) {
    guard let index = wishlistItems.firstIndex(where: { $0.id == item.id }) else { return }
    wishlistItems[index].status = status
    persistWishlist()
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

  private func persistIntegrations() {
    integrationRepository.saveMailboxes(mailboxes)
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

  private func persistSLAPolicies() {
    slaPolicyRepository.saveSLAPolicies(slaPolicies)
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

private extension SLAPolicy {
  var auditDetail: String {
    "Name: \(name); linked: \(linkedEntityType.rawValue); priority: \(priority.rawValue); enabled: \(isEnabled ? "yes" : "no"); response: \(responseTarget); resolution: \(resolutionTarget); review: \(reviewState.rawValue); created: \(createdDate); last evaluated: \(lastEvaluatedDate); matches: \(matchCount); condition: \(conditionSummary)."
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

private extension ReconciliationIssue {
  var auditDetail: String {
    "Type: \(issueType.rawValue); severity: \(severity.rawValue); source: \(sourceEntityType.rawValue) \(sourceEntityID); target: \(targetEntityType?.rawValue ?? "none") \(targetEntityID ?? "none"); detected: \(detectedValue); operational: \(currentOperationalValue); review: \(reviewState.rawValue); created: \(createdDate); summary: \(summary); suggested: \(suggestedResolution)."
  }
}
