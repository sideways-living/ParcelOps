import SwiftUI

struct AutomationView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var steps: [(String, String, String)] = [
    ("Mailbox parsing", "Extract order numbers, sender domains, totals, delivery warnings, and recipient aliases.", "envelope.open.fill"),
    ("Account sync", "Refresh supplier portals and Shopify OAuth stores without overwriting reviewed data.", "arrow.triangle.2.circlepath"),
    ("Order matching", "Compare supplier order number, checked mailbox, original recipient email, store, and customer team.", "link"),
    ("Review gate", "Risky matches enter Needs Review before changing order records.", "checkmark.shield.fill"),
    ("Delivery handoff", "Use a free carrier API if available, otherwise export delivery details to the Parcel app.", "square.and.arrow.up")
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Automation flow")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        ForEach(steps, id: \.0) { step in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.2)
              .foregroundStyle(.white)
              .frame(width: 34, height: 34)
              .background(.teal)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
              Text(step.0)
                .font(.headline)
              Text(step.1)
                .foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .background(.background)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}
