import SwiftUI

@main
struct ParcelOpsApp: App {
  var body: some Scene {
    WindowGroup {
      ParcelOpsRootView()
        .parcelOpsWindowFrame()
    }
    .commands {
      ParcelRouteCommands()
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

private struct ParcelRouteShortcut {
  var key: KeyEquivalent
  var label: String
  var modifiers: EventModifiers = .command
}

private struct ParcelSectionSelectionFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<ParcelSection>
}

private extension FocusedValues {
  var parcelSectionSelection: Binding<ParcelSection>? {
    get { self[ParcelSectionSelectionFocusedValueKey.self] }
    set { self[ParcelSectionSelectionFocusedValueKey.self] = newValue }
  }
}

private struct ParcelRouteCommands: Commands {
  @FocusedBinding(\.parcelSectionSelection) private var selection

  var body: some Commands {
    CommandMenu("Navigate") {
      Button("Dashboard") { selection = .dashboard }
        .keyboardShortcut("1", modifiers: .command)
        .disabled(selection == nil)
      Button("Inbox") { selection = .inbox }
        .keyboardShortcut("2", modifiers: .command)
        .disabled(selection == nil)
      Button("Orders") { selection = .orders }
        .keyboardShortcut("3", modifiers: .command)
        .disabled(selection == nil)
      Button("Workbench") { selection = .workbench }
        .keyboardShortcut("4", modifiers: .command)
        .disabled(selection == nil)
      Button("Dispatch") { selection = .dispatch }
        .keyboardShortcut("5", modifiers: .command)
        .disabled(selection == nil)
      Button("Tasks") { selection = .tasks }
        .keyboardShortcut("6", modifiers: .command)
        .disabled(selection == nil)
      Button("Audit") { selection = .audit }
        .keyboardShortcut("7", modifiers: .command)
        .disabled(selection == nil)
      Button("Settings") { selection = .settings }
        .keyboardShortcut("8", modifiers: .command)
        .disabled(selection == nil)
    }
  }
}

struct ParcelOpsRootView: View {
  @State private var store = ParcelOpsStore()
  @State private var selection: ParcelSection = .dashboard
  @State private var isMoreMenuExpanded = false
  @AppStorage("parcelops.showSecondaryDesktopGroups") private var showSecondaryDesktopGroups = false
  @State private var expandedDesktopGroupIDs: Set<String> = []
  @State private var sidebarSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isSearchingSidebar: Bool {
    !sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var desktopSearchResults: [ParcelNavigationGroup] {
    ParcelNavigationGroup.desktopGroupsMatching(sidebarSearchText)
  }

  private var selectionIsSecondaryDesktopRoute: Bool {
    ParcelNavigationGroup.secondaryDesktopGroups.flatMap(\.sections).contains(selection)
  }

  private var shouldShowSecondaryDesktopGroups: Bool {
    showSecondaryDesktopGroups || selectionIsSecondaryDesktopRoute
  }

  private var dailyAttentionCount: Int {
    store.reviewIntakeEmails.count
      + store.intakeParserDiagnostics.count
      + store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
      + store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) }
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.acceptanceRecordsNeedingReview.count
      + store.reviewOrders.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
  }

  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - dailyAttentionCount, 0)
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasLiveMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasLiveMailboxCredentialOrAuth: Bool {
    hasSpaceMailCredentialReference || hasGmailConnectedAuth
  }

