import SwiftUI

struct WishlistView: View {
  var store: ParcelOpsStore
  @State private var showDeletedItems = false
  @State private var wishlistSearchText = ""
  @State private var selectedSource: WishlistSource?
  @State private var selectedStatus: String?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var statuses: [String] {
    Array(Set(store.wishlistItems.map(\.status))).sorted()
  }

  private let wishlistSources: [WishlistSource] = [.pdf, .screenshot, .shareSheet, .browserExtension, .manual]

  private var baseFilteredItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      let matchesSource = selectedSource == nil || item.source == selectedSource
      let matchesStatus = selectedStatus == nil || item.status == selectedStatus
      return matchesSource && matchesStatus
    }
  }

  private var filteredItems: [WishlistItem] {
    let query = wishlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredItems }
    return baseFilteredItems.filter { item in
      [
        item.id.uuidString,
        item.itemName,
        item.storefront,
        item.storefrontURL,
        item.estimatedCost,
        item.owner,
        item.pool,
        item.source.rawValue,
        item.status,
        item.capturedDetail
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedSource != nil
      || selectedStatus != nil
      || !wishlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var gmailWishlistCandidateEmails: [ForwardedEmailIntake] {
    store.intakeEmails
      .filter { email in
        store.intakeSourceSummary(for: email).tone == "gmail"
          && gmailWishlistCandidateScore(for: email) > 0
      }
      .sorted(by: { first, second in
        let firstScore = gmailWishlistCandidateScore(for: first)
        let secondScore = gmailWishlistCandidateScore(for: second)
        if firstScore == secondScore {
          return first.receivedDate > second.receivedDate
        }
        return firstScore > secondScore
      })
  }

  private var gmailWishlistReadyCount: Int {
    gmailWishlistCandidateEmails.filter { email in
      !email.detectedMerchant.isPlaceholderValidationValue
        || !email.detectedOrderNumber.isPlaceholderValidationValue
        || !email.subject.isPlaceholderValidationValue
    }.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Wishlist")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Per-user purchase ideas can be staged locally before becoming orders. File, screenshot, share, and extension capture are placeholder paths unless explicitly implemented.")
            .foregroundStyle(.secondary)
        }

        HStack {
          Button("PDF placeholder", systemImage: "doc.badge.plus", action: store.uploadWishlistPDFPlaceholder)
          Button("Screenshot placeholder", systemImage: "photo.badge.plus", action: store.addWishlistScreenshotPlaceholder)
          Button("Browser capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
        }
        .buttonStyle(.bordered)

        wishlistReadinessPanel
        wishlistCaptureCandidatesPanel
        wishlistComparisonPlanningPanel
        gmailWishlistFocusPanel
        filterBar

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF placeholder", detail: "Creates a local test item only. No file picker, OCR, or PDF parser runs from this screen.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot placeholder", detail: "Creates a local test item only. No screenshot picker, OCR, or image parser runs from this screen.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "Share path placeholder", detail: "Documents a future share-sheet flow. ParcelOps does not receive shared browser pages yet.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Browser capture staging", detail: "Creates or reviews local capture candidates in the staging queue. No browser extension, scraping, or external sync is active here.")
        }

        SettingsPanel(title: "Wishlist items", symbol: "star.square.fill") {
          HStack {
            Text("\(filteredItems.count) visible wishlist items")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredItems.count) after filters", color: .blue)
            }
            Spacer()
            Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredItems.isEmpty {
            MVPEmptyState(title: "No wishlist items match this view", detail: hasActiveFilters ? "Clear search or filters to return to all active wishlist items." : "Add a manual wishlist item or use a placeholder capture action to test wishlist-to-order handoff.", symbol: "star.square.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Manual item", action: hasActiveFilters ? clearFilters : store.addManualWishlistItemPlaceholder)
          } else {
            ForEach(filteredItems) { item in
              WishlistItemRow(item: item) {
                store.convertWishlistToOrder(item)
              } onLink: {
                store.linkWishlistItemToOrder(item)
              } onCompare: {
                store.createWishlistComparisonPlan(item)
              } onScore: {
                store.evaluateWishlistComparisonOptions(item)
              } onCheck: {
                store.runWishlistPurchaseReadinessCheck(item)
              } onHandoff: {
                store.prepareWishlistPurchaseHandoff(item)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(item)
              } onOrderSeen: {
                store.markWishlistOrderConfirmationSeen(item)
              } onReady: {
                store.markWishlistReadyForPurchase(item)
              } onPreferredOption: { option in
                store.markWishlistPreferredOption(item, option: option)
              } onTask: {
                store.createReviewTask(from: item)
              } onDraft: {
                store.createDraftMessage(from: item)
              } onDelete: {
                store.deleteWishlistItem(item)
              }
            }
          }
        }

        SettingsPanel(title: "Deleted items", symbol: "trash.fill") {
          Button {
            withAnimation(.snappy) {
              showDeletedItems.toggle()
            }
          } label: {
            HStack {
              Label("\(store.deletedWishlistItems.count) deleted item", systemImage: showDeletedItems ? "folder.fill.badge.minus" : "folder.fill")
              Spacer()
              Image(systemName: showDeletedItems ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          if showDeletedItems {
            Text("Deleted wishlist items are retained for 90 days before permanent removal.")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(store.deletedWishlistItems) { item in
              WishlistItemRow(item: item, isDeleted: true) {
                store.restoreWishlistItem(item)
              } onLink: {
                store.permanentlyDeleteWishlistItem(item)
              } onCompare: {
                store.restoreWishlistItem(item)
              } onScore: {
                store.restoreWishlistItem(item)
              } onCheck: {
                store.restoreWishlistItem(item)
              } onHandoff: {
                store.restoreWishlistItem(item)
              } onPurchased: {
                store.restoreWishlistItem(item)
              } onOrderSeen: {
                store.restoreWishlistItem(item)
              } onReady: {
                store.restoreWishlistItem(item)
              } onPreferredOption: { _ in
                store.restoreWishlistItem(item)
              } onTask: {
                store.restoreWishlistItem(item)
              } onDraft: {
                store.restoreWishlistItem(item)
              } onDelete: {
                store.permanentlyDeleteWishlistItem(item)
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
      TextField("Search item, store, URL, cost, owner, pool, source, or captured detail", text: $wishlistSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Source", selection: $selectedSource) {
        Text("All sources").tag(nil as WishlistSource?)
        ForEach(wishlistSources, id: \.self) { source in
          Text(source.rawValue).tag(source as WishlistSource?)
        }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as String?)
        ForEach(statuses, id: \.self) { status in
          Text(status).tag(status as String?)
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
    wishlistSearchText = ""
    selectedSource = nil
    selectedStatus = nil
  }

  private var wishlistReadinessPanel: some View {
    let activeItems = store.wishlistItems
    let readyItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("ready") }
    let reviewItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("review") }
    let linkedItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("linked") }
    let placeholderItems = activeItems.filter { item in
      item.storefront.isPlaceholderValidationValue
        || item.estimatedCost.isPlaceholderValidationValue
        || item.capturedDetail.localizedCaseInsensitiveContains("placeholder")
    }
    let itemsNeedingReadiness = uniqueWishlistItems(reviewItems + placeholderItems)

    return SettingsPanel(title: "Wishlist-to-order readiness", symbol: "star.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use Wishlist as a local staging area only. Convert to an order when item, storefront, owner, cost, and purchase intent are clear enough to hand off into Orders.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 135) {
          Badge("\(activeItems.count) active", color: activeItems.isEmpty ? .secondary : .blue)
          Badge("\(readyItems.count) ready", color: readyItems.isEmpty ? .secondary : .green)
          Badge("\(reviewItems.count) needs review", color: reviewItems.isEmpty ? .green : .orange)
          Badge("\(linkedItems.count) linked", color: linkedItems.isEmpty ? .secondary : .teal)
          Badge("\(placeholderItems.count) placeholders", color: placeholderItems.isEmpty ? .green : .orange)
          Badge("\(store.deletedWishlistItems.count) deleted", color: store.deletedWishlistItems.isEmpty ? .secondary : .gray)
        }

        if activeItems.isEmpty {
          MVPEmptyState(
            title: "No active wishlist items",
            detail: "Add a manual item or placeholder capture item to test wishlist-to-order handoff locally.",
            symbol: "star.square.fill"
          )
        } else if reviewItems.isEmpty && placeholderItems.isEmpty {
          Label("Active wishlist items look ready for local linking or order conversion.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Review before converting")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(Array(itemsNeedingReadiness.prefix(4))) { item in
              WishlistReadinessRow(item: item)
            }
            let remaining = max(itemsNeedingReadiness.count - 4, 0)
            if remaining > 0 {
              Text("\(remaining) more wishlist items need review before conversion.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var wishlistComparisonPlanningPanel: some View {
    let activeItems = store.wishlistItems
    let comparedItems = activeItems.filter { !($0.comparisonOptions ?? []).isEmpty }
    let purchaseReadyItems = activeItems.filter {
      $0.status.localizedCaseInsensitiveContains("ready to purchase")
        || ($0.purchaseReadiness ?? "").localizedCaseInsensitiveContains("ready")
    }
    let trustReviewItems = activeItems.filter {
      ($0.comparisonOptions ?? []).contains { option in
        option.trustRating.localizedCaseInsensitiveContains("unknown")
          || option.trustRating.localizedCaseInsensitiveContains("review")
      }
    }

    return SettingsPanel(title: "Purchase comparison planning", symbol: "magnifyingglass.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the local planning boundary for the future shopping agent. A real agent should compare Australian and overseas sellers, convert totals to AUD, include postage costs and delivery times, and reject low-trust sellers before a human buys anything.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Wishlist", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .blue),
          ("Compared", "\(comparedItems.count)", comparedItems.isEmpty ? .secondary : .teal),
          ("Ready", "\(purchaseReadyItems.count)", purchaseReadyItems.isEmpty ? .secondary : .green),
          ("Trust review", "\(trustReviewItems.count)", trustReviewItems.isEmpty ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 240), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistPlanningStep(number: "1", title: "Capture item", detail: "Manual entry, share sheet, screenshot, PDF, or future browser extension records item and source URL locally.")
          WishlistPlanningStep(number: "2", title: "Compare sellers", detail: "Future agent should check AU and overseas retailers, AUD landed cost, postage, delivery time, returns, and warranty.")
          WishlistPlanningStep(number: "3", title: "Trust filter", detail: "Seller trust must beat price. Low-trust or unknown sellers should stay blocked until reviewed.")
          WishlistPlanningStep(number: "4", title: "Purchase handoff", detail: "Only after a seller is selected should the item become ready to purchase or convert to a local order draft.")
        }

        Text("Not active yet: live web search, retailer scraping, currency feeds, postage quote APIs, browser extension capture, account detection, checkout automation, purchase monitoring, and payment handling.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistCaptureCandidatesPanel: some View {
    SettingsPanel(title: "Capture candidate staging", symbol: "puzzlepiece.extension.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review local product-page capture candidates before they become Wishlist items. This is the boundary a future browser extension or share flow can write into; this screen does not install an extension, scrape pages, or sync with a browser.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(store.wishlistCaptureCandidates.count) staged", color: store.wishlistCaptureCandidates.isEmpty ? .secondary : .blue)
          Badge("\(store.wishlistCaptureCandidates.filter { $0.reviewState == .needsReview }.count) needs review", color: store.wishlistCaptureCandidates.contains { $0.reviewState == .needsReview } ? .orange : .green)
          Badge("\(store.wishlistCaptureCandidates.filter { $0.source == .browserExtension }.count) extension path", color: .teal)
        }

        CompactActionRow {
          Button("Add browser capture placeholder", systemImage: "puzzlepiece.extension.fill") {
            store.addBrowserExtensionWishlistCapturePlaceholder()
          }
        }
        .buttonStyle(.bordered)

        if store.wishlistCaptureCandidates.isEmpty {
          MVPEmptyState(
            title: "No staged capture candidates",
            detail: "Use the browser capture placeholder to test the future extension handoff without reading any browser page or contacting external services.",
            symbol: "puzzlepiece.extension.fill",
            actionTitle: "Add placeholder",
            action: store.addBrowserExtensionWishlistCapturePlaceholder
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 320), spacing: 10)], spacing: 10) {
            ForEach(store.wishlistCaptureCandidates) { capture in
              WishlistCaptureCandidateRow(capture: capture) {
                store.promoteWishlistCaptureToItem(capture)
              } onDismiss: {
                store.dismissWishlistCapture(capture)
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var gmailWishlistFocusPanel: some View {
    if !store.gmailMailboxConnections.isEmpty || !gmailWishlistCandidateEmails.isEmpty {
      SettingsPanel(title: "Gmail wishlist focus", symbol: "envelope.badge.shield.half.filled") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Gmail messages sometimes contain purchase intent rather than active orders. Keep those out of Orders until a person confirms the item, storefront, owner, and whether it should become a wishlist item.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Gmail candidates", "\(gmailWishlistCandidateEmails.count)", gmailWishlistCandidateEmails.isEmpty ? .secondary : .blue),
            ("Ready signals", "\(gmailWishlistReadyCount)", gmailWishlistReadyCount == 0 ? .secondary : .teal),
            ("Wishlist items", "\(store.wishlistItems.count)", store.wishlistItems.isEmpty ? .secondary : .green),
            ("Needs review", "\(store.wishlistItems.filter { $0.status.localizedCaseInsensitiveContains("review") }.count)", store.wishlistItems.contains { $0.status.localizedCaseInsensitiveContains("review") } ? .orange : .green)
          ])

          if gmailWishlistCandidateEmails.isEmpty {
            Label("No Gmail-origin purchase-intent candidates are visible. Use Mailbox Monitor for Gmail refresh and classifier review before adding wishlist items manually.", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Review Gmail purchase signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 260), spacing: 10)], spacing: 10) {
                ForEach(gmailWishlistCandidateEmails.prefix(4)) { email in
                  VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                      Label("Gmail intake", systemImage: "envelope.badge.shield.half.filled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                      Spacer(minLength: 8)
                      Badge(gmailWishlistCandidateLabel(for: email), color: gmailWishlistCandidateScore(for: email) > 2 ? .orange : .teal)
                    }
                    Text(email.subject.isPlaceholderValidationValue ? email.detectedMerchant : email.subject)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(gmailWishlistCandidateDetail(for: email))
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  .padding(10)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
              }
            }
          }

          CompactActionRow {
            Button("Manual wishlist item", systemImage: "plus") {
              store.addManualWishlistItemPlaceholder()
            }
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Inbox", systemImage: "tray.full.fill")
            }
          }
          .buttonStyle(.bordered)

          Text("This panel reads only local Gmail intake summaries. It does not fetch Gmail, create wishlist items automatically, open shopfronts automatically, store token values, or mutate mailbox messages.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func gmailWishlistCandidateScore(for email: ForwardedEmailIntake) -> Int {
    let text = [email.subject, email.rawBodyPreview, email.detectedMerchant, email.detectedDestinationAddress]
      .joined(separator: " ")
      .localizedLowercase
    var score = 0
    if text.contains("wishlist") || text.contains("wish list") { score += 3 }
    if text.contains("want to buy") || text.contains("would like to buy") || text.contains("looking to buy") { score += 3 }
    if text.contains("purchase") || text.contains("quote") || text.contains("price") || text.contains("stock") { score += 2 }
    if text.contains("recommend") || text.contains("replacement") || text.contains("supplier") || text.contains("vendor") { score += 1 }
    if !email.detectedMerchant.isPlaceholderValidationValue { score += 1 }
    if !email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue { score -= 3 }
    return max(score, 0)
  }

  private func gmailWishlistCandidateLabel(for email: ForwardedEmailIntake) -> String {
    let score = gmailWishlistCandidateScore(for: email)
    if score >= 4 { return "Likely wishlist" }
    if score > 0 { return "Possible wishlist" }
    return "Review"
  }

  private func gmailWishlistCandidateDetail(for email: ForwardedEmailIntake) -> String {
    var parts: [String] = []
    if !email.detectedMerchant.isPlaceholderValidationValue { parts.append("merchant: \(email.detectedMerchant)") }
    if !email.detectedOrderNumber.isPlaceholderValidationValue { parts.append("order already detected") }
    if !email.detectedTrackingNumber.isPlaceholderValidationValue { parts.append("tracking already detected") }
    if parts.isEmpty { parts.append("confirm item, storefront, and purchase intent before adding a manual wishlist item") }
    return parts.joined(separator: "; ")
  }

  private func uniqueWishlistItems(_ items: [WishlistItem]) -> [WishlistItem] {
    var seen = Set<UUID>()
    return items.filter { item in
      if seen.contains(item.id) { return false }
      seen.insert(item.id)
      return true
    }
  }
}

private struct WishlistReadinessRow: View {
  var item: WishlistItem

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.source.symbol)
        .foregroundStyle(.teal)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
        Text(readinessDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Badge(item.status, color: item.status.localizedCaseInsensitiveContains("review") ? .orange : .blue)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var readinessDetail: String {
    if item.capturedDetail.localizedCaseInsensitiveContains("placeholder") {
      return "Placeholder capture. Confirm item, storefront, owner, and purchase intent before creating an order."
    }
    if item.storefront.isPlaceholderValidationValue {
      return "Storefront needs review before this becomes an order."
    }
    if item.estimatedCost.isPlaceholderValidationValue {
      return "Estimated cost needs review before handoff."
    }
    if item.status.localizedCaseInsensitiveContains("review") {
      return "Review status is still open. Confirm details before linking or converting."
    }
    return "Ready for local link or conversion when purchase intent is confirmed."
  }
}

struct CaptureChannelRow: View {
  var symbol: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCaptureCandidateRow: View {
  var capture: WishlistCaptureCandidate
  var onPromote: () -> Void
  var onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: capture.source.symbol)
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(capture.pageTitle.isPlaceholderValidationValue ? "Captured product page" : capture.pageTitle)
            .font(.headline)
            .lineLimit(2)
          Text(capture.productSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(capture.reviewState.rawValue, color: capture.reviewState == .needsReview ? .orange : .blue)
      }

      CompactMetadataGrid(minimumWidth: 120) {
        Label(capture.source.rawValue, systemImage: capture.source.symbol)
        Label(capture.detectedStorefront, systemImage: "storefront.fill")
        Label(capture.detectedPrice, systemImage: "dollarsign.circle.fill")
        Label(capture.capturedDate, systemImage: "clock.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if !capture.pageURL.isPlaceholderValidationValue {
        Text(capture.pageURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(capture.notes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Promote to Wishlist", systemImage: "star.square.fill", action: onPromote)
          .buttonStyle(.borderedProminent)
        Button("Dismiss", systemImage: "xmark.circle", action: onDismiss)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPlanningStep: View {
  var number: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(number)
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(.teal, in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistItemRow: View {
  var item: WishlistItem
  var isDeleted = false
  var onConvert: () -> Void
  var onLink: () -> Void
  var onCompare: () -> Void
  var onScore: () -> Void
  var onCheck: () -> Void
  var onHandoff: () -> Void
  var onPurchased: () -> Void
  var onOrderSeen: () -> Void
  var onReady: () -> Void
  var onPreferredOption: (WishlistComparisonOption) -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onDelete: () -> Void
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(.teal)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.itemName)
            .font(.headline)
          Text("\(item.storefront) • \(item.estimatedCost)")
            .foregroundStyle(.secondary)
          Text(item.storefrontURL)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(item.owner) • \(item.pool)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(item.status, color: .blue)
      }
      Text(item.capturedDetail)
        .font(.caption)
        .foregroundStyle(.secondary)

      wishlistComparisonSummary
      wishlistPurchaseChecksSummary
      wishlistPurchaseHandoffSummary

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
        if isDeleted {
          Button("Restore", systemImage: "arrow.uturn.backward") {
            onConvert()
            feedbackMessage = "Wishlist item restored locally. Confirm details before linking or converting it to an order."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Restore")
          Button("Delete now", systemImage: "trash.fill") {
            onDelete()
            feedbackMessage = "Wishlist item deleted locally. No shopfront, mailbox, payment, or order system was contacted."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Delete permanently")
        } else {
          if let url = URL(string: item.storefrontURL) {
            Link(destination: url) {
              Label("Open shopfront", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.iconOnly)
            .help("Open shopfront")
            ShareLink(item: url) {
              Label("Share link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Share link")
          }
          Button("Convert to order", systemImage: "shippingbox.fill") {
            onConvert()
            feedbackMessage = "Wishlist item converted locally. Check Orders before any dispatch or purchase follow-up."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Convert to order")
          Button("Link order", systemImage: "link") {
            onLink()
            feedbackMessage = "Wishlist item linked locally. Review the order context before closing this capture."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Link to existing order")
          Button("Compare sellers", systemImage: "magnifyingglass.circle") {
            onCompare()
            feedbackMessage = "Local comparison plan created. No web search, retailer scrape, currency lookup, postage quote, or trust service was contacted."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create local seller comparison plan")
          Button("Score options", systemImage: "chart.bar.doc.horizontal") {
            onScore()
            feedbackMessage = "Seller options scored locally from existing comparison fields. Verify live price, postage, trust, returns, and account readiness before buying."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Score seller options locally")
          Button("Ready to buy", systemImage: "checkmark.seal") {
            onReady()
            feedbackMessage = "Wishlist item marked ready for purchase review locally. ParcelOps did not buy anything or store payment details."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Mark ready for purchase review")
          Button("Readiness", systemImage: "checklist.checked") {
            onCheck()
            feedbackMessage = "Purchase readiness checked locally. Fix blockers before buying externally."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Run local purchase readiness check")
          Button("Handoff", systemImage: "person.crop.circle.badge.checkmark") {
            onHandoff()
            feedbackMessage = "Manual purchase handoff prepared locally. Confirm account and payment outside ParcelOps."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Prepare manual purchase handoff")
          Button("Purchased", systemImage: "bag.fill") {
            onPurchased()
            feedbackMessage = "External purchase recorded locally. ParcelOps did not buy anything or store payment details."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Record external purchase")
          Button("Order seen", systemImage: "envelope.badge.fill") {
            onOrderSeen()
            feedbackMessage = "Order confirmation marked seen locally. Link the real order if needed."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Mark order confirmation seen")
          Button("Task", systemImage: "checklist") {
            onTask()
            feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create comparison review task")
          Button("Draft", systemImage: "envelope.open") {
            onDraft()
            feedbackMessage = "Wishlist purchase review draft created locally. No message was sent."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create purchase review draft")
          Button("Delete", systemImage: "trash") {
            onDelete()
            feedbackMessage = "Wishlist item moved to deleted locally. No external shopfront, mailbox, or order system was changed."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Move to deleted items")
        }
      }

      if let feedbackMessage {
        WishlistActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistComparisonSummary: some View {
    let options = item.comparisonOptions ?? []
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Comparison", systemImage: "magnifyingglass.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
        Spacer(minLength: 8)
        Badge(item.comparisonStatus ?? "Not compared", color: options.isEmpty ? .secondary : .teal)
        if let readiness = item.purchaseReadiness {
          Badge(readiness, color: readiness.localizedCaseInsensitiveContains("ready") ? .green : .orange)
        }
      }

      if let notes = item.comparisonNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(notes)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      if options.isEmpty {
        Text("No seller options yet. Create a local comparison plan before converting this to an order or buying externally.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        if let preferred = options.first(where: { $0.id == item.preferredOptionID }) {
          WishlistPreferredOptionSummary(option: preferred)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(options) { option in
            WishlistComparisonOptionCard(
              option: option,
              isPreferred: item.preferredOptionID == option.id
            ) {
              onPreferredOption(option)
              feedbackMessage = "Preferred seller selected locally. Confirm trust, postage, returns, and total AUD cost before purchase."
            }
          }
        }
      }
    }
    .padding(10)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistPurchaseChecksSummary: some View {
    let checks = item.purchaseChecks ?? []
    if !checks.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase readiness", systemImage: "checklist.checked")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.indigo)
          Spacer(minLength: 8)
          Badge("\(checks.filter { $0.status == "Passed" }.count) passed", color: .green)
          let reviewCount = checks.filter { $0.status != "Passed" }.count
          Badge("\(reviewCount) review", color: reviewCount == 0 ? .green : .orange)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(checks) { check in
            WishlistPurchaseCheckRow(check: check)
          }
        }
        Text("Readiness checks are local guidance only. Confirm live seller, price, account, payment, postage, returns, and delivery details outside ParcelOps before buying.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  @ViewBuilder
  private var wishlistPurchaseHandoffSummary: some View {
    if let handoff = item.purchaseHandoff {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase handoff", systemImage: "person.crop.circle.badge.checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Spacer(minLength: 8)
          Badge(handoff.purchaseStatus, color: handoff.purchaseStatus.localizedCaseInsensitiveContains("linked") ? .green : .purple)
        }
        CompactMetadataGrid(minimumWidth: 190) {
          PurchaseHandoffFact(title: "Seller", value: handoff.sellerName, symbol: "storefront.fill")
          PurchaseHandoffFact(title: "Account", value: handoff.accountLabel, symbol: "person.crop.circle.fill")
          PurchaseHandoffFact(title: "Order watch", value: handoff.orderWatchStatus, symbol: "envelope.badge.fill")
          PurchaseHandoffFact(title: "Updated", value: handoff.updatedAt, symbol: "clock.fill")
        }
        Text("Expected order signals: \(handoff.expectedOrderSignals)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(handoff.notes)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct WishlistPreferredOptionSummary: View {
  var option: WishlistComparisonOption

  private var color: Color {
    guard let risk = option.riskLevel else { return .teal }
    if risk.localizedCaseInsensitiveContains("lower") { return .green }
    if risk.localizedCaseInsensitiveContains("high") { return .red }
    return .orange
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(color)
      VStack(alignment: .leading, spacing: 3) {
        Text("Current best candidate: \(option.sellerName)")
          .font(.caption.weight(.semibold))
        Text("Local score \(option.localScore.map(String.init) ?? "not scored") • \(option.riskLevel ?? "risk not scored")")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(color)
        if let reason = option.decisionReason, !reason.isEmpty {
          Text(reason)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PurchaseHandoffFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(.purple)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseCheckRow: View {
  var check: WishlistPurchaseCheck

  private var color: Color {
    if check.status == "Passed" { return .green }
    if check.severity == "High" { return .red }
    return .orange
  }

  private var symbol: String {
    if check.status == "Passed" { return "checkmark.circle.fill" }
    if check.severity == "High" { return "exclamationmark.triangle.fill" }
    return "exclamationmark.circle.fill"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(check.title)
            .font(.caption.weight(.semibold))
          Badge(check.status, color: color)
        }
        Text(check.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonOptionCard: View {
  var option: WishlistComparisonOption
  var isPreferred: Bool
  var onPrefer: () -> Void

  private var trustColor: Color {
    if option.trustRating.localizedCaseInsensitiveContains("high") || option.trustRating.localizedCaseInsensitiveContains("trusted") { return .green }
    if option.trustRating.localizedCaseInsensitiveContains("review") || option.trustRating.localizedCaseInsensitiveContains("unknown") { return .orange }
    return .secondary
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(option.sellerName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Spacer(minLength: 8)
        Badge(isPreferred ? "Preferred" : option.recommendation, color: isPreferred ? .green : .blue)
      }
      Text("\(option.estimatedAUDTotal) • postage \(option.postageCost) • \(option.postageTime)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("\(option.sellerRegion) • trust: \(option.trustRating)")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(trustColor)
      if let score = option.localScore, let risk = option.riskLevel {
        Text("Local score \(score)/100 • \(risk)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(risk.localizedCaseInsensitiveContains("high") ? .red : trustColor)
      }
      if let reason = option.decisionReason, !reason.isEmpty {
        Text(reason)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      Text(option.trustNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)
      HStack {
        if let url = URL(string: option.productURL), !option.productURL.isPlaceholderValidationValue {
          Link(destination: url) {
            Label("Open seller", systemImage: "safari")
          }
          .buttonStyle(.bordered)
          .labelStyle(.iconOnly)
          .help("Open seller page")
        }
        Button(isPreferred ? "Preferred" : "Prefer", systemImage: isPreferred ? "checkmark.seal.fill" : "checkmark.seal") {
          onPrefer()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help(isPreferred ? "Preferred option" : "Select preferred option")
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background((isPreferred ? Color.green : trustColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistActionFeedbackPanel: View {
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
