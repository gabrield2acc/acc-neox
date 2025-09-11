import Foundation
import UIKit

class AIBrandingService {
    
    static let shared = AIBrandingService()
    
    private let apiBaseURL = "https://your-ai-service.azure.com" // Will be configured
    private let apiKey = "your-api-key" // Will be configured via environment
    
    private init() {}
    
    struct BrandingRequest {
        let ssid: String
        let companyInfo: SSIDAnalyzer.CompanyInfo
        let style: BrandingStyle
        let dimensions: ImageDimensions
    }
    
    struct BrandingResponse {
        let companyName: String
        let imageURL: String
        let generatedAt: Date
        let cacheKey: String
        let description: String
    }
    
    enum BrandingStyle: String, CaseIterable {
        case professional = "professional"
        case modern = "modern"
        case minimalist = "minimalist"
        case vibrant = "vibrant"
    }
    
    struct ImageDimensions {
        let width: Int
        let height: Int
        
        static let standard = ImageDimensions(width: 300, height: 200)
    }
    
    enum AIBrandingError: Error {
        case invalidRequest
        case networkError(Error)
        case serverError(Int)
        case invalidResponse
        case imageLoadError
        case serviceUnavailable
    }
    
    func generateBranding(for request: BrandingRequest, completion: @escaping (Result<BrandingResponse, AIBrandingError>) -> Void) {
        print("🤖 AIBrandingService: Generating branding for \(request.companyInfo.name)")
        
        // First check cache
        if let cachedResponse = getCachedBranding(for: request) {
            print("✅ AIBrandingService: Found cached branding")
            completion(.success(cachedResponse))
            return
        }
        
        // Generate new branding via API
        performAPIRequest(for: request) { [weak self] result in
            switch result {
            case .success(let response):
                // Cache the response
                self?.cacheBranding(response, for: request)
                completion(.success(response))
                
            case .failure(let error):
                print("❌ AIBrandingService: API request failed: \(error)")
                // Try to provide fallback branding
                if let fallbackResponse = self?.createFallbackBranding(for: request) {
                    completion(.success(fallbackResponse))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performAPIRequest(for request: BrandingRequest, completion: @escaping (Result<BrandingResponse, AIBrandingError>) -> Void) {
        
        guard let url = URL(string: "\(apiBaseURL)/generate-branding") else {
            completion(.failure(.invalidRequest))
            return
        }
        
        let requestBody: [String: Any] = [
            "ssid": request.ssid,
            "company_name": request.companyInfo.name,
            "company_domain": request.companyInfo.domain,
            "company_category": request.companyInfo.category,
            "confidence": request.companyInfo.confidence,
            "style": request.style.rawValue,
            "dimensions": [
                "width": request.dimensions.width,
                "height": request.dimensions.height
            ]
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.invalidRequest))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let companyName = json["company_name"] as? String,
                       let imageURL = json["image_url"] as? String,
                       let generatedAtString = json["generated_at"] as? String,
                       let cacheKey = json["cache_key"] as? String {
                        
                        let dateFormatter = ISO8601DateFormatter()
                        let generatedAt = dateFormatter.date(from: generatedAtString) ?? Date()
                        
                        let response = BrandingResponse(
                            companyName: companyName,
                            imageURL: imageURL,
                            generatedAt: generatedAt,
                            cacheKey: cacheKey,
                            description: json["description"] as? String ?? "AI-generated branding"
                        )
                        
                        completion(.success(response))
                    } else {
                        completion(.failure(.invalidResponse))
                    }
                } catch {
                    completion(.failure(.invalidResponse))
                }
            }
        }.resume()
    }
    
