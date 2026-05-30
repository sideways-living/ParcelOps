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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    GeometryReader { proxy in
      let usePhoneLayout = horizontalSizeClass == .compact || proxy.size.width < 700

      Group {
        if usePhoneLayout {
        TabView(selection: $selection) {
          ForEach(ParcelSection.allCases) { section in
            NavigationStack {
              content(for: section)
                .navigationTitle(section.title)
            }
            .tabItem {
              Label(section.title, systemImage: section.symbol)
            }
            .tag(section)
          }
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
    case .integrations:
      IntegrationsView(mailboxes: store.mailboxes, shopifyConnections: store.shopifyConnections, connections: store.connections)
    case .automation:
      AutomationView()
    case .settings:
      SettingsView(mailboxes: store.mailboxes, shopifyConnections: store.shopifyConnections)
    }
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
  var connections: [SourceConnection] = SampleData.connections

  var activeCount: Int {
    orders.filter { $0.status != .delivered }.count
  }

  var exceptionCount: Int {
    orders.filter { $0.status == .exception || $0.reviewState == .needsReview }.count
  }

  var reviewQueueCount: Int {
    orders.filter { $0.reviewState == .needsReview }.count + mailEvents.filter { $0.reviewState == .needsReview }.count
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
  case integrations
  case automation
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .orders: "Orders"
    case .mailbox: "Mailbox Monitor"
    case .integrations: "Integrations"
    case .automation: "Automation Flow"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "rectangle.grid.2x2.fill"
    case .orders: "shippingbox.fill"
    case .mailbox: "envelope.badge.fill"
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
}

struct TimelineEvent: Identifiable, Hashable {
  var id = UUID()
  var title: String
  var detail: String
  var time: String
  var symbol: String
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

  var symbol: String {
    switch self {
    case .mailbox: "envelope.fill"
    case .shopify: "cart.badge.plus"
    case .vaultLogin: "key.horizontal.fill"
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

struct IntegrationsView: View {
  var mailboxes: [TrackedMailbox]
  var shopifyConnections: [ShopifyConnection]
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

  static var connections: [SourceConnection] = [
    SourceConnection(name: "3 tracked mailboxes", kind: .mailbox, account: "Microsoft 365, Gmail, IMAP", status: "2 watching", lastSync: "2 min ago"),
    SourceConnection(name: "3 Shopify stores", kind: .shopify, account: "OAuth connections", status: "2 active", lastSync: "6 min ago"),
    SourceConnection(name: "Northwind Wholesale", kind: .vaultLogin, account: "Password vault", status: "Needs 2FA soon", lastSync: "1 hr ago"),
    SourceConnection(name: "SafetyPro Supplies", kind: .vaultLogin, account: "Password vault", status: "Synced", lastSync: "14 min ago")
  ]
}
