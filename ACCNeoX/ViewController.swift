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
        
        statusLabel.text = "Checking available browsers..."
        
        // Show browser options and debug info
        showBrowserOptions(sender: sender)
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
    
    private func showBrowserOptions(sender: UIButton) {
        print("DEBUG: showBrowserOptions called")
        
        let urlString = "https://profiles.acloudradius.net"
        guard let targetURL = URL(string: urlString) else {
            statusLabel.text = "ERROR: Invalid URL"
            return
        }
        
        // Check all available browsers
        let browsers = detectAvailableBrowsers()
        print("DEBUG: Found \(browsers.count) available browsers")
        
        // Create action sheet with all browser options
        let alert = UIAlertController(title: "Open Profile Installation", message: "Available browsers and debug info:\n\nTarget URL: \(urlString)", preferredStyle: .actionSheet)
        
        // Add browser options
        for browser in browsers {
            let action = UIAlertAction(title: "\(browser.name) ✓", style: .default) { _ in
                self.openInBrowser(browser: browser, url: targetURL)
            }
            alert.addAction(action)
        }
        
        // Add debug info option
        alert.addAction(UIAlertAction(title: "Show Debug Info", style: .default) { _ in
            self.showDebugInfo()
        })
        
        // Add system default option
        alert.addAction(UIAlertAction(title: "Try System Default", style: .default) { _ in
            self.openWithSystemDefault(url: targetURL)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func detectAvailableBrowsers() -> [Browser] {
        let browsers = [
            Browser(name: "Safari", scheme: "https://", packageName: "com.apple.mobilesafari"),
            Browser(name: "Chrome", scheme: "googlechromes://", packageName: "com.google.chrome.ios"),
            Browser(name: "Firefox", scheme: "firefox://open-url?url=https://", packageName: "org.mozilla.ios.Firefox"),
            Browser(name: "Edge", scheme: "microsoft-edge-https://", packageName: "com.microsoft.msedge"),
            Browser(name: "Opera", scheme: "opera-https://", packageName: "com.operasoftware.OperaTouch"),
            Browser(name: "Brave", scheme: "brave-https://", packageName: "com.brave.ios.browser")
        ]
        
        return browsers.filter { browser in
            let testURL = URL(string: browser.scheme)!
            let canOpen = UIApplication.shared.canOpenURL(testURL)
            print("DEBUG: Browser \(browser.name) - Can open: \(canOpen)")
            return canOpen
        }
    }
    
    private func openInBrowser(browser: Browser, url: URL) {
        print("DEBUG: Opening in \(browser.name)")
        statusLabel.text = "Opening in \(browser.name)..."
        
        var browserURL: URL
        
        if browser.name == "Safari" {
            browserURL = url
        } else if browser.name == "Chrome" {
            browserURL = URL(string: "googlechromes://\(url.absoluteString)")!
        } else if browser.name == "Firefox" {
            browserURL = URL(string: "firefox://open-url?url=\(url.absoluteString)")!
        } else if browser.name == "Edge" {
            browserURL = URL(string: "microsoft-edge-https://\(url.host!)\(url.path)")!
        } else if browser.name == "Opera" {
            browserURL = URL(string: "opera-https://\(url.host!)\(url.path)")!
        } else if browser.name == "Brave" {
            browserURL = URL(string: "brave-https://\(url.host!)\(url.path)")!
        } else {
            browserURL = url
        }
        
        print("DEBUG: Browser URL: \(browserURL)")
        
        UIApplication.shared.open(browserURL, options: [:]) { success in
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: \(browser.name) opened!"
                    print("DEBUG: SUCCESS - \(browser.name) opened")
                } else {
                    self.statusLabel.text = "FAILED: \(browser.name) didn't open"
                    print("DEBUG: FAILED - \(browser.name) didn't open")
                }
            }
        }
    }
    
    private func openWithSystemDefault(url: URL) {
        print("DEBUG: Opening with system default")
        statusLabel.text = "Trying system default..."
        
        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS: System default opened!"
                } else {
                    self.statusLabel.text = "FAILED: System default didn't work"
                }
            }
        }
    }
    
    private func showDebugInfo() {
        let urlString = "https://profiles.acloudradius.net"
        guard let url = URL(string: urlString) else { return }
        
        var debugText = "=== DEBUG INFO ===\n\n"
        debugText += "Target URL: \(urlString)\n"
        debugText += "URL valid: \(url.absoluteString)\n"
        debugText += "Main thread: \(Thread.isMainThread)\n"
        debugText += "iOS version: \(UIDevice.current.systemVersion)\n\n"
        
        debugText += "Browser Capabilities:\n"
        let testBrowsers = [
            ("Safari", "https://"),
            ("Chrome", "googlechromes://"),
            ("Firefox", "firefox://"),
            ("Edge", "microsoft-edge-https://"),
            ("System HTTPS", "https://")
        ]
        
        for (name, scheme) in testBrowsers {
            if let testURL = URL(string: scheme) {
                let canOpen = UIApplication.shared.canOpenURL(testURL)
                debugText += "• \(name): \(canOpen ? "✓" : "✗")\n"
            }
        }
        
        debugText += "\n📱 To see detailed logs:\n"
        debugText += "1. Connect device to Mac\n"
        debugText += "2. Open Console app\n"
        debugText += "3. Select your device\n"
        debugText += "4. Filter by 'ACCNeoX'\n"
        debugText += "5. Press button again\n"
        
        let alert = UIAlertController(title: "Debug Information", message: debugText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy Debug Info", style: .default) { _ in
            UIPasteboard.general.string = debugText
            self.statusLabel.text = "Debug info copied to clipboard"
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    struct Browser {
        let name: String
        let scheme: String
        let packageName: String
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