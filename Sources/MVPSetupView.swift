import SwiftUI

struct MVPSetupView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        SettingsPanel(title: "First usable workflow", symbol: "point.3.connected.trianglepath.dotted") {
          VStack(alignment: .leading, spacing: 12) {
            MVPWorkflowStep(number: "1", title: "Review intake", detail: "Use Mailbox Monitor, Import Queue, and Acceptance Review to turn local sample intake into tracked orders.")
            MVPWorkflowStep(number: "2", title: "Work exceptions", detail: "Use Needs Review and Operations Workbench to clear blocked, risky, or incomplete operational records.")
            MVPWorkflowStep(number: "3", title: "Prepare dispatch", detail: "Use Shipment Manifests and Dispatch Readiness to stage local outbound handoff work.")
            MVPWorkflowStep(number: "4", title: "Check traceability", detail: "Use Tasks and Audit to confirm follow-up work and local change history.")
          }
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          MVPStatusCard(title: "Local data store", detail: "Orders, intake, review work, manifests, tasks, and audit events are persisted as local JSON.", status: "Available", symbol: "internaldrive.fill", color: .green)
          MVPStatusCard(title: "Manual operations", detail: "You can create, edit, review, link, and remove local operational records.", status: "Available", symbol: "hand.tap.fill", color: .green)
          MVPStatusCard(title: "Forwarded mailbox", detail: "Mailbox records and intake review screens exist, but no real email provider is connected.", status: "Placeholder", symbol: "envelope.badge.fill", color: .orange)
          MVPStatusCard(title: "Shopify", detail: "Shopify records and account placeholders exist, but no Shopify API or OAuth flow is connected.", status: "Placeholder", symbol: "cart.badge.plus", color: .orange)
          MVPStatusCard(title: "Carrier tracking", detail: "Tracking events are local records only. Carrier APIs and live refresh are not connected.", status: "Placeholder", symbol: "location.fill.viewfinder", color: .orange)
          MVPStatusCard(title: "Store logins", detail: "Account records are placeholders only. No browser automation or credential sync is active.", status: "Placeholder", symbol: "key.horizontal.fill", color: .orange)
          MVPStatusCard(title: "Credential storage", detail: "No passwords, tokens, API keys, OAuth secrets, or Keychain records are stored.", status: "Not connected", symbol: "lock.shield.fill", color: .red)
          MVPStatusCard(title: "Background work", detail: "No background sync, notifications, reminders, calendars, OCR, scanners, or file pickers are active.", status: "Not connected", symbol: "bell.slash.fill", color: .red)
        }

        SettingsPanel(title: "MVP health snapshot", symbol: "gauge.with.dots.needle.67percent") {
          MetricStrip(items: [
            ("Orders", "\(store.orders.count)", .blue),
            ("Review queue", "\(store.reviewQueueCount)", .orange),
            ("Open work", "\(store.openWorkbenchItems.count)", .teal),
            ("Audit events", "\(store.auditEvents.count)", .purple)
          ])

          Text("Use this pass to judge whether the workflow is understandable before connecting real systems. The best next product work is simplifying confusing screens, then connecting one real intake source.")
            .foregroundStyle(.secondary)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.background)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MVP Setup")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("ParcelOps is currently a local-first operations prototype. Use these screens to test the order intake, review, dispatch, task, and audit workflow before connecting live systems.")
        .foregroundStyle(.secondary)
    }
  }
}

struct MVPWorkflowStep: View {
  var number: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(number)
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(.teal)
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct MVPStatusCard: View {
  var title: String
  var detail: String
  var status: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        Image(systemName: symbol)
          .foregroundStyle(color)
          .frame(width: 24)
        Spacer()
        Badge(status, color: color)
      }
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}
