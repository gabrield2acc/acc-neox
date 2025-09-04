import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork
import CoreLocation

class ViewController: UIViewController {
    
    private var profileButton: UIButton!
    private var advertisementImageView: UIImageView!
    private var statusLabel: UILabel!
    
    private let networkMonitor = NetworkMonitor.shared
    private var currentNetworkInfo: NetworkInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 ViewController viewDidLoad called")
        setupUI()
        setupNetworkMonitoring()
        
        // CRITICAL: Perform immediate network check after UI setup
        // This ensures SONY branding shows immediately if connected to acc-venue1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔵 ViewController: Performing initial network check for acc-venue1")
            self.networkMonitor.forceNetworkCheck()
        }
        
        print("🔵 ViewController setup completed")
    }
    
    private func setupNetworkMonitoring() {
        print("🔍 Setting up advanced network monitoring...")
        networkMonitor.delegate = self
        networkMonitor.startMonitoring()
    }
    
    private func setupUI() {
        print("🔵 Setting up UI components programmatically...")
        
        view.backgroundColor = .systemBackground
        
        // Create main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 30
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "ACCNeoX"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .systemOrange
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        // Create advertisement image view
        advertisementImageView = UIImageView()
        advertisementImageView.contentMode = .scaleAspectFit
        advertisementImageView.layer.cornerRadius = 12
        advertisementImageView.clipsToBounds = true
        advertisementImageView.backgroundColor = .secondarySystemBackground
        advertisementImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(advertisementImageView)
        
        // Create profile button
        profileButton = UIButton(type: .system)
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        profileButton.showsTouchWhenHighlighted = true
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(profileButton)
        
        // Create status label
        statusLabel = UILabel()
        statusLabel.text = "Tap the button to access free WiFi"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(statusLabel)
        
        // Add spacer view
        let spacerView = UIView()
        stackView.addArrangedSubview(spacerView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Advertisement image view constraints
            advertisementImageView.widthAnchor.constraint(equalToConstant: 300),
            advertisementImageView.heightAnchor.constraint(equalToConstant: 200),
            
            // Profile button constraints
            profileButton.widthAnchor.constraint(equalToConstant: 200),
            profileButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Status label constraints
            statusLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
        ])
        
        // Add button target
        profileButton.addTarget(self, action: #selector(installProfileButtonTapped(_:)), for: .touchUpInside)
        
        // Add debug gesture recognizers
        setupDebugGestures()
        
        // Load placeholder image initially - will be replaced by network detection
        loadPlaceholderImage()
        
        print("✅ Programmatic UI setup completed successfully")
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
        
        // Six tap to test acc-venue1 detection
        let sixTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugSixTapped))
        sixTapGesture.numberOfTapsRequired = 6
        advertisementImageView.addGestureRecognizer(sixTapGesture)
        
        // Seven tap to force full network detection refresh
        let sevenTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugSevenTapped))
        sevenTapGesture.numberOfTapsRequired = 7
        advertisementImageView.addGestureRecognizer(sevenTapGesture)
        
        // Eight tap to force permanent SONY lock for troubleshooting
        let eightTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugEightTapped))
        eightTapGesture.numberOfTapsRequired = 8
        advertisementImageView.addGestureRecognizer(eightTapGesture)
        
        print("🧪 Debug gestures enabled:")
        print("  - Double tap image: Force switch to SONY branding")
        print("  - Triple tap image: Force switch to neoX branding") 
        print("  - Quad tap image: Simulate ACLCloudRadius network")
        print("  - Five tap image: Test exact acloudradius.net SSID")
        print("  - Six tap image: Test acc-venue1 detection")
        print("  - Seven tap image: Force full network refresh")
        print("  - Eight tap image: Force permanent SONY lock")
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
    
    @objc private func debugSixTapped() {
        print("🧪 DEBUG: Six tap detected - testing acc-venue1 detection")
        networkMonitor.testACCVenue1Detection(ssid: "Current-Network-With-Venue")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusLabel.text = "🧪 Testing: Should show 'Device connected to venue=acc-venue1'"
        }
    }
    
    @objc private func debugSevenTapped() {
        print("🧪 DEBUG: Seven tap detected - forcing full network refresh")
        networkMonitor.debugForceNetworkDetection()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusLabel.text = "🧪 Debug: Full network refresh completed"
        }
    }
    
    @objc private func debugEightTapped() {
        print("🧪 DEBUG: Eight tap detected - forcing permanent SONY lock")
        networkMonitor.forcePermanentSONYLock()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusLabel.text = "🔒 EMERGENCY: Permanent SONY lock activated!"
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
    
    @objc func installProfileButtonTapped(_ sender: UIButton) {
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
    
    private func loadPlaceholderImage() {
        // Show neutral placeholder until network detection completes
        // This prevents overriding SONY branding when acc-venue1 is detected
        advertisementImageView.backgroundColor = .systemGray5
        print("🔵 Loaded placeholder image - waiting for network detection")
    }
    
    private func updateUIForNetworkStatus(isACLCloudRadiusConnected: Bool, networkInfo: NetworkInfo?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentNetworkInfo = networkInfo
            
            // PRIORITY CHECK: If NetworkMonitor is locked to SONY (acc-venue1 detected), ALWAYS show SONY
            if self.networkMonitor.isCurrentlyLockedToSONY() {
                print("🔒 ViewController: NetworkMonitor is locked to SONY - maintaining SONY branding")
                self.createSONYImage()
                
                if let info = networkInfo {
                    if info.hasACCVenue1 || (info.venueName?.lowercased().contains("acc-venue1") == true) {
                        self.statusLabel.text = "Device connected to venue=acc-venue1"
                        print("🎯 SONY branding maintained due to acc-venue1 venue name")
                    } else {
                        self.statusLabel.text = "Connected to \(info.ssid)"
                        print("🎯 SONY branding maintained due to locked state")
                    }
                } else {
                    self.statusLabel.text = "Device connected to venue=acc-venue1"
                }
                return // EXIT - do not process other branding logic
            }
            
            // NORMAL LOGIC: Only if not locked to SONY
            if isACLCloudRadiusConnected {
                print("✅ Switching to SONY branding - connected to acloudradius.net realm or acc-venue1")
                self.createSONYImage()
                
                if let info = networkInfo {
                    // Check if this is acc-venue1 based detection
                    if info.hasACCVenue1 || (info.venueName?.lowercased().contains("acc-venue1") == true) {
                        self.statusLabel.text = "Device connected to venue=acc-venue1"
                        print("🎯 SONY branding triggered by acc-venue1 venue name")
                    } else {
                        self.statusLabel.text = "Connected to \(info.ssid)"
                        print("🎯 SONY branding triggered by acloudradius.net network")
                    }
                } else {
                    self.statusLabel.text = "Connected to premium network"
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