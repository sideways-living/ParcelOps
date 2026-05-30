import Foundation

protocol OrderRepository {
  func loadOrders() -> [TrackedOrder]
  func saveOrders(_ orders: [TrackedOrder])
}

protocol MailEventRepository {
  func loadMailEvents() -> [MailEvent]
  func saveMailEvents(_ events: [MailEvent])
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

final class InMemoryParcelOpsRepository: OrderRepository, MailEventRepository, IntegrationRepository, WishlistRepository, SettingsRepository {
  private var orders = SampleData.orders
  private var mailEvents = SampleData.mailEvents
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
