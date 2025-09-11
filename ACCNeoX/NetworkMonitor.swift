import Foundation
import SystemConfiguration.CaptiveNetwork
import SystemConfiguration
import Network

protocol NetworkMonitorDelegate: AnyObject {
    func wifiStatusChanged(isConnected: Bool, networkName: String?)
    func wifiCompanyDetected(isConnected: Bool, networkName: String?, companyInfo: SSIDAnalyzer.CompanyInfo?)
}

class NetworkMonitor: NSObject {
    static let shared = NetworkMonitor()
    
    weak var delegate: NetworkMonitorDelegate?
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
    
    private override init() {
        super.init()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("🔍 NetworkMonitor: Starting modern network detection...")
        isMonitoring = true
        
        // Use Network framework for modern, reliable network detection
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPathUpdate(path)
            }
        }
        pathMonitor?.start(queue: monitorQueue)
        
        // Also use timer as backup method
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkWiFiConnection()
        }
        
        // Immediate check
        checkWiFiConnection()
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        let isWiFi = path.usesInterfaceType(.wifi)
        let isCellular = path.usesInterfaceType(.cellular)
        
        print("🔍 NetworkMonitor: Network path update")
        print("  - Status: \(path.status)")
        print("  - Connected: \(isConnected)")
        print("  - WiFi Interface: \(isWiFi)")
        print("  - Cellular Interface: \(isCellular)")
        print("  - Available Interfaces: \(path.availableInterfaces.map { $0.name })")
        
        // Enhanced logic with company detection
        if isConnected && isWiFi {
            let networkName = getWiFiNetworkName() ?? "WiFi Network"
            print("✅ NetworkMonitor: WiFi detected - analyzing SSID for company info")
            
            // Analyze SSID for company information
            let companyInfo = SSIDAnalyzer.shared.analyzeSSID(networkName)
            
            // Call both delegates for backward compatibility and new functionality
            delegate?.wifiStatusChanged(isConnected: true, networkName: networkName)
            delegate?.wifiCompanyDetected(isConnected: true, networkName: networkName, companyInfo: companyInfo)
        } else {
            print("📱 NetworkMonitor: No WiFi or not connected - showing default branding")
            delegate?.wifiStatusChanged(isConnected: false, networkName: nil)
            delegate?.wifiCompanyDetected(isConnected: false, networkName: nil, companyInfo: nil)
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🔍 NetworkMonitor: Stopping network monitoring")
        isMonitoring = false
        
        // Stop path monitor
        pathMonitor?.cancel()
        pathMonitor = nil
        
        // Stop timer
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func checkWiFiConnection() {
        let (isConnected, networkName) = getCurrentWiFiStatus()
        
        print("🔍 NetworkMonitor: WiFi Status Check:")
        print("  - Connected: \(isConnected)")
        print("  - Network: \(networkName ?? "None")")
        
        // Analyze company info if connected to WiFi
        var companyInfo: SSIDAnalyzer.CompanyInfo?
        if isConnected, let networkName = networkName {
            companyInfo = SSIDAnalyzer.shared.analyzeSSID(networkName)
        }
        
        delegate?.wifiStatusChanged(isConnected: isConnected, networkName: networkName)
        delegate?.wifiCompanyDetected(isConnected: isConnected, networkName: networkName, companyInfo: companyInfo)
    }
    
    private func getWiFiNetworkName() -> String? {
        // Check if running in iOS Simulator
        #if targetEnvironment(simulator)
        return "Simulator Network"
        #else
        // Real device WiFi detection - attempt to get SSID
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else {
            print("❌ NetworkMonitor: No WiFi interfaces available for SSID lookup")
            return nil
        }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary?,
               let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String {
                print("✅ NetworkMonitor: Found WiFi SSID: '\(ssid)'")
                return ssid
            }
        }
        
        print("🔍 NetworkMonitor: Could not retrieve WiFi SSID (may require location permissions)")
        return nil
        #endif
    }
    
    private func getCurrentWiFiStatus() -> (isConnected: Bool, networkName: String?) {
        #if targetEnvironment(simulator)
        print("🔍 NetworkMonitor: Simulator - always show SONY branding")
        return (true, "Simulator Network")
        #else
        
        // Try multiple methods to detect WiFi connection
        print("🔍 NetworkMonitor: Backup WiFi detection on real device")
        
        // Method 1: Try to get WiFi network name
        let networkName = getWiFiNetworkName()
        if networkName != nil {
            print("✅ NetworkMonitor: WiFi SSID found - definitely connected to WiFi")
            return (true, networkName)
        }
        
        // Method 2: Check network reachability with WiFi-specific flags
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            print("❌ NetworkMonitor: Could not create reachability reference")
            return (false, nil)
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            print("❌ NetworkMonitor: Could not get reachability flags")
            return (false, nil)
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        let isNetworkReachable = isReachable && (!needsConnection || canConnectWithoutUserInteraction)
        
        // Check if we're NOT on cellular (indicating WiFi)
        let isOnWWAN = flags.contains(.isWWAN)
        let isWiFiConnection = isNetworkReachable && !isOnWWAN
        
        print("🔍 NetworkMonitor: Reachability analysis:")
        print("  - Reachable: \(isReachable)")
        print("  - Network reachable: \(isNetworkReachable)")
        print("  - On WWAN (cellular): \(isOnWWAN)")
        print("  - WiFi connection: \(isWiFiConnection)")
        
        if isWiFiConnection {
            print("✅ NetworkMonitor: WiFi connection detected via reachability")
            return (true, "WiFi Network")
        } else {
            print("📱 NetworkMonitor: No WiFi connection - likely cellular or no connection")
            return (false, nil)
        }
        #endif
    }
    
    // Manual check for immediate updates
    func forceWiFiCheck() {
        checkWiFiConnection()
    }
    
    // Test method to force different states for testing
    func testWiFiStates() {
        print("🧪 NetworkMonitor: Testing WiFi states")
        
        // Test neoX branding (no WiFi)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 Testing neoX branding (no WiFi)")
            self.delegate?.wifiStatusChanged(isConnected: false, networkName: nil)
        }
        
        // Test SONY branding (WiFi connected) after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🧪 Testing SONY branding (WiFi connected)")
            self.delegate?.wifiStatusChanged(isConnected: true, networkName: "Test WiFi Network")
        }
        
        // Back to neoX after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            print("🧪 Back to neoX branding")
            self.delegate?.wifiStatusChanged(isConnected: false, networkName: nil)
        }
        
        // Back to actual detection after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            print("🧪 Resuming actual WiFi detection")
            self.forceWiFiCheck()
        }
    }
}