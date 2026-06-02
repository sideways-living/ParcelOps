import SwiftUI

struct AuditView: View {
  var store: ParcelOpsStore
  @State private var selectedAction: AuditAction?
  @State private var selectedEntityType: AuditEntityType?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var filteredEvents: [AuditEvent] {
    store.auditEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      return matchesAction && matchesEntity
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Audit trail")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local history for order, intake, and review actions.")
            .foregroundStyle(.secondary)
        }

        filterBar

        SettingsPanel(title: "Recent activity", symbol: "list.clipboard.fill") {
          if filteredEvents.isEmpty {
            Text("No audit events match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredEvents) { event in
              AuditEventRow(event: event)
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Action", selection: $selectedAction) {
        Text("All actions").tag(nil as AuditAction?)
        ForEach(AuditAction.allCases) { action in
          Text(action.rawValue).tag(action as AuditAction?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as AuditEntityType?)
        ForEach(AuditEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as AuditEntityType?)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedAction = nil
        selectedEntityType = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct AuditEventRow: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.entityLabel)
                .font(.headline)
              Text("\(event.actor) • \(event.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(event.action.rawValue, color: event.action.color)
          }

          Text(event.summary)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(event.entityType.rawValue, color: event.action.color)
            Text(event.entityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }

      if event.beforeDetail != nil || event.afterDetail != nil {
        VStack(alignment: .leading, spacing: 8) {
          if let beforeDetail = event.beforeDetail {
            AuditDetailBlock(title: "Before", detail: beforeDetail)
          }
          if let afterDetail = event.afterDetail {
            AuditDetailBlock(title: "After", detail: afterDetail)
          }
        }
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct AuditDetailBlock: View {
  var title: String
  var detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.background.opacity(0.65))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
