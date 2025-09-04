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
    private var isLockedToSONY: Bool = false // Track if SONY branding is locked due to acc-venue1
    private var accVenue1NetworkDetected: Bool = false // Track if acc-venue1 was ever detected
    
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
        
        // Start with frequent checks for fast detection, maintain higher frequency for acc-venue1 networks
        var checkInterval: TimeInterval = 1.0
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] timer in
            self?.checkCurrentNetwork()
            
            // Check if we're connected to acc-venue1 network to maintain frequent monitoring
            let hasACCVenue1Connection = self?.lastNetworkInfo?.hasACCVenue1 == true || 
                                       self?.lastNetworkInfo?.venueName?.lowercased().contains("acc-venue1") == true
            
            // After 30 seconds, reduce frequency but keep higher for acc-venue1 networks
            if timer.timeInterval == 1.0 && Date().timeIntervalSince(timer.fireDate.addingTimeInterval(-30)) > 0 {
                timer.invalidate()
                let newInterval: TimeInterval = hasACCVenue1Connection ? 2.0 : 3.0
                self?.monitoringTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
                    self?.checkCurrentNetwork()
                }
                print("🔍 NetworkMonitor: Adjusted monitoring frequency to \(newInterval) seconds (acc-venue1: \(hasACCVenue1Connection))")
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
        
        // ENHANCEMENT: Also scan for nearby networks with acc-venue1 even if not connected
        scanForNearbyAccVenue1Networks()
        
        if let info = networkInfo {
            // Check for acc-venue1 venue name immediately
            let hasACCVenue1 = info.hasACCVenue1
            let venueNameLower = info.venueName?.lowercased() ?? ""
            let hasACCVenueName = venueNameLower.contains("acc-venue1") || venueNameLower.contains("acc venue1")
            
            // CRITICAL: Also check if SSID itself is "acloudradius" - this should ALWAYS trigger SONY
            let ssidLower = info.ssid.lowercased()
            let isACLCloudRadiusSSID = ssidLower == "acloudradius" || ssidLower == "acloudradius.net"
            
            let isACCVenue1Network = hasACCVenue1 || hasACCVenueName || isACLCloudRadiusSSID
            
            print("🔍 NetworkMonitor: DETAILED acc-venue1 detection for SSID '\(info.ssid)':")
            print("  - Raw venue name: '\(info.venueName ?? "nil")'")
            print("  - Venue name lowercased: '\(venueNameLower)'")
            print("  - hasACCVenue1 (struct property): \(hasACCVenue1)")
            print("  - hasACCVenueName (string check): \(hasACCVenueName)")
            print("  - isACLCloudRadiusSSID (exact SSID): \(isACLCloudRadiusSSID)")
            print("  - FINAL isACCVenue1Network: \(isACCVenue1Network)")
            
            // PRIORITY 1: Check if connected to acc-venue1 and lock SONY branding immediately
            if isACCVenue1Network {
                print("🎯 CRITICAL: acc-venue1 network detected - FORCING SONY branding lock")
                print("  - Current SSID: \(info.ssid)")
                print("  - Venue name: \(info.venueName ?? "inferred")")
                print("  - hasACCVenue1: \(hasACCVenue1)")
                print("  - hasACCVenueName: \(hasACCVenueName)")
                
                if !isLockedToSONY {
                    print("🔒 NetworkMonitor: LOCKING to SONY branding due to acc-venue1 detection!")
                    isLockedToSONY = true
                    accVenue1NetworkDetected = true
                }
                
                // ALWAYS show SONY immediately when acc-venue1 is detected
                currentBrandingState = true
                lastNetworkInfo = info
                
                let enhancedInfo = NetworkInfo(
                    ssid: info.ssid,
                    bssid: info.bssid,
                    realm: info.realm ?? targetRealm,
                    isPasspoint: true,
                    signalStrength: info.signalStrength,
                    venueName: info.venueName ?? "acc-venue1"
                )
                
                print("🔒 LOCKED STATE: Forcing SONY branding for acc-venue1")
                delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: enhancedInfo)
                return  // EXIT IMMEDIATELY - do not process any other logic
            }
            
            // PRIORITY 2: If locked to SONY but no longer on acc-venue1, check if we should unlock
            if isLockedToSONY {
                print("🔒 NetworkMonitor: Currently locked to SONY but acc-venue1 not detected on current network")
                print("  - Current SSID: \(info.ssid)")
                print("  - Current venue: \(info.venueName ?? "none")")
                
                // IMPORTANT: Only unlock if we're connected to a completely different network
                // Stay locked if we're just switching between networks in the same location
                let isDifferentLocation = !ssidLooksLikeACCLocation(info.ssid)
                
                if isDifferentLocation {
                    print("  - UNLOCKING from SONY branding - moved to different location")
                    isLockedToSONY = false
                    accVenue1NetworkDetected = false
                    print("🔓 NetworkMonitor: UNLOCKED from SONY branding")
                } else {
                    print("  - MAINTAINING SONY lock - still appears to be in ACC location")
                    
                    // Maintain SONY branding even if acc-venue1 not detected on current network
                    let persistentInfo = NetworkInfo(
                        ssid: info.ssid,
                        bssid: info.bssid,
                        realm: info.realm ?? targetRealm,
                        isPasspoint: true,
                        signalStrength: info.signalStrength,
                        venueName: "acc-venue1"
                    )
                    
                    delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: persistentInfo)
                    return // EXIT - maintain SONY branding
                }
                
                // Continue processing to determine correct branding for current network
            }
            
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
            
            // CRITICAL: Exact "acloudradius" SSID match should ALWAYS trigger SONY
            let isExactACLCloudRadiusSSID = ssidLower == "acloudradius" || ssidLower == "acloudradius.net"
            let hasACLCloudRadiusSSID = isExactACLCloudRadiusSSID ||
                                       ssidLower.contains("acloudradius") || 
                                       ssidLower.contains("test-acloudradius") ||
                                       ssidLower.contains("aclcloud") ||
                                       ssidLower.contains("cloudradius")
            
            print("🎯 CRITICAL SSID CHECK for '\(info.ssid)':")
            print("  - isExactACLCloudRadiusSSID: \(isExactACLCloudRadiusSSID)")
            print("  - hasACLCloudRadiusSSID: \(hasACLCloudRadiusSSID)")
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
            
            // Priority check: acc-venue1 detection is primary trigger
            if isACCVenue1Network {
                print("🎯 PRIMARY TRIGGER: acc-venue1 venue detected!")
                print("  - Venue name: \(info.venueName ?? "inferred")")
                print("  - hasACCVenue1: \(hasACCVenue1)")
                print("  - hasACCVenueName: \(hasACCVenueName)")
            }
            
            // Determine if this is an ACLCloudRadius network - be more inclusive for SSID matches
            let isACLCloudRadiusNetwork = hasACLCloudRadiusRealm || hasACLCloudRadiusSSID || hasACLCloudRadiusInRealm || 
                                        hasACLPattern || hasSONYPattern || hasPasspointACLPattern || isACCVenue1Network
            
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
                print("  - ACC-Venue1 check: \(isACCVenue1Network)")
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
            // No network detected - check if we should unlock from SONY branding
            if isLockedToSONY {
                print("🔒 NetworkMonitor: No network detected while locked to SONY")
                print("  - Checking if we should unlock from SONY branding...")
                print("  - Device is now disconnected from WiFi")
                print("  - Unlocking from SONY branding and switching to neoX")
                
                // Unlock from SONY branding when completely disconnected from WiFi
                isLockedToSONY = false
                accVenue1NetworkDetected = false
                print("🔓 NetworkMonitor: UNLOCKED from SONY branding - device disconnected from WiFi")
            }
            
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
        print("🔍 NetworkMonitor: Extracting REAL venue name from ANQP for SSID: '\(ssid)'")
        
        // Method 1: Check PasspointInfo for ANQP venue information (PRIMARY SOURCE)
        if let passpointInfo = interfaceInfo["PasspointInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Found PasspointInfo - checking for ANQP venue data: \(passpointInfo)")
            
            // Check all possible ANQP venue keys
            let anqpVenueKeys = ["VenueName", "venue_name", "VenueInfo", "venue_info", 
                               "ANQPVenueName", "anqp_venue_name", "Venue", "venue",
                               "VenueGroup", "venue_group", "VenueType", "venue_type",
                               "ANQPVenueInfo", "anqp_venue_info"]
            
            for key in anqpVenueKeys {
                if let venueValue = passpointInfo[key] as? String {
                    print("✅ NetworkMonitor: Found ANQP venue name with key '\(key)': \(venueValue)")
                    return venueValue
                }
            }
            
            // Check for nested ANQP data structures
            for (key, value) in passpointInfo {
                if key.lowercased().contains("anqp") || key.lowercased().contains("venue") {
                    print("🔍 NetworkMonitor: Checking ANQP/venue key '\(key)': \(value)")
                    
                    if let stringValue = value as? String {
                        print("✅ NetworkMonitor: Found venue string in '\(key)': \(stringValue)")
                        return stringValue
                    } else if let dictValue = value as? [String: Any] {
                        // Check nested dictionaries for venue information
                        for (nestedKey, nestedValue) in dictValue {
                            if let nestedString = nestedValue as? String,
                               nestedKey.lowercased().contains("venue") {
                                print("✅ NetworkMonitor: Found venue in nested key '\(nestedKey)': \(nestedString)")
                                return nestedString
                            }
                        }
                    }
                }
            }
        }
        
        // Method 2: Check NetworkExtensionInfo for ANQP data
        if let networkExtensionInfo = interfaceInfo["NetworkExtensionInfo"] as? [String: Any] {
            print("🔍 NetworkMonitor: Checking NetworkExtensionInfo for ANQP venue: \(networkExtensionInfo)")
            
            // Look for ANQP venue information in NetworkExtensionInfo
            let anqpKeys = ["VenueName", "ANQPVenueName", "VenueInfo", "ANQPVenueInfo", "Venue"]
            for key in anqpKeys {
                if let venueValue = networkExtensionInfo[key] as? String {
                    print("✅ NetworkMonitor: Found ANQP venue in NetworkExtensionInfo '\(key)': \(venueValue)")
                    return venueValue
                }
            }
        }
        
        // Method 3: Comprehensive search for ANY venue-related keys containing ANQP data
        print("🔍 NetworkMonitor: Performing comprehensive ANQP venue search...")
        for key in interfaceInfo.allKeys {
            let keyString = String(describing: key).lowercased()
            
            // Look for keys that might contain ANQP venue information
            if keyString.contains("venue") || keyString.contains("anqp") {
                print("🔍 NetworkMonitor: Found potential ANQP venue key '\(key)': \(interfaceInfo[key] ?? "nil")")
                
                if let stringValue = interfaceInfo[key] as? String {
                    print("✅ NetworkMonitor: Found ANQP venue string value: \(stringValue)")
                    return stringValue
                } else if let dictValue = interfaceInfo[key] as? [String: Any] {
                    // Search within nested dictionaries for venue information
                    for (nestedKey, nestedValue) in dictValue {
                        if let nestedString = nestedValue as? String {
                            print("✅ NetworkMonitor: Found venue in nested ANQP data '\(nestedKey)': \(nestedString)")
                            return nestedString
                        }
                    }
                }
            }
        }
        
        // Method 4: CRITICAL FALLBACK - If no ANQP venue detected but SSID is "acloudradius"
        // treat it as having acc-venue1 venue name
        let ssidLower = ssid.lowercased()
        if ssidLower == "acloudradius" || ssidLower == "acloudradius.net" {
            print("🎯 CRITICAL FALLBACK: SSID '\(ssid)' is acloudradius - assuming venue=acc-venue1")
            print("🔍 This covers cases where ANQP venue data isn't exposed by iOS")
            return "acc-venue1"
        }
        
        print("❌ NetworkMonitor: No ANQP venue name detected from access point for SSID: '\(ssid)'")
        print("🔍 NetworkMonitor: This means access point is not broadcasting venue information via ANQP")
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
    
    // Check if currently locked to SONY branding (for ViewController)
    func isCurrentlyLockedToSONY() -> Bool {
        return isLockedToSONY
    }
    
    // Scan for nearby WiFi networks that might have acc-venue1 venue name
    private func scanForNearbyAccVenue1Networks() {
        print("🔍 NetworkMonitor: Scanning for nearby acc-venue1 networks...")
        
        // This method attempts to detect acc-venue1 venue names from nearby access points
        // even if not currently connected to them
        
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else {
            print("🔍 NetworkMonitor: No WiFi interfaces available for nearby scan")
            return
        }
        
        for interface in interfaces {
            if let interfaceName = interface as? String {
                // Try to get additional network information that might include nearby networks
                print("🔍 NetworkMonitor: Checking interface \(interfaceName) for nearby networks...")
                
                // Note: iOS severely restricts access to nearby WiFi networks for security
                // We rely on the connected network's ANQP data primarily
                // But we can check for cached Passpoint configurations
                
                if let networkList = CNCopyCurrentNetworkInfo(interfaceName as CFString) as NSDictionary? {
                    // Check if we have any Passpoint or cached network information
                    if let passpointInfo = networkList["PasspointInfo"] as? [String: Any] {
                        print("🔍 NetworkMonitor: Found PasspointInfo in nearby scan: \(passpointInfo)")
                        
                        // Look for any acc-venue1 references in Passpoint data
                        for (key, value) in passpointInfo {
                            if let stringValue = value as? String, 
                               stringValue.lowercased().contains("acc-venue1") {
                                print("🎯 NetworkMonitor: Found acc-venue1 in nearby Passpoint data!")
                                print("  - Key: \(key), Value: \(stringValue)")
                                
                                // Trigger SONY branding lock for nearby acc-venue1
                                if !isLockedToSONY {
                                    print("🔒 NetworkMonitor: LOCKING to SONY due to nearby acc-venue1 detection!")
                                    isLockedToSONY = true
                                    accVenue1NetworkDetected = true
                                    
                                    // Create synthetic network info for nearby acc-venue1
                                    let nearbyNetworkInfo = NetworkInfo(
                                        ssid: "Nearby-ACC-Venue1-Network",
                                        bssid: nil,
                                        realm: targetRealm,
                                        isPasspoint: true,
                                        signalStrength: nil,
                                        venueName: "acc-venue1"
                                    )
                                    
                                    delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: nearbyNetworkInfo)
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        
        print("🔍 NetworkMonitor: No nearby acc-venue1 networks detected in this scan")
    }
    
    // Helper method to determine if SSID suggests we're still in ACC location
    private func ssidLooksLikeACCLocation(_ ssid: String) -> Bool {
        let ssidLower = ssid.lowercased()
        
        // Check for common ACC/SONY/venue-related SSID patterns
        let accLocationPatterns = [
            "acc", "sony", "venue", "acloudradius", "guest", "wifi",
            "passpoint", "hotspot", "free", "public", "corp", "corporate"
        ]
        
        for pattern in accLocationPatterns {
            if ssidLower.contains(pattern) {
                print("🔍 NetworkMonitor: SSID '\(ssid)' contains ACC location pattern '\(pattern)'")
                return true
            }
        }
        
        print("🔍 NetworkMonitor: SSID '\(ssid)' does not match ACC location patterns")
        return false
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
    
    // Test specifically for acc-venue1 venue name detection (PRIMARY REQUIREMENT)
    func testACCVenue1Detection(ssid: String = "WiFi-Network-With-Venue") {
        print("🧪 NetworkMonitor: Testing acc-venue1 venue name detection")
        print("🧪 Expected message: 'Device connected to venue=acc-venue1'")
        
        // Force lock to SONY immediately
        isLockedToSONY = true
        accVenue1NetworkDetected = true
        currentBrandingState = true
        
        let testNetworkInfo = NetworkInfo(
            ssid: ssid,
            bssid: nil,
            realm: targetRealm,
            isPasspoint: true,
            signalStrength: nil,
            venueName: "acc-venue1"
        )
        
        lastNetworkInfo = testNetworkInfo
        print("🧪 This should trigger SONY branding via venue name acc-venue1")
        print("🧪 SSID: \(ssid), Venue: acc-venue1")
        print("🔒 FORCING SONY LOCK STATE for testing")
        delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: testNetworkInfo)
    }
    
    // Force permanent SONY branding lock (for troubleshooting)
    func forcePermanentSONYLock() {
        print("🔒 EMERGENCY: Forcing permanent SONY branding lock!")
        isLockedToSONY = true
        accVenue1NetworkDetected = true
        currentBrandingState = true
        
        let forcedInfo = NetworkInfo(
            ssid: "FORCED-ACC-VENUE1",
            bssid: nil,
            realm: targetRealm,
            isPasspoint: true,
            signalStrength: nil,
            venueName: "acc-venue1"
        )
        
        lastNetworkInfo = forcedInfo
        delegate?.networkStatusChanged(isPasspointConnected: true, networkInfo: forcedInfo)
        print("🔒 PERMANENT SONY LOCK ACTIVATED")
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