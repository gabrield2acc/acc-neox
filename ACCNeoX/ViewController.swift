import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork
import NetworkExtension

class ViewController: UIViewController {
    
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var advertisementImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private let profileManager = ProfileManager()
    private let networkMonitor = NetworkMonitor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNetworkMonitoring()
        loadDefaultAdvertisementImage()
    }
    
    private func setupUI() {
        profileButton.setTitle("Install WiFi Profile", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        statusLabel.text = "Tap the button to install your WiFi profile"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .label
        
        advertisementImageView.contentMode = .scaleAspectFit
        advertisementImageView.layer.cornerRadius = 12
        advertisementImageView.clipsToBounds = true
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.onNetworkChange = { [weak self] in
            DispatchQueue.main.async {
                self?.checkNetworkAndUpdateAdvertisement()
            }
        }
        networkMonitor.startMonitoring()
    }
    
    private func loadDefaultAdvertisementImage() {
        if let image = UIImage(named: "neoX-default") {
            advertisementImageView.image = image
        } else {
            createDefaultNeoXImage()
        }
    }
    
    private func createDefaultNeoXImage() {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            UIColor.black.setFill()
            context.fill(rect)
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [UIColor.systemOrange.cgColor, UIColor.white.cgColor] as CFArray,
                                    locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "neoX"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                y: (size.height - textSize.height) / 2,
                                width: textSize.width,
                                height: textSize.height)
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        advertisementImageView.image = image
    }
    
    private func createSONYImage() {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            UIColor.black.setFill()
            context.fill(rect)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "SONY"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                y: (size.height - textSize.height) / 2,
                                width: textSize.width,
                                height: textSize.height)
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        advertisementImageView.image = image
    }
    
    @IBAction func installProfileButtonTapped(_ sender: UIButton) {
        print("DEBUG: ===== BUTTON TAPPED =====")
        print("DEBUG: Button sender: \(sender)")
        print("DEBUG: Current thread: \(Thread.current)")
        print("DEBUG: Is main thread: \(Thread.isMainThread)")
        
        statusLabel.text = "Button pressed! Attempting to open Safari..."
        
        // Try multiple approaches to open URL
        openURLWithMultipleMethods()
    }
    
    private func openProfileInstallationPage() {
        print("DEBUG: openProfileInstallationPage called")
        guard let url = URL(string: "https://profiles.acloudradius.net") else {
            print("DEBUG: URL creation failed")
            showAlert(title: "Error", message: "Invalid URL")
            return
        }
        
        print("DEBUG: URL created successfully: \(url)")
        statusLabel.text = "Opening profile installation page..."
        
        // Try SFSafariViewController first, fallback to external Safari if needed
        if #available(iOS 9.0, *) {
            let safariVC = SFSafariViewController(url: url)
            safariVC.delegate = self
            print("DEBUG: About to present SFSafariViewController")
            present(safariVC, animated: true) {
                print("DEBUG: SFSafariViewController presented successfully")
            }
        } else {
            // Fallback for older iOS versions
            print("DEBUG: Using UIApplication.shared.open fallback")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: UIApplication.shared.open success: \(success)")
            }
        }
    }
    
    private func openInExternalSafari() {
        print("DEBUG: openInExternalSafari called")
        
        guard let url = URL(string: "https://profiles.acloudradius.net") else {
            print("DEBUG: URL creation failed for external Safari")
            DispatchQueue.main.async {
                self.statusLabel.text = "Error: Invalid URL"
                self.showAlert(title: "Error", message: "Could not create URL for profile installation")
            }
            return
        }
        
        print("DEBUG: URL created successfully: \(url)")
        print("DEBUG: Checking if URL can be opened...")
        
        // First check if the URL can be opened
        guard UIApplication.shared.canOpenURL(url) else {
            print("DEBUG: Cannot open URL - no app available")
            DispatchQueue.main.async {
                self.statusLabel.text = "Error: Cannot open Safari"
                self.showAlert(title: "Error", message: "Safari is not available to open this URL")
            }
            return
        }
        
        print("DEBUG: URL can be opened, attempting to open...")
        statusLabel.text = "Opening Safari..."
        
        UIApplication.shared.open(url, options: [:]) { success in
            print("DEBUG: UIApplication.shared.open completed with success: \(success)")
            DispatchQueue.main.async {
                if success {
                    print("DEBUG: Successfully opened URL in external Safari")
                    self.statusLabel.text = "Safari opened! Install the WiFi profile and return to this app."
                } else {
                    print("DEBUG: Failed to open URL in external Safari")
                    self.statusLabel.text = "Failed to open Safari. Please check device settings."
                    self.showAlert(title: "Error", message: "Unable to open Safari. Please check if Safari is enabled in device settings.")
                }
            }
        }
    }
    
    private func openURLWithMultipleMethods() {
        print("DEBUG: openURLWithMultipleMethods called")
        
        let urlString = "https://profiles.acloudradius.net"
        guard let url = URL(string: urlString) else {
            print("DEBUG: FAILED to create URL from string: \(urlString)")
            statusLabel.text = "ERROR: Invalid URL"
            return
        }
        
        print("DEBUG: URL created successfully: \(url)")
        print("DEBUG: URL scheme: \(url.scheme ?? "nil")")
        print("DEBUG: URL host: \(url.host ?? "nil")")
        
        // Method 1: Check if Safari is available
        let safariURL = URL(string: "safari://")!
        let canOpenSafari = UIApplication.shared.canOpenURL(safariURL)
        print("DEBUG: Can open Safari app: \(canOpenSafari)")
        
        // Method 2: Check if we can open HTTPS URLs
        let canOpenHTTPS = UIApplication.shared.canOpenURL(url)
        print("DEBUG: Can open HTTPS URL: \(canOpenHTTPS)")
        
        statusLabel.text = "Checking URL opening capabilities..."
        
        // Try approach 1: Direct URL open
        print("DEBUG: === ATTEMPTING METHOD 1: Direct URL open ===")
        UIApplication.shared.open(url, options: [:]) { success in
            print("DEBUG: Method 1 result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: Safari opened!"
                    print("DEBUG: SUCCESS - Safari opened with direct method")
                } else {
                    print("DEBUG: Method 1 FAILED, trying method 2")
                    self.tryMethod2(url: url)
                }
            }
        }
    }
    
    private func tryMethod2(url: URL) {
        print("DEBUG: === ATTEMPTING METHOD 2: With options ===")
        statusLabel.text = "Trying alternate method..."
        
        let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [
            .universalLinksOnly: false
        ]
        
        UIApplication.shared.open(url, options: options) { success in
            print("DEBUG: Method 2 result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: Safari opened (method 2)!"
                    print("DEBUG: SUCCESS - Safari opened with method 2")
                } else {
                    print("DEBUG: Method 2 FAILED, trying method 3")
                    self.tryMethod3()
                }
            }
        }
    }
    
    private func tryMethod3() {
        print("DEBUG: === ATTEMPTING METHOD 3: Settings app (fallback) ===")
        statusLabel.text = "Opening Settings app as test..."
        
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("DEBUG: FAILED to create Settings URL")
            statusLabel.text = "ERROR: Cannot create Settings URL"
            return
        }
        
        UIApplication.shared.open(settingsURL, options: [:]) { success in
            print("DEBUG: Method 3 (Settings) result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "Settings opened - URL opening works! Safari may be restricted."
                    self.showSafariError()
                } else {
                    self.statusLabel.text = "ERROR: Cannot open any URLs on this device"
                    print("DEBUG: CRITICAL - Cannot open any URLs at all")
                }
            }
        }
    }
    
    private func showSafariError() {
        let alert = UIAlertController(
            title: "Safari Issue", 
            message: "URL opening works, but Safari won't open. This could be due to:\n\n1. Safari is disabled in Screen Time\n2. Safari is restricted by device management\n3. App sandbox restrictions\n\nPlease check Safari settings.", 
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func checkNetworkAndUpdateAdvertisement() {
        if let ssid = getCurrentWiFiSSID() {
            statusLabel.text = "Connected to: \(ssid)"
            
            if isConnectedToPasspointNetwork() {
                createSONYImage()
                statusLabel.text = "Connected to Passpoint network - SONY content loaded"
            } else {
                loadDefaultAdvertisementImage()
                statusLabel.text = "Connected to: \(ssid) - Default content"
            }
        } else {
            statusLabel.text = "Not connected to WiFi"
            loadDefaultAdvertisementImage()
        }
    }
    
    private func getCurrentWiFiSSID() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else { return nil }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
            }
        }
        return nil
    }
    
    private func isConnectedToPasspointNetwork() -> Bool {
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else { return false }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                if let bssid = interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String {
                    return checkForPasspointIndicators(bssid: bssid)
                }
            }
        }
        return false
    }
    
    private func checkForPasspointIndicators(bssid: String) -> Bool {
        return profileManager.isPasspointNetworkConnected()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        statusLabel.text = "Profile installation completed. Please check your settings."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkNetworkAndUpdateAdvertisement()
        }
    }
}