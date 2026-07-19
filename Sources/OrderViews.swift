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
    store.inboxCreatedOrders
      .map(queueItem)
      .sorted { first, second in
        if first.inboxHandoffPriority == second.inboxHandoffPriority {
          return first.order.orderNumber.localizedCaseInsensitiveCompare(second.order.orderNumber) == .orderedAscending
        }
        return first.inboxHandoffPriority > second.inboxHandoffPriority
      }
      .prefix(4)
      .map { $0 }
  }
  private var wishlistLinkedOrderItems: [OrderQueueItem] {
    store.wishlistLinkedOrders
      .map(queueItem)
      .sorted { first, second in
        if first.wishlistHandoffPriority == second.wishlistHandoffPriority {
          return first.order.orderNumber.localizedCaseInsensitiveCompare(second.order.orderNumber) == .orderedAscending
        }
        return first.wishlistHandoffPriority > second.wishlistHandoffPriority
      }
      .prefix(4)
      .map { $0 }
  }
  private var inboxCreatedOrderCount: Int {
    store.inboxCreatedOrderCount
  }
  private var inboxCreatedOrdersWithSourceTrailCount: Int {
    store.inboxCreatedOrders
      .filter { store.sourceTrailCount(for: $0, includeWishlist: true) > 0 }
      .count
  }
  private var inboxCreatedOrdersMissingSourceTrailCount: Int {
    max(inboxCreatedOrderCount - inboxCreatedOrdersWithSourceTrailCount, 0)
  }
  private var inboxCreatedOrdersActionableCount: Int {
    store.inboxCreatedOrders
      .map(queueItem)
      .filter(\.needsInboxHandoffAction)
      .count
  }
  private var inboxCreatedOrdersNeedingReviewCount: Int {
    store.inboxCreatedOrders.filter { $0.reviewState != .accepted }.count
  }
  private var inboxCreatedOrdersMissingDispatchCount: Int {
    store.inboxCreatedOrders.filter { order in
      [.shipped, .inTransit, .exception].contains(order.status)
        && store.suggestedShipmentManifestRecords(for: order).isEmpty
        && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
    }.count
  }
  private var partialInboxOrderTaskCount: Int {
    store.reviewTasks.filter { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }.count
  }
  private var wishlistLinkedOrderTrackingReviewCount: Int {
    store.wishlistLinkedOrders.filter { order in
      order.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || order.trackingNumber.isPlaceholderValidationValue
        || order.trackingNumber.localizedCaseInsensitiveContains("pending")
    }.count
  }
  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }
  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }
  private var pendingUncertainMailboxCount: Int {
    store.latestMailboxUncertainCount
  }
  private var mailboxFetchedCount: Int {
    store.latestMailboxFetchedCount
  }
  private var mailboxImportedCount: Int {
    store.latestMailboxImportedCount
  }
  private var mailboxFilteredCount: Int {
    store.latestMailboxFilteredCount
  }
  private var mailboxDuplicateCount: Int {
    store.latestMailboxDuplicateCount
  }
  private var mailboxDuplicateRefreshedCount: Int {
    store.latestMailboxDuplicateRefreshedCount
  }
  private var orderMailboxProviderRows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] {
    var rows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] = []

    if let summary = latestSpaceMailSummary {
      let status: String
      let detail: String
      let color: Color
      if summary.importedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Open Inbox and create or link orders from the imported SpaceMail rows."
        color = .green
      } else if summary.totalUncertainCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Review uncertain SpaceMail previews in Mailbox Monitor before expecting Orders to change."
        color = .orange
      } else if summary.duplicateRefreshedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Duplicate SpaceMail refreshed existing Inbox rows. Orders changes after the refreshed row is linked or created as an order."
        color = .green
      } else if summary.duplicateCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "SpaceMail fetched messages already captured locally; Orders changes only if an existing intake row is linked."
        color = .teal
      } else if summary.filteredCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Mixed-mailbox filtering kept non-order SpaceMail out of Inbox and Orders."
        color = .teal
      } else {
        status = summary.primaryOutcomeStatus
        detail = summary.nextAction
        color = .secondary
      }
      rows.append(("SpaceMail", status, detail, "server.rack", color))
    }

    if let summary = latestGmailSummary {
      let status: String
      let detail: String
      let color: Color
      if summary.importedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Open Inbox and create or link orders from the imported Gmail rows."
        color = .green
      } else if summary.totalUncertainCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Review uncertain Gmail previews in Mailbox Monitor before expecting Orders to change."
        color = .orange
      } else if summary.duplicateRefreshedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Duplicate Gmail refreshed existing Inbox rows. Orders changes after the refreshed row is linked or created as an order."
        color = .green
      } else if summary.duplicateCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Gmail fetched messages already captured locally; Orders changes only if an existing intake row is linked."
        color = .teal
      } else if summary.filteredCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Gmail filtering kept non-order mail out of Inbox and Orders."
        color = .teal
      } else {
        status = summary.primaryOutcomeStatus
        detail = summary.nextAction
        color = .secondary
      }
      rows.append(("Gmail", status, detail, "envelope.badge.shield.half.filled", color))
    }

    if let summary = latestMicrosoft365Summary {
      let status: String
      let detail: String
      let color: Color
      if summary.blockedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Outlook/Microsoft Graph needs sign-in, consent, token, or Graph diagnostics review before expecting Orders to change."
        color = .orange
      } else if summary.importedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Open Inbox and create or link orders from the imported Outlook rows."
        color = .green
      } else if summary.duplicateRefreshedCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Duplicate Outlook refreshed existing Inbox rows. Orders changes after the refreshed row is linked or created as an order."
        color = .green
      } else if summary.duplicateCount > 0 {
        status = summary.primaryOutcomeStatus
        detail = "Outlook fetched messages already captured locally; Orders changes only if an existing intake row is linked."
        color = .teal
      } else {
        status = summary.primaryOutcomeStatus
        detail = summary.nextAction
        color = .secondary
      }
      rows.append(("Outlook", status, detail, "mail.stack.fill", color))
    }

    if rows.isEmpty {
      rows.append(("Mailbox", "No refresh yet", "Run a manual refresh for the active mailbox provider, then create or link confirmed order rows from Inbox.", "envelope.badge.fill", .secondary))
    }
    return rows
  }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        orderNextActionPanel
        orderReadinessLadderPanel

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

        inboxCreatedOrderHandoffPanel

        SettingsPanel(title: "Order queue", symbol: "shippingbox.fill") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Prioritized local orders with tracking, task, review, and dispatch signals in one row.")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            filterControls

            if orderItems.isEmpty {
              MVPEmptyState(title: "No orders match this queue", detail: "Clear the status filter or search text, or add a manual order to start the local order workflow.", symbol: "shippingbox.fill", actionTitle: "Add order", action: store.createManualOrderPlaceholder)
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

  private var inboxCreatedOrderHandoffPanel: some View {
    SettingsPanel(title: "Source to Orders handoff", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Orders created or linked from mailbox intake, import queue, or acceptance review appear here. Use this after confirming an Inbox row or Wishlist source is genuinely order-related.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Source orders", "\(inboxCreatedOrderCount)", inboxCreatedOrderCount == 0 ? .secondary : .teal),
          ("Source trail", "\(inboxCreatedOrdersWithSourceTrailCount)", inboxCreatedOrdersMissingSourceTrailCount == 0 ? .green : .orange),
          ("Actionable", "\(inboxCreatedOrdersActionableCount)", inboxCreatedOrdersActionableCount == 0 ? .green : .orange),
          ("From Wishlist", "\(store.wishlistLinkedOrderCount)", store.wishlistLinkedOrderCount == 0 ? .secondary : .pink),
          ("Wishlist tracking", "\(wishlistLinkedOrderTrackingReviewCount)", wishlistLinkedOrderTrackingReviewCount == 0 ? .green : .orange),
          ("Wishlist dispatch", "\(store.wishlistLinkedOrderDispatchGapItemCount)", store.wishlistLinkedOrderDispatchGapItemCount == 0 ? .green : .purple),
          ("Mail fetched", "\(mailboxFetchedCount)", mailboxFetchedCount == 0 ? .secondary : .blue),
          ("Mail imported", "\(mailboxImportedCount)", mailboxImportedCount == 0 ? .secondary : .green),
          ("Mail filtered", "\(mailboxFilteredCount)", mailboxFilteredCount == 0 ? .secondary : .teal),
          ("Duplicates", "\(mailboxDuplicateCount)", mailboxDuplicateCount == 0 ? .secondary : .orange),
          ("Refreshed", "\(mailboxDuplicateRefreshedCount)", mailboxDuplicateRefreshedCount == 0 ? .secondary : .green)
        ])

        VStack(alignment: .leading, spacing: 8) {
          Label("Mailbox provider handoff", systemImage: "point.3.connected.trianglepath.dotted")
            .font(.subheadline.weight(.semibold))
          Text("Orders only change after an imported Inbox row or source record is created or linked as an order. Provider rows explain why the latest mailbox refresh did or did not create order work.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(orderMailboxProviderRows, id: \.provider) { row in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: row.symbol)
                .foregroundStyle(row.color)
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                  Text(row.provider)
                    .font(.caption.weight(.semibold))
                  Badge(row.status, color: row.color)
                }
                Text(row.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 0)
            }
          }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

        gmailOrderReadinessPanel

        GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)

        MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)

        if !wishlistLinkedOrderItems.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Wishlist order handoff", systemImage: "star.square.fill")
              .font(.subheadline.weight(.semibold))
            Text("Wishlist-linked orders stay visible here until tracking, source trail, and dispatch setup are locally reviewed.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            ForEach(wishlistLinkedOrderItems) { item in
              OrderWishlistHandoffMiniRow(item: item, store: store)
            }
          }
          .padding(10)
          .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.pink.opacity(0.22)))
        }

        if inboxCreatedOrderItems.isEmpty {
          OrdersInboxHandoffEmptyState(
            fetchedCount: mailboxFetchedCount,
            importedCount: mailboxImportedCount,
            filteredCount: mailboxFilteredCount,
            uncertainCount: pendingUncertainMailboxCount,
            duplicateCount: mailboxDuplicateCount,
            duplicateRefreshedCount: mailboxDuplicateRefreshedCount,
            store: store
          )
        } else {
          Text(inboxCreatedOrdersActionableCount == 0
            ? "Source-created orders are reviewed and have no promoted dispatch setup gap."
            : "The rows below are sorted by handoff risk: review gaps, missing dispatch setup, exceptions, then routine monitoring.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(inboxCreatedOrdersActionableCount == 0 ? .green : .orange)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(inboxCreatedOrderItems) { item in
            OrderQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var gmailOrderReadinessPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      GmailReleaseBoundaryPanel(
        store: store,
        title: "Gmail order readiness",
        lead: "Gmail setup, sign-in, labels, classifier review, Inbox handoff, and audit evidence are provider-readiness work. Orders should only change after a confirmed Inbox row or source record is created or linked as an order.",
        sourceMetricTitle: "Gmail imported",
        sourceCount: latestGmailSummary?.importedCount ?? 0,
        boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create orders automatically, or mutate mailbox messages."
      )
      Microsoft365ReleaseBoundaryPanel(
        store: store,
        title: "Outlook order readiness",
        lead: "Microsoft setup, sign-in, Graph diagnostics, Inbox handoff, and audit evidence are provider-readiness work. Orders should only change after a confirmed Outlook Inbox row or source record is created or linked as an order.",
        sourceMetricTitle: "Outlook imported",
        sourceCount: latestMicrosoft365Summary?.importedCount ?? 0,
        boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, create orders automatically, or mutate mailbox messages."
      )
    }
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
        ("From Inbox", "\(store.inboxCreatedOrderCount)", .purple),
        ("Exceptions", "\(store.orders.filter { $0.status == .exception }.count)", .red),
        ("Delivered", "\(store.orders.filter { $0.status == .delivered }.count)", .green)
      ])
    }
  }

  private var exceptionOrderCount: Int {
    orderItems.filter { $0.order.status == .exception || $0.criticalTrackingCount > 0 }.count
  }

  private var blockedDispatchOrderCount: Int {
    orderItems.filter { $0.blockedDispatchCount > 0 }.count
  }

  private var reviewOrderCount: Int {
    orderItems.filter { $0.order.reviewState != .accepted }.count
  }

  private var trackingWarningOrderCount: Int {
    orderItems.filter { $0.warningTrackingCount > 0 }.count
  }

  private var urgentTaskOrderCount: Int {
    orderItems.filter { $0.urgentTaskCount > 0 }.count
  }

  private var activeOrderCount: Int {
    orderItems.filter { $0.order.status != .delivered }.count
  }

  private var orderNextActionTone: Color {
    if exceptionOrderCount > 0 || blockedDispatchOrderCount > 0 { return .red }
    if inboxCreatedOrderItems.count > 0 || urgentTaskOrderCount > 0 || reviewOrderCount > 0 { return .orange }
    if trackingWarningOrderCount > 0 { return .purple }
    if activeOrderCount > 0 { return .teal }
    return .green
  }

  private var orderNextActionTitle: String {
    if exceptionOrderCount > 0 { return "Start with exception orders" }
    if blockedDispatchOrderCount > 0 { return "Clear blocked dispatch setup" }
    if inboxCreatedOrderItems.count > 0 { return "Confirm Inbox-created orders" }
    if urgentTaskOrderCount > 0 { return "Resolve linked order tasks" }
    if reviewOrderCount > 0 { return "Review order details" }
    if trackingWarningOrderCount > 0 { return "Check tracking warnings" }
    if activeOrderCount > 0 { return "Monitor active orders" }
    return "Order queue is clear"
  }

  private var orderNextActionDetail: String {
    if exceptionOrderCount > 0 {
      return "\(exceptionOrderCount) order has exception or critical tracking context. Open the first row, create a task or draft, and mark reviewed once the response path is clear."
    }
    if blockedDispatchOrderCount > 0 {
      return "\(blockedDispatchOrderCount) order has blocked dispatch context. Open the order or Dispatch to fix manifest/readiness setup."
    }
    if inboxCreatedOrderItems.count > 0 {
      return "\(inboxCreatedOrderItems.count) recently created source order needs operator confirmation. Check customer, destination, tracking, and dispatch setup."
    }
    if urgentTaskOrderCount > 0 {
      return "\(urgentTaskOrderCount) order has overdue or high-priority linked task work. Resolve the task before routine monitoring."
    }
    if reviewOrderCount > 0 {
      return "\(reviewOrderCount) order still needs local review. Open the row, verify detected details, then mark reviewed."
    }
    if trackingWarningOrderCount > 0 {
      return "\(trackingWarningOrderCount) order has tracking warnings. Check tracking context before changing operational status."
    }
    if activeOrderCount > 0 {
      return "\(activeOrderCount) active order is in the queue with no critical blockers promoted above it."
    }
    return "There are no active, review-needed, exception, or tracking-warning orders in the current queue."
  }

  private var orderReadinessItems: [(title: String, detail: String, count: Int, destination: String, symbol: String, color: Color)] {
    let sourceTrailMissing = orderItems.filter { $0.isInboxCreated && $0.sourceTrailCount == 0 }.count
    let detectedFieldMissing = orderItems.filter { $0.missingDetectedFieldCount > 0 }.count
    let reviewNeeded = orderItems.filter { $0.order.reviewState != .accepted }.count
    let linkedTaskWork = orderItems.filter { $0.urgentTaskCount > 0 || $0.partialInboxTaskCount > 0 }.count
    let dispatchSetupMissing = orderItems.filter(\.needsDispatchSetup).count
    let auditTrailCount = store.auditEvents.filter { event in
      event.entityType == .order
        || event.summary.localizedCaseInsensitiveContains("order")
        || event.summary.localizedCaseInsensitiveContains("Inbox-created")
        || event.afterDetail?.localizedCaseInsensitiveContains("Inbox") == true
    }.count

    return [
      (
        "Source trail",
        "Source-created orders should link back to intake, import, acceptance, or Wishlist evidence before handoff is closed.",
        sourceTrailMissing,
        "Inbox or order detail",
        "tray.and.arrow.down.fill",
        sourceTrailMissing == 0 ? .green : .orange
      ),
      (
        "Detected fields",
        "Order number, tracking, and destination should be confirmed before dispatch setup or review closure.",
        detectedFieldMissing,
        "Order detail",
        "number.square.fill",
        detectedFieldMissing == 0 ? .green : .orange
      ),
      (
        "Local review",
        "Rows stay promoted until customer, destination, status, tracking, and linked context are reviewed locally.",
        reviewNeeded,
        "Orders",
        "checkmark.shield.fill",
        reviewNeeded == 0 ? .green : .purple
      ),
      (
        "Linked work",
        "Open verification, overdue, or high-priority tasks should be completed before routine monitoring.",
        linkedTaskWork,
        "Tasks",
        "checklist",
        linkedTaskWork == 0 ? .green : .orange
      ),
      (
        "Dispatch setup",
        "Shipped, in-transit, or exception orders need manifest/readiness context before dispatch can be treated as ready.",
        dispatchSetupMissing,
        "Dispatch",
        "paperplane.fill",
        dispatchSetupMissing == 0 ? .green : .blue
      ),
      (
        "Audit trail",
        "Audit confirms local create, link, review, task, draft, and dispatch handoff actions.",
        auditTrailCount,
        "Audit",
        "list.clipboard.fill",
        auditTrailCount == 0 ? .secondary : .teal
      )
    ]
  }

  private var orderReadinessLadderPanel: some View {
    SettingsPanel(title: "Order readiness ladder", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this to decide why an order is still visible in the primary queue. It reads existing local records only and does not create or change order data.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 215), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(orderReadinessItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge("\(item.count)", color: item.color)
              }
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text("Check \(item.destination)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
  }

  private var orderNextActionPanel: some View {
    SettingsPanel(title: "Order next action", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: orderNextActionTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(orderNextActionTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(orderNextActionTitle)
              .font(.headline)
            Text(orderNextActionDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        MetricStrip(items: [
          ("Exceptions", "\(exceptionOrderCount)", exceptionOrderCount == 0 ? .green : .red),
          ("Blocked dispatch", "\(blockedDispatchOrderCount)", blockedDispatchOrderCount == 0 ? .green : .red),
          ("From Inbox", "\(inboxCreatedOrderItems.count)", inboxCreatedOrderItems.isEmpty ? .green : .teal),
          ("Source trail", "\(inboxCreatedOrdersWithSourceTrailCount)", inboxCreatedOrdersMissingSourceTrailCount == 0 ? .green : .orange),
          ("Partial", "\(partialInboxOrderTaskCount)", partialInboxOrderTaskCount == 0 ? .green : .orange),
          ("Linked tasks", "\(urgentTaskOrderCount)", urgentTaskOrderCount == 0 ? .green : .orange),
          ("Needs review", "\(reviewOrderCount)", reviewOrderCount == 0 ? .green : .purple)
        ])

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var filterControls: some View {
    @Bindable var store = store

    return FilterControlGrid {
      TextField("Search orders, customers, tracking, carrier, or destination", text: $store.searchText)
        .textFieldStyle(.roundedBorder)

      if isCompact {
        statusPicker
          .pickerStyle(.menu)
      } else {
        statusPicker
          .pickerStyle(.segmented)
      }

      Button("Clear", systemImage: "xmark.circle") {
        store.searchText = ""
        store.selectedStatus = nil
      }
      .buttonStyle(.bordered)
      .disabled(store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.selectedStatus == nil)

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
    let wishlistItems = store.activeWishlistItemsLinked(to: order)
    let wishlistDispatchGaps = Array(Set(wishlistItems.flatMap { item in
      store.wishlistLinkedOrderDispatchGaps(for: item)
    })).sorted()

    return OrderQueueItem(
      order: order,
      trackingEvents: store.trackingEvents(for: order.id),
      tasks: store.tasks(for: .order, linkedEntityID: order.id.uuidString),
      manifests: store.suggestedShipmentManifestRecords(for: order),
      checklists: store.suggestedDispatchReadinessChecklists(for: order),
      sourceTrailCount: store.sourceTrailCount(for: order, includeWishlist: true),
      mailboxSourceSummaries: store.mailboxSourceSummaries(for: order),
      wishlistItems: wishlistItems,
      wishlistDispatchGaps: wishlistDispatchGaps
    )
  }



}

private struct OrderWishlistSourceRow: View {
  var item: WishlistItem
  var store: ParcelOpsStore
  var onTask: () -> Void
  var onDraft: () -> Void
  var onFeedback: (String) -> Void

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  private var hasLinkedOrder: Bool {
    handoff?.linkedOrderID != nil
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "star.square.fill")
        .foregroundStyle(.pink)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
        Text("\(handoff?.sellerName ?? item.storefront) • \(handoff?.purchaseStatus ?? item.status)")
          .font(.caption2)
          .foregroundStyle(.secondary)
        if let handoff {
          Text("Order link: \(handoff.orderWatchStatus)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if hasLinkedOrder {
          wishlistDispatchStatus
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 6) {
        Badge("Wishlist", color: .pink)
        HStack(spacing: 6) {
          Button("Task", systemImage: "checklist", action: onTask)
            .labelStyle(.iconOnly)
            .help("Create Wishlist follow-up task")
          Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
            .labelStyle(.iconOnly)
            .help("Create Wishlist review draft")
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistDispatchStatus: some View {
    let summary = store.wishlistOrderDetailDispatchSummary(for: item)

    VStack(alignment: .leading, spacing: 5) {
      Text(summary.title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(wishlistDispatchStatusColor(summary.tone))
        .fixedSize(horizontal: false, vertical: true)
      Text(summary.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if summary.missingManifest || summary.missingReadiness {
        CompactActionRow {
          if summary.missingManifest {
            Button("Stage manifest", systemImage: "list.bullet.clipboard.fill") {
              store.createWishlistShipmentManifest(item)
              onFeedback("Wishlist dispatch manifest staged locally from order detail. No retailer, payment, carrier, mailbox, or external service was contacted.")
            }
          }
          if summary.missingReadiness {
            Button("Stage readiness", systemImage: "checkmark.rectangle.stack.fill") {
              store.createWishlistDispatchReadinessChecklist(item)
              onFeedback("Wishlist dispatch readiness checklist staged locally from order detail. Check Dispatch for the outbound queue.")
            }
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.top, 2)
  }

  private func wishlistDispatchStatusColor(_ tone: String) -> Color {
    switch tone {
    case "warning": return .orange
    case "success": return .green
    default: return .secondary
    }
  }
}

private struct OrderClosedWishlistSourceRow: View {
  var item: WishlistItem

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "archivebox.fill")
        .foregroundStyle(.secondary)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
        Text("\(handoff?.sellerName ?? item.storefront) • \(handoff?.purchaseStatus ?? item.status)")
          .font(.caption2)
          .foregroundStyle(.secondary)
        if let handoff {
          Text("Historical order link: \(handoff.orderWatchStatus)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Closed Wishlist link retained for provenance only. It is not counted as active order follow-up.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      Badge("Closed history", color: .secondary)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderWishlistHandoffMiniRow: View {
  var item: OrderQueueItem
  var store: ParcelOpsStore

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.needsWishlistTrackingReview ? "barcode.viewfinder" : "star.square.fill")
        .foregroundStyle(item.handoffDecisionColor)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text("\(item.order.store) • \(item.order.orderNumber)")
              .font(.caption.weight(.semibold))
            Text("\(item.wishlistItems.count) linked Wishlist item\(item.wishlistItems.count == 1 ? "" : "s")")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          Badge(item.handoffDecisionBadge, color: item.handoffDecisionColor)
        }

        CompactMetadataGrid {
          Badge(item.order.status.rawValue, color: item.order.status.color)
          Badge(item.order.reviewState.rawValue, color: item.order.reviewState.color)
          Badge(item.needsWishlistTrackingReview ? "Tracking review" : "Tracking present", color: item.needsWishlistTrackingReview ? .orange : .green)
          if item.wishlistDispatchGaps.isEmpty {
            Badge("Dispatch context ok", color: .green)
          } else {
            Badge("\(item.wishlistDispatchGaps.count) dispatch gap\(item.wishlistDispatchGaps.count == 1 ? "" : "s")", color: .purple)
          }
          Badge(item.sourceTrailCount > 0 ? "\(item.sourceTrailCount) source" : "Source missing", color: item.sourceTrailCount > 0 ? .green : .orange)
        }

        Text(item.handoffDecisionDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            OrderDetailView(order: item.order, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.right.circle.fill")
          }

          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Open Wishlist", systemImage: "star.square.fill")
          }

          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct OrdersInboxHandoffEmptyState: View {
  var fetchedCount: Int
  var importedCount: Int
  var filteredCount: Int
  var uncertainCount: Int
  var duplicateCount: Int
  var duplicateRefreshedCount: Int
  var store: ParcelOpsStore

  private var title: String {
    if importedCount > 0 { return "Imported intake is waiting in Inbox" }
    if uncertainCount > 0 { return "Uncertain mailbox mail needs review" }
    if duplicateRefreshedCount > 0 { return "Existing Inbox rows were refreshed" }
    if duplicateCount > 0 { return "No new mailbox order handoff" }
    if filteredCount > 0 { return "No order mail reached Orders" }
    if fetchedCount > 0 { return "Mailbox refresh found no order handoff" }
    return "No Inbox-created orders yet"
  }

  private var detail: String {
    if importedCount > 0 {
      return "A mailbox refresh imported likely order mail, but no order has been created or linked yet. Open Inbox, verify the row, then use Create order or Link order."
    }
    if uncertainCount > 0 {
      return "Mixed-mailbox filtering held possible order mail out of Inbox. Open Mailbox Monitor and import only true order updates."
    }
    if duplicateRefreshedCount > 0 {
      return "The latest mailbox refresh updated existing Inbox rows without creating duplicates. Open Inbox and link the refreshed row to an order if it is ready."
    }
    if duplicateCount > 0 {
      return "The latest mailbox refresh found messages ParcelOps already captured or reviewed. Orders stays unchanged unless a new intake row is imported or an existing row is linked."
    }
    if filteredCount > 0 {
      return "The latest mailbox refresh mostly filtered non-order mail. Orders stays empty until a confirmed order/tracking message is imported or manually added."
    }
    if fetchedCount > 0 {
      return "A manual mailbox refresh ran, but it did not produce an Inbox order handoff. Send or forward a clear order/tracking test email when testing this path."
    }
    return "Run a manual refresh for the active mailbox provider, or import an intake row first, then create/link an order from Inbox."
  }

  private var color: Color {
    if importedCount > 0 || uncertainCount > 0 { return .orange }
    if duplicateRefreshedCount > 0 { return .green }
    if duplicateCount > 0 { return .teal }
    if filteredCount > 0 || fetchedCount > 0 { return .teal }
    return .secondary
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: importedCount > 0 ? "tray.full.fill" : "shippingbox")
          .foregroundStyle(color)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge(importedCount > 0 || uncertainCount > 0 ? "Action" : "Waiting", color: color)
      }

      CompactActionRow {
        NavigationLink {
          InboxView(store: store)
        } label: {
          Label("Open Inbox", systemImage: "tray.full.fill")
        }

        NavigationLink {
          MailboxView(store: store)
        } label: {
          Label("Open Mailbox Monitor", systemImage: "server.rack")
        }

        Button("Add manual order", systemImage: "plus") {
          store.createManualOrderPlaceholder()
        }
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderQueueItem: Identifiable {
  var order: TrackedOrder
  var trackingEvents: [CarrierTrackingEvent]
  var tasks: [ReviewTask]
  var manifests: [ShipmentManifestRecord]
  var checklists: [DispatchReadinessChecklist]
  var sourceTrailCount: Int
  var mailboxSourceSummaries: [OrderMailboxSourceSummary]
  var wishlistItems: [WishlistItem]
  var wishlistDispatchGaps: [String]

  var id: UUID { order.id }
  var isWishlistLinked: Bool {
    !wishlistItems.isEmpty
  }
  var needsWishlistTrackingReview: Bool {
    isWishlistLinked
      && (order.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || order.trackingNumber.isPlaceholderValidationValue
        || order.trackingNumber.localizedCaseInsensitiveContains("pending"))
  }
  var wishlistHandoffPriority: Int {
    guard isWishlistLinked else { return 0 }
    if order.status == .exception || criticalTrackingCount > 0 { return 120 }
    if needsWishlistTrackingReview { return 115 }
    if !wishlistDispatchGaps.isEmpty { return 110 }
    if order.reviewState != .accepted { return 100 }
    if urgentTaskCount > 0 { return 90 }
    if warningTrackingCount > 0 { return 80 }
    return 50
  }
  var warningTrackingCount: Int {
    trackingEvents.filter { $0.severity == .watch || $0.severity == .critical }.count
  }
  var criticalTrackingCount: Int {
    trackingEvents.filter { $0.severity == .critical }.count
  }
  var urgentTaskCount: Int {
    tasks.filter { $0.status != .completed && ($0.priority == .urgent || $0.priority == .high || $0.isLocallyOverdue) }.count
  }
  var partialInboxTaskCount: Int {
    tasks.filter { $0.status != .completed && $0.isPartialInboxOrderFollowUp }.count
  }
  var missingDetectedFieldCount: Int {
    [order.orderNumber, order.trackingNumber, order.destination]
      .filter { value in
        value == "Pending" || value == "Pending review" || value.isPlaceholderValidationValue
      }
      .count
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
  var operationalTimelineSignalCount: Int {
    1
      + (isInboxCreated ? 1 : 0)
      + wishlistItems.count
      + wishlistDispatchGaps.count
      + sourceTrailCount
      + tasks.count
      + manifests.count
      + checklists.count
      + warningTrackingCount
  }
  var needsDispatchSetup: Bool {
    dispatchContextCount == 0 && [.shipped, .inTransit, .exception].contains(order.status)
  }
  var needsInboxHandoffAction: Bool {
    isInboxCreated && (partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 || order.reviewState != .accepted || needsDispatchSetup || order.status == .exception || criticalTrackingCount > 0 || urgentTaskCount > 0)
  }
  var inboxHandoffPriority: Int {
    guard isInboxCreated else { return 0 }
    if order.status == .exception || criticalTrackingCount > 0 { return 120 }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 { return 115 }
    if order.reviewState != .accepted { return 110 }
    if needsDispatchSetup { return 100 }
    if urgentTaskCount > 0 { return 90 }
    if warningTrackingCount > 0 { return 80 }
    if order.status == .delivered { return 10 }
    return 50
  }
  var isInboxCreated: Bool {
    order.source == .forwardedMailbox
      || order.checkedMailbox == "manual-import"
      || order.latestStatus.localizedCaseInsensitiveContains("import queue")
      || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
  }
  var inboxHandoffLabel: String {
    if isWishlistLinked && !isInboxCreated { return "Wishlist-linked order" }
    if order.source == .forwardedMailbox { return "Mailbox-created order" }
    if order.latestStatus.localizedCaseInsensitiveContains("acceptance") { return "Acceptance-created order" }
    if order.latestStatus.localizedCaseInsensitiveContains("import queue") || order.checkedMailbox == "manual-import" { return "Import-created order" }
    return "Source handoff"
  }
  var inboxHandoffDetail: String {
    if partialInboxTaskCount > 0 {
      return "A verification task is open for missing order, tracking, or destination details."
    }
    if missingDetectedFieldCount > 0 {
      return "Detected order details are incomplete. Open the order and confirm missing values."
    }
    if sourceTrailCount == 0 {
      return "No intake, import, acceptance, or Wishlist purchase source trail is linked yet. Confirm where this order came from before closing the handoff."
    }
    if order.reviewState != .accepted {
      return "Confirm customer, destination, tracking, and dispatch setup before marking reviewed."
    }
    if needsDispatchSetup {
      return "Order is reviewed, but dispatch context is not linked yet."
    }
    return "Source handoff is reviewed; keep monitoring status and linked tasks."
  }
  var operationalTimelineDetail: String {
    if operationalTimelineSignalCount <= 1 {
      return "Open detail for the base order status timeline."
    }
    if blockedDispatchCount > 0 {
      return "Operational timeline includes blocked dispatch context."
    }
    if isInboxCreated && dispatchContextCount > 0 {
      return "Operational timeline links Inbox handoff, order detail, and dispatch setup."
    }
    if isInboxCreated {
      return "Operational timeline links Inbox handoff and order detail."
    }
    if urgentTaskCount > 0 {
      return "Operational timeline includes follow-up task work."
    }
    if warningTrackingCount > 0 {
      return "Operational timeline includes tracking warnings."
    }
    return "Operational timeline has linked local context."
  }
  var riskLabel: String {
    if order.status == .exception || criticalTrackingCount > 0 || blockedDispatchCount > 0 {
      "High risk"
    } else if needsWishlistTrackingReview || !wishlistDispatchGaps.isEmpty || warningTrackingCount > 0 || urgentTaskCount > 0 || order.reviewState != .accepted {
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
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 {
      "Verify missing intake details"
    } else if needsWishlistTrackingReview {
      "Confirm Wishlist tracking"
    } else if !wishlistDispatchGaps.isEmpty {
      "Stage Wishlist dispatch setup"
    } else if order.reviewState != .accepted {
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
  var handoffDecisionTitle: String {
    if isWishlistLinked && needsWishlistTrackingReview {
      return "Wishlist order needs tracking"
    }
    if isWishlistLinked && !wishlistDispatchGaps.isEmpty {
      return "Wishlist dispatch setup is next"
    }
    if !isInboxCreated {
      return riskLabel == "High risk" ? "Resolve order risk" : "Continue normal order monitoring"
    }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 {
      return "Inbox handoff is not complete"
    }
    if sourceTrailCount == 0 {
      return "Source trail needs confirmation"
    }
    if order.reviewState != .accepted {
      return "Order needs local review"
    }
    if needsDispatchSetup {
      return "Dispatch setup is next"
    }
    if order.status == .exception || criticalTrackingCount > 0 {
      return "Exception follow-up is needed"
    }
    return "Inbox handoff is ready"
  }
  var handoffDecisionDetail: String {
    if isWishlistLinked && needsWishlistTrackingReview {
      return "\(wishlistItems.count) Wishlist item\(wishlistItems.count == 1 ? "" : "s") linked to this order. Confirm the tracking number before treating the purchase handoff as ready."
    }
    if isWishlistLinked && !wishlistDispatchGaps.isEmpty {
      return "Linked Wishlist purchase has dispatch setup gaps: \(wishlistDispatchGaps.prefix(2).joined(separator: ", "))."
    }
    if !isInboxCreated {
      if urgentTaskCount > 0 {
        return "\(urgentTaskCount) urgent or overdue order task needs action before routine monitoring."
      }
      if warningTrackingCount > 0 {
        return "\(warningTrackingCount) tracking warning should be checked from the order detail or Tracking screen."
      }
      return "This order is not marked as source-created. Use the normal status, tracking, task, and dispatch context to decide the next step."
    }
    if partialInboxTaskCount > 0 {
      return "\(partialInboxTaskCount) verification task is open for missing intake details. Resolve it after order number, tracking, and destination are confirmed."
    }
    if missingDetectedFieldCount > 0 {
      return "\(missingDetectedFieldCount) key intake field is still missing or placeholder text. Edit the order before dispatch setup."
    }
    if sourceTrailCount == 0 {
      return "No linked intake, import, acceptance, or Wishlist purchase source matched this order yet. Confirm the source trail before marking the handoff reviewed."
    }
    if order.reviewState != .accepted {
      return "Customer, destination, tracking, and source trail are present enough for a local review decision."
    }
    if needsDispatchSetup {
      return "The order is reviewed and has no manifest/readiness context yet. Create or open dispatch setup when it is ready to move."
    }
    if order.status == .exception || criticalTrackingCount > 0 {
      return "Create a follow-up task or inspect tracking before moving this order forward."
    }
    return "Source trail and review state are clear. Continue monitoring dispatch, tracking, and linked tasks."
  }
  var handoffDecisionBadge: String {
    if isWishlistLinked && needsWishlistTrackingReview { return "Wishlist tracking" }
    if isWishlistLinked && !wishlistDispatchGaps.isEmpty { return "Wishlist dispatch" }
    if !isInboxCreated { return riskLabel }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 { return "Verify" }
    if sourceTrailCount == 0 { return "Trace" }
    if order.reviewState != .accepted { return "Review" }
    if needsDispatchSetup { return "Dispatch" }
    if order.status == .exception || criticalTrackingCount > 0 { return "Exception" }
    return "Ready"
  }
  var handoffDecisionColor: Color {
    if isWishlistLinked && needsWishlistTrackingReview { return .orange }
    if isWishlistLinked && !wishlistDispatchGaps.isEmpty { return .purple }
    if !isInboxCreated { return riskColor }
    if order.status == .exception || criticalTrackingCount > 0 { return .red }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 || sourceTrailCount == 0 || order.reviewState != .accepted { return .orange }
    if needsDispatchSetup { return .purple }
    return .green
  }
  var handoffDecisionSymbol: String {
    if isWishlistLinked && needsWishlistTrackingReview { return "barcode.viewfinder" }
    if isWishlistLinked && !wishlistDispatchGaps.isEmpty { return "paperplane.fill" }
    if !isInboxCreated { return order.status == .exception ? "exclamationmark.triangle.fill" : "shippingbox.fill" }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 { return "checklist.unchecked" }
    if sourceTrailCount == 0 { return "link.badge.plus" }
    if order.reviewState != .accepted { return "checkmark.shield.fill" }
    if needsDispatchSetup { return "paperplane.fill" }
    if order.status == .exception || criticalTrackingCount > 0 { return "exclamationmark.triangle.fill" }
    return "checkmark.seal.fill"
  }
  var sortPriority: Int {
    if order.status == .exception { return 120 }
    if criticalTrackingCount > 0 { return 110 }
    if blockedDispatchCount > 0 { return 105 }
    if partialInboxTaskCount > 0 || missingDetectedFieldCount > 0 { return 100 }
    if needsWishlistTrackingReview || !wishlistDispatchGaps.isEmpty { return 98 }
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
  @State private var feedbackMessage: String?

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
            if item.isInboxCreated {
              Badge(item.inboxHandoffLabel, color: .teal)
              Badge(item.sourceTrailCount > 0 ? "\(item.sourceTrailCount) source" : "Source trail missing", color: item.sourceTrailCount > 0 ? .green : .orange)
              ForEach(item.mailboxSourceSummaries.prefix(2)) { source in
                Badge(source.badgeLabel, color: mailboxSourceColor(source))
              }
            }
            if item.isWishlistLinked {
              Badge("\(item.wishlistItems.count) Wishlist", color: .pink)
              if item.needsWishlistTrackingReview {
                Badge("Wishlist tracking", color: .orange)
              }
              if !item.wishlistDispatchGaps.isEmpty {
                Badge("\(item.wishlistDispatchGaps.count) Wishlist dispatch", color: .purple)
              }
            }
            if item.partialInboxTaskCount > 0 {
              Badge("\(item.partialInboxTaskCount) verify", color: .orange)
            }
            if item.missingDetectedFieldCount > 0 {
              Badge("\(item.missingDetectedFieldCount) missing", color: .orange)
            }
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
            if item.operationalTimelineSignalCount > 1 {
              Badge("\(item.operationalTimelineSignalCount) timeline", color: item.blockedDispatchCount > 0 ? .red : .blue)
            }
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption)
            .foregroundStyle(item.riskColor)

          if item.isInboxCreated {
            Label(item.inboxHandoffDetail, systemImage: "tray.and.arrow.down.fill")
              .font(.caption)
              .foregroundStyle(.teal)
              .fixedSize(horizontal: false, vertical: true)

            if item.sourceTrailCount == 0 {
              Label("Open order source trail before completing this Inbox handoff.", systemImage: "link.badge.plus")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            } else if !item.mailboxSourceSummaries.isEmpty {
              Label(mailboxSourceTraceText(item.mailboxSourceSummaries), systemImage: "envelope.badge.fill")
                .font(.caption)
                .foregroundStyle(.teal)
                .fixedSize(horizontal: false, vertical: true)
            }

            if item.isWishlistLinked {
              Label(wishlistSourceTraceText(item), systemImage: "star.square.fill")
                .font(.caption)
                .foregroundStyle(item.needsWishlistTrackingReview || !item.wishlistDispatchGaps.isEmpty ? .orange : .pink)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          if item.operationalTimelineSignalCount > 1 {
            Label(item.operationalTimelineDetail, systemImage: "calendar.badge.clock")
              .font(.caption)
              .foregroundStyle(item.blockedDispatchCount > 0 ? .red : .blue)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      orderHandoffDecisionPanel

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: order, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.right.circle.fill")
        }
        .buttonStyle(.bordered)

        Button("Edit", systemImage: "pencil") {
          isEditing = true
        }
        .buttonStyle(.bordered)

        Button("Create task", systemImage: "checklist") {
          store.createReviewTask(from: order)
          feedbackMessage = "Order follow-up task created. Check Tasks."
        }
        .buttonStyle(.bordered)

        Button("Create draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
          feedbackMessage = "Draft message created from order. Check Drafts."
        }
        .buttonStyle(.bordered)

        Button("Mark reviewed", systemImage: "checkmark.shield.fill") {
          var reviewedOrder = order
          reviewedOrder.reviewState = .accepted
          store.updateOrder(reviewedOrder)
          feedbackMessage = "Order marked reviewed locally."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
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

  private var orderHandoffDecisionPanel: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.handoffDecisionSymbol)
        .foregroundStyle(item.handoffDecisionColor)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.handoffDecisionTitle)
          .font(.caption.weight(.semibold))
        Text(item.handoffDecisionDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)
      Badge(item.handoffDecisionBadge, color: item.handoffDecisionColor)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(item.handoffDecisionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func mailboxSourceTraceText(_ summaries: [OrderMailboxSourceSummary]) -> String {
    summaries.prefix(2)
      .map { "\($0.providerName) via \($0.mailboxLabel)" }
      .joined(separator: "; ")
  }

  private func wishlistSourceTraceText(_ item: OrderQueueItem) -> String {
    if item.needsWishlistTrackingReview {
      return "Wishlist purchase is linked; confirm tracking before dispatch handoff."
    }
    if !item.wishlistDispatchGaps.isEmpty {
      return "Wishlist dispatch setup gaps: \(item.wishlistDispatchGaps.prefix(2).joined(separator: ", "))."
    }
    return "Wishlist purchase source is linked to this order."
  }

  private func mailboxSourceColor(_ summary: OrderMailboxSourceSummary) -> Color {
    if summary.importedCount > 0 { return .green }
    if summary.duplicateRefreshedCount > 0 { return .teal }
    if summary.duplicateCount > 0 { return .orange }
    switch summary.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
    }
  }
}

private struct OrderActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        if message.localizedCaseInsensitiveContains("task") {
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        if message.localizedCaseInsensitiveContains("draft") {
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
        }
        if message.localizedCaseInsensitiveContains("dispatch") || message.localizedCaseInsensitiveContains("handoff") || message.localizedCaseInsensitiveContains("readiness") || message.localizedCaseInsensitiveContains("manifest") {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
        }
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct OrderDetailView: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var isEditing = false
  @State private var feedbackMessage: String?

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

        if let feedbackMessage {
          OrderActionFeedbackPanel(message: feedbackMessage, store: store)
        }

        if order.isInboxCreatedLocalOrder {
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
              Text("No local accounts matched this order.")
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
            AcceptanceHistoryStrip(records: records, store: store)
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
                TrackingEventRow(event: event, store: store, order: order, suggestedContacts: store.suggestedContacts(for: event), suggestedProfiles: store.suggestedVendorProfiles(for: event), customerProfiles: store.suggestedCustomerProfiles(for: event), destinationAddresses: store.suggestedDestinationAddresses(for: event), deliveryInstructions: store.suggestedDeliveryInstructions(for: event), packageContents: store.suggestedPackageContents(for: event), shipmentGroups: store.suggestedShipmentGroups(for: event)) {
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

        operationalTimelinePanel(order)

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
    let partialInboxTasks = tasks.filter(\.isPartialInboxOrderFollowUp)
    let manifests = store.suggestedShipmentManifestRecords(for: order)
    let checklists = store.suggestedDispatchReadinessChecklists(for: order)
    let missingTracking = order.trackingNumber == "Pending" || order.trackingNumber.isPlaceholderValidationValue
    let missingDestination = order.destination == "Pending review" || order.destination.isPlaceholderValidationValue
    let missingHandoffFields = store.partialInboxOrderMissingFields(for: order)
    let needsDispatchSetup = [.shipped, .inTransit, .exception].contains(order.status) && manifests.isEmpty && checklists.isEmpty
    let canCreateDispatchSetup = needsDispatchSetup && missingHandoffFields.isEmpty

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
            detail: canCreateDispatchSetup
              ? "Create local manifest and readiness records now that Inbox handoff fields are usable."
              : needsDispatchSetup
                ? "Confirm missing handoff details before creating manifest or readiness records."
                : "Manifest/readiness links: \(manifests.count + checklists.count).",
            symbol: "shippingbox.and.arrow.backward.fill",
            color: canCreateDispatchSetup ? .green : needsDispatchSetup ? .orange : .teal
          )
        }

        if !partialInboxTasks.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Partial order follow-up")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)

            ForEach(partialInboxTasks) { task in
              PartialInboxOrderFollowUpRow(task: task, store: store, order: order)
            }
          }
        }

        if !manifests.isEmpty || !checklists.isEmpty {
          OrderDispatchHandoffRows(order: order, manifests: manifests, checklists: checklists, store: store)
        }

        CompactActionRow {
          Button("Edit order", systemImage: "pencil") {
            isEditing = true
          }
          .buttonStyle(.bordered)

          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: order)
            feedbackMessage = "Order handoff task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          if canCreateDispatchSetup {
            Button("Create dispatch setup", systemImage: "shippingbox.and.arrow.backward.fill") {
              store.createDispatchSetup(for: order)
              feedbackMessage = "Dispatch setup created for this order. Check Dispatch."
            }
            .buttonStyle(.borderedProminent)
          }

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

  private func mailboxSourceTraceText(_ summaries: [OrderMailboxSourceSummary]) -> String {
    summaries.prefix(2)
      .map { "\($0.providerName) via \($0.mailboxLabel)" }
      .joined(separator: "; ")
  }

  private func mailboxSourceColor(_ summary: OrderMailboxSourceSummary) -> Color {
    if summary.importedCount > 0 { return .green }
    if summary.duplicateRefreshedCount > 0 { return .teal }
    if summary.duplicateCount > 0 { return .orange }
    switch summary.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
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
    let emails = store.linkedIntakeEmails(for: order)
    let imports = store.importQueueItems(for: order)
    let acceptance = store.acceptanceRecords(for: order)
    let wishlistItems = store.activeWishlistItemsLinked(to: order)
    let closedWishlistItems = store.closedWishlistItemsLinked(to: order)
    let mailboxSources = store.mailboxSourceSummaries(for: order)

    return Panel(title: "Order source trail", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Trace the local intake, import, acceptance, and active Wishlist records that led to this order. Closed Wishlist links are retained as read-only history below so they do not look like active follow-up.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(emails.count) intake emails", color: emails.isEmpty ? .secondary : .teal)
          Badge("\(imports.count) import items", color: imports.isEmpty ? .secondary : .blue)
          Badge("\(acceptance.count) acceptance records", color: acceptance.isEmpty ? .secondary : .purple)
          Badge("\(wishlistItems.count) active wishlist", color: wishlistItems.isEmpty ? .secondary : .pink)
          if !closedWishlistItems.isEmpty {
            Badge("\(closedWishlistItems.count) closed history", color: .secondary)
          }
        }

        if !mailboxSources.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Mailbox provider sources")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(mailboxSources) { source in
              OrderMailboxSourceSummaryRow(source: source)
            }
          }
        }

        if emails.isEmpty && imports.isEmpty && acceptance.isEmpty && wishlistItems.isEmpty && closedWishlistItems.isEmpty {
          MVPEmptyState(
            title: "No source records matched",
            detail: "This order still looks Inbox-created, but no linked intake, import, acceptance, or Wishlist handoff records matched the current order number.",
            symbol: "tray.and.arrow.down.fill"
          )
        } else {
          if !wishlistItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Wishlist handoff")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(wishlistItems) { item in
                OrderWishlistSourceRow(item: item, store: store) {
                  store.createReviewTask(from: item)
                  feedbackMessage = "Wishlist follow-up task created locally from order source trail. No retailer, payment, browser, mailbox, or external service was contacted."
                } onDraft: {
                  store.createDraftMessage(from: item)
                  feedbackMessage = "Wishlist review draft created locally from order source trail. No message was sent."
                } onFeedback: { message in
                  feedbackMessage = message
                }
              }
            }
          }

          if !closedWishlistItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Closed Wishlist history")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(closedWishlistItems) { item in
                OrderClosedWishlistSourceRow(item: item)
              }
            }
          }

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
              AcceptanceHistoryStrip(records: acceptance, store: store)
            }
          }
        }
      }
    }
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    return Array(
      store.linkedIntakeEmails(for: order)
        .prefix(5)
    )
  }

  private func operationalTimelinePanel(_ order: TrackedOrder) -> some View {
    let activities = orderOperationalTimelineActivities(for: order)

    return Panel(title: "Operational timeline", symbol: "calendar.badge.clock") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Local activity linked to this order across Inbox intake, import, acceptance, dispatch setup, readiness, and follow-up tasks.")
          .font(.callout)
          .foregroundStyle(.secondary)

        if activities.isEmpty {
          MVPEmptyState(
            title: "No linked operational timeline yet",
            detail: "Create or link intake, dispatch, readiness, or task records and they will appear here without calling external services.",
            symbol: "calendar.badge.clock"
          )
        } else {
          MetricStrip(items: [
            ("Events", "\(activities.count)", .blue),
            ("Dispatch", "\(activities.filter { $0.entityType == .shipmentManifest || $0.entityType == .dispatchChecklist }.count)", .purple),
            ("Tasks", "\(activities.filter { $0.entityType == .reviewTask }.count)", .orange),
            ("Inbox", "\(activities.filter { $0.entityType == .intakeEmail || $0.entityType == .importQueueItem || $0.entityType == .acceptanceRecord }.count)", .teal)
          ])

          VStack(spacing: 8) {
            ForEach(activities) { activity in
              OrderOperationalTimelineRow(activity: activity, store: store)
            }
          }

          NavigationLink {
            TimelineView(store: store)
          } label: {
            Label("Open full timeline", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private func orderOperationalTimelineActivities(for order: TrackedOrder) -> [TimelineActivity] {
    let orderID = order.id.uuidString
    let intakeIDs = Set(store.linkedIntakeEmails(for: order).map { $0.id.uuidString })
    let importIDs = Set(store.importQueueItems(for: order).map { $0.id.uuidString })
    let acceptanceIDs = Set(store.acceptanceRecords(for: order).map { $0.id.uuidString })
    let taskIDs = Set(store.tasks(for: .order, linkedEntityID: orderID).map { $0.id.uuidString })
    let manifestIDs = Set(store.suggestedShipmentManifestRecords(for: order).map { $0.id.uuidString })
    let checklistIDs = Set(store.suggestedDispatchReadinessChecklists(for: order).map { $0.id.uuidString })

    return Array(
      store.timelineActivities
        .filter { activity in
          switch activity.entityType {
          case .order:
            return activity.entityID == orderID
          case .intakeEmail:
            return intakeIDs.contains(activity.entityID)
          case .importQueueItem:
            return importIDs.contains(activity.entityID)
          case .acceptanceRecord:
            return acceptanceIDs.contains(activity.entityID)
          case .reviewTask:
            return taskIDs.contains(activity.entityID)
          case .shipmentManifest:
            return manifestIDs.contains(activity.entityID)
          case .dispatchChecklist:
            return checklistIDs.contains(activity.entityID)
          default:
            return false
          }
        }
        .prefix(8)
    )
  }

  @ViewBuilder
  private func orderHeaderButtons(_ order: TrackedOrder) -> some View {
    Button("Edit", systemImage: "pencil") {
      isEditing = true
    }
    .buttonStyle(.bordered)
    Button("Task", systemImage: "checklist") {
      store.createReviewTask(from: order)
      feedbackMessage = "Order follow-up task created. Check Tasks."
    }
    .buttonStyle(.bordered)
    Button("Draft", systemImage: "envelope.open.fill") {
      store.createDraftMessage(from: order)
      feedbackMessage = "Draft message created from order. Check Drafts."
    }
    .buttonStyle(.bordered)
  }
}

private struct PartialInboxOrderFollowUpRow: View {
  var task: ReviewTask
  var store: ParcelOpsStore
  var order: TrackedOrder
  @State private var feedbackMessage: String?

  private var missingTracking: Bool {
    order.trackingNumber == "Pending" || order.trackingNumber.isPlaceholderValidationValue
  }

  private var missingDestination: Bool {
    order.destination == "Pending review" || order.destination.isPlaceholderValidationValue
  }

  private var missingFields: [String] {
    store.partialInboxOrderMissingFields(for: order)
  }

  private var canResolveFollowUp: Bool {
    task.status != .completed && missingFields.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(task.title)
            .font(.callout.weight(.semibold))
          Text("Confirm \(task.partialInboxMissingSummary) before dispatch setup.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()
        Badge(task.status.rawValue, color: task.status.color)
      }

      CompactMetadataGrid(minimumWidth: 135) {
        Badge(missingTracking ? "Tracking needs check" : "Tracking present", color: missingTracking ? .orange : .green)
        Badge(missingDestination ? "Destination needs check" : "Destination present", color: missingDestination ? .orange : .green)
        if canResolveFollowUp {
          Badge("Ready to close", color: .green)
        } else if !missingFields.isEmpty {
          Badge("Missing \(missingFields.joined(separator: ", "))", color: .orange)
        }
        Badge(task.priority.rawValue, color: task.priority.color)
        Badge(task.reviewState.rawValue, color: task.reviewState.color)
      }

      if !missingFields.isEmpty {
        Label("Edit the order first. Still missing: \(missingFields.joined(separator: ", ")).", systemImage: "pencil.and.list.clipboard")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if task.status != .completed {
        Label("The required handoff fields are present. Resolve this follow-up to clear the Inbox verification task.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      }

      CompactActionRow {
        if task.status == .completed {
          Button("Reopen task", systemImage: "arrow.uturn.backward.circle.fill") {
            store.reopenReviewTask(task)
            feedbackMessage = "Partial order task reopened."
          }
          .buttonStyle(.bordered)
        } else if canResolveFollowUp {
          Button("Resolve follow-up", systemImage: "checkmark.seal.fill") {
            store.resolvePartialInboxOrderFollowUpIfReady(for: order)
            feedbackMessage = "Partial order follow-up resolved locally."
          }
          .buttonStyle(.borderedProminent)
        } else {
          Button("Complete task", systemImage: "checkmark.circle.fill") {
            store.completeReviewTask(task)
            feedbackMessage = "Partial order task completed locally."
          }
          .buttonStyle(.borderedProminent)
        }

        Button("Mark reviewed", systemImage: "checkmark.shield.fill") {
          store.markReviewTaskReviewed(task)
          feedbackMessage = "Partial order task marked reviewed locally."
        }
        .buttonStyle(.bordered)

        Button("Draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: task)
          feedbackMessage = "Draft message created from partial order task. Check Drafts."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(10)
    .background(Color.orange.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderDispatchHandoffRows: View {
  var order: TrackedOrder
  var manifests: [ShipmentManifestRecord]
  var checklists: [DispatchReadinessChecklist]
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var hasBlockedRecord: Bool {
    manifests.contains { $0.dispatchStatus == .blockedNeedsReview }
      || checklists.contains { $0.checklistStatus == .blockedNeedsReview }
  }

  private var hasOpenHandoffRecord: Bool {
    manifests.contains { $0.dispatchStatus != .handedOff }
      || checklists.contains { $0.checklistStatus != .completed }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("Linked dispatch setup")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if hasOpenHandoffRecord && !hasBlockedRecord {
          Button("Complete handoff", systemImage: "checkmark.seal.fill") {
            store.completeInboxDispatchHandoff(for: order)
            feedbackMessage = "Inbox dispatch handoff completed locally."
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        } else if !hasBlockedRecord {
          Button("Reopen handoff", systemImage: "arrow.counterclockwise.circle.fill") {
            store.reopenInboxDispatchHandoff(for: order)
            feedbackMessage = "Inbox dispatch handoff reopened."
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }

      if hasBlockedRecord {
        Label("Resolve blocked dispatch records before completing the order handoff.", systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      } else if hasOpenHandoffRecord {
        Label("Use Complete handoff after local readiness and courier/internal handoff are confirmed.", systemImage: "hand.raised.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Label("Dispatch handoff is complete. Reopen only if the local handoff needs correction.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      }

      CompactActionRow {
        if !manifests.isEmpty {
          NavigationLink {
            ShipmentManifestsView(store: store)
          } label: {
            Label("Open manifests", systemImage: "shippingbox.and.arrow.backward.fill")
          }
          .buttonStyle(.bordered)
        }

        if !checklists.isEmpty {
          NavigationLink {
            DispatchReadinessView(store: store)
          } label: {
            Label("Open readiness", systemImage: "checklist.checked")
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      ForEach(manifests.prefix(2)) { manifest in
        OrderDispatchManifestRow(record: manifest, store: store)
      }

      ForEach(checklists.prefix(2)) { checklist in
        OrderDispatchReadinessRow(checklist: checklist, store: store)
      }
    }
  }
}

private struct OrderDispatchManifestRow: View {
  var record: ShipmentManifestRecord
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var nextAction: String {
    switch record.dispatchStatus {
    case .draft, .reopened:
      return record.isInboxHandoffSetup ? "Prepare after readiness is checked." : "Prepare this manifest."
    case .prepared:
      return "Dispatch or block this manifest."
    case .dispatched:
      return "Confirm handoff."
    case .handedOff:
      return "Handoff is complete."
    case .blockedNeedsReview:
      return "Resolve the blocked manifest."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: record.manifestType.symbol)
          .foregroundStyle(record.dispatchStatus.color)
          .frame(width: 20)

        VStack(alignment: .leading, spacing: 3) {
          Text(record.title)
            .font(.callout.weight(.semibold))
          Text("\(record.carrierCourier) • \(record.destinationSummary)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(nextAction)
            .font(.caption.weight(.semibold))
            .foregroundStyle(record.dispatchStatus.color)
        }

        Spacer()
        Badge(record.isInboxHandoffSetup ? "Inbox manifest" : record.dispatchStatus.rawValue, color: record.dispatchStatus.color)
      }

      CompactActionRow {
        Button("Prepared", systemImage: "checkmark.circle.fill") {
          store.markShipmentManifestPrepared(record)
          feedbackMessage = "Manifest marked prepared locally."
        }
        .buttonStyle(.bordered)

        Button("Dispatched", systemImage: "paperplane.fill") {
          store.markShipmentManifestDispatched(record)
          feedbackMessage = "Manifest marked dispatched locally."
        }
        .buttonStyle(.bordered)

        Button("Handed off", systemImage: "person.badge.shield.checkmark.fill") {
          store.markShipmentManifestHandedOff(record)
          feedbackMessage = "Manifest handoff recorded locally."
        }
        .buttonStyle(.borderedProminent)

        Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
          store.markShipmentManifestBlocked(record)
          feedbackMessage = "Manifest blocked for dispatch review."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderDispatchReadinessRow: View {
  var checklist: DispatchReadinessChecklist
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var nextAction: String {
    switch checklist.checklistStatus {
    case .draft, .reopened:
      return checklist.isInboxHandoffSetup ? "Confirm labels, scans, custody, and handoff." : "Mark ready or block."
    case .ready:
      return "Complete readiness checks."
    case .completed:
      return "Readiness complete."
    case .blockedNeedsReview:
      return "Resolve the blocked checklist."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: checklist.checklistType.symbol)
          .foregroundStyle(checklist.checklistStatus.color)
          .frame(width: 20)

        VStack(alignment: .leading, spacing: 3) {
          Text(checklist.title)
            .font(.callout.weight(.semibold))
          Text(checklist.missingRequirementsSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(nextAction)
            .font(.caption.weight(.semibold))
            .foregroundStyle(checklist.checklistStatus.color)
        }

        Spacer()
        Badge(checklist.isInboxHandoffSetup ? "Inbox readiness" : checklist.checklistStatus.rawValue, color: checklist.checklistStatus.color)
      }

      CompactActionRow {
        Button("Ready", systemImage: "checkmark.circle.fill") {
          store.markDispatchChecklistReady(checklist)
          feedbackMessage = "Readiness checklist marked ready locally."
        }
        .buttonStyle(.bordered)

        Button("Complete", systemImage: "checkmark.seal.fill") {
          store.markDispatchChecklistCompleted(checklist)
          feedbackMessage = "Readiness checklist completed locally."
        }
        .buttonStyle(.borderedProminent)

        Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
          store.markDispatchChecklistBlocked(checklist)
          feedbackMessage = "Readiness checklist blocked for review."
        }
        .buttonStyle(.bordered)

        Button("Reopen", systemImage: "arrow.counterclockwise") {
          store.reopenDispatchChecklist(checklist)
          feedbackMessage = "Readiness checklist reopened."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderOperationalTimelineRow: View {
  var activity: TimelineActivity
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: activity.entityType.symbol)
          .foregroundStyle(activity.risk.color)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
              Text(activity.title)
                .font(.callout.weight(.semibold))
              Text(activity.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(activity.entityType.rawValue, color: activity.risk.color)
          }

          Text(activity.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          CompactMetadataGrid(minimumWidth: 130) {
            Badge(activity.risk.rawValue, color: activity.risk.color)
            if let reviewState = activity.reviewState {
              Badge(reviewState.rawValue, color: reviewState.color)
            }
            Label(activity.timestampText, systemImage: "clock.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(activity.suggestedActionText, systemImage: "arrow.forward.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        if activity.supportsReviewTask {
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: activity)
            feedbackMessage = "Timeline follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
        }

        if activity.supportsDraftMessage {
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: activity)
            feedbackMessage = "Draft message created from timeline item. Check Drafts."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct OrderMailboxSourceSummaryRow: View {
  var source: OrderMailboxSourceSummary

  private var color: Color {
    if source.importedCount > 0 { return .green }
    if source.duplicateRefreshedCount > 0 { return .teal }
    if source.duplicateCount > 0 { return .orange }
    switch source.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
    }
  }

  private var symbol: String {
    switch source.providerName {
    case "Gmail": return "envelope.badge.shield.half.filled"
    case "SpaceMail": return "server.rack"
    case "Microsoft 365": return "mail.stack.fill"
    default: return "envelope.badge.fill"
    }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(source.providerName)
            .font(.caption.weight(.semibold))
          Badge(source.statusLabel, color: color)
        }
        Text(source.detailText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(10)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
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

      IntakeSourceContextPanel(
        email: email,
        store: store,
        manualDetail: "No mailbox ingest record is linked to this intake row. Treat it as local/manual evidence for this order.",
        linkedDetailSuffix: "Duplicate-safe source metadata is linked to this order trail."
      )

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
        OrderActionFeedbackPanel(message: feedbackMessage, store: store)
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
