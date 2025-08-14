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
        
        // Directly try to open URL and show the result
        statusLabel.text = "Testing URL opening..."
        testAllURLOpeningMethods()
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
    
    private func testAllURLOpeningMethods() {
        print("DEBUG: testAllURLOpeningMethods called")
        
        let urlString = "https://profiles.acloudradius.net"
        guard let url = URL(string: urlString) else {
            statusLabel.text = "ERROR: Cannot create URL"
            showAlert(title: "Error", message: "Invalid URL: \(urlString)")
            return
        }
        
        print("DEBUG: Testing URL: \(url)")
        statusLabel.text = "Step 1: Testing Safari direct..."
        
        // Test 1: Direct Safari
        UIApplication.shared.open(url, options: [:]) { success in
            print("DEBUG: Direct Safari result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: Safari opened!"
                } else {
                    self.statusLabel.text = "Step 2: Safari failed, trying Chrome..."
                    self.testChrome(url: url)
                }
            }
        }
    }
    
    private func testChrome(url: URL) {
        print("DEBUG: Testing Chrome")
        
        let chromeURL = "googlechromes://\(url.absoluteString)"
        guard let chromeURLObject = URL(string: chromeURL) else {
            statusLabel.text = "Step 3: Chrome URL invalid, trying Settings..."
            testSettings()
            return
        }
        
        UIApplication.shared.open(chromeURLObject, options: [:]) { success in
            print("DEBUG: Chrome result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: Chrome opened!"
                } else {
                    self.statusLabel.text = "Step 3: Chrome failed, trying Settings..."
                    self.testSettings()
                }
            }
        }
    }
    
    private func testSettings() {
        print("DEBUG: Testing Settings app as fallback")
        
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            statusLabel.text = "ERROR: Cannot create Settings URL"
            showCompleteFailure()
            return
        }
        
        statusLabel.text = "Testing if URL opening works at all..."
        
        UIApplication.shared.open(settingsURL, options: [:]) { success in
            print("DEBUG: Settings app result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "URL opening works! But browsers are restricted."
                    self.showBrowserRestrictedAlert()
                } else {
                    self.statusLabel.text = "CRITICAL: Cannot open any URLs"
                    self.showCompleteFailure()
                }
            }
        }
    }
    
    private func showBrowserRestrictedAlert() {
        let alert = UIAlertController(
            title: "Browsers Restricted",
            message: "URL opening works (Settings app opened), but Safari and Chrome are blocked.\n\nThis could be due to:\n• Screen Time restrictions\n• Device management policies\n• Parental controls\n• App sandbox limitations\n\nPlease check your device settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Show Debug Info", style: .default) { _ in
            self.showInlineDebugInfo()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showCompleteFailure() {
        let alert = UIAlertController(
            title: "Critical Error",
            message: "Cannot open any URLs on this device. This indicates a serious system restriction or app sandbox issue.\n\nPlease check:\n• Device management settings\n• Screen Time settings\n• App-specific restrictions",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Show Debug Info", style: .default) { _ in
            self.showInlineDebugInfo()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showInlineDebugInfo() {
        let urlString = "https://profiles.acloudradius.net"
        guard let url = URL(string: urlString) else { return }
        
        // Create visible debug information
        var debugText = "=== DEBUG INFORMATION ===\n\n"
        debugText += "Target URL: \(urlString)\n"
        debugText += "iOS Version: \(UIDevice.current.systemVersion)\n"
        debugText += "Device Model: \(UIDevice.current.model)\n"
        debugText += "App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")\n\n"
        
        // Test URL schemes
        let testSchemes = [
            ("Safari HTTPS", "https://apple.com"),
            ("Chrome", "googlechromes://apple.com"),
            ("Settings", UIApplication.openSettingsURLString)
        ]
        
        debugText += "URL Scheme Tests:\n"
        for (name, scheme) in testSchemes {
            if let testURL = URL(string: scheme) {
                let canOpen = UIApplication.shared.canOpenURL(testURL)
                debugText += "• \(name): \(canOpen ? "✓ Available" : "✗ Blocked")\n"
            }
        }
        
        debugText += "\n📱 Device Logs:\n"
        debugText += "1. Connect to Mac\n"
        debugText += "2. Open Console app\n"
        debugText += "3. Select device\n"
        debugText += "4. Search 'ACCNeoX'\n"
        debugText += "5. Press button again\n"
        
        let alert = UIAlertController(title: "Debug Information", message: debugText, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Copy to Clipboard", style: .default) { _ in
            UIPasteboard.general.string = debugText
            self.statusLabel.text = "Debug info copied to clipboard!"
        })
        
        alert.addAction(UIAlertAction(title: "Try Manual URL", style: .default) { _ in
            self.showManualURLInstructions()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    private func showManualURLInstructions() {
        let alert = UIAlertController(
            title: "Manual Instructions",
            message: "Since automatic opening isn't working, please:\n\n1. Open Safari manually\n2. Go to: https://profiles.acloudradius.net\n3. Follow the profile installation steps\n4. Return to this app\n\nThe URL has been copied to your clipboard.",
            preferredStyle: .alert
        )
        
        UIPasteboard.general.string = "https://profiles.acloudradius.net"
        statusLabel.text = "Manual instructions shown - URL copied to clipboard"
        
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