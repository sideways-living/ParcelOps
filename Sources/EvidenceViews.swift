import SwiftUI

struct EvidenceView: View {
  var store: ParcelOpsStore
  @State private var selectedEntityType: EvidenceLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var evidenceSearchText = ""
  @State private var showAllEvidenceAttachments = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredAttachments: [EvidenceAttachment] {
    store.evidenceAttachments.filter { attachment in
      let matchesEntity = selectedEntityType == nil || attachment.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || attachment.reviewState == selectedReviewState
      return matchesEntity && matchesReview
    }
  }

  private var filteredAttachments: [EvidenceAttachment] {
    let query = evidenceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredAttachments }
    return baseFilteredAttachments.filter { attachment in
      evidenceAttachment(attachment, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEntityType != nil
      || selectedReviewState != nil
      || !evidenceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var displayedAttachments: [EvidenceAttachment] {
    showAllEvidenceAttachments ? filteredAttachments : Array(filteredAttachments.prefix(48))
  }

  private var hiddenDisplayedAttachmentCount: Int {
    max(filteredAttachments.count - displayedAttachments.count, 0)
  }

  private var inboxCreatedOrdersWithEvidence: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !evidenceForOrder(order).isEmpty
    }
  }

  private var inboxCreatedOrdersWithoutEvidence: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      evidenceForOrder(order).isEmpty
    }
  }

  private var inboxCreatedOrdersMissingSourceTrail: [TrackedOrder] {
    store.operatorSourceOrdersMissingSourceTrail(includeWishlist: true)
  }

  private var evidenceProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
          detail = "SpaceMail intake can provide the source trail even when no attachment is linked yet.\(providerRefreshSuffix(for: tone))"
        case "gmail":
          detail = "Gmail intake can provide the source trail even when no attachment is linked yet.\(providerRefreshSuffix(for: tone))"
        case "microsoft":
          detail = "Outlook/Microsoft Graph intake can provide the source trail even when no attachment is linked yet.\(providerRefreshSuffix(for: tone))"
        case "mock":
          detail = "Mock mailbox intake is local test evidence. Confirm live provider context before treating it as operational support."
        default:
          detail = "Local mailbox intake can support evidence checks once linked to an order."
        }
        return (label: label, count: count, detail: detail, symbol: providerSymbol(for: tone, label: label), color: providerColor(for: tone))
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
    case "microsoft":
      refreshedCount = store.totalMicrosoft365DuplicateRefreshedCount
    default:
      refreshedCount = 0
    }
    guard refreshedCount > 0 else { return "" }
    return " \(refreshedCount) duplicate refresh\(refreshedCount == 1 ? "" : "es") updated existing Inbox rows; no extra evidence row was created."
  }

  private var gmailSourceTrailEmails: [ForwardedEmailIntake] {
    store.intakeEmails.filter { email in
      store.intakeSourceSummary(for: email).tone == "gmail"
    }
  }

  private var spaceMailSourceTrailEmails: [ForwardedEmailIntake] {
    store.intakeEmails.filter { email in
      store.intakeSourceSummary(for: email).tone == "spacemail"
    }
  }

  private var gmailSourceTrailOrders: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      store.linkedIntakeEmails(for: order).contains { email in
        store.intakeSourceSummary(for: email).tone == "gmail"
      }
    }
  }

  private var spaceMailSourceTrailOrders: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      store.linkedIntakeEmails(for: order).contains { email in
        store.intakeSourceSummary(for: email).tone == "spacemail"
      }
    }
  }

  private var gmailOrdersMissingEvidence: [TrackedOrder] {
    gmailSourceTrailOrders.filter { evidenceForOrder($0).isEmpty }
  }

  private var spaceMailOrdersMissingEvidence: [TrackedOrder] {
    spaceMailSourceTrailOrders.filter { evidenceForOrder($0).isEmpty }
  }

  private var outlookSourceTrailEmails: [ForwardedEmailIntake] {
    store.intakeEmails.filter { email in
      store.intakeSourceSummary(for: email).tone == "microsoft"
    }
  }

  private var outlookSourceTrailOrders: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      store.linkedIntakeEmails(for: order).contains { email in
        store.intakeSourceSummary(for: email).tone == "microsoft"
      }
    }
  }

  private var outlookOrdersMissingEvidence: [TrackedOrder] {
    outlookSourceTrailOrders.filter { evidenceForOrder($0).isEmpty }
  }

  private var providerSourceTrailEmails: [ForwardedEmailIntake] {
    (spaceMailSourceTrailEmails + gmailSourceTrailEmails + outlookSourceTrailEmails).uniquedByID()
  }

  private var providerOrdersMissingEvidence: [TrackedOrder] {
    (spaceMailOrdersMissingEvidence + gmailOrdersMissingEvidence + outlookOrdersMissingEvidence).uniquedByID()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Evidence")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local attachments linked to orders and forwarded intake emails.")
            .foregroundStyle(.secondary)
        }

        filterBar
        inboxEvidenceCoveragePanel
        gmailEvidenceFocusPanel

        SettingsPanel(title: "Attachments", symbol: "paperclip") {
          HStack {
            Text("\(filteredAttachments.count) visible attachments")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredAttachments.count) after filters", color: .blue)
            }
            Spacer()
          }

          if filteredAttachments.isEmpty {
            MVPEmptyState(title: "No evidence matches this view", detail: hasActiveFilters ? "Clear search or filters to return to all local evidence records." : "Evidence appears here when local attachments or placeholder file references are linked to operational records.", symbol: "paperclip", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
          } else {
            if hiddenDisplayedAttachmentCount > 0 {
              CompactActionRow {
                Label("Showing first \(displayedAttachments.count) attachments", systemImage: "speedometer")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Badge("\(hiddenDisplayedAttachmentCount) older hidden", color: .secondary)
                Button(showAllEvidenceAttachments ? "Show first 48" : "Show all \(filteredAttachments.count)", systemImage: showAllEvidenceAttachments ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                  withAnimation(.snappy) {
                    showAllEvidenceAttachments.toggle()
                  }
                }
                .buttonStyle(.bordered)
              }
              Text("Search and filters still scan every local evidence record. The default list is capped so Evidence opens quickly with accumulated test data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(displayedAttachments) { attachment in
              EvidenceAttachmentRow(attachment: attachment, store: store, linkedOrder: linkedOrder(for: attachment), shipmentGroups: store.suggestedShipmentGroups(for: attachment), customerProfiles: store.suggestedCustomerProfiles(for: attachment), destinationAddresses: store.suggestedDestinationAddresses(for: attachment), deliveryInstructions: store.suggestedDeliveryInstructions(for: attachment), packageContents: store.suggestedPackageContents(for: attachment)) {
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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private func linkedOrder(for attachment: EvidenceAttachment) -> TrackedOrder? {
    guard attachment.linkedEntityType == .order else { return nil }
    return store.orders.first { $0.id == attachment.linkedEntityID }
  }

  private var inboxEvidenceCoveragePanel: some View {
    SettingsPanel(title: "Inbox and Wishlist evidence coverage", symbol: "envelope.open.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Evidence should support orders created from Inbox, Import Queue, Acceptance Review, or Wishlist purchase handoff. Missing evidence is not a blocker by itself, but it should be visible before handoff closure.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Inbox orders", "\(store.inboxCreatedOrderCount)", store.inboxCreatedOrderCount == 0 ? .secondary : .teal),
          ("Wishlist orders", "\(store.wishlistLinkedOrderCount)", store.wishlistLinkedOrderCount == 0 ? .secondary : .pink),
          ("With evidence", "\(inboxCreatedOrdersWithEvidence.count)", inboxCreatedOrdersWithoutEvidence.isEmpty ? .green : .orange),
          ("No evidence", "\(inboxCreatedOrdersWithoutEvidence.count)", inboxCreatedOrdersWithoutEvidence.isEmpty ? .green : .orange),
          ("Missing source", "\(inboxCreatedOrdersMissingSourceTrail.count)", inboxCreatedOrdersMissingSourceTrail.isEmpty ? .green : .orange)
        ])

        if !evidenceProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for evidence checks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(evidenceProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        if inboxCreatedOrdersWithoutEvidence.isEmpty && inboxCreatedOrdersMissingSourceTrail.isEmpty {
          Label(store.operatorSourceOrderCount == 0 ? "No Inbox-created or Wishlist-linked orders exist yet." : "Inbox-created and Wishlist-linked orders have evidence or source context available.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(Array((inboxCreatedOrdersWithoutEvidence + inboxCreatedOrdersMissingSourceTrail).uniquedByID().prefix(4))) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                  .foregroundStyle(.orange)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(order.store) • \(order.orderNumber)")
                    .font(.subheadline.weight(.semibold))
                  Text(evidenceForOrder(order).isEmpty ? "No local evidence attachment is linked to this Inbox-created or Wishlist-linked order. Check source trail before closing handoff work." : "Source trail is missing even though evidence exists. Open order detail to link or review the source context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(evidenceForOrder(order).isEmpty ? "No evidence" : "Trace", color: .orange)
              }
              .padding(10)
              .background(Color.orange.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
          let missingEvidenceOrders = (inboxCreatedOrdersWithoutEvidence + inboxCreatedOrdersMissingSourceTrail).uniquedByID()
          if missingEvidenceOrders.count > 4 {
            Text("\(missingEvidenceOrders.count - 4) more Inbox/Wishlist orders are hidden and still need evidence or source-trail review.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var gmailEvidenceFocusPanel: some View {
    if !store.spaceMailIMAPConnections.isEmpty || !store.gmailMailboxConnections.isEmpty || !store.microsoft365MailboxConnections.isEmpty || !providerSourceTrailEmails.isEmpty {
      SettingsPanel(title: "Mailbox evidence focus", symbol: "mail.stack.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("SpaceMail, Gmail, and Outlook-origin intake can serve as the local source trail for an order even when no file attachment exists. Use this to decide whether mailbox-created orders need extra evidence before handoff closure.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("SpaceMail rows", "\(spaceMailSourceTrailEmails.count)", spaceMailSourceTrailEmails.isEmpty ? .secondary : .teal),
            ("Gmail source rows", "\(gmailSourceTrailEmails.count)", gmailSourceTrailEmails.isEmpty ? .secondary : .blue),
            ("Outlook source rows", "\(outlookSourceTrailEmails.count)", outlookSourceTrailEmails.isEmpty ? .secondary : .purple),
            ("Mailbox orders", "\((spaceMailSourceTrailOrders + gmailSourceTrailOrders + outlookSourceTrailOrders).uniquedByID().count)", providerSourceTrailEmails.isEmpty ? .secondary : .green),
            ("SpaceMail missing", "\(spaceMailOrdersMissingEvidence.count)", spaceMailOrdersMissingEvidence.isEmpty ? .green : .orange),
            ("Provider missing", "\(providerOrdersMissingEvidence.count)", providerOrdersMissingEvidence.isEmpty ? .green : .orange),
            ("Mailbox refreshes", "\(store.totalMailboxFetchedCount)", store.totalMailboxFetchedCount == 0 ? .secondary : .teal)
          ])

          CollapsedProviderEvidencePanel(
            title: "Mailbox evidence boundaries",
            detail: "Provider setup, source counts, and local-only boundaries for SpaceMail, Gmail, and Outlook evidence trails.",
            symbol: "doc.viewfinder.fill"
          ) {
            GmailReleaseBoundaryPanel(
              store: store,
              title: "Gmail evidence readiness",
              lead: "Use this before treating Gmail source trails as sufficient release evidence. Setup, sign-in, labels, classifier review, Inbox handoff, and Audit evidence should be clear before evidence gaps are closed.",
              sourceMetricTitle: "Gmail source rows",
              sourceCount: gmailSourceTrailEmails.count,
              boundaryDetail: "Local-only boundary: this panel does not open Google sign-in, fetch Gmail, store token values, create evidence attachments, or mutate mailbox messages."
            )

            Microsoft365ReleaseBoundaryPanel(
              store: store,
              title: "Outlook evidence readiness",
              lead: "Use this before treating Outlook source trails as sufficient release evidence. Microsoft setup, sign-in, Graph diagnostics, Inbox handoff, and Audit evidence should be clear before evidence gaps are closed.",
              sourceMetricTitle: "Outlook source rows",
              sourceCount: outlookSourceTrailEmails.count,
              boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, open file pickers, run OCR, create evidence attachments, or mutate mailbox messages."
            )
          }

          if !store.gmailMailboxConnections.isEmpty {
            MailboxProviderPostRefreshDisclosure(
              title: "Gmail evidence follow-up",
              detail: "Open this when Gmail refresh results affect evidence review. Evidence rows remain the primary work here.",
              symbol: "envelope.badge.shield.half.filled",
              tone: .pink,
              statusLabel: "Gmail"
            ) {
              GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            }
          }

          if providerSourceTrailEmails.isEmpty {
            Label("No mailbox-origin intake is linked to orders yet. Run the matching manual refresh, then create or link confirmed order rows from Inbox.", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          } else if providerOrdersMissingEvidence.isEmpty {
            Label("Mailbox-created orders have evidence or source context available.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Mailbox-created orders to check")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 260), spacing: 10)], spacing: 10) {
                ForEach(Array(providerOrdersMissingEvidence.prefix(4))) { order in
                  NavigationLink {
                    OrderDetailView(order: order, store: store)
                  } label: {
                    HStack(alignment: .top, spacing: 10) {
                      Image(systemName: "mail.stack.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 22)
                      VStack(alignment: .leading, spacing: 4) {
                        Text("\(order.store) • \(order.orderNumber)")
                          .font(.caption.weight(.semibold))
                        Text("Mailbox source trail exists, but no evidence attachment is linked. Open order detail before closing handoff work.")
                          .font(.caption2)
                          .foregroundStyle(.secondary)
                          .fixedSize(horizontal: false, vertical: true)
                      }
                      Spacer(minLength: 8)
                      Badge("Check", color: .orange)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            if providerOrdersMissingEvidence.count > 4 {
              Text("\(providerOrdersMissingEvidence.count - 4) more mailbox-created orders are hidden and still need evidence or source-trail review.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          CompactActionRow {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Audit", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)

          Text("This panel is local evidence guidance only. It does not fetch SpaceMail, Gmail, or Outlook, open sign-in, store token values, attach files, or mutate mailbox messages.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search file, summary, linked record, order, customer, destination, or item", text: $evidenceSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as EvidenceLinkedEntityType?)
        ForEach(EvidenceLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as EvidenceLinkedEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
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
    selectedEntityType = nil
    selectedReviewState = nil
    evidenceSearchText = ""
  }

  private func evidenceAttachment(_ attachment: EvidenceAttachment, matches query: String) -> Bool {
    let order = linkedOrder(for: attachment)
    let shipmentGroups = store.suggestedShipmentGroups(for: attachment)
    let customerProfiles = store.suggestedCustomerProfiles(for: attachment)
    let destinationAddresses = store.suggestedDestinationAddresses(for: attachment)
    let deliveryInstructions = store.suggestedDeliveryInstructions(for: attachment)
    let packageContents = store.suggestedPackageContents(for: attachment)
    var searchParts: [String] = [
      attachment.id.uuidString,
      attachment.linkedEntityType.rawValue,
      attachment.linkedEntityID.uuidString,
      attachment.fileName,
      attachment.fileType,
      attachment.source.rawValue,
      attachment.addedDate,
      attachment.summary,
      attachment.reviewState.rawValue,
      attachment.localFilePath,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: shipmentGroups.map(\.groupName))
    searchParts.append(contentsOf: customerProfiles.map(\.displayName))
    searchParts.append(contentsOf: destinationAddresses.map(\.label))
    searchParts.append(contentsOf: destinationAddresses.map(\.addressLineSummary))
    searchParts.append(contentsOf: deliveryInstructions.map(\.title))
    searchParts.append(contentsOf: deliveryInstructions.map(\.instructionSummary))
    searchParts.append(contentsOf: packageContents.map(\.title))
    searchParts.append(contentsOf: packageContents.map(\.itemSummary))
    if let order {
      let mailboxSummaries = store.mailboxSourceSummaries(for: order)
      searchParts.append(contentsOf: mailboxSummaries.map(\.providerName))
      searchParts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.detailText))
    }
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }

  private func providerColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "microsoft" || label.localizedCaseInsensitiveContains("Microsoft") || label.localizedCaseInsensitiveContains("Graph") {
      return "mail.stack.fill"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
  }

  private func evidenceForOrder(_ order: TrackedOrder) -> [EvidenceAttachment] {
    evidenceAttachmentsForOrder(order, in: store.evidenceAttachments, intakeEmails: store.intakeEmails)
  }


}

struct EvidenceAttachmentRow: View {
  var attachment: EvidenceAttachment
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentGroups: [ShipmentGroup] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: attachment.source.symbol)
          .foregroundStyle(attachment.reviewState.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(attachment.fileName)
                .font(.headline)
              Text("\(attachment.fileType) • \(attachment.addedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(attachment.reviewState.rawValue, color: attachment.reviewState.color)
          }

          Text(attachment.summary)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(attachment.linkedEntityType.rawValue, color: attachment.reviewState.color)
            Label(attachment.source.rawValue, systemImage: attachment.source.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(attachment.localFilePath)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
          }

          if let linkedOrder, linkedOrder.isInboxCreatedLocalOrder || !linkedWishlistItems.isEmpty {
            EvidenceInboxSourceTrailCallout(
              evidenceCount: evidenceForLinkedOrder.count,
              sourceTrailCount: store?.sourceTrailCount(for: linkedOrder) ?? 0
            )
          }

          if !evidenceWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Label("Evidence follow-up", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)
              ForEach(evidenceWarnings, id: \.self) { warning in
                Text(warning)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }

          if let store, let linkedOrder {
            let linkedEmails = store.linkedIntakeEmails(for: linkedOrder)
            if !linkedEmails.isEmpty || !linkedWishlistItems.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                Label("Inbox/Wishlist evidence source", systemImage: "tray.and.arrow.down.fill")
                  .font(.caption.bold())
                  .foregroundStyle(.teal)
                ForEach(linkedWishlistItems.prefix(2)) { item in
                  HStack(spacing: 6) {
                    Badge("Wishlist", color: .pink)
                    if let handoff = item.purchaseHandoff {
                      Badge(handoff.purchaseStatus, color: .secondary)
                    }
                    Text(item.itemName)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
                if linkedWishlistItems.count > 2 {
                  Text("\(linkedWishlistItems.count - 2) more Wishlist item\(linkedWishlistItems.count - 2 == 1 ? "" : "s") are linked to this evidence record but hidden here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
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
                if linkedEmails.count > 2 {
                  Text("\(linkedEmails.count - 2) more source email\(linkedEmails.count - 2 == 1 ? "" : "s") are linked to this evidence record but hidden here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
            OrderMailboxSourceTrailPanel(
              summaries: store.mailboxSourceSummaries(for: linkedOrder),
              title: "Mailbox provider evidence trail",
              symbol: "paperclip"
            )
          }

          if !customerProfiles.isEmpty {
            CustomerProfileStrip(profiles: customerProfiles)
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
        }
      }

      CompactActionRow {
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Evidence marked reviewed locally. No OCR, file picker, external storage, or mailbox system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Evidence reference removed locally. No local file, mailbox message, or external system was deleted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this evidence item for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this evidence item. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus") {
          onCreateContact()
          feedbackMessage = "Contact placeholder created from this evidence item for local follow-up."
        }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        EvidenceActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var evidenceForLinkedOrder: [EvidenceAttachment] {
    guard let store, let linkedOrder else { return [] }
    return evidenceAttachmentsForOrder(linkedOrder, in: store.evidenceAttachments, intakeEmails: store.intakeEmails)
  }

  private var linkedWishlistItems: [WishlistItem] {
    guard let store, let linkedOrder else { return [] }
    return store.activeWishlistItemsLinked(to: linkedOrder)
  }

  private var evidenceWarnings: [String] {
    var warnings: [String] = []
    if attachment.reviewState != .accepted {
      warnings.append("Review state is \(attachment.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    if attachment.localFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment.localFilePath.localizedCaseInsensitiveContains("placeholder") {
      warnings.append("Local file reference is a placeholder or missing.")
    }
    if attachment.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment.summary.localizedCaseInsensitiveContains("placeholder") {
      warnings.append("Evidence summary needs confirmation.")
    }
    if let linkedOrder, linkedOrder.isInboxCreatedLocalOrder, (store?.sourceTrailCount(for: linkedOrder) ?? 0) == 0 {
      warnings.append("Inbox-created order source trail is missing.")
    }
    return warnings
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

private struct EvidenceActionFeedbackPanel: View {
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

private struct EvidenceInboxSourceTrailCallout: View {
  var evidenceCount: Int
  var sourceTrailCount: Int

  private var tone: Color {
    evidenceCount > 0 && sourceTrailCount > 0 ? .green : .orange
  }

  private var title: String {
    if evidenceCount > 0 && sourceTrailCount > 0 { return "Inbox source and evidence are linked" }
    if evidenceCount == 0 && sourceTrailCount == 0 { return "Inbox source and evidence need review" }
    if evidenceCount == 0 { return "Inbox order has source trail but no evidence" }
    return "Evidence exists but source trail is missing"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: tone == .green ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(tone)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
        Text("Evidence records: \(evidenceCount). Source trail records: \(sourceTrailCount). Open order detail before closing related Inbox handoff work.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
    }
    .padding(10)
    .background(tone.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private func evidenceAttachmentsForOrder(_ order: TrackedOrder, in attachments: [EvidenceAttachment], intakeEmails: [ForwardedEmailIntake]) -> [EvidenceAttachment] {
  let linkedIntakeIDs = Set(intakeEmails.filter { $0.linkedOrderID == order.id }.map(\.id))
  return attachments.filter { attachment in
    (attachment.linkedEntityType == .order && attachment.linkedEntityID == order.id)
      || (attachment.linkedEntityType == .intakeEmail && linkedIntakeIDs.contains(attachment.linkedEntityID))
  }
}

private extension Array where Element == TrackedOrder {
  func uniquedByID() -> [TrackedOrder] {
    var seen: Set<UUID> = []
    return filter { order in
      seen.insert(order.id).inserted
    }
  }
}

private extension Array where Element == ForwardedEmailIntake {
  func uniquedByID() -> [ForwardedEmailIntake] {
    var seen: Set<UUID> = []
    return filter { email in
      seen.insert(email.id).inserted
    }
  }
}
