import SwiftUI

struct TrackingView: View {
  var store: ParcelOpsStore
  @State private var selectedCarrier: String?
  @State private var selectedSeverity: Severity?
  @State private var selectedOrderStatus: OrderStatus?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var carriers: [String] {
    Array(Set(store.carrierTrackingEvents.map(\.carrier))).sorted()
  }

  private var filteredEvents: [CarrierTrackingEvent] {
    store.carrierTrackingEvents.filter { event in
      let order = store.orders.first { $0.id == event.orderID }
      let matchesCarrier = selectedCarrier == nil || event.carrier == selectedCarrier
      let matchesSeverity = selectedSeverity == nil || event.severity == selectedSeverity
      let matchesOrderStatus = selectedOrderStatus == nil || order?.status == selectedOrderStatus
      return matchesCarrier && matchesSeverity && matchesOrderStatus
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Tracking")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local carrier updates linked to tracked orders.")
            .foregroundStyle(.secondary)
        }

        filterBar

        SettingsPanel(title: "Carrier events", symbol: "location.fill.viewfinder") {
          if filteredEvents.isEmpty {
            Text("No tracking events match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredEvents) { event in
              TrackingEventRow(event: event, order: store.orders.first { $0.id == event.orderID }) {
                store.markTrackingEventReviewed(event)
              } onRemove: {
                store.removeTrackingEvent(event)
              } onCreateTask: {
                store.createReviewTask(from: event)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Carrier", selection: $selectedCarrier) {
        Text("All carriers").tag(nil as String?)
        ForEach(carriers, id: \.self) { carrier in
          Text(carrier).tag(carrier as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Severity", selection: $selectedSeverity) {
        Text("All severities").tag(nil as Severity?)
        Text(Severity.info.rawValue).tag(Severity.info as Severity?)
        Text(Severity.watch.rawValue).tag(Severity.watch as Severity?)
        Text(Severity.critical.rawValue).tag(Severity.critical as Severity?)
      }
      .pickerStyle(.menu)

      Picker("Order status", selection: $selectedOrderStatus) {
        Text("All statuses").tag(nil as OrderStatus?)
        ForEach(OrderStatus.allCases) { status in
          Text(status.rawValue).tag(status as OrderStatus?)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedCarrier = nil
        selectedSeverity = nil
        selectedOrderStatus = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct TrackingEventRow: View {
  var event: CarrierTrackingEvent
  var order: TrackedOrder?
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.source.symbol)
          .foregroundStyle(event.severity.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.status)
                .font(.headline)
              Text("\(event.carrier) • \(event.trackingNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(event.severity.rawValue, color: event.severity.color)
          }

          Text(event.detail)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Label(event.location, systemImage: "mappin.and.ellipse")
            Text(event.eventTime)
            if let order {
              Text(order.orderNumber)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(event.reviewState.rawValue, color: event.reviewState.color)
            Label(event.source.rawValue, systemImage: event.source.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      HStack {
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
