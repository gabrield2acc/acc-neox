import Foundation
import SystemConfiguration.CaptiveNetwork

protocol NetworkMonitorDelegate: AnyObject {
    func wifiStatusChanged(isConnected: Bool, networkName: String?)
}

class NetworkMonitor: NSObject {
    static let shared = NetworkMonitor()
    
    weak var delegate: NetworkMonitorDelegate?
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    
    private override init() {
        super.init()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("🔍 NetworkMonitor: Starting simple WiFi detection...")
        isMonitoring = true
        
        // Check WiFi status every 2 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkWiFiConnection()
        }
        
        // Immediate check
        checkWiFiConnection()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🔍 NetworkMonitor: Stopping WiFi monitoring")
        isMonitoring = false
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
    
    private func getCurrentWiFiStatus() -> (isConnected: Bool, networkName: String?) {
        // Check if running in iOS Simulator
        #if targetEnvironment(simulator)
        print("🔍 NetworkMonitor: Running in iOS Simulator - simulating WiFi connection")
        // In simulator, we'll simulate being connected to WiFi since the simulator 
        // uses the host Mac's internet connection
        return (true, "Simulator Network")
        #else
        // Real device WiFi detection
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else {
            print("❌ NetworkMonitor: No WiFi interfaces available")
            return (false, nil)
        }
        
        print("🔍 NetworkMonitor: Checking \(interfaces.count) interface(s)")
        
        for interface in interfaces {
            print("🔍 NetworkMonitor: Checking interface: \(interface)")
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                print("🔍 NetworkMonitor: Interface info: \(interfaceInfo)")
                if let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String {
                    print("✅ NetworkMonitor: Connected to WiFi - SSID: '\(ssid)'")
                    return (true, ssid)
                } else {
                    print("🔍 NetworkMonitor: Interface info available but no SSID found")
                }
            } else {
                print("🔍 NetworkMonitor: No interface info for: \(interface)")
            }
        }
        
        print("🔍 NetworkMonitor: No WiFi connection detected on real device")
        return (false, nil)
        #endif
    }
    
    // Manual check for immediate updates
    func forceWiFiCheck() {
        checkWiFiConnection()
    }
}