import SwiftUI

struct TrackingView: View {
  var store: ParcelOpsStore
  @State private var selectedCarrier: String?
  @State private var selectedSeverity: Severity?
  @State private var selectedOrderStatus: OrderStatus?
  @State private var trackingSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var carriers: [String] {
    Array(Set(store.carrierTrackingEvents.map(\.carrier))).sorted()
  }

  private var baseFilteredEvents: [CarrierTrackingEvent] {
    store.carrierTrackingEvents.filter { event in
      let order = store.orders.first { $0.id == event.orderID }
      let matchesCarrier = selectedCarrier == nil || event.carrier == selectedCarrier
      let matchesSeverity = selectedSeverity == nil || event.severity == selectedSeverity
      let matchesOrderStatus = selectedOrderStatus == nil || order?.status == selectedOrderStatus
      return matchesCarrier && matchesSeverity && matchesOrderStatus
    }
  }

  private var filteredEvents: [CarrierTrackingEvent] {
    let query = trackingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredEvents }
    return baseFilteredEvents.filter { event in
      trackingEvent(event, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedCarrier != nil
      || selectedSeverity != nil
      || selectedOrderStatus != nil
      || !trackingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
          HStack {
            Text("\(filteredEvents.count) visible tracking events")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredEvents.count) after filters", color: .blue)
            }
            Spacer()
          }

          if filteredEvents.isEmpty {
            MVPEmptyState(title: "No tracking events match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local carrier events." : "Tracking events appear here when local carrier warnings or placeholder updates are captured.", symbol: "location.fill.viewfinder", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
          } else {
            ForEach(filteredEvents) { event in
              TrackingEventRow(event: event, store: store, order: store.orders.first { $0.id == event.orderID }, suggestedContacts: store.suggestedContacts(for: event), suggestedProfiles: store.suggestedVendorProfiles(for: event), customerProfiles: store.suggestedCustomerProfiles(for: event), destinationAddresses: store.suggestedDestinationAddresses(for: event), deliveryInstructions: store.suggestedDeliveryInstructions(for: event), packageContents: store.suggestedPackageContents(for: event), shipmentGroups: store.suggestedShipmentGroups(for: event)) {
                store.markTrackingEventReviewed(event)
              } onRemove: {
                store.removeTrackingEvent(event)
              } onCreateTask: {
                store.createReviewTask(from: event)
              } onCreateDraft: {
                store.createDraftMessage(from: event)
              } onDraftFromContact: { contact in
                store.createDraftMessage(from: contact, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString, label: event.trackingNumber)
              } onCreateProfile: {
                store.addVendorProfile(profileType: .carrier, organisation: event.carrier, label: event.trackingNumber)
              } onTaskFromProfile: { profile in
                store.createReviewTask(from: profile)
              } onDraftFromProfile: { profile in
                store.createDraftMessage(from: profile)
              } relatedTasks: {
                store.tasks(for: .trackingEvent, linkedEntityID: event.id.uuidString)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search carrier, tracking, status, location, order, customer, or destination", text: $trackingSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Carrier", selection: $selectedCarrier) {
        Text("All carriers").tag(nil as String?)
        ForEach(carriers, id: \.self) { carrier in
          Text(carrier).tag(carrier as String?)
        }
      }

      Picker("Severity", selection: $selectedSeverity) {
        Text("All severities").tag(nil as Severity?)
        Text(Severity.info.rawValue).tag(Severity.info as Severity?)
        Text(Severity.watch.rawValue).tag(Severity.watch as Severity?)
        Text(Severity.critical.rawValue).tag(Severity.critical as Severity?)
      }

      Picker("Order status", selection: $selectedOrderStatus) {
        Text("All statuses").tag(nil as OrderStatus?)
        ForEach(OrderStatus.allCases) { status in
          Text(status.rawValue).tag(status as OrderStatus?)
        }
      }

      if hasActiveFilters {
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    selectedCarrier = nil
    selectedSeverity = nil
    selectedOrderStatus = nil
    trackingSearchText = ""
  }

  private func trackingEvent(_ event: CarrierTrackingEvent, matches query: String) -> Bool {
    let order = store.orders.first { $0.id == event.orderID }
    let shipmentGroups = store.suggestedShipmentGroups(for: event)
    let searchableText = [
      event.carrier,
      event.trackingNumber,
      event.eventTime,
      event.location,
      event.status,
      event.detail,
      event.severity.rawValue,
      event.source.rawValue,
      event.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? "",
      shipmentGroups.map(\.groupName).joined(separator: " "),
      shipmentGroups.map(\.destinationSummary).joined(separator: " "),
      shipmentGroups.map(\.recipientCustomerSummary).joined(separator: " ")
    ].joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct TrackingEventRow: View {
  var event: CarrierTrackingEvent
  var store: ParcelOpsStore? = nil
  var order: TrackedOrder?
  var suggestedContacts: [ContactDirectoryEntry] = []
  var suggestedProfiles: [VendorProfile] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var shipmentGroups: [ShipmentGroup] = []
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  var onDraftFromContact: (ContactDirectoryEntry) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }
  var relatedTasks: () -> [ReviewTask] = { [] }

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

          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
          }

          if !destinationAddresses.isEmpty {
            DestinationAddressStrip(addresses: destinationAddresses)
          }
          if !deliveryInstructions.isEmpty {
            DeliveryInstructionStrip(instructions: deliveryInstructions)
          }
          if !packageContents.isEmpty {
            PackageContentStrip(contents: packageContents)
          }

          ForEach(relatedTasks()) { task in
            HStack(spacing: 8) {
              Badge(task.isLocallyOverdue ? "Overdue" : task.priority.rawValue, color: task.isLocallyOverdue ? .red : task.priority.color)
              Text("Task due \(task.dueDate) with \(task.assignee)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          ForEach(suggestedContacts) { contact in
            ContactSuggestionRow(contact: contact) {
              onDraftFromContact(contact)
            }
          }

          ForEach(suggestedProfiles) { profile in
            VendorProfileSuggestionRow(profile: profile) {
              onTaskFromProfile(profile)
            } onCreateDraft: {
              onDraftFromProfile(profile)
        }
      }

      if !customerProfiles.isEmpty {
        CustomerProfileStrip(profiles: customerProfiles)
      }
    }
      }

      CompactActionRow {
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if let store, let order {
          NavigationLink {
            OrderDetailView(order: order, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
