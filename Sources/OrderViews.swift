import SwiftUI

struct OrdersView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var orderItems: [OrderQueueItem] {
    store.filteredOrders
      .map(queueItem)
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.order.orderNumber.localizedCaseInsensitiveCompare(second.order.orderNumber) == .orderedAscending
        }
        return first.sortPriority > second.sortPriority
      }
  }
  private var inboxCreatedOrderItems: [OrderQueueItem] {
    store.orders
      .filter(isInboxCreatedOrder)
      .prefix(4)
      .map(queueItem)
  }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        MVPWorkflowGuide(
          title: "Order workflow",
          detail: "Use this queue after Inbox acceptance to focus on active, risky, or review-needed order records first.",
          steps: [
            "Search by order number, tracking number, store, customer, email, or destination.",
            "Work exceptions, review-needed orders, warning tracking events, and overdue tasks first.",
            "Open an order when you need the full linked record context."
          ],
          symbol: "shippingbox.fill"
        )

        if !inboxCreatedOrderItems.isEmpty {
          SettingsPanel(title: "Created from Inbox", symbol: "tray.and.arrow.down.fill") {
            VStack(alignment: .leading, spacing: 12) {
              Text("Newest orders created or linked from mailbox intake, import queue, or acceptance review. Start here after using Create order in Inbox.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              ForEach(inboxCreatedOrderItems) { item in
                OrderQueueRow(item: item, store: store)
              }
            }
          }
        }

        SettingsPanel(title: "Order queue", symbol: "shippingbox.fill") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Prioritized local orders with tracking, task, review, and dispatch signals in one row.")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            filterControls

            if orderItems.isEmpty {
              MVPEmptyState(title: "No orders match this queue", detail: "Clear the status filter or search text, or add a manual order to test the local order workflow.", symbol: "shippingbox.fill", actionTitle: "Add order", action: store.createManualOrderPlaceholder)
            } else {
              ForEach(orderItems) { item in
                OrderQueueRow(item: item, store: store)
              }
            }
          }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .searchable(text: $store.searchText, prompt: "Search orders, tracking, email, store")
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Orders")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("A focused queue for tracked local orders after intake has been accepted or linked.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Queue", "\(orderItems.count)", .blue),
        ("Active", "\(store.orders.filter { $0.status != .delivered }.count)", .teal),
        ("Review", "\(store.orders.filter { $0.reviewState != .accepted }.count)", .orange),
        ("From Inbox", "\(store.orders.filter(isInboxCreatedOrder).count)", .purple),
        ("Exceptions", "\(store.orders.filter { $0.status == .exception }.count)", .red),
        ("Delivered", "\(store.orders.filter { $0.status == .delivered }.count)", .green)
      ])
    }
  }

  private var filterControls: some View {
    @Bindable var store = store

    return HStack(alignment: .center, spacing: 10) {
      if isCompact {
        statusPicker
          .pickerStyle(.menu)
      } else {
        statusPicker
          .pickerStyle(.segmented)
      }
      Spacer()
      Button("Add order", systemImage: "plus", action: store.createManualOrderPlaceholder)
        .buttonStyle(.borderedProminent)
    }
  }

  private var statusPicker: some View {
    @Bindable var store = store
    return Picker("Status", selection: $store.selectedStatus) {
      Text("All").tag(nil as OrderStatus?)
      ForEach(OrderStatus.allCases) { status in
        Text(status.rawValue).tag(status as OrderStatus?)
      }
    }
  }

  private func queueItem(for order: TrackedOrder) -> OrderQueueItem {
    OrderQueueItem(
      order: order,
      trackingEvents: store.trackingEvents(for: order.id),
      tasks: store.tasks(for: .order, linkedEntityID: order.id.uuidString),
      manifests: store.suggestedShipmentManifestRecords(for: order),
      checklists: store.suggestedDispatchReadinessChecklists(for: order)
    )
  }

  private func isInboxCreatedOrder(_ order: TrackedOrder) -> Bool {
    order.source == .forwardedMailbox
      || order.checkedMailbox == "manual-import"
      || order.latestStatus.localizedCaseInsensitiveContains("import queue")
      || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
  }
}

