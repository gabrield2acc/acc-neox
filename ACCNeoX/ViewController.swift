import UIKit
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import WebKit

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
        print("DEBUG: ========== BUTTON TAPPED ===========")
        
        // IMMEDIATE visual feedback to confirm method is called
        sender.backgroundColor = .systemRed
        statusLabel.text = "BUTTON PRESSED! Method called successfully."
        
        // Show an alert to confirm the method is working
        let alert = UIAlertController(title: "Button Works!", message: "Method is being called. Choose how to open URL:", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Try External Browser", style: .default) { _ in
            self.openProfileInstallationURL()
        })
        
        alert.addAction(UIAlertAction(title: "Open In WebView", style: .default) { _ in
            self.openInWebView()
        })
        
        alert.addAction(UIAlertAction(title: "Test Basic URL", style: .default) { _ in
            self.testBasicURL()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            sender.backgroundColor = .systemOrange
            self.statusLabel.text = "Tap the button to install your WiFi profile"
        })
        
        present(alert, animated: true)
        
        // Reset button color after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            sender.backgroundColor = .systemOrange
        }
    }
    
    private func openProfileInstallationURL() {
        let targetURL = "https://profiles.acloudradius.net"
        print("DEBUG: Starting comprehensive URL opening for: \(targetURL)")
        statusLabel.text = "Attempting to open browser..."
        
        // Method 1: Try direct HTTPS URL opening
        tryDirectHTTPS(targetURL)
    }
    
    private func tryDirectHTTPS(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("DEBUG: Failed to create URL from: \(urlString)")
            statusLabel.text = "Error: Invalid URL"
            return
        }
        
        print("DEBUG: Method 1 - Trying direct HTTPS: \(url)")
        
        // Check if URL can be opened first
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for HTTPS")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Direct HTTPS result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Browser opened! Install the WiFi profile and return to this app."
                    } else {
                        print("DEBUG: Direct HTTPS failed, trying Safari scheme")
                        self.statusLabel.text = "Method 1 failed, trying Safari scheme..."
                        self.trySafariScheme(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for HTTPS, trying Safari scheme")
            statusLabel.text = "HTTPS blocked, trying Safari scheme..."
            trySafariScheme(urlString)
        }
    }
    
    private func trySafariScheme(_ urlString: String) {
        // Method 2: Try safari-https:// scheme
        let safariURL = "safari-https://\(urlString.replacingOccurrences(of: "https://", with: ""))"
        guard let url = URL(string: safariURL) else {
            print("DEBUG: Failed to create Safari scheme URL")
            tryChrome(urlString)
            return
        }
        
        print("DEBUG: Method 2 - Trying Safari scheme: \(url)")
        
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for Safari scheme")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Safari scheme result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Safari opened! Install the WiFi profile and return to this app."
                    } else {
                        print("DEBUG: Safari scheme failed, trying Chrome")
                        self.statusLabel.text = "Method 2 failed, trying Chrome..."
                        self.tryChrome(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for Safari scheme, trying Chrome")
            statusLabel.text = "Safari scheme blocked, trying Chrome..."
            tryChrome(urlString)
        }
    }
    
    private func tryChrome(_ urlString: String) {
        // Method 3: Try Chrome
        let chromeURL = "googlechromes://\(urlString.replacingOccurrences(of: "https://", with: ""))"
        guard let url = URL(string: chromeURL) else {
            print("DEBUG: Failed to create Chrome URL")
            tryEdge(urlString)
            return
        }
        
        print("DEBUG: Method 3 - Trying Chrome: \(url)")
        
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for Chrome")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Chrome result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Chrome opened! Install the WiFi profile and return to this app."
                    } else {
                        print("DEBUG: Chrome failed, trying Edge")
                        self.statusLabel.text = "Method 3 failed, trying Edge..."
                        self.tryEdge(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for Chrome, trying Edge")
            statusLabel.text = "Chrome not available, trying Edge..."
            tryEdge(urlString)
        }
    }
    
    private func tryEdge(_ urlString: String) {
        // Method 4: Try Microsoft Edge
        let edgeURL = "microsoft-edge-https://\(urlString.replacingOccurrences(of: "https://", with: ""))"
        guard let url = URL(string: edgeURL) else {
            print("DEBUG: Failed to create Edge URL")
            tryFirefox(urlString)
            return
        }
        
        print("DEBUG: Method 4 - Trying Edge: \(url)")
        
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for Edge")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Edge result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Edge opened! Install the WiFi profile and return to this app."
                    } else {
                        print("DEBUG: Edge failed, trying Firefox")
                        self.statusLabel.text = "Method 4 failed, trying Firefox..."
                        self.tryFirefox(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for Edge, trying Firefox")
            statusLabel.text = "Edge not available, trying Firefox..."
            tryFirefox(urlString)
        }
    }
    
    private func tryFirefox(_ urlString: String) {
        // Method 5: Try Firefox
        let firefoxURL = "firefox://open-url?url=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)"
        guard let url = URL(string: firefoxURL) else {
            print("DEBUG: Failed to create Firefox URL")
            trySettings(urlString)
            return
        }
        
        print("DEBUG: Method 5 - Trying Firefox: \(url)")
        
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for Firefox")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Firefox result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Firefox opened! Install the WiFi profile and return to this app."
                    } else {
                        print("DEBUG: Firefox failed, testing with Settings")
                        self.statusLabel.text = "Method 5 failed, testing URL opening..."
                        self.trySettings(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for Firefox, testing with Settings")
            statusLabel.text = "Firefox not available, testing URL opening..."
            trySettings(urlString)
        }
    }
    
    private func trySettings(_ targetURL: String) {
        // Method 6: Test if URL opening works at all by opening Settings
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("DEBUG: Failed to create Settings URL")
            showAllMethodsFailed(targetURL)
            return
        }
        
        print("DEBUG: Method 6 - Testing URL opening capability with Settings")
        statusLabel.text = "Testing if device allows URL opening..."
        
        UIApplication.shared.open(settingsURL, options: [:]) { success in
            print("DEBUG: Settings test result: \(success)")
            DispatchQueue.main.async {
                if success {
                    print("DEBUG: URL opening works, but all browsers failed")
                    self.statusLabel.text = "URL opening works, but browsers are restricted"
                    self.showBrowsersRestrictedMessage(targetURL)
                } else {
                    print("DEBUG: URL opening completely disabled")
                    self.statusLabel.text = "URL opening is completely disabled on this device"
                    self.showAllMethodsFailed(targetURL)
                }
            }
        }
    }
    
    private func showBrowsersRestrictedMessage(_ targetURL: String) {
        let message = "All browser opening methods failed, but URL opening works (Settings opened).\n\nThis suggests browser restrictions are in place.\n\nPlease manually:\n1. Open Safari\n2. Go to: \(targetURL)\n3. Install the profile\n4. Return to this app"
        
        let alert = UIAlertController(title: "Browsers Restricted", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Copy URL", style: .default) { _ in
            UIPasteboard.general.string = targetURL
            self.statusLabel.text = "URL copied to clipboard"
        })
        
        alert.addAction(UIAlertAction(title: "Show Debug", style: .default) { _ in
            self.showDebugInfo(targetURL)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAllMethodsFailed(_ targetURL: String) {
        let message = "All URL opening methods failed.\n\nThis indicates severe device restrictions.\n\nPlease check:\n• Screen Time settings\n• Device management policies\n• Parental controls\n\nManually open: \(targetURL)"
        
        let alert = UIAlertController(title: "Critical: All Methods Failed", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Copy URL", style: .default) { _ in
            UIPasteboard.general.string = targetURL
            self.statusLabel.text = "URL copied to clipboard"
        })
        
        alert.addAction(UIAlertAction(title: "Show Debug", style: .default) { _ in
            self.showDebugInfo(targetURL)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showDebugInfo(_ targetURL: String) {
        var debugText = "=== COMPREHENSIVE DEBUG INFO ===\n\n"
        debugText += "Target: \(targetURL)\n"
        debugText += "iOS: \(UIDevice.current.systemVersion)\n"
        debugText += "Device: \(UIDevice.current.model)\n"
        debugText += "Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")\n\n"
        
        // Test all URL schemes
        let schemes = [
            ("HTTPS Direct", targetURL),
            ("Safari Scheme", "safari-https://profiles.acloudradius.net"),
            ("Chrome", "googlechromes://profiles.acloudradius.net"),
            ("Edge", "microsoft-edge-https://profiles.acloudradius.net"),
            ("Firefox", "firefox://open-url?url=\(targetURL)"),
            ("Settings", UIApplication.openSettingsURLString)
        ]
        
        debugText += "URL Scheme Availability:\n"
        for (name, urlString) in schemes {
            if let url = URL(string: urlString) {
                let canOpen = UIApplication.shared.canOpenURL(url)
                debugText += "• \(name): \(canOpen ? "✓" : "✗")\n"
            } else {
                debugText += "• \(name): Invalid URL\n"
            }
        }
        
        debugText += "\n📝 Manual Steps:\n"
        debugText += "1. Open Safari manually\n"
        debugText += "2. Navigate to: \(targetURL)\n"
        debugText += "3. Follow profile installation steps\n"
        debugText += "4. Return to ACCNeoX app\n"
        
        let alert = UIAlertController(title: "Debug Information", message: debugText, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Copy Debug Info", style: .default) { _ in
            UIPasteboard.general.string = debugText
            self.statusLabel.text = "Debug info copied to clipboard"
        })
        
        alert.addAction(UIAlertAction(title: "Copy URL Only", style: .default) { _ in
            UIPasteboard.general.string = targetURL
            self.statusLabel.text = "URL copied to clipboard"
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func openInWebView() {
        guard let url = URL(string: "https://profiles.acloudradius.net") else {
            statusLabel.text = "Error: Could not create URL"
            return
        }
        
        print("DEBUG: Opening URL in WebView: \(url)")
        statusLabel.text = "Loading profile page in WebView..."
        
        // Create WebView
        let webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .systemBackground
        
        // Create navigation controller with WebView
        let webViewController = UIViewController()
        webViewController.view = webView
        webViewController.title = "Install WiFi Profile"
        webViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close", 
            style: .done, 
            target: self, 
            action: #selector(closeWebView)
        )
        
        let navController = UINavigationController(rootViewController: webViewController)
        navController.modalPresentationStyle = .fullScreen
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Present the WebView
        present(navController, animated: true) {
            self.statusLabel.text = "WebView opened with profile page"
        }
    }
    
    @objc private func closeWebView() {
        dismiss(animated: true) {
            self.statusLabel.text = "WebView closed. Check Settings if you installed a profile."
            // Check network after WebView closes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkNetworkAndUpdateAdvertisement()
            }
        }
    }
    
    private func testBasicURL() {
        print("DEBUG: Testing basic URL opening capabilities")
        statusLabel.text = "Testing basic URL opening..."
        
        // Test with Apple's website first
        guard let appleURL = URL(string: "https://www.apple.com") else {
            statusLabel.text = "Error: Could not create Apple URL"
            return
        }
        
        print("DEBUG: Testing with Apple URL: \(appleURL)")
        
        if UIApplication.shared.canOpenURL(appleURL) {
            print("DEBUG: canOpenURL returned true for Apple.com")
            UIApplication.shared.open(appleURL, options: [:]) { success in
                print("DEBUG: Apple URL opening result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Basic URL opening works! Apple.com opened."
                        // Now try our target URL
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.tryTargetURLAfterApple()
                        }
                    } else {
                        self.statusLabel.text = "Basic URL opening failed even for Apple.com"
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false for Apple.com")
            statusLabel.text = "Error: canOpenURL failed for Apple.com - severe restrictions"
        }
    }
    
    private func tryTargetURLAfterApple() {
        guard let targetURL = URL(string: "https://profiles.acloudradius.net") else {
            statusLabel.text = "Error: Could not create target URL"
            return
        }
        
        print("DEBUG: Now trying target URL after Apple success: \(targetURL)")
        statusLabel.text = "Apple worked, now trying target URL..."
        
        UIApplication.shared.open(targetURL, options: [:]) { success in
            print("DEBUG: Target URL result after Apple success: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.statusLabel.text = "SUCCESS! Target URL opened after Apple test."
                } else {
                    self.statusLabel.text = "Target URL failed even though Apple worked."
                }
            }
        }
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

