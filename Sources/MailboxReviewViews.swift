import SwiftUI

struct MailboxView: View {
  var events: [MailEvent]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(events) { event in
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
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
