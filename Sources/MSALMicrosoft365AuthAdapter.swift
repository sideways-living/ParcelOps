import Foundation

#if canImport(MSAL)
import MSAL
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
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

  @MainActor
  func callbackReadinessStatus(for url: URL) -> String {
    guard url.scheme == Self.redirectScheme else {
      return "Ignored non-MSAL callback URL."
    }
    #if canImport(MSAL) && os(iOS)
    _ = MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    #endif
    return "MSAL callback URL scheme detected and routed through the Microsoft sign-in boundary when supported."
  }
}

struct MSALMicrosoft365AuthClient: Microsoft365AuthClient {
  func connect(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    #if canImport(MSAL)
    let missingFields = missingReadinessFields(for: connection)
    guard missingFields.isEmpty else {
      return Microsoft365AuthResult(
        status: .notConfigured,
        signedInAccount: "Not signed in",
        detailText: "Setup incomplete: \(missingFields.joined(separator: ", ")). Real Microsoft 365 sign-in was not started, no browser opened, and no token request was made. Use Edit setup to add Entra tenant/client/redirect values, or use mock auth for local testing."
      )
    }

    return await performInteractiveSignIn(connection: connection)
    #else
    Microsoft365AuthResult(
      status: .notConfigured,
      signedInAccount: "Not signed in",
      detailText: "Real Microsoft 365 sign-in is unavailable because MSAL is not linked in this build."
    )
    #endif
  }

  func simulateFailure(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    Microsoft365AuthResult(
      status: .authFailed,
      signedInAccount: "Not signed in",
      detailText: "Real Microsoft 365 sign-in failure simulation is not used. Use the mock auth client for local failure testing."
    )
  }

  private static let redirectURI = "msauth.app.bitrig.parcelops://auth"

  private func missingReadinessFields(for connection: Microsoft365MailboxConnection) -> [String] {
    var missingFields: [String] = []
    if connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && connection.tenantDomainHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Tenant ID or tenant domain")
    }
    if connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Client ID")
    }
    let redirect = connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    if redirect.isEmpty {
      missingFields.append("Redirect URI")
    } else if redirect != Self.redirectURI {
      missingFields.append("Redirect URI must be \(Self.redirectURI)")
    }
    return missingFields
  }

  private func normalizedTenant(for connection: Microsoft365MailboxConnection) -> String {
    let tenantID = connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tenantID.isEmpty {
      return tenantID
    }
    let domainHint = connection.tenantDomainHint.trimmingCharacters(in: .whitespacesAndNewlines)
    return domainHint.isEmpty ? "organizations" : domainHint
  }

  @MainActor
  private func performInteractiveSignIn(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    let tenant = normalizedTenant(for: connection)
    guard let authorityURL = URL(string: "https://login.microsoftonline.com/\(tenant)") else {
      return Microsoft365AuthResult(
          status: .notConfigured,
          signedInAccount: "Not signed in",
          detailText: "Setup issue: the tenant placeholder could not form a Microsoft identity authority URL. Use a tenant ID GUID or domain such as company.onmicrosoft.com. No token value was stored and no mailbox call was made."
        )
    }

    do {
      let authority = try MSALAADAuthority(url: authorityURL)
      let config = MSALPublicClientApplicationConfig(
        clientId: connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
        redirectUri: Self.redirectURI,
        authority: authority
      )
      let application = try MSALPublicClientApplication(configuration: config)
      let webParameters = try Self.webviewParameters()
      let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webParameters)
      parameters.promptType = .selectAccount
      return await acquireToken(application: application, parameters: parameters, connection: connection)
    } catch {
      return Microsoft365AuthResult(
        status: .authFailed,
        signedInAccount: "Not signed in",
        detailText: "MSAL setup/runtime issue: \(safeErrorSummary(error)). Check client ID, redirect URI, active app window, Xcode signing, and MSAL cache/Keychain configuration. No token value was stored in ParcelOps JSON and no Microsoft Graph mailbox call was made."
      )
    }
  }

  @MainActor
  private func acquireToken(
    application: MSALPublicClientApplication,
    parameters: MSALInteractiveTokenParameters,
    connection: Microsoft365MailboxConnection
  ) async -> Microsoft365AuthResult {
    await withCheckedContinuation { continuation in
      application.acquireToken(with: parameters) { result, error in
        if let error {
          continuation.resume(returning: self.authResult(from: error))
          return
        }

        guard let result else {
          continuation.resume(returning: Microsoft365AuthResult(
            status: .authFailed,
            signedInAccount: "Not signed in",
            detailText: "Sign-in ended without an MSAL result. Try again from an active ParcelOps window, or use mock auth for local testing. No token value was stored in ParcelOps JSON and no Microsoft Graph mailbox call was made."
          ))
          return
        }

        let account = result.account.username ?? connection.mailboxAddress
        continuation.resume(returning: Microsoft365AuthResult(
          status: .connected,
          signedInAccount: account.isEmpty ? "Signed in Microsoft account" : account,
          detailText: "Success: real Microsoft 365 identity sign-in completed with User.Read only. MSAL handled its token cache internally; ParcelOps did not store or log access tokens, refresh tokens, ID tokens, auth codes, passwords, or client secrets. Microsoft Graph mailbox calls remain mocked."
        ))
      }
    }
  }

  private func authResult(from error: Error) -> Microsoft365AuthResult {
    let nsError = error as NSError
    if nsError.domain == "MSALErrorDomain" && nsError.code == -50005 {
      return Microsoft365AuthResult(
        status: .notConnected,
        signedInAccount: "Not signed in",
        detailText: "Cancelled: Microsoft 365 sign-in was closed before completion. No account was connected, no token value was stored in ParcelOps JSON, and no Microsoft Graph mailbox call was made."
      )
    }

    let status: Microsoft365AuthStatus = nsError.domain == "MSALErrorDomain" ? .consentRequired : .authFailed
    return Microsoft365AuthResult(
      status: status,
      signedInAccount: "Not signed in",
      detailText: "\(status == .consentRequired ? "Consent/admin review needed" : "Sign-in failed"): \(safeErrorSummary(error)). Check Entra app registration, tenant policy, User.Read consent, redirect URI, and signing. No token value was stored in ParcelOps JSON and no Microsoft Graph mailbox call was made."
    )
  }

  private func safeErrorSummary(_ error: Error) -> String {
    let description = error.localizedDescription
    return description.isEmpty ? "MSAL returned an authentication error." : description
  }

  #if canImport(UIKit)
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }
    var controller = keyWindow?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    guard let controller else {
      throw MSALMicrosoft365AuthError.missingPresentationWindow
    }
    return MSALWebviewParameters(authPresentationViewController: controller)
  }
  #elseif canImport(AppKit)
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    guard let controller = NSApplication.shared.keyWindow?.contentViewController ?? NSApplication.shared.mainWindow?.contentViewController else {
      throw MSALMicrosoft365AuthError.missingPresentationWindow
    }
    return MSALWebviewParameters(authPresentationViewController: controller)
  }
  #else
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    throw MSALMicrosoft365AuthError.missingPresentationWindow
  }
  #endif
}

enum MSALMicrosoft365AuthError: LocalizedError {
  case missingPresentationWindow

  var errorDescription: String? {
    switch self {
    case .missingPresentationWindow:
      "ParcelOps could not find an active presentation window for Microsoft sign-in."
    }
  }
}
