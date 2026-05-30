import SwiftUI

struct IntegrationsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Connected sources")
            .font(isCompact ? .title2.bold() : .title.bold())
          HStack {
            Button("Add mailbox", systemImage: "envelope.badge.fill", action: store.addTrackedMailboxPlaceholder)
            Button("Connect Shopify", systemImage: "cart.badge.plus", action: store.connectShopifyPlaceholder)
            Button("Watch folder", systemImage: "folder.badge.plus", action: store.addWatchedFolderPlaceholder)
            Button("Add login", systemImage: "key.fill", action: store.addStoreLoginPlaceholder)
          }
        }

        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
        }
        SettingsPanel(title: "Shopify stores", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
        }
        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
        }
        ForEach(store.connections) { connection in
          SourceConnectionRow(connection: connection)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct MailboxConnectionRow: View {
  var mailbox: TrackedMailbox

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: mailbox.provider.symbol)
        .foregroundStyle(.blue)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(mailbox.address)
          .font(.headline)
        Text("\(mailbox.provider.rawValue) • \(mailbox.monitoredFolders)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(mailbox.routingRule)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(mailbox.status)
          .font(.callout.weight(.semibold))
        Text(mailbox.lastChecked)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ShopifyConnectionRow: View {
  var connection: ShopifyConnection

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "cart.fill")
        .foregroundStyle(.green)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(connection.storeName)
          .font(.headline)
        Text(connection.storeDomain)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(connection.mappedTeam) • \(connection.mappedMailbox)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(connection.isEnabled ? connection.status : "Disabled")
          .font(.callout.weight(.semibold))
        Text(connection.lastSync)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WatchedFolderRow: View {
  var folder: WatchedFolder

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "folder.fill.badge.gearshape")
        .foregroundStyle(.orange)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(folder.name)
          .font(.headline)
        Text(folder.location)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(folder.platform) • \(folder.fileTypes) • \(folder.cadence)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(folder.status)
          .font(.callout.weight(.semibold))
        Text(folder.lastScan)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct SourceConnectionRow: View {
  var connection: SourceConnection

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: connection.kind.symbol)
        .foregroundStyle(.teal)
        .frame(width: 34)
      VStack(alignment: .leading, spacing: 4) {
        Text(connection.name)
          .font(.headline)
        Text("\(connection.kind.rawValue) • \(connection.account)")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(connection.status)
          .font(.callout.weight(.semibold))
        Text(connection.lastSync)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct SettingsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(isCompact ? .title.bold() : .largeTitle.bold())

        SettingsPanel(title: "Mailbox intake", symbol: "envelope.open.fill") {
          Toggle("Monitor forwarded tracking mailbox", isOn: $store.settings.mailboxMonitoringEnabled)
          Toggle("Create orders from recognized emails", isOn: $store.settings.autoCreateOrdersFromEmail)
          Picker("Match confidence", selection: $store.settings.matchConfidencePolicy) {
            Text("Strict").tag("Strict")
            Text("Balanced").tag("Balanced")
            Text("Permissive").tag("Permissive")
          }
          .pickerStyle(.menu)
        }

        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
          Button("Add tracked mailbox", systemImage: "plus", action: store.addTrackedMailboxPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Shopify accounts", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
          Button("Connect Shopify account", systemImage: "plus", action: store.connectShopifyPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          Toggle("Regularly scan saved folders", isOn: $store.settings.folderWatchingEnabled)
          Picker("Scan cadence", selection: $store.settings.folderScanCadence) {
            Text("Every 5 minutes").tag("Every 5 minutes")
            Text("Every 15 minutes").tag("Every 15 minutes")
            Text("Hourly").tag("Hourly")
            Text("Manual only").tag("Manual only")
          }
          .pickerStyle(.menu)
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
          Button("Add folder", systemImage: "folder.badge.plus", action: store.addWatchedFolderPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Review controls", symbol: "checkmark.shield.fill") {
          Toggle("Require review for risky email/order matches", isOn: $store.settings.requireReviewForRiskyMatches)
          Toggle("Notify on delivery exceptions", isOn: $store.settings.notifyOnDeliveryExceptions)
          Stepper("Exception alert threshold: \(store.settings.exceptionThreshold)", value: $store.settings.exceptionThreshold, in: 1...10)
        }

        SettingsPanel(title: "Connected sources", symbol: "link.badge.plus") {
          Toggle("Sync Shopify OAuth suppliers", isOn: $store.settings.shopifySyncEnabled)
          Toggle("Sync password-vault store logins", isOn: $store.settings.storeLoginSyncEnabled)
          Toggle("Enable delivery handoff after shipment", isOn: $store.settings.carrierTrackingEnabled)
          Picker("Carrier tracking mode", selection: $store.settings.carrierTrackingMode) {
            Text("Export to Parcel").tag("Export to Parcel")
            Text("Free carrier API").tag("Free carrier API")
            Text("Manual updates").tag("Manual updates")
          }
          .pickerStyle(.menu)
          Button("Save settings", systemImage: "checkmark", action: store.saveSettings)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}
