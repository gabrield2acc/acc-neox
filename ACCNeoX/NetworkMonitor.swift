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
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else {
            print("❌ NetworkMonitor: No WiFi interfaces available")
            return (false, nil)
        }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary?,
               let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String {
                print("✅ NetworkMonitor: Connected to WiFi - SSID: '\(ssid)'")
                return (true, ssid)
            }
        }
        
        print("🔍 NetworkMonitor: No WiFi connection detected")
        return (false, nil)
    }
    
    // Manual check for immediate updates
    func forceWiFiCheck() {
        checkWiFiConnection()
    }
}