  private var hasRealMailboxRefreshEvidence: Bool {
    (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      || store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || (latestGmailSummary?.fetchedCount ?? 0) > 0
      || store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var hasInboxOrderHandoff: Bool {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.contains { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }
  }

  private var mvpReadinessSignalCount: Int {
    [
      true,
      hasLiveMailboxSetup,
      hasLiveMailboxCredentialOrAuth,
      hasRealMailboxRefreshEvidence,
      hasInboxOrderHandoff,
      !store.auditEvents.isEmpty
    ].filter { $0 }.count
  }

  private var sidebarMVPStatusTitle: String {
    if mvpReadinessSignalCount >= 5 { return "MVP usable" }
    if mvpReadinessSignalCount >= 3 { return "MVP needs QA" }
    return "Setup needed"
  }

  private var sidebarMVPStatusColor: Color {
    if mvpReadinessSignalCount >= 5 { return .green }
    if mvpReadinessSignalCount >= 3 { return .teal }
    return .orange
  }

  private var sidebarMVPStatusDetail: String {
    if !hasLiveMailboxSetup { return "Add an active mailbox provider before live intake testing." }
    if !hasLiveMailboxCredentialOrAuth { return "Set the mailbox credential or complete provider sign-in." }
    if !hasRealMailboxRefreshEvidence { return "Run one manual read-only mailbox refresh." }
    if !hasInboxOrderHandoff { return "Create or link one order from Inbox." }
    if store.auditEvents.isEmpty { return "Perform one local action and confirm Audit." }
    return "Ready for a supervised daily-flow QA pass."
  }

  private var sidebarReadinessItems: [(title: String, isReady: Bool)] {
    [
      ("Setup", hasLiveMailboxSetup),
      ("Credential", hasLiveMailboxCredentialOrAuth),
      ("Refresh", hasRealMailboxRefreshEvidence),
      ("Order", hasInboxOrderHandoff),
      ("Audit", !store.auditEvents.isEmpty)
    ]
  }

  private var dailyFocusSections: [ParcelSection] {
    [.inbox, .orders, .workbench, .dispatch, .tasks]
  }

  private func routeShortcut(for section: ParcelSection) -> ParcelRouteShortcut? {
    switch section {
    case .dashboard: ParcelRouteShortcut(key: "1", label: "⌘1")
    case .inbox: ParcelRouteShortcut(key: "2", label: "⌘2")
    case .orders: ParcelRouteShortcut(key: "3", label: "⌘3")
    case .workbench: ParcelRouteShortcut(key: "4", label: "⌘4")
    case .dispatch: ParcelRouteShortcut(key: "5", label: "⌘5")
    case .tasks: ParcelRouteShortcut(key: "6", label: "⌘6")
    case .audit: ParcelRouteShortcut(key: "7", label: "⌘7")
    case .settings: ParcelRouteShortcut(key: "8", label: "⌘8")
    default: nil
    }
  }

  var body: some View {
    GeometryReader { proxy in
      let usePhoneLayout = horizontalSizeClass == .compact || proxy.size.width < 700

      if usePhoneLayout {
        NavigationStack {
          content(for: selection)
            .navigationTitle(selection.title)
        }
        .safeAreaInset(edge: .bottom) {
          ExpandableBottomMenu(
            selection: $selection,
            isExpanded: $isMoreMenuExpanded,
            readinessItems: sidebarReadinessItems,
            mvpStatusTitle: sidebarMVPStatusTitle,
            mvpStatusColor: sidebarMVPStatusColor,
            mvpStatusDetail: sidebarMVPStatusDetail,
            dailyAttentionCount: dailyAttentionCount
          ) { section in
            withAnimation(.snappy) {
              selection = section
            }
          } attentionCount: { section in
            attentionCount(for: section)
          }
        }
      } else {
        NavigationSplitView {
          List {
            if isSearchingSidebar {
              Section("Route Search") {
                if desktopSearchResults.isEmpty {
                  Text("No matching ParcelOps screens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                } else {
                  ForEach(desktopSearchResults) { group in
                    ForEach(group.sections) { section in
                      sidebarButton(for: section, context: group.title)
                    }
                  }
                }
              }
            } else {
              Section("Daily Focus") {
                sidebarDailyFocusSummary
                  .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 8, trailing: 10))
                  .listRowSeparator(.hidden)
              }

              Section("Primary Workflow") {
                ForEach(ParcelNavigationGroup.dailyOperations.sections) { section in
                  sidebarButton(for: section)
                }
              }

              Section {
                VStack(alignment: .leading, spacing: 8) {
                  Text("Reference records, setup screens, and detailed review tools are available when needed. Keep this hidden for daily operator work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                  Button {
                    withAnimation(.snappy) {
                      toggleSecondaryDesktopGroups()
                    }
                  } label: {
                    Label(advancedRoutesButtonTitle, systemImage: advancedRoutesButtonSymbol)
                      .font(.caption.weight(.semibold))
                  }
                  .buttonStyle(.bordered)

                  if selectionIsSecondaryDesktopRoute {
                    Text("An advanced route is currently selected, so the advanced groups stay visible until you return to the daily workflow.")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .padding(.vertical, 4)
              }

              if shouldShowSecondaryDesktopGroups {
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
            }

            Section {
              sidebarReviewFooter
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
          }
          .navigationTitle("ParcelOps")
          .searchable(text: $sidebarSearchText, placement: .sidebar, prompt: "Find a screen")
        } detail: {
          content(for: selection)
            .navigationTitle(selection.title)
        }
      }
    }
    .tint(.teal)
    .focusedSceneValue(\.parcelSectionSelection, $selection)
    .onOpenURL { url in
      store.handleMicrosoft365AuthCallback(url)
      store.handleGmailAuthCallback(url)
    }
  }

  private var sidebarDailyFocusSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Start with the row that has the highest active count. Advanced records stay hidden unless you need diagnostics.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(dailyFocusSections) { section in
          let count = attentionCount(for: section) ?? 0
          Button {
            selection = section
            sidebarSearchText = ""
          } label: {
            HStack(spacing: 5) {
              Image(systemName: section.symbol)
                .frame(width: 14)
              Text(section.shortTitle)
                .lineLimit(1)
              if count > 0 {
                Text("\(count)")
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 1)
                  .background(attentionColor(for: section, count: count), in: Capsule())
              }
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(selection == section ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
          }
          .buttonStyle(.plain)
          .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
      }
    }
  }

  private var sidebarReviewFooter: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: dailyAttentionCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(dailyAttentionCount == 0 ? .green : .orange)
          .frame(width: 18)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text("Daily attention")
              .font(.caption.weight(.semibold))
              .lineLimit(1)
            Badge("\(dailyAttentionCount)", color: dailyAttentionCount == 0 ? .green : .orange)
            Badge(sidebarMVPStatusTitle, color: sidebarMVPStatusColor)
          }

          Text(dailyAttentionCount == 0 ? sidebarMVPStatusDetail : "Start with Inbox, Orders, Workbench, Dispatch, or Tasks.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      HStack(spacing: 6) {
        ForEach(sidebarReadinessItems, id: \.title) { item in
          Image(systemName: item.isReady ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(item.isReady ? .green : .secondary)
            .help(item.title)
        }
        Spacer(minLength: 4)
        Text("Advanced \(advancedBacklogCount)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.bar)
  }

  private var advancedRoutesButtonTitle: String {
    if selectionIsSecondaryDesktopRoute {
      return "Return to daily focus"
    }
    return shouldShowSecondaryDesktopGroups ? "Hide advanced routes" : "Show advanced routes"
  }

  private var advancedRoutesButtonSymbol: String {
    if selectionIsSecondaryDesktopRoute {
      return "sidebar.left"
    }
    return shouldShowSecondaryDesktopGroups ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
  }

  private func toggleSecondaryDesktopGroups() {
    if selectionIsSecondaryDesktopRoute {
      selection = .dashboard
      showSecondaryDesktopGroups = false
      expandedDesktopGroupIDs.removeAll()
    } else {
      showSecondaryDesktopGroups.toggle()
      if !showSecondaryDesktopGroups {
        expandedDesktopGroupIDs.removeAll()
      }
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

  private func sidebarButton(for section: ParcelSection, context: String? = nil) -> some View {
    let count = attentionCount(for: section)

    return Button {
      selection = section
      if ParcelNavigationGroup.secondaryDesktopGroups.flatMap(\.sections).contains(section) {
        showSecondaryDesktopGroups = true
      }
      sidebarSearchText = ""
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          Label(section.title, systemImage: section.symbol)
            .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
          Spacer(minLength: 6)
          if let shortcut = routeShortcut(for: section) {
            Text(shortcut.label)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          if let count, count > 0 {
            Badge("\(count)", color: attentionColor(for: section, count: count))
          }
        }
        if let context {
          Text(context)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private func attentionCount(for section: ParcelSection) -> Int? {
    switch section {
    case .dashboard:
      return dailyAttentionCount
    case .inbox:
      return store.reviewIntakeEmails.count
        + store.intakeParserDiagnostics.count
        + store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
        + store.importQueueItemsNeedingReview.count
        + store.blockedImportQueueItems.count
        + store.acceptanceRecordsNeedingReview.count
    case .orders:
      return store.reviewOrders.count
        + store.orders.filter { $0.status == .exception }.count
        + store.trackingWarningCount
        + store.criticalTrackingCount
    case .workbench:
      return store.highPriorityWorkbenchItems.count
    case .dispatch:
      return store.blockedShipmentManifests.count
        + store.undispatchedShipmentManifests.count
        + store.blockedDispatchChecklists.count
        + store.incompleteDispatchChecklists.count
    case .tasks:
      return store.reviewTasksNeedingAttention.count
        + store.handoffNotesNeedingAttention.count
        + store.draftMessagesNeedingReview.count
    case .communication:
      return store.draftMessagesNeedingReview.count
    case .review:
      return dailyAttentionCount
    default:
      return nil
    }
  }

  private func attentionColor(for section: ParcelSection, count: Int) -> Color {
    guard count > 0 else { return .green }
    switch section {
    case .orders:
      return .red
    case .dispatch:
      return .orange
    case .workbench, .inbox, .review, .dashboard:
      return .teal
    case .tasks, .communication:
      return .purple
    default:
      return .secondary
    }
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
  @State private var routeSearchText = ""
  var readinessItems: [(title: String, isReady: Bool)]
  var mvpStatusTitle: String
  var mvpStatusColor: Color
  var mvpStatusDetail: String
  var dailyAttentionCount: Int
  var onSelect: (ParcelSection) -> Void
  var attentionCount: (ParcelSection) -> Int?

  private var primaryItems: [ParcelSection] {
    ParcelNavigationGroup.mobilePrimarySections
  }

  private var secondaryGroups: [ParcelNavigationGroup] {
    ParcelNavigationGroup.mobileSecondaryGroupsMatching(routeSearchText)
  }

  private var isSearching: Bool {
    !routeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 0) {
        ForEach(primaryItems) { section in
          BottomMenuButton(title: section.shortTitle, symbol: section.symbol, badgeCount: attentionCount(section), isSelected: selection == section) {
            withAnimation(.snappy) {
              isExpanded = false
              onSelect(section)
            }
          }
        }

        BottomMenuButton(title: isExpanded ? "Less" : "More", symbol: isExpanded ? "arrow.down" : "arrow.up", isSelected: isExpanded) {
          withAnimation(.snappy) {
            isExpanded.toggle()
            if !isExpanded {
              routeSearchText = ""
            }
          }
        }
      }

      if isExpanded {
        TextField("Find a screen", text: $routeSearchText)
          .textFieldStyle(.roundedBorder)
          .font(.callout)
          .padding(.horizontal, 4)

        if !isSearching {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label("Daily readiness", systemImage: dailyAttentionCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(dailyAttentionCount == 0 ? .green : .orange)
              Spacer()
              Badge(mvpStatusTitle, color: mvpStatusColor)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], alignment: .leading, spacing: 6) {
              ForEach(readinessItems, id: \.title) { item in
                Label(item.title, systemImage: item.isReady ? "checkmark.circle.fill" : "circle")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(item.isReady ? .green : .secondary)
                  .lineLimit(1)
              }
            }

            Text(dailyAttentionCount == 0 ? mvpStatusDetail : "Start with the badged daily routes. \(mvpStatusDetail)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 8)
          .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          .padding(.horizontal, 4)

          Text("Dispatch, Audit, Settings, and detailed records live here. Workbench stays in the primary bar for daily exception work.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
        }

        ScrollView(.vertical, showsIndicators: false) {
          VStack(alignment: .leading, spacing: 10) {
            if secondaryGroups.isEmpty {
              Text(isSearching ? "No matching ParcelOps screens." : "No secondary routes available.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            } else {
              ForEach(secondaryGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                  Text(group.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                  LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(group.sections) { section in
                      CompactMenuRouteButton(section: section, badgeCount: attentionCount(section), isSelected: selection == section) {
                        routeSearchText = ""
                        onSelect(section)
                      }
                    }
                  }
                }
              }
            }
          }
          .padding(.horizontal, 4)
          .padding(.bottom, 4)
        }
        .frame(maxHeight: 260)
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

  static let dailyOperations = ParcelNavigationGroup(title: "Primary Workflow", sections: [.dashboard, .inbox, .orders, .workbench, .dispatch, .tasks, .audit, .settings])

  static let mobilePrimarySections: [ParcelSection] = [.dashboard, .inbox, .orders, .workbench, .tasks]

  static let secondaryDesktopGroups: [ParcelNavigationGroup] = [
    ParcelNavigationGroup(title: "Detailed Review", sections: [.mvpSetup, .review, .mailbox, .importQueue, .acceptanceReview, .shipmentManifests, .dispatchReadiness, .tracking, .search, .timeline, .validation, .reconciliation, .handoffNotes]),
    ParcelNavigationGroup(title: "Operational Records", sections: [.evidence, .shipmentGroups, .packageContents, .costsBudgets, .returnsClaims, .procurement, .receivingInspections, .inventoryReceipts, .storageLocations, .custodyChain, .labelReferences, .scanSessions]),
    ParcelNavigationGroup(title: "Setup & Reference", sections: [.integrations, .automation, .slaPolicies, .exceptionPlaybooks, .communication, .contacts, .customerProfiles, .destinationAddresses, .deliveryInstructions, .accounts, .vendorProfiles, .wishlist])
  ]

  static let desktopGroups: [ParcelNavigationGroup] = [
    dailyOperations
  ] + secondaryDesktopGroups

  static var mobileSecondarySections: [ParcelSection] {
    let primarySet = Set(mobilePrimarySections)
    return desktopGroups.flatMap(\.sections).filter { !primarySet.contains($0) }
  }

  static var mobileSecondaryGroups: [ParcelNavigationGroup] {
    let primarySet = Set(mobilePrimarySections)
    let dailyOverflow = ParcelNavigationGroup(
      title: "More daily tools",
      sections: dailyOperations.sections.filter { !primarySet.contains($0) }
    )
    return [dailyOverflow] + secondaryDesktopGroups
  }

  static func desktopGroupsMatching(_ query: String) -> [ParcelNavigationGroup] {
    filteredGroups(desktopGroups, matching: query)
  }

  static func mobileSecondaryGroupsMatching(_ query: String) -> [ParcelNavigationGroup] {
    filteredGroups(mobileSecondaryGroups, matching: query)
  }

  private static func filteredGroups(_ groups: [ParcelNavigationGroup], matching query: String) -> [ParcelNavigationGroup] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else {
      return groups
    }

    return groups.compactMap { group in
      let groupMatches = group.title.lowercased().contains(trimmed)
      let sections = group.sections.filter { section in
        groupMatches
          || section.title.lowercased().contains(trimmed)
          || section.shortTitle.lowercased().contains(trimmed)
          || section.rawValue.lowercased().contains(trimmed)
          || section.searchKeywords.joined(separator: " ").lowercased().contains(trimmed)
      }
      guard !sections.isEmpty else { return nil }
      return ParcelNavigationGroup(title: group.title, sections: sections)
    }
  }
}

struct BottomMenuButton: View {
  var title: String
  var symbol: String
  var badgeCount: Int?
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        ZStack(alignment: .topTrailing) {
          Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 30, height: 20)
          if let badgeCount, badgeCount > 0 {
            Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
              .font(.system(size: 8, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(Color.teal, in: Capsule())
              .offset(x: 12, y: -7)
          }
        }
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

struct CompactMenuRouteButton: View {
  var section: ParcelSection
  var badgeCount: Int?
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: section.symbol)
          .font(.caption.weight(.semibold))
          .frame(width: 16)
        Text(section.shortTitle)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        Spacer(minLength: 0)
        if let badgeCount, badgeCount > 0 {
          Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.teal, in: Capsule())
        }
      }
      .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
      .padding(.horizontal, 9)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor.opacity(0.28) : Color.clear))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(section.title)
  }
}