private struct OrderQueueItem: Identifiable {
  var order: TrackedOrder
  var trackingEvents: [CarrierTrackingEvent]
  var tasks: [ReviewTask]
  var manifests: [ShipmentManifestRecord]
  var checklists: [DispatchReadinessChecklist]

  var id: UUID { order.id }
  var warningTrackingCount: Int {
    trackingEvents.filter { $0.severity == .watch || $0.severity == .critical }.count
  }
  var criticalTrackingCount: Int {
    trackingEvents.filter { $0.severity == .critical }.count
  }
  var urgentTaskCount: Int {
    tasks.filter { $0.status != .completed && ($0.priority == .urgent || $0.priority == .high || $0.isLocallyOverdue) }.count
  }
  var blockedDispatchCount: Int {
    let blockedManifests = manifests.filter { manifest in
      manifest.dispatchStatus == .blockedNeedsReview
    }.count
    let blockedChecklists = checklists.filter { checklist in
      checklist.checklistStatus == .blockedNeedsReview
    }.count
    return blockedManifests + blockedChecklists
  }
  var dispatchContextCount: Int {
    manifests.count + checklists.count
  }
  var riskLabel: String {
    if order.status == .exception || criticalTrackingCount > 0 || blockedDispatchCount > 0 {
      "High risk"
    } else if warningTrackingCount > 0 || urgentTaskCount > 0 || order.reviewState != .accepted {
      "Needs attention"
    } else if order.status == .delivered {
      "Complete"
    } else {
      "On track"
    }
  }
  var riskColor: Color {
    switch riskLabel {
    case "High risk": .red
    case "Needs attention": .orange
    case "Complete": .green
    default: .blue
    }
  }
  var nextAction: String {
    if order.reviewState != .accepted {
      "Review order details"
    } else if order.status == .exception || criticalTrackingCount > 0 {
      "Create follow-up task"
    } else if blockedDispatchCount > 0 {
      "Open dispatch context"
    } else if urgentTaskCount > 0 {
      "Resolve linked task"
    } else if warningTrackingCount > 0 {
      "Check tracking events"
    } else if order.status == .delivered {
      "Confirm closure"
    } else {
      "Monitor progress"
    }
  }
  var sortPriority: Int {
    if order.status == .exception { return 120 }
    if criticalTrackingCount > 0 { return 110 }
    if blockedDispatchCount > 0 { return 105 }
    if urgentTaskCount > 0 { return 95 }
    if order.reviewState != .accepted { return 90 }
    if warningTrackingCount > 0 { return 80 }
    switch order.status {
    case .inTransit, .shipped: return 70
    case .ordered, .intake: return 60
    case .delivered: return 20
    case .exception: return 120
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
        Text(order.orderNumber)
          .font(.headline)
        Text(order.store)
          .foregroundStyle(.secondary)
        Text("\(order.customer) • recipient \(order.recipientEmail)")
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

private struct OrderQueueRow: View {
  var item: OrderQueueItem
  var store: ParcelOpsStore
  @State private var isEditing = false

  var body: some View {
    let order = item.order

    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: order.status == .exception ? "exclamationmark.triangle.fill" : order.source.symbol)
          .foregroundStyle(item.riskColor)
          .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
              Text("\(order.store) • \(order.orderNumber)")
                .font(.headline)
              Text("\(order.customer) • \(order.recipientEmail)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Badge(item.riskLabel, color: item.riskColor)
          }

          Text(order.destination)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          Text("\(order.carrier) • \(order.trackingNumber) • \(order.latestStatus)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          CompactMetadataGrid {
            Badge(order.status.rawValue, color: order.status.color)
            Badge(order.reviewState.rawValue, color: order.reviewState.color)
            Badge(order.fulfillment.rawValue, color: .blue)
            Label(order.eta, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            if item.warningTrackingCount > 0 {
              Badge("\(item.warningTrackingCount) tracking", color: item.criticalTrackingCount > 0 ? .red : .orange)
            }
            if item.urgentTaskCount > 0 {
              Badge("\(item.urgentTaskCount) task", color: .red)
            }
            if item.dispatchContextCount > 0 {
              Badge("\(item.dispatchContextCount) dispatch", color: item.blockedDispatchCount > 0 ? .red : .purple)
            }
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption)
            .foregroundStyle(item.riskColor)
        }
      }

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: order, store: store)
        } label: {
          Label("Open", systemImage: "arrow.right.circle.fill")
        }
        .buttonStyle(.bordered)

