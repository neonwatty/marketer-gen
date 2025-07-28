# Branding::AnalysisService Usage Guide

## Overview

The enhanced `Branding::AnalysisService` provides comprehensive brand voice extraction and analysis capabilities with:

- Advanced prompt engineering for better brand analysis
- Multi-document analysis with content prioritization
- Visual brand analysis from logos and images
- Sophisticated parsing with error handling
- Multi-provider LLM support (OpenAI, Claude, Cohere, etc.)
- Comprehensive confidence scoring
- Brand consistency analysis

## Basic Usage

```ruby
# Initialize with a brand
brand = Brand.find(1)
service = Branding::AnalysisService.new(brand)

# Run analysis (async)
result = service.analyze
# => { success: true, analysis_id: 123 }

# The analysis runs in background via BrandAnalysisJob
```

## Advanced Usage

### Custom LLM Provider

```ruby
# Use Claude for nuanced analysis
service = Branding::AnalysisService.new(
  brand,
  nil,  # Use aggregated content
  llm_provider: 'claude-3-opus-20240229',
  temperature: 0.7
)

result = service.analyze
```

### Custom Content Analysis

```ruby
# Analyze specific content instead of all brand assets
custom_content = "Our brand stands for innovation and quality..."
service = Branding::AnalysisService.new(brand, custom_content)

result = service.analyze
```

### Synchronous Analysis (for testing/debugging)

```ruby
# Create analysis record
analysis = brand.brand_analyses.create!(analysis_status: "processing")

# Run analysis directly
service = Branding::AnalysisService.new(brand)
success = service.perform_analysis(analysis)

# Check results
if success
  puts analysis.reload.confidence_score
  puts analysis.voice_attributes
  puts analysis.brand_values
end
```

## Analysis Output Structure

### Voice Attributes

```ruby
{
  formality: {
    level: "professional",      # very_formal, formal, neutral, casual, very_casual
    score: 0.85,
    evidence: ["We maintain...", "Our commitment..."],
    consistency: 0.9,
    distribution: { "professional" => 8, "formal" => 2 }
  },
  energy: {
    level: "energetic",        # high_energy, energetic, balanced, calm, subdued
    score: 0.75,
    evidence: ["Exciting innovations...", "Dynamic solutions..."]
  },
  warmth: {
    level: "warm",             # very_warm, warm, neutral, cool, professional
    score: 0.8,
    evidence: ["We care about...", "Your success matters..."]
  },
  authority: {
    level: "authoritative",    # commanding, authoritative, balanced, approachable, peer_level
    score: 0.7,
    evidence: ["Industry leader...", "25 years of expertise..."]
  },
  tone: {
    primary: "professional",
    secondary: ["friendly", "innovative"],
    avoided: ["casual", "playful"],
    consistency: 0.85,
    distribution: { "professional" => 10, "friendly" => 7 }
  },
  style: {
    writing: "informative",
    sentence_structure: "varied",
    vocabulary: "intermediate",
    paragraph_length: "medium",
    active_passive_ratio: 0.8
  },
  personality_traits: [
    { trait: "Innovative", frequency: 8, strength: 0.9 },
    { trait: "Trustworthy", frequency: 6, strength: 0.85 }
  ],
  linguistic_patterns: {
    common_phrases: ["cutting-edge", "customer success"],
    power_words: ["transform", "empower", "innovate"],
    transitions: ["Moreover", "Furthermore", "As a result"],
    openings: ["We believe", "Our mission"],
    closings: ["Join us", "Learn more"]
  },
  emotional_tone: {
    primary_emotion: "confidence",
    emotional_range: "moderate",
    positivity_ratio: 0.85
  },
  consistency_score: 0.88
}
```

### Brand Values

```ruby
[
  {
    name: "Innovation",
    score: 0.95,
    type: :explicit,              # :explicit, :implied, :behavioral
    frequency: 12,
    evidence: [
      "We are committed to innovation",
      "Pioneering new solutions"
    ],
    contexts: [
      "Mission statement",
      "Product descriptions"
    ]
  },
  {
    name: "Customer Success",
    score: 0.88,
    type: :behavioral,
    frequency: 8,
    evidence: ["24/7 support", "Success metrics"],
    contexts: ["Service descriptions"]
  }
]
```

