import Foundation

protocol OrderRepository {
  func loadOrders() -> [TrackedOrder]
  func saveOrders(_ orders: [TrackedOrder])
}

protocol MailEventRepository {
  func loadMailEvents() -> [MailEvent]
  func saveMailEvents(_ events: [MailEvent])
}

protocol IntakeEmailRepository {
  func loadIntakeEmails() -> [ForwardedEmailIntake]
  func saveIntakeEmails(_ emails: [ForwardedEmailIntake])
}

protocol IntegrationRepository {
  func loadMailboxes() -> [TrackedMailbox]
  func saveMailboxes(_ mailboxes: [TrackedMailbox])
  func loadShopifyConnections() -> [ShopifyConnection]
  func saveShopifyConnections(_ connections: [ShopifyConnection])
  func loadWatchedFolders() -> [WatchedFolder]
  func saveWatchedFolders(_ folders: [WatchedFolder])
  func loadSourceConnections() -> [SourceConnection]
  func saveSourceConnections(_ connections: [SourceConnection])
}

protocol WishlistRepository {
  func loadWishlistItems() -> [WishlistItem]
  func saveWishlistItems(_ items: [WishlistItem])
  func loadDeletedWishlistItems() -> [WishlistItem]
  func saveDeletedWishlistItems(_ items: [WishlistItem])
}

protocol SettingsRepository {
  func loadSettings() -> ParcelOpsSettings
  func saveSettings(_ settings: ParcelOpsSettings)
}

protocol AuditRepository {
  func loadAuditEvents() -> [AuditEvent]
  func saveAuditEvents(_ events: [AuditEvent])
}

protocol EvidenceRepository {
  func loadEvidenceAttachments() -> [EvidenceAttachment]
  func saveEvidenceAttachments(_ attachments: [EvidenceAttachment])
}

protocol TrackingRepository {
  func loadCarrierTrackingEvents() -> [CarrierTrackingEvent]
  func saveCarrierTrackingEvents(_ events: [CarrierTrackingEvent])
}

protocol AutomationRuleRepository {
  func loadAutomationRules() -> [AutomationRule]
  func saveAutomationRules(_ rules: [AutomationRule])
}

protocol SavedFilterRepository {
  func loadSavedFilters() -> [SavedFilter]
  func saveSavedFilters(_ filters: [SavedFilter])
}

protocol ReviewTaskRepository {
  func loadReviewTasks() -> [ReviewTask]
  func saveReviewTasks(_ tasks: [ReviewTask])
}

protocol SLAPolicyRepository {
  func loadSLAPolicies() -> [SLAPolicy]
  func saveSLAPolicies(_ policies: [SLAPolicy])
}

protocol CommunicationRepository {
  func loadCommunicationTemplates() -> [CommunicationTemplate]
  func saveCommunicationTemplates(_ templates: [CommunicationTemplate])
  func loadDraftMessages() -> [DraftMessage]
  func saveDraftMessages(_ messages: [DraftMessage])
}

protocol ContactDirectoryRepository {
  func loadContactDirectoryEntries() -> [ContactDirectoryEntry]
  func saveContactDirectoryEntries(_ contacts: [ContactDirectoryEntry])
}

protocol AccountCredentialRepository {
  func loadAccountCredentialRecords() -> [AccountCredentialRecord]
  func saveAccountCredentialRecords(_ accounts: [AccountCredentialRecord])
}

protocol VendorProfileRepository {
  func loadVendorProfiles() -> [VendorProfile]
  func saveVendorProfiles(_ profiles: [VendorProfile])
}

protocol ShipmentGroupRepository {
  func loadShipmentGroups() -> [ShipmentGroup]
  func saveShipmentGroups(_ groups: [ShipmentGroup])
}

protocol ImportQueueRepository {
  func loadImportQueueItems() -> [ImportQueueItem]
  func saveImportQueueItems(_ items: [ImportQueueItem])
}

