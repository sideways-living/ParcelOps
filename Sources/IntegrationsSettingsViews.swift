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
            ShopifyConnectionRow(connection: connection, suggestedAccounts: store.suggestedAccounts(for: connection), suggestedProfiles: store.suggestedVendorProfiles(for: connection)) {
              store.addAccountCredentialRecord(linkedEntityType: .shopifyStore, linkedEntityID: connection.id.uuidString, organisation: connection.storeName, label: connection.storeName)
            } onTaskFromAccount: { account in
              store.createReviewTask(from: account)
            } onDraftFromAccount: { account in
              store.createDraftMessage(from: account)
            } onCreateProfile: {
              store.addVendorProfile(profileType: .shopifyStore, organisation: connection.storeName, label: connection.storeName)
            } onTaskFromProfile: { profile in
              store.createReviewTask(from: profile)
            } onDraftFromProfile: { profile in
              store.createDraftMessage(from: profile)
            }
          }
        }
        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
        }
        ForEach(store.connections) { connection in
          SourceConnectionRow(connection: connection, suggestedAccounts: store.suggestedAccounts(for: connection), suggestedProfiles: store.suggestedVendorProfiles(for: connection)) {
            store.addAccountCredentialRecord(linkedEntityType: .sourceConnection, linkedEntityID: connection.id.uuidString, organisation: connection.name, label: connection.name)
          } onTaskFromAccount: { account in
            store.createReviewTask(from: account)
          } onDraftFromAccount: { account in
            store.createDraftMessage(from: account)
          } onCreateProfile: {
            store.addVendorProfile(profileType: .supplier, organisation: connection.name, label: connection.name)
          } onTaskFromProfile: { profile in
            store.createReviewTask(from: profile)
          } onDraftFromProfile: { profile in
            store.createDraftMessage(from: profile)
          }
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
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
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

      HStack {
        Button("Account", systemImage: "key.badge.plus", action: onCreateAccount)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
      }

      ForEach(suggestedAccounts) { account in
        AccountSuggestionRow(account: account) {
          onTaskFromAccount(account)
        } onCreateDraft: {
          onDraftFromAccount(account)
        }
      }

      ForEach(suggestedProfiles) { profile in
        VendorProfileSuggestionRow(profile: profile) {
          onTaskFromProfile(profile)
        } onCreateDraft: {
          onDraftFromProfile(profile)
        }
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
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
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

      HStack {
        Button("Account", systemImage: "key.badge.plus", action: onCreateAccount)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
      }

      ForEach(suggestedAccounts) { account in
        AccountSuggestionRow(account: account) {
          onTaskFromAccount(account)
        } onCreateDraft: {
          onDraftFromAccount(account)
        }
      }

      ForEach(suggestedProfiles) { profile in
        VendorProfileSuggestionRow(profile: profile) {
          onTaskFromProfile(profile)
        } onCreateDraft: {
          onDraftFromProfile(profile)
        }
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

        MVPWorkflowGuide(
          title: "Before connecting live systems",
          detail: "These settings describe the intended workflow, but the current MVP remains local-only.",
          steps: [
            "Use sample and placeholder records to test the full flow.",
            "Do not enter real passwords, API keys, OAuth secrets, or mailbox credentials.",
            "Treat toggles as planning controls until integrations are explicitly added.",
            "Use Audit to confirm that local actions are being recorded."
          ],
          symbol: "gearshape.2.fill"
        )

        SettingsPanel(title: "MVP local-only status", symbol: "checklist") {
          Text("ParcelOps currently stores local JSON records and sample operational data. These controls describe intended workflows; they do not connect to live services yet.")
            .foregroundStyle(.secondary)

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            IntegrationStatusRow(title: "Email mailbox", status: "Not connected", symbol: "envelope.badge.fill", color: .orange)
            IntegrationStatusRow(title: "Shopify", status: "Not connected", symbol: "cart.badge.plus", color: .orange)
            IntegrationStatusRow(title: "Carrier APIs", status: "Not connected", symbol: "location.fill.viewfinder", color: .orange)
            IntegrationStatusRow(title: "Store logins", status: "Placeholder only", symbol: "key.horizontal.fill", color: .orange)
            IntegrationStatusRow(title: "Credential storage", status: "Not enabled", symbol: "lock.shield.fill", color: .red)
            IntegrationStatusRow(title: "Background sync", status: "Not enabled", symbol: "bell.slash.fill", color: .red)
          }
        }

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
          Toggle("Plan Shopify supplier sync", isOn: $store.settings.shopifySyncEnabled)
          Toggle("Plan password-vault login sync", isOn: $store.settings.storeLoginSyncEnabled)
          Toggle("Plan carrier tracking handoff", isOn: $store.settings.carrierTrackingEnabled)
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

struct IntegrationStatusRow: View {
  var title: String
  var status: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(status)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
