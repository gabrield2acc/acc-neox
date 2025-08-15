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
    let venueName: String? // Passpoint venue name attribute
    
    var isACLCloudRadiusRealm: Bool {
        return realm?.lowercased().contains("acloudradius.net") == true
    }
    
    var hasACCVenue1: Bool {
        // Check if venue name contains acc-venue1 (Passpoint venue attribute)
        return venueName?.lowercased().contains("acc-venue1") == true
    }
}

class NetworkMonitor: NSObject {
    static let shared = NetworkMonitor()
    
    weak var delegate: NetworkMonitorDelegate?
    
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var locationManager: CLLocationManager?
    private let targetRealm = "acloudradius.net"
    private var lastDetectedACLNetwork: String? // Track last ACL network to maintain state
    private var consecutiveACLDetections = 0 // Count consecutive detections for stability
    private var currentBrandingState: Bool = false // Track current branding (true = SONY, false = neoX)
    private var lastNetworkInfo: NetworkInfo? // Cache last network info to avoid unnecessary updates
    
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
        
        // Start with more frequent checks for faster detection, then reduce frequency for stability
        var checkInterval: TimeInterval = 1.0
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] timer in
            self?.checkCurrentNetwork()
            
            // After 30 seconds, reduce frequency to preserve battery and improve stability  
            if timer.timeInterval == 1.0 && Date().timeIntervalSince(timer.fireDate.addingTimeInterval(-30)) > 0 {
                timer.invalidate()
                self?.monitoringTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    self?.checkCurrentNetwork()
                }
                print("🔍 NetworkMonitor: Reduced monitoring frequency to 3 seconds for stability")
            }
        }
        
        // Force immediate check when monitoring starts
        print("🔍 NetworkMonitor: Performing immediate network check on startup...")
        checkCurrentNetwork()
    }
    
    func forceNetworkCheck() {
        print("🔍 NetworkMonitor: Force network check requested")
        // Reset state to ensure fresh detection
        currentBrandingState = false
        lastNetworkInfo = nil
        print("🔍 NetworkMonitor: Reset branding state for fresh detection")
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
            // Check if network info has actually changed to avoid unnecessary UI updates
            let networkChanged = hasNetworkChanged(current: info, previous: lastNetworkInfo)
            
            if !networkChanged && currentBrandingState {
                // If connected to ACL network and nothing changed, maintain SONY branding
                print("🔍 NetworkMonitor: Network unchanged, maintaining current SONY branding")
                print("  - Current SSID: \(info.ssid)")
                print("  - Current venue: \(info.venueName ?? "none")")
                print("  - Branding state: \(currentBrandingState ? "SONY" : "neoX")")
                return
            }
            
            print("🔍 NetworkMonitor: Current network - SSID: \(info.ssid), Realm: \(info.realm ?? "unknown"), Passpoint: \(info.isPasspoint), Venue: \(info.venueName ?? "unknown")")
            print("🔍 NetworkMonitor: Previous branding state: \(currentBrandingState ? "SONY" : "neoX")")
            print("🔍 NetworkMonitor: Network changed: \(networkChanged)")
            
            // Enhanced ACLCloudRadius detection - more aggressive SSID-based detection
            let ssidLower = info.ssid.lowercased()
            let realmLower = info.realm?.lowercased() ?? ""
            
            // Primary detection methods - SSID is most reliable
            let hasACLCloudRadiusRealm = info.isACLCloudRadiusRealm
            let hasACLCloudRadiusSSID = ssidLower.contains("acloudradius") || 
                                       ssidLower.contains("test-acloudradius") ||
                                       ssidLower.contains("aclcloud") ||
                                       ssidLower.contains("cloudradius")
            let hasACLCloudRadiusInRealm = realmLower.contains("acloudradius") || realmLower.contains("cloudradius")
            
            // Enhanced SSID pattern matching for various ACLCloudRadius network names
            let hasACLPattern = ssidLower.contains("acl") && (ssidLower.contains("cloud") || 
                               ssidLower.contains("radius") || ssidLower.contains("wifi") ||
                               ssidLower.contains("hotspot") || ssidLower.contains("guest"))
            
            // SONY branded networks that should show SONY branding
            let hasSONYPattern = ssidLower.contains("sony") || 
                               (ssidLower.contains("entertainment") && (info.isPasspoint || realmLower.contains("acloudradius")))
            
            // Passpoint networks with ACLCloudRadius indicators
            let hasPasspointACLPattern = info.isPasspoint && (realmLower.contains("acloudradius") || 
                                        realmLower.contains("sony") || hasACLPattern)
            
            // Check for acc-venue1 venue name attribute (NEW REQUIREMENT)
            let hasACCVenue1 = info.hasACCVenue1
            let venueNameLower = info.venueName?.lowercased() ?? ""
            let hasACCVenueName = venueNameLower.contains("acc-venue1") || venueNameLower.contains("acc venue1")
            
            // Determine if this is an ACLCloudRadius network - be more inclusive for SSID matches
            let isACLCloudRadiusNetwork = hasACLCloudRadiusRealm || hasACLCloudRadiusSSID || hasACLCloudRadiusInRealm || 
                                        hasACLPattern || hasSONYPattern || hasPasspointACLPattern ||
                                        hasACCVenue1 || hasACCVenueName
            
            if isACLCloudRadiusNetwork {
                // Track consecutive ACL detections for stability
                if lastDetectedACLNetwork == info.ssid {
                    consecutiveACLDetections += 1
                } else {
                    consecutiveACLDetections = 1
                    lastDetectedACLNetwork = info.ssid
                }
                
                print("✅ NetworkMonitor: DETECTED ACLCloudRadius network! (consecutive: \(consecutiveACLDetections))")
                print("  - SSID: \(info.ssid)")
                print("  - Realm: \(info.realm ?? "none")")
                print("  - Realm check: \(hasACLCloudRadiusRealm)")
                print("  - SSID check: \(hasACLCloudRadiusSSID)")
                print("  - Realm contains ACL: \(hasACLCloudRadiusInRealm)")
                print("  - ACL pattern: \(hasACLPattern)")
                print("  - SONY pattern: \(hasSONYPattern)")
                print("  - Passpoint ACL pattern: \(hasPasspointACLPattern)")
                print("  - ACC-Venue1 check: \(hasACCVenue1)")
                print("  - ACC venue name: \(hasACCVenueName)")
                print("  - Venue name: \(info.venueName ?? "none")")
                print("  - 🎯 TRIGGERING SONY BRANDING 🎯")
                
                // Create enhanced NetworkInfo with forced ACLCloudRadius realm
                let enhancedInfo = NetworkInfo(
                    ssid: info.ssid,
                    bssid: info.bssid,
                    realm: info.realm ?? targetRealm, // Use detected realm or force targetRealm
                    isPasspoint: true, // Force passpoint for ACLCloudRadius networks
                    signalStrength: info.signalStrength,
                    venueName: info.venueName // Preserve venue name
                )
                
                // Update branding state and cache
                currentBrandingState = true // SONY branding
                lastNetworkInfo = enhancedInfo
                
                // Always trigger SONY branding for ACL networks - be aggressive
                delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: enhancedInfo)
            } else {
                // Reset ACL detection tracking
                lastDetectedACLNetwork = nil
                consecutiveACLDetections = 0
                
                // Update branding state and cache
                currentBrandingState = false // neoX branding
                lastNetworkInfo = info
                
                print("🔍 NetworkMonitor: NOT an ACLCloudRadius network")
                print("  - SSID: \(info.ssid)")
                print("  - 📱 TRIGGERING neoX BRANDING 📱")
                delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: info)
            }
        } else {
            // Update branding state and cache
            currentBrandingState = false // neoX branding
            lastNetworkInfo = nil
            
            print("🔍 NetworkMonitor: No WiFi network detected - showing neoX branding")
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
                let venueName = extractVenueNameFromNetwork(interfaceInfo: interfaceInfo, ssid: ssid)
                
                print("🔍 NetworkMonitor: Detected realm: '\(realm ?? "none")', isPasspoint: \(isPasspoint), venue: '\(venueName ?? "none")'")
                
                return NetworkInfo(
                    ssid: ssid,
                    bssid: bssid,
                    realm: realm,
                    isPasspoint: isPasspoint,
                    signalStrength: nil,
                    venueName: venueName
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
        
        // Method 4: Direct SSID matching for acloudradius (most important check)
        let ssidLower = ssid.lowercased()
        if ssidLower.contains("acloudradius") || ssidLower.contains("acl") {
            print("✅ NetworkMonitor: Inferred realm from SSID containing ACLCloudRadius: \(targetRealm)")
            return targetRealm
        }
        
        // Method 5: Pattern-based inference
        let inferredRealm = inferRealmFromSSID(ssid: ssid)
        if let realm = inferredRealm {
            print("✅ NetworkMonitor: Inferred realm from SSID pattern: \(realm)")
            return realm
        }
        
        // Method 6: Aggressive detection for common WiFi network patterns
        let testPatterns = ["test-acloudradius", "acloudradius", "acl", "wifi", "hotspot", "guest", "free", "public", "sony", "entertainment"]
        for pattern in testPatterns {
            if ssidLower.contains(pattern) {
                print("⚠️ NetworkMonitor: Detected potential target network by pattern '\(pattern)', assuming acloudradius.net realm")
                return targetRealm
            }
        }
        
        print("❌ NetworkMonitor: No realm detected for SSID: '\(ssid)'")
        return nil
    }
    
    private func extractVenueNameFromNetwork(interfaceInfo: NSDictionary, ssid: String) -> String? {
        print("🔍 NetworkMonitor: Extracting venue name for SSID: '\(ssid)'")
        
        // Method 1: Check NetworkExtensionInfo for venue information
        if let networkExtensionInfo = interfaceInfo["NetworkExtensionInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Checking NetworkExtensionInfo for venue name: \(networkExtensionInfo)")
            if let venueName = networkExtensionInfo["VenueName"] as? String {
                print("✅ NetworkMonitor: Found venue name in NetworkExtensionInfo: \(venueName)")
                return venueName
            }
            if let venueInfo = networkExtensionInfo["VenueInfo"] as? String {
                print("✅ NetworkMonitor: Found venue info in NetworkExtensionInfo: \(venueInfo)")
                return venueInfo
            }
            // Check nested objects for venue information
            for (key, value) in networkExtensionInfo {
                if let stringValue = value as? String, 
                   (key.lowercased().contains("venue") || stringValue.lowercased().contains("acc-venue1")) {
                    print("✅ NetworkMonitor: Found venue-related info in '\(key)': \(stringValue)")
                    return stringValue
                }
            }
        }
        
        // Method 2: Check PasspointInfo for venue information
        if let passpointInfo = interfaceInfo["PasspointInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Checking PasspointInfo for venue name: \(passpointInfo)")
            if let venueName = passpointInfo["VenueName"] as? String {
                print("✅ NetworkMonitor: Found venue name in PasspointInfo: \(venueName)")
                return venueName
            }
            if let venueGroup = passpointInfo["VenueGroup"] as? String {
                print("✅ NetworkMonitor: Found venue group in PasspointInfo: \(venueGroup)")
                return venueGroup
            }
            if let venueType = passpointInfo["VenueType"] as? String {
                print("✅ NetworkMonitor: Found venue type in PasspointInfo: \(venueType)")
                return venueType
            }
        }
        
        // Method 3: Check for other possible keys containing venue info
        let possibleVenueKeys = ["venue", "Venue", "VenueName", "venue_name", "VenueInfo", "venue_info", 
                                "VenueGroup", "venue_group", "VenueType", "venue_type"]
        for key in possibleVenueKeys {
            if let venueValue = interfaceInfo[key] as? String {
                print("✅ NetworkMonitor: Found venue with key '\(key)': \(venueValue)")
                return venueValue
            }
        }
        
        // Method 4: Check for acc-venue1 pattern in any string values (comprehensive search)
        for key in interfaceInfo.allKeys {
            if let stringValue = interfaceInfo[key] as? String {
                let lowerValue = stringValue.lowercased()
                if lowerValue.contains("acc-venue1") || lowerValue.contains("acc venue1") {
                    print("✅ NetworkMonitor: Found acc-venue1 pattern in key '\(key)': \(stringValue)")
                    return stringValue
                }
            }
        }
        
        // Method 5: SSID-based venue inference (since iOS may not expose venue name directly)
        let ssidLower = ssid.lowercased()
        if ssidLower.contains("acc-venue") || ssidLower.contains("venue1") || 
           ssidLower.contains("acc venue") || ssidLower.contains("accvenue") {
            print("✅ NetworkMonitor: Inferred acc-venue1 from SSID pattern: \(ssid)")
            return "acc-venue1"
        }
        
        // Method 6: Check if connected to known ACC networks and assume acc-venue1
        if ssidLower.contains("acloudradius") || ssidLower.contains("test-acloudradius") ||
           ssidLower.contains("acl") && (ssidLower.contains("cloud") || ssidLower.contains("radius")) {
            print("✅ NetworkMonitor: Inferring acc-venue1 for known ACLCloudRadius network: \(ssid)")
            return "acc-venue1"
        }
        
        print("❌ NetworkMonitor: No venue name detected for SSID: '\(ssid)'")
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
        
        // Primary patterns that should definitely match acloudradius.net
        let primaryPatterns = ["acloudradius", "acl", "test-acloudradius"]
        for pattern in primaryPatterns {
            if ssidLower.contains(pattern) {
                print("✅ NetworkMonitor: Primary pattern match '\(pattern)' in SSID: \(ssid)")
                return targetRealm
            }
        }
        
        // Secondary patterns (SONY branding networks)
        if ssidLower.contains("sony") {
            print("✅ NetworkMonitor: SONY pattern match in SSID: \(ssid)")
            return targetRealm
        }
        
        // Tertiary patterns (generic hotspot networks that might be ours)
        if ssidLower.contains("hotspot") || ssidLower.contains("guest") {
            if ssidLower.contains("sony") || ssidLower.contains("entertainment") {
                print("✅ NetworkMonitor: Hotspot+SONY pattern match in SSID: \(ssid)")
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
            "acloudradius", "acl", "test-acloudradius", "sony", "wifi", "hotspot", "guest", 
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
                    signalStrength: networkInfo.signalStrength,
                    venueName: networkInfo.venueName
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
                signalStrength: nil,
                venueName: nil
            )
            delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: testNetworkInfo)
        } else {
            let testNetworkInfo = NetworkInfo(
                ssid: "Regular-WiFi-Network",
                bssid: nil,
                realm: nil,
                isPasspoint: false,
                signalStrength: nil,
                venueName: nil
            )
            delegate?.networkStatusChanged(isPasspointConnected: false, networkInfo: testNetworkInfo)
        }
    }
    
    // Test method to simulate various network types for debugging
    func simulateNetworkConnection(ssid: String, realm: String? = nil, isPasspoint: Bool = false, venueName: String? = nil) {
        print("🧪 NetworkMonitor: Simulating network connection")
        print("  - SSID: \(ssid)")
        print("  - Realm: \(realm ?? "none")")
        print("  - Passpoint: \(isPasspoint)")
        print("  - Venue: \(venueName ?? "none")")
        
        let testNetworkInfo = NetworkInfo(
            ssid: ssid,
            bssid: nil,
            realm: realm,
            isPasspoint: isPasspoint,
            signalStrength: nil,
            venueName: venueName
        )
        
        // Use the same logic as checkCurrentNetwork to determine if this should show SONY or neoX
        let ssidLower = ssid.lowercased()
        let realmLower = realm?.lowercased() ?? ""
        
        let hasACLCloudRadiusRealm = realm?.lowercased().contains("acloudradius.net") == true
        let hasACLCloudRadiusSSID = ssidLower.contains("acloudradius") || ssidLower.contains("test-acloudradius")
        let hasACLCloudRadiusInRealm = realmLower.contains("acloudradius")
        let hasSONYPattern = ssidLower.contains("sony") && (isPasspoint || realmLower.contains("acloudradius"))
        let hasSpecificACLPattern = (ssidLower.contains("acl") || ssidLower.contains("passpoint")) && 
                                   (realmLower.contains("acloudradius") || realmLower.contains("sony"))
        
        let isACLCloudRadiusNetwork = hasACLCloudRadiusRealm || hasACLCloudRadiusSSID || hasACLCloudRadiusInRealm || 
                                    hasSONYPattern || hasSpecificACLPattern
        
        print("🧪 Simulation result: \(isACLCloudRadiusNetwork ? "SONY" : "neoX") branding")
        delegate?.networkStatusChanged(isPasspointConnected: isACLCloudRadiusNetwork, networkInfo: testNetworkInfo)
    }
    
    // Test specifically for user's ACLCloudRadius SSID
    func testACLCloudRadiusSSID(ssid: String = "acloudradius.net") {
        print("🧪 NetworkMonitor: Testing specific ACLCloudRadius SSID: \(ssid)")
        
        let testNetworkInfo = NetworkInfo(
            ssid: ssid,
            bssid: nil,
            realm: "acloudradius.net",
            isPasspoint: true,
            signalStrength: nil,
            venueName: nil
        )
        
        print("🧪 This should DEFINITELY trigger SONY branding")
        delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: testNetworkInfo)
    }
    
    // Test specifically for acc-venue1 venue name detection (NEW REQUIREMENT)
    func testACCVenue1Detection(ssid: String = "Test-Venue-Network") {
        print("🧪 NetworkMonitor: Testing acc-venue1 venue name detection")
        
        let testNetworkInfo = NetworkInfo(
            ssid: ssid,
            bssid: nil,
            realm: nil,
            isPasspoint: true,
            signalStrength: nil,
            venueName: "acc-venue1"
        )
        
        print("🧪 This should trigger SONY branding via venue name acc-venue1")
        delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: testNetworkInfo)
    }
    
    // Debug method to force immediate network detection with state reset
    func debugForceNetworkDetection() {
        print("🧪 NetworkMonitor: DEBUG - Force immediate network detection with full state reset")
        
        // Stop and restart monitoring
        stopMonitoring()
        
        // Reset all state
        currentBrandingState = false
        lastNetworkInfo = nil
        lastDetectedACLNetwork = nil
        consecutiveACLDetections = 0
        
        // Restart monitoring
        startMonitoring()
        
        print("🧪 NetworkMonitor: Full monitoring restart completed")
    }
    
    // Helper function to check if network info has changed significantly
    private func hasNetworkChanged(current: NetworkInfo, previous: NetworkInfo?) -> Bool {
        guard let previous = previous else {
            return true // No previous info, consider it changed
        }
        
        // Compare key network attributes
        let ssidChanged = current.ssid != previous.ssid
        let realmChanged = current.realm != previous.realm
        let passpointChanged = current.isPasspoint != previous.isPasspoint
        
        let hasChanged = ssidChanged || realmChanged || passpointChanged
        
        if hasChanged {
            print("🔍 NetworkMonitor: Network change detected:")
            print("  - SSID: \(previous.ssid) → \(current.ssid) (changed: \(ssidChanged))")
            print("  - Realm: \(previous.realm ?? "none") → \(current.realm ?? "none") (changed: \(realmChanged))")
            print("  - Passpoint: \(previous.isPasspoint) → \(current.isPasspoint) (changed: \(passpointChanged))")
        }
        
        return hasChanged
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