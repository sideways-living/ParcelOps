import Foundation

#if canImport(MSAL)
import MSAL
#endif

struct MSALMicrosoft365AuthAdapter {
  static let bundleID = "app.bitrig.parcelops"
  static let redirectScheme = "msauth.app.bitrig.parcelops"
  static let redirectURI = "msauth.app.bitrig.parcelops://auth"

  var dependencyStatus: String {
    #if canImport(MSAL)
    "MSAL package is linked for compile-time readiness."
    #else
    "MSAL package is not available to this build."
    #endif
  }

  func callbackReadinessStatus(for url: URL) -> String {
    guard url.scheme == Self.redirectScheme else {
      return "Ignored non-MSAL callback URL."
    }
    return "MSAL callback URL scheme detected. OAuth response handling is intentionally not active yet."
  }
}
