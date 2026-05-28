import SwiftUI

@main
struct CompanyParcelTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            AppShell()
                .frame(minWidth: 1080, minHeight: 720)
        }
    }
}

struct TrackedOrder: Identifiable, Hashable {
    let id = UUID()
    var orderNumber: String
    var store: String
    var customer: String
    var email: String
    var carrier: String
    var trackingNumber: String
    var destination: String
    var status: OrderStatus
    var risk: RiskLevel
    var lastUpdate: String
    var expectedDelivery: String
    var source: IntakeSource
    var updates: [TrackingEvent]
}

struct TrackingEvent: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var detail: String
    var time: String
    var icon: String
}

struct MailEvent: Identifiable, Hashable {
    let id = UUID()
    var sender: String
    var subject: String
    var received: String
    var matchedOrder: String
    var severity: RiskLevel
    var summary: String
}

struct IntegrationAccount: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: String
    var login: String
    var status: String
    var lastSync: String
}

enum OrderStatus: String, CaseIterable {
    case intake = "Intake"
    case ordered = "Ordered"
    case shipped = "Shipped"
    case inTransit = "In transit"
    case exception = "Exception"
    case delivered = "Delivered"

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

enum RiskLevel: String, CaseIterable {
    case low = "Low"
    case watch = "Watch"
    case high = "High"

    var color: Color {
        switch self {
        case .low: .green
        case .watch: .orange
        case .high: .red
        }
    }
}

enum IntakeSource: String, CaseIterable {
    case forwardedEmail = "Forwarded email"
    case shopify = "Shopify"
    case storeLogin = "Store login"
    case manual = "Manual"
}

final class ParcelTrackerModel: ObservableObject {
    @Published var selectedOrderID: TrackedOrder.ID?
    @Published var statusFilter: OrderStatus?
    @Published var searchText = ""

    @Published var orders: [TrackedOrder] = [
        TrackedOrder(
            orderNumber: "SP-10492",
            store: "SafetyPro Supplies",
            customer: "Melbourne Operations",
            email: "ops-orders@company.com",
            carrier: "Australia Post",
            trackingNumber: "33AUL8841295",
            destination: "18 Collins Street, Melbourne VIC",
            status: .inTransit,
            risk: .low,
            lastUpdate: "Arrived at Melbourne facility",
            expectedDelivery: "Tomorrow",
            source: .forwardedEmail,
            updates: [
                TrackingEvent(title: "Arrived at facility", detail: "Melbourne VIC sorting facility", time: "Today 9:12 AM", icon: "shippingbox.fill"),
                TrackingEvent(title: "Left origin", detail: "Sydney NSW warehouse", time: "Yesterday 6:40 PM", icon: "truck.box.fill"),
                TrackingEvent(title: "Order confirmed", detail: "Forwarded confirmation matched by order number", time: "Tue 2:18 PM", icon: "envelope.fill")
            ]
        ),
        TrackedOrder(
            orderNumber: "SHP-8831",
            store: "Acme Parts Shopify",
            customer: "Brisbane Field Team",
            email: "field-orders@company.com",
            carrier: "DHL",
            trackingNumber: "JD0146000098312",
            destination: "77 Eagle Street, Brisbane QLD",
            status: .exception,
            risk: .high,
            lastUpdate: "Address confirmation requested",
            expectedDelivery: "Pending",
            source: .shopify,
            updates: [
                TrackingEvent(title: "Action required", detail: "Carrier email requests suite number confirmation", time: "Today 8:05 AM", icon: "exclamationmark.triangle.fill"),
                TrackingEvent(title: "Shipment created", detail: "Shopify fulfillment webhook received", time: "Yesterday 11:34 AM", icon: "link.badge.plus"),
                TrackingEvent(title: "Order imported", detail: "Shopify order synced from Acme Parts", time: "Mon 4:22 PM", icon: "cart.fill")
            ]
        ),
        TrackedOrder(
            orderNumber: "NWS-7720",
            store: "Northwind Wholesale",
            customer: "Perth Office",
            email: "office-orders@company.com",
            carrier: "StarTrack",
            trackingNumber: "ST942017553",
            destination: "125 St Georges Terrace, Perth WA",
            status: .ordered,
            risk: .watch,
            lastUpdate: "Awaiting shipment email",
            expectedDelivery: "Not available",
            source: .storeLogin,
            updates: [
                TrackingEvent(title: "Order visible in portal", detail: "Login sync found order but no tracking number yet", time: "Today 7:30 AM", icon: "person.crop.circle.badge.checkmark"),
                TrackingEvent(title: "Receipt captured", detail: "Forwarded mailbox parsed invoice and total", time: "Yesterday 5:01 PM", icon: "doc.text.fill")
            ]
        )
    ]