final class JSONParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, IntegrationRepository, WishlistRepository, SettingsRepository, AuditRepository, EvidenceRepository, TrackingRepository, AutomationRuleRepository, SavedFilterRepository, ReviewTaskRepository, SLAPolicyRepository, CommunicationRepository, ContactDirectoryRepository, AccountCredentialRepository, VendorProfileRepository, ShipmentGroupRepository, ImportQueueRepository {
  private let storeDirectory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    fileManager: FileManager = .default,
    storeDirectory: URL? = nil
  ) {
    self.fileManager = fileManager
    self.storeDirectory = storeDirectory ?? Self.defaultStoreDirectory(fileManager: fileManager)
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    createStoreDirectoryIfNeeded()
  }

  func loadOrders() -> [TrackedOrder] {
    load([TrackedOrder].self, from: .orders, defaultValue: SampleData.orders)
  }

  func saveOrders(_ orders: [TrackedOrder]) {
    save(orders, to: .orders)
  }

  func loadMailEvents() -> [MailEvent] {
    load([MailEvent].self, from: .mailEvents, defaultValue: SampleData.mailEvents)
  }

  func saveMailEvents(_ events: [MailEvent]) {
    save(events, to: .mailEvents)
  }

  func loadIntakeEmails() -> [ForwardedEmailIntake] {
    load([ForwardedEmailIntake].self, from: .intakeEmails, defaultValue: SampleData.intakeEmails)
  }

  func saveIntakeEmails(_ emails: [ForwardedEmailIntake]) {
    save(emails, to: .intakeEmails)
  }

  func loadMailboxes() -> [TrackedMailbox] {
    load([TrackedMailbox].self, from: .mailboxes, defaultValue: SampleData.mailboxes)
  }

  func saveMailboxes(_ mailboxes: [TrackedMailbox]) {
    save(mailboxes, to: .mailboxes)
  }

  func loadShopifyConnections() -> [ShopifyConnection] {
    load([ShopifyConnection].self, from: .shopifyConnections, defaultValue: SampleData.shopifyConnections)
  }

  func saveShopifyConnections(_ connections: [ShopifyConnection]) {
    save(connections, to: .shopifyConnections)
  }

  func loadWatchedFolders() -> [WatchedFolder] {
    load([WatchedFolder].self, from: .watchedFolders, defaultValue: SampleData.watchedFolders)
  }

  func saveWatchedFolders(_ folders: [WatchedFolder]) {
    save(folders, to: .watchedFolders)
  }

  func loadSourceConnections() -> [SourceConnection] {
    load([SourceConnection].self, from: .sourceConnections, defaultValue: SampleData.connections)
  }

  func saveSourceConnections(_ connections: [SourceConnection]) {
    save(connections, to: .sourceConnections)
  }

  func loadWishlistItems() -> [WishlistItem] {
    load([WishlistItem].self, from: .wishlistItems, defaultValue: SampleData.wishlistItems)
  }

  func saveWishlistItems(_ items: [WishlistItem]) {
    save(items, to: .wishlistItems)
  }

  func loadDeletedWishlistItems() -> [WishlistItem] {
    load([WishlistItem].self, from: .deletedWishlistItems, defaultValue: SampleData.deletedWishlistItems)
  }

  func saveDeletedWishlistItems(_ items: [WishlistItem]) {
    save(items, to: .deletedWishlistItems)
  }

  func loadSettings() -> ParcelOpsSettings {
    load(ParcelOpsSettings.self, from: .settings, defaultValue: ParcelOpsSettings())
  }

  func saveSettings(_ settings: ParcelOpsSettings) {
    save(settings, to: .settings)
  }

  func loadAuditEvents() -> [AuditEvent] {
    load([AuditEvent].self, from: .auditEvents, defaultValue: SampleData.auditEvents)
  }

  func saveAuditEvents(_ events: [AuditEvent]) {
    save(events, to: .auditEvents)
  }

  func loadEvidenceAttachments() -> [EvidenceAttachment] {
    load([EvidenceAttachment].self, from: .evidenceAttachments, defaultValue: SampleData.evidenceAttachments)
  }

  func saveEvidenceAttachments(_ attachments: [EvidenceAttachment]) {
    save(attachments, to: .evidenceAttachments)
  }

  func loadCarrierTrackingEvents() -> [CarrierTrackingEvent] {
    load([CarrierTrackingEvent].self, from: .carrierTrackingEvents, defaultValue: SampleData.carrierTrackingEvents)
  }

  func saveCarrierTrackingEvents(_ events: [CarrierTrackingEvent]) {
    save(events, to: .carrierTrackingEvents)
  }

  func loadAutomationRules() -> [AutomationRule] {
    load([AutomationRule].self, from: .automationRules, defaultValue: SampleData.automationRules)
  }

  func saveAutomationRules(_ rules: [AutomationRule]) {
    save(rules, to: .automationRules)
  }

  func loadSavedFilters() -> [SavedFilter] {
    load([SavedFilter].self, from: .savedFilters, defaultValue: SampleData.savedFilters)
  }

  func saveSavedFilters(_ filters: [SavedFilter]) {
    save(filters, to: .savedFilters)
  }

  func loadReviewTasks() -> [ReviewTask] {
    load([ReviewTask].self, from: .reviewTasks, defaultValue: SampleData.reviewTasks)
  }

  func saveReviewTasks(_ tasks: [ReviewTask]) {
    save(tasks, to: .reviewTasks)
  }

  func loadSLAPolicies() -> [SLAPolicy] {
    load([SLAPolicy].self, from: .slaPolicies, defaultValue: SampleData.slaPolicies)
  }

  func saveSLAPolicies(_ policies: [SLAPolicy]) {
    save(policies, to: .slaPolicies)
  }

  func loadCommunicationTemplates() -> [CommunicationTemplate] {
    load([CommunicationTemplate].self, from: .communicationTemplates, defaultValue: SampleData.communicationTemplates)
  }

  func saveCommunicationTemplates(_ templates: [CommunicationTemplate]) {
    save(templates, to: .communicationTemplates)
  }

  func loadDraftMessages() -> [DraftMessage] {
    load([DraftMessage].self, from: .draftMessages, defaultValue: SampleData.draftMessages)
  }

  func saveDraftMessages(_ messages: [DraftMessage]) {
    save(messages, to: .draftMessages)
  }

  func loadContactDirectoryEntries() -> [ContactDirectoryEntry] {
    load([ContactDirectoryEntry].self, from: .contactDirectoryEntries, defaultValue: SampleData.contactDirectoryEntries)
  }

  func saveContactDirectoryEntries(_ contacts: [ContactDirectoryEntry]) {
    save(contacts, to: .contactDirectoryEntries)
  }

  func loadAccountCredentialRecords() -> [AccountCredentialRecord] {
    load([AccountCredentialRecord].self, from: .accountCredentialRecords, defaultValue: SampleData.accountCredentialRecords)
  }

  func saveAccountCredentialRecords(_ accounts: [AccountCredentialRecord]) {
    save(accounts, to: .accountCredentialRecords)
  }

  func loadVendorProfiles() -> [VendorProfile] {
    load([VendorProfile].self, from: .vendorProfiles, defaultValue: SampleData.vendorProfiles)
  }

  func saveVendorProfiles(_ profiles: [VendorProfile]) {
    save(profiles, to: .vendorProfiles)
  }

  func loadShipmentGroups() -> [ShipmentGroup] {
    load([ShipmentGroup].self, from: .shipmentGroups, defaultValue: SampleData.shipmentGroups)
  }

  func saveShipmentGroups(_ groups: [ShipmentGroup]) {
    save(groups, to: .shipmentGroups)
  }

  func loadImportQueueItems() -> [ImportQueueItem] {
    load([ImportQueueItem].self, from: .importQueueItems, defaultValue: SampleData.importQueueItems)
  }

  func saveImportQueueItems(_ items: [ImportQueueItem]) {
    save(items, to: .importQueueItems)
  }

  private static func defaultStoreDirectory(fileManager: FileManager) -> URL {
    #if os(macOS)
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
    #else
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? fileManager.temporaryDirectory
    #endif
    return baseURL.appendingPathComponent("ParcelOps", isDirectory: true)
  }

  private func createStoreDirectoryIfNeeded() {
    try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
  }

  private func fileURL(for file: StoreFile) -> URL {
    storeDirectory.appendingPathComponent(file.rawValue, isDirectory: false)
  }

  private func load<Value: Codable>(_ type: Value.Type, from file: StoreFile, defaultValue: Value) -> Value {
    let url = fileURL(for: file)
    guard fileManager.fileExists(atPath: url.path) else {
      save(defaultValue, to: file)
      return defaultValue
    }

    do {
      let data = try Data(contentsOf: url)
      return try decoder.decode(Value.self, from: data)
    } catch {
      archiveCorruptFile(at: url)
      save(defaultValue, to: file)
      return defaultValue
    }
  }

  private func save<Value: Encodable>(_ value: Value, to file: StoreFile) {
    createStoreDirectoryIfNeeded()
    let url = fileURL(for: file)

    do {
      let data = try encoder.encode(value)
      try data.write(to: url, options: [.atomic])
    } catch {
      assertionFailure("Failed to save \(file.rawValue): \(error.localizedDescription)")
    }
  }

  private func archiveCorruptFile(at url: URL) {
    let archiveURL = url.deletingPathExtension()
      .appendingPathExtension("invalid-\(Int(Date().timeIntervalSince1970)).json")
    try? fileManager.moveItem(at: url, to: archiveURL)
  }

  private enum StoreFile: String {
    case orders = "orders.json"
    case mailEvents = "mail-events.json"
    case intakeEmails = "intake-emails.json"
    case mailboxes = "mailboxes.json"
    case shopifyConnections = "shopify-connections.json"
    case watchedFolders = "watched-folders.json"
    case sourceConnections = "source-connections.json"
    case wishlistItems = "wishlist-items.json"
    case deletedWishlistItems = "deleted-wishlist-items.json"
    case settings = "settings.json"
    case auditEvents = "audit-events.json"
    case evidenceAttachments = "evidence-attachments.json"
    case carrierTrackingEvents = "carrier-tracking-events.json"
    case automationRules = "automation-rules.json"
    case savedFilters = "saved-filters.json"
    case reviewTasks = "review-tasks.json"
    case slaPolicies = "sla-policies.json"
    case communicationTemplates = "communication-templates.json"
    case draftMessages = "draft-messages.json"
    case contactDirectoryEntries = "contact-directory.json"
    case accountCredentialRecords = "account-credential-records.json"
    case vendorProfiles = "vendor-profiles.json"
    case shipmentGroups = "shipment-groups.json"
    case importQueueItems = "import-queue-items.json"
  }
}

