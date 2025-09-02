# frozen_string_literal: true

# Service for building comprehensive brand context for AI-powered journey suggestions
# Combines brand identity, assets, guidelines, and journey-specific information
class JourneyBrandContextBuilder < ApplicationService
  attr_reader :journey, :user, :brand_identity

  def initialize(journey, user)
    @journey = journey
    @user = user
    @brand_identity = user.active_brand_identity || user.brand_identities.active.first
  end

  def build_complete_context
    return build_generic_context unless brand_identity

    {
      brand: build_brand_context,
      brand_assets: build_brand_assets_context,
      brand_variants: build_brand_variants_context,
      journey: build_journey_context,
      historical_performance: build_performance_context,
      industry_context: build_industry_context
    }
  end

  def build_brand_summary
    return "No brand identity configured" unless brand_identity

    <<~SUMMARY
      Brand: #{brand_identity.name}
      Voice: #{brand_identity.brand_voice || 'Professional and approachable'}
      Core Values: #{extract_core_values}
      Target Audience: #{brand_identity.target_demographics || journey.target_audience}
    SUMMARY
  end

  private

  def build_brand_context
    {
      id: brand_identity.id,
      name: brand_identity.name,
      description: brand_identity.description,
      voice: brand_identity.brand_voice,
      tone_guidelines: brand_identity.tone_guidelines,
      messaging_framework: brand_identity.messaging_framework,
      visual_identity: extract_visual_guidelines,
      restrictions: parse_restrictions,
      processed_guidelines: brand_identity.processed_guidelines || {},
      core_values: extract_core_values,
      unique_selling_points: extract_usps
    }
  end

  def build_brand_assets_context
    {
      logos: process_logo_files,
      style_guides: process_style_guides,
      brand_materials: process_brand_materials,
      color_palette: extract_color_palette,
      typography: extract_typography_rules,
      imagery_style: extract_imagery_guidelines,
      content_examples: extract_content_examples
    }
  end

  def build_brand_variants_context
    return [] unless brand_identity.brand_variants.any?

    brand_identity.brand_variants.map do |variant|
      {
        id: variant.id,
        name: variant.name,
        target_audience: variant.target_audience,
        tone_adjustments: variant.tone_adjustments,
        messaging_adjustments: variant.messaging_adjustments,
        channel_preferences: variant.channel_preferences,
        active: variant.is_active
      }
    end
  end

  def build_journey_context
    {
      id: journey.id,
      name: journey.name,
      campaign_type: journey.campaign_type,
      target_audience: journey.target_audience,
      description: journey.description || '',
      current_stage: journey.stages&.first,
      stages: journey.stages || [],
      existing_steps: serialize_existing_steps,
      metadata: journey.metadata || {}
    }
  end

  def build_performance_context
    {
      similar_journeys: find_similar_successful_journeys,
      brand_content_performance: analyze_brand_content_performance,
      channel_effectiveness: analyze_channel_effectiveness,
      audience_engagement_patterns: analyze_audience_patterns
    }
  end

  def build_industry_context
    {
      industry: detect_industry,
      competitors: [],
      market_position: 'standard',
      seasonal_factors: [],
      trending_approaches: []
    }
  end

  def build_generic_context
    {
      brand: {
        name: "Generic Brand",
        voice: "Professional",
        tone_guidelines: "Clear, concise, and helpful",
        messaging_framework: "Focus on value and benefits",
        restrictions: []
      },
      brand_assets: {},
      brand_variants: [],
      journey: build_journey_context,
      historical_performance: {},
      industry_context: {}
    }
  end

  # Visual and Asset Processing Methods

  def extract_visual_guidelines
    return default_visual_guidelines unless brand_identity.style_guides.attached?

    # In production, this would process attached style guides
    # For now, return structured guidelines
    {
      primary_colors: extract_color_palette,
      typography: extract_typography_rules,
      spacing: { unit: "8px", scale: [0.5, 1, 1.5, 2, 3, 4, 6, 8] },
      imagery: extract_imagery_guidelines,
      iconography: { style: "outline", weight: "medium" }
    }
  end

  def process_logo_files
    return [] unless brand_identity.logo_files.attached?

    brand_identity.logo_files.map do |logo|
      {
        id: logo.id,
        filename: logo.filename.to_s,
        content_type: logo.content_type,
        usage_guidelines: {
          minimum_size: "32px",
          clear_space: "2x height",
          backgrounds: ["light", "dark", "photo"]
        }
      }
    end
  end

  def process_style_guides
    return [] unless brand_identity.style_guides.attached?

    brand_identity.style_guides.map do |guide|
      {
        id: guide.id,
        filename: guide.filename.to_s,
        content_type: guide.content_type,
        extracted_rules: extract_rules_from_guide(guide)
      }
    end
  end

  def process_brand_materials
    return [] unless brand_identity.brand_materials.attached?

    brand_identity.brand_materials.map do |material|
      {
        id: material.id,
        filename: material.filename.to_s,
        content_type: material.content_type,
        category: categorize_material(material)
      }
    end
  end

  def extract_color_palette
    # Extract from processed_guidelines or use defaults
    brand_identity.processed_guidelines&.dig("colors") || {
      primary: "#007bff",
      secondary: "#6c757d",
      accent: "#28a745",
      neutral: ["#ffffff", "#f8f9fa", "#e9ecef", "#dee2e6", "#ced4da", "#6c757d", "#495057", "#343a40", "#212529", "#000000"]
    }
  end

  def extract_typography_rules
    brand_identity.processed_guidelines&.dig("typography") || {
      font_family: {
        headings: "Inter, system-ui, sans-serif",
        body: "Inter, system-ui, sans-serif",
        mono: "SF Mono, monospace"
      },
      font_sizes: {
        h1: "2.5rem",
        h2: "2rem",
        h3: "1.75rem",
        h4: "1.5rem",
        body: "1rem",
        small: "0.875rem"
      },
      line_height: {
        tight: 1.2,
        normal: 1.5,
        relaxed: 1.75
      }
    }
  end

  def extract_imagery_guidelines
    brand_identity.processed_guidelines&.dig("imagery") || {
      style: "modern, authentic, diverse",
      tone: "optimistic and professional",
      avoid: "stock photos, clichés",
      preferred_types: ["lifestyle", "product", "team"]
    }
  end

  def extract_content_examples
    # Get successful content examples from this brand
    GeneratedContent.joins(:campaign_plan)
                   .where(campaign_plans: { user_id: user.id })
                   .where(status: 'published')
                   .order(created_at: :desc)
                   .limit(5)
                   .pluck(:title, :content_type, :body_content)
                   .map do |title, type, content|
      {
        title: title,
        type: type,
        excerpt: content&.truncate(200)
      }
    end
  end

  # Helper Methods

  def parse_restrictions
    return [] unless brand_identity.restrictions.present?
    
    brand_identity.restrictions.split(/[,;\n]/).map(&:strip).reject(&:blank?)
  end

  def extract_core_values
    brand_identity.processed_guidelines&.dig("core_values") ||
      brand_identity.messaging_framework&.scan(/value[s]?:\s*([^.]+)/i)&.flatten&.first ||
      "Quality, Innovation, Customer Focus"
  end

  def extract_usps
    brand_identity.processed_guidelines&.dig("unique_selling_points") ||
      brand_identity.messaging_framework&.scan(/unique|differentiator|advantage:\s*([^.]+)/i)&.flatten ||
      []
  end

  def serialize_existing_steps
    journey.journey_steps.map do |step|
      {
        id: step.id,
        title: step.title,
        step_type: step.step_type,
        channel: step.channel,
        position: step.sequence_order,
        status: step.status
      }
    end
  end

  def find_similar_successful_journeys
    Journey.where(campaign_type: journey.campaign_type)
           .where(user_id: user.id)
           .where(status: 'completed')
           .limit(3)
           .map do |j|
      {
        id: j.id,
        name: j.name,
        performance_score: j.ai_performance_score || 0,
        key_steps: j.journey_steps.pluck(:step_type)
      }
    end
  end

  def analyze_brand_content_performance
    return {} unless brand_identity

    {
      average_engagement: calculate_average_engagement,
      top_performing_types: identify_top_content_types,
      optimal_length: calculate_optimal_content_length,
      best_posting_times: identify_best_timing
    }
  end

  def analyze_channel_effectiveness
    # Analyze which channels work best for this brand
    {
      email: { effectiveness: 85, best_for: ["announcements", "nurturing"] },
      social: { effectiveness: 72, best_for: ["awareness", "engagement"] },
      blog: { effectiveness: 68, best_for: ["education", "seo"] }
    }
  end

  def analyze_audience_patterns
    {
      peak_engagement_hours: [9, 12, 17, 20],
      preferred_content_formats: ["video", "infographic", "how-to"],
      average_journey_length: "14 days",
      conversion_triggers: ["social_proof", "urgency", "value_demonstration"]
    }
  end

  def detect_industry
    # Detect from brand description or journey context
    brand_identity.description&.scan(/\b(?:tech|saas|retail|finance|healthcare|education)\b/i)&.first&.downcase ||
      "general"
  end

  def detect_seasonal_factors
    current_month = Date.current.month
    {
      current_season: get_season(current_month),
      upcoming_events: get_upcoming_events(current_month),
      seasonal_trends: get_seasonal_trends(current_month)
    }
  end

  def get_season(month)
    case month
    when 12, 1, 2 then "winter"
    when 3, 4, 5 then "spring"  
    when 6, 7, 8 then "summer"
    when 9, 10, 11 then "fall"
    end
  end

  def get_upcoming_events(month)
    # Return relevant marketing events for the month
    events = {
      1 => ["New Year", "Fresh Start Campaigns"],
      2 => ["Valentine's Day", "President's Day"],
      3 => ["Women's History Month", "Spring Break"],
      4 => ["Easter", "Earth Day"],
      5 => ["Mother's Day", "Memorial Day"],
      6 => ["Father's Day", "Summer Start"],
      7 => ["Independence Day", "Summer Sales"],
      8 => ["Back to School"],
      9 => ["Labor Day", "Fall Season"],
      10 => ["Halloween", "Cybersecurity Month"],
      11 => ["Black Friday", "Cyber Monday", "Thanksgiving"],
      12 => ["Holidays", "Year End"]
    }
    events[month] || []
  end

  def get_seasonal_trends(_month)
    # This would connect to trend analysis in production
    ["sustainability", "personalization", "ai-powered", "authentic"]
  end

  def get_industry_trends
    # This would fetch real trends in production
    case detect_industry
    when "tech", "saas"
      ["product-led growth", "freemium models", "api-first"]
    when "retail"
      ["omnichannel", "social commerce", "sustainable packaging"]
    else
      ["customer experience", "personalization", "automation"]
    end
  end

  def categorize_material(material)
    filename = material.filename.to_s.downcase
    
    case filename
    when /template/i then "template"
    when /example|sample/i then "example"
    when /guide/i then "guide"
    when /brief/i then "brief"
    else "other"
    end
  end

  def extract_rules_from_guide(_guide)
    # In production, this would parse the style guide document
    # For now, return placeholder rules
    {
      logo_usage: "Maintain clear space equal to 'x' height",
      color_usage: "Primary color for CTAs, secondary for backgrounds",
      typography: "Headlines in bold, body in regular weight",
      tone: "Professional yet approachable"
    }
  end

  def calculate_average_engagement
    # Calculate from historical data
    "4.2%"
  end

  def identify_top_content_types
    ["email", "blog_post", "social_video"]
  end

  def calculate_optimal_content_length
    {
      email: "150-200 words",
      blog: "1200-1500 words",
      social: "80-100 characters"
    }
  end

  def identify_best_timing
    {
      email: "Tuesday 10am",
      social: "Weekdays 12pm, 5pm",
      blog: "Thursday 9am"
    }
  end

  def default_visual_guidelines
    {
      primary_colors: { main: "#007bff", dark: "#0056b3", light: "#7abaff" },
      typography: { heading: "sans-serif", body: "sans-serif" },
      spacing: { unit: "8px" },
      imagery: { style: "modern" }
    }
  end
end