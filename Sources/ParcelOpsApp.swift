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
  @State private var expandedDesktopGroupIDs: Set<String> = []
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
            Section("Daily Operations") {
              ForEach(ParcelNavigationGroup.dailyOperations.sections) { section in
                sidebarButton(for: section)
              }
            }

            Section {
              Text("Advanced records and setup views are still available, but the daily workflow starts above.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            }

            ForEach(ParcelNavigationGroup.secondaryDesktopGroups) { group in
              DisclosureGroup(isExpanded: desktopGroupBinding(for: group)) {
                ForEach(group.sections) { section in
                  sidebarButton(for: section)
                }
              } label: {
                HStack(spacing: 6) {
                  Text(group.title)
                  Spacer()
                  Text("\(group.sections.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quinary, in: Capsule())
                }
                .font(.subheadline.weight(.semibold))
              }
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
    .onOpenURL { url in
      store.handleMicrosoft365AuthCallback(url)
    }
  }

  private func desktopGroupBinding(for group: ParcelNavigationGroup) -> Binding<Bool> {
    Binding {
      expandedDesktopGroupIDs.contains(group.id) || group.sections.contains(selection)
    } set: { isExpanded in
      if isExpanded {
        expandedDesktopGroupIDs.insert(group.id)
      } else {
        expandedDesktopGroupIDs.remove(group.id)
      }
    }
  }

  private func sidebarButton(for section: ParcelSection) -> some View {
    Button {
      selection = section
    } label: {
      Label(section.title, systemImage: section.symbol)
        .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func content(for section: ParcelSection) -> some View {
    switch section {
    case .dashboard:
      DashboardView(store: store)
    case .inbox:
      InboxView(store: store)
    case .orders:
      OrdersView(store: store)
    case .workbench:
      OperationsWorkbenchView(store: store)
    case .dispatch:
      DispatchView(store: store)
    case .mvpSetup:
      MVPSetupView(store: store)
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
    case .handoffNotes:
      HandoffNotesView(store: store)
    case .slaPolicies:
      SLAPoliciesView(store: store)
    case .exceptionPlaybooks:
      ExceptionPlaybooksView(store: store)
    case .communication:
      CommunicationView(store: store)
    case .contacts:
      ContactsView(store: store)
    case .customerProfiles:
      CustomerProfilesView(store: store)
    case .destinationAddresses:
      DestinationAddressesView(store: store)
    case .deliveryInstructions:
      DeliveryInstructionsView(store: store)
    case .packageContents:
      PackageContentsView(store: store)
    case .costsBudgets:
      CostsBudgetsView(store: store)
    case .returnsClaims:
      ReturnsClaimsView(store: store)
    case .procurement:
      ProcurementView(store: store)
    case .receivingInspections:
      ReceivingInspectionsView(store: store)
    case .inventoryReceipts:
      InventoryReceiptsView(store: store)
    case .storageLocations:
      StorageLocationsView(store: store)
    case .custodyChain:
      CustodyChainView(store: store)
    case .labelReferences:
      LabelReferencesView(store: store)
    case .scanSessions:
      ScanSessionsView(store: store)
    case .shipmentManifests:
      ShipmentManifestsView(store: store)
    case .dispatchReadiness:
      DispatchReadinessView(store: store)
    case .accounts:
      AccountsView(store: store)
    case .vendorProfiles:
      VendorProfilesView(store: store)
    case .shipmentGroups:
      ShipmentGroupsView(store: store)
    case .importQueue:
      ImportQueueView(store: store)
    case .acceptanceReview:
      AcceptanceReviewView(store: store)
    case .reconciliation:
      ReconciliationView(store: store)
    case .timeline:
      TimelineView(store: store)
    case .validation:
      ValidationView(store: store)
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
    [.dashboard, .inbox, .orders, .workbench]
  }

  private var secondaryItems: [ParcelSection] {
    ParcelNavigationGroup.mobileSecondarySections
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
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 0) {
            ForEach(secondaryItems) { section in
              BottomMenuButton(title: section.shortTitle, symbol: section.symbol, isSelected: selection == section) {
                onSelect(section)
              }
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

struct ParcelNavigationGroup: Identifiable {
  var title: String
  var sections: [ParcelSection]
  var id: String { title }

  static let dailyOperations = ParcelNavigationGroup(title: "Daily Operations", sections: [.dashboard, .inbox, .orders, .workbench, .dispatch, .tasks, .audit, .settings])

  static let secondaryDesktopGroups: [ParcelNavigationGroup] = [
    ParcelNavigationGroup(title: "Advanced Workflow", sections: [.mvpSetup, .review, .mailbox, .importQueue, .acceptanceReview, .shipmentManifests, .dispatchReadiness, .tracking, .search, .timeline, .validation, .reconciliation, .handoffNotes]),
    ParcelNavigationGroup(title: "Supporting Records", sections: [.evidence, .shipmentGroups, .packageContents, .costsBudgets, .returnsClaims, .procurement, .receivingInspections, .inventoryReceipts, .storageLocations, .custodyChain, .labelReferences, .scanSessions]),
    ParcelNavigationGroup(title: "Admin & Reference", sections: [.integrations, .automation, .slaPolicies, .exceptionPlaybooks, .communication, .contacts, .customerProfiles, .destinationAddresses, .deliveryInstructions, .accounts, .vendorProfiles, .wishlist])
  ]

  static let desktopGroups: [ParcelNavigationGroup] = [
    dailyOperations
  ] + secondaryDesktopGroups

  static var mobileSecondarySections: [ParcelSection] {
    desktopGroups.flatMap(\.sections).filter { !dailyOperations.sections.prefix(4).contains($0) }
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
