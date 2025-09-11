import UIKit
import SafariServices
import CoreLocation

class ViewController: UIViewController {
    
    private var titleLabel: UILabel!
    private var advertisementImageView: UIImageView!
    private var profileButton: UIButton!
    private var testButton: UIButton!
    private var statusLabel: UILabel!
    private var loadingIndicator: UIActivityIndicatorView!
    
    private let networkMonitor = NetworkMonitor.shared
    private let locationManager = CLLocationManager()
    
    // AI Branding properties
    private var currentCompanyInfo: SSIDAnalyzer.CompanyInfo?
    private var isGeneratingImage = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 ViewController: Starting with simplified WiFi-based branding")
        
        setupUI()
        requestLocationPermission()
        setupNetworkMonitoring()
        
        print("🔵 ViewController: Setup completed")
    }
    
    private func requestLocationPermission() {
        // Request location permission for WiFi SSID access
        print("🔵 ViewController: Requesting location permission for WiFi detection")
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.delegate = self
        networkMonitor.startMonitoring()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Create main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 30
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Title
        titleLabel = UILabel()
        titleLabel.text = "ACCNeoX"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .systemOrange
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        // Advertisement image
        advertisementImageView = UIImageView()
        advertisementImageView.contentMode = .scaleAspectFit
        advertisementImageView.backgroundColor = .clear
        advertisementImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(advertisementImageView)
        
        // Main Button
        profileButton = UIButton(type: .system)
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(profileButton)
        
        // Test Button (for debugging branding states)
        testButton = UIButton(type: .system)
        testButton.setTitle("🧪 Test Branding States", for: .normal)
        testButton.backgroundColor = .systemBlue
        testButton.setTitleColor(.white, for: .normal)
        testButton.layer.cornerRadius = 8
        testButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        testButton.translatesAutoresizingMaskIntoConstraints = false
        testButton.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(testButton)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(statusLabel)
        
        // Loading indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            
            advertisementImageView.widthAnchor.constraint(equalToConstant: 300),
            advertisementImageView.heightAnchor.constraint(equalToConstant: 200),
            
            profileButton.widthAnchor.constraint(equalToConstant: 200),
            profileButton.heightAnchor.constraint(equalToConstant: 50),
            
            testButton.widthAnchor.constraint(equalToConstant: 200),
            testButton.heightAnchor.constraint(equalToConstant: 44),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: advertisementImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: advertisementImageView.centerYAnchor)
        ])
        
        // Start with neoX image (default state)
        showNeoXBranding()
        
        print("✅ UI setup completed - default neoX branding shown")
    }
    
    @objc private func buttonTapped() {
        print("🔵 Button tapped - opening WiFi profile URL")
        
        guard let url = URL(string: "https://profiles.acloudradius.net/") else {
            print("❌ Invalid URL")
            return
        }
        
        // Visual feedback
        profileButton.backgroundColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.profileButton.backgroundColor = .systemOrange
        }
        
        // Open URL
        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully opened WiFi profile URL")
                } else {
                    print("❌ Failed to open URL")
                    self.openInSafariViewController(url: url)
                }
            }
        }
    }
    
    @objc private func testButtonTapped() {
        print("🧪 Test button tapped - testing branding states")
        
        // Visual feedback
        testButton.backgroundColor = .systemPurple
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.testButton.backgroundColor = .systemBlue
        }
        
        // Run the branding test sequence
        networkMonitor.testWiFiStates()
    }
    
    private func openInSafariViewController(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }
    
    // MARK: - Branding Methods
    
    private func showNeoXBranding() {
        print("🎨 Showing neoX branding (no WiFi)")
        
        let image = createNeoXImage()
        advertisementImageView.image = image
        statusLabel.text = "Tap the button to access free WiFi"
    }
    
    private func showSONYBranding(networkName: String) {
        print("🎨 Showing SONY branding (connected to WiFi: \(networkName))")
        
        let image = createSONYImage()
        advertisementImageView.image = image
        statusLabel.text = "Connected to \(networkName)"
    }
    
    private func createNeoXImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Orange gradient background
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [UIColor.systemOrange.cgColor, UIColor.white.cgColor] as CFArray,
                                    locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            // neoX text
            let text = "neoX"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 42),
                .foregroundColor: UIColor.black
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func createSONYImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Black background
            UIColor.black.setFill()
            context.fill(rect)
            
            // SONY text in white
            let text = "SONY"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Force a WiFi check when view appears
        networkMonitor.forceWiFiCheck()
    }
    
    deinit {
        networkMonitor.stopMonitoring()
    }
}

// MARK: - NetworkMonitorDelegate

