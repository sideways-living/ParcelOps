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

          AnalyticsSection(title: "SLA policies", symbol: "timer") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledSLAPolicyCount)", .green),
              ("Disabled", "\(store.disabledSLAPolicyCount)", .gray),
              ("Review", "\(store.policiesNeedingReview.count)", .orange),
              ("Overdue", "\(store.overdueOpenReviewTasks.count)", .red)
            ])
            CompactSLAPolicyList(policies: store.recentPolicyMatches)
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