### Messaging Pillars

```ruby
{
  pillars: [
    {
      name: "Innovation Leadership",
      description: "Pioneering cutting-edge solutions",
      key_messages: [
        "First to market with AI integration",
        "Continuous innovation pipeline"
      ],
      supporting_points: [
        "10 patents filed",
        "R&D investment of 20% revenue"
      ],
      target_emotion: "excitement",
      evidence: ["From our website...", "CEO message..."],
      strength_score: 0.92,
      consistency_score: 0.88
    }
  ],
  relationships: [
    {
      pillar1: "Innovation Leadership",
      pillar2: "Customer Success",
      relationship: "Innovation drives customer outcomes"
    }
  ],
  pillar_hierarchy: {
    primary: ["Innovation Leadership", "Customer Success"],
    supporting: ["Sustainability"],
    connections: ["Innovation + Customer Success: Technology enables results"]
  }
}
```

### Extracted Rules

```ruby
{
  voice_tone_rules: {
    must_do: [
      "Use active voice",
      "Maintain professional yet approachable tone"
    ],
    should_do: [
      "Include customer success stories",
      "Use data to support claims"
    ],
    must_not_do: [
      "Use jargon without explanation",
      "Make unsubstantiated claims"
    ],
    examples: {
      good: ["We help you achieve...", "Our data shows..."],
      bad: ["We might be able to...", "Some people say..."]
    }
  },
  messaging_rules: {
    required_elements: ["Value proposition", "Call to action"],
    key_phrases: ["Transform your business", "Proven results"],
    prohibited_topics: ["Competitor failures", "Political views"],
    competitor_mentions: "Focus on our strengths, not their weaknesses"
  },
  visual_rules: {
    colors: {
      primary: ["#1E40AF", "#3B82F6"],
      secondary: ["#10B981"],
      usage_rules: ["Primary for headers", "Secondary for accents"]
    },
    typography: {
      fonts: ["Inter", "System UI"],
      sizes: ["16px body", "48px h1"],
      usage_rules: ["Inter for all text", "Bold for headers"]
    },
    imagery: {
      style: "Modern, clean, professional photography",
      do: ["Use diverse representation", "Show real customers"],
      dont: ["Avoid stock photos", "No clip art"]
    }
  },
  grammar_style_rules: {
    punctuation: ["Oxford comma required", "Em dash for emphasis"],
    capitalization: ["Title Case for headers", "Sentence case for body"],
    formatting: ["Short paragraphs", "Bullet points for lists"],
    preferred_terms: {
      "customer": "partner",
      "buy": "invest",
      "cheap": "affordable"
    }
  },
  behavioral_rules: {
    customer_interaction: [
      "Respond within 24 hours",
      "Always offer solutions"
    ],
    response_patterns: [
      "Acknowledge, empathize, resolve"
    ],
    ethical_guidelines: [
      "Transparency in all communications",
      "Respect customer privacy"
    ]
  },
  rule_priority: [
    {
      rule: "Maintain consistent brand voice",
      category: "voice",
      importance: 10,
      consequences: "Brand confusion and loss of trust"
    }
  ],
  rule_consistency: 0.85,
  conflicts: []
}
```

### Visual Guidelines

```ruby
{
  colors: {
    primary: ["#1E40AF", "#3B82F6", "#2563EB"],
    secondary: ["#10B981", "#059669"],
    accent: ["#F59E0B"],
    neutral: ["#F3F4F6", "#9CA3AF", "#1F2937"],
    color_relationships: {
      primary_usage: "Headers, CTAs, brand elements",
      secondary_usage: "Supporting elements, backgrounds",
      contrast_ratios: "Ensures accessibility"
    }
  },
  typography: {
    primary_font: "Inter",
    secondary_font: "Georgia",
    heading_hierarchy: {
      h1: { size: "48px", weight: "bold" },
      h2: { size: "36px", weight: "semibold" },
      h3: { size: "24px", weight: "semibold" },
      h4: { size: "20px", weight: "medium" }
    },
    body_text: {
      size: "16px",
      line_height: "1.5",
      weight: "regular"
    }
  },
  imagery: {
    style_characteristics: {
      primary_style: "modern",
      characteristics: ["clean", "professional", "vibrant"]
    },
    common_subjects: ["people in work settings", "technology", "collaboration"],
    color_treatment: {
      dominant_treatment: "natural",
      variations: ["bright", "muted"]
    },
    composition_patterns: {
      common_patterns: ["rule of thirds", "centered subjects"],
      guidelines: "Follow rule of thirds, maintain visual hierarchy"
    }
  },
  logo_usage: {
    variations: ["full-color", "mono", "icon-only"],
    clear_space: "Minimum clear space equal to 'x' height",
    minimum_size: "No smaller than 24px height for digital",
    backgrounds: {
      preferred: "White or light backgrounds",
      acceptable: "Brand colors with sufficient contrast",
      prohibited: "Busy patterns or low contrast"
    }
  },
  visual_consistency: 0.82
}
```

