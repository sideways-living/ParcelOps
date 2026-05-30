import SwiftUI

struct WishlistView: View {
  var store: ParcelOpsStore
  @State private var showDeletedItems = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Wishlist")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Per-user purchase ideas can be captured from files, screenshots, browser sharing, or extensions before converting to orders.")
            .foregroundStyle(.secondary)
        }

        HStack {
          Button("Upload PDF", systemImage: "doc.badge.plus", action: store.uploadWishlistPDFPlaceholder)
          Button("Add screenshot", systemImage: "photo.badge.plus", action: store.addWishlistScreenshotPlaceholder)
          Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
        }
        .buttonStyle(.bordered)

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF upload", detail: "Parse supplier PDFs and invoices for storefront, item name, price, and order clues.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot upload", detail: "Extract storefront URL, item title, visible price, and availability from saved screenshots.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "iOS and macOS Share", detail: "Accept shared web pages from Safari or another browser into the signed-in user's wishlist.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Chrome and Firefox extension", detail: "Browser extension capture path for desktop browsers and Android phones.")
        }

        SettingsPanel(title: "Wishlist items", symbol: "star.square.fill") {
          ForEach(store.wishlistItems) { item in
            WishlistItemRow(item: item) {
              store.convertWishlistToOrder(item)
            } onLink: {
              store.linkWishlistItemToOrder(item)
            } onDelete: {
              store.deleteWishlistItem(item)
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
          Button("Restore", systemImage: "arrow.uturn.backward", action: onConvert)
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Restore")
          Button("Delete now", systemImage: "trash.fill", action: onDelete)
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
          Button("Convert to order", systemImage: "shippingbox.fill", action: onConvert)
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Convert to order")
          Button("Link order", systemImage: "link", action: onLink)
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Link to existing order")
          Button("Delete", systemImage: "trash", action: onDelete)
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Move to deleted items")
        }
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
