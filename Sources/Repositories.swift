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

final class JSONParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, IntegrationRepository, WishlistRepository, SettingsRepository {
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
  }
}

final class InMemoryParcelOpsRepository: OrderRepository, MailEventRepository, IntakeEmailRepository, IntegrationRepository, WishlistRepository, SettingsRepository {
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
}
