import SwiftUI

struct WatchContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Label("42 active", systemImage: "shippingbox.fill")
          .foregroundStyle(.teal)
        Label("3 exceptions", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
        Label("18 mail events", systemImage: "envelope.fill")
          .foregroundStyle(.blue)
      }
      .navigationTitle("ParcelOps")
    }
  }
}
