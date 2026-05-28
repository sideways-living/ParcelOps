#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct ParcelOpsActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var status: String
    var eta: String
    var exceptionCount: Int
  }

  var orderNumber: String
  var store: String
  var destination: String
}
#endif
