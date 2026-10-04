import Foundation
import ServiceManagement

/// Start-at-login, driven by the optional `startAtLogin` config key.
enum LoginItem {
    /// Makes the login item match `desired`. `nil` (key absent) leaves it exactly as the user
    /// has it in System Settings, so Lattice never changes login behaviour unless asked to.
    static func apply(_ desired: Bool?) {
        guard let desired else { return }
        let service = SMAppService.mainApp
        do {
            if desired {
                if service.status != .enabled {
                    try service.register()
                    Log.log("login item: registered")
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
                Log.log("login item: unregistered")
            }
        } catch {
            Log.log("login item: could not set startAtLogin=\(desired): \(error.localizedDescription)")
        }
        Log.log("login item: startAtLogin=\(desired) status=\(statusDescription)")
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "enabled"
        case .notRegistered: return "notRegistered"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
