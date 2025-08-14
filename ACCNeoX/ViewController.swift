import UIKit
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {
    
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
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        statusLabel.text = "Tap the button to access free WiFi"
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
        print("DEBUG: Access Free WiFi button tapped")
        
        // Update button and status immediately
        sender.backgroundColor = .systemGreen
        statusLabel.text = "Opening profile generation page..."
        
        // Use the backend endpoint that generates credentials automatically
        let profileURL = "https://profiles.acloudradius.net/generate"
        print("DEBUG: Profile generation URL: \(profileURL)")
        
        // Open the profile generation URL directly in browser/webview
        openProfileGenerationURL(profileURL)
        
        // Reset button color after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            sender.backgroundColor = .systemOrange
        }
    }
    
    private func openProfileGenerationURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("DEBUG: Failed to create profile generation URL")
            statusLabel.text = "Error: Could not create profile URL"
            return
        }
        
        print("DEBUG: Opening profile generation URL: \(url)")
        
        // First try direct URL opening (this should trigger profile download)
        if UIApplication.shared.canOpenURL(url) {
            print("DEBUG: canOpenURL returned true for profile generation URL")
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Profile URL opening result: \(success)")
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Profile page opened! Follow the installation steps."
                    } else {
                        print("DEBUG: Direct opening failed, trying WebView")
                        self.statusLabel.text = "External browser failed, opening in WebView..."
                        self.openProfileInWebView(urlString)
                    }
                }
            }
        } else {
            print("DEBUG: canOpenURL returned false, opening in WebView")
            statusLabel.text = "External browser blocked, opening in WebView..."
            openProfileInWebView(urlString)
        }
    }
    
    private func openProfileInWebView(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            statusLabel.text = "Error: Could not create profile URL"
            return
        }
        
        print("DEBUG: Opening profile generation URL in WebView: \(url)")
        statusLabel.text = "Loading profile generation page in WebView..."
        
        // Create WebView with specific configuration for profile downloads
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []
        
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        
        // Create navigation controller with WebView
        let webViewController = UIViewController()
        webViewController.view = webView
        webViewController.title = "Install WiFi Profile"
        
        let navController = UINavigationController(rootViewController: webViewController)
        navController.modalPresentationStyle = .fullScreen
        
        // Add navigation buttons
        webViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close", 
            style: .done, 
            target: self, 
            action: #selector(closeProfileWebView)
        )
        
        webViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reload", 
            style: .plain, 
            target: self, 
            action: #selector(reloadProfileWebView)
        )
        
        // Store webview reference for reload functionality
        self.currentWebView = webView
        
        // Load the profile generation URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Present the WebView
        present(navController, animated: true) {
            self.statusLabel.text = "WebView opened with profile generation page"
        }
    }
    
    // Store reference to current webview
    private var currentWebView: WKWebView?
    
    @objc private func closeProfileWebView() {
        currentWebView = nil
        dismiss(animated: true) {
            self.statusLabel.text = "WebView closed. Check Settings→General→VPN & Device Management if you installed a profile."
            // Check network after WebView closes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkNetworkAndUpdateAdvertisement()
            }
        }
    }
    
    @objc private func reloadProfileWebView() {
        currentWebView?.reload()
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

// MARK: - WKNavigationDelegate
extension ViewController {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        print("DEBUG: WebView navigation to: \(url)")
        
        // Check if this is a profile download (.mobileconfig or Content-Type header)
        if url.pathExtension.lowercased() == "mobileconfig" || 
           url.absoluteString.contains("mobileconfig") ||
           url.absoluteString.contains("/generate") {
            
            print("DEBUG: Detected profile generation/download URL: \(url)")
            statusLabel.text = "Profile detected! Opening in Safari for installation..."
            
            // For profile downloads/generation, we need to open in Safari
            UIApplication.shared.open(url, options: [:]) { success in
                DispatchQueue.main.async {
                    if success {
                        self.statusLabel.text = "Profile page opened in Safari! Follow steps to download and tap 'Allow' to install."
                        // Close the WebView after successful Safari opening
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.closeProfileWebView()
                        }
                    } else {
                        self.statusLabel.text = "Could not open profile page in Safari."
                    }
                }
            }
            
            decisionHandler(.cancel)
            return
        }
        
        // Allow all other navigation
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("DEBUG: WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
        DispatchQueue.main.async {
            if let url = webView.url, url.absoluteString.contains("/generate") {
                self.statusLabel.text = "Profile generation page loaded. The backend will create credentials and trigger download."
            } else {
                self.statusLabel.text = "Page loaded. Look for profile download or generation options."
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("DEBUG: WebView failed to load: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.statusLabel.text = "Failed to load profile page: \(error.localizedDescription)"
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        // Check the response MIME type for profile downloads
        if let mimeType = navigationResponse.response.mimeType {
            print("DEBUG: Response MIME type: \(mimeType)")
            
            if mimeType.contains("application/x-apple-aspen-config") || 
               mimeType.contains("application/xml") ||
               mimeType.contains("text/xml") {
                
                print("DEBUG: Detected profile MIME type, will handle download")
                statusLabel.text = "Profile download starting..."
            }
        }
        
        decisionHandler(.allow)
    }
}