    @Published var mailEvents: [MailEvent] = [
        MailEvent(sender: "DHL Support", subject: "Action required for JD0146000098312", received: "Today 8:05 AM", matchedOrder: "SHP-8831", severity: .high, summary: "Carrier needs destination suite number before delivery continues."),
        MailEvent(sender: "SafetyPro Supplies", subject: "Your order SP-10492 has shipped", received: "Yesterday 6:10 PM", matchedOrder: "SP-10492", severity: .low, summary: "Shipping confirmation parsed and tracking number attached."),
        MailEvent(sender: "Northwind Wholesale", subject: "Invoice for NWS-7720", received: "Yesterday 5:01 PM", matchedOrder: "NWS-7720", severity: .watch, summary: "Order found, but no dispatch or carrier information yet.")
    ]

    @Published var integrations: [IntegrationAccount] = [
        IntegrationAccount(name: "tracking-intake@company.com", type: "Forwarded mailbox", login: "IMAP", status: "Watching", lastSync: "2 min ago"),
        IntegrationAccount(name: "Acme Parts", type: "Shopify", login: "OAuth connected", status: "Synced", lastSync: "6 min ago"),
        IntegrationAccount(name: "Northwind Wholesale", type: "Store login", login: "Password vault", status: "Needs 2FA soon", lastSync: "1 hr ago"),
        IntegrationAccount(name: "SafetyPro Supplies", type: "Store login", login: "Password vault", status: "Synced", lastSync: "14 min ago")
    ]

    var filteredOrders: [TrackedOrder] {
        orders.filter { order in
            let matchesFilter = statusFilter == nil || order.status == statusFilter
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = query.isEmpty
                || order.orderNumber.lowercased().contains(query)
                || order.store.lowercased().contains(query)
                || order.destination.lowercased().contains(query)
                || order.email.lowercased().contains(query)
                || order.trackingNumber.lowercased().contains(query)
            return matchesFilter && matchesSearch
        }
    }

    var selectedOrder: TrackedOrder? {
        guard let selectedOrderID else { return filteredOrders.first ?? orders.first }
        return orders.first(where: { $0.id == selectedOrderID }) ?? filteredOrders.first ?? orders.first
    }

    var activeCount: Int {
        orders.filter { $0.status != .delivered }.count
    }

    var exceptionCount: Int {
        orders.filter { $0.status == .exception || $0.risk == .high }.count
    }
}

struct AppShell: View {
    @StateObject private var model = ParcelTrackerModel()

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
        } detail: {
            Dashboard(model: model)
        }
        .tint(.teal)
    }
}

struct Sidebar: View {
    @ObservedObject var model: ParcelTrackerModel

    var body: some View {
        List(selection: $model.selectedOrderID) {
            Section {
                SummaryRow(title: "Active orders", value: "\(model.activeCount)", icon: "shippingbox.fill", color: .teal)
                SummaryRow(title: "Needs attention", value: "\(model.exceptionCount)", icon: "exclamationmark.triangle.fill", color: .red)
                SummaryRow(title: "Mailbox events", value: "\(model.mailEvents.count)", icon: "envelope.fill", color: .blue)
            }

            Section("Orders") {
                ForEach(model.filteredOrders) { order in
                    OrderSidebarRow(order: order)
                        .tag(order.id)
                }
            }
        }
        .navigationTitle("ParcelOps")
        .searchable(text: $model.searchText, prompt: "Search orders, tracking, email")
        .safeAreaInset(edge: .bottom) {
            Picker("Status", selection: $model.statusFilter) {
                Text("All").tag(nil as OrderStatus?)
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status as OrderStatus?)
                }
            }
            .pickerStyle(.menu)
            .padding()
        }
    }
}

struct Dashboard: View {
    @ObservedObject var model: ParcelTrackerModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Header(model: model)

