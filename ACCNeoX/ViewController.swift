import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork

class ViewController: UIViewController {
    
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var advertisementImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkNetworkAndUpdateImage()
    }
    
    private func setupUI() {
        // Configure button
        profileButton.setTitle("Access Free WiFi", for: .normal)
        profileButton.backgroundColor = .systemOrange
        profileButton.setTitleColor(.white, for: .normal)
        profileButton.layer.cornerRadius = 8
        profileButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        // Configure status label
        statusLabel.text = "Tap the button to access free WiFi"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .label
        
        // Configure image view
        advertisementImageView.contentMode = .scaleAspectFit
        advertisementImageView.layer.cornerRadius = 12
        advertisementImageView.clipsToBounds = true
        
        // Load default image
        loadDefaultImage()
    }
    
    @IBAction func installProfileButtonTapped(_ sender: UIButton) {
        print("Button tapped!")
        
        // Visual feedback
        sender.backgroundColor = .systemGreen
        statusLabel.text = "Opening profile page..."
        
        // Open the root URL (not /generate) as suggested
        let urlString = "https://profiles.acloudradius.net/"
        
        guard let url = URL(string: urlString) else {
            statusLabel.text = "Invalid URL"
            sender.backgroundColor = .systemOrange
            return
        }
        
        print("Opening URL: \(url)")
        
        // Use SFSafariViewController as recommended by Apple
        let safariVC = SFSafariViewController(url: url)
        safariVC.dismissButtonStyle = .close
        safariVC.delegate = self
        
        present(safariVC, animated: true) {
            self.statusLabel.text = "Profile page opened - follow the instructions to install."
        }
        
        // Reset button color after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            sender.backgroundColor = .systemOrange
        }
    }
    
    private func loadDefaultImage() {
        createNeoXImage()
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
    
    private func checkNetworkAndUpdateImage() {
        if isConnectedToPasspointNetwork() {
            createSONYImage()
            statusLabel.text = "Connected to Passpoint network - Enjoy your free WiFi!"
        } else {
            loadDefaultImage()
        }
    }
    
    private func isConnectedToPasspointNetwork() -> Bool {
        // Check if connected to a network with acloudradius.net realm
        guard let interfaces = CNCopySupportedInterfaces() as NSArray? else { return false }
        
        for interface in interfaces {
            if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                if let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String {
                    print("Connected to SSID: \(ssid)")
                    
                    // Simple heuristic: if SSID contains certain keywords or patterns
                    // In real implementation, you'd check NAI realm for acloudradius.net
                    if ssid.lowercased().contains("passpoint") || 
                       ssid.lowercased().contains("hotspot") ||
                       ssid.lowercased().contains("guest") ||
                       ssid.lowercased().contains("acloudradius") {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check network status when returning to app (after profile installation)
        checkNetworkAndUpdateImage()
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        statusLabel.text = "Safari closed. If you installed a profile, you may see the SONY branding when connected."
        
        // Check network status after Safari closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkNetworkAndUpdateImage()
        }
    }
}