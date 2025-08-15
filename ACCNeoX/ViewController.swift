import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork
import CoreLocation

class ViewController: UIViewController {
    
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var advertisementImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private let networkMonitor = NetworkMonitor.shared
    private var currentNetworkInfo: NetworkInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 ViewController viewDidLoad called")
        setupUI()
        setupNetworkMonitoring()
        print("🔵 ViewController setup completed")
    }
    
    private func setupNetworkMonitoring() {
        print("🔍 Setting up advanced network monitoring...")
        networkMonitor.delegate = self
        networkMonitor.startMonitoring()
    }
    
    private func setupUI() {
        print("🔵 Setting up UI components...")
        
        // Verify outlets are connected
        if profileButton == nil {
            print("❌ ERROR: profileButton outlet is nil!")
        } else {
            print("✅ profileButton outlet is connected")
        }
        
        if statusLabel == nil {
            print("❌ ERROR: statusLabel outlet is nil!")
        } else {
            print("✅ statusLabel outlet is connected")
        }
        
        if advertisementImageView == nil {
            print("❌ ERROR: advertisementImageView outlet is nil!")
        } else {
            print("✅ advertisementImageView outlet is connected")
        }
        
        // Add debug gesture recognizers for testing UI switching
        setupDebugGestures()
        
        // Configure button
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        // Add programmatic target as backup
        print("🔵 Adding programmatic button target...")
        profileButton.addTarget(self, action: #selector(installProfileButtonTapped(_:)), for: .touchUpInside)
        
        // Make button more responsive
        profileButton.showsTouchWhenHighlighted = true
        profileButton.adjustsImageWhenHighlighted = true
        
        print("🔵 Button configuration completed")
        
        // Configure status label
        statusLabel.text = "Tap the button to access free WiFi"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .label
        
        // Configure image view
        advertisementImageView.contentMode = .scaleAspectFit
        advertisementImageView.layer.cornerRadius = 12
        advertisementImageView.clipsToBounds = true
        
        // Load default image initially
        loadDefaultImage()
        
        print("🔵 UI setup completed successfully")
    }
    
    private func setupDebugGestures() {
        // Double tap on image to force switch to SONY
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugDoubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        advertisementImageView.addGestureRecognizer(doubleTapGesture)
        advertisementImageView.isUserInteractionEnabled = true
        
        // Triple tap on image to force switch back to neoX
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugTripleTapped))
        tripleTapGesture.numberOfTapsRequired = 3
        advertisementImageView.addGestureRecognizer(tripleTapGesture)
        
        // Long press on status label to cycle through network simulations
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(debugLongPressed))
        longPressGesture.minimumPressDuration = 2.0
        statusLabel.addGestureRecognizer(longPressGesture)
        statusLabel.isUserInteractionEnabled = true
        
        // Quad tap to simulate ACLCloudRadius network
        let quadTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugQuadTapped))
        quadTapGesture.numberOfTapsRequired = 4
        advertisementImageView.addGestureRecognizer(quadTapGesture)
        
        // Five tap to test exact acloudradius.net SSID
        let fiveTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugFiveTapped))
        fiveTapGesture.numberOfTapsRequired = 5
        advertisementImageView.addGestureRecognizer(fiveTapGesture)
        
        print("🧪 Debug gestures enabled:")
        print("  - Double tap image: Force switch to SONY branding")
        print("  - Triple tap image: Force switch to neoX branding") 
        print("  - Quad tap image: Simulate ACLCloudRadius network")
        print("  - Five tap image: Test exact acloudradius.net SSID")
        print("  - Long press status: Cycle through network simulations")
    }
    
    @objc private func debugDoubleTapped() {
        print("🧪 DEBUG: Double tap detected - forcing SONY branding")
        networkMonitor.testUISwitch(toSONY: true)
    }
    
    @objc private func debugTripleTapped() {
        print("🧪 DEBUG: Triple tap detected - forcing neoX branding")
        networkMonitor.testUISwitch(toSONY: false)
    }
    
    @objc private func debugQuadTapped() {
        print("🧪 DEBUG: Quad tap detected - simulating ACLCloudRadius network")
        networkMonitor.simulateNetworkConnection(ssid: "Test-ACLCloudRadius-WiFi", realm: "acloudradius.net", isPasspoint: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusLabel.text = "🧪 Debug: Simulated ACLCloudRadius network"
        }
    }
    
    @objc private func debugFiveTapped() {
        print("🧪 DEBUG: Five tap detected - testing exact acloudradius.net SSID")
        networkMonitor.testACLCloudRadiusSSID(ssid: "acloudradius.net")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusLabel.text = "🧪 Debug: Testing acloudradius.net SSID - should show SONY!"
        }
    }
    
    private var debugNetworkIndex = 0
    
    @objc private func debugLongPressed(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            print("🧪 DEBUG: Long press detected - cycling through network simulations")
            
            let testNetworks = [
                ("HomeWiFi", nil, false),                                    // Should show neoX
                ("acloudradius.net", "acloudradius.net", true),              // Should show SONY - exact SSID
                ("Test-ACLCloudRadius-Network", "acloudradius.net", true),   // Should show SONY  
                ("ACLCloudRadius-WiFi", "acloudradius.net", true),           // Should show SONY
                ("SONY-Guest", "acloudradius.net", true),                    // Should show SONY
                ("ACL-Cloud-WiFi", nil, false),                             // Should show SONY - pattern match
                ("CloudRadius-Hotspot", nil, true),                         // Should show SONY - pattern match
                ("Public-WiFi", nil, false),                                 // Should show neoX
                ("Regular-Passpoint", "other.realm.com", true)               // Should show neoX
            ]
            
            let (ssid, realm, isPasspoint) = testNetworks[debugNetworkIndex % testNetworks.count]
            debugNetworkIndex += 1
            
            print("🧪 Testing network: \(ssid)")
            networkMonitor.simulateNetworkConnection(ssid: ssid, realm: realm, isPasspoint: isPasspoint)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.statusLabel.text = "🧪 Debug: Testing \(ssid)"
            }
        }
    }
    
    @IBAction @objc func installProfileButtonTapped(_ sender: UIButton) {
        print("🔵 Button tapped - installProfileButtonTapped called")
        
        // Immediate visual feedback to confirm button is working
        sender.backgroundColor = .systemRed
        statusLabel.text = "Button pressed! Processing..."
        
        // Force UI update
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        let urlString = "https://profiles.acloudradius.net/"
        print("🔵 Creating URL from string: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Failed to create URL from string: \(urlString)")
            statusLabel.text = "❌ Invalid URL"
            sender.backgroundColor = .systemOrange
            return
        }
        
        print("✅ URL created successfully: \(url)")
        print("🔵 Checking if app can open URL...")
        
        // Check if we can open the URL
        let canOpen = UIApplication.shared.canOpenURL(url)
        print("🔵 Can open URL: \(canOpen)")
        
        statusLabel.text = "Opening browser..."
        sender.backgroundColor = .systemGreen
        
        // Always try to open in external browser first
        print("🔵 Attempting to open URL in external browser...")
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            print("🔵 External browser open result: \(success)")
            
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully opened in external browser")
                    self?.statusLabel.text = "✅ Opened in Safari! Follow instructions to install profile."
                } else {
                    print("❌ Failed to open in external browser, trying Safari View Controller...")
                    self?.statusLabel.text = "Opening in app browser..."
                    self?.openWithSafariViewController(url: url)
                }
            }
        }
        
        // Reset button color after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔵 Resetting button color to orange")
            sender.backgroundColor = .systemOrange
        }
    }
    
    private func openWithSafariViewController(url: URL) {
        print("🔵 Creating Safari View Controller for URL: \(url)")
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.dismissButtonStyle = .close
        safariVC.delegate = self
        
        print("🔵 Presenting Safari View Controller...")
        present(safariVC, animated: true) {
            print("✅ Safari View Controller presented successfully")
            self.statusLabel.text = "📱 Opened in app browser - follow instructions to install profile."
        }
    }
    
    private func loadDefaultImage() {
        createNeoXImage()
    }
    
    private func updateUIForNetworkStatus(isACLCloudRadiusConnected: Bool, networkInfo: NetworkInfo?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentNetworkInfo = networkInfo
            
            if isACLCloudRadiusConnected {
                print("✅ Switching to SONY branding - connected to acloudradius.net realm")
                self.createSONYImage()
                
                if let info = networkInfo {
                    self.statusLabel.text = "🎉 Connected to \(info.ssid)! Enjoy your premium WiFi experience."
                } else {
                    self.statusLabel.text = "🎉 Connected to Passpoint network! Enjoying premium experience."
                }
            } else if let info = networkInfo, info.isPasspoint {
                print("🔍 Connected to Passpoint network but not acloudradius.net realm")
                self.createNeoXImage()
                self.statusLabel.text = "Connected to \(info.ssid). Tap button for premium access."
            } else if let info = networkInfo {
                print("🔍 Connected to regular WiFi network: \(info.ssid)")
                self.createNeoXImage()
                self.statusLabel.text = "Connected to \(info.ssid). Tap button for free WiFi access."
            } else {
                print("🔍 No WiFi connection detected")
                self.createNeoXImage()
                self.statusLabel.text = "Tap the button to access free WiFi"
            }
        }
    }
    
    private func createNeoXImage() {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Black background
            UIColor.black.setFill()
            context.fill(rect)
            
            // Orange to white gradient
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [UIColor.systemOrange.cgColor, UIColor.white.cgColor] as CFArray,
                                    locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            // neoX text
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
            
            // Black background
            UIColor.black.setFill()
            context.fill(rect)
            
            // SONY text in white
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
    
    deinit {
        networkMonitor.stopMonitoring()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Force an immediate network check when view appears
        print("🔵 ViewController appearing - forcing immediate network check")
        networkMonitor.forceNetworkCheck()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force another check after view fully appears to catch any network changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔵 ViewController fully appeared - additional network check")
            self.networkMonitor.forceNetworkCheck()
        }
    }
}

