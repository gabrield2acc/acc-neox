import Foundation
import SystemConfiguration.CaptiveNetwork
import Network

protocol NetworkMonitorDelegate: AnyObject {
    func wifiStatusChanged(isConnected: Bool, networkName: String?)
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
        var connectionType = "Unknown"
        var networkName: String?
        
        // Check if using WiFi interface
        let isWiFi = path.usesInterfaceType(.wifi)
        
        if isWiFi {
            connectionType = "WiFi"
            networkName = getWiFiNetworkName() ?? "WiFi Network"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = "Ethernet"
        }
        
        print("🔍 NetworkMonitor: Network path update")
        print("  - Status: \(path.status)")
        print("  - Connected: \(isConnected)")
        print("  - WiFi: \(isWiFi)")
        print("  - Connection Type: \(connectionType)")
        
        // For our app logic: connected to WiFi = show SONY, otherwise show neoX
        delegate?.wifiStatusChanged(isConnected: isWiFi && isConnected, networkName: networkName)
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
        
        delegate?.wifiStatusChanged(isConnected: isConnected, networkName: networkName)
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
        // This method is now primarily used as backup - the main detection uses Network framework
        let networkName = getWiFiNetworkName()
        let hasWiFiName = networkName != nil
        
        print("🔍 NetworkMonitor: Backup WiFi check - SSID available: \(hasWiFiName)")
        
        // If we can get a network name, we're likely connected to WiFi
        return (hasWiFiName, networkName)
    }
    
    // Manual check for immediate updates
    func forceWiFiCheck() {
        checkWiFiConnection()
    }
}