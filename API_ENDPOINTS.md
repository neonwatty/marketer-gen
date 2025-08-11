# Content Generation API Documentation

## Overview

The Content Generation API provides endpoints for creating various types of marketing content using AI-powered prompt templates.

## Base URL

```
/api/v1/generate/
```

## Endpoints

### 1. Social Media Content Generation

**POST** `/api/v1/generate/social_media`

Generate social media content optimized for various platforms.

**Required Parameters:**
- `platform` (string) - Target platform (Instagram, Facebook, Twitter, LinkedIn, etc.)
- `brand_context` (string) - Brand description and context

**Optional Parameters:**
- `content_type` (string, default: "social media post")
- `campaign_name` (string)
- `campaign_goal` (string, default: "engagement") 
- `target_audience` (string)
- `tone` (string, default: "engaging")
- `content_length` (string, default: "medium")
- `required_elements` (string)
- `restrictions` (string)
- `additional_context` (string)
- `generate_variations` (boolean) - Generate content variations
- `variation_count` (integer) - Number of variations to generate

**Example Request:**
```json
{
  "platform": "Instagram",
  "brand_context": "Sustainable fashion brand for millennials",
  "campaign_name": "Summer Collection Launch",
  "campaign_goal": "Drive awareness and engagement",
  "target_audience": "Environmentally conscious millennials aged 25-35",
  "tone": "inspiring and authentic",
  "generate_variations": true,
  "variation_count": 2
}
```

### 2. Ad Copy Generation

**POST** `/api/v1/generate/ad_copy`

Generate advertising copy for various platforms and ad types.

**Required Parameters:**
- `offering` (string) - Product or service being advertised
- `target_audience` (string) - Target audience description
- `brand_context` (string) - Brand description and context

**Optional Parameters:**
- `ad_type` (string, default: "display ad")
- `platform` (string, default: "Google Ads")
- `campaign_name` (string)
- `character_limit` (string, default: "150")
- `headline_count` (string, default: "3")
- `description_count` (string, default: "2")
- `key_messages` (string)
- `usp` (string) - Unique selling proposition
- `emotional_hooks` (string)
- `cta` (string, default: "Learn More")
- `brand_voice` (string, default: "professional")
- `platform_requirements` (string)

### 3. Email Marketing

**POST** `/api/v1/generate/email`

Generate email marketing content including subject lines and body copy.

**Required Parameters:**
- `email_type` (string) - Type of email (promotional, newsletter, welcome, etc.)
- `primary_goal` (string) - Primary goal of the email
- `brand_context` (string) - Brand description and context

**Optional Parameters:**
- `campaign_context` (string)
- `subject_focus` (string)
- `target_segment` (string)
- `send_timing` (string, default: "immediate")
- `brand_voice` (string, default: "professional")
- `tone` (string, default: "friendly")
- `content_length` (string, default: "medium")
- `call_to_action` (string, default: "Click here")
- `personalization_level` (string, default: "medium")
- `special_requirements` (string)

### 4. Landing Page Copy

**POST** `/api/v1/generate/landing_page`

Generate landing page copy optimized for conversions.

**Required Parameters:**
- `page_purpose` (string) - Purpose of the landing page
- `offering` (string) - Product or service being promoted
- `brand_context` (string) - Brand description and context

**Optional Parameters:**
- `target_audience` (string)
- `conversion_goal` (string, default: "signup")
- `page_sections` (string, default: "hero, features, testimonials, cta")
- `key_benefits` (string)
- `social_proof` (string)
- `competitive_advantages` (string)
- `cta_text` (string, default: "Get Started")
- `additional_requirements` (string)

### 5. Campaign Planning

**POST** `/api/v1/generate/campaign_plan`

Generate comprehensive marketing campaign strategies.

**Required Parameters:**
- `campaign_name` (string) - Name of the campaign
- `campaign_purpose` (string) - Purpose and goals of the campaign

**Optional Parameters:**
- `budget` (string)
- `start_date` (string)
- `end_date` (string)
- `target_audience` (string)
- `brand_context` (string)
- `additional_requirements` (string)

### 6. Brand Analysis

**POST** `/api/v1/generate/brand_analysis`

Analyze brand assets and generate strategic insights.

**Required Parameters:**
- `brand_assets` (string) - Description or content of brand assets to analyze

**Optional Parameters:**
- `focus_areas` (string, default: "brand voice, messaging, target audience, compliance")
- `technical_context` (string)

## Global Parameters

All endpoints support these optional parameters:

- `ai_provider` (string, default: "anthropic") - AI provider to use
- `ai_model` (string, default: "claude-3-5-sonnet-20241022") - AI model to use

## Response Format

### Success Response

```json
{
  "success": true,
  "content": "Generated content here...",
  "template_used": "Social Media Content",
  "generation_metadata": {
    "template_id": 3,
    "template_version": 1,
    "model_used": "claude-3-5-sonnet-20241022",
    "generated_at": "2025-08-10T20:45:00.000Z",
    "variable_count": 6,
    "content_length": 245
  },
  "variations": [
    {
      "variation_id": 1,
      "content": "Alternative content...",
      "temperature_used": 0.85
    }
  ]
}
```

### Error Response

```json
{
  "success": false,
  "error": "Error message describing what went wrong",
  "timestamp": "2025-08-10T20:45:00.000Z"
}
```

## HTTP Status Codes

- `200 OK` - Successful content generation
- `400 Bad Request` - Invalid or missing parameters
- `422 Unprocessable Entity` - Request validation failed
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error during generation
- `503 Service Unavailable` - AI service temporarily unavailable

## Error Handling

The API includes comprehensive error handling for:

- Parameter validation errors
- Template not found errors
- AI service failures
- Circuit breaker activation (when AI service is down)
- Rate limiting
- Variable validation errors

## Content Variations

To generate multiple variations of content, include these parameters:

- `generate_variations`: `true`
- `variation_count`: Number of variations (1-5 recommended)

Variations use slightly different temperature settings to produce diverse outputs while maintaining the same core prompt and brand context.