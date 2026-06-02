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
  private let mailboxIngestionService: MailboxIngestionService
  private let orderMatchingService: OrderMatchingService
  private let shopifySyncService: ShopifySyncService
  private let carrierTrackingService: CarrierTrackingService
  private let parcelExportService: ParcelExportService
  private let workflowTemplateEngine: WorkflowTemplateEngine

  typealias Repository = OrderRepository & MailEventRepository & IntakeEmailRepository & IntegrationRepository & WishlistRepository & SettingsRepository & AuditRepository & EvidenceRepository & TrackingRepository & AutomationRuleRepository & SavedFilterRepository & ReviewTaskRepository & SLAPolicyRepository & CommunicationRepository & ContactDirectoryRepository & AccountCredentialRepository & VendorProfileRepository

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
    reviewOrders.count + reviewMailEvents.count + reviewIntakeEmails.count + reviewEvidenceAttachments.count + reviewCarrierTrackingEvents.count + reviewTasksNeedingAttention.count + policiesNeedingReview.count + draftMessagesNeedingReview.count + contactsNeedingReview.count + accountRecordsNeedingReview.count + vendorProfilesNeedingReview.count + highRiskEnabledVendorProfiles.count
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
