import SwiftUI

@main
struct ParcelOpsApp: App {
  var body: some Scene {
    WindowGroup {
      ParcelOpsRootView()
        .parcelOpsWindowFrame()
    }
  }
}

extension View {
  @ViewBuilder
  func parcelOpsWindowFrame() -> some View {
    #if os(macOS)
    self.frame(minWidth: 1120, minHeight: 760)
    #else
    self
    #endif
  }
}

struct ParcelOpsRootView: View {
  @State private var store = ParcelOpsStore()
  @State private var selection: ParcelSection = .dashboard
  @State private var isMoreMenuExpanded = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    GeometryReader { proxy in
      let usePhoneLayout = horizontalSizeClass == .compact || proxy.size.width < 700

      if usePhoneLayout {
        NavigationStack {
          content(for: selection)
            .navigationTitle(selection.title)
        }
        .safeAreaInset(edge: .bottom) {
          ExpandableBottomMenu(selection: $selection, isExpanded: $isMoreMenuExpanded) { section in
            withAnimation(.snappy) {
              selection = section
            }
          }
        }
      } else {
        NavigationSplitView {
          List {
            ForEach(ParcelSection.allCases) { section in
              Button {
                selection = section
              } label: {
                Label(section.title, systemImage: section.symbol)
                  .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
              }
              .buttonStyle(.plain)
            }
          }
          .navigationTitle("ParcelOps")
          .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
              Label("Review required", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
              Text("\(store.reviewQueueCount) items are waiting for review.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
          }
        } detail: {
          content(for: selection)
            .navigationTitle(selection.title)
        }
      }
    }
    .tint(.teal)
  }

  @ViewBuilder
  private func content(for section: ParcelSection) -> some View {
    switch section {
    case .dashboard:
      DashboardView(store: store)
    case .orders:
      OrdersView(store: store)
    case .mailbox:
      MailboxView(store: store)
    case .review:
      NeedsReviewView(store: store)
    case .wishlist:
      WishlistView(store: store)
    case .integrations:
      IntegrationsView(store: store)
    case .automation:
      AutomationView(store: store)
    case .tracking:
      TrackingView(store: store)
    case .evidence:
      EvidenceView(store: store)
    case .tasks:
      TasksView(store: store)
    case .slaPolicies:
      SLAPoliciesView(store: store)
    case .communication:
      CommunicationView(store: store)
    case .contacts:
      ContactsView(store: store)
    case .accounts:
      AccountsView(store: store)
    case .search:
      SearchView(store: store)
    case .audit:
      AuditView(store: store)
    case .settings:
      SettingsView(store: store)
    }
  }
}

struct ExpandableBottomMenu: View {
  @Binding var selection: ParcelSection
  @Binding var isExpanded: Bool
  var onSelect: (ParcelSection) -> Void

  private var primaryItems: [ParcelSection] {
    [.dashboard, .orders, .tasks, .review]
  }

  private var secondaryItems: [ParcelSection] {
    [.wishlist, .mailbox, .search, .communication, .contacts, .accounts, .integrations, .tracking, .evidence, .slaPolicies, .automation, .audit, .settings]
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 0) {
        ForEach(primaryItems) { section in
          BottomMenuButton(title: section.shortTitle, symbol: section.symbol, isSelected: selection == section) {
            withAnimation(.snappy) {
              isExpanded = false
              onSelect(section)
            }
          }
        }

        BottomMenuButton(title: isExpanded ? "Less" : "More", symbol: isExpanded ? "arrow.down" : "arrow.up", isSelected: isExpanded) {
          withAnimation(.snappy) {
            isExpanded.toggle()
          }
        }
      }

      if isExpanded {
        HStack(spacing: 0) {
          ForEach(secondaryItems) { section in
            BottomMenuButton(title: section.shortTitle, symbol: section.symbol, isSelected: selection == section) {
              onSelect(section)
            }
          }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 10)
    .padding(.top, 10)
    .padding(.bottom, 8)
    .background(.bar)
  }
}

struct BottomMenuButton: View {
  var title: String
  var symbol: String
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .semibold))
        Text(title)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}
