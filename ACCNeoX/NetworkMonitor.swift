import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import CoreLocation

protocol NetworkMonitorDelegate: AnyObject {
    func networkStatusChanged(isPasspointConnected: Bool, networkInfo: NetworkInfo?)
}

struct NetworkInfo {
    let ssid: String
    let bssid: String?
    let realm: String?
    let isPasspoint: Bool
    let signalStrength: Int?
    
    var isACLCloudRadiusRealm: Bool {
        return realm?.lowercased().contains("acloudradius.net") == true
    }
}

class NetworkMonitor: NSObject {
    static let shared = NetworkMonitor()
    
    weak var delegate: NetworkMonitorDelegate?
    
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var locationManager: CLLocationManager?
    private let targetRealm = "acloudradius.net"
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("🔍 NetworkMonitor: Starting network monitoring...")
        isMonitoring = true
        
        requestLocationPermissionIfNeeded()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkCurrentNetwork()
        }
        
        checkCurrentNetwork()
    }
    
    func stopMonitoring() {
        print("🔍 NetworkMonitor: Stopping network monitoring...")
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func requestLocationPermissionIfNeeded() {
        guard let locationManager = locationManager else { return }
        
        let status = locationManager.authorizationStatus
        print("🔍 NetworkMonitor: Location permission status: \(status.rawValue)")
        
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            print("⚠️ NetworkMonitor: Location permission denied - WiFi detection will be limited")
        }
    }
    
    private func checkCurrentNetwork() {
        let networkInfo = getCurrentNetworkInfo()
        
        if let info = networkInfo {
            print("🔍 NetworkMonitor: Current network - SSID: \(info.ssid), Realm: \(info.realm ?? "unknown"), Passpoint: \(info.isPasspoint)")
            
            if info.isACLCloudRadiusRealm {
                print("✅ NetworkMonitor: Connected to acloudradius.net realm!")
                delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: info)
            } else if info.isPasspoint {
                print("🔍 NetworkMonitor: Connected to passpoint network but not acloudradius.net realm")
                delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: info)
            } else {
                print("🔍 NetworkMonitor: Connected to regular WiFi network")
                delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: info)
            }
        } else {
            print("🔍 NetworkMonitor: No WiFi network detected")
            delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: nil)
        }
    }
    
    private func getCurrentNetworkInfo() -> NetworkInfo? {
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else {
            print("🔍 NetworkMonitor: Unable to get supported interfaces")
            return nil
        }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String ?? "Unknown"
                let bssid = interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
                
                print("🔍 NetworkMonitor: Found network interface - SSID: \(ssid)")
                
                let realm = extractRealmFromNetwork(interfaceInfo: interfaceInfo, ssid: ssid)
                let isPasspoint = detectPasspointNetwork(interfaceInfo: interfaceInfo, ssid: ssid, realm: realm)
                
                return NetworkInfo(
                    ssid: ssid,
                    bssid: bssid,
                    realm: realm,
                    isPasspoint: isPasspoint,
                    signalStrength: nil
                )
            }
        }
        
        return nil
    }
    
    private func extractRealmFromNetwork(interfaceInfo: NSDictionary, ssid: String) -> String? {
        if let networkExtensionInfo = interfaceInfo["NetworkExtensionInfo"] as? [String: Any] {
            if let realm = networkExtensionInfo["Realm"] as? String {
                print("🔍 NetworkMonitor: Found realm in NetworkExtensionInfo: \(realm)")
                return realm
            }
        }
        
        if let passpointInfo = interfaceInfo["PasspointInfo"] as? [String: Any] {
            if let realm = passpointInfo["NAIRealm"] as? String {
                print("🔍 NetworkMonitor: Found NAI realm in PasspointInfo: \(realm)")
                return realm
            }
        }
        
        if ssid.lowercased().contains("acloudradius") {
            print("🔍 NetworkMonitor: Inferred realm from SSID: \(targetRealm)")
            return targetRealm
        }
        
        let inferredRealm = inferRealmFromSSID(ssid: ssid)
        if let realm = inferredRealm {
            print("🔍 NetworkMonitor: Inferred realm from SSID pattern: \(realm)")
        }
        
        return inferredRealm
    }
    
    private func detectPasspointNetwork(interfaceInfo: NSDictionary, ssid: String, realm: String?) -> Bool {
        if let _ = interfaceInfo["PasspointInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Detected Passpoint network via PasspointInfo")
            return true
        }
        
        if let _ = interfaceInfo["NetworkExtensionInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Detected possible Passpoint network via NetworkExtensionInfo")
            return true
        }
        
        if let realm = realm, realm.contains(".") {
            print("🔍 NetworkMonitor: Detected Passpoint network via realm presence: \(realm)")
            return true
        }
        
        let passpointIndicators = [
            "passpoint", "hotspot", "guest", "wifi", "internet", "access",
            "acloudradius", "sony", "entertainment"
        ]
        
        let ssidLower = ssid.lowercased()
        for indicator in passpointIndicators {
            if ssidLower.contains(indicator) {
                print("🔍 NetworkMonitor: Detected possible Passpoint network via SSID pattern: \(ssid)")
                return true
            }
        }
        
        return false
    }
    
    private func inferRealmFromSSID(ssid: String) -> String? {
        let ssidLower = ssid.lowercased()
        
        if ssidLower.contains("acloudradius") || ssidLower.contains("acl") {
            return targetRealm
        }
        
        if ssidLower.contains("sony") {
            return targetRealm
        }
        
        if ssidLower.contains("hotspot") || ssidLower.contains("guest") {
            if ssidLower.contains("sony") || ssidLower.contains("entertainment") {
                return targetRealm
            }
        }
        
        return nil
    }
    
    func getCurrentNetworkRealm() -> String? {
        return getCurrentNetworkInfo()?.realm
    }
    
    func isConnectedToACLCloudRadiusRealm() -> Bool {
        guard let networkInfo = getCurrentNetworkInfo() else { return false }
        return networkInfo.isACLCloudRadiusRealm
    }
    
    deinit {
        stopMonitoring()
    }
}

extension NetworkMonitor: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔍 NetworkMonitor: Location authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ NetworkMonitor: Location permission granted - enhanced WiFi detection available")
        case .denied, .restricted:
            print("⚠️ NetworkMonitor: Location permission denied - WiFi detection will be limited")
        case .notDetermined:
            print("🔍 NetworkMonitor: Location permission not determined")
        @unknown default:
            print("🔍 NetworkMonitor: Unknown location permission status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ NetworkMonitor: Location manager failed with error: \(error.localizedDescription)")
    }
}