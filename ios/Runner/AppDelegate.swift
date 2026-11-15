import Flutter
import UIKit
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StudioPurchaseVerification") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "m.volume.booster/purchases", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "currentEntitlements" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        let productIds: Set<String> = ["v.booster.weekly", "v.booster.monthly", "v.booster.yearly"]
        var entitlements: [[String: Any]] = []
        do {
          for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
              productIds.contains(transaction.productID),
              transaction.productType == .autoRenewable,
              transaction.revocationDate == nil,
              !transaction.isUpgraded,
              var expiry = transaction.expirationDate
            else { continue }
            if expiry <= Date() {
              // currentEntitlements also includes valid billing-grace access.
              // Use its verified renewal expiry, never an invented grace date.
              let products = try await Product.products(for: [transaction.productID])
              guard let subscription = products.first?.subscription else {
                result(FlutterError(code: "store_unavailable", message: "Subscription status is unavailable", details: nil))
                return
              }
              var graceExpiry: Date?
              for status in try await subscription.status {
                guard status.state == .inGracePeriod,
                  case .verified(let statusTransaction) = status.transaction,
                  statusTransaction.id == transaction.id,
                  case .verified(let renewalInfo) = status.renewalInfo,
                  let date = renewalInfo.gracePeriodExpirationDate, date > Date()
                else { continue }
                graceExpiry = date
              }
              guard let date = graceExpiry else { continue }
              expiry = date
            }
            entitlements.append([
              "transactionId": String(transaction.id),
              "productId": transaction.productID,
              "expiresAtMs": Int64(expiry.timeIntervalSince1970 * 1000),
              "verified": true,
              "revoked": false,
            ])
          }
          result(entitlements)
        } catch {
          result(FlutterError(code: "store_unavailable", message: "Subscription verification is unavailable", details: nil))
        }
      }
    }
  }
}
