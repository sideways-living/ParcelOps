import AppIntents
import SwiftUI
import WidgetKit

struct ParcelOpsWidgetEntry: TimelineEntry {
  var date: Date
  var activeOrders: Int
  var exceptions: Int
  var mailboxEvents: Int
}

struct ParcelOpsWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> ParcelOpsWidgetEntry {
    ParcelOpsWidgetEntry(date: .now, activeOrders: 42, exceptions: 3, mailboxEvents: 18)
  }

  func getSnapshot(in context: Context, completion: @escaping (ParcelOpsWidgetEntry) -> Void) {
    completion(placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ParcelOpsWidgetEntry>) -> Void) {
    completion(Timeline(entries: [placeholder(in: context)], policy: .after(.now.addingTimeInterval(900))))
  }
}

struct ParcelOpsWidgetView: View {
  var entry: ParcelOpsWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("ParcelOps", systemImage: "shippingbox.fill")
        .font(.headline)
      HStack {
        Metric("Active", value: entry.activeOrders, color: .teal)
        Metric("Issues", value: entry.exceptions, color: .red)
        Metric("Mail", value: entry.mailboxEvents, color: .blue)
      }
    }
    .containerBackground(.background, for: .widget)
  }
}

struct Metric: View {
  var title: String
  var value: Int
  var color: Color

  init(_ title: String, value: Int, color: Color) {
    self.title = title
    self.value = value
    self.color = color
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("\(value)")
        .font(.title2.bold())
        .foregroundStyle(color)
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct ParcelOpsStatusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "parcelops.status", provider: ParcelOpsWidgetProvider()) { entry in
      ParcelOpsWidgetView(entry: entry)
    }
    .configurationDisplayName("ParcelOps Status")
    .description("Shows active orders, exception count, and mailbox intake volume.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct OpenParcelOpsIntent: AppIntent {
  static var title: LocalizedStringResource = "Open ParcelOps"
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    .result()
  }
}

@available(iOS 18.0, macOS 15.0, watchOS 11.0, *)
struct ParcelOpsControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "parcelops.open-control") {
      ControlWidgetButton(action: OpenParcelOpsIntent()) {
        Label("ParcelOps", systemImage: "shippingbox.fill")
      }
    }
    .displayName("Open ParcelOps")
    .description("Open the operations dashboard.")
  }
}

struct ParcelOpsLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ParcelOpsActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 6) {
        Text(context.attributes.orderNumber)
          .font(.headline)
        Text(context.state.status)
        Text(context.attributes.destination)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .containerBackground(.background, for: .widget)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.orderNumber)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.eta)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.status)
        }
      } compactLeading: {
        Image(systemName: "shippingbox.fill")
      } compactTrailing: {
        Text("\(context.state.exceptionCount)")
      } minimal: {
        Image(systemName: "shippingbox.fill")
      }
    }
  }
}

@main
struct ParcelOpsWidgetBundle: WidgetBundle {
  var body: some Widget {
    ParcelOpsStatusWidget()
    ParcelOpsLiveActivity()
    if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *) {
      ParcelOpsControl()
    }
  }
}