    private func getCachedBranding(for request: BrandingRequest) -> BrandingResponse? {
        let cacheKey = generateCacheKey(for: request)
        
        // Check UserDefaults for cached response metadata
        guard let cachedData = UserDefaults.standard.data(forKey: "branding_\(cacheKey)"),
              let cachedResponse = try? JSONDecoder().decode(CachedBrandingResponse.self, from: cachedData) else {
            return nil
        }
        
        // Check if cache is still valid (24 hours)
        let cacheAge = Date().timeIntervalSince(cachedResponse.cachedAt)
        guard cacheAge < 24 * 60 * 60 else {
            // Cache expired, remove it
            UserDefaults.standard.removeObject(forKey: "branding_\(cacheKey)")
            return nil
        }
        
        // Check if cached image file exists
        let imageURL = getCachedImageURL(for: cacheKey)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            // Image file missing, remove cache entry
            UserDefaults.standard.removeObject(forKey: "branding_\(cacheKey)")
            return nil
        }
        
        return BrandingResponse(
            companyName: cachedResponse.companyName,
            imageURL: imageURL.absoluteString,
            generatedAt: cachedResponse.generatedAt,
            cacheKey: cachedResponse.cacheKey,
            description: cachedResponse.description
        )
    }
    
    private func cacheBranding(_ response: BrandingResponse, for request: BrandingRequest) {
        let cacheKey = generateCacheKey(for: request)
        
        let cachedResponse = CachedBrandingResponse(
            companyName: response.companyName,
            generatedAt: response.generatedAt,
            cacheKey: response.cacheKey,
            description: response.description,
            cachedAt: Date()
        )
        
        // Cache metadata
        if let data = try? JSONEncoder().encode(cachedResponse) {
            UserDefaults.standard.set(data, forKey: "branding_\(cacheKey)")
        }
        
        // Download and cache image
        downloadAndCacheImage(from: response.imageURL, cacheKey: cacheKey)
    }
    
    private func downloadAndCacheImage(from urlString: String, cacheKey: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            let cachedImageURL = self.getCachedImageURL(for: cacheKey)
            try? data.write(to: cachedImageURL)
        }.resume()
    }
    
    private func getCachedImageURL(for cacheKey: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("branding_\(cacheKey).png")
    }
    
    private func generateCacheKey(for request: BrandingRequest) -> String {
        let keyComponents = [
            request.ssid,
            request.companyInfo.name,
            request.style.rawValue,
            "\(request.dimensions.width)x\(request.dimensions.height)"
        ]
        return keyComponents.joined(separator: "_").addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "default"
    }
    
    private func createFallbackBranding(for request: BrandingRequest) -> BrandingResponse? {
        // Create a simple fallback branded image
        print("🔄 AIBrandingService: Creating fallback branding for \(request.companyInfo.name)")
        
        let fallbackImage = createFallbackImage(
            companyName: request.companyInfo.name,
            dimensions: request.dimensions
        )
        
        // Save fallback image temporarily
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("fallback_\(request.companyInfo.name).png")
        if let imageData = fallbackImage.pngData() {
            try? imageData.write(to: tempURL)
        }
        
        return BrandingResponse(
            companyName: request.companyInfo.name,
            imageURL: tempURL.absoluteString,
            generatedAt: Date(),
            cacheKey: "fallback_\(generateCacheKey(for: request))",
            description: "Fallback branding for \(request.companyInfo.name)"
        )
    }
    
    private func createFallbackImage(companyName: String, dimensions: ImageDimensions) -> UIImage {
        let size = CGSize(width: dimensions.width, height: dimensions.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Dynamic color based on company name
            let backgroundColor = generateCompanyColor(from: companyName)
            backgroundColor.setFill()
            context.fill(rect)
            
            // Add company name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
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
        let adjustedRed = max(red * 0.7, 0.2)
        let adjustedGreen = max(green * 0.7, 0.2)
        let adjustedBlue = max(blue * 0.7, 0.2)
        
        return UIColor(red: adjustedRed, green: adjustedGreen, blue: adjustedBlue, alpha: 1.0)
    }
}

// MARK: - Supporting Types

private struct CachedBrandingResponse: Codable {
    let companyName: String
    let generatedAt: Date
    let cacheKey: String
    let description: String
    let cachedAt: Date
}