// MARK: - NetworkMonitorDelegate
extension ViewController: NetworkMonitorDelegate {
    func networkStatusChanged(isPasspointConnected: Bool, networkInfo: NetworkInfo?) {
        print("🔍 ViewController: Network status changed")
        print("  - Passpoint Connected: \(isPasspointConnected)")
        print("  - Network SSID: \(networkInfo?.ssid ?? "None")")
        print("  - Network Realm: \(networkInfo?.realm ?? "None")")
        print("  - Is ACLCloudRadius Realm: \(networkInfo?.isACLCloudRadiusRealm ?? false)")
        
        // Trust the NetworkMonitor's enhanced detection
        // isPasspointConnected=true now means "connected to ACLCloudRadius network"
        let isACLCloudRadiusConnected = isPasspointConnected
        
        print("🔍 ViewController: Final determination - ACLCloudRadius connected: \(isACLCloudRadiusConnected)")
        print("  - NetworkMonitor determined isPasspointConnected: \(isPasspointConnected)")
        print("  - This will show: \(isACLCloudRadiusConnected ? "SONY" : "neoX") branding")
        
        updateUIForNetworkStatus(isACLCloudRadiusConnected: isACLCloudRadiusConnected, networkInfo: networkInfo)
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        statusLabel.text = "Safari closed. If you installed a profile, network detection will update automatically."
        
        // Network monitoring will automatically detect changes - no manual check needed
        print("🔵 Safari closed - automatic network monitoring will detect profile installation")
    }
}