import SwiftUI

private enum WishlistWorkflowFocus: String, CaseIterable, Identifiable {
  case all = "All"
  case capture = "Capture"
  case compare = "Compare"
  case buy = "Buy"
  case watch = "Watch"
  case operations = "Operations"

  var id: String { rawValue }
  var title: String { rawValue }

  var detail: String {
    switch self {
    case .all:
      return "Show every active Wishlist item."
    case .capture:
      return "Items still need basic item, seller, source, or capture details before comparison."
    case .compare:
      return "Items need seller options, landed cost, postage, trust, or recommendation review."
    case .buy:
      return "Items are in purchase decision, checklist, or manual handoff preparation."
    case .watch:
      return "Items have purchase handoff/order-watch state and need order confirmation linking."
    case .operations:
      return "Items are linked or confirmed enough to stage receiving, storage, custody, and dispatch records."
    }
  }

  var color: Color {
    switch self {
    case .all: return .blue
    case .capture: return .blue
    case .compare: return .orange
    case .buy: return .purple
    case .watch: return .green
    case .operations: return .teal
    }
  }

  func matches(item: WishlistItem, in store: ParcelOpsStore) -> Bool {
    switch self {
    case .all:
      return true
    case .capture:
      return item.comparisonOptions?.isEmpty != false
        && item.purchaseDecision == nil
        && item.purchaseHandoff == nil
    case .compare:
      return item.comparisonOptions?.isEmpty == false
        && (item.purchaseDecision == nil || item.purchaseDecision?.reviewState == .needsReview)
        && item.purchaseHandoff == nil
    case .buy:
      return item.purchaseDecision != nil
        && item.purchaseHandoff == nil
        || item.purchaseReadiness?.localizedCaseInsensitiveContains("purchase") == true
          && item.purchaseHandoff == nil
    case .watch:
      return item.purchaseHandoff != nil
        && item.purchaseHandoff?.linkedOrderID == nil
    case .operations:
      return item.purchaseHandoff?.linkedOrderID != nil
        || !store.suggestedReceivingInspections(for: item).isEmpty
        || !store.suggestedInventoryReceipts(for: item).isEmpty
        || !store.suggestedShipmentManifestRecords(for: item).isEmpty
        || !store.suggestedDispatchReadinessChecklists(for: item).isEmpty
    }
  }
}

private struct WishlistPriceWatchDecisionEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var bestSnapshot: WishlistPriceSnapshot?
  var snapshotCount: Int
  var blockers: [String]
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseConfirmationCandidate: Identifiable {
  var id: UUID { email.id }
  var item: WishlistItem
  var email: ForwardedEmailIntake
  var confidence: String
  var score: Int
  var reasons: [String]
}

private struct WishlistLinkedOrderSummary: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var order: TrackedOrder
  var manifestCount: Int
  var checklistCount: Int
  var gaps: [String]
}

private struct WishlistComparisonReadinessEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var status: String
  var detail: String
  var tone: Color
  var actionTitle: String
}

private struct WishlistPurchaseStateCard: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 22, height: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(color.opacity(0.16), lineWidth: 1)
    )
  }
}

private struct WishlistLinkedOrderSummaryRow: View {
  var summary: WishlistLinkedOrderSummary
  var store: ParcelOpsStore
  var onStageManifest: () -> Void
  var onStageChecklist: () -> Void
  var onFocus: () -> Void

  private var tone: Color {
    summary.gaps.isEmpty ? .green : .purple
  }

  private var statusText: String {
    if summary.gaps.isEmpty {
      return "Dispatch setup staged locally"
    }
    return "Needs \(summary.gaps.joined(separator: " and "))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: summary.gaps.isEmpty ? "checkmark.seal.fill" : "link.badge.plus")
          .foregroundStyle(tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(summary.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text("\(summary.order.orderNumber) • \(summary.order.store)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(summary.order.latestStatus)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(summary.order.status.color)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(summary.gaps.isEmpty ? "Ready trail" : "\(summary.gaps.count) gaps", color: tone)
          Badge(summary.order.status.rawValue, color: summary.order.status.color)
        }
      }

      Text(statusText)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 120) {
        WishlistMatrixMetric(title: "Manifest", value: summary.manifestCount == 0 ? "Missing" : "\(summary.manifestCount) staged", symbol: "paperplane.fill")
        WishlistMatrixMetric(title: "Readiness", value: summary.checklistCount == 0 ? "Missing" : "\(summary.checklistCount) staged", symbol: "checkmark.rectangle.stack.fill")
        WishlistMatrixMetric(title: "Order", value: summary.order.orderNumber, symbol: "shippingbox.fill")
      }

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: summary.order, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.up.right.square.fill")
        }
        if summary.manifestCount > 0 || summary.checklistCount > 0 {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
        }
        if summary.manifestCount == 0 {
          Button("Stage manifest", systemImage: "paperplane.fill", action: onStageManifest)
        }
        if summary.checklistCount == 0 {
          Button("Stage checklist", systemImage: "checkmark.rectangle.stack.fill", action: onStageChecklist)
        }
        Button("Focus item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.mini)
    }
    .padding(10)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(tone.opacity(0.16), lineWidth: 1)
    )
  }
}

private struct WishlistPurchaseConfirmationCandidateRow: View {
  var candidate: WishlistPurchaseConfirmationCandidate
  var onUse: () -> Void
  var onFocus: () -> Void

  private var orderSummary: String {
    let order = candidate.email.detectedOrderNumber.isPlaceholderValidationValue ? "order needs review" : candidate.email.detectedOrderNumber
    let tracking = candidate.email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking needs review" : candidate.email.detectedTrackingNumber
    return "\(order) • \(tracking)"
  }

  private var tone: Color {
    switch candidate.confidence {
    case "High": return .green
    case "Medium": return .teal
    default: return .orange
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "envelope.badge.fill")
          .foregroundStyle(tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(candidate.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(candidate.email.subject)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(orderSummary)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(candidate.confidence, color: tone)
          Badge("\(candidate.score)", color: tone)
        }
      }

      Text("Reasons: \(candidate.reasons.prefix(4).joined(separator: ", "))")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Use match", systemImage: "link.badge.plus", action: onUse)
        Button("Focus item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.mini)
    }
    .padding(10)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(tone.opacity(0.16), lineWidth: 1)
    )
  }
}

private struct WishlistLocalActivityRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void
  @State private var showDetails = false
  @State private var feedbackMessage: String?

  private var outcomeLines: [String] {
    guard let detail = event.afterDetail else { return [] }
    let wantedPrefixes = [
      "Status:",
      "Readiness result:",
      "Scoring basis:",
      "Linked order:",
      "Created order:",
      "Manual record only.",
      "Review only."
    ]
    return detail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { line in wantedPrefixes.contains { line.hasPrefix($0) } }
      .prefix(4)
      .map { $0 }
  }

  private var shortDetail: String {
    let detail = event.afterDetail ?? event.beforeDetail ?? ""
    let clean = detail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .prefix(3)
      .joined(separator: " ")
    return clean.isEmpty ? "No detail recorded." : clean
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(event.entityLabel)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(event.action.rawValue) • \(event.timestamp)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(event.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(event.entityType.rawValue, color: event.action.color)
      }

      if !outcomeLines.isEmpty {
        CompactMetadataGrid(minimumWidth: 135) {
          ForEach(outcomeLines, id: \.self) { line in
            Badge(line, color: event.action.color)
          }
        }
      }

      if showDetails {
        Text(shortDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
      }

      if let feedbackMessage {
        Label(feedbackMessage, systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
      }

      CompactActionRow {
        Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
          showDetails.toggle()
        }
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Wishlist follow-up task created locally. Check Tasks."
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(event.action.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistExceptionQueueRow: View {
  var entry: WishlistExceptionQueueEntry
  var store: ParcelOpsStore
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var sellerSummary: String {
    let options = entry.item.comparisonOptions ?? []
    if let preferredID = entry.item.preferredOptionID,
       let preferred = options.first(where: { $0.id == preferredID }) {
      return "\(preferred.sellerName) • \(preferred.estimatedAUDTotal)"
    }
    if let first = options.first {
      return "\(first.sellerName) • \(first.estimatedAUDTotal)"
    }
    return entry.item.storefront
  }

  private var orderSummary: String {
    if let linkedOrder = entry.linkedOrder {
      return "\(linkedOrder.orderNumber) • \(linkedOrder.latestStatus)"
    }
    if entry.item.purchaseHandoff?.linkedOrderID != nil {
      return "Linked order ID recorded"
    }
    return "No linked order"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.issue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Seller", value: sellerSummary, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Status", value: entry.item.status, symbol: "tag.fill")
        WishlistMatrixMetric(title: "Owner", value: entry.item.owner, symbol: "person.crop.circle")
        WishlistMatrixMetric(title: "Order", value: orderSummary, symbol: "link")
      }

      Text("Local follow-up only. Use this row to route review work; it does not buy items, contact sellers, mutate email, poll carriers, or update external systems.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseTimelineRow: View {
  var entry: WishlistPurchaseTimelineEntry
  var onFocus: () -> Void

  private var progressText: String {
    "\(entry.readyCount)/\(max(entry.totalCount, 1)) ready"
  }

  private var progressValue: Double {
    guard entry.totalCount > 0 else { return 0 }
    return Double(entry.readyCount) / Double(entry.totalCount)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        ZStack {
          Circle()
            .fill(entry.tone.opacity(0.14))
          Image(systemName: entry.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(entry.tone)
        }
        .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 4) {
          Text(entry.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.attentionCount == 0 ? "Clear" : "\(entry.attentionCount) attention", color: entry.attentionCount == 0 ? .green : entry.tone)
          Text(progressText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }

      ProgressView(value: progressValue)
        .tint(entry.tone)

      CompactMetadataGrid(minimumWidth: 110) {
        WishlistMatrixMetric(title: "Ready", value: "\(entry.readyCount)", symbol: "checkmark.circle.fill")
        WishlistMatrixMetric(title: "Attention", value: "\(entry.attentionCount)", symbol: "exclamationmark.triangle.fill")
        WishlistMatrixMetric(title: "Total", value: "\(entry.totalCount)", symbol: "sum")
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistDataQualityIssue: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var symbol: String
  var color: Color
  var priority: Int
}

private struct WishlistDataQualityEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var issues: [WishlistDataQualityIssue]
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistNextActionEntry: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var count: Int
  var actionTitle: String
  var actionSymbol: String
  var symbol: String
  var color: Color
  var sortPriority: Int
}

private struct WishlistOperatorQueueEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var workflow: WishlistWorkflowFocus
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var sellerSummary: String
  var statusSummary: String
  var handoffSummary: String?
  var orderWatchSummary: String?
  var tone: Color
  var sortPriority: Int
}

private struct WishlistExceptionQueueEntry: Identifiable {
  var id: String { "\(item.id.uuidString)-\(issue)" }
  var item: WishlistItem
  var issue: String
  var detail: String
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
  var linkedOrder: TrackedOrder?
  var dataQualityEntry: WishlistDataQualityEntry?
}

private struct WishlistPurchaseTimelineEntry: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var workflowFocus: WishlistWorkflowFocus
  var readyCount: Int
  var attentionCount: Int
  var totalCount: Int
  var symbol: String
  var tone: Color
  var nextAction: String
  var sortPriority: Int
}

private struct WishlistPurchaseReadinessEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var passedChecks: Int
  var totalChecks: Int
  var blockers: [String]
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistCaptureSourceReadiness: Identifiable {
  var id: WishlistSource { source }
  var source: WishlistSource
  var status: String
  var detail: String
  var operatorAction: String
  var activeItems: Int
  var stagedCandidates: Int
  var gaps: Int
  var tone: Color
}

private struct WishlistAgentReadinessVerdictRow: View {
  var item: WishlistAgentReadinessItem

  private var color: Color {
    switch item.tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: item.tone == "success" ? "checkmark.circle.fill" : item.tone == "warning" ? "exclamationmark.triangle.fill" : "circle.dashed.inset.filled")
          .foregroundStyle(color)
        Text(item.title)
          .font(.caption.weight(.semibold))
        Spacer(minLength: 8)
        Badge(item.status, color: color)
      }
      Text(item.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Next: \(item.nextAction)")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistExtensionPayloadField: Identifiable {
  var id: String { name }
  var name: String
  var requirement: String
  var detail: String
  var tone: Color
}

private struct WishlistOperatorQueueRow: View {
  var entry: WishlistOperatorQueueEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.workflow == .operations ? "shippingbox.fill" : entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24, height: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge(entry.workflow.title, color: entry.workflow.color)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        Label(entry.sellerSummary, systemImage: "storefront.fill")
        Label(entry.statusSummary, systemImage: "checkmark.seal.fill")
        Label(entry.item.owner, systemImage: "person.crop.circle")
        Label(entry.item.source.rawValue, systemImage: "square.and.arrow.down.fill")
        if let handoffSummary = entry.handoffSummary {
          Label(handoffSummary, systemImage: "person.crop.circle.badge.checkmark")
        }
        if let orderWatchSummary = entry.orderWatchSummary {
          Label(orderWatchSummary, systemImage: "envelope.badge.fill")
        }
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if !entry.item.operatorPurchaseBlockers.isEmpty {
        Text("Blockers: \(entry.item.operatorPurchaseBlockers.prefix(3).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseReadinessRow: View {
  var entry: WishlistPurchaseReadinessEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var progressText: String {
    entry.totalChecks == 0 ? "Checks not run" : "\(entry.passedChecks)/\(entry.totalChecks) checks"
  }

  private var progressValue: Double {
    guard entry.totalChecks > 0 else { return 0 }
    return Double(entry.passedChecks) / Double(entry.totalChecks)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24, height: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Text(progressText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }

      ProgressView(value: progressValue)
        .tint(entry.tone)

      CompactMetadataGrid(minimumWidth: 125) {
        WishlistMatrixMetric(title: "Seller", value: entry.item.storefront, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Owner", value: entry.item.owner, symbol: "person.crop.circle")
        WishlistMatrixMetric(title: "Readiness", value: entry.item.purchaseReadiness ?? entry.item.status, symbol: "cart.badge.questionmark")
        WishlistMatrixMetric(title: "Blockers", value: "\(entry.blockers.count)", symbol: "exclamationmark.triangle.fill")
      }

      if !entry.blockers.isEmpty {
        Text("Needs: \(entry.blockers.prefix(4).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistDataQualityRow: View {
  var entry: WishlistDataQualityEntry
  var onFocus: () -> Void
  var onAction: () -> Void
  var onTask: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.issues.first?.symbol ?? "checklist")
          .foregroundStyle(entry.tone)
          .frame(width: 24, height: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.stage) • \(entry.item.storefront)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.issues.first?.detail ?? entry.item.operatorPurchaseNextAction)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge("\(entry.issues.count) gap\(entry.issues.count == 1 ? "" : "s")", color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 150) {
        ForEach(entry.issues.prefix(4)) { issue in
          Label(issue.title, systemImage: issue.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(issue.color)
            .lineLimit(1)
        }
      }

      CompactActionRow {
        Button("Focus", systemImage: "scope", action: onFocus)
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistView: View {
  var store: ParcelOpsStore
  @State private var showDeletedItems = false
  @State private var showClosedItems = false
  @State private var wishlistSearchText = ""
  @State private var selectedSource: WishlistSource?
  @State private var selectedStatus: String?
  @State private var selectedWorkflowFocus: WishlistWorkflowFocus = .all
  @State private var editingCaptureCandidate: WishlistCaptureCandidate?
  @State private var showManualWishlistItemForm = false
  @State private var showPastedLinkCaptureForm = false
  @State private var showPastedComparisonResultForm = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var statuses: [String] {
    Array(Set(store.wishlistItems.map(\.status))).sorted()
  }

  private let wishlistSources: [WishlistSource] = [.pdf, .screenshot, .shareSheet, .browserExtension, .manual]

  private var activeWishlistItems: [WishlistItem] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .sorted { first, second in
        first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
      }
  }

  private var closedWishlistItems: [WishlistItem] {
    store.wishlistItems
      .filter { $0.status == "Closed locally" }
      .sorted { first, second in
        first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
      }
  }

  private var baseFilteredItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      let isClosed = item.status == "Closed locally"
      let canShowClosed = showClosedItems || selectedStatus == "Closed locally"
      let matchesSource = selectedSource == nil || item.source == selectedSource
      let matchesStatus = selectedStatus == nil || item.status == selectedStatus
      let matchesWorkflow = selectedWorkflowFocus.matches(item: item, in: store)
      return (!isClosed || canShowClosed) && matchesSource && matchesStatus && matchesWorkflow
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
      || selectedWorkflowFocus != .all
      || showClosedItems
      || !wishlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var wishlistPurchaseStatePanel: some View {
    let active = store.activeWishlistItems
    let readyToBuy = active.filter { item in
      guard let handoff = item.purchaseHandoff else { return false }
      let purchased = handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased")
        || item.status.localizedCaseInsensitiveContains("awaiting order")
      return handoff.linkedOrderID == nil && !purchased
    }
    let waitingForConfirmation = active.filter { item in
      guard let handoff = item.purchaseHandoff else { return false }
      return handoff.linkedOrderID == nil
        && (handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased")
          || item.status.localizedCaseInsensitiveContains("awaiting order")
          || item.purchaseReadiness?.localizedCaseInsensitiveContains("watch") == true)
    }
    let linkedOrders = active.filter { $0.purchaseHandoff?.linkedOrderID != nil }
    let linkedOrderSummaries = linkedOrders.compactMap { item -> WishlistLinkedOrderSummary? in
      guard let orderID = item.purchaseHandoff?.linkedOrderID,
            let order = store.orders.first(where: { $0.id == orderID }) else { return nil }
      let manifests = store.suggestedShipmentManifestRecords(for: item)
      let checklists = store.suggestedDispatchReadinessChecklists(for: item)
      var gaps: [String] = []
      if manifests.isEmpty { gaps.append("manifest") }
      if checklists.isEmpty { gaps.append("readiness") }
      return WishlistLinkedOrderSummary(
        item: item,
        order: order,
        manifestCount: manifests.count,
        checklistCount: checklists.count,
        gaps: gaps
      )
    }
    let inboxCandidates = active.reduce(0) { total, item in
      total + store.suggestedWishlistOrderConfirmations(for: item).count
    }
    let confirmationCandidates = active.flatMap { item in
      store.suggestedWishlistOrderConfirmations(for: item).prefix(2).map { email in
        let detail = store.wishlistOrderConfirmationMatchDetail(item: item, email: email)
        return WishlistPurchaseConfirmationCandidate(
          item: item,
          email: email,
          confidence: detail.confidence,
          score: detail.score,
          reasons: detail.reasons
        )
      }
    }
      .sorted { first, second in
        if first.score == second.score {
          return first.email.receivedDate > second.email.receivedDate
        }
        return first.score > second.score
      }
    let blockers = active.filter { !$0.operatorPurchaseBlockers.isEmpty }
    let primaryWaiting = waitingForConfirmation.first
    let primaryReady = readyToBuy.first
    let primaryBlocked = blockers.first

    return SettingsPanel(title: "Wishlist purchase state", symbol: "cart.badge.questionmark") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Daily purchase view: decide what is ready to buy, what has already been bought outside ParcelOps, and what still needs an Inbox/order confirmation link.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Ready to buy", "\(readyToBuy.count)", readyToBuy.isEmpty ? .secondary : .blue),
          ("Need order link", "\(waitingForConfirmation.count)", waitingForConfirmation.isEmpty ? .secondary : .green),
          ("Inbox matches", "\(inboxCandidates)", inboxCandidates == 0 ? .secondary : .teal),
          ("Linked orders", "\(linkedOrders.count)", linkedOrders.isEmpty ? .secondary : .purple),
          ("Blocked", "\(blockers.count)", blockers.isEmpty ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistPurchaseStateCard(
            title: "Next order to link",
            detail: primaryWaiting.map { "\($0.itemName): \($0.purchaseHandoff?.orderWatchStatus ?? $0.purchaseReadiness ?? "Refresh Inbox, then link the confirmation to an order")" } ?? "No externally purchased Wishlist item is currently waiting for an order confirmation link.",
            symbol: "envelope.badge.fill",
            color: waitingForConfirmation.isEmpty ? .secondary : .green
          )
          WishlistPurchaseStateCard(
            title: "Next item ready to buy",
            detail: primaryReady.map { "\($0.itemName): \($0.purchaseHandoff?.sellerName ?? $0.storefront), \($0.purchaseHandoff?.accountLabel ?? $0.owner)" } ?? "No item is marked ready for manual external purchase.",
            symbol: "bag.fill",
            color: readyToBuy.isEmpty ? .secondary : .blue
          )
          WishlistPurchaseStateCard(
            title: "Top blocker",
            detail: primaryBlocked.map { "\($0.itemName): \($0.operatorPurchaseBlockers.prefix(3).joined(separator: ", "))" } ?? "No active Wishlist item has purchase blockers.",
            symbol: "exclamationmark.triangle.fill",
            color: blockers.isEmpty ? .green : .orange
          )
        }

        if !confirmationCandidates.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Inbox confirmations ready to review", systemImage: "tray.full.fill")
              .font(.caption.bold())
              .foregroundStyle(.teal)
            Text("These are the strongest local Inbox matches for Wishlist purchases. Use only when the email clearly confirms the external purchase.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
              ForEach(Array(confirmationCandidates.prefix(3))) { candidate in
                WishlistPurchaseConfirmationCandidateRow(candidate: candidate) {
                  store.confirmWishlistOrderFromIntake(candidate.item, email: candidate.email)
                } onFocus: {
                  wishlistSearchText = candidate.item.itemName
                  selectedSource = nil
                  selectedStatus = nil
                  selectedWorkflowFocus = .watch
                }
              }
            }
          }
          .padding(10)
          .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !linkedOrderSummaries.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Wishlist items now linked to Orders", systemImage: "link.badge.plus")
              .font(.caption.bold())
              .foregroundStyle(.purple)
            Text("Use these links after a confirmation match has created or attached the order. Continue fulfilment and dispatch work from the order record.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
              ForEach(Array(linkedOrderSummaries.prefix(3))) { summary in
                WishlistLinkedOrderSummaryRow(summary: summary, store: store) {
                  store.createWishlistShipmentManifest(summary.item)
                } onStageChecklist: {
                  store.createWishlistDispatchReadinessChecklist(summary.item)
                } onFocus: {
                  wishlistSearchText = summary.item.itemName
                  selectedSource = nil
                  selectedStatus = nil
                  selectedWorkflowFocus = .operations
                }
              }
            }
          }
          .padding(10)
          .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        CompactActionRow {
          Button("Show buy queue", systemImage: "cart.fill") {
            selectedWorkflowFocus = .buy
            selectedSource = nil
            selectedStatus = nil
          }
          Button("Show order-link queue", systemImage: "envelope.badge.fill") {
            selectedWorkflowFocus = .watch
            selectedSource = nil
            selectedStatus = nil
          }
          Button("Check order links", systemImage: "magnifyingglass") {
            store.checkOpenWishlistOrderWatchRecords()
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Text("This panel uses local Wishlist, Inbox, and order records only. It does not buy items, log in to retailers, fetch mail, poll in the background, store payment details, or mutate mailbox messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
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

  private var wishlistPurchaseBlockerQueueItems: [WishlistItem] {
    store.wishlistItems
      .filter { store.isActiveWishlistItem($0) && !$0.operatorPurchaseBlockers.isEmpty }
      .sorted { first, second in
        if first.operatorPurchaseBlockers.count == second.operatorPurchaseBlockers.count {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return first.operatorPurchaseBlockers.count > second.operatorPurchaseBlockers.count
      }
  }

  private var wishlistPipelineItems: [WishlistPipelineItem] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .map(wishlistPipelineItem(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistDataQualityEntries: [WishlistDataQualityEntry] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .compactMap { item in
        let issues = wishlistDataQualityIssues(for: item)
        guard !issues.isEmpty else { return nil }
        let firstIssue = issues.sorted { $0.priority < $1.priority }.first
        return WishlistDataQualityEntry(
          item: item,
          issues: issues.sorted { first, second in
            if first.priority == second.priority {
              return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
            return first.priority < second.priority
          },
          stage: wishlistDataQualityStage(for: item),
          nextAction: wishlistDataQualityActionTitle(for: item, firstIssue: firstIssue),
          nextSymbol: wishlistDataQualityActionSymbol(for: item, firstIssue: firstIssue),
          tone: firstIssue?.color ?? .blue,
          sortPriority: firstIssue?.priority ?? 100
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistExceptionQueueEntries: [WishlistExceptionQueueEntry] {
    let dataQualityByItemID = Dictionary(uniqueKeysWithValues: wishlistDataQualityEntries.map { ($0.item.id, $0) })
    let linkedFollowUpsByItemID = Dictionary(uniqueKeysWithValues: wishlistLinkedOrderFollowUpDashboardEntries.map { ($0.checklist.item.id, $0) })
    let closureByItemID = Dictionary(uniqueKeysWithValues: wishlistOperationsClosureReadinessEntries.map { ($0.item.id, $0) })

    var entries: [WishlistExceptionQueueEntry] = []

    for item in store.activeWishlistItems {
      let options = item.comparisonOptions ?? []
      let riskySeller = options.first { option in
        let trust = option.trustRating.lowercased()
        let risk = (option.riskLevel ?? "").lowercased()
        return trust.contains("unknown")
          || trust.contains("review")
          || trust.contains("low")
          || risk.contains("high")
      }
      let linkedOrder = item.purchaseHandoff?.linkedOrderID.flatMap { id in
        store.orders.first { $0.id == id }
      }

      if let dataQuality = dataQualityByItemID[item.id], let firstIssue = dataQuality.issues.first {
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: firstIssue.title,
          detail: firstIssue.detail,
          stage: dataQuality.stage,
          nextAction: dataQuality.nextAction,
          nextSymbol: dataQuality.nextSymbol,
          tone: firstIssue.color,
          sortPriority: firstIssue.priority,
          linkedOrder: linkedOrder,
          dataQualityEntry: dataQuality
        ))
      }

      if let riskySeller {
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: "Seller trust risk",
          detail: "\(riskySeller.sellerName) needs local trust, delivery, returns, or source review before purchase.",
          stage: "Compare",
          nextAction: "Trust task",
          nextSymbol: "shield.lefthalf.filled.badge.checkmark",
          tone: .red,
          sortPriority: 18,
          linkedOrder: linkedOrder,
          dataQualityEntry: nil
        ))
      }

      if item.purchaseDecision?.reviewState == .accepted && item.purchaseHandoff == nil {
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: "Purchase handoff missing",
          detail: "Purchase decision is accepted locally, but seller/account/order-watch handoff has not been prepared.",
          stage: "Buy",
          nextAction: "Handoff",
          nextSymbol: "person.crop.circle.badge.checkmark",
          tone: .purple,
          sortPriority: 28,
          linkedOrder: linkedOrder,
          dataQualityEntry: nil
        ))
      }

      if item.purchaseHandoff != nil && linkedOrder == nil {
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: "Order link missing",
          detail: "A purchase handoff exists, but no local order is linked yet. Match Inbox confirmation or create/link an order.",
          stage: "Watch",
          nextAction: "Order seen",
          nextSymbol: "envelope.badge.fill",
          tone: .teal,
          sortPriority: 36,
          linkedOrder: nil,
          dataQualityEntry: nil
        ))
      }

      if let followUp = linkedFollowUpsByItemID[item.id], followUp.stage != "Ready for closure" {
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: followUp.stage,
          detail: followUp.detail,
          stage: "Operations",
          nextAction: followUp.nextAction,
          nextSymbol: followUp.nextSymbol,
          tone: followUp.tone,
          sortPriority: 46,
          linkedOrder: followUp.linkedOrder,
          dataQualityEntry: nil
        ))
      }

      if let closure = closureByItemID[item.id], !closure.gaps.isEmpty || closure.openTaskCount > 0 {
        let taskDetail = closure.openTaskCount > 0 ? " \(closure.openTaskCount) follow-up task\(closure.openTaskCount == 1 ? "" : "s") still open." : ""
        entries.append(WishlistExceptionQueueEntry(
          item: item,
          issue: "Closure blocked",
          detail: "Closure gaps: \(closure.gaps.prefix(5).joined(separator: ", ")).\(taskDetail)",
          stage: "Closure",
          nextAction: closure.nextAction,
          nextSymbol: closure.nextSymbol,
          tone: closure.tone,
          sortPriority: 56,
          linkedOrder: closure.linkedOrder,
          dataQualityEntry: nil
        ))
      }
    }

    return entries.sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private func runWishlistExceptionQueueAction(for entry: WishlistExceptionQueueEntry) {
    if let dataQualityEntry = entry.dataQualityEntry {
      runWishlistDataQualityAction(for: dataQualityEntry)
      return
    }

    switch entry.issue {
    case "Seller trust risk":
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    case "Purchase handoff missing":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Order link missing":
      store.markWishlistOrderConfirmationSeen(entry.item)
    case "Tracking needs review", "Tasks open":
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    case "Receiving follow-up":
      store.createWishlistReceivingInspection(entry.item)
    case "Dispatch follow-up":
      if store.suggestedShipmentManifestRecords(for: entry.item).isEmpty {
        store.createWishlistShipmentManifest(entry.item)
      } else {
        store.createWishlistDispatchReadinessChecklist(entry.item)
      }
    case "Closure blocked":
      store.checkWishlistOperationsClosureReadinessBatch()
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private func createWishlistExceptionQueueTask(for entry: WishlistExceptionQueueEntry) {
    if ["Seller trust risk"].contains(entry.issue) {
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    } else if ["Purchase handoff missing", "Order link missing", "Tracking needs review", "Tasks open"].contains(entry.issue) {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else if entry.stage == "Operations" || entry.stage == "Closure" {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else if entry.dataQualityEntry?.issues.contains(where: { $0.title.localizedCaseInsensitiveContains("decision") }) == true {
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    } else {
      store.createReviewTask(from: entry.item)
    }
  }

  private var wishlistNextActionEntries: [WishlistNextActionEntry] {
    let activeItems = store.activeWishlistItems
    let activeResearchRequests = store.activeWishlistResearchRequests
    let stagedCaptureGaps = store.wishlistCaptureCandidates.filter { !$0.operatorCaptureGaps.isEmpty }
    let unbriefedItems = activeItems.filter { item in
      !activeResearchRequests.contains { $0.wishlistItemID == item.id }
        && (item.comparisonOptions ?? []).isEmpty
    }
    let researchScopeGaps = activeResearchRequests.filter {
      !$0.isAgentBriefReady && !$0.requestStatus.localizedCaseInsensitiveContains("blocked")
    }
    let sellerEvidenceGaps = activeItems.filter { item in
      (item.comparisonOptions ?? []).contains { !$0.operatorSellerEvidenceGaps.isEmpty }
    }
    let purchaseBlockers = activeItems.filter { !$0.operatorPurchaseBlockers.isEmpty }
    let orderWatchItems = activeItems.filter {
      $0.purchaseHandoff != nil && $0.purchaseHandoff?.linkedOrderID == nil
    }
    let linkedOperationalItems = activeItems.filter {
      $0.purchaseHandoff?.linkedOrderID != nil
        || !store.suggestedReceivingInspections(for: $0).isEmpty
        || !store.suggestedInventoryReceipts(for: $0).isEmpty
        || !store.suggestedDispatchReadinessChecklists(for: $0).isEmpty
    }

    let entries = [
      WishlistNextActionEntry(
        title: "Clean capture inputs",
        detail: stagedCaptureGaps.isEmpty ? "No staged capture candidates have blocking capture gaps." : "Review staged captures before they become Wishlist items. Confirm item name, seller, URL, price clues, and source detail.",
        count: stagedCaptureGaps.count,
        actionTitle: "Review capture",
        actionSymbol: "square.and.arrow.down.fill",
        symbol: "square.and.arrow.down.fill",
        color: stagedCaptureGaps.isEmpty ? .green : .orange,
        sortPriority: stagedCaptureGaps.isEmpty ? 80 : 10
      ),
      WishlistNextActionEntry(
        title: "Create comparison briefs",
        detail: unbriefedItems.isEmpty ? "Every active item has a research brief or seller option context." : "Create local briefs before any human or future agent compares Australian and overseas retailers.",
        count: unbriefedItems.count,
        actionTitle: "Create briefs",
        actionSymbol: "list.bullet.clipboard",
        symbol: "doc.text.magnifyingglass",
        color: unbriefedItems.isEmpty ? .green : .blue,
        sortPriority: unbriefedItems.isEmpty ? 85 : 20
      ),
      WishlistNextActionEntry(
        title: "Fix research scope",
        detail: researchScopeGaps.isEmpty ? "No open research brief is missing core handoff scope." : "Fill AUD budget, region, seller, postage, trust, source, or operator-review gaps before handoff.",
        count: researchScopeGaps.count,
        actionTitle: "Focus compare",
        actionSymbol: "scope",
        symbol: "checklist.checked",
        color: researchScopeGaps.isEmpty ? .green : .orange,
        sortPriority: researchScopeGaps.isEmpty ? 90 : 30
      ),
      WishlistNextActionEntry(
        title: "Review seller evidence",
        detail: sellerEvidenceGaps.isEmpty ? "No captured seller option currently has required evidence gaps." : "Check product links, AUD landed totals, postage timing, returns/warranty, trust notes, and recommendation quality.",
        count: sellerEvidenceGaps.count,
        actionTitle: "Review sellers",
        actionSymbol: "storefront.fill",
        symbol: "shield.checkered",
        color: sellerEvidenceGaps.isEmpty ? .green : .purple,
        sortPriority: sellerEvidenceGaps.isEmpty ? 95 : 40
      ),
      WishlistNextActionEntry(
        title: "Clear purchase blockers",
        detail: purchaseBlockers.isEmpty ? "No active item has local purchase blockers." : "Resolve missing seller choice, price, postage, trust, approval, account, or order-watch checks before buying externally.",
        count: purchaseBlockers.count,
        actionTitle: "Focus buy",
        actionSymbol: "cart.badge.plus",
        symbol: "exclamationmark.triangle.fill",
        color: purchaseBlockers.isEmpty ? .green : .orange,
        sortPriority: purchaseBlockers.isEmpty ? 100 : 50
      ),
      WishlistNextActionEntry(
        title: "Match order confirmations",
        detail: orderWatchItems.isEmpty ? "No Wishlist purchase handoff is waiting for an order confirmation match." : "Match purchase handoffs to Inbox confirmations or Orders once the external purchase is complete.",
        count: orderWatchItems.count,
        actionTitle: "Focus watch",
        actionSymbol: "envelope.badge.fill",
        symbol: "link.badge.plus",
        color: orderWatchItems.isEmpty ? .green : .teal,
        sortPriority: orderWatchItems.isEmpty ? 105 : 60
      ),
      WishlistNextActionEntry(
        title: "Operational handoff",
        detail: linkedOperationalItems.isEmpty ? "No Wishlist item has moved into receiving, storage, dispatch, or linked order operations yet." : "Check linked-order, receiving, inventory, storage, custody, and dispatch context for purchased items.",
        count: linkedOperationalItems.count,
        actionTitle: "Focus operations",
        actionSymbol: "shippingbox.fill",
        symbol: "shippingbox.fill",
        color: linkedOperationalItems.isEmpty ? .secondary : .green,
        sortPriority: linkedOperationalItems.isEmpty ? 110 : 70
      )
    ]

    return entries.sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistCaptureRunwayPanel: some View {
    let candidates = store.wishlistCaptureCandidates
    let readyCandidates = candidates.filter { $0.operatorCaptureGaps.isEmpty }
    let gapCandidates = candidates.filter { !$0.operatorCaptureGaps.isEmpty }
    let manualItems = store.wishlistItems.filter { store.isActiveWishlistItem($0) && $0.source == .manual }
    let itemSellerOptionCount = store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && item.comparisonOptions?.isEmpty == false
    }.count
    let firstGap = gapCandidates.first

    return SettingsPanel(title: "Capture runway", symbol: "square.and.arrow.down.badge.clock") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: gapCandidates.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(gapCandidates.isEmpty ? .green : .orange)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(gapCandidates.isEmpty ? "Capture inputs are ready for review" : "Clean staged captures before comparison")
              .font(.headline)
            Text(firstGap.map { "Next: edit \($0.pageTitle.isPlaceholderValidationValue ? "the staged capture" : $0.pageTitle) and add \($0.operatorCaptureGaps.prefix(3).joined(separator: ", "))." } ?? "Use manual entry or staged capture placeholders to collect item name, seller/source, product URL, price clue, owner, and why the item is needed.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(gapCandidates.isEmpty ? "Ready" : "\(gapCandidates.count) gaps", color: gapCandidates.isEmpty ? .green : .orange)
        }

        MetricStrip(items: [
          ("Manual items", "\(manualItems.count)", manualItems.isEmpty ? .secondary : .green),
          ("Staged", "\(candidates.count)", candidates.isEmpty ? .secondary : .blue),
          ("Ready staged", "\(readyCandidates.count)", readyCandidates.isEmpty ? .secondary : .green),
          ("Gaps", "\(gapCandidates.count)", gapCandidates.isEmpty ? .green : .orange),
          ("Seller options", "\(itemSellerOptionCount)", itemSellerOptionCount == 0 ? .secondary : .teal)
        ])

        CompactMetadataGrid(minimumWidth: horizontalSizeClass == .compact ? 150 : 190) {
          Badge("1 Capture item", color: .blue)
          Badge("2 Confirm seller/link", color: .teal)
          Badge("3 Add price/postage clue", color: .orange)
          Badge("4 Compare sellers later", color: .purple)
          Badge("5 Decide manually", color: .pink)
          Badge("6 Watch for order email", color: .green)
        }

        CompactActionRow {
          Button("Manual item", systemImage: "plus", action: openManualWishlistItemForm)
          Button("Paste product link", systemImage: "link.badge.plus") {
            showPastedLinkCaptureForm = true
          }
          Button("Stage browser capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          if firstGap != nil {
            Button("Focus capture gaps", systemImage: "line.3.horizontal.decrease.circle") {
              selectedWorkflowFocus = .capture
            }
          }
        }
        .buttonStyle(.bordered)

        Text("Capture boundary: this is local staging only. It does not install a browser extension, open retailer pages, compare prices, convert currency, estimate postage, rate sellers, log in, buy, pay, or monitor orders.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistComparisonRunwayPanel: some View {
    let activeItems = store.activeWishlistItems
    let requests = store.activeWishlistResearchRequests
    let entries = activeItems.map { item -> WishlistComparisonReadinessEntry in
      let options = item.comparisonOptions ?? []
      let request = requests.first { $0.wishlistItemID == item.id }

      if !options.isEmpty {
        let evidenceGaps = options.flatMap(\.operatorSellerEvidenceGaps)
        if evidenceGaps.isEmpty {
          return WishlistComparisonReadinessEntry(
            item: item,
            status: "Seller options ready",
            detail: "Seller options have local product links, AUD totals, postage, trust, and returns/warranty fields ready for operator scoring.",
            tone: .green,
            actionTitle: "Review sellers"
          )
        }
        return WishlistComparisonReadinessEntry(
          item: item,
          status: "Seller evidence gaps",
          detail: "Fill: \(Array(Set(evidenceGaps)).prefix(4).joined(separator: ", ")).",
          tone: .orange,
          actionTitle: "Fix seller evidence"
        )
      }

      if let request {
        if request.isAgentBriefReady {
          return WishlistComparisonReadinessEntry(
            item: item,
            status: "Comparison brief ready",
            detail: "Ready for manual or future-agent seller research. Compare Australian and overseas retailers, AUD landed cost, postage, delivery time, and seller trust.",
            tone: .teal,
            actionTitle: "Use brief"
          )
        }
        return WishlistComparisonReadinessEntry(
          item: item,
          status: "Brief needs scope",
          detail: "Clarify: \(request.agentBriefGaps.prefix(4).joined(separator: ", ")).",
          tone: .orange,
          actionTitle: "Fix brief"
        )
      }

      return WishlistComparisonReadinessEntry(
        item: item,
        status: "Needs comparison brief",
        detail: "Create a local brief before comparing sellers. This keeps source URL, budget, region, postage needs, and trust requirements together.",
        tone: .blue,
        actionTitle: "Create brief"
      )
    }
    let readyBriefs = entries.filter { $0.status == "Comparison brief ready" }.count
    let readySellerOptions = entries.filter { $0.status == "Seller options ready" }.count
    let gaps = entries.filter { $0.tone == .orange }.count
    let missingBriefs = entries.filter { $0.status == "Needs comparison brief" }.count
    let leadingEntry = entries.first { $0.status == "Needs comparison brief" }
      ?? entries.first { $0.tone == .orange }
      ?? entries.first

    return SettingsPanel(title: "Comparison runway", symbol: "magnifyingglass.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: gaps == 0 && missingBriefs == 0 ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
            .font(.title3)
            .foregroundStyle(gaps == 0 && missingBriefs == 0 ? .green : .blue)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(gaps == 0 && missingBriefs == 0 ? "Comparison inputs are locally ready" : "Prepare items before seller comparison")
              .font(.headline)
            Text(leadingEntry.map { "\($0.item.itemName): \($0.detail)" } ?? "Add a Wishlist item, then create a comparison brief or seller option before purchase review.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(gaps == 0 && missingBriefs == 0 ? "Ready" : "\(gaps + missingBriefs) to work", color: gaps == 0 && missingBriefs == 0 ? .green : .orange)
        }

        MetricStrip(items: [
          ("Items", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .purple),
          ("Brief ready", "\(readyBriefs)", readyBriefs == 0 ? .secondary : .teal),
          ("Seller ready", "\(readySellerOptions)", readySellerOptions == 0 ? .secondary : .green),
          ("Need brief", "\(missingBriefs)", missingBriefs == 0 ? .green : .blue),
          ("Gaps", "\(gaps)", gaps == 0 ? .green : .orange)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist items yet",
            detail: "Add a manual item or staged capture before preparing seller comparison work.",
            symbol: "star.square.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(4)) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: entry.status == "Seller options ready" ? "storefront.fill" : "doc.text.magnifyingglass")
                    .foregroundStyle(entry.tone)
                    .frame(width: 20, height: 20)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(entry.item.itemName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(entry.status)
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(entry.tone)
                  }
                  Spacer(minLength: 8)
                  Badge(entry.status, color: entry.tone)
                }

                Text(entry.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                CompactActionRow {
                  Button(entry.actionTitle, systemImage: entry.status == "Needs comparison brief" ? "list.bullet.clipboard" : "scope") {
                    if entry.status == "Needs comparison brief" {
                      store.createWishlistResearchRequest(from: entry.item)
                    } else {
                      selectedWorkflowFocus = .compare
                      wishlistSearchText = entry.item.itemName
                    }
                  }
                  .buttonStyle(.bordered)
                  .controlSize(.mini)
                }
              }
              .padding(10)
              .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(entry.tone.opacity(0.16), lineWidth: 1)
              )
            }
          }
        }

        CompactActionRow {
          Button("Create missing briefs", systemImage: "list.bullet.clipboard", action: store.createMissingWishlistResearchRequests)
          Button("Focus comparison", systemImage: "scope") {
            selectedWorkflowFocus = .compare
          }
        }
        .buttonStyle(.bordered)

        Text("Comparison boundary: this prepares local briefs and seller-review rows only. ParcelOps does not browse retailers, run live web search, convert currencies, quote postage, score seller trust externally, log in, purchase, pay, or monitor retailer pages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
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

        CompactActionRow {
          Button("Paste product link", systemImage: "link.badge.plus") {
            showPastedLinkCaptureForm = true
          }
          Button("Paste comparison result", systemImage: "doc.text.magnifyingglass") {
            showPastedComparisonResultForm = true
          }
          Button("PDF placeholder", systemImage: "doc.badge.plus", action: store.uploadWishlistPDFPlaceholder)
          Button("Screenshot placeholder", systemImage: "photo.badge.plus", action: store.addWishlistScreenshotPlaceholder)
          Button("Browser capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          Button("Manual item", systemImage: "plus", action: openManualWishlistItemForm)
        }
        .buttonStyle(.bordered)

        wishlistNextActionGuidePanel
        wishlistCaptureRunwayPanel
        wishlistComparisonRunwayPanel
        wishlistPurchaseStatePanel
        wishlistPurchaseTriagePanel
        wishlistPurchaseTimelinePanel
        wishlistPurchaseReadinessChecklistPanel
        wishlistComparisonReadinessLadderPanel
        wishlistOperatorControlCentrePanel
        wishlistExceptionQueuePanel
        wishlistOperationsNextStepsPanel
        wishlistSellerDecisionSnapshotPanel
        wishlistComparisonBriefShortcutPanel
        wishlistWorkflowFocusPanel
        wishlistOperatorQueuePanel
        wishlistLocalActivityPanel
        wishlistDataQualityPanel
        wishlistReadinessPanel
        wishlistPipelineBoardPanel
        wishlistPurchaseBlockerQueuePanel
        wishlistCaptureContractPanel
        wishlistCaptureSourceReadinessPanel
        wishlistBrowserExtensionPayloadPanel
        wishlistCaptureCandidatesPanel
        wishlistCapturedOptionCleanupPanel
        wishlistComparisonPlanningPanel
        wishlistAgentReadinessVerdictPanel
        wishlistSellerOptionReviewPanel
        wishlistSellerSafetyRubricPanel
        wishlistSellerTrustDiligencePanel
        wishlistSellerTrustChecklistPanel
        wishlistSellerTrustEvidenceLedgerPanel
        wishlistComparisonMatrixPanel
        wishlistLandedCostReviewPanel
        wishlistPriceWatchSnapshotPanel
        wishlistPriceWatchDecisionBoardPanel
        wishlistPriceWatchRulesPanel
        wishlistPurchaseRecommendationPanel
        wishlistPurchaseDecisionRiskGatePanel
        wishlistPurchaseShortlistPanel
        wishlistPurchaseDecisionRunwayPanel
        wishlistPurchasePacketPanel
        wishlistPurchaseDecisionQueuePanel
        wishlistPurchaseReadinessBlockerSummaryPanel
        wishlistExternalPurchaseSafetyGatePanel
        wishlistPurchaseDecisionSummaryPanel
        wishlistManualPurchaseHandoffReadinessPanel
        wishlistPurchaseEvidenceDossierPanel
        wishlistPurchaseDecisionEvidencePackPanel
        wishlistPurchaseApprovalPanel
        wishlistPurchaseLinkPanel
        wishlistPrePurchaseOperatorChecklistPanel
        wishlistPurchaseReleaseChecklistPanel
        wishlistManualPurchaseDayPlanPanel
        wishlistPurchaseHandoffPackPanel
        wishlistPurchaseHandoffSanityPanel
        wishlistPurchaseAccountReadinessPanel
        wishlistPurchaseAccountLedgerPanel
        wishlistPurchaseWatchCommandCentrePanel
        wishlistOrderConfirmationHandoffPanel
        wishlistPostPurchaseMonitorPanel
        wishlistOrderWatchRecordsPanel
        wishlistOrderConfirmationMatchingPanel
        wishlistPostPurchaseOrderWatchPanel
        wishlistPurchaseOperationsHandoffPanel
        wishlistLinkedOrderOperationsChecklistPanel
        wishlistLinkedOrderFollowUpDashboardPanel
        wishlistOperationsClosureReadinessPanel
        wishlistOrderConfirmationMatchPacketPanel
        wishlistAgentResearchRunwayPanel
        wishlistAgentHandoffPacketPanel
        wishlistAgentOutputContractPanel
        wishlistAgentBriefQualityPanel
        wishlistAgentBatchBriefPanel
        wishlistResearchResultIntakePanel
        wishlistSellerQuoteIntakePanel
        wishlistResearchPasteBackChecklistPanel
        wishlistResearchPasteBackFieldMapPanel
        wishlistResearchResultQualityPanel
        wishlistSellerComparisonDecisionRunwayPanel
        wishlistResearchRequestsPanel
        gmailWishlistFocusPanel
        filterBar

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF placeholder", detail: "Creates a local test item only. No file picker, OCR, or PDF parser runs from this screen.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot placeholder", detail: "Creates a local test item only. No screenshot picker, OCR, or image parser runs from this screen.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "Share path placeholder", detail: "Documents a future share-sheet flow. ParcelOps does not receive shared browser pages yet.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Browser capture staging", detail: "Creates or reviews local capture candidates in the staging queue. No browser extension, scraping, or external sync is active here.")
        }

        SettingsPanel(title: "Wishlist items", symbol: "star.square.fill") {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("\(filteredItems.count) visible wishlist items")
                .font(.caption)
                .foregroundStyle(.secondary)
              if hasActiveFilters {
                Badge("\(baseFilteredItems.count) after filters", color: .blue)
              }
              if !closedWishlistItems.isEmpty && !showClosedItems && selectedStatus != "Closed locally" {
                Badge("\(closedWishlistItems.count) closed hidden", color: .green)
              }
              Spacer()
              Button("Manual item", systemImage: "plus", action: openManualWishlistItemForm)
                .buttonStyle(.borderedProminent)
            }

            if !closedWishlistItems.isEmpty {
              CompactActionRow {
                Button(showClosedItems ? "Hide closed" : "Show closed", systemImage: showClosedItems ? "eye.slash.fill" : "checkmark.circle.fill") {
                  withAnimation(.snappy) {
                    showClosedItems.toggle()
                  }
                }
                Button("Closed status", systemImage: "line.3.horizontal.decrease.circle") {
                  selectedStatus = "Closed locally"
                  showClosedItems = true
                }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }

          if filteredItems.isEmpty {
            MVPEmptyState(title: "No wishlist items match this view", detail: hasActiveFilters ? "Clear search or filters to return to all active wishlist items." : "Add a manual wishlist item or use a placeholder capture action to test wishlist-to-order handoff.", symbol: "star.square.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Manual item", action: hasActiveFilters ? clearFilters : openManualWishlistItemForm)
          } else {
            ForEach(filteredItems) { item in
              WishlistItemRow(
                item: item,
                linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
                  store.orders.first { $0.id == orderID }
                },
                store: store,
                confirmationMatches: store.suggestedWishlistOrderConfirmations(for: item),
                suggestedAccounts: store.suggestedAccounts(for: item),
                suggestedCosts: store.suggestedCostRecords(for: item),
                suggestedProcurementRequests: store.suggestedProcurementRequests(for: item),
                suggestedReceivingInspections: store.suggestedReceivingInspections(for: item),
                suggestedInventoryReceipts: store.suggestedInventoryReceipts(for: item),
                suggestedStorageLocations: store.suggestedStorageLocations(for: item),
                suggestedCustodyRecords: store.suggestedCustodyRecords(for: item),
                suggestedLabelReferences: store.suggestedLabelReferenceRecords(for: item),
                suggestedScanSessions: store.suggestedScanSessionRecords(for: item),
                suggestedShipmentManifests: store.suggestedShipmentManifestRecords(for: item),
                suggestedDispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item)
              ) {
                store.convertWishlistToOrder(item)
              } onLink: {
                store.linkWishlistItemToOrder(item)
              } onCompare: {
                store.createWishlistComparisonPlan(item)
                store.createWishlistResearchRequest(from: item)
              } onAddOption: {
                store.addManualWishlistSellerOptionPlaceholder(item)
              } onScore: {
                store.evaluateWishlistComparisonOptions(item)
              } onEvidenceTask: {
                store.createWishlistSellerEvidenceReviewTask(item)
              } onCheck: {
                store.runWishlistPurchaseReadinessCheck(item)
              } onDecision: {
                store.createWishlistPurchaseDecision(item)
              } onDecisionReviewed: {
                store.markWishlistPurchaseDecisionReviewed(item)
              } onDecisionNeedsReview: {
                store.markWishlistPurchaseDecisionNeedsReview(item)
              } onDecisionTask: {
                store.createWishlistPurchaseDecisionReviewTask(item)
              } onHandoff: {
                store.prepareWishlistPurchaseHandoff(item)
              } onHandoffTask: {
                store.createWishlistPurchaseHandoffReviewTask(item)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(item)
              } onOrderSeen: {
                store.markWishlistOrderConfirmationSeen(item)
              } onUseConfirmation: { email in
                store.confirmWishlistOrderFromIntake(item, email: email)
              } onAddAccount: {
                store.addAccountCredentialRecord(
                  linkedEntityType: .supplier,
                  linkedEntityID: item.id.uuidString,
                  organisation: item.purchaseHandoff?.sellerName ?? item.storefront,
                  label: item.itemName
                )
              } onAccountTask: { account in
                store.createReviewTask(from: account)
              } onAccountDraft: { account in
                store.createDraftMessage(from: account)
              } onAddCost: {
                store.createWishlistPurchaseCostRecord(item)
              } onCostTask: { cost in
                store.createReviewTask(from: cost)
              } onCostDraft: { cost in
                store.createDraftMessage(from: cost)
              } onAddProcurement: {
                store.createWishlistProcurementRequest(item)
              } onProcurementTask: { request in
                store.createReviewTask(from: request)
              } onProcurementDraft: { request in
                store.createDraftMessage(from: request)
              } onAddInspection: {
                store.createWishlistReceivingInspection(item)
              } onInspectionTask: { inspection in
                store.createReviewTask(from: inspection)
              } onInspectionDraft: { inspection in
                store.createDraftMessage(from: inspection)
              } onAddInventoryReceipt: {
                store.createWishlistInventoryReceipt(item)
              } onInventoryReceiptTask: { receipt in
                store.createReviewTask(from: receipt)
              } onInventoryReceiptDraft: { receipt in
                store.createDraftMessage(from: receipt)
              } onAddStorageLocation: {
                store.createWishlistStorageLocation(item)
              } onStorageLocationTask: { location in
                store.createReviewTask(from: location)
              } onStorageLocationDraft: { location in
                store.createDraftMessage(from: location)
              } onAddCustody: {
                store.createWishlistCustodyRecord(item)
              } onCustodyTask: { custody in
                store.createReviewTask(from: custody)
              } onCustodyDraft: { custody in
                store.createDraftMessage(from: custody)
              } onAddLabelReference: {
                store.createWishlistLabelReference(item)
              } onLabelReferenceTask: { label in
                store.createReviewTask(from: label)
              } onLabelReferenceDraft: { label in
                store.createDraftMessage(from: label)
              } onAddScanSession: {
                store.createWishlistScanSession(item)
              } onScanSessionTask: { scan in
                store.createReviewTask(from: scan)
              } onScanSessionDraft: { scan in
                store.createDraftMessage(from: scan)
              } onAddShipmentManifest: {
                store.createWishlistShipmentManifest(item)
              } onShipmentManifestTask: { manifest in
                store.createReviewTask(from: manifest)
              } onShipmentManifestDraft: { manifest in
                store.createDraftMessage(from: manifest)
              } onAddDispatchChecklist: {
                store.createWishlistDispatchReadinessChecklist(item)
              } onDispatchChecklistTask: { checklist in
                store.createReviewTask(from: checklist)
              } onDispatchChecklistDraft: { checklist in
                store.createDraftMessage(from: checklist)
              } onReady: {
                store.markWishlistReadyForPurchase(item)
              } onPreferredOption: { option in
                store.markWishlistPreferredOption(item, option: option)
              } onDuplicateOption: { option in
                store.duplicateWishlistSellerOption(item, option: option)
              } onUpdateOption: { option in
                store.updateWishlistSellerOption(item, option: option)
              } onRemoveOption: { option in
                store.removeWishlistSellerOption(item, option: option)
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

        wishlistClosedItemsPanel

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
              } onAddOption: {
                store.restoreWishlistItem(item)
              } onScore: {
                store.restoreWishlistItem(item)
              } onEvidenceTask: {
                store.restoreWishlistItem(item)
              } onCheck: {
                store.restoreWishlistItem(item)
              } onDecision: {
                store.restoreWishlistItem(item)
              } onDecisionReviewed: {
                store.restoreWishlistItem(item)
              } onDecisionNeedsReview: {
                store.restoreWishlistItem(item)
              } onDecisionTask: {
                store.restoreWishlistItem(item)
              } onHandoff: {
                store.restoreWishlistItem(item)
              } onHandoffTask: {
                store.restoreWishlistItem(item)
              } onPurchased: {
                store.restoreWishlistItem(item)
              } onOrderSeen: {
                store.restoreWishlistItem(item)
              } onUseConfirmation: { _ in
                store.restoreWishlistItem(item)
              } onAddAccount: {
                store.restoreWishlistItem(item)
              } onAccountTask: { _ in
                store.restoreWishlistItem(item)
              } onAccountDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddCost: {
                store.restoreWishlistItem(item)
              } onCostTask: { _ in
                store.restoreWishlistItem(item)
              } onCostDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddProcurement: {
                store.restoreWishlistItem(item)
              } onProcurementTask: { _ in
                store.restoreWishlistItem(item)
              } onProcurementDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddInspection: {
                store.restoreWishlistItem(item)
              } onInspectionTask: { _ in
                store.restoreWishlistItem(item)
              } onInspectionDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddInventoryReceipt: {
                store.restoreWishlistItem(item)
              } onInventoryReceiptTask: { _ in
                store.restoreWishlistItem(item)
              } onInventoryReceiptDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddStorageLocation: {
                store.restoreWishlistItem(item)
              } onStorageLocationTask: { _ in
                store.restoreWishlistItem(item)
              } onStorageLocationDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddCustody: {
                store.restoreWishlistItem(item)
              } onCustodyTask: { _ in
                store.restoreWishlistItem(item)
              } onCustodyDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddLabelReference: {
                store.restoreWishlistItem(item)
              } onLabelReferenceTask: { _ in
                store.restoreWishlistItem(item)
              } onLabelReferenceDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddScanSession: {
                store.restoreWishlistItem(item)
              } onScanSessionTask: { _ in
                store.restoreWishlistItem(item)
              } onScanSessionDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddShipmentManifest: {
                store.restoreWishlistItem(item)
              } onShipmentManifestTask: { _ in
                store.restoreWishlistItem(item)
              } onShipmentManifestDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddDispatchChecklist: {
                store.restoreWishlistItem(item)
              } onDispatchChecklistTask: { _ in
                store.restoreWishlistItem(item)
              } onDispatchChecklistDraft: { _ in
                store.restoreWishlistItem(item)
              } onReady: {
                store.restoreWishlistItem(item)
              } onPreferredOption: { _ in
                store.restoreWishlistItem(item)
              } onDuplicateOption: { _ in
                store.restoreWishlistItem(item)
              } onUpdateOption: { _ in
                store.restoreWishlistItem(item)
              } onRemoveOption: { _ in
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
    .sheet(item: $editingCaptureCandidate) { capture in
      NavigationStack {
        WishlistCaptureCandidateEditor(capture: capture) { updated in
          store.updateWishlistCaptureCandidate(updated)
          editingCaptureCandidate = nil
        }
      }
    }
    .sheet(isPresented: $showManualWishlistItemForm) {
      NavigationStack {
        WishlistManualItemEditor { draft in
          store.addManualWishlistItem(
            itemName: draft.itemName,
            storefront: draft.storefront,
            storefrontURL: draft.storefrontURL,
            estimatedCost: draft.estimatedCost,
            owner: draft.owner,
            pool: draft.pool,
            notes: draft.notes
          )
          showManualWishlistItemForm = false
        }
      }
    }
    .sheet(isPresented: $showPastedLinkCaptureForm) {
      NavigationStack {
        WishlistPastedLinkCaptureEditor { draft in
          store.stageWishlistCaptureFromPastedLink(
            pastedText: draft.pastedText,
            itemName: draft.itemName,
            sellerHint: draft.sellerHint,
            priceHint: draft.priceHint,
            notes: draft.notes
          )
          showPastedLinkCaptureForm = false
        }
      }
    }
    .sheet(isPresented: $showPastedComparisonResultForm) {
      NavigationStack {
        WishlistPastedComparisonResultEditor(items: activeWishlistItems) { item, draft in
          if draft.splitIntoSellerOptions {
            store.addWishlistSellerOptionsFromPastedComparisonBatch(
              item,
              pastedText: draft.pastedText,
              sellerHint: draft.sellerHint,
              productURLHint: draft.productURLHint,
              listedPriceHint: draft.listedPriceHint,
              currencyHint: draft.currencyHint,
              audTotalHint: draft.audTotalHint,
              postageCostHint: draft.postageCostHint,
              postageTimeHint: draft.postageTimeHint,
              trustHint: draft.trustHint,
              notes: draft.notes
            )
          } else {
            store.addWishlistSellerOptionFromPastedComparison(
              item,
              pastedText: draft.pastedText,
              sellerHint: draft.sellerHint,
              productURLHint: draft.productURLHint,
              listedPriceHint: draft.listedPriceHint,
              currencyHint: draft.currencyHint,
              audTotalHint: draft.audTotalHint,
              postageCostHint: draft.postageCostHint,
              postageTimeHint: draft.postageTimeHint,
              trustHint: draft.trustHint,
              notes: draft.notes
            )
          }
          showPastedComparisonResultForm = false
        }
      }
    }
  }

  private func openManualWishlistItemForm() {
    showManualWishlistItemForm = true
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
    selectedWorkflowFocus = .all
    showClosedItems = false
  }

  private var wishlistNextActionGuidePanel: some View {
    let entries = wishlistNextActionEntries
    let attentionCount = entries.filter { $0.count > 0 && $0.sortPriority < 80 }.count
    let leadingEntry = entries.first { $0.count > 0 } ?? entries.first
    let activeItems = store.activeWishlistItems
    let sellerOptionCount = activeItems.reduce(0) { $0 + ($1.comparisonOptions?.count ?? 0) }
    let openCaptureCount = store.stagedWishlistCaptureCandidateCount
    let activeBriefCount = store.activeWishlistResearchRequestCount
    let activeOrderWatchCount = store.activeWishlistOrderWatchRecordCount

    return SettingsPanel(title: "Wishlist next actions", symbol: "arrowshape.turn.up.right.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: leadingEntry?.symbol ?? "checkmark.seal.fill")
            .foregroundStyle(leadingEntry?.color ?? .green)
            .frame(width: 24, height: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(leadingEntry.map { $0.count > 0 ? $0.title : "Wishlist workflow has no immediate blockers" } ?? "Wishlist workflow has no immediate blockers")
              .font(.headline)
            Text(leadingEntry?.detail ?? "Add a manual item or staged capture when there is a new wanted product to compare.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(attentionCount == 0 ? "Clear" : "\(attentionCount) focus area\(attentionCount == 1 ? "" : "s")", color: attentionCount == 0 ? .green : .orange)
        }

        MetricStrip(items: [
          ("Items", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .purple),
          ("Captures", "\(openCaptureCount)", openCaptureCount == 0 ? .green : .orange),
          ("Briefs", "\(activeBriefCount)", activeBriefCount == 0 ? .secondary : .blue),
          ("Seller options", "\(sellerOptionCount)", sellerOptionCount == 0 ? .secondary : .teal),
          ("Order watch", "\(activeOrderWatchCount)", activeOrderWatchCount == 0 ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 280), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(entries.prefix(6)) { entry in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(entry.title, systemImage: entry.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(entry.color)
                Spacer(minLength: 8)
                Badge("\(entry.count)", color: entry.color)
              }
              Text(entry.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Button(entry.actionTitle, systemImage: entry.actionSymbol) {
                runWishlistNextAction(entry)
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              .disabled(entry.count == 0 && entry.title != "Create comparison briefs")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(entry.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Boundary: this guide only reads and updates local Wishlist records. It does not browse retailer pages, compare live prices, convert currencies, quote postage, rate sellers externally, log into accounts, purchase, pay, or monitor order pages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseTimelineEntries: [WishlistPurchaseTimelineEntry] {
    let activeItems = store.activeWishlistItems
    let total = activeItems.count
    let captureReady = activeItems.filter { item in
      !item.itemName.isPlaceholderValidationValue
        && !item.storefront.isPlaceholderValidationValue
        && !item.storefrontURL.isPlaceholderValidationValue
        && !item.estimatedCost.isPlaceholderValidationValue
        && !item.owner.isPlaceholderValidationValue
    }.count
    let captureAttention = max(total - captureReady, 0)

    let comparisonReady = activeItems.filter { item in
      let options = item.comparisonOptions ?? []
      return !options.isEmpty && item.preferredOptionID != nil
    }.count
    let comparisonAttention = activeItems.filter { item in
      let options = item.comparisonOptions ?? []
      return options.isEmpty || item.preferredOptionID == nil || options.contains { !$0.operatorSellerEvidenceGaps.isEmpty }
    }.count

    let decisionReady = activeItems.filter { $0.purchaseDecision?.reviewState == .accepted }.count
    let decisionAttention = activeItems.filter { item in
      item.purchaseDecision == nil && item.comparisonOptions?.isEmpty == false
        || item.purchaseDecision?.reviewState != nil && item.purchaseDecision?.reviewState != .accepted
    }.count

    let handoffReady = activeItems.filter { $0.purchaseHandoff != nil }.count
    let handoffAttention = activeItems.filter { item in
      item.purchaseDecision?.reviewState == .accepted && item.purchaseHandoff == nil
    }.count

    let watchReady = activeItems.filter { item in
      guard let linkedOrderID = item.purchaseHandoff?.linkedOrderID else { return false }
      return store.orders.contains { $0.id == linkedOrderID }
    }.count
    let watchAttention = activeItems.filter { item in
      item.purchaseHandoff != nil && item.purchaseHandoff?.linkedOrderID == nil
    }.count + store.wishlistOrderWatchRecords.filter {
      store.isActiveWishlistOrderWatchRecord($0) && $0.linkedOrderID == nil
    }.count

    let operationsReady = wishlistOperationsClosureReadinessEntries.filter {
      $0.gaps.isEmpty && $0.openTaskCount == 0
    }.count
    let operationsAttention = wishlistLinkedOrderFollowUpDashboardEntries.filter {
      $0.stage != "Ready for closure"
    }.count + wishlistOperationsClosureReadinessEntries.filter {
      !$0.gaps.isEmpty || $0.openTaskCount > 0
    }.count

    return [
      WishlistPurchaseTimelineEntry(
        title: "1. Capture",
        detail: "Manual item, source, owner, URL, cost, and notes are clear enough to compare.",
        workflowFocus: .capture,
        readyCount: captureReady,
        attentionCount: captureAttention,
        totalCount: total,
        symbol: "square.and.arrow.down.fill",
        tone: captureAttention == 0 ? .green : .blue,
        nextAction: "Focus capture",
        sortPriority: 10
      ),
      WishlistPurchaseTimelineEntry(
        title: "2. Compare",
        detail: "Seller options, landed AUD cost, postage, trust, and preferred seller are locally reviewed.",
        workflowFocus: .compare,
        readyCount: comparisonReady,
        attentionCount: comparisonAttention,
        totalCount: total,
        symbol: "chart.bar.doc.horizontal",
        tone: comparisonAttention == 0 ? .green : .orange,
        nextAction: "Focus compare",
        sortPriority: 20
      ),
      WishlistPurchaseTimelineEntry(
        title: "3. Decide",
        detail: "Purchase decision and readiness checks are accepted before external buying.",
        workflowFocus: .buy,
        readyCount: decisionReady,
        attentionCount: decisionAttention,
        totalCount: total,
        symbol: "checkmark.seal.fill",
        tone: decisionAttention == 0 ? .green : .purple,
        nextAction: "Focus decisions",
        sortPriority: 30
      ),
      WishlistPurchaseTimelineEntry(
        title: "4. Handoff",
        detail: "Seller, account, expected order signals, and manual purchase notes are staged locally.",
        workflowFocus: .buy,
        readyCount: handoffReady,
        attentionCount: handoffAttention,
        totalCount: total,
        symbol: "person.crop.circle.badge.checkmark",
        tone: handoffAttention == 0 ? .green : .purple,
        nextAction: "Focus handoff",
        sortPriority: 40
      ),
      WishlistPurchaseTimelineEntry(
        title: "5. Watch orders",
        detail: "Inbox confirmations and local Orders are linked after the external purchase happens.",
        workflowFocus: .watch,
        readyCount: watchReady,
        attentionCount: watchAttention,
        totalCount: max(handoffReady, 1),
        symbol: "envelope.badge.fill",
        tone: watchAttention == 0 ? .green : .teal,
        nextAction: "Focus watch",
        sortPriority: 50
      ),
      WishlistPurchaseTimelineEntry(
        title: "6. Operations",
        detail: "Linked orders have receiving, inventory, storage, custody, label, dispatch, and closure context.",
        workflowFocus: .operations,
        readyCount: operationsReady,
        attentionCount: operationsAttention,
        totalCount: max(watchReady, 1),
        symbol: "shippingbox.fill",
        tone: operationsAttention == 0 ? .green : .brown,
        nextAction: "Focus operations",
        sortPriority: 60
      )
    ].sorted { $0.sortPriority < $1.sortPriority }
  }

  private var wishlistPurchaseTimelinePanel: some View {
    let entries = wishlistPurchaseTimelineEntries
    let attentionTotal = entries.reduce(0) { $0 + $1.attentionCount }
    let readyTotal = entries.reduce(0) { $0 + $1.readyCount }

    return SettingsPanel(title: "Wishlist purchase timeline", symbol: "timeline.selection") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: attentionTotal == 0 ? "checkmark.seal.fill" : "timeline.selection")
            .foregroundStyle(attentionTotal == 0 ? Color.green : Color.blue)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text("One local path from idea to order follow-up")
              .font(.headline)
            Text("This turns the long Wishlist workspace into six checkpoints: capture, compare, decide, handoff, watch orders, and operations.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(attentionTotal == 0 ? "Clear" : "\(attentionTotal) checks", color: attentionTotal == 0 ? .green : .blue)
        }

        MetricStrip(items: [
          ("Timeline steps", "\(entries.count)", .blue),
          ("Ready signals", "\(readyTotal)", readyTotal == 0 ? .secondary : .green),
          ("Attention", "\(attentionTotal)", attentionTotal == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 330), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(entries) { entry in
            WishlistPurchaseTimelineRow(entry: entry) {
              selectedWorkflowFocus = entry.workflowFocus
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          }
        }

        Text("Timeline counts are local guidance only. ParcelOps does not verify live prices, stock, postage, seller trust, account state, payment, mailbox state, carrier status, dispatch booking, or delivery completion.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseReadinessEntries: [WishlistPurchaseReadinessEntry] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .map { item in
        let checks = item.purchaseChecks ?? []
        let passedChecks = checks.filter { $0.status == "Passed" }.count
        let blockers = item.operatorPurchaseBlockers
        let hasOptions = item.comparisonOptions?.isEmpty == false
        let hasPreferredSeller = item.preferredOptionID != nil
        let decisionAccepted = item.purchaseDecision?.reviewState == .accepted
        let hasHandoff = item.purchaseHandoff != nil
        let linkedOrder = item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
          store.orders.first { $0.id == orderID }
        }

        let stage: String
        let detail: String
        let nextAction: String
        let nextSymbol: String
        let tone: Color
        let sortPriority: Int

        if !hasOptions {
          stage = "Needs comparison"
          detail = "Add or brief seller options before assessing landed price, postage, trust, or purchase readiness."
          nextAction = "Create brief"
          nextSymbol = "doc.text.magnifyingglass"
          tone = .blue
          sortPriority = 10
        } else if !hasPreferredSeller {
          stage = "Choose seller"
          detail = "Seller options exist, but no preferred option is selected for readiness checks and decision review."
          nextAction = "Score sellers"
          nextSymbol = "shield.checkered"
          tone = .orange
          sortPriority = 20
        } else if checks.isEmpty || checks.contains(where: { $0.status != "Passed" }) {
          stage = checks.isEmpty ? "Checks needed" : "Checks blocked"
          detail = item.purchaseReadiness ?? "Run the local purchase readiness check before drafting or accepting a decision."
          nextAction = "Run checks"
          nextSymbol = "checklist.checked"
          tone = checks.isEmpty ? .orange : .red
          sortPriority = checks.isEmpty ? 30 : 35
        } else if item.purchaseDecision == nil {
          stage = "Decision needed"
          detail = "Readiness checks are clear enough to draft a local purchase decision for review."
          nextAction = "Draft decision"
          nextSymbol = "doc.badge.plus"
          tone = .purple
          sortPriority = 40
        } else if !decisionAccepted {
          stage = "Decision review"
          detail = "Purchase decision exists but still needs local review before an external purchase handoff."
          nextAction = "Mark reviewed"
          nextSymbol = "checkmark.seal.fill"
          tone = .brown
          sortPriority = 50
        } else if !hasHandoff {
          stage = "Handoff needed"
          detail = "Decision is accepted. Prepare seller, account, expected order signal, and order-watch notes before buying externally."
          nextAction = "Prepare handoff"
          nextSymbol = "person.crop.circle.badge.checkmark"
          tone = .purple
          sortPriority = 60
        } else if linkedOrder == nil {
          stage = "Watch order"
          detail = "Purchase handoff exists. Link the eventual Inbox confirmation or local order after the external purchase."
          nextAction = "Order seen"
          nextSymbol = "envelope.badge.fill"
          tone = .teal
          sortPriority = 70
        } else {
          stage = "Linked order"
          detail = "Wishlist handoff is linked to \(linkedOrder?.orderNumber ?? "a local order"). Use Orders and Operations as the source of truth."
          nextAction = "Focus item"
          nextSymbol = "scope"
          tone = .green
          sortPriority = 90
        }

        return WishlistPurchaseReadinessEntry(
          item: item,
          passedChecks: passedChecks,
          totalChecks: checks.count,
          blockers: blockers,
          stage: stage,
          detail: detail,
          nextAction: nextAction,
          nextSymbol: nextSymbol,
          tone: tone,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseReadinessChecklistPanel: some View {
    let entries = wishlistPurchaseReadinessEntries
    let attentionEntries = entries.filter { $0.sortPriority < 90 }
    let readyEntries = entries.filter { $0.sortPriority >= 90 }
    let blockedChecks = entries.filter { $0.stage == "Checks blocked" }.count
    let handoffNeeded = entries.filter { $0.stage == "Handoff needed" }.count
    let watchNeeded = entries.filter { $0.stage == "Watch order" }.count

    return SettingsPanel(title: "Wishlist purchase readiness checklist", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: attentionEntries.isEmpty ? "checkmark.seal.fill" : "checklist.checked")
            .foregroundStyle(attentionEntries.isEmpty ? Color.green : Color.orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(attentionEntries.isEmpty ? "Wishlist purchase readiness is clear" : "Work these items before buying externally")
              .font(.headline)
            Text(attentionEntries.isEmpty
              ? "Active Wishlist items either have linked order context or no counted readiness blocker."
              : "This is the compact checklist for manual purchasing: compare, choose seller, run checks, review decision, prepare handoff, then watch for the order confirmation.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(attentionEntries.isEmpty ? "Clear" : "\(attentionEntries.count) to review", color: attentionEntries.isEmpty ? .green : .orange)
        }

        MetricStrip(items: [
          ("Active", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("To review", "\(attentionEntries.count)", attentionEntries.isEmpty ? .green : .orange),
          ("Check blocks", "\(blockedChecks)", blockedChecks == 0 ? .green : .red),
          ("Handoff", "\(handoffNeeded)", handoffNeeded == 0 ? .green : .purple),
          ("Order watch", "\(watchNeeded)", watchNeeded == 0 ? .secondary : .teal),
          ("Linked", "\(readyEntries.count)", readyEntries.isEmpty ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No active Wishlist items",
            detail: "Add a manual item or use a local capture placeholder to start purchase readiness checks.",
            symbol: "star.square.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseReadinessRow(entry: entry) {
                runWishlistPurchaseReadinessAction(for: entry)
              } onTask: {
                createWishlistPurchaseReadinessTask(for: entry)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }
        }

        Text("Readiness is local guidance only. ParcelOps does not buy the item, log into sellers, verify live price or stock, send payment, open a browser, mutate mailboxes, or run background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseTriagePanel: some View {
    let entries = wishlistPurchaseReadinessEntries
    let blockedEntries = entries.filter { $0.sortPriority < 60 }
    let handoffEntries = entries.filter { $0.stage == "Handoff needed" }
    let watchEntries = entries.filter { $0.stage == "Watch order" }
    let linkedEntries = entries.filter { $0.stage == "Linked order" }
    let primaryEntry = blockedEntries.first ?? handoffEntries.first ?? watchEntries.first

    return SettingsPanel(title: "Wishlist purchase triage", symbol: "cart.badge.questionmark") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: primaryEntry?.nextSymbol ?? "checkmark.seal.fill")
            .foregroundStyle(primaryEntry?.tone ?? .green)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(primaryEntry.map { "Next purchase step: \($0.stage)" } ?? "No active purchase triage blockers")
              .font(.headline)
            Text(primaryEntry?.detail ?? "Wishlist items either have no purchase-stage work yet or are already linked to local order context.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(primaryEntry == nil ? "Clear" : "Action needed", color: primaryEntry?.tone ?? .green)
        }

        MetricStrip(items: [
          ("Blocked", "\(blockedEntries.count)", blockedEntries.isEmpty ? .green : .orange),
          ("Handoff", "\(handoffEntries.count)", handoffEntries.isEmpty ? .secondary : .purple),
          ("Order watch", "\(watchEntries.count)", watchEntries.isEmpty ? .secondary : .teal),
          ("Linked", "\(linkedEntries.count)", linkedEntries.isEmpty ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No active Wishlist purchase work",
            detail: "Add a manual item or staged capture before purchase triage has anything to review.",
            symbol: "star.square.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 320), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(Array(entries.prefix(4))) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: entry.nextSymbol)
                    .foregroundStyle(entry.tone)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(entry.item.itemName)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(2)
                    Text(entry.stage)
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(entry.tone)
                    Text(entry.detail)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 8)
                  Badge(entry.stage, color: entry.tone)
                }

                CompactActionRow {
                  Button(entry.nextAction, systemImage: entry.nextSymbol) {
                    runWishlistPurchaseReadinessAction(for: entry)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = entry.item.itemName
                    selectedSource = nil
                    selectedStatus = nil
                    selectedWorkflowFocus = .all
                  }
                  Button("Task", systemImage: "checklist") {
                    createWishlistPurchaseReadinessTask(for: entry)
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              .overlay(RoundedRectangle(cornerRadius: 8).stroke(entry.tone.opacity(0.18)))
            }
          }
        }

        Text("Use this for local triage only. It does not compare live retailers, open websites, store payment details, purchase items, or watch seller pages in the background.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistPurchaseReadinessAction(for entry: WishlistPurchaseReadinessEntry) {
    switch entry.stage {
    case "Needs comparison":
      store.createWishlistComparisonPlan(entry.item)
      store.createWishlistResearchRequest(from: entry.item)
      selectedWorkflowFocus = .compare
    case "Choose seller":
      store.evaluateWishlistComparisonOptions(entry.item)
      selectedWorkflowFocus = .compare
    case "Checks needed", "Checks blocked":
      store.runWishlistPurchaseReadinessCheck(entry.item)
      selectedWorkflowFocus = .buy
    case "Decision needed":
      store.createWishlistPurchaseDecision(entry.item)
      selectedWorkflowFocus = .buy
    case "Decision review":
      store.markWishlistPurchaseDecisionReviewed(entry.item)
      selectedWorkflowFocus = .buy
    case "Handoff needed":
      store.prepareWishlistPurchaseHandoff(entry.item)
      selectedWorkflowFocus = .watch
    case "Watch order":
      store.markWishlistOrderConfirmationSeen(entry.item)
      selectedWorkflowFocus = .watch
    default:
      wishlistSearchText = entry.item.itemName
    }
    selectedSource = nil
    selectedStatus = nil
  }

  private func createWishlistPurchaseReadinessTask(for entry: WishlistPurchaseReadinessEntry) {
    switch entry.stage {
    case "Decision needed", "Decision review", "Checks needed", "Checks blocked":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    case "Handoff needed", "Watch order":
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    case "Choose seller":
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    default:
      store.createReviewTask(from: entry.item)
    }
  }

  private func runWishlistNextAction(_ entry: WishlistNextActionEntry) {
    switch entry.title {
    case "Clean capture inputs":
      wishlistSearchText = ""
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .capture
    case "Create comparison briefs":
      store.createMissingWishlistResearchRequests()
      selectedWorkflowFocus = .compare
    case "Fix research scope", "Review seller evidence":
      wishlistSearchText = ""
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .compare
    case "Clear purchase blockers":
      wishlistSearchText = ""
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .buy
    case "Match order confirmations":
      wishlistSearchText = ""
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .watch
    case "Operational handoff":
      wishlistSearchText = ""
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .operations
    default:
      break
    }
  }

  private var wishlistComparisonReadinessLadderPanel: some View {
    let activeItems = store.activeWishlistItems
    let activeResearchRequests = store.activeWishlistResearchRequests
    let stagedCaptureGaps = store.wishlistCaptureCandidates.filter { !$0.operatorCaptureGaps.isEmpty }.count
    let unbriefedItems = activeItems.filter { item in
      !activeResearchRequests.contains { $0.wishlistItemID == item.id }
        && (item.comparisonOptions ?? []).isEmpty
    }.count
    let researchScopeGaps = activeResearchRequests.filter {
      !$0.isAgentBriefReady && !$0.requestStatus.localizedCaseInsensitiveContains("blocked")
    }.count
    let sellerEvidenceGaps = activeItems.filter { item in
      (item.comparisonOptions ?? []).contains { !$0.operatorSellerEvidenceGaps.isEmpty }
    }.count
    let purchaseBlockers = activeItems.filter { !$0.operatorPurchaseBlockers.isEmpty }.count
    let acceptedDecisions = activeItems.filter { $0.purchaseDecision?.reviewState == .accepted }.count
    let orderWatchItems = activeItems.filter {
      $0.purchaseHandoff != nil && $0.purchaseHandoff?.linkedOrderID == nil
    }.count
    let linkedOperationalItems = activeItems.filter {
      $0.purchaseHandoff?.linkedOrderID != nil
        || !store.suggestedReceivingInspections(for: $0).isEmpty
        || !store.suggestedInventoryReceipts(for: $0).isEmpty
        || !store.suggestedDispatchReadinessChecklists(for: $0).isEmpty
    }.count
    let blockingCount = stagedCaptureGaps + unbriefedItems + researchScopeGaps + sellerEvidenceGaps + purchaseBlockers

    let steps: [(title: String, status: String, detail: String, count: Int, symbol: String, color: Color, focus: WishlistWorkflowFocus)] = [
      (
        "1. Capture",
        stagedCaptureGaps == 0 ? "Inputs clear" : "Fix captures",
        stagedCaptureGaps == 0 ? "Manual items and staged captures have enough basic product context." : "Confirm item name, seller, URL, price clues, and owner before comparison.",
        stagedCaptureGaps,
        "square.and.arrow.down.fill",
        stagedCaptureGaps == 0 ? .green : .orange,
        .capture
      ),
      (
        "2. Research brief",
        unbriefedItems == 0 ? "Briefs present" : "Create briefs",
        unbriefedItems == 0 ? "Active items have a local brief or seller option context." : "Create a local comparison brief before any human or future agent compares retailers.",
        unbriefedItems,
        "doc.text.magnifyingglass",
        unbriefedItems == 0 ? .green : .blue,
        .compare
      ),
      (
        "3. Scope quality",
        researchScopeGaps == 0 ? "Scope clear" : "Scope gaps",
        researchScopeGaps == 0 ? "Research requests include item, source, budget, region, postage, and trust expectations." : "Fill missing AUD budget, region, seller criteria, postage, trust, source, or review fields.",
        researchScopeGaps,
        "checklist.checked",
        researchScopeGaps == 0 ? .green : .orange,
        .compare
      ),
      (
        "4. Seller comparison",
        sellerEvidenceGaps == 0 ? "Evidence clear" : "Evidence gaps",
        sellerEvidenceGaps == 0 ? "Recorded seller options have enough local evidence for operator review." : "Add product URL, AUD landed total, postage, delivery time, trust, returns, or recommendation notes.",
        sellerEvidenceGaps,
        "shield.checkered",
        sellerEvidenceGaps == 0 ? .green : .purple,
        .compare
      ),
      (
        "5. Purchase decision",
        purchaseBlockers == 0 ? "\(acceptedDecisions) accepted" : "Blocked",
        purchaseBlockers == 0 ? "Purchase decisions can be drafted or reviewed locally before any external purchase." : "Resolve seller choice, price, postage, trust, approval, account, or order-watch checks before buying.",
        purchaseBlockers,
        "cart.badge.plus",
        purchaseBlockers == 0 ? .green : .orange,
        .buy
      ),
      (
        "6. Order watch",
        orderWatchItems == 0 ? "No watch queue" : "Watch confirmations",
        orderWatchItems == 0 ? "No purchased Wishlist item is currently waiting for an order confirmation link." : "After external purchase, match Inbox/Orders confirmation back to the Wishlist handoff.",
        orderWatchItems,
        "envelope.badge.fill",
        orderWatchItems == 0 ? .secondary : .teal,
        .watch
      ),
      (
        "7. Operations",
        linkedOperationalItems == 0 ? "Not started" : "Linked",
        linkedOperationalItems == 0 ? "Operations work starts after a Wishlist handoff is linked to an order or downstream records." : "Continue receiving, storage, custody, labels, dispatch, and closure checks.",
        linkedOperationalItems,
        "shippingbox.fill",
        linkedOperationalItems == 0 ? .secondary : .green,
        .operations
      )
    ]

    return SettingsPanel(title: "Wishlist comparison readiness ladder", symbol: "list.bullet.rectangle.portrait.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: blockingCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(blockingCount == 0 ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(blockingCount == 0 ? "Wishlist comparison path is locally clear" : "Wishlist comparison path has local blockers")
              .font(.headline)
            Text(blockingCount == 0
              ? "Use the queue below to choose a purchase decision, prepare a handoff, or match order confirmations when needed."
              : "Work the ladder top-down before relying on seller comparisons, purchase decisions, or order-watch handoff.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(blockingCount == 0 ? "Clear" : "\(blockingCount) blocker\(blockingCount == 1 ? "" : "s")", color: blockingCount == 0 ? .green : .orange)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 260), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(step.title, systemImage: step.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(step.color)
                Spacer(minLength: 8)
                Badge(step.status, color: step.color)
              }
              Text(step.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              HStack {
                Badge("\(step.count)", color: step.color)
                Spacer()
                Button("Focus", systemImage: "scope") {
                  selectedWorkflowFocus = step.focus
                  selectedSource = nil
                  selectedStatus = nil
                  wishlistSearchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(step.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Boundary: this ladder reads local Wishlist records only. It does not compare live websites, convert currency, rate sellers externally, log into retailer accounts, purchase, pay, scrape pages, or monitor orders in the background.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistOperatorControlCentrePanel: some View {
    let activeItems = store.activeWishlistItems
    let captureGaps = store.wishlistCaptureCandidates.filter { !$0.operatorCaptureGaps.isEmpty }.count
    let missingResearch = activeItems.filter { item in
      (item.comparisonOptions ?? []).isEmpty
        && !store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id && store.isActiveWishlistResearchRequest($0) }
    }.count
    let comparisonGaps = activeItems.filter { item in
      (item.comparisonOptions ?? []).contains { !$0.operatorSellerEvidenceGaps.isEmpty }
        || item.preferredOptionID == nil && (item.comparisonOptions ?? []).isEmpty == false
    }.count
    let readinessGaps = activeItems.filter { item in
      let checks = item.purchaseChecks ?? []
      return item.purchaseDecision != nil
        && (checks.isEmpty || checks.contains { $0.status != "Passed" })
    }.count
    let handoffGaps = activeItems.filter {
      $0.purchaseDecision?.reviewState == .accepted && $0.purchaseHandoff == nil
    }.count
    let openOrderWatch = store.wishlistOrderWatchRecords.filter {
      store.isActiveWishlistOrderWatchRecord($0)
        && $0.linkedOrderID == nil
        && !$0.watchStatus.localizedCaseInsensitiveContains("blocked")
    }.count
    let closureCandidates = activeItems.filter {
      $0.purchaseHandoff?.linkedOrderID != nil
        || !store.suggestedReceivingInspections(for: $0).isEmpty
        || !store.suggestedInventoryReceipts(for: $0).isEmpty
        || !store.suggestedStorageLocations(for: $0).isEmpty
        || !store.suggestedCustodyRecords(for: $0).isEmpty
        || !store.suggestedLabelReferenceRecords(for: $0).isEmpty
        || !store.suggestedScanSessionRecords(for: $0).isEmpty
        || !store.suggestedShipmentManifestRecords(for: $0).isEmpty
        || !store.suggestedDispatchReadinessChecklists(for: $0).isEmpty
    }.count
    let operatorWork = captureGaps + missingResearch + comparisonGaps + readinessGaps + handoffGaps + openOrderWatch

    return SettingsPanel(title: "Wishlist operator control centre", symbol: "slider.horizontal.3") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: operatorWork == 0 ? "checkmark.circle.fill" : "scope")
            .foregroundStyle(operatorWork == 0 ? .green : .blue)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(operatorWork == 0 ? "Wishlist queue is locally tidy" : "Run the next local Wishlist controls from here")
              .font(.headline)
            Text(operatorWork == 0
              ? "No immediate local capture, research, purchase, handoff, or order-watch blockers are counted."
              : "Use this panel as the short path through the long Wishlist workspace: capture cleanup, research briefs, seller evidence, purchase checks, handoff, then order-watch matching.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(operatorWork == 0 ? "Clear" : "\(operatorWork) work item\(operatorWork == 1 ? "" : "s")", color: operatorWork == 0 ? .green : .blue)
        }

        MetricStrip(items: [
          ("Active", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .blue),
          ("Capture gaps", "\(captureGaps)", captureGaps == 0 ? .green : .orange),
          ("Need briefs", "\(missingResearch)", missingResearch == 0 ? .green : .purple),
          ("Seller gaps", "\(comparisonGaps)", comparisonGaps == 0 ? .green : .orange),
          ("Checks", "\(readinessGaps)", readinessGaps == 0 ? .green : .brown),
          ("Handoff", "\(handoffGaps)", handoffGaps == 0 ? .green : .purple),
          ("Order watch", "\(openOrderWatch)", openOrderWatch == 0 ? .secondary : .teal),
          ("Closure", "\(closureCandidates)", closureCandidates == 0 ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 320), spacing: 10)], alignment: .leading, spacing: 10) {
          wishlistOperatorControlCard(
            title: "1. Capture cleanup",
            detail: captureGaps == 0 ? "No staged capture gaps are counted." : "Open capture focus and fix item, seller, URL, price, or owner gaps.",
            count: captureGaps,
            color: captureGaps == 0 ? .green : .orange,
            symbol: "square.and.arrow.down.fill",
            buttonTitle: "Focus capture",
            action: {
              selectedWorkflowFocus = .capture
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          )

          wishlistOperatorControlCard(
            title: "2. Research briefs",
            detail: missingResearch == 0 ? "Every active unpriced item has a brief or seller option context." : "Create missing local research briefs before comparison work.",
            count: missingResearch,
            color: missingResearch == 0 ? .green : .purple,
            symbol: "doc.text.magnifyingglass",
            buttonTitle: "Create briefs",
            action: store.createMissingWishlistResearchRequests
          )

          wishlistOperatorControlCard(
            title: "3. Seller evidence",
            detail: comparisonGaps == 0 ? "No preferred-seller or evidence gaps are counted." : "Focus comparison rows and fill URL, AUD total, postage, trust, returns, or recommendation gaps.",
            count: comparisonGaps,
            color: comparisonGaps == 0 ? .green : .orange,
            symbol: "shield.checkered",
            buttonTitle: "Focus compare",
            action: {
              selectedWorkflowFocus = .compare
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          )

          wishlistOperatorControlCard(
            title: "4. Purchase checks",
            detail: readinessGaps == 0 ? "No drafted purchase decision currently needs readiness checks." : "Run local readiness checks for decision queue items.",
            count: readinessGaps,
            color: readinessGaps == 0 ? .green : .brown,
            symbol: "checklist.checked",
            buttonTitle: "Run checks",
            action: store.runWishlistPurchaseReadinessChecksForDecisionQueue
          )

          wishlistOperatorControlCard(
            title: "5. Purchase handoff",
            detail: handoffGaps == 0 ? "No accepted decision is missing a local purchase handoff." : "Focus buy rows and prepare account, payment, delivery, and order-watch notes.",
            count: handoffGaps,
            color: handoffGaps == 0 ? .green : .purple,
            symbol: "person.crop.circle.badge.checkmark",
            buttonTitle: "Focus buy",
            action: {
              selectedWorkflowFocus = .buy
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          )

          wishlistOperatorControlCard(
            title: "6. Order watch",
            detail: openOrderWatch == 0 ? "No open watch rules are waiting for local order matching." : "Check open Wishlist order-watch records against local Orders.",
            count: openOrderWatch,
            color: openOrderWatch == 0 ? .secondary : .teal,
            symbol: "envelope.badge.fill",
            buttonTitle: "Check matches",
            action: store.checkOpenWishlistOrderWatchRecords
          )

          wishlistOperatorControlCard(
            title: "7. Closure readiness",
            detail: closureCandidates == 0 ? "No linked Wishlist item is ready for closure review." : "Check linked operational records for closure blockers.",
            count: closureCandidates,
            color: closureCandidates == 0 ? .secondary : .green,
            symbol: "checkmark.seal.text.page.fill",
            buttonTitle: "Check closure",
            action: store.checkWishlistOperationsClosureReadinessBatch
          )
        }

        Text("These controls only update local records, review tasks, drafts, and audit events. They do not compare live retailers, open accounts, purchase, pay, mutate mailboxes, scrape pages, run background jobs, or contact external services.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistExceptionQueuePanel: some View {
    let entries = wishlistExceptionQueueEntries
    let compare = entries.filter { $0.stage == "Compare" }.count
    let buy = entries.filter { $0.stage == "Buy" }.count
    let watch = entries.filter { $0.stage == "Watch" }.count
    let operations = entries.filter { $0.stage == "Operations" || $0.stage == "Closure" }.count

    return SettingsPanel(title: "Wishlist exception queue", symbol: "exclamationmark.triangle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: entries.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(entries.isEmpty ? Color.green : Color.orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(entries.isEmpty ? "No Wishlist exceptions need attention" : "Wishlist items needing operator follow-up")
              .font(.headline)
            Text(entries.isEmpty
              ? "Capture, comparison, purchase handoff, order-watch, operations, and closure checks are not reporting urgent local blockers."
              : "This queue pulls the highest-impact Wishlist blockers into one place so daily operators do not have to scan every detailed Wishlist panel.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(entries.isEmpty ? "Clear" : "\(entries.count) exception\(entries.count == 1 ? "" : "s")", color: entries.isEmpty ? .green : .orange)
        }

        MetricStrip(items: [
          ("Exceptions", "\(entries.count)", entries.isEmpty ? .green : .orange),
          ("Compare", "\(compare)", compare == 0 ? .green : .red),
          ("Buy", "\(buy)", buy == 0 ? .green : .purple),
          ("Watch", "\(watch)", watch == 0 ? .green : .teal),
          ("Ops/closure", "\(operations)", operations == 0 ? .green : .brown)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "Wishlist exception queue is clear",
            detail: "New capture gaps, seller trust risks, missing purchase handoffs, unlinked orders, operations gaps, and closure blockers will appear here.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistExceptionQueueRow(entry: entry, store: store) {
                runWishlistExceptionQueueAction(for: entry)
              } onTask: {
                createWishlistExceptionQueueTask(for: entry)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist exception\(remaining == 1 ? "" : "s") are available in the detailed sections below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This queue only routes local work. It does not scrape sellers, compare live prices, log in, purchase, mutate mailboxes, poll carriers, book dispatch, send notifications, or contact retailers.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistOperationsNextStepsPanel: some View {
    let handoffEntries = wishlistPurchaseOperationsHandoffItems
    let linkedEntries = wishlistLinkedOrderOperationsChecklistEntries
    let closureEntries = wishlistOperationsClosureReadinessEntries
    let needsOrderLink = handoffEntries.filter { entry in
      entry.linkedOrder == nil || entry.gaps.contains { $0.localizedCaseInsensitiveContains("order") }
    }
    let needsOperationalRecords = handoffEntries.filter { !$0.gaps.isEmpty }
    let linkedButIncomplete = linkedEntries.filter { entry in
      entry.phaseChecks.contains { !$0.1 }
    }
    let blockedClosure = closureEntries.filter { entry in
      !entry.gaps.isEmpty || entry.openTaskCount > 0
    }
    let readyToClose = closureEntries.filter { entry in
      entry.gaps.isEmpty && entry.openTaskCount == 0
    }
    let totalAttention = needsOrderLink.count + needsOperationalRecords.count + linkedButIncomplete.count + blockedClosure.count
    let leadingText: String
    if totalAttention == 0 {
      leadingText = readyToClose.isEmpty
        ? "No purchased Wishlist item is waiting on operations handoff."
        : "\(readyToClose.count) Wishlist item\(readyToClose.count == 1 ? "" : "s") look locally ready for closure review."
    } else {
      leadingText = "Focus the operations handoff queue before closing Wishlist purchases."
    }

    return SettingsPanel(title: "Wishlist operations next steps", symbol: "shippingbox.and.arrow.backward.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: totalAttention == 0 ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .foregroundStyle(totalAttention == 0 ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(totalAttention == 0 ? "Operations handoff is locally clear" : "Operations handoff needs attention")
              .font(.headline)
            Text(leadingText)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(totalAttention == 0 ? "Clear" : "\(totalAttention) gap\(totalAttention == 1 ? "" : "s")", color: totalAttention == 0 ? .green : .orange)
        }

        MetricStrip(items: [
          ("Need order link", "\(needsOrderLink.count)", needsOrderLink.isEmpty ? .green : .teal),
          ("Need records", "\(needsOperationalRecords.count)", needsOperationalRecords.isEmpty ? .green : .orange),
          ("Incomplete", "\(linkedButIncomplete.count)", linkedButIncomplete.isEmpty ? .green : .purple),
          ("Closure blocked", "\(blockedClosure.count)", blockedClosure.isEmpty ? .green : .brown),
          ("Ready to close", "\(readyToClose.count)", readyToClose.isEmpty ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 235 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
          wishlistOperationsNextStepCard(
            title: "1. Match purchase to order",
            detail: needsOrderLink.isEmpty ? "No purchase handoff is waiting for an order link." : "Use Inbox or Orders confirmations to link purchased Wishlist items to tracked orders.",
            count: needsOrderLink.count,
            color: needsOrderLink.isEmpty ? .green : .teal,
            symbol: "link.badge.plus",
            buttonTitle: "Focus watch",
            action: {
              selectedWorkflowFocus = .watch
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          )

          wishlistOperationsNextStepCard(
            title: "2. Stage downstream records",
            detail: needsOperationalRecords.isEmpty ? "Receiving, inventory, storage, custody, label, manual-check, and dispatch placeholders are staged where needed." : "Create the next missing local operations records for purchased items.",
            count: needsOperationalRecords.count,
            color: needsOperationalRecords.isEmpty ? .green : .orange,
            symbol: "wand.and.stars",
            buttonTitle: "Stage records",
            action: {
              stageNextWishlistOperationsRecords(for: Array(handoffEntries.prefix(8)))
              selectedWorkflowFocus = .operations
            }
          )

          wishlistOperationsNextStepCard(
            title: "3. Complete linked setup",
            detail: linkedButIncomplete.isEmpty ? "Linked Wishlist orders have no counted operations setup gaps." : "Review linked-order, receiving, stock, storage, custody, label, manual-check, and dispatch setup.",
            count: linkedButIncomplete.count,
            color: linkedButIncomplete.isEmpty ? .green : .purple,
            symbol: "checklist.checked",
            buttonTitle: "Focus setup",
            action: {
              selectedWorkflowFocus = .operations
              selectedSource = nil
              selectedStatus = nil
              wishlistSearchText = ""
            }
          )

          wishlistOperationsNextStepCard(
            title: "4. Check closure readiness",
            detail: blockedClosure.isEmpty ? "No local closure blockers are counted." : "Run the closure check after downstream records and follow-up tasks are staged.",
            count: blockedClosure.count,
            color: blockedClosure.isEmpty ? .green : .brown,
            symbol: "checkmark.seal.text.page.fill",
            buttonTitle: "Check closure",
            action: store.checkWishlistOperationsClosureReadinessBatch
          )
        }

        CompactActionRow {
          Button("Stage next records", systemImage: "wand.and.stars") {
            stageNextWishlistOperationsRecords(for: Array(handoffEntries.prefix(8)))
          }
          .disabled(needsOperationalRecords.isEmpty)
          Button("Closure check", systemImage: "checkmark.seal.text.page.fill", action: store.checkWishlistOperationsClosureReadinessBatch)
            .disabled(closureEntries.isEmpty)
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Text("This is a local operator summary. It does not receive stock, scan labels, book dispatch, contact sellers, update retailer accounts, or close external orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistOperationsNextStepCard(
    title: String,
    detail: String,
    count: Int,
    color: Color,
    symbol: String,
    buttonTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
        Spacer(minLength: 8)
        Badge("\(count)", color: color)
      }
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button(buttonTitle, systemImage: symbol, action: action)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(count == 0 && title != "4. Check closure readiness")
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var wishlistSellerDecisionSnapshotEntries: [WishlistSellerDecisionSnapshotEntry] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .compactMap { item -> WishlistSellerDecisionSnapshotEntry? in
        let options = item.comparisonOptions ?? []
        let preferred = item.preferredOptionID.flatMap { preferredID in
          options.first { $0.id == preferredID }
        } ?? options.first
        let bestScored = options.sorted { first, second in
          if (first.localScore ?? -1) == (second.localScore ?? -1) {
            return first.sellerName.localizedCaseInsensitiveCompare(second.sellerName) == .orderedAscending
          }
          return (first.localScore ?? -1) > (second.localScore ?? -1)
        }.first
        let selected = preferred ?? bestScored
        let gaps = options.flatMap(\.operatorSellerEvidenceGaps)
        var seenGaps = Set<String>()
        let uniqueGaps = gaps.filter { gap in
          let key = gap.localizedLowercase
          guard !seenGaps.contains(key) else { return false }
          seenGaps.insert(key)
          return true
        }
        let trustReview = options.contains { option in
          option.trustRating.localizedCaseInsensitiveContains("unknown")
            || option.trustRating.localizedCaseInsensitiveContains("review")
            || option.trustRating.localizedCaseInsensitiveContains("needs")
            || (option.riskLevel ?? "").localizedCaseInsensitiveContains("high")
        }
        let missingPreferred = !options.isEmpty && item.preferredOptionID == nil

        let stage: String
        let detail: String
        let tone: Color
        let nextAction: String
        let nextSymbol: String
        let priority: Int

        if options.isEmpty {
          stage = "Need sellers"
          detail = "No seller options are recorded yet. Add or draft a comparison before choosing where to buy."
          tone = .orange
          nextAction = "Create plan"
          nextSymbol = "magnifyingglass.circle"
          priority = 10
        } else if !uniqueGaps.isEmpty {
          stage = "Evidence gaps"
          detail = "Missing \(uniqueGaps.prefix(4).joined(separator: ", "))."
          tone = .orange
          nextAction = "Score options"
          nextSymbol = "chart.bar.doc.horizontal"
          priority = 20
        } else if missingPreferred {
          stage = "Choose seller"
          detail = "Seller options are recorded but no preferred seller has been selected."
          tone = .purple
          nextAction = "Score options"
          nextSymbol = "chart.bar.doc.horizontal"
          priority = 30
        } else if trustReview {
          stage = "Trust review"
          detail = "Seller trust or delivery reliability needs operator review before purchase handoff."
          tone = .red
          nextAction = "Trust task"
          nextSymbol = "shield.lefthalf.filled"
          priority = 40
        } else if item.purchaseDecision == nil {
          stage = "Decision ready"
          detail = "Seller option fields look complete enough for a local purchase decision draft."
          tone = .green
          nextAction = "Draft decision"
          nextSymbol = "doc.badge.plus"
          priority = 50
        } else {
          return nil
        }

        return WishlistSellerDecisionSnapshotEntry(
          item: item,
          selectedOption: selected,
          optionCount: options.count,
          gapCount: uniqueGaps.count,
          gapSummary: uniqueGaps.isEmpty ? "No seller evidence gaps counted." : uniqueGaps.prefix(4).joined(separator: ", "),
          stage: stage,
          detail: detail,
          nextAction: nextAction,
          nextSymbol: nextSymbol,
          tone: tone,
          sortPriority: priority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          if first.gapCount == second.gapCount {
            return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
          }
          return first.gapCount > second.gapCount
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistSellerDecisionSnapshotPanel: some View {
    let entries = wishlistSellerDecisionSnapshotEntries
    let needSellers = entries.filter { $0.stage == "Need sellers" }.count
    let evidenceGaps = entries.filter { $0.stage == "Evidence gaps" }.count
    let trustReview = entries.filter { $0.stage == "Trust review" }.count
    let decisionReady = entries.filter { $0.stage == "Decision ready" }.count

    return SettingsPanel(title: "Seller decision snapshot", symbol: "storefront.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: entries.isEmpty ? "checkmark.seal.fill" : "storefront.fill")
            .foregroundStyle(entries.isEmpty ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(entries.isEmpty ? "Seller decisions are locally tidy" : "Seller decisions need operator review")
              .font(.headline)
            Text(entries.isEmpty
              ? "No active Wishlist item is missing seller options, preferred seller choice, trust review, or decision drafting."
              : "Review seller choice, AUD landed total, postage timing, and trust evidence before any external purchase.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(entries.isEmpty ? "Clear" : "\(entries.count) item\(entries.count == 1 ? "" : "s")", color: entries.isEmpty ? .green : .orange)
        }

        MetricStrip(items: [
          ("Need sellers", "\(needSellers)", needSellers == 0 ? .green : .orange),
          ("Evidence gaps", "\(evidenceGaps)", evidenceGaps == 0 ? .green : .purple),
          ("Trust review", "\(trustReview)", trustReview == 0 ? .green : .red),
          ("Decision ready", "\(decisionReady)", decisionReady == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller decision work waiting",
            detail: "Wishlist items either have seller decisions moving forward or are not ready for seller review yet.",
            symbol: "storefront.circle.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistSellerDecisionSnapshotRow(entry: entry) {
                runWishlistSellerDecisionSnapshotAction(for: entry)
              } onTask: {
                store.createWishlistSellerEvidenceReviewTask(entry.item)
              } onFocus: {
                selectedWorkflowFocus = .compare
                selectedSource = nil
                selectedStatus = nil
                wishlistSearchText = entry.item.itemName
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller decision item\(remaining == 1 ? "" : "s") are available in the detailed comparison panels below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This snapshot is local-only. It does not browse retailer sites, convert currency, quote postage, check live stock, verify seller trust externally, log into accounts, buy, or pay.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistSellerDecisionSnapshotAction(for entry: WishlistSellerDecisionSnapshotEntry) {
    switch entry.stage {
    case "Need sellers":
      store.createWishlistComparisonPlan(entry.item)
      store.createWishlistResearchRequest(from: entry.item)
    case "Evidence gaps", "Choose seller":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Trust review":
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    case "Decision ready":
      store.createWishlistPurchaseDecision(entry.item)
    default:
      selectedWorkflowFocus = .compare
      wishlistSearchText = entry.item.itemName
    }
  }

  private var wishlistComparisonBriefShortcutPanel: some View {
    let activeItems = store.activeWishlistItems
    let itemsNeedingDraft = activeItems.filter { item in
      !store.draftMessages.contains {
        $0.linkedEntityType == .wishlistItem
          && $0.linkedEntityID == item.id.uuidString
          && $0.subject.localizedCaseInsensitiveContains("wishlist research brief")
      }
    }
    let missingResearch = itemsNeedingDraft.filter { item in
      !store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id && store.isActiveWishlistResearchRequest($0) }
    }.count
    let existingRequests = itemsNeedingDraft.count - missingResearch
    let displayedItems = Swift.Array(itemsNeedingDraft.prefix(6))

    return SettingsPanel(title: "Wishlist comparison brief shortcut", symbol: "doc.text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: itemsNeedingDraft.isEmpty ? "checkmark.circle.fill" : "doc.badge.plus")
            .foregroundStyle(itemsNeedingDraft.isEmpty ? .green : .purple)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(itemsNeedingDraft.isEmpty ? "Comparison brief drafts are staged" : "Prepare local research packets from Wishlist items")
              .font(.headline)
            Text(itemsNeedingDraft.isEmpty
              ? "Every active Wishlist item already has a local research brief draft or no longer needs one."
              : "Use this after manual entry to turn an item into a local comparison brief: Australian and overseas sellers, AUD landed cost, postage, delivery time, seller trust, and direct product links.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(itemsNeedingDraft.isEmpty ? "Clear" : "\(itemsNeedingDraft.count) need draft", color: itemsNeedingDraft.isEmpty ? .green : .purple)
        }

        MetricStrip(items: [
          ("Need draft", "\(itemsNeedingDraft.count)", itemsNeedingDraft.isEmpty ? .green : .purple),
          ("Need request", "\(missingResearch)", missingResearch == 0 ? .green : .orange),
          ("Request ready", "\(existingRequests)", existingRequests == 0 ? .secondary : .blue)
        ])

        Text("Creates or refreshes a local research request, then creates a draft comparison packet. It does not browse websites, compare live prices, convert currency, rate sellers externally, log into retailer accounts, buy, pay, or monitor orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)

        if itemsNeedingDraft.isEmpty {
          MVPEmptyState(
            title: "No Wishlist brief drafts needed",
            detail: "Manual items and captured items already have draft packets ready for future comparison work.",
            symbol: "doc.text.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 340), spacing: 10)], alignment: .leading, spacing: 10) {
            if displayedItems.count > 0 { wishlistComparisonBriefShortcutRow(displayedItems[0]) }
            if displayedItems.count > 1 { wishlistComparisonBriefShortcutRow(displayedItems[1]) }
            if displayedItems.count > 2 { wishlistComparisonBriefShortcutRow(displayedItems[2]) }
            if displayedItems.count > 3 { wishlistComparisonBriefShortcutRow(displayedItems[3]) }
            if displayedItems.count > 4 { wishlistComparisonBriefShortcutRow(displayedItems[4]) }
            if displayedItems.count > 5 { wishlistComparisonBriefShortcutRow(displayedItems[5]) }
          }
        }
      }
    }
  }

  private func wishlistComparisonBriefShortcutRow(_ item: WishlistItem) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(.purple)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text([item.storefront, item.estimatedCost, item.owner].filter { !$0.isPlaceholderValidationValue }.joined(separator: " | "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge(store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id && store.isActiveWishlistResearchRequest($0) } ? "Request ready" : "Needs request", color: .purple)
      }
      Button("Create brief draft", systemImage: "doc.badge.plus") {
        store.createWishlistComparisonBriefDraft(from: item)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func wishlistOperatorControlCard(
    title: String,
    detail: String,
    count: Int,
    color: Color,
    symbol: String,
    buttonTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
        Spacer(minLength: 8)
        Badge("\(count)", color: color)
      }
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button(buttonTitle, systemImage: "arrow.right.circle") {
        action()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .disabled(count == 0 && !["Focus capture", "Focus compare", "Focus buy"].contains(buttonTitle))
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var wishlistClosedItemsPanel: some View {
    SettingsPanel(title: "Closed Wishlist items", symbol: "checkmark.circle.fill") {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Closed items stay in local JSON for audit and linked-order history, but are hidden from the active Wishlist queue unless you show them.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
          Badge("\(closedWishlistItems.count) closed", color: closedWishlistItems.isEmpty ? .secondary : .green)
        }

        if closedWishlistItems.isEmpty {
          MVPEmptyState(
            title: "No locally closed Wishlist items",
            detail: "Use the operations closure checklist once a Wishlist item has a linked order, receiving, storage, custody, label, manual check, manifest, dispatch, and no open tasks.",
            symbol: "checkmark.circle.fill"
          )
        } else {
          ForEach(closedWishlistItems.prefix(6)) { item in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 4) {
                Text(item.itemName)
                  .font(.headline)
                Text("\(item.storefront) • \(item.owner) • \(item.purchaseHandoff?.purchaseStatus ?? item.status)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                Text("Linked order: \(item.purchaseHandoff?.linkedOrderID?.uuidString ?? "none")")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer()
              Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
                store.reopenClosedWishlistItem(item)
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
            .padding(10)
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }

          let remaining = max(closedWishlistItems.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more closed item\(remaining == 1 ? "" : "s") are available by using the Closed status filter.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var wishlistWorkflowFocusPanel: some View {
    let all = store.activeWishlistItems
    let capture = all.filter { WishlistWorkflowFocus.capture.matches(item: $0, in: store) }.count
    let compare = all.filter { WishlistWorkflowFocus.compare.matches(item: $0, in: store) }.count
    let buy = all.filter { WishlistWorkflowFocus.buy.matches(item: $0, in: store) }.count
    let watch = all.filter { WishlistWorkflowFocus.watch.matches(item: $0, in: store) }.count
    let operations = all.filter { WishlistWorkflowFocus.operations.matches(item: $0, in: store) }.count
    let selectedCount = all.filter { selectedWorkflowFocus.matches(item: $0, in: store) }.count

    return SettingsPanel(title: "Workflow focus", symbol: "point.3.connected.trianglepath.dotted") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the daily Wishlist map: capture the item, compare seller options, decide whether to buy, watch for order confirmation, then stage receiving and dispatch records.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("All", "\(all.count)", selectedWorkflowFocus == .all ? .blue : .secondary),
          ("Capture", "\(capture)", capture == 0 ? .secondary : .blue),
          ("Compare", "\(compare)", compare == 0 ? .secondary : .orange),
          ("Buy", "\(buy)", buy == 0 ? .secondary : .purple),
          ("Watch", "\(watch)", watch == 0 ? .secondary : .green),
          ("Ops", "\(operations)", operations == 0 ? .secondary : .teal)
        ])

        Picker("Wishlist workflow focus", selection: $selectedWorkflowFocus) {
          ForEach(WishlistWorkflowFocus.allCases) { focus in
            Text(focus.title).tag(focus)
          }
        }
        .pickerStyle(.segmented)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Badge("\(selectedCount) in \(selectedWorkflowFocus.title)", color: selectedWorkflowFocus == .all ? .blue : selectedWorkflowFocus.color)
          Text(selectedWorkflowFocus.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          if selectedWorkflowFocus != .all {
            Button("Show all", systemImage: "line.3.horizontal.decrease.circle") {
              selectedWorkflowFocus = .all
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }

        Text("This is a view filter only. It does not search retailers, buy anything, log in, store payment details, fetch mail, or modify downstream records.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistOperatorQueueEntries: [WishlistOperatorQueueEntry] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .map(wishlistOperatorQueueEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistOperatorQueuePanel: some View {
    let entries = wishlistOperatorQueueEntries
    let capture = entries.filter { $0.workflow == .capture }.count
    let compare = entries.filter { $0.workflow == .compare }.count
    let buy = entries.filter { $0.workflow == .buy }.count
    let watch = entries.filter { $0.workflow == .watch }.count
    let operations = entries.filter { $0.workflow == .operations }.count

    return SettingsPanel(title: "Wishlist operator queue", symbol: "tray.full.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the primary daily Wishlist queue. It collapses capture, comparison, purchase decision, handoff, and order-watch work into one next-action list.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Capture", "\(capture)", capture == 0 ? .secondary : .blue),
          ("Compare", "\(compare)", compare == 0 ? .secondary : .orange),
          ("Buy", "\(buy)", buy == 0 ? .secondary : .purple),
          ("Watch", "\(watch)", watch == 0 ? .secondary : .green),
          ("Ops", "\(operations)", operations == 0 ? .secondary : .teal)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist work queued",
            detail: "Add a manual item, browser capture placeholder, PDF placeholder, or screenshot placeholder to start local Wishlist tracking.",
            symbol: "tray.full.fill",
            actionTitle: "Add manual item",
            action: openManualWishlistItemForm
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistOperatorQueueRow(entry: entry) {
                runWishlistOperatorQueueAction(for: entry)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: entry.item.id.uuidString,
                  label: entry.item.itemName,
                  summary: "Wishlist follow-up: \(entry.nextAction). \(entry.detail)",
                  priority: entry.sortPriority < 40 ? .high : .normal,
                  assignee: "Wishlist review"
                )
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = entry.workflow
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist queue item\(remaining == 1 ? "" : "s") are available in the detailed panels below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Queue actions are local workflow actions only. ParcelOps does not browse retailers, log in, purchase, pay, fetch live stock, quote postage, or mutate external mailboxes from this queue.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistOperatorQueueEntry(for item: WishlistItem) -> WishlistOperatorQueueEntry {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    } ?? options.first
    let checks = item.purchaseChecks ?? []
    let failedChecks = checks.filter { $0.status != "Passed" }
    let handoff = item.purchaseHandoff
    let isPurchased = handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true
      || item.status.localizedCaseInsensitiveContains("awaiting order")
      || item.status.localizedCaseInsensitiveContains("confirmation")

    let workflow: WishlistWorkflowFocus
    let stage: String
    let detail: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if item.itemName.isPlaceholderValidationValue
      || item.storefront.isPlaceholderValidationValue
      || item.storefrontURL.isPlaceholderValidationValue
      || item.owner.isPlaceholderValidationValue {
      workflow = .capture
      stage = "Capture cleanup"
      detail = "Confirm item, retailer/source, product link, owner, and why it is needed."
      nextAction = "Run readiness"
      nextSymbol = "checklist.checked"
      tone = .blue
      sortPriority = 10
    } else if options.isEmpty {
      workflow = .compare
      stage = "Need comparison"
      detail = "No seller options are recorded. Create a local comparison plan before deciding where to buy."
      nextAction = "Create plan"
      nextSymbol = "magnifyingglass.circle"
      tone = .orange
      sortPriority = 20
    } else if options.contains(where: { !$0.operatorSellerEvidenceGaps.isEmpty }) {
      workflow = .compare
      stage = "Seller evidence gaps"
      detail = "Seller options need product link, AUD total, postage, trust, or returns/warranty cleanup."
      nextAction = "Score options"
      nextSymbol = "chart.bar.doc.horizontal"
      tone = .orange
      sortPriority = 30
    } else if item.preferredOptionID == nil || preferred == nil {
      workflow = .compare
      stage = "Choose seller"
      detail = "Options are recorded. Select a preferred seller before purchase review."
      nextAction = "Score options"
      nextSymbol = "chart.bar.doc.horizontal"
      tone = .purple
      sortPriority = 40
    } else if checks.isEmpty || !failedChecks.isEmpty {
      workflow = .buy
      stage = checks.isEmpty ? "Readiness not run" : "Readiness blocked"
      detail = checks.isEmpty ? "Run local purchase checks before drafting a decision." : "\(failedChecks.count) purchase check\(failedChecks.count == 1 ? "" : "s") need attention."
      nextAction = "Run checks"
      nextSymbol = "checklist.checked"
      tone = .purple
      sortPriority = 50
    } else if item.purchaseDecision == nil {
      workflow = .buy
      stage = "Decision needed"
      detail = "Seller comparison and readiness are ready for a local purchase decision draft."
      nextAction = "Draft decision"
      nextSymbol = "doc.badge.plus"
      tone = .purple
      sortPriority = 60
    } else if item.purchaseDecision?.reviewState != .accepted {
      workflow = .buy
      stage = "Decision review"
      detail = "Purchase decision exists but still needs local operator review."
      nextAction = "Review task"
      nextSymbol = "checklist"
      tone = .brown
      sortPriority = 70
    } else if item.purchaseHandoff == nil {
      workflow = .watch
      stage = "Handoff needed"
      detail = "Prepare account, payment, delivery, and order-watch notes before buying outside ParcelOps."
      nextAction = "Prepare handoff"
      nextSymbol = "person.crop.circle.badge.checkmark"
      tone = .green
      sortPriority = 80
    } else if item.purchaseHandoff?.linkedOrderID == nil && !isPurchased {
      workflow = .watch
      stage = "Ready to purchase"
      detail = "Manual purchase handoff is prepared. Record the external purchase only after buying outside ParcelOps."
      nextAction = "Record purchase"
      nextSymbol = "bag.fill"
      tone = .blue
      sortPriority = 85
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      workflow = .watch
      stage = "Watch confirmation"
      detail = "After external purchase, watch Inbox/Orders for confirmation and link the order."
      nextAction = "Order seen"
      nextSymbol = "envelope.badge.fill"
      tone = .green
      sortPriority = 90
    } else {
      workflow = .operations
      stage = "Operations follow-up"
      detail = "Order is linked. Continue receiving, storage, custody, labels, dispatch, and closure checks."
      nextAction = "Focus item"
      nextSymbol = "scope"
      tone = .teal
      sortPriority = 100
    }

    return WishlistOperatorQueueEntry(
      item: item,
      workflow: workflow,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      sellerSummary: preferred.map { "\($0.sellerName) • \($0.estimatedAUDTotal) • \($0.trustRating)" } ?? item.storefront,
      statusSummary: item.purchaseReadiness ?? item.status,
      handoffSummary: handoff.map { "\($0.sellerName) • \($0.accountLabel)" },
      orderWatchSummary: handoff.map { $0.linkedOrderID == nil ? $0.orderWatchStatus : "Linked order ready" },
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistOperatorQueueAction(for entry: WishlistOperatorQueueEntry) {
    switch entry.stage {
    case "Capture cleanup":
      store.runWishlistPurchaseReadinessCheck(entry.item)
    case "Need comparison":
      store.createWishlistComparisonPlan(entry.item)
      store.createWishlistResearchRequest(from: entry.item)
    case "Seller evidence gaps", "Choose seller":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Readiness not run", "Readiness blocked":
      store.runWishlistPurchaseReadinessCheck(entry.item)
    case "Decision needed":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    case "Handoff needed":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Ready to purchase":
      store.recordWishlistPurchasedExternally(entry.item)
    case "Watch confirmation":
      store.markWishlistOrderConfirmationSeen(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = entry.workflow
    }
  }

  private var wishlistLocalActivityEvents: [AuditEvent] {
    store.auditEvents
      .filter { event in
        let searchable = [
          event.entityLabel,
          event.summary,
          event.beforeDetail ?? "",
          event.afterDetail ?? "",
          event.entityType.rawValue
        ].joined(separator: " ")
        return event.entityType == .wishlistItem
          || searchable.localizedCaseInsensitiveContains("wishlist")
          || searchable.localizedCaseInsensitiveContains("purchase handoff")
          || searchable.localizedCaseInsensitiveContains("purchase decision")
          || searchable.localizedCaseInsensitiveContains("seller option")
          || searchable.localizedCaseInsensitiveContains("order confirmation")
      }
      .prefix(8)
      .map { $0 }
  }

  private var wishlistLocalActivityPanel: some View {
    let events = wishlistLocalActivityEvents
    let purchaseEvents = events.filter { event in
      [event.summary, event.afterDetail ?? ""].joined(separator: " ").localizedCaseInsensitiveContains("purchase")
    }.count
    let orderEvents = events.filter { event in
      [event.summary, event.afterDetail ?? ""].joined(separator: " ").localizedCaseInsensitiveContains("order")
    }.count

    return SettingsPanel(title: "Recent Wishlist activity", symbol: "clock.arrow.circlepath") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Recent local Wishlist actions are shown here so purchase, comparison, handoff, and order-watch changes can be checked without leaving this screen.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Recent", "\(events.count)", events.isEmpty ? .secondary : .blue),
          ("Purchase", "\(purchaseEvents)", purchaseEvents == 0 ? .secondary : .purple),
          ("Order trail", "\(orderEvents)", orderEvents == 0 ? .secondary : .teal)
        ])

        if events.isEmpty {
          MVPEmptyState(
            title: "No recent Wishlist activity",
            detail: "Wishlist creates, edits, comparison plans, purchase checks, handoffs, and order-watch actions will appear here after local actions are taken.",
            symbol: "clock.arrow.circlepath"
          )
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(events) { event in
              WishlistLocalActivityRow(event: event) {
                store.createReviewTask(from: event)
              }
            }
          }
        }

        Text("This is a read-only activity summary except for creating a local follow-up task. It does not contact retailers, fetch mail, access accounts, or change orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistDataQualityPanel: some View {
    let entries = wishlistDataQualityEntries
    let captureGaps = entries.filter { $0.stage == "Capture quality" }.count
    let comparisonGaps = entries.filter { $0.stage == "Comparison quality" }.count
    let purchaseGaps = entries.filter { $0.stage == "Purchase handoff" }.count

    return SettingsPanel(title: "Wishlist data quality", symbol: "checkmark.shield.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Fix weak item, seller, link, cost, comparison, and handoff fields before a Wishlist item becomes an order. Actions here are local checks, tasks, and planning records only.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items with gaps", "\(entries.count)", entries.isEmpty ? .green : .orange),
          ("Capture", "\(captureGaps)", captureGaps == 0 ? .green : .blue),
          ("Compare", "\(comparisonGaps)", comparisonGaps == 0 ? .green : .orange),
          ("Handoff", "\(purchaseGaps)", purchaseGaps == 0 ? .green : .purple)
        ])

        if entries.isEmpty {
          Label("No prominent Wishlist data-quality gaps are currently flagged. Continue with comparison, decision, or order-watch work below.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(6)) { entry in
              WishlistDataQualityRow(entry: entry) {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              } onAction: {
                runWishlistDataQualityAction(for: entry)
              } onTask: {
                runWishlistDataQualityTask(for: entry)
              }
            }
          }

          let remaining = max(entries.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist item\(remaining == 1 ? "" : "s") have quality gaps in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This panel does not verify live seller data, scrape pages, quote postage, log in, store payment details, or purchase items.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistDataQualityIssues(for item: WishlistItem) -> [WishlistDataQualityIssue] {
    let options = item.comparisonOptions ?? []
    var issues: [WishlistDataQualityIssue] = []

    func add(_ title: String, detail: String, symbol: String, color: Color, priority: Int) {
      issues.append(WishlistDataQualityIssue(title: title, detail: detail, symbol: symbol, color: color, priority: priority))
    }

    if item.itemName.isPlaceholderValidationValue || item.itemName.localizedCaseInsensitiveContains("placeholder") {
      add("Item name", detail: "Replace the placeholder item name before comparison or purchase handoff.", symbol: "text.cursor", color: .orange, priority: 10)
    }
    if item.storefront.isPlaceholderValidationValue || item.storefront.localizedCaseInsensitiveContains("placeholder") {
      add("Seller/source", detail: "Confirm the retailer, direct product source, or expected purchase channel.", symbol: "storefront", color: .orange, priority: 12)
    }
    if item.storefrontURL.isPlaceholderValidationValue || !item.storefrontURL.localizedCaseInsensitiveContains("http") {
      add("Product link", detail: "Add a usable product or retailer URL before seller comparison.", symbol: "link", color: .orange, priority: 14)
    }
    if item.estimatedCost.isPlaceholderValidationValue || item.estimatedCost.localizedCaseInsensitiveContains("pending") {
      add("Cost note", detail: "Record an estimated price, AUD total, or cost note before purchase review.", symbol: "dollarsign.circle", color: .orange, priority: 16)
    }
    if item.owner.isPlaceholderValidationValue || item.pool.isPlaceholderValidationValue {
      add("Owner/pool", detail: "Confirm who wants the item and which local pool/team owns follow-up.", symbol: "person.crop.circle", color: .blue, priority: 18)
    }
    if item.capturedDetail.isPlaceholderValidationValue || item.capturedDetail.localizedCaseInsensitiveContains("placeholder") {
      add("Capture detail", detail: "Add the reason, product notes, or source context for the item.", symbol: "doc.text", color: .blue, priority: 20)
    }
    if options.isEmpty {
      add("Seller options", detail: "Create a local comparison plan or manual seller option before choosing where to buy.", symbol: "chart.bar.doc.horizontal", color: .purple, priority: 30)
    } else if item.preferredOptionID == nil {
      add("Preferred seller", detail: "Score or choose the preferred seller option after checking cost, postage, and trust.", symbol: "checkmark.seal", color: .purple, priority: 32)
    }
    if item.purchaseChecks?.isEmpty != false {
      add("Readiness check", detail: "Run the local purchase readiness check before drafting a purchase decision.", symbol: "checklist.checked", color: .brown, priority: 40)
    }
    if !options.isEmpty && item.purchaseDecision == nil {
      add("Purchase decision", detail: "Draft a local purchase decision once options and readiness are clear.", symbol: "doc.text.magnifyingglass", color: .brown, priority: 42)
    } else if item.purchaseDecision?.reviewState != nil && item.purchaseDecision?.reviewState != .accepted {
      add("Decision review", detail: "Review the local purchase decision before handoff.", symbol: "person.badge.clock", color: .brown, priority: 44)
    }
    if item.purchaseDecision?.reviewState == .accepted && item.purchaseHandoff == nil {
      add("Handoff", detail: "Prepare seller/account/order-watch handoff after the decision is accepted.", symbol: "person.crop.circle.badge.checkmark", color: .teal, priority: 50)
    }
    if item.purchaseHandoff != nil && item.purchaseHandoff?.linkedOrderID == nil {
      add("Order link", detail: "Watch for the confirmation email and link the created order once available.", symbol: "envelope.badge.fill", color: .teal, priority: 52)
    }

    return issues
  }

  private func wishlistDataQualityStage(for item: WishlistItem) -> String {
    if item.purchaseHandoff != nil || item.purchaseDecision?.reviewState == .accepted {
      return "Purchase handoff"
    }
    if item.comparisonOptions?.isEmpty == false {
      return "Comparison quality"
    }
    return "Capture quality"
  }

  private func wishlistDataQualityActionTitle(for item: WishlistItem, firstIssue: WishlistDataQualityIssue?) -> String {
    guard let title = firstIssue?.title else { return "Focus" }
    if ["Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail"].contains(title) { return "Readiness" }
    if title == "Seller options" { return "Compare" }
    if title == "Preferred seller" { return "Score" }
    if title == "Readiness check" { return "Readiness" }
    if title == "Purchase decision" { return "Decision" }
    if title == "Decision review" { return "Decision task" }
    if title == "Handoff" { return "Handoff" }
    if title == "Order link" { return "Order seen" }
    return item.operatorPurchaseBlockers.isEmpty ? "Focus" : "Review"
  }

  private func wishlistDataQualityActionSymbol(for item: WishlistItem, firstIssue: WishlistDataQualityIssue?) -> String {
    guard let title = firstIssue?.title else { return "scope" }
    if ["Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail", "Readiness check"].contains(title) { return "checklist.checked" }
    if title == "Seller options" { return "magnifyingglass.circle" }
    if title == "Preferred seller" { return "chart.bar.doc.horizontal" }
    if title == "Purchase decision" { return "doc.text.magnifyingglass" }
    if title == "Decision review" { return "checklist" }
    if title == "Handoff" { return "person.crop.circle.badge.checkmark" }
    if title == "Order link" { return "envelope.badge.fill" }
    return item.operatorPurchaseBlockers.isEmpty ? "scope" : "arrow.right.circle"
  }

  private func runWishlistDataQualityAction(for entry: WishlistDataQualityEntry) {
    guard let firstIssue = entry.issues.first else { return }
    switch firstIssue.title {
    case "Seller options":
      store.createWishlistComparisonPlan(entry.item)
      store.createWishlistResearchRequest(from: entry.item)
    case "Preferred seller":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Readiness check", "Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail":
      store.runWishlistPurchaseReadinessCheck(entry.item)
    case "Purchase decision":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    case "Handoff":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Order link":
      store.markWishlistOrderConfirmationSeen(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private func runWishlistDataQualityTask(for entry: WishlistDataQualityEntry) {
    if entry.issues.contains(where: { $0.title == "Handoff" || $0.title == "Order link" }) {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else if entry.issues.contains(where: { $0.title == "Decision review" || $0.title == "Purchase decision" }) {
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    } else {
      store.createReviewTask(from: entry.item)
    }
  }

  private var wishlistReadinessPanel: some View {
    let activeItems = store.activeWishlistItems
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

  private var wishlistPipelineBoardPanel: some View {
    let items = wishlistPipelineItems
    let capture = items.filter { $0.stage == "Capture" }.count
    let compare = items.filter { $0.stage == "Compare" }.count
    let decide = items.filter { $0.stage == "Decide" }.count
    let handoff = items.filter { $0.stage == "Handoff" }.count
    let orderWatch = items.filter { $0.stage == "Order watch" }.count
    let linked = items.filter { $0.stage == "Linked order" }.count

    return SettingsPanel(title: "Wishlist purchase pipeline", symbol: "rectangle.stack.badge.person.crop.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This board shows the daily operator path from idea capture to seller comparison, purchase decision, handoff, order-confirmation watch, and linked order. It is local workflow tracking only; it does not search retailers, buy items, access accounts, or monitor mail in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Capture", "\(capture)", capture == 0 ? .secondary : .blue),
          ("Compare", "\(compare)", compare == 0 ? .secondary : .orange),
          ("Decide", "\(decide)", decide == 0 ? .secondary : .brown),
          ("Handoff", "\(handoff)", handoff == 0 ? .secondary : .purple),
          ("Order watch", "\(orderWatch)", orderWatch == 0 ? .secondary : .green),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No Wishlist pipeline items",
            detail: "Add a manual item or capture placeholder to start the local Wishlist workflow.",
            symbol: "star.square.fill",
            actionTitle: "Manual item",
            action: openManualWishlistItemForm
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { pipelineItem in
              WishlistPipelineRow(pipelineItem: pipelineItem) {
                runWishlistPipelineAction(for: pipelineItem.item)
              } onFocus: {
                wishlistSearchText = pipelineItem.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist pipeline item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func wishlistPipelineItem(for item: WishlistItem) -> WishlistPipelineItem {
    let options = item.comparisonOptions ?? []
    let blockers = item.operatorPurchaseBlockers
    let linkedOrder = item.purchaseHandoff?.linkedOrderID != nil
    let gate = wishlistPurchaseReleaseGate(for: item)

    if linkedOrder {
      return WishlistPipelineItem(
        item: item,
        stage: "Linked order",
        detail: "A local order is linked. Continue work from Orders, Dispatch, Tasks, and Audit.",
        nextAction: "Focus item",
        symbol: "link.circle.fill",
        tone: .teal,
        sortPriority: 60
      )
    }

    if item.purchaseHandoff != nil {
      let matches = store.suggestedWishlistOrderConfirmations(for: item).count
      return WishlistPipelineItem(
        item: item,
        stage: "Order watch",
        detail: matches > 0 ? "\(matches) imported Inbox confirmation match\(matches == 1 ? "" : "es") need linking." : "Manual purchase handoff is ready; wait for or import the order confirmation.",
        nextAction: matches > 0 ? "Use confirmation" : "Order seen",
        symbol: "envelope.badge.fill",
        tone: matches > 0 ? .green : .orange,
        sortPriority: matches > 0 ? 10 : 50
      )
    }

    if item.purchaseDecision?.reviewState == .accepted {
      return WishlistPipelineItem(
        item: item,
        stage: "Handoff",
        detail: "Purchase decision is accepted. Prepare account, seller, and expected order-confirmation handoff.",
        nextAction: "Prepare handoff",
        symbol: "person.crop.circle.badge.checkmark",
        tone: .purple,
        sortPriority: 20
      )
    }

    if item.purchaseDecision != nil {
      return WishlistPipelineItem(
        item: item,
        stage: "Decide",
        detail: "Purchase decision exists but still needs local review before handoff.",
        nextAction: "Review decision",
        symbol: "checkmark.seal",
        tone: .brown,
        sortPriority: 30
      )
    }

    if !options.isEmpty {
      let firstBlocker = blockers.first ?? gate.detail
      let needsDecision = blockers.contains { $0.localizedCaseInsensitiveContains("decision") }
      return WishlistPipelineItem(
        item: item,
        stage: needsDecision ? "Decide" : "Compare",
        detail: firstBlocker,
        nextAction: gate.actionTitle,
        symbol: needsDecision ? "doc.text.magnifyingglass" : "chart.bar.doc.horizontal",
        tone: needsDecision ? .brown : .orange,
        sortPriority: needsDecision ? 35 : 40
      )
    }

    return WishlistPipelineItem(
      item: item,
      stage: "Capture",
      detail: item.capturedDetail.isPlaceholderValidationValue ? "Confirm item details, seller link, owner, and purchase intent." : "Create seller options or a comparison research request before purchase review.",
      nextAction: "Compare",
      symbol: "square.and.arrow.down.fill",
      tone: .blue,
      sortPriority: 45
    )
  }

  private func runWishlistPipelineAction(for item: WishlistItem) {
    let pipelineItem = wishlistPipelineItem(for: item)
    if pipelineItem.stage == "Capture" {
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    } else if pipelineItem.stage == "Order watch", store.suggestedWishlistOrderConfirmations(for: item).first != nil {
      if let email = store.suggestedWishlistOrderConfirmations(for: item).first {
        store.confirmWishlistOrderFromIntake(item, email: email)
      }
    } else if pipelineItem.stage == "Linked order" {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    } else {
      runWishlistPurchaseReleaseAction(for: item)
    }
  }

  private var wishlistPurchaseBlockerQueuePanel: some View {
    let blockerItems = wishlistPurchaseBlockerQueueItems

    return SettingsPanel(title: "Purchase blocker queue", symbol: "exclamationmark.triangle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue to clear Wishlist purchase blockers without opening every item. Actions are local only and do not buy, scrape, log in, quote postage, or contact retailers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Blocked items", "\(blockerItems.count)", blockerItems.isEmpty ? .green : .orange),
          ("Seller evidence", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("confirm") } }.count)", .orange),
          ("Decision", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("decision") } }.count)", .brown),
          ("Handoff", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("handoff") || $0.localizedCaseInsensitiveContains("link order") } }.count)", .purple)
        ])

        if blockerItems.isEmpty {
          Label("No Wishlist purchase blockers are currently promoted. Use the detailed item rows for normal comparison and capture work.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(blockerItems.prefix(5)) { item in
            WishlistPurchaseBlockerQueueRow(
              item: item,
              actionTitle: wishlistBlockerActionTitle(for: item),
              actionSymbol: wishlistBlockerActionSymbol(for: item)
            ) {
              wishlistSearchText = item.itemName
              selectedSource = nil
              selectedStatus = nil
            } onAction: {
              runWishlistBlockerAction(for: item)
            }
          }

          let remaining = max(blockerItems.count - 5, 0)
          if remaining > 0 {
            Text("\(remaining) more blocked Wishlist item\(remaining == 1 ? "" : "s") are in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func wishlistBlockerActionTitle(for item: WishlistItem) -> String {
    guard let blocker = item.operatorPurchaseBlockers.first else { return "Review" }
    if blocker.localizedCaseInsensitiveContains("add seller") { return "Compare" }
    if blocker.localizedCaseInsensitiveContains("choose preferred") { return "Score" }
    if blocker.localizedCaseInsensitiveContains("confirm") { return "Evidence task" }
    if blocker.localizedCaseInsensitiveContains("readiness") { return "Readiness" }
    if blocker.localizedCaseInsensitiveContains("draft purchase") { return "Decision" }
    if blocker.localizedCaseInsensitiveContains("review purchase") { return "Decision task" }
    if blocker.localizedCaseInsensitiveContains("prepare handoff") { return "Handoff" }
    if blocker.localizedCaseInsensitiveContains("link order") { return "Order seen" }
    return "Review"
  }

  private func wishlistBlockerActionSymbol(for item: WishlistItem) -> String {
    guard let blocker = item.operatorPurchaseBlockers.first else { return "arrow.right.circle" }
    if blocker.localizedCaseInsensitiveContains("add seller") { return "magnifyingglass.circle" }
    if blocker.localizedCaseInsensitiveContains("choose preferred") { return "chart.bar.doc.horizontal" }
    if blocker.localizedCaseInsensitiveContains("confirm") { return "checklist" }
    if blocker.localizedCaseInsensitiveContains("readiness") { return "checklist.checked" }
    if blocker.localizedCaseInsensitiveContains("decision") { return "doc.text.magnifyingglass" }
    if blocker.localizedCaseInsensitiveContains("handoff") { return "person.crop.circle.badge.checkmark" }
    if blocker.localizedCaseInsensitiveContains("link order") { return "envelope.badge.fill" }
    return "arrow.right.circle"
  }

  private func runWishlistBlockerAction(for item: WishlistItem) {
    guard let blocker = item.operatorPurchaseBlockers.first else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
      return
    }

    if blocker.localizedCaseInsensitiveContains("add seller") {
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    } else if blocker.localizedCaseInsensitiveContains("choose preferred") {
      store.evaluateWishlistComparisonOptions(item)
    } else if blocker.localizedCaseInsensitiveContains("confirm") {
      store.createWishlistSellerEvidenceReviewTask(item)
    } else if blocker.localizedCaseInsensitiveContains("readiness") {
      store.runWishlistPurchaseReadinessCheck(item)
    } else if blocker.localizedCaseInsensitiveContains("draft purchase") {
      store.createWishlistPurchaseDecision(item)
    } else if blocker.localizedCaseInsensitiveContains("review purchase") {
      store.createWishlistPurchaseDecisionReviewTask(item)
    } else if blocker.localizedCaseInsensitiveContains("prepare handoff") {
      store.prepareWishlistPurchaseHandoff(item)
    } else if blocker.localizedCaseInsensitiveContains("link order") {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistComparisonPlanningPanel: some View {
    let activeItems = store.activeWishlistItems
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

  private var wishlistAgentReadinessVerdictPanel: some View {
    let summary = store.wishlistAgentReadinessSummary
    let color = wishlistAgentReadinessColor(summary.tone)

    return SettingsPanel(title: "Wishlist agent readiness verdict", symbol: "sparkles.rectangle.stack.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: summary.tone == "success" ? "checkmark.seal.fill" : summary.tone == "warning" ? "exclamationmark.triangle.fill" : "person.text.rectangle.fill")
            .foregroundStyle(color)
            .frame(width: 26)
          VStack(alignment: .leading, spacing: 5) {
            Text(summary.title)
              .font(.headline)
            Text(summary.verdict)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(color)
            Text(summary.detail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(summary.tone.capitalized, color: color)
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        MetricStrip(items: [
          ("Ready briefs", "\(summary.readyBriefCount)", summary.readyBriefCount == 0 ? .secondary : .green),
          ("Scope gaps", "\(summary.scopeGapCount)", summary.scopeGapCount == 0 ? .green : .orange),
          ("Seller gaps", "\(summary.sellerOptionGapCount)", summary.sellerOptionGapCount == 0 ? .green : .orange),
          ("Trust review", "\(summary.trustReviewCount)", summary.trustReviewCount == 0 ? .green : .red),
          ("Order watch", "\(summary.orderWatchGapCount)", summary.orderWatchGapCount == 0 ? .green : .teal),
          ("Closure trail", "\(summary.operationsClosureGapCount)", summary.operationsClosureGapCount == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(summary.items) { item in
            WishlistAgentReadinessVerdictRow(item: item)
          }
        }

        CompactActionRow {
          Button("Record snapshot", systemImage: "camera.metering.center.weighted") {
            store.recordWishlistAgentReadinessSnapshot()
          }
          Button("Create readiness task", systemImage: "checklist") {
            store.createWishlistAgentReadinessReviewTask()
          }
          Button("Create batch brief", systemImage: "doc.badge.plus") {
            store.createWishlistBatchResearchBriefDraft()
          }
          .disabled(store.activeWishlistUnblockedResearchRequestCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit trail", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        Text("Boundary: this verdict is computed from local Wishlist records only. It does not browse websites, compare live prices, convert currencies, quote postage, rate external sellers, open accounts, buy items, pay, or monitor orders in the background.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistAgentReadinessColor(_ tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  private var wishlistSellerOptionReviewPanel: some View {
    let issues = wishlistSellerOptionIssues
    let readyOptions = wishlistReadySellerOptions
    let totalOptions = store.activeWishlistItems.reduce(0) { count, item in
      count + (item.comparisonOptions?.count ?? 0)
    }
    let missingAUD = issues.filter { $0.kind == "AUD total" }.count
    let missingPostage = issues.filter { $0.kind == "Postage" }.count
    let trustReview = issues.filter { $0.kind == "Trust" }.count

    return SettingsPanel(title: "Seller option review", symbol: "storefront.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this to clean up manual seller options before purchase handoff. Each option should have a real product link, total AUD cost, postage cost/time, and explicit seller trust notes before it becomes the preferred purchase route.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(totalOptions)", totalOptions == 0 ? .secondary : .blue),
          ("Missing AUD", "\(missingAUD)", missingAUD == 0 ? .green : .orange),
          ("Postage gaps", "\(missingPostage)", missingPostage == 0 ? .green : .orange),
          ("Trust review", "\(trustReview)", trustReview == 0 ? .green : .red),
          ("Ready-looking", "\(readyOptions.count)", readyOptions.isEmpty ? .secondary : .green)
        ])

        if totalOptions == 0 {
          MVPEmptyState(
            title: "No seller options yet",
            detail: "Add a seller option or create a comparison plan on a Wishlist item before scoring and purchase handoff.",
            symbol: "storefront.fill"
          )
        } else {
          if issues.isEmpty {
            Label("No obvious seller option gaps. Run local scoring and confirm live prices before buying externally.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Needs cleanup")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(Array(issues.prefix(6))) { issue in
                WishlistSellerOptionIssueRow(issue: issue)
              }
              let remaining = max(issues.count - 6, 0)
              if remaining > 0 {
                Text("\(remaining) more seller option issue\(remaining == 1 ? "" : "s") need review.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }

          if !readyOptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Ready-looking local candidates")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(Array(readyOptions.prefix(4))) { candidate in
                WishlistSellerOptionIssueRow(issue: candidate)
              }
            }
          }
        }

        Text("This panel is local guidance only. It does not verify live retailer prices, exchange rates, postage, delivery times, seller reviews, account access, checkout state, or payment readiness.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistCapturedOptionCleanupPanel: some View {
    let entries = wishlistCapturedOptionCleanupEntries
    let highPriorityCount = entries.filter { $0.priorityColor == .red || $0.priorityColor == .orange }.count
    let trustGapCount = entries.filter { $0.gaps.contains("seller trust") }.count

    return SettingsPanel(title: "Captured seller option cleanup", symbol: "puzzlepiece.extension.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Seller options created from staged capture clues need manual cleanup before purchase comparison. Confirm the product link, AUD total, postage, trust evidence, returns, warranty, and availability before making one preferred.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Captured options", "\(entries.count)", entries.isEmpty ? .secondary : .purple),
          ("High priority", "\(highPriorityCount)", highPriorityCount == 0 ? .green : .orange),
          ("Trust gaps", "\(trustGapCount)", trustGapCount == 0 ? .green : .red),
          ("Ready to score", "\(entries.filter { $0.gaps.isEmpty }.count)", entries.contains { $0.gaps.isEmpty } ? .green : .secondary)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No captured seller options need cleanup",
            detail: "When a staged capture becomes a Wishlist item, any carried-over seller option with missing evidence will appear here before purchase comparison.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 330), spacing: 10)], spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistCapturedOptionCleanupRow(entry: entry) {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .all
                showClosedItems = false
              } onTask: {
                store.createWishlistSellerEvidenceReviewTask(entry.item)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more captured seller option\(remaining == 1 ? "" : "s") need cleanup in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This is a local cleanup queue only. ParcelOps does not scrape seller pages, verify live stock, convert exchange rates, calculate postage, inspect reviews, or start checkout.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistCapturedOptionCleanupEntries: [WishlistCapturedOptionCleanupEntry] {
    store.wishlistItems
      .filter(store.isActiveWishlistItem)
      .flatMap { item in
        (item.comparisonOptions ?? []).compactMap { option -> WishlistCapturedOptionCleanupEntry? in
          guard wishlistIsCaptureStagedOption(option) else { return nil }
          let gaps = option.operatorSellerEvidenceGaps
          let score = option.operatorSellerMatrixScore
          let priorityColor: Color
          let priorityLabel: String

          if gaps.contains("seller trust") || gaps.contains("product link") {
            priorityColor = .red
            priorityLabel = "Evidence first"
          } else if gaps.contains("AUD total") || gaps.contains("postage cost") || gaps.contains("postage time") || score < 55 {
            priorityColor = .orange
            priorityLabel = "Cleanup needed"
          } else if gaps.isEmpty {
            priorityColor = .green
            priorityLabel = "Ready to score"
          } else {
            priorityColor = .purple
            priorityLabel = "Captured"
          }

          return WishlistCapturedOptionCleanupEntry(
            item: item,
            option: option,
            gaps: gaps,
            priorityLabel: priorityLabel,
            priorityColor: priorityColor
          )
        }
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private func wishlistIsCaptureStagedOption(_ option: WishlistComparisonOption) -> Bool {
    option.recommendation.localizedCaseInsensitiveContains("captured")
      || option.decisionReason?.localizedCaseInsensitiveContains("capture metadata") == true
      || option.trustNotes.localizedCaseInsensitiveContains("Wishlist staging")
  }

  private var wishlistSellerOptionIssues: [WishlistSellerOptionIssue] {
    store.activeWishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).flatMap { option -> [WishlistSellerOptionIssue] in
        var issues: [WishlistSellerOptionIssue] = []
        let audText = option.estimatedAUDTotal.trimmingCharacters(in: .whitespacesAndNewlines)
        let postageText = "\(option.postageCost) \(option.postageTime)".localizedLowercase
        let trustText = option.trustRating.localizedLowercase

        if audText.isEmpty || audText.localizedCaseInsensitiveContains("pending") || !audText.localizedCaseInsensitiveContains("aud") {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "AUD total",
            title: "AUD total missing",
            detail: "Record total landed AUD cost including item, currency conversion, postage, and likely fees.",
            symbol: "dollarsign.circle.fill",
            color: .orange
          ))
        }

        if postageText.contains("pending") || option.postageCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || option.postageTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "Postage",
            title: "Postage details missing",
            detail: "Add postage cost and estimated delivery time before choosing this seller.",
            symbol: "shippingbox.fill",
            color: .orange
          ))
        }

        if trustText.contains("unknown") || trustText.contains("review") || trustText.contains("needs") {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "Trust",
            title: "Seller trust needs review",
            detail: "Confirm seller reputation, returns, warranty, contact details, and delivery evidence before purchase.",
            symbol: "exclamationmark.shield.fill",
            color: .red
          ))
        }

        return issues
      }
    }
  }

  private var wishlistReadySellerOptions: [WishlistSellerOptionIssue] {
    store.activeWishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).compactMap { option in
        let searchable = [
          option.estimatedAUDTotal,
          option.postageCost,
          option.postageTime,
          option.trustRating,
          option.trustNotes
        ].joined(separator: " ").localizedLowercase
        let hasAUD = searchable.contains("aud") && !searchable.contains("pending aud")
        let hasPostage = !option.postageCost.localizedCaseInsensitiveContains("pending")
          && !option.postageTime.localizedCaseInsensitiveContains("pending")
        let trusted = option.trustRating.localizedCaseInsensitiveContains("trusted")
          || option.trustRating.localizedCaseInsensitiveContains("high")
          || option.trustRating.localizedCaseInsensitiveContains("accepted")
        guard hasAUD && hasPostage && trusted else { return nil }
        return WishlistSellerOptionIssue(
          item: item,
          option: option,
          kind: "Ready",
          title: "Ready-looking seller option",
          detail: "Local fields look complete. Still confirm live price, stock, postage, returns, and account/payment details before buying externally.",
          symbol: "checkmark.seal.fill",
          color: .green
        )
      }
    }
  }

  private var wishlistSellerSafetyRubricEntries: [WishlistSellerSafetyRubricEntry] {
    store.activeWishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).map { option in
        wishlistSellerSafetyRubricEntry(item: item, option: option)
      }
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistSellerSafetyRubricPanel: some View {
    let entries = wishlistSellerSafetyRubricEntries
    let ready = entries.filter { $0.decision == "Acceptable local candidate" }.count
    let caution = entries.filter { $0.decision == "Caution" }.count
    let reject = entries.filter { $0.decision == "Reject or manual review" }.count
    let preferredNeedsReview = entries.filter { $0.isPreferred && $0.decision != "Acceptable local candidate" }.count

    return SettingsPanel(title: "Seller trust and landed-cost rubric", symbol: "shield.lefthalf.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this local rubric before purchase handoff. Cheap sellers are not considered safe until total AUD cost, postage time, returns/warranty, and seller trust evidence are explicit.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Acceptable", "\(ready)", ready == 0 ? .secondary : .green),
          ("Caution", "\(caution)", caution == 0 ? .green : .orange),
          ("Reject/review", "\(reject)", reject == 0 ? .green : .red),
          ("Preferred review", "\(preferredNeedsReview)", preferredNeedsReview == 0 ? .green : .purple)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller options to score",
            detail: "Create a comparison plan or add manual seller options before using the trust and landed-cost rubric.",
            symbol: "shield.lefthalf.filled"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistSellerSafetyRubricRow(entry: entry) {
                runWishlistSellerSafetyAction(for: entry)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller option\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Rubric scoring is local only. ParcelOps does not verify live stock, real-time prices, exchange rates, postage quotes, independent reviews, or seller identity.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistSellerSafetyRubricEntry(item: WishlistItem, option: WishlistComparisonOption) -> WishlistSellerSafetyRubricEntry {
    let gaps = option.operatorSellerEvidenceGaps
    let score = option.operatorSellerMatrixScore
    let trust = option.trustRating.localizedLowercase
    let recommendation = option.recommendation.localizedLowercase
    let hasAUD = option.estimatedAUDTotal.localizedCaseInsensitiveContains("aud")
      && !option.estimatedAUDTotal.localizedCaseInsensitiveContains("pending")
    let hasPostage = !option.postageCost.localizedCaseInsensitiveContains("pending")
      && !option.postageTime.localizedCaseInsensitiveContains("pending")
    let trustLooksGood = trust.contains("trusted")
      || trust.contains("high")
      || trust.contains("accepted")
    let trustLooksWeak = trust.contains("unknown")
      || trust.contains("review")
      || trust.contains("needs")
      || recommendation.contains("avoid")
      || recommendation.contains("reject")
    let isPreferred = item.preferredOptionID == option.id

    let decision: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if gaps.isEmpty && score >= 70 && trustLooksGood && hasAUD && hasPostage {
      decision = "Acceptable local candidate"
      detail = "Local fields are complete enough for manual live verification before purchase."
      tone = .green
      sortPriority = isPreferred ? 20 : 40
    } else if score < 55 || trustLooksWeak || gaps.contains("seller trust") {
      decision = "Reject or manual review"
      detail = "Do not prefer this seller until trust evidence, delivery reliability, and returns/warranty are manually confirmed."
      tone = .red
      sortPriority = isPreferred ? 1 : 10
    } else {
      decision = "Caution"
      detail = gaps.isEmpty ? "Local score is moderate. Reconfirm live price, postage, and seller trust before purchase." : "Missing \(gaps.prefix(3).joined(separator: ", "))."
      tone = .orange
      sortPriority = isPreferred ? 5 : 30
    }

    return WishlistSellerSafetyRubricEntry(
      item: item,
      option: option,
      isPreferred: isPreferred,
      decision: decision,
      detail: detail,
      gaps: gaps,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistSellerSafetyAction(for entry: WishlistSellerSafetyRubricEntry) {
    if entry.gaps.isEmpty && entry.decision == "Acceptable local candidate" {
      store.runWishlistPurchaseReadinessCheck(entry.item)
    } else if entry.gaps.contains("seller trust") || entry.decision == "Reject or manual review" {
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    } else {
      store.evaluateWishlistComparisonOptions(entry.item)
    }
  }

  private var wishlistSellerTrustDiligenceEntries: [WishlistSellerTrustDiligenceEntry] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).map { option in
        wishlistSellerTrustDiligenceEntry(item: item, option: option)
      }
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        if first.option.operatorSellerMatrixScore == second.option.operatorSellerMatrixScore {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.option.operatorSellerMatrixScore < second.option.operatorSellerMatrixScore
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistSellerTrustDiligencePanel: some View {
    let entries = wishlistSellerTrustDiligenceEntries
    let blocked = entries.filter { $0.verdict == "Do not buy yet" }.count
    let needsEvidence = entries.filter { $0.verdict == "Needs evidence" }.count
    let liveCheck = entries.filter { $0.verdict == "Ready for live check" }.count
    let overseas = entries.filter { $0.isOverseas }.count

    return SettingsPanel(title: "Seller trust due diligence", symbol: "person.badge.shield.checkmark.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this checklist before a cheap option becomes the preferred seller. It is intentionally conservative: a seller needs a product link, landed AUD total, postage detail, returns/warranty notes, and explicit trust evidence before purchase.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Do not buy", "\(blocked)", blocked == 0 ? .green : .red),
          ("Needs evidence", "\(needsEvidence)", needsEvidence == 0 ? .green : .orange),
          ("Live-check ready", "\(liveCheck)", liveCheck == 0 ? .secondary : .green),
          ("Overseas", "\(overseas)", overseas == 0 ? .secondary : .purple)
        ])

        CompactActionRow {
          Button("Score all", systemImage: "chart.bar.doc.horizontal") {
            scoreAllWishlistOptions()
          }
          .disabled(entries.isEmpty)
          Button("Focus risks", systemImage: "exclamationmark.shield.fill") {
            wishlistSearchText = ""
            selectedSource = nil
            selectedStatus = nil
          }
          .disabled(blocked + needsEvidence == 0)
        }
        .buttonStyle(.bordered)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No sellers to review",
            detail: "Add seller comparison options to Wishlist items before running seller trust due diligence.",
            symbol: "person.badge.shield.checkmark.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistSellerTrustDiligenceRow(entry: entry) {
                runWishlistSellerTrustDiligenceAction(for: entry)
              } onPrefer: {
                store.markWishlistPreferredOption(entry.item, option: entry.option)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more seller option\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only checklist. ParcelOps does not scrape reviews, validate seller identity, check live ABNs/business registrations, convert currencies, request live postage quotes, or verify delivery probability.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistSellerTrustDiligenceEntry(item: WishlistItem, option: WishlistComparisonOption) -> WishlistSellerTrustDiligenceEntry {
    let gaps = option.operatorSellerEvidenceGaps
    let score = option.operatorSellerMatrixScore
    let trustText = [option.trustRating, option.trustNotes, option.recommendation].joined(separator: " ").localizedLowercase
    let regionText = option.sellerRegion.localizedLowercase
    let isPreferred = item.preferredOptionID == option.id
    let isOverseas = regionText.contains("overseas")
      || regionText.contains("international")
      || regionText.contains("global")
      || (!regionText.isEmpty && !regionText.contains("australia") && !regionText.contains(" au"))
    let hasProductLink = !option.productURL.isPlaceholderValidationValue && option.productURL.localizedCaseInsensitiveContains("http")
    let hasAUDTotal = option.estimatedAUDTotal.localizedCaseInsensitiveContains("aud")
      && !option.estimatedAUDTotal.localizedCaseInsensitiveContains("pending")
    let hasPostage = !option.postageCost.isPlaceholderValidationValue
      && !option.postageTime.isPlaceholderValidationValue
      && !option.postageCost.localizedCaseInsensitiveContains("pending")
      && !option.postageTime.localizedCaseInsensitiveContains("pending")
    let hasReturns = trustText.contains("return") || trustText.contains("warranty")
    let trustLooksGood = trustText.contains("trusted")
      || trustText.contains("high")
      || trustText.contains("accepted")
      || trustText.contains("known")

    var checks: [WishlistSellerTrustDiligenceCheck] = [
      WishlistSellerTrustDiligenceCheck(label: "Product link", status: hasProductLink ? "Recorded" : "Missing", tone: hasProductLink ? .green : .orange),
      WishlistSellerTrustDiligenceCheck(label: "AUD landed total", status: hasAUDTotal ? "Recorded" : "Missing", tone: hasAUDTotal ? .green : .orange),
      WishlistSellerTrustDiligenceCheck(label: "Postage time/cost", status: hasPostage ? "Recorded" : "Missing", tone: hasPostage ? .green : .orange),
      WishlistSellerTrustDiligenceCheck(label: "Returns/warranty", status: hasReturns ? "Recorded" : "Missing", tone: hasReturns ? .green : .orange),
      WishlistSellerTrustDiligenceCheck(label: "Trust evidence", status: trustLooksGood ? "Acceptable" : "Review", tone: trustLooksGood ? .green : .red)
    ]

    if isOverseas {
      checks.append(WishlistSellerTrustDiligenceCheck(label: "Overseas risk", status: "Manual import check", tone: .purple))
    }

    let verdict: String
    let rationale: String
    let tone: Color
    let sortPriority: Int

    if score < 55 || gaps.contains("seller trust") || (!trustLooksGood && isOverseas) {
      verdict = "Do not buy yet"
      rationale = "Seller trust or delivery reliability is not strong enough for purchase handoff."
      tone = .red
      sortPriority = isPreferred ? 0 : 5
    } else if !gaps.isEmpty || !trustLooksGood || !hasReturns {
      verdict = "Needs evidence"
      rationale = "Resolve \(gaps.prefix(3).joined(separator: ", ")) before preferring this seller."
      tone = .orange
      sortPriority = isPreferred ? 10 : 20
    } else {
      verdict = "Ready for live check"
      rationale = "Local trust fields are complete. Reconfirm live stock, price, postage, returns, account, and checkout before buying."
      tone = .green
      sortPriority = isPreferred ? 30 : 40
    }

    return WishlistSellerTrustDiligenceEntry(
      item: item,
      option: option,
      isPreferred: isPreferred,
      isOverseas: isOverseas,
      verdict: verdict,
      rationale: rationale,
      checks: checks,
      gaps: gaps,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistSellerTrustDiligenceAction(for entry: WishlistSellerTrustDiligenceEntry) {
    if entry.verdict == "Do not buy yet" || entry.gaps.contains("seller trust") {
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    } else if entry.verdict == "Needs evidence" {
      store.evaluateWishlistComparisonOptions(entry.item)
    } else {
      store.runWishlistPurchaseReadinessCheck(entry.item)
    }
  }

  private var wishlistSellerTrustEvidenceLedgerPanel: some View {
    let entries = wishlistSellerTrustDiligenceEntries
    let blocked = entries.filter { $0.verdict == "Do not buy yet" }.count
    let missingReturns = entries.filter { entry in
      entry.checks.contains { $0.label == "Returns/warranty" && $0.status == "Missing" }
    }.count
    let missingTrust = entries.filter { entry in
      entry.checks.contains { $0.label == "Trust evidence" && $0.status == "Review" }
    }.count
    let overseasReview = entries.filter(\.isOverseas).count
    let preferredRisk = entries.filter { $0.isPreferred && $0.verdict != "Ready for live check" }.count

    return SettingsPanel(title: "Seller trust evidence ledger", symbol: "shield.checkered") {
      VStack(alignment: .leading, spacing: 12) {
        Text("A compact local ledger of seller trust evidence before purchase. It highlights missing returns/warranty notes, weak trust evidence, overseas review risk, and preferred sellers that still should not be bought from.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Seller options", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red),
          ("Trust gaps", "\(missingTrust)", missingTrust == 0 ? .green : .orange),
          ("Returns gaps", "\(missingReturns)", missingReturns == 0 ? .green : .purple),
          ("Overseas", "\(overseasReview)", overseasReview == 0 ? .secondary : .teal),
          ("Preferred risk", "\(preferredRisk)", preferredRisk == 0 ? .green : .red)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller trust evidence to review",
            detail: "Add seller options first. Trust evidence appears here once sellers have been recorded for Wishlist comparison.",
            symbol: "shield.checkered"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: entry.verdict == "Ready for live check" ? "shield.lefthalf.filled" : "exclamationmark.shield.fill")
                    .foregroundStyle(entry.tone)
                    .frame(width: 24)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(entry.option.sellerName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(entry.item.itemName)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(2)
                  }
                  Spacer(minLength: 8)
                  Badge(entry.verdict, color: entry.tone)
                }

                Text(wishlistSellerTrustEvidenceLedgerDetail(for: entry))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                CompactMetadataGrid(minimumWidth: 125) {
                  Badge(entry.option.trustRating, color: entry.tone)
                  Badge(entry.option.sellerRegion.isEmpty ? "Region missing" : entry.option.sellerRegion, color: entry.isOverseas ? .purple : .blue)
                  Badge(entry.option.postageTime, color: entry.option.postageTime.localizedCaseInsensitiveContains("pending") ? .orange : .teal)
                  Badge(entry.isPreferred ? "Preferred" : "Alternative", color: entry.isPreferred ? .green : .secondary)
                }

                let missing = entry.checks.filter { $0.status == "Missing" || $0.status == "Review" }.map(\.label)
                if !missing.isEmpty {
                  Text("Evidence needed: \(missing.prefix(4).joined(separator: ", ")).")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                CompactActionRow {
                  Button(entry.verdict == "Ready for live check" ? "Readiness" : "Evidence task", systemImage: entry.verdict == "Ready for live check" ? "checklist.checked" : "checklist") {
                    runWishlistSellerTrustDiligenceAction(for: entry)
                  }
                  Button("Score", systemImage: "chart.bar.doc.horizontal") {
                    store.evaluateWishlistComparisonOptions(entry.item)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = entry.item.itemName
                    selectedSource = nil
                    selectedStatus = nil
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(10)
              .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Trust evidence remains manually supplied. ParcelOps does not call review sites, check business registrations, validate seller identity, test checkout, verify delivery probability, or contact sellers.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistSellerTrustEvidenceLedgerDetail(for entry: WishlistSellerTrustDiligenceEntry) -> String {
    if entry.verdict == "Do not buy yet" {
      return "Seller should stay blocked until trust evidence, delivery reliability, returns/warranty, and landed cost are stronger."
    }
    if entry.verdict == "Needs evidence" {
      let missing = entry.checks.filter { $0.status == "Missing" || $0.status == "Review" }.map(\.label)
      return missing.isEmpty
        ? "Seller needs manual evidence cleanup before it becomes a purchase candidate."
        : "Missing or weak evidence: \(missing.prefix(3).joined(separator: ", "))."
    }
    return "Local trust evidence is complete enough for manual live verification. Still check current stock, price, postage, returns, account, and payment externally."
  }

  private var wishlistComparisonMatrixEntries: [WishlistComparisonMatrixEntry] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).map { option in
        WishlistComparisonMatrixEntry(
          item: item,
          option: option,
          isPreferred: item.preferredOptionID == option.id
        )
      }
    }
    .sorted { first, second in
      if first.isPreferred != second.isPreferred {
        return first.isPreferred
      }
      if first.option.operatorSellerMatrixScore == second.option.operatorSellerMatrixScore {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.option.operatorSellerMatrixScore > second.option.operatorSellerMatrixScore
    }
  }

  private var wishlistComparisonMatrixPanel: some View {
    let entries = wishlistComparisonMatrixEntries
    let readyCount = entries.filter { $0.option.operatorSellerEvidenceGaps.isEmpty && $0.option.operatorSellerMatrixScore >= 70 }.count
    let highRiskCount = entries.filter { $0.option.operatorSellerMatrixScore < 55 || $0.option.operatorSellerMatrixRisk.localizedCaseInsensitiveContains("high") }.count
    let gapCount = entries.filter { !$0.option.operatorSellerEvidenceGaps.isEmpty }.count

    return SettingsPanel(title: "Seller comparison matrix", symbol: "tablecells.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Compare manual seller options in one place before purchase handoff. Scores are local guidance only and must be checked against live price, AUD landed cost, postage, delivery time, seller trust, returns, and account readiness before buying.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready-looking", "\(readyCount)", readyCount == 0 ? .secondary : .green),
          ("Evidence gaps", "\(gapCount)", gapCount == 0 ? .green : .orange),
          ("High risk", "\(highRiskCount)", highRiskCount == 0 ? .green : .red)
        ])

        CompactActionRow {
          Button("Score all options", systemImage: "chart.bar.doc.horizontal") {
            scoreAllWishlistOptions()
          }
          .disabled(entries.isEmpty)
          Button("Show gaps", systemImage: "exclamationmark.triangle.fill") {
            wishlistSearchText = ""
            selectedSource = nil
            selectedStatus = nil
          }
          .disabled(gapCount == 0)
        }
        .buttonStyle(.bordered)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller options to compare",
            detail: "Add seller options to Wishlist items before using the comparison matrix. Nothing here performs live retailer search, scraping, currency conversion, or postage lookup.",
            symbol: "tablecells.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 340), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(12)) { entry in
              WishlistComparisonMatrixRow(entry: entry) {
                store.markWishlistPreferredOption(entry.item, option: entry.option)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 12, 0)
          if remaining > 0 {
            Text("\(remaining) more seller option\(remaining == 1 ? "" : "s") are available in the detailed Wishlist item rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Matrix scoring is local only. ParcelOps has not checked stock, current price, exchange rates, postage quote, seller reviews, checkout, payment, or account login.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func scoreAllWishlistOptions() {
    let itemsWithOptions = store.wishlistItems.filter { store.isActiveWishlistItem($0) && !($0.comparisonOptions ?? []).isEmpty }
    for item in itemsWithOptions {
      store.evaluateWishlistComparisonOptions(item)
    }
  }

  private var wishlistLandedCostReviewEntries: [WishlistLandedCostReviewEntry] {
    store.activeWishlistItems.flatMap { item in
      let options = item.comparisonOptions ?? []
      let cheapestID = options
        .compactMap { option -> (UUID, Double)? in
          guard let audValue = wishlistAUDValue(option.estimatedAUDTotal) else { return nil }
          return (option.id, audValue)
        }
        .min { $0.1 < $1.1 }?.0
      let safestID = options
        .max { first, second in
          first.operatorSellerMatrixScore < second.operatorSellerMatrixScore
        }?.id
      let fastestID = options
        .compactMap { option -> (UUID, Int)? in
          guard let days = wishlistPostageDays(option.postageTime) else { return nil }
          return (option.id, days)
        }
        .min { $0.1 < $1.1 }?.0

      return options.map { option in
        wishlistLandedCostReviewEntry(
          item: item,
          option: option,
          isPreferred: item.preferredOptionID == option.id,
          isCheapest: cheapestID == option.id,
          isSafest: safestID == option.id,
          isFastest: fastestID == option.id
        )
      }
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        if first.item.itemName == second.item.itemName {
          return first.option.sellerName.localizedCaseInsensitiveCompare(second.option.sellerName) == .orderedAscending
        }
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistLandedCostReviewPanel: some View {
    let entries = wishlistLandedCostReviewEntries
    let preferred = entries.filter(\.isPreferred).count
    let cheapest = entries.filter(\.isCheapest).count
    let safest = entries.filter(\.isSafest).count
    let blocked = entries.filter { !$0.blockers.isEmpty || $0.tone == .red }.count

    return SettingsPanel(title: "Landed-cost option review", symbol: "dollarsign.arrow.circlepath") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review seller options as purchase candidates, not just rows of data. This highlights cheapest, safest, fastest-looking, preferred, and blocked options using local fields only.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Preferred", "\(preferred)", preferred == 0 ? .secondary : .purple),
          ("Cheapest", "\(cheapest)", cheapest == 0 ? .secondary : .green),
          ("Safest", "\(safest)", safest == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red)
        ])

        CompactActionRow {
          Button("Score all", systemImage: "chart.bar.doc.horizontal") {
            scoreAllWishlistOptions()
          }
          .disabled(entries.isEmpty)
          Button("Show risky", systemImage: "exclamationmark.triangle.fill") {
            wishlistSearchText = ""
            selectedSource = nil
            selectedStatus = nil
          }
          .disabled(blocked == 0)
        }
        .buttonStyle(.bordered)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No landed-cost options to review",
            detail: "Add manual seller options or create a comparison plan before reviewing landed cost, postage, and trust tradeoffs.",
            symbol: "dollarsign.arrow.circlepath"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistLandedCostReviewRow(entry: entry) {
                store.markWishlistPreferredOption(entry.item, option: entry.option)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onEvidenceTask: {
                store.createWishlistSellerEvidenceReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more landed-cost option\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This review does not perform live retailer search, exchange-rate conversion, postage quote lookup, review scraping, account login, checkout, or payment.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistLandedCostReviewEntry(
    item: WishlistItem,
    option: WishlistComparisonOption,
    isPreferred: Bool,
    isCheapest: Bool,
    isSafest: Bool,
    isFastest: Bool
  ) -> WishlistLandedCostReviewEntry {
    var badges: [String] = []
    if isPreferred { badges.append("Preferred") }
    if isCheapest { badges.append("Cheapest") }
    if isSafest { badges.append("Safest") }
    if isFastest { badges.append("Fastest") }

    let gaps = option.operatorSellerEvidenceGaps
    var blockers: [String] = gaps
    if wishlistAUDValue(option.estimatedAUDTotal) == nil {
      blockers.append("AUD total")
    }
    if wishlistPostageDays(option.postageTime) == nil && option.postageTime.localizedCaseInsensitiveContains("pending") {
      blockers.append("postage time")
    }
    if option.trustRating.localizedCaseInsensitiveContains("unknown") || option.trustRating.localizedCaseInsensitiveContains("review") {
      blockers.append("seller trust")
    }

    let tone: Color
    let recommendation: String
    let sortPriority: Int
    if isPreferred && blockers.isEmpty {
      tone = .green
      recommendation = "Preferred option looks locally complete. Reconfirm live stock, price, postage, returns, and account/payment readiness before buying."
      sortPriority = 5
    } else if blockers.contains("seller trust") || option.operatorSellerMatrixScore < 55 {
      tone = .red
      recommendation = "Do not buy from this seller until trust, returns, warranty, and delivery reliability are manually confirmed."
      sortPriority = isPreferred ? 1 : 20
    } else if !blockers.isEmpty {
      tone = .orange
      recommendation = "Fill \(Array(Set(blockers)).prefix(3).joined(separator: ", ")) before this can become a preferred purchase option."
      sortPriority = isPreferred ? 2 : 30
    } else if isCheapest && !isSafest {
      tone = .orange
      recommendation = "Cheapest is not automatically best. Compare trust, postage time, returns, and warranty before preferring it."
      sortPriority = 35
    } else {
      tone = .teal
      recommendation = "Candidate is usable for decision review once live seller details are manually checked."
      sortPriority = isSafest ? 10 : 40
    }

    return WishlistLandedCostReviewEntry(
      item: item,
      option: option,
      badges: badges,
      blockers: Array(Set(blockers)).sorted(),
      recommendation: recommendation,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func wishlistAUDValue(_ value: String) -> Double? {
    let filtered = value.replacingOccurrences(of: ",", with: "")
    let match = filtered.firstMatch(of: /[0-9]+(\.[0-9]+)?/)
    guard let text = match.map({ String($0.output.0) }) else { return nil }
    return Double(text)
  }

  private func wishlistPostageDays(_ value: String) -> Int? {
    let lower = value.localizedLowercase
    if lower.contains("same day") { return 0 }
    if lower.contains("overnight") { return 1 }
    if let match = lower.firstMatch(of: /[0-9]+/) {
      return Int(String(match.output))
    }
    return nil
  }

  private var wishlistPriceWatchSnapshotPanel: some View {
    let snapshots = wishlistPriceWatchSnapshots
    let needsReview = snapshots.filter { $0.reviewState != .accepted }.count
    let missingPostage = snapshots.filter { snapshot in
      let postage = "\(snapshot.postageCost) \(snapshot.postageTime)".localizedLowercase
      return postage.contains("pending") || postage.contains("confirm") || postage.contains("unknown")
    }.count
    let missingTrust = snapshots.filter { snapshot in
      let trust = snapshot.trustSignal.localizedLowercase
      return trust.contains("missing") || trust.contains("unknown") || trust.contains("review") || trust.contains("confirm")
    }.count
    let linkedSnapshots = snapshots.filter { $0.wishlistItemID != nil }.count

    return SettingsPanel(title: "Price/watch snapshots", symbol: "tag.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Record manual observations of seller price, estimated AUD total, postage, availability, and trust over time. These are local snapshots for comparison and purchase review; ParcelOps does not check live retailer pages or run an agent here.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Snapshots", "\(snapshots.count)", snapshots.isEmpty ? .secondary : .blue),
          ("Needs review", "\(needsReview)", needsReview == 0 ? .green : .orange),
          ("Linked items", "\(linkedSnapshots)", linkedSnapshots == 0 ? .secondary : .teal),
          ("Postage gaps", "\(missingPostage)", missingPostage == 0 ? .green : .orange),
          ("Trust gaps", "\(missingTrust)", missingTrust == 0 ? .green : .red)
        ])

        CompactActionRow {
          Button("Snapshot first item", systemImage: "tag.badge.plus") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistPriceSnapshot(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)

          Button("Task for first snapshot", systemImage: "checklist") {
            if let snapshot = snapshots.first {
              store.createWishlistPriceSnapshotReviewTask(snapshot)
            }
          }
          .disabled(snapshots.isEmpty)
        }
        .buttonStyle(.bordered)

        if snapshots.isEmpty {
          MVPEmptyState(
            title: "No price/watch snapshots yet",
            detail: "Create a manual seller option or use Snapshot first item to start recording price, postage, availability, and trust observations before purchase.",
            symbol: "tag.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(snapshots.prefix(10)) { snapshot in
              wishlistPriceWatchSnapshotRow(snapshot)
            }
          }

          let remaining = max(snapshots.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more price/watch snapshot\(remaining == 1 ? "" : "s") are stored locally.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Manual snapshot ledger only. No live price polling, currency lookup, postage quote, seller trust lookup, browser extension sync, account login, checkout, purchase, payment, background job, or notification is active.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPriceWatchSnapshots: [WishlistPriceSnapshot] {
    store.wishlistPriceSnapshots.filter(store.isActiveWishlistPriceSnapshot).sorted { first, second in
      let firstPriority = wishlistPriceSnapshotPriority(first)
      let secondPriority = wishlistPriceSnapshotPriority(second)
      if firstPriority == secondPriority {
        return first.capturedDate > second.capturedDate
      }
      return firstPriority < secondPriority
    }
  }

  private func wishlistPriceSnapshotPriority(_ snapshot: WishlistPriceSnapshot) -> Int {
    if snapshot.reviewState == .needsReview { return 0 }
    if wishlistPriceSnapshotHasGaps(snapshot) { return 1 }
    if snapshot.reviewState == .monitor { return 2 }
    return 3
  }

  private func wishlistPriceSnapshotHasGaps(_ snapshot: WishlistPriceSnapshot) -> Bool {
    let searchable = [
      snapshot.estimatedAUDTotal,
      snapshot.postageCost,
      snapshot.postageTime,
      snapshot.availabilityStatus,
      snapshot.trustSignal
    ]
      .joined(separator: " ")
      .localizedLowercase
    return searchable.contains("pending")
      || searchable.contains("confirm")
      || searchable.contains("unknown")
      || searchable.contains("missing")
      || searchable.contains("review")
  }

  private func wishlistItem(for snapshot: WishlistPriceSnapshot) -> WishlistItem? {
    if let itemID = snapshot.wishlistItemID,
       let item = store.wishlistItems.first(where: { $0.id == itemID }) {
      return item
    }
    return store.wishlistItems.first { item in
      item.itemName.localizedCaseInsensitiveContains(snapshot.itemName)
        || snapshot.itemName.localizedCaseInsensitiveContains(item.itemName)
    }
  }

  @ViewBuilder
  private func wishlistPriceWatchSnapshotRow(_ snapshot: WishlistPriceSnapshot) -> some View {
    let linkedItem = wishlistItem(for: snapshot)
    let hasGaps = wishlistPriceSnapshotHasGaps(snapshot)
    let tone: Color = snapshot.reviewState == .accepted && !hasGaps ? .green : hasGaps ? .orange : .teal

    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "tag.fill")
          .foregroundStyle(tone)
        VStack(alignment: .leading, spacing: 3) {
          Text(snapshot.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(snapshot.sellerName) • \(snapshot.snapshotSource)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge(snapshot.reviewState.rawValue, color: tone)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
        WishlistMatrixMetric(title: "Observed", value: "\(snapshot.observedPrice) \(snapshot.currency)", symbol: "tag.fill")
        WishlistMatrixMetric(title: "AUD total", value: snapshot.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(snapshot.postageCost), \(snapshot.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: snapshot.trustSignal, symbol: "shield.checkered")
      }

      Text(snapshot.availabilityStatus)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      Text(linkedItem == nil ? "Not linked to a current Wishlist item. Keep for reference or remove if it is no longer useful." : "Linked to \(linkedItem?.itemName ?? snapshot.itemName). Reconfirm live details before buying.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(linkedItem == nil ? .orange : .secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        if let linkedItem {
          Button("New snapshot", systemImage: "tag.badge.plus") {
            store.addWishlistPriceSnapshot(linkedItem)
          }
        }
        Button("Reviewed", systemImage: "checkmark.seal") {
          store.markWishlistPriceSnapshotReviewed(snapshot)
        }
        .disabled(snapshot.reviewState == .accepted && !hasGaps)
        Button("Task", systemImage: "checklist") {
          store.createWishlistPriceSnapshotReviewTask(snapshot)
        }
        Button("Focus item", systemImage: "scope") {
          wishlistSearchText = linkedItem?.itemName ?? snapshot.itemName
          selectedSource = nil
          selectedStatus = nil
        }
        Button("Remove", systemImage: "trash") {
          store.removeWishlistPriceSnapshot(snapshot)
        }
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var wishlistPriceWatchDecisionEntries: [WishlistPriceWatchDecisionEntry] {
    store.wishlistItems
      .map(wishlistPriceWatchDecisionEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPriceWatchDecisionBoardPanel: some View {
    let entries = wishlistPriceWatchDecisionEntries
    let ready = entries.filter { $0.stage == "Ready to verify" }.count
    let missingSnapshots = entries.filter { $0.bestSnapshot == nil }.count
    let blocked = entries.filter { $0.stage == "Blocked" }.count
    let review = entries.filter { $0.stage == "Needs review" }.count

    return SettingsPanel(title: "Price/watch decision board", symbol: "chart.line.uptrend.xyaxis") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this board before purchase decisions. It rolls local price/watch snapshots up by Wishlist item so operators can see whether the current best recorded option has AUD total, postage, availability, and seller trust evidence.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready to verify", "\(ready)", ready == 0 ? .secondary : .green),
          ("Needs review", "\(review)", review == 0 ? .green : .orange),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red),
          ("No snapshot", "\(missingSnapshots)", missingSnapshots == 0 ? .green : .purple)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist items to assess",
            detail: "Add a Wishlist item, create a seller option, then capture a local price/watch snapshot before purchase review.",
            symbol: "chart.line.uptrend.xyaxis"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 430), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistPriceWatchDecisionRow(entry: entry) {
                runWishlistPriceWatchDecisionAction(for: entry)
              } onSnapshot: {
                store.addWishlistPriceSnapshot(entry.item)
              } onReview: {
                if let snapshot = entry.bestSnapshot {
                  store.markWishlistPriceSnapshotReviewed(snapshot)
                }
              } onTask: {
                if let snapshot = entry.bestSnapshot {
                  store.createWishlistPriceSnapshotReviewTask(snapshot)
                } else {
                  store.createReviewTask(from: entry.item)
                }
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist item\(remaining == 1 ? "" : "s") have price/watch decision state below the fold.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Decision board is local guidance only. It does not poll prices, convert currency, verify trust ratings, open retailer pages, log in to accounts, buy items, or watch external sites.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPriceWatchDecisionEntry(for item: WishlistItem) -> WishlistPriceWatchDecisionEntry {
    let snapshots = store.wishlistPriceSnapshots(for: item)
    let bestSnapshot = wishlistBestPriceSnapshot(from: snapshots)
    var blockers: [String] = []

    if snapshots.isEmpty {
      blockers.append("price snapshot")
    }
    if let bestSnapshot {
      if wishlistAUDValue(bestSnapshot.estimatedAUDTotal) == nil {
        blockers.append("AUD total")
      }
      if wishlistPostageDays(bestSnapshot.postageTime) == nil || wishlistPriceSnapshotTextNeedsReview(bestSnapshot.postageCost) || wishlistPriceSnapshotTextNeedsReview(bestSnapshot.postageTime) {
        blockers.append("postage")
      }
      if wishlistPriceSnapshotTextNeedsReview(bestSnapshot.trustSignal) {
        blockers.append("seller trust")
      }
      if wishlistPriceSnapshotTextNeedsReview(bestSnapshot.availabilityStatus) {
        blockers.append("availability")
      }
      if bestSnapshot.reviewState != .accepted {
        blockers.append("snapshot review")
      }
    }

    let uniqueBlockers = Array(Set(blockers)).sorted()
    let stage: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if bestSnapshot == nil {
      stage = "No snapshot"
      nextAction = "Add snapshot"
      nextSymbol = "tag.badge.plus"
      tone = .purple
      sortPriority = 0
    } else if uniqueBlockers.contains("seller trust") || uniqueBlockers.contains("AUD total") || uniqueBlockers.contains("postage") {
      stage = "Blocked"
      nextAction = "Create task"
      nextSymbol = "checklist"
      tone = .red
      sortPriority = 1
    } else if !uniqueBlockers.isEmpty {
      stage = "Needs review"
      nextAction = "Mark reviewed"
      nextSymbol = "checkmark.seal"
      tone = .orange
      sortPriority = 2
    } else {
      stage = "Ready to verify"
      nextAction = "Focus item"
      nextSymbol = "scope"
      tone = .green
      sortPriority = 4
    }

    return WishlistPriceWatchDecisionEntry(
      item: item,
      bestSnapshot: bestSnapshot,
      snapshotCount: snapshots.count,
      blockers: uniqueBlockers,
      stage: stage,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func wishlistBestPriceSnapshot(from snapshots: [WishlistPriceSnapshot]) -> WishlistPriceSnapshot? {
    snapshots
      .sorted { first, second in
        let firstAUD = wishlistAUDValue(first.estimatedAUDTotal)
        let secondAUD = wishlistAUDValue(second.estimatedAUDTotal)
        let firstScore = (first.reviewState == .accepted ? 0 : 1000)
          + (wishlistPriceSnapshotHasGaps(first) ? 100 : 0)
          + Int((firstAUD ?? 999_999).rounded())
        let secondScore = (second.reviewState == .accepted ? 0 : 1000)
          + (wishlistPriceSnapshotHasGaps(second) ? 100 : 0)
          + Int((secondAUD ?? 999_999).rounded())
        if firstScore == secondScore {
          return first.capturedDate > second.capturedDate
        }
        return firstScore < secondScore
      }
      .first
  }

  private func wishlistPriceSnapshotTextNeedsReview(_ value: String) -> Bool {
    let lower = value.localizedLowercase
    return lower.isEmpty
      || lower.contains("pending")
      || lower.contains("confirm")
      || lower.contains("unknown")
      || lower.contains("missing")
      || lower.contains("review")
  }

  private func runWishlistPriceWatchDecisionAction(for entry: WishlistPriceWatchDecisionEntry) {
    if entry.bestSnapshot == nil {
      store.addWishlistPriceSnapshot(entry.item)
    } else if entry.stage == "Blocked" {
      if let snapshot = entry.bestSnapshot {
        store.createWishlistPriceSnapshotReviewTask(snapshot)
      }
    } else if entry.stage == "Needs review" {
      if let snapshot = entry.bestSnapshot {
        store.markWishlistPriceSnapshotReviewed(snapshot)
      }
    } else {
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseRecommendationEntries: [WishlistPurchaseRecommendationEntry] {
    store.activeWishlistItems.compactMap(wishlistPurchaseRecommendationEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseRecommendationPanel: some View {
    let entries = wishlistPurchaseRecommendationEntries
    let readyCount = entries.filter { $0.warningLabels.isEmpty }.count
    let cheaperThanRecommendedCount = entries.filter { entry in
      guard let cheapest = entry.cheapestOption else { return false }
      return cheapest.id != entry.recommendedOption.id
    }.count
    let missingPreferredCount = entries.filter { $0.preferredOption == nil }.count
    let evidenceGapCount = entries.filter { !$0.recommendedOption.operatorSellerEvidenceGaps.isEmpty }.count

    return SettingsPanel(title: "Purchase recommendation summary", symbol: "sparkle.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the local operator summary before drafting a purchase decision. It compares manually recorded seller options for safest, cheapest, fastest, and preferred routes without checking live retailer pages.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Locally ready", "\(readyCount)", readyCount == 0 ? .secondary : .green),
          ("Cheaper alt", "\(cheaperThanRecommendedCount)", cheaperThanRecommendedCount == 0 ? .green : .orange),
          ("Need preferred", "\(missingPreferredCount)", missingPreferredCount == 0 ? .green : .purple),
          ("Evidence gaps", "\(evidenceGapCount)", evidenceGapCount == 0 ? .green : .red)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller options to recommend from",
            detail: "Add manual seller options or create a comparison plan. ParcelOps will then summarise safest, cheapest, fastest, and preferred choices locally.",
            symbol: "sparkle.magnifyingglass"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseRecommendationRow(entry: entry) {
                store.markWishlistPreferredOption(entry.item, option: entry.recommendedOption)
              } onPreferCheapest: {
                if let cheapest = entry.cheapestOption {
                  store.markWishlistPreferredOption(entry.item, option: cheapest)
                }
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more recommendation summar\(remaining == 1 ? "y is" : "ies are") available in the detailed Wishlist rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Recommendation summary is advisory only. Confirm live stock, final AUD total, postage, delivery time, seller trust, returns, warranty, account login, checkout, and payment outside ParcelOps before buying.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseRecommendationEntry(for item: WishlistItem) -> WishlistPurchaseRecommendationEntry? {
    let options = item.comparisonOptions ?? []
    guard !options.isEmpty else { return nil }

    let safest = options.max { first, second in
      first.operatorSellerMatrixScore < second.operatorSellerMatrixScore
    } ?? options[0]
    let cheapest = options
      .compactMap { option -> (WishlistComparisonOption, Double)? in
        guard let audValue = wishlistAUDValue(option.estimatedAUDTotal) else { return nil }
        return (option, audValue)
      }
      .min { $0.1 < $1.1 }?.0
    let fastest = options
      .compactMap { option -> (WishlistComparisonOption, Int)? in
        guard let days = wishlistPostageDays(option.postageTime) else { return nil }
        return (option, days)
      }
      .min { $0.1 < $1.1 }?.0
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    }

    let evidenceReadyOptions = options.filter { option in
      option.operatorSellerEvidenceGaps.isEmpty && option.operatorSellerMatrixScore >= 65
    }
    let recommended = evidenceReadyOptions.max { first, second in
      first.operatorSellerMatrixScore < second.operatorSellerMatrixScore
    } ?? safest

    var warnings: [String] = []
    if preferred == nil {
      warnings.append("preferred seller missing")
    } else if preferred?.id != recommended.id {
      warnings.append("preferred differs from safest")
    }
    if let cheapest, cheapest.id != recommended.id {
      warnings.append("cheapest differs from safest")
    }
    if let fastest, fastest.id != recommended.id {
      warnings.append("fastest differs from safest")
    }
    if !recommended.operatorSellerEvidenceGaps.isEmpty {
      warnings.append("recommended has evidence gaps")
    }
    if wishlistAUDValue(recommended.estimatedAUDTotal) == nil {
      warnings.append("AUD total missing")
    }
    if recommended.trustRating.localizedCaseInsensitiveContains("unknown") || recommended.trustRating.localizedCaseInsensitiveContains("review") {
      warnings.append("trust needs review")
    }

    let rationale: String
    let tone: Color
    let sortPriority: Int
    if recommended.operatorSellerEvidenceGaps.isEmpty && warnings.isEmpty {
      rationale = "\(recommended.sellerName) is the strongest local candidate. Still manually confirm live stock, final price, postage, returns, warranty, and checkout before buying."
      tone = .green
      sortPriority = 40
    } else if recommended.operatorSellerMatrixScore < 55 || warnings.contains("trust needs review") {
      rationale = "\(recommended.sellerName) is currently only a provisional candidate. Resolve trust and evidence gaps before purchase handoff."
      tone = .red
      sortPriority = 5
    } else if warnings.contains("cheapest differs from safest") {
      rationale = "\(recommended.sellerName) is safer locally, but a cheaper option exists. Review whether the price saving justifies trust, postage, and warranty risk."
      tone = .orange
      sortPriority = 15
    } else {
      rationale = "\(recommended.sellerName) is the current local recommendation. Complete the highlighted checks before drafting the purchase decision."
      tone = .teal
      sortPriority = 25
    }

    return WishlistPurchaseRecommendationEntry(
      item: item,
      recommendedOption: recommended,
      cheapestOption: cheapest,
      safestOption: safest,
      fastestOption: fastest,
      preferredOption: preferred,
      warningLabels: Array(Set(warnings)).sorted(),
      rationale: rationale,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private var wishlistPurchaseDecisionRiskGateEntries: [WishlistPurchaseRecommendationEntry] {
    wishlistPurchaseRecommendationEntries
      .filter { entry in
        !entry.warningLabels.isEmpty
          || entry.recommendedOption.operatorSellerMatrixScore < 70
          || !entry.recommendedOption.operatorSellerEvidenceGaps.isEmpty
          || entry.preferredOption == nil
          || entry.preferredOption?.id != entry.recommendedOption.id
      }
  }

  private var wishlistPurchaseDecisionRiskGatePanel: some View {
    let entries = wishlistPurchaseDecisionRiskGateEntries
    let blocked = entries.filter { $0.recommendedOption.operatorSellerMatrixScore < 55 || $0.warningLabels.contains("trust needs review") }.count
    let cheaperRisk = entries.filter { $0.warningLabels.contains("cheapest differs from safest") }.count
    let preferredConflict = entries.filter { $0.warningLabels.contains("preferred differs from safest") || $0.warningLabels.contains("preferred seller missing") }.count
    let evidenceGaps = entries.filter { !$0.recommendedOption.operatorSellerEvidenceGaps.isEmpty }.count

    return SettingsPanel(title: "Purchase decision risk gate", symbol: "shield.lefthalf.filled.badge.checkmark") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This gate catches the cases that should not move straight from seller comparison into a purchase decision: cheap-but-risky sellers, missing preferred routes, trust gaps, postage uncertainty, and incomplete AUD landed cost evidence.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Risk items", "\(entries.count)", entries.isEmpty ? .green : .orange),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red),
          ("Cheaper risk", "\(cheaperRisk)", cheaperRisk == 0 ? .green : .orange),
          ("Preferred issue", "\(preferredConflict)", preferredConflict == 0 ? .green : .purple),
          ("Evidence gaps", "\(evidenceGaps)", evidenceGaps == 0 ? .green : .red)
        ])

        if entries.isEmpty {
          Label("No purchase decision risk gates are currently blocking seller recommendations. Continue to shortlist and decision review, then manually confirm live details before buying.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: entry.recommendedOption.operatorSellerMatrixScore < 55 ? "xmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(entry.recommendedOption.operatorSellerMatrixScore < 55 ? .red : .orange)
                    .frame(width: 24)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(entry.item.itemName)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(2)
                    Text(wishlistPurchaseDecisionRiskGateDetail(for: entry))
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 8)
                  VStack(alignment: .trailing, spacing: 6) {
                    Badge("Score \(entry.recommendedOption.operatorSellerMatrixScore)", color: entry.recommendedOption.operatorSellerMatrixScore < 55 ? .red : .orange)
                    Badge(entry.warningLabels.isEmpty ? "Check live" : "\(entry.warningLabels.count) warning\(entry.warningLabels.count == 1 ? "" : "s")", color: entry.warningLabels.isEmpty ? .teal : .orange)
                  }
                }

                CompactMetadataGrid(minimumWidth: 145) {
                  Label(entry.recommendedOption.sellerName, systemImage: "storefront.fill")
                  Label(entry.recommendedOption.estimatedAUDTotal, systemImage: "dollarsign.circle.fill")
                  Label("\(entry.recommendedOption.postageCost) / \(entry.recommendedOption.postageTime)", systemImage: "shippingbox.fill")
                  Label(entry.recommendedOption.trustRating, systemImage: "shield.checkered")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !entry.warningLabels.isEmpty {
                  Text("Warnings: \(entry.warningLabels.joined(separator: ", ")).")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !entry.recommendedOption.operatorSellerEvidenceGaps.isEmpty {
                  Text("Evidence gaps: \(entry.recommendedOption.operatorSellerEvidenceGaps.joined(separator: ", ")).")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                }

                CompactActionRow {
                  Button("Use safest", systemImage: "checkmark.shield.fill") {
                    store.markWishlistPreferredOption(entry.item, option: entry.recommendedOption)
                  }
                  Button("Score", systemImage: "chart.bar.doc.horizontal") {
                    store.evaluateWishlistComparisonOptions(entry.item)
                  }
                  Button("Task", systemImage: "checklist") {
                    store.createWishlistPurchaseDecisionReviewTask(entry.item)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = entry.item.itemName
                    selectedSource = nil
                    selectedStatus = nil
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(entry.recommendedOption.operatorSellerMatrixScore < 55 ? Color.red.opacity(0.08) : Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more risk-gated item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This gate is advisory and local only. It does not verify live price, stock, seller reputation, exchange rates, postage quotes, account access, checkout, payment, or delivery probability.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseDecisionRiskGateDetail(for entry: WishlistPurchaseRecommendationEntry) -> String {
    if entry.recommendedOption.operatorSellerMatrixScore < 55 {
      return "\(entry.recommendedOption.sellerName) is below the local safety threshold. Do not move to purchase decision until trust, postage, returns, and landed cost evidence are improved."
    }
    if entry.warningLabels.contains("trust needs review") {
      return "Seller trust is still unresolved. Confirm reputation, returns, warranty, delivery evidence, and contact details before purchase review."
    }
    if entry.warningLabels.contains("cheapest differs from safest") {
      return "A cheaper option exists, but the safest local recommendation differs. Review whether the saving is worth the trust, postage, warranty, and delivery risk."
    }
    if entry.warningLabels.contains("preferred differs from safest") {
      return "The preferred seller does not match the safest local recommendation. Reconfirm why the preferred route is acceptable."
    }
    if entry.warningLabels.contains("preferred seller missing") {
      return "Choose a preferred seller before drafting the purchase decision."
    }
    if !entry.recommendedOption.operatorSellerEvidenceGaps.isEmpty {
      return "The recommended seller is missing required evidence before purchase decision review."
    }
    return "Reconfirm live stock, final AUD total, postage time, seller trust, returns, warranty, and account readiness before purchase handoff."
  }

  private var wishlistPurchaseShortlistEntries: [WishlistPurchaseShortlistEntry] {
    wishlistPurchaseRecommendationEntries
      .map(wishlistPurchaseShortlistEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseShortlistPanel: some View {
    let entries = wishlistPurchaseShortlistEntries
    let readyCount = entries.filter { $0.stage == "Ready for decision" }.count
    let checkCount = entries.filter { $0.stage == "Needs checks" }.count
    let preferredCount = entries.filter { $0.entry.preferredOption?.id == $0.entry.recommendedOption.id }.count
    let blockedCount = entries.filter { $0.stage == "Blocked" }.count

    return SettingsPanel(title: "Purchase shortlist", symbol: "list.bullet.rectangle.portrait.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the small operator queue for items that have seller options. It separates ready-to-decide items from cheaper-but-riskier, missing-preference, and blocked cases before any external purchase.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Shortlisted", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(readyCount)", readyCount == 0 ? .secondary : .green),
          ("Need checks", "\(checkCount)", checkCount == 0 ? .green : .orange),
          ("Preferred", "\(preferredCount)", preferredCount == 0 ? .secondary : .purple),
          ("Blocked", "\(blockedCount)", blockedCount == 0 ? .green : .red)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist items are ready for the shortlist",
            detail: "Add seller options or run local comparison scoring first. The shortlist appears once ParcelOps has enough local seller data to suggest a purchase route.",
            symbol: "list.bullet.rectangle.portrait.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 255 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { shortlist in
              WishlistPurchaseShortlistRow(shortlist: shortlist) {
                store.runWishlistPurchaseReadinessCheck(shortlist.item)
              } onDecision: {
                store.createWishlistPurchaseDecision(shortlist.item)
              } onPrefer: {
                store.markWishlistPreferredOption(shortlist.item, option: shortlist.entry.recommendedOption)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(shortlist.item)
              } onFocus: {
                wishlistSearchText = shortlist.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more shortlist candidate\(remaining == 1 ? "" : "s") are available in the detailed Wishlist rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Shortlist actions only update local review state, preferred seller, tasks, and decision drafts. They do not open retailer sites, compare live prices, authenticate accounts, buy, pay, or monitor external pages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseShortlistEntry(for entry: WishlistPurchaseRecommendationEntry) -> WishlistPurchaseShortlistEntry {
    let item = entry.item
    let gaps = entry.warningLabels
    let hasReadinessCheck = !(item.purchaseChecks ?? []).isEmpty
    let hasDecision = item.purchaseDecision != nil

    let stage: String
    let nextAction: String
    let nextSymbol: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if entry.recommendedOption.operatorSellerMatrixScore < 55 || gaps.contains("trust needs review") {
      stage = "Blocked"
      nextAction = "Review task"
      nextSymbol = "checklist"
      detail = "Trust, seller evidence, or local score is too weak for purchase decision. Create a task before buying externally."
      tone = .red
      sortPriority = 5
    } else if entry.preferredOption?.id != entry.recommendedOption.id {
      stage = "Set preferred"
      nextAction = "Prefer seller"
      nextSymbol = "checkmark.seal"
      detail = "The safest local recommendation is not the selected preferred seller yet."
      tone = .purple
      sortPriority = 10
    } else if !gaps.isEmpty || !hasReadinessCheck {
      stage = "Needs checks"
      nextAction = "Readiness"
      nextSymbol = "checklist.checked"
      detail = gaps.isEmpty
        ? "Run the local readiness checklist before drafting the purchase decision."
        : "Resolve \(gaps.prefix(3).joined(separator: ", ")) before drafting the purchase decision."
      tone = .orange
      sortPriority = 20
    } else if !hasDecision {
      stage = "Ready for decision"
      nextAction = "Decision"
      nextSymbol = "doc.text.magnifyingglass"
      detail = "Seller route looks locally complete enough to draft a human-reviewed purchase decision."
      tone = .green
      sortPriority = 30
    } else {
      stage = "Decision drafted"
      nextAction = "Focus"
      nextSymbol = "line.3.horizontal.decrease.circle"
      detail = "Purchase decision exists. Continue review, handoff, and order-watch work in the decision panels."
      tone = .teal
      sortPriority = 40
    }

    return WishlistPurchaseShortlistEntry(
      entry: entry,
      stage: stage,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      detail: detail,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private var wishlistPurchasePacketPanel: some View {
    let activeItems = store.activeWishlistItems
    let itemsWithSellerOptions = activeItems.filter { ($0.comparisonOptions ?? []).isEmpty == false }
    let itemsNeedingPacket = itemsWithSellerOptions.filter { item in
      !store.draftMessages.contains {
        $0.linkedEntityType == .wishlistItem
          && $0.linkedEntityID == item.id.uuidString
          && $0.subject.localizedCaseInsensitiveContains("wishlist purchase packet")
      }
    }
    let decisionReady = itemsNeedingPacket.filter { $0.purchaseDecision != nil }.count
    let needingDecision = itemsNeedingPacket.count - decisionReady
    let purchaseLinksReady = itemsNeedingPacket.filter { item in
      store.wishlistPurchaseLinkRecords(for: item).contains { $0.selectedForPurchase || $0.reviewState == .accepted }
    }.count
    let displayedItems = Swift.Array(itemsNeedingPacket.prefix(6))

    return SettingsPanel(title: "Purchase packet shortcut", symbol: "doc.text.fill.viewfinder") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: itemsNeedingPacket.isEmpty ? "checkmark.circle.fill" : "doc.badge.plus")
            .foregroundStyle(itemsNeedingPacket.isEmpty ? .green : .indigo)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(itemsNeedingPacket.isEmpty ? "Purchase packets are ready" : "Create local buy/no-buy packets from shortlisted items")
              .font(.headline)
            Text(itemsNeedingPacket.isEmpty
              ? "Every active Wishlist item with seller options already has a local purchase packet draft."
              : "A packet collects the selected seller, alternatives, AUD total, postage, trust evidence, approvals, purchase links, and order-watch notes into one local draft before any external purchase.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(itemsNeedingPacket.isEmpty ? "Clear" : "\(itemsNeedingPacket.count) need packet", color: itemsNeedingPacket.isEmpty ? .green : .indigo)
        }

        MetricStrip(items: [
          ("Need packet", "\(itemsNeedingPacket.count)", itemsNeedingPacket.isEmpty ? .green : .indigo),
          ("Decision ready", "\(decisionReady)", decisionReady == 0 ? .secondary : .green),
          ("Need decision", "\(needingDecision)", needingDecision == 0 ? .green : .orange),
          ("Links ready", "\(purchaseLinksReady)", purchaseLinksReady == 0 ? .secondary : .purple)
        ])

        Text("This is a local operator packet only. It does not open product links, compare live prices, convert currency, check seller reputation externally, log in, buy, pay, mutate mailboxes, or monitor orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)

        if itemsWithSellerOptions.isEmpty {
          MVPEmptyState(
            title: "No seller options yet",
            detail: "Add seller options, promote seller quotes, or create a comparison plan before building a purchase packet.",
            symbol: "doc.text.fill.viewfinder"
          )
        } else if itemsNeedingPacket.isEmpty {
          MVPEmptyState(
            title: "No purchase packets needed",
            detail: "Purchase packet drafts already exist for active Wishlist items with seller options.",
            symbol: "checkmark.circle.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            if displayedItems.count > 0 { wishlistPurchasePacketShortcutRow(displayedItems[0]) }
            if displayedItems.count > 1 { wishlistPurchasePacketShortcutRow(displayedItems[1]) }
            if displayedItems.count > 2 { wishlistPurchasePacketShortcutRow(displayedItems[2]) }
            if displayedItems.count > 3 { wishlistPurchasePacketShortcutRow(displayedItems[3]) }
            if displayedItems.count > 4 { wishlistPurchasePacketShortcutRow(displayedItems[4]) }
            if displayedItems.count > 5 { wishlistPurchasePacketShortcutRow(displayedItems[5]) }
          }
        }
      }
    }
  }

  private func wishlistPurchasePacketShortcutRow(_ item: WishlistItem) -> some View {
    let sellerOptionCount = item.comparisonOptions?.count ?? 0
    let purchaseLinks = store.wishlistPurchaseLinkRecords(for: item)
    let approvals = store.wishlistPurchaseApprovalRecords(for: item)
    let selectedSeller = item.preferredOptionID.flatMap { preferredID in
      item.comparisonOptions?.first { $0.id == preferredID }
    }?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront

    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "doc.text.fill.viewfinder")
          .foregroundStyle(.indigo)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text("Seller: \(selectedSeller)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.indigo)
            .lineLimit(2)
          Text(item.purchaseReadiness ?? item.operatorPurchaseNextAction)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge(item.purchaseDecision == nil ? "Needs decision" : "Decision staged", color: item.purchaseDecision == nil ? .orange : .green)
      }

      CompactMetadataGrid(minimumWidth: 115) {
        WishlistMatrixMetric(title: "Seller options", value: "\(sellerOptionCount)", symbol: "list.bullet.rectangle")
        WishlistMatrixMetric(title: "Purchase links", value: "\(purchaseLinks.count)", symbol: "link")
        WishlistMatrixMetric(title: "Approvals", value: "\(approvals.count)", symbol: "checkmark.seal")
      }

      Button("Create packet draft", systemImage: "doc.badge.plus") {
        store.createWishlistPurchasePacketDraft(item)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var wishlistPurchaseDecisionRunwayPanel: some View {
    let queueItems = wishlistPurchaseDecisionQueueItems
    let readyToDraft = queueItems.filter { wishlistPurchaseDecisionPriority(for: $0) == 4 }
    let needsReadiness = queueItems.filter { wishlistPurchaseDecisionPriority(for: $0) == 3 }
    let needsSellerWork = queueItems.filter { wishlistPurchaseDecisionPriority(for: $0) <= 2 }
    let drafted = queueItems.filter { $0.purchaseDecision != nil && $0.purchaseDecision?.reviewState != .accepted }
    let acceptedNeedsHandoff = queueItems.filter { $0.purchaseDecision?.reviewState == .accepted && $0.purchaseHandoff == nil }
    let leadingItem = readyToDraft.first ?? needsReadiness.first ?? drafted.first ?? needsSellerWork.first ?? acceptedNeedsHandoff.first

    return SettingsPanel(title: "Purchase decision runway", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: readyToDraft.isEmpty && needsReadiness.isEmpty && needsSellerWork.isEmpty ? "checkmark.seal.fill" : "bag.badge.questionmark.fill")
            .font(.title3)
            .foregroundStyle(readyToDraft.isEmpty && needsReadiness.isEmpty && needsSellerWork.isEmpty ? .green : .brown)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(readyToDraft.isEmpty ? "Purchase decisions need prep or review" : "\(readyToDraft.count) item\(readyToDraft.count == 1 ? "" : "s") ready for decision draft")
              .font(.headline)
            Text(leadingItem.map { "\($0.itemName): \(wishlistPurchaseDecisionStageDetail(for: $0))" } ?? "No active Wishlist item is currently waiting in purchase decision flow.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(readyToDraft.isEmpty ? "\(queueItems.count) in flow" : "\(readyToDraft.count) ready", color: readyToDraft.isEmpty ? .secondary : .green)
        }

        MetricStrip(items: [
          ("Decision flow", "\(queueItems.count)", queueItems.isEmpty ? .secondary : .blue),
          ("Seller prep", "\(needsSellerWork.count)", needsSellerWork.isEmpty ? .green : .orange),
          ("Readiness", "\(needsReadiness.count)", needsReadiness.isEmpty ? .green : .brown),
          ("Ready draft", "\(readyToDraft.count)", readyToDraft.isEmpty ? .secondary : .green),
          ("Draft review", "\(drafted.count)", drafted.isEmpty ? .secondary : .purple),
          ("Handoff", "\(acceptedNeedsHandoff.count)", acceptedNeedsHandoff.isEmpty ? .secondary : .teal)
        ])

        if queueItems.isEmpty {
          MVPEmptyState(
            title: "No purchase decision work yet",
            detail: "Seller options must exist before an item appears in the purchase decision runway.",
            symbol: "bag.badge.questionmark.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 330), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(queueItems.prefix(5)) { item in
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: wishlistPurchaseDecisionActionSymbol(for: item))
                    .foregroundStyle(wishlistPurchaseDecisionStageColor(for: item))
                    .frame(width: 20, height: 20)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(item.itemName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(wishlistPurchaseDecisionStageTitle(for: item))
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(wishlistPurchaseDecisionStageColor(for: item))
                      .lineLimit(2)
                  }
                  Spacer(minLength: 8)
                  Badge(wishlistPurchaseDecisionStageTitle(for: item), color: wishlistPurchaseDecisionStageColor(for: item))
                }

                Text(wishlistPurchaseDecisionStageDetail(for: item))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                CompactActionRow {
                  Button(wishlistPurchaseDecisionActionTitle(for: item), systemImage: wishlistPurchaseDecisionActionSymbol(for: item)) {
                    runWishlistPurchaseDecisionAction(for: item)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = item.itemName
                    selectedWorkflowFocus = .buy
                    selectedSource = nil
                    selectedStatus = nil
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(wishlistPurchaseDecisionStageColor(for: item).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(wishlistPurchaseDecisionStageColor(for: item).opacity(0.16), lineWidth: 1)
              )
            }
          }
        }

        Text("Decision boundary: these actions only update local Wishlist records, checks, tasks, handoffs, and audit history. They do not open seller pages, log into accounts, purchase, pay, mutate mailboxes, or run monitoring.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseDecisionQueueItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        !(item.comparisonOptions ?? []).isEmpty
          || item.purchaseDecision != nil
          || item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("purchase")
      }
      .sorted { first, second in
        let firstPriority = wishlistPurchaseDecisionPriority(for: first)
        let secondPriority = wishlistPurchaseDecisionPriority(for: second)
        if firstPriority == secondPriority {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstPriority < secondPriority
      }
  }

  private var wishlistPurchaseDecisionQueuePanel: some View {
    let queueItems = wishlistPurchaseDecisionQueueItems
    let decisionNeeded = queueItems.filter { $0.purchaseDecision == nil }.count
    let reviewNeeded = queueItems.filter { $0.purchaseDecision?.reviewState == .needsReview }.count
    let handoffNeeded = queueItems.filter { $0.purchaseDecision?.reviewState == .accepted && $0.purchaseHandoff == nil }.count
    let orderWatch = queueItems.filter { $0.purchaseHandoff?.linkedOrderID == nil && $0.purchaseHandoff != nil }.count
    let readinessBatchItems = queueItems.filter { wishlistPurchaseDecisionPriority(for: $0) == 3 }

    return SettingsPanel(title: "Purchase decision queue", symbol: "bag.badge.questionmark.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue after seller options exist. It keeps the local path explicit: score sellers, run readiness, draft/review a purchase decision, prepare handoff, then watch for the order confirmation.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("In queue", "\(queueItems.count)", queueItems.isEmpty ? .secondary : .blue),
          ("Need decision", "\(decisionNeeded)", decisionNeeded == 0 ? .green : .orange),
          ("Need review", "\(reviewNeeded)", reviewNeeded == 0 ? .green : .brown),
          ("Need handoff", "\(handoffNeeded)", handoffNeeded == 0 ? .green : .purple),
          ("Order watch", "\(orderWatch)", orderWatch == 0 ? .secondary : .teal)
        ])

        CompactActionRow {
          Button("Run readiness checks", systemImage: "checklist.checked") {
            store.runWishlistPurchaseReadinessChecksForDecisionQueue()
          }
          .disabled(readinessBatchItems.isEmpty)
          Badge("\(readinessBatchItems.count) need checks", color: readinessBatchItems.isEmpty ? .green : .orange)
        }

        if queueItems.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases are in decision flow",
            detail: "Add seller options to a Wishlist item before purchase readiness, decision, and handoff work appears here.",
            symbol: "bag.badge.questionmark.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(queueItems.prefix(8)) { item in
              WishlistPurchaseDecisionQueueRow(
                item: item,
                stageTitle: wishlistPurchaseDecisionStageTitle(for: item),
                stageDetail: wishlistPurchaseDecisionStageDetail(for: item),
                stageColor: wishlistPurchaseDecisionStageColor(for: item),
                actionTitle: wishlistPurchaseDecisionActionTitle(for: item),
                actionSymbol: wishlistPurchaseDecisionActionSymbol(for: item)
              ) {
                runWishlistPurchaseDecisionAction(for: item)
              } onFocus: {
                wishlistSearchText = item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(queueItems.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist purchase item\(remaining == 1 ? "" : "s") are in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This queue does not buy anything. It only records local review, handoff, account, budget, and order-watch readiness before a human purchases externally.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseDecisionPriority(for item: WishlistItem) -> Int {
    if (item.comparisonOptions ?? []).isEmpty { return 0 }
    if item.preferredOptionID == nil { return 1 }
    if (item.comparisonOptions ?? []).contains(where: { !$0.operatorSellerEvidenceGaps.isEmpty }) { return 2 }
    let checks = item.purchaseChecks ?? []
    if checks.isEmpty || checks.contains(where: { $0.status != "Passed" }) { return 3 }
    if item.purchaseDecision == nil { return 4 }
    if item.purchaseDecision?.reviewState != .accepted { return 5 }
    if item.purchaseHandoff == nil { return 6 }
    if item.purchaseHandoff?.linkedOrderID == nil { return 7 }
    return 8
  }

  private func wishlistPurchaseDecisionStageTitle(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "Seller options needed"
    case 1: return "Preferred seller needed"
    case 2: return "Seller evidence gaps"
    case 3: return "Readiness check needed"
    case 4: return "Purchase decision needed"
    case 5: return "Decision review needed"
    case 6: return "Purchase handoff needed"
    case 7: return "Order confirmation watch"
    default: return "Linked order ready"
    }
  }

  private func wishlistPurchaseDecisionStageDetail(for item: WishlistItem) -> String {
    let preferred = item.preferredOptionID.flatMap { preferredID in
      item.comparisonOptions?.first { $0.id == preferredID }
    }
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0:
      return "Create local seller options or a research brief before comparing purchase routes."
    case 1:
      return "Run local scoring or choose the preferred seller option."
    case 2:
      let gaps = (item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps)
      return "Confirm \(Array(Set(gaps)).prefix(3).joined(separator: ", ")) before buying."
    case 3:
      return "Run the local readiness checklist for \(preferred?.sellerName ?? "the preferred seller")."
    case 4:
      return "Draft the purchase decision with seller, AUD total, postage, trust, and rejected options."
    case 5:
      return "Review and accept the local decision before preparing handoff."
    case 6:
      return "Prepare account/order-watch handoff for \(item.purchaseDecision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront)."
    case 7:
      return "Watch mailbox/order intake for the confirmation, then link the order."
    default:
      return "Order is linked. Continue tracking through Orders, Dispatch, and Tasks."
    }
  }

  private func wishlistPurchaseDecisionStageColor(for item: WishlistItem) -> Color {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0...3: return .orange
    case 4...5: return .brown
    case 6: return .purple
    case 7: return .teal
    default: return .green
    }
  }

  private func wishlistPurchaseDecisionActionTitle(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "Compare"
    case 1: return "Score"
    case 2: return "Evidence task"
    case 3: return "Readiness"
    case 4: return "Decision"
    case 5: return "Review"
    case 6: return "Handoff"
    case 7: return "Order seen"
    default: return "Open item"
    }
  }

  private func wishlistPurchaseDecisionActionSymbol(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "magnifyingglass.circle"
    case 1: return "chart.bar.doc.horizontal"
    case 2: return "checklist"
    case 3: return "checklist.checked"
    case 4: return "doc.text.magnifyingglass"
    case 5: return "checkmark.seal"
    case 6: return "person.crop.circle.badge.checkmark"
    case 7: return "envelope.badge.fill"
    default: return "line.3.horizontal.decrease.circle"
    }
  }

  private func runWishlistPurchaseDecisionAction(for item: WishlistItem) {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0:
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    case 1:
      store.evaluateWishlistComparisonOptions(item)
    case 2:
      store.createWishlistSellerEvidenceReviewTask(item)
    case 3:
      store.runWishlistPurchaseReadinessCheck(item)
    case 4:
      store.createWishlistPurchaseDecision(item)
    case 5:
      store.markWishlistPurchaseDecisionReviewed(item)
    case 6:
      store.prepareWishlistPurchaseHandoff(item)
    case 7:
      store.markWishlistOrderConfirmationSeen(item)
    default:
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseReadinessBlockerSummaries: [WishlistReadinessBlockerSummary] {
    store.wishlistItems
      .compactMap { item -> WishlistReadinessBlockerSummary? in
        let failedChecks = (item.purchaseChecks ?? []).filter { $0.status != "Passed" }
        guard !failedChecks.isEmpty else { return nil }
        let criticalChecks = failedChecks.filter { $0.status == "Blocked" || $0.severity == "High" }
        let preferred = item.preferredOptionID.flatMap { optionID in
          item.comparisonOptions?.first { $0.id == optionID }
        } ?? item.comparisonOptions?.first
        let primaryCheck = criticalChecks.first ?? failedChecks.first
        let category = wishlistReadinessCategory(for: primaryCheck?.title ?? "Readiness")
        let nextAction = wishlistReadinessNextAction(for: primaryCheck?.title ?? "Readiness")

        return WishlistReadinessBlockerSummary(
          item: item,
          preferredSeller: preferred?.sellerName ?? item.storefront,
          category: category,
          nextAction: nextAction,
          failedChecks: failedChecks,
          criticalChecks: criticalChecks,
          detail: primaryCheck?.detail ?? "Review local purchase readiness before buying externally."
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseReadinessBlockerSummaryPanel: some View {
    let summaries = wishlistPurchaseReadinessBlockerSummaries
    let critical = summaries.filter { !$0.criticalChecks.isEmpty }.count
    let sellerTrust = summaries.filter { $0.category == "Seller trust" }.count
    let postage = summaries.filter { $0.category == "Postage" }.count
    let landedCost = summaries.filter { $0.category == "AUD landed cost" }.count

    return SettingsPanel(title: "Readiness blockers", symbol: "checklist.unchecked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this summary after running purchase readiness checks. It groups the local blockers that must be cleared before a human buys externally.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Blocked items", "\(summaries.count)", summaries.isEmpty ? .green : .orange),
          ("Critical", "\(critical)", critical == 0 ? .green : .red),
          ("Seller trust", "\(sellerTrust)", sellerTrust == 0 ? .green : .orange),
          ("Postage", "\(postage)", postage == 0 ? .green : .teal),
          ("AUD cost", "\(landedCost)", landedCost == 0 ? .green : .brown)
        ])

        if summaries.isEmpty {
          MVPEmptyState(
            title: "No readiness blockers",
            detail: "Run purchase readiness checks from the decision queue. Items with failed seller trust, postage, landed cost, source, or owner checks will appear here.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(summaries.prefix(8)) { summary in
              WishlistReadinessBlockerSummaryRow(summary: summary) {
                store.runWishlistPurchaseReadinessCheck(summary.item)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(summary.item)
              } onFocus: {
                wishlistSearchText = summary.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(summaries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more readiness-blocked Wishlist item\(remaining == 1 ? "" : "s") are in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This panel is local guidance only. It does not verify live seller stock, price, postage, account access, checkout, payment, or delivery status.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistReadinessCategory(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("trust") { return "Seller trust" }
    if title.localizedCaseInsensitiveContains("postage") || title.localizedCaseInsensitiveContains("delivery") { return "Postage" }
    if title.localizedCaseInsensitiveContains("aud") || title.localizedCaseInsensitiveContains("cost") { return "AUD landed cost" }
    if title.localizedCaseInsensitiveContains("seller") { return "Seller selection" }
    if title.localizedCaseInsensitiveContains("owner") || title.localizedCaseInsensitiveContains("account") { return "Owner/account" }
    if title.localizedCaseInsensitiveContains("source") || title.localizedCaseInsensitiveContains("item") { return "Item/source" }
    return "Readiness"
  }

  private func wishlistReadinessNextAction(for title: String) -> String {
    if title.localizedCaseInsensitiveContains("trust") { return "Confirm seller trust" }
    if title.localizedCaseInsensitiveContains("postage") || title.localizedCaseInsensitiveContains("delivery") { return "Confirm postage" }
    if title.localizedCaseInsensitiveContains("aud") || title.localizedCaseInsensitiveContains("cost") { return "Confirm AUD total" }
    if title.localizedCaseInsensitiveContains("seller") { return "Choose seller" }
    if title.localizedCaseInsensitiveContains("owner") || title.localizedCaseInsensitiveContains("account") { return "Confirm owner/account" }
    if title.localizedCaseInsensitiveContains("source") || title.localizedCaseInsensitiveContains("item") { return "Confirm item/source" }
    return "Review readiness"
  }

  private var wishlistExternalPurchaseSafetyGatePanel: some View {
    let summaries = wishlistPurchaseDecisionSummaries
    let blocked = summaries.filter { !$0.verificationGaps.isEmpty || $0.item.purchaseDecision?.reviewState != .accepted }
    let handoffMissing = summaries.filter { $0.item.purchaseDecision?.reviewState == .accepted && $0.item.purchaseHandoff == nil }
    let orderWatchMissing = summaries.filter { $0.item.purchaseHandoff != nil && $0.item.purchaseHandoff?.linkedOrderID == nil }
    let ready = summaries.filter { wishlistExternalPurchaseSafetyStatus(for: $0).label == "Ready to buy externally" }

    return SettingsPanel(title: "External purchase safety gate", symbol: "lock.shield.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the last local gate before a human buys on a retailer site. It keeps cheap-but-risky options, missing AUD totals, unclear postage, weak seller trust, and missing account/order-watch handoff out of the purchase path.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("In gate", "\(summaries.count)", summaries.isEmpty ? .secondary : .blue),
          ("Blocked", "\(blocked.count)", blocked.isEmpty ? .green : .orange),
          ("Need handoff", "\(handoffMissing.count)", handoffMissing.isEmpty ? .green : .purple),
          ("Order watch", "\(orderWatchMissing.count)", orderWatchMissing.isEmpty ? .secondary : .teal),
          ("Ready", "\(ready.count)", ready.isEmpty ? .secondary : .green)
        ])

        if summaries.isEmpty {
          MVPEmptyState(
            title: "No seller route is near purchase",
            detail: "Add seller options, score them, and create a purchase decision before the external purchase gate becomes active.",
            symbol: "lock.shield.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(summaries.prefix(8)) { summary in
              let safety = wishlistExternalPurchaseSafetyStatus(for: summary)
              VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: safety.symbol)
                    .foregroundStyle(safety.color)
                    .frame(width: 24)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(summary.item.itemName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(summary.selectedSeller)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                  Spacer(minLength: 8)
                  Badge(safety.label, color: safety.color)
                }

                Text(safety.detail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                CompactMetadataGrid(minimumWidth: 125) {
                  Badge(summary.totalAUD, color: wishlistPurchaseDecisionValueNeedsReview(summary.totalAUD) ? .orange : .green)
                  Badge(summary.postage, color: wishlistPurchaseDecisionValueNeedsReview(summary.postage) ? .orange : .teal)
                  Badge(summary.trust, color: wishlistPurchaseDecisionValueNeedsReview(summary.trust) ? .orange : .purple)
                  Badge(summary.item.purchaseHandoff == nil ? "No handoff" : "Handoff ready", color: summary.item.purchaseHandoff == nil ? .orange : .green)
                }

                if !summary.verificationGaps.isEmpty {
                  Text("Blockers: \(summary.verificationGaps.prefix(4).joined(separator: ", "))\(summary.verificationGaps.count > 4 ? "..." : "").")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                CompactActionRow {
                  Button(safety.actionTitle, systemImage: safety.actionSymbol) {
                    wishlistRunExternalPurchaseSafetyAction(for: summary)
                  }
                  Button("Task", systemImage: "checklist") {
                    store.createWishlistPurchaseDecisionReviewTask(summary.item)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = summary.item.itemName
                    selectedSource = nil
                    selectedStatus = nil
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(10)
              .background(safety.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Safety boundary: this gate does not open retailer pages, log into accounts, check stock, compare live prices, pay, buy, store payment data, or mutate mailbox/order data. It records only local readiness for a human external purchase.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistExternalPurchaseSafetyStatus(for summary: WishlistPurchaseDecisionSummary) -> (label: String, detail: String, color: Color, symbol: String, actionTitle: String, actionSymbol: String) {
    if summary.item.purchaseDecision == nil {
      return (
        "Decision missing",
        "Draft the local purchase decision before any external checkout. Include seller, AUD total, postage, trust, and rejected alternatives.",
        .brown,
        "doc.text.magnifyingglass",
        "Draft decision",
        "doc.text.magnifyingglass"
      )
    }
    if summary.item.purchaseDecision?.reviewState != .accepted {
      return (
        "Review required",
        "Decision exists but has not been accepted. Review the seller route and verification gaps before buying externally.",
        .orange,
        "checkmark.seal",
        "Accept decision",
        "checkmark.seal"
      )
    }
    if !summary.verificationGaps.isEmpty {
      return (
        "Blocked",
        "Resolve local blockers before purchase: \(summary.verificationGaps.prefix(3).joined(separator: ", ")).",
        .red,
        "exclamationmark.triangle.fill",
        "Create task",
        "checklist"
      )
    }
    if summary.item.purchaseHandoff == nil {
      return (
        "Handoff missing",
        "Prepare account, order-watch, budget, and expected confirmation signals before buying externally.",
        .purple,
        "person.crop.circle.badge.checkmark",
        "Prepare handoff",
        "person.crop.circle.badge.checkmark"
      )
    }
    if summary.item.purchaseHandoff?.linkedOrderID == nil {
      return (
        "Ready to buy externally",
        "Local gate is clear. After the human purchase, watch Inbox/Orders for confirmation and link the order back to this Wishlist item.",
        .green,
        "lock.open.fill",
        "Order seen",
        "envelope.badge.fill"
      )
    }
    return (
      "Order linked",
      "Purchase trail is linked to an order. Continue operational follow-up through Orders, Dispatch, Tasks, and Audit.",
      .teal,
      "link.circle.fill",
      "Focus item",
      "scope"
    )
  }

  private func wishlistRunExternalPurchaseSafetyAction(for summary: WishlistPurchaseDecisionSummary) {
    if summary.item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(summary.item)
    } else if summary.item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(summary.item)
    } else if !summary.verificationGaps.isEmpty {
      store.createWishlistPurchaseDecisionReviewTask(summary.item)
    } else if summary.item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(summary.item)
    } else if summary.item.purchaseHandoff?.linkedOrderID == nil {
      store.markWishlistOrderConfirmationSeen(summary.item)
    } else {
      wishlistSearchText = summary.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseDecisionSummaries: [WishlistPurchaseDecisionSummary] {
    wishlistPurchaseDecisionQueueItems
      .map(wishlistPurchaseDecisionSummary(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseDecisionSummaryPanel: some View {
    let summaries = wishlistPurchaseDecisionSummaries
    let draftedCount = summaries.filter { $0.item.purchaseDecision != nil }.count
    let acceptedCount = summaries.filter { $0.item.purchaseDecision?.reviewState == .accepted }.count
    let missingVerificationCount = summaries.filter { !$0.verificationGaps.isEmpty }.count
    let handoffReadyCount = summaries.filter { $0.item.purchaseHandoff != nil }.count

    return SettingsPanel(title: "Purchase decision summary", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review the selected seller and the manual verification still required before buying. ParcelOps records the decision, evidence, and handoff path only; it does not check live retailer data or purchase anything.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Summaries", "\(summaries.count)", summaries.isEmpty ? .secondary : .blue),
          ("Drafted", "\(draftedCount)", draftedCount == 0 ? .secondary : .brown),
          ("Accepted", "\(acceptedCount)", acceptedCount == 0 ? .secondary : .green),
          ("Need checks", "\(missingVerificationCount)", missingVerificationCount == 0 ? .green : .orange),
          ("Handoff ready", "\(handoffReadyCount)", handoffReadyCount == 0 ? .secondary : .purple)
        ])

        if summaries.isEmpty {
          MVPEmptyState(
            title: "No purchase decisions to summarise",
            detail: "Create seller options first. The decision summary appears once a Wishlist item enters comparison, purchase decision, or handoff flow.",
            symbol: "checkmark.seal.text.page.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(summaries.prefix(8)) { summary in
              WishlistPurchaseDecisionSummaryRow(summary: summary) {
                runWishlistPurchaseDecisionSummaryAction(for: summary.item)
              } onReviewTask: {
                store.createWishlistPurchaseDecisionReviewTask(summary.item)
              } onNeedsReview: {
                store.markWishlistPurchaseDecisionNeedsReview(summary.item)
              } onFocus: {
                wishlistSearchText = summary.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(summaries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase decision summar\(remaining == 1 ? "y is" : "ies are") available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Required before buying: confirm live stock and price, AUD landed cost, postage cost/time, seller trust, account access, payment method, delivery address, returns, and warranty outside ParcelOps.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseDecisionSummary(for item: WishlistItem) -> WishlistPurchaseDecisionSummary {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    } ?? options.first
    let decision = item.purchaseDecision
    let seller = decision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront
    let total = decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost
    let postage = decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not recorded"
    let trust = decision?.trustSummary ?? preferred.map { "\($0.trustRating): \($0.trustNotes)" } ?? "Seller trust not assessed"
    let rejected = decision?.rejectedOptionsSummary ?? rejectedWishlistSellerSummary(for: item, selectedOption: preferred)
    let gaps = wishlistPurchaseDecisionVerificationGaps(item: item, preferred: preferred)

    let stage: String
    let detail: String
    let color: Color
    let actionTitle: String
    let actionSymbol: String
    let sortPriority: Int

    if decision == nil {
      stage = "Decision needed"
      detail = preferred == nil
        ? "Choose or add a seller option before drafting the purchase decision."
        : "Draft a local decision for \(seller), then review live price, stock, postage, trust, account, and payment readiness."
      color = .brown
      actionTitle = "Draft decision"
      actionSymbol = "doc.text.magnifyingglass"
      sortPriority = preferred == nil ? 0 : 10
    } else if decision?.reviewState != .accepted {
      stage = "Review decision"
      detail = "Decision exists but still needs operator review before purchase handoff."
      color = .orange
      actionTitle = "Accept decision"
      actionSymbol = "checkmark.seal"
      sortPriority = 20
    } else if item.purchaseHandoff == nil {
      stage = "Prepare handoff"
      detail = "Decision is accepted. Prepare account and order-watch handoff before buying externally."
      color = .purple
      actionTitle = "Prepare handoff"
      actionSymbol = "person.crop.circle.badge.checkmark"
      sortPriority = 30
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      stage = "Watch for order"
      detail = "Handoff is ready. After purchase, watch Inbox and Orders for confirmation and link the order."
      color = .teal
      actionTitle = "Order seen"
      actionSymbol = "envelope.badge.fill"
      sortPriority = 40
    } else {
      stage = "Linked order"
      detail = "Decision and handoff are linked to an order. Continue through Orders, Dispatch, and Tasks."
      color = .green
      actionTitle = "Focus item"
      actionSymbol = "line.3.horizontal.decrease.circle"
      sortPriority = 50
    }

    return WishlistPurchaseDecisionSummary(
      item: item,
      selectedSeller: seller,
      totalAUD: total,
      postage: postage,
      trust: trust,
      rejectedOptions: rejected,
      verificationGaps: gaps,
      stage: stage,
      detail: detail,
      color: color,
      actionTitle: actionTitle,
      actionSymbol: actionSymbol,
      sortPriority: sortPriority
    )
  }

  private func rejectedWishlistSellerSummary(for item: WishlistItem, selectedOption: WishlistComparisonOption?) -> String {
    let rejected = (item.comparisonOptions ?? [])
      .filter { $0.id != selectedOption?.id }
      .map { "\($0.sellerName): \($0.estimatedAUDTotal), trust \($0.trustRating)" }
    return rejected.isEmpty ? "No alternate seller options recorded." : rejected.joined(separator: " | ")
  }

  private func wishlistPurchaseDecisionVerificationGaps(item: WishlistItem, preferred: WishlistComparisonOption?) -> [String] {
    var gaps: [String] = []
    let decision = item.purchaseDecision

    if preferred == nil {
      gaps.append("seller option")
    }
    if item.preferredOptionID == nil {
      gaps.append("preferred seller")
    }
    if item.purchaseReadiness?.localizedCaseInsensitiveContains("ready") != true {
      gaps.append("readiness check")
    }
    if decision == nil {
      gaps.append("decision draft")
    } else if decision?.reviewState != .accepted {
      gaps.append("decision review")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal) {
      gaps.append("AUD landed cost")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.postageSummary ?? preferred?.postageCost) {
      gaps.append("postage cost/time")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.trustSummary ?? preferred?.trustRating) {
      gaps.append("seller trust")
    }
    if !(preferred?.operatorSellerEvidenceGaps.isEmpty ?? true) {
      gaps.append(contentsOf: preferred?.operatorSellerEvidenceGaps ?? [])
    }
    if item.purchaseHandoff == nil {
      gaps.append("account/order-watch handoff")
    }

    return Array(Set(gaps)).sorted()
  }

  private func wishlistPurchaseDecisionValueNeedsReview(_ value: String?) -> Bool {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty { return true }
    let lower = trimmed.localizedLowercase
    return lower.contains("pending")
      || lower.contains("unknown")
      || lower.contains("not recorded")
      || lower.contains("not assessed")
      || lower.contains("to confirm")
      || lower.contains("review")
      || lower.contains("no seller")
  }

  private func runWishlistPurchaseDecisionSummaryAction(for item: WishlistItem) {
    if item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(item)
    } else if item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(item)
    } else if item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(item)
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistManualPurchaseHandoffReadinessEntries: [WishlistManualPurchaseHandoffReadinessEntry] {
    wishlistPurchaseDecisionQueueItems
      .compactMap { item -> WishlistManualPurchaseHandoffReadinessEntry? in
        let links = store.wishlistPurchaseLinkRecords(for: item)
        let approvals = store.wishlistPurchaseApprovalRecords(for: item)
        let accounts = store.wishlistPurchaseAccountRecords(for: item)
        let selectedLink = links.first { $0.selectedForPurchase } ?? links.first { $0.reviewState == .accepted } ?? links.first
        let approval = approvals.first { $0.reviewState == .accepted || $0.approvalStatus.localizedCaseInsensitiveContains("approved") } ?? approvals.first
        let account = accounts.first { $0.reviewState == .accepted } ?? accounts.first
        let decision = item.purchaseDecision
        let handoff = item.purchaseHandoff
        let linkReady = selectedLink?.reviewState == .accepted || selectedLink?.readinessStatus.localizedCaseInsensitiveContains("ready") == true
        let approvalReady = approval?.reviewState == .accepted || approval?.approvalStatus.localizedCaseInsensitiveContains("approved") == true
        let accountReady = account?.reviewState == .accepted
        let decisionReady = decision?.reviewState == .accepted

        let stage: String
        let detail: String
        let actionTitle: String
        let actionSymbol: String
        let tone: Color
        let sortPriority: Int

        if decision == nil {
          stage = "Decision missing"
          detail = "Draft a local purchase decision before preparing account, link, approval, and order-watch handoff."
          actionTitle = "Draft decision"
          actionSymbol = "doc.text.magnifyingglass"
          tone = .brown
          sortPriority = 10
        } else if !decisionReady {
          stage = "Decision review"
          detail = "Accept or reopen the purchase decision locally before moving toward manual buying."
          actionTitle = "Review decision"
          actionSymbol = "checkmark.seal"
          tone = .orange
          sortPriority = 20
        } else if selectedLink == nil {
          stage = "Purchase link missing"
          detail = "Add the product or retailer link the human should open outside ParcelOps."
          actionTitle = "Add link"
          actionSymbol = "link.badge.plus"
          tone = .purple
          sortPriority = 30
        } else if !linkReady {
          stage = "Link review"
          detail = "Selected link still needs local readiness review for seller, AUD total, postage, and trust."
          actionTitle = "Link task"
          actionSymbol = "checklist"
          tone = .purple
          sortPriority = 40
        } else if approval == nil {
          stage = "Approval missing"
          detail = "Add a local approval and budget record before manual purchase."
          actionTitle = "Add approval"
          actionSymbol = "checkmark.seal"
          tone = .indigo
          sortPriority = 50
        } else if !approvalReady {
          stage = "Approval review"
          detail = "Approval exists but is not accepted locally. Confirm approver, limit, budget, and payment method outside ParcelOps."
          actionTitle = "Approval task"
          actionSymbol = "checklist"
          tone = .indigo
          sortPriority = 60
        } else if account == nil {
          stage = "Account missing"
          detail = "Add non-secret account readiness: account label, delivery status, and expected order email signals."
          actionTitle = "Add account"
          actionSymbol = "person.badge.plus"
          tone = .teal
          sortPriority = 70
        } else if !accountReady {
          stage = "Account review"
          detail = "Account readiness is not accepted locally. Confirm access, payment readiness, and delivery details outside ParcelOps."
          actionTitle = "Account task"
          actionSymbol = "checklist"
          tone = .teal
          sortPriority = 80
        } else if handoff == nil {
          stage = "Handoff missing"
          detail = "Prepare the local handoff so Inbox and Orders know what confirmation to watch for after a human buys externally."
          actionTitle = "Prepare handoff"
          actionSymbol = "person.crop.circle.badge.checkmark"
          tone = .orange
          sortPriority = 90
        } else if handoff?.linkedOrderID == nil {
          stage = "Ready for manual purchase"
          detail = "Local readiness is assembled. After a human buys externally, watch Inbox for the confirmation and link the order."
          actionTitle = "Order seen"
          actionSymbol = "envelope.badge.fill"
          tone = .green
          sortPriority = 100
        } else {
          stage = "Order linked"
          detail = "Manual purchase trail is linked to an order. Continue in Orders, Dispatch, Tasks, and Audit."
          actionTitle = "Focus"
          actionSymbol = "scope"
          tone = .green
          sortPriority = 110
        }

        return WishlistManualPurchaseHandoffReadinessEntry(
          item: item,
          decision: decision,
          selectedLink: selectedLink,
          approval: approval,
          account: account,
          handoff: handoff,
          stage: stage,
          detail: detail,
          actionTitle: actionTitle,
          actionSymbol: actionSymbol,
          tone: tone,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistManualPurchaseHandoffReadinessPanel: some View {
    let entries = wishlistManualPurchaseHandoffReadinessEntries
    let linkGaps = entries.filter { $0.stage == "Purchase link missing" || $0.stage == "Link review" }.count
    let approvalGaps = entries.filter { $0.stage == "Approval missing" || $0.stage == "Approval review" }.count
    let accountGaps = entries.filter { $0.stage == "Account missing" || $0.stage == "Account review" }.count
    let ready = entries.filter { $0.stage == "Ready for manual purchase" || $0.stage == "Order linked" }.count

    return SettingsPanel(title: "Manual purchase handoff readiness", symbol: "hand.raised.square.on.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this after the seller decision. It pulls selected link, local approval, account readiness, handoff, and order-watch trail into one operator checklist.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("In handoff", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Link gaps", "\(linkGaps)", linkGaps == 0 ? .green : .purple),
          ("Approval gaps", "\(approvalGaps)", approvalGaps == 0 ? .green : .indigo),
          ("Account gaps", "\(accountGaps)", accountGaps == 0 ? .green : .teal),
          ("Ready/linked", "\(ready)", ready == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No manual purchase handoff work yet",
            detail: "Items appear here once they have seller options, purchase decisions, approval/link/account records, or handoff activity.",
            symbol: "hand.raised.square.on.square.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 255 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistManualPurchaseHandoffReadinessRow(entry: entry) {
                runWishlistManualPurchaseHandoffReadinessAction(for: entry)
              } onTask: {
                runWishlistManualPurchaseHandoffReadinessTask(for: entry)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .buy
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more manual purchase handoff item\(remaining == 1 ? "" : "s") are available in the detailed panels below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Boundary: this panel does not browse, log in, store payment details, store passwords, check stock, place orders, pay, send emails, or mutate mailbox messages. It records only local readiness.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistManualPurchaseHandoffReadinessAction(for entry: WishlistManualPurchaseHandoffReadinessEntry) {
    switch entry.stage {
    case "Decision missing":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.markWishlistPurchaseDecisionReviewed(entry.item)
    case "Purchase link missing":
      store.addWishlistPurchaseLinkRecord(entry.item)
    case "Link review":
      if let link = entry.selectedLink { store.createWishlistPurchaseLinkRecordReviewTask(link) }
    case "Approval missing":
      store.addWishlistPurchaseApprovalRecord(entry.item)
    case "Approval review":
      if let approval = entry.approval { store.createWishlistPurchaseApprovalRecordReviewTask(approval) }
    case "Account missing":
      store.addWishlistPurchaseAccountRecord(entry.item)
    case "Account review":
      if let account = entry.account { store.createWishlistPurchaseAccountRecordReviewTask(account) }
    case "Handoff missing":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Ready for manual purchase":
      store.markWishlistOrderConfirmationSeen(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .buy
    }
  }

  private func runWishlistManualPurchaseHandoffReadinessTask(for entry: WishlistManualPurchaseHandoffReadinessEntry) {
    if let link = entry.selectedLink, entry.stage == "Link review" {
      store.createWishlistPurchaseLinkRecordReviewTask(link)
    } else if let approval = entry.approval, entry.stage == "Approval review" {
      store.createWishlistPurchaseApprovalRecordReviewTask(approval)
    } else if let account = entry.account, entry.stage == "Account review" {
      store.createWishlistPurchaseAccountRecordReviewTask(account)
    } else if entry.handoff != nil {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else {
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    }
  }

  private var wishlistPurchaseEvidenceDossiers: [WishlistPurchaseEvidenceDossier] {
    wishlistPurchaseDecisionSummaries
      .map { summary in
        wishlistPurchaseEvidenceDossier(for: summary.item, summary: summary)
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseEvidenceDossierPanel: some View {
    let dossiers = wishlistPurchaseEvidenceDossiers
    let ready = dossiers.filter { $0.stage == "Evidence ready" }.count
    let missing = dossiers.filter { $0.stage == "Evidence missing" }.count
    let needsReview = dossiers.filter { $0.stage == "Decision review" }.count
    let handoffMissing = dossiers.filter { $0.gaps.contains("handoff") || $0.gaps.contains("order watch") }.count

    return SettingsPanel(title: "Purchase evidence dossier", symbol: "folder.badge.gearshape.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Before a Wishlist item is bought externally, confirm the local evidence bundle is coherent: seller choice, AUD total, postage, trust, account context, cost context, decision review, and order-watch handoff.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Dossiers", "\(dossiers.count)", dossiers.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Missing evidence", "\(missing)", missing == 0 ? .green : .orange),
          ("Decision review", "\(needsReview)", needsReview == 0 ? .green : .brown),
          ("Handoff gaps", "\(handoffMissing)", handoffMissing == 0 ? .green : .purple)
        ])

        if dossiers.isEmpty {
          MVPEmptyState(
            title: "No purchase evidence dossiers yet",
            detail: "Add seller options and enter the purchase decision flow before ParcelOps can summarise evidence readiness.",
            symbol: "folder.badge.gearshape.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(dossiers.prefix(8)) { dossier in
              WishlistPurchaseEvidenceDossierRow(dossier: dossier) {
                runWishlistPurchaseEvidenceDossierAction(for: dossier)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(dossier.item)
              } onDecision: {
                store.createWishlistPurchaseDecision(dossier.item)
              } onFocus: {
                wishlistSearchText = dossier.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(dossiers.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more evidence dossier\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Evidence dossiers are local summaries only. ParcelOps does not verify live stock, live price, payment availability, account login, seller reviews, seller identity, or retailer checkout.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseEvidenceDossier(for item: WishlistItem, summary: WishlistPurchaseDecisionSummary) -> WishlistPurchaseEvidenceDossier {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { optionID in
      options.first { $0.id == optionID }
    }
    let decision = item.purchaseDecision
    let handoff = item.purchaseHandoff
    let accountCount = store.suggestedAccounts(for: item).count
    let costCount = store.suggestedCostRecords(for: item).count
    let passedChecks = (item.purchaseChecks ?? []).filter { $0.status == "Passed" }.count
    let failedChecks = (item.purchaseChecks ?? []).filter { $0.status != "Passed" }.count

    let checks: [WishlistPurchaseEvidenceCheck] = [
      WishlistPurchaseEvidenceCheck(label: "Seller option", detail: preferred?.sellerName ?? "No preferred seller", isReady: preferred != nil),
      WishlistPurchaseEvidenceCheck(label: "AUD total", detail: summary.totalAUD, isReady: !wishlistPurchaseDecisionValueNeedsReview(summary.totalAUD)),
      WishlistPurchaseEvidenceCheck(label: "Postage", detail: summary.postage, isReady: !wishlistPurchaseDecisionValueNeedsReview(summary.postage)),
      WishlistPurchaseEvidenceCheck(label: "Seller trust", detail: summary.trust, isReady: !wishlistPurchaseDecisionValueNeedsReview(summary.trust) && preferred?.operatorSellerEvidenceGaps.contains("seller trust") != true),
      WishlistPurchaseEvidenceCheck(label: "Readiness", detail: passedChecks == 0 && failedChecks == 0 ? "Not run" : "\(passedChecks) passed, \(failedChecks) need review", isReady: passedChecks > 0 && failedChecks == 0),
      WishlistPurchaseEvidenceCheck(label: "Decision", detail: decision?.reviewState.rawValue ?? "Not drafted", isReady: decision?.reviewState == .accepted),
      WishlistPurchaseEvidenceCheck(label: "Account context", detail: accountCount == 0 ? "No suggested account" : "\(accountCount) suggested", isReady: accountCount > 0 || handoff != nil),
      WishlistPurchaseEvidenceCheck(label: "Cost context", detail: costCount == 0 ? "No linked cost" : "\(costCount) suggested", isReady: costCount > 0 || decision != nil),
      WishlistPurchaseEvidenceCheck(label: "Order watch", detail: handoff?.orderWatchStatus ?? "Handoff not prepared", isReady: handoff != nil)
    ]

    var gaps = checks.filter { !$0.isReady }.map { $0.label.localizedLowercase }
    gaps.append(contentsOf: summary.verificationGaps)
    gaps = Array(Set(gaps)).sorted()

    let stage: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if decision == nil {
      stage = "Evidence missing"
      detail = "Draft a purchase decision after seller, cost, postage, and trust fields are coherent."
      tone = .orange
      sortPriority = 10
    } else if decision?.reviewState != .accepted {
      stage = "Decision review"
      detail = "Decision exists but still needs local review before handoff."
      tone = .brown
      sortPriority = 20
    } else if !gaps.isEmpty {
      stage = "Evidence missing"
      detail = "Resolve \(gaps.prefix(3).joined(separator: ", ")) before external purchase."
      tone = .orange
      sortPriority = 30
    } else if handoff == nil {
      stage = "Handoff missing"
      detail = "Evidence is mostly ready. Prepare the account and order-watch handoff."
      tone = .purple
      sortPriority = 40
    } else {
      stage = "Evidence ready"
      detail = "Local evidence is ready for final live checks and external purchase."
      tone = .green
      sortPriority = 50
    }

    return WishlistPurchaseEvidenceDossier(
      item: item,
      selectedSeller: summary.selectedSeller,
      checks: checks,
      gaps: gaps,
      stage: stage,
      detail: detail,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistPurchaseEvidenceDossierAction(for dossier: WishlistPurchaseEvidenceDossier) {
    if dossier.item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(dossier.item)
    } else if dossier.item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(dossier.item)
    } else if dossier.item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(dossier.item)
    } else if !dossier.gaps.isEmpty {
      store.runWishlistPurchaseReadinessCheck(dossier.item)
    } else {
      wishlistSearchText = dossier.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseDecisionEvidencePacks: [WishlistPurchaseDecisionEvidencePack] {
    wishlistPurchaseDecisionSummaries
      .map { summary in
        let dossier = wishlistPurchaseEvidenceDossier(for: summary.item, summary: summary)
        let decision = summary.item.purchaseDecision
        let handoff = summary.item.purchaseHandoff
        let unresolved = Array(Set(summary.verificationGaps + dossier.gaps)).sorted()
        let readyEvidence = dossier.checks.filter(\.isReady).count
        let totalEvidence = dossier.checks.count
        let isSignedOff = decision?.reviewState == .accepted && unresolved.isEmpty && handoff != nil

        let status: String
        let detail: String
        let tone: Color
        let sortPriority: Int

        if decision == nil {
          status = "Decision missing"
          detail = "No purchase decision exists yet. Draft the selected seller, AUD total, postage, trust rationale, and rejected alternatives."
          tone = .brown
          sortPriority = 10
        } else if decision?.reviewState != .accepted {
          status = "Review required"
          detail = "Decision exists but has not been accepted. Confirm the seller route and evidence before preparing purchase handoff."
          tone = .orange
          sortPriority = 20
        } else if !unresolved.isEmpty {
          status = "Evidence gaps"
          detail = "Decision is accepted, but unresolved evidence remains: \(unresolved.prefix(3).joined(separator: ", "))."
          tone = .orange
          sortPriority = 30
        } else if handoff == nil {
          status = "Handoff missing"
          detail = "Decision evidence is acceptable locally. Prepare account, delivery, payment-method, and order-watch handoff before buying."
          tone = .purple
          sortPriority = 40
        } else if handoff?.linkedOrderID == nil {
          status = "Ready for external buy"
          detail = "Local evidence pack is signed off. Buy outside ParcelOps only after final live checks, then watch for order confirmation."
          tone = .green
          sortPriority = 50
        } else {
          status = "Order linked"
          detail = "Purchase decision evidence is linked to a local order. Continue operational tracking through Orders, Dispatch, Tasks, and Audit."
          tone = .teal
          sortPriority = 60
        }

        return WishlistPurchaseDecisionEvidencePack(
          item: summary.item,
          summary: summary,
          dossier: dossier,
          status: status,
          detail: detail,
          unresolvedEvidence: unresolved,
          readyEvidence: readyEvidence,
          totalEvidence: totalEvidence,
          isSignedOff: isSignedOff,
          tone: tone,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseDecisionEvidencePackPanel: some View {
    let packs = wishlistPurchaseDecisionEvidencePacks
    let missingDecision = packs.filter { $0.status == "Decision missing" }.count
    let needsReview = packs.filter { $0.status == "Review required" || $0.status == "Evidence gaps" }.count
    let ready = packs.filter { $0.status == "Ready for external buy" }.count
    let linked = packs.filter { $0.status == "Order linked" }.count

    return SettingsPanel(title: "Purchase decision evidence pack", symbol: "doc.badge.gearshape.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("A final local sign-off view for Wishlist purchase decisions. It connects selected seller, rejected alternatives, AUD total, postage, trust, evidence gaps, handoff, and order-watch state before any external purchase.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Packs", "\(packs.count)", packs.isEmpty ? .secondary : .blue),
          ("Missing decision", "\(missingDecision)", missingDecision == 0 ? .green : .brown),
          ("Need review", "\(needsReview)", needsReview == 0 ? .green : .orange),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal)
        ])

        if packs.isEmpty {
          MVPEmptyState(
            title: "No decision evidence packs",
            detail: "Wishlist items appear here once they have seller options or enter the purchase decision flow.",
            symbol: "doc.badge.gearshape.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(packs.prefix(8)) { pack in
              WishlistPurchaseDecisionEvidencePackRow(pack: pack) {
                runWishlistPurchaseDecisionEvidencePackAction(for: pack)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(pack.item)
              } onFocus: {
                wishlistSearchText = pack.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(packs.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more decision evidence pack\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Evidence pack sign-off is local only. ParcelOps does not verify live stock, current seller reputation, checkout availability, account login, payment, delivery address, returns, warranty, or order placement.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistPurchaseDecisionEvidencePackAction(for pack: WishlistPurchaseDecisionEvidencePack) {
    switch pack.status {
    case "Decision missing":
      store.createWishlistPurchaseDecision(pack.item)
    case "Review required":
      store.markWishlistPurchaseDecisionReviewed(pack.item)
    case "Evidence gaps":
      store.runWishlistPurchaseReadinessCheck(pack.item)
      store.createWishlistPurchaseDecisionReviewTask(pack.item)
    case "Handoff missing":
      store.prepareWishlistPurchaseHandoff(pack.item)
    case "Ready for external buy":
      store.markWishlistOrderConfirmationSeen(pack.item)
    default:
      wishlistSearchText = pack.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPrePurchaseOperatorChecklistItems: [WishlistPurchaseOperatorChecklist] {
    wishlistPurchaseReleaseChecklistItems
      .map { gate in
        let item = gate.item
        let decision = item.purchaseDecision
        let handoff = item.purchaseHandoff
        let preferred = item.preferredOptionID.flatMap { optionID in
          item.comparisonOptions?.first { $0.id == optionID }
        } ?? item.comparisonOptions?.first
        let checks = item.purchaseChecks ?? []
        let failedChecks = checks.filter { $0.status != "Passed" }
        let hasReadyDecision = decision?.reviewState == .accepted
        let hasHandoff = handoff != nil
        let hasOrder = handoff?.linkedOrderID != nil

        let manualChecks: [(String, Bool)] = [
          ("Seller chosen", preferred != nil && item.preferredOptionID != nil),
          ("Decision accepted", hasReadyDecision),
          ("AUD/postage/trust checked", !checks.isEmpty && failedChecks.isEmpty),
          ("Account/payment/delivery noted", hasHandoff),
          ("Order watch ready", hasHandoff),
          ("Order linked", hasOrder)
        ]

        let blockers = manualChecks.filter { !$0.1 }.map(\.0)
        let liveVerification = [
          "live stock",
          "current price",
          "AUD landed total",
          "postage cost/time",
          "seller trust",
          "returns/warranty",
          "account access",
          "payment method",
          "delivery address"
        ]

        let stage: String
        let detail: String
        let tone: Color
        let actionTitle: String
        let actionSymbol: String
        let sortPriority: Int

        if !hasReadyDecision {
          stage = "Decision not accepted"
          detail = decision == nil
            ? "Draft and review the selected seller decision before handoff."
            : "Accept or reopen the purchase decision after confirming seller and cost details."
          tone = .orange
          actionTitle = decision == nil ? "Draft decision" : "Accept decision"
          actionSymbol = decision == nil ? "doc.text.magnifyingglass" : "checkmark.seal"
          sortPriority = 10
        } else if failedChecks.isEmpty == false || checks.isEmpty {
          stage = "Checks need review"
          detail = checks.isEmpty ? "Run the local readiness check before handoff." : "Clear failed readiness checks before buying externally."
          tone = .orange
          actionTitle = "Run checks"
          actionSymbol = "checklist.checked"
          sortPriority = 20
        } else if !hasHandoff {
          stage = "Handoff needed"
          detail = "Prepare account, payment, delivery, and order-watch notes before the external purchase."
          tone = .purple
          actionTitle = "Prepare handoff"
          actionSymbol = "person.crop.circle.badge.checkmark"
          sortPriority = 30
        } else if !hasOrder {
          stage = "Ready to buy externally"
          detail = "Handoff is ready. Buy outside ParcelOps only after final live checks, then watch Inbox/Orders for confirmation."
          tone = .green
          actionTitle = "Order seen"
          actionSymbol = "envelope.badge.fill"
          sortPriority = 40
        } else {
          stage = "Order linked"
          detail = "Order confirmation has been linked. Continue operational tracking in Orders, Dispatch, and Tasks."
          tone = .teal
          actionTitle = "Focus item"
          actionSymbol = "scope"
          sortPriority = 50
        }

        return WishlistPurchaseOperatorChecklist(
          item: item,
          stage: stage,
          detail: detail,
          selectedSeller: decision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront,
          totalAUD: decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost,
          postage: decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not recorded",
          trust: decision?.trustSummary ?? preferred?.trustRating ?? "Seller trust not assessed",
          handoff: handoff?.accountLabel ?? "Account/payment/delivery not prepared",
          manualChecks: manualChecks,
          blockers: blockers,
          liveVerification: liveVerification,
          tone: tone,
          actionTitle: actionTitle,
          actionSymbol: actionSymbol,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPrePurchaseOperatorChecklistPanel: some View {
    let items = wishlistPrePurchaseOperatorChecklistItems
    let ready = items.filter { $0.stage == "Ready to buy externally" }.count
    let linked = items.filter { $0.stage == "Order linked" }.count
    let blocked = items.filter { $0.sortPriority < 40 }.count
    let handoffMissing = items.filter { $0.blockers.contains("Account/payment/delivery noted") }.count

    return SettingsPanel(title: "Operator pre-purchase checklist", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the human buying checklist. It separates local readiness from real-world verification: ParcelOps can stage the decision and order watch, but a person must still confirm live seller, account, payment, and delivery details outside the app.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Checklist items", "\(items.count)", items.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .orange),
          ("Need handoff", "\(handoffMissing)", handoffMissing == 0 ? .green : .purple)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No pre-purchase checklist items",
            detail: "Wishlist items appear here once they have seller options, purchase decisions, handoff setup, or release readiness.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { item in
              WishlistPurchaseOperatorChecklistRow(checklist: item) {
                runWishlistPrePurchaseChecklistAction(for: item.item)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(item.item)
              } onFocus: {
                wishlistSearchText = item.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more pre-purchase checklist item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("No checkout, payment, account login, seller trust lookup, currency conversion, postage quote, browser automation, or retailer contact runs from this checklist.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistPrePurchaseChecklistAction(for item: WishlistItem) {
    if item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(item)
    } else if item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(item)
    } else if item.purchaseChecks?.isEmpty != false || item.purchaseChecks?.contains(where: { $0.status != "Passed" }) == true {
      store.runWishlistPurchaseReadinessCheck(item)
    } else if item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(item)
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseReleaseChecklistItems: [WishlistPurchaseReleaseGate] {
    store.wishlistItems
      .filter { item in
        !(item.comparisonOptions ?? []).isEmpty
          || item.purchaseDecision != nil
          || item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("ready")
      }
      .map(wishlistPurchaseReleaseGate(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseReleaseChecklistPanel: some View {
    let gates = wishlistPurchaseReleaseChecklistItems
    let handoffReady = gates.filter(\.isReadyForManualPurchase).count
    let linkedOrders = gates.filter(\.isLinkedOrder).count
    let blocked = gates.filter { !$0.isReadyForManualPurchase && !$0.isLinkedOrder }.count
    let highRisk = gates.filter { $0.tone == .red || $0.tone == .orange }.count

    return SettingsPanel(title: "Purchase release checklist", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the final local gate before a human purchase or order-confirmation watch. It checks source details, preferred seller evidence, readiness checks, decision review, handoff setup, and linked order state without buying anything or contacting retailers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Release items", "\(gates.count)", gates.isEmpty ? .secondary : .blue),
          ("Ready handoff", "\(handoffReady)", handoffReady == 0 ? .secondary : .green),
          ("Linked orders", "\(linkedOrders)", linkedOrders == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .orange),
          ("Risk", "\(highRisk)", highRisk == 0 ? .green : .red)
        ])

        if gates.isEmpty {
          MVPEmptyState(
            title: "No Wishlist items are near purchase release",
            detail: "Add seller options and run comparison before an item appears in this final purchase gate.",
            symbol: "checkmark.seal.text.page.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gates.prefix(8)) { gate in
              WishlistPurchaseReleaseChecklistRow(gate: gate) {
                runWishlistPurchaseReleaseAction(for: gate.item)
              } onFocus: {
                wishlistSearchText = gate.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(gates.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist release item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Release means local readiness only. ParcelOps has not verified live price, stock, postage, seller reputation, account login, payment, checkout, or delivery status.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseReleaseGate(for item: WishlistItem) -> WishlistPurchaseReleaseGate {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    } ?? options.first
    let checks = item.purchaseChecks ?? []
    let sourceOK = !item.itemName.isPlaceholderValidationValue
      && !item.storefrontURL.isPlaceholderValidationValue
      && !item.owner.isPlaceholderValidationValue
    let sellerOK = preferred != nil && preferred?.operatorSellerEvidenceGaps.isEmpty == true
    let readinessOK = !checks.isEmpty && !checks.contains { $0.status != "Passed" }
    let decisionOK = item.purchaseDecision?.reviewState == .accepted
    let handoffOK = item.purchaseHandoff != nil
    let orderLinked = item.purchaseHandoff?.linkedOrderID != nil

    var checksSummary: [(String, Bool)] = [
      ("Source", sourceOK),
      ("Seller", sellerOK),
      ("Readiness", readinessOK),
      ("Decision", decisionOK),
      ("Handoff", handoffOK),
      ("Order", orderLinked)
    ]

    let stage: String
    let detail: String
    let actionTitle: String
    let actionSymbol: String
    let tone: Color
    let sortPriority: Int

    if options.isEmpty {
      stage = "Seller comparison needed"
      detail = "Add seller options or a research request before this item can be released for purchase review."
      actionTitle = "Compare"
      actionSymbol = "magnifyingglass.circle"
      tone = .orange
      sortPriority = 1
    } else if preferred == nil || item.preferredOptionID == nil {
      stage = "Preferred seller needed"
      detail = "Score or choose the preferred seller before release."
      actionTitle = "Score"
      actionSymbol = "chart.bar.doc.horizontal"
      tone = .orange
      sortPriority = 2
    } else if !sellerOK {
      let gaps = preferred?.operatorSellerEvidenceGaps ?? []
      stage = "Seller evidence needed"
      detail = "Confirm \(gaps.prefix(3).joined(separator: ", ")) before purchase handoff."
      actionTitle = "Evidence task"
      actionSymbol = "checklist"
      tone = .orange
      sortPriority = 3
    } else if !readinessOK {
      stage = "Readiness check needed"
      detail = checks.isEmpty ? "Run the local purchase readiness check." : "Clear failed readiness checks before release."
      actionTitle = "Readiness"
      actionSymbol = "checklist.checked"
      tone = .orange
      sortPriority = 4
    } else if item.purchaseDecision == nil {
      stage = "Purchase decision needed"
      detail = "Draft the selected seller, AUD total, postage, trust, and rejected alternatives."
      actionTitle = "Decision"
      actionSymbol = "doc.text.magnifyingglass"
      tone = .brown
      sortPriority = 5
    } else if !decisionOK {
      stage = "Decision review needed"
      detail = "Review and accept the local decision before handoff."
      actionTitle = "Review"
      actionSymbol = "checkmark.seal"
      tone = .brown
      sortPriority = 6
    } else if !handoffOK {
      stage = "Handoff setup needed"
      detail = "Prepare the manual purchase handoff and expected order-confirmation watch."
      actionTitle = "Handoff"
      actionSymbol = "person.crop.circle.badge.checkmark"
      tone = .purple
      sortPriority = 7
    } else if !orderLinked {
      stage = "Ready for manual purchase"
      detail = "Handoff is ready. After external purchase, watch Inbox/Mailbox Monitor for confirmation and link the order."
      actionTitle = "Order seen"
      actionSymbol = "envelope.badge.fill"
      tone = .green
      sortPriority = 8
    } else {
      stage = "Linked order released"
      detail = "A local order is linked. Continue through Orders, Dispatch, Tasks, and Audit."
      actionTitle = "Open item"
      actionSymbol = "scope"
      tone = .teal
      sortPriority = 9
    }

    if orderLinked {
      checksSummary[5] = ("Order", true)
    }

    return WishlistPurchaseReleaseGate(
      item: item,
      stage: stage,
      detail: detail,
      actionTitle: actionTitle,
      actionSymbol: actionSymbol,
      checks: checksSummary,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistPurchaseReleaseAction(for item: WishlistItem) {
    let gate = wishlistPurchaseReleaseGate(for: item)
    switch gate.sortPriority {
    case 1:
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    case 2:
      store.evaluateWishlistComparisonOptions(item)
    case 3:
      store.createWishlistSellerEvidenceReviewTask(item)
    case 4:
      store.runWishlistPurchaseReadinessCheck(item)
    case 5:
      store.createWishlistPurchaseDecision(item)
    case 6:
      store.markWishlistPurchaseDecisionReviewed(item)
    case 7:
      store.prepareWishlistPurchaseHandoff(item)
    case 8:
      store.markWishlistOrderConfirmationSeen(item)
    default:
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistManualPurchaseDayPlanEntries: [WishlistManualPurchaseDayPlanEntry] {
    wishlistPurchaseReleaseChecklistItems
      .filter { gate in
        gate.stage == "Ready for manual purchase"
          || gate.stage == "Linked order released"
          || gate.stage == "Handoff setup needed"
          || gate.item.purchaseHandoff != nil
          || gate.item.purchaseDecision?.reviewState == .accepted
      }
      .map(wishlistManualPurchaseDayPlanEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistManualPurchaseDayPlanPanel: some View {
    let entries = wishlistManualPurchaseDayPlanEntries
    let buyReady = entries.filter { $0.stage == "Ready to buy externally" }.count
    let needsHandoff = entries.filter { $0.stage == "Prepare handoff" }.count
    let watching = entries.filter { $0.stage == "Watch confirmation" }.count
    let linked = entries.filter { $0.stage == "Order linked" }.count

    return SettingsPanel(title: "Manual purchase day plan", symbol: "calendar.badge.clock") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this when a Wishlist item is close to buying. It keeps the real-world sequence explicit: final seller checks, external purchase, local purchase marker, Inbox/order watch, then linked order follow-up.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Plan items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(buyReady)", buyReady == 0 ? .secondary : .green),
          ("Need handoff", "\(needsHandoff)", needsHandoff == 0 ? .green : .purple),
          ("Watching", "\(watching)", watching == 0 ? .secondary : .orange),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No manual purchase plans yet",
            detail: "A plan appears after a Wishlist item has an accepted decision, purchase handoff, or release gate ready for external buying.",
            symbol: "calendar.badge.clock"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 410), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistManualPurchaseDayPlanRow(entry: entry) {
                runWishlistManualPurchaseDayPlanAction(for: entry)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(entry.item)
              } onConfirmation: {
                store.markWishlistOrderConfirmationSeen(entry.item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more manual purchase plan item\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("The plan does not open seller pages, log in, place orders, pay, send email, mutate mailboxes, or monitor in the background. It records local readiness and follow-up only.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistManualPurchaseDayPlanEntry(for gate: WishlistPurchaseReleaseGate) -> WishlistManualPurchaseDayPlanEntry {
    let item = gate.item
    let handoff = item.purchaseHandoff
    let decision = item.purchaseDecision
    let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    let confirmationCandidates = store.suggestedWishlistOrderConfirmations(for: item).count
    let seller = handoff?.sellerName ?? decision?.selectedSellerName ?? item.storefront
    let account = handoff?.accountLabel ?? "\(item.owner) account to confirm"

    let stage: String
    let nextAction: String
    let nextSymbol: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if linkedOrder != nil {
      stage = "Order linked"
      nextAction = "Focus"
      nextSymbol = "scope"
      detail = "Order is linked. Continue normal Orders, Dispatch, Tasks, and receiving follow-up."
      tone = .teal
      sortPriority = 50
    } else if confirmationCandidates > 0 {
      stage = "Confirmation candidates"
      nextAction = "Link seen"
      nextSymbol = "envelope.badge.fill"
      detail = "Inbox has possible order confirmations. Review and link the correct local order before closing purchase follow-up."
      tone = .teal
      sortPriority = 10
    } else if handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
      stage = "Watch confirmation"
      nextAction = "Confirmation seen"
      nextSymbol = "envelope.badge.fill"
      detail = "External purchase was recorded. Watch Inbox/Mailbox Monitor and Orders for confirmation from \(seller)."
      tone = .orange
      sortPriority = 20
    } else if handoff == nil {
      stage = "Prepare handoff"
      nextAction = "Handoff task"
      nextSymbol = "checklist"
      detail = "Prepare account, payment-method reminder, delivery address, seller, and expected order signals before buying externally."
      tone = .purple
      sortPriority = 30
    } else {
      stage = "Ready to buy externally"
      nextAction = "Mark purchased"
      nextSymbol = "bag.fill"
      detail = "Do final live checks outside ParcelOps, buy manually if appropriate, then mark purchased so the order-watch trail starts."
      tone = .green
      sortPriority = 40
    }

    let steps = [
      "Confirm live stock and final AUD total",
      "Confirm postage cost/time, returns, warranty, and seller trust",
      "Use external seller site/account manually",
      "Record purchased locally after checkout",
      "Watch Inbox and Orders for confirmation"
    ]

    return WishlistManualPurchaseDayPlanEntry(
      item: item,
      seller: seller,
      account: account,
      linkedOrder: linkedOrder,
      confirmationCandidates: confirmationCandidates,
      stage: stage,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      detail: detail,
      steps: steps,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistManualPurchaseDayPlanAction(for entry: WishlistManualPurchaseDayPlanEntry) {
    switch entry.stage {
    case "Confirmation candidates", "Watch confirmation":
      store.markWishlistOrderConfirmationSeen(entry.item)
    case "Prepare handoff":
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    case "Ready to buy externally":
      store.recordWishlistPurchasedExternally(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseHandoffPackItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        item.purchaseHandoff != nil
          || item.purchaseDecision?.reviewState == .accepted
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("order confirmation")
      }
      .sorted { first, second in
        let firstGaps = wishlistPurchaseHandoffPackGaps(for: first).count
        let secondGaps = wishlistPurchaseHandoffPackGaps(for: second).count
        if firstGaps == secondGaps {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstGaps > secondGaps
      }
  }

  private var wishlistPurchaseHandoffPackPanel: some View {
    let items = wishlistPurchaseHandoffPackItems
    let missingOrder = items.filter { $0.purchaseHandoff?.linkedOrderID == nil }.count
    let missingCost = items.filter { store.suggestedCostRecords(for: $0).isEmpty }.count
    let missingProcurement = items.filter { store.suggestedProcurementRequests(for: $0).isEmpty }.count
    let missingReceiving = items.filter { store.suggestedReceivingInspections(for: $0).isEmpty }.count

    return SettingsPanel(title: "Purchase handoff pack", symbol: "shippingbox.and.arrow.backward.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("After a Wishlist item is ready to buy or has been bought externally, use this pack to stage the local records ParcelOps needs: account context, cost/budget, procurement, receiving, and order-confirmation watch.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Handoff items", "\(items.count)", items.isEmpty ? .secondary : .blue),
          ("No linked order", "\(missingOrder)", missingOrder == 0 ? .green : .teal),
          ("Cost gaps", "\(missingCost)", missingCost == 0 ? .green : .orange),
          ("Procurement gaps", "\(missingProcurement)", missingProcurement == 0 ? .green : .purple),
          ("Receiving gaps", "\(missingReceiving)", missingReceiving == 0 ? .green : .brown)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No purchase handoffs yet",
            detail: "Review a purchase decision or prepare a manual purchase handoff before staging cost, procurement, receiving, and order watch records.",
            symbol: "shippingbox.and.arrow.backward.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { item in
              WishlistPurchaseHandoffPackRow(
                item: item,
                linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
                  store.orders.first { $0.id == orderID }
                },
                gaps: wishlistPurchaseHandoffPackGaps(for: item),
                accountCount: store.suggestedAccounts(for: item).count,
                costCount: store.suggestedCostRecords(for: item).count,
                procurementCount: store.suggestedProcurementRequests(for: item).count,
                receivingCount: store.suggestedReceivingInspections(for: item).count
              ) {
                runWishlistHandoffPackAction(for: item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(item)
              } onOrderSeen: {
                store.markWishlistOrderConfirmationSeen(item)
              } onFocus: {
                wishlistSearchText = item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist handoff item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This pack creates local planning records only. It does not buy items, log in to retailers, store payment details, send email, mutate mailboxes, book carriers, or run background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseHandoffPackGaps(for item: WishlistItem) -> [String] {
    var gaps: [String] = []
    if item.purchaseHandoff == nil { gaps.append("handoff") }
    if store.suggestedAccounts(for: item).isEmpty { gaps.append("account") }
    if store.suggestedCostRecords(for: item).isEmpty { gaps.append("cost") }
    if store.suggestedProcurementRequests(for: item).isEmpty { gaps.append("procurement") }
    if store.suggestedReceivingInspections(for: item).isEmpty { gaps.append("receiving") }
    if item.purchaseHandoff?.linkedOrderID == nil { gaps.append("order link") }
    return gaps
  }

  private func runWishlistHandoffPackAction(for item: WishlistItem) {
    let gaps = wishlistPurchaseHandoffPackGaps(for: item)
    if gaps.contains("handoff") {
      store.prepareWishlistPurchaseHandoff(item)
    } else if gaps.contains("cost") {
      store.createWishlistPurchaseCostRecord(item)
    } else if gaps.contains("procurement") {
      store.createWishlistProcurementRequest(item)
    } else if gaps.contains("receiving") {
      store.createWishlistReceivingInspection(item)
    } else if gaps.contains("order link") {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      store.createWishlistPurchaseHandoffReviewTask(item)
    }
  }

  private var wishlistPurchaseHandoffSanityEntries: [WishlistPurchaseHandoffSanityEntry] {
    wishlistPurchaseHandoffPackItems.map { item in
      let handoff = item.purchaseHandoff
      let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
        store.orders.first { $0.id == orderID }
      }
      let accountCount = store.suggestedAccounts(for: item).count
      let costCount = store.suggestedCostRecords(for: item).count
      let procurementCount = store.suggestedProcurementRequests(for: item).count
      let receivingCount = store.suggestedReceivingInspections(for: item).count
      var checks: [WishlistPurchaseHandoffSanityCheck] = []

      func addCheck(_ title: String, detail: String, ready: Bool, symbol: String) {
        checks.append(WishlistPurchaseHandoffSanityCheck(title: title, detail: detail, ready: ready, symbol: symbol))
      }

      let seller = handoff?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront
      addCheck("Seller route", detail: seller.isPlaceholderValidationValue ? "Seller still needs confirmation" : seller, ready: !seller.isPlaceholderValidationValue, symbol: "storefront.fill")
      addCheck("Account label", detail: handoff?.accountLabel ?? "No handoff account label", ready: handoff?.accountLabel.isPlaceholderValidationValue == false || accountCount > 0, symbol: "person.crop.circle.badge.key.fill")
      addCheck("Order watch", detail: handoff?.expectedOrderSignals ?? "No expected confirmation signal", ready: handoff?.expectedOrderSignals.isPlaceholderValidationValue == false, symbol: "envelope.badge.fill")
      addCheck("Local cost", detail: costCount == 0 ? "No local cost placeholder" : "\(costCount) local cost record\(costCount == 1 ? "" : "s")", ready: costCount > 0, symbol: "dollarsign.circle.fill")
      addCheck("Procurement", detail: procurementCount == 0 ? "No procurement placeholder" : "\(procurementCount) procurement record\(procurementCount == 1 ? "" : "s")", ready: procurementCount > 0, symbol: "cart.badge.plus")
      addCheck("Receiving", detail: receivingCount == 0 ? "No receiving placeholder" : "\(receivingCount) receiving record\(receivingCount == 1 ? "" : "s")", ready: receivingCount > 0, symbol: "shippingbox.and.arrow.down.fill")
      addCheck("Order link", detail: linkedOrder?.orderNumber ?? "Not linked yet", ready: linkedOrder != nil || handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") != true, symbol: "link")

      let missingCount = checks.filter { !$0.ready }.count
      let tone: Color = missingCount == 0 ? .green : (missingCount >= 4 ? .orange : .purple)
      let nextAction: String
      let nextSymbol: String
      if handoff == nil {
        nextAction = "Prepare handoff"
        nextSymbol = "person.crop.circle.badge.checkmark"
      } else if costCount == 0 {
        nextAction = "Add cost"
        nextSymbol = "dollarsign.circle.fill"
      } else if procurementCount == 0 {
        nextAction = "Procurement"
        nextSymbol = "cart.badge.plus"
      } else if receivingCount == 0 {
        nextAction = "Receiving"
        nextSymbol = "shippingbox.and.arrow.down.fill"
      } else if linkedOrder == nil && handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
        nextAction = "Order seen"
        nextSymbol = "envelope.badge.fill"
      } else {
        nextAction = "Review task"
        nextSymbol = "checklist"
      }

      return WishlistPurchaseHandoffSanityEntry(
        item: item,
        handoff: handoff,
        linkedOrder: linkedOrder,
        checks: checks,
        tone: tone,
        nextAction: nextAction,
        nextSymbol: nextSymbol,
        missingCount: missingCount
      )
    }
    .sorted { first, second in
      if first.missingCount == second.missingCount {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.missingCount > second.missingCount
    }
  }

  private var wishlistPurchaseHandoffSanityPanel: some View {
    let entries = wishlistPurchaseHandoffSanityEntries
    let readyCount = entries.filter { $0.missingCount == 0 }.count
    let blockedCount = entries.filter { $0.missingCount >= 4 }.count
    let needsOrderLink = entries.filter { entry in
      entry.handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true && entry.linkedOrder == nil
    }.count

    return SettingsPanel(title: "Purchase handoff sanity check", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this compact check before and after buying outside ParcelOps. It confirms the local handoff has seller, account, order-watch, cost, procurement, receiving, and order-link context for downstream operations.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Checked", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(readyCount)", readyCount == 0 ? .secondary : .green),
          ("Blocked", "\(blockedCount)", blockedCount == 0 ? .green : .orange),
          ("Need order link", "\(needsOrderLink)", needsOrderLink == 0 ? .green : .teal)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No purchase handoffs to sanity-check",
            detail: "Accepted purchase decisions and prepared handoffs will appear here before external buying or order-confirmation linking.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseHandoffSanityRow(entry: entry) {
                runWishlistHandoffPackAction(for: entry.item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase handoff sanity check\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This is a local readiness check. It does not buy, pay, log in, monitor mail in the background, contact retailers, mutate mailbox messages, or create external tasks.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPostPurchaseMonitorEntries: [WishlistPostPurchaseMonitorEntry] {
    store.wishlistItems
      .compactMap(wishlistPostPurchaseMonitorEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPostPurchaseMonitorPanel: some View {
    let entries = wishlistPostPurchaseMonitorEntries
    let needsHandoff = entries.filter { $0.stage == "Prepare handoff" }.count
    let awaitingConfirmation = entries.filter { $0.stage == "Awaiting confirmation" }.count
    let matchReview = entries.filter { $0.stage == "Review confirmation" }.count
    let linked = entries.filter { $0.stage == "Linked order" }.count

    return SettingsPanel(title: "Post-purchase monitor", symbol: "bag.badge.clock.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this monitor after a Wishlist item is ready to buy or has been bought externally. It keeps the local path visible: handoff, purchase recorded, Inbox confirmation, linked order, and operations follow-up.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Monitoring", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Need handoff", "\(needsHandoff)", needsHandoff == 0 ? .green : .purple),
          ("Awaiting", "\(awaitingConfirmation)", awaitingConfirmation == 0 ? .green : .orange),
          ("Review match", "\(matchReview)", matchReview == 0 ? .secondary : .teal),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases to monitor",
            detail: "Accepted purchase decisions, prepared handoffs, externally purchased items, and linked orders will appear here.",
            symbol: "bag.badge.clock.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPostPurchaseMonitorRow(entry: entry) {
                runWishlistPostPurchaseMonitorAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more monitored Wishlist purchase\(remaining == 1 ? "" : "s") are available in detailed rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This monitor is local only. It does not run background mailbox checks, contact sellers, log in, purchase, send mail, mutate mailbox messages, or update retailer/order systems.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPostPurchaseMonitorEntry(for item: WishlistItem) -> WishlistPostPurchaseMonitorEntry? {
    let decision = item.purchaseDecision
    let handoff = item.purchaseHandoff
    let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    let matches = store.suggestedWishlistOrderConfirmations(for: item)
    let isPurchaseRelated = decision?.reviewState == .accepted
      || handoff != nil
      || linkedOrder != nil
      || item.status.localizedCaseInsensitiveContains("purchase")
      || item.status.localizedCaseInsensitiveContains("order confirmation")
      || !matches.isEmpty

    guard isPurchaseRelated else { return nil }

    let stage: String
    let detail: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if handoff == nil {
      stage = "Prepare handoff"
      detail = "Purchase decision is ready enough for account, cost, and order-watch handoff."
      nextAction = "Prepare handoff"
      nextSymbol = "person.crop.circle.badge.checkmark"
      tone = .purple
      sortPriority = 10
    } else if linkedOrder != nil {
      stage = "Linked order"
      detail = "Wishlist purchase is linked to \(linkedOrder?.orderNumber ?? "an order"). Continue in Orders, Dispatch, and Tasks."
      nextAction = "Focus item"
      nextSymbol = "scope"
      tone = .green
      sortPriority = 50
    } else if !matches.isEmpty {
      stage = "Review confirmation"
      detail = "\(matches.count) Inbox confirmation candidate\(matches.count == 1 ? "" : "s") may link this purchase to an order."
      nextAction = "Use match"
      nextSymbol = "link.badge.plus"
      tone = .teal
      sortPriority = 20
    } else if handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true
                || item.status.localizedCaseInsensitiveContains("awaiting order")
                || item.status.localizedCaseInsensitiveContains("confirmation") {
      stage = "Awaiting confirmation"
      detail = "External purchase is recorded, but no matching Inbox confirmation is linked yet."
      nextAction = "Mark seen"
      nextSymbol = "envelope.badge.fill"
      tone = .orange
      sortPriority = 30
    } else {
      stage = "Ready to purchase"
      detail = "Handoff exists. Record the external purchase when done, then watch Inbox for confirmation."
      nextAction = "Purchased"
      nextSymbol = "bag.fill"
      tone = .blue
      sortPriority = 40
    }

    return WishlistPostPurchaseMonitorEntry(
      item: item,
      handoff: handoff,
      linkedOrder: linkedOrder,
      matches: matches,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistPostPurchaseMonitorAction(for entry: WishlistPostPurchaseMonitorEntry) {
    switch entry.stage {
    case "Prepare handoff":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Review confirmation":
      if let email = entry.matches.first {
        store.confirmWishlistOrderFromIntake(entry.item, email: email)
      } else {
        store.markWishlistOrderConfirmationSeen(entry.item)
      }
    case "Awaiting confirmation":
      store.markWishlistOrderConfirmationSeen(entry.item)
    case "Ready to purchase":
      store.recordWishlistPurchasedExternally(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseWatchCommandCentreEntries: [WishlistPurchaseWatchCommandCentreEntry] {
    let operationsEntries = Dictionary(uniqueKeysWithValues: wishlistPurchaseOperationsHandoffItems.map { ($0.item.id, $0) })
    return wishlistPostPurchaseMonitorEntries
      .map { monitor in
        wishlistPurchaseWatchCommandCentreEntry(for: monitor, operationsEntry: operationsEntries[monitor.item.id])
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseWatchCommandCentrePanel: some View {
    let entries = wishlistPurchaseWatchCommandCentreEntries
    let needHandoff = entries.filter { $0.stage == "Prepare handoff" }.count
    let readyToBuy = entries.filter { $0.stage == "Ready to record purchase" }.count
    let awaiting = entries.filter { $0.stage == "Awaiting confirmation" }.count
    let matches = entries.filter { $0.stage == "Match confirmation" }.count
    let operations = entries.filter { $0.stage == "Stage operations" }.count

    return SettingsPanel(title: "Purchase watch command centre", symbol: "binoculars.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("One local queue for Wishlist items after seller decision: prepare the purchase handoff, record the manual purchase, match Inbox/order confirmation, then stage receiving and dispatch records. This does not buy, monitor mail in the background, or contact retailers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Watching", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Need handoff", "\(needHandoff)", needHandoff == 0 ? .green : .purple),
          ("Ready to buy", "\(readyToBuy)", readyToBuy == 0 ? .green : .blue),
          ("Awaiting", "\(awaiting)", awaiting == 0 ? .green : .orange),
          ("Matches", "\(matches)", matches == 0 ? .secondary : .teal),
          ("Ops setup", "\(operations)", operations == 0 ? .green : .brown)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases are in watch mode",
            detail: "Accepted purchase decisions and handoffs appear here before and after the manual purchase is made outside ParcelOps.",
            symbol: "binoculars.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 400), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseWatchCommandCentreRow(entry: entry) {
                runWishlistPurchaseWatchCommandCentreAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase-watch item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Manual boundary: ParcelOps only records local handoff/watch state here. It does not purchase, pay, store retailer credentials, run background mailbox checks, mutate mailbox messages, or update external order systems.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseWatchCommandCentreEntry(
    for monitor: WishlistPostPurchaseMonitorEntry,
    operationsEntry: WishlistPurchaseOperationsHandoffEntry?
  ) -> WishlistPurchaseWatchCommandCentreEntry {
    let item = monitor.item
    let handoff = monitor.handoff
    let operationsGaps = operationsEntry?.gaps ?? []
    let operationCount = [
      operationsEntry?.inspectionCount ?? 0,
      operationsEntry?.receiptCount ?? 0,
      operationsEntry?.storageCount ?? 0,
      operationsEntry?.custodyCount ?? 0,
      operationsEntry?.labelCount ?? 0,
      operationsEntry?.scanCount ?? 0,
      operationsEntry?.manifestCount ?? 0,
      operationsEntry?.dispatchCount ?? 0
    ].reduce(0, +)

    let stage: String
    let detail: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if handoff == nil {
      stage = "Prepare handoff"
      detail = "Accepted purchase decision needs account, seller, expected order-signal, and manual buy checklist context."
      nextAction = "Prepare handoff"
      nextSymbol = "person.crop.circle.badge.checkmark"
      tone = .purple
      sortPriority = 0
    } else if monitor.linkedOrder != nil {
      if operationsGaps.isEmpty || operationCount >= 8 {
        stage = "Operations staged"
        detail = "Wishlist purchase is linked to \(monitor.linkedOrder?.orderNumber ?? "an order") and core local operations records are staged."
        nextAction = "Focus item"
        nextSymbol = "scope"
        tone = .green
        sortPriority = 50
      } else {
        stage = "Stage operations"
        detail = "Order is linked. Next operations gap: \(operationsGaps.first ?? "local receiving/dispatch setup")."
        nextAction = wishlistPurchaseOperationsActionTitle(for: operationsGaps)
        nextSymbol = wishlistPurchaseOperationsActionSymbol(for: operationsGaps)
        tone = .brown
        sortPriority = 40
      }
    } else if !monitor.matches.isEmpty {
      stage = "Match confirmation"
      detail = "\(monitor.matches.count) Inbox confirmation candidate\(monitor.matches.count == 1 ? "" : "s") can link this Wishlist purchase to an order."
      nextAction = "Use match"
      nextSymbol = "link.badge.plus"
      tone = .teal
      sortPriority = 10
    } else if handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true
                || item.status.localizedCaseInsensitiveContains("awaiting order")
                || item.status.localizedCaseInsensitiveContains("confirmation") {
      stage = "Awaiting confirmation"
      detail = "Manual purchase is recorded; Inbox/order confirmation still needs to be found or marked seen."
      nextAction = "Mark seen"
      nextSymbol = "envelope.badge.fill"
      tone = .orange
      sortPriority = 20
    } else {
      stage = "Ready to record purchase"
      detail = "Handoff exists. When the external checkout is done, record the purchase locally and watch for confirmation."
      nextAction = "Purchased"
      nextSymbol = "bag.fill"
      tone = .blue
      sortPriority = 30
    }

    return WishlistPurchaseWatchCommandCentreEntry(
      item: item,
      handoff: handoff,
      linkedOrder: monitor.linkedOrder,
      inboxMatchCount: monitor.matches.count,
      operationsGapCount: operationsGaps.count,
      operationRecordCount: operationCount,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistPurchaseWatchCommandCentreAction(for entry: WishlistPurchaseWatchCommandCentreEntry) {
    switch entry.stage {
    case "Prepare handoff":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Match confirmation":
      if let email = store.suggestedWishlistOrderConfirmations(for: entry.item).first {
        store.confirmWishlistOrderFromIntake(entry.item, email: email)
      } else {
        store.markWishlistOrderConfirmationSeen(entry.item)
      }
    case "Awaiting confirmation":
      store.markWishlistOrderConfirmationSeen(entry.item)
    case "Ready to record purchase":
      store.recordWishlistPurchasedExternally(entry.item)
    case "Stage operations":
      if let operationsEntry = wishlistPurchaseOperationsHandoffItems.first(where: { $0.item.id == entry.item.id }) {
        runWishlistPurchaseOperationsHandoffAction(for: operationsEntry)
      }
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseAccountLedgerItems: [WishlistPurchaseAccountLedgerEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPurchaseAccountLedgerEntry? in
        guard store.isActiveWishlistItem(item) else { return nil }
        let decision = item.purchaseDecision
        let handoff = item.purchaseHandoff
        let isPurchaseRelated = handoff != nil
          || decision?.reviewState == .accepted
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("order confirmation")
          || item.status.localizedCaseInsensitiveContains("purchased")
        guard isPurchaseRelated else { return nil }

        let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
          store.orders.first { $0.id == orderID }
        }
        let candidateCount = store.suggestedWishlistOrderConfirmations(for: item).count

        if handoff == nil {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: nil,
            linkedOrder: linkedOrder,
            candidateCount: candidateCount,
            stage: "Handoff needed",
            detail: "Prepare the local account/order-watch handoff before buying externally.",
            tone: .purple,
            actionTitle: "Prepare handoff",
            actionSymbol: "person.crop.circle.badge.checkmark",
            sortPriority: 1
          )
        }

        if linkedOrder == nil && candidateCount > 0 {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Confirmation candidates",
            detail: "Inbox has possible order confirmations. Review and link one before closing purchase follow-up.",
            tone: .teal,
            actionTitle: "Order seen",
            actionSymbol: "envelope.badge.fill",
            sortPriority: 2
          )
        }

        if linkedOrder == nil && (handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true || handoff?.orderWatchStatus.localizedCaseInsensitiveContains("watch") == true) {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Awaiting confirmation",
            detail: "External purchase has been recorded. Watch Inbox for an order confirmation from the selected seller/account.",
            tone: .orange,
            actionTitle: "Order seen",
            actionSymbol: "envelope.badge.fill",
            sortPriority: 3
          )
        }

        if linkedOrder == nil {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Ready for order watch",
            detail: "Handoff is staged. Record the external purchase when it happens, then watch for confirmation.",
            tone: .green,
            actionTitle: "Purchased",
            actionSymbol: "bag.fill",
            sortPriority: 4
          )
        }

        return WishlistPurchaseAccountLedgerEntry(
          item: item,
          handoff: handoff,
          linkedOrder: linkedOrder,
          candidateCount: candidateCount,
          stage: "Linked order",
          detail: "Wishlist purchase has a linked order trail. Keep the order open for dispatch and receipt follow-up.",
          tone: .green,
          actionTitle: "Focus item",
          actionSymbol: "scope",
          sortPriority: 5
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseApprovalPanel: some View {
    let records = store.wishlistPurchaseApprovalRecords.filter(store.isActiveWishlistPurchaseApprovalRecord).sorted { first, second in
      if first.reviewState == second.reviewState {
        return first.createdDate > second.createdDate
      }
      return first.reviewState == .needsReview
    }
    let approved = records.filter { $0.reviewState == .accepted || $0.approvalStatus.localizedCaseInsensitiveContains("approved") }.count
    let blocked = records.filter { $0.approvalStatus.localizedCaseInsensitiveContains("blocked") }.count
    let needsApproval = records.filter { $0.reviewState != .accepted && !$0.approvalStatus.localizedCaseInsensitiveContains("blocked") }.count
    let missingBudget = records.filter { record in
      record.budgetCode.localizedCaseInsensitiveContains("confirm")
        || record.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }.count

    return SettingsPanel(title: "Purchase approval gate", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Record the local approval, budget limit, approver, and payment-method readiness before a Wishlist item is treated as ready to buy. This is an operator gate only; ParcelOps still does not purchase, pay, check out, or connect to finance systems.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Approvals", "\(records.count)", records.isEmpty ? .secondary : .blue),
          ("Need approval", "\(needsApproval)", needsApproval == 0 ? .green : .orange),
          ("Approved", "\(approved)", approved == 0 ? .secondary : .green),
          ("Blocked", "\(blocked)", blocked == 0 ? .secondary : .red),
          ("Budget gaps", "\(missingBudget)", missingBudget == 0 ? .green : .purple)
        ])

        CompactActionRow {
          Button("Add approval", systemImage: "checkmark.seal") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistPurchaseApprovalRecord(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if records.isEmpty {
          MVPEmptyState(
            title: "No purchase approval records yet",
            detail: "Add an approval when a Wishlist item has a preferred seller and landed-cost evidence. Keep budget and payment confirmation as non-secret notes only.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(records.prefix(8)) { record in
              WishlistPurchaseApprovalRow(record: record) {
                store.markWishlistPurchaseApprovalApproved(record)
              } onBlock: {
                store.blockWishlistPurchaseApprovalRecord(record)
              } onRemove: {
                store.removeWishlistPurchaseApprovalRecord(record)
              } onTask: {
                store.createWishlistPurchaseApprovalRecordReviewTask(record)
              } onFocus: {
                wishlistSearchText = record.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .buy
              }
            }
          }

          let remaining = max(records.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase approval record\(remaining == 1 ? "" : "s") are available in local storage.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only boundary: approvals here are notes in ParcelOps JSON. No payment card, bank feed, finance platform, checkout, seller login, purchase order submission, or purchase automation is connected.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseLinkPanel: some View {
    let records = store.wishlistPurchaseLinkRecords.filter(store.isActiveWishlistPurchaseLinkRecord).sorted { first, second in
      if first.selectedForPurchase != second.selectedForPurchase {
        return first.selectedForPurchase
      }
      if first.reviewState == second.reviewState {
        return first.createdDate > second.createdDate
      }
      return first.reviewState == .needsReview
    }
    let selected = records.filter(\.selectedForPurchase).count
    let ready = records.filter { $0.reviewState == .accepted || $0.readinessStatus.localizedCaseInsensitiveContains("ready") }.count
    let blocked = records.filter { $0.readinessStatus.localizedCaseInsensitiveContains("blocked") }.count
    let missingTrust = records.filter { record in
      record.trustSummary.localizedCaseInsensitiveContains("needs")
        || record.trustSummary.localizedCaseInsensitiveContains("unknown")
        || record.trustSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }.count

    return SettingsPanel(title: "Purchase links", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Keep the best retailer/product links ready for a human to open outside ParcelOps. Each link records AUD total, postage, trust, account context, and readiness without opening checkout or buying.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Links", "\(records.count)", records.isEmpty ? .secondary : .blue),
          ("Selected", "\(selected)", selected == 0 ? .secondary : .green),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Blocked", "\(blocked)", blocked == 0 ? .secondary : .red),
          ("Trust gaps", "\(missingTrust)", missingTrust == 0 ? .green : .orange)
        ])

        CompactActionRow {
          Button("Add link", systemImage: "link.badge.plus") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistPurchaseLinkRecord(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if records.isEmpty {
          MVPEmptyState(
            title: "No purchase links yet",
            detail: "Add links after a seller option has been compared. A ready link is still manual: the operator opens it outside ParcelOps and completes any purchase elsewhere.",
            symbol: "link.badge.plus"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(records.prefix(8)) { record in
              WishlistPurchaseLinkRow(record: record) {
                store.markWishlistPurchaseLinkSelected(record)
              } onReady: {
                store.markWishlistPurchaseLinkReady(record)
              } onBlock: {
                store.blockWishlistPurchaseLinkRecord(record)
              } onRemove: {
                store.removeWishlistPurchaseLinkRecord(record)
              } onTask: {
                store.createWishlistPurchaseLinkRecordReviewTask(record)
              } onFocus: {
                wishlistSearchText = record.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .buy
              }
            }
          }

          let remaining = max(records.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase link record\(remaining == 1 ? "" : "s") are stored locally.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only boundary: ParcelOps stores product links and review notes only. It does not open browser pages, log into retailer accounts, place orders, pay, reserve stock, or monitor retailer pages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseAccountReadinessPanel: some View {
    let records = store.wishlistPurchaseAccountRecords.filter(store.isActiveWishlistPurchaseAccountRecord).sorted { first, second in
      if first.reviewState == second.reviewState {
        return first.createdDate > second.createdDate
      }
      return first.reviewState == .needsReview
    }
    let ready = records.filter { $0.reviewState == .accepted }.count
    let blocked = records.filter { $0.accountReadinessStatus.localizedCaseInsensitiveContains("blocked") }.count
    let missingPayment = records.filter { $0.paymentReadinessStatus.localizedCaseInsensitiveContains("not stored") || $0.paymentReadinessStatus.localizedCaseInsensitiveContains("confirm") }.count
    let needsReview = records.filter { $0.reviewState != .accepted }.count

    return SettingsPanel(title: "Purchase account readiness", symbol: "person.crop.circle.badge.checkmark") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Confirm the non-secret purchase context before buying outside ParcelOps: seller account label, payment readiness, delivery address, and expected order confirmation signals. No passwords, cards, checkout, or retailer login are stored.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Records", "\(records.count)", records.isEmpty ? .secondary : .blue),
          ("Need review", "\(needsReview)", needsReview == 0 ? .green : .orange),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Blocked", "\(blocked)", blocked == 0 ? .secondary : .red),
          ("Payment check", "\(missingPayment)", missingPayment == 0 ? .green : .purple)
        ])

        CompactActionRow {
          Button("Add account record", systemImage: "person.badge.plus") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistPurchaseAccountRecord(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if records.isEmpty {
          MVPEmptyState(
            title: "No purchase account records yet",
            detail: "Add one when a Wishlist item has a likely seller. This records non-secret readiness only; credentials and payment details stay outside ParcelOps.",
            symbol: "person.crop.circle.badge.checkmark"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(records.prefix(8)) { record in
              WishlistPurchaseAccountReadinessRow(record: record) {
                store.markWishlistPurchaseAccountReady(record)
              } onBlock: {
                store.blockWishlistPurchaseAccountRecord(record)
              } onRemove: {
                store.removeWishlistPurchaseAccountRecord(record)
              } onTask: {
                store.createWishlistPurchaseAccountRecordReviewTask(record)
              } onFocus: {
                wishlistSearchText = record.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .buy
              }
            }
          }

          let remaining = max(records.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase account record\(remaining == 1 ? "" : "s") are available in the local readiness ledger.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only boundary: this does not store passwords, app passwords, payment cards, billing credentials, auth tokens, retailer sessions, checkout data, or purchase actions.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseAccountLedgerPanel: some View {
    let entries = wishlistPurchaseAccountLedgerItems
    let needHandoff = entries.filter { $0.handoff == nil }.count
    let watching = entries.filter { $0.stage == "Awaiting confirmation" || $0.stage == "Ready for order watch" }.count
    let candidates = entries.filter { $0.candidateCount > 0 && $0.linkedOrder == nil }.count
    let linked = entries.filter { $0.linkedOrder != nil }.count

    return SettingsPanel(title: "Purchase account and order-watch ledger", symbol: "person.crop.circle.badge.clock.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Track the local trail from selected seller to account label, external purchase, expected confirmation signals, and linked order. This ledger does not log in, buy, send email, store payment details, or monitor mail in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Ledger items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Need handoff", "\(needHandoff)", needHandoff == 0 ? .green : .purple),
          ("Watching", "\(watching)", watching == 0 ? .secondary : .orange),
          ("Inbox candidates", "\(candidates)", candidates == 0 ? .secondary : .teal),
          ("Linked orders", "\(linked)", linked == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No purchase account ledger yet",
            detail: "Prepare a Wishlist purchase handoff or accept a purchase decision to start tracking account labels and order-confirmation watch locally.",
            symbol: "person.crop.circle.badge.clock.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 252 : 385), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseAccountLedgerRow(entry: entry) {
                runWishlistPurchaseAccountLedgerAction(for: entry)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(entry.item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more ledger item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func runWishlistPurchaseAccountLedgerAction(for entry: WishlistPurchaseAccountLedgerEntry) {
    if entry.handoff == nil {
      store.prepareWishlistPurchaseHandoff(entry.item)
    } else if entry.linkedOrder == nil && entry.stage == "Ready for order watch" {
      store.recordWishlistPurchasedExternally(entry.item)
    } else if entry.linkedOrder == nil {
      store.markWishlistOrderConfirmationSeen(entry.item)
    } else {
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistOrderConfirmationHandoffPanel: some View {
    let activeItems = store.activeWishlistItems
    let handoffItems = activeItems.filter { $0.purchaseHandoff != nil }
    let linkedItems = handoffItems.filter { $0.purchaseHandoff?.linkedOrderID != nil }
    let unlinkedItems = handoffItems.filter { $0.purchaseHandoff?.linkedOrderID == nil }
    let purchasedAwaiting = unlinkedItems.filter { item in
      item.purchaseHandoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true
        || item.status.localizedCaseInsensitiveContains("awaiting order")
        || item.status.localizedCaseInsensitiveContains("confirmation")
    }
    let candidateEntries = unlinkedItems.map { item in
      (item: item, matches: store.suggestedWishlistOrderConfirmations(for: item))
    }
    let withCandidates = candidateEntries.filter { !$0.matches.isEmpty }
    let leadingItem = withCandidates.first?.item ?? purchasedAwaiting.first ?? unlinkedItems.first

    return SettingsPanel(title: "Order confirmation handoff", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: withCandidates.isEmpty && purchasedAwaiting.isEmpty ? "envelope.badge.clock" : "link.badge.plus")
            .font(.title3)
            .foregroundStyle(withCandidates.isEmpty && purchasedAwaiting.isEmpty ? .blue : .teal)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(withCandidates.isEmpty ? "Watch for purchase confirmations" : "\(withCandidates.count) Wishlist purchase\(withCandidates.count == 1 ? "" : "s") have Inbox candidates")
              .font(.headline)
            Text(leadingItem.map { item in
              let matches = store.suggestedWishlistOrderConfirmations(for: item)
              if let first = matches.first {
                return "\(item.itemName): possible confirmation '\(first.subject)' is ready to review."
              }
              if item.purchaseHandoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
                return "\(item.itemName): purchase recorded externally; refresh/check Inbox and link the confirmation when it arrives."
              }
              return "\(item.itemName): handoff prepared; record external purchase when complete, then match the confirmation."
            } ?? "Prepare a purchase handoff before order confirmation matching becomes active.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(withCandidates.isEmpty ? "\(unlinkedItems.count) watching" : "\(withCandidates.count) candidates", color: withCandidates.isEmpty ? .orange : .green)
        }

        MetricStrip(items: [
          ("Handoffs", "\(handoffItems.count)", handoffItems.isEmpty ? .secondary : .blue),
          ("Awaiting", "\(purchasedAwaiting.count)", purchasedAwaiting.isEmpty ? .secondary : .orange),
          ("With candidates", "\(withCandidates.count)", withCandidates.isEmpty ? .secondary : .teal),
          ("Linked", "\(linkedItems.count)", linkedItems.isEmpty ? .secondary : .green),
          ("Unlinked", "\(unlinkedItems.count)", unlinkedItems.isEmpty ? .green : .purple)
        ])

        if handoffItems.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchase handoff yet",
            detail: "Accept a purchase decision or prepare a purchase handoff before ParcelOps can watch for a local Inbox/order confirmation.",
            symbol: "envelope.badge.shield.half.filled"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 235 : 340), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(candidateEntries.prefix(5), id: \.item.id) { entry in
              let item = entry.item
              let handoff = item.purchaseHandoff
              let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
                store.orders.first { $0.id == orderID }
              }
              let tone: Color = linkedOrder != nil ? .green : entry.matches.isEmpty ? .orange : .teal

              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: linkedOrder != nil ? "checkmark.seal.fill" : entry.matches.isEmpty ? "envelope.badge.clock" : "link.badge.plus")
                    .foregroundStyle(tone)
                    .frame(width: 20, height: 20)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(item.itemName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(handoff?.sellerName ?? item.storefront)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                  Spacer(minLength: 8)
                  Badge(linkedOrder != nil ? "Order linked" : entry.matches.isEmpty ? "Awaiting" : "\(entry.matches.count) match\(entry.matches.count == 1 ? "" : "es")", color: tone)
                }

                Text(linkedOrder.map { "Linked to \($0.orderNumber). Continue in Orders, Dispatch, and Tasks." } ?? (entry.matches.first.map { "Best candidate: \($0.subject)" } ?? "Expected: \(handoff?.expectedOrderSignals ?? "order confirmation, receipt, dispatch, or tracking")"))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(3)
                  .fixedSize(horizontal: false, vertical: true)

                CompactActionRow {
                  if let first = entry.matches.first {
                    Button("Use candidate", systemImage: "link.badge.plus") {
                      store.confirmWishlistOrderFromIntake(item, email: first)
                    }
                  } else if linkedOrder == nil {
                    Button("Mark seen", systemImage: "envelope.badge.fill") {
                      store.markWishlistOrderConfirmationSeen(item)
                    }
                  }
                  Button("Task", systemImage: "checklist") {
                    store.createWishlistPurchaseHandoffReviewTask(item)
                  }
                  Button("Focus", systemImage: "scope") {
                    wishlistSearchText = item.itemName
                    selectedWorkflowFocus = .watch
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(tone.opacity(0.16), lineWidth: 1)
              )
            }
          }
        }

        Text("Confirmation boundary: this matches existing local Inbox/order records only. It does not fetch mail, mark email read, contact sellers, open retailer accounts, purchase, pay, send notifications, or monitor in the background.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistOrderWatchRecordsPanel: some View {
    let records = store.activeWishlistOrderWatchRecords.sorted { first, second in
      if (first.linkedOrderID == nil) != (second.linkedOrderID == nil) {
        return first.linkedOrderID == nil
      }
      if first.reviewState == second.reviewState {
        return first.createdDate > second.createdDate
      }
      return first.reviewState == .needsReview
    }
    let waiting = records.filter { $0.linkedOrderID == nil && !$0.watchStatus.localizedCaseInsensitiveContains("blocked") }.count
    let linked = records.filter { $0.linkedOrderID != nil }.count
    let blocked = records.filter { $0.watchStatus.localizedCaseInsensitiveContains("blocked") }.count
    let needsReview = records.filter { $0.reviewState != .accepted }.count
    let candidateMatches = records.reduce(0) { total, record in
      guard let itemID = record.wishlistItemID,
            let item = store.wishlistItems.first(where: { $0.id == itemID }) else {
        return total
      }
      return total + store.suggestedWishlistOrderConfirmations(for: item).count
    }

    return SettingsPanel(title: "Order watch rules", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Track what should appear after a human buys externally: seller, account label, expected confirmation wording, mailbox/source, and local order link. Checks are manual only; no background polling or mailbox mutation runs here.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Rules", "\(records.count)", records.isEmpty ? .secondary : .blue),
          ("Waiting", "\(waiting)", waiting == 0 ? .secondary : .orange),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .green),
          ("Inbox candidates", "\(candidateMatches)", candidateMatches == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .secondary : .red),
          ("Need review", "\(needsReview)", needsReview == 0 ? .green : .purple)
        ])

        CompactActionRow {
          Button("Add watch rule", systemImage: "envelope.badge.shield.half.filled") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistOrderWatchRecord(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          Button("Check open rules", systemImage: "magnifyingglass.circle") {
            store.checkOpenWishlistOrderWatchRecords()
          }
          .disabled(waiting == 0)
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if records.isEmpty {
          MVPEmptyState(
            title: "No order watch rules yet",
            detail: "Add a watch rule after a purchase link or handoff exists. Then refresh the relevant mailbox manually and link any captured order confirmation.",
            symbol: "envelope.badge.shield.half.filled"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 430), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(records.prefix(8)) { record in
              let item = record.wishlistItemID.flatMap { itemID in
                store.wishlistItems.first { $0.id == itemID }
              }
              let linkedOrder = record.linkedOrderID.flatMap { orderID in
                store.orders.first { $0.id == orderID }
              }
              WishlistOrderWatchRecordRow(
                record: record,
                store: store,
                linkedOrder: linkedOrder,
                candidateMatches: item.map { store.suggestedWishlistOrderConfirmations(for: $0) } ?? []
              ) {
                store.checkWishlistOrderWatchRecord(record)
              } onReviewed: {
                store.markWishlistOrderWatchRecordReviewed(record)
              } onBlock: {
                store.blockWishlistOrderWatchRecord(record)
              } onRemove: {
                store.removeWishlistOrderWatchRecord(record)
              } onTask: {
                store.createWishlistOrderWatchRecordReviewTask(record)
              } onFocus: {
                wishlistSearchText = record.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .watch
              } onUseConfirmation: { email in
                if let item {
                  store.confirmWishlistOrderFromIntake(item, email: email)
                }
              }
            }
          }

          let remaining = max(records.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more order watch rule\(remaining == 1 ? "" : "s") are stored locally.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only boundary: this stores expected order-confirmation signals and manual check status. It does not poll mailboxes, scrape retailers, mark email read, place orders, pay, or send messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistOrderConfirmationMatchingEntries: [WishlistPostPurchaseOrderWatchEntry] {
    wishlistPostPurchaseOrderWatchEntries
      .filter { entry in
        !entry.matches.isEmpty
          || entry.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased")
          || entry.item.status.localizedCaseInsensitiveContains("awaiting order")
          || entry.item.status.localizedCaseInsensitiveContains("confirmation")
      }
      .sorted { first, second in
        if first.matches.count == second.matches.count {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.matches.count > second.matches.count
      }
  }

  private var wishlistOrderConfirmationMatchPacketPanel: some View {
    let entries = wishlistPostPurchaseOrderWatchEntries
    let readyToWatch = entries.filter { $0.stage == "Ready to watch" }.count
    let awaiting = entries.filter { $0.stage == "Awaiting confirmation" }.count
    let withCandidates = entries.filter { !$0.matches.isEmpty }.count
    let candidateRows = entries.reduce(0) { $0 + $1.matches.count }

    return SettingsPanel(title: "Order confirmation match packet", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Prepare the local matching packet before and after an external Wishlist purchase. It tells the operator what confirmation signals to expect, how many Inbox candidates exist, and what to do next without fetching mail or touching retailer accounts.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Watching", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(readyToWatch)", readyToWatch == 0 ? .secondary : .green),
          ("Awaiting", "\(awaiting)", awaiting == 0 ? .green : .orange),
          ("With candidates", "\(withCandidates)", withCandidates == 0 ? .secondary : .teal),
          ("Candidate rows", "\(candidateRows)", candidateRows == 0 ? .secondary : .purple)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist order confirmations are being watched",
            detail: "Prepare a purchase handoff or record an external purchase before order confirmation matching becomes active.",
            symbol: "envelope.badge.shield.half.filled"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: entry.matches.isEmpty ? "envelope.badge.clock" : "link.badge.plus")
                    .foregroundStyle(entry.tone)
                    .frame(width: 24)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(entry.item.itemName)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(entry.handoff.sellerName)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                  Spacer(minLength: 8)
                  Badge(entry.stage, color: entry.tone)
                }

                Text(wishlistOrderConfirmationMatchPacketDetail(for: entry))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                CompactMetadataGrid(minimumWidth: 130) {
                  Badge(entry.handoff.accountLabel, color: .blue)
                  Badge(entry.handoff.purchaseStatus, color: entry.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") ? .green : .orange)
                  Badge(entry.matches.isEmpty ? "No candidates" : "\(entry.matches.count) candidate\(entry.matches.count == 1 ? "" : "s")", color: entry.matches.isEmpty ? .secondary : .teal)
                  Badge(entry.handoff.linkedOrderID == nil ? "No linked order" : "Order linked", color: entry.handoff.linkedOrderID == nil ? .orange : .green)
                }

                Text("Expected signals: \(wishlistOrderConfirmationExpectedSignals(for: entry))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(3)
                  .fixedSize(horizontal: false, vertical: true)

                if let first = entry.matches.first {
                  HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "envelope.open.fill")
                      .foregroundStyle(.teal)
                      .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                      Text("Best Inbox candidate")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                      Text("\(first.subject) • \(first.detectedOrderNumber) • \(first.detectedTrackingNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }
                  }
                }

                CompactActionRow {
                  if let first = entry.matches.first {
                    Button("Use candidate", systemImage: "link.badge.plus") {
                      store.confirmWishlistOrderFromIntake(entry.item, email: first)
                    }
                  }
                  Button(entry.matches.isEmpty ? "Mark seen" : "Review match", systemImage: "envelope.badge.fill") {
                    if let first = entry.matches.first {
                      store.confirmWishlistOrderFromIntake(entry.item, email: first)
                    } else {
                      store.markWishlistOrderConfirmationSeen(entry.item)
                    }
                  }
                  Button("Task", systemImage: "checklist") {
                    store.createWishlistPurchaseHandoffReviewTask(entry.item)
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(10)
              .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Match packets are local guidance only. ParcelOps does not fetch mail here, monitor in the background, log in to seller accounts, open checkout pages, send messages, or mutate mailbox messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistOrderConfirmationMatchPacketDetail(for entry: WishlistPostPurchaseOrderWatchEntry) -> String {
    if !entry.matches.isEmpty {
      return "\(entry.matches.count) Inbox candidate\(entry.matches.count == 1 ? "" : "s") match seller, item, order, tracking, receipt, or dispatch signals. Use the candidate only after checking it is the real confirmation."
    }
    if entry.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") || entry.item.status.localizedCaseInsensitiveContains("awaiting order") {
      return "External purchase is recorded, but no imported Inbox confirmation matches yet. Refresh mailbox manually, then review candidates here."
    }
    return "Purchase handoff is ready. After the human buys externally, record the purchase and watch for matching Inbox order confirmation."
  }

  private func wishlistOrderConfirmationExpectedSignals(for entry: WishlistPostPurchaseOrderWatchEntry) -> String {
    let raw = [
      entry.handoff.expectedOrderSignals,
      entry.handoff.sellerName,
      entry.item.itemName,
      entry.item.storefront,
      entry.item.purchaseDecision?.selectedSellerName,
      entry.item.purchaseDecision?.totalAUDSummary,
      entry.item.purchaseDecision?.postageSummary
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && !$0.isPlaceholderValidationValue }

    var seenSignals = Set<String>()
    let unique = raw.filter { signal in
      let key = signal.localizedLowercase
      guard !seenSignals.contains(key) else { return false }
      seenSignals.insert(key)
      return true
    }
    return unique.prefix(5).joined(separator: " | ").isEmpty
      ? "seller, item name, order number, tracking number, receipt, dispatch, or delivery wording"
      : unique.prefix(5).joined(separator: " | ")
  }

  private var wishlistOrderConfirmationMatchingPanel: some View {
    let entries = wishlistOrderConfirmationMatchingEntries
    let withMatches = entries.filter { !$0.matches.isEmpty }.count
    let awaiting = entries.filter { $0.matches.isEmpty }.count
    let totalMatches = entries.reduce(0) { $0 + $1.matches.count }
    let purchased = entries.filter { $0.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") }.count

    return SettingsPanel(title: "Wishlist order confirmation matching", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review imported Inbox confirmations against Wishlist purchases. Use a matching intake row to create or link the local order, or mark confirmation seen when the purchase was checked outside ParcelOps.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Purchases", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("With matches", "\(withMatches)", withMatches == 0 ? .secondary : .green),
          ("Match rows", "\(totalMatches)", totalMatches == 0 ? .secondary : .teal),
          ("Awaiting", "\(awaiting)", awaiting == 0 ? .green : .orange),
          ("Purchased", "\(purchased)", purchased == 0 ? .secondary : .purple)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist confirmations need matching",
            detail: "After an external Wishlist purchase is recorded, matching Inbox confirmations will appear here for local order linking.",
            symbol: "link.badge.plus"
          )
        } else {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(6)) { entry in
              WishlistOrderConfirmationMatchReviewRow(entry: entry) { email in
                store.confirmWishlistOrderFromIntake(entry.item, email: email)
              } onMarkSeen: {
                if let email = entry.matches.first {
                  store.confirmWishlistOrderFromIntake(entry.item, email: email)
                } else {
                  store.markWishlistOrderConfirmationSeen(entry.item)
                }
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more confirmation matching item\(remaining == 1 ? "" : "s") are available in the post-purchase watch below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Matching is local-only. It does not fetch mail, mark messages read, contact sellers, log in, mutate orders externally, or monitor in the background.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPostPurchaseOrderWatchEntries: [WishlistPostPurchaseOrderWatchEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPostPurchaseOrderWatchEntry? in
        guard store.isActiveWishlistItem(item) else { return nil }
        guard let handoff = item.purchaseHandoff,
              handoff.linkedOrderID == nil else { return nil }
        let matches = store.suggestedWishlistOrderConfirmations(for: item)
        let isPurchased = handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased")
          || item.status.localizedCaseInsensitiveContains("awaiting order")
          || item.status.localizedCaseInsensitiveContains("confirmation")
        let stage = matches.isEmpty
          ? (isPurchased ? "Awaiting confirmation" : "Ready to watch")
          : "Match review"
        let tone: Color = matches.isEmpty ? (isPurchased ? .orange : .blue) : .green
        let detail = matches.isEmpty
          ? "No imported Inbox confirmation currently matches this purchase handoff."
          : "\(matches.count) imported Inbox row\(matches.count == 1 ? "" : "s") may confirm this purchase."
        let priority = matches.isEmpty ? (isPurchased ? 2 : 3) : 1
        return WishlistPostPurchaseOrderWatchEntry(
          item: item,
          handoff: handoff,
          matches: matches,
          stage: stage,
          detail: detail,
          tone: tone,
          sortPriority: priority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          if first.matches.count == second.matches.count {
            return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
          }
          return first.matches.count > second.matches.count
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPostPurchaseOrderWatchPanel: some View {
    let entries = wishlistPostPurchaseOrderWatchEntries
    let matched = entries.filter { !$0.matches.isEmpty }.count
    let purchased = entries.filter { $0.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") }.count
    let ready = entries.filter { $0.matches.isEmpty && !$0.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") }.count

    return SettingsPanel(title: "Post-purchase order watch", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue after a Wishlist item is bought outside ParcelOps. It keeps order-confirmation follow-up visible until a local Inbox confirmation or order is linked.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Watching", "\(entries.count)", entries.isEmpty ? .secondary : .orange),
          ("Inbox matches", "\(matched)", matched == 0 ? .secondary : .green),
          ("Purchased", "\(purchased)", purchased == 0 ? .secondary : .orange),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .blue)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases waiting for order confirmation",
            detail: "When an external purchase is recorded, it will appear here until an Inbox confirmation or local order is linked.",
            symbol: "envelope.badge.shield.half.filled"
          )
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(entries.prefix(6)) { entry in
              WishlistOrderWatchMatchRow(
                item: entry.item,
                matches: Array(entry.matches.prefix(3))
              ) { email in
                store.confirmWishlistOrderFromIntake(entry.item, email: email)
              } onMarkSeen: {
                if let email = entry.matches.first {
                  store.confirmWishlistOrderFromIntake(entry.item, email: email)
                } else {
                  store.markWishlistOrderConfirmationSeen(entry.item)
                }
              }
            }
          }

          let remaining = max(entries.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more post-purchase watch item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Manual and local only. This queue does not monitor mailboxes in the background, contact retailers, log in to accounts, store payment data, or mutate mailbox messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseOperationsHandoffItems: [WishlistPurchaseOperationsHandoffEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPurchaseOperationsHandoffEntry? in
        guard store.isActiveWishlistItem(item) else { return nil }
        guard item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("order confirmation")
          || item.status.localizedCaseInsensitiveContains("awaiting order")
          || item.status.localizedCaseInsensitiveContains("purchased")
          || item.purchaseDecision?.reviewState == .accepted else { return nil }

        let orderLinked = item.purchaseHandoff?.linkedOrderID != nil
        let inspectionCount = store.suggestedReceivingInspections(for: item).count
        let receiptCount = store.suggestedInventoryReceipts(for: item).count
        let storageCount = store.suggestedStorageLocations(for: item).count
        let custodyCount = store.suggestedCustodyRecords(for: item).count
        let labelCount = store.suggestedLabelReferenceRecords(for: item).count
        let scanCount = store.suggestedScanSessionRecords(for: item).count
        let manifestCount = store.suggestedShipmentManifestRecords(for: item).count
        let dispatchCount = store.suggestedDispatchReadinessChecklists(for: item).count

        var gaps: [String] = []
        if item.purchaseHandoff == nil { gaps.append("handoff") }
        if !orderLinked { gaps.append("order") }
        if inspectionCount == 0 { gaps.append("receiving") }
        if receiptCount == 0 { gaps.append("inventory") }
        if storageCount == 0 { gaps.append("storage") }
        if custodyCount == 0 { gaps.append("custody") }
        if labelCount == 0 { gaps.append("label") }
        if scanCount == 0 { gaps.append("manual check") }
        if manifestCount == 0 { gaps.append("manifest") }
        if dispatchCount == 0 { gaps.append("dispatch") }

        let stage: String
        let detail: String
        let tone: Color
        let actionTitle: String
        let actionSymbol: String
        let priority: Int

        if item.purchaseHandoff == nil {
          stage = "Handoff first"
          detail = "Prepare the purchase handoff before staging receiving, storage, custody, or dispatch records."
          tone = .purple
          actionTitle = "Prepare handoff"
          actionSymbol = "person.crop.circle.badge.checkmark"
          priority = 1
        } else if !orderLinked {
          stage = "Order link needed"
          detail = "Link an order confirmation before this can become a clean receiving and dispatch trail."
          tone = .orange
          actionTitle = "Order seen"
          actionSymbol = "envelope.badge.fill"
          priority = 2
        } else if !gaps.isEmpty {
          stage = "Ops setup gaps"
          detail = "Create the next local downstream record: \(gaps.prefix(3).joined(separator: ", "))."
          tone = .teal
          actionTitle = wishlistPurchaseOperationsActionTitle(for: gaps)
          actionSymbol = wishlistPurchaseOperationsActionSymbol(for: gaps)
          priority = 3
        } else {
          stage = "Ops trail ready"
          detail = "Order, receiving, storage, custody, label, manual check, manifest, and dispatch records are all staged locally."
          tone = .green
          actionTitle = "Focus item"
          actionSymbol = "scope"
          priority = 4
        }

        return WishlistPurchaseOperationsHandoffEntry(
          item: item,
          linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in store.orders.first { $0.id == orderID } },
          stage: stage,
          detail: detail,
          gaps: gaps,
          inspectionCount: inspectionCount,
          receiptCount: receiptCount,
          storageCount: storageCount,
          custodyCount: custodyCount,
          labelCount: labelCount,
          scanCount: scanCount,
          manifestCount: manifestCount,
          dispatchCount: dispatchCount,
          tone: tone,
          actionTitle: actionTitle,
          actionSymbol: actionSymbol,
          sortPriority: priority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          if first.gaps.count == second.gaps.count {
            return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
          }
          return first.gaps.count > second.gaps.count
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseOperationsHandoffPanel: some View {
    let entries = wishlistPurchaseOperationsHandoffItems
    let orderGaps = entries.filter { $0.gaps.contains("order") }.count
    let receivingGaps = entries.filter { $0.gaps.contains("receiving") || $0.gaps.contains("inventory") }.count
    let custodyGaps = entries.filter { $0.gaps.contains("storage") || $0.gaps.contains("custody") || $0.gaps.contains("label") || $0.gaps.contains("manual check") }.count
    let dispatchGaps = entries.filter { $0.gaps.contains("manifest") || $0.gaps.contains("dispatch") }.count

    return SettingsPanel(title: "Purchase-to-operations handoff", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        Text("After a Wishlist item is bought and confirmed, use this panel to stage the local receiving, inventory, storage, custody, label, manual verification, manifest, and dispatch readiness trail.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Handoff items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Order gaps", "\(orderGaps)", orderGaps == 0 ? .green : .orange),
          ("Receiving gaps", "\(receivingGaps)", receivingGaps == 0 ? .green : .teal),
          ("Custody gaps", "\(custodyGaps)", custodyGaps == 0 ? .green : .purple),
          ("Dispatch gaps", "\(dispatchGaps)", dispatchGaps == 0 ? .green : .brown)
        ])

        CompactActionRow {
          Button("Stage next records", systemImage: "wand.and.stars") {
            stageNextWishlistOperationsRecords(for: Array(entries.prefix(8)))
          }
          .disabled(!entries.contains { !$0.gaps.isEmpty })
          Button("Check closure readiness", systemImage: "checkmark.seal.text.page.fill") {
            store.checkWishlistOperationsClosureReadinessBatch()
          }
          .disabled(entries.isEmpty)
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No purchase-to-operations handoff items yet",
            detail: "Items appear here after a purchase decision, purchase handoff, or order-confirmation state exists.",
            symbol: "arrow.triangle.branch"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 252 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseOperationsHandoffRow(entry: entry, store: store) {
                runWishlistPurchaseOperationsHandoffAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more operations handoff item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local planning only. This panel does not book carriers, print labels, scan items, access warehouses, contact retailers, mutate mailboxes, or run background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseOperationsActionTitle(for gaps: [String]) -> String {
    if gaps.contains("handoff") { return "Handoff" }
    if gaps.contains("order") { return "Order seen" }
    if gaps.contains("receiving") { return "Receiving" }
    if gaps.contains("inventory") { return "Inventory" }
    if gaps.contains("storage") { return "Storage" }
    if gaps.contains("custody") { return "Custody" }
    if gaps.contains("label") { return "Label" }
    if gaps.contains("manual check") { return "Manual check" }
    if gaps.contains("manifest") { return "Manifest" }
    if gaps.contains("dispatch") { return "Dispatch" }
    return "Focus item"
  }

  private func wishlistPurchaseOperationsActionSymbol(for gaps: [String]) -> String {
    if gaps.contains("handoff") { return "person.crop.circle.badge.checkmark" }
    if gaps.contains("order") { return "envelope.badge.fill" }
    if gaps.contains("receiving") { return "checkmark.seal.fill" }
    if gaps.contains("inventory") { return "shippingbox.and.arrow.backward.fill" }
    if gaps.contains("storage") { return "archivebox.fill" }
    if gaps.contains("custody") { return "person.2.badge.gearshape.fill" }
    if gaps.contains("label") { return "tag.square.fill" }
    if gaps.contains("manual check") { return "checklist.checked" }
    if gaps.contains("manifest") { return "paperplane.fill" }
    if gaps.contains("dispatch") { return "checkmark.rectangle.stack.fill" }
    return "scope"
  }

  private func runWishlistPurchaseOperationsHandoffAction(for entry: WishlistPurchaseOperationsHandoffEntry) {
    let gaps = entry.gaps
    if gaps.contains("handoff") {
      store.prepareWishlistPurchaseHandoff(entry.item)
    } else if gaps.contains("order") {
      if let email = store.suggestedWishlistOrderConfirmations(for: entry.item).first {
        store.confirmWishlistOrderFromIntake(entry.item, email: email)
      } else {
        store.markWishlistOrderConfirmationSeen(entry.item)
      }
    } else if gaps.contains("receiving") {
      store.createWishlistReceivingInspection(entry.item)
    } else if gaps.contains("inventory") {
      store.createWishlistInventoryReceipt(entry.item)
    } else if gaps.contains("storage") {
      store.createWishlistStorageLocation(entry.item)
    } else if gaps.contains("custody") {
      store.createWishlistCustodyRecord(entry.item)
    } else if gaps.contains("label") {
      store.createWishlistLabelReference(entry.item)
    } else if gaps.contains("manual check") {
      store.createWishlistScanSession(entry.item)
    } else if gaps.contains("manifest") {
      store.createWishlistShipmentManifest(entry.item)
    } else if gaps.contains("dispatch") {
      store.createWishlistDispatchReadinessChecklist(entry.item)
    } else {
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private func stageNextWishlistOperationsRecords(for entries: [WishlistPurchaseOperationsHandoffEntry]) {
    entries
      .filter { !$0.gaps.isEmpty }
      .forEach(runWishlistPurchaseOperationsHandoffAction)
  }

  private var wishlistLinkedOrderOperationsChecklistEntries: [WishlistLinkedOrderOperationsChecklistEntry] {
    wishlistPurchaseOperationsHandoffItems
      .filter { $0.linkedOrder != nil || !$0.gaps.contains("order") }
      .map(wishlistLinkedOrderOperationsChecklistEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistLinkedOrderOperationsChecklistPanel: some View {
    let entries = wishlistLinkedOrderOperationsChecklistEntries
    let receiving = entries.filter { $0.stage == "Receiving setup" }.count
    let inventory = entries.filter { $0.stage == "Inventory and storage" }.count
    let custody = entries.filter { $0.stage == "Custody and verification" }.count
    let dispatch = entries.filter { $0.stage == "Dispatch setup" }.count
    let complete = entries.filter { $0.stage == "Operations trail staged" }.count

    return SettingsPanel(title: "Linked order operations checklist", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Once a Wishlist purchase has a local order trail, this checklist shows the next local operations record to stage: receiving, inventory, storage, custody, labels, manual verification, manifest, and dispatch readiness.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Receiving", "\(receiving)", receiving == 0 ? .green : .teal),
          ("Inventory", "\(inventory)", inventory == 0 ? .green : .purple),
          ("Custody", "\(custody)", custody == 0 ? .green : .orange),
          ("Dispatch", "\(dispatch)", dispatch == 0 ? .green : .brown),
          ("Complete", "\(complete)", complete == 0 ? .secondary : .green)
        ])

        CompactActionRow {
          Button("Stage next records", systemImage: "wand.and.stars") {
            stageNextWishlistLinkedOrderOperationsRecords(for: Array(entries.prefix(8)))
          }
          .disabled(!entries.contains { $0.phaseChecks.contains { !$0.1 } })
          Button("Closure check", systemImage: "checkmark.seal.text.page.fill") {
            store.checkWishlistOperationsClosureReadinessBatch()
          }
          .disabled(entries.isEmpty)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No linked Wishlist orders need operations setup",
            detail: "Link or mark a Wishlist order confirmation first. Then receiving, storage, custody, label, manual check, and dispatch setup appears here.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 410), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistLinkedOrderOperationsChecklistRow(entry: entry, store: store) {
                runWishlistLinkedOrderOperationsChecklistAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more linked-order operations item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Checklist actions create local records only. They do not receive stock, scan hardware, print labels, book carriers, contact sellers, update external systems, or mutate mailboxes.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistLinkedOrderOperationsChecklistEntry(for entry: WishlistPurchaseOperationsHandoffEntry) -> WishlistLinkedOrderOperationsChecklistEntry {
    let receivingDone = entry.inspectionCount > 0
    let inventoryDone = entry.receiptCount > 0
    let storageDone = entry.storageCount > 0
    let custodyDone = entry.custodyCount > 0
    let labelDone = entry.labelCount > 0
    let manualCheckDone = entry.scanCount > 0
    let manifestDone = entry.manifestCount > 0
    let dispatchDone = entry.dispatchCount > 0

    let stage: String
    let detail: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if !receivingDone {
      stage = "Receiving setup"
      detail = "Stage a local receiving inspection before stock, storage, custody, or dispatch work."
      nextAction = "Receiving"
      nextSymbol = "checkmark.seal.fill"
      tone = .teal
      sortPriority = 10
    } else if !inventoryDone || !storageDone {
      stage = "Inventory and storage"
      detail = !inventoryDone ? "Create the inventory receipt next." : "Create the storage location/bin reference next."
      nextAction = !inventoryDone ? "Inventory" : "Storage"
      nextSymbol = !inventoryDone ? "shippingbox.and.arrow.backward.fill" : "archivebox.fill"
      tone = .purple
      sortPriority = 20
    } else if !custodyDone || !labelDone || !manualCheckDone {
      stage = "Custody and verification"
      if !custodyDone {
        detail = "Create the local custody chain record."
        nextAction = "Custody"
        nextSymbol = "person.2.badge.gearshape.fill"
      } else if !labelDone {
        detail = "Create the local label/reference placeholder."
        nextAction = "Label"
        nextSymbol = "tag.square.fill"
      } else {
        detail = "Create the local manual verification/scan-session placeholder."
        nextAction = "Manual check"
        nextSymbol = "checklist.checked"
      }
      tone = .orange
      sortPriority = 30
    } else if !manifestDone || !dispatchDone {
      stage = "Dispatch setup"
      detail = !manifestDone ? "Create the shipment manifest next." : "Create the dispatch readiness checklist next."
      nextAction = !manifestDone ? "Manifest" : "Dispatch"
      nextSymbol = !manifestDone ? "paperplane.fill" : "checkmark.rectangle.stack.fill"
      tone = .brown
      sortPriority = 40
    } else {
      stage = "Operations trail staged"
      detail = "Core local receiving, stock, custody, label, manual check, manifest, and dispatch records are staged."
      nextAction = "Focus item"
      nextSymbol = "scope"
      tone = .green
      sortPriority = 50
    }

    let phaseChecks: [(String, Bool)] = [
      ("Receiving", receivingDone),
      ("Inventory", inventoryDone),
      ("Storage", storageDone),
      ("Custody", custodyDone),
      ("Label", labelDone),
      ("Manual check", manualCheckDone),
      ("Manifest", manifestDone),
      ("Dispatch", dispatchDone)
    ]

    return WishlistLinkedOrderOperationsChecklistEntry(
      item: entry.item,
      linkedOrder: entry.linkedOrder,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      phaseChecks: phaseChecks,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistLinkedOrderOperationsChecklistAction(for entry: WishlistLinkedOrderOperationsChecklistEntry) {
    switch entry.stage {
    case "Receiving setup":
      store.createWishlistReceivingInspection(entry.item)
    case "Inventory and storage":
      if entry.phaseChecks.first(where: { $0.0 == "Inventory" })?.1 == false {
        store.createWishlistInventoryReceipt(entry.item)
      } else {
        store.createWishlistStorageLocation(entry.item)
      }
    case "Custody and verification":
      if entry.phaseChecks.first(where: { $0.0 == "Custody" })?.1 == false {
        store.createWishlistCustodyRecord(entry.item)
      } else if entry.phaseChecks.first(where: { $0.0 == "Label" })?.1 == false {
        store.createWishlistLabelReference(entry.item)
      } else {
        store.createWishlistScanSession(entry.item)
      }
    case "Dispatch setup":
      if entry.phaseChecks.first(where: { $0.0 == "Manifest" })?.1 == false {
        store.createWishlistShipmentManifest(entry.item)
      } else {
        store.createWishlistDispatchReadinessChecklist(entry.item)
      }
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private func stageNextWishlistLinkedOrderOperationsRecords(for entries: [WishlistLinkedOrderOperationsChecklistEntry]) {
    entries
      .filter { $0.phaseChecks.contains { !$0.1 } }
      .forEach(runWishlistLinkedOrderOperationsChecklistAction)
  }

  private var wishlistLinkedOrderFollowUpDashboardEntries: [WishlistLinkedOrderFollowUpDashboardEntry] {
    wishlistLinkedOrderOperationsChecklistEntries
      .compactMap { checklist -> WishlistLinkedOrderFollowUpDashboardEntry? in
        guard let linkedOrder = checklist.linkedOrder else { return nil }
        let openTasks = store.reviewTasks.filter { task in
          task.linkedEntityType == .wishlistItem
            && task.linkedEntityID == checklist.item.id.uuidString
            && task.status != .completed
        }
        let missingPhases = checklist.phaseChecks.filter { !$0.1 }.map(\.0)
        let hasTracking = !linkedOrder.trackingNumber.isPlaceholderValidationValue
          && !linkedOrder.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dispatchReady = checklist.phaseChecks.first(where: { $0.0 == "Dispatch" })?.1 == true
        let receivingReady = checklist.phaseChecks.first(where: { $0.0 == "Receiving" })?.1 == true
        let manifestReady = checklist.phaseChecks.first(where: { $0.0 == "Manifest" })?.1 == true

        let stage: String
        let detail: String
        let nextAction: String
        let nextSymbol: String
        let tone: Color
        let sortPriority: Int

        if !hasTracking {
          stage = "Tracking needs review"
          detail = "Linked order exists, but tracking is still blank or placeholder. Confirm tracking from Inbox/order source before dispatch follow-up."
          nextAction = "Task"
          nextSymbol = "checklist"
          tone = .orange
          sortPriority = 10
        } else if !receivingReady {
          stage = "Receiving follow-up"
          detail = "Tracking exists. Stage or review receiving before inventory, storage, custody, and dispatch."
          nextAction = "Receiving"
          nextSymbol = "checkmark.seal.fill"
          tone = .teal
          sortPriority = 20
        } else if !manifestReady || !dispatchReady {
          stage = "Dispatch follow-up"
          detail = !manifestReady ? "Receiving path has started. Create the shipment manifest placeholder next." : "Manifest exists. Create the dispatch readiness checklist next."
          nextAction = !manifestReady ? "Manifest" : "Dispatch"
          nextSymbol = !manifestReady ? "paperplane.fill" : "checkmark.rectangle.stack.fill"
          tone = .brown
          sortPriority = 30
        } else if !openTasks.isEmpty {
          stage = "Tasks open"
          detail = "\(openTasks.count) local follow-up task\(openTasks.count == 1 ? "" : "s") remain before closure."
          nextAction = "Open task"
          nextSymbol = "checklist"
          tone = .purple
          sortPriority = 40
        } else if !missingPhases.isEmpty {
          stage = "Ops gaps"
          detail = "Missing \(missingPhases.prefix(3).joined(separator: ", ")) before local closure."
          nextAction = checklist.nextAction
          nextSymbol = checklist.nextSymbol
          tone = .orange
          sortPriority = 50
        } else {
          stage = "Ready for closure"
          detail = "Tracking, receiving, dispatch, and follow-up task context are locally ready for closure review."
          nextAction = "Closure check"
          nextSymbol = "checkmark.seal.text.page.fill"
          tone = .green
          sortPriority = 60
        }

        return WishlistLinkedOrderFollowUpDashboardEntry(
          checklist: checklist,
          linkedOrder: linkedOrder,
          openTaskCount: openTasks.count,
          missingPhases: missingPhases,
          stage: stage,
          detail: detail,
          nextAction: nextAction,
          nextSymbol: nextSymbol,
          tone: tone,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.checklist.item.itemName.localizedCaseInsensitiveCompare(second.checklist.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistLinkedOrderFollowUpDashboardPanel: some View {
    let entries = wishlistLinkedOrderFollowUpDashboardEntries
    let trackingReview = entries.filter { $0.stage == "Tracking needs review" }.count
    let receivingFollowUp = entries.filter { $0.stage == "Receiving follow-up" }.count
    let dispatchFollowUp = entries.filter { $0.stage == "Dispatch follow-up" }.count
    let ready = entries.filter { $0.stage == "Ready for closure" }.count

    return SettingsPanel(title: "Linked order follow-up dashboard", symbol: "shippingbox.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this once a Wishlist purchase is linked to an order. It keeps the daily follow-up focused on tracking, receiving, dispatch setup, open tasks, and closure readiness.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Linked orders", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Tracking review", "\(trackingReview)", trackingReview == 0 ? .green : .orange),
          ("Receiving", "\(receivingFollowUp)", receivingFollowUp == 0 ? .green : .teal),
          ("Dispatch", "\(dispatchFollowUp)", dispatchFollowUp == 0 ? .green : .brown),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No linked Wishlist orders to follow up",
            detail: "Once a Wishlist purchase is linked to an order, tracking, receiving, dispatch, and closure follow-up appears here.",
            symbol: "shippingbox.circle.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 410), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistLinkedOrderFollowUpDashboardRow(entry: entry, store: store) {
                runWishlistLinkedOrderFollowUpAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.checklist.item)
              } onFocus: {
                wishlistSearchText = entry.checklist.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more linked Wishlist order\(remaining == 1 ? "" : "s") are available in the detailed panels below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This dashboard is local-only. It does not poll carriers, update orders externally, receive stock, book dispatch, mutate mailboxes, send notifications, or contact retailers.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistLinkedOrderFollowUpAction(for entry: WishlistLinkedOrderFollowUpDashboardEntry) {
    switch entry.stage {
    case "Tracking needs review", "Tasks open":
      store.createWishlistPurchaseHandoffReviewTask(entry.checklist.item)
    case "Receiving follow-up":
      store.createWishlistReceivingInspection(entry.checklist.item)
    case "Dispatch follow-up":
      if entry.checklist.phaseChecks.first(where: { $0.0 == "Manifest" })?.1 == false {
        store.createWishlistShipmentManifest(entry.checklist.item)
      } else {
        store.createWishlistDispatchReadinessChecklist(entry.checklist.item)
      }
    case "Ready for closure":
      store.checkWishlistOperationsClosureReadinessBatch()
    default:
      runWishlistLinkedOrderOperationsChecklistAction(for: entry.checklist)
    }
  }

  private var wishlistOperationsClosureReadinessEntries: [WishlistOperationsClosureReadinessEntry] {
    wishlistLinkedOrderOperationsChecklistEntries
      .map(wishlistOperationsClosureReadinessEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistOperationsClosureReadinessPanel: some View {
    let entries = wishlistOperationsClosureReadinessEntries
    let ready = entries.filter { $0.stage == "Ready to close" }.count
    let orderGaps = entries.filter { $0.gaps.contains("order link") }.count
    let receivingGaps = entries.filter { $0.gaps.contains("receiving") || $0.gaps.contains("inventory") || $0.gaps.contains("storage") }.count
    let dispatchGaps = entries.filter { $0.gaps.contains("manifest") || $0.gaps.contains("dispatch") }.count

    return SettingsPanel(title: "Wishlist operations closure readiness", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this final local checklist before treating a Wishlist purchase as handed over to operations. It confirms the order trail, receiving, stock/storage, custody, label/manual check, manifest, dispatch, and follow-up task state.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready to close", "\(ready)", ready == 0 ? .secondary : .green),
          ("Order gaps", "\(orderGaps)", orderGaps == 0 ? .green : .orange),
          ("Receiving gaps", "\(receivingGaps)", receivingGaps == 0 ? .green : .teal),
          ("Dispatch gaps", "\(dispatchGaps)", dispatchGaps == 0 ? .green : .brown)
        ])

        CompactActionRow {
          Button("Check closure gaps", systemImage: "checkmark.seal.text.page.fill") {
            store.checkWishlistOperationsClosureReadinessBatch()
          }
          .disabled(entries.isEmpty)
          Button("Close ready", systemImage: "checkmark.circle.fill") {
            store.closeReadyWishlistItemsLocally()
          }
          .disabled(ready == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist operations trail to close",
            detail: "Link a Wishlist purchase to an order and stage downstream records before closure readiness appears here.",
            symbol: "checkmark.seal.text.page.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistOperationsClosureReadinessRow(entry: entry, store: store) {
                runWishlistOperationsClosureReadinessAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more closure readiness item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Closure readiness is local only. It does not close orders externally, receive stock, update inventory systems, book dispatch, print labels, scan hardware, or contact sellers.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistOperationsClosureReadinessEntry(for entry: WishlistLinkedOrderOperationsChecklistEntry) -> WishlistOperationsClosureReadinessEntry {
    let orderLinked = entry.linkedOrder != nil
    let checks = entry.phaseChecks
    let missing = checks.filter { !$0.1 }.map { $0.0.localizedLowercase }
    var gaps = missing
    if !orderLinked { gaps.append("order link") }

    let openTasks = store.reviewTasks.filter { task in
      task.linkedEntityType == .wishlistItem
        && task.linkedEntityID == entry.item.id.uuidString
        && task.status != .completed
    }
    if !openTasks.isEmpty {
      gaps.append("open task")
    }

    let stage: String
    let detail: String
    let nextAction: String
    let nextSymbol: String
    let tone: Color
    let sortPriority: Int

    if !orderLinked {
      stage = "Order link needed"
      detail = "Link the order confirmation before closing the Wishlist purchase trail."
      nextAction = "Order seen"
      nextSymbol = "envelope.badge.fill"
      tone = .orange
      sortPriority = 10
    } else if !missing.isEmpty {
      stage = "Ops records missing"
      detail = "Stage \(missing.prefix(3).joined(separator: ", ")) before closure."
      nextAction = wishlistClosureActionTitle(for: missing)
      nextSymbol = wishlistClosureActionSymbol(for: missing)
      tone = .teal
      sortPriority = 20
    } else if !openTasks.isEmpty {
      stage = "Follow-up tasks open"
      detail = "\(openTasks.count) local follow-up task\(openTasks.count == 1 ? "" : "s") still need review before closure."
      nextAction = "Task"
      nextSymbol = "checklist"
      tone = .purple
      sortPriority = 30
    } else {
      stage = "Ready to close"
      detail = "Local order and operations records are staged, with no open Wishlist follow-up tasks."
      nextAction = "Close locally"
      nextSymbol = "checkmark.circle.fill"
      tone = .green
      sortPriority = 40
    }

    return WishlistOperationsClosureReadinessEntry(
      item: entry.item,
      linkedOrder: entry.linkedOrder,
      phaseChecks: checks,
      openTaskCount: openTasks.count,
      gaps: Array(Set(gaps)).sorted(),
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      nextSymbol: nextSymbol,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func wishlistClosureActionTitle(for gaps: [String]) -> String {
    if gaps.contains("receiving") { return "Receiving" }
    if gaps.contains("inventory") { return "Inventory" }
    if gaps.contains("storage") { return "Storage" }
    if gaps.contains("custody") { return "Custody" }
    if gaps.contains("label") { return "Label" }
    if gaps.contains("manual check") { return "Manual check" }
    if gaps.contains("manifest") { return "Manifest" }
    if gaps.contains("dispatch") { return "Dispatch" }
    return "Task"
  }

  private func wishlistClosureActionSymbol(for gaps: [String]) -> String {
    if gaps.contains("receiving") { return "checkmark.seal.fill" }
    if gaps.contains("inventory") { return "shippingbox.and.arrow.backward.fill" }
    if gaps.contains("storage") { return "archivebox.fill" }
    if gaps.contains("custody") { return "person.2.badge.gearshape.fill" }
    if gaps.contains("label") { return "tag.square.fill" }
    if gaps.contains("manual check") { return "checklist.checked" }
    if gaps.contains("manifest") { return "paperplane.fill" }
    if gaps.contains("dispatch") { return "checkmark.rectangle.stack.fill" }
    return "checklist"
  }

  private func runWishlistOperationsClosureReadinessAction(for entry: WishlistOperationsClosureReadinessEntry) {
    if entry.gaps.contains("order link") {
      if let email = store.suggestedWishlistOrderConfirmations(for: entry.item).first {
        store.confirmWishlistOrderFromIntake(entry.item, email: email)
      } else {
        store.markWishlistOrderConfirmationSeen(entry.item)
      }
    } else if entry.gaps.contains("receiving") {
      store.createWishlistReceivingInspection(entry.item)
    } else if entry.gaps.contains("inventory") {
      store.createWishlistInventoryReceipt(entry.item)
    } else if entry.gaps.contains("storage") {
      store.createWishlistStorageLocation(entry.item)
    } else if entry.gaps.contains("custody") {
      store.createWishlistCustodyRecord(entry.item)
    } else if entry.gaps.contains("label") {
      store.createWishlistLabelReference(entry.item)
    } else if entry.gaps.contains("manual check") {
      store.createWishlistScanSession(entry.item)
    } else if entry.gaps.contains("manifest") {
      store.createWishlistShipmentManifest(entry.item)
    } else if entry.gaps.contains("dispatch") {
      store.createWishlistDispatchReadinessChecklist(entry.item)
    } else if entry.gaps.contains("open task") {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else {
      store.closeWishlistItemLocally(entry.item)
    }
  }

  private var wishlistAgentHandoffPacketPanel: some View {
    let requests = store.activeWishlistResearchRequests
    let ready = requests.filter(\.isAgentBriefReady)
    let needsScope = requests.filter { !$0.isAgentBriefReady && !$0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let blocked = requests.filter { $0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let missingResearchItems = store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item)
        && (item.comparisonOptions ?? []).isEmpty
        && !requests.contains { $0.wishlistItemID == item.id }
    }

    return SettingsPanel(title: "Future comparison agent packet", symbol: "sparkles.rectangle.stack.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the local contract for a future shopping comparison agent. It defines what can be handed off later: product/source context, AU and overseas retailer scope, AUD landed cost, postage timing, seller trust evidence, and strict no-purchase boundaries.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Ready briefs", "\(ready.count)", ready.isEmpty ? .secondary : .green),
          ("Need scope", "\(needsScope.count)", needsScope.isEmpty ? .green : .orange),
          ("Blocked", "\(blocked.count)", blocked.isEmpty ? .green : .red),
          ("No brief", "\(missingResearchItems.count)", missingResearchItems.isEmpty ? .green : .blue)
        ])

        VStack(alignment: .leading, spacing: 6) {
          Label("Future agent output contract", systemImage: "doc.text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("Required output: product URL, seller, listed price/currency, estimated AUD landed total, postage cost/time, seller region, returns/warranty notes, trust evidence, and recommendation.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Boundaries: no checkout, no payment, no account login, no credential capture, no mailbox mutation, no carrier booking, and no background monitoring.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

        if requests.isEmpty {
          MVPEmptyState(
            title: "No agent research briefs staged",
            detail: "Use Compare on Wishlist items to stage local research briefs. Later, a real agent can consume these briefs without changing the operator workflow.",
            symbol: "list.bullet.clipboard.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(Array((ready + needsScope + blocked).prefix(6))) { request in
              WishlistAgentHandoffPacketRow(request: request) {
                store.markWishlistResearchRequestReviewed(request)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: request.wishlistItemID?.uuidString ?? request.id.uuidString,
                  label: request.itemName,
                  summary: "Prepare future comparison-agent brief: confirm AUD budget, seller criteria, postage timing, trust evidence, and no-purchase boundaries before live research.",
                  priority: request.isAgentBriefReady ? .normal : .high,
                  assignee: "Wishlist review"
                )
              } onDraft: {
                store.createWishlistResearchBriefDraft(request)
              }
            }
          }
        }

        if !missingResearchItems.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Items without a research brief")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(missingResearchItems.prefix(3)) { item in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "star.square.fill")
                  .foregroundStyle(.blue)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text("Create a comparison plan before this can be handed to a future agent.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Create brief", systemImage: "list.bullet.clipboard") {
                  store.createWishlistComparisonPlan(item)
                  store.createWishlistResearchRequest(from: item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(8)
              .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }
    }
  }

  private var wishlistAgentBatchBriefPanel: some View {
    let requests = store.activeWishlistResearchRequests
    let ready = requests.filter(\.isAgentBriefReady)
    let usable = ready.isEmpty ? requests.filter { !$0.requestStatus.localizedCaseInsensitiveContains("blocked") } : ready
    let scopeGaps = requests.reduce(0) { $0 + $1.agentBriefGaps.count }
    let lastBatchDraft = store.draftMessages.first { draft in
      draft.linkedEntityType == .wishlistItem
        && draft.linkedEntityID == "wishlist-research-batch"
    }

    return SettingsPanel(title: "Batch comparison brief", symbol: "doc.text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Create one local draft packet for future comparison work across Wishlist items. The packet is designed for later agent or human research: compare AU and overseas sellers, estimate AUD landed totals, include postage timing, and reject low-trust sellers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Requests", "\(requests.count)", requests.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready.count)", ready.isEmpty ? .secondary : .green),
          ("Included now", "\(min(usable.count, 12))", usable.isEmpty ? .secondary : .teal),
          ("Scope gaps", "\(scopeGaps)", scopeGaps == 0 ? .green : .orange)
        ])

        HStack(alignment: .top, spacing: 10) {
          Image(systemName: usable.isEmpty ? "exclamationmark.triangle.fill" : "checklist.checked")
            .foregroundStyle(usable.isEmpty ? .orange : .green)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(usable.isEmpty ? "No batch-ready research requests" : "Batch packet can be drafted")
              .font(.subheadline.weight(.semibold))
            Text(usable.isEmpty ? "Create or review Wishlist research requests first. Blocked requests are intentionally excluded." : "The draft includes up to 12 \(ready.isEmpty ? "unblocked" : "agent-ready") requests, required output fields, seller trust rules, postage expectations, and no-purchase boundaries.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .background((usable.isEmpty ? Color.orange : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if let lastBatchDraft {
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: "star.square.on.square.fill")
                .foregroundStyle(lastBatchDraft.status.color)
                .frame(width: 24, height: 24)
              VStack(alignment: .leading, spacing: 4) {
                Text("Latest batch draft")
                  .font(.subheadline.weight(.semibold))
                Text(lastBatchDraft.subject)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(wishlistBatchDraftNextAction(lastBatchDraft))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 8)
              Badge(lastBatchDraft.status.rawValue, color: lastBatchDraft.status.color)
            }

            CompactMetadataGrid(minimumWidth: 145) {
              Badge(lastBatchDraft.reviewState.rawValue, color: lastBatchDraft.reviewState.color)
              Label(lastBatchDraft.createdDate, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
              Label("Local draft only", systemImage: "lock.doc.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            CompactActionRow {
              Button("Ready", systemImage: "checkmark.seal.fill") {
                store.markDraftMessageReady(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .ready)
              Button("Sent locally", systemImage: "paperplane.fill") {
                store.markDraftMessageSentLocally(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .sentLocally)
              Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
                store.reopenDraftMessage(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .reopened)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
          .padding(10)
          .background(lastBatchDraft.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !usable.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Included examples")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(usable.prefix(4)) { request in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: request.isAgentBriefReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                  .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                  Text(request.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text(request.isAgentBriefReady ? "Ready packet: AUD, postage, trust, region, and output boundaries present." : request.agentBriefNextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : .orange)
              }
              .padding(8)
              .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        CompactActionRow {
          Button("Create batch brief draft", systemImage: "doc.badge.plus") {
            store.createWishlistBatchResearchBriefDraft()
          }
          .disabled(usable.isEmpty)
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit trail", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        Text("Still not active: live retailer search, exchange-rate lookup, postage APIs, seller trust services, browser automation, account login, checkout, payment, order monitoring, or external agents.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistAgentOutputContractEntries: [WishlistAgentOutputContractEntry] {
    store.wishlistResearchRequests
      .filter(store.isActiveWishlistResearchRequest)
      .map { request in
        let gaps = request.agentBriefGaps
        let isBlocked = request.requestStatus.localizedCaseInsensitiveContains("blocked")
        let requiredOutputs = [
          "Product URL",
          "Seller",
          "Listed price/currency",
          "Estimated AUD landed total",
          "Postage cost",
          "Postage timing",
          "Seller trust evidence",
          "Returns/warranty notes",
          "Recommendation"
        ]
        let stage: String
        let detail: String
        let tone: Color
        let sortPriority: Int

        if isBlocked {
          stage = "Blocked"
          detail = "Do not hand off until the block is resolved or the request is replaced."
          tone = .red
          sortPriority = 0
        } else if gaps.isEmpty {
          stage = "Ready contract"
          detail = "Brief is ready to be copied into manual research or a future agent run."
          tone = .green
          sortPriority = 30
        } else if gaps == ["operator review"] {
          stage = "Review contract"
          detail = "Scope is complete; operator review is the only remaining handoff step."
          tone = .brown
          sortPriority = 10
        } else {
          stage = "Contract gaps"
          detail = "Resolve \(gaps.prefix(3).joined(separator: ", ")) before handoff."
          tone = .orange
          sortPriority = 20
        }

        return WishlistAgentOutputContractEntry(
          request: request,
          stage: stage,
          detail: detail,
          requiredOutputs: requiredOutputs,
          gaps: gaps,
          tone: tone,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.request.itemName.localizedCaseInsensitiveCompare(second.request.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistAgentOutputContractPanel: some View {
    let entries = wishlistAgentOutputContractEntries
    let ready = entries.filter { $0.stage == "Ready contract" }.count
    let review = entries.filter { $0.stage == "Review contract" }.count
    let gaps = entries.filter { $0.stage == "Contract gaps" }.count
    let blocked = entries.filter { $0.stage == "Blocked" }.count

    return SettingsPanel(title: "Agent research output contract", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This converts Wishlist research briefs into a precise result contract. It tells a future agent or human researcher exactly what must come back before ParcelOps can compare sellers or prepare a purchase decision.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Contracts", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Need review", "\(review)", review == 0 ? .green : .brown),
          ("Gaps", "\(gaps)", gaps == 0 ? .green : .orange),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red)
        ])

        VStack(alignment: .leading, spacing: 8) {
          Label("Required result fields", systemImage: "list.bullet.rectangle.portrait.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactMetadataGrid(minimumWidth: 145) {
            Label("Seller/product URL", systemImage: "link")
            Label("AUD landed total", systemImage: "dollarsign.circle.fill")
            Label("Postage cost/time", systemImage: "shippingbox.fill")
            Label("Trust evidence", systemImage: "shield.checkered")
            Label("Returns/warranty", systemImage: "arrow.uturn.backward.circle.fill")
            Label("Recommendation", systemImage: "hand.thumbsup.fill")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if entries.isEmpty {
          MVPEmptyState(
            title: "No output contracts yet",
            detail: "Create Wishlist research requests first. Each request becomes a local contract for comparison results.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistAgentOutputContractRow(entry: entry) {
                if entry.gaps == ["operator review"] || entry.gaps.isEmpty {
                  store.markWishlistResearchRequestReviewed(entry.request)
                } else {
                  store.createReviewTask(
                    linkedEntityType: .wishlistItem,
                    linkedEntityID: entry.request.wishlistItemID?.uuidString ?? entry.request.id.uuidString,
                    label: entry.request.itemName,
                    summary: "Resolve Wishlist research output contract gaps before handoff: \(entry.gaps.prefix(5).joined(separator: ", ")).",
                    priority: .high,
                    assignee: "Wishlist review"
                  )
                }
              } onDraft: {
                store.createWishlistResearchBriefDraft(entry.request)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: entry.request.wishlistItemID?.uuidString ?? entry.request.id.uuidString,
                  label: entry.request.itemName,
                  summary: "Prepare Wishlist research output contract. Required return fields: seller/product URL, listed price/currency, AUD landed total, postage cost/time, trust evidence, returns/warranty, and recommendation. Boundaries: no checkout, payment, login, credential capture, or mailbox mutation.",
                  priority: entry.gaps.isEmpty ? .normal : .high,
                  assignee: "Wishlist review"
                )
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more output contract\(remaining == 1 ? "" : "s") are available in the research requests list.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Still local-only: this does not browse retailers, convert currencies, quote postage, call seller trust services, run an external agent, log into accounts, purchase, pay, or monitor order pages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistAgentBriefQualityEntries: [WishlistAgentBriefQualityEntry] {
    store.wishlistResearchRequests
      .filter(store.isActiveWishlistResearchRequest)
      .map(wishlistAgentBriefQualityEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.request.itemName.localizedCaseInsensitiveCompare(second.request.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistAgentBriefQualityPanel: some View {
    let entries = wishlistAgentBriefQualityEntries
    let ready = entries.filter { $0.stage == "Ready for future agent" }.count
    let missingScope = entries.filter { $0.stage == "Scope gaps" }.count
    let reviewNeeded = entries.filter { $0.stage == "Needs operator review" }.count
    let blocked = entries.filter { $0.stage == "Blocked" }.count

    return SettingsPanel(title: "Agent brief quality control", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Quality-control each comparison brief before handing it to a future agent or human researcher. A usable brief must specify item/source, AU and overseas scope, AUD budget, postage expectations, seller trust requirements, required output fields, and no-purchase boundaries.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Briefs", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Scope gaps", "\(missingScope)", missingScope == 0 ? .green : .orange),
          ("Need review", "\(reviewNeeded)", reviewNeeded == 0 ? .green : .brown),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No research briefs to quality-control",
            detail: "Use Compare on a Wishlist item to create a local research request, then review its agent-ready scope here.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistAgentBriefQualityRow(entry: entry) {
                runWishlistAgentBriefQualityAction(for: entry)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: entry.request.wishlistItemID?.uuidString ?? entry.request.id.uuidString,
                  label: entry.request.itemName,
                  summary: "Quality-control wishlist comparison brief. Resolve: \(entry.gaps.isEmpty ? "no current gaps" : entry.gaps.joined(separator: ", ")). Keep boundaries: no checkout, payment, login, credential capture, mailbox mutation, or background monitoring.",
                  priority: entry.gaps.isEmpty ? .normal : .high,
                  assignee: "Wishlist review"
                )
              } onDraft: {
                store.createWishlistResearchBriefDraft(entry.request)
              } onFocus: {
                wishlistSearchText = entry.request.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more brief quality item\(remaining == 1 ? "" : "s") are available in the research requests panel.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This is planning only. ParcelOps still does not run a live agent, scrape retailer sites, convert currencies, request postage quotes, score external sellers, log in, check out, pay, or monitor web pages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistAgentBriefQualityEntry(for request: WishlistResearchRequest) -> WishlistAgentBriefQualityEntry {
    let gaps = request.agentBriefGaps
    let isBlocked = request.requestStatus.localizedCaseInsensitiveContains("blocked")
    let outputContractPresent = request.agentInstructionPacket.localizedCaseInsensitiveContains("estimated AUD landed total")
      && request.agentInstructionPacket.localizedCaseInsensitiveContains("postage cost/time")
      && request.agentInstructionPacket.localizedCaseInsensitiveContains("trust evidence")
      && request.agentInstructionPacket.localizedCaseInsensitiveContains("do not buy")

    let checks: [WishlistAgentBriefQualityCheck] = [
      WishlistAgentBriefQualityCheck(label: "Item/source", detail: request.sourceURL, isReady: !gaps.contains("item name") && !gaps.contains("source URL")),
      WishlistAgentBriefQualityCheck(label: "Region scope", detail: request.regionScope, isReady: !gaps.contains("region scope")),
      WishlistAgentBriefQualityCheck(label: "AUD budget", detail: request.maxBudgetAUD, isReady: !gaps.contains("AUD budget")),
      WishlistAgentBriefQualityCheck(label: "Seller criteria", detail: request.sellerCriteria, isReady: !gaps.contains("seller criteria")),
      WishlistAgentBriefQualityCheck(label: "Postage rules", detail: request.postageRequirements, isReady: !gaps.contains("postage requirements")),
      WishlistAgentBriefQualityCheck(label: "Trust rules", detail: request.trustRequirements, isReady: !gaps.contains("seller trust requirements")),
      WishlistAgentBriefQualityCheck(label: "Output contract", detail: "URL, seller, AUD total, postage, trust, recommendation", isReady: outputContractPresent),
      WishlistAgentBriefQualityCheck(label: "Operator review", detail: request.reviewState.rawValue, isReady: request.reviewState == .accepted)
    ]

    let stage: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if isBlocked {
      stage = "Blocked"
      detail = "Research brief is blocked. Reopen or replace the request before handoff."
      tone = .red
      sortPriority = 0
    } else if gaps.contains("operator review") && gaps.count == 1 {
      stage = "Needs operator review"
      detail = "Scope looks complete; mark reviewed before future agent handoff."
      tone = .brown
      sortPriority = 10
    } else if !gaps.isEmpty {
      stage = "Scope gaps"
      detail = "Clarify \(gaps.prefix(3).joined(separator: ", ")) before using this brief."
      tone = .orange
      sortPriority = 20
    } else {
      stage = "Ready for future agent"
      detail = "Brief has the local scope and safety boundaries needed for a future research handoff."
      tone = .green
      sortPriority = 30
    }

    return WishlistAgentBriefQualityEntry(
      request: request,
      checks: checks,
      gaps: gaps,
      stage: stage,
      detail: detail,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistAgentBriefQualityAction(for entry: WishlistAgentBriefQualityEntry) {
    if entry.stage == "Needs operator review" || entry.stage == "Ready for future agent" {
      store.markWishlistResearchRequestReviewed(entry.request)
    } else if entry.stage == "Blocked" {
      store.createWishlistResearchBriefDraft(entry.request)
    } else {
      store.createReviewTask(
        linkedEntityType: .wishlistItem,
        linkedEntityID: entry.request.wishlistItemID?.uuidString ?? entry.request.id.uuidString,
        label: entry.request.itemName,
        summary: "Resolve wishlist research brief gaps: \(entry.gaps.prefix(5).joined(separator: ", ")).",
        priority: .high,
        assignee: "Wishlist review"
      )
    }
  }

  private func wishlistBatchDraftNextAction(_ draft: DraftMessage) -> String {
    switch draft.status {
    case .draft:
      return "Review the packet before handing it to a future research agent or copying it into a manual comparison workflow."
    case .ready:
      return "Use the packet outside ParcelOps, then mark it sent locally once the handoff is complete."
    case .sentLocally:
      return "The packet is no longer active in Tasks. Reopen it only if the comparison research needs another pass."
    case .reopened:
      return "Update the batch brief or Wishlist request scope, then mark it ready again."
    }
  }

  private var wishlistAgentResearchRunwayPanel: some View {
    let requests = store.activeWishlistResearchRequests
    let readyRequests = requests.filter(\.isAgentBriefReady)
    let scopeGapRequests = requests.filter { !$0.isAgentBriefReady && !$0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let blockedRequests = requests.filter { $0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let captureGapCandidates = store.wishlistCaptureCandidates.filter { !$0.operatorCaptureGaps.isEmpty }
    let unbriefedItems = store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item)
        && !requests.contains { $0.wishlistItemID == item.id }
        && (item.comparisonOptions ?? []).isEmpty
    }
    let returnedOptionItems = store.wishlistItems.filter { item in
      let hasRequest = requests.contains { $0.wishlistItemID == item.id }
      return store.isActiveWishlistItem(item)
        && hasRequest
        && !(item.comparisonOptions ?? []).isEmpty
        && item.purchaseDecision == nil
    }
    let lastBatchDraft = store.draftMessages.first { draft in
      draft.linkedEntityType == .wishlistItem
        && draft.linkedEntityID == "wishlist-research-batch"
    }
    let nextItemWithoutBrief = unbriefedItems.first

    return SettingsPanel(title: "Wishlist research runway", symbol: "point.topleft.down.curvedto.point.bottomright.up") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this local runway to prepare Wishlist items for later comparison work. It keeps capture cleanup, research briefs, batch handoff, and returned seller options in one place without running web search, browser automation, checkout, or external agents.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Capture gaps", "\(captureGapCandidates.count)", captureGapCandidates.isEmpty ? .green : .orange),
          ("Need briefs", "\(unbriefedItems.count)", unbriefedItems.isEmpty ? .green : .blue),
          ("Brief gaps", "\(scopeGapRequests.count)", scopeGapRequests.isEmpty ? .green : .orange),
          ("Ready briefs", "\(readyRequests.count)", readyRequests.isEmpty ? .secondary : .green),
          ("Returned options", "\(returnedOptionItems.count)", returnedOptionItems.isEmpty ? .secondary : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistResearchRunwayStep(
            number: "1",
            title: "Clean capture",
            detail: captureGapCandidates.isEmpty ? "No staged capture candidates have blocking gaps." : "\(captureGapCandidates.count) staged capture candidate\(captureGapCandidates.count == 1 ? "" : "s") need title, URL, seller, price, summary, or review cleanup.",
            status: captureGapCandidates.isEmpty ? "Clear" : "Fix gaps",
            color: captureGapCandidates.isEmpty ? .green : .orange
          )

          WishlistResearchRunwayStep(
            number: "2",
            title: "Create briefs",
            detail: unbriefedItems.isEmpty ? "Every comparison-stage Wishlist item has a local research brief or seller options." : "\(unbriefedItems.count) item\(unbriefedItems.count == 1 ? "" : "s") still need a comparison brief before future agent handoff.",
            status: unbriefedItems.isEmpty ? "Covered" : "Brief needed",
            color: unbriefedItems.isEmpty ? .green : .blue
          )

          WishlistResearchRunwayStep(
            number: "3",
            title: "Quality-control scope",
            detail: scopeGapRequests.isEmpty ? "No open research brief is missing core agent handoff scope." : "\(scopeGapRequests.count) brief\(scopeGapRequests.count == 1 ? "" : "s") need AUD budget, region, seller, postage, trust, source, or operator review scope.",
            status: blockedRequests.isEmpty ? (scopeGapRequests.isEmpty ? "Ready" : "Scope gaps") : "\(blockedRequests.count) blocked",
            color: blockedRequests.isEmpty ? (scopeGapRequests.isEmpty ? .green : .orange) : .red
          )

          WishlistResearchRunwayStep(
            number: "4",
            title: "Review returned options",
            detail: returnedOptionItems.isEmpty ? "No briefed Wishlist item has un-decided seller options waiting for purchase review." : "\(returnedOptionItems.count) item\(returnedOptionItems.count == 1 ? "" : "s") have seller options but no purchase decision yet.",
            status: returnedOptionItems.isEmpty ? "No queue" : "Review options",
            color: returnedOptionItems.isEmpty ? .secondary : .purple
          )
        }

        VStack(alignment: .leading, spacing: 8) {
          Label("Next local action", systemImage: "arrowshape.turn.up.right.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          if let firstGap = captureGapCandidates.first {
            Text("Fix capture candidate: \(firstGap.pageTitle.isPlaceholderValidationValue ? "Untitled capture" : firstGap.pageTitle). Missing \(firstGap.operatorCaptureGaps.prefix(3).joined(separator: ", ")).")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          } else if let nextItemWithoutBrief {
            Text("Create a research brief for \(nextItemWithoutBrief.itemName) so it can enter the comparison handoff queue.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          } else if let firstScopeGap = scopeGapRequests.first {
            Text("\(firstScopeGap.itemName): \(firstScopeGap.agentBriefNextAction)")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          } else if let firstReturned = returnedOptionItems.first {
            Text("Review seller options for \(firstReturned.itemName) and prepare a purchase decision if the trust, postage, and AUD landed cost evidence is sufficient.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            Text("The local Wishlist research runway has no immediate blockers. Create a batch brief when you want a handoff packet for future research.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if let lastBatchDraft {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.text.fill")
              .foregroundStyle(lastBatchDraft.status.color)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
              Text("Latest batch handoff draft")
                .font(.caption.weight(.semibold))
              Text(lastBatchDraft.subject)
                .font(.caption)
                .lineLimit(2)
              Text("Status: \(lastBatchDraft.status.rawValue). \(wishlistBatchDraftNextAction(lastBatchDraft))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Badge(lastBatchDraft.status.rawValue, color: lastBatchDraft.status.color)
          }
          .padding(10)
          .background(lastBatchDraft.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        CompactActionRow {
          Button("Create missing brief", systemImage: "list.bullet.clipboard") {
            if let item = nextItemWithoutBrief {
              store.createWishlistComparisonPlan(item)
              store.createWishlistResearchRequest(from: item)
            }
          }
          .disabled(nextItemWithoutBrief == nil)

          Button("Create all missing", systemImage: "square.stack.3d.up.fill") {
            store.createMissingWishlistResearchRequests()
          }
          .disabled(unbriefedItems.isEmpty)

          Button("Create batch brief", systemImage: "doc.badge.plus") {
            store.createWishlistBatchResearchBriefDraft()
          }
          .disabled(requests.filter { !$0.requestStatus.localizedCaseInsensitiveContains("blocked") }.isEmpty)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        Text("Research remains local/manual here. ParcelOps does not compare live retailer sites, convert currencies, quote postage, rate external sellers, open browser pages, log into accounts, purchase, or monitor orders from this section.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistResearchResultIntakeItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        guard store.isActiveWishlistItem(item) else { return false }
        let hasRequest = store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id }
        let hasBatchDraft = store.draftMessages.contains {
          $0.linkedEntityType == .wishlistItem
            && $0.linkedEntityID == "wishlist-research-batch"
            && $0.body.localizedCaseInsensitiveContains(item.itemName)
        }
        let hasUsefulOptions = !(item.comparisonOptions ?? []).contains { option in
          !option.operatorSellerEvidenceGaps.contains("product link")
            && !option.operatorSellerEvidenceGaps.contains("AUD total")
        }
        return (hasRequest || hasBatchDraft)
          && (!hasUsefulOptions || item.purchaseDecision == nil)
          && item.purchaseHandoff == nil
      }
      .sorted { first, second in
        let firstOptions = first.comparisonOptions?.count ?? 0
        let secondOptions = second.comparisonOptions?.count ?? 0
        if firstOptions == secondOptions {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstOptions < secondOptions
      }
  }

  private var wishlistResearchResultsReadyCount: Int {
    store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && (item.comparisonOptions ?? []).contains { option in
        option.operatorSellerEvidenceGaps.isEmpty && option.operatorSellerMatrixScore >= 70
      }
    }.count
  }

  private var wishlistResearchResultIntakePanel: some View {
    let intakeItems = wishlistResearchResultIntakeItems
    let sellerOptionCount = store.activeWishlistItems.reduce(0) { $0 + ($1.comparisonOptions?.count ?? 0) }
    let batchDraftCount = store.draftMessages.filter {
      $0.linkedEntityType == .wishlistItem && $0.linkedEntityID == "wishlist-research-batch"
    }.count

    return SettingsPanel(title: "Research results intake", symbol: "square.and.pencil") {
      VStack(alignment: .leading, spacing: 12) {
        Text("After a human or future agent compares retailers, paste the useful result back into Wishlist as seller options. This keeps the app useful before live retailer search, currency conversion, postage quotes, or seller trust APIs exist.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Result candidates", "\(intakeItems.count)", intakeItems.isEmpty ? .green : .purple),
          ("Seller options", "\(sellerOptionCount)", sellerOptionCount == 0 ? .secondary : .blue),
          ("Ready-looking", "\(wishlistResearchResultsReadyCount)", wishlistResearchResultsReadyCount == 0 ? .secondary : .green),
          ("Batch drafts", "\(batchDraftCount)", batchDraftCount == 0 ? .secondary : .teal)
        ])

        if intakeItems.isEmpty {
          Label("No research-result intake is waiting. Create a research brief, or add seller options directly on a Wishlist item after manual comparison.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 320), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(intakeItems.prefix(6)) { item in
              VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: "square.and.pencil")
                    .foregroundStyle(.purple)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(item.itemName)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(2)
                    Text(wishlistResearchResultIntakeDetail(for: item))
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 8)
                  Badge(wishlistResearchResultIntakeBadge(for: item), color: wishlistResearchResultIntakeColor(for: item))
                }

                CompactMetadataGrid(minimumWidth: 120) {
                  Badge("\(item.comparisonOptions?.count ?? 0) option\(item.comparisonOptions?.count == 1 ? "" : "s")", color: item.comparisonOptions?.isEmpty == false ? .blue : .orange)
                  Badge(item.comparisonStatus ?? "Comparison needed", color: .purple)
                  Badge(item.purchaseReadiness ?? "Not ready", color: .orange)
                }

                CompactActionRow {
                  Button("Add seller option", systemImage: "storefront.fill") {
                    store.addManualWishlistSellerOptionPlaceholder(item)
                  }
                  Button("Score options", systemImage: "chart.bar.doc.horizontal") {
                    store.evaluateWishlistComparisonOptions(item)
                  }
                  .disabled(item.comparisonOptions?.isEmpty != false)
                  Button("Focus item", systemImage: "scope") {
                    wishlistSearchText = item.itemName
                    selectedSource = nil
                    selectedStatus = nil
                    selectedWorkflowFocus = .compare
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(10)
              .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        CompactActionRow {
          Button("Paste comparison result", systemImage: "doc.text.magnifyingglass") {
            showPastedComparisonResultForm = true
          }
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)

        Text("Still manual: the operator must verify live price, stock, AUD landed total, postage time, returns/warranty, seller trust, account fit, and payment readiness outside ParcelOps before buying.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistResearchResultIntakeDetail(for item: WishlistItem) -> String {
    let request = store.wishlistResearchRequests.first { $0.wishlistItemID == item.id }
    let optionCount = item.comparisonOptions?.count ?? 0
    if optionCount == 0 {
      return request?.isAgentBriefReady == true
        ? "Research brief is ready. Add the first seller option from manual or future-agent comparison results."
        : "Add seller options after checking product link, price, AUD landed total, postage, and seller trust."
    }
    let gapCount = (item.comparisonOptions ?? []).reduce(0) { $0 + $1.operatorSellerEvidenceGaps.count }
    if gapCount > 0 {
      return "\(optionCount) seller option\(optionCount == 1 ? "" : "s") recorded, but \(gapCount) evidence gap\(gapCount == 1 ? "" : "s") still need manual cleanup."
    }
    return "Seller options look complete enough for local scoring and purchase decision review."
  }

  private func wishlistResearchResultIntakeBadge(for item: WishlistItem) -> String {
    if item.comparisonOptions?.isEmpty != false { return "Needs options" }
    if (item.comparisonOptions ?? []).contains(where: { !$0.operatorSellerEvidenceGaps.isEmpty }) { return "Clean up" }
    return "Score"
  }

  private func wishlistResearchResultIntakeColor(for item: WishlistItem) -> Color {
    if item.comparisonOptions?.isEmpty != false { return .orange }
    if (item.comparisonOptions ?? []).contains(where: { !$0.operatorSellerEvidenceGaps.isEmpty }) { return .purple }
    return .green
  }

  private var wishlistSellerQuoteIntakePanel: some View {
    let quotes = store.wishlistSellerQuotes.filter(store.isActiveWishlistSellerQuote).sorted { first, second in
      if first.reviewState == second.reviewState {
        return first.capturedDate > second.capturedDate
      }
      return first.reviewState == .needsReview
    }
    let needsReview = quotes.filter { $0.reviewState != .accepted && !$0.quoteStatus.localizedCaseInsensitiveContains("rejected") }.count
    let promoted = quotes.filter { $0.quoteStatus.localizedCaseInsensitiveContains("promoted") }.count
    let rejected = quotes.filter { $0.quoteStatus.localizedCaseInsensitiveContains("rejected") }.count
    let linked = quotes.filter { quote in
      store.wishlistItems.contains { item in
        store.isActiveWishlistItem(item) && (
        quote.wishlistItemID == item.id
          || quote.itemName.localizedCaseInsensitiveContains(item.itemName)
          || item.itemName.localizedCaseInsensitiveContains(quote.itemName)
        )
      }
    }.count

    return SettingsPanel(title: "Seller quote intake", symbol: "cart.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Capture researched seller offers before they become purchase options. Use this for manual research now and future browser/agent paste-back later; every quote still needs operator review before purchase.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Quotes", "\(quotes.count)", quotes.isEmpty ? .secondary : .blue),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal),
          ("Need review", "\(needsReview)", needsReview == 0 ? .green : .orange),
          ("Promoted", "\(promoted)", promoted == 0 ? .secondary : .green),
          ("Rejected", "\(rejected)", rejected == 0 ? .secondary : .red)
        ])

        CompactActionRow {
          Button("Add quote for first item", systemImage: "cart.badge.plus") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistSellerQuotePlaceholder(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if quotes.isEmpty {
          MVPEmptyState(
            title: "No seller quotes captured",
            detail: "Add a local quote after manual research. Later browser or agent results can use this same review lane before becoming seller options.",
            symbol: "cart.badge.plus"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(quotes.prefix(8)) { quote in
              WishlistSellerQuoteRow(
                quote: quote,
                linkedItem: store.wishlistItems.first { item in
                  quote.wishlistItemID == item.id
                    || quote.itemName.localizedCaseInsensitiveContains(item.itemName)
                    || item.itemName.localizedCaseInsensitiveContains(quote.itemName)
                }
              ) {
                store.promoteWishlistSellerQuoteToOption(quote)
              } onReject: {
                store.rejectWishlistSellerQuote(quote)
              } onTrustChecks: {
                store.createWishlistSellerTrustRecords(from: quote)
              } onTask: {
                store.createWishlistSellerQuoteReviewTask(quote)
              } onFocus: {
                wishlistSearchText = quote.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .compare
              }
            }
          }

          let remaining = max(quotes.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller quote\(remaining == 1 ? "" : "s") are stored in the local quote ledger.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local-only boundary: this does not browse retailer sites, convert currency, fetch postage, rate sellers, log into stores, buy, pay, or monitor orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPriceWatchRulesPanel: some View {
    let rules = store.wishlistPriceWatchRules.filter(store.isActiveWishlistPriceWatchRule).sorted { first, second in
      if first.reviewState == second.reviewState {
        return first.lastEvaluatedDate > second.lastEvaluatedDate
      }
      return first.reviewState == .needsReview
    }
    let matched = rules.filter { $0.ruleStatus.localizedCaseInsensitiveContains("matched") }.count
    let watching = rules.filter { $0.ruleStatus.localizedCaseInsensitiveContains("watching") }.count
    let disabled = rules.filter { $0.ruleStatus.localizedCaseInsensitiveContains("disabled") }.count
    let unevaluated = rules.filter { $0.lastEvaluatedDate.localizedCaseInsensitiveContains("not evaluated") }.count

    return SettingsPanel(title: "Price watch rules", symbol: "bell.badge.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Define the local buying conditions that should make a Wishlist item worth attention. Rules evaluate saved seller quotes and price snapshots only; no web monitoring, alerts, or background jobs run.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Rules", "\(rules.count)", rules.isEmpty ? .secondary : .blue),
          ("Matched", "\(matched)", matched == 0 ? .secondary : .green),
          ("Watching", "\(watching)", watching == 0 ? .secondary : .teal),
          ("Unevaluated", "\(unevaluated)", unevaluated == 0 ? .green : .orange),
          ("Disabled", "\(disabled)", disabled == 0 ? .secondary : .red)
        ])

        CompactActionRow {
          Button("Add rule for first item", systemImage: "bell.badge.fill") {
            if let item = store.activeWishlistItems.first {
              store.addWishlistPriceWatchRule(item)
            }
          }
          .disabled(store.activeWishlistItemCount == 0)
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if rules.isEmpty {
          MVPEmptyState(
            title: "No price watch rules yet",
            detail: "Add a rule to capture a target AUD total, postage threshold, trust requirement, and region preference for a Wishlist item.",
            symbol: "bell.badge"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(rules.prefix(8)) { rule in
              WishlistPriceWatchRuleRow(rule: rule) {
                store.evaluateWishlistPriceWatchRule(rule)
              } onReview: {
                store.markWishlistPriceWatchRuleReviewed(rule)
              } onDisable: {
                store.disableWishlistPriceWatchRule(rule)
              } onTask: {
                store.createWishlistPriceWatchRuleReviewTask(rule)
              } onFocus: {
                wishlistSearchText = rule.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .buy
              }
            }
          }

          let remaining = max(rules.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more price watch rule\(remaining == 1 ? "" : "s") are available in the local rules ledger.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Operator boundary: rule matches are prompts to review. They are not live price alerts and do not buy, pay, log into retailers, send notifications, or mutate mailbox/order data.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistSellerTrustChecklistPanel: some View {
    let checks = store.wishlistSellerTrustRecords.filter(store.isActiveWishlistSellerTrustRecord).sorted { first, second in
      if first.reviewState == second.reviewState {
        return first.checkedDate > second.checkedDate
      }
      return first.reviewState == .needsReview
    }
    let accepted = checks.filter { $0.reviewState == .accepted }.count
    let blocked = checks.filter { $0.resultStatus.localizedCaseInsensitiveContains("blocked") }.count
    let highRisk = checks.filter { $0.riskLevel.localizedCaseInsensitiveContains("high") }.count
    let needsReview = checks.filter { $0.reviewState != .accepted }.count

    return SettingsPanel(title: "Seller trust checklist", symbol: "shield.lefthalf.filled.badge.checkmark") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Track seller trust evidence before purchase: business identity, returns/warranty, delivery reliability, and price realism. These are local operator checks only.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Checks", "\(checks.count)", checks.isEmpty ? .secondary : .blue),
          ("Need review", "\(needsReview)", needsReview == 0 ? .green : .orange),
          ("Accepted", "\(accepted)", accepted == 0 ? .secondary : .green),
          ("Blocked", "\(blocked)", blocked == 0 ? .secondary : .red),
          ("High risk", "\(highRisk)", highRisk == 0 ? .green : .red)
        ])

        if checks.isEmpty {
          MVPEmptyState(
            title: "No seller trust checks yet",
            detail: "Create trust checks from a seller quote. Checks stay local and give operators a concrete review list before buying.",
            symbol: "shield.lefthalf.filled.badge.checkmark"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 420), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(checks.prefix(8)) { check in
              WishlistSellerTrustRecordRow(check: check) {
                store.markWishlistSellerTrustRecordAccepted(check)
              } onBlock: {
                store.blockWishlistSellerTrustRecord(check)
              } onTask: {
                store.createWishlistSellerTrustRecordReviewTask(check)
              } onFocus: {
                wishlistSearchText = check.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .compare
              }
            }
          }

          let remaining = max(checks.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller trust check\(remaining == 1 ? "" : "s") are available in the local checklist.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("No external trust service, seller lookup, account login, checkout, purchase, payment, or network call runs from these checks.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistResearchPasteBackChecklistPanel: some View {
    let briefedItems = store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && (
        store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id }
        || store.draftMessages.contains {
          $0.linkedEntityType == .wishlistItem
            && $0.linkedEntityID == "wishlist-research-batch"
            && $0.body.localizedCaseInsensitiveContains(item.itemName)
        }
      )
    }
    let awaitingPasteBack = briefedItems.filter { ($0.comparisonOptions ?? []).isEmpty }
    let optionsNeedingCleanup = briefedItems.filter { item in
      (item.comparisonOptions ?? []).contains { !$0.operatorSellerEvidenceGaps.isEmpty }
    }
    let readyForScoring = briefedItems.filter { item in
      let options = item.comparisonOptions ?? []
      return !options.isEmpty
        && options.allSatisfy { $0.operatorSellerEvidenceGaps.isEmpty }
        && item.purchaseDecision == nil
    }
    let nextItem = awaitingPasteBack.first ?? optionsNeedingCleanup.first ?? readyForScoring.first

    return SettingsPanel(title: "Research paste-back checklist", symbol: "square.and.arrow.down.on.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this when comparison research comes back from a person, draft packet, browser notes, or future agent. Paste only verified result fields into seller options, then score locally before any purchase decision.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Briefed items", "\(briefedItems.count)", briefedItems.isEmpty ? .secondary : .blue),
          ("Need paste-back", "\(awaitingPasteBack.count)", awaitingPasteBack.isEmpty ? .green : .orange),
          ("Clean up", "\(optionsNeedingCleanup.count)", optionsNeedingCleanup.isEmpty ? .green : .purple),
          ("Ready to score", "\(readyForScoring.count)", readyForScoring.isEmpty ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 300), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistResearchRunwayStep(
            number: "1",
            title: "Identify result source",
            detail: "Confirm which brief, draft, browser note, or manual comparison the seller option came from.",
            status: "Traceable",
            color: .blue
          )
          WishlistResearchRunwayStep(
            number: "2",
            title: "Paste seller option",
            detail: "Record seller, product URL, listed price/currency, AUD landed total, postage cost/time, seller region, and returns/warranty notes.",
            status: awaitingPasteBack.isEmpty ? "No waiting" : "\(awaitingPasteBack.count) waiting",
            color: awaitingPasteBack.isEmpty ? .green : .orange
          )
          WishlistResearchRunwayStep(
            number: "3",
            title: "Check trust",
            detail: "Do not accept cheap options without clear seller trust evidence, delivery reliability, contact details, and returns/warranty terms.",
            status: optionsNeedingCleanup.isEmpty ? "Clear" : "Review",
            color: optionsNeedingCleanup.isEmpty ? .green : .purple
          )
          WishlistResearchRunwayStep(
            number: "4",
            title: "Score locally",
            detail: "Run local scoring after fields are complete. Scoring guides a human decision; it does not verify live pages or buy.",
            status: readyForScoring.isEmpty ? "Not ready" : "Ready",
            color: readyForScoring.isEmpty ? .secondary : .green
          )
        }

        if let nextItem {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrowshape.turn.up.right.fill")
              .foregroundStyle(.teal)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
              Text("Next paste-back item")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(nextItem.itemName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
              Text(wishlistResearchPasteBackNextAction(for: nextItem))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Badge(wishlistResearchResultIntakeBadge(for: nextItem), color: wishlistResearchResultIntakeColor(for: nextItem))
          }
          .padding(10)
          .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        } else {
          Label("No research paste-back work is waiting. Create a research brief or add seller options when comparison results are available.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        }

        CompactActionRow {
          Button("Add seller option", systemImage: "storefront.fill") {
            if let nextItem {
              store.addManualWishlistSellerOptionPlaceholder(nextItem)
            }
          }
          .disabled(nextItem == nil)

          Button("Score next", systemImage: "chart.bar.doc.horizontal") {
            if let nextItem {
              store.evaluateWishlistComparisonOptions(nextItem)
            }
          }
          .disabled(nextItem?.comparisonOptions?.isEmpty != false)

          Button("Create task", systemImage: "checklist") {
            if let nextItem {
              store.createReviewTask(
                linkedEntityType: .wishlistItem,
                linkedEntityID: nextItem.id.uuidString,
                label: nextItem.itemName,
                summary: "Paste back Wishlist comparison research into seller options. Required fields: seller/product URL, listed price/currency, AUD landed total, postage cost/time, seller region, returns/warranty, trust evidence, and recommendation. Do not buy, log in, store credentials, or rely on unverified seller claims.",
                priority: .high,
                assignee: "Wishlist review"
              )
            }
          }
          .disabled(nextItem == nil)
        }
        .buttonStyle(.bordered)

        Text("Manual boundary: this checklist does not browse, scrape, convert currencies, quote postage, validate seller trust, log into accounts, buy items, pay, or monitor orders. It only prepares local seller-option records for human review.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistResearchPasteBackNextAction(for item: WishlistItem) -> String {
    let options = item.comparisonOptions ?? []
    if options.isEmpty {
      return "Paste the first verified seller option from returned research. Include URL, AUD total, postage, delivery time, and trust evidence."
    }
    let gapCount = options.reduce(0) { $0 + $1.operatorSellerEvidenceGaps.count }
    if gapCount > 0 {
      return "\(options.count) seller option\(options.count == 1 ? "" : "s") exist, but \(gapCount) evidence gap\(gapCount == 1 ? "" : "s") still need cleanup before scoring."
    }
    if item.preferredOptionID == nil {
      return "Seller option fields look complete. Run local scoring and choose a preferred purchase route."
    }
    return "Preferred seller exists. Move this into purchase decision review if live price, stock, postage, trust, and account readiness are still acceptable."
  }

  private var wishlistResearchPasteBackFieldMapPanel: some View {
    let activeItems = store.activeWishlistItems
    let optionCount = activeItems.reduce(0) { $0 + ($1.comparisonOptions?.count ?? 0) }
    let gapCount = activeItems.reduce(0) { total, item in
      total + (item.comparisonOptions ?? []).reduce(0) { $0 + $1.operatorSellerEvidenceGaps.count }
    }
    let readyCount = activeItems.reduce(0) { total, item in
      total + (item.comparisonOptions ?? []).filter { option in
        option.operatorSellerEvidenceGaps.isEmpty && option.operatorSellerMatrixScore >= 70
      }.count
    }
    let missingAudCount = activeItems.reduce(0) { total, item in
      total + (item.comparisonOptions ?? []).filter { option in
        option.estimatedAUDTotal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }.count
    }

    return SettingsPanel(title: "Research paste-back field map", symbol: "rectangle.and.pencil.and.ellipsis") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this field map when a human, browser note, or future agent returns retailer comparisons. It shows exactly what has to be copied into local seller options before a purchase route can be trusted.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Seller options", "\(optionCount)", optionCount == 0 ? .secondary : .blue),
          ("Evidence gaps", "\(gapCount)", gapCount == 0 ? .green : .orange),
          ("Missing AUD", "\(missingAudCount)", missingAudCount == 0 ? .green : .purple),
          ("Ready-scored", "\(readyCount)", readyCount == 0 ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 330), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistResearchRunwayStep(
            number: "1",
            title: "Identity",
            detail: "Paste seller name, retailer region, product title, and direct product URL. Reject marketplace listings without a stable product page.",
            status: "Required",
            color: .blue
          )
          WishlistResearchRunwayStep(
            number: "2",
            title: "Price",
            detail: "Capture listed price, currency, estimated exchange rate note, GST/tax note, postage, and final AUD landed total.",
            status: missingAudCount == 0 ? "Covered" : "\(missingAudCount) missing",
            color: missingAudCount == 0 ? .green : .orange
          )
          WishlistResearchRunwayStep(
            number: "3",
            title: "Delivery",
            detail: "Record shipping method, postage cost, estimated dispatch window, estimated delivery window, and any stock or backorder warning.",
            status: "Manual check",
            color: .teal
          )
          WishlistResearchRunwayStep(
            number: "4",
            title: "Trust",
            detail: "Add seller trust evidence: known retailer, public reviews, returns address, warranty clarity, payment safety, and scam-risk notes.",
            status: gapCount == 0 ? "No gaps" : "Needs evidence",
            color: gapCount == 0 ? .green : .purple
          )
          WishlistResearchRunwayStep(
            number: "5",
            title: "Decision",
            detail: "Paste recommendation, caveats, and rejected alternatives. Local scoring can rank options only after fields are complete.",
            status: readyCount == 0 ? "Not ready" : "\(readyCount) ready",
            color: readyCount == 0 ? .secondary : .green
          )
          WishlistResearchRunwayStep(
            number: "6",
            title: "Boundaries",
            detail: "Do not paste passwords, card details, session links, checkout pages, private account data, or unverified live-price claims.",
            status: "No secrets",
            color: .orange
          )
        }

        CompactMetadataGrid(minimumWidth: horizontalSizeClass == .compact ? 135 : 170) {
          Badge("Must include product URL", color: .blue)
          Badge("Must include AUD total", color: missingAudCount == 0 ? .green : .orange)
          Badge("Postage time required", color: .teal)
          Badge("Trust evidence required", color: gapCount == 0 ? .green : .purple)
          Badge("No checkout/payment", color: .orange)
        }

        CompactActionRow {
          Button("Create paste-back task", systemImage: "checklist") {
            store.createReviewTask(
              linkedEntityType: .wishlistItem,
              linkedEntityID: "wishlist-research-paste-back-field-map",
              label: "Wishlist research paste-back",
              summary: "Use the Wishlist paste-back field map to enter seller comparison results locally. Required: seller identity, product URL, listed price/currency, AUD landed total, postage cost/time, seller trust evidence, returns/warranty, and recommendation. Do not store credentials, checkout links, payment data, or unverified live-price claims.",
              priority: .normal,
              assignee: "Wishlist review"
            )
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)

        Text("This is a local field map only. ParcelOps still does not browse retailer sites, compare live prices, convert currency live, quote postage, rate sellers externally, open accounts, buy items, or monitor orders from Wishlist.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistResearchResultQualityEntries: [WishlistResearchResultQualityEntry] {
    store.activeWishlistItems.compactMap { item in
      wishlistResearchResultQualityEntry(for: item)
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistResearchResultQualityPanel: some View {
    let entries = wishlistResearchResultQualityEntries
    let missingOptions = entries.filter { $0.stage == "Needs seller option" }.count
    let evidenceGaps = entries.filter { $0.stage == "Clean evidence" }.count
    let readyForDecision = entries.filter { $0.stage == "Ready for decision" }.count
    let preferredNeeded = entries.filter { $0.stage == "Select preferred" }.count

    return SettingsPanel(title: "Research result quality review", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this before turning comparison research into a purchase decision. It checks that seller options include a product link, AUD landed total, postage detail, returns/warranty evidence, and seller trust notes.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("In review", "\(entries.count)", entries.isEmpty ? .green : .purple),
          ("Need options", "\(missingOptions)", missingOptions == 0 ? .green : .orange),
          ("Evidence gaps", "\(evidenceGaps)", evidenceGaps == 0 ? .green : .orange),
          ("Pick preferred", "\(preferredNeeded)", preferredNeeded == 0 ? .green : .blue),
          ("Decision-ready", "\(readyForDecision)", readyForDecision == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          Label("No research-result QA is waiting. Seller options either have not been created yet or have already moved into purchase decision and handoff review.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistResearchResultQualityRow(entry: entry) {
                runWishlistResearchResultQualityPrimaryAction(for: entry)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: entry.item.id.uuidString,
                  label: entry.item.itemName,
                  summary: "Review wishlist seller research quality: \(entry.nextAction)",
                  priority: entry.stage == "Ready for decision" ? .normal : .high,
                  assignee: "Wishlist review"
                )
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .compare
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more research-result review item\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Still local only: this quality review does not browse retailer pages, convert currencies, quote postage, verify seller identity, log in, purchase, or monitor external stock.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistResearchResultQualityEntry(for item: WishlistItem) -> WishlistResearchResultQualityEntry? {
    let hasResearchRequest = store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id }
    let hasBatchDraft = store.draftMessages.contains {
      $0.linkedEntityType == .wishlistItem
        && $0.linkedEntityID == "wishlist-research-batch"
        && $0.body.localizedCaseInsensitiveContains(item.itemName)
    }
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    }
    let bestOption = options.sorted { first, second in
      first.operatorSellerMatrixScore > second.operatorSellerMatrixScore
    }.first
    let readyOptions = options.filter { $0.operatorSellerEvidenceGaps.isEmpty && $0.operatorSellerMatrixScore >= 70 }
    let gapLabels = Array(Set(options.flatMap(\.operatorSellerEvidenceGaps))).sorted()

    guard hasResearchRequest || hasBatchDraft || !options.isEmpty else { return nil }
    guard item.purchaseHandoff == nil else { return nil }

    let stage: String
    let detail: String
    let nextAction: String
    let primaryActionTitle: String
    let primaryActionSymbol: String
    let tone: Color
    let sortPriority: Int

    if options.isEmpty {
      stage = "Needs seller option"
      detail = "Research exists, but no seller option has been captured into the item yet."
      nextAction = "Add a seller option with product URL, AUD total, postage, trust, and returns/warranty evidence."
      primaryActionTitle = "Add option"
      primaryActionSymbol = "storefront.fill"
      tone = .orange
      sortPriority = 0
    } else if !gapLabels.isEmpty {
      stage = "Clean evidence"
      detail = "Seller options are recorded, but missing \(gapLabels.prefix(4).joined(separator: ", "))."
      nextAction = "Edit seller options, then score them again before purchase review."
      primaryActionTitle = "Score"
      primaryActionSymbol = "chart.bar.doc.horizontal"
      tone = .orange
      sortPriority = 10
    } else if readyOptions.isEmpty {
      stage = "Score review"
      detail = "Evidence fields are complete, but no seller option has reached the local decision threshold."
      nextAction = "Run local scoring and review seller risk before drafting a decision."
      primaryActionTitle = "Score"
      primaryActionSymbol = "chart.bar.doc.horizontal"
      tone = .purple
      sortPriority = 20
    } else if preferred == nil || preferred?.operatorSellerEvidenceGaps.isEmpty == false || (preferred?.operatorSellerMatrixScore ?? 0) < 70 {
      stage = "Select preferred"
      detail = "A viable seller exists. Choose the strongest option before drafting the purchase decision."
      nextAction = "Mark the best scored seller as preferred."
      primaryActionTitle = "Prefer best"
      primaryActionSymbol = "star.circle.fill"
      tone = .blue
      sortPriority = 30
    } else if item.purchaseDecision == nil {
      stage = "Ready for decision"
      detail = "Preferred seller has enough local evidence for a draft purchase decision."
      nextAction = "Draft the local purchase decision and keep live price/payment checks outside ParcelOps."
      primaryActionTitle = "Draft decision"
      primaryActionSymbol = "doc.badge.plus"
      tone = .green
      sortPriority = 40
    } else if item.purchaseDecision?.reviewState != .accepted {
      stage = "Decision review"
      detail = "Purchase decision exists and needs operator review before handoff."
      nextAction = "Review the decision or send it back for seller evidence cleanup."
      primaryActionTitle = "Decision task"
      primaryActionSymbol = "checklist"
      tone = .teal
      sortPriority = 50
    } else {
      stage = "Decision accepted"
      detail = "Decision is accepted locally; use purchase handoff before any real buy action."
      nextAction = "Prepare account/order-watch handoff if it has not already been created."
      primaryActionTitle = "Focus item"
      primaryActionSymbol = "scope"
      tone = .green
      sortPriority = 60
    }

    return WishlistResearchResultQualityEntry(
      item: item,
      bestOption: bestOption,
      preferredOption: preferred,
      readyOptionCount: readyOptions.count,
      evidenceGaps: gapLabels,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      primaryActionTitle: primaryActionTitle,
      primaryActionSymbol: primaryActionSymbol,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistResearchResultQualityPrimaryAction(for entry: WishlistResearchResultQualityEntry) {
    switch entry.stage {
    case "Needs seller option":
      store.addManualWishlistSellerOptionPlaceholder(entry.item)
    case "Clean evidence", "Score review":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Select preferred":
      if let option = entry.bestOption {
        store.markWishlistPreferredOption(entry.item, option: option)
      }
    case "Ready for decision":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .compare
    }
  }

  private var wishlistSellerComparisonDecisionRunwayEntries: [WishlistComparisonDecisionRunwayEntry] {
    store.activeWishlistItems.compactMap(wishlistSellerComparisonDecisionRunwayEntry(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistSellerComparisonDecisionRunwayPanel: some View {
    let entries = wishlistSellerComparisonDecisionRunwayEntries
    let needsOptions = entries.filter { $0.stage == "Need seller option" }.count
    let evidenceGaps = entries.filter { $0.stage == "Evidence gaps" }.count
    let needsPreferred = entries.filter { $0.stage == "Choose seller" }.count
    let needsDecision = entries.filter { $0.stage == "Draft decision" }.count
    let handoffReady = entries.filter { $0.stage == "Ready for handoff" }.count

    return SettingsPanel(title: "Seller comparison decision runway", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        Text("A local operator queue for turning captured seller comparisons into a safe purchase handoff. It favours complete evidence over cheap-looking sellers: product link, AUD landed total, postage time/cost, seller trust, returns/warranty, preferred seller, decision review, then handoff.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Need options", "\(needsOptions)", needsOptions == 0 ? .green : .orange),
          ("Evidence gaps", "\(evidenceGaps)", evidenceGaps == 0 ? .green : .orange),
          ("Choose seller", "\(needsPreferred)", needsPreferred == 0 ? .green : .blue),
          ("Draft decision", "\(needsDecision)", needsDecision == 0 ? .green : .purple),
          ("Handoff-ready", "\(handoffReady)", handoffReady == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller comparison decisions waiting",
            detail: "Create research briefs or seller options from Wishlist items first. This queue stays local and does not browse retailers, quote postage, or buy anything.",
            symbol: "arrow.triangle.branch"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistComparisonDecisionRunwayRow(entry: entry) {
                runWishlistSellerComparisonDecisionRunwayAction(for: entry)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: entry.item.id.uuidString,
                  label: entry.item.itemName,
                  summary: "Advance Wishlist seller comparison decision. Current stage: \(entry.stage). Next action: \(entry.nextAction)",
                  priority: entry.stage == "Ready for handoff" ? .normal : .high,
                  assignee: "Wishlist review"
                )
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
                selectedWorkflowFocus = .compare
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller comparison item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Still manual/local: no live retailer validation, exchange-rate lookup, postage quote, seller trust API, account login, checkout, payment, order monitoring, or mailbox mutation happens from this queue.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistSellerComparisonDecisionRunwayEntry(for item: WishlistItem) -> WishlistComparisonDecisionRunwayEntry? {
    let hasResearchContext = store.wishlistResearchRequests.contains { $0.wishlistItemID == item.id }
      || store.draftMessages.contains {
        $0.linkedEntityType == .wishlistItem
          && $0.linkedEntityID == "wishlist-research-batch"
          && $0.body.localizedCaseInsensitiveContains(item.itemName)
      }
    let options = item.comparisonOptions ?? []
    guard hasResearchContext || !options.isEmpty else { return nil }
    guard item.purchaseHandoff == nil else { return nil }

    let bestOption = options.sorted { first, second in
      first.operatorSellerMatrixScore > second.operatorSellerMatrixScore
    }.first
    let preferredOption = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    }
    let preferredGaps = preferredOption?.operatorSellerEvidenceGaps ?? []
    let allGapLabels = Array(Set(options.flatMap(\.operatorSellerEvidenceGaps))).sorted()

    let stage: String
    let detail: String
    let nextAction: String
    let primaryAction: String
    let primarySymbol: String
    let tone: Color
    let sortPriority: Int
    let blockers: [String]

    if options.isEmpty {
      stage = "Need seller option"
      detail = "Research context exists, but no seller option is captured locally."
      nextAction = "Add a seller option with product URL, landed AUD total, postage, trust, and returns/warranty notes."
      primaryAction = "Add option"
      primarySymbol = "storefront.fill"
      tone = .orange
      sortPriority = 0
      blockers = ["seller option"]
    } else if !allGapLabels.isEmpty {
      stage = "Evidence gaps"
      detail = "Seller options are present but still missing \(allGapLabels.prefix(4).joined(separator: ", "))."
      nextAction = "Edit seller evidence or re-score options before choosing a preferred seller."
      primaryAction = "Score"
      primarySymbol = "chart.bar.doc.horizontal"
      tone = .orange
      sortPriority = 10
      blockers = allGapLabels
    } else if preferredOption == nil {
      stage = "Choose seller"
      detail = "Seller evidence is complete enough for a local preferred-seller choice."
      nextAction = "Mark the strongest local seller as preferred before drafting a purchase decision."
      primaryAction = "Prefer best"
      primarySymbol = "star.circle.fill"
      tone = .blue
      sortPriority = 20
      blockers = []
    } else if !preferredGaps.isEmpty || (preferredOption?.operatorSellerMatrixScore ?? 0) < 65 {
      stage = "Preferred review"
      detail = "The preferred seller still needs evidence or risk review."
      nextAction = "Re-score and confirm the preferred seller has acceptable trust, postage, and AUD landed cost evidence."
      primaryAction = "Score"
      primarySymbol = "chart.bar.doc.horizontal"
      tone = .purple
      sortPriority = 30
      blockers = preferredGaps.isEmpty ? ["seller risk"] : preferredGaps
    } else if item.purchaseDecision == nil {
      stage = "Draft decision"
      detail = "A preferred seller exists with enough local evidence for a purchase decision draft."
      nextAction = "Draft a local purchase decision, then review it before real checkout outside ParcelOps."
      primaryAction = "Draft decision"
      primarySymbol = "doc.badge.plus"
      tone = .green
      sortPriority = 40
      blockers = []
    } else if item.purchaseDecision?.reviewState != .accepted {
      stage = "Decision review"
      detail = "The purchase decision exists but still needs operator review."
      nextAction = "Review the purchase decision or create a follow-up task if seller evidence is still weak."
      primaryAction = "Review task"
      primarySymbol = "checklist"
      tone = .teal
      sortPriority = 50
      blockers = ["decision review"]
    } else {
      stage = "Ready for handoff"
      detail = "Decision is accepted. Prepare account/order-watch handoff before any manual purchase."
      nextAction = "Prepare a local purchase handoff with account label and expected order-confirmation signals."
      primaryAction = "Prepare handoff"
      primarySymbol = "person.crop.circle.badge.checkmark"
      tone = .green
      sortPriority = 60
      blockers = []
    }

    return WishlistComparisonDecisionRunwayEntry(
      item: item,
      bestOption: bestOption,
      preferredOption: preferredOption,
      stage: stage,
      detail: detail,
      nextAction: nextAction,
      primaryAction: primaryAction,
      primarySymbol: primarySymbol,
      blockers: blockers,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistSellerComparisonDecisionRunwayAction(for entry: WishlistComparisonDecisionRunwayEntry) {
    switch entry.stage {
    case "Need seller option":
      store.addManualWishlistSellerOptionPlaceholder(entry.item)
    case "Evidence gaps", "Preferred review":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Choose seller":
      if let option = entry.bestOption {
        store.markWishlistPreferredOption(entry.item, option: option)
      }
    case "Draft decision":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    case "Ready for handoff":
      store.prepareWishlistPurchaseHandoff(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
      selectedWorkflowFocus = .compare
    }
  }

  private var wishlistCaptureContractPanel: some View {
    let candidates = store.wishlistCaptureCandidates
    let extensionCandidates = candidates.filter { $0.source == .browserExtension }.count
    let manualReady = store.wishlistItems.filter { store.isActiveWishlistItem($0) && $0.source == .manual && !$0.itemName.isPlaceholderValidationValue }.count
    let stagedWithGaps = candidates.filter { !$0.operatorCaptureGaps.isEmpty }.count

    return SettingsPanel(title: "Wishlist capture contract", symbol: "square.and.arrow.down.on.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the local contract for manual entry, future browser extension capture, share-sheet capture, screenshots, and PDF captures. Captures should stage a product idea first; seller comparison and purchase decisions happen later.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Staged", "\(candidates.count)", candidates.isEmpty ? .secondary : .blue),
          ("Extension", "\(extensionCandidates)", extensionCandidates == 0 ? .secondary : .teal),
          ("Manual ready", "\(manualReady)", manualReady == 0 ? .secondary : .green),
          ("Capture gaps", "\(stagedWithGaps)", stagedWithGaps == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 280), spacing: 10)], alignment: .leading, spacing: 10) {
          wishlistCaptureContractCard(
            title: "Minimum capture",
            symbol: "doc.text.magnifyingglass",
            tone: .blue,
            lines: [
              "Product or item name",
              "Source URL or capture note",
              "Retailer or website label",
              "Why it is wanted or needed"
            ]
          )
          wishlistCaptureContractCard(
            title: "Comparison-ready fields",
            symbol: "chart.bar.doc.horizontal",
            tone: .orange,
            lines: [
              "Listed price and currency",
              "Shipping/postage clue",
              "Seller region if visible",
              "Variant, size, model, or compatibility"
            ]
          )
          wishlistCaptureContractCard(
            title: "Trust cues",
            symbol: "shield.checkered",
            tone: .purple,
            lines: [
              "Seller identity and contact clues",
              "Returns or warranty text",
              "Marketplace versus direct seller",
              "Evidence gaps to verify later"
            ]
          )
          wishlistCaptureContractCard(
            title: "Strict boundary",
            symbol: "hand.raised.fill",
            tone: .red,
            lines: [
              "No checkout or payment",
              "No account login or credentials",
              "No live scraping or background sync",
              "No automatic seller trust claims"
            ]
          )
        }

        CompactActionRow {
          Button("Add manual item", systemImage: "plus", action: openManualWishlistItemForm)
          Button("Stage browser capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          Button("Create capture task", systemImage: "checklist") {
            store.createReviewTask(
              linkedEntityType: .wishlistItem,
              linkedEntityID: "wishlist-capture-contract",
              label: "Wishlist capture contract",
              summary: "Review Wishlist capture contract before using manual entry, share-sheet, browser extension, screenshot, or PDF capture paths. Confirm item name, source URL, retailer, price/currency clues, shipping clues, and trust evidence boundaries.",
              priority: .normal,
              assignee: "Wishlist capture"
            )
          }
        }
        .buttonStyle(.bordered)

        Text("Future extension output should write only staged capture candidates. ParcelOps should not buy, log in, scrape retailer pages, convert currency, quote postage, validate seller trust, or monitor orders from the capture step.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistCaptureSourceReadinessRows: [WishlistCaptureSourceReadiness] {
    let sources: [WishlistSource] = [.manual, .browserExtension, .shareSheet, .screenshot, .pdf]
    return sources.map { source in
      let activeItems = store.wishlistItems.filter { store.isActiveWishlistItem($0) && $0.source == source }.count
      let candidates = store.wishlistCaptureCandidates.filter { $0.source == source }
      let gaps = candidates.filter { !$0.operatorCaptureGaps.isEmpty }.count

      switch source {
      case .manual:
        return WishlistCaptureSourceReadiness(
          source: source,
          status: "Usable now",
          detail: "Manual entry is the current dependable path for adding wanted items. It should capture item name, seller/source, URL, estimated cost, owner, and why the item is needed.",
          operatorAction: activeItems == 0 ? "Add first manual item" : "Review manual item quality",
          activeItems: activeItems,
          stagedCandidates: candidates.count,
          gaps: gaps,
          tone: activeItems == 0 ? .orange : .green
        )
      case .browserExtension:
        return WishlistCaptureSourceReadiness(
          source: source,
          status: "Staging only",
          detail: "Browser extension capture is represented by local staged candidates. No extension is installed, no browser page is read, and no product data is synced automatically.",
          operatorAction: candidates.isEmpty ? "Stage placeholder capture" : "Review staged candidates",
          activeItems: activeItems,
          stagedCandidates: candidates.count,
          gaps: gaps,
          tone: gaps > 0 ? .orange : (candidates.isEmpty ? .secondary : .teal)
        )
      case .shareSheet:
        return WishlistCaptureSourceReadiness(
          source: source,
          status: "Future path",
          detail: "Share-sheet capture is a planned handoff for product pages or retailer links. It should stage a candidate first, not create a trusted purchase record directly.",
          operatorAction: "Define share payload before implementation",
          activeItems: activeItems,
          stagedCandidates: candidates.count,
          gaps: gaps,
          tone: candidates.isEmpty ? .secondary : .blue
        )
      case .screenshot:
        return WishlistCaptureSourceReadiness(
          source: source,
          status: "Placeholder",
          detail: "Screenshot capture currently creates local test items only. OCR, file pickers, image import, and product extraction are not connected.",
          operatorAction: "Use only for workflow testing",
          activeItems: activeItems,
          stagedCandidates: candidates.count,
          gaps: gaps,
          tone: activeItems == 0 ? .secondary : .purple
        )
      case .pdf:
        return WishlistCaptureSourceReadiness(
          source: source,
          status: "Placeholder",
          detail: "PDF capture currently creates local test items only. PDF picking, parsing, OCR, and supplier document extraction are not connected.",
          operatorAction: "Use only for workflow testing",
          activeItems: activeItems,
          stagedCandidates: candidates.count,
          gaps: gaps,
          tone: activeItems == 0 ? .secondary : .brown
        )
      }
    }
  }

  private var wishlistCaptureSourceReadinessPanel: some View {
    let rows = wishlistCaptureSourceReadinessRows
    let usable = rows.filter { $0.status == "Usable now" }.count
    let staged = rows.reduce(0) { $0 + $1.stagedCandidates }
    let gaps = rows.reduce(0) { $0 + $1.gaps }
    let placeholders = rows.filter { $0.status == "Placeholder" || $0.status == "Future path" }.count

    return SettingsPanel(title: "Capture source readiness", symbol: "square.and.arrow.down.badge.clock") {
      VStack(alignment: .leading, spacing: 12) {
        Text("A practical map of which Wishlist capture paths are usable today and which are still staged or planned. Use this before relying on browser, share, screenshot, or PDF intake for real purchase decisions.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Usable now", "\(usable)", usable == 0 ? .orange : .green),
          ("Staged candidates", "\(staged)", staged == 0 ? .secondary : .teal),
          ("Capture gaps", "\(gaps)", gaps == 0 ? .green : .orange),
          ("Planned paths", "\(placeholders)", placeholders == 0 ? .green : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 330), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(rows) { row in
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: row.source.symbol)
                  .foregroundStyle(row.tone)
                  .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                  Text(row.source.rawValue)
                    .font(.caption.weight(.semibold))
                  Text(row.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(row.status, color: row.tone)
              }

              CompactMetadataGrid(minimumWidth: 115) {
                Badge("\(row.activeItems) items", color: row.activeItems == 0 ? .secondary : .blue)
                Badge("\(row.stagedCandidates) staged", color: row.stagedCandidates == 0 ? .secondary : .teal)
                Badge("\(row.gaps) gaps", color: row.gaps == 0 ? .green : .orange)
                Badge(row.operatorAction, color: row.tone)
              }

              CompactActionRow {
                if row.source == .manual {
                  Button("Manual item", systemImage: "plus", action: openManualWishlistItemForm)
                } else if row.source == .browserExtension {
                  Button("Stage capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
                }
                Button("Task", systemImage: "checklist") {
                  store.createReviewTask(
                    linkedEntityType: .wishlistItem,
                    linkedEntityID: "wishlist-capture-\(row.source.rawValue)",
                    label: "Wishlist \(row.source.rawValue) capture readiness",
                    summary: "Review Wishlist \(row.source.rawValue) capture readiness. Status: \(row.status). Action: \(row.operatorAction). Confirm the source captures item, URL, seller, price, postage clues, and trust evidence before it feeds comparison or purchase decisions.",
                    priority: row.gaps > 0 ? .high : .normal,
                    assignee: "Wishlist capture"
                  )
                }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
            .padding(10)
            .background(row.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Only manual entry and local placeholder staging are active. ParcelOps does not install browser extensions, receive share-sheet payloads, read screenshots/PDFs, scrape retailer pages, or validate live product data from this panel.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistBrowserExtensionPayloadFields: [WishlistExtensionPayloadField] {
    [
      WishlistExtensionPayloadField(
        name: "Page title",
        requirement: "Required",
        detail: "Used as the first product/item name candidate. Operators must still confirm it before comparison.",
        tone: .blue
      ),
      WishlistExtensionPayloadField(
        name: "Canonical product URL",
        requirement: "Required",
        detail: "Must be a product or seller page URL. Shorteners, login pages, carts, checkout pages, and tracking redirect URLs should be rejected.",
        tone: .blue
      ),
      WishlistExtensionPayloadField(
        name: "Seller/storefront",
        requirement: "Required",
        detail: "Should identify the retailer, marketplace, or direct manufacturer. Unknown sellers stay in capture review.",
        tone: .orange
      ),
      WishlistExtensionPayloadField(
        name: "Visible price/currency",
        requirement: "Recommended",
        detail: "Record exactly what was visible, including currency. AUD landed total is calculated or reviewed later, not at capture time.",
        tone: .green
      ),
      WishlistExtensionPayloadField(
        name: "Postage clue",
        requirement: "Recommended",
        detail: "Capture visible shipping, delivery date, free-postage, pickup, or international-delivery text only as an unverified clue.",
        tone: .teal
      ),
      WishlistExtensionPayloadField(
        name: "Variant/model clues",
        requirement: "Recommended",
        detail: "Size, colour, model, capacity, compatibility, SKU, or option text helps avoid buying the wrong item.",
        tone: .purple
      ),
      WishlistExtensionPayloadField(
        name: "Trust/returns clue",
        requirement: "Optional",
        detail: "Capture visible seller rating, returns, warranty, ABN/contact, marketplace seller, or delivery-risk text as evidence to review later.",
        tone: .brown
      ),
      WishlistExtensionPayloadField(
        name: "Operator note",
        requirement: "Optional",
        detail: "A human reason for wanting the item. This should not contain passwords, payment details, account cookies, or private checkout data.",
        tone: .secondary
      )
    ]
  }

  private var wishlistBrowserExtensionPayloadPanel: some View {
    let staged = store.wishlistCaptureCandidates.filter { $0.source == .browserExtension }
    let gaps = staged.filter { !$0.operatorCaptureGaps.isEmpty }.count
    let ready = staged.count - gaps
    let fields = wishlistBrowserExtensionPayloadFields

    return SettingsPanel(title: "Browser extension payload contract", symbol: "puzzlepiece.extension.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("A local contract for a future browser extension. The extension should only create staged capture candidates with safe page metadata. It must not scrape accounts, read checkout pages, capture credentials, purchase items, or sync in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Payload fields", "\(fields.count)", .blue),
          ("Extension staged", "\(staged.count)", staged.isEmpty ? .secondary : .teal),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("With gaps", "\(gaps)", gaps == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 310), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(fields) { field in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline) {
                Text(field.name)
                  .font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Badge(field.requirement, color: field.tone)
              }
              Text(field.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(field.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        VStack(alignment: .leading, spacing: 8) {
          Label("Reject extension payloads when:", systemImage: "hand.raised.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.red)
          CompactMetadataGrid(minimumWidth: 170) {
            Badge("Checkout/cart page", color: .red)
            Badge("Login/account page", color: .red)
            Badge("Missing product URL", color: .orange)
            Badge("Unknown seller", color: .orange)
            Badge("Credential/payment text", color: .red)
            Badge("Background capture", color: .red)
          }
        }
        .padding(10)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

        CompactActionRow {
          Button("Stage sample payload", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          Button("Create extension task", systemImage: "checklist") {
            store.createReviewTask(
              linkedEntityType: .wishlistItem,
              linkedEntityID: "wishlist-browser-extension-payload",
              label: "Wishlist browser extension payload contract",
              summary: "Review the future Wishlist browser extension payload contract. Required safe fields: page title, canonical product URL, seller/storefront, plus optional price, postage, variant, trust/returns, and operator notes. Reject checkout, login, credential, payment, or background-capture payloads.",
              priority: .normal,
              assignee: "Wishlist capture"
            )
          }
        }
        .buttonStyle(.bordered)

        Text("This panel is only a contract. ParcelOps does not install a browser extension, read browser tabs, scrape pages, collect cookies, access accounts, capture payment details, or send data to an external service.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private func wishlistCaptureContractCard(title: String, symbol: String, tone: Color, lines: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone)
      ForEach(lines, id: \.self) { line in
        Label(line, systemImage: "checkmark.circle")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var wishlistCaptureCandidatesPanel: some View {
    let candidates = store.wishlistCaptureCandidates
    let readyCount = candidates.filter { $0.operatorCaptureGaps.isEmpty }.count
    let gapCount = candidates.count - readyCount
    let shareOrExtensionCount = candidates.filter { $0.source == .browserExtension || $0.source == .shareSheet }.count

    return SettingsPanel(title: "Capture candidate staging", symbol: "puzzlepiece.extension.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review local product-page capture candidates before they become Wishlist items. This is the boundary a future browser extension or share flow can write into; this screen does not install an extension, scrape pages, or sync with a browser.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(candidates.count) staged", color: candidates.isEmpty ? .secondary : .blue)
          Badge("\(readyCount) ready", color: readyCount == 0 ? .secondary : .green)
          Badge("\(gapCount) with gaps", color: gapCount == 0 ? .green : .orange)
          Badge("\(candidates.filter { $0.reviewState == .needsReview }.count) needs review", color: candidates.contains { $0.reviewState == .needsReview } ? .orange : .green)
          Badge("\(shareOrExtensionCount) share/extension", color: shareOrExtensionCount == 0 ? .secondary : .teal)
        }

        CompactActionRow {
          Button("Paste product link", systemImage: "link.badge.plus") {
            showPastedLinkCaptureForm = true
          }
          Button("Add browser capture placeholder", systemImage: "puzzlepiece.extension.fill") {
            store.addBrowserExtensionWishlistCapturePlaceholder()
          }
        }
        .buttonStyle(.bordered)

        if candidates.isEmpty {
          MVPEmptyState(
            title: "No staged capture candidates",
            detail: "Use the browser capture placeholder to test the future extension handoff without reading any browser page or contacting external services.",
            symbol: "puzzlepiece.extension.fill",
            actionTitle: "Add placeholder",
            action: store.addBrowserExtensionWishlistCapturePlaceholder
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 320), spacing: 10)], spacing: 10) {
            ForEach(candidates) { capture in
              WishlistCaptureCandidateRow(capture: capture) {
                editingCaptureCandidate = capture
              } onPromote: {
                store.promoteWishlistCaptureToItem(capture)
              } onDismiss: {
                store.dismissWishlistCapture(capture)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: capture.id.uuidString,
                  label: capture.pageTitle,
                  summary: "Review Wishlist capture candidate before promotion. Gaps: \(capture.operatorCaptureGaps.isEmpty ? "none" : capture.operatorCaptureGaps.joined(separator: ", ")). Source: \(capture.source.rawValue).",
                  priority: capture.operatorCaptureGaps.isEmpty ? .normal : .high,
                  assignee: "Wishlist capture"
                )
              }
            }
          }
        }

        Text("Promoting a capture creates a local Wishlist item only. It does not verify the seller, fetch the product page, scrape the browser, check live price, or start a purchase.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistResearchRequestsPanel: some View {
    let requests = store.activeWishlistResearchRequests
    let openRequests = requests.filter { $0.reviewState != .accepted }
    let blockedRequests = requests.filter { $0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let readyRequests = requests.filter(\.isAgentBriefReady)
    let scopeGapRequests = requests.filter { !$0.isAgentBriefReady }

    return SettingsPanel(title: "Future agent research queue", symbol: "list.bullet.clipboard.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("These are local briefs for a future comparison agent. Each request defines what to compare across Australian and overseas retailers, which postage details to capture, what seller trust evidence is required, and what the agent must not do before buying.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Research briefs", "\(requests.count)", requests.isEmpty ? .secondary : .blue),
          ("Open", "\(openRequests.count)", openRequests.isEmpty ? .green : .orange),
          ("Agent-ready", "\(readyRequests.count)", readyRequests.isEmpty ? .secondary : .green),
          ("Scope gaps", "\(scopeGapRequests.count)", scopeGapRequests.isEmpty ? .green : .orange),
          ("Blocked", "\(blockedRequests.count)", blockedRequests.isEmpty ? .green : .red)
        ])

        if !scopeGapRequests.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Briefs needing scope")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(scopeGapRequests.prefix(4)) { request in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(request.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text(request.agentBriefNextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : .orange)
              }
              .padding(8)
              .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        if requests.isEmpty {
          MVPEmptyState(
            title: "No research briefs yet",
            detail: "Use Compare on a Wishlist item to create a local brief for future seller research. No live web search or external agent runs from this screen.",
            symbol: "list.bullet.clipboard.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 340), spacing: 10)], spacing: 10) {
            ForEach(requests) { request in
              WishlistResearchRequestRow(request: request) {
                store.markWishlistResearchRequestReviewed(request)
              } onBlock: {
                store.blockWishlistResearchRequest(request)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: request.wishlistItemID?.uuidString ?? request.id.uuidString,
                  label: request.itemName,
                  summary: "Prepare wishlist comparison research: \(request.itemName). Confirm seller criteria, AUD landed cost, postage timing, returns/warranty, and seller trust requirements before any purchase.",
                  priority: request.reviewState == .needsReview ? .high : .normal,
                  assignee: "Wishlist review"
                )
              } onDraft: {
                store.createWishlistResearchBriefDraft(request)
              } onRemove: {
                store.removeWishlistResearchRequest(request)
              }
            }
          }
        }

        Text("Not active yet: browsing retailer sites, exchange-rate lookup, postage quote APIs, seller trust services, browser automation, account login, checkout, payment, or background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
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
            ("Wishlist items", "\(store.activeWishlistItemCount)", store.activeWishlistItemCount == 0 ? .secondary : .green),
            ("Needs review", "\(store.activeWishlistStatusReviewCount)", store.activeWishlistStatusReviewCount > 0 ? .orange : .green)
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
              openManualWishlistItemForm()
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

private struct WishlistPurchaseReleaseGate: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var actionTitle: String
  var actionSymbol: String
  var checks: [(String, Bool)]
  var tone: Color
  var sortPriority: Int

  var isReadyForManualPurchase: Bool {
    stage == "Ready for manual purchase"
  }

  var isLinkedOrder: Bool {
    stage == "Linked order released"
  }
}

private struct WishlistReadinessBlockerSummary: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var preferredSeller: String
  var category: String
  var nextAction: String
  var failedChecks: [WishlistPurchaseCheck]
  var criticalChecks: [WishlistPurchaseCheck]
  var detail: String

  var sortPriority: Int {
    if !criticalChecks.isEmpty { return 0 }
    if category == "Seller trust" { return 1 }
    if category == "Postage" || category == "AUD landed cost" { return 2 }
    return 3
  }

  var tone: Color {
    if !criticalChecks.isEmpty { return .red }
    if category == "Postage" { return .teal }
    if category == "AUD landed cost" { return .brown }
    return .orange
  }
}

private struct WishlistReadinessBlockerSummaryRow: View {
  var summary: WishlistReadinessBlockerSummary
  var onRunCheck: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: summary.criticalChecks.isEmpty ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(summary.tone)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 3) {
          Text(summary.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text("\(summary.preferredSeller) • \(summary.item.owner)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge("\(summary.failedChecks.count) checks", color: summary.tone)
      }

      HStack(spacing: 6) {
        Badge(summary.category, color: summary.tone)
        Badge(summary.nextAction, color: .blue)
      }

      Text(summary.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if summary.failedChecks.count > 1 {
        Text("Also review: \(summary.failedChecks.dropFirst().prefix(2).map(\.title).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button("Run check", systemImage: "checklist.checked", action: onRunCheck)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(summary.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistManualPurchaseDayPlanEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var seller: String
  var account: String
  var linkedOrder: TrackedOrder?
  var confirmationCandidates: Int
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var detail: String
  var steps: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseOperatorChecklist: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var selectedSeller: String
  var totalAUD: String
  var postage: String
  var trust: String
  var handoff: String
  var manualChecks: [(String, Bool)]
  var blockers: [String]
  var liveVerification: [String]
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseOperatorChecklistRow: View {
  var checklist: WishlistPurchaseOperatorChecklist
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
          .foregroundStyle(checklist.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(checklist.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(checklist.selectedSeller)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(checklist.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(checklist.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(checklist.stage, color: checklist.tone)
      }

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "AUD", value: checklist.totalAUD, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: checklist.postage, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: checklist.trust, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Handoff", value: checklist.handoff, symbol: "person.crop.circle.badge.checkmark")
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Local checklist")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        CompactMetadataGrid(minimumWidth: 118) {
          ForEach(checklist.manualChecks, id: \.0) { check in
            Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(check.1 ? Color.green : Color.secondary)
              .lineLimit(1)
          }
        }
      }

      if !checklist.blockers.isEmpty {
        Text("Before buying: \(checklist.blockers.prefix(4).joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 5) {
        Label("Manual live verification", systemImage: "hand.raised.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
          ForEach(checklist.liveVerification, id: \.self) { label in
            Badge(label, color: .orange)
          }
        }
      }

      CompactActionRow {
        Button(checklist.actionTitle, systemImage: checklist.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(checklist.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseAccountLedgerEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff?
  var linkedOrder: TrackedOrder?
  var candidateCount: Int
  var stage: String
  var detail: String
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseApprovalRow: View {
  var record: WishlistPurchaseApprovalRecord
  var onApprove: () -> Void
  var onBlock: () -> Void
  var onRemove: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isApproved: Bool {
    record.reviewState == .accepted || record.approvalStatus.localizedCaseInsensitiveContains("approved")
  }

  private var isBlocked: Bool {
    record.approvalStatus.localizedCaseInsensitiveContains("blocked")
  }

  private var tone: Color {
    if isBlocked { return .red }
    if isApproved { return .green }
    if record.reviewState == .needsReview { return .orange }
    return .purple
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isApproved ? "checkmark.seal.fill" : "checkmark.seal")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(record.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(record.sellerName) • \(record.approvalStatus)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(record.approvalReason)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(record.reviewState.rawValue, color: isApproved ? .green : .orange)
          Badge(record.lastReviewedDate, color: .secondary)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Limit", value: record.approvedAUDLimit, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Budget", value: record.budgetCode, symbol: "tag.fill")
        WishlistMatrixMetric(title: "Approver", value: record.approver, symbol: "person.crop.circle.fill")
        WishlistMatrixMetric(title: "Payment", value: record.paymentMethodSummary, symbol: "creditcard.fill")
      }

      Text(record.notes)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Approve", systemImage: "checkmark.seal", action: onApprove)
          .disabled(isApproved)
        Button("Block", systemImage: "exclamationmark.octagon", action: onBlock)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
        Button("Remove", systemImage: "trash", action: onRemove)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(12)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(tone.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct WishlistPurchaseLinkRow: View {
  var record: WishlistPurchaseLinkRecord
  var onSelect: () -> Void
  var onReady: () -> Void
  var onBlock: () -> Void
  var onRemove: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isReady: Bool {
    record.reviewState == .accepted || record.readinessStatus.localizedCaseInsensitiveContains("ready")
  }

  private var isBlocked: Bool {
    record.readinessStatus.localizedCaseInsensitiveContains("blocked")
  }

  private var tone: Color {
    if isBlocked { return .red }
    if isReady { return .green }
    if record.selectedForPurchase { return .purple }
    if record.reviewState == .needsReview { return .orange }
    return .blue
  }

  private var safeURLSummary: String {
    guard let host = URL(string: record.productURL)?.host else { return record.productURL }
    return host
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: record.selectedForPurchase ? "link.badge.plus" : "link")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(record.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(record.sellerName) • \(safeURLSummary)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(record.readinessStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(record.selectedForPurchase ? "Selected" : record.linkType, color: record.selectedForPurchase ? .purple : .blue)
          Badge(record.reviewState.rawValue, color: isReady ? .green : .orange)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "AUD total", value: record.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: record.postageSummary, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: record.trustSummary, symbol: "shield.lefthalf.filled")
        WishlistMatrixMetric(title: "Account", value: record.accountContext, symbol: "person.crop.circle.fill")
      }

      Text(record.notes)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Select", systemImage: "scope", action: onSelect)
          .disabled(record.selectedForPurchase)
        Button("Ready", systemImage: "checkmark.seal", action: onReady)
          .disabled(isReady)
        Button("Block", systemImage: "exclamationmark.octagon", action: onBlock)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "magnifyingglass", action: onFocus)
        Button("Remove", systemImage: "trash", action: onRemove)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(12)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(tone.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct WishlistOrderWatchRecordRow: View {
  var record: WishlistOrderWatchRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var candidateMatches: [ForwardedEmailIntake] = []
  var onCheck: () -> Void
  var onReviewed: () -> Void
  var onBlock: () -> Void
  var onRemove: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void
  var onUseConfirmation: (ForwardedEmailIntake) -> Void = { _ in }

  private var isLinked: Bool {
    record.linkedOrderID != nil || record.watchStatus.localizedCaseInsensitiveContains("matched")
  }

  private var isBlocked: Bool {
    record.watchStatus.localizedCaseInsensitiveContains("blocked")
  }

  private var tone: Color {
    if isBlocked { return .red }
    if isLinked || record.reviewState == .accepted { return .green }
    if record.watchStatus.localizedCaseInsensitiveContains("no local") { return .orange }
    return .purple
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isLinked ? "envelope.badge.fill" : "envelope.badge.shield.half.filled")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(record.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(record.sellerName) • \(record.watchStatus)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(record.nextCheckSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(record.linkedOrderID == nil ? "No order link" : "Linked", color: record.linkedOrderID == nil ? .orange : .green)
          Badge(record.reviewState.rawValue, color: record.reviewState == .accepted ? .green : .orange)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Account", value: record.accountLabel, symbol: "person.crop.circle.fill")
        WishlistMatrixMetric(title: "Source", value: record.expectedMailboxOrSource, symbol: "tray.full.fill")
        WishlistMatrixMetric(title: "Signals", value: record.expectedOrderSignals, symbol: "magnifyingglass")
        WishlistMatrixMetric(title: "Match", value: record.matchedOrderSummary, symbol: "link")
      }

      Text(record.notes)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      if let linkedOrder {
        VStack(alignment: .leading, spacing: 6) {
          Label("Linked local order", systemImage: "link.badge.plus")
            .font(.caption.bold())
            .foregroundStyle(.green)
          HStack(spacing: 6) {
            Badge(linkedOrder.orderNumber, color: .green)
            Badge(linkedOrder.store, color: .secondary)
            Badge(linkedOrder.status.rawValue, color: linkedOrder.status.color)
          }
        }
      } else if !candidateMatches.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Possible Inbox confirmations", systemImage: "tray.full.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(candidateMatches.prefix(2)) { email in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              VStack(alignment: .leading, spacing: 2) {
                Text(email.subject)
                  .font(.caption.weight(.semibold))
                  .lineLimit(1)
                Text("\(email.detectedOrderNumber.isPlaceholderValidationValue ? "Order needs review" : email.detectedOrderNumber) • \(email.detectedTrackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : email.detectedTrackingNumber)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer(minLength: 8)
              Button("Use", systemImage: "link") {
                onUseConfirmation(email)
              }
              .buttonStyle(.bordered)
              .controlSize(.mini)
            }
          }
          Text("Using a match links the existing local Inbox confirmation to this Wishlist item; it does not fetch mail or change the mailbox.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
      }

      CompactActionRow {
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
        }
        Button("Check local", systemImage: "magnifyingglass", action: onCheck)
        Button("Reviewed", systemImage: "checkmark.seal", action: onReviewed)
          .disabled(record.reviewState == .accepted)
        Button("Block", systemImage: "exclamationmark.octagon", action: onBlock)
        Button(isLinked ? "Task" : "Find confirmation", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
        Button("Remove", systemImage: "trash", action: onRemove)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(12)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(tone.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct WishlistPurchaseAccountReadinessRow: View {
  var record: WishlistPurchaseAccountRecord
  var onReady: () -> Void
  var onBlock: () -> Void
  var onRemove: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isReady: Bool {
    record.reviewState == .accepted && record.accountReadinessStatus.localizedCaseInsensitiveContains("ready")
  }

  private var isBlocked: Bool {
    record.accountReadinessStatus.localizedCaseInsensitiveContains("blocked")
      || record.paymentReadinessStatus.localizedCaseInsensitiveContains("do not")
  }

  private var tone: Color {
    if isBlocked { return .red }
    if isReady { return .green }
    if record.reviewState == .needsReview { return .orange }
    return .purple
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isReady ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.exclamationmark")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(record.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(record.sellerName) • \(record.accountLabel)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(record.accountReadinessStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(record.reviewState.rawValue, color: record.reviewState == .accepted ? .green : .orange)
          Badge(record.lastReviewedDate, color: .secondary)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Payment", value: record.paymentReadinessStatus, symbol: "creditcard.fill")
        WishlistMatrixMetric(title: "Delivery", value: record.deliveryAddressStatus, symbol: "mappin.and.ellipse")
        WishlistMatrixMetric(title: "Signals", value: record.expectedOrderEmailSignals, symbol: "envelope.badge.fill")
        WishlistMatrixMetric(title: "Credential", value: record.credentialStorageNote, symbol: "key.slash.fill")
      }

      Text(record.purchaseBoundaryNote)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Ready", systemImage: "checkmark.seal", action: onReady)
          .disabled(isReady)
        Button("Block", systemImage: "exclamationmark.octagon", action: onBlock)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
        Button("Remove", systemImage: "trash", action: onRemove)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPostPurchaseMonitorEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff?
  var linkedOrder: TrackedOrder?
  var matches: [ForwardedEmailIntake]
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseWatchCommandCentreEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff?
  var linkedOrder: TrackedOrder?
  var inboxMatchCount: Int
  var operationsGapCount: Int
  var operationRecordCount: Int
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistSellerDecisionSnapshotEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var selectedOption: WishlistComparisonOption?
  var optionCount: Int
  var gapCount: Int
  var gapSummary: String
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistSellerDecisionSnapshotRow: View {
  var entry: WishlistSellerDecisionSnapshotEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var sellerSummary: String {
    guard let option = entry.selectedOption else {
      return entry.item.storefront.isPlaceholderValidationValue ? "Seller options not recorded" : entry.item.storefront
    }
    return "\(option.sellerName) • \(option.estimatedAUDTotal)"
  }

  private var postageSummary: String {
    guard let option = entry.selectedOption else { return "Postage not recorded" }
    return "\(option.postageCost) • \(option.postageTime)"
  }

  private var trustSummary: String {
    entry.selectedOption?.trustRating ?? "Trust not recorded"
  }

  private var scoreSummary: String {
    guard let score = entry.selectedOption?.localScore else { return "Unscored" }
    return "\(score)/100"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 128) {
        WishlistMatrixMetric(title: "Seller", value: sellerSummary, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Postage", value: postageSummary, symbol: "truck.box.fill")
        WishlistMatrixMetric(title: "Trust", value: trustSummary, symbol: "shield.lefthalf.filled")
        WishlistMatrixMetric(title: "Score", value: scoreSummary, symbol: "chart.bar.doc.horizontal")
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Badge("\(entry.optionCount) option\(entry.optionCount == 1 ? "" : "s")", color: entry.optionCount == 0 ? .orange : .blue)
        Badge("\(entry.gapCount) gap\(entry.gapCount == 1 ? "" : "s")", color: entry.gapCount == 0 ? .green : .orange)
      }

      Text(entry.gapSummary)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(entry.gapCount == 0 ? Color.green : entry.tone)
        .fixedSize(horizontal: false, vertical: true)

      Text("Review live price, stock, postage, seller trust, returns, account fit, and payment details outside ParcelOps before buying.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseWatchCommandCentreRow: View {
  var entry: WishlistPurchaseWatchCommandCentreEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var sellerSummary: String {
    if let handoff = entry.handoff {
      return "\(handoff.sellerName) via \(handoff.accountLabel)"
    }
    return entry.item.storefront.isPlaceholderValidationValue ? "Seller/account handoff not prepared" : entry.item.storefront
  }

  private var orderSummary: String {
    if let linkedOrder = entry.linkedOrder {
      return "\(linkedOrder.orderNumber) linked"
    }
    if entry.inboxMatchCount > 0 {
      return "\(entry.inboxMatchCount) Inbox candidate\(entry.inboxMatchCount == 1 ? "" : "s")"
    }
    return "No order confirmation linked"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 130) {
        Label(sellerSummary, systemImage: "storefront.fill")
        Label(orderSummary, systemImage: "envelope.badge.fill")
        Label("\(entry.operationRecordCount) ops records", systemImage: "shippingbox.fill")
        Label(entry.operationsGapCount == 0 ? "No ops gaps" : "\(entry.operationsGapCount) ops gaps", systemImage: entry.operationsGapCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if let watchStatus = entry.handoff?.orderWatchStatus, !watchStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(watchStatus)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPostPurchaseMonitorRow: View {
  var entry: WishlistPostPurchaseMonitorEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var orderSummary: String {
    if let linkedOrder = entry.linkedOrder {
      return "\(linkedOrder.store) \(linkedOrder.orderNumber) • \(linkedOrder.status)"
    }
    if let handoff = entry.handoff {
      return "\(handoff.sellerName) • \(handoff.accountLabel) • \(handoff.purchaseStatus)"
    }
    return "No purchase handoff yet"
  }

  private var confirmationSummary: String {
    if entry.matches.isEmpty {
      return "No Inbox confirmation candidates"
    }
    let first = entry.matches[0]
    let order = first.detectedOrderNumber.isPlaceholderValidationValue ? "order pending" : first.detectedOrderNumber
    let tracking = first.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking pending" : first.detectedTrackingNumber
    return "\(entry.matches.count) candidate\(entry.matches.count == 1 ? "" : "s") • \(order) • \(tracking)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.linkedOrder == nil ? "bag.badge.clock.fill" : "bag.badge.checkmark.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(orderSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          if !entry.matches.isEmpty {
            Badge("\(entry.matches.count) match\(entry.matches.count == 1 ? "" : "es")", color: .teal)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 135) {
        WishlistMatrixMetric(title: "Confirmation", value: confirmationSummary, symbol: "envelope.badge.fill")
        WishlistMatrixMetric(title: "Order link", value: entry.linkedOrder?.orderNumber ?? "Not linked", symbol: "link")
        WishlistMatrixMetric(title: "Watch status", value: entry.handoff?.orderWatchStatus ?? "No handoff", symbol: "eye.fill")
        WishlistMatrixMetric(title: "Purchase status", value: entry.handoff?.purchaseStatus ?? entry.item.status, symbol: "bag.fill")
      }

      Text("Manual follow-up only. Use Inbox confirmation or local order link as the source of truth after buying externally.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseAccountLedgerRow: View {
  var entry: WishlistPurchaseAccountLedgerEntry
  var onAction: () -> Void
  var onPurchased: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var seller: String {
    entry.handoff?.sellerName ?? entry.item.purchaseDecision?.selectedSellerName ?? entry.item.storefront
  }

  private var account: String {
    entry.handoff?.accountLabel ?? "\(entry.item.owner) account to confirm"
  }

  private var orderSummary: String {
    entry.linkedOrder?.orderNumber ?? "No linked order"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "person.crop.circle.badge.clock.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(seller) • \(account)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "Seller", value: seller, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Account", value: account, symbol: "person.crop.circle.badge.key.fill")
        WishlistMatrixMetric(title: "Order", value: orderSummary, symbol: "link")
        WishlistMatrixMetric(title: "Candidates", value: "\(entry.candidateCount) Inbox", symbol: "envelope.badge.fill")
      }

      if let handoff = entry.handoff {
        VStack(alignment: .leading, spacing: 5) {
          Label("Order-watch notes", systemImage: "eye.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(handoff.expectedOrderSignals)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Text(handoff.orderWatchStatus)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else {
        Text("No purchase handoff exists yet. Prepare one before buying externally so the account label and expected confirmation text are captured locally.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.purple)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Local-only ledger: no account login, checkout, payment, mailbox mutation, carrier booking, or background monitoring occurs here.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.actionTitle, systemImage: entry.actionSymbol, action: onAction)
        Button("Purchased", systemImage: "bag.fill", action: onPurchased)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPostPurchaseOrderWatchEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff
  var matches: [ForwardedEmailIntake]
  var stage: String
  var detail: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistOrderConfirmationMatchReviewRow: View {
  var entry: WishlistPostPurchaseOrderWatchEntry
  var onUseConfirmation: (ForwardedEmailIntake) -> Void
  var onMarkSeen: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var matchSummary: String {
    if entry.matches.isEmpty {
      return "No imported Inbox match yet"
    }
    let first = entry.matches[0]
    let order = first.detectedOrderNumber.isPlaceholderValidationValue ? "order pending" : "order \(first.detectedOrderNumber)"
    let tracking = first.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking pending" : "tracking \(first.detectedTrackingNumber)"
    return "\(entry.matches.count) match\(entry.matches.count == 1 ? "" : "es") • \(order) • \(tracking)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.matches.isEmpty ? "envelope.badge.clock" : "link.badge.plus")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.handoff.sellerName) • \(entry.handoff.accountLabel)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(matchSummary)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      WishlistOrderWatchMatchRow(
        item: entry.item,
        matches: Array(entry.matches.prefix(3)),
        onUseConfirmation: onUseConfirmation,
        onMarkSeen: onMarkSeen
      )

      CompactActionRow {
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseOperationsHandoffEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var stage: String
  var detail: String
  var gaps: [String]
  var inspectionCount: Int
  var receiptCount: Int
  var storageCount: Int
  var custodyCount: Int
  var labelCount: Int
  var scanCount: Int
  var manifestCount: Int
  var dispatchCount: Int
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistLinkedOrderOperationsChecklistEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var phaseChecks: [(String, Bool)]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistLinkedOrderFollowUpDashboardEntry: Identifiable {
  var id: UUID { checklist.item.id }
  var checklist: WishlistLinkedOrderOperationsChecklistEntry
  var linkedOrder: TrackedOrder
  var openTaskCount: Int
  var missingPhases: [String]
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistOperationsClosureReadinessEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var phaseChecks: [(String, Bool)]
  var openTaskCount: Int
  var gaps: [String]
  var stage: String
  var detail: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseOperationsHandoffRow: View {
  var entry: WishlistPurchaseOperationsHandoffEntry
  var store: ParcelOpsStore
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var orderValue: String {
    entry.linkedOrder?.orderNumber ?? "Not linked"
  }

  private var gapSummary: String {
    entry.gaps.isEmpty ? "No downstream setup gaps detected." : "Next gaps: \(entry.gaps.prefix(5).joined(separator: ", "))."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.triangle.branch")
          .foregroundStyle(entry.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.item.storefront) • \(entry.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 118) {
        WishlistMatrixMetric(title: "Order", value: orderValue, symbol: "link")
        WishlistMatrixMetric(title: "Receiving", value: "\(entry.inspectionCount)", symbol: "checkmark.seal.fill")
        WishlistMatrixMetric(title: "Inventory", value: "\(entry.receiptCount)", symbol: "shippingbox.and.arrow.backward.fill")
        WishlistMatrixMetric(title: "Storage", value: "\(entry.storageCount)", symbol: "archivebox.fill")
        WishlistMatrixMetric(title: "Custody", value: "\(entry.custodyCount)", symbol: "person.2.badge.gearshape.fill")
        WishlistMatrixMetric(title: "Label", value: "\(entry.labelCount)", symbol: "tag.square.fill")
        WishlistMatrixMetric(title: "Manual check", value: "\(entry.scanCount)", symbol: "checklist.checked")
        WishlistMatrixMetric(title: "Dispatch", value: "\(entry.manifestCount)/\(entry.dispatchCount)", symbol: "paperplane.fill")
      }

      Text(gapSummary)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(entry.gaps.isEmpty ? Color.green : entry.tone)
        .fixedSize(horizontal: false, vertical: true)

      Text("Local downstream planning only. Use this to stage records, not to receive stock, scan labels, book carriers, or change mailbox/order systems.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        if let linkedOrder = entry.linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
        }
        Button(entry.actionTitle, systemImage: entry.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistLinkedOrderFollowUpDashboardRow: View {
  var entry: WishlistLinkedOrderFollowUpDashboardEntry
  var store: ParcelOpsStore
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var trackingSummary: String {
    entry.linkedOrder.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : entry.linkedOrder.trackingNumber
  }

  private var phaseSummary: String {
    entry.missingPhases.isEmpty ? "All core phases staged" : "Missing \(entry.missingPhases.prefix(4).joined(separator: ", "))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.nextSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.checklist.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.linkedOrder.orderNumber) • \(entry.linkedOrder.latestStatus)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 128) {
        WishlistMatrixMetric(title: "Tracking", value: trackingSummary, symbol: "number.circle.fill")
        WishlistMatrixMetric(title: "Carrier", value: entry.linkedOrder.carrier, symbol: "truck.box.fill")
        WishlistMatrixMetric(title: "ETA", value: entry.linkedOrder.eta, symbol: "calendar")
        WishlistMatrixMetric(title: "Destination", value: entry.linkedOrder.destination, symbol: "mappin.and.ellipse")
        WishlistMatrixMetric(title: "Ops phases", value: phaseSummary, symbol: "checklist.checked")
        WishlistMatrixMetric(title: "Open tasks", value: "\(entry.openTaskCount)", symbol: "checklist")
      }

      if !entry.missingPhases.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
          ForEach(entry.missingPhases.prefix(8), id: \.self) { phase in
            Badge(phase, color: .orange)
          }
        }
      }

      Text("Local follow-up only. This row does not poll carriers, update orders externally, receive stock, book dispatch, send notifications, or contact retailers.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: entry.linkedOrder, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.up.right.square.fill")
        }
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistOperationsClosureReadinessRow: View {
  var entry: WishlistOperationsClosureReadinessEntry
  var store: ParcelOpsStore
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var completedCount: Int {
    entry.phaseChecks.filter(\.1).count
  }

  private var orderSummary: String {
    entry.linkedOrder.map { "\($0.orderNumber) • \($0.latestStatus)" } ?? "Order link pending"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.stage == "Ready to close" ? "checkmark.seal.text.page.fill" : "checklist.unchecked")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(orderSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge("\(completedCount)/\(entry.phaseChecks.count)", color: completedCount == entry.phaseChecks.count ? .green : entry.tone)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(entry.phaseChecks, id: \.0) { check in
          Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(check.1 ? Color.green : Color.secondary)
            .lineLimit(1)
        }
      }

      if !entry.gaps.isEmpty {
        Text("Closure gaps: \(entry.gaps.prefix(6).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      if entry.openTaskCount > 0 {
        Label("\(entry.openTaskCount) local follow-up task\(entry.openTaskCount == 1 ? "" : "s") still open", systemImage: "checklist")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.purple)
      }

      Text("Closure readiness is a local handoff summary. It does not close external orders, receive goods, update stock, book dispatch, or contact retailers.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        if let linkedOrder = entry.linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
        }
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistLinkedOrderOperationsChecklistRow: View {
  var entry: WishlistLinkedOrderOperationsChecklistEntry
  var store: ParcelOpsStore
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var orderSummary: String {
    entry.linkedOrder.map { "\($0.orderNumber) • \($0.latestStatus)" } ?? "Order link pending"
  }

  private var completedCount: Int {
    entry.phaseChecks.filter(\.1).count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(orderSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge("\(completedCount)/\(entry.phaseChecks.count)", color: completedCount == entry.phaseChecks.count ? .green : entry.tone)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(entry.phaseChecks, id: \.0) { check in
          Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(check.1 ? Color.green : Color.secondary)
            .lineLimit(1)
        }
      }

      Text("Local setup checklist only. These records help operators track downstream work after the order exists; they do not interact with stock systems, scanners, carriers, sellers, or mailboxes.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        if let linkedOrder = entry.linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
        }
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPipelineItem: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var nextAction: String
  var symbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPipelineRow: View {
  var pipelineItem: WishlistPipelineItem
  var onAction: () -> Void
  var onFocus: () -> Void

  private var blockerSummary: String {
    let blockers = pipelineItem.item.operatorPurchaseBlockers
    guard !blockers.isEmpty else { return "No local blocker promoted." }
    return blockers.prefix(3).joined(separator: " • ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: pipelineItem.symbol)
          .foregroundStyle(pipelineItem.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(pipelineItem.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(pipelineItem.item.storefront) • \(pipelineItem.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(pipelineItem.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(pipelineItem.stage, color: pipelineItem.tone)
      }

      Text(blockerSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      CompactActionRow {
        Button(pipelineItem.nextAction, systemImage: "arrow.forward.circle", action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .background(pipelineItem.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseReleaseChecklistRow: View {
  var gate: WishlistPurchaseReleaseGate
  var onAction: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.seal.text.page.fill")
          .foregroundStyle(gate.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(gate.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(gate.item.storefront) • \(gate.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(gate.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(gate.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(gate.stage, color: gate.tone)
      }

      CompactMetadataGrid(minimumWidth: 92) {
        ForEach(gate.checks, id: \.0) { check in
          Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(check.1 ? Color.green : Color.secondary)
            .lineLimit(1)
        }
      }

      CompactActionRow {
        Button(gate.actionTitle, systemImage: gate.actionSymbol, action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .background(gate.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistManualPurchaseDayPlanRow: View {
  var entry: WishlistManualPurchaseDayPlanEntry
  var onPrimary: () -> Void
  var onPurchased: () -> Void
  var onConfirmation: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var orderSummary: String {
    if let linkedOrder = entry.linkedOrder {
      return "\(linkedOrder.orderNumber) • \(linkedOrder.latestStatus)"
    }
    if entry.confirmationCandidates > 0 {
      return "\(entry.confirmationCandidates) Inbox candidate\(entry.confirmationCandidates == 1 ? "" : "s")"
    }
    return "No linked order yet"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "calendar.badge.clock")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.seller) • \(entry.account)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Seller", value: entry.seller, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Account", value: entry.account, symbol: "person.crop.circle")
        WishlistMatrixMetric(title: "Order trail", value: orderSummary, symbol: "envelope.badge.fill")
        WishlistMatrixMetric(title: "Purchase state", value: entry.item.purchaseHandoff?.purchaseStatus ?? "Not purchased", symbol: "bag.fill")
      }

      VStack(alignment: .leading, spacing: 5) {
        Label("Manual sequence", systemImage: "list.number")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(Array(entry.steps.prefix(5).enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 6) {
            Text("\(index + 1).")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(entry.tone)
              .frame(width: 18, alignment: .trailing)
            Text(step)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onPrimary)
        Button("Purchased", systemImage: "bag.fill", action: onPurchased)
        Button("Confirmation", systemImage: "envelope.badge.fill", action: onConfirmation)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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

private struct WishlistPurchaseBlockerQueueRow: View {
  var item: WishlistItem
  var actionTitle: String
  var actionSymbol: String
  var onFocus: () -> Void
  var onAction: () -> Void

  private var blockerSummary: String {
    item.operatorPurchaseBlockers.prefix(3).joined(separator: ", ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "star.square.fill")
        .foregroundStyle(.orange)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(item.storefront) • \(item.owner)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text("Blockers: \(blockerSummary)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(item.operatorPurchaseBlockers.count)", color: .orange)
        Button("Focus", systemImage: "scope", action: onFocus)
          .buttonStyle(.bordered)
          .labelStyle(.iconOnly)
          .help("Filter Wishlist to this item")
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
          .buttonStyle(.borderedProminent)
          .labelStyle(.iconOnly)
          .help(actionTitle)
      }
    }
    .padding(8)
    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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

private struct WishlistSellerOptionIssue: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-\(kind)"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var kind: String
  var title: String
  var detail: String
  var symbol: String
  var color: Color
}

private struct WishlistCapturedOptionCleanupEntry: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-captured-cleanup"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var gaps: [String]
  var priorityLabel: String
  var priorityColor: Color

  var sortPriority: Int {
    if priorityColor == .red { return 0 }
    if priorityColor == .orange { return 1 }
    if priorityColor == .purple { return 2 }
    return 3
  }
}

private struct WishlistSellerSafetyRubricEntry: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-safety"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var isPreferred: Bool
  var decision: String
  var detail: String
  var gaps: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistSellerSafetyRubricRow: View {
  var entry: WishlistSellerSafetyRubricEntry
  var onAction: () -> Void
  var onFocus: () -> Void

  private var actionTitle: String {
    if entry.decision == "Acceptable local candidate" { return "Readiness" }
    if entry.decision == "Reject or manual review" { return "Evidence task" }
    return "Re-score"
  }

  private var actionSymbol: String {
    if entry.decision == "Acceptable local candidate" { return "checklist.checked" }
    if entry.decision == "Reject or manual review" { return "checklist" }
    return "chart.bar.doc.horizontal"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.decision == "Acceptable local candidate" ? "shield.checkered" : "exclamationmark.shield.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(entry.decision, color: entry.tone)
          if entry.isPreferred {
            Badge("Preferred", color: .purple)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 120) {
        Label(entry.option.estimatedAUDTotal, systemImage: "dollarsign.circle.fill")
        Label("\(entry.option.postageCost), \(entry.option.postageTime)", systemImage: "shippingbox.fill")
        Label(entry.option.trustRating, systemImage: "shield.lefthalf.filled")
        Label("Score \(entry.option.operatorSellerMatrixScore)", systemImage: "gauge.with.dots.needle.50percent")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if !entry.gaps.isEmpty {
        Text("Missing: \(entry.gaps.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerTrustDiligenceCheck: Identifiable {
  var id: String { label }
  var label: String
  var status: String
  var tone: Color
}

private struct WishlistSellerTrustDiligenceEntry: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-trust-diligence"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var isPreferred: Bool
  var isOverseas: Bool
  var verdict: String
  var rationale: String
  var checks: [WishlistSellerTrustDiligenceCheck]
  var gaps: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistSellerTrustDiligenceRow: View {
  var entry: WishlistSellerTrustDiligenceEntry
  var onPrimary: () -> Void
  var onPrefer: () -> Void
  var onScore: () -> Void
  var onFocus: () -> Void

  private var primaryTitle: String {
    if entry.verdict == "Do not buy yet" { return "Evidence task" }
    if entry.verdict == "Needs evidence" { return "Re-score" }
    return "Readiness"
  }

  private var primarySymbol: String {
    if entry.verdict == "Do not buy yet" { return "checklist" }
    if entry.verdict == "Needs evidence" { return "chart.bar.doc.horizontal" }
    return "checklist.checked"
  }

  private var sellerSummary: String {
    [
      entry.option.estimatedAUDTotal,
      "\(entry.option.postageCost), \(entry.option.postageTime)",
      entry.option.sellerRegion
    ]
    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    .joined(separator: " • ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.verdict == "Ready for live check" ? "person.badge.shield.checkmark.fill" : "exclamationmark.shield.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.rationale)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.verdict, color: entry.tone)
          Badge("\(entry.option.operatorSellerMatrixScore)/100", color: entry.tone)
          if entry.isPreferred {
            Badge("Preferred", color: .purple)
          }
        }
      }

      if !sellerSummary.isEmpty {
        Text(sellerSummary)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(entry.checks) { check in
          HStack(spacing: 5) {
            Circle()
              .fill(check.tone)
              .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
              Text(check.label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
              Text(check.status)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .padding(7)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(check.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if !entry.gaps.isEmpty {
        Text("Evidence gaps: \(entry.gaps.prefix(5).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !entry.option.productURL.isPlaceholderValidationValue {
        Text(entry.option.productURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(entry.option.trustNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      CompactActionRow {
        Button(primaryTitle, systemImage: primarySymbol, action: onPrimary)
        Button(entry.isPreferred ? "Preferred" : "Prefer", systemImage: "checkmark.seal", action: onPrefer)
          .disabled(entry.isPreferred || entry.verdict == "Do not buy yet")
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerOptionIssueRow: View {
  var issue: WishlistSellerOptionIssue

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: issue.symbol)
        .foregroundStyle(issue.color)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(issue.title)
            .font(.caption.weight(.semibold))
          Badge(issue.kind, color: issue.color)
        }
        Text("\(issue.item.itemName) • \(issue.option.sellerName)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(issue.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("AUD \(issue.option.estimatedAUDTotal) • postage \(issue.option.postageCost), \(issue.option.postageTime) • trust \(issue.option.trustRating)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(issue.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCapturedOptionCleanupRow: View {
  var entry: WishlistCapturedOptionCleanupEntry
  var onFocus: () -> Void
  var onTask: () -> Void
  var onScore: () -> Void

  private var gapSummary: String {
    entry.gaps.isEmpty ? "No obvious evidence gaps. Re-score and confirm manually before preferring." : "Needs \(entry.gaps.prefix(4).joined(separator: ", "))"
  }

  private var linkSummary: String {
    entry.option.productURL.isPlaceholderValidationValue ? "Product link needs confirmation" : entry.option.productURL
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "puzzlepiece.extension.fill")
          .foregroundStyle(entry.priorityColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(gapSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge("Captured", color: .purple)
          Badge(entry.priorityLabel, color: entry.priorityColor)
        }
      }

      CompactMetadataGrid(minimumWidth: 125) {
        WishlistMatrixMetric(title: "AUD", value: entry.option.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(entry.option.postageCost), \(entry.option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.option.trustRating, symbol: "shield.lefthalf.filled")
        WishlistMatrixMetric(title: "Score", value: "\(entry.option.operatorSellerMatrixScore)/100", symbol: "chart.bar.fill")
      }

      Text(linkSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)

      Text("Captured from staged metadata. Confirm seller evidence before selecting as preferred.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.purple)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Focus item", systemImage: "scope", action: onFocus)
        Button("Evidence task", systemImage: "checklist", action: onTask)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.priorityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCaptureCandidateRow: View {
  var capture: WishlistCaptureCandidate
  var onEdit: () -> Void
  var onPromote: () -> Void
  var onDismiss: () -> Void
  var onTask: () -> Void

  private var gaps: [String] {
    capture.operatorCaptureGaps
  }

  private var readyForPromotion: Bool {
    gaps.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: capture.source.symbol)
          .foregroundStyle(readyForPromotion ? .green : .orange)
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
        VStack(alignment: .trailing, spacing: 5) {
          Badge(readyForPromotion ? "Ready to promote" : "\(gaps.count) capture gap\(gaps.count == 1 ? "" : "s")", color: readyForPromotion ? .green : .orange)
          Badge(capture.reviewState.rawValue, color: capture.reviewState == .needsReview ? .orange : .blue)
        }
      }

      CompactMetadataGrid(minimumWidth: 120) {
        Label(capture.source.rawValue, systemImage: capture.source.symbol)
        Label(capture.detectedStorefront, systemImage: "storefront.fill")
        Label(capture.detectedPrice, systemImage: "dollarsign.circle.fill")
        Label(capture.capturedDate, systemImage: "clock.fill")
        Label(capture.captureStatus, systemImage: "tray.full.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if !gaps.isEmpty {
        Text("Review before promotion: \(gaps.prefix(4).joined(separator: ", ")).")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

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
        Button("Edit", systemImage: "pencil", action: onEdit)
          .buttonStyle(.bordered)
        Button(readyForPromotion ? "Promote to Wishlist" : "Promote anyway", systemImage: "star.square.fill", action: onPromote)
          .buttonStyle(.borderedProminent)
        Button("Task", systemImage: "checklist", action: onTask)
          .buttonStyle(.bordered)
        Button("Dismiss", systemImage: "xmark.circle", action: onDismiss)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPastedLinkCaptureDraft {
  var pastedText = ""
  var itemName = ""
  var sellerHint = ""
  var priceHint = ""
  var notes = ""

  var canSave: Bool {
    !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private struct WishlistPastedLinkCaptureEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft = WishlistPastedLinkCaptureDraft()
  var onSave: (WishlistPastedLinkCaptureDraft) -> Void

  var body: some View {
    Form {
      Section("Paste product link") {
        TextField("Product URL or copied page text", text: $draft.pastedText, axis: .vertical)
          .lineLimit(3...8)
        Text("Paste the direct product link where possible. ParcelOps only stores local hints; it does not open the link or read the website.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Optional hints") {
        TextField("Item name", text: $draft.itemName)
        TextField("Seller or retailer", text: $draft.sellerHint)
        TextField("Visible price or budget", text: $draft.priceHint)
        TextField("Notes, model, size, shipping clue, or why it is wanted", text: $draft.notes, axis: .vertical)
          .lineLimit(3...6)
      }

      Section("What happens next") {
        Text("This creates a staged capture candidate. Review and promote it before it becomes a Wishlist item. No browser extension, scraping, live price check, currency conversion, seller trust lookup, account login, checkout, purchase, payment, or background monitoring runs from this form.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .navigationTitle("Stage Product Link")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Stage") {
          onSave(draft)
        }
        .disabled(!draft.canSave)
      }
    }
  }
}

private struct WishlistPastedComparisonResultDraft {
  var itemID: UUID?
  var pastedText = ""
  var sellerHint = ""
  var productURLHint = ""
  var listedPriceHint = ""
  var currencyHint = ""
  var audTotalHint = ""
  var postageCostHint = ""
  var postageTimeHint = ""
  var trustHint = ""
  var notes = ""
  var splitIntoSellerOptions = true

  var canSave: Bool {
    itemID != nil && !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private struct WishlistPastedComparisonResultEditor: View {
  @Environment(\.dismiss) private var dismiss
  var items: [WishlistItem]
  @State private var draft = WishlistPastedComparisonResultDraft()
  var onSave: (WishlistItem, WishlistPastedComparisonResultDraft) -> Void

  private var selectedItem: WishlistItem? {
    guard let itemID = draft.itemID else { return nil }
    return items.first { $0.id == itemID }
  }

  var body: some View {
    Form {
      Section("Wishlist item") {
        if items.isEmpty {
          Text("No active Wishlist items are available. Add or promote a Wishlist item before pasting comparison research.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Picker("Item", selection: $draft.itemID) {
            Text("Choose item").tag(Optional<UUID>.none)
            ForEach(items) { item in
              Text(item.itemName).tag(Optional(item.id))
            }
          }
        }
      }

      Section("Paste comparison result") {
        TextField("Paste seller comparison notes, quote summary, or future-agent output", text: $draft.pastedText, axis: .vertical)
          .lineLimit(5...12)
        Toggle("Split blank-line or --- separated seller blocks into multiple options", isOn: $draft.splitIntoSellerOptions)
        Text("ParcelOps reads this text locally and creates reviewable seller options. Use blank lines or --- between sellers in a future-agent or manual comparison result. It does not open retailer links, compare live websites, convert currency, quote postage, check trust services, log into accounts, buy, or pay.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Section("Optional overrides") {
        Text("Overrides are used as fallbacks. If splitting is enabled, leave seller and URL blank when each pasted block already contains its own Seller, Retailer, Store, Merchant, URL, Price, AUD total, Postage, Delivery, or Trust line.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        TextField("Seller or retailer", text: $draft.sellerHint)
        TextField("Product URL", text: $draft.productURLHint)
        TextField("Listed price", text: $draft.listedPriceHint)
        TextField("Currency", text: $draft.currencyHint)
        TextField("Estimated AUD total", text: $draft.audTotalHint)
        TextField("Postage cost", text: $draft.postageCostHint)
        TextField("Postage time", text: $draft.postageTimeHint)
        TextField("Trust rating or trust note", text: $draft.trustHint)
        TextField("Operator notes", text: $draft.notes, axis: .vertical)
          .lineLimit(2...5)
      }

      Section("Review boundary") {
        Text("The created seller option stays in manual review until price, AUD landed cost, postage, delivery time, seller trust, returns/warranty, account fit, and payment readiness are checked outside ParcelOps.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear {
      if draft.itemID == nil {
        draft.itemID = items.first?.id
      }
    }
    .navigationTitle("Paste Comparison Result")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Add option") {
          guard let selectedItem else { return }
          onSave(selectedItem, draft)
        }
        .disabled(!draft.canSave)
      }
    }
  }
}

private struct WishlistManualItemDraft {
  var itemName = ""
  var storefront = ""
  var storefrontURL = ""
  var estimatedCost = ""
  var owner = "Current user"
  var pool = "Personal wishlist"
  var notes = ""

  var canSave: Bool {
    !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private struct WishlistManualItemEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft = WishlistManualItemDraft()
  var onSave: (WishlistManualItemDraft) -> Void

  var body: some View {
    Form {
      Section("Item") {
        TextField("Item name", text: $draft.itemName)
        TextField("Product or retailer URL", text: $draft.storefrontURL)
        TextField("Seller or retailer", text: $draft.storefront)
        TextField("Listed price or rough budget", text: $draft.estimatedCost)
      }

      Section("Local owner") {
        TextField("Owner/team", text: $draft.owner)
        TextField("Wishlist pool", text: $draft.pool)
      }

      Section("Notes") {
        TextField("Why it is wanted, size/model clues, seller notes, shipping clues, or comparison requirements", text: $draft.notes, axis: .vertical)
          .lineLimit(4...8)
      }

      Section("What happens next") {
        Text("ParcelOps will create a local Wishlist item and, when seller/link/price clues are present, stage an initial seller option for later comparison. It will not open the website, compare prices, convert currency, check stock, rate the seller, log into accounts, buy, pay, or monitor anything in the background.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .navigationTitle("Add Wishlist Item")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Add") {
          onSave(draft)
        }
        .disabled(!draft.canSave)
      }
    }
  }
}

private struct WishlistCaptureCandidateEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: WishlistCaptureCandidate
  var onSave: (WishlistCaptureCandidate) -> Void

  private let sources: [WishlistSource] = [.manual, .browserExtension, .shareSheet, .screenshot, .pdf]
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  init(capture: WishlistCaptureCandidate, onSave: @escaping (WishlistCaptureCandidate) -> Void) {
    _draft = State(initialValue: capture)
    self.onSave = onSave
  }

  var body: some View {
    Form {
      Section("Capture source") {
        Picker("Source", selection: $draft.source) {
          ForEach(sources, id: \.self) { source in
            Label(source.rawValue, systemImage: source.symbol)
              .tag(source)
          }
        }
        TextField("Page title or item name", text: $draft.pageTitle)
        TextField("Product URL", text: $draft.pageURL)
      }

      Section("Detected product details") {
        TextField("Seller or storefront", text: $draft.detectedStorefront)
        TextField("Visible price and currency", text: $draft.detectedPrice)
        TextField("Product summary", text: $draft.productSummary, axis: .vertical)
          .lineLimit(3...6)
      }

      Section("Local review") {
        TextField("Capture status", text: $draft.captureStatus)
        Picker("Review state", selection: $draft.reviewState) {
          ForEach(reviewStates, id: \.self) { state in
            Text(state.rawValue).tag(state)
          }
        }
        TextField("Notes", text: $draft.notes, axis: .vertical)
          .lineLimit(3...6)
      }

      Section("Boundary") {
        Text("This edits the local staged capture only. It does not install a browser extension, read browser tabs, scrape pages, check live prices, log into accounts, purchase, pay, or contact external services.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .navigationTitle("Edit Capture")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          onSave(draft)
        }
      }
    }
  }
}

private extension WishlistCaptureCandidate {
  var operatorCaptureGaps: [String] {
    var gaps: [String] = []
    let title = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let url = pageURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let storefront = detectedStorefront.trimmingCharacters(in: .whitespacesAndNewlines)
    let price = detectedPrice.trimmingCharacters(in: .whitespacesAndNewlines)
    let summary = productSummary.trimmingCharacters(in: .whitespacesAndNewlines)

    if title.isPlaceholderValidationValue || title.localizedCaseInsensitiveContains("captured product page") {
      gaps.append("item title")
    }
    if url.isPlaceholderValidationValue || !url.localizedCaseInsensitiveContains("http") || url.localizedCaseInsensitiveContains("example.com") {
      gaps.append("product URL")
    }
    if storefront.isPlaceholderValidationValue
      || storefront.localizedCaseInsensitiveContains("needs review")
      || storefront.localizedCaseInsensitiveContains("pending") {
      gaps.append("seller")
    }
    if price.isPlaceholderValidationValue
      || price.localizedCaseInsensitiveContains("needs review")
      || price.localizedCaseInsensitiveContains("pending") {
      gaps.append("price")
    }
    if summary.isPlaceholderValidationValue || summary.count < 24 {
      gaps.append("summary")
    }
    if reviewState == .needsReview {
      gaps.append("review state")
    }

    return gaps
  }
}

private struct WishlistResearchRunwayStep: View {
  var number: String
  var title: String
  var detail: String
  var status: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Text(number)
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(color, in: Circle())
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.subheadline.weight(.semibold))
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
      }

      Badge(status, color: color)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonDecisionRunwayEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var bestOption: WishlistComparisonOption?
  var preferredOption: WishlistComparisonOption?
  var stage: String
  var detail: String
  var nextAction: String
  var primaryAction: String
  var primarySymbol: String
  var blockers: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistComparisonDecisionRunwayRow: View {
  var entry: WishlistComparisonDecisionRunwayEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var optionSummary: String {
    if let preferred = entry.preferredOption {
      return "Preferred: \(preferred.sellerName), \(preferred.estimatedAUDTotal), score \(preferred.operatorSellerMatrixScore)/100."
    }
    if let best = entry.bestOption {
      return "Best local candidate: \(best.sellerName), \(best.estimatedAUDTotal), score \(best.operatorSellerMatrixScore)/100."
    }
    return "No seller option captured yet."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.primarySymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 130) {
        Label(optionSummary, systemImage: "storefront.fill")
        Label(entry.item.owner, systemImage: "person.crop.circle")
        Label(entry.item.source.rawValue, systemImage: "square.and.arrow.down.fill")
        if let preferred = entry.preferredOption {
          Label(preferred.postageTime, systemImage: "shippingbox.fill")
          Label(preferred.trustRating, systemImage: "shield.checkered")
        } else if let best = entry.bestOption {
          Label(best.postageTime, systemImage: "shippingbox.fill")
          Label(best.trustRating, systemImage: "shield.checkered")
        }
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if !entry.blockers.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
          ForEach(entry.blockers.prefix(5), id: \.self) { blocker in
            Badge(blocker, color: .orange)
          }
        }
      }

      Text(entry.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(entry.tone)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.primaryAction, systemImage: entry.primarySymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistResearchRequestRow: View {
  var request: WishlistResearchRequest
  var onReviewed: () -> Void
  var onBlock: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onRemove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "list.bullet.clipboard.fill")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(request.itemName)
            .font(.headline)
            .lineLimit(2)
          Text(request.requestStatus)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : (request.requestStatus.localizedCaseInsensitiveContains("blocked") ? .red : .orange))
          Badge(request.reviewState.rawValue, color: request.reviewState == .needsReview ? .orange : .green)
        }
      }

      CompactMetadataGrid(minimumWidth: 145) {
        Label(request.maxBudgetAUD, systemImage: "dollarsign.circle.fill")
        Label(request.createdDate, systemImage: "clock.fill")
        Label(request.lastReviewedDate, systemImage: "checkmark.seal.fill")
        Label(request.agentBriefGaps.isEmpty ? "No scope gaps" : "\(request.agentBriefGaps.count) scope gaps", systemImage: request.agentBriefGaps.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        WishlistResearchLine(title: "Scope", detail: request.regionScope)
        WishlistResearchLine(title: "Seller criteria", detail: request.sellerCriteria)
        WishlistResearchLine(title: "Postage", detail: request.postageRequirements)
        WishlistResearchLine(title: "Trust", detail: request.trustRequirements)
      }

      if !request.sourceURL.isPlaceholderValidationValue {
        Text(request.sourceURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      VStack(alignment: .leading, spacing: 6) {
        Label("Agent packet preview", systemImage: "doc.text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
        Text(request.agentBriefNextAction)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)
        if !request.agentBriefGaps.isEmpty {
          Text("Missing: \(request.agentBriefGaps.joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Output expected: seller/product link, listed currency, AUD landed total, postage cost/time, seller region, returns/warranty, trust evidence, safest recommendation.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(8)
      .background((request.isAgentBriefReady ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      CompactActionRow {
        Button("Reviewed", systemImage: "checkmark.seal", action: onReviewed)
          .buttonStyle(.borderedProminent)
        Button("Block", systemImage: "exclamationmark.triangle", action: onBlock)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onTask)
          .buttonStyle(.bordered)
        Button("Brief", systemImage: "doc.text", action: onDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAgentOutputContractEntry: Identifiable {
  var id: UUID { request.id }
  var request: WishlistResearchRequest
  var stage: String
  var detail: String
  var requiredOutputs: [String]
  var gaps: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistAgentOutputContractRow: View {
  var entry: WishlistAgentOutputContractEntry
  var onPrimary: () -> Void
  var onDraft: () -> Void
  var onTask: () -> Void

  private var primaryTitle: String {
    if entry.gaps == ["operator review"] || entry.gaps.isEmpty {
      return "Review"
    }
    return "Resolve"
  }

  private var primarySymbol: String {
    if entry.gaps == ["operator review"] || entry.gaps.isEmpty {
      return "checkmark.seal.fill"
    }
    return "exclamationmark.triangle.fill"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "doc.text.magnifyingglass")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.request.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(entry.stage, color: entry.tone)
          Badge(entry.request.reviewState.rawValue, color: entry.request.reviewState.color)
        }
      }

      CompactMetadataGrid(minimumWidth: 135) {
        Label(entry.request.maxBudgetAUD, systemImage: "dollarsign.circle.fill")
        Label(entry.request.regionScope, systemImage: "globe.asia.australia.fill")
        Label(entry.request.createdDate, systemImage: "calendar")
        Label(entry.gaps.isEmpty ? "No gaps" : "\(entry.gaps.count) gap\(entry.gaps.count == 1 ? "" : "s")", systemImage: entry.gaps.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        Label("Return contract", systemImage: "checklist")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(entry.requiredOutputs.joined(separator: " • "))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(8)
      .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      if !entry.gaps.isEmpty {
        Text("Missing before handoff: \(entry.gaps.joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Boundary: returned research may inform a local purchase decision, but ParcelOps still must not check out, pay, log into retailer accounts, capture credentials, or mutate mailboxes.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(primaryTitle, systemImage: primarySymbol, action: onPrimary)
          .buttonStyle(.borderedProminent)
        Button("Draft brief", systemImage: "doc.badge.plus", action: onDraft)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onTask)
          .buttonStyle(.bordered)
      }
      .controlSize(.small)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAgentHandoffPacketRow: View {
  var request: WishlistResearchRequest
  var onReviewed: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void

  private var tone: Color {
    if request.requestStatus.localizedCaseInsensitiveContains("blocked") { return .red }
    return request.isAgentBriefReady ? .green : .orange
  }

  private var packetSummary: String {
    if request.isAgentBriefReady {
      return "Ready later for a live comparison agent once integration exists."
    }
    return request.agentBriefNextAction
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: request.isAgentBriefReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(request.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(packetSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(request.agentBriefStatus, color: tone)
      }

      CompactMetadataGrid(minimumWidth: 118) {
        Label(request.maxBudgetAUD, systemImage: "dollarsign.circle.fill")
        Label(request.reviewState.rawValue, systemImage: "checkmark.seal.fill")
        Label(request.agentBriefGaps.isEmpty ? "No gaps" : "\(request.agentBriefGaps.count) gaps", systemImage: request.agentBriefGaps.isEmpty ? "checkmark.circle.fill" : "circle")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      Text("Scope: \(request.regionScope)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      CompactActionRow {
        Button("Reviewed", systemImage: "checkmark.seal", action: onReviewed)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Brief draft", systemImage: "doc.text", action: onDraft)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAgentBriefQualityCheck: Identifiable {
  var id: String { label }
  var label: String
  var detail: String
  var isReady: Bool
}

private struct WishlistAgentBriefQualityEntry: Identifiable {
  var id: UUID { request.id }
  var request: WishlistResearchRequest
  var checks: [WishlistAgentBriefQualityCheck]
  var gaps: [String]
  var stage: String
  var detail: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistResearchResultQualityEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var bestOption: WishlistComparisonOption?
  var preferredOption: WishlistComparisonOption?
  var readyOptionCount: Int
  var evidenceGaps: [String]
  var stage: String
  var detail: String
  var nextAction: String
  var primaryActionTitle: String
  var primaryActionSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistResearchResultQualityRow: View {
  var entry: WishlistResearchResultQualityEntry
  var onPrimary: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var optionCount: Int {
    entry.item.comparisonOptions?.count ?? 0
  }

  private var bestSellerSummary: String {
    guard let option = entry.bestOption else {
      return "No seller option captured yet."
    }
    return "\(option.sellerName): \(option.estimatedAUDTotal), postage \(option.postageCost) / \(option.postageTime), trust \(option.trustRating), score \(option.operatorSellerMatrixScore)."
  }

  private var preferredSummary: String {
    guard let option = entry.preferredOption else {
      return "No preferred seller selected."
    }
    return "\(option.sellerName), \(option.operatorSellerMatrixRecommendation)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.stage == "Ready for decision" ? "checkmark.seal.fill" : "checklist.checked")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge("\(entry.readyOptionCount) ready", color: entry.readyOptionCount == 0 ? .secondary : .green)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        Label("\(optionCount) seller option\(optionCount == 1 ? "" : "s")", systemImage: "storefront.fill")
        Label(entry.item.comparisonStatus ?? "Comparison needed", systemImage: "chart.bar.doc.horizontal")
        Label(entry.item.purchaseReadiness ?? "Not ready", systemImage: "cart.badge.questionmark")
        Label(entry.item.purchaseDecision == nil ? "No decision" : "Decision drafted", systemImage: "doc.text.fill")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        WishlistResearchLine(title: "Best local option", detail: bestSellerSummary)
        WishlistResearchLine(title: "Preferred seller", detail: preferredSummary)
        WishlistResearchLine(title: "Next action", detail: entry.nextAction)
      }

      if !entry.evidenceGaps.isEmpty {
        Text("Evidence gaps: \(entry.evidenceGaps.prefix(6).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Research QA only. Verify live retailer price, stock, AUD total, postage, delivery timing, trust evidence, returns, and account/payment readiness outside ParcelOps.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.primaryActionTitle, systemImage: entry.primaryActionSymbol, action: onPrimary)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPriceWatchDecisionRow: View {
  var entry: WishlistPriceWatchDecisionEntry
  var onPrimary: () -> Void
  var onSnapshot: () -> Void
  var onReview: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var snapshot: WishlistPriceSnapshot? {
    entry.bestSnapshot
  }

  private var blockerText: String {
    entry.blockers.isEmpty ? "No local blockers in the latest selected snapshot." : entry.blockers.prefix(4).joined(separator: ", ")
  }

  private var sellerSummary: String {
    guard let snapshot else { return "No recorded seller snapshot yet." }
    return "\(snapshot.sellerName) • \(snapshot.estimatedAUDTotal)"
  }

  private var postureDetail: String {
    guard let snapshot else {
      return "Create a manual snapshot from the current preferred seller option before purchase decision work continues."
    }
    if entry.stage == "Ready to verify" {
      return "Best local snapshot has no obvious field gaps. Reconfirm live price, stock, postage, returns, and trust outside ParcelOps before buying."
    }
    return "Resolve \(blockerText) before using this as a purchase candidate. Snapshot source: \(snapshot.snapshotSource)."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.stage == "Ready to verify" ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(sellerSummary)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .lineLimit(2)
          Text(postureDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge("\(entry.snapshotCount) snapshot\(entry.snapshotCount == 1 ? "" : "s")", color: .secondary)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "AUD total", value: snapshot?.estimatedAUDTotal ?? "Missing", symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: snapshot.map { "\($0.postageCost), \($0.postageTime)" } ?? "Missing", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: snapshot?.trustSignal ?? "Missing", symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Review", value: snapshot?.reviewState.rawValue ?? "No snapshot", symbol: "checkmark.seal")
      }

      if let url = snapshot?.productURL, !url.isPlaceholderValidationValue {
        Text(url)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onPrimary)
        Button("Snapshot", systemImage: "tag.badge.plus", action: onSnapshot)
        Button("Reviewed", systemImage: "checkmark.seal", action: onReview)
          .disabled(snapshot == nil || snapshot?.reviewState == .accepted)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerQuoteRow: View {
  var quote: WishlistSellerQuote
  var linkedItem: WishlistItem?
  var onPromote: () -> Void
  var onReject: () -> Void
  var onTrustChecks: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isPromoted: Bool {
    quote.quoteStatus.localizedCaseInsensitiveContains("promoted")
  }

  private var isRejected: Bool {
    quote.quoteStatus.localizedCaseInsensitiveContains("rejected")
  }

  private var tone: Color {
    if isRejected { return .red }
    if isPromoted { return .green }
    if quote.reviewState == .accepted { return .teal }
    return .orange
  }

  private var linkedDetail: String {
    if let linkedItem {
      return "Linked to \(linkedItem.itemName)"
    }
    return "No matching Wishlist item yet"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isPromoted ? "checkmark.seal.fill" : "cart.badge.plus")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(quote.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(quote.sellerName) • \(quote.estimatedAUDTotal)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(linkedDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(quote.quoteStatus, color: tone)
          Badge(quote.reviewState.rawValue, color: quote.reviewState == .accepted ? .green : .orange)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Listed", value: "\(quote.listedPrice) \(quote.currency)", symbol: "tag.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(quote.postageCost), \(quote.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Region", value: quote.sellerRegion, symbol: "globe.asia.australia.fill")
        WishlistMatrixMetric(title: "Trust", value: quote.trustSummary, symbol: "shield.checkered")
      }

      Text(quote.returnsWarrantySummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if !quote.productURL.isPlaceholderValidationValue {
        Text(quote.productURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      CompactActionRow {
        Button("Promote", systemImage: "arrow.up.doc.fill", action: onPromote)
          .disabled(isPromoted || isRejected || linkedItem == nil)
        Button("Reject", systemImage: "xmark.circle", action: onReject)
          .disabled(isRejected)
        Button("Trust checks", systemImage: "shield.lefthalf.filled.badge.checkmark", action: onTrustChecks)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerTrustRecordRow: View {
  var check: WishlistSellerTrustRecord
  var onAccept: () -> Void
  var onBlock: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isAccepted: Bool {
    check.reviewState == .accepted
  }

  private var isBlocked: Bool {
    check.resultStatus.localizedCaseInsensitiveContains("blocked")
  }

  private var tone: Color {
    if isBlocked || check.riskLevel.localizedCaseInsensitiveContains("high") { return .red }
    if isAccepted { return .green }
    return .orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isAccepted ? "shield.checkered" : "shield.lefthalf.filled.badge.checkmark")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(check.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(check.checkType) • \(check.itemName)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(check.evidenceSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(check.resultStatus, color: tone)
          Badge(check.riskLevel, color: tone)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Review", value: check.reviewState.rawValue, symbol: "checkmark.seal")
        WishlistMatrixMetric(title: "Checked", value: check.checkedDate, symbol: "calendar")
        WishlistMatrixMetric(title: "Source", value: check.sourceURL.isPlaceholderValidationValue ? "No URL" : "URL recorded", symbol: "link")
        WishlistMatrixMetric(title: "Quote", value: check.sellerQuoteID == nil ? "Unlinked" : "Linked", symbol: "cart")
      }

      Text(check.notes)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Accept", systemImage: "checkmark.seal", action: onAccept)
          .disabled(isAccepted)
        Button("Block", systemImage: "exclamationmark.octagon", action: onBlock)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPriceWatchRuleRow: View {
  var rule: WishlistPriceWatchRule
  var onEvaluate: () -> Void
  var onReview: () -> Void
  var onDisable: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var isMatched: Bool {
    rule.ruleStatus.localizedCaseInsensitiveContains("matched")
  }

  private var isDisabled: Bool {
    rule.ruleStatus.localizedCaseInsensitiveContains("disabled")
  }

  private var tone: Color {
    if isDisabled { return .red }
    if isMatched { return .green }
    if rule.reviewState == .needsReview { return .orange }
    return .teal
  }

  private var detail: String {
    if isMatched {
      return "A saved quote or snapshot appears to meet the local watch rule. Review live seller details before buying."
    }
    if isDisabled {
      return "Rule is disabled locally and will not be treated as active operator work."
    }
    if rule.lastEvaluatedDate.localizedCaseInsensitiveContains("not evaluated") {
      return "Rule has not been evaluated against saved quotes and snapshots yet."
    }
    return "No saved quote or snapshot currently satisfies the target, postage, trust, and region criteria."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isMatched ? "bell.and.waves.left.and.right.fill" : "bell.badge.fill")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(rule.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(rule.ruleStatus)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(2)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(rule.reviewState.rawValue, color: rule.reviewState == .accepted ? .green : .orange)
          Badge(rule.lastEvaluatedDate, color: .secondary)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Target", value: rule.targetAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: rule.maxPostageCost, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Delivery", value: rule.maximumDeliveryTime, symbol: "clock.fill")
        WishlistMatrixMetric(title: "Trust", value: rule.requiredTrustLevel, symbol: "shield.checkered")
      }

      Text("Regions: \(rule.allowedRegions)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Evaluate", systemImage: "checklist.checked", action: onEvaluate)
          .disabled(isDisabled)
        Button("Reviewed", systemImage: "checkmark.seal", action: onReview)
          .disabled(rule.reviewState == .accepted)
        Button("Disable", systemImage: "bell.slash", action: onDisable)
          .disabled(isDisabled)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAgentBriefQualityRow: View {
  var entry: WishlistAgentBriefQualityEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onFocus: () -> Void

  private var readyCount: Int {
    entry.checks.filter(\.isReady).count
  }

  private var actionTitle: String {
    switch entry.stage {
    case "Ready for future agent", "Needs operator review":
      return "Reviewed"
    case "Blocked":
      return "Draft"
    default:
      return "Task"
    }
  }

  private var actionSymbol: String {
    switch entry.stage {
    case "Ready for future agent", "Needs operator review":
      return "checkmark.seal"
    case "Blocked":
      return "doc.text"
    default:
      return "checklist"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.stage == "Ready for future agent" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.request.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(entry.stage, color: entry.tone)
          Badge("\(readyCount)/\(entry.checks.count)", color: readyCount == entry.checks.count ? .green : entry.tone)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(entry.checks) { check in
          VStack(alignment: .leading, spacing: 3) {
            Label(check.label, systemImage: check.isReady ? "checkmark.circle.fill" : "circle")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(check.isReady ? .green : .orange)
              .lineLimit(1)
            Text(check.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded" : check.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          .padding(7)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background((check.isReady ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if !entry.gaps.isEmpty {
        Text("Scope gaps: \(entry.gaps.prefix(6).joined(separator: ", "))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("No-purchase boundary: future research must not log in, check out, pay, store credentials, mutate mailboxes, book carriers, or run background monitoring.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Brief draft", systemImage: "doc.text", action: onDraft)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistResearchLine: View {
  var title: String
  var detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption.weight(.semibold))
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
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

private struct WishlistComparisonMatrixEntry: Identifiable {
  var item: WishlistItem
  var option: WishlistComparisonOption
  var isPreferred: Bool

  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)"
  }
}

private struct WishlistLandedCostReviewEntry: Identifiable {
  var item: WishlistItem
  var option: WishlistComparisonOption
  var badges: [String]
  var blockers: [String]
  var recommendation: String
  var tone: Color
  var sortPriority: Int

  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-landed-cost"
  }

  var isPreferred: Bool {
    badges.contains("Preferred")
  }

  var isCheapest: Bool {
    badges.contains("Cheapest")
  }

  var isSafest: Bool {
    badges.contains("Safest")
  }
}

private struct WishlistPurchaseRecommendationEntry: Identifiable {
  var item: WishlistItem
  var recommendedOption: WishlistComparisonOption
  var cheapestOption: WishlistComparisonOption?
  var safestOption: WishlistComparisonOption
  var fastestOption: WishlistComparisonOption?
  var preferredOption: WishlistComparisonOption?
  var warningLabels: [String]
  var rationale: String
  var tone: Color
  var sortPriority: Int

  var id: String {
    "\(item.id.uuidString)-purchase-recommendation"
  }
}

private struct WishlistPurchaseShortlistEntry: Identifiable {
  var entry: WishlistPurchaseRecommendationEntry
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var detail: String
  var tone: Color
  var sortPriority: Int

  var item: WishlistItem {
    entry.item
  }

  var id: String {
    "\(item.id.uuidString)-purchase-shortlist"
  }
}

private struct WishlistPurchaseRecommendationRow: View {
  var entry: WishlistPurchaseRecommendationEntry
  var onPreferRecommended: () -> Void
  var onPreferCheapest: () -> Void
  var onScore: () -> Void
  var onFocus: () -> Void

  private var cheapestSummary: String {
    guard let cheapest = entry.cheapestOption else { return "No AUD total recorded" }
    return "\(cheapest.sellerName) • \(cheapest.estimatedAUDTotal)"
  }

  private var fastestSummary: String {
    guard let fastest = entry.fastestOption else { return "No delivery time recorded" }
    return "\(fastest.sellerName) • \(fastest.postageTime)"
  }

  private var preferredSummary: String {
    guard let preferred = entry.preferredOption else { return "No preferred seller selected" }
    return "\(preferred.sellerName) • \(preferred.estimatedAUDTotal)"
  }

  private var cheapestIsRecommended: Bool {
    entry.cheapestOption?.id == entry.recommendedOption.id
  }

  private var recommendedIsPreferred: Bool {
    entry.preferredOption?.id == entry.recommendedOption.id
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "sparkle.magnifyingglass")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("Recommended: \(entry.recommendedOption.sellerName)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .lineLimit(2)
          Text(entry.rationale)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge("\(entry.recommendedOption.operatorSellerMatrixScore)/100", color: entry.tone)
          if recommendedIsPreferred {
            Badge("Preferred", color: .purple)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Recommended total", value: entry.recommendedOption.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Recommended postage", value: "\(entry.recommendedOption.postageCost), \(entry.recommendedOption.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.recommendedOption.trustRating, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Preferred now", value: preferredSummary, symbol: "checkmark.seal")
        WishlistMatrixMetric(title: "Cheapest recorded", value: cheapestSummary, symbol: "tag.fill")
        WishlistMatrixMetric(title: "Fastest recorded", value: fastestSummary, symbol: "timer")
      }

      if !entry.warningLabels.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Decision warnings", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(entry.warningLabels.prefix(8), id: \.self) { warning in
              Badge(warning, color: .orange)
            }
          }
        }
      }

      Text("Local-only summary. ParcelOps has not checked live stock, retailer pages, exchange rates, postage quotes, seller reviews, login, checkout, payment, or delivery guarantees.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(recommendedIsPreferred ? "Recommended" : "Prefer safest", systemImage: "checkmark.seal", action: onPreferRecommended)
          .disabled(recommendedIsPreferred)
        Button(cheapestIsRecommended ? "Cheapest is safest" : "Prefer cheapest", systemImage: "tag.fill", action: onPreferCheapest)
          .disabled(entry.cheapestOption == nil || cheapestIsRecommended)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseShortlistRow: View {
  var shortlist: WishlistPurchaseShortlistEntry
  var onReadiness: () -> Void
  var onDecision: () -> Void
  var onPrefer: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var option: WishlistComparisonOption {
    shortlist.entry.recommendedOption
  }

  private var preferredMatches: Bool {
    shortlist.entry.preferredOption?.id == option.id
  }

  private var warningsText: String {
    let warnings = shortlist.entry.warningLabels
    if warnings.isEmpty { return "No local recommendation warnings." }
    return warnings.prefix(4).joined(separator: ", ")
  }

  private func runPrimaryAction() {
    switch shortlist.stage {
    case "Set preferred":
      onPrefer()
    case "Needs checks":
      onReadiness()
    case "Ready for decision":
      onDecision()
    case "Blocked":
      onTask()
    default:
      onFocus()
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "list.bullet.rectangle.portrait.fill")
          .foregroundStyle(shortlist.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(shortlist.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(option.sellerName) • \(option.estimatedAUDTotal)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(shortlist.tone)
            .lineLimit(2)
          Text(shortlist.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(shortlist.stage, color: shortlist.tone)
          if preferredMatches {
            Badge("Preferred", color: .purple)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "Recommended", value: "\(option.operatorSellerMatrixScore)/100", symbol: "chart.bar.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(option.postageCost), \(option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: option.trustRating, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Warnings", value: warningsText, symbol: "exclamationmark.triangle.fill")
      }

      if !option.productURL.isPlaceholderValidationValue {
        Text(option.productURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      CompactActionRow {
        Button(shortlist.nextAction, systemImage: shortlist.nextSymbol, action: runPrimaryAction)
        Button("Readiness", systemImage: "checklist.checked", action: onReadiness)
        Button("Decision", systemImage: "doc.text.magnifyingglass", action: onDecision)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(shortlist.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistLandedCostReviewRow: View {
  var entry: WishlistLandedCostReviewEntry
  var onPrefer: () -> Void
  var onScore: () -> Void
  var onEvidenceTask: () -> Void
  var onFocus: () -> Void

  private var actionTitle: String {
    if entry.blockers.contains("seller trust") || entry.tone == .red { return "Evidence task" }
    if !entry.blockers.isEmpty { return "Re-score" }
    return entry.isPreferred ? "Preferred" : "Prefer"
  }

  private var actionSymbol: String {
    if entry.blockers.contains("seller trust") || entry.tone == .red { return "checklist" }
    if !entry.blockers.isEmpty { return "chart.bar.doc.horizontal" }
    return "checkmark.seal"
  }

  private func runPrimaryAction() {
    if entry.blockers.contains("seller trust") || entry.tone == .red {
      onEvidenceTask()
    } else if !entry.blockers.isEmpty {
      onScore()
    } else {
      onPrefer()
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.isCheapest ? "dollarsign.circle.fill" : "storefront.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.recommendation)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(entry.option.recommendation, color: entry.tone)
          ForEach(entry.badges.prefix(2), id: \.self) { badge in
            Badge(badge, color: badge == "Preferred" ? .purple : .teal)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 125) {
        WishlistMatrixMetric(title: "AUD total", value: entry.option.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(entry.option.postageCost), \(entry.option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.option.trustRating, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Score", value: "\(entry.option.operatorSellerMatrixScore)/100", symbol: "chart.bar.fill")
      }

      if !entry.blockers.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Blocks preference", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(entry.blockers.prefix(6), id: \.self) { blocker in
              Badge(blocker, color: .orange)
            }
          }
        }
      }

      if !entry.option.productURL.isPlaceholderValidationValue {
        Text(entry.option.productURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(entry.option.trustNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: runPrimaryAction)
          .disabled(entry.isPreferred && entry.blockers.isEmpty)
        Button("Prefer", systemImage: "checkmark.seal", action: onPrefer)
          .disabled(entry.isPreferred)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonMatrixRow: View {
  var entry: WishlistComparisonMatrixEntry
  var onPreferred: () -> Void
  var onScore: () -> Void
  var onFocus: () -> Void

  private var scoreColor: Color {
    let score = entry.option.operatorSellerMatrixScore
    if score >= 75 { return .green }
    if score >= 55 { return .orange }
    return .red
  }

  private var evidenceSummary: String {
    let gaps = entry.option.operatorSellerEvidenceGaps
    if gaps.isEmpty {
      return entry.option.operatorSellerMatrixRecommendation
    }
    return "Needs \(gaps.prefix(3).joined(separator: ", "))"
  }

  private var evidenceColor: Color {
    entry.option.operatorSellerEvidenceGaps.isEmpty ? .secondary : .orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.isPreferred ? "checkmark.seal.fill" : "storefront.fill")
          .foregroundStyle(entry.isPreferred ? .green : .teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(entry.option.sellerName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Text(entry.item.itemName)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 4) {
          Badge("\(entry.option.operatorSellerMatrixScore)", color: scoreColor)
          if entry.isPreferred {
            Badge("Preferred", color: .green)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 120) {
        WishlistMatrixMetric(title: "AUD total", value: entry.option.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(entry.option.postageCost), \(entry.option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.option.trustRating, symbol: "shield.lefthalf.filled")
        WishlistMatrixMetric(title: "Region", value: entry.option.sellerRegion, symbol: "globe.asia.australia.fill")
      }

      Text(evidenceSummary)
        .font(.caption)
        .foregroundStyle(evidenceColor)
        .fixedSize(horizontal: false, vertical: true)

      if let decisionReason = entry.option.decisionReason, !decisionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(decisionReason)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }

      CompactActionRow {
        Button(entry.isPreferred ? "Preferred" : "Prefer", systemImage: "checkmark.seal", action: onPreferred)
          .disabled(entry.isPreferred)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistMatrixMetric: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded" : value)
          .font(.caption2)
          .lineLimit(2)
      }
    }
  }
}

private struct WishlistPurchaseDecisionSummary: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var selectedSeller: String
  var totalAUD: String
  var postage: String
  var trust: String
  var rejectedOptions: String
  var verificationGaps: [String]
  var stage: String
  var detail: String
  var color: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistManualPurchaseHandoffReadinessEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var decision: WishlistPurchaseDecision?
  var selectedLink: WishlistPurchaseLinkRecord?
  var approval: WishlistPurchaseApprovalRecord?
  var account: WishlistPurchaseAccountRecord?
  var handoff: WishlistPurchaseHandoff?
  var stage: String
  var detail: String
  var actionTitle: String
  var actionSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistManualPurchaseHandoffReadinessRow: View {
  var entry: WishlistManualPurchaseHandoffReadinessEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var sellerSummary: String {
    entry.handoff?.sellerName
      ?? entry.decision?.selectedSellerName
      ?? entry.selectedLink?.sellerName
      ?? entry.item.storefront
  }

  private var linkStatus: (String, Color) {
    guard let link = entry.selectedLink else { return ("No link", .orange) }
    if link.readinessStatus.localizedCaseInsensitiveContains("blocked") { return ("Link blocked", .red) }
    if link.reviewState == .accepted || link.readinessStatus.localizedCaseInsensitiveContains("ready") { return ("Link ready", .green) }
    return ("Link review", .purple)
  }

  private var approvalStatus: (String, Color) {
    guard let approval = entry.approval else { return ("No approval", .orange) }
    if approval.approvalStatus.localizedCaseInsensitiveContains("blocked") { return ("Approval blocked", .red) }
    if approval.reviewState == .accepted || approval.approvalStatus.localizedCaseInsensitiveContains("approved") { return ("Approved", .green) }
    return ("Approval review", .indigo)
  }

  private var accountStatus: (String, Color) {
    guard let account = entry.account else { return ("No account", .orange) }
    if account.accountReadinessStatus.localizedCaseInsensitiveContains("blocked") { return ("Account blocked", .red) }
    if account.reviewState == .accepted { return ("Account ready", .green) }
    return ("Account review", .teal)
  }

  private var handoffStatus: (String, Color) {
    guard let handoff = entry.handoff else { return ("No handoff", .orange) }
    if handoff.linkedOrderID != nil { return ("Order linked", .green) }
    if handoff.orderWatchStatus.localizedCaseInsensitiveContains("seen") { return ("Order watch", .teal) }
    return ("Watch order", .teal)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.actionSymbol)
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(sellerSummary)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .lineLimit(1)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 118) {
        let link = linkStatus
        let approval = approvalStatus
        let account = accountStatus
        let handoff = handoffStatus
        Badge(link.0, color: link.1)
        Badge(approval.0, color: approval.1)
        Badge(account.0, color: account.1)
        Badge(handoff.0, color: handoff.1)
      }

      CompactMetadataGrid(minimumWidth: 135) {
        WishlistMatrixMetric(title: "AUD total", value: entry.decision?.totalAUDSummary ?? entry.selectedLink?.estimatedAUDTotal ?? entry.item.estimatedCost, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: entry.decision?.postageSummary ?? entry.selectedLink?.postageSummary ?? "Postage not recorded", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Expected email", value: entry.handoff?.expectedOrderSignals ?? entry.account?.expectedOrderEmailSignals ?? "Order confirmation signals not recorded", symbol: "envelope.badge.fill")
      }

      Text("Manual handoff only. Confirm live stock, seller page, account access, payment, and delivery details outside ParcelOps.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.actionTitle, systemImage: entry.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseDecisionSummaryRow: View {
  var summary: WishlistPurchaseDecisionSummary
  var onAction: () -> Void
  var onReviewTask: () -> Void
  var onNeedsReview: () -> Void
  var onFocus: () -> Void

  private var decision: WishlistPurchaseDecision? {
    summary.item.purchaseDecision
  }

  private var reviewLabel: String {
    decision?.reviewState.rawValue ?? "Not drafted"
  }

  private var notes: String {
    let raw = decision?.decisionNotes ?? summary.detail
    return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? summary.detail : raw
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(summary.color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(summary.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(summary.selectedSeller)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Badge(summary.stage, color: summary.color)
      }

      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "AUD total", value: summary.totalAUD, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: summary.postage, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: summary.trust, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Review", value: reviewLabel, symbol: "checkmark.seal")
      }

      if !summary.rejectedOptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Label("Alternates rejected or left behind", systemImage: "arrow.triangle.branch")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(summary.rejectedOptions)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }

      if !summary.verificationGaps.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Verify before buying", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(summary.verificationGaps.prefix(8), id: \.self) { gap in
              Badge(gap, color: .orange)
            }
          }
        }
      } else {
        Text("Local decision fields are complete. Still verify live price, stock, postage, account, payment, delivery address, returns, and warranty outside ParcelOps before buying.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text(notes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(summary.actionTitle, systemImage: summary.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onReviewTask)
        Button("Needs review", systemImage: "exclamationmark.triangle", action: onNeedsReview)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(summary.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseEvidenceCheck: Identifiable {
  var id: String { label }
  var label: String
  var detail: String
  var isReady: Bool
}

private struct WishlistPurchaseEvidenceDossier: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var selectedSeller: String
  var checks: [WishlistPurchaseEvidenceCheck]
  var gaps: [String]
  var stage: String
  var detail: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseDecisionEvidencePack: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var summary: WishlistPurchaseDecisionSummary
  var dossier: WishlistPurchaseEvidenceDossier
  var status: String
  var detail: String
  var unresolvedEvidence: [String]
  var readyEvidence: Int
  var totalEvidence: Int
  var isSignedOff: Bool
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseDecisionEvidencePackRow: View {
  var pack: WishlistPurchaseDecisionEvidencePack
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var decision: WishlistPurchaseDecision? {
    pack.item.purchaseDecision
  }

  private var actionTitle: String {
    switch pack.status {
    case "Decision missing": return "Draft decision"
    case "Review required": return "Accept decision"
    case "Evidence gaps": return "Run checks"
    case "Handoff missing": return "Prepare handoff"
    case "Ready for external buy": return "Order seen"
    default: return "Focus"
    }
  }

  private var actionSymbol: String {
    switch pack.status {
    case "Decision missing": return "doc.text.magnifyingglass"
    case "Review required": return "checkmark.seal"
    case "Evidence gaps": return "checklist.checked"
    case "Handoff missing": return "person.crop.circle.badge.checkmark"
    case "Ready for external buy": return "envelope.badge.fill"
    default: return "scope"
    }
  }

  private var safeNotes: String {
    let notes = decision?.decisionNotes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return notes.isEmpty ? "No decision notes recorded yet." : notes
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: pack.isSignedOff ? "doc.badge.checkmark.fill" : "doc.badge.gearshape.fill")
          .foregroundStyle(pack.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(pack.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(pack.summary.selectedSeller)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(pack.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(pack.status, color: pack.tone)
          Badge("\(pack.readyEvidence)/\(pack.totalEvidence) evidence", color: pack.readyEvidence == pack.totalEvidence ? .green : .orange)
        }
      }

      CompactMetadataGrid(minimumWidth: 130) {
        WishlistMatrixMetric(title: "AUD total", value: pack.summary.totalAUD, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: pack.summary.postage, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: pack.summary.trust, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Decision", value: decision?.reviewState.rawValue ?? "Not drafted", symbol: "checkmark.seal")
      }

      if !pack.summary.rejectedOptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Label("Rejected/alternate seller evidence", systemImage: "arrow.triangle.branch")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(pack.summary.rejectedOptions)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }

      if pack.unresolvedEvidence.isEmpty {
        Label("No unresolved local evidence gaps. Final live verification still happens outside ParcelOps.", systemImage: "checkmark.seal.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(alignment: .leading, spacing: 5) {
          Label("Unresolved evidence", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(pack.unresolvedEvidence.prefix(8), id: \.self) { gap in
              Badge(gap, color: .orange)
            }
          }
        }
      }

      Text(safeNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text("Before buying externally, manually confirm live stock, current price, landed AUD total, postage, returns, warranty, account access, payment method, and delivery address.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(pack.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseEvidenceDossierRow: View {
  var dossier: WishlistPurchaseEvidenceDossier
  var onAction: () -> Void
  var onTask: () -> Void
  var onDecision: () -> Void
  var onFocus: () -> Void

  private var actionTitle: String {
    switch dossier.stage {
    case "Decision review":
      return "Accept decision"
    case "Handoff missing":
      return "Handoff"
    case "Evidence ready":
      return "Focus"
    default:
      return dossier.item.purchaseDecision == nil ? "Draft decision" : "Run checks"
    }
  }

  private var actionSymbol: String {
    switch dossier.stage {
    case "Decision review":
      return "checkmark.seal"
    case "Handoff missing":
      return "person.crop.circle.badge.checkmark"
    case "Evidence ready":
      return "scope"
    default:
      return dossier.item.purchaseDecision == nil ? "doc.text.magnifyingglass" : "checklist.checked"
    }
  }

  private var readyCount: Int {
    dossier.checks.filter(\.isReady).count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: dossier.stage == "Evidence ready" ? "folder.badge.checkmark" : "folder.badge.gearshape.fill")
          .foregroundStyle(dossier.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(dossier.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(dossier.selectedSeller)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(dossier.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 5) {
          Badge(dossier.stage, color: dossier.tone)
          Badge("\(readyCount)/\(dossier.checks.count)", color: readyCount == dossier.checks.count ? .green : .orange)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(dossier.checks) { check in
          VStack(alignment: .leading, spacing: 3) {
            Label(check.label, systemImage: check.isReady ? "checkmark.circle.fill" : "circle")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(check.isReady ? .green : .orange)
              .lineLimit(1)
            Text(check.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          .padding(7)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background((check.isReady ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if !dossier.gaps.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Evidence still needed", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(dossier.gaps.prefix(8), id: \.self) { gap in
              Badge(gap, color: .orange)
            }
          }
        }
      }

      Text("This dossier is a local readiness summary. Re-check live seller page, checkout, payment, stock, final AUD total, postage, delivery address, returns, and warranty before buying outside ParcelOps.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Evidence task", systemImage: "checklist", action: onTask)
        Button("Decision", systemImage: "doc.text.magnifyingglass", action: onDecision)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(dossier.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseDecisionQueueRow: View {
  var item: WishlistItem
  var stageTitle: String
  var stageDetail: String
  var stageColor: Color
  var actionTitle: String
  var actionSymbol: String
  var onAction: () -> Void
  var onFocus: () -> Void

  private var preferredSeller: WishlistComparisonOption? {
    guard let preferredOptionID = item.preferredOptionID else { return nil }
    return item.comparisonOptions?.first { $0.id == preferredOptionID }
  }

  private var sellerSummary: String {
    if let preferredSeller {
      return "\(preferredSeller.sellerName) • \(preferredSeller.estimatedAUDTotal) • \(preferredSeller.postageTime)"
    }
    if let first = item.comparisonOptions?.first {
      return "\(first.sellerName) • preferred seller not selected"
    }
    return "No seller option selected"
  }

  private var reviewSummary: String {
    [
      item.purchaseReadiness,
      item.purchaseDecision?.decisionStatus,
      item.purchaseHandoff?.purchaseStatus
    ]
      .compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
      }
      .prefix(2)
      .joined(separator: " • ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "bag.badge.questionmark.fill")
          .foregroundStyle(stageColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(sellerSummary)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge(stageTitle, color: stageColor)
      }

      Text(stageDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if !reviewSummary.isEmpty {
        Text(reviewSummary)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(stageColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(stageColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseHandoffPackRow: View {
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var gaps: [String]
  var accountCount: Int
  var costCount: Int
  var procurementCount: Int
  var receivingCount: Int
  var onNext: () -> Void
  var onTask: () -> Void
  var onOrderSeen: () -> Void
  var onFocus: () -> Void

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  private var stageColor: Color {
    if gaps.isEmpty { return .green }
    if gaps.contains("order link") { return .teal }
    if gaps.contains("cost") || gaps.contains("procurement") || gaps.contains("receiving") { return .orange }
    return .purple
  }

  private var nextActionTitle: String {
    if gaps.contains("handoff") { return "Handoff" }
    if gaps.contains("cost") { return "Cost" }
    if gaps.contains("procurement") { return "Procurement" }
    if gaps.contains("receiving") { return "Receiving" }
    if gaps.contains("order link") { return "Order seen" }
    return "Task"
  }

  private var nextActionSymbol: String {
    if gaps.contains("handoff") { return "person.crop.circle.badge.checkmark" }
    if gaps.contains("cost") { return "dollarsign.circle.fill" }
    if gaps.contains("procurement") { return "cart.badge.plus" }
    if gaps.contains("receiving") { return "shippingbox.and.arrow.down.fill" }
    if gaps.contains("order link") { return "envelope.badge.fill" }
    return "checklist"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "shippingbox.and.arrow.backward.fill")
          .foregroundStyle(stageColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(handoff?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Badge(gaps.isEmpty ? "Pack ready" : "\(gaps.count) gaps", color: stageColor)
      }

      Text(handoff?.purchaseStatus ?? item.purchaseReadiness ?? "Purchase handoff not prepared")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 120) {
        WishlistMatrixMetric(title: "Account", value: accountCount == 0 ? handoff?.accountLabel ?? "To confirm" : "\(accountCount) matched", symbol: "person.crop.circle.badge.key.fill")
        WishlistMatrixMetric(title: "Cost", value: costCount == 0 ? "Missing" : "\(costCount) linked", symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Procurement", value: procurementCount == 0 ? "Missing" : "\(procurementCount) linked", symbol: "cart.badge.plus")
        WishlistMatrixMetric(title: "Receiving", value: receivingCount == 0 ? "Missing" : "\(receivingCount) linked", symbol: "shippingbox.and.arrow.down.fill")
        WishlistMatrixMetric(title: "Order", value: linkedOrder?.orderNumber ?? "Not linked", symbol: "link")
      }

      if !gaps.isEmpty {
        Text("Next setup: \(gaps.prefix(4).joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(stageColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(nextActionTitle, systemImage: nextActionSymbol, action: onNext)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Order seen", systemImage: "envelope.badge.fill", action: onOrderSeen)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(stageColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseHandoffSanityEntry: Identifiable {
  var id: String {
    "\(item.id.uuidString)-handoff-sanity"
  }

  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff?
  var linkedOrder: TrackedOrder?
  var checks: [WishlistPurchaseHandoffSanityCheck]
  var tone: Color
  var nextAction: String
  var nextSymbol: String
  var missingCount: Int
}

private struct WishlistPurchaseHandoffSanityCheck: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var ready: Bool
  var symbol: String
}

private struct WishlistPurchaseHandoffSanityRow: View {
  var entry: WishlistPurchaseHandoffSanityEntry
  var onNext: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var visibleChecks: [WishlistPurchaseHandoffSanityCheck] {
    let failed = entry.checks.filter { !$0.ready }
    return failed.isEmpty ? Array(entry.checks.prefix(4)) : Array(failed.prefix(5))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.missingCount == 0 ? "checkmark.seal.fill" : "checklist")
          .foregroundStyle(entry.tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(entry.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(entry.handoff?.sellerName ?? entry.item.purchaseDecision?.selectedSellerName ?? entry.item.storefront)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.missingCount == 0 ? "Local handoff context looks complete enough for manual verification." : "\(entry.missingCount) local handoff detail\(entry.missingCount == 1 ? "" : "s") still need attention.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.missingCount == 0 ? "Ready" : "\(entry.missingCount) gaps", color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 130) {
        ForEach(visibleChecks) { check in
          WishlistMatrixMetric(
            title: check.title,
            value: check.ready ? "Ready" : check.detail,
            symbol: check.ready ? "checkmark.circle.fill" : check.symbol
          )
        }
      }

      if let linkedOrder = entry.linkedOrder {
        Label("Linked to \(linkedOrder.orderNumber). Continue tracking in Orders and downstream operations.", systemImage: "link.circle.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      } else if entry.handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
        Label("External purchase is recorded locally, but no order confirmation is linked yet.", systemImage: "envelope.badge.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.teal)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onNext)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistItemRow: View {
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var store: ParcelOpsStore?
  var confirmationMatches: [ForwardedEmailIntake] = []
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedCosts: [CostRecord] = []
  var suggestedProcurementRequests: [ProcurementRequest] = []
  var suggestedReceivingInspections: [ReceivingInspectionRecord] = []
  var suggestedInventoryReceipts: [InventoryReceiptRecord] = []
  var suggestedStorageLocations: [StorageLocationRecord] = []
  var suggestedCustodyRecords: [CustodyRecord] = []
  var suggestedLabelReferences: [LabelReferenceRecord] = []
  var suggestedScanSessions: [ScanSessionRecord] = []
  var suggestedShipmentManifests: [ShipmentManifestRecord] = []
  var suggestedDispatchChecklists: [DispatchReadinessChecklist] = []
  var isDeleted = false
  var onConvert: () -> Void
  var onLink: () -> Void
  var onCompare: () -> Void
  var onAddOption: () -> Void
  var onScore: () -> Void
  var onEvidenceTask: () -> Void
  var onCheck: () -> Void
  var onDecision: () -> Void
  var onDecisionReviewed: () -> Void
  var onDecisionNeedsReview: () -> Void
  var onDecisionTask: () -> Void
  var onHandoff: () -> Void
  var onHandoffTask: () -> Void
  var onPurchased: () -> Void
  var onOrderSeen: () -> Void
  var onUseConfirmation: (ForwardedEmailIntake) -> Void
  var onAddAccount: () -> Void
  var onAccountTask: (AccountCredentialRecord) -> Void
  var onAccountDraft: (AccountCredentialRecord) -> Void
  var onAddCost: () -> Void
  var onCostTask: (CostRecord) -> Void
  var onCostDraft: (CostRecord) -> Void
  var onAddProcurement: () -> Void
  var onProcurementTask: (ProcurementRequest) -> Void
  var onProcurementDraft: (ProcurementRequest) -> Void
  var onAddInspection: () -> Void
  var onInspectionTask: (ReceivingInspectionRecord) -> Void
  var onInspectionDraft: (ReceivingInspectionRecord) -> Void
  var onAddInventoryReceipt: () -> Void
  var onInventoryReceiptTask: (InventoryReceiptRecord) -> Void
  var onInventoryReceiptDraft: (InventoryReceiptRecord) -> Void
  var onAddStorageLocation: () -> Void
  var onStorageLocationTask: (StorageLocationRecord) -> Void
  var onStorageLocationDraft: (StorageLocationRecord) -> Void
  var onAddCustody: () -> Void
  var onCustodyTask: (CustodyRecord) -> Void
  var onCustodyDraft: (CustodyRecord) -> Void
  var onAddLabelReference: () -> Void
  var onLabelReferenceTask: (LabelReferenceRecord) -> Void
  var onLabelReferenceDraft: (LabelReferenceRecord) -> Void
  var onAddScanSession: () -> Void
  var onScanSessionTask: (ScanSessionRecord) -> Void
  var onScanSessionDraft: (ScanSessionRecord) -> Void
  var onAddShipmentManifest: () -> Void
  var onShipmentManifestTask: (ShipmentManifestRecord) -> Void
  var onShipmentManifestDraft: (ShipmentManifestRecord) -> Void
  var onAddDispatchChecklist: () -> Void
  var onDispatchChecklistTask: (DispatchReadinessChecklist) -> Void
  var onDispatchChecklistDraft: (DispatchReadinessChecklist) -> Void
  var onReady: () -> Void
  var onPreferredOption: (WishlistComparisonOption) -> Void
  var onDuplicateOption: (WishlistComparisonOption) -> Void
  var onUpdateOption: (WishlistComparisonOption) -> Void
  var onRemoveOption: (WishlistComparisonOption) -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onDelete: () -> Void
  @State private var feedbackMessage: String?

  private var isClosedLocally: Bool {
    item.status == "Closed locally"
  }

  private var statusBadgeColor: Color {
    if isClosedLocally { return .green }
    if item.status.localizedCaseInsensitiveContains("blocked") { return .red }
    if item.status.localizedCaseInsensitiveContains("review") { return .orange }
    if item.status.localizedCaseInsensitiveContains("ready") { return .teal }
    return .blue
  }

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
        Badge(item.status, color: statusBadgeColor)
      }
      Text(item.capturedDetail)
        .font(.caption)
        .foregroundStyle(.secondary)

      if isClosedLocally {
        wishlistClosedStateSummary
      }

      wishlistPurchasePacketSummary
      wishlistComparisonSummary
      wishlistPurchaseChecksSummary
      wishlistPurchaseDecisionSummary
      wishlistPurchaseHandoffSummary
      if !isDeleted && !isClosedLocally {
        wishlistOperatorNextStep
      }

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
          Button("Add seller option", systemImage: "storefront") {
            onAddOption()
            feedbackMessage = "Manual seller option added locally. Fill in live price, AUD total, postage, trust, and product link before choosing where to buy."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Add seller option")
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
          Button("Decision", systemImage: "doc.text.magnifyingglass") {
            onDecision()
            feedbackMessage = "Purchase decision drafted locally. Review why this seller is preferred before buying externally."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Draft purchase decision")
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

  private var wishlistClosedStateSummary: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Closed locally", systemImage: "checkmark.circle.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.green)
      Text("This item is retained for local audit, linked-order history, and handoff evidence, but it is no longer active Wishlist work. Use the Closed Wishlist items ledger to reopen it if follow-up is needed.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if let handoff = item.purchaseHandoff {
        HStack(spacing: 8) {
          Badge(handoff.purchaseStatus, color: .green)
          Badge(handoff.linkedOrderID == nil ? "No linked order" : "Linked order retained", color: handoff.linkedOrderID == nil ? .orange : .teal)
        }
      }
    }
    .padding(10)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistPurchasePacketSummary: some View {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { id in options.first { $0.id == id } }
    let decision = item.purchaseDecision
    let handoff = item.purchaseHandoff
    let checks = item.purchaseChecks ?? []
    let failedChecks = checks.filter { $0.status != "Passed" }
    let blockers = wishlistPurchasePacketBlockers(
      options: options,
      preferred: preferred,
      decision: decision,
      handoff: handoff,
      failedChecks: failedChecks
    )

    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Purchase packet", systemImage: "doc.text.image.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
        Spacer(minLength: 8)
        Badge(blockers.isEmpty ? "Packet looks ready" : "\(blockers.count) blocker\(blockers.count == 1 ? "" : "s")", color: blockers.isEmpty ? .green : .orange)
      }

      CompactMetadataGrid(minimumWidth: 170) {
        PurchasePacketFact(title: "Preferred seller", value: preferred?.sellerName ?? decision?.selectedSellerName ?? "Seller not selected", symbol: "storefront.fill", color: preferred == nil ? .orange : .teal)
        PurchasePacketFact(title: "AUD total", value: decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost, symbol: "dollarsign.circle.fill", color: wishlistPacketValueNeedsReview(decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost) ? .orange : .green)
        PurchasePacketFact(title: "Postage", value: decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not reviewed", symbol: "shippingbox.fill", color: preferred == nil ? .orange : .purple)
        PurchasePacketFact(title: "Trust", value: decision?.trustSummary ?? preferred?.trustRating ?? "Trust not reviewed", symbol: "shield.checkered", color: wishlistPacketTrustColor(decision?.trustSummary ?? preferred?.trustRating ?? ""))
        PurchasePacketFact(title: "Decision", value: decision?.decisionStatus ?? "Decision not drafted", symbol: "doc.text.magnifyingglass", color: decision?.reviewState == .accepted ? .green : .orange)
        PurchasePacketFact(title: "Order link", value: linkedOrder?.orderNumber ?? (handoff?.linkedOrderID == nil ? "No linked order yet" : "Linked order missing"), symbol: "link", color: linkedOrder == nil ? .orange : .green)
      }

      if blockers.isEmpty {
        Label("Local packet is ready for manual live verification. Confirm current price, stock, postage, seller trust, account, delivery address, and payment details outside ParcelOps before buying.", systemImage: "checkmark.seal.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          Text("Before purchase")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(blockers.prefix(5), id: \.self) { blocker in
            Label(blocker, systemImage: "exclamationmark.triangle.fill")
              .font(.caption2)
              .foregroundStyle(.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
          let remaining = max(blockers.count - 5, 0)
          if remaining > 0 {
            Text("\(remaining) more blocker\(remaining == 1 ? "" : "s") shown in the detailed sections below.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Packet draft", systemImage: "envelope.open") {
          onDraft()
          feedbackMessage = "Wishlist purchase packet draft created locally. No message was sent and no seller, browser, mailbox, checkout, or payment action occurred."
        }
        .buttonStyle(.bordered)
        Button("Handoff task", systemImage: "checklist") {
          onHandoffTask()
          feedbackMessage = "Wishlist purchase handoff task created or refreshed locally. Confirm account, payment, address, seller page, and order confirmation outside ParcelOps."
        }
        .buttonStyle(.bordered)
      }

      Text("This packet is a local buying checklist only. ParcelOps does not verify live retailer pages, convert currency live, quote postage, assess seller reputation externally, buy items, or store payment details.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func wishlistPurchasePacketBlockers(
    options: [WishlistComparisonOption],
    preferred: WishlistComparisonOption?,
    decision: WishlistPurchaseDecision?,
    handoff: WishlistPurchaseHandoff?,
    failedChecks: [WishlistPurchaseCheck]
  ) -> [String] {
    var blockers: [String] = []
    if options.isEmpty {
      blockers.append("Add or draft seller comparison options.")
    }
    if preferred == nil {
      blockers.append("Select a preferred seller option.")
    }
    if let preferred {
      let gaps = preferred.operatorSellerEvidenceGaps
      if !gaps.isEmpty {
        blockers.append("Complete preferred seller evidence: \(gaps.joined(separator: ", ")).")
      }
    }
    if failedChecks.isEmpty && item.purchaseChecks?.isEmpty != false {
      blockers.append("Run the local purchase readiness check.")
    } else if !failedChecks.isEmpty {
      blockers.append("Resolve \(failedChecks.count) readiness check item\(failedChecks.count == 1 ? "" : "s").")
    }
    if decision == nil {
      blockers.append("Draft the purchase decision.")
    } else if decision?.reviewState != .accepted {
      blockers.append("Review and accept the purchase decision locally.")
    }
    if handoff == nil {
      blockers.append("Prepare the manual purchase handoff.")
    } else if linkedOrder == nil {
      blockers.append("After external purchase, link or create the local order when confirmation arrives.")
    }
    return blockers
  }

  private func wishlistPacketValueNeedsReview(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    return normalized.isEmpty
      || normalized.contains("pending")
      || normalized.contains("confirm")
      || normalized.contains("review")
      || normalized.isPlaceholderValidationValue
  }

  private func wishlistPacketTrustColor(_ value: String) -> Color {
    if value.localizedCaseInsensitiveContains("trusted") || value.localizedCaseInsensitiveContains("high") || value.localizedCaseInsensitiveContains("accepted") {
      return .green
    }
    if value.localizedCaseInsensitiveContains("unknown") || value.localizedCaseInsensitiveContains("review") || value.localizedCaseInsensitiveContains("blocked") {
      return .orange
    }
    return .secondary
  }

  @ViewBuilder
  private var wishlistComparisonSummary: some View {
    let options = item.comparisonOptions ?? []
    let missingEvidence = missingSellerEvidenceLabels
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
            } onDuplicate: {
              onDuplicateOption(option)
              feedbackMessage = "Seller option copied locally. Adjust the copy with the alternate retailer, AUD total, postage, and trust notes."
            } onUpdate: { updatedOption in
              onUpdateOption(updatedOption)
              feedbackMessage = "Seller option saved locally. Re-run local scoring after confirming price, AUD total, postage, and trust details."
            } onRemove: {
              onRemoveOption(option)
              feedbackMessage = "Seller option removed locally. No retailer, browser, payment, or order state was changed."
            }
          }
        }

        if !missingEvidence.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Seller evidence still needs review", systemImage: "checklist")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.orange)
            Text("Missing: \(missingEvidence.joined(separator: ", ")). Create one local task to confirm these before purchase.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            CompactActionRow {
              Button("Evidence task", systemImage: "checklist") {
                onEvidenceTask()
                feedbackMessage = "Wishlist seller evidence task created locally. No web search, seller lookup, browser automation, purchase, payment, or external service ran."
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(8)
          .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(10)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var missingSellerEvidenceLabels: [String] {
    let labels = (item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps)
    return Array(Set(labels)).sorted()
  }

  @ViewBuilder
  private var wishlistOperatorNextStep: some View {
    let options = item.comparisonOptions ?? []
    let checks = item.purchaseChecks ?? []
    let failedChecks = checks.filter { $0.status != "Passed" }
    let missingEvidence = missingSellerEvidenceLabels

    if options.isEmpty {
      wishlistNextStepPanel(
        title: "Next: compare seller options",
        detail: "Add or draft seller options before deciding where to buy. This stays local until you explicitly open a seller page.",
        symbol: "magnifyingglass.circle.fill",
        color: .teal
      ) {
        Button("Compare sellers", systemImage: "magnifyingglass.circle") {
          onCompare()
          feedbackMessage = "Local comparison plan created. No web search, retailer scrape, currency lookup, postage quote, or trust service was contacted."
        }
        .buttonStyle(.borderedProminent)
        Button("Add option", systemImage: "storefront") {
          onAddOption()
          feedbackMessage = "Manual seller option added locally. Fill in live price, AUD total, postage, trust, and product link before choosing where to buy."
        }
        .buttonStyle(.bordered)
      }
    } else if !missingEvidence.isEmpty {
      wishlistNextStepPanel(
        title: "Next: fill seller evidence gaps",
        detail: "Confirm \(missingEvidence.joined(separator: ", ")) before purchase review. Create one task to track the missing evidence without duplicating work.",
        symbol: "checklist",
        color: .orange
      ) {
        Button("Evidence task", systemImage: "checklist") {
          onEvidenceTask()
          feedbackMessage = "Wishlist seller evidence task created locally. No web search, seller lookup, browser automation, purchase, payment, or external service ran."
        }
        .buttonStyle(.borderedProminent)
        Button("Score options", systemImage: "chart.bar.doc.horizontal") {
          onScore()
          feedbackMessage = "Seller options scored locally from existing comparison fields. Verify live price, postage, trust, returns, and account readiness before buying."
        }
        .buttonStyle(.bordered)
      }
    } else if checks.isEmpty || !failedChecks.isEmpty {
      wishlistNextStepPanel(
        title: checks.isEmpty ? "Next: run readiness check" : "Next: clear purchase blockers",
        detail: checks.isEmpty ? "Run the local checklist before drafting a purchase decision." : "\(failedChecks.count) readiness item\(failedChecks.count == 1 ? "" : "s") still need review before handoff.",
        symbol: "checklist.checked",
        color: .indigo
      ) {
        Button("Run readiness", systemImage: "checklist.checked") {
          onCheck()
          feedbackMessage = "Purchase readiness checked locally. Fix blockers before buying externally."
        }
        .buttonStyle(.borderedProminent)
        Button("Task", systemImage: "checklist") {
          onTask()
          feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
        }
        .buttonStyle(.bordered)
      }
    } else if item.purchaseDecision == nil {
      wishlistNextStepPanel(
        title: "Next: draft purchase decision",
        detail: "Readiness checks are clear locally. Draft the seller decision so cost, trust, postage, and rejected options are recorded before purchase.",
        symbol: "doc.text.magnifyingglass",
        color: .brown
      ) {
        Button("Decision", systemImage: "doc.text.magnifyingglass") {
          onDecision()
          feedbackMessage = "Purchase decision drafted locally. Review why this seller is preferred before buying externally."
        }
        .buttonStyle(.borderedProminent)
      }
    } else if item.purchaseDecision?.reviewState != .accepted {
      wishlistNextStepPanel(
        title: "Next: review purchase decision",
        detail: "The decision exists but has not been accepted locally. Review it before preparing purchase handoff.",
        symbol: "checkmark.seal",
        color: .brown
      ) {
        Button("Reviewed", systemImage: "checkmark.seal") {
          onDecisionReviewed()
          feedbackMessage = "Purchase decision reviewed locally. Confirm live seller/account/payment details before buying externally."
        }
        .buttonStyle(.borderedProminent)
        Button("Decision task", systemImage: "checklist") {
          onDecisionTask()
          feedbackMessage = "Purchase decision review task created or refreshed locally. Check Tasks before buying externally."
        }
        .buttonStyle(.bordered)
      }
    } else if item.purchaseHandoff == nil {
      wishlistNextStepPanel(
        title: "Next: prepare manual purchase handoff",
        detail: "The decision is reviewed locally. Prepare the handoff so account, expected order signals, and order watch state are tracked.",
        symbol: "person.crop.circle.badge.checkmark",
        color: .purple
      ) {
        Button("Prepare handoff", systemImage: "person.crop.circle.badge.checkmark") {
          onHandoff()
          feedbackMessage = "Manual purchase handoff prepared locally. Confirm account and payment outside ParcelOps."
        }
        .buttonStyle(.borderedProminent)
      }
    } else if linkedOrder == nil {
      wishlistNextStepPanel(
        title: "Next: watch for order confirmation",
        detail: "Purchase handoff is staged. After buying outside ParcelOps, mark the confirmation seen or link the matching local order.",
        symbol: "envelope.badge.fill",
        color: .purple
      ) {
        Button("Order seen", systemImage: "envelope.badge.fill") {
          onOrderSeen()
          feedbackMessage = "Order confirmation marked seen locally. Link the real order if needed."
        }
        .buttonStyle(.borderedProminent)
        Button("Link order", systemImage: "link") {
          onLink()
          feedbackMessage = "Wishlist item linked locally. Review the order context before closing this capture."
        }
        .buttonStyle(.bordered)
      }
    } else {
      wishlistNextStepPanel(
        title: "Next: use the linked order as source of truth",
        detail: "Wishlist purchase context is linked to \(linkedOrder?.orderNumber ?? "a local order"). Continue tracking dispatch, receiving, evidence, and tasks from the order workflow.",
        symbol: "shippingbox.fill",
        color: .green
      ) {
        Button("Task", systemImage: "checklist") {
          onTask()
          feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
        }
        .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open") {
          onDraft()
          feedbackMessage = "Wishlist follow-up draft created locally. No message was sent."
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func wishlistNextStepPanel<Actions: View>(
    title: String,
    detail: String,
    symbol: String,
    color: Color,
    @ViewBuilder actions: () -> Actions
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        actions()
      }
    }
    .padding(10)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistPurchaseDecisionSummary: some View {
    if let decision = item.purchaseDecision {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase decision", systemImage: "doc.text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.brown)
          Spacer(minLength: 8)
          Badge(decision.decisionStatus, color: decision.reviewState == .accepted ? .green : .orange)
        }

        CompactMetadataGrid(minimumWidth: 180) {
          PurchaseDecisionFact(title: "Seller", value: decision.selectedSellerName, symbol: "storefront.fill")
          PurchaseDecisionFact(title: "AUD total", value: decision.totalAUDSummary, symbol: "dollarsign.circle.fill")
          PurchaseDecisionFact(title: "Postage", value: decision.postageSummary, symbol: "shippingbox.fill")
          PurchaseDecisionFact(title: "Trust", value: decision.trustSummary, symbol: "shield.checkered")
        }

        if !decision.rejectedOptionsSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text("Rejected/alternate options: \(decision.rejectedOptionsSummary)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(decision.decisionNotes)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          Button("Reviewed", systemImage: "checkmark.seal") {
            onDecisionReviewed()
            feedbackMessage = "Purchase decision reviewed locally. Confirm live seller/account/payment details before buying externally."
          }
          .buttonStyle(.borderedProminent)
          Button("Needs review", systemImage: "exclamationmark.triangle") {
            onDecisionNeedsReview()
            feedbackMessage = "Purchase decision reopened locally for seller, trust, postage, account, or payment review."
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            onDecisionTask()
            feedbackMessage = "Purchase decision review task created or refreshed locally. Check Tasks before buying externally."
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(10)
      .background(.brown.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
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

        CompactActionRow {
          Button("Handoff task", systemImage: "checklist") {
            onHandoffTask()
            feedbackMessage = "Wishlist purchase handoff task created or refreshed locally. Confirm account, payment, address, seller page, and order confirmation outside ParcelOps."
          }
          .buttonStyle(.bordered)
        }

        if let linkedOrder, let store {
          VStack(alignment: .leading, spacing: 6) {
            Label("Linked order", systemImage: "shippingbox.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
            Text("This Wishlist handoff is linked to \(linkedOrder.orderNumber). Use the order detail as the source of truth for tracking, dispatch setup, receiving, and evidence.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            CompactActionRow {
              NavigationLink {
                OrderDetailView(order: linkedOrder, store: store)
              } label: {
                Label("Open linked order", systemImage: "arrow.up.right.square.fill")
              }
            }
            .buttonStyle(.bordered)
          }
          .padding(8)
          .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        } else if handoff.linkedOrderID != nil {
          Label("Linked order ID is stored, but the local order record was not found. Recreate or relink the order before staging downstream handoff records.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        VStack(alignment: .leading, spacing: 6) {
          Label("Account used for purchase", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Track the retailer or supplier account reference here. ParcelOps stores only non-secret account placeholders; no passwords, tokens, payment details, or browser sessions are stored.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedAccounts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No matching local account placeholder yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add account", systemImage: "key.badge.plus") {
                onAddAccount()
                feedbackMessage = "Account placeholder created from Wishlist handoff. No secrets, login, Keychain item, payment details, or retailer access were used."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedAccounts.prefix(3)) { account in
              WishlistAccountContextRow(account: account) {
                onAccountTask(account)
                feedbackMessage = "Account review task created locally. No credentials or retailer account were accessed."
              } onDraft: {
                onAccountDraft(account)
                feedbackMessage = "Account follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Cost and budget handoff", systemImage: "dollarsign.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local cost placeholder once a seller is preferred or purchase handoff is ready. This records expected AUD total, postage, trust context, owner, budget code, and account link without payment processing or accounting integration.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedCosts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No linked cost or budget placeholder yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add cost", systemImage: "dollarsign.circle") {
                onAddCost()
                feedbackMessage = "Wishlist purchase cost placeholder created locally. Review Costs & Budgets before buying externally."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedCosts.prefix(3)) { cost in
              WishlistCostContextRow(cost: cost) {
                onCostTask(cost)
                feedbackMessage = "Cost review task created locally. No payment, reimbursement, or accounting integration was used."
              } onDraft: {
                onCostDraft(cost)
                feedbackMessage = "Cost follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Procurement request", systemImage: "cart.badge.plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this when the item needs approval or buying coordination before an external purchase. It stays local and links back to the Wishlist item, account placeholder, and cost record.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedProcurementRequests.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No linked procurement request yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add request", systemImage: "cart.badge.plus") {
                onAddProcurement()
                feedbackMessage = "Wishlist procurement request created locally. Review approval, seller, account, budget, and delivery details before buying externally."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedProcurementRequests.prefix(3)) { request in
              WishlistProcurementContextRow(request: request) {
                onProcurementTask(request)
                feedbackMessage = "Procurement review task created locally. No supplier, purchase order, or payment integration was used."
              } onDraft: {
                onProcurementDraft(request)
                feedbackMessage = "Procurement follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Receiving check", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Stage a local receiving inspection before the item arrives so the operator knows what to verify: item, quantity, condition, accessories, paperwork, and discrepancy follow-up.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedReceivingInspections.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No receiving check staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add check", systemImage: "checkmark.seal") {
                onAddInspection()
                feedbackMessage = "Wishlist receiving inspection staged locally. No carrier, supplier, scanner, OCR, or warehouse system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedReceivingInspections.prefix(3)) { inspection in
              WishlistReceivingInspectionRow(inspection: inspection) {
                onInspectionTask(inspection)
                feedbackMessage = "Receiving inspection task created locally. No carrier, warehouse, scanner, or OCR integration was used."
              } onDraft: {
                onInspectionDraft(inspection)
                feedbackMessage = "Receiving inspection follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Inventory receipt", systemImage: "shippingbox.and.arrow.backward.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this to plan where the received item goes after inspection: stocked, handed off, partially accepted, rejected, or still pending local review.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedInventoryReceipts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No stock or handoff receipt staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add receipt", systemImage: "shippingbox.and.arrow.backward") {
                onAddInventoryReceipt()
                feedbackMessage = "Wishlist inventory receipt staged locally. No warehouse, inventory API, scanner, carrier, supplier, or mailbox action occurred."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedInventoryReceipts.prefix(3)) { receipt in
              WishlistInventoryReceiptRow(receipt: receipt) {
                onInventoryReceiptTask(receipt)
                feedbackMessage = "Inventory receipt task created locally. No warehouse, inventory API, scanner, or carrier integration was used."
              } onDraft: {
                onInventoryReceiptDraft(receipt)
                feedbackMessage = "Inventory receipt follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Storage or handoff location", systemImage: "archivebox.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Reserve a local staging spot for the item after receipt. This can later become a real shelf, bin, desk, locker, or handoff area assignment.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedStorageLocations.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No staging location reserved yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add location", systemImage: "archivebox") {
                onAddStorageLocation()
                feedbackMessage = "Wishlist staging location created locally. No warehouse, map, access-control, scanner, carrier, supplier, or inventory system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedStorageLocations.prefix(3)) { location in
              WishlistStorageLocationRow(location: location) {
                onStorageLocationTask(location)
                feedbackMessage = "Storage location task created locally. No warehouse, access-control, scanner, map, or inventory integration was used."
              } onDraft: {
                onStorageLocationDraft(location)
                feedbackMessage = "Storage location follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Custody and responsibility", systemImage: "person.2.badge.gearshape.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Track who is responsible for the item as it moves from purchase confirmation to receiving, staging, storage, or handoff. This is a local chain-of-custody note, not a signature or scanner workflow.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedCustodyRecords.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No custody record staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add custody", systemImage: "person.2.badge.gearshape") {
                onAddCustody()
                feedbackMessage = "Wishlist custody record created locally. No signature capture, scanner, access-control, warehouse, carrier, supplier, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedCustodyRecords.prefix(3)) { custody in
              WishlistCustodyRecordRow(custody: custody) {
                onCustodyTask(custody)
                feedbackMessage = "Custody review task created locally. No signature capture, scanner, access-control, or external system was used."
              } onDraft: {
                onCustodyDraft(custody)
                feedbackMessage = "Custody follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Label reference", systemImage: "tag.square.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local label placeholder that ties the Wishlist item to receiving, storage, custody, or handoff notes. This does not generate a barcode, QR code, printable label, scan, or carrier label.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedLabelReferences.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No label reference staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add label", systemImage: "tag.square") {
                onAddLabelReference()
                feedbackMessage = "Wishlist label reference created locally. No barcode, QR, printer, scanner, camera, carrier, warehouse, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedLabelReferences.prefix(3)) { label in
              WishlistLabelReferenceRow(label: label) {
                onLabelReferenceTask(label)
                feedbackMessage = "Label reference review task created locally. No scanner, printer, QR, barcode, carrier, or warehouse integration was used."
              } onDraft: {
                onLabelReferenceDraft(label)
                feedbackMessage = "Label reference follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Manual verification", systemImage: "checklist.checked")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Stage a local manual check that the received item, label reference, storage location, and custody record line up. This is not scanner hardware, camera access, barcode scanning, or QR generation.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedScanSessions.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No manual verification session staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add check", systemImage: "checklist.checked") {
                onAddScanSession()
                feedbackMessage = "Wishlist manual verification session created locally. No scanner, camera, barcode, QR, printer, carrier, warehouse, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedScanSessions.prefix(3)) { scan in
              WishlistScanSessionRow(scan: scan) {
                onScanSessionTask(scan)
                feedbackMessage = "Manual verification review task created locally. No scanner, camera, barcode, QR, printer, or external integration was used."
              } onDraft: {
                onScanSessionDraft(scan)
                feedbackMessage = "Manual verification follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Outbound handoff plan", systemImage: "paperplane.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local dispatch manifest only when the item needs an outbound transfer, courier handoff, internal delivery run, or final handoff after purchase and receipt. This does not book a carrier, print a label, or mark anything shipped.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedShipmentManifests.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No outbound handoff plan staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add manifest", systemImage: "paperplane") {
                onAddShipmentManifest()
                feedbackMessage = "Wishlist dispatch manifest created locally. No carrier booking, label printing, scanner, camera, warehouse, supplier, retailer, or mailbox action occurred."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedShipmentManifests.prefix(3)) { manifest in
              WishlistShipmentManifestRow(manifest: manifest) {
                onShipmentManifestTask(manifest)
                feedbackMessage = "Dispatch manifest review task created locally. No carrier, label, scanner, or warehouse integration was used."
              } onDraft: {
                onShipmentManifestDraft(manifest)
                feedbackMessage = "Dispatch manifest follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Dispatch readiness", systemImage: "checkmark.rectangle.stack.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this as a final local readiness gate before any outbound handoff. It checks the order evidence, receipt, storage, custody, label reference, manual verification, and manifest context without booking or sending anything.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedDispatchChecklists.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No dispatch readiness checklist staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add checklist", systemImage: "checkmark.rectangle.stack") {
                onAddDispatchChecklist()
                feedbackMessage = "Wishlist dispatch readiness checklist created locally. No carrier booking, label printing, scanner, camera, warehouse, notification, calendar, or external service was used."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedDispatchChecklists.prefix(3)) { checklist in
              WishlistDispatchChecklistRow(checklist: checklist) {
                onDispatchChecklistTask(checklist)
                feedbackMessage = "Dispatch readiness review task created locally. No carrier, label, scanner, notification, calendar, or external integration was used."
              } onDraft: {
                onDispatchChecklistDraft(checklist)
                feedbackMessage = "Dispatch readiness follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if !confirmationMatches.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Possible Inbox confirmations", systemImage: "envelope.badge.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.purple)
            Text("These are stored Inbox intake rows that match this Wishlist handoff. Use one only after confirming it is the purchase confirmation.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            ForEach(confirmationMatches.prefix(3)) { email in
              WishlistOrderConfirmationCandidateRow(email: email) {
                onUseConfirmation(email)
                feedbackMessage = "Wishlist handoff linked to an existing Inbox confirmation locally. Check Orders for the created or linked order."
              }
            }
          }
          .padding(8)
          .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .padding(10)
      .background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct WishlistOrderConfirmationCandidateRow: View {
  var email: ForwardedEmailIntake
  var onUse: () -> Void

  private var detail: String {
    [
      email.sender,
      email.receivedDate,
      email.detectedOrderNumber.isPlaceholderValidationValue ? nil : "Order \(email.detectedOrderNumber)",
      email.detectedTrackingNumber.isPlaceholderValidationValue ? nil : "Tracking \(email.detectedTrackingNumber)"
    ]
      .compactMap { $0 }
      .joined(separator: " • ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "envelope.open.fill")
        .foregroundStyle(.purple)
      VStack(alignment: .leading, spacing: 3) {
        Text(email.subject.isPlaceholderValidationValue ? "Inbox confirmation candidate" : email.subject)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      Button("Use", systemImage: "link.badge.plus", action: onUse)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Use this Inbox email as the Wishlist order confirmation")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAccountContextRow: View {
  var account: AccountCredentialRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "key.horizontal.fill")
        .foregroundStyle(account.credentialStorageStatus.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(account.accountName)
          .font(.caption.weight(.semibold))
        Text("\(account.organisation) • \(account.usernameLabel)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(account.credentialStorageStatus.rawValue, color: account.credentialStorageStatus.color)
          Badge(account.mfaStatus.rawValue, color: account.mfaStatus.color)
          Badge(account.reviewState.rawValue, color: account.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create account review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create account follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCostContextRow: View {
  var cost: CostRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "dollarsign.circle.fill")
        .foregroundStyle(cost.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(cost.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(cost.amountText) \(cost.currency) • \(cost.budgetCode) • \(cost.costOwnerTeam)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(cost.approvalStatus.rawValue, color: cost.approvalStatus == .approved ? .green : .orange)
          Badge(cost.reimbursementStatus.rawValue, color: cost.reimbursementStatus == .reimbursed ? .green : .secondary)
          Badge(cost.reviewState.rawValue, color: cost.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create cost review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create cost follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistProcurementContextRow: View {
  var request: ProcurementRequest
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "cart.badge.plus")
        .foregroundStyle(request.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(request.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(request.estimatedCostText) \(request.currency) • \(request.budgetCode) • \(request.assignedBuyerTeam)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(request.approvalStatus.rawValue, color: request.approvalStatus == .approved ? .green : .orange)
          Badge(request.procurementStatus.rawValue, color: request.procurementStatus == .received ? .green : .blue)
          Badge(request.reviewState.rawValue, color: request.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create procurement review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create procurement follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistReceivingInspectionRow: View {
  var inspection: ReceivingInspectionRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(inspection.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(inspection.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(inspection.inspectionType.rawValue) • \(inspection.assignedInspectorTeam) • \(inspection.dueDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(inspection.inspectionStatus.rawValue, color: inspection.inspectionStatus == .resolved ? .green : .blue)
          Badge(inspection.discrepancyType.rawValue, color: inspection.discrepancyType == .none ? .secondary : .orange)
          Badge(inspection.reviewState.rawValue, color: inspection.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create receiving inspection task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create receiving inspection follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistInventoryReceiptRow: View {
  var receipt: InventoryReceiptRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "shippingbox.and.arrow.backward.fill")
        .foregroundStyle(receipt.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(receipt.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(receipt.receiptType.rawValue) • \(receipt.assignedOwnerTeam) • \(receipt.storageLocationSummary)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(receipt.stockHandoffStatus.rawValue, color: receipt.stockHandoffStatus == .stocked || receipt.stockHandoffStatus == .handedOff ? .green : .blue)
          Badge("\(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted", color: receipt.quantityRejected > 0 ? .orange : .secondary)
          Badge(receipt.reviewState.rawValue, color: receipt.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create inventory receipt task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create inventory receipt follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistStorageLocationRow: View {
  var location: StorageLocationRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "archivebox.fill")
        .foregroundStyle(location.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(location.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(location.locationType.rawValue) • \(location.locationCode) • \(location.areaZone)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(location.isEnabled ? "Enabled" : "Disabled", color: location.isEnabled ? .green : .secondary)
          Badge(location.assignedOwnerTeam, color: .blue)
          Badge(location.reviewState.rawValue, color: location.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create storage location task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create storage location follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCustodyRecordRow: View {
  var custody: CustodyRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "person.2.badge.gearshape.fill")
        .foregroundStyle(custody.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(custody.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(custody.currentCustodianTeam) • \(custody.handoffMethod.rawValue) • \(custody.transferDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(custody.custodyStatus.rawValue, color: custody.custodyStatus == .received || custody.custodyStatus == .returnedClosed ? .green : .blue)
          Badge(custody.assignedOwnerTeam, color: .blue)
          Badge(custody.reviewState.rawValue, color: custody.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create custody review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create custody follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistLabelReferenceRow: View {
  var label: LabelReferenceRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "tag.square.fill")
        .foregroundStyle(label.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(label.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(label.labelType.rawValue) • \(label.labelValuePlaceholder) • \(label.labelSource.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(label.labelStatus.rawValue, color: label.labelStatus == .scannedVerified ? .green : label.labelStatus == .invalidNeedsReview ? .red : .blue)
          Badge(label.assignedOwnerTeam, color: .blue)
          Badge(label.reviewState.rawValue, color: label.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create label reference review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create label reference follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistScanSessionRow: View {
  var scan: ScanSessionRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checklist.checked")
        .foregroundStyle(scan.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(scan.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(scan.scanPurpose.rawValue) • \(scan.scanMethodPlaceholder.rawValue) • expected \(scan.expectedLabelReferenceValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(scan.scanStatus.rawValue, color: scan.scanStatus == .completed || scan.scanStatus == .matched ? .green : scan.scanStatus == .mismatchNeedsReview ? .red : .blue)
          Badge(scan.assignedOperatorTeam, color: .blue)
          Badge(scan.reviewState.rawValue, color: scan.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create manual verification review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create manual verification follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistShipmentManifestRow: View {
  var manifest: ShipmentManifestRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "paperplane.fill")
        .foregroundStyle(manifest.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(manifest.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(manifest.manifestType.rawValue) • \(manifest.carrierCourier) • \(manifest.plannedDispatchDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(manifest.dispatchStatus.rawValue, color: manifest.dispatchStatus == .handedOff || manifest.dispatchStatus == .dispatched ? .green : manifest.dispatchStatus == .blockedNeedsReview ? .red : .blue)
          Badge(manifest.assignedOwnerTeam, color: .blue)
          Badge(manifest.reviewState.rawValue, color: manifest.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch manifest review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch manifest follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistDispatchChecklistRow: View {
  var checklist: DispatchReadinessChecklist
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.rectangle.stack.fill")
        .foregroundStyle(checklist.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(checklist.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(checklist.checklistType.rawValue) • \(checklist.plannedDispatchDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(checklist.checklistStatus.rawValue, color: checklist.checklistStatus == .ready || checklist.checklistStatus == .completed ? .green : checklist.checklistStatus == .blockedNeedsReview ? .red : .blue)
          Badge(checklist.assignedOwnerTeam, color: .blue)
          Badge(checklist.reviewState.rawValue, color: checklist.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch readiness review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch readiness follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
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

private struct PurchasePacketFact: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(color)
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
    .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PurchaseDecisionFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(.brown)
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
    .background(.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
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
  var onDuplicate: () -> Void
  var onUpdate: (WishlistComparisonOption) -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var draft: WishlistComparisonOption

  init(
    option: WishlistComparisonOption,
    isPreferred: Bool,
    onPrefer: @escaping () -> Void,
    onDuplicate: @escaping () -> Void,
    onUpdate: @escaping (WishlistComparisonOption) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.option = option
    self.isPreferred = isPreferred
    self.onPrefer = onPrefer
    self.onDuplicate = onDuplicate
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _draft = State(initialValue: option)
  }

  private var trustColor: Color {
    if option.trustRating.localizedCaseInsensitiveContains("high") || option.trustRating.localizedCaseInsensitiveContains("trusted") { return .green }
    if option.trustRating.localizedCaseInsensitiveContains("review") || option.trustRating.localizedCaseInsensitiveContains("unknown") { return .orange }
    return .secondary
  }

  private var isCaptureStagedOption: Bool {
    option.recommendation.localizedCaseInsensitiveContains("captured")
      || option.decisionReason?.localizedCaseInsensitiveContains("capture metadata") == true
      || option.trustNotes.localizedCaseInsensitiveContains("Wishlist staging")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(option.sellerName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Spacer(minLength: 8)
        if isCaptureStagedOption {
          Badge("Captured", color: .purple)
        }
        Badge(isPreferred ? "Preferred" : option.recommendation, color: isPreferred ? .green : .blue)
      }
      if isCaptureStagedOption {
        Label("Created from staged capture clues. Confirm live price, AUD total, postage, trust, returns, warranty, and availability before selecting this seller.", systemImage: "puzzlepiece.extension.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.purple)
          .fixedSize(horizontal: false, vertical: true)
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
      WishlistSellerEvidenceChecklist(option: option)
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
        Button("Edit option", systemImage: "pencil") {
          draft = option
          isEditing = true
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Edit seller option")
        Button("Copy option", systemImage: "doc.on.doc") {
          onDuplicate()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Copy seller option")
        Button("Remove option", systemImage: "trash") {
          onRemove()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Remove seller option")
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background((isPreferred ? Color.green : trustColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      WishlistComparisonOptionEditor(option: $draft) {
        isEditing = false
      } onSave: {
        onUpdate(draft)
        isEditing = false
      }
    }
  }
}

private struct WishlistSellerEvidenceChecklist: View {
  var option: WishlistComparisonOption

  private var evidenceItems: [(String, Bool, String)] {
    let searchable = [
      option.productURL,
      option.listedPrice,
      option.currency,
      option.estimatedAUDTotal,
      option.postageCost,
      option.postageTime,
      option.sellerRegion,
      option.trustRating,
      option.trustNotes,
      option.recommendation
    ]
      .joined(separator: " ")
      .localizedLowercase

    return [
      ("Product link", !option.productURL.isPlaceholderValidationValue && option.productURL.localizedCaseInsensitiveContains("http"), "Direct seller page"),
      ("AUD total", option.estimatedAUDTotal.localizedCaseInsensitiveContains("aud") && !option.estimatedAUDTotal.localizedCaseInsensitiveContains("pending"), "Landed AUD"),
      ("Postage cost", !option.postageCost.localizedCaseInsensitiveContains("pending") && !option.postageCost.isPlaceholderValidationValue, "Cost known"),
      ("Postage time", !option.postageTime.localizedCaseInsensitiveContains("pending") && !option.postageTime.isPlaceholderValidationValue, "ETA known"),
      ("Seller trust", !option.trustRating.localizedCaseInsensitiveContains("unknown") && !option.trustRating.localizedCaseInsensitiveContains("review"), "Trust noted"),
      ("Returns/warranty", searchable.contains("return") || searchable.contains("warranty"), "Policy noted")
    ]
  }

  private var missingItems: [String] {
    evidenceItems.filter { !$0.1 }.map(\.0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Label("Evidence", systemImage: "checklist")
          .font(.caption2.weight(.semibold))
        Badge(missingItems.isEmpty ? "Complete enough for review" : "\(missingItems.count) missing", color: missingItems.isEmpty ? .green : .orange)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(evidenceItems, id: \.0) { title, passed, detail in
          HStack(spacing: 5) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
              .foregroundStyle(passed ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
              Text(title)
                .font(.caption2.weight(.semibold))
              Text(passed ? detail : "Needs check")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .padding(6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background((passed ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
      }
      if !missingItems.isEmpty {
        Text("Before purchase review, fill in: \(missingItems.joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonOptionEditor: View {
  @Binding var option: WishlistComparisonOption
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("Seller option", systemImage: "storefront.fill")
          .font(.headline)
        Spacer()
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
        Button("Save", action: onSave)
          .buttonStyle(.borderedProminent)
      }

      Text("Record manual comparison details only. ParcelOps does not verify live prices, contact retailers, calculate postage, access accounts, or purchase anything from this editor.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          GroupBox("Retailer") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Seller name", text: $option.sellerName)
              TextField("Product URL", text: $option.productURL)
              TextField("Seller region", text: $option.sellerRegion)
              TextField("Recommendation", text: $option.recommendation)
            }
          }

          GroupBox("Price and postage") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Listed price", text: $option.listedPrice)
              TextField("Currency", text: $option.currency)
              TextField("Estimated AUD total", text: $option.estimatedAUDTotal)
              TextField("Postage cost", text: $option.postageCost)
              TextField("Postage time", text: $option.postageTime)
            }
          }

          GroupBox("Trust and decision notes") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Trust rating", text: $option.trustRating)
              TextField("Trust notes", text: $option.trustNotes, axis: .vertical)
                .lineLimit(3...6)
              TextField("Decision reason", text: Binding(
                get: { option.decisionReason ?? "" },
                set: { option.decisionReason = $0 }
              ), axis: .vertical)
                .lineLimit(2...5)
            }
          }
        }
      }
    }
    .padding(20)
    .frame(minWidth: 520, minHeight: 560)
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
