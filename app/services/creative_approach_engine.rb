class CreativeApproachEngine
  def initialize(campaign)
    @campaign = campaign
    @llm_service = LlmService.new(temperature: 0.8) # Higher temperature for creativity
  end

  def thread_across_phases
    {
      core_creative_concept: develop_core_creative_concept,
      visual_identity: design_visual_identity,
      messaging_hierarchy: create_messaging_hierarchy,
      phase_adaptations: adapt_creative_across_phases
    }
  end

  def ensure_channel_consistency
    {
      channel_adaptations: adapt_creative_by_channel,
      consistent_elements: define_consistent_elements,
      flexible_elements: define_flexible_elements,
      brand_guidelines: establish_brand_guidelines
    }
  end

  def develop_visual_identity
    prompt = build_visual_identity_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    {
      color_palette: parsed_response['color_palette'] || build_default_color_palette,
      typography: parsed_response['typography'] || build_default_typography,
      imagery_style: parsed_response['imagery_style'] || build_default_imagery_style,
      logo_treatment: parsed_response['logo_treatment'] || build_default_logo_treatment,
      iconography: parsed_response['iconography'] || build_default_iconography,
      layout_principles: parsed_response['layout_principles'] || build_default_layout_principles
    }
  end

  def create_messaging_hierarchy
    prompt = build_messaging_hierarchy_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    {
      primary_message: parsed_response['primary_message'] || build_primary_message,
      secondary_messages: parsed_response['secondary_messages'] || build_secondary_messages,
      supporting_messages: parsed_response['supporting_messages'] || build_supporting_messages,
      proof_points: parsed_response['proof_points'] || build_proof_points,
      call_to_action_hierarchy: parsed_response['call_to_action_hierarchy'] || build_cta_hierarchy,
      tone_variations: parsed_response['tone_variations'] || build_tone_variations
    }
  end

  private

  def develop_core_creative_concept
    prompt = build_creative_concept_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    {
      main_theme: parsed_response['main_theme'] || build_default_theme,
      creative_direction: parsed_response['creative_direction'] || build_default_direction,
      emotional_appeal: parsed_response['emotional_appeal'] || build_emotional_appeal,
      narrative_structure: parsed_response['narrative_structure'] || build_narrative_structure,
      key_visuals: parsed_response['key_visuals'] || build_key_visuals,
      content_pillars: parsed_response['content_pillars'] || build_content_pillars
    }
  end

  def design_visual_identity
    {
      color_palette: determine_color_palette,
      typography: select_typography,
      imagery_style: define_imagery_style,
      visual_elements: create_visual_elements,
      brand_expression: establish_brand_expression
    }
  end

  def adapt_creative_across_phases
    phases = get_campaign_phases
    
    phases.map do |phase|
      {
        phase_name: phase[:name],
        creative_focus: determine_phase_creative_focus(phase),
        messaging_emphasis: determine_messaging_emphasis(phase),
        visual_treatment: adapt_visual_treatment(phase),
        content_formats: recommend_content_formats(phase),
        engagement_tactics: suggest_engagement_tactics(phase)
      }
    end
  end

  def adapt_creative_by_channel
    channels = get_campaign_channels
    
    channels.each_with_object({}) do |channel, adaptations|
      adaptations[channel] = {
        format_requirements: get_channel_format_requirements(channel),
        message_adaptation: adapt_message_for_channel(channel),
        visual_adaptation: adapt_visuals_for_channel(channel),
        content_specifications: get_channel_content_specs(channel),
        optimization_considerations: get_channel_optimization_tips(channel)
      }
    end
  end

  def define_consistent_elements
    {
      brand_colors: "Consistent color palette across all materials",
      logo_usage: "Standardized logo placement and sizing",
      typography: "Consistent font family and hierarchy",
      messaging_tone: "Unified brand voice and personality",
      visual_style: "Consistent imagery style and treatment",
      core_messaging: "Key value propositions remain constant"
    }
  end

  def define_flexible_elements
    {
      channel_formatting: "Adapt to platform-specific requirements",
      message_length: "Vary copy length based on channel constraints",
      visual_composition: "Adjust layouts for different screen sizes",
      content_depth: "Tailor detail level to audience engagement stage",
      interaction_methods: "Customize calls-to-action per platform",
      localization: "Adapt language and cultural references as needed"
    }
  end

  def establish_brand_guidelines
    {
      logo_guidelines: {
        minimum_size: "20px height for digital, 0.5 inch for print",
        clear_space: "Minimum clear space equal to logo height",
        color_variations: "Primary, secondary, and monochrome versions",
        usage_restrictions: "No distortion, rotation, or color changes"
      },
      color_specifications: {
        primary_palette: determine_color_palette[:primary],
        secondary_palette: determine_color_palette[:secondary],
        usage_ratios: "Primary 60%, Secondary 30%, Accent 10%",
        accessibility: "Ensure WCAG AA compliance for text contrast"
      },
      typography_system: {
        heading_fonts: select_typography[:headings],
        body_fonts: select_typography[:body],
        hierarchy_rules: "H1 largest, consistent scale factor 1.25",
        usage_guidelines: "Headings for impact, body for readability"
      },
      imagery_standards: {
        style_description: define_imagery_style,
        composition_rules: "Rule of thirds, consistent lighting",
        color_treatment: "Consistent filter and color grading",
        subject_matter: "Real people, authentic scenarios"
      }
    }
  end

  def build_creative_concept_prompt
    <<~PROMPT
      Develop a core creative concept for a #{@campaign.campaign_type} campaign.

      Campaign Details:
      - Name: #{@campaign.name}
      - Type: #{@campaign.campaign_type}
      - Target: #{@campaign.persona&.name || 'Target audience'}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please create a compelling creative concept including:
      1. Main creative theme that ties everything together
      2. Creative direction and approach
      3. Emotional appeal and connection points
      4. Narrative structure and storytelling approach
      5. Key visual concepts and imagery ideas
      6. Content pillars and themes

      JSON structure:
      {
        "main_theme": "central creative theme",
        "creative_direction": "overall creative approach",
        "emotional_appeal": "emotional connection strategy",
        "narrative_structure": "storytelling framework",
        "key_visuals": ["visual1", "visual2", "visual3"],
        "content_pillars": ["pillar1", "pillar2", "pillar3"]
      }
    PROMPT
  end

  def build_visual_identity_prompt
    <<~PROMPT
      Design a visual identity system for a #{@campaign.campaign_type} campaign targeting #{@campaign.persona&.name || 'target audience'}.

      Campaign Context:
      - Industry: #{@campaign.persona&.industry || 'Technology'}
      - Campaign Type: #{@campaign.campaign_type}
      - Brand Personality: Professional, innovative, trustworthy

      Please specify:
      1. Color palette (primary, secondary, accent colors)
      2. Typography recommendations (headings and body text)
      3. Imagery style and treatment
      4. Logo treatment and usage
      5. Iconography style
      6. Layout principles and composition

      JSON structure:
      {
        "color_palette": {"primary": ["color1", "color2"], "secondary": ["color3", "color4"]},
        "typography": {"headings": "font family", "body": "font family"},
        "imagery_style": "style description",
        "logo_treatment": "treatment guidelines",
        "iconography": "icon style description",
        "layout_principles": ["principle1", "principle2"]
      }
    PROMPT
  end

  def build_messaging_hierarchy_prompt
    <<~PROMPT
      Create a messaging hierarchy for a #{@campaign.campaign_type} campaign.

      Campaign Details:
      - Target: #{@campaign.persona&.name || 'Target audience'}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please develop:
      1. Primary message (main value proposition)
      2. Secondary messages (key benefits)
      3. Supporting messages (proof points and details)
      4. Proof points and credibility statements
      5. Call-to-action hierarchy (primary, secondary, micro-CTAs)
      6. Tone variations for different contexts

      JSON structure:
      {
        "primary_message": "main message",
        "secondary_messages": ["message1", "message2"],
        "supporting_messages": ["support1", "support2", "support3"],
        "proof_points": ["proof1", "proof2"],
        "call_to_action_hierarchy": {"primary": "main CTA", "secondary": "secondary CTA"},
        "tone_variations": {"formal": "formal tone", "casual": "casual tone"}
      }
    PROMPT
  end

  def parse_llm_response(response)
    if response.is_a?(String)
      JSON.parse(response) rescue {}
    else
      response || {}
    end
  end

  def build_default_theme
    case @campaign.campaign_type
    when 'product_launch'
      "Innovation meets excellence - transforming the way you work"
    when 'brand_awareness'
      "Your trusted partner in success - reliable, innovative, forward-thinking"
    when 'lead_generation'
      "Unlock your potential - expert solutions for modern challenges"
    when 'event_promotion'
      "Connect, learn, grow - where industry leaders come together"
    else
      "Excellence in action - delivering results that matter"
    end
  end

  def build_default_direction
    "Clean, modern, professional aesthetic with authentic human elements and real-world applications showcasing transformation and success."
  end

  def build_emotional_appeal
    {
      primary_emotion: "Confidence and empowerment",
      secondary_emotions: ["Trust", "Excitement", "Achievement"],
      emotional_triggers: ["Success stories", "Transformation", "Community", "Recognition"],
      connection_points: ["Professional growth", "Business success", "Industry leadership"]
    }
  end

  def build_narrative_structure
    {
      story_arc: "Challenge → Solution → Transformation → Success",
      key_characters: ["Industry professionals", "Business leaders", "Success stories"],
      setting: "Modern business environment with real-world applications",
      conflict: "Common industry challenges and pain points",
      resolution: "Clear path to success with measurable outcomes"
    }
  end

  def build_key_visuals
    [
      "Professional team collaboration in modern workspace",
      "Data visualization and analytics dashboards",
      "Before/after transformation scenarios",
      "Customer testimonials and success celebrations",
      "Technology integration and innovation"
    ]
  end

  def build_content_pillars
    [
      "Industry expertise and thought leadership",
      "Customer success stories and results",
      "Innovation and product excellence",
      "Community and partnership",
      "Educational insights and best practices"
    ]
  end

  def determine_color_palette
    case @campaign.campaign_type
    when 'product_launch'
      {
        primary: ["#0066CC", "#004499"], # Professional blues
        secondary: ["#00AA44", "#FF6600"], # Success green, energy orange
        accent: ["#F0F8FF", "#E6F3FF"], # Light accent colors
        neutral: ["#333333", "#666666", "#CCCCCC"] # Text and background
      }
    when 'brand_awareness'
      {
        primary: ["#1F4E79", "#2E5984"], # Trust blues
        secondary: ["#28A745", "#FFC107"], # Growth green, optimism yellow
        accent: ["#F8F9FA", "#E9ECEF"], # Clean backgrounds
        neutral: ["#212529", "#6C757D", "#DEE2E6"] # Text hierarchy
      }
    else
      {
        primary: ["#007BFF", "#0056B3"], # Standard blues
        secondary: ["#28A745", "#DC3545"], # Success and alert
        accent: ["#17A2B8", "#6F42C1"], # Info and brand accent
        neutral: ["#343A40", "#6C757D", "#CED4DA"] # Neutral scale
      }
    end
  end

  def select_typography
    {
      headings: "Inter, Helvetica, Arial, sans-serif",
      body: "Source Sans Pro, Helvetica, Arial, sans-serif",
      accent: "Poppins, sans-serif",
      hierarchy: {
        h1: "48px, bold, 1.2 line-height",
        h2: "36px, semi-bold, 1.3 line-height",
        h3: "24px, medium, 1.4 line-height",
        body: "16px, regular, 1.6 line-height"
      }
    }
  end

  def define_imagery_style
    "Authentic, professional photography featuring real people in natural work environments. Clean, modern aesthetic with good lighting and authentic emotions. Avoid overly staged or stock-photo appearance."
  end

  def create_visual_elements
    {
      icons: "Line-style icons with consistent stroke width",
      illustrations: "Modern, minimal style supporting photography",
      graphics: "Clean data visualizations and infographics",
      patterns: "Subtle geometric patterns for backgrounds",
      textures: "Minimal, professional textures when needed"
    }
  end

  def establish_brand_expression
    {
      personality: "Professional, approachable, innovative, trustworthy",
      voice: "Confident but not arrogant, helpful, expert",
      tone: "Conversational yet professional, encouraging",
      style: "Clear, direct communication with human warmth"
    }
  end

  def get_campaign_phases
    [
      { name: "Awareness", objective: "Generate awareness and interest" },
      { name: "Consideration", objective: "Educate and nurture prospects" },
      { name: "Decision", objective: "Drive conversion and action" },
      { name: "Retention", objective: "Maintain engagement and satisfaction" }
    ]
  end

  def determine_phase_creative_focus(phase)
    case phase[:name]
    when "Awareness"
      "Bold, attention-grabbing visuals with broad appeal and emotional connection"
    when "Consideration"
      "Educational and informative content with detailed product/service showcases"
    when "Decision"
      "Trust-building elements, testimonials, and clear value propositions"
    when "Retention"
      "Community-focused content and ongoing value demonstration"
    else
      "Balanced approach with clear messaging and professional presentation"
    end
  end

  def determine_messaging_emphasis(phase)
    case phase[:name]
    when "Awareness"
      "Problem identification and brand introduction"
    when "Consideration"
      "Solution explanation and benefit demonstration"
    when "Decision"
      "Proof points, testimonials, and clear next steps"
    when "Retention"
      "Ongoing value and community building"
    else
      "Clear value proposition and call-to-action"
    end
  end

  def adapt_visual_treatment(phase)
    case phase[:name]
    when "Awareness"
      "High contrast, bold visuals with emotional appeal"
    when "Consideration"
      "Detailed product shots, infographics, educational visuals"
    when "Decision"
      "Professional testimonials, awards, certifications"
    when "Retention"
      "Community images, success celebrations, behind-the-scenes"
    else
      "Clean, professional presentation with clear hierarchy"
    end
  end

  def recommend_content_formats(phase)
    case phase[:name]
    when "Awareness"
      ["Social media posts", "Display ads", "Video teasers", "Blog posts"]
    when "Consideration"
      ["Whitepapers", "Webinars", "Product demos", "Comparison guides"]
    when "Decision"
      ["Case studies", "Testimonials", "ROI calculators", "Free trials"]
    when "Retention"
      ["Newsletters", "Community content", "Success stories", "Educational content"]
    else
      ["Mixed content formats", "Multi-channel approach"]
    end
  end

  def suggest_engagement_tactics(phase)
    case phase[:name]
    when "Awareness"
      ["Hashtag campaigns", "Influencer partnerships", "Viral content"]
    when "Consideration"
      ["Gated content", "Email nurturing", "Retargeting campaigns"]
    when "Decision"
      ["Personalized demos", "Sales calls", "Limited-time offers"]
    when "Retention"
      ["User-generated content", "Loyalty programs", "Exclusive events"]
    else
      ["Multi-touchpoint engagement", "Personalized communication"]
    end
  end

  def get_campaign_channels
    @campaign.target_metrics&.dig('channels') || ['email', 'social_media', 'content_marketing', 'search']
  end

  def get_channel_format_requirements(channel)
    case channel
    when 'social_media'
      { image_sizes: "1200x630 (Facebook), 1080x1080 (Instagram)", character_limits: "280 (Twitter), 2200 (LinkedIn)" }
    when 'email'
      { width: "600px max", subject_line: "50 characters max", preview_text: "90 characters" }
    when 'display_ads'
      { sizes: "728x90, 300x250, 320x50", file_size: "150KB max", formats: "JPG, PNG, GIF" }
    when 'search'
      { headlines: "30 characters each", descriptions: "90 characters", extensions: "25 characters" }
    else
      { format: "Standard web formats", optimization: "Mobile-responsive design" }
    end
  end

  def adapt_message_for_channel(channel)
    case channel
    when 'social_media'
      "Conversational, engaging tone with hashtags and social elements"
    when 'email'
      "Personal, direct communication with clear subject line and preview"
    when 'search'
      "Keyword-optimized, benefit-focused messaging with clear CTAs"
    when 'display_ads'
      "Brief, impactful messaging with strong visual hierarchy"
    else
      "Channel-appropriate tone and messaging optimization"
    end
  end

  def adapt_visuals_for_channel(channel)
    case channel
    when 'social_media'
      "Square and vertical formats, bold visuals, social-friendly design"
    when 'email'
      "Header images, inline graphics, mobile-optimized layouts"
    when 'search'
      "Minimal visuals, text-focused, clean and professional"
    when 'display_ads'
      "Eye-catching graphics, clear branding, animation where appropriate"
    else
      "Platform-optimized visual treatments"
    end
  end

  def get_channel_content_specs(channel)
    case channel
    when 'social_media'
      { posts_per_week: 3-5, optimal_times: "Business hours, lunch, evening", engagement_focus: "High" }
    when 'email'
      { frequency: "Weekly or bi-weekly", optimal_days: "Tuesday-Thursday", personalization: "High" }
    when 'search'
      { ad_groups: "Tightly themed", keywords: "High-intent", landing_pages: "Relevant and optimized" }
    when 'content_marketing'
      { frequency: "2-3 posts per week", length: "1000-2000 words", SEO_focus: "High" }
    else
      { best_practices: "Follow platform guidelines", optimization: "Continuous testing and improvement" }
    end
  end

  def get_channel_optimization_tips(channel)
    case channel
    when 'social_media'
      ["Use platform-native features", "Test posting times", "Engage with comments quickly"]
    when 'email'
      ["A/B test subject lines", "Optimize for mobile", "Segment audiences"]
    when 'search'
      ["Monitor quality scores", "Test ad copy variations", "Optimize landing pages"]
    when 'display_ads'
      ["Test multiple creative sizes", "Use retargeting", "Monitor viewability"]
    else
      ["Regular performance monitoring", "Continuous testing", "Data-driven optimization"]
    end
  end

  def build_default_color_palette
    {
      primary: ["#007BFF", "#0056B3"],
      secondary: ["#28A745", "#FFC107"],
      accent: ["#17A2B8", "#6F42C1"],
      neutral: ["#343A40", "#6C757D", "#CED4DA"]
    }
  end

  def build_default_typography
    {
      headings: "Inter, Helvetica, Arial, sans-serif",
      body: "Source Sans Pro, Helvetica, Arial, sans-serif"
    }
  end

  def build_default_imagery_style
    "Professional, authentic photography with modern, clean aesthetic"
  end

  def build_default_logo_treatment
    "Clean, minimal treatment with proper spacing and contrast"
  end

  def build_default_iconography
    "Line-style icons with consistent stroke width and modern appearance"
  end

  def build_default_layout_principles
    ["Clean hierarchy", "Generous white space", "Consistent grid system", "Mobile-first design"]
  end

  def build_primary_message
    "Transform your business with innovative solutions that deliver real results"
  end

  def build_secondary_messages
    [
      "Proven track record of success",
      "Expert support and guidance",
      "Scalable solutions for growth"
    ]
  end

  def build_supporting_messages
    [
      "Join thousands of satisfied customers",
      "Award-winning products and services",
      "24/7 support and customer success"
    ]
  end

  def build_proof_points
    [
      "95% customer satisfaction rate",
      "Industry-leading security and compliance",
      "Trusted by Fortune 500 companies"
    ]
  end

  def build_cta_hierarchy
    {
      primary: "Get Started Today",
      secondary: "Learn More",
      tertiary: "Contact Us"
    }
  end

  def build_tone_variations
    {
      formal: "Professional, authoritative, industry-focused",
      casual: "Friendly, approachable, conversational",
      urgent: "Action-oriented, time-sensitive, compelling"
    }
  end
end