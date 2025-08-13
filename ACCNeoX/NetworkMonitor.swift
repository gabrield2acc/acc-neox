import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

class NetworkMonitor {
    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var onNetworkChange: (() -> Void)?
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.onNetworkChange?()
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func getCurrentNetworkInfo() -> [String: Any]? {
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else { return nil }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                return interfaceInfo as? [String: Any]
            }
        }
        return nil
    }
    
    func isConnectedToWiFi() -> Bool {
        return getCurrentNetworkInfo() != nil
    }
    
    func getConnectedSSID() -> String? {
        return getCurrentNetworkInfo()?[kCNNetworkInfoKeySSID as String] as? String
    }
    
    func getBSSID() -> String? {
        return getCurrentNetworkInfo()?[kCNNetworkInfoKeyBSSID as String] as? String
    }
}