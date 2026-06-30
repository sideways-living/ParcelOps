import SwiftUI

struct DashboardView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var dashboardSearchText = ""

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var normalizedDashboardSearch: String {
    dashboardSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
  private var metricColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4)
  }
  private var sectionColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 14), count: isCompact ? 1 : 2)
  }
  private var incomingAttentionCount: Int {
    store.reviewIntakeEmails.count + spaceMailHealthAttentionCount + store.importQueueItemsNeedingReview.count + store.blockedImportQueueItems.count + store.acceptanceRecordsNeedingReview.count
  }
  private var spaceMailHealthAttentionCount: Int {
    store.spaceMailIntakeHealthSummaries.filter {
      $0.tone == "warning" || $0.pendingUncertainReviewCount > 0 || $0.parserIssueCount > 0 || $0.importedCount > 0
    }.count
  }
  private var problemOrdersCount: Int {
    store.reviewOrders.count + store.orders.filter { $0.status == .exception }.count + store.trackingWarningCount + store.criticalTrackingCount
  }
  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter(isInboxCreatedOrder)
  }
  private var partialInboxOrderBlockers: [TrackedOrder] {
    inboxCreatedOrders.filter { order in
      hasPartialInboxOrderTask(order) || order.missingInboxOrderFieldCount > 0
    }
  }
  private var inboxDispatchGapOrders: [TrackedOrder] {
    store.orders.filter { order in
      isInboxCreatedOrder(order)
        && [.shipped, .inTransit, .exception].contains(order.status)
        && store.suggestedShipmentManifestRecords(for: order).isEmpty
        && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
    }
  }
  private var inboxDispatchSetupPendingOrders: [TrackedOrder] {
    store.orders.filter { order in
      isInboxCreatedOrder(order)
        && !hasPartialInboxOrderTask(order)
        && order.missingInboxOrderFieldCount == 0
        && !inboxDispatchHandoffCompleted(order)
        && (
          store.suggestedShipmentManifestRecords(for: order).contains(where: \.isInboxHandoffSetup)
            || store.suggestedDispatchReadinessChecklists(for: order).contains(where: \.isInboxHandoffSetup)
        )
        && store.suggestedDispatchReadinessChecklists(for: order).contains { checklist in
          checklist.isInboxHandoffSetup && checklist.checklistStatus != .completed
        }
    }
  }
  private var reopenedInboxDispatchManifests: [ShipmentManifestRecord] {
    store.shipmentManifestRecords.filter { $0.isInboxHandoffSetup && $0.dispatchStatus == .reopened }
  }
  private var reopenedInboxDispatchChecklists: [DispatchReadinessChecklist] {
    store.dispatchReadinessChecklists.filter { $0.isInboxHandoffSetup && $0.checklistStatus == .reopened }
  }
  private var reopenedInboxDispatchHandoffCount: Int {
    reopenedInboxDispatchManifests.count + reopenedInboxDispatchChecklists.count
  }
  private var dispatchAttentionCount: Int {
    store.blockedShipmentManifests.count + store.undispatchedShipmentManifests.count + store.blockedDispatchChecklists.count + store.incompleteDispatchChecklists.count + inboxDispatchGapOrders.count + inboxDispatchSetupPendingOrders.count + partialInboxOrderBlockers.count + reopenedInboxDispatchHandoffCount
  }
  private var taskAttentionCount: Int {
    store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
  }
  private var operatorWorkbenchItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { $0.source != .intakeParser }
  }
  private var highPriorityOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter { $0.rank >= 3 }
  }
  private var overdueOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter(\.isDueOrOverdue)
  }
  private var blockedOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter(\.isBlocked)
  }
  private var operatorWorkbenchReviewItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter { $0.reviewState == .needsReview }
  }
  private var attentionNowCount: Int {
    incomingAttentionCount + problemOrdersCount + dispatchAttentionCount + taskAttentionCount + highPriorityOperatorWorkbenchItems.count
  }
  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - attentionNowCount, 0)
  }
  private var visibleDashboardMatchCount: Int {
    [
      dashboardMatches("inbox", "mailbox", "spacemail", "email", "parser", "import", "acceptance", "triage", "intake"),
      dashboardMatches("orders", "order", "tracking", "customer", "destination", "inbox-created"),
      dashboardMatches("workbench", "exception", "validation", "reconciliation", "high-priority"),
      dashboardMatches("dispatch", "manifest", "readiness", "outbound", "handoff", "reopened"),
      dashboardMatches("tasks", "task", "handoff", "draft", "follow-up", "overdue"),
      dashboardMatches("audit", "activity", "history", "record change", "workflow"),
      dashboardMatches("incoming order intake", "inbox", "mailbox", "spacemail", "parser", "import", "acceptance"),
      dashboardMatches("active problem orders", "orders", "tracking", "inbox-created", "customer", "destination"),
      dashboardMatches("dispatch readiness", "dispatch", "manifest", "readiness", "blocked", "undispatched", "reopened"),
      dashboardMatches("open tasks handoffs drafts", "tasks", "handoff", "draft", "overdue", "high"),
      dashboardMatches("recent local activity", "audit", "activity", "recent", "history")
    ].filter { $0 }.count
  }

  private var dailyStartTone: Color {
    if incomingAttentionCount > 0 { return .orange }
    if !partialInboxOrderBlockers.isEmpty { return .orange }
    if problemOrdersCount > 0 { return .red }
    if highPriorityOperatorWorkbenchItems.count > 0 { return .purple }
    if reopenedInboxDispatchHandoffCount > 0 { return .purple }
    if dispatchAttentionCount > 0 { return .blue }
    if taskAttentionCount > 0 { return .orange }
    return .green
  }

  private var dailyStartTitle: String {
    if incomingAttentionCount > 0 { return "Start in Inbox" }
    if !partialInboxOrderBlockers.isEmpty { return "Verify Inbox-created orders" }
    if problemOrdersCount > 0 { return "Start with Orders" }
    if highPriorityOperatorWorkbenchItems.count > 0 { return "Start in Workbench" }
    if reopenedInboxDispatchHandoffCount > 0 { return "Review reopened dispatch handoffs" }
    if dispatchAttentionCount > 0 { return "Start with Dispatch" }
    if taskAttentionCount > 0 { return "Start with Tasks" }
    return "Daily queue is clear"
  }

  private var dailyStartDetail: String {
    if incomingAttentionCount > 0 {
      return "\(incomingAttentionCount) incoming item needs triage from mailbox intake, SpaceMail review, import queue, or acceptance review."
    }
    if !partialInboxOrderBlockers.isEmpty {
      return "\(partialInboxOrderBlockers.count) Inbox-created order has missing details or an open verification task. Confirm those before dispatch setup."
    }
    if problemOrdersCount > 0 {
      return "\(problemOrdersCount) order signal needs attention from review state, exceptions, tracking warnings, or Inbox-created order handoff."
    }
    if highPriorityOperatorWorkbenchItems.count > 0 {
      return "\(highPriorityOperatorWorkbenchItems.count) high-priority exception, validation, reconciliation, or operational workbench item is open."
    }
    if reopenedInboxDispatchHandoffCount > 0 {
      return "\(reopenedInboxDispatchHandoffCount) Inbox dispatch handoff record was reopened. Open Dispatch or the linked order to complete or block it."
    }
    if dispatchAttentionCount > 0 {
      return "\(dispatchAttentionCount) dispatch item needs preparation, readiness review, or blocked-manifest follow-up."
    }
    if taskAttentionCount > 0 {
      return "\(taskAttentionCount) task, handoff, or draft message needs ownership, completion, local send status, or review."
    }
    return "No primary daily operator queue has promoted work right now. Use Audit or advanced routes only when checking detailed history."
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        dailyStartDecisionPanel
        MVPWorkflowGuide(
          title: "First run path",
          detail: "Use these screens in order when testing the local-only app in Xcode.",
          steps: [
            "Review forwarded email and import intake.",
            "Accept or link records into orders and shipment groups.",
            "Work exceptions in the workbench and tasks.",
            "Prepare manifests and dispatch readiness.",
            "Check audit history and local-only settings."
          ],
          symbol: "map.fill"
        )
        MVPReadinessCallout(store: store)
        MVPHandsOnDashboardStatus(store: store)
        dailyOperatorStart

        VStack(alignment: .leading, spacing: 6) {
          Text("Detailed local analytics")
            .font(.title2.bold())
          Text("Broader local record summaries remain available below for deeper review and testing.")
            .foregroundStyle(.secondary)
        }

        AnalyticsSection(title: "Operations", symbol: "shippingbox.fill") {
          LazyVGrid(columns: metricColumns, spacing: 12) {
            MetricCard(title: "Active", value: "\(store.activeCount)", symbol: "shippingbox.fill", color: .teal)
            MetricCard(title: "Delivered", value: "\(store.deliveredCount)", symbol: "checkmark.circle.fill", color: .green)
            MetricCard(title: "Orders review", value: "\(store.reviewOrders.count)", symbol: "checkmark.shield.fill", color: .orange)
            MetricCard(title: "Total orders", value: "\(store.orders.count)", symbol: "tray.full.fill", color: .blue)
          }
        }

        LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 14) {
          AnalyticsSection(title: "Operations Workbench", symbol: "rectangle.stack.badge.person.crop.fill") {
            MetricStrip(items: [
              ("Open", "\(operatorWorkbenchItems.count)", .blue),
              ("Overdue", "\(overdueOperatorWorkbenchItems.count)", overdueOperatorWorkbenchItems.isEmpty ? .green : .red),
              ("Blocked", "\(blockedOperatorWorkbenchItems.count)", blockedOperatorWorkbenchItems.isEmpty ? .green : .red),
              ("Review", "\(operatorWorkbenchReviewItems.count)", operatorWorkbenchReviewItems.isEmpty ? .green : .orange)
            ])
            CompactWorkbenchList(items: Array(highPriorityOperatorWorkbenchItems.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Review workload", symbol: "exclamationmark.triangle.fill") {
            MetricStrip(items: [
              ("Queue", "\(store.reviewQueueCount)", .orange),
              ("Intake", "\(store.reviewIntakeEmails.count)", .blue),
              ("Evidence", "\(store.reviewEvidenceAttachments.count)", .purple),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red)
            ])
            CompactIntakeList(emails: store.newestIntakeEmails, store: store)
          }

          AnalyticsSection(title: "Tracking health", symbol: "location.fill.viewfinder") {
            MetricStrip(items: [
              ("Warnings", "\(store.trackingWarningCount)", .orange),
              ("Critical", "\(store.criticalTrackingCount)", .red),
              ("Events", "\(store.carrierTrackingEvents.count)", .blue)
            ])
            CompactTrackingList(events: store.highestRiskTrackingEvents, orders: store.orders, store: store)
          }

          AnalyticsSection(title: "Evidence", symbol: "paperclip") {
            MetricStrip(items: [
              ("Total", "\(store.evidenceAttachments.count)", .blue),
              ("Needs review", "\(store.reviewEvidenceAttachments.count)", .orange)
            ])
            CompactEvidenceList(attachments: Array(store.evidenceAttachments.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Automation", symbol: "arrow.triangle.branch") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAutomationRuleCount)", .green),
              ("Disabled", "\(store.disabledAutomationRuleCount)", .gray),
              ("Rules", "\(store.automationRules.count)", .teal)
            ])
            CompactAutomationList(rules: Array(store.automationRules.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Tasks", symbol: "checklist") {
            MetricStrip(items: [
              ("Open", "\(store.openReviewTasks.count)", .blue),
              ("Attention", "\(store.reviewTasksNeedingAttention.count)", .orange),
              ("Total", "\(store.reviewTasks.count)", .teal)
            ])
            CompactTaskList(tasks: Array(store.reviewTasksNeedingAttention.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
            MetricStrip(items: [
              ("Open", "\(store.openHandoffNotes.count)", .blue),
              ("Attention", "\(store.handoffNotesNeedingAttention.count)", .orange),
              ("Overdue", "\(store.overdueHandoffNotes.count)", .red),
              ("High", "\(store.highPriorityHandoffNotes.count)", .red)
            ])
            CompactHandoffNoteList(notes: Array(store.handoffNotesNeedingAttention.prefix(4)), store: store)
          }

          AnalyticsSection(title: "SLA policies", symbol: "timer") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledSLAPolicyCount)", .green),
              ("Disabled", "\(store.disabledSLAPolicyCount)", .gray),
              ("Review", "\(store.policiesNeedingReview.count)", .orange),
              ("Overdue", "\(store.overdueOpenReviewTasks.count)", .red)
            ])
            CompactSLAPolicyList(policies: store.recentPolicyMatches, store: store)
          }

          AnalyticsSection(title: "Exception playbooks", symbol: "book.closed.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledPlaybookCount)", .green),
              ("Disabled", "\(store.disabledPlaybookCount)", .gray),
              ("Review", "\(store.playbooksNeedingReview.count)", .orange),
              ("High", "\(store.enabledHighPriorityPlaybooks.count)", .red)
            ])
            CompactExceptionPlaybookList(playbooks: Array((store.playbooksNeedingReview + store.enabledHighPriorityPlaybooks).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Drafts & Templates", symbol: "bubble.left.and.text.bubble.right.fill") {
            MetricStrip(items: [
              ("Templates", "\(store.enabledCommunicationTemplateCount)", .green),
              ("Disabled", "\(store.disabledCommunicationTemplateCount)", .gray),
              ("Drafts", "\(store.draftMessages.count)", .blue),
              ("Review", "\(store.draftMessagesNeedingReview.count)", .orange)
            ])
            CompactDraftMessageList(drafts: Array(store.draftMessagesNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Contacts", symbol: "person.crop.circle.badge.checkmark") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledContactCount)", .green),
              ("Disabled", "\(store.disabledContactCount)", .gray),
              ("Review", "\(store.contactsNeedingReview.count)", .orange),
              ("Total", "\(store.contactDirectoryEntries.count)", .blue)
            ])
            CompactContactList(contacts: Array(store.contactsNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledCustomerProfileCount)", .green),
              ("Disabled", "\(store.disabledCustomerProfileCount)", .gray),
              ("Review", "\(store.customerProfilesNeedingReview.count)", .orange),
              ("Total", "\(store.customerRecipientProfiles.count)", .blue)
            ])
            CompactCustomerProfileList(profiles: Array((store.customerProfilesNeedingReview + store.customerRecipientProfiles.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Destination addresses", symbol: "mappin.and.ellipse") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDestinationAddressCount)", .green),
              ("Disabled", "\(store.disabledDestinationAddressCount)", .gray),
              ("Review", "\(store.destinationAddressesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskDestinationAddresses.count)", .red)
            ])
            CompactDestinationAddressList(addresses: Array((store.destinationAddressesNeedingReview + store.highRiskDestinationAddresses + store.destinationAddresses.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDeliveryInstructionCount)", .green),
              ("Disabled", "\(store.disabledDeliveryInstructionCount)", .gray),
              ("Review", "\(store.deliveryInstructionsNeedingReview.count)", .orange),
              ("Access", "\(store.deliveryInstructionsWithAccessConstraints.count)", .red)
            ])
            CompactDeliveryInstructionList(instructions: Array((store.deliveryInstructionsNeedingReview + store.highRiskDeliveryInstructions + store.deliveryInstructions.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Package contents", symbol: "shippingbox.circle.fill") {
            MetricStrip(items: [
              ("Unverified", "\(store.unverifiedPackageContents.count)", .orange),
              ("Discrepancy", "\(store.packageContentDiscrepancies.count)", .red),
              ("High risk", "\(store.highRiskPackageContents.count)", .red),
              ("High value", "\(store.highValuePackageContents.count)", .purple)
            ])
            CompactPackageContentList(contents: Array((store.packageContentsNeedingReview + store.unverifiedPackageContents + store.packageContentDiscrepancies + store.highRiskPackageContents + store.highValuePackageContents).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Costs & budgets", symbol: "creditcard.and.123") {
            MetricStrip(items: [
              ("Review", "\(store.costRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCostRecords.count)", .red),
              ("Unreimbursed", "\(store.unreimbursedCostRecords.count)", .orange),
              ("Missing budget", "\(store.missingBudgetCodeCostRecords.count)", .red)
            ])
            CompactCostRecordList(costs: Array((store.costRecordsNeedingReview + store.disputedCostRecords + store.unreimbursedCostRecords + store.unapprovedCostRecords + store.highRiskCostRecords + store.missingBudgetCodeCostRecords).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
            MetricStrip(items: [
              ("Review", "\(store.returnClaimsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedReturnClaims.count)", .red),
              ("Unresolved", "\(store.unresolvedReturnClaims.count)", .orange),
              ("Missing evidence", "\(store.returnClaimsMissingEvidence.count)", .red)
            ])
            CompactReturnClaimList(claims: Array((store.returnClaimsNeedingReview + store.disputedReturnClaims + store.unresolvedReturnClaims + store.overdueReturnClaims + store.highRiskReturnClaims + store.returnClaimsMissingEvidence).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Procurement", symbol: "cart.badge.plus") {
            MetricStrip(items: [
              ("Review", "\(store.procurementRequestsNeedingReview.count)", .orange),
              ("Unapproved", "\(store.unapprovedProcurementRequests.count)", .orange),
              ("Rejected", "\(store.rejectedProcurementRequests.count)", .red),
              ("Missing budget", "\(store.missingBudgetCodeProcurementRequests.count)", .red)
            ])
            CompactProcurementRequestList(requests: Array((store.procurementRequestsNeedingReview + store.unapprovedProcurementRequests + store.rejectedProcurementRequests + store.notYetOrderedProcurementRequests + store.overdueProcurementRequests + store.highRiskProcurementRequests + store.missingBudgetCodeProcurementRequests).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Receiving inspections", symbol: "checklist.checked") {
            MetricStrip(items: [
              ("Review", "\(store.receivingInspectionsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedReceivingInspections.count)", .purple),
              ("Discrepancies", "\(store.unresolvedInspectionDiscrepancies.count)", .red),
              ("Qty mismatch", "\(store.quantityMismatchReceivingInspections.count)", .orange)
            ])
            CompactReceivingInspectionList(inspections: Array((store.receivingInspectionsNeedingReview + store.blockedReceivingInspections + store.unresolvedInspectionDiscrepancies + store.highRiskReceivingInspections + store.overdueReceivingInspections + store.quantityMismatchReceivingInspections).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Inventory receipts", symbol: "archivebox.fill") {
            MetricStrip(items: [
              ("Review", "\(store.inventoryReceiptsNeedingReview.count)", .orange),
              ("Rejected", "\(store.rejectedInventoryReceipts.count)", .red),
              ("Partial", "\(store.partiallyAcceptedInventoryReceipts.count)", .orange),
              ("Missing storage", "\(store.inventoryReceiptsMissingStorage.count)", .red)
            ])
            CompactInventoryReceiptList(receipts: Array((store.inventoryReceiptsNeedingReview + store.rejectedInventoryReceipts + store.partiallyAcceptedInventoryReceipts + store.highRiskInventoryReceipts + store.unassignedInventoryReceipts + store.inventoryReceiptsMissingStorage).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Storage locations", symbol: "cabinet.fill") {
            MetricStrip(items: [
              ("Review", "\(store.storageLocationsNeedingReview.count)", .orange),
              ("Disabled", "\(store.disabledStorageLocations.count)", .gray),
              ("Missing code", "\(store.storageLocationsMissingCodes.count)", .red),
              ("Capacity", "\(store.storageLocationsWithCapacityWarnings.count)", .red)
            ])
            CompactStorageLocationList(locations: Array((store.storageLocationsNeedingReview + store.disabledStorageLocations + store.highRiskStorageLocations + store.storageLocationsMissingCodes + store.storageLocationsWithAccessNotes + store.storageLocationsWithCapacityWarnings).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
            MetricStrip(items: [
              ("Review", "\(store.custodyRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCustodyRecords.count)", .red),
              ("Open", "\(store.openCustodyTransfers.count)", .blue),
              ("Missing", "\(store.custodyRecordsMissingCustodians.count + store.custodyRecordsMissingLocations.count)", .red)
            ])
            CompactCustodyRecordList(records: Array((store.custodyRecordsNeedingReview + store.disputedCustodyRecords + store.openCustodyTransfers + store.overdueCustodyRecords + store.highRiskCustodyRecords + store.custodyRecordsMissingCustodians + store.custodyRecordsMissingLocations).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Label references", symbol: "barcode.viewfinder") {
            MetricStrip(items: [
              ("Review", "\(store.labelReferencesNeedingReview.count)", .orange),
              ("Invalid", "\(store.invalidLabelReferences.count)", .red),
              ("Unverified", "\(store.unverifiedLabelReferences.count)", .blue),
              ("Missing", "\(store.labelReferencesMissingValues.count + store.labelReferencesMissingLinkedRecords.count)", .red)
            ])
            CompactLabelReferenceList(records: Array((store.labelReferencesNeedingReview + store.invalidLabelReferences + store.unverifiedLabelReferences + store.highRiskLabelReferences + store.labelReferencesMissingValues + store.labelReferencesMissingLinkedRecords).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Scan sessions", symbol: "qrcode.viewfinder") {
            MetricStrip(items: [
              ("Review", "\(store.scanSessionsNeedingReview.count)", .orange),
              ("Mismatch", "\(store.mismatchScanSessions.count)", .red),
              ("Incomplete", "\(store.incompleteScanSessions.count)", .blue),
              ("Missing", "\(store.scanSessionsMissingCapturedValues.count + store.scanSessionsMissingLabelReferences.count)", .red)
            ])
            CompactScanSessionList(records: Array((store.scanSessionsNeedingReview + store.mismatchScanSessions + store.incompleteScanSessions + store.highRiskScanSessions + store.scanSessionsMissingCapturedValues + store.scanSessionsMissingLabelReferences).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
            MetricStrip(items: [
              ("Review", "\(store.shipmentManifestsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedShipmentManifests.count)", .red),
              ("Undispatched", "\(store.undispatchedShipmentManifests.count)", .blue),
              ("Missing", "\(store.shipmentManifestsMissingIncludedOrders.count + store.shipmentManifestsMissingHandoffLocation.count)", .red)
            ])
            CompactShipmentManifestList(records: Array((store.shipmentManifestsNeedingReview + store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests + store.shipmentManifestsMissingIncludedOrders + store.shipmentManifestsMissingHandoffLocation + store.shipmentManifestsWithIncompleteScans).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
            MetricStrip(items: [
              ("Review", "\(store.dispatchChecklistsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedDispatchChecklists.count)", .red),
              ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .blue),
              ("Missing", "\(store.dispatchChecklistsMissingRequirements.count)", .red)
            ])
            CompactDispatchReadinessList(checklists: Array((store.dispatchChecklistsNeedingReview + store.blockedDispatchChecklists + store.incompleteDispatchChecklists + store.highRiskDispatchChecklists + store.dispatchChecklistsMissingRequirements + store.dispatchChecklistsLinkedToBlockedManifests).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Accounts", symbol: "key.horizontal.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAccountRecordCount)", .green),
              ("Disabled", "\(store.disabledAccountRecordCount)", .gray),
              ("Review", "\(store.accountRecordsNeedingReview.count)", .orange),
              ("Total", "\(store.accountCredentialRecords.count)", .blue)
            ])
            CompactAccountList(accounts: Array(store.accountRecordsNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Vendor profiles", symbol: "building.2.crop.circle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledVendorProfileCount)", .green),
              ("Disabled", "\(store.disabledVendorProfileCount)", .gray),
              ("Review", "\(store.vendorProfilesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskEnabledVendorProfiles.count)", .red)
            ])
            CompactVendorProfileList(profiles: Array((store.vendorProfilesNeedingReview + store.highRiskEnabledVendorProfiles).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
            MetricStrip(items: [
              ("Total", "\(store.shipmentGroups.count)", .blue),
              ("Review", "\(store.shipmentGroupsNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskShipmentGroups.count)", .red),
              ("Critical", "\(store.shipmentGroups.filter { $0.riskLevel == .critical }.count)", .red)
            ])
            CompactShipmentGroupList(groups: Array((store.shipmentGroupsNeedingReview + store.highRiskShipmentGroups).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
            MetricStrip(items: [
              ("Total", "\(store.importQueueItems.count)", .blue),
              ("Review", "\(store.importQueueItemsNeedingReview.count)", .orange),
              ("Low conf", "\(store.lowConfidenceImportQueueItems.count)", .orange),
              ("Blocked", "\(store.blockedImportQueueItems.count)", .red)
            ])
            CompactImportQueueList(items: Array((store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Acceptance review", symbol: "checkmark.rectangle.stack.fill") {
            MetricStrip(items: [
              ("Ready", "\(store.acceptanceCandidates.filter { $0.decision == .ready }.count)", .blue),
              ("Accepted", "\(store.acceptedAcceptanceRecords.count)", .green),
              ("Blocked", "\(store.blockedAcceptanceRecords.count)", .red),
              ("Reopened", "\(store.reopenedAcceptanceRecords.count)", .orange)
            ])
            CompactAcceptanceList(records: Array((store.blockedAcceptanceRecords + store.reopenedAcceptanceRecords + store.ignoredAcceptanceRecords + store.acceptanceRecordsNeedingReview).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Reconciliation", symbol: "arrow.triangle.2.circlepath.circle.fill") {
            MetricStrip(items: [
              ("Unresolved", "\(store.unresolvedReconciliationIssues.count)", .orange),
              ("High", "\(store.highSeverityReconciliationIssues.count)", .red),
              ("Conflicts", "\(store.reconciliationIssues.filter { $0.issueType == .orderNumberConflict || $0.issueType == .trackingNumberConflict || $0.issueType == .destinationConflict }.count)", .purple),
              ("Total", "\(store.reconciliationIssues.count)", .blue)
            ])
            CompactReconciliationIssueList(issues: Array(store.unresolvedReconciliationIssues.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Timeline", symbol: "clock.badge.exclamationmark.fill") {
            MetricStrip(items: [
              ("Recent", "\(store.recentTimelineActivities.count)", .blue),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red),
              ("Critical", "\(store.timelineWatchlist.filter { $0.risk == .critical }.count)", .red),
              ("High", "\(store.timelineWatchlist.filter { $0.risk == .high }.count)", .orange)
            ])
            CompactTimelineList(activities: store.recentTimelineActivities, store: store)
          }

          AnalyticsSection(title: "Validation health", symbol: "checkmark.seal.fill") {
            MetricStrip(items: [
              ("Health", "\(store.validationHealthScore)%", store.validationHealthScore >= 80 ? .green : .orange),
              ("High", "\(store.highSeverityValidationIssues.count)", .red),
              ("Low conf", "\(store.lowConfidenceValidationCount)", .orange),
              ("Duplicates", "\(store.duplicateValidationCount)", .purple)
            ])
            CompactValidationIssueList(issues: Array(store.validationIssues.prefix(4)), store: store)
          }
        }

        AnalyticsSection(title: "Recent activity", symbol: "list.clipboard.fill") {
          CompactAuditList(events: store.recentAuditEvents, store: store)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Daily operations")
          .font(isCompact ? .title.bold() : .largeTitle.bold())
        Text("Start here, then move through Inbox, Orders, Workbench, Dispatch, Tasks, and Audit.")
          .foregroundStyle(.secondary)
      }
      CompactActionRow {
        Button("Create manual order", systemImage: "plus", action: store.createManualOrderPlaceholder)
          .buttonStyle(.borderedProminent)
        Button("Import local test mail", systemImage: "arrow.clockwise", action: store.syncSources)
          .buttonStyle(.bordered)
      }
    }
  }

  private var dailyStartDecisionPanel: some View {
    SettingsPanel(title: "Start here", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: dailyStartTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(dailyStartTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(dailyStartTitle)
              .font(.headline)
            Text(dailyStartDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Inbox", "\(incomingAttentionCount)", incomingAttentionCount == 0 ? .green : .orange),
          ("Orders", "\(problemOrdersCount)", problemOrdersCount == 0 ? .green : .red),
          ("Workbench", "\(store.highPriorityWorkbenchItems.count)", store.highPriorityWorkbenchItems.isEmpty ? .green : .purple),
          ("Dispatch", "\(dispatchAttentionCount)", dispatchAttentionCount == 0 ? .green : .blue),
          ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
          ("Tasks", "\(taskAttentionCount)", taskAttentionCount == 0 ? .green : .orange)
        ])
      }
    }
  }

  private var dailyOperatorStart: some View {
    VStack(alignment: .leading, spacing: 16) {
      AnalyticsSection(title: "What needs attention now", symbol: "exclamationmark.triangle.fill") {
        OperatorDailyWorkloadSummary(
          dailyAttentionCount: attentionNowCount,
          advancedBacklogCount: advancedBacklogCount,
          reviewQueueCount: store.reviewQueueCount,
          detailWhenBusy: "Start with the cards below. The advanced backlog is still available, but it is not the first daily operating queue."
        )

        FilterControlGrid {
          TextField("Find daily work: Inbox, SpaceMail, orders, dispatch, tasks", text: $dashboardSearchText)
            .textFieldStyle(.roundedBorder)
          Badge("\(visibleDashboardMatchCount) daily areas", color: visibleDashboardMatchCount == 0 ? .orange : .blue)
          if !normalizedDashboardSearch.isEmpty {
            Button("Clear filter", systemImage: "xmark.circle") {
              dashboardSearchText = ""
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleDashboardMatchCount == 0 {
          MVPEmptyState(
            title: "No daily areas match",
            detail: "Clear the Dashboard filter or try Inbox, SpaceMail, order, dispatch, task, workbench, or audit.",
            symbol: "magnifyingglass"
          )
        }

        LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 12) {
          if dashboardMatches("inbox", "mailbox", "spacemail", "email", "parser", "import", "acceptance", "triage", "intake") {
            OperatorDashboardCard(
              title: "Inbox",
              count: incomingAttentionCount,
              detail: "Forwarded emails, parser diagnostics, import items, and acceptance records waiting for triage.",
              nextAction: incomingAttentionCount == 0 ? "Inbox is clear" : "Triage incoming work",
              symbol: "tray.full.fill",
              tint: incomingAttentionCount == 0 ? .green : .orange
            ) {
              InboxView(store: store)
            }
          }

          if dashboardMatches("orders", "order", "tracking", "customer", "destination", "inbox-created") {
            OperatorDashboardCard(
              title: "Orders",
              count: problemOrdersCount,
              detail: "Review-needed orders, exceptions, warning tracking events, and orders newly created from Inbox.",
              nextAction: partialInboxOrderBlockers.isEmpty ? (inboxCreatedOrders.isEmpty ? (problemOrdersCount == 0 ? "Orders look steady" : "Review problem orders") : "Review Inbox-created orders") : "Verify missing Inbox details",
              symbol: "shippingbox.fill",
              tint: partialInboxOrderBlockers.isEmpty ? (inboxCreatedOrders.isEmpty ? (problemOrdersCount == 0 ? .green : .red) : .purple) : .orange
            ) {
              OrdersView(store: store)
            }
          }

          if dashboardMatches("workbench", "exception", "validation", "reconciliation", "high-priority") {
            OperatorDashboardCard(
              title: "Workbench",
              count: store.highPriorityWorkbenchItems.count,
              detail: "Highest-priority local work from exceptions, validation, reconciliation, and follow-up records.",
              nextAction: store.highPriorityWorkbenchItems.isEmpty ? "No urgent workbench items" : "Open high-priority work",
              symbol: "rectangle.stack.badge.person.crop.fill",
              tint: store.highPriorityWorkbenchItems.isEmpty ? .green : .purple
            ) {
              OperationsWorkbenchView(store: store)
            }
          }

          if dashboardMatches("dispatch", "manifest", "readiness", "outbound", "handoff", "reopened") {
            OperatorDashboardCard(
              title: "Dispatch",
              count: dispatchAttentionCount,
              detail: "Blocked manifests, reopened handoffs, undispatched batches, incomplete checklists, and Inbox-created orders that need verification or dispatch setup.",
              nextAction: reopenedInboxDispatchHandoffCount > 0 ? "Review reopened handoffs" : partialInboxOrderBlockers.isEmpty ? (inboxDispatchGapOrders.isEmpty ? (dispatchAttentionCount == 0 ? "Dispatch queue is steady" : "Prepare outbound work") : "Add dispatch setup") : "Verify order details first",
              symbol: "shippingbox.and.arrow.backward.fill",
              tint: reopenedInboxDispatchHandoffCount > 0 ? .purple : partialInboxOrderBlockers.isEmpty ? (dispatchAttentionCount == 0 ? .green : .blue) : .orange
            ) {
              DispatchView(store: store)
            }
          }

          if dashboardMatches("tasks", "task", "handoff", "draft", "follow-up", "overdue") {
            OperatorDashboardCard(
              title: "Tasks",
              count: taskAttentionCount,
              detail: "Open review tasks, handoff notes, and draft messages that need ownership, completion, or local send status.",
              nextAction: taskAttentionCount == 0 ? "No task escalations" : "Work follow-ups and drafts",
              symbol: "checklist",
              tint: taskAttentionCount == 0 ? .green : .orange
            ) {
              TasksView(store: store)
            }
          }

          if dashboardMatches("audit", "activity", "history", "record change", "workflow") {
            OperatorDashboardCard(
              title: "Audit",
              count: store.recentAuditEvents.count,
              detail: "Recent local actions, record changes, reviews, creates, removes, tasks, and drafts.",
              nextAction: "Check recent activity",
              symbol: "list.clipboard.fill",
              tint: .teal
            ) {
              AuditView(store: store)
            }
          }
        }
      }

      LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 14) {
        if dashboardMatches("incoming order intake", "inbox", "mailbox", "spacemail", "parser", "import", "acceptance") {
          AnalyticsSection(title: "Incoming order intake", symbol: "tray.full.fill") {
            MetricStrip(items: [
              ("Triage", "\(incomingAttentionCount)", incomingAttentionCount == 0 ? .green : .orange),
              ("Emails", "\(store.reviewIntakeEmails.count)", .blue),
              ("Mailbox", "\(spaceMailHealthAttentionCount)", spaceMailHealthAttentionCount == 0 ? .green : .orange),
              ("Imports", "\(store.importQueueItemsNeedingReview.count + store.blockedImportQueueItems.count)", .purple),
              ("Acceptance", "\(store.acceptanceRecordsNeedingReview.count)", .teal)
            ])
            SpaceMailPrimaryStatusStrip(store: store, showTitle: false)
            CompactSpaceMailActionPlan(plan: store.spaceMailPostRefreshActionPlan)
            CompactSpaceMailHealthList(summaries: store.spaceMailIntakeHealthSummaries, store: store)
            CompactIntakeList(emails: store.newestIntakeEmails, store: store)
          }
        }

        if dashboardMatches("active problem orders", "orders", "tracking", "inbox-created", "customer", "destination") {
          AnalyticsSection(title: "Active/problem orders", symbol: "shippingbox.fill") {
            MetricStrip(items: [
              ("Active", "\(store.activeCount)", .teal),
              ("Review", "\(store.reviewOrders.count)", .orange),
              ("From Inbox", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .green : .purple),
              ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
              ("Tracking", "\(store.trackingWarningCount + store.criticalTrackingCount)", .red),
              ("Delivered", "\(store.deliveredCount)", .green)
            ])
            CompactPartialInboxOrderList(orders: Array(partialInboxOrderBlockers.prefix(4)), store: store)
            CompactInboxCreatedOrderList(orders: Array(inboxCreatedOrders.prefix(3)), store: store)
            CompactOrderList(orders: Array((store.reviewOrders + store.orders.filter { $0.status == .exception || $0.status == .inTransit || $0.status == .shipped }).prefix(4)), store: store)
          }
        }

        if dashboardMatches("dispatch readiness", "dispatch", "manifest", "readiness", "blocked", "undispatched", "reopened") {
          AnalyticsSection(title: "Dispatch readiness", symbol: "shippingbox.and.arrow.backward.fill") {
            MetricStrip(items: [
              ("Blocked", "\(store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count)", .red),
              ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
              ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
              ("Inbox gaps", "\(inboxDispatchGapOrders.count)", inboxDispatchGapOrders.isEmpty ? .green : .purple),
              ("Inbox setup", "\(inboxDispatchSetupPendingOrders.count)", inboxDispatchSetupPendingOrders.isEmpty ? .green : .teal),
              ("Undispatched", "\(store.undispatchedShipmentManifests.count)", .blue),
              ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .orange),
              ("Review", "\(store.shipmentManifestsNeedingReview.count + store.dispatchChecklistsNeedingReview.count)", .purple)
            ])
            CompactPartialInboxOrderList(orders: Array(partialInboxOrderBlockers.prefix(4)), store: store)
            CompactReopenedInboxDispatchHandoffList(manifests: Array(reopenedInboxDispatchManifests.prefix(3)), checklists: Array(reopenedInboxDispatchChecklists.prefix(3)), store: store)
            CompactInboxDispatchGapList(orders: Array(inboxDispatchGapOrders.prefix(4)), store: store)
            CompactInboxDispatchSetupList(orders: Array(inboxDispatchSetupPendingOrders.prefix(4)), store: store)
            CompactShipmentManifestList(records: Array((store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests).prefix(4)), store: store)
          }
        }

        if dashboardMatches("open tasks handoffs drafts", "tasks", "handoff", "draft", "overdue", "high") {
          AnalyticsSection(title: "Open tasks, handoffs, and drafts", symbol: "checklist") {
            MetricStrip(items: [
              ("Tasks", "\(store.reviewTasksNeedingAttention.count)", .orange),
              ("Handoffs", "\(store.handoffNotesNeedingAttention.count)", .blue),
              ("Drafts", "\(store.draftMessagesNeedingReview.count)", store.draftMessagesNeedingReview.isEmpty ? .green : .purple),
              ("Overdue", "\(store.overdueOpenReviewTasks.count + store.overdueHandoffNotes.count)", .red),
              ("High", "\(store.highPriorityHandoffNotes.count + store.reviewTasks.filter { $0.priority == .high || $0.priority == .urgent }.count)", .red)
            ])
            CompactTaskList(tasks: Array(store.reviewTasksNeedingAttention.prefix(3)), store: store)
            CompactHandoffNoteList(notes: Array(store.handoffNotesNeedingAttention.prefix(3)), store: store)
            CompactDraftMessageList(drafts: Array(store.draftMessagesNeedingReview.prefix(3)), store: store)
          }
        }
      }

      if dashboardMatches("recent local activity", "audit", "activity", "recent", "history") {
        AnalyticsSection(title: "Recent local activity", symbol: "list.clipboard.fill") {
          if store.recentAuditEvents.isEmpty {
            MVPEmptyState(title: "No recent local activity", detail: "Create, edit, review, accept, dispatch, or complete a local record and it will appear here.", symbol: "list.clipboard.fill")
          } else {
            CompactAuditList(events: store.recentAuditEvents, store: store)
          }
        }
      }
    }
  }

  private func dashboardMatches(_ terms: String...) -> Bool {
    let query = normalizedDashboardSearch
    guard !query.isEmpty else { return true }
    return terms.contains { $0.localizedLowercase.contains(query) }
  }

  private func isInboxCreatedOrder(_ order: TrackedOrder) -> Bool {
    dashboardIsInboxCreatedOrder(order)
  }

  private func hasPartialInboxOrderTask(_ order: TrackedOrder) -> Bool {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString).contains { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }
  }

  private func inboxDispatchHandoffCompleted(_ order: TrackedOrder) -> Bool {
    if order.latestStatus.localizedCaseInsensitiveContains("Inbox dispatch handoff completed") {
      return true
    }

    let manifests = store.suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
    let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
    guard !manifests.isEmpty || !checklists.isEmpty else { return false }
    return manifests.allSatisfy { $0.dispatchStatus == .handedOff }
      && checklists.allSatisfy { $0.checklistStatus == .completed }
  }
}

private extension ReviewTask {
  var isPartialInboxOrderFollowUp: Bool {
    linkedEntityType == .order
      && title.localizedCaseInsensitiveContains("Verify Inbox-created order")
      && summary.localizedCaseInsensitiveContains("Confirm missing")
  }
}

private extension TrackedOrder {
  var missingInboxOrderFieldCount: Int {
    [orderNumber, trackingNumber, destination]
      .filter { value in
        value == "Pending" || value == "Pending review" || value.isPlaceholderValidationValue
      }
      .count
  }
}

private extension ShipmentManifestRecord {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Dispatch setup for")
          || manifestReferencePlaceholder.localizedCaseInsensitiveContains("INBOX-")
          || notes.localizedCaseInsensitiveContains("Inbox handoff")
      )
  }
}

private extension DispatchReadinessChecklist {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Readiness for")
          || completedChecksSummary.localizedCaseInsensitiveContains("Inbox handoff")
          || missingRequirementsSummary.localizedCaseInsensitiveContains("handoff location")
      )
  }
}

private struct OperatorDashboardCard<Destination: View>: View {
  var title: String
  var count: Int
  var detail: String
  var nextAction: String
  var symbol: String
  var tint: Color
  @ViewBuilder var destination: Destination
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    NavigationLink {
      destination
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: symbol)
            .foregroundStyle(tint)
            .frame(width: 26)
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.headline)
            Text(detail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Text("\(count)")
            .font(.title2.bold())
            .foregroundStyle(tint)
        }

        Label(nextAction, systemImage: "arrow.right.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
          .lineLimit(isCompact ? 2 : 1)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
    .buttonStyle(.plain)
  }
}

struct MVPReadinessCallout: View {
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "checklist")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("MVP readiness")
            .font(.headline)
          Text("ParcelOps is local-only right now. Use it to test order intake, exception review, dispatch preparation, tasks, and audit before connecting live services.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge("Local prototype", color: .orange)
      }

      MetricStrip(items: [
        ("Review queue", "\(store.reviewQueueCount)", .orange),
        ("Open work", "\(store.openWorkbenchItems.count)", .blue),
        ("Manifests", "\(store.shipmentManifestRecords.count)", .purple),
        ("Readiness", "\(store.dispatchReadinessChecklists.count)", .teal)
      ])

      SpaceMailMVPReadinessCard(summary: store.spaceMailMVPReadinessSummary, showChecklist: false)
    }
    .padding(16)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MVPHandsOnDashboardStatus: View {
  var store: ParcelOpsStore

  private var inboxCreatedOrdersCount: Int {
    store.orders.filter { order in
      order.source == .forwardedMailbox || order.checkedMailbox == "manual-import"
    }.count
  }

  private var hasManualRefresh: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var blockedDailyCount: Int {
    store.blockedWorkbenchItems.count + store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count
  }

  private var tone: Color {
    if !hasManualRefresh { return .orange }
    if store.reviewIntakeEmails.isEmpty && inboxCreatedOrdersCount == 0 { return .orange }
    if blockedDailyCount > 0 { return .red }
    return .green
  }

  private var title: String {
    if !hasManualRefresh { return "Run one supervised intake test" }
    if store.reviewIntakeEmails.isEmpty && inboxCreatedOrdersCount == 0 { return "Create or link one intake order" }
    if blockedDailyCount > 0 { return "Resolve blocked daily work" }
    return "Hands-on test path is ready"
  }

  private var detail: String {
    if !hasManualRefresh {
      return "Start in Mailbox Monitor, run a manual SpaceMail refresh, then check imported, filtered, duplicate, and uncertain counts."
    }
    if store.reviewIntakeEmails.isEmpty && inboxCreatedOrdersCount == 0 {
      return "Use Inbox to import, reprocess, create, or link one order so the Dashboard, Orders, Workbench, Tasks, and Audit trail can be verified."
    }
    if blockedDailyCount > 0 {
      return "\(blockedDailyCount) blocked work item needs review before this is a clean release-candidate test run."
    }
    return "Use MVP Setup for the full checklist, then quit and reopen the app to confirm local JSON persistence."
  }

  var body: some View {
    SettingsPanel(title: "Hands-on test status", symbol: "checklist.checked") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: tone == .green ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(tone == .green ? "Ready" : "Check", color: tone)
      }

      MetricStrip(items: [
        ("SpaceMail runs", "\(store.spaceMailIMAPConnections.filter { $0.lastManualRefreshDate != "Never" }.count)", hasManualRefresh ? .green : .orange),
        ("Inbox review", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .secondary : .orange),
        ("Inbox orders", "\(inboxCreatedOrdersCount)", inboxCreatedOrdersCount == 0 ? .orange : .green),
        ("Blocked", "\(blockedDailyCount)", blockedDailyCount == 0 ? .green : .red),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
      ])

      Text("This card is local-only. It does not trigger refresh, background sync, mailbox mutation, Shopify, carrier APIs, OCR, scanners, notifications, or outbound email.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct AnalyticsSection<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: symbol)
        .font(.headline)
      content
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }
}

struct MetricCard: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(color)
      Text(value)
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text(title)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MetricStrip: View {
  var items: [(String, String, Color)]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var columns: [GridItem] {
    if isCompact {
      return [GridItem(.adaptive(minimum: 116), spacing: 8)]
    }
    return Array(repeating: GridItem(.flexible()), count: max(items.count, 1))
  }

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
      ForEach(items, id: \.0) { item in
        VStack(alignment: .leading, spacing: 4) {
          Text(item.1)
            .font(.title3.bold())
            .foregroundStyle(item.2)
          Text(item.0)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
      }
    }
  }
}

struct CompactIntakeList: View {
  var emails: [ForwardedEmailIntake]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Newest intake", symbol: "envelope.open.fill") {
      ForEach(emails) { email in
        NavigationLink {
          MailboxView(store: store)
        } label: {
          CompactRow(
            title: email.detectedOrderNumber,
            detail: "\(email.detectedMerchant) • \(email.subject)",
            badge: email.reviewState.rawValue,
            color: email.reviewState.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactSpaceMailHealthList: View {
  var summaries: [SpaceMailIntakeHealthSummary]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Mailbox intake health", symbol: "server.rack") {
      if summaries.isEmpty {
        NavigationLink {
          MailboxView(store: store)
        } label: {
          CompactRow(
            title: "No SpaceMail mailbox",
            detail: "Add a SpaceMail setup when you are ready to use real IMAP intake.",
            badge: "Setup",
            color: .secondary
          )
        }
        .buttonStyle(.plain)
      } else {
        ForEach(summaries.prefix(3)) { summary in
          NavigationLink {
            MailboxView(store: store)
          } label: {
            CompactRow(
              title: summary.verdict,
              detail: "\(summary.displayName) • \(summary.nextAction)",
              badge: "\(summary.importedCount) in / \(summary.filteredCount) filtered",
              color: color(for: summary)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func color(for summary: SpaceMailIntakeHealthSummary) -> Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .blue
    }
  }
}

struct CompactSpaceMailActionPlan: View {
  var plan: SpaceMailPostRefreshActionPlan

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.triangle.branch")
          .foregroundStyle(color(for: plan.tone))
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(plan.title)
            .font(.subheadline.weight(.semibold))
          Text(plan.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Next: \(plan.primaryAction)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: plan.tone))
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("SpaceMail", color: color(for: plan.tone))
      }

      CompactMetadataGrid(minimumWidth: 150) {
        ForEach(plan.items) { item in
          Label("\(item.title): \(item.count)", systemImage: item.symbol)
            .font(.caption)
            .foregroundStyle(color(for: item.tone))
            .lineLimit(2)
        }
      }

      Text("Use Mailbox Monitor for uncertain or filtered message review; use Inbox for imported order emails.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color(for: plan.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

private func dashboardIsInboxCreatedOrder(_ order: TrackedOrder) -> Bool {
  order.source == .forwardedMailbox
    || order.checkedMailbox == "manual-import"
    || order.latestStatus.localizedCaseInsensitiveContains("import queue")
    || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
    || order.latestStatus.localizedCaseInsensitiveContains("forwarded email")
}

private func dashboardOrderTimelineSignalCount(for order: TrackedOrder, store: ParcelOpsStore) -> Int {
  let taskCount = store.tasks(for: .order, linkedEntityID: order.id.uuidString).count
  let manifestCount = store.suggestedShipmentManifestRecords(for: order).count
  let checklistCount = store.suggestedDispatchReadinessChecklists(for: order).count
  let warningTrackingCount = store.trackingEvents(for: order.id).filter { event in
    event.severity == .watch || event.severity == .critical
  }.count

  return 1
    + (dashboardIsInboxCreatedOrder(order) ? 1 : 0)
    + taskCount
    + manifestCount
    + checklistCount
    + warningTrackingCount
}

private func dashboardOrderTimelineDetail(for order: TrackedOrder, store: ParcelOpsStore) -> String {
  let taskCount = store.tasks(for: .order, linkedEntityID: order.id.uuidString).count
  let manifestCount = store.suggestedShipmentManifestRecords(for: order).count
  let checklistCount = store.suggestedDispatchReadinessChecklists(for: order).count
  let warningTrackingCount = store.trackingEvents(for: order.id).filter { event in
    event.severity == .watch || event.severity == .critical
  }.count

  if dashboardIsInboxCreatedOrder(order) && (manifestCount + checklistCount) > 0 {
    return "Inbox handoff linked to dispatch setup • \(order.trackingNumber)"
  }
  if dashboardIsInboxCreatedOrder(order) {
    return "Inbox-created order needs local follow-up • \(order.trackingNumber)"
  }
  if taskCount > 0 {
    return "\(taskCount) linked task signal • \(order.customer)"
  }
  if (manifestCount + checklistCount) > 0 {
    return "Linked dispatch context • \(order.carrier) • \(order.trackingNumber)"
  }
  if warningTrackingCount > 0 {
    return "\(warningTrackingCount) tracking warning signal • \(order.carrier)"
  }
  return "\(order.customer) • \(order.carrier) • \(order.trackingNumber)"
}

struct CompactOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Active/problem orders", symbol: "shippingbox.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No problem orders",
          detail: "Active and review-needed orders will appear here.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : order.status.rawValue,
              color: timelineCount > 1 ? .blue : order.status.color
            )
          }
        }
      }
    }
  }
}

struct CompactInboxCreatedOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox-created orders", symbol: "tray.and.arrow.down.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox-created orders waiting",
          detail: "Orders created from Inbox triage will appear here for quick follow-up.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : order.reviewState.rawValue,
              color: timelineCount > 1 ? .purple : order.reviewState.color
            )
          }
        }
      }
    }
  }
}

struct CompactPartialInboxOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Verify before dispatch", symbol: "exclamationmark.triangle.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No partial Inbox order blockers",
          detail: "Inbox-created orders have no promoted missing-detail blocker.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: "\(dashboardOrderTimelineDetail(for: order, store: store)) • \(order.destination)",
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : "\(order.missingInboxOrderFieldCount) missing",
              color: .orange
            )
          }
        }
      }
    }
  }
}

struct CompactInboxDispatchGapList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox orders missing dispatch setup", symbol: "tray.and.arrow.down.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox dispatch gaps",
          detail: "Reviewed or active Inbox-created orders have no promoted dispatch setup gap.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : (order.reviewState == .accepted ? "Dispatch gap" : "Review first"),
              color: order.reviewState == .accepted ? .purple : .orange
            )
          }
        }
      }
    }
  }
}