final class InMemoryParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, IntegrationRepository, WishlistRepository, SettingsRepository, AuditRepository, EvidenceRepository, TrackingRepository, AutomationRuleRepository, SavedFilterRepository, ReviewTaskRepository, SLAPolicyRepository, CommunicationRepository, ContactDirectoryRepository, AccountCredentialRepository, VendorProfileRepository, ShipmentGroupRepository, ImportQueueRepository {
  private var orders = SampleData.orders
  private var mailEvents = SampleData.mailEvents
  private var intakeEmails = SampleData.intakeEmails
  private var mailboxes = SampleData.mailboxes
  private var shopifyConnections = SampleData.shopifyConnections
  private var watchedFolders = SampleData.watchedFolders
  private var sourceConnections = SampleData.connections
  private var wishlistItems = SampleData.wishlistItems
  private var deletedWishlistItems = SampleData.deletedWishlistItems
  private var settings = ParcelOpsSettings()
  private var auditEvents = SampleData.auditEvents
  private var evidenceAttachments = SampleData.evidenceAttachments
  private var carrierTrackingEvents = SampleData.carrierTrackingEvents
  private var automationRules = SampleData.automationRules
  private var savedFilters = SampleData.savedFilters
  private var reviewTasks = SampleData.reviewTasks
  private var slaPolicies = SampleData.slaPolicies
  private var communicationTemplates = SampleData.communicationTemplates
  private var draftMessages = SampleData.draftMessages
  private var contactDirectoryEntries = SampleData.contactDirectoryEntries
  private var accountCredentialRecords = SampleData.accountCredentialRecords
  private var vendorProfiles = SampleData.vendorProfiles
  private var shipmentGroups = SampleData.shipmentGroups
  private var importQueueItems = SampleData.importQueueItems