                HStack(alignment: .top, spacing: 16) {
                    if let order = model.selectedOrder {
                        OrderDetail(order: order)
                    }
                    MailMonitor(events: model.mailEvents)
                }

                HStack(alignment: .top, spacing: 16) {
                    IntakePipeline()
                    IntegrationsPanel(integrations: model.integrations)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct Header: View {
    @ObservedObject var model: ParcelTrackerModel

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Company mail and parcel tracking")
                    .font(.largeTitle.bold())
                Text("Forwarded order emails, Shopify orders, store logins, and carrier updates in one operational queue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
            } label: {
                Label("Add order", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Button {
            } label: {
                Label("Sync now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SummaryRow: View {
    var title: String
    var value: String
    var icon: String
    var color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(title)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

struct OrderSidebarRow: View {
    var order: TrackedOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.orderNumber)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(order.risk.color)
                    .frame(width: 8, height: 8)
            }
            Text(order.store)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(order.status.rawValue)
                .font(.caption)
                .foregroundStyle(order.status.color)
        }
        .padding(.vertical, 5)
    }
}

struct OrderDetail: View {
    var order: TrackedOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .font(.title2.bold())
                    Text(order.store)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: order.status.rawValue, color: order.status.color)
                StatusBadge(text: "\(order.risk.rawValue) risk", color: order.risk.color)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                DetailTile(title: "Tracked email", value: order.email, icon: "at")
                DetailTile(title: "Carrier", value: "\(order.carrier) \(order.trackingNumber)", icon: "truck.box.fill")
                DetailTile(title: "Destination", value: order.destination, icon: "mappin.and.ellipse")
                DetailTile(title: "Expected", value: order.expectedDelivery, icon: "calendar")
                DetailTile(title: "Source", value: order.source.rawValue, icon: "tray.and.arrow.down.fill")
                DetailTile(title: "Latest update", value: order.lastUpdate, icon: "waveform.path.ecg")
            }

            Divider()

            Text("Tracking timeline")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(order.updates) { event in
                    TrackingEventRow(event: event)
                }
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct DetailTile: View {
    var title: String
    var value: String
    var icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.teal)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TrackingEventRow: View {
    var event: TrackingEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.icon)
                .foregroundStyle(.teal)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.title)
                        .font(.callout.bold())
                    Spacer()
                    Text(event.time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(event.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}

struct MailMonitor: View {
    var events: [MailEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mailbox monitor")
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "envelope.badge.shield.half.filled")
                    .foregroundStyle(.blue)
            }
            Text("Emails forwarded to the tracking mailbox are matched by order number, sender, tracking number, and recipient email.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        StatusBadge(text: event.severity.rawValue, color: event.severity.color)
                        Text(event.received)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(event.matchedOrder)
                            .font(.caption.bold())
                    }
                    Text(event.subject)
                        .font(.headline)
                    Text(event.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(event.sender)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .frame(width: 360, alignment: .top)
    }
}

struct IntakePipeline: View {
    private let steps = [
        ("Forwarded mailbox", "Parse receipts, dispatch notices, failed delivery emails, and support messages.", "envelope.open.fill"),
        ("Account sync", "Use store logins and Shopify OAuth to find orders that have no forwarded email yet.", "person.crop.circle.badge.checkmark"),
        ("Order matching", "Attach emails to the tracked user email, order number, store, and carrier tracking ID.", "link"),
        ("Carrier tracking", "Follow carrier scan events until delivery at the expected destination address.", "location.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Automation flow")
                .font(.title3.bold())

            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.2)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.teal)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.0)
                            .font(.headline)
                        Text(step.1)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct IntegrationsPanel: View {
    var integrations: [IntegrationAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Connected sources")
                    .font(.title3.bold())
                Spacer()
                Button {
                } label: {
                    Label("Connect", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            ForEach(integrations) { account in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: account.type))
                        .foregroundStyle(.teal)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(account.name)
                            .font(.headline)
                        Text("\(account.type) · \(account.login)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(account.status)
                            .font(.callout.bold())
                        Text(account.lastSync)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func icon(for type: String) -> String {
        if type == "Shopify" { return "cart.fill" }
        if type == "Forwarded mailbox" { return "envelope.fill" }
        return "lock.shield.fill"
    }
}