        Button("Edit", systemImage: "pencil") {
          isEditing = true
        }
        .buttonStyle(.bordered)

        Button("Task", systemImage: "checklist") {
          store.createReviewTask(from: order)
        }
        .buttonStyle(.bordered)

        Button("Draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
        }
        .buttonStyle(.bordered)

        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          var reviewedOrder = order
          reviewedOrder.reviewState = .accepted
          store.updateOrder(reviewedOrder)
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    .sheet(isPresented: $isEditing) {
      OrderEditView(order: order) { updatedOrder in
        store.updateOrder(updatedOrder)
      }
    }
  }
}

struct OrderDetailView: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var isEditing = false

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var currentOrder: TrackedOrder {
    store.orders.first { $0.id == order.id } ?? order
  }

  var body: some View {
    let order = currentOrder

    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if isCompact {
          VStack(alignment: .leading, spacing: 12) {
            orderHeaderSummary(order)
            CompactActionRow {
              orderHeaderButtons(order)
            }
          }
        } else {
          HStack(alignment: .top) {
            orderHeaderSummary(order)
            Spacer()
            HStack(spacing: 8) {
              orderHeaderButtons(order)
            }
          }
        }

        if isInboxCreatedOrder(order) {
          inboxHandoffChecklist(order)
          inboxSourceTrail(order)
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isCompact ? 1 : 2), alignment: .leading, spacing: 12) {
          DetailCell("Recipient email", order.recipientEmail, symbol: "at")
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

        Panel(title: "Suggested contacts", symbol: "person.crop.circle.badge.checkmark") {
          let contacts = store.suggestedContacts(for: order)

          if contacts.isEmpty {
            Text("No local contacts matched this order.")
              .foregroundStyle(.secondary)
          } else {
            VStack(spacing: 10) {
              ForEach(contacts) { contact in
                ContactSuggestionRow(contact: contact) {
                  store.createDraftMessage(from: contact, linkedEntityType: .order, linkedEntityID: order.id.uuidString, label: order.orderNumber)
                }
              }
            }
          }
        }

        Panel(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
          let profiles = store.suggestedCustomerProfiles(for: order)

          if profiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("No local customer profiles matched this order.")
                .foregroundStyle(.secondary)
              Button("Create profile", systemImage: "person.badge.plus") {
                store.addCustomerRecipientProfile(displayName: order.customer, organisationTeam: order.customer, email: order.recipientEmail, destination: order.destination, profileType: .recipient)
              }
              .buttonStyle(.bordered)
            }
          } else {
            CustomerProfileStrip(profiles: profiles)
          }
        }

        Panel(title: "Destination addresses", symbol: "mappin.and.ellipse") {
          let addresses = store.suggestedDestinationAddresses(for: order)

          if addresses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("No local destination addresses matched this order.")
                .foregroundStyle(.secondary)
              Button("Create address", systemImage: "mappin.and.ellipse") {
                store.addDestinationAddress(label: "\(order.customer) destination", customerProfileID: store.suggestedCustomerProfiles(for: order).first?.id, organisationTeam: order.customer, addressSummary: order.destination, cityRegion: order.destination, preferredCarrier: order.carrier)
              }
              .buttonStyle(.bordered)
            }
          } else {
            DestinationAddressStrip(addresses: addresses)
          }
        }

        Panel(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
          let instructions = store.suggestedDeliveryInstructions(for: order)

          if instructions.isEmpty {
            Text("No local delivery instructions matched this order.")
              .foregroundStyle(.secondary)
          } else {
            DeliveryInstructionStrip(instructions: instructions)
          }
        }

        Panel(title: "Package contents", symbol: "shippingbox.circle.fill") {
          let contents = store.suggestedPackageContents(for: order)

          if contents.isEmpty {
            Text("No local package contents matched this order.")
              .foregroundStyle(.secondary)
          } else {
            PackageContentStrip(contents: contents)
          }
        }

        Panel(title: "Costs & budgets", symbol: "creditcard.and.123") {
          let costs = store.suggestedCostRecords(for: order)

          if costs.isEmpty {
            Text("No local cost records matched this order.")
              .foregroundStyle(.secondary)
          } else {
            CostRecordStrip(costs: costs)
          }
        }

        Panel(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
          let claims = store.suggestedReturnClaims(for: order)

          if claims.isEmpty {
            Text("No local returns or claims matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ReturnClaimStrip(claims: claims)
          }
        }

        Panel(title: "Procurement", symbol: "cart.badge.plus") {
          let requests = store.suggestedProcurementRequests(for: order)

          if requests.isEmpty {
            Text("No local procurement requests matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ProcurementRequestStrip(requests: requests)
          }
        }

        Panel(title: "Receiving inspections", symbol: "checklist.checked") {
          let inspections = store.suggestedReceivingInspections(for: order)

          if inspections.isEmpty {
            Text("No local receiving inspections matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ReceivingInspectionStrip(inspections: inspections)
          }
        }

        Panel(title: "Inventory receipts", symbol: "archivebox.fill") {
          let receipts = store.suggestedInventoryReceipts(for: order)

          if receipts.isEmpty {
            Text("No local inventory receipts matched this order.")
              .foregroundStyle(.secondary)
          } else {
            InventoryReceiptStrip(receipts: receipts)
          }
        }

        Panel(title: "Storage locations", symbol: "cabinet.fill") {
          let locations = store.suggestedStorageLocations(for: order)

          if locations.isEmpty {
            Text("No local storage locations matched this order.")
              .foregroundStyle(.secondary)
          } else {
            StorageLocationStrip(locations: locations)
          }
        }

        Panel(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
          let records = store.suggestedCustodyRecords(for: order)

          if records.isEmpty {
            Text("No local custody records matched this order.")
              .foregroundStyle(.secondary)
          } else {
            CustodyRecordStrip(records: records)
          }
        }

        Panel(title: "Label references", symbol: "barcode.viewfinder") {
          let records = store.suggestedLabelReferenceRecords(for: order)

          if records.isEmpty {
            Text("No local label references matched this order.")
              .foregroundStyle(.secondary)
          } else {
            LabelReferenceStrip(records: records)
          }
        }

        Panel(title: "Scan sessions", symbol: "qrcode.viewfinder") {
          let records = store.suggestedScanSessionRecords(for: order)

          if records.isEmpty {
            Text("No local scan sessions matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ScanSessionStrip(records: records)
          }
        }

        Panel(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
          let records = store.suggestedShipmentManifestRecords(for: order)

          if records.isEmpty {
            Text("No local shipment manifests matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ShipmentManifestStrip(records: records)
          }
        }

        Panel(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
          let checklists = store.suggestedDispatchReadinessChecklists(for: order)

          if checklists.isEmpty {
            Text("No local dispatch readiness checklists matched this order.")
              .foregroundStyle(.secondary)
          } else {
            DispatchReadinessStrip(checklists: checklists)
          }
        }

        Panel(title: "Suggested accounts", symbol: "key.horizontal.fill") {
          let accounts = store.suggestedAccounts(for: order)

          if accounts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("No local account placeholders matched this order.")
                .foregroundStyle(.secondary)
              Button("Create account", systemImage: "key.badge.plus") {
                store.addAccountCredentialRecord(linkedEntityType: .order, linkedEntityID: order.id.uuidString, organisation: order.store, label: order.orderNumber)
              }
              .buttonStyle(.bordered)
            }
          } else {
            VStack(spacing: 10) {
              ForEach(accounts) { account in
                AccountSuggestionRow(account: account) {
                  store.createReviewTask(from: account)
                } onCreateDraft: {
                  store.createDraftMessage(from: account)
                }
              }
            }
          }
        }

        Panel(title: "Suggested vendor profiles", symbol: "building.2.crop.circle.fill") {
          let profiles = store.suggestedVendorProfiles(for: order)

          if profiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("No local vendor profiles matched this order.")
                .foregroundStyle(.secondary)
              Button("Create profile", systemImage: "building.2.crop.circle") {
                store.addVendorProfile(profileType: order.fulfillment == .delivery ? .carrier : .store, organisation: order.store, label: order.orderNumber)
              }
              .buttonStyle(.bordered)
            }
          } else {
            VStack(spacing: 10) {
              ForEach(profiles) { profile in
                VendorProfileSuggestionRow(profile: profile) {
                  store.createReviewTask(from: profile)
                } onCreateDraft: {
                  store.createDraftMessage(from: profile)
                }
              }
            }
          }
        }

        Panel(title: "Shipment group context", symbol: "shippingbox.and.arrow.backward.fill") {
          let groups = store.suggestedShipmentGroups(for: order)

          if groups.isEmpty {
            Text("No local shipment groups matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ShipmentGroupContextStrip(groups: groups)
          }
        }

        Panel(title: "Import queue context", symbol: "tray.and.arrow.down.fill") {
          let items = store.importQueueItems(for: order)

          if items.isEmpty {
            Text("No local import queue items matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ImportQueueContextStrip(items: items)
          }
        }

        Panel(title: "Acceptance history", symbol: "checkmark.rectangle.stack.fill") {
          let records = store.acceptanceRecords(for: order)

          if records.isEmpty {
            Text("No local acceptance records matched this order.")
              .foregroundStyle(.secondary)
          } else {
            AcceptanceHistoryStrip(records: records)
          }
        }

        Panel(title: "Exception playbooks", symbol: "book.closed.fill") {
          let playbooks = store.suggestedPlaybooks(for: order)

          if playbooks.isEmpty {
            Text("No local exception playbooks matched this order.")
              .foregroundStyle(.secondary)
          } else {
            ExceptionPlaybookStrip(playbooks: playbooks)
          }
        }

        Panel(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
          let notes = store.handoffNotes(for: order)

          if notes.isEmpty {
            Text("No local handoff notes matched this order.")
              .foregroundStyle(.secondary)
          } else {
            HandoffNoteStrip(notes: notes)
          }
        }

        Panel(title: "SLA context", symbol: "timer") {
          let tasks = store.tasks(for: .order, linkedEntityID: order.id.uuidString)
          let policies = store.policies(for: .order)

          VStack(alignment: .leading, spacing: 10) {
            if tasks.isEmpty && policies.isEmpty {
              Text("No local SLA tasks or policies linked to this order.")
                .foregroundStyle(.secondary)
            } else {
              ForEach(tasks) { task in
                HStack {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                      .font(.callout.weight(.semibold))
                    Text("Due \(task.dueDate) • \(task.assignee)")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Badge(task.isLocallyOverdue ? "Overdue" : task.priority.rawValue, color: task.isLocallyOverdue ? .red : task.priority.color)
                }
                .padding(10)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }

              ForEach(policies) { policy in
                Text("\(policy.name): \(policy.responseTarget); \(policy.resolutionTarget)")
                  .font(.caption)
                  .foregroundStyle(policy.priority.color)
              }
            }
          }
        }

        if order.fulfillment == .delivery {
          Button("Mark parcel handoff planned", systemImage: "square.and.arrow.up") {
            store.exportToParcel(order: order)
          }
          .buttonStyle(.borderedProminent)
        }

        Panel(title: "Tracking", symbol: "location.fill.viewfinder") {
          let events = store.trackingEvents(for: order.id)

          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("\(events.count) carrier events")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Add event", systemImage: "plus") {
                store.addPlaceholderTrackingEvent(to: order)
              }
              .buttonStyle(.bordered)
            }

            if events.isEmpty {
              Text("No tracking events linked.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
              ForEach(events) { event in
                TrackingEventRow(event: event, order: order, suggestedContacts: store.suggestedContacts(for: event), suggestedProfiles: store.suggestedVendorProfiles(for: event), customerProfiles: store.suggestedCustomerProfiles(for: event), destinationAddresses: store.suggestedDestinationAddresses(for: event), deliveryInstructions: store.suggestedDeliveryInstructions(for: event), packageContents: store.suggestedPackageContents(for: event), shipmentGroups: store.suggestedShipmentGroups(for: event)) {
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

        Panel(title: "Evidence", symbol: "paperclip") {
          let attachments = store.evidence(for: .order, linkedEntityID: order.id)

          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("\(attachments.count) linked attachments")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Add evidence", systemImage: "plus") {
                store.addPlaceholderEvidence(to: .order, linkedEntityID: order.id, label: order.orderNumber)
              }
              .buttonStyle(.bordered)
            }

            if attachments.isEmpty {
              Text("No evidence linked.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
              ForEach(attachments) { attachment in
                EvidenceAttachmentRow(attachment: attachment, shipmentGroups: store.suggestedShipmentGroups(for: attachment), customerProfiles: store.suggestedCustomerProfiles(for: attachment), destinationAddresses: store.suggestedDestinationAddresses(for: attachment), deliveryInstructions: store.suggestedDeliveryInstructions(for: attachment), packageContents: store.suggestedPackageContents(for: attachment)) {
                  store.markEvidenceReviewed(attachment)
                } onRemove: {
                  store.removeEvidence(attachment)
                } onCreateTask: {
                  store.createReviewTask(from: attachment)
                } onCreateDraft: {
                  store.createDraftMessage(from: attachment)
                } onCreateContact: {
                  store.addContactDirectoryEntry(linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString, label: attachment.fileName)
                }
              }
            }
          }
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
    .sheet(isPresented: $isEditing) {
      OrderEditView(order: order) { updatedOrder in
        store.updateOrder(updatedOrder)
      }
    }
  }

  private func orderHeaderSummary(_ order: TrackedOrder) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(order.orderNumber)
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text(order.store)
        .foregroundStyle(.secondary)
      HStack {
        Badge(order.status.rawValue, color: order.status.color)
        Badge(order.reviewState.rawValue, color: order.reviewState.color)
      }
    }
  }

  private func inboxHandoffChecklist(_ order: TrackedOrder) -> some View {
    let tasks = store.tasks(for: .order, linkedEntityID: order.id.uuidString)
    let manifests = store.suggestedShipmentManifestRecords(for: order)
    let checklists = store.suggestedDispatchReadinessChecklists(for: order)
    let missingTracking = order.trackingNumber == "Pending" || order.trackingNumber.isPlaceholderValidationValue
    let missingDestination = order.destination == "Pending review" || order.destination.isPlaceholderValidationValue
    let needsDispatchSetup = [.shipped, .inTransit, .exception].contains(order.status) && manifests.isEmpty && checklists.isEmpty

    return Panel(title: "Inbox handoff checklist", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This order was created from intake. Confirm the detected details before it moves deeper into dispatch or customer follow-up.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge(missingTracking ? "Tracking needs check" : "Tracking captured", color: missingTracking ? .orange : .green)
          Badge(missingDestination ? "Destination needs check" : "Destination captured", color: missingDestination ? .orange : .green)
          Badge("\(tasks.count) tasks", color: tasks.isEmpty ? .secondary : .purple)
          Badge("\(manifests.count + checklists.count) dispatch links", color: needsDispatchSetup ? .orange : .teal)
        }

        VStack(alignment: .leading, spacing: 6) {
          checklistLine(
            title: missingTracking ? "Confirm tracking number" : "Tracking number is ready",
            detail: missingTracking ? "Edit the order if the intake parser could not extract a carrier tracking value." : "\(order.carrier) • \(order.trackingNumber)",
            symbol: "barcode.viewfinder",
            color: missingTracking ? .orange : .green
          )
          checklistLine(
            title: missingDestination ? "Confirm destination" : "Destination is ready",
            detail: missingDestination ? "Edit the order or create a destination address before dispatch setup." : order.destination,
            symbol: "mappin.and.ellipse",
            color: missingDestination ? .orange : .green
          )
          checklistLine(
            title: tasks.isEmpty ? "Create follow-up ownership" : "Follow-up task exists",
            detail: tasks.isEmpty ? "Create a task when someone needs to verify this Inbox-created order." : tasks.prefix(2).map(\.title).joined(separator: "; "),
            symbol: "checklist",
            color: tasks.isEmpty ? .orange : .purple
          )
          checklistLine(
            title: needsDispatchSetup ? "Dispatch setup is missing" : "Dispatch context is present or not needed yet",
            detail: needsDispatchSetup ? "Open Dispatch, Manifests, or Readiness to plan outbound work for this order." : "Manifest/readiness links: \(manifests.count + checklists.count).",
            symbol: "shippingbox.and.arrow.backward.fill",
            color: needsDispatchSetup ? .orange : .teal
          )
        }

        CompactActionRow {
          Button("Edit order", systemImage: "pencil") {
            isEditing = true
          }
          .buttonStyle(.bordered)

          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: order)
          }
          .buttonStyle(.bordered)

          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private func checklistLine(title: String, detail: String, symbol: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }

  private func inboxSourceTrail(_ order: TrackedOrder) -> some View {
    let emails = linkedIntakeEmails(for: order)
    let imports = store.importQueueItems(for: order)
    let acceptance = store.acceptanceRecords(for: order)

    return Panel(title: "Inbox source trail", symbol: "envelope.open.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Trace the local intake, import, and acceptance records that led to this order. Use this before editing operational details or marking the handoff reviewed.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(emails.count) intake emails", color: emails.isEmpty ? .secondary : .teal)
          Badge("\(imports.count) import items", color: imports.isEmpty ? .secondary : .blue)
          Badge("\(acceptance.count) acceptance records", color: acceptance.isEmpty ? .secondary : .purple)
        }

        if emails.isEmpty && imports.isEmpty && acceptance.isEmpty {
          MVPEmptyState(
            title: "No source records matched",
            detail: "This order still looks Inbox-created, but no linked intake, import, or acceptance records matched the current order number.",
            symbol: "tray.and.arrow.down.fill"
          )
        } else {
          ForEach(emails) { email in
            OrderIntakeSourceRow(email: email, store: store)
          }

          if !imports.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Import queue")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ImportQueueContextStrip(items: imports)
            }
          }

          if !acceptance.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Acceptance history")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              AcceptanceHistoryStrip(records: acceptance)
            }
          }
        }
      }
    }
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return Array(
      store.intakeEmails
        .filter { email in
          email.linkedOrderID == order.id
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
        }
        .prefix(5)
    )
  }

  private func isInboxCreatedOrder(_ order: TrackedOrder) -> Bool {
    order.source == .forwardedMailbox
      || order.checkedMailbox == "manual-import"
      || order.latestStatus.localizedCaseInsensitiveContains("import queue")
      || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
      || order.latestStatus.localizedCaseInsensitiveContains("forwarded email")
  }

  @ViewBuilder
  private func orderHeaderButtons(_ order: TrackedOrder) -> some View {
    Button("Edit", systemImage: "pencil") {
      isEditing = true
    }
    .buttonStyle(.bordered)
    Button("Task", systemImage: "checklist") {
      store.createReviewTask(from: order)
    }
    .buttonStyle(.bordered)
    Button("Draft", systemImage: "envelope.open.fill") {
      store.createDraftMessage(from: order)
    }
    .buttonStyle(.bordered)
  }
}

