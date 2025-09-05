import UIKit
import SafariServices

class ViewController: UIViewController {
    
    private var titleLabel: UILabel!
    private var advertisementImageView: UIImageView!
    private var profileButton: UIButton!
    private var statusLabel: UILabel!
    
    private let networkMonitor = NetworkMonitor.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 ViewController: Starting with simplified WiFi-based branding")
        
        setupUI()
        setupNetworkMonitoring()
        
        print("🔵 ViewController: Setup completed")
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
        
        // Button
        profileButton = UIButton(type: .system)
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(profileButton)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(statusLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            
            advertisementImageView.widthAnchor.constraint(equalToConstant: 300),
            advertisementImageView.heightAnchor.constraint(equalToConstant: 200),
            
            profileButton.widthAnchor.constraint(equalToConstant: 200),
            profileButton.heightAnchor.constraint(equalToConstant: 50)
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
            
            if isConnected, let networkName = networkName {
                // Connected to WiFi → Show SONY branding
                self.showSONYBranding(networkName: networkName)
            } else {
                // Not connected to WiFi → Show neoX branding
                self.showNeoXBranding()
            }
        }
    }
}