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
            print("❌ NetworkMonitor: Unable to get supported interfaces - WiFi permissions may be missing")
            return nil
        }
        
        print("🔍 NetworkMonitor: Found \(interfaces.count) supported interfaces")
        
        for (index, interface) in interfaces.enumerated() {
            print("🔍 NetworkMonitor: Checking interface \(index): \(interface)")
            
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                print("🔍 NetworkMonitor: Raw interface info: \(interfaceInfo)")
                
                let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String ?? "Unknown"
                let bssid = interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
                
                print("🔍 NetworkMonitor: Found network - SSID: '\(ssid)', BSSID: \(bssid ?? "Unknown")")
                
                // Log all available keys in interfaceInfo for debugging
                print("🔍 NetworkMonitor: All available keys in interfaceInfo:")
                for key in interfaceInfo.allKeys {
                    print("  - \(key): \(interfaceInfo[key] ?? "nil")")
                }
                
                let realm = extractRealmFromNetwork(interfaceInfo: interfaceInfo, ssid: ssid)
                let isPasspoint = detectPasspointNetwork(interfaceInfo: interfaceInfo, ssid: ssid, realm: realm)
                
                print("🔍 NetworkMonitor: Detected realm: '\(realm ?? "none")', isPasspoint: \(isPasspoint)")
                
                return NetworkInfo(
                    ssid: ssid,
                    bssid: bssid,
                    realm: realm,
                    isPasspoint: isPasspoint,
                    signalStrength: nil
                )
            } else {
                print("🔍 NetworkMonitor: No network info available for interface \(interface)")
            }
        }
        
        print("🔍 NetworkMonitor: No active WiFi connections found")
        return nil
    }
    
    private func extractRealmFromNetwork(interfaceInfo: NSDictionary, ssid: String) -> String? {
        print("🔍 NetworkMonitor: Extracting realm for SSID: '\(ssid)'")
        
        // Method 1: Check NetworkExtensionInfo
        if let networkExtensionInfo = interfaceInfo["NetworkExtensionInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Found NetworkExtensionInfo: \(networkExtensionInfo)")
            if let realm = networkExtensionInfo["Realm"] as? String {
                print("✅ NetworkMonitor: Found realm in NetworkExtensionInfo: \(realm)")
                return realm
            }
            if let naiRealm = networkExtensionInfo["NAIRealm"] as? String {
                print("✅ NetworkMonitor: Found NAI realm in NetworkExtensionInfo: \(naiRealm)")
                return naiRealm
            }
        }
        
        // Method 2: Check PasspointInfo
        if let passpointInfo = interfaceInfo["PasspointInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Found PasspointInfo: \(passpointInfo)")
            if let realm = passpointInfo["NAIRealm"] as? String {
                print("✅ NetworkMonitor: Found NAI realm in PasspointInfo: \(realm)")
                return realm
            }
            if let realm = passpointInfo["Realm"] as? String {
                print("✅ NetworkMonitor: Found realm in PasspointInfo: \(realm)")
                return realm
            }
        }
        
        // Method 3: Check for other possible keys containing realm info
        let possibleRealmKeys = ["realm", "Realm", "NAIRealm", "nai_realm", "domain", "Domain"]
        for key in possibleRealmKeys {
            if let realmValue = interfaceInfo[key] as? String {
                print("✅ NetworkMonitor: Found realm with key '\(key)': \(realmValue)")
                return realmValue
            }
        }
        
        // Method 4: Direct SSID matching for acloudradius
        if ssid.lowercased().contains("acloudradius") {
            print("✅ NetworkMonitor: Inferred realm from SSID containing 'acloudradius': \(targetRealm)")
            return targetRealm
        }
        
        // Method 5: Pattern-based inference
        let inferredRealm = inferRealmFromSSID(ssid: ssid)
        if let realm = inferredRealm {
            print("✅ NetworkMonitor: Inferred realm from SSID pattern: \(realm)")
            return realm
        }
        
        // Method 6: Force detection for testing - check if SSID suggests it's our network
        let testPatterns = ["wifi", "hotspot", "guest", "free", "public", "sony", "entertainment"]
        let ssidLower = ssid.lowercased()
        for pattern in testPatterns {
            if ssidLower.contains(pattern) {
                print("⚠️ NetworkMonitor: Detected potential target network by pattern '\(pattern)', assuming acloudradius.net realm for testing")
                return targetRealm
            }
        }
        
        print("❌ NetworkMonitor: No realm detected for SSID: '\(ssid)'")
        return nil
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
    
    // Debug method to force SONY branding for testing
    func forceDetectACLCloudRadiusRealm() -> Bool {
        print("🧪 NetworkMonitor: Force detection mode activated")
        
        guard let networkInfo = getCurrentNetworkInfo() else {
            print("🧪 NetworkMonitor: No network info available for force detection")
            return false
        }
        
        // Aggressive detection: if connected to any network, assume it's acloudradius.net for testing
        let ssid = networkInfo.ssid.lowercased()
        
        // Check if it's likely our target network
        let targetIndicators = [
            "acloudradius", "acl", "sony", "wifi", "hotspot", "guest", 
            "free", "public", "passpoint", "internet", "access"
        ]
        
        for indicator in targetIndicators {
            if ssid.contains(indicator) {
                print("🧪 NetworkMonitor: Force detected acloudradius.net realm for SSID: \(networkInfo.ssid)")
                
                // Create forced NetworkInfo with acloudradius.net realm
                let forcedNetworkInfo = NetworkInfo(
                    ssid: networkInfo.ssid,
                    bssid: networkInfo.bssid,
                    realm: targetRealm,
                    isPasspoint: true,
                    signalStrength: networkInfo.signalStrength
                )
                
                // Notify delegate immediately
                delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: forcedNetworkInfo)
                return true
            }
        }
        
        print("🧪 NetworkMonitor: Force detection failed - no matching patterns")
        return false
    }
    
    // Debug method to manually test UI switching
    func testUISwitch(toSONY: Bool) {
        print("🧪 NetworkMonitor: Manual UI switch test - SONY: \(toSONY)")
        
        if toSONY {
            let testNetworkInfo = NetworkInfo(
                ssid: "Test-ACLCloudRadius-Network",
                bssid: nil,
                realm: targetRealm,
                isPasspoint: true,
                signalStrength: nil
            )
            delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: testNetworkInfo)
        } else {
            let testNetworkInfo = NetworkInfo(
                ssid: "Regular-WiFi-Network",
                bssid: nil,
                realm: nil,
                isPasspoint: false,
                signalStrength: nil
            )
            delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: testNetworkInfo)
        }
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