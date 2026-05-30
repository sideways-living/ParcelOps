import SwiftUI

struct DashboardView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Operations overview")
              .font(isCompact ? .title.bold() : .largeTitle.bold())
            Text("Mail intake, supplier accounts, recipient email matching, wishlist intake, collections, and delivery exports.")
              .foregroundStyle(.secondary)
          }
          HStack {
            Button("Create manual order", systemImage: "plus", action: store.createManualOrderPlaceholder)
              .buttonStyle(.borderedProminent)
            Button("Sync", systemImage: "arrow.clockwise", action: store.syncSources)
              .buttonStyle(.bordered)
          }
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4), spacing: 12) {
          MetricCard(title: "Active orders", value: "\(store.activeCount)", symbol: "shippingbox.fill", color: .teal)
          MetricCard(title: "Exceptions", value: "\(store.exceptionCount)", symbol: "exclamationmark.triangle.fill", color: .red)
          MetricCard(title: "Mailbox events", value: "\(store.mailEvents.count)", symbol: "envelope.fill", color: .blue)
          MetricCard(title: "Wishlist", value: "\(store.wishlistItems.count)", symbol: "star.square.fill", color: .purple)
        }

        if isCompact {
          VStack(alignment: .leading, spacing: 14) {
            OrdersCompactView(orders: store.orders)
            MailboxCompactView(events: store.mailEvents)
          }
        } else {
          HStack(alignment: .top, spacing: 14) {
            OrdersCompactView(orders: store.orders)
            MailboxCompactView(events: store.mailEvents)
          }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }
}

struct MetricCard: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(color)
      Text(value)
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text(title)
        .font(.callout)
        .foregroundStyle(.secondary)
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
          HStack(alignment: .top) {
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
