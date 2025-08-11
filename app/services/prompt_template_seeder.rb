class PromptTemplateSeeder
  def self.seed_default_templates
    templates = [
      {
        name: "Campaign Planning",
        prompt_type: "campaign_planning",
        category: "strategy",
        system_prompt: <<~SYSTEM,
          You are a marketing strategist AI that creates comprehensive campaign plans.
          
          Your responses should be well-structured JSON with the following format:
          {
            "campaign_overview": "Brief description of the campaign strategy",
            "target_audience": "Primary audience description", 
            "key_messages": ["message 1", "message 2", "message 3"],
            "channels": {
              "email": { "strategy": "...", "content_ideas": [...] },
              "social_media": { "strategy": "...", "content_ideas": [...] },
              "web": { "strategy": "...", "content_ideas": [...] }
            },
            "timeline": {
              "planning_phase": "timeframe",
              "execution_phase": "timeframe",
              "analysis_phase": "timeframe"
            },
            "success_metrics": ["metric 1", "metric 2", "metric 3"],
            "budget_recommendations": {
              "channel_allocation": {...},
              "priority_areas": [...]
            }
          }
          
          Focus on practical, actionable strategies that align with modern marketing best practices.
        SYSTEM
        user_prompt: <<~USER,
          Create a comprehensive marketing campaign plan for:
          
          Campaign Name: {{campaign_name}}
          Purpose: {{campaign_purpose}}
          Budget: {{budget}}
          Duration: {{start_date}} to {{end_date}}
          Target Audience: {{target_audience}}
          
          Brand Context:
          {{brand_context}}
          
          {{additional_requirements}}
          
          Please provide a detailed campaign strategy that includes target audience analysis, key messaging, channel recommendations, timeline, success metrics, and budget allocation suggestions.
          
          Focus on actionable strategies that can be implemented effectively within the given constraints.
        USER
        description: "Comprehensive campaign planning template for creating marketing strategies",
        temperature: 0.3,
        max_tokens: 3000,
        tags: "strategy,planning,campaign"
      },
      
      {
        name: "Brand Analysis", 
        prompt_type: "brand_analysis",
        category: "analysis",
        system_prompt: <<~SYSTEM,
          You are a brand analysis AI that extracts insights from brand assets and documents.
          
          Analyze the provided brand materials and return structured JSON with:
          {
            "brand_voice": "Description of brand personality and tone",
            "key_themes": ["theme 1", "theme 2", "theme 3"],
            "target_demographics": "Inferred target audience",
            "competitive_advantages": ["advantage 1", "advantage 2"],
            "brand_guidelines": {
              "tone_of_voice": "...",
              "messaging_style": "...", 
              "content_restrictions": [...]
            },
            "content_opportunities": ["opportunity 1", "opportunity 2"],
            "compliance_considerations": ["consideration 1", "consideration 2"],
            "recommendations": {
              "content_strategy": "...",
              "messaging_improvements": [...],
              "channel_optimization": [...]
            }
          }
          
          Base your analysis strictly on the provided materials without making assumptions.
        SYSTEM
        user_prompt: <<~USER,
          Analyze the following brand assets and extract key insights:
          
          {{brand_assets}}
          
          Focus your analysis on: {{focus_areas}}
          
          {{technical_context}}
          
          Provide insights that can inform content creation and marketing strategy decisions.
          Include specific recommendations for improving brand consistency and messaging effectiveness.
        USER
        description: "Brand asset analysis template for extracting marketing insights",
        temperature: 0.4,
        max_tokens: 2000,
        tags: "analysis,brand,insights"
      },
      
      {
        name: "Social Media Content",
        prompt_type: "social_media",
        category: "content",
        system_prompt: "You are a social media content creator. Generate engaging, shareable content optimized for social media platforms with appropriate hashtags and calls-to-action. Focus on creating content that drives engagement, builds community, and aligns with platform best practices.",
        user_prompt: <<~USER,
          Create {{content_type}} content for {{platform}} social media.
          
          Brand Context:
          {{brand_context}}
          
          Campaign Details:
          - Campaign: {{campaign_name}}
          - Goal: {{campaign_goal}}
          - Target Audience: {{target_audience}}
          - Tone: {{tone}}
          
          Content Requirements:
          - Length: {{content_length}}
          - Include: {{required_elements}}
          - Avoid: {{restrictions}}
          
          {{additional_context}}
          
          Please create content that is engaging, on-brand, and optimized for {{platform}}.
          Include relevant hashtags and a clear call-to-action.
        USER
        description: "Social media content generation for various platforms",
        temperature: 0.8,
        max_tokens: 500,
        tags: "social,content,engagement"
      },
      
      {
        name: "Email Marketing",
        prompt_type: "email_marketing", 
        category: "email",
        system_prompt: "You are an email marketing specialist. Create compelling email content that drives engagement and conversions while following email marketing best practices. Focus on subject lines, personalization, clear CTAs, and mobile optimization.",
        user_prompt: <<~USER,
          Create an email {{email_type}} for our marketing campaign.
          
          Campaign Context:
          {{campaign_context}}
          
          Email Details:
          - Subject Focus: {{subject_focus}}
          - Primary Goal: {{primary_goal}}
          - Target Segment: {{target_segment}}
          - Send Time: {{send_timing}}
          
          Brand Voice: {{brand_voice}}
          
          Content Requirements:
          - Tone: {{tone}}
          - Length: {{content_length}}
          - CTA: {{call_to_action}}
          - Personalization: {{personalization_level}}
          
          {{special_requirements}}
          
          Create an effective email that includes:
          1. Compelling subject line
          2. Engaging email body
          3. Clear call-to-action
          4. Mobile-friendly format
        USER
        description: "Email marketing content generation template",
        temperature: 0.6,
        max_tokens: 1200,
        tags: "email,marketing,conversion"
      },
      
      {
        name: "Landing Page Copy",
        prompt_type: "landing_page",
        category: "web",
        system_prompt: "You are a landing page copywriter specialist. Create high-converting landing page content that is clear, compelling, and action-oriented. Focus on headlines, benefits, social proof, and strong calls-to-action that drive conversions.",
        user_prompt: <<~USER,
          Create landing page copy for {{page_purpose}}.
          
          Product/Service: {{offering}}
          Target Audience: {{target_audience}}
          Primary Goal: {{conversion_goal}}
          
          Brand Context:
          {{brand_context}}
          
          Page Sections Needed:
          {{page_sections}}
          
          Key Benefits:
          {{key_benefits}}
          
          Social Proof Available:
          {{social_proof}}
          
          Competitive Advantages:
          {{competitive_advantages}}
          
          Call-to-Action: {{cta_text}}
          
          {{additional_requirements}}
          
          Create compelling copy that includes:
          1. Attention-grabbing headline
          2. Clear value proposition
          3. Benefit-focused content
          4. Trust elements and social proof
          5. Strong, action-oriented CTA
          6. Mobile-optimized structure
        USER
        description: "Landing page copywriting template for conversions",
        temperature: 0.7,
        max_tokens: 2000,
        tags: "landing,conversion,copywriting"
      },
      
      {
        name: "Ad Copy Generator",
        prompt_type: "ad_copy",
        category: "advertising",
        system_prompt: "You are an advertising copywriter. Create compelling ad copy that captures attention, communicates value, and drives action. Focus on headline impact, benefit clarity, emotional triggers, and strong calls-to-action within character limits.",
        user_prompt: <<~USER,
          Create {{ad_type}} ad copy for {{platform}}.
          
          Campaign: {{campaign_name}}
          Product/Service: {{offering}}
          Target Audience: {{target_audience}}
          
          Ad Specifications:
          - Character Limit: {{character_limit}}
          - Headlines Needed: {{headline_count}}
          - Description Lines: {{description_count}}
          
          Key Messages:
          {{key_messages}}
          
          Unique Selling Points:
          {{usp}}
          
          Emotional Triggers:
          {{emotional_hooks}}
          
          Call-to-Action: {{cta}}
          
          Brand Voice: {{brand_voice}}
          
          {{platform_requirements}}
          
          Create multiple variations of ad copy optimized for {{platform}}.
          Focus on attention-grabbing headlines and compelling descriptions that drive clicks.
        USER
        description: "Advertisement copy generation for multiple platforms",
        temperature: 0.8,
        max_tokens: 800,
        tags: "advertising,copy,conversion"
      }
    ]

    created_count = 0
    
    templates.each do |template_data|
      # Check if template already exists
      existing = PromptTemplate.find_by(
        name: template_data[:name], 
        prompt_type: template_data[:prompt_type]
      )
      
      next if existing
      
      template = PromptTemplate.create!(template_data)
      created_count += 1
      
      puts "Created template: #{template.name} (#{template.prompt_type})"
    end
    
    puts "Created #{created_count} new prompt templates"
    created_count
  end

  def self.create_example_variants
    # Create A/B test variants for testing
    base_template = PromptTemplate.find_by(name: "Social Media Content")
    return unless base_template

    # Create a more casual variant
    casual_variant = base_template.create_variant("Casual Tone", {
      system_prompt: base_template.system_prompt.gsub(
        "professional responses",
        "casual, conversational responses"
      ),
      temperature: 0.9
    })

    # Create a formal variant  
    formal_variant = base_template.create_variant("Formal Tone", {
      system_prompt: base_template.system_prompt.gsub(
        "engaging, shareable content",
        "professional, authoritative content"
      ),
      temperature: 0.5
    })

    puts "Created variants for #{base_template.name}: Casual and Formal"
    [casual_variant, formal_variant]
  end
end