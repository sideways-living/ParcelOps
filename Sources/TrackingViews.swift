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
        inboxTrackingCoverage
        mailboxProviderReleaseTrackingPanel
        gmailTrackingReleaseBoundary

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

  @ViewBuilder
  private var mailboxProviderReleaseTrackingPanel: some View {
    if store.mailboxProviderReleaseGateSummary.tone != "success" || store.mailboxProviderHandoffPacketSummary.tone != "success" {
      SettingsPanel(title: "Mailbox provider tracking context", symbol: "checkmark.seal.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this before trusting mailbox-derived tracking values as ready for dispatch. It summarizes provider setup, refresh evidence, parser/classifier state, and handoff follow-up without reading mail or changing carrier records.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
          MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
        }
      }
    }
  }

  private var gmailTrackingReleaseBoundary: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail tracking readiness",
      lead: "Gmail setup, sign-in, labels, classifier review, Inbox handoff, and audit evidence should not create carrier tracking work directly. Tracking starts from a confirmed order or imported Inbox row with tracking context.",
      sourceMetricTitle: "Gmail tracking sources",
      sourceCount: gmailTrackingSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, call carrier APIs, create tracking events, mutate mail, or change carrier records automatically."
    )
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

  private var inboxTrackingCoverage: some View {
    let inboxOrders = store.operatorSourceOrders
    let linkedEvents = trackingEventsLinkedToInboxOrders
    let actionEvents = trackingEventsNeedingAction
    let missingTrackingCount = inboxOrdersMissingTracking.count

    return SettingsPanel(title: "Inbox/Wishlist tracking readiness", symbol: "location.fill.viewfinder") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local carrier updates, warning state, and review follow-up.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedEvents.count) linked events", color: .teal)
          Badge("\(actionEvents.count) need action", color: actionEvents.isEmpty ? .green : .orange)
          Badge("\(missingTrackingCount) missing tracking", color: missingTrackingCount == 0 ? .green : .orange)
        }

        if !inboxTrackingProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for tracking checks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
              ForEach(inboxTrackingProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 9) {
                  Image(systemName: row.label.localizedCaseInsensitiveContains("Gmail") ? "envelope.badge.shield.half.filled" : "tray.and.arrow.down.fill")
                    .foregroundStyle(row.color)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer(minLength: 8)
                      Badge("\(row.count) intake", color: row.color)
                    }
                    Text(row.detail)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .padding(9)
                .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        if inboxOrders.isEmpty {
          Text("No source-created or Wishlist-linked orders are present yet. Create an order from Inbox or link a Wishlist purchase before checking tracking coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedEvents.isEmpty {
          Text("Source-created and Wishlist-linked orders do not have tracking events yet. Add a local tracking note from the order when carrier status needs monitoring.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionEvents.prefix(3))) { event in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: event.severity == .critical ? "exclamationmark.triangle.fill" : "location.fill.viewfinder")
                .foregroundStyle(event.severity == .critical ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(event.status)
                  .font(.caption.bold())
                Text(trackingActionSummary(for: event))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(event.severity.rawValue, color: event.severity.color)
            }
          }

          if actionEvents.isEmpty {
            Text("Linked tracking events are informational and reviewed for current source-created and Wishlist-linked orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionEvents.count > 3 {
            Text("\(actionEvents.count - 3) more linked tracking events need review or operational follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }




  private var trackingEventsLinkedToInboxOrders: [CarrierTrackingEvent] {
    let orderIDs = Set(store.operatorSourceOrders.map(\.id))
    return store.carrierTrackingEvents.filter { orderIDs.contains($0.orderID) }
  }

  private var inboxOrdersMissingTracking: [TrackedOrder] {
    let trackingOrderIDs = Set(trackingEventsLinkedToInboxOrders.map(\.orderID))
    return store.operatorSourceOrders.filter { !trackingOrderIDs.contains($0.id) }
  }

  private var inboxTrackingProviderRows: [(label: String, count: Int, detail: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]

    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }

    return counts
      .map { label, count in
        let tone = tones[label] ?? ""
        let detail: String
        switch tone {
        case "spacemail":
          detail = "SpaceMail intake supplied order or tracking context. Confirm linked tracking events before closing carrier follow-up.\(providerRefreshSuffix(for: tone))"
        case "gmail":
          detail = "Gmail intake supplied order or tracking context. Confirm linked tracking events before closing carrier follow-up.\(providerRefreshSuffix(for: tone))"
        case "mock":
          detail = "Mock mailbox intake supplied local test context. Use real provider refresh before relying on this for live operations."
        default:
          detail = "Local mailbox intake supplied order or tracking context. Open the linked order to inspect the source trail."
        }
        return (label: label, count: count, detail: detail, color: sourceColor(for: tone))
      }
      .sorted { lhs, rhs in
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return lhs.label < rhs.label
      }
  }

  private func providerRefreshSuffix(for tone: String) -> String {
    let refreshedCount: Int
    switch tone {
    case "spacemail":
      refreshedCount = store.totalSpaceMailDuplicateRefreshedCount
    case "gmail":
      refreshedCount = store.totalGmailDuplicateRefreshedCount
    default:
      refreshedCount = 0
    }
    guard refreshedCount > 0 else { return "" }
    return " \(refreshedCount) duplicate refresh\(refreshedCount == 1 ? "" : "es") updated existing Inbox rows; confirm tracking values before adding carrier follow-up."
  }

  private var gmailTrackingSourceCount: Int {
    inboxTrackingProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var trackingEventsNeedingAction: [CarrierTrackingEvent] {
    trackingEventsLinkedToInboxOrders.filter { event in
      event.severity == .watch || event.severity == .critical || event.reviewState != .accepted
    }
  }

  private func trackingActionSummary(for event: CarrierTrackingEvent) -> String {
    var parts: [String] = []
    if event.severity == .critical { parts.append("critical carrier update") }
    if event.severity == .watch { parts.append("watch carrier status") }
    if event.reviewState != .accepted { parts.append("mark reviewed") }
    if event.status.localizedCaseInsensitiveContains("delay") || event.detail.localizedCaseInsensitiveContains("delay") { parts.append("check delay") }
    if event.status.localizedCaseInsensitiveContains("exception") || event.detail.localizedCaseInsensitiveContains("exception") { parts.append("resolve exception") }
    return parts.isEmpty ? "Tracking event is informational and reviewed." : parts.joined(separator: ", ")
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

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
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
  @State private var feedbackMessage: String?

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

          if !trackingWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Label("Tracking follow-up", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)
              ForEach(trackingWarnings, id: \.self) { warning in
                Text(warning)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }

          if let store, let order {
            let linkedEmails = store.linkedIntakeEmails(for: order)
            let wishlistItems = store.activeWishlistItemsLinked(to: order)
            if !linkedEmails.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                Label("Inbox tracking source", systemImage: "tray.and.arrow.down.fill")
                  .font(.caption.bold())
                  .foregroundStyle(.teal)
                ForEach(linkedEmails.prefix(2)) { email in
                  HStack(spacing: 6) {
                    let sourceSummary = store.intakeSourceSummary(for: email)
                    Badge(sourceSummary.label, color: sourceColor(for: sourceSummary.tone))
                    if !email.detectedTrackingNumber.isPlaceholderValidationValue {
                      Badge("Tracking \(email.detectedTrackingNumber)", color: .teal)
                    }
                    if !email.detectedOrderNumber.isPlaceholderValidationValue {
                      Badge("Order \(email.detectedOrderNumber)", color: .blue)
                    }
                    Text(email.subject)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
              }
            }
            if !wishlistItems.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                Label("Wishlist tracking source", systemImage: "heart.text.square.fill")
                  .font(.caption.bold())
                  .foregroundStyle(.pink)
                ForEach(wishlistItems.prefix(2)) { item in
                  HStack(spacing: 6) {
                    Badge("Wishlist", color: .pink)
                    Badge(item.status, color: item.status.localizedCaseInsensitiveContains("review") ? .orange : .blue)
                    Text(item.itemName)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
              }
            }
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
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Tracking event marked reviewed locally. No carrier API, notification, or mailbox mutation occurred."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Tracking event removed locally. No carrier record, order system, or mailbox message was changed."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this tracking event for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this tracking event. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        if let store, let order {
          NavigationLink {
            OrderDetailView(order: order, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Profile", systemImage: "building.2.crop.circle") {
          onCreateProfile()
          feedbackMessage = "Vendor profile placeholder created from this tracking event for local reference."
        }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        TrackingEventActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var trackingWarnings: [String] {
    var warnings: [String] = []
    if event.severity == .critical {
      warnings.append("Critical tracking event needs immediate review.")
    }
    if event.severity == .watch {
      warnings.append("Tracking event is on watch; confirm whether the order needs follow-up.")
    }
    if event.status.localizedCaseInsensitiveContains("delay") || event.detail.localizedCaseInsensitiveContains("delay") {
      warnings.append("Carrier detail mentions a delay.")
    }
    if event.status.localizedCaseInsensitiveContains("exception") || event.detail.localizedCaseInsensitiveContains("exception") {
      warnings.append("Carrier detail mentions an exception.")
    }
    if event.reviewState != .accepted {
      warnings.append("Review state is \(event.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    return warnings
  }


  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }
}

private struct TrackingEventActionFeedbackPanel: View {
  var message: String

  var body: some View {
    Label {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}