struct CompactInboxDispatchSetupList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox dispatch setup pending", symbol: "checkmark.rectangle.stack.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox dispatch setup pending",
          detail: "Verified Inbox-created orders have no promoted readiness follow-up.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: checklists.first?.missingRequirementsSummary ?? "\(order.carrier) • \(order.trackingNumber)",
              badge: checklists.first?.checklistStatus.rawValue ?? "Readiness",
              color: .teal
            )
          }
        }
      }
    }
  }
}

struct CompactReopenedInboxDispatchHandoffList: View {
  var manifests: [ShipmentManifestRecord]
  var checklists: [DispatchReadinessChecklist]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Reopened Inbox dispatch handoffs", symbol: "arrow.counterclockwise.circle.fill") {
      if manifests.isEmpty && checklists.isEmpty {
        CompactRow(
          title: "No reopened handoffs",
          detail: "Inbox-created dispatch handoffs have no promoted reopened records.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(manifests) { manifest in
          NavigationLink {
            ShipmentManifestsView(store: store)
          } label: {
            CompactRow(
              title: manifest.title,
              detail: "\(manifest.carrierCourier) • planned \(manifest.plannedDispatchDate)",
              badge: manifest.dispatchStatus.rawValue,
              color: .purple
            )
          }
          .buttonStyle(.plain)
        }
        ForEach(checklists) { checklist in
          NavigationLink {
            DispatchReadinessView(store: store)
          } label: {
            CompactRow(
              title: checklist.title,
              detail: "\(checklist.assignedOwnerTeam) • \(checklist.missingRequirementsSummary)",
              badge: checklist.checklistStatus.rawValue,
              color: .purple
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct DashboardOrderCompactLink<Content: View>: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @ViewBuilder var content: Content

  var body: some View {
    NavigationLink {
      OrderDetailView(order: order, store: store)
    } label: {
      content
    }
    .buttonStyle(.plain)
  }
}

struct CompactWorkbenchList: View {
  var items: [WorkbenchItem]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Highest priority work", symbol: "rectangle.stack.badge.person.crop.fill") {
      ForEach(items) { item in
        NavigationLink {
          OperationsWorkbenchView(store: store)
        } label: {
          CompactRow(
            title: item.title,
            detail: "\(item.source.rawValue) • \(item.suggestedNextAction)",
            badge: item.prioritySeverity,
            color: item.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTrackingList: View {
  var events: [CarrierTrackingEvent]
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Highest risk tracking", symbol: "location.fill.viewfinder") {
      ForEach(events) { event in
        if let order = orders.first(where: { $0.id == event.orderID }) {
          NavigationLink {
            OrderDetailView(order: order, store: store)
          } label: {
            CompactRow(
              title: event.status,
              detail: "\(order.orderNumber) • \(event.carrier) • \(event.location)",
              badge: event.severity.rawValue,
              color: event.severity.color
            )
          }
          .buttonStyle(.plain)
        } else {
          NavigationLink {
            TrackingView(store: store)
          } label: {
            CompactRow(
              title: event.status,
              detail: "Unlinked • \(event.carrier) • \(event.location)",
              badge: event.severity.rawValue,
              color: event.severity.color
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

struct CompactEvidenceList: View {
  var attachments: [EvidenceAttachment]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Latest evidence", symbol: "paperclip") {
      ForEach(attachments) { attachment in
        NavigationLink {
          EvidenceView(store: store)
        } label: {
          CompactRow(
            title: attachment.fileName,
            detail: "\(attachment.fileType) • \(attachment.source.rawValue)",
            badge: attachment.reviewState.rawValue,
            color: attachment.reviewState.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAutomationList: View {
  var rules: [AutomationRule]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Automation rules", symbol: "arrow.triangle.branch") {
      ForEach(rules) { rule in
        NavigationLink {
          AutomationView(store: store)
        } label: {
          CompactRow(
            title: rule.name,
            detail: "\(rule.triggerType.rawValue) • \(rule.runCount) runs",
            badge: rule.isEnabled ? "Enabled" : "Disabled",
            color: rule.isEnabled ? .green : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTaskList: View {
  var tasks: [ReviewTask]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Task escalations", symbol: "checklist") {
      ForEach(tasks) { task in
        NavigationLink {
          TasksView(store: store)
        } label: {
          CompactRow(
            title: task.title,
            detail: "\(task.assignee) • due \(task.dueDate)",
            badge: task.priority.rawValue,
            color: task.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactHandoffNoteList: View {
  var notes: [HandoffNote]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
      ForEach(notes) { note in
        NavigationLink {
          HandoffNotesView(store: store)
        } label: {
          CompactRow(
            title: note.title,
            detail: "\(note.assignee) • due \(note.dueDate)",
            badge: note.status.rawValue,
            color: note.status.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactSLAPolicyList: View {
  var policies: [SLAPolicy]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent policy matches", symbol: "timer") {
      ForEach(policies) { policy in
        NavigationLink {
          SLAPoliciesView(store: store)
        } label: {
          CompactRow(
            title: policy.name,
            detail: "\(policy.linkedEntityType.rawValue) • \(policy.lastEvaluatedDate)",
            badge: "\(policy.matchCount)",
            color: policy.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactExceptionPlaybookList: View {
  var playbooks: [ExceptionPlaybook]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Exception playbooks", symbol: "book.closed.fill") {
      ForEach(playbooks) { playbook in
        NavigationLink {
          ExceptionPlaybooksView(store: store)
        } label: {
          CompactRow(
            title: playbook.name,
            detail: "\(playbook.issueType.rawValue) • \(playbook.escalationContact)",
            badge: playbook.priority.rawValue,
            color: playbook.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDraftMessageList: View {
  var drafts: [DraftMessage]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Draft messages", symbol: "envelope.open.fill") {
      ForEach(drafts) { draft in
        NavigationLink {
          CommunicationView(store: store)
        } label: {
          CompactRow(
            title: draft.subject,
            detail: "\(draft.recipient) • \(draft.channel.rawValue)",
            badge: draft.status.rawValue,
            color: draft.status.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactContactList: View {
  var contacts: [ContactDirectoryEntry]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Contacts needing review", symbol: "person.crop.circle.badge.checkmark") {
      ForEach(contacts) { contact in
        NavigationLink {
          ContactsView(store: store)
        } label: {
          CompactRow(
            title: contact.name,
            detail: "\(contact.organisation) • \(contact.channelPreference.rawValue)",
            badge: contact.reviewState.rawValue,
            color: contact.reviewState.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCustomerProfileList: View {
  var profiles: [CustomerRecipientProfile]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
      ForEach(profiles) { profile in
        NavigationLink {
          CustomerProfilesView(store: store)
        } label: {
          CompactRow(
            title: profile.displayName,
            detail: "\(profile.organisationTeam) • \(profile.deliveryPreference.rawValue)",
            badge: profile.isEnabled ? profile.reviewState.rawValue : "Disabled",
            color: profile.isEnabled ? profile.reviewState.color : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDestinationAddressList: View {
  var addresses: [DestinationAddressRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Destination addresses", symbol: "mappin.and.ellipse") {
      ForEach(addresses) { address in
        NavigationLink {
          DestinationAddressesView(store: store)
        } label: {
          CompactRow(
            title: address.label,
            detail: "\(address.addressLineSummary), \(address.cityRegion) • \(address.preferredCarrier)",
            badge: address.riskLevel.rawValue,
            color: address.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDeliveryInstructionList: View {
  var instructions: [DeliveryInstructionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
      ForEach(instructions) { instruction in
        NavigationLink {
          DeliveryInstructionsView(store: store)
        } label: {
          CompactRow(
            title: instruction.title,
            detail: "\(instruction.instructionType.rawValue) • \(instruction.preferredDeliveryWindow)",
            badge: instruction.riskLevel.rawValue,
            color: instruction.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactPackageContentList: View {
  var contents: [PackageContentRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Package contents", symbol: "shippingbox.circle.fill") {
      ForEach(contents) { content in
        NavigationLink {
          PackageContentsView(store: store)
        } label: {
          CompactRow(
            title: content.title,
            detail: "\(content.itemCategory.rawValue) • \(content.verifiedQuantity)/\(content.expectedQuantity) verified",
            badge: content.verificationStatus.rawValue,
            color: content.verificationStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCostRecordList: View {
  var costs: [CostRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Costs needing action", symbol: "creditcard.and.123") {
      ForEach(costs) { cost in
        NavigationLink {
          CostsBudgetsView(store: store)
        } label: {
          CompactRow(
            title: cost.title,
            detail: "\(cost.amountText) \(cost.currency) • \(cost.budgetCode)",
            badge: cost.approvalStatus.rawValue,
            color: cost.approvalStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactReturnClaimList: View {
  var claims: [ReturnClaimRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Returns and claims", symbol: "arrow.uturn.backward.square.fill") {
      ForEach(claims) { claim in
        NavigationLink {
          ReturnsClaimsView(store: store)
        } label: {
          CompactRow(
            title: claim.title,
            detail: "\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue)",
            badge: claim.claimStatus.rawValue,
            color: claim.claimStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactProcurementRequestList: View {
  var requests: [ProcurementRequest]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Procurement requests", symbol: "cart.badge.plus") {
      ForEach(requests) { request in
        NavigationLink {
          ProcurementView(store: store)
        } label: {
          CompactRow(
            title: request.title,
            detail: "\(request.estimatedCostText) \(request.currency) • \(request.budgetCode)",
            badge: request.procurementStatus.rawValue,
            color: request.procurementStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactReceivingInspectionList: View {
  var inspections: [ReceivingInspectionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Receiving inspections", symbol: "checklist.checked") {
      ForEach(inspections) { inspection in
        NavigationLink {
          ReceivingInspectionsView(store: store)
        } label: {
          CompactRow(
            title: inspection.title,
            detail: "\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received",
            badge: inspection.inspectionStatus.rawValue,
            color: inspection.inspectionStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactInventoryReceiptList: View {
  var receipts: [InventoryReceiptRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inventory receipts", symbol: "archivebox.fill") {
      ForEach(receipts) { receipt in
        NavigationLink {
          InventoryReceiptsView(store: store)
        } label: {
          CompactRow(
            title: receipt.title,
            detail: "\(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted • \(receipt.storageLocationSummary)",
            badge: receipt.stockHandoffStatus.rawValue,
            color: receipt.stockHandoffStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactStorageLocationList: View {
  var locations: [StorageLocationRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Storage locations", symbol: "cabinet.fill") {
      ForEach(locations) { location in
        NavigationLink {
          StorageLocationsView(store: store)
        } label: {
          CompactRow(
            title: location.title,
            detail: "\(location.locationCode) • \(location.areaZone)",
            badge: location.isEnabled ? "Enabled" : "Disabled",
            color: location.isEnabled ? .green : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCustodyRecordList: View {
  var records: [CustodyRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
      ForEach(records) { record in
        NavigationLink {
          CustodyChainView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.currentCustodianTeam) • \(record.expectedReturnCloseDate)",
            badge: record.custodyStatus.rawValue,
            color: record.custodyStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactLabelReferenceList: View {
  var records: [LabelReferenceRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Label references", symbol: "barcode.viewfinder") {
      ForEach(records) { record in
        NavigationLink {
          LabelReferencesView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.labelType.rawValue) • \(record.labelValuePlaceholder)",
            badge: record.labelStatus.rawValue,
            color: record.labelStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactScanSessionList: View {
  var records: [ScanSessionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Scan sessions", symbol: "qrcode.viewfinder") {
      ForEach(records) { record in
        NavigationLink {
          ScanSessionsView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.scanPurpose.rawValue) • \(record.capturedValuePlaceholder.isEmpty ? "Missing captured value" : record.capturedValuePlaceholder)",
            badge: record.scanStatus.rawValue,
            color: record.scanStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactShipmentManifestList: View {
  var records: [ShipmentManifestRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
      ForEach(records) { record in
        NavigationLink {
          ShipmentManifestsView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.carrierCourier) • \(record.destinationSummary)",
            badge: record.dispatchStatus.rawValue,
            color: record.dispatchStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDispatchReadinessList: View {
  var checklists: [DispatchReadinessChecklist]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
      ForEach(checklists) { checklist in
        NavigationLink {
          DispatchReadinessView(store: store)
        } label: {
          CompactRow(
            title: checklist.title,
            detail: "\(checklist.checklistType.rawValue) • \(checklist.plannedDispatchDate)",
            badge: checklist.checklistStatus.rawValue,
            color: checklist.checklistStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAccountList: View {
  var accounts: [AccountCredentialRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Accounts needing review", symbol: "key.horizontal.fill") {
      ForEach(accounts) { account in
        NavigationLink {
          AccountsView(store: store)
        } label: {
          CompactRow(
            title: account.accountName,
            detail: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
            badge: account.mfaStatus.rawValue,
            color: account.mfaStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactVendorProfileList: View {
  var profiles: [VendorProfile]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Profile watchlist", symbol: "building.2.crop.circle.fill") {
      ForEach(profiles) { profile in
        NavigationLink {
          VendorProfilesView(store: store)
        } label: {
          CompactRow(
            title: profile.name,
            detail: "\(profile.profileType.rawValue) • \(profile.primaryOrganisation)",
            badge: profile.riskLevel.rawValue,
            color: profile.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactShipmentGroupList: View {
  var groups: [ShipmentGroup]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Shipment group watchlist", symbol: "shippingbox.and.arrow.backward.fill") {
      ForEach(groups) { group in
        NavigationLink {
          ShipmentGroupsView(store: store)
        } label: {
          CompactRow(
            title: group.groupName,
            detail: "\(group.carrierSummary) • \(group.statusSummary)",
            badge: group.riskLevel.rawValue,
            color: group.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactImportQueueList: View {
  var items: [ImportQueueItem]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
      ForEach(items) { item in
        NavigationLink {
          ImportQueueView(store: store)
        } label: {
          CompactRow(
            title: item.sourceLabel,
            detail: "\(item.detectedMerchant) • \(item.detectedOrderNumber) • \(item.confidenceScore)%",
            badge: item.importStatus.rawValue,
            color: item.importStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAcceptanceList: View {
  var records: [AcceptanceRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Acceptance history", symbol: "checkmark.rectangle.stack.fill") {
      ForEach(records) { record in
        NavigationLink {
          AcceptanceReviewView(store: store)
        } label: {
          CompactRow(
            title: record.sourceLabel,
            detail: "\(record.sourceType.rawValue) • \(record.confidenceScore)% • \(record.decidedDate)",
            badge: record.decision.rawValue,
            color: record.decision.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAuditList: View {
  var events: [AuditEvent]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent audit", symbol: "list.clipboard.fill") {
      ForEach(events) { event in
        NavigationLink {
          AuditView(store: store)
        } label: {
          CompactRow(
            title: event.summary,
            detail: "\(event.entityType.rawValue) • \(event.entityLabel) • \(event.timestamp)",
            badge: event.action.rawValue,
            color: event.action.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTimelineList: View {
  var activities: [TimelineActivity]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent timeline", symbol: "clock.badge.exclamationmark.fill") {
      ForEach(activities) { activity in
        NavigationLink {
          TimelineView(store: store)
        } label: {
          CompactRow(
            title: activity.title,
            detail: "\(activity.entityType.rawValue) • \(activity.source.rawValue) • \(activity.timestampText)",
            badge: activity.risk.rawValue,
            color: activity.risk.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactValidationIssueList: View {
  var issues: [ValidationIssue]
  var store: ParcelOpsStore?

  var body: some View {
    CompactList(title: "Validation issues", symbol: "checkmark.seal.fill") {
      ForEach(issues) { issue in
        if let store {
          NavigationLink {
            ValidationView(store: store)
          } label: {
            CompactRow(
              title: issue.title,
              detail: "\(issue.entityType.rawValue) • \(issue.status.rawValue) • confidence \(issue.confidenceScore)%",
              badge: issue.severity.rawValue,
              color: issue.severity.color
            )
          }
          .buttonStyle(.plain)
        } else {
          CompactRow(
            title: issue.title,
            detail: "\(issue.entityType.rawValue) • \(issue.status.rawValue) • confidence \(issue.confidenceScore)%",
            badge: issue.severity.rawValue,
            color: issue.severity.color
          )
        }
      }
    }
  }
}

struct CompactReconciliationIssueList: View {
  var issues: [ReconciliationIssue]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Reconciliation issues", symbol: "arrow.triangle.2.circlepath.circle.fill") {
      ForEach(issues) { issue in
        NavigationLink {
          ReconciliationView(store: store)
        } label: {
          CompactRow(
            title: issue.title,
            detail: "\(issue.issueType.rawValue) • \(issue.sourceEntityType.rawValue) → \(issue.targetEntityType?.rawValue ?? "None")",
            badge: issue.severity.rawValue,
            color: issue.severity.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactList<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      VStack(spacing: 8) {
        content
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct CompactRow: View {
  var title: String
  var detail: String
  var badge: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
          .lineLimit(1)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Badge(badge, color: color)
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
