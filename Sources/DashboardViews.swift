import SwiftUI

struct DashboardView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var metricColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4)
  }
  private var sectionColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 14), count: isCompact ? 1 : 2)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header

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
              ("Open", "\(store.openWorkbenchItems.count)", .blue),
              ("Overdue", "\(store.overdueWorkbenchItems.count)", .red),
              ("Blocked", "\(store.blockedWorkbenchItems.count)", .red),
              ("Review", "\(store.workbenchItemsNeedingReview.count)", .orange)
            ])
            CompactWorkbenchList(items: Array(store.highPriorityWorkbenchItems.prefix(4)))
          }

          AnalyticsSection(title: "Review workload", symbol: "exclamationmark.triangle.fill") {
            MetricStrip(items: [
              ("Queue", "\(store.reviewQueueCount)", .orange),
              ("Intake", "\(store.reviewIntakeEmails.count)", .blue),
              ("Evidence", "\(store.reviewEvidenceAttachments.count)", .purple),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red)
            ])
            CompactIntakeList(emails: store.newestIntakeEmails)
          }

          AnalyticsSection(title: "Tracking health", symbol: "location.fill.viewfinder") {
            MetricStrip(items: [
              ("Warnings", "\(store.trackingWarningCount)", .orange),
              ("Critical", "\(store.criticalTrackingCount)", .red),
              ("Events", "\(store.carrierTrackingEvents.count)", .blue)
            ])
            CompactTrackingList(events: store.highestRiskTrackingEvents, orders: store.orders)
          }

          AnalyticsSection(title: "Evidence", symbol: "paperclip") {
            MetricStrip(items: [
              ("Total", "\(store.evidenceAttachments.count)", .blue),
              ("Needs review", "\(store.reviewEvidenceAttachments.count)", .orange)
            ])
            CompactEvidenceList(attachments: Array(store.evidenceAttachments.prefix(4)))
          }

          AnalyticsSection(title: "Automation", symbol: "arrow.triangle.branch") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAutomationRuleCount)", .green),
              ("Disabled", "\(store.disabledAutomationRuleCount)", .gray),
              ("Rules", "\(store.automationRules.count)", .teal)
            ])
            CompactAutomationList(rules: Array(store.automationRules.prefix(4)))
          }

          AnalyticsSection(title: "Tasks", symbol: "checklist") {
            MetricStrip(items: [
              ("Open", "\(store.openReviewTasks.count)", .blue),
              ("Attention", "\(store.reviewTasksNeedingAttention.count)", .orange),
              ("Total", "\(store.reviewTasks.count)", .teal)
            ])
            CompactTaskList(tasks: Array(store.reviewTasksNeedingAttention.prefix(4)))
          }

          AnalyticsSection(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
            MetricStrip(items: [
              ("Open", "\(store.openHandoffNotes.count)", .blue),
              ("Attention", "\(store.handoffNotesNeedingAttention.count)", .orange),
              ("Overdue", "\(store.overdueHandoffNotes.count)", .red),
              ("High", "\(store.highPriorityHandoffNotes.count)", .red)
            ])
            CompactHandoffNoteList(notes: Array(store.handoffNotesNeedingAttention.prefix(4)))
          }

          AnalyticsSection(title: "SLA policies", symbol: "timer") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledSLAPolicyCount)", .green),
              ("Disabled", "\(store.disabledSLAPolicyCount)", .gray),
              ("Review", "\(store.policiesNeedingReview.count)", .orange),
              ("Overdue", "\(store.overdueOpenReviewTasks.count)", .red)
            ])
            CompactSLAPolicyList(policies: store.recentPolicyMatches)
          }

          AnalyticsSection(title: "Exception playbooks", symbol: "book.closed.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledPlaybookCount)", .green),
              ("Disabled", "\(store.disabledPlaybookCount)", .gray),
              ("Review", "\(store.playbooksNeedingReview.count)", .orange),
              ("High", "\(store.enabledHighPriorityPlaybooks.count)", .red)
            ])
            CompactExceptionPlaybookList(playbooks: Array((store.playbooksNeedingReview + store.enabledHighPriorityPlaybooks).prefix(4)))
          }

          AnalyticsSection(title: "Communication", symbol: "bubble.left.and.text.bubble.right.fill") {
            MetricStrip(items: [
              ("Templates", "\(store.enabledCommunicationTemplateCount)", .green),
              ("Disabled", "\(store.disabledCommunicationTemplateCount)", .gray),
              ("Drafts", "\(store.draftMessages.count)", .blue),
              ("Review", "\(store.draftMessagesNeedingReview.count)", .orange)
            ])
            CompactDraftMessageList(drafts: Array(store.draftMessagesNeedingReview.prefix(4)))
          }

          AnalyticsSection(title: "Contacts", symbol: "person.crop.circle.badge.checkmark") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledContactCount)", .green),
              ("Disabled", "\(store.disabledContactCount)", .gray),
              ("Review", "\(store.contactsNeedingReview.count)", .orange),
              ("Total", "\(store.contactDirectoryEntries.count)", .blue)
            ])
            CompactContactList(contacts: Array(store.contactsNeedingReview.prefix(4)))
          }

          AnalyticsSection(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledCustomerProfileCount)", .green),
              ("Disabled", "\(store.disabledCustomerProfileCount)", .gray),
              ("Review", "\(store.customerProfilesNeedingReview.count)", .orange),
              ("Total", "\(store.customerRecipientProfiles.count)", .blue)
            ])
            CompactCustomerProfileList(profiles: Array((store.customerProfilesNeedingReview + store.customerRecipientProfiles.filter { !$0.isEnabled }).prefix(4)))
          }

          AnalyticsSection(title: "Destination addresses", symbol: "mappin.and.ellipse") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDestinationAddressCount)", .green),
              ("Disabled", "\(store.disabledDestinationAddressCount)", .gray),
              ("Review", "\(store.destinationAddressesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskDestinationAddresses.count)", .red)
            ])
            CompactDestinationAddressList(addresses: Array((store.destinationAddressesNeedingReview + store.highRiskDestinationAddresses + store.destinationAddresses.filter { !$0.isEnabled }).prefix(4)))
          }

          AnalyticsSection(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDeliveryInstructionCount)", .green),
              ("Disabled", "\(store.disabledDeliveryInstructionCount)", .gray),
              ("Review", "\(store.deliveryInstructionsNeedingReview.count)", .orange),
              ("Access", "\(store.deliveryInstructionsWithAccessConstraints.count)", .red)
            ])
            CompactDeliveryInstructionList(instructions: Array((store.deliveryInstructionsNeedingReview + store.highRiskDeliveryInstructions + store.deliveryInstructions.filter { !$0.isEnabled }).prefix(4)))
          }

          AnalyticsSection(title: "Package contents", symbol: "shippingbox.circle.fill") {
            MetricStrip(items: [
              ("Unverified", "\(store.unverifiedPackageContents.count)", .orange),
              ("Discrepancy", "\(store.packageContentDiscrepancies.count)", .red),
              ("High risk", "\(store.highRiskPackageContents.count)", .red),
              ("High value", "\(store.highValuePackageContents.count)", .purple)
            ])
            CompactPackageContentList(contents: Array((store.packageContentsNeedingReview + store.unverifiedPackageContents + store.packageContentDiscrepancies + store.highRiskPackageContents + store.highValuePackageContents).prefix(4)))
          }

          AnalyticsSection(title: "Costs & budgets", symbol: "creditcard.and.123") {
            MetricStrip(items: [
              ("Review", "\(store.costRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCostRecords.count)", .red),
              ("Unreimbursed", "\(store.unreimbursedCostRecords.count)", .orange),
              ("Missing budget", "\(store.missingBudgetCodeCostRecords.count)", .red)
            ])
            CompactCostRecordList(costs: Array((store.costRecordsNeedingReview + store.disputedCostRecords + store.unreimbursedCostRecords + store.unapprovedCostRecords + store.highRiskCostRecords + store.missingBudgetCodeCostRecords).prefix(4)))
          }

          AnalyticsSection(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
            MetricStrip(items: [
              ("Review", "\(store.returnClaimsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedReturnClaims.count)", .red),
              ("Unresolved", "\(store.unresolvedReturnClaims.count)", .orange),
              ("Missing evidence", "\(store.returnClaimsMissingEvidence.count)", .red)
            ])
            CompactReturnClaimList(claims: Array((store.returnClaimsNeedingReview + store.disputedReturnClaims + store.unresolvedReturnClaims + store.overdueReturnClaims + store.highRiskReturnClaims + store.returnClaimsMissingEvidence).prefix(4)))
          }

          AnalyticsSection(title: "Procurement", symbol: "cart.badge.plus") {
            MetricStrip(items: [
              ("Review", "\(store.procurementRequestsNeedingReview.count)", .orange),
              ("Unapproved", "\(store.unapprovedProcurementRequests.count)", .orange),
              ("Rejected", "\(store.rejectedProcurementRequests.count)", .red),
              ("Missing budget", "\(store.missingBudgetCodeProcurementRequests.count)", .red)
            ])
            CompactProcurementRequestList(requests: Array((store.procurementRequestsNeedingReview + store.unapprovedProcurementRequests + store.rejectedProcurementRequests + store.notYetOrderedProcurementRequests + store.overdueProcurementRequests + store.highRiskProcurementRequests + store.missingBudgetCodeProcurementRequests).prefix(4)))
          }

          AnalyticsSection(title: "Receiving inspections", symbol: "checklist.checked") {
            MetricStrip(items: [
              ("Review", "\(store.receivingInspectionsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedReceivingInspections.count)", .purple),
              ("Discrepancies", "\(store.unresolvedInspectionDiscrepancies.count)", .red),
              ("Qty mismatch", "\(store.quantityMismatchReceivingInspections.count)", .orange)
            ])
            CompactReceivingInspectionList(inspections: Array((store.receivingInspectionsNeedingReview + store.blockedReceivingInspections + store.unresolvedInspectionDiscrepancies + store.highRiskReceivingInspections + store.overdueReceivingInspections + store.quantityMismatchReceivingInspections).prefix(4)))
          }

          AnalyticsSection(title: "Inventory receipts", symbol: "archivebox.fill") {
            MetricStrip(items: [
              ("Review", "\(store.inventoryReceiptsNeedingReview.count)", .orange),
              ("Rejected", "\(store.rejectedInventoryReceipts.count)", .red),
              ("Partial", "\(store.partiallyAcceptedInventoryReceipts.count)", .orange),
              ("Missing storage", "\(store.inventoryReceiptsMissingStorage.count)", .red)
            ])
            CompactInventoryReceiptList(receipts: Array((store.inventoryReceiptsNeedingReview + store.rejectedInventoryReceipts + store.partiallyAcceptedInventoryReceipts + store.highRiskInventoryReceipts + store.unassignedInventoryReceipts + store.inventoryReceiptsMissingStorage).prefix(4)))
          }

          AnalyticsSection(title: "Storage locations", symbol: "cabinet.fill") {
            MetricStrip(items: [
              ("Review", "\(store.storageLocationsNeedingReview.count)", .orange),
              ("Disabled", "\(store.disabledStorageLocations.count)", .gray),
              ("Missing code", "\(store.storageLocationsMissingCodes.count)", .red),
              ("Capacity", "\(store.storageLocationsWithCapacityWarnings.count)", .red)
            ])
            CompactStorageLocationList(locations: Array((store.storageLocationsNeedingReview + store.disabledStorageLocations + store.highRiskStorageLocations + store.storageLocationsMissingCodes + store.storageLocationsWithAccessNotes + store.storageLocationsWithCapacityWarnings).prefix(4)))
          }

          AnalyticsSection(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
            MetricStrip(items: [
              ("Review", "\(store.custodyRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCustodyRecords.count)", .red),
              ("Open", "\(store.openCustodyTransfers.count)", .blue),
              ("Missing", "\(store.custodyRecordsMissingCustodians.count + store.custodyRecordsMissingLocations.count)", .red)
            ])
            CompactCustodyRecordList(records: Array((store.custodyRecordsNeedingReview + store.disputedCustodyRecords + store.openCustodyTransfers + store.overdueCustodyRecords + store.highRiskCustodyRecords + store.custodyRecordsMissingCustodians + store.custodyRecordsMissingLocations).prefix(4)))
          }

          AnalyticsSection(title: "Accounts", symbol: "key.horizontal.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAccountRecordCount)", .green),
              ("Disabled", "\(store.disabledAccountRecordCount)", .gray),
              ("Review", "\(store.accountRecordsNeedingReview.count)", .orange),
              ("Total", "\(store.accountCredentialRecords.count)", .blue)
            ])
            CompactAccountList(accounts: Array(store.accountRecordsNeedingReview.prefix(4)))
          }

          AnalyticsSection(title: "Vendor profiles", symbol: "building.2.crop.circle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledVendorProfileCount)", .green),
              ("Disabled", "\(store.disabledVendorProfileCount)", .gray),
              ("Review", "\(store.vendorProfilesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskEnabledVendorProfiles.count)", .red)
            ])
            CompactVendorProfileList(profiles: Array((store.vendorProfilesNeedingReview + store.highRiskEnabledVendorProfiles).prefix(4)))
          }

          AnalyticsSection(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
            MetricStrip(items: [
              ("Total", "\(store.shipmentGroups.count)", .blue),
              ("Review", "\(store.shipmentGroupsNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskShipmentGroups.count)", .red),
              ("Critical", "\(store.shipmentGroups.filter { $0.riskLevel == .critical }.count)", .red)
            ])
            CompactShipmentGroupList(groups: Array((store.shipmentGroupsNeedingReview + store.highRiskShipmentGroups).prefix(4)))
          }

          AnalyticsSection(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
            MetricStrip(items: [
              ("Total", "\(store.importQueueItems.count)", .blue),
              ("Review", "\(store.importQueueItemsNeedingReview.count)", .orange),
              ("Low conf", "\(store.lowConfidenceImportQueueItems.count)", .orange),
              ("Blocked", "\(store.blockedImportQueueItems.count)", .red)
            ])
            CompactImportQueueList(items: Array((store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview).prefix(4)))
          }

          AnalyticsSection(title: "Acceptance review", symbol: "checkmark.rectangle.stack.fill") {
            MetricStrip(items: [
              ("Ready", "\(store.acceptanceCandidates.filter { $0.decision == .ready }.count)", .blue),
              ("Accepted", "\(store.acceptedAcceptanceRecords.count)", .green),
              ("Blocked", "\(store.blockedAcceptanceRecords.count)", .red),
              ("Reopened", "\(store.reopenedAcceptanceRecords.count)", .orange)
            ])
            CompactAcceptanceList(records: Array((store.blockedAcceptanceRecords + store.reopenedAcceptanceRecords + store.ignoredAcceptanceRecords + store.acceptanceRecordsNeedingReview).prefix(4)))
          }

          AnalyticsSection(title: "Reconciliation", symbol: "arrow.triangle.2.circlepath.circle.fill") {
            MetricStrip(items: [
              ("Unresolved", "\(store.unresolvedReconciliationIssues.count)", .orange),
              ("High", "\(store.highSeverityReconciliationIssues.count)", .red),
              ("Conflicts", "\(store.reconciliationIssues.filter { $0.issueType == .orderNumberConflict || $0.issueType == .trackingNumberConflict || $0.issueType == .destinationConflict }.count)", .purple),
              ("Total", "\(store.reconciliationIssues.count)", .blue)
            ])
            CompactReconciliationIssueList(issues: Array(store.unresolvedReconciliationIssues.prefix(4)))
          }

          AnalyticsSection(title: "Timeline", symbol: "clock.badge.exclamationmark.fill") {
            MetricStrip(items: [
              ("Recent", "\(store.recentTimelineActivities.count)", .blue),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red),
              ("Critical", "\(store.timelineWatchlist.filter { $0.risk == .critical }.count)", .red),
              ("High", "\(store.timelineWatchlist.filter { $0.risk == .high }.count)", .orange)
            ])
            CompactTimelineList(activities: store.recentTimelineActivities)
          }

          AnalyticsSection(title: "Validation health", symbol: "checkmark.seal.fill") {
            MetricStrip(items: [
              ("Health", "\(store.validationHealthScore)%", store.validationHealthScore >= 80 ? .green : .orange),
              ("High", "\(store.highSeverityValidationIssues.count)", .red),
              ("Low conf", "\(store.lowConfidenceValidationCount)", .orange),
              ("Duplicates", "\(store.duplicateValidationCount)", .purple)
            ])
            CompactValidationIssueList(issues: Array(store.validationIssues.prefix(4)))
          }
        }

        AnalyticsSection(title: "Recent activity", symbol: "list.clipboard.fill") {
          CompactAuditList(events: store.recentAuditEvents)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Operations overview")
          .font(isCompact ? .title.bold() : .largeTitle.bold())
        Text("Current work across orders, intake, tracking, evidence, automation, and review.")
          .foregroundStyle(.secondary)
      }
      HStack {
        Button("Create manual order", systemImage: "plus", action: store.createManualOrderPlaceholder)
          .buttonStyle(.borderedProminent)
        Button("Sync", systemImage: "arrow.clockwise", action: store.syncSources)
          .buttonStyle(.bordered)
      }
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

  var body: some View {
    HStack(spacing: 8) {
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

  var body: some View {
    CompactList(title: "Newest intake", symbol: "envelope.open.fill") {
      ForEach(emails) { email in
        CompactRow(
          title: email.detectedOrderNumber,
          detail: "\(email.detectedMerchant) • \(email.subject)",
          badge: email.reviewState.rawValue,
          color: email.reviewState.color
        )
      }
    }
  }
}

struct CompactWorkbenchList: View {
  var items: [WorkbenchItem]

  var body: some View {
    CompactList(title: "Highest priority work", symbol: "rectangle.stack.badge.person.crop.fill") {
      ForEach(items) { item in
        CompactRow(
          title: item.title,
          detail: "\(item.source.rawValue) • \(item.suggestedNextAction)",
          badge: item.prioritySeverity,
          color: item.color
        )
      }
    }
  }
}

struct CompactTrackingList: View {
  var events: [CarrierTrackingEvent]
  var orders: [TrackedOrder]

  var body: some View {
    CompactList(title: "Highest risk tracking", symbol: "location.fill.viewfinder") {
      ForEach(events) { event in
        let orderNumber = orders.first { $0.id == event.orderID }?.orderNumber ?? "Unlinked"
        CompactRow(
          title: event.status,
          detail: "\(orderNumber) • \(event.carrier) • \(event.location)",
          badge: event.severity.rawValue,
          color: event.severity.color
        )
      }
    }
  }
}

struct CompactEvidenceList: View {
  var attachments: [EvidenceAttachment]

  var body: some View {
    CompactList(title: "Latest evidence", symbol: "paperclip") {
      ForEach(attachments) { attachment in
        CompactRow(
          title: attachment.fileName,
          detail: "\(attachment.fileType) • \(attachment.source.rawValue)",
          badge: attachment.reviewState.rawValue,
          color: attachment.reviewState.color
        )
      }
    }
  }
}

struct CompactAutomationList: View {
  var rules: [AutomationRule]

  var body: some View {
    CompactList(title: "Automation rules", symbol: "arrow.triangle.branch") {
      ForEach(rules) { rule in
        CompactRow(
          title: rule.name,
          detail: "\(rule.triggerType.rawValue) • \(rule.runCount) runs",
          badge: rule.isEnabled ? "Enabled" : "Disabled",
          color: rule.isEnabled ? .green : .gray
        )
      }
    }
  }
}

struct CompactTaskList: View {
  var tasks: [ReviewTask]

  var body: some View {
    CompactList(title: "Task escalations", symbol: "checklist") {
      ForEach(tasks) { task in
        CompactRow(
          title: task.title,
          detail: "\(task.assignee) • due \(task.dueDate)",
          badge: task.priority.rawValue,
          color: task.priority.color
        )
      }
    }
  }
}

struct CompactHandoffNoteList: View {
  var notes: [HandoffNote]

  var body: some View {
    CompactList(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
      ForEach(notes) { note in
        CompactRow(
          title: note.title,
          detail: "\(note.assignee) • due \(note.dueDate)",
          badge: note.status.rawValue,
          color: note.status.color
        )
      }
    }
  }
}

struct CompactSLAPolicyList: View {
  var policies: [SLAPolicy]

  var body: some View {
    CompactList(title: "Recent policy matches", symbol: "timer") {
      ForEach(policies) { policy in
        CompactRow(
          title: policy.name,
          detail: "\(policy.linkedEntityType.rawValue) • \(policy.lastEvaluatedDate)",
          badge: "\(policy.matchCount)",
          color: policy.priority.color
        )
      }
    }
  }
}

struct CompactExceptionPlaybookList: View {
  var playbooks: [ExceptionPlaybook]

  var body: some View {
    CompactList(title: "Exception playbooks", symbol: "book.closed.fill") {
      ForEach(playbooks) { playbook in
        CompactRow(
          title: playbook.name,
          detail: "\(playbook.issueType.rawValue) • \(playbook.escalationContact)",
          badge: playbook.priority.rawValue,
          color: playbook.priority.color
        )
      }
    }
  }
}

struct CompactDraftMessageList: View {
  var drafts: [DraftMessage]

  var body: some View {
    CompactList(title: "Draft messages", symbol: "envelope.open.fill") {
      ForEach(drafts) { draft in
        CompactRow(
          title: draft.subject,
          detail: "\(draft.recipient) • \(draft.channel.rawValue)",
          badge: draft.status.rawValue,
          color: draft.status.color
        )
      }
    }
  }
}

struct CompactContactList: View {
  var contacts: [ContactDirectoryEntry]

  var body: some View {
    CompactList(title: "Contacts needing review", symbol: "person.crop.circle.badge.checkmark") {
      ForEach(contacts) { contact in
        CompactRow(
          title: contact.name,
          detail: "\(contact.organisation) • \(contact.channelPreference.rawValue)",
          badge: contact.reviewState.rawValue,
          color: contact.reviewState.color
        )
      }
    }
  }
}

struct CompactCustomerProfileList: View {
  var profiles: [CustomerRecipientProfile]

  var body: some View {
    CompactList(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
      ForEach(profiles) { profile in
        CompactRow(
          title: profile.displayName,
          detail: "\(profile.organisationTeam) • \(profile.deliveryPreference.rawValue)",
          badge: profile.isEnabled ? profile.reviewState.rawValue : "Disabled",
          color: profile.isEnabled ? profile.reviewState.color : .gray
        )
      }
    }
  }
}

struct CompactDestinationAddressList: View {
  var addresses: [DestinationAddressRecord]

  var body: some View {
    CompactList(title: "Destination addresses", symbol: "mappin.and.ellipse") {
      ForEach(addresses) { address in
        CompactRow(
          title: address.label,
          detail: "\(address.addressLineSummary), \(address.cityRegion) • \(address.preferredCarrier)",
          badge: address.riskLevel.rawValue,
          color: address.riskLevel.color
        )
      }
    }
  }
}

struct CompactDeliveryInstructionList: View {
  var instructions: [DeliveryInstructionRecord]

  var body: some View {
    CompactList(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
      ForEach(instructions) { instruction in
        CompactRow(
          title: instruction.title,
          detail: "\(instruction.instructionType.rawValue) • \(instruction.preferredDeliveryWindow)",
          badge: instruction.riskLevel.rawValue,
          color: instruction.riskLevel.color
        )
      }
    }
  }
}

struct CompactPackageContentList: View {
  var contents: [PackageContentRecord]

  var body: some View {
    CompactList(title: "Package contents", symbol: "shippingbox.circle.fill") {
      ForEach(contents) { content in
        CompactRow(
          title: content.title,
          detail: "\(content.itemCategory.rawValue) • \(content.verifiedQuantity)/\(content.expectedQuantity) verified",
          badge: content.verificationStatus.rawValue,
          color: content.verificationStatus.color
        )
      }
    }
  }
}

struct CompactCostRecordList: View {
  var costs: [CostRecord]

  var body: some View {
    CompactList(title: "Costs needing action", symbol: "creditcard.and.123") {
      ForEach(costs) { cost in
        CompactRow(
          title: cost.title,
          detail: "\(cost.amountText) \(cost.currency) • \(cost.budgetCode)",
          badge: cost.approvalStatus.rawValue,
          color: cost.approvalStatus.color
        )
      }
    }
  }
}

struct CompactReturnClaimList: View {
  var claims: [ReturnClaimRecord]

  var body: some View {
    CompactList(title: "Returns and claims", symbol: "arrow.uturn.backward.square.fill") {
      ForEach(claims) { claim in
        CompactRow(
          title: claim.title,
          detail: "\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue)",
          badge: claim.claimStatus.rawValue,
          color: claim.claimStatus.color
        )
      }
    }
  }
}

struct CompactProcurementRequestList: View {
  var requests: [ProcurementRequest]

  var body: some View {
    CompactList(title: "Procurement requests", symbol: "cart.badge.plus") {
      ForEach(requests) { request in
        CompactRow(
          title: request.title,
          detail: "\(request.estimatedCostText) \(request.currency) • \(request.budgetCode)",
          badge: request.procurementStatus.rawValue,
          color: request.procurementStatus.color
        )
      }
    }
  }
}

struct CompactReceivingInspectionList: View {
  var inspections: [ReceivingInspectionRecord]

  var body: some View {
    CompactList(title: "Receiving inspections", symbol: "checklist.checked") {
      ForEach(inspections) { inspection in
        CompactRow(
          title: inspection.title,
          detail: "\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received",
          badge: inspection.inspectionStatus.rawValue,
          color: inspection.inspectionStatus.color
        )
      }
    }
  }
}

struct CompactInventoryReceiptList: View {
  var receipts: [InventoryReceiptRecord]

  var body: some View {
    CompactList(title: "Inventory receipts", symbol: "archivebox.fill") {
      ForEach(receipts) { receipt in
        CompactRow(
          title: receipt.title,
          detail: "\(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted • \(receipt.storageLocationSummary)",
          badge: receipt.stockHandoffStatus.rawValue,
          color: receipt.stockHandoffStatus.color
        )
      }
    }
  }
}

struct CompactStorageLocationList: View {
  var locations: [StorageLocationRecord]

  var body: some View {
    CompactList(title: "Storage locations", symbol: "cabinet.fill") {
      ForEach(locations) { location in
        CompactRow(
          title: location.title,
          detail: "\(location.locationCode) • \(location.areaZone)",
          badge: location.isEnabled ? "Enabled" : "Disabled",
          color: location.isEnabled ? .green : .gray
        )
      }
    }
  }
}

struct CompactCustodyRecordList: View {
  var records: [CustodyRecord]

  var body: some View {
    CompactList(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
      ForEach(records) { record in
        CompactRow(
          title: record.title,
          detail: "\(record.currentCustodianTeam) • \(record.expectedReturnCloseDate)",
          badge: record.custodyStatus.rawValue,
          color: record.custodyStatus.color
        )
      }
    }
  }
}

struct CompactAccountList: View {
  var accounts: [AccountCredentialRecord]

  var body: some View {
    CompactList(title: "Accounts needing review", symbol: "key.horizontal.fill") {
      ForEach(accounts) { account in
        CompactRow(
          title: account.accountName,
          detail: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
          badge: account.mfaStatus.rawValue,
          color: account.mfaStatus.color
        )
      }
    }
  }
}

struct CompactVendorProfileList: View {
  var profiles: [VendorProfile]

  var body: some View {
    CompactList(title: "Profile watchlist", symbol: "building.2.crop.circle.fill") {
      ForEach(profiles) { profile in
        CompactRow(
          title: profile.name,
          detail: "\(profile.profileType.rawValue) • \(profile.primaryOrganisation)",
          badge: profile.riskLevel.rawValue,
          color: profile.riskLevel.color
        )
      }
    }
  }
}

struct CompactShipmentGroupList: View {
  var groups: [ShipmentGroup]

  var body: some View {
    CompactList(title: "Shipment group watchlist", symbol: "shippingbox.and.arrow.backward.fill") {
      ForEach(groups) { group in
        CompactRow(
          title: group.groupName,
          detail: "\(group.carrierSummary) • \(group.statusSummary)",
          badge: group.riskLevel.rawValue,
          color: group.riskLevel.color
        )
      }
    }
  }
}

struct CompactImportQueueList: View {
  var items: [ImportQueueItem]

  var body: some View {
    CompactList(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
      ForEach(items) { item in
        CompactRow(
          title: item.sourceLabel,
          detail: "\(item.detectedMerchant) • \(item.detectedOrderNumber) • \(item.confidenceScore)%",
          badge: item.importStatus.rawValue,
          color: item.importStatus.color
        )
      }
    }
  }
}

struct CompactAcceptanceList: View {
  var records: [AcceptanceRecord]

  var body: some View {
    CompactList(title: "Acceptance history", symbol: "checkmark.rectangle.stack.fill") {
      ForEach(records) { record in
        CompactRow(
          title: record.sourceLabel,
          detail: "\(record.sourceType.rawValue) • \(record.confidenceScore)% • \(record.decidedDate)",
          badge: record.decision.rawValue,
          color: record.decision.color
        )
      }
    }
  }
}

struct CompactAuditList: View {
  var events: [AuditEvent]

  var body: some View {
    CompactList(title: "Recent audit", symbol: "list.clipboard.fill") {
      ForEach(events) { event in
        CompactRow(
          title: event.summary,
          detail: "\(event.entityType.rawValue) • \(event.entityLabel) • \(event.timestamp)",
          badge: event.action.rawValue,
          color: event.action.color
        )
      }
    }
  }
}

struct CompactTimelineList: View {
  var activities: [TimelineActivity]

  var body: some View {
    CompactList(title: "Recent timeline", symbol: "clock.badge.exclamationmark.fill") {
      ForEach(activities) { activity in
        CompactRow(
          title: activity.title,
          detail: "\(activity.entityType.rawValue) • \(activity.source.rawValue) • \(activity.timestampText)",
          badge: activity.risk.rawValue,
          color: activity.risk.color
        )
      }
    }
  }
}

struct CompactValidationIssueList: View {
  var issues: [ValidationIssue]

  var body: some View {
    CompactList(title: "Validation issues", symbol: "checkmark.seal.fill") {
      ForEach(issues) { issue in
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

struct CompactReconciliationIssueList: View {
  var issues: [ReconciliationIssue]

  var body: some View {
    CompactList(title: "Reconciliation issues", symbol: "arrow.triangle.2.circlepath.circle.fill") {
      ForEach(issues) { issue in
        CompactRow(
          title: issue.title,
          detail: "\(issue.issueType.rawValue) • \(issue.sourceEntityType.rawValue) → \(issue.targetEntityType?.rawValue ?? "None")",
          badge: issue.severity.rawValue,
          color: issue.severity.color
        )
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
