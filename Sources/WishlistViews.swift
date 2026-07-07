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
          Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
        }
        .buttonStyle(.bordered)

        wishlistReadinessPanel
        gmailWishlistFocusPanel
        filterBar

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF placeholder", detail: "Creates a local test item only. No file picker, OCR, or PDF parser runs from this screen.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot placeholder", detail: "Creates a local test item only. No screenshot picker, OCR, or image parser runs from this screen.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "Share path placeholder", detail: "Documents a future share-sheet flow. ParcelOps does not receive shared browser pages yet.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Browser extension placeholder", detail: "Documents a future extension capture path. No browser extension or external sync is active here.")
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

struct WishlistItemRow: View {
  var item: WishlistItem
  var isDeleted = false
  var onConvert: () -> Void
  var onLink: () -> Void
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
