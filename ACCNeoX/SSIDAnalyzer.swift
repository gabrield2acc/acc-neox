import Foundation

class SSIDAnalyzer {
    
    static let shared = SSIDAnalyzer()
    
    private init() {}
    
    struct CompanyInfo {
        let name: String
        let domain: String
        let category: String
        let confidence: Double
    }
    
    func analyzeSSID(_ ssid: String) -> CompanyInfo? {
        print("🔍 SSIDAnalyzer: Analyzing SSID: '\(ssid)'")
        
        let cleanSSID = cleanSSIDName(ssid)
        
        // Check against known company patterns
        if let companyInfo = detectKnownCompany(cleanSSID) {
            print("✅ SSIDAnalyzer: Found known company: \(companyInfo.name)")
            return companyInfo
        }
        
        // Extract potential company name from SSID
        if let extractedInfo = extractCompanyFromSSID(cleanSSID) {
            print("✅ SSIDAnalyzer: Extracted company info: \(extractedInfo.name)")
            return extractedInfo
        }
        
        print("❌ SSIDAnalyzer: Could not identify company from SSID")
        return nil
    }
    
    private func cleanSSIDName(_ ssid: String) -> String {
        // Remove common WiFi suffixes and prefixes
        let cleanPatterns = [
            "_5GHz", "_2.4GHz", "-5G", "-2G",
            "_Guest", "_Public", "_WiFi", "-WiFi",
            "_Network", "_Net", "_Internet",
            "Guest_", "Public_", "WiFi_", "Net_"
        ]
        
        var cleaned = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for pattern in cleanPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-_. "))
    }
    
    private func detectKnownCompany(_ ssid: String) -> CompanyInfo? {
        let knownCompanies: [String: CompanyInfo] = [
            "sony": CompanyInfo(name: "Sony Corporation", domain: "sony.com", category: "Technology", confidence: 0.95),
            "samsung": CompanyInfo(name: "Samsung", domain: "samsung.com", category: "Technology", confidence: 0.95),
            "apple": CompanyInfo(name: "Apple Inc.", domain: "apple.com", category: "Technology", confidence: 0.95),
            "microsoft": CompanyInfo(name: "Microsoft Corporation", domain: "microsoft.com", category: "Technology", confidence: 0.95),
            "google": CompanyInfo(name: "Google LLC", domain: "google.com", category: "Technology", confidence: 0.95),
            "amazon": CompanyInfo(name: "Amazon", domain: "amazon.com", category: "Technology", confidence: 0.95),
            "starbucks": CompanyInfo(name: "Starbucks Corporation", domain: "starbucks.com", category: "Food & Beverage", confidence: 0.9),
            "mcdonalds": CompanyInfo(name: "McDonald's Corporation", domain: "mcdonalds.com", category: "Food & Beverage", confidence: 0.9),
            "walmart": CompanyInfo(name: "Walmart Inc.", domain: "walmart.com", category: "Retail", confidence: 0.9),
            "bestbuy": CompanyInfo(name: "Best Buy Co. Inc.", domain: "bestbuy.com", category: "Retail", confidence: 0.9),
            "tesla": CompanyInfo(name: "Tesla Inc.", domain: "tesla.com", category: "Automotive", confidence: 0.9),
            "nike": CompanyInfo(name: "Nike Inc.", domain: "nike.com", category: "Apparel", confidence: 0.9),
            "intel": CompanyInfo(name: "Intel Corporation", domain: "intel.com", category: "Technology", confidence: 0.9),
            "cisco": CompanyInfo(name: "Cisco Systems", domain: "cisco.com", category: "Technology", confidence: 0.9),
            "hp": CompanyInfo(name: "HP Inc.", domain: "hp.com", category: "Technology", confidence: 0.85),
            "dell": CompanyInfo(name: "Dell Technologies", domain: "dell.com", category: "Technology", confidence: 0.85),
            "ibm": CompanyInfo(name: "IBM Corporation", domain: "ibm.com", category: "Technology", confidence: 0.9)
        ]
        
        let lowerSSID = ssid.lowercased()
        
        // Exact match first
        if let company = knownCompanies[lowerSSID] {
            return company
        }
        
        // Partial match
        for (key, company) in knownCompanies {
            if lowerSSID.contains(key) || key.contains(lowerSSID) {
                // Reduce confidence for partial matches
                let adjustedCompany = CompanyInfo(
                    name: company.name,
                    domain: company.domain,
                    category: company.category,
                    confidence: company.confidence * 0.8
                )
                return adjustedCompany
            }
        }
        
        return nil
    }
    
    private func extractCompanyFromSSID(_ ssid: String) -> CompanyInfo? {
        // Check if SSID contains a domain name
        if let domain = extractDomain(ssid) {
            let companyName = domainToCompanyName(domain)
            return CompanyInfo(
                name: companyName,
                domain: domain,
                category: "Unknown",
                confidence: 0.7
            )
        }
        
        // Check for corporate patterns
        if let corporateInfo = detectCorporatePattern(ssid) {
            return corporateInfo
        }
        
        return nil
    }
    
    private func extractDomain(_ ssid: String) -> String? {
        // Look for domain patterns in SSID
        let domainRegex = try? NSRegularExpression(pattern: "([a-zA-Z0-9-]+\\.(com|net|org|edu|gov|co\\.[a-z]{2}))", options: .caseInsensitive)
        
        if let regex = domainRegex {
            let range = NSRange(location: 0, length: ssid.utf16.count)
            if let match = regex.firstMatch(in: ssid, options: [], range: range) {
                if let domainRange = Range(match.range, in: ssid) {
                    return String(ssid[domainRange])
                }
            }
        }
        
        return nil
    }
    
    private func domainToCompanyName(_ domain: String) -> String {
        let companyName = domain.components(separatedBy: ".").first ?? domain
        return companyName.capitalized
    }
    
    private func detectCorporatePattern(_ ssid: String) -> CompanyInfo? {
        let corporatePatterns = [
            "corp", "company", "inc", "ltd", "llc", "enterprise", "business", "office"
        ]
        
        let lowerSSID = ssid.lowercased()
        
        for pattern in corporatePatterns {
            if lowerSSID.contains(pattern) {
                // Extract potential company name
                let components = ssid.components(separatedBy: CharacterSet(charactersIn: "-_ "))
                if let companyComponent = components.first(where: { !$0.lowercased().contains(pattern) && $0.count > 2 }) {
                    return CompanyInfo(
                        name: companyComponent.capitalized,
                        domain: "\(companyComponent.lowercased()).com",
                        category: "Corporate",
                        confidence: 0.6
                    )
                }
            }
        }
        
        return nil
    }
}