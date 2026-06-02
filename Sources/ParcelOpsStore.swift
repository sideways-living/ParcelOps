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
  private let mailboxIngestionService: MailboxIngestionService
  private let orderMatchingService: OrderMatchingService
  private let shopifySyncService: ShopifySyncService
  private let carrierTrackingService: CarrierTrackingService
  private let parcelExportService: ParcelExportService
  private let workflowTemplateEngine: WorkflowTemplateEngine

  typealias Repository = OrderRepository & MailEventRepository & IntakeEmailRepository & IntegrationRepository & WishlistRepository & SettingsRepository & AuditRepository & EvidenceRepository & TrackingRepository & AutomationRuleRepository

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
    reviewOrders.count + reviewMailEvents.count + reviewIntakeEmails.count + reviewEvidenceAttachments.count + reviewCarrierTrackingEvents.count
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