  func loadOrders() -> [TrackedOrder] { orders }
  func saveOrders(_ orders: [TrackedOrder]) { self.orders = orders }

  func loadMailEvents() -> [MailEvent] { mailEvents }
  func saveMailEvents(_ events: [MailEvent]) { mailEvents = events }

  func loadIntakeEmails() -> [ForwardedEmailIntake] { intakeEmails }
  func saveIntakeEmails(_ emails: [ForwardedEmailIntake]) { intakeEmails = emails }

  func loadMailboxes() -> [TrackedMailbox] { mailboxes }
  func saveMailboxes(_ mailboxes: [TrackedMailbox]) { self.mailboxes = mailboxes }

  func loadShopifyConnections() -> [ShopifyConnection] { shopifyConnections }
  func saveShopifyConnections(_ connections: [ShopifyConnection]) { shopifyConnections = connections }

  func loadWatchedFolders() -> [WatchedFolder] { watchedFolders }
  func saveWatchedFolders(_ folders: [WatchedFolder]) { watchedFolders = folders }

  func loadSourceConnections() -> [SourceConnection] { sourceConnections }
  func saveSourceConnections(_ connections: [SourceConnection]) { sourceConnections = connections }

  func loadWishlistItems() -> [WishlistItem] { wishlistItems }
  func saveWishlistItems(_ items: [WishlistItem]) { wishlistItems = items }

