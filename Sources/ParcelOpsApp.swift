import SwiftUI

@main
struct ParcelOpsApp: App {
  var body: some Scene {
    WindowGroup {
      ParcelOpsRootView()
        .parcelOpsWindowFrame()
    }
  }
}

extension View {
  @ViewBuilder
  func parcelOpsWindowFrame() -> some View {
    #if os(macOS)
    self.frame(minWidth: 1120, minHeight: 760)
    #else
    self
    #endif
  }
}

struct ParcelOpsRootView: View {
  @State private var store = ParcelOpsStore()
  @State private var selection: ParcelSection = .dashboard
  @State private var isMoreMenuExpanded = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    GeometryReader { proxy in
      let usePhoneLayout = horizontalSizeClass == .compact || proxy.size.width < 700

      Group {
        if usePhoneLayout {
          NavigationStack {
            content(for: selection)
              .navigationTitle(selection.title)
          }
          .safeAreaInset(edge: .bottom) {
            ExpandableBottomMenu(
              selection: $selection,
              isExpanded: $isMoreMenuExpanded,
              onSelect: { section in
              withAnimation(.snappy) {
                selection = section
              }
            })
          }
        } else {
        NavigationSplitView {
          List {
            ForEach(ParcelSection.allCases) { section in
              Button {
                selection = section
              } label: {
                Label(section.title, systemImage: section.symbol)
                  .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
              }
              .buttonStyle(.plain)
            }
          }
          .navigationTitle("ParcelOps")
          .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
              Label("Review required", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
              Text("\(store.reviewQueueCount) risky email/order matches are waiting for confirmation.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
          }
        } detail: {
          content(for: selection)
            .navigationTitle(selection.title)
        }
      }
      }
    }
    .tint(.teal)
  }

  @ViewBuilder
  private func content(for section: ParcelSection) -> some View {
    switch section {
    case .dashboard:
      DashboardView(store: store)
    case .orders:
      OrdersView(store: store)
    case .mailbox:
      MailboxView(events: store.mailEvents)
    case .review:
      NeedsReviewView(store: store)
    case .wishlist:
      WishlistView(items: store.wishlistItems, deletedItems: store.deletedWishlistItems)
    case .integrations:
      IntegrationsView(mailboxes: store.mailboxes, shopifyConnections: store.shopifyConnections, watchedFolders: store.watchedFolders, connections: store.connections)
    case .automation:
      AutomationView()
    case .settings:
      SettingsView(mailboxes: store.mailboxes, shopifyConnections: store.shopifyConnections, watchedFolders: store.watchedFolders)
    }
  }
}

struct ExpandableBottomMenu: View {
  @Binding var selection: ParcelSection
  @Binding var isExpanded: Bool
  var onSelect: (ParcelSection) -> Void

  private var primaryItems: [ParcelSection] {
    [.dashboard, .orders, .review, .settings]
  }

  private var secondaryItems: [ParcelSection] {
    [.wishlist, .mailbox, .integrations, .automation]
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 0) {
        ForEach(primaryItems) { section in
          BottomMenuButton(
            title: section.shortTitle,
            symbol: section.symbol,
            isSelected: selection == section
          ) {
            withAnimation(.snappy) {
              isExpanded = false
              onSelect(section)
            }
          }
        }

        BottomMenuButton(
          title: isExpanded ? "Less" : "More",
          symbol: isExpanded ? "arrow.down" : "arrow.up",
          isSelected: isExpanded
        ) {
          withAnimation(.snappy) {
            isExpanded.toggle()
          }
        }
      }

      if isExpanded {
        HStack(spacing: 0) {
          ForEach(secondaryItems) { section in
            BottomMenuButton(
              title: section.shortTitle,
              symbol: section.symbol,
              isSelected: selection == section
            ) {
              onSelect(section)
            }
          }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 10)
    .padding(.top, 10)
    .padding(.bottom, 8)
    .background(.bar)
  }
}

struct BottomMenuButton: View {
  var title: String
  var symbol: String
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .semibold))
        Text(title)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

@Observable
final class ParcelOpsStore {
  var searchText = ""
  var selectedStatus: OrderStatus?

  var orders: [TrackedOrder] = SampleData.orders
  var mailEvents: [MailEvent] = SampleData.mailEvents
  var mailboxes: [TrackedMailbox] = SampleData.mailboxes
  var shopifyConnections: [ShopifyConnection] = SampleData.shopifyConnections
  var watchedFolders: [WatchedFolder] = SampleData.watchedFolders
  var wishlistItems: [WishlistItem] = SampleData.wishlistItems
  var deletedWishlistItems: [WishlistItem] = SampleData.deletedWishlistItems
  var connections: [SourceConnection] = SampleData.connections

  var activeCount: Int {
    orders.filter { $0.status != .delivered }.count
  }

  var exceptionCount: Int {
    orders.filter { $0.status == .exception || $0.reviewState == .needsReview }.count
  }

  var reviewQueueCount: Int {
    reviewOrders.count + reviewMailEvents.count
  }

  var reviewOrders: [TrackedOrder] {
    orders.filter { $0.status == .exception || $0.reviewState != .accepted }
  }

  var reviewMailEvents: [MailEvent] {
    mailEvents.filter { $0.severity != .info || $0.reviewState != .accepted }
  }

