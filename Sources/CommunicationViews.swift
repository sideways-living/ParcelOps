import SwiftUI

struct CommunicationView: View {
  var store: ParcelOpsStore

  @State private var selectedMode: CommunicationMode = .drafts
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var selectedDraftStatus: DraftMessageStatus?
  @State private var searchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var searchQuery: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
  }

  private var baseFilteredTemplates: [CommunicationTemplate] {
    store.communicationTemplates.filter { template in
      let matchesEntity = selectedEntityType == nil || template.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || template.reviewState == selectedReviewState
      return matchesEntity && matchesReview
    }
  }

  private var filteredTemplates: [CommunicationTemplate] {
    guard !searchQuery.isEmpty else { return baseFilteredTemplates }
    return baseFilteredTemplates.filter { template in
      communicationTemplateSearchParts(template).joined(separator: " ").localizedLowercase.contains(searchQuery)
    }
  }

  private var baseFilteredDrafts: [DraftMessage] {
    store.draftMessages.filter { draft in
      let matchesEntity = selectedEntityType == nil || draft.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || draft.reviewState == selectedReviewState
      let matchesStatus = selectedDraftStatus == nil || draft.status == selectedDraftStatus
      return matchesEntity && matchesReview && matchesStatus
    }
  }

  private var filteredDrafts: [DraftMessage] {
    guard !searchQuery.isEmpty else { return baseFilteredDrafts }
    return baseFilteredDrafts.filter { draft in
      draftSearchParts(draft).joined(separator: " ").localizedLowercase.contains(searchQuery)
    }
  }

  private var hasActiveFilters: Bool {
    !searchQuery.isEmpty
      || selectedEntityType != nil
      || selectedReviewState != nil
      || (selectedMode == .drafts && selectedDraftStatus != nil)
  }

  private var openDrafts: [DraftMessage] {
    store.draftMessages.filter { $0.status != .sentLocally }
  }

  private var readyDrafts: [DraftMessage] {
    store.draftMessages.filter { $0.status == .ready }
  }

  private var draftNextActionTitle: String {
    if !readyDrafts.isEmpty { return "Send ready drafts outside ParcelOps" }
    if !store.draftMessagesNeedingReview.isEmpty { return "Review draft follow-up" }
    if openDrafts.isEmpty { return "No open draft follow-up" }
    return "Continue open draft work"
  }

  private var draftNextActionDetail: String {
    if !readyDrafts.isEmpty {
      return "\(readyDrafts.count) draft is marked ready. Send it in the real mail client, then mark it sent locally here."
    }
    if !store.draftMessagesNeedingReview.isEmpty {
      return "\(store.draftMessagesNeedingReview.count) draft needs review, readiness, sending, or reopening before its related work is closed."
    }
    if openDrafts.isEmpty {
      return "All local drafts are either sent locally or no drafts have been created yet. ParcelOps still does not send outbound email."
    }
    return "\(openDrafts.count) draft is still open. Use the status controls to keep follow-up visible on Dashboard, Workbench, and Tasks."
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Drafts & Templates")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local draft follow-up and reusable message templates. Nothing is sent from ParcelOps yet.")
            .foregroundStyle(.secondary)
        }

        CompactActionRow {
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        draftSummaryPanel
        wishlistDraftFocusPanel
        gmailDraftFocusPanel
        inboxDraftCoverage
        filterBar

        Picker("Drafts and templates mode", selection: $selectedMode) {
          ForEach(CommunicationMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        if selectedMode == .templates {
          SettingsPanel(title: "Templates", symbol: "text.badge.checkmark") {
            HStack {
              Text("\(filteredTemplates.count) visible templates")
                .font(.caption)
                .foregroundStyle(.secondary)
              if hasActiveFilters {
                Badge("\(baseFilteredTemplates.count) after filters", color: .blue)
              }
              Spacer()
              Button("Add template", systemImage: "plus", action: store.addCommunicationTemplatePlaceholder)
                .buttonStyle(.borderedProminent)
            }

            ForEach(filteredTemplates) { template in
              CommunicationTemplateRow(template: template, store: store) { updatedTemplate in
                store.updateCommunicationTemplate(updatedTemplate)
              } onToggle: {
                store.toggleCommunicationTemplate(template)
              } onReviewed: {
                store.markCommunicationTemplateReviewed(template)
              } onCreateDraft: {
                store.createDraftMessage(
                  linkedEntityType: template.linkedEntityType,
                  linkedEntityID: "Template preview",
                  label: template.name,
                  recipient: "operations@parcelops.example",
                  template: template
                )
              } onRemove: {
                store.removeCommunicationTemplate(template)
              }
            }
            if filteredTemplates.isEmpty {
              MVPEmptyState(
                title: "No templates match this view",
                detail: hasActiveFilters ? "Clear search or filters to return to all local templates." : "Add a local template to start common follow-up drafts without sending mail.",
                symbol: "text.badge.checkmark",
                actionTitle: hasActiveFilters ? "Clear filters" : "Add template",
                action: hasActiveFilters ? clearFilters : store.addCommunicationTemplatePlaceholder
              )
            }
          }
        } else {
          SettingsPanel(title: "Draft messages", symbol: "envelope.open.fill") {
            HStack {
              Text("\(filteredDrafts.count) visible drafts")
                .font(.caption)
                .foregroundStyle(.secondary)
              if hasActiveFilters {
                Badge("\(baseFilteredDrafts.count) after filters", color: .blue)
              }
              Spacer()
              Button("Add draft", systemImage: "plus", action: store.addDraftMessagePlaceholder)
                .buttonStyle(.borderedProminent)
            }

            ForEach(filteredDrafts) { draft in
              DraftMessageRow(draft: draft, store: store, linkedOrder: linkedOrder(for: draft), inboxOrders: inboxOrders(for: draft), destinationAddresses: store.suggestedDestinationAddresses(for: draft), deliveryInstructions: store.suggestedDeliveryInstructions(for: draft), packageContents: store.suggestedPackageContents(for: draft)) { updatedDraft in
                store.updateDraftMessage(updatedDraft)
              } onReady: {
                store.markDraftMessageReady(draft)
              } onSent: {
                store.markDraftMessageSentLocally(draft)
              } onReopen: {
                store.reopenDraftMessage(draft)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .draftMessage, linkedEntityID: draft.id.uuidString, label: draft.recipient)
              } onRemove: {
                store.removeDraftMessage(draft)
              }
            }
            if filteredDrafts.isEmpty {
              MVPEmptyState(
                title: "No drafts match this view",
                detail: hasActiveFilters ? "Clear search or filters to return to all local drafts." : "Add a local draft. Drafts stay local until you send the message outside ParcelOps and mark it sent locally.",
                symbol: "envelope.open.fill",
                actionTitle: hasActiveFilters ? "Clear filters" : "Add draft",
                action: hasActiveFilters ? clearFilters : store.addDraftMessagePlaceholder
              )
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var draftSummaryPanel: some View {
    SettingsPanel(title: "Draft operator follow-up", symbol: "paperplane.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: readyDrafts.isEmpty && store.draftMessagesNeedingReview.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .foregroundStyle(readyDrafts.isEmpty && store.draftMessagesNeedingReview.isEmpty ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(draftNextActionTitle)
              .font(.headline)
            Text(draftNextActionDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Needs review", "\(store.draftMessagesNeedingReview.count)", store.draftMessagesNeedingReview.isEmpty ? .green : .orange),
          ("Ready", "\(readyDrafts.count)", readyDrafts.isEmpty ? .green : .blue),
          ("Open", "\(openDrafts.count)", openDrafts.isEmpty ? .green : .purple),
          ("All drafts", "\(store.draftMessages.count)", store.draftMessages.isEmpty ? .secondary : .teal)
        ])

        Text("Use this screen to manage local draft state only. ParcelOps does not send outbound email, store SMTP credentials, or contact a mail provider for sending.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var gmailDrafts: [DraftMessage] {
    store.draftMessages
      .filter { draft in
        [draft.subject, draft.body, draft.recipient, draft.linkedEntityID]
          .joined(separator: " ")
          .localizedCaseInsensitiveContains("gmail")
      }
      .sorted { first, second in
        let firstPriority = gmailDraftSortPriority(first)
        let secondPriority = gmailDraftSortPriority(second)
        if firstPriority == secondPriority {
          return first.createdDate > second.createdDate
        }
        return firstPriority > secondPriority
      }
  }

  private var wishlistDrafts: [DraftMessage] {
    store.draftMessages
      .filter { draft in
        store.isActiveWishlistDraft(draft)
          && (
            draft.linkedEntityType == .wishlistItem
              || draft.linkedEntityID.localizedCaseInsensitiveContains("wishlist")
              || draft.subject.localizedCaseInsensitiveContains("wishlist")
              || draft.body.localizedCaseInsensitiveContains("wishlist")
          )
      }
      .sorted { first, second in
        let firstPriority = wishlistDraftSortPriority(first)
        let secondPriority = wishlistDraftSortPriority(second)
        if firstPriority == secondPriority {
          return first.createdDate > second.createdDate
        }
        return firstPriority > secondPriority
      }
  }

  private var openWishlistDrafts: [DraftMessage] {
    wishlistDrafts.filter { $0.status != .sentLocally || $0.reviewState != .accepted }
  }

  private var wishlistBatchDrafts: [DraftMessage] {
    wishlistDrafts.filter {
      $0.linkedEntityType == .wishlistItem && $0.linkedEntityID == "wishlist-research-batch"
    }
  }
  private var wishlistPurchasePacketDrafts: [DraftMessage] {
    wishlistDrafts.filter {
      $0.linkedEntityType == .wishlistItem
        && $0.subject.localizedCaseInsensitiveContains("wishlist purchase packet")
    }
  }

  @ViewBuilder
  private var wishlistDraftFocusPanel: some View {
    if !wishlistDrafts.isEmpty || store.wishlistItems.contains(where: store.isActiveWishlistItem) || !store.wishlistResearchRequests.isEmpty {
      SettingsPanel(title: "Wishlist draft focus", symbol: "star.square.on.square.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Wishlist research briefs, purchase handoff packets, and seller follow-up drafts are grouped here. They stay local until an operator copies or sends them outside ParcelOps and marks them sent locally.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Wishlist drafts", "\(wishlistDrafts.count)", wishlistDrafts.isEmpty ? .secondary : .purple),
            ("Open", "\(openWishlistDrafts.count)", openWishlistDrafts.isEmpty ? .green : .orange),
            ("Batch briefs", "\(wishlistBatchDrafts.count)", wishlistBatchDrafts.isEmpty ? .secondary : .blue),
            ("Purchase packets", "\(wishlistPurchasePacketDrafts.count)", wishlistPurchasePacketDrafts.isEmpty ? .secondary : .indigo),
            ("Ready", "\(wishlistDrafts.filter { $0.status == .ready }.count)", wishlistDrafts.contains { $0.status == .ready } ? .blue : .green),
            ("Needs review", "\(wishlistDrafts.filter { $0.reviewState != .accepted }.count)", wishlistDrafts.contains { $0.reviewState != .accepted } ? .orange : .green)
          ])

          if openWishlistDrafts.isEmpty && !wishlistDrafts.isEmpty {
            Label("Wishlist drafts are reviewed and marked sent locally. Reopen a draft only if seller comparison, purchase handoff, or order-watch work needs another pass.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else if wishlistDrafts.isEmpty {
            Label("No Wishlist drafts yet. Create research briefs or purchase handoff packets from Wishlist when comparison work is ready to leave the item view.", systemImage: "doc.badge.plus")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 200 : 280), spacing: 10)], alignment: .leading, spacing: 10) {
              ForEach(openWishlistDrafts.prefix(4)) { draft in
                VStack(alignment: .leading, spacing: 8) {
                  HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(wishlistDraftKind(for: draft), systemImage: wishlistDraftSymbol(for: draft))
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(draft.status.color)
                    Spacer(minLength: 8)
                    Badge(draft.status.rawValue, color: draft.status.color)
                  }
                  Text(draft.subject)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                  Text(wishlistDraftActionSummary(for: draft))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                  CompactMetadataGrid(minimumWidth: 115) {
                    Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
                    Label(draft.createdDate, systemImage: "calendar")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                  }
                }
                .padding(10)
                .background(draft.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }

          CompactActionRow {
            NavigationLink {
              WishlistView(store: store)
            } label: {
              Label("Open Wishlist", systemImage: "star.square.fill")
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
  }

  private var openGmailDrafts: [DraftMessage] {
    gmailDrafts.filter { $0.status != .sentLocally || $0.reviewState != .accepted }
  }

  @ViewBuilder
  private var gmailDraftFocusPanel: some View {
    if !gmailDrafts.isEmpty || !store.gmailMailboxConnections.isEmpty {
      SettingsPanel(title: "Gmail draft focus", symbol: "envelope.badge.shield.half.filled") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Local drafts linked to Gmail intake, Gmail setup, classifier tuning, or provider-release work are grouped here. Send any ready message outside ParcelOps, then mark it sent locally.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Gmail drafts", "\(gmailDrafts.count)", .blue),
            ("Open", "\(openGmailDrafts.count)", openGmailDrafts.isEmpty ? .green : .orange),
            ("Ready", "\(gmailDrafts.filter { $0.status == .ready }.count)", gmailDrafts.contains { $0.status == .ready } ? .blue : .green),
            ("Needs review", "\(gmailDrafts.filter { $0.reviewState != .accepted }.count)", gmailDrafts.contains { $0.reviewState != .accepted } ? .orange : .green)
          ])

          GmailReleaseBoundaryPanel(
            store: store,
            title: "Gmail draft readiness",
            lead: "Use this before drafting operator, customer, or supplier follow-up from Gmail intake. Setup, sign-in, labels, classifier review, Inbox handoff, and Audit evidence should be clear before release messages are treated as routine.",
            sourceMetricTitle: "Gmail drafts",
            sourceCount: gmailDrafts.count,
            boundaryDetail: "Local-only boundary: this panel does not send Gmail messages, open Google sign-in, fetch Gmail, store token values, or mutate mailbox messages."
          )

          if !store.gmailMailboxConnections.isEmpty {
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
          }

          if !openGmailDrafts.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 260), spacing: 10)], alignment: .leading, spacing: 10) {
              ForEach(openGmailDrafts.prefix(4)) { draft in
                VStack(alignment: .leading, spacing: 6) {
                  HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(draft.channel.rawValue, systemImage: "envelope.badge.shield.half.filled")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(draft.status == .ready ? .blue : .orange)
                    Spacer()
                    Badge(draft.status.rawValue, color: draft.status.color)
                  }
                  Text(draft.subject)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                  Text(gmailDraftActionSummary(for: draft))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((draft.status == .ready ? Color.blue : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }

          if openGmailDrafts.isEmpty && !gmailDrafts.isEmpty {
            Label("All Gmail-related drafts are reviewed and marked sent locally.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else if openGmailDrafts.isEmpty && gmailDrafts.isEmpty {
            Label("No Gmail-related drafts exist yet. Create a release task first if setup, classifier, Inbox handoff, or Audit evidence still needs ownership.", systemImage: "envelope.open.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(store.gmailMailboxConnections.isEmpty ? Color.secondary : Color.orange)
          } else if openGmailDrafts.count > 4 {
            Text("\(openGmailDrafts.count - 4) more Gmail-related draft\(openGmailDrafts.count - 4 == 1 ? "" : "s") can be worked from the draft list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          CompactActionRow {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Tasks", systemImage: "checklist")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Audit", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)

          Text("This panel does not send Gmail messages, open Google sign-in, fetch Gmail, store token values, or mutate mailbox messages.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var inboxDraftCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedDrafts = draftsLinkedToInboxOrders
    let actionDrafts = linkedDrafts.filter { $0.status != .sentLocally || $0.reviewState != .accepted }

    return SettingsPanel(title: "Inbox and Wishlist draft readiness", symbol: "envelope.open.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local draft follow-up. ParcelOps still does not send email; ready drafts must be sent outside the app.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedDrafts.count) linked drafts", color: .teal)
          Badge("\(actionDrafts.count) need action", color: actionDrafts.isEmpty ? .green : .orange)
          Badge("\(readyDrafts.count) ready", color: readyDrafts.isEmpty ? .green : .blue)
        }

        if !draftProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for draft follow-up")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(draftProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22, height: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer()
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

        if sourceOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create or link an order from Inbox or Wishlist before checking draft coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedDrafts.isEmpty {
          Text("No drafts currently link to Inbox-created or Wishlist-linked orders. Create a draft only when a customer, supplier, carrier, or team follow-up is needed.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if actionDrafts.isEmpty {
          Text("Linked drafts for Inbox-created and Wishlist-linked orders are reviewed and marked sent locally.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionDrafts.prefix(3))) { draft in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: draft.status == .ready ? "paperplane.fill" : "envelope.open.fill")
                .foregroundStyle(draft.status == .ready ? .blue : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(draft.subject)
                  .font(.caption.bold())
                Text(draftActionSummary(for: draft))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(draft.status.rawValue, color: draft.status.color)
            }
          }
        }
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search drafts and templates", text: $searchText)
        .textFieldStyle(.roundedBorder)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
      }

      if selectedMode == .drafts {
        Picker("Draft status", selection: $selectedDraftStatus) {
          Text("All draft statuses").tag(nil as DraftMessageStatus?)
          ForEach(DraftMessageStatus.allCases) { status in
            Text(status.rawValue).tag(status as DraftMessageStatus?)
          }
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
    searchText = ""
    selectedEntityType = nil
    selectedReviewState = nil
    selectedDraftStatus = nil
  }

  private func linkedOrder(for draft: DraftMessage) -> TrackedOrder? {
    guard draft.linkedEntityType == .order, let orderID = UUID(uuidString: draft.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }


  private var draftsLinkedToInboxOrders: [DraftMessage] {
    store.draftMessages.filter { draft in
      store.operatorSourceOrders.contains { order in
        draftMessage(draft, matches: order)
      }
    }
  }

  private func inboxOrders(for draft: DraftMessage) -> [TrackedOrder] {
    store.operatorSourceOrders.filter { draftMessage(draft, matches: $0) }
  }

  private func draftMessage(_ draft: DraftMessage, matches order: TrackedOrder) -> Bool {
    if draft.linkedEntityType == .order, let linkedID = UUID(uuidString: draft.linkedEntityID), linkedID == order.id {
      return true
    }
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    let searchable = [draft.subject, draft.body, draft.recipient, draft.linkedEntityID].joined(separator: " ")
    return (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && searchable.localizedCaseInsensitiveContains(orderNumber))
      || searchable.localizedCaseInsensitiveContains(order.trackingNumber)
      || searchable.localizedCaseInsensitiveContains(order.recipientEmail)
  }

  private func draftActionSummary(for draft: DraftMessage) -> String {
    var parts: [String] = []
    if draft.status == .ready { parts.append("send outside ParcelOps then mark sent locally") }
    if draft.status != .sentLocally && draft.status != .ready { parts.append("finish draft") }
    if draft.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Draft is reviewed and sent locally." : parts.joined(separator: ", ")
  }

  private func gmailDraftSortPriority(_ draft: DraftMessage) -> Int {
    var priority = 0
    if draft.status == .ready { priority += 40 }
    if draft.status == .reopened { priority += 25 }
    if draft.reviewState != .accepted { priority += 20 }
    if draft.status == .draft { priority += 10 }
    if draft.status == .sentLocally { priority -= 20 }
    return priority
  }

  private func wishlistDraftSortPriority(_ draft: DraftMessage) -> Int {
    var priority = 0
    if draft.linkedEntityID == "wishlist-research-batch" { priority += 45 }
    if draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet") { priority += 42 }
    if draft.status == .ready { priority += 40 }
    if draft.status == .reopened { priority += 30 }
    if draft.reviewState != .accepted { priority += 20 }
    if draft.status == .draft { priority += 10 }
    if draft.status == .sentLocally { priority -= 20 }
    return priority
  }

  private func wishlistDraftKind(for draft: DraftMessage) -> String {
    if draft.linkedEntityID == "wishlist-research-batch" { return "Batch research" }
    if draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet") { return "Purchase packet" }
    if draft.body.localizedCaseInsensitiveContains("purchase handoff") { return "Purchase handoff" }
    if draft.body.localizedCaseInsensitiveContains("seller") { return "Seller follow-up" }
    return "Wishlist draft"
  }

  private func wishlistDraftSymbol(for draft: DraftMessage) -> String {
    if draft.linkedEntityID == "wishlist-research-batch" { return "doc.text.magnifyingglass" }
    if draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet") { return "doc.text.fill.viewfinder" }
    if draft.body.localizedCaseInsensitiveContains("purchase handoff") { return "person.crop.circle.badge.checkmark" }
    if draft.body.localizedCaseInsensitiveContains("seller") { return "storefront.fill" }
    return "star.square.fill"
  }

  private func wishlistDraftActionSummary(for draft: DraftMessage) -> String {
    if draft.linkedEntityID == "wishlist-research-batch" {
      switch draft.status {
      case .draft:
        return "Review the comparison packet before handing it to a future research agent or manual research workflow."
      case .ready:
        return "Use the packet outside ParcelOps, then mark it sent locally."
      case .sentLocally:
        return "Batch packet is closed locally. Reopen only if comparison research needs another pass."
      case .reopened:
        return "Update the research scope or packet before marking ready again."
      }
    }
    if draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet") {
      switch draft.status {
      case .draft:
        return "Review seller choice, AUD total, postage, trust, approvals, purchase links, and order-watch notes before any manual buying."
      case .ready:
        return "Use this packet as the local buying checklist outside ParcelOps. After manual purchase work is handled, mark it sent locally."
      case .sentLocally:
        return "Purchase packet is closed locally. Reopen only if seller, price, trust, approval, or order-watch details changed."
      case .reopened:
        return "Update the purchase packet before it is used for manual buying."
      }
    }
    var parts: [String] = []
    if draft.status == .ready { parts.append("send or copy outside ParcelOps, then mark sent locally") }
    if draft.status == .reopened { parts.append("finish reopened Wishlist follow-up") }
    if draft.status == .draft { parts.append("finish local Wishlist draft") }
    if draft.reviewState != .accepted { parts.append("mark reviewed after seller, price, trust, or handoff context is checked") }
    return parts.isEmpty ? "Wishlist draft is reviewed and marked sent locally." : parts.joined(separator: ", ")
  }

  private func gmailDraftActionSummary(for draft: DraftMessage) -> String {
    var parts: [String] = []
    if draft.status == .ready { parts.append("send outside ParcelOps, then mark sent locally") }
    if draft.status == .reopened { parts.append("finish reopened Gmail follow-up") }
    if draft.status == .draft { parts.append("finish draft before release or handoff closure") }
    if draft.reviewState != .accepted { parts.append("mark reviewed after checking context") }
    return parts.isEmpty ? "Gmail draft is reviewed and marked sent locally." : parts.joined(separator: ", ")
  }


  private var draftProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }

    return counts.map { label, count in
      let tone = tones[label] ?? ""
      let detail: String
      switch tone {
      case "spacemail":
        detail = "SpaceMail intake can create customer, supplier, carrier, or team follow-up drafts after an operator confirms the order context."
      case "gmail":
        detail = "Gmail intake can create customer, supplier, carrier, or team follow-up drafts after an operator confirms the order context."
      case "mock":
        detail = "Mock mailbox intake supports local draft workflow testing without contacting a mailbox provider."
      default:
        detail = "Local mailbox intake can create draft follow-up after an order is confirmed. Drafts still send outside ParcelOps."
      }
      return (
        label: label,
        count: count,
        detail: detail,
        symbol: providerSymbol(for: tone, label: label),
        color: sourceColor(for: tone)
      )
    }
    .sorted { lhs, rhs in
      if lhs.count == rhs.count { return lhs.label < rhs.label }
      return lhs.count > rhs.count
    }
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

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
  }

  private func communicationTemplateSearchParts(_ template: CommunicationTemplate) -> [String] {
    [
      template.id.uuidString,
      template.name,
      template.linkedEntityType.rawValue,
      template.subjectTemplate,
      template.bodyTemplate,
      template.channel.rawValue,
      template.isEnabled ? "Enabled" : "Disabled",
      template.createdDate,
      template.lastUsedDate,
      "\(template.usageCount)",
      template.reviewState.rawValue
    ]
  }

  private func draftSearchParts(_ draft: DraftMessage) -> [String] {
    let order = linkedOrder(for: draft)
    let template = draft.templateID.flatMap { templateID in
      store.communicationTemplates.first { $0.id == templateID }
    }
    let mailboxSummaries = order.map { store.mailboxSourceSummaries(for: $0) } ?? []
    var parts = [
      draft.id.uuidString,
      draft.linkedEntityType.rawValue,
      draft.linkedEntityID,
      draft.templateID?.uuidString ?? "",
      draft.recipient,
      draft.subject,
      draft.body,
      draft.channel.rawValue,
      draft.createdDate,
      draft.status.rawValue,
      draft.reviewState.rawValue,
      template?.name ?? "",
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    parts.append(contentsOf: mailboxSummaries.map(\.providerName))
    parts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.detailText))
    return parts
  }
}

enum CommunicationMode: String, CaseIterable, Identifiable {
  case templates = "Templates"
  case drafts = "Drafts"

  var id: String { rawValue }
}

struct CommunicationTemplateRow: View {
  var template: CommunicationTemplate
  var store: ParcelOpsStore? = nil
  var onSave: (CommunicationTemplate) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: template.channel.symbol)
          .foregroundStyle(template.isEnabled ? .green : .secondary)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(template.name)
                .font(.headline)
              Text("\(template.linkedEntityType.rawValue) • \(template.channel.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(template.isEnabled ? "Enabled" : "Disabled", color: template.isEnabled ? .green : .gray)
          }

          Text(template.subjectTemplate)
            .font(.subheadline.weight(.semibold))
          Text(template.bodyTemplate)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          CompactMetadataGrid {
            Badge(template.reviewState.rawValue, color: template.reviewState.color)
            Text("\(template.usageCount) uses")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("Last used \(template.lastUsedDate)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let feedbackMessage {
        CommunicationActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(template.isEnabled ? "Disable" : "Enable", systemImage: template.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = template.isEnabled ? "Template disabled locally." : "Template enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Template marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from template. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Template removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      CommunicationTemplateEditView(template: template) { updatedTemplate in
        onSave(updatedTemplate)
        feedbackMessage = "Template saved locally."
      }
    }
  }
}

struct DraftMessageRow: View {
  var draft: DraftMessage
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var inboxOrders: [TrackedOrder] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (DraftMessage) -> Void
  var onReady: () -> Void
  var onSent: () -> Void
  var onReopen: () -> Void
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var isWishlistPurchasePacketDraft: Bool {
    draft.linkedEntityType == .wishlistItem
      && draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet")
  }

  private var linkedWishlistItem: WishlistItem? {
    guard let store, draft.linkedEntityType == .wishlistItem else { return nil }
    return store.wishlistItem(linkedEntityID: draft.linkedEntityID)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: draft.channel.symbol)
          .foregroundStyle(draft.status.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(draft.subject)
                .font(.headline)
              Text("\(draft.recipient) • \(draft.channel.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(draft.status.rawValue, color: draft.status.color)
          }

          Text(draft.body)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(4)

          CompactMetadataGrid {
            Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
            Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(draft.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
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

          if let linkedWishlistItem {
            VStack(alignment: .leading, spacing: 6) {
              Label(isWishlistPurchasePacketDraft ? "Wishlist purchase packet source" : "Wishlist draft source", systemImage: "star.square.fill")
                .font(.caption.bold())
                .foregroundStyle(.purple)
              HStack(spacing: 6) {
                Badge(linkedWishlistItem.itemName, color: .purple)
                Badge(linkedWishlistItem.purchaseHandoff == nil ? "No handoff" : "Handoff staged", color: linkedWishlistItem.purchaseHandoff == nil ? .orange : .green)
                Badge(linkedWishlistItem.purchaseHandoff?.linkedOrderID == nil ? "No linked order" : "Order linked", color: linkedWishlistItem.purchaseHandoff?.linkedOrderID == nil ? .orange : .green)
              }
              Text("Use the packet to prepare a local handoff and order-watch rule before any manual buying outside ParcelOps.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          if !inboxOrders.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Label("Inbox draft source", systemImage: "tray.and.arrow.down.fill")
                .font(.caption.bold())
                .foregroundStyle(.teal)
              ForEach(inboxOrders.prefix(2)) { order in
                HStack(spacing: 6) {
                  Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
                  Badge(order.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: order.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
                  Text(order.customer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              if let store {
                ForEach(sourceEmails(using: store).prefix(2)) { email in
                  HStack(spacing: 6) {
                    let source = store.intakeSourceSummary(for: email)
                    Badge(source.label, color: sourceColor(for: source.tone))
                    Text(email.subject)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
              }
            }
          }

          if let store {
            OrderMailboxSourceTrailPanel(
              summaries: mailboxSummaries(using: store),
              title: "Mailbox provider draft trail",
              symbol: "envelope.open.fill"
            )
          }

          if !draftWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Label("Draft follow-up", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)
              ForEach(draftWarnings, id: \.self) { warning in
                Text(warning)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      if let feedbackMessage {
        CommunicationActionFeedbackPanel(message: feedbackMessage, store: store)
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
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Ready", systemImage: "checkmark.circle.fill") {
          onReady()
          feedbackMessage = "Draft marked ready locally. Send it outside ParcelOps, then mark sent locally."
        }
          .buttonStyle(.bordered)
        Button("Sent locally", systemImage: "paperplane.fill") {
          onSent()
          feedbackMessage = "Draft marked sent locally."
        }
          .buttonStyle(.borderedProminent)
        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
          onReopen()
          feedbackMessage = "Draft reopened for follow-up."
        }
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus") {
          onCreateContact()
          feedbackMessage = "Contact placeholder created from draft."
        }
          .buttonStyle(.bordered)
        if let store, let linkedWishlistItem, isWishlistPurchasePacketDraft {
          Button("Prepare handoff/watch", systemImage: "envelope.badge.fill") {
            store.prepareWishlistPurchaseHandoff(linkedWishlistItem)
            feedbackMessage = "Wishlist purchase handoff and order-watch record prepared locally."
          }
          .buttonStyle(.bordered)
        }
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Draft removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      DraftMessageEditView(draft: draft) { updatedDraft in
        onSave(updatedDraft)
        feedbackMessage = "Draft saved locally."
      }
    }
  }

  private var draftWarnings: [String] {
    var warnings: [String] = []
    if draft.linkedEntityType == .wishlistItem && draft.subject.localizedCaseInsensitiveContains("wishlist purchase packet") {
      warnings.append("Wishlist purchase packet: review seller, AUD total, postage, trust, approvals, purchase links, account context, and order-watch notes before any manual buying.")
      warnings.append("Local boundary: ParcelOps does not open retailer links, log in, buy, pay, or monitor orders in the background.")
    }
    if draft.status == .ready && !inboxOrders.isEmpty {
      warnings.append("Draft is ready. Send it outside ParcelOps, then mark sent locally.")
    }
    if draft.status != .sentLocally && draft.status != .ready && !inboxOrders.isEmpty {
      warnings.append("Draft is still open for an Inbox-created order.")
    }
    if draft.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Draft needs review before related handoff work is closed.")
    }
    if draft.recipient.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Recipient needs confirmation.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      return store.linkedIntakeEmails(for: order)
    }.filter { seen.insert($0.id).inserted }
  }

  private func mailboxSummaries(using store: ParcelOpsStore) -> [OrderMailboxSourceSummary] {
    var seen = Set<String>()
    return inboxOrders.flatMap { order in
      store.mailboxSourceSummaries(for: order)
    }.filter { seen.insert($0.id).inserted }
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

private struct CommunicationActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      Text("This is a local communication workflow action. ParcelOps still does not send outbound email.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink {
              CommunicationView(store: store)
            } label: {
              Label("Open Drafts", systemImage: "envelope.open.fill")
            }
          }
          if message.localizedCaseInsensitiveContains("contact") {
            NavigationLink {
              ContactsView(store: store)
            } label: {
              Label("Open Contacts", systemImage: "person.2.fill")
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
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct CommunicationTemplateEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CommunicationTemplate
  var onSave: (CommunicationTemplate) -> Void

  init(template: CommunicationTemplate, onSave: @escaping (CommunicationTemplate) -> Void) {
    self._draft = State(initialValue: template)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Template") {
          TextField("Name", text: $draft.name)
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Subject template", text: $draft.subjectTemplate)
          TextField("Body template", text: $draft.bodyTemplate, axis: .vertical)
            .lineLimit(4...8)
          Picker("Channel", selection: $draft.channel) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last used", text: $draft.lastUsedDate)
          Stepper("Usage count: \(draft.usageCount)", value: $draft.usageCount, in: 0...999)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit template")
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

struct DraftMessageEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DraftMessage
  var onSave: (DraftMessage) -> Void

  init(draft: DraftMessage, onSave: @escaping (DraftMessage) -> Void) {
    self._draft = State(initialValue: draft)
    self.onSave = onSave
  }

  private var templateIDBinding: Binding<String> {
    Binding(
      get: { draft.templateID?.uuidString ?? "" },
      set: { value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.templateID = trimmed.isEmpty ? nil : UUID(uuidString: trimmed)
      }
    )
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Linked record") {
          Picker("Record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
          TextField("Template ID", text: templateIDBinding)
        }

        Section("Message") {
          TextField("Recipient", text: $draft.recipient)
          TextField("Subject", text: $draft.subject)
          TextField("Body", text: $draft.body, axis: .vertical)
            .lineLimit(5...10)
          Picker("Channel", selection: $draft.channel) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("State") {
          TextField("Created date", text: $draft.createdDate)
          Picker("Status", selection: $draft.status) {
            ForEach(DraftMessageStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit draft")
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