extension ViewController: NetworkMonitorDelegate {
    func wifiStatusChanged(isConnected: Bool, networkName: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("📱 ViewController: WiFi status changed")
            print("  - Connected: \(isConnected)")
            print("  - Network: \(networkName ?? "None")")
            
            // Keep backward compatibility - this method still works for basic functionality
            if !isConnected {
                self.showNeoXBranding()
            }
        }
    }
    
    func wifiCompanyDetected(isConnected: Bool, networkName: String?, companyInfo: SSIDAnalyzer.CompanyInfo?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🏢 ViewController: Company detection result")
            print("  - Connected: \(isConnected)")
            print("  - Network: \(networkName ?? "None")")
            print("  - Company: \(companyInfo?.name ?? "None")")
            
            if isConnected, let companyInfo = companyInfo {
                // Company detected → Generate AI branding
                self.currentCompanyInfo = companyInfo
                self.generateAIBranding(for: companyInfo, ssid: networkName ?? "WiFi")
            } else if isConnected {
                // WiFi connected but no company detected → Show generic WiFi branding
                self.showGenericWiFiBranding(networkName: networkName ?? "WiFi Network")
            } else {
                // Not connected → Show neoX branding
                self.currentCompanyInfo = nil
                self.showNeoXBranding()
            }
        }
    }
}

// MARK: - AI Branding Methods

extension ViewController {
    private func generateAIBranding(for companyInfo: SSIDAnalyzer.CompanyInfo, ssid: String) {
        guard !isGeneratingImage else {
            print("🤖 ViewController: AI branding generation already in progress")
            return
        }
        
        print("🤖 ViewController: Starting AI branding generation for \(companyInfo.name)")
        
        isGeneratingImage = true
        loadingIndicator.startAnimating()
        
        // Show loading state
        statusLabel.text = "Generating \(companyInfo.name) branding..."
        
        let request = AIBrandingService.BrandingRequest(
            ssid: ssid,
            companyInfo: companyInfo,
            style: .professional,
            dimensions: .standard
        )
        
        AIBrandingService.shared.generateBranding(for: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isGeneratingImage = false
                self.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let brandingResponse):
                    print("✅ ViewController: AI branding generated successfully")
                    self.displayAIBranding(brandingResponse)
                    
                case .failure(let error):
                    print("❌ ViewController: AI branding generation failed: \(error)")
                    // Fallback to generic branding
                    self.showGenericWiFiBranding(networkName: ssid)
                }
            }
        }
    }
    
    private func displayAIBranding(_ branding: AIBrandingService.BrandingResponse) {
        print("🎨 ViewController: Displaying AI-generated branding for \(branding.companyName)")
        
        // Load image from URL or local cache
        loadImageFromBranding(branding) { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let image = image {
                    self.advertisementImageView.image = image
                    self.statusLabel.text = "Connected to \(branding.companyName)"
                    print("✅ ViewController: AI branding image displayed successfully")
                } else {
                    print("❌ ViewController: Failed to load AI branding image")
                    // Fallback to text-based branding
                    self.showTextBranding(companyName: branding.companyName)
                }
            }
        }
    }
    
    private func loadImageFromBranding(_ branding: AIBrandingService.BrandingResponse, completion: @escaping (UIImage?) -> Void) {
        // Check if it's a local file URL first
        if branding.imageURL.hasPrefix("file://"), let url = URL(string: branding.imageURL) {
            // Load from local file
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                completion(image)
                return
            }
        }
        
        // Load from remote URL
        guard let url = URL(string: branding.imageURL) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }
    
    private func showGenericWiFiBranding(networkName: String) {
        print("🎨 ViewController: Showing generic WiFi branding for \(networkName)")
        
        // Create a generic WiFi branded image
        let image = createGenericWiFiImage(networkName: networkName)
        advertisementImageView.image = image
        statusLabel.text = "Connected to \(networkName)"
    }
    
    private func showTextBranding(companyName: String) {
        print("🎨 ViewController: Showing text-based branding for \(companyName)")
        
        let image = createTextBrandingImage(companyName: companyName)
        advertisementImageView.image = image
        statusLabel.text = "Connected to \(companyName)"
    }
    
    private func createGenericWiFiImage(networkName: String) -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Blue gradient background for WiFi
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [UIColor.systemBlue.cgColor, UIColor.white.cgColor] as CFArray,
                                    locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            // WiFi symbol and network name
            let text = "📶 \(networkName)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func createTextBrandingImage(companyName: String) -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Company-based color background
            let backgroundColor = generateCompanyColor(from: companyName)
            backgroundColor.setFill()
            context.fill(rect)
            
            // Company name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = companyName.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            companyName.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func generateCompanyColor(from companyName: String) -> UIColor {
        let hash = companyName.hash
        let red = CGFloat((hash & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hash & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hash & 0x0000FF) / 255.0
        
        // Ensure minimum brightness for readability
        let adjustedRed = max(red * 0.7, 0.3)
        let adjustedGreen = max(green * 0.7, 0.3)
        let adjustedBlue = max(blue * 0.7, 0.3)
        
        return UIColor(red: adjustedRed, green: adjustedGreen, blue: adjustedBlue, alpha: 1.0)
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔵 ViewController: Location authorization changed to: \(status)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted - WiFi SSID detection enabled")
            // Force a network check now that we have permission
            networkMonitor.forceWiFiCheck()
        case .denied, .restricted:
            print("❌ Location permission denied - WiFi SSID detection limited")
            // Network framework will still detect WiFi interface without SSID
        case .notDetermined:
            print("⏳ Location permission not determined")
        @unknown default:
            print("❓ Unknown location permission status")
        }
    }
}