private struct OrderIntakeSourceRow: View {
  var email: ForwardedEmailIntake
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(email.reviewState.color)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(email.subject.isEmpty ? "No subject" : email.subject)
            .font(.callout.weight(.semibold))
            .lineLimit(2)
          Text("\(email.sender) • \(email.receivedDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(email.rawBodyPreview)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        Spacer()
        Badge(email.reviewState.rawValue, color: email.reviewState.color)
      }

      CompactMetadataGrid {
        Label(email.detectedMerchant, systemImage: "storefront.fill")
        Label(email.detectedOrderNumber, systemImage: "number")
        Label(email.detectedTrackingNumber, systemImage: "barcode.viewfinder")
        Label(email.detectedDestinationAddress, systemImage: "mappin.and.ellipse")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      CompactActionRow {
        Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
          store.reprocessIntakeEmail(email)
          feedbackMessage = "Intake email reprocessed."
        }
        .buttonStyle(.bordered)

        Button("Task", systemImage: "checklist") {
          store.createReviewTask(from: email)
          feedbackMessage = "Review task created."
        }
        .buttonStyle(.bordered)

        Button("Draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: email)
          feedbackMessage = "Draft created."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        Text(feedbackMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct OrderEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: TrackedOrder
  var onSave: (TrackedOrder) -> Void

  init(order: TrackedOrder, onSave: @escaping (TrackedOrder) -> Void) {
    self._draft = State(initialValue: order)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Order") {
          TextField("Merchant", text: $draft.store)
          TextField("Order number", text: $draft.orderNumber)
          TextField("Customer/team", text: $draft.customer)
          TextField("Recipient email", text: $draft.recipientEmail)
          TextField("Checked mailbox", text: $draft.checkedMailbox)
        }

        Section("Fulfillment") {
          Picker("Fulfillment method", selection: $draft.fulfillment) {
            Text(FulfillmentMethod.delivery.rawValue).tag(FulfillmentMethod.delivery)
            Text(FulfillmentMethod.clickAndCollect.rawValue).tag(FulfillmentMethod.clickAndCollect)
          }
          TextField(draft.fulfillment == .delivery ? "Carrier" : "Collection point", text: $draft.carrier)
          TextField(draft.fulfillment == .delivery ? "Tracking number" : "Collection reference", text: $draft.trackingNumber)
          TextField(draft.fulfillment == .delivery ? "Destination address" : "Pickup address", text: $draft.destination, axis: .vertical)
            .lineLimit(2...4)
          TextField(draft.fulfillment == .delivery ? "Delivery ETA" : "Pickup window", text: $draft.eta)
        }

        Section("Review") {
          Picker("Status", selection: $draft.status) {
            ForEach(OrderStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
          TextField("Latest status", text: $draft.latestStatus, axis: .vertical)
            .lineLimit(2...4)
        }
      }
      .navigationTitle("Edit order")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 560, minHeight: 620)
      #endif
    }
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