  func clearIssue(for orderNumber: String) {
    for index in orders.indices where orders[index].orderNumber == orderNumber {
      orders[index].reviewState = .accepted
      if orders[index].status == .exception {
        orders[index].status = .inTransit
      }
      orders[index].latestStatus = "Issue cleared by user review"
    }

    for index in mailEvents.indices where mailEvents[index].matchedOrder == orderNumber {
      mailEvents[index].reviewState = .accepted
      mailEvents[index].severity = .info
      mailEvents[index].summary = "Reviewed and cleared. \(mailEvents[index].summary)"
    }
  }

  func discardSpam(for orderNumber: String) {
    mailEvents.removeAll { $0.matchedOrder == orderNumber }
    for index in orders.indices where orders[index].orderNumber == orderNumber {
      orders[index].reviewState = .accepted
      if orders[index].status == .exception {
        orders[index].status = .ordered
      }
      orders[index].latestStatus = "Related exception discarded as spam"
    }
  }

  var filteredOrders: [TrackedOrder] {
    orders.filter { order in
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let matchesStatus = selectedStatus == nil || order.status == selectedStatus
      let matchesQuery = query.isEmpty
        || order.orderNumber.lowercased().contains(query)
        || order.store.lowercased().contains(query)
        || order.trackedEmail.lowercased().contains(query)
        || order.customer.lowercased().contains(query)
        || order.trackingNumber.lowercased().contains(query)
      return matchesStatus && matchesQuery
    }
  }
}

enum ParcelSection: String, CaseIterable, Identifiable {
  case dashboard
  case orders
  case mailbox
  case review
  case wishlist
  case integrations
  case automation
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .orders: "Orders"
    case .mailbox: "Mailbox Monitor"
    case .review: "Needs Review"
    case .wishlist: "Wishlist"
    case .integrations: "Integrations"
    case .automation: "Automation Flow"
    case .settings: "Settings"
    }
  }

  var shortTitle: String {
    switch self {
    case .dashboard: "Dashboard"
    case .orders: "Orders"
    case .mailbox: "Mailbox"
    case .review: "Review"
    case .wishlist: "Wishlist"
    case .integrations: "Sources"
    case .automation: "Flow"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "rectangle.grid.2x2.fill"
    case .orders: "shippingbox.fill"
    case .mailbox: "envelope.badge.fill"
    case .review: "checkmark.shield.fill"
    case .wishlist: "star.square.fill"
    case .integrations: "point.3.connected.trianglepath.dotted"
    case .automation: "arrow.triangle.branch"
    case .settings: "gearshape.fill"
    }
  }
}

struct TrackedOrder: Identifiable, Hashable {
  var id = UUID()
  var orderNumber: String
  var store: String
  var trackedEmail: String
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

struct TimelineEvent: Identifiable, Hashable {
  var id = UUID()
  var title: String
  var detail: String
  var time: String
  var symbol: String
}

struct ContactHistoryEvent: Identifiable, Hashable {
  var id = UUID()
  var time: String
  var source: ContactSource
  var contactPoint: String
  var summary: String
  var evidence: String
  var reviewState: ReviewState
}

enum ContactSource: String, Hashable {
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

struct MailEvent: Identifiable, Hashable {
  var id = UUID()
  var sender: String
  var summary: String
  var receivedTime: String
  var matchedOrder: String
  var severity: Severity
  var reviewState: ReviewState
}

struct SourceConnection: Identifiable, Hashable {
  var id = UUID()
  var name: String
  var kind: ConnectionKind
  var account: String
  var status: String
  var lastSync: String
}

struct TrackedMailbox: Identifiable, Hashable {
  var id = UUID()
  var address: String
  var provider: MailboxProvider
  var monitoredFolders: String
  var status: String
  var lastChecked: String
  var routingRule: String
}

struct ShopifyConnection: Identifiable, Hashable {
  var id = UUID()
  var storeName: String
  var storeDomain: String
  var mappedMailbox: String
  var mappedTeam: String
  var status: String
  var lastSync: String
  var isEnabled: Bool
}

struct WatchedFolder: Identifiable, Hashable {
  var id = UUID()
  var name: String
  var location: String
  var platform: String
  var fileTypes: String
  var cadence: String
  var status: String
  var lastScan: String
}

struct WishlistItem: Identifiable, Hashable {
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

enum WishlistSource: String, Hashable {
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

enum FulfillmentMethod: String, Hashable {
  case delivery = "Delivery"
  case clickAndCollect = "Click and collect"

  var symbol: String {
    switch self {
    case .delivery: "truck.box.fill"
    case .clickAndCollect: "bag.fill"
    }
  }
}

enum MailboxProvider: String, Hashable {
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

enum IntakeSource: String, CaseIterable, Hashable {
  case forwardedMailbox = "Forwarded mailbox"
  case shopify = "Shopify OAuth"
  case storeLogin = "Store login"
  case manual = "Manual"

  var symbol: String {
    switch self {
    case .forwardedMailbox: "envelope.open.fill"
    case .shopify: "cart.fill"
    case .storeLogin: "lock.shield.fill"
    case .manual: "square.and.pencil"
    }
  }
}

enum OrderStatus: String, CaseIterable, Identifiable, Hashable {
  case intake = "Intake"
  case ordered = "Ordered"
  case shipped = "Shipped"
  case inTransit = "In transit"
  case exception = "Exception"
  case delivered = "Delivered"

  var id: String { rawValue }

  var color: Color {
    switch self {
    case .intake: .gray
    case .ordered: .blue
    case .shipped: .cyan
    case .inTransit: .indigo
    case .exception: .red
    case .delivered: .green
    }
  }
}

enum ReviewState: String, Hashable {
  case accepted = "Accepted"
  case needsReview = "Needs review"
  case monitor = "Monitor"