  func loadDeletedWishlistItems() -> [WishlistItem] { deletedWishlistItems }
  func saveDeletedWishlistItems(_ items: [WishlistItem]) { deletedWishlistItems = items }

  func loadSettings() -> ParcelOpsSettings { settings }
  func saveSettings(_ settings: ParcelOpsSettings) { self.settings = settings }

  func loadAuditEvents() -> [AuditEvent] { auditEvents }
  func saveAuditEvents(_ events: [AuditEvent]) { auditEvents = events }

  func loadEvidenceAttachments() -> [EvidenceAttachment] { evidenceAttachments }
  func saveEvidenceAttachments(_ attachments: [EvidenceAttachment]) { evidenceAttachments = attachments }

  func loadCarrierTrackingEvents() -> [CarrierTrackingEvent] { carrierTrackingEvents }
  func saveCarrierTrackingEvents(_ events: [CarrierTrackingEvent]) { carrierTrackingEvents = events }

  func loadAutomationRules() -> [AutomationRule] { automationRules }
  func saveAutomationRules(_ rules: [AutomationRule]) { automationRules = rules }

  func loadSavedFilters() -> [SavedFilter] { savedFilters }
  func saveSavedFilters(_ filters: [SavedFilter]) { savedFilters = filters }

  func loadReviewTasks() -> [ReviewTask] { reviewTasks }
  func saveReviewTasks(_ tasks: [ReviewTask]) { reviewTasks = tasks }

  func loadSLAPolicies() -> [SLAPolicy] { slaPolicies }
  func saveSLAPolicies(_ policies: [SLAPolicy]) { slaPolicies = policies }

  func loadCommunicationTemplates() -> [CommunicationTemplate] { communicationTemplates }
  func saveCommunicationTemplates(_ templates: [CommunicationTemplate]) { communicationTemplates = templates }

  func loadDraftMessages() -> [DraftMessage] { draftMessages }
  func saveDraftMessages(_ messages: [DraftMessage]) { draftMessages = messages }

  func loadContactDirectoryEntries() -> [ContactDirectoryEntry] { contactDirectoryEntries }
  func saveContactDirectoryEntries(_ contacts: [ContactDirectoryEntry]) { contactDirectoryEntries = contacts }

  func loadAccountCredentialRecords() -> [AccountCredentialRecord] { accountCredentialRecords }
  func saveAccountCredentialRecords(_ accounts: [AccountCredentialRecord]) { accountCredentialRecords = accounts }

  func loadVendorProfiles() -> [VendorProfile] { vendorProfiles }
  func saveVendorProfiles(_ profiles: [VendorProfile]) { vendorProfiles = profiles }

  func loadShipmentGroups() -> [ShipmentGroup] { shipmentGroups }
  func saveShipmentGroups(_ groups: [ShipmentGroup]) { shipmentGroups = groups }

  func loadImportQueueItems() -> [ImportQueueItem] { importQueueItems }
  func saveImportQueueItems(_ items: [ImportQueueItem]) { importQueueItems = items }
}
