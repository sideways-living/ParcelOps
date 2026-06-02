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

  private let orderRepository: OrderRepository
  private let mailEventRepository: MailEventRepository
  private let intakeEmailRepository: IntakeEmailRepository
  private let integrationRepository: IntegrationRepository
  private let wishlistRepository: WishlistRepository
  private let settingsRepository: SettingsRepository
  private let mailboxIngestionService: MailboxIngestionService
  private let orderMatchingService: OrderMatchingService
  private let shopifySyncService: ShopifySyncService
  private let carrierTrackingService: CarrierTrackingService
  private let parcelExportService: ParcelExportService
  private let workflowTemplateEngine: WorkflowTemplateEngine

  typealias Repository = OrderRepository & MailEventRepository & IntakeEmailRepository & IntegrationRepository & WishlistRepository & SettingsRepository

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
  }

  var activeCount: Int {
    orders.filter { $0.status != .delivered }.count
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
    reviewOrders.count + reviewMailEvents.count + reviewIntakeEmails.count
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
  }

  func clearIssue(for orderNumber: String) {
    for index in orders.indices where orders[index].orderNumber == orderNumber {
      orders[index].reviewState = .accepted
      if orders[index].status == .exception {
        orders[index].status = .inTransit
      }
      orders[index].latestStatus = "Issue cleared by user review"
      orders[index].contactHistory.insert(ContactHistoryEvent(time: "Now", source: .manual, contactPoint: "Needs Review", summary: "User cleared the issue.", evidence: "Related review entries were resolved together.", reviewState: .accepted), at: 0)
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
  }

  func markIntakeEmailReviewed(_ email: ForwardedEmailIntake) {
    updateIntakeEmail(email, reviewState: .reviewed)
  }

  func ignoreIntakeEmail(_ email: ForwardedEmailIntake) {
    updateIntakeEmail(email, reviewState: .ignored)
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

  private func updateIntakeEmail(_ email: ForwardedEmailIntake, reviewState: IntakeEmailReviewState) {
    guard let index = intakeEmails.firstIndex(where: { $0.id == email.id }) else { return }
    intakeEmails[index].reviewState = reviewState
    persistIntakeEmails()
  }
}

private extension String {
  var isPlaceholder: Bool {
    let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty || normalized == "pending" || normalized == "not detected"
  }
}