  var color: Color {
    switch self {
    case .accepted: .green
    case .needsReview: .orange
    case .monitor: .blue
    }
  }
}

enum Severity: String, Hashable {
  case info = "Info"
  case watch = "Watch"
  case critical = "Critical"

  var color: Color {
    switch self {
    case .info: .blue
    case .watch: .orange
    case .critical: .red
    }
  }
}

enum ConnectionKind: String, Hashable {
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

struct DashboardView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Operations overview")
              .font(isCompact ? .title.bold() : .largeTitle.bold())
            Text("Mail intake, supplier accounts, recipient email matching, collections, and delivery exports in one queue.")
              .foregroundStyle(.secondary)
          }
          HStack {
            Button("Create manual order", systemImage: "plus") {}
              .buttonStyle(.borderedProminent)
            Button("Sync", systemImage: "arrow.clockwise") {}
              .buttonStyle(.bordered)
          }
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4), spacing: 12) {
          MetricCard(title: "Active orders", value: "\(store.activeCount)", symbol: "shippingbox.fill", color: .teal)
          MetricCard(title: "Exceptions", value: "\(store.exceptionCount)", symbol: "exclamationmark.triangle.fill", color: .red)
          MetricCard(title: "Mailbox events", value: "\(store.mailEvents.count)", symbol: "envelope.fill", color: .blue)
          MetricCard(title: "Connected sources", value: "\(store.connections.count)", symbol: "link.badge.plus", color: .purple)
        }

        stack {
          OrdersCompactView(orders: store.orders)
          MailboxCompactView(events: store.mailEvents)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  @ViewBuilder
  private func stack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if isCompact {
      VStack(alignment: .leading, spacing: 14, content: content)
    } else {
      HStack(alignment: .top, spacing: 14, content: content)
    }
  }
}

struct OrdersView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          if horizontalSizeClass == .compact {
            Picker("Status", selection: $store.selectedStatus) {
              Text("All").tag(nil as OrderStatus?)
              ForEach(OrderStatus.allCases) { status in
                Text(status.rawValue).tag(status as OrderStatus?)
              }
            }
            .pickerStyle(.menu)
          } else {
            Picker("Status", selection: $store.selectedStatus) {
              Text("All").tag(nil as OrderStatus?)
              ForEach(OrderStatus.allCases) { status in
                Text(status.rawValue).tag(status as OrderStatus?)
              }
            }
            .pickerStyle(.segmented)
          }
          Spacer()
          Button("Add order", systemImage: "plus") {}
            .buttonStyle(.bordered)
        }

