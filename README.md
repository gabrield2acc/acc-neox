# ACCNeoX iOS App

A WiFi Passpoint profile installation and marketing app for iOS.

## Features

- **WiFi Profile Installation**: Direct button to redirect users to `profiles.acloudradius.net` for profile installation
- **Smart Advertisement**: Dynamic marketing content that switches based on network connection
- **Passpoint Detection**: Automatically detects when connected to a passpoint-enabled network with `acloudradius.net` NAI realm
- **Network Monitoring**: Real-time network status monitoring and connection detection

## App Behavior

1. **Default State**: Shows neoX branded advertisement image (orange/black/white theme)
2. **Profile Installation**: Safari redirect to `profiles.acloudradius.net` for profile download
3. **Passpoint Detection**: When connected to passpoint network with `acloudradius.net` realm, switches to SONY advertisement
4. **Network Monitoring**: Continuously monitors WiFi connection status

## Technical Implementation

### Core Components

- `ViewController.swift`: Main app interface and logic
- `NetworkMonitor.swift`: WiFi network monitoring and detection
- `ProfileManager.swift`: Profile installation and passpoint detection logic

### Key Features

- **Safari Integration**: Uses `SFSafariViewController` for secure profile installation
- **Network Detection**: Utilizes `SystemConfiguration.CaptiveNetwork` and `Network` frameworks
- **Dynamic UI**: Programmatically generated marketing images
- **Real-time Updates**: Network change monitoring with automatic UI updates

### Permissions Required

- Local Network Usage
- WiFi Information Access

## GitHub Actions Deployment

The repository includes automated iOS build and deployment workflow:

### Required GitHub Secrets

Set these secrets in your GitHub repository settings:

```
KEYCHAIN_PASSWORD              # Password for build keychain
APPLE_DISTRIBUTION_CERTIFICATE # Base64 encoded .p12 certificate
CERTIFICATE_PASSWORD           # Password for .p12 certificate
PROVISIONING_PROFILE          # Base64 encoded .mobileprovision file
PROVISIONING_PROFILE_NAME     # Name of provisioning profile
CODE_SIGN_IDENTITY           # Code signing identity
DEVELOPMENT_TEAM             # Apple Developer Team ID
APPLE_ID                     # Apple ID for App Store Connect
APPLE_APP_SPECIFIC_PASSWORD  # App-specific password for Apple ID
```

### Deployment Process

1. **Build**: Compiles iOS app with release configuration
2. **Archive**: Creates .xcarchive for distribution
3. **Export**: Generates .ipa file for App Store
4. **Upload**: Submits to TestFlight automatically

## Project Structure

```
ACCNeoX/
├── ACCNeoX.xcodeproj/         # Xcode project file
├── ACCNeoX/                   # Source code
│   ├── AppDelegate.swift      # App lifecycle
│   ├── SceneDelegate.swift    # Scene management
│   ├── ViewController.swift   # Main UI controller
│   ├── NetworkMonitor.swift   # Network monitoring
│   ├── ProfileManager.swift   # Profile management
│   ├── Assets.xcassets/       # App assets
│   ├── Base.lproj/           # Storyboard files
│   └── Info.plist            # App configuration
├── .github/workflows/        # CI/CD workflows
└── README.md                # This file
```

## Build Requirements

- Xcode 15.0+
- iOS 15.0+ deployment target
- Apple Developer Program membership
- Valid code signing certificates and provisioning profiles

## Local Development

1. Open `ACCNeoX.xcodeproj` in Xcode
2. Configure code signing with your Apple Developer account
3. Build and run on simulator or device

## App Store Submission

The GitHub Actions workflow automatically handles:
- Building the release version
- Code signing
- Creating IPA file
- Uploading to TestFlight

After TestFlight processing, submit for App Store review through App Store Connect.# Build triggered Wed 13 Aug 2025 17:25:27 BST
