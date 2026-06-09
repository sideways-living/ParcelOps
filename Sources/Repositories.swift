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

protocol MailboxIngestRepository {
  func loadMailboxIngestRecords() -> [MailboxIngestRecord]
  func saveMailboxIngestRecords(_ records: [MailboxIngestRecord])
}

protocol IntegrationRepository {
  func loadMailboxes() -> [TrackedMailbox]
  func saveMailboxes(_ mailboxes: [TrackedMailbox])
  func loadMicrosoft365MailboxConnections() -> [Microsoft365MailboxConnection]
  func saveMicrosoft365MailboxConnections(_ connections: [Microsoft365MailboxConnection])
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

protocol HandoffNoteRepository {
  func loadHandoffNotes() -> [HandoffNote]
  func saveHandoffNotes(_ notes: [HandoffNote])
}

protocol SLAPolicyRepository {
  func loadSLAPolicies() -> [SLAPolicy]
  func saveSLAPolicies(_ policies: [SLAPolicy])
}

protocol ExceptionPlaybookRepository {
  func loadExceptionPlaybooks() -> [ExceptionPlaybook]
  func saveExceptionPlaybooks(_ playbooks: [ExceptionPlaybook])
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

protocol CustomerRecipientProfileRepository {
  func loadCustomerRecipientProfiles() -> [CustomerRecipientProfile]
  func saveCustomerRecipientProfiles(_ profiles: [CustomerRecipientProfile])
}

protocol DestinationAddressRepository {
  func loadDestinationAddresses() -> [DestinationAddressRecord]
  func saveDestinationAddresses(_ addresses: [DestinationAddressRecord])
}

protocol DeliveryInstructionRepository {
  func loadDeliveryInstructions() -> [DeliveryInstructionRecord]
  func saveDeliveryInstructions(_ instructions: [DeliveryInstructionRecord])
}

protocol PackageContentRepository {
  func loadPackageContents() -> [PackageContentRecord]
  func savePackageContents(_ contents: [PackageContentRecord])
}

protocol CostRecordRepository {
  func loadCostRecords() -> [CostRecord]
  func saveCostRecords(_ costs: [CostRecord])
}

protocol ReturnClaimRepository {
  func loadReturnClaims() -> [ReturnClaimRecord]
  func saveReturnClaims(_ claims: [ReturnClaimRecord])
}

protocol ProcurementRequestRepository {
  func loadProcurementRequests() -> [ProcurementRequest]
  func saveProcurementRequests(_ requests: [ProcurementRequest])
}

protocol ReceivingInspectionRepository {
  func loadReceivingInspections() -> [ReceivingInspectionRecord]
  func saveReceivingInspections(_ inspections: [ReceivingInspectionRecord])
}

protocol InventoryReceiptRepository {
  func loadInventoryReceipts() -> [InventoryReceiptRecord]
  func saveInventoryReceipts(_ receipts: [InventoryReceiptRecord])
}

protocol StorageLocationRepository {
  func loadStorageLocations() -> [StorageLocationRecord]
  func saveStorageLocations(_ locations: [StorageLocationRecord])
}

protocol CustodyRepository {
  func loadCustodyRecords() -> [CustodyRecord]
  func saveCustodyRecords(_ records: [CustodyRecord])
}

protocol LabelReferenceRepository {
  func loadLabelReferenceRecords() -> [LabelReferenceRecord]
  func saveLabelReferenceRecords(_ records: [LabelReferenceRecord])
}

protocol ScanSessionRepository {
  func loadScanSessionRecords() -> [ScanSessionRecord]
  func saveScanSessionRecords(_ records: [ScanSessionRecord])
}

protocol ShipmentManifestRepository {
  func loadShipmentManifestRecords() -> [ShipmentManifestRecord]
  func saveShipmentManifestRecords(_ records: [ShipmentManifestRecord])
}

protocol DispatchReadinessRepository {
  func loadDispatchReadinessChecklists() -> [DispatchReadinessChecklist]
  func saveDispatchReadinessChecklists(_ checklists: [DispatchReadinessChecklist])
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

protocol AcceptanceRepository {
  func loadAcceptanceRecords() -> [AcceptanceRecord]
  func saveAcceptanceRecords(_ records: [AcceptanceRecord])
}

final class JSONParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, MailboxIngestRepository, IntegrationRepository, WishlistRepository, SettingsRepository, AuditRepository, EvidenceRepository, TrackingRepository, AutomationRuleRepository, SavedFilterRepository, ReviewTaskRepository, HandoffNoteRepository, SLAPolicyRepository, ExceptionPlaybookRepository, CommunicationRepository, ContactDirectoryRepository, CustomerRecipientProfileRepository, DestinationAddressRepository, DeliveryInstructionRepository, PackageContentRepository, CostRecordRepository, ReturnClaimRepository, ProcurementRequestRepository, ReceivingInspectionRepository, InventoryReceiptRepository, StorageLocationRepository, CustodyRepository, LabelReferenceRepository, ScanSessionRepository, ShipmentManifestRepository, DispatchReadinessRepository, AccountCredentialRepository, VendorProfileRepository, ShipmentGroupRepository, ImportQueueRepository, AcceptanceRepository {
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

  func loadMailboxIngestRecords() -> [MailboxIngestRecord] {
    load([MailboxIngestRecord].self, from: .mailboxIngestRecords, defaultValue: [])
  }

  func saveMailboxIngestRecords(_ records: [MailboxIngestRecord]) {
    save(records, to: .mailboxIngestRecords)
  }

  func loadMailboxes() -> [TrackedMailbox] {
    load([TrackedMailbox].self, from: .mailboxes, defaultValue: SampleData.mailboxes)
  }

  func saveMailboxes(_ mailboxes: [TrackedMailbox]) {
    save(mailboxes, to: .mailboxes)
  }

  func loadMicrosoft365MailboxConnections() -> [Microsoft365MailboxConnection] {
    load([Microsoft365MailboxConnection].self, from: .microsoft365MailboxConnections, defaultValue: SampleData.microsoft365MailboxConnections)
  }

  func saveMicrosoft365MailboxConnections(_ connections: [Microsoft365MailboxConnection]) {
    save(connections, to: .microsoft365MailboxConnections)
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

  func loadHandoffNotes() -> [HandoffNote] {
    load([HandoffNote].self, from: .handoffNotes, defaultValue: SampleData.handoffNotes)
  }

  func saveHandoffNotes(_ notes: [HandoffNote]) {
    save(notes, to: .handoffNotes)
  }

  func loadSLAPolicies() -> [SLAPolicy] {
    load([SLAPolicy].self, from: .slaPolicies, defaultValue: SampleData.slaPolicies)
  }

  func saveSLAPolicies(_ policies: [SLAPolicy]) {
    save(policies, to: .slaPolicies)
  }

  func loadExceptionPlaybooks() -> [ExceptionPlaybook] {
    load([ExceptionPlaybook].self, from: .exceptionPlaybooks, defaultValue: SampleData.exceptionPlaybooks)
  }

  func saveExceptionPlaybooks(_ playbooks: [ExceptionPlaybook]) {
    save(playbooks, to: .exceptionPlaybooks)
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

  func loadCustomerRecipientProfiles() -> [CustomerRecipientProfile] {
    load([CustomerRecipientProfile].self, from: .customerRecipientProfiles, defaultValue: SampleData.customerRecipientProfiles)
  }

  func saveCustomerRecipientProfiles(_ profiles: [CustomerRecipientProfile]) {
    save(profiles, to: .customerRecipientProfiles)
  }

  func loadDestinationAddresses() -> [DestinationAddressRecord] {
    load([DestinationAddressRecord].self, from: .destinationAddresses, defaultValue: SampleData.destinationAddresses)
  }

  func saveDestinationAddresses(_ addresses: [DestinationAddressRecord]) {
    save(addresses, to: .destinationAddresses)
  }

  func loadDeliveryInstructions() -> [DeliveryInstructionRecord] {
    load([DeliveryInstructionRecord].self, from: .deliveryInstructions, defaultValue: SampleData.deliveryInstructions)
  }

  func saveDeliveryInstructions(_ instructions: [DeliveryInstructionRecord]) {
    save(instructions, to: .deliveryInstructions)
  }

  func loadPackageContents() -> [PackageContentRecord] {
    load([PackageContentRecord].self, from: .packageContents, defaultValue: SampleData.packageContents)
  }

  func savePackageContents(_ contents: [PackageContentRecord]) {
    save(contents, to: .packageContents)
  }

  func loadCostRecords() -> [CostRecord] {
    load([CostRecord].self, from: .costRecords, defaultValue: SampleData.costRecords)
  }

  func saveCostRecords(_ costs: [CostRecord]) {
    save(costs, to: .costRecords)
  }

  func loadReturnClaims() -> [ReturnClaimRecord] {
    load([ReturnClaimRecord].self, from: .returnClaims, defaultValue: SampleData.returnClaims)
  }

  func saveReturnClaims(_ claims: [ReturnClaimRecord]) {
    save(claims, to: .returnClaims)
  }

  func loadProcurementRequests() -> [ProcurementRequest] {
    load([ProcurementRequest].self, from: .procurementRequests, defaultValue: SampleData.procurementRequests)
  }

  func saveProcurementRequests(_ requests: [ProcurementRequest]) {
    save(requests, to: .procurementRequests)
  }

  func loadReceivingInspections() -> [ReceivingInspectionRecord] {
    load([ReceivingInspectionRecord].self, from: .receivingInspections, defaultValue: SampleData.receivingInspections)
  }

  func saveReceivingInspections(_ inspections: [ReceivingInspectionRecord]) {
    save(inspections, to: .receivingInspections)
  }

  func loadInventoryReceipts() -> [InventoryReceiptRecord] {
    load([InventoryReceiptRecord].self, from: .inventoryReceipts, defaultValue: SampleData.inventoryReceipts)
  }

  func saveInventoryReceipts(_ receipts: [InventoryReceiptRecord]) {
    save(receipts, to: .inventoryReceipts)
  }

  func loadStorageLocations() -> [StorageLocationRecord] {
    load([StorageLocationRecord].self, from: .storageLocations, defaultValue: SampleData.storageLocations)
  }

  func saveStorageLocations(_ locations: [StorageLocationRecord]) {
    save(locations, to: .storageLocations)
  }

  func loadCustodyRecords() -> [CustodyRecord] {
    load([CustodyRecord].self, from: .custodyRecords, defaultValue: SampleData.custodyRecords)
  }

  func saveCustodyRecords(_ records: [CustodyRecord]) {
    save(records, to: .custodyRecords)
  }

  func loadLabelReferenceRecords() -> [LabelReferenceRecord] {
    load([LabelReferenceRecord].self, from: .labelReferenceRecords, defaultValue: SampleData.labelReferenceRecords)
  }

  func saveLabelReferenceRecords(_ records: [LabelReferenceRecord]) {
    save(records, to: .labelReferenceRecords)
  }

  func loadScanSessionRecords() -> [ScanSessionRecord] {
    load([ScanSessionRecord].self, from: .scanSessionRecords, defaultValue: SampleData.scanSessionRecords)
  }

  func saveScanSessionRecords(_ records: [ScanSessionRecord]) {
    save(records, to: .scanSessionRecords)
  }

  func loadShipmentManifestRecords() -> [ShipmentManifestRecord] {
    load([ShipmentManifestRecord].self, from: .shipmentManifestRecords, defaultValue: SampleData.shipmentManifestRecords)
  }

  func saveShipmentManifestRecords(_ records: [ShipmentManifestRecord]) {
    save(records, to: .shipmentManifestRecords)
  }

  func loadDispatchReadinessChecklists() -> [DispatchReadinessChecklist] {
    load([DispatchReadinessChecklist].self, from: .dispatchReadinessChecklists, defaultValue: SampleData.dispatchReadinessChecklists)
  }

  func saveDispatchReadinessChecklists(_ checklists: [DispatchReadinessChecklist]) {
    save(checklists, to: .dispatchReadinessChecklists)
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

  func loadAcceptanceRecords() -> [AcceptanceRecord] {
    load([AcceptanceRecord].self, from: .acceptanceRecords, defaultValue: SampleData.acceptanceRecords)
  }

  func saveAcceptanceRecords(_ records: [AcceptanceRecord]) {
    save(records, to: .acceptanceRecords)
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
    case mailboxIngestRecords = "mailbox-ingest-records.json"
    case mailboxes = "mailboxes.json"
    case microsoft365MailboxConnections = "microsoft365-mailbox-connections.json"
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
    case handoffNotes = "handoff-notes.json"
    case slaPolicies = "sla-policies.json"
    case exceptionPlaybooks = "exception-playbooks.json"
    case communicationTemplates = "communication-templates.json"
    case draftMessages = "draft-messages.json"
    case contactDirectoryEntries = "contact-directory.json"
    case customerRecipientProfiles = "customer-profiles.json"
    case destinationAddresses = "destination-addresses.json"
    case deliveryInstructions = "delivery-instructions.json"
    case packageContents = "package-contents.json"
    case costRecords = "cost-records.json"
    case returnClaims = "return-claims.json"
    case procurementRequests = "procurement-requests.json"
    case receivingInspections = "receiving-inspections.json"
    case inventoryReceipts = "inventory-receipts.json"
    case storageLocations = "storage-locations.json"
    case custodyRecords = "custody-records.json"
    case labelReferenceRecords = "label-reference-records.json"
    case scanSessionRecords = "scan-session-records.json"
    case shipmentManifestRecords = "shipment-manifest-records.json"
    case dispatchReadinessChecklists = "dispatch-readiness-checklists.json"
    case accountCredentialRecords = "account-credential-records.json"
    case vendorProfiles = "vendor-profiles.json"
    case shipmentGroups = "shipment-groups.json"
    case importQueueItems = "import-queue-items.json"
    case acceptanceRecords = "acceptance-records.json"
  }
}

final class InMemoryParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, MailboxIngestRepository, IntegrationRepository, WishlistRepository, SettingsRepository, AuditRepository, EvidenceRepository, TrackingRepository, AutomationRuleRepository, SavedFilterRepository, ReviewTaskRepository, HandoffNoteRepository, SLAPolicyRepository, ExceptionPlaybookRepository, CommunicationRepository, ContactDirectoryRepository, CustomerRecipientProfileRepository, DestinationAddressRepository, DeliveryInstructionRepository, PackageContentRepository, CostRecordRepository, ReturnClaimRepository, ProcurementRequestRepository, ReceivingInspectionRepository, InventoryReceiptRepository, StorageLocationRepository, CustodyRepository, LabelReferenceRepository, ScanSessionRepository, ShipmentManifestRepository, DispatchReadinessRepository, AccountCredentialRepository, VendorProfileRepository, ShipmentGroupRepository, ImportQueueRepository, AcceptanceRepository {
  private var orders = SampleData.orders
  private var mailEvents = SampleData.mailEvents
  private var intakeEmails = SampleData.intakeEmails
  private var mailboxIngestRecords: [MailboxIngestRecord] = []
  private var mailboxes = SampleData.mailboxes
  private var microsoft365MailboxConnections = SampleData.microsoft365MailboxConnections
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
  private var handoffNotes = SampleData.handoffNotes
  private var slaPolicies = SampleData.slaPolicies
  private var exceptionPlaybooks = SampleData.exceptionPlaybooks
  private var communicationTemplates = SampleData.communicationTemplates
  private var draftMessages = SampleData.draftMessages
  private var contactDirectoryEntries = SampleData.contactDirectoryEntries
  private var customerRecipientProfiles = SampleData.customerRecipientProfiles
  private var destinationAddresses = SampleData.destinationAddresses
  private var deliveryInstructions = SampleData.deliveryInstructions
  private var packageContents = SampleData.packageContents
  private var costRecords = SampleData.costRecords
  private var returnClaims = SampleData.returnClaims
  private var procurementRequests = SampleData.procurementRequests
  private var receivingInspections = SampleData.receivingInspections
  private var inventoryReceipts = SampleData.inventoryReceipts
  private var storageLocations = SampleData.storageLocations
  private var custodyRecords = SampleData.custodyRecords
  private var labelReferenceRecords = SampleData.labelReferenceRecords
  private var scanSessionRecords = SampleData.scanSessionRecords
  private var shipmentManifestRecords = SampleData.shipmentManifestRecords
  private var dispatchReadinessChecklists = SampleData.dispatchReadinessChecklists
  private var accountCredentialRecords = SampleData.accountCredentialRecords
  private var vendorProfiles = SampleData.vendorProfiles
  private var shipmentGroups = SampleData.shipmentGroups
  private var importQueueItems = SampleData.importQueueItems
  private var acceptanceRecords = SampleData.acceptanceRecords

  func loadOrders() -> [TrackedOrder] { orders }
  func saveOrders(_ orders: [TrackedOrder]) { self.orders = orders }

  func loadMailEvents() -> [MailEvent] { mailEvents }
  func saveMailEvents(_ events: [MailEvent]) { mailEvents = events }

  func loadIntakeEmails() -> [ForwardedEmailIntake] { intakeEmails }
  func saveIntakeEmails(_ emails: [ForwardedEmailIntake]) { intakeEmails = emails }
  func loadMailboxIngestRecords() -> [MailboxIngestRecord] { mailboxIngestRecords }
  func saveMailboxIngestRecords(_ records: [MailboxIngestRecord]) { mailboxIngestRecords = records }

  func loadMailboxes() -> [TrackedMailbox] { mailboxes }
  func saveMailboxes(_ mailboxes: [TrackedMailbox]) { self.mailboxes = mailboxes }
  func loadMicrosoft365MailboxConnections() -> [Microsoft365MailboxConnection] { microsoft365MailboxConnections }
  func saveMicrosoft365MailboxConnections(_ connections: [Microsoft365MailboxConnection]) { microsoft365MailboxConnections = connections }

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

  func loadHandoffNotes() -> [HandoffNote] { handoffNotes }
  func saveHandoffNotes(_ notes: [HandoffNote]) { handoffNotes = notes }

  func loadSLAPolicies() -> [SLAPolicy] { slaPolicies }
  func saveSLAPolicies(_ policies: [SLAPolicy]) { slaPolicies = policies }

  func loadExceptionPlaybooks() -> [ExceptionPlaybook] { exceptionPlaybooks }
  func saveExceptionPlaybooks(_ playbooks: [ExceptionPlaybook]) { exceptionPlaybooks = playbooks }

  func loadCommunicationTemplates() -> [CommunicationTemplate] { communicationTemplates }
  func saveCommunicationTemplates(_ templates: [CommunicationTemplate]) { communicationTemplates = templates }

  func loadDraftMessages() -> [DraftMessage] { draftMessages }
  func saveDraftMessages(_ messages: [DraftMessage]) { draftMessages = messages }

  func loadContactDirectoryEntries() -> [ContactDirectoryEntry] { contactDirectoryEntries }
  func saveContactDirectoryEntries(_ contacts: [ContactDirectoryEntry]) { contactDirectoryEntries = contacts }

  func loadCustomerRecipientProfiles() -> [CustomerRecipientProfile] { customerRecipientProfiles }
  func saveCustomerRecipientProfiles(_ profiles: [CustomerRecipientProfile]) { customerRecipientProfiles = profiles }

  func loadDestinationAddresses() -> [DestinationAddressRecord] { destinationAddresses }
  func saveDestinationAddresses(_ addresses: [DestinationAddressRecord]) { destinationAddresses = addresses }

  func loadDeliveryInstructions() -> [DeliveryInstructionRecord] { deliveryInstructions }
  func saveDeliveryInstructions(_ instructions: [DeliveryInstructionRecord]) { deliveryInstructions = instructions }

  func loadPackageContents() -> [PackageContentRecord] { packageContents }
  func savePackageContents(_ contents: [PackageContentRecord]) { packageContents = contents }

  func loadCostRecords() -> [CostRecord] { costRecords }
  func saveCostRecords(_ costs: [CostRecord]) { costRecords = costs }
  func loadReturnClaims() -> [ReturnClaimRecord] { returnClaims }
  func saveReturnClaims(_ claims: [ReturnClaimRecord]) { returnClaims = claims }
  func loadProcurementRequests() -> [ProcurementRequest] { procurementRequests }
  func saveProcurementRequests(_ requests: [ProcurementRequest]) { procurementRequests = requests }
  func loadReceivingInspections() -> [ReceivingInspectionRecord] { receivingInspections }
  func saveReceivingInspections(_ inspections: [ReceivingInspectionRecord]) { receivingInspections = inspections }
  func loadInventoryReceipts() -> [InventoryReceiptRecord] { inventoryReceipts }
  func saveInventoryReceipts(_ receipts: [InventoryReceiptRecord]) { inventoryReceipts = receipts }
  func loadStorageLocations() -> [StorageLocationRecord] { storageLocations }
  func saveStorageLocations(_ locations: [StorageLocationRecord]) { storageLocations = locations }
  func loadCustodyRecords() -> [CustodyRecord] { custodyRecords }
  func saveCustodyRecords(_ records: [CustodyRecord]) { custodyRecords = records }
  func loadLabelReferenceRecords() -> [LabelReferenceRecord] { labelReferenceRecords }
  func saveLabelReferenceRecords(_ records: [LabelReferenceRecord]) { labelReferenceRecords = records }
  func loadScanSessionRecords() -> [ScanSessionRecord] { scanSessionRecords }
  func saveScanSessionRecords(_ records: [ScanSessionRecord]) { scanSessionRecords = records }
  func loadShipmentManifestRecords() -> [ShipmentManifestRecord] { shipmentManifestRecords }
  func saveShipmentManifestRecords(_ records: [ShipmentManifestRecord]) { shipmentManifestRecords = records }
  func loadDispatchReadinessChecklists() -> [DispatchReadinessChecklist] { dispatchReadinessChecklists }
  func saveDispatchReadinessChecklists(_ checklists: [DispatchReadinessChecklist]) { dispatchReadinessChecklists = checklists }

  func loadAccountCredentialRecords() -> [AccountCredentialRecord] { accountCredentialRecords }
  func saveAccountCredentialRecords(_ accounts: [AccountCredentialRecord]) { accountCredentialRecords = accounts }

  func loadVendorProfiles() -> [VendorProfile] { vendorProfiles }
  func saveVendorProfiles(_ profiles: [VendorProfile]) { vendorProfiles = profiles }

  func loadShipmentGroups() -> [ShipmentGroup] { shipmentGroups }
  func saveShipmentGroups(_ groups: [ShipmentGroup]) { shipmentGroups = groups }

  func loadImportQueueItems() -> [ImportQueueItem] { importQueueItems }
  func saveImportQueueItems(_ items: [ImportQueueItem]) { importQueueItems = items }

  func loadAcceptanceRecords() -> [AcceptanceRecord] { acceptanceRecords }
  func saveAcceptanceRecords(_ records: [AcceptanceRecord]) { acceptanceRecords = records }
}