        ForEach(store.filteredOrders) { order in
          NavigationLink {
            OrderDetailView(order: order)
          } label: {
            OrderListRow(order: order)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .searchable(text: $store.searchText, prompt: "Search orders, tracking, email, store")
  }
}

struct OrderDetailView: View {
  var order: TrackedOrder
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 6) {
            Text(order.orderNumber)
              .font(isCompact ? .title.bold() : .largeTitle.bold())
            Text(order.store)
              .foregroundStyle(.secondary)
          }
          HStack {
            Badge(order.status.rawValue, color: order.status.color)
            Badge(order.reviewState.rawValue, color: order.reviewState.color)
          }
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isCompact ? 1 : 2), alignment: .leading, spacing: 12) {
          DetailCell("Recipient email", order.trackedEmail, symbol: "at")
          DetailCell("Checked mailbox", order.checkedMailbox, symbol: "envelope.badge.fill")
          DetailCell("Customer/team", order.customer, symbol: "person.2.fill")
          DetailCell("Fulfillment", order.fulfillment.rawValue, symbol: order.fulfillment.symbol)
          DetailCell(order.fulfillment == .delivery ? "Carrier" : "Collection point", order.carrier, symbol: order.fulfillment.symbol)
          DetailCell(order.fulfillment == .delivery ? "Tracking number" : "Collection reference", order.trackingNumber, symbol: "barcode.viewfinder")
          DetailCell(order.fulfillment == .delivery ? "Destination" : "Pickup address", order.destination, symbol: "mappin.and.ellipse")
          DetailCell(order.fulfillment == .delivery ? "Delivery ETA" : "Pickup window", order.eta, symbol: "calendar")
          DetailCell("Source", order.source.rawValue, symbol: order.source.symbol)
          DetailCell("Latest status", order.latestStatus, symbol: "waveform.path.ecg")
        }

        if order.fulfillment == .delivery {
          Button("Send to Parcel", systemImage: "square.and.arrow.up") {}
            .buttonStyle(.borderedProminent)
        }

        Panel(title: "Timeline", symbol: "clock.fill") {
          VStack(spacing: 0) {
            ForEach(order.timeline) { event in
              TimelineRow(event: event)
            }
          }
        }

        Panel(title: "Full contact history", symbol: "tray.full.fill") {
          VStack(spacing: 10) {
            ForEach(order.contactHistory) { event in
              ContactHistoryRow(event: event)
            }
          }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct MailboxView: View {
  var events: [MailEvent]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(events) { event in
          VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "envelope.open.fill")
              .foregroundStyle(event.severity.color)
              .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(event.sender)
                  .font(.headline)
                Badge(event.severity.rawValue, color: event.severity.color)
                Badge(event.reviewState.rawValue, color: event.reviewState.color)
                Spacer()
                Text(event.receivedTime)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Text(event.summary)
                .foregroundStyle(.secondary)
              Text("Matched order: \(event.matchedOrder)")
                .font(.caption.weight(.semibold))
            }
          }
          .padding(14)
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct NeedsReviewView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Needs review")
              .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
            Text("Exceptions, risky matches, and lower-confidence intake wait here until a user accepts or discards them.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Badge("\(store.reviewQueueCount)", color: .orange)
        }

        SettingsPanel(title: "Order matches", symbol: "shippingbox.fill") {
          ForEach(store.reviewOrders) { order in
            ReviewOrderRow(order: order) {
              store.clearIssue(for: order.orderNumber)
            } onDiscard: {
              store.discardSpam(for: order.orderNumber)
            }
          }
        }

        SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
          ForEach(store.reviewMailEvents) { event in
            ReviewMailEventRow(event: event) {
              store.clearIssue(for: event.matchedOrder)
            } onDiscard: {
              store.discardSpam(for: event.matchedOrder)
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct ReviewOrderRow: View {
  var order: TrackedOrder
  var onClear: () -> Void
  var onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.orderNumber) • \(order.store)")
            .font(.headline)
          Text("Recipient \(order.trackedEmail), checked in \(order.checkedMailbox)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(order.latestStatus)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(order.reviewState.rawValue, color: order.reviewState.color)
      }
      HStack {
        Button("Add to orders", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ReviewMailEventRow: View {
  var event: MailEvent
  var onClear: () -> Void
  var onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(event.sender)
            .font(.headline)
          Text(event.summary)
            .foregroundStyle(.secondary)
          Text("Suggested match: \(event.matchedOrder)")
            .font(.caption.weight(.semibold))
        }
        Spacer()
        Badge(event.severity.rawValue, color: event.severity.color)
      }
      HStack {
        Button("Add to order", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistView: View {
  var items: [WishlistItem]
  var deletedItems: [WishlistItem]
  @State private var showDeletedItems = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Wishlist")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Per-user purchase ideas can be captured from files, screenshots, browser sharing, or extensions before converting to orders.")
            .foregroundStyle(.secondary)
        }

        HStack {
          Button("Upload PDF", systemImage: "doc.badge.plus") {}
          Button("Add screenshot", systemImage: "photo.badge.plus") {}
          Button("Manual item", systemImage: "plus") {}
        }
        .buttonStyle(.bordered)

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF upload", detail: "Parse supplier PDFs and invoices for storefront, item name, price, and order clues.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot upload", detail: "Extract storefront URL, item title, visible price, and availability from saved screenshots.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "iOS and macOS Share", detail: "Accept shared web pages from Safari or another browser into the signed-in user's wishlist.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Chrome and Firefox extension", detail: "Browser extension capture path for desktop browsers and Android phones.")
        }

        SettingsPanel(title: "Wishlist items", symbol: "star.square.fill") {
          ForEach(items) { item in
            WishlistItemRow(item: item)
          }
        }

        SettingsPanel(title: "Deleted items", symbol: "trash.fill") {
          Button {
            withAnimation(.snappy) {
              showDeletedItems.toggle()
            }
          } label: {
            HStack {
              Label("\(deletedItems.count) deleted item", systemImage: showDeletedItems ? "folder.fill.badge.minus" : "folder.fill")
              Spacer()
              Image(systemName: showDeletedItems ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          if showDeletedItems {
            Text("Deleted wishlist items are retained for 90 days before permanent removal.")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(deletedItems) { item in
              WishlistItemRow(item: item, isDeleted: true)
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct CaptureChannelRow: View {
  var symbol: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistItemRow: View {
  var item: WishlistItem
  var isDeleted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(.teal)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.itemName)
            .font(.headline)
          Text("\(item.storefront) • \(item.estimatedCost)")
            .foregroundStyle(.secondary)
          Text(item.storefrontURL)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(item.owner) • \(item.pool)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(item.status, color: .blue)
      }
      Text(item.capturedDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
      if isDeleted {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
          Button("Restore", systemImage: "arrow.uturn.backward") {}
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Restore")
          Button("Delete now", systemImage: "trash.fill") {}
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Delete permanently")
        }
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
          if let url = URL(string: item.storefrontURL) {
            Link(destination: url) {
              Label("Open shopfront", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.iconOnly)
            .help("Open shopfront")
            ShareLink(item: url) {
              Label("Share link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Share link")
          }
          Button("Convert to order", systemImage: "shippingbox.fill") {}
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Convert to order")
          Button("Link order", systemImage: "link") {}
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Link to existing order")
          Button("Delete", systemImage: "trash") {}
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Move to deleted items")
        }
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct IntegrationsView: View {
  var mailboxes: [TrackedMailbox]
  var shopifyConnections: [ShopifyConnection]
  var watchedFolders: [WatchedFolder]
  var connections: [SourceConnection]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Connected sources")
            .font(isCompact ? .title2.bold() : .title.bold())
          HStack {
            Button("Add mailbox", systemImage: "envelope.badge.fill") {}
            Button("Connect Shopify", systemImage: "cart.badge.plus") {}
            Button("Watch folder", systemImage: "folder.badge.plus") {}
            Button("Add login", systemImage: "key.fill") {}
          }
        }
        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
        }
        SettingsPanel(title: "Shopify stores", symbol: "cart.badge.plus") {
          ForEach(shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
        }
        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
        }
        ForEach(connections) { connection in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: connection.kind.symbol)
              .foregroundStyle(.teal)
              .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
              Text(connection.name)
                .font(.headline)
              Text("\(connection.kind.rawValue) • \(connection.account)")
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Text(connection.status)
                .font(.callout.weight(.semibold))
              Text(connection.lastSync)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct MailboxConnectionRow: View {
  var mailbox: TrackedMailbox

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: mailbox.provider.symbol)
        .foregroundStyle(.blue)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(mailbox.address)
          .font(.headline)
        Text("\(mailbox.provider.rawValue) • \(mailbox.monitoredFolders)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(mailbox.routingRule)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(mailbox.status)
          .font(.callout.weight(.semibold))
        Text(mailbox.lastChecked)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ShopifyConnectionRow: View {
  var connection: ShopifyConnection

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "cart.fill")
        .foregroundStyle(.green)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(connection.storeName)
          .font(.headline)
        Text(connection.storeDomain)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(connection.mappedTeam) • \(connection.mappedMailbox)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(connection.isEnabled ? connection.status : "Disabled")
          .font(.callout.weight(.semibold))
        Text(connection.lastSync)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WatchedFolderRow: View {
  var folder: WatchedFolder

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "folder.fill.badge.gearshape")
        .foregroundStyle(.orange)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(folder.name)
          .font(.headline)
        Text(folder.location)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(folder.platform) • \(folder.fileTypes) • \(folder.cadence)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(folder.status)
          .font(.callout.weight(.semibold))
        Text(folder.lastScan)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct AutomationView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private var steps: [(String, String, String)] = [
    ("Mailbox parsing", "Extract order numbers, sender domains, totals, delivery warnings, and recipient aliases.", "envelope.open.fill"),
    ("Account sync", "Refresh supplier portals and Shopify OAuth stores without overwriting reviewed data.", "arrow.triangle.2.circlepath"),
    ("Order matching", "Compare supplier order number, checked mailbox, original recipient email, store, and customer team.", "link"),
    ("Review gate", "Risky matches enter a review state before changing order records.", "checkmark.shield.fill"),
    ("Delivery handoff", "Use a free carrier API if available, otherwise export delivery details to the Parcel app.", "square.and.arrow.up")
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Automation flow")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        ForEach(steps, id: \.0) { step in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.2)
              .foregroundStyle(.white)
              .frame(width: 34, height: 34)
              .background(.teal)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
              Text(step.0)
                .font(.headline)
              Text(step.1)
                .foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct SettingsView: View {
  var mailboxes: [TrackedMailbox]
  var shopifyConnections: [ShopifyConnection]
  var watchedFolders: [WatchedFolder]
  @AppStorage("folderWatchingEnabled") private var folderWatchingEnabled = true
  @AppStorage("folderScanCadence") private var folderScanCadence = "Every 15 minutes"
  @AppStorage("mailboxMonitoringEnabled") private var mailboxMonitoringEnabled = true
  @AppStorage("autoCreateOrdersFromEmail") private var autoCreateOrdersFromEmail = true
  @AppStorage("shopifySyncEnabled") private var shopifySyncEnabled = true
  @AppStorage("storeLoginSyncEnabled") private var storeLoginSyncEnabled = true
  @AppStorage("carrierTrackingEnabled") private var carrierTrackingEnabled = true
  @AppStorage("carrierTrackingMode") private var carrierTrackingMode = "Export to Parcel"
  @AppStorage("requireReviewForRiskyMatches") private var requireReviewForRiskyMatches = true
  @AppStorage("notifyOnDeliveryExceptions") private var notifyOnDeliveryExceptions = true
  @AppStorage("exceptionThreshold") private var exceptionThreshold = 3.0
  @AppStorage("matchConfidencePolicy") private var matchConfidencePolicy = "Balanced"
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(isCompact ? .title.bold() : .largeTitle.bold())

        SettingsPanel(title: "Mailbox intake", symbol: "envelope.open.fill") {
          Toggle("Monitor forwarded tracking mailbox", isOn: $mailboxMonitoringEnabled)
          Toggle("Create orders from recognized emails", isOn: $autoCreateOrdersFromEmail)
          Picker("Match confidence", selection: $matchConfidencePolicy) {
            Text("Strict").tag("Strict")
            Text("Balanced").tag("Balanced")
            Text("Permissive").tag("Permissive")
          }
          .pickerStyle(.menu)
        }

        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
          Button("Add tracked mailbox", systemImage: "plus") {}
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Shopify accounts", symbol: "cart.badge.plus") {
          ForEach(shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
          Button("Connect Shopify account", systemImage: "plus") {}
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          Toggle("Regularly scan saved folders", isOn: $folderWatchingEnabled)
          Picker("Scan cadence", selection: $folderScanCadence) {
            Text("Every 5 minutes").tag("Every 5 minutes")
            Text("Every 15 minutes").tag("Every 15 minutes")
            Text("Hourly").tag("Hourly")
            Text("Manual only").tag("Manual only")
          }
          .pickerStyle(.menu)
          ForEach(watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
          Button("Add folder", systemImage: "folder.badge.plus") {}
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Review controls", symbol: "checkmark.shield.fill") {
          Toggle("Require review for risky email/order matches", isOn: $requireReviewForRiskyMatches)
          Toggle("Notify on delivery exceptions", isOn: $notifyOnDeliveryExceptions)
          VStack(alignment: .leading, spacing: 8) {
            Text("Exception alert threshold: \(Int(exceptionThreshold))")
              .font(.callout.weight(.medium))
            Slider(value: $exceptionThreshold, in: 1...10, step: 1) {
              Text("Exception alert threshold")
            } minimumValueLabel: {
              Image(systemName: "1.circle")
            } maximumValueLabel: {
              Image(systemName: "10.circle")
            }
          }
        }

        SettingsPanel(title: "Connected sources", symbol: "link.badge.plus") {
          Toggle("Sync Shopify OAuth suppliers", isOn: $shopifySyncEnabled)
          Toggle("Sync password-vault store logins", isOn: $storeLoginSyncEnabled)
          Toggle("Enable delivery handoff after shipment", isOn: $carrierTrackingEnabled)
          Picker("Carrier tracking mode", selection: $carrierTrackingMode) {
            Text("Export to Parcel").tag("Export to Parcel")
            Text("Free carrier API").tag("Free carrier API")
            Text("Manual updates").tag("Manual updates")
          }
          .pickerStyle(.menu)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct SettingsPanel<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: symbol)
        .font(.headline)
      VStack(alignment: .leading, spacing: 12) {
        content
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct OrdersCompactView: View {
  var orders: [TrackedOrder]

  var body: some View {
    Panel(title: "Active order queue", symbol: "shippingbox.fill") {
      VStack(spacing: 10) {
        ForEach(orders.prefix(4)) { order in
          OrderListRow(order: order)
        }
      }
    }
  }
}

struct MailboxCompactView: View {
  var events: [MailEvent]

  var body: some View {
    Panel(title: "Mailbox events", symbol: "envelope.badge.fill") {
      VStack(spacing: 10) {
        ForEach(events) { event in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(event.sender)
                .font(.headline)
              Text(event.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(event.severity.rawValue, color: event.severity.color)
          }
          .padding(10)
          .background(.quinary)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }
}

struct OrderListRow: View {
  var order: TrackedOrder

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: order.status == .exception ? "exclamationmark.triangle.fill" : order.source.symbol)
        .foregroundStyle(order.status.color)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        VStack(alignment: .leading, spacing: 2) {
          Text(order.orderNumber)
            .font(.headline)
          Text(order.store)
            .foregroundStyle(.secondary)
        }
        Text("\(order.customer) • recipient \(order.trackedEmail)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Checked in \(order.checkedMailbox)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 5) {
        Badge(order.status.rawValue, color: order.status.color)
        Text(order.eta)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MetricCard: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: symbol)
          .foregroundStyle(color)
        Spacer()
      }
      Text(value)
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text(title)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct Panel<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: symbol)
        .font(.title3.bold())
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct DetailCell: View {
  var title: String
  var value: String
  var symbol: String

  init(_ title: String, _ value: String, symbol: String) {
    self.title = title
    self.value = value
    self.symbol = symbol
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.callout.weight(.medium))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct TimelineRow: View {
  var event: TimelineEvent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: event.symbol)
        .foregroundStyle(.teal)
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(event.title)
            .font(.callout.bold())
          Spacer()
          Text(event.time)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(event.detail)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 10)
  }
}

struct ContactHistoryRow: View {
  var event: ContactHistoryEvent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: event.source.symbol)
        .foregroundStyle(.teal)
        .frame(width: 26, height: 26)
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(event.source.rawValue)
              .font(.headline)
            Text(event.contactPoint)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 4) {
            Badge(event.reviewState.rawValue, color: event.reviewState.color)
            Text(event.time)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Text(event.summary)
          .font(.callout)
        Text(event.evidence)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct Badge: View {
  var text: String
  var color: Color

  init(_ text: String, color: Color) {
    self.text = text
    self.color = color
  }

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }
}

enum SampleData {
  static var orders: [TrackedOrder] = [
    TrackedOrder(
      orderNumber: "SP-10492",
      store: "SafetyPro Supplies",
      trackedEmail: "ops-orders@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Melbourne Operations",
      fulfillment: .delivery,
      carrier: "Australia Post",
      trackingNumber: "33AUL8841295",
      destination: "18 Collins Street, Melbourne VIC",
      eta: "Tomorrow",
      source: .forwardedMailbox,
      status: .inTransit,
      reviewState: .accepted,
      latestStatus: "Arrived at Melbourne sorting facility",
      timeline: [
        TimelineEvent(title: "Arrived at facility", detail: "Carrier scan received from Melbourne VIC.", time: "Today 9:12 AM", symbol: "shippingbox.fill"),
        TimelineEvent(title: "Shipment email parsed", detail: "Order SP-10492 was found in tracking-intake@parcelops.example and logged against recipient ops-orders@parcelops.example.", time: "Yesterday 6:10 PM", symbol: "envelope.fill"),
        TimelineEvent(title: "Order created", detail: "Supplier order number opened a new tracked order.", time: "Tue 2:18 PM", symbol: "tray.and.arrow.down.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 9:12 AM", source: .carrier, contactPoint: "Australia Post 33AUL8841295", summary: "Carrier scan placed shipment at Melbourne sorting facility.", evidence: "Carrier tracking update linked to supplier order SP-10492.", reviewState: .accepted),
        ContactHistoryEvent(time: "Yesterday 6:10 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Shipping email forwarded into checked mailbox.", evidence: "Recipient email ops-orders@parcelops.example matched the purchase identity.", reviewState: .accepted),
        ContactHistoryEvent(time: "Tue 2:18 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Order confirmation created the order record.", evidence: "Supplier order number SP-10492 extracted from forwarded message.", reviewState: .accepted)
      ]
    ),
    TrackedOrder(
      orderNumber: "SHP-8831",
      store: "Acme Parts Shopify",
      trackedEmail: "field-orders@parcelops.example",
      checkedMailbox: "field-purchasing@parcelops.example",
      customer: "Brisbane Field Team",
      fulfillment: .delivery,
      carrier: "DHL",
      trackingNumber: "JD0146000098312",
      destination: "77 Eagle Street, Brisbane QLD",
      eta: "Pending",
      source: .shopify,
      status: .exception,
      reviewState: .needsReview,
      latestStatus: "Address confirmation requested",
      timeline: [
        TimelineEvent(title: "Review required", detail: "Support email may belong to this order, but suite details differ.", time: "Today 8:05 AM", symbol: "checkmark.shield.fill"),
        TimelineEvent(title: "Fulfillment synced", detail: "Shopify OAuth connection added the shipment record.", time: "Yesterday 11:34 AM", symbol: "cart.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 8:05 AM", source: .mailbox, contactPoint: "field-purchasing@parcelops.example", summary: "DHL support email requested destination confirmation.", evidence: "Matched by tracking number, but address details differ and need user review.", reviewState: .needsReview),
        ContactHistoryEvent(time: "Yesterday 11:34 AM", source: .shopify, contactPoint: "acme-parts.myshopify.com", summary: "Shopify fulfillment added DHL shipment.", evidence: "OAuth sync mapped store order SHP-8831 to Brisbane Field Team.", reviewState: .accepted),
        ContactHistoryEvent(time: "Mon 4:22 PM", source: .shopify, contactPoint: "acme-parts.myshopify.com", summary: "Original Shopify order imported.", evidence: "Recipient email field-orders@parcelops.example linked to checked mailbox field-purchasing@parcelops.example.", reviewState: .accepted)
      ]
    ),
    TrackedOrder(
      orderNumber: "NWS-7720",
      store: "Northwind Wholesale",
      trackedEmail: "office-orders@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Perth Office",
      fulfillment: .clickAndCollect,
      carrier: "Northwind Perth counter",
      trackingNumber: "Pickup code NW7720",
      destination: "Northwind Trade Desk, Perth WA",
      eta: "Ready tomorrow",
      source: .storeLogin,
      status: .ordered,
      reviewState: .monitor,
      latestStatus: "Portal order found with no dispatch notice",
      timeline: [
        TimelineEvent(title: "Portal sync", detail: "Password-vault login found order status inside supplier account.", time: "Today 7:30 AM", symbol: "lock.shield.fill"),
        TimelineEvent(title: "Invoice matched", detail: "Forwarded invoice matched the Perth Office tracked email.", time: "Yesterday 5:01 PM", symbol: "doc.text.fill")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 7:30 AM", source: .supplierPortal, contactPoint: "Northwind Wholesale login", summary: "Portal sync confirmed click-and-collect order status.", evidence: "Pickup code NW7720 found in supplier account.", reviewState: .monitor),
        ContactHistoryEvent(time: "Yesterday 5:01 PM", source: .mailbox, contactPoint: "tracking-intake@parcelops.example", summary: "Invoice email matched the order.", evidence: "Recipient office-orders@parcelops.example and supplier order NWS-7720 matched.", reviewState: .accepted),
        ContactHistoryEvent(time: "Yesterday 4:54 PM", source: .watchedFolder, contactPoint: "~/Downloads", summary: "PDF invoice saved from browser was scanned.", evidence: "PDF text extraction found NWS-7720 and Northwind Wholesale.", reviewState: .monitor)
      ]
    ),
    TrackedOrder(
      orderNumber: "MAN-2194",
      store: "Regional Courier Desk",
      trackedEmail: "facilities@parcelops.example",
      checkedMailbox: "tracking-intake@parcelops.example",
      customer: "Facilities",
      fulfillment: .delivery,
      carrier: "TNT",
      trackingNumber: "TNT55928103",
      destination: "Dock 4, 9 Harbour Road, Sydney NSW",
      eta: "Friday",
      source: .manual,
      status: .shipped,
      reviewState: .accepted,
      latestStatus: "Shipment created manually from supplier call",
      timeline: [
        TimelineEvent(title: "Manual order created", detail: "Operator entered supplier, carrier, destination, and tracking number.", time: "Today 10:20 AM", symbol: "square.and.pencil")
      ],
      contactHistory: [
        ContactHistoryEvent(time: "Today 10:20 AM", source: .manual, contactPoint: "Facilities user entry", summary: "Manual order was created from supplier phone call.", evidence: "Operator entered TNT55928103, Dock 4 destination, and supplier details.", reviewState: .accepted),
        ContactHistoryEvent(time: "Today 10:22 AM", source: .watchedFolder, contactPoint: "iCloud Drive/ParcelOps Orders", summary: "Supporting PDF was uploaded to the order folder.", evidence: "Filename Regional-Courier-MAN-2194.pdf matched the manual order number.", reviewState: .accepted)
      ]
    )
  ]

  static var mailEvents: [MailEvent] = [
    MailEvent(sender: "DHL Support", summary: "Carrier needs destination suite confirmation before delivery continues.", receivedTime: "Today 8:05 AM", matchedOrder: "SHP-8831", severity: .critical, reviewState: .needsReview),
    MailEvent(sender: "SafetyPro Supplies", summary: "Shipping confirmation parsed and tracking number attached.", receivedTime: "Yesterday 6:10 PM", matchedOrder: "SP-10492", severity: .info, reviewState: .accepted),
    MailEvent(sender: "Northwind Wholesale", summary: "Invoice matched, but no dispatch or carrier information yet.", receivedTime: "Yesterday 5:01 PM", matchedOrder: "NWS-7720", severity: .watch, reviewState: .monitor)
  ]

  static var mailboxes: [TrackedMailbox] = [
    TrackedMailbox(address: "tracking-intake@parcelops.example", provider: .microsoft365, monitoredFolders: "Inbox, Forwarded Orders", status: "Watching", lastChecked: "2 min ago", routingRule: "Default order intake and carrier alerts"),
    TrackedMailbox(address: "field-purchasing@parcelops.example", provider: .gmail, monitoredFolders: "Purchases, Shipping", status: "Watching", lastChecked: "5 min ago", routingRule: "Field team purchases"),
    TrackedMailbox(address: "ap-invoices@parcelops.example", provider: .imap, monitoredFolders: "Orders", status: "Needs auth", lastChecked: "Yesterday", routingRule: "Invoice-only matching")
  ]

  static var shopifyConnections: [ShopifyConnection] = [
    ShopifyConnection(storeName: "Acme Parts", storeDomain: "acme-parts.myshopify.com", mappedMailbox: "field-purchasing@parcelops.example", mappedTeam: "Brisbane Field Team", status: "Synced", lastSync: "6 min ago", isEnabled: true),
    ShopifyConnection(storeName: "SafetyPro Direct", storeDomain: "safetypro-direct.myshopify.com", mappedMailbox: "tracking-intake@parcelops.example", mappedTeam: "Melbourne Operations", status: "Synced", lastSync: "12 min ago", isEnabled: true),
    ShopifyConnection(storeName: "Office Kit Store", storeDomain: "office-kit.myshopify.com", mappedMailbox: "ap-invoices@parcelops.example", mappedTeam: "Perth Office", status: "Needs reauth", lastSync: "Yesterday", isEnabled: false)
  ]

  static var watchedFolders: [WatchedFolder] = [
    WatchedFolder(name: "Desktop screenshots", location: "~/Desktop", platform: "macOS", fileTypes: "PNG, JPG, PDF", cadence: "Every 15 minutes", status: "Watching", lastScan: "3 min ago"),
    WatchedFolder(name: "Downloads invoices", location: "~/Downloads", platform: "macOS", fileTypes: "PDF, CSV", cadence: "Every 15 minutes", status: "Watching", lastScan: "8 min ago"),
    WatchedFolder(name: "Order uploads", location: "iCloud Drive/ParcelOps Orders", platform: "iOS and macOS", fileTypes: "PDF, images, email exports", cadence: "Hourly", status: "Watching", lastScan: "23 min ago")
  ]

  static var wishlistItems: [WishlistItem] = [
    WishlistItem(itemName: "Compact barcode scanner", storefront: "SafetyPro Direct", storefrontURL: "https://safetypro.example/scanner-compact", estimatedCost: "$189.00", owner: "Mia Chen", pool: "Shared company pool", source: .shareSheet, status: "Ready", capturedDetail: "Shared from Safari with item URL, visible price, and supplier page title."),
    WishlistItem(itemName: "Thermal label rolls", storefront: "Office Kit Store", storefrontURL: "https://officekit.example/thermal-rolls", estimatedCost: "$42.50", owner: "Jordan Lee", pool: "Personal wishlist", source: .screenshot, status: "Needs review", capturedDetail: "Screenshot parser found item title and price, but storefront URL needs confirmation."),
    WishlistItem(itemName: "Dock safety cones", storefront: "Northwind Wholesale", storefrontURL: "https://northwind.example/cones", estimatedCost: "$76.00", owner: "Priya Shah", pool: "Facilities team", source: .browserExtension, status: "Ready", capturedDetail: "Captured through Chrome/Firefox extension path for cross-device wishlist intake."),
    WishlistItem(itemName: "Replacement printer tray", storefront: "Acme Parts", storefrontURL: "https://acme-parts.example/printer-tray", estimatedCost: "$118.20", owner: "Mia Chen", pool: "Shared company pool", source: .pdf, status: "Ready", capturedDetail: "PDF quote upload parsed supplier, SKU, item name, and estimated cost.")
  ]

  static var deletedWishlistItems: [WishlistItem] = [
    WishlistItem(itemName: "Old label printer cable", storefront: "Office Kit Store", storefrontURL: "https://officekit.example/old-cable", estimatedCost: "$18.40", owner: "Jordan Lee", pool: "Personal wishlist", source: .manual, status: "Deleted 12 days ago", capturedDetail: "Moved to deleted items. It will be retained for 90 days before permanent removal.")
  ]

  static var connections: [SourceConnection] = [
    SourceConnection(name: "3 tracked mailboxes", kind: .mailbox, account: "Microsoft 365, Gmail, IMAP", status: "2 watching", lastSync: "2 min ago"),
    SourceConnection(name: "3 Shopify stores", kind: .shopify, account: "OAuth connections", status: "2 active", lastSync: "6 min ago"),
    SourceConnection(name: "3 watched folders", kind: .watchedFolder, account: "Desktop, Downloads, iCloud Drive", status: "Watching", lastSync: "3 min ago"),
    SourceConnection(name: "Northwind Wholesale", kind: .vaultLogin, account: "Password vault", status: "Needs 2FA soon", lastSync: "1 hr ago"),
    SourceConnection(name: "SafetyPro Supplies", kind: .vaultLogin, account: "Password vault", status: "Synced", lastSync: "14 min ago")
  ]
}
