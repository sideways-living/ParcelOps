import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct ParcelOpsApp: App {
  #if os(macOS)
  @NSApplicationDelegateAdaptor(ParcelOpsAppDelegate.self) private var appDelegate
  #endif

  var body: some Scene {
    #if os(macOS)
    WindowGroup {
      ParcelOpsRootView()
        .parcelOpsWindowFrame()
    }
    .defaultSize(width: 1320, height: 860)
    .commands {
      ParcelRouteCommands()
    }

    Settings {
      EmptyView()
    }
    #else
    WindowGroup {
      ParcelOpsRootView()
        .parcelOpsWindowFrame()
    }
    .commands {
      ParcelRouteCommands()
    }
    #endif
  }
}

#if os(macOS)
final class ParcelOpsAppDelegate: NSObject, NSApplicationDelegate {
  private var fallbackWindowController: NSWindowController?
  private var isCheckingForMainWindow = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    openMainWindowIfNeeded()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      openMainWindowIfNeeded()
    }
    return true
  }

  private func openMainWindowIfNeeded() {
    guard !isCheckingForMainWindow else { return }
    isCheckingForMainWindow = true

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      defer { self.isCheckingForMainWindow = false }
      let hasVisibleParcelWindow = NSApp.windows.contains { window in
        window.isVisible && !window.title.localizedCaseInsensitiveContains("settings")
      }
      guard !hasVisibleParcelWindow else { return }

      self.openFallbackWindow()
    }
  }

  private func openFallbackWindow() {
    if let window = fallbackWindowController?.window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "ParcelOps"
    window.isReleasedWhenClosed = false
    window.center()
    window.contentViewController = NSHostingController(rootView: ParcelOpsRootView().parcelOpsWindowFrame())

    let controller = NSWindowController(window: window)
    fallbackWindowController = controller
    controller.showWindow(nil)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
#endif

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

private extension Notification.Name {
  static let parcelRouteRequested = Notification.Name("ParcelOps.routeRequested")
}

private enum ParcelRouteRequest {
  static func post(_ section: ParcelSection) {
    NotificationCenter.default.post(name: .parcelRouteRequested, object: section.rawValue)
  }
}

private struct ParcelRouteCommands: Commands {
  var body: some Commands {
    CommandMenu("Navigate") {
      Button("Dashboard") { ParcelRouteRequest.post(.dashboard) }
        .keyboardShortcut("1", modifiers: .command)
      Button("Inbox") { ParcelRouteRequest.post(.inbox) }
        .keyboardShortcut("2", modifiers: .command)
      Button("Orders") { ParcelRouteRequest.post(.orders) }
        .keyboardShortcut("3", modifiers: .command)
      Button("Workbench") { ParcelRouteRequest.post(.workbench) }
        .keyboardShortcut("4", modifiers: .command)
      Button("Dispatch") { ParcelRouteRequest.post(.dispatch) }
        .keyboardShortcut("5", modifiers: .command)
      Button("Tasks") { ParcelRouteRequest.post(.tasks) }
        .keyboardShortcut("6", modifiers: .command)
      Button("Wishlist") { ParcelRouteRequest.post(.wishlist) }
        .keyboardShortcut("7", modifiers: .command)
      Button("Audit") { ParcelRouteRequest.post(.audit) }
        .keyboardShortcut("8", modifiers: .command)
      Button("Settings") { ParcelRouteRequest.post(.settings) }
        .keyboardShortcut("9", modifiers: .command)
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
      + store.pendingMailboxReviewCount
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.acceptanceRecordsNeedingReview.count
      + store.reviewOrders.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
      + wishlistAttentionCount
  }

  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - dailyAttentionCount, 0)
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasMicrosoft365Setup: Bool {
    !store.microsoft365MailboxConnections.isEmpty
  }

  private var hasLiveMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup || hasMicrosoft365Setup
  }

  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailConnectedAuth: Bool {
    store.hasGmailConnectedAuth
  }

  private var hasMicrosoft365ConnectedAuth: Bool {
    store.microsoft365MailboxConnections.contains {
      store.microsoft365AuthSessionState(for: $0).status == .connected
    }
  }

  private var hasLiveMailboxCredentialOrAuth: Bool {
    hasSpaceMailCredentialReference || hasGmailConnectedAuth || hasMicrosoft365ConnectedAuth
  }

  private var hasRealMailboxRefreshEvidence: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastRefreshFetchedCount > 0 }
      || store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || store.gmailMailboxConnections.contains { $0.lastRefreshFetchedCount > 0 }
      || store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
      || store.microsoft365MailboxConnections.contains { $0.lastRefreshFetchedCount > 0 }
      || store.microsoft365MailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
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
    [.inbox, .orders, .workbench, .dispatch, .tasks, .wishlist]
  }

  private var wishlistAttentionCount: Int {
    store.wishlistItems.filter { item in
      guard store.isActiveWishlistItem(item) else { return false }
      let options = item.comparisonOptions ?? []
      let snapshots = store.wishlistPriceSnapshots(for: item)
      let preferred = item.preferredOptionID.flatMap { preferredID in
        options.first { $0.id == preferredID }
      }
      let hasSnapshotGaps = snapshots.contains { snapshot in
        let searchable = [
          snapshot.estimatedAUDTotal,
          snapshot.postageCost,
          snapshot.postageTime,
          snapshot.availabilityStatus,
          snapshot.trustSignal
        ].joined(separator: " ").localizedLowercase
        return snapshot.reviewState != .accepted
          || searchable.contains("pending")
          || searchable.contains("confirm")
          || searchable.contains("unknown")
          || searchable.contains("missing")
          || searchable.contains("review")
      }
      return options.isEmpty
        || snapshots.isEmpty
        || hasSnapshotGaps
        || preferred == nil
        || preferred?.operatorSellerEvidenceGaps.isEmpty == false
        || (preferred?.operatorSellerMatrixScore ?? 0) < 65
        || item.purchaseDecision?.reviewState == .needsReview
        || item.purchaseHandoff?.linkedOrderID == nil && item.purchaseHandoff != nil
    }.count
  }

  private func routeShortcut(for section: ParcelSection) -> ParcelRouteShortcut? {
    switch section {
    case .dashboard: ParcelRouteShortcut(key: "1", label: "⌘1")
    case .inbox: ParcelRouteShortcut(key: "2", label: "⌘2")
    case .orders: ParcelRouteShortcut(key: "3", label: "⌘3")
    case .workbench: ParcelRouteShortcut(key: "4", label: "⌘4")
    case .dispatch: ParcelRouteShortcut(key: "5", label: "⌘5")
    case .tasks: ParcelRouteShortcut(key: "6", label: "⌘6")
    case .wishlist: ParcelRouteShortcut(key: "7", label: "⌘7")
    case .audit: ParcelRouteShortcut(key: "8", label: "⌘8")
    case .settings: ParcelRouteShortcut(key: "9", label: "⌘9")
    default: nil
    }
  }

  var body: some View {
    rootLayout
      .tint(.teal)
      .onReceive(NotificationCenter.default.publisher(for: .parcelRouteRequested)) { notification in
        guard
          let rawValue = notification.object as? String,
          let section = ParcelSection(rawValue: rawValue)
        else { return }
        route(to: section)
      }
      .onOpenURL { url in
        store.handleMicrosoft365AuthCallback(url)
        store.handleGmailAuthCallback(url)
      }
  }

  @ViewBuilder
  private var rootLayout: some View {
    #if os(macOS)
    desktopLayout
    #else
    GeometryReader { proxy in
      let usePhoneLayout = horizontalSizeClass == .compact || proxy.size.width < 700

      if usePhoneLayout {
        phoneLayout
      } else {
        desktopLayout
      }
    }
    #endif
  }

  private var phoneLayout: some View {
    NavigationStack {
      content(for: selection)
        .id(selection)
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
        route(to: section)
      } attentionCount: { section in
        attentionCount(for: section)
      }
    }
  }

  private var desktopLayout: some View {
    HStack(spacing: 0) {
      desktopSidebar

      Divider()

      content(for: selection)
        .id(selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var desktopSidebar: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Text("ParcelOps")
            .font(.title3.weight(.bold))
          Spacer()
          Badge("\(dailyAttentionCount)", color: dailyAttentionCount == 0 ? .green : .orange)
        }

        TextField("Find a screen", text: $sidebarSearchText)
          .textFieldStyle(.roundedBorder)
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 12)

      Divider()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          if isSearchingSidebar {
            sidebarSectionHeader("Route Search")
            if desktopSearchResults.isEmpty {
              Text("No matching ParcelOps screens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            } else {
              ForEach(desktopSearchResults) { group in
                ForEach(group.sections) { section in
                  sidebarButton(for: section, context: group.title)
                }
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 8) {
              sidebarSectionHeader("Daily Focus")
              sidebarDailyFocusSummary
                .padding(.horizontal, 18)
            }

            VStack(alignment: .leading, spacing: 6) {
              sidebarSectionHeader("Primary Workflow")
              ForEach(ParcelNavigationGroup.dailyOperations.sections) { section in
                sidebarButton(for: section)
              }
            }

            VStack(alignment: .leading, spacing: 8) {
              sidebarSectionHeader("Reference Records")

              VStack(alignment: .leading, spacing: 8) {
                Text("Setup screens, detailed review tools, and supporting records stay secondary unless you need diagnostics.")
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
                  Text("An advanced route is selected, so these groups remain visible until you return to the daily workflow.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(.horizontal, 18)
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
                .padding(.horizontal, 18)
              }
            }
          }
        }
      }
      .scrollIndicators(.visible)

      Divider()

      sidebarReviewFooter
    }
    .frame(width: 460)
    .background(.bar)
  }

  private func sidebarSectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var sidebarDailyFocusSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Start with the row that has the highest active count. Advanced records stay hidden unless you need diagnostics.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(dailyFocusSections) { section in
          let count = attentionCount(for: section) ?? 0
          Button {
            route(to: section)
          } label: {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: section.symbol)
                .font(.body.weight(.semibold))
                .frame(width: 22, height: 24)

              VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(1)
                Text(sidebarDailyFocusDetail(for: section, count: count))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                  .fixedSize(horizontal: false, vertical: true)
              }

              Spacer(minLength: 6)

              if count > 0 {
                Text("\(count)")
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(attentionColor(for: section, count: count), in: Capsule())
              }
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .topLeading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(selection == section ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
          }
          .buttonStyle(.plain)
          .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
      }
    }
  }

  private func sidebarDailyFocusDetail(for section: ParcelSection, count: Int) -> String {
    if count > 0 {
      return "Needs attention in the daily queue."
    }
    switch section {
    case .inbox:
      return "Mailbox and intake triage."
    case .orders:
      return "Order review and tracking."
    case .workbench:
      return "Exceptions and mismatches."
    case .dispatch:
      return "Manifests and readiness."
    case .tasks:
      return "Tasks, handoffs, drafts."
    case .wishlist:
      return "Wanted items and purchase prep."
    default:
      return section.shortTitle
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
              .lineLimit(2)
            Badge("\(dailyAttentionCount)", color: dailyAttentionCount == 0 ? .green : .orange)
            Badge(sidebarMVPStatusTitle, color: sidebarMVPStatusColor)
          }
          .fixedSize(horizontal: false, vertical: true)

          Text(dailyAttentionCount == 0 ? sidebarMVPStatusDetail : "Start with Inbox, Orders, Workbench, Dispatch, or Tasks.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(sidebarReadinessItems, id: \.title) { item in
          Label(item.title, systemImage: item.isReady ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(item.isReady ? .green : .secondary)
            .lineLimit(1)
            .help(item.title)
        }
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
      route(to: .dashboard)
      showSecondaryDesktopGroups = false
      expandedDesktopGroupIDs.removeAll()
    } else {
      showSecondaryDesktopGroups.toggle()
      if !showSecondaryDesktopGroups {
        expandedDesktopGroupIDs.removeAll()
      }
    }
  }

  private func route(to section: ParcelSection) {
    selection = section
    sidebarSearchText = ""
    if ParcelNavigationGroup.secondaryDesktopGroups.flatMap(\.sections).contains(section) {
      showSecondaryDesktopGroups = true
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
      route(to: section)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: section.symbol)
            .font(.body.weight(.semibold))
            .frame(width: 22, height: 24, alignment: .center)
            .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
          Text(section.title)
            .font(.body)
            .foregroundStyle(selection == section ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          Spacer(minLength: 8)
          if let shortcut = routeShortcut(for: section) {
            Text(shortcut.label)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.top, 2)
              .frame(minWidth: 24, alignment: .trailing)
          }
          if let count, count > 0 {
            Badge("\(count)", color: attentionColor(for: section, count: count))
              .padding(.top, 1)
          }
        }
        if let context {
          Text(context)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 28)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(selection == section ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 6)
  }

  private func attentionCount(for section: ParcelSection) -> Int? {
    switch section {
    case .dashboard:
      return dailyAttentionCount
    case .inbox:
      return store.reviewIntakeEmails.count
        + store.pendingMailboxReviewCount
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
    case .wishlist:
      return wishlistAttentionCount
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

          Text("Dispatch, Tasks, Audit, Settings, and detailed records live here. Wishlist stays in the primary bar for purchase planning.")
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

  static let dailyOperations = ParcelNavigationGroup(title: "Primary Workflow", sections: [.dashboard, .inbox, .orders, .workbench, .dispatch, .tasks, .wishlist, .audit, .settings])

  static let mobilePrimarySections: [ParcelSection] = [.dashboard, .inbox, .orders, .workbench, .wishlist]

  static let secondaryDesktopGroups: [ParcelNavigationGroup] = [
    ParcelNavigationGroup(title: "Detailed Review", sections: [.mvpSetup, .review, .mailbox, .importQueue, .acceptanceReview, .shipmentManifests, .dispatchReadiness, .tracking, .search, .timeline, .validation, .reconciliation, .handoffNotes]),
    ParcelNavigationGroup(title: "Operational Records", sections: [.evidence, .shipmentGroups, .packageContents, .costsBudgets, .returnsClaims, .procurement, .receivingInspections, .inventoryReceipts, .storageLocations, .custodyChain, .labelReferences, .scanSessions]),
    ParcelNavigationGroup(title: "Setup & Reference", sections: [.integrations, .automation, .slaPolicies, .exceptionPlaybooks, .communication, .contacts, .customerProfiles, .destinationAddresses, .deliveryInstructions, .accounts, .vendorProfiles])
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
