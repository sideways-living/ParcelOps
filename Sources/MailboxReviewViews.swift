import SwiftUI

struct MailboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Forwarded email intake")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local captures from the tracking mailbox are reviewed here before they become order records or supporting evidence.")
            .foregroundStyle(.secondary)
        }

        SettingsPanel(title: "Detected order emails", symbol: "envelope.open.fill") {
          ForEach(store.intakeEmails) { email in
            IntakeEmailRow(email: email, orders: store.orders) { order in
              store.linkIntakeEmail(email, to: order)
            } onCreateOrder: {
              store.createOrder(from: email)
            } onReviewed: {
              store.markIntakeEmailReviewed(email)
            } onIgnore: {
              store.ignoreIntakeEmail(email)
            }
          }
        }

        SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
          ForEach(store.mailEvents) { event in
            MailEventRow(event: event)
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct IntakeEmailRow: View {
  var email: ForwardedEmailIntake
  var orders: [TrackedOrder]
  var onLinkOrder: (TrackedOrder) -> Void
  var onCreateOrder: () -> Void
  var onReviewed: () -> Void
  var onIgnore: () -> Void

  private var linkedOrder: TrackedOrder? {
    orders.first { $0.id == email.linkedOrderID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(email.reviewState.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(email.subject)
                .font(.headline)
              Text("\(email.sender) • \(email.receivedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(email.reviewState.rawValue, color: email.reviewState.color)
          }
          Text(email.rawBodyPreview)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            IntakeFact(title: "Merchant", value: email.detectedMerchant, symbol: "storefront.fill")
            IntakeFact(title: "Order", value: email.detectedOrderNumber, symbol: "number")
            IntakeFact(title: "Tracking", value: email.detectedTrackingNumber, symbol: "barcode.viewfinder")
            IntakeFact(title: "Destination", value: email.detectedDestinationAddress, symbol: "mappin.and.ellipse")
          }
          if let linkedOrder {
            Text("Linked to \(linkedOrder.orderNumber) • \(linkedOrder.store)")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          }
        }
      }

      HStack {
        Menu {
          ForEach(orders) { order in
            Button("\(order.orderNumber) • \(order.store)") {
              onLinkOrder(order)
            }
          }
        } label: {
          Label("Link order", systemImage: "link")
        }
        .buttonStyle(.bordered)

        Button("Create order", systemImage: "plus.circle.fill", action: onCreateOrder)
          .buttonStyle(.borderedProminent)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Ignore", systemImage: "trash", action: onIgnore)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct IntakeFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
      }
    }
  }
}

struct MailEventRow: View {
  var event: MailEvent

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "envelope.badge.fill")
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
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
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

        SettingsPanel(title: "Forwarded emails", symbol: "envelope.open.fill") {
          ForEach(store.reviewIntakeEmails) { email in
            IntakeEmailRow(email: email, orders: store.orders) { order in
              store.linkIntakeEmail(email, to: order)
            } onCreateOrder: {
              store.createOrder(from: email)
            } onReviewed: {
              store.markIntakeEmailReviewed(email)
            } onIgnore: {
              store.ignoreIntakeEmail(email)
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
          Text("Recipient \(order.recipientEmail), checked in \(order.checkedMailbox)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(order.latestStatus)
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