### Confidence Score

```ruby
{
  overall: 0.84,
  breakdown: {
    content_volume: 0.9,         # Based on amount of content analyzed
    voice_consistency: 0.85,     # How consistent voice is across content
    value_confidence: 0.88,      # Strength of value extraction
    messaging_clarity: 0.82,     # Clarity of messaging pillars
    guidelines_completeness: 0.8, # Completeness of extracted rules
    visual_confidence: 0.75,     # Confidence in visual analysis
    cross_validation: 0.86       # Alignment between different aspects
  },
  confidence_level: "High",
  recommendations: [
    "Upload more brand materials for comprehensive analysis",
    "Ensure visual assets follow consistent style"
  ]
}
```

## Configuration Options

### Service Options

```ruby
options = {
  llm_provider: 'claude-3-opus-20240229',  # or 'gpt-4-turbo-preview'
  temperature: 0.7,                         # 0.0-1.0, higher = more creative
  max_tokens: 4000,                         # Response length limit
  chunk_size: 4000,                         # Content chunk size
  system_message: "Custom system prompt"    # Override default
}

service = Branding::AnalysisService.new(brand, nil, options)
```

### Supported LLM Providers

- **OpenAI**: `gpt-4-turbo-preview`, `gpt-4`, `gpt-3.5-turbo`
- **Anthropic**: `claude-3-opus-20240229`, `claude-3-sonnet-20240229`
- **Cohere**: `command`, `command-light`
- **Hugging Face**: Various open models

## Error Handling

```ruby
result = service.analyze

if result[:success]
  analysis_id = result[:analysis_id]
  # Monitor job progress
else
  error = result[:error]
  # Handle error - likely insufficient content
end
```

## Testing

```ruby
# In tests, mock the LLM service
allow_any_instance_of(LlmService).to receive(:analyze).and_return(
  '{"formality": {"level": "professional", "score": 0.8}}'
)

# Test analysis
service = Branding::AnalysisService.new(brand)
analysis = create_test_analysis
success = service.perform_analysis(analysis)

assert success
assert_equal "professional", analysis.voice_attributes["formality"]["level"]
```

## Performance Considerations

1. **Content Chunking**: Large documents are automatically chunked to stay within LLM token limits
2. **Async Processing**: Analysis runs in background jobs to avoid blocking
3. **Caching**: Consider caching analysis results for similar content
4. **Rate Limiting**: The service handles rate limits with automatic retries

## Best Practices

1. **Content Quality**: Provide diverse brand materials for best results
   - Brand guidelines
   - Marketing materials
   - Website content
   - Sales presentations

2. **Regular Updates**: Re-run analysis when brand materials change significantly

3. **Review Results**: Always review extracted guidelines for accuracy

4. **Customization**: Adjust prompts for industry-specific terminology

5. **Monitoring**: Track confidence scores to identify areas needing more content

## Extending the Service

### Custom Analysis Dimensions

```ruby
class CustomAnalysisService < Branding::AnalysisService
  def analyze_industry_specific_aspects
    prompt = build_industry_prompt
    response = llm_service.analyze(prompt, json_response: true)
    parse_industry_response(response)
  end
  
  private
  
  def build_industry_prompt
    # Custom prompt for your industry
  end
end
```

### Custom Validation Rules

```ruby
def validate_industry_compliance(analysis)
  # Add industry-specific validation
  compliance_score = check_regulatory_language(analysis.extracted_rules)
  
  analysis.analysis_data.merge!(
    industry_compliance: compliance_score
  )
end
```