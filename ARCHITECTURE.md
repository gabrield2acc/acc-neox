# AI-Generated Dynamic Branding Architecture

## 🎯 Feature Overview

Transform WiFi SSID detection into dynamic, AI-generated company branding:

1. **Detect WiFi SSID** → Extract company information
2. **Query AI Agent** → Research company details online  
3. **Generate Custom Image** → Create branded image via Stable Diffusion
4. **Display in App** → Show dynamic branding instead of static SONY/neoX

## 🏗 System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │  AI Service     │    │ Stable Diffusion│
│   ACCNeoX       │◄──►│  (Azure VM)     │◄──►│    Engine       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ SSID Detection  │    │ Company Research│    │ Image Generation│
│ • WiFi Monitor  │    │ • Web Search    │    │ • Text-to-Image │
│ • SSID Extract  │    │ • LLM Analysis  │    │ • Brand Styling │
│ • Cache Check   │    │ • Brand Info    │    │ • Logo Creation │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📱 iOS App Enhancements

### New Components:
- **SSIDAnalyzer**: Extract company info from SSID names
- **AIBrandingService**: Communicate with Azure AI service
- **ImageCache**: Local storage for generated images
- **DynamicBrandingView**: Display AI-generated content

### Enhanced Flow:
1. WiFi detected → Extract SSID
2. Analyze SSID → Identify company
3. Check cache → Return cached image if exists
4. Request AI generation → Get custom branded image
5. Cache & display → Show dynamic branding

## ☁️ Azure Infrastructure

### Repository Structure:
```
acc-neox-ai-infrastructure/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── stable-diffusion.tf
│   └── ai-service.tf
├── api/
│   ├── app.py (Flask API)
│   ├── requirements.txt
│   └── services/
│       ├── company_research.py
│       ├── image_generation.py
│       └── cache_manager.py
└── deployment/
    ├── docker/
    └── scripts/
```

### VM Specifications:
- **Instance**: Standard_NC4as_T4_v3 (GPU-enabled)
- **OS**: Ubuntu 22.04 LTS
- **Storage**: 200GB Premium SSD
- **Network**: Public IP with NSG rules

## 🔄 API Endpoints

### AI Service API:
```
POST /generate-branding
{
  "ssid": "sony-corp-wifi",
  "style": "professional",
  "dimensions": "300x200"
}

Response:
{
  "company": "Sony Corporation",
  "image_url": "https://ai-service.azure.com/images/sony-brand.png",
  "generated_at": "2025-09-10T14:30:00Z",
  "cache_key": "sony-corp-wifi-hash"
}
```

## 💾 Caching Strategy

### iOS App Cache:
- Local image storage (Core Data + File System)
- TTL: 24 hours per generated image
- Cache key: Hash of (SSID + style + dimensions)

### Azure Service Cache:
- Redis cache for company research data
- Generated images stored in Azure Blob Storage
- CDN for fast image delivery

## 🔒 Security Considerations

- API authentication with token-based access
- Rate limiting to prevent abuse
- Input validation and sanitization
- Secure image storage with expiration

## 📊 Performance Optimizations

- Background image generation
- Progressive loading with placeholders  
- Fallback to static branding on failures
- Preemptive caching for common SSIDs

## 🚀 Deployment Plan

1. **Phase 1**: Azure infrastructure deployment
2. **Phase 2**: AI service development and testing
3. **Phase 3**: iOS app integration
4. **Phase 4**: Testing and performance optimization
5. **Phase 5**: Production deployment