# frozen_string_literal: true

# Mock LLM Service implementation for development and testing
# Provides realistic sample content generation without external API calls
class MockLlmService
  include LlmServiceInterface

  def initialize
    @response_delay_range = (0.5..2.0) # Simulate realistic API response times
    @error_simulation_rate = 0.02 # 2% chance of simulated errors
  end

  def generate_social_media_content(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    platform = (params[:platform] || params['platform'])&.to_s || 'general'
    tone = (params[:tone] || params['tone'])&.to_s || 'professional'
    topic = params[:topic] || params['topic'] || 'marketing campaign'
    character_limit = params[:character_limit] || params['character_limit'] || platform_character_limits[platform] || platform_character_limits['general']
    brand_context = params[:brand_context] || params['brand_context'] || {}

    # Apply brand context to tone and content
    effective_tone = apply_brand_voice(tone, brand_context)
    content = generate_social_content(platform, effective_tone, topic, character_limit, brand_context)
    
    {
      content: content,
      metadata: {
        platform: platform,
        tone: effective_tone,
        character_count: content.length,
        character_limit: character_limit,
        brand_voice_applied: brand_context.present?,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_email_content(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    email_type = params[:email_type] || params['email_type'] || 'promotional'
    subject_topic = params[:subject] || params['subject'] || 'marketing campaign'
    tone = params[:tone] || params['tone'] || 'professional'
    brand_context = params[:brand_context] || params['brand_context'] || {}

    # Apply brand context to tone and content
    effective_tone = apply_brand_voice(tone, brand_context)
    subject, content = generate_email_parts(email_type, subject_topic, effective_tone, brand_context)

    {
      subject: subject,
      content: content,
      metadata: {
        email_type: email_type,
        tone: effective_tone,
        word_count: content.split.length,
        brand_voice_applied: brand_context.present?,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_ad_copy(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    ad_type = params[:ad_type] || params['ad_type'] || 'search'
    platform = params[:platform] || params['platform'] || 'google'
    objective = params[:objective] || params['objective'] || 'conversions'
    brand_context = params[:brand_context] || params['brand_context'] || {}

    # Apply brand context to content generation
    headline, description, cta = generate_ad_parts(ad_type, platform, objective, brand_context)

    {
      headline: headline,
      description: description,
      call_to_action: cta,
      metadata: {
        ad_type: ad_type,
        platform: platform,
        objective: objective,
        brand_voice_applied: brand_context.present?,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_landing_page_content(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    page_type = params[:page_type] || params['page_type'] || 'product'
    objective = params[:objective] || params['objective'] || 'conversion'
    key_features = params[:key_features] || params['key_features'] || []
    brand_context = params[:brand_context] || params['brand_context'] || {}

    # Apply brand context to content generation
    headline, subheadline, body, cta = generate_landing_page_parts(page_type, objective, key_features, brand_context)

    {
      headline: headline,
      subheadline: subheadline,
      body: body,
      cta: cta,
      metadata: {
        page_type: page_type,
        objective: objective,
        feature_count: key_features.length,
        brand_voice_applied: brand_context.present?,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_campaign_plan(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    campaign_type = params[:campaign_type] || params['campaign_type'] || 'product_launch'
    objective = params[:objective] || params['objective'] || 'brand_awareness'
    brand_context = params[:brand_context] || params['brand_context'] || {}

    # Apply brand context to campaign planning
    summary, strategy, timeline, assets = generate_campaign_parts(campaign_type, objective, brand_context)

    {
      summary: summary,
      strategy: strategy,
      timeline: timeline,
      assets: assets,
      metadata: {
        campaign_type: campaign_type,
        objective: objective,
        brand_voice_applied: brand_context.present?,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_content_variations(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    original_content = params[:original_content] || params['original_content'] || 'Original content'
    content_type = params[:content_type] || params['content_type'] || 'social_media'
    variant_count = [params[:variant_count] || params['variant_count'] || 3, 10].min # Max 10 variants

    variations = generate_variations(original_content, content_type, variant_count)

    variations.map.with_index do |content, index|
      {
        content: content,
        variant_number: index + 1,
        strategy: variation_strategies[index % variation_strategies.length],
        metadata: {
          content_type: content_type,
          generated_at: Time.current,
          service: 'mock'
        }
      }
    end
  end

  def optimize_content(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    content = params[:content] || params['content'] || 'Sample content'
    content_type = params[:content_type] || params['content_type'] || 'general'
    
    optimized_content, changes = generate_optimizations(content, content_type)

    {
      optimized_content: optimized_content,
      changes: changes,
      metadata: {
        content_type: content_type,
        optimization_count: changes.length,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def check_brand_compliance(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    content = params[:content] || params['content'] || ''
    
    # Simulate brand compliance checking
    issues = simulate_brand_issues(content)
    suggestions = simulate_brand_suggestions(issues)

    {
      compliant: issues.empty?,
      issues: issues,
      suggestions: suggestions,
      metadata: {
        content_length: content.length,
        checks_performed: ['tone', 'terminology', 'format'],
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_analytics_insights(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    time_period = params[:time_period] || params['time_period'] || '30_days'
    metrics = params[:metrics] || params['metrics'] || ['impressions', 'clicks', 'conversions']

    insights, recommendations = generate_mock_insights(time_period, metrics)

    {
      insights: insights,
      recommendations: recommendations,
      metadata: {
        time_period: time_period,
        metrics_analyzed: metrics,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  end

  def generate_content(params)
    simulate_delay
    simulate_error if should_simulate_error?

    # Convert to hash to ensure consistent access
    params = params.to_h if params.respond_to?(:to_h)
    
    prompt = params[:prompt] || params['prompt'] || ''
    max_tokens = params[:max_tokens] || params['max_tokens'] || 1000
    temperature = params[:temperature] || params['temperature'] || 0.7

    # Generate mock content based on prompt keywords
    content = generate_mock_content_from_prompt(prompt)

    {
      success: true,
      content: content,
      metadata: {
        max_tokens: max_tokens,
        temperature: temperature,
        prompt_length: prompt.length,
        generated_at: Time.current,
        service: 'mock'
      }
    }
  rescue => error
    {
      success: false,
      error: error.message,
      content: nil
    }
  end

  def health_check
    start_time = Time.current
    simulate_delay
    
    {
      status: 'healthy',
      response_time: Time.current - start_time,
      metadata: {
        service: 'mock',
        version: '1.0.0',
        checked_at: Time.current
      }
    }
  end

  private

  def simulate_delay
    delay = rand(@response_delay_range)
    sleep(delay) unless Rails.env.test?
  end

  def should_simulate_error?
    rand < @error_simulation_rate && !Rails.env.test?
  end

  def simulate_error
    raise StandardError, "Simulated LLM service error"
  end

  def platform_character_limits
    {
      'twitter' => 280,
      'linkedin' => 3000,
      'facebook' => 63206,
      'instagram' => 2200,
      'general' => 1000
    }
  end

  def generate_social_content(platform, tone, topic, character_limit, brand_context = {})
    templates = social_content_templates[platform] || social_content_templates['general']
    template = templates[tone] || templates['professional']
    
    content = template.sample.gsub('[TOPIC]', topic)
    
    # Apply brand context modifications
    content = apply_brand_keywords(content, brand_context)
    content = apply_brand_style(content, brand_context)
    
    # Truncate if over character limit (after brand modifications)
    if character_limit && content.length > character_limit
      content = content[0..character_limit-4] + '...'
    end
    
    content
  end

  def generate_email_parts(email_type, subject_topic, tone, brand_context = {})
    subject_templates = email_subject_templates[email_type] || email_subject_templates['promotional']
    content_templates = email_content_templates[email_type] || email_content_templates['promotional']
    
    subject = subject_templates[tone]&.sample&.gsub('[TOPIC]', subject_topic) || 
              "Exciting news about #{subject_topic}"
    
    content = content_templates[tone]&.sample&.gsub('[TOPIC]', subject_topic) ||
              "We're excited to share some news about #{subject_topic}..."
    
    # Apply brand context modifications
    subject = apply_brand_keywords(subject, brand_context)
    subject = apply_brand_style(subject, brand_context)
    content = apply_brand_keywords(content, brand_context)
    content = apply_brand_style(content, brand_context)
    
    [subject, content]
  end

  def generate_ad_parts(ad_type, platform, objective, brand_context = {})
    ad_templates = ad_copy_templates[ad_type] || ad_copy_templates['search']
    
    headline = ad_templates[:headlines].sample
    description = ad_templates[:descriptions].sample
    cta = ad_templates[:ctas].sample
    
    # Apply brand context modifications
    headline = apply_brand_keywords(headline, brand_context)
    headline = apply_brand_style(headline, brand_context)
    description = apply_brand_keywords(description, brand_context)
    description = apply_brand_style(description, brand_context)
    cta = apply_brand_style(cta, brand_context)
    
    [headline, description, cta]
  end

  def generate_landing_page_parts(page_type, objective, key_features, brand_context = {})
    templates = landing_page_templates[page_type] || landing_page_templates['product']
    
    headline = templates[:headlines].sample
    subheadline = templates[:subheadlines].sample
    body = templates[:body].sample
    cta = templates[:ctas].sample
    
    # Include key features if provided
    if key_features.any?
      features_text = "Key features:\n" + key_features.map { |f| "• #{f}" }.join("\n")
      body = "#{body}\n\n#{features_text}"
    end
    
    # Apply brand context modifications
    headline = apply_brand_keywords(headline, brand_context)
    headline = apply_brand_style(headline, brand_context)
    subheadline = apply_brand_keywords(subheadline, brand_context)
    subheadline = apply_brand_style(subheadline, brand_context)
    body = apply_brand_keywords(body, brand_context)
    body = apply_brand_style(body, brand_context)
    cta = apply_brand_style(cta, brand_context)
    
    [headline, subheadline, body, cta]
  end

  def generate_campaign_parts(campaign_type, objective, brand_context = {})
    templates = campaign_plan_templates[campaign_type] || campaign_plan_templates['product_launch']
    
    summary = templates[:summary]
    strategy = templates[:strategy]
    timeline = templates[:timeline]
    assets = templates[:assets]
    
    # Apply brand context modifications to summary and strategy
    summary = apply_brand_keywords(summary, brand_context)
    summary = apply_brand_style(summary, brand_context)
    
    # For strategy, modify the description if present
    if strategy.is_a?(Hash) && strategy[:description]
      strategy[:description] = apply_brand_keywords(strategy[:description], brand_context)
      strategy[:description] = apply_brand_style(strategy[:description], brand_context)
    end
    
    [summary, strategy, timeline, assets]
  end

  def generate_variations(original_content, content_type, variant_count)
    strategies = variation_strategies
    
    (1..variant_count).map do |i|
      strategy = strategies[(i - 1) % strategies.length]
      apply_variation_strategy(original_content, strategy)
    end
  end

  def apply_variation_strategy(content, strategy)
    case strategy
    when 'emotional_appeal'
      "🚀 #{content} Don't miss out!"
    when 'urgency'
      "⏰ Limited time: #{content}"
    when 'social_proof'
      "Join thousands who love #{content}"
    when 'question_format'
      "Ready to #{content.downcase}?"
    when 'benefit_focused'
      "Get more results with #{content.downcase}"
    else
      content
    end
  end

  def generate_optimizations(content, content_type)
    changes = [
      'Added stronger call-to-action',
      'Improved headline clarity',
      'Enhanced emotional appeal',
      'Optimized for better readability'
    ].sample(2)
    
    optimized_content = "✨ #{content} - Now optimized!"
    
    [optimized_content, changes]
  end

  def simulate_brand_issues(content)
    # Random simulation of potential brand issues
    potential_issues = [
      'Tone too casual for brand guidelines',
      'Missing brand terminology',
      'Inconsistent capitalization',
      'Color scheme not brand-compliant'
    ]
    
    # 20% chance of having issues
    return [] if rand > 0.2
    
    potential_issues.sample(rand(1..2))
  end

  def simulate_brand_suggestions(issues)
    return [] if issues.empty?
    
    [
      'Use more formal language to match brand voice',
      'Include brand-specific keywords',
      'Follow brand style guide for formatting'
    ].sample(issues.length)
  end

  def generate_mock_insights(time_period, metrics)
    insights = [
      'Performance improved 15% over previous period',
      'Engagement rates highest on Tuesday afternoons',
      'Mobile traffic accounts for 70% of conversions',
      'Video content performs 3x better than static images'
    ].sample(3)
    
    recommendations = [
      'Increase budget allocation to top-performing channels',
      'Test more video content formats',
      'Optimize landing pages for mobile experience',
      'Schedule posts during peak engagement times'
    ].sample(2)
    
    [insights, recommendations]
  end

  def variation_strategies
    %w[emotional_appeal urgency social_proof question_format benefit_focused]
  end

  # Content template data
  def social_content_templates
    {
      'twitter' => {
        'professional' => [
          'Excited to share insights about [TOPIC] 🚀',
          'New developments in [TOPIC] are game-changing',
          'Join the conversation about [TOPIC] #innovation'
        ],
        'casual' => [
          'Loving the latest trends in [TOPIC]! 💪',
          'Can\'t stop thinking about [TOPIC] today',
          'Anyone else obsessed with [TOPIC]? Just me? 😅'
        ]
      },
      'linkedin' => {
        'professional' => [
          'I\'ve been analyzing the impact of [TOPIC] on our industry...',
          'Thought leadership insight: [TOPIC] is reshaping how we work',
          'After 5 years in the industry, here\'s what I\'ve learned about [TOPIC]'
        ]
      },
      'general' => {
        'professional' => [
          'Discover the power of [TOPIC] for your business',
          'Transform your approach with [TOPIC]',
          'Leading innovation in [TOPIC]'
        ]
      }
    }
  end

  def email_subject_templates
    {
      'promotional' => {
        'professional' => [
          'Exclusive offer: [TOPIC]',
          'Don\'t miss out on [TOPIC]',
          'Limited time: [TOPIC] special pricing'
        ],
        'friendly' => [
          'Something exciting about [TOPIC]! 🎉',
          'You\'ll love this [TOPIC] update',
          'Special news about [TOPIC] just for you'
        ]
      },
      'welcome' => {
        'professional' => [
          'Welcome to [TOPIC]',
          'Your [TOPIC] journey begins now',
          'Thank you for choosing [TOPIC]'
        ]
      }
    }
  end

  def email_content_templates
    {
      'promotional' => {
        'professional' => [
          'We\'re excited to announce our latest [TOPIC] offering...',
          'Take advantage of our exclusive [TOPIC] promotion...',
          'Discover why thousands choose our [TOPIC] solution...'
        ]
      },
      'welcome' => {
        'professional' => [
          'Welcome to our community! We\'re thrilled you\'ve joined us for [TOPIC]...',
          'Thank you for signing up. Here\'s everything you need to know about [TOPIC]...'
        ]
      }
    }
  end

  def ad_copy_templates
    {
      'search' => {
        headlines: [
          'Revolutionary Marketing Solutions',
          'Boost Your ROI by 300%',
          'The #1 Choice for Growth',
          'Transform Your Business Today'
        ],
        descriptions: [
          'Proven strategies that deliver results. Join thousands of satisfied customers.',
          'Award-winning platform trusted by industry leaders worldwide.',
          'Get started with our free trial. No commitment required.'
        ],
        ctas: [
          'Start Free Trial',
          'Get Quote Now',
          'Learn More',
          'Book Demo'
        ]
      },
      'display' => {
        headlines: [
          'Unleash Your Potential',
          'Success Starts Here',
          'Join the Revolution'
        ],
        descriptions: [
          'Discover tools that change everything.',
          'Experience the difference quality makes.'
        ],
        ctas: [
          'Discover Now',
          'Join Today',
          'Get Started'
        ]
      }
    }
  end

  def landing_page_templates
    {
      'product' => {
        headlines: [
          'The Future of Marketing is Here',
          'Revolutionary Tools for Modern Marketers',
          'Transform Your Marketing Strategy'
        ],
        subheadlines: [
          'Discover powerful features that drive real results for your business',
          'Join thousands of marketers who have transformed their approach'
        ],
        body: [
          'Our comprehensive platform provides everything you need to create, manage, and optimize your marketing campaigns...',
          'Built by marketers, for marketers, our solution addresses the real challenges you face every day...'
        ],
        ctas: [
          'Start Your Free Trial',
          'Schedule a Demo',
          'Get Started Today'
        ]
      }
    }
  end

  def campaign_plan_templates
    {
      'product_launch' => {
        summary: 'Comprehensive product launch campaign targeting early adopters and industry influencers',
        strategy: {
          phases: ['Pre-launch buzz', 'Launch event', 'Post-launch nurturing'],
          channels: ['Social media', 'Email marketing', 'PR', 'Influencer partnerships'],
          budget_allocation: { social: 40, email: 20, pr: 30, influencers: 10 }
        },
        timeline: [
          { week: 1, activity: 'Teaser campaign launch' },
          { week: 2, activity: 'Influencer partnerships activated' },
          { week: 3, activity: 'Product launch event' },
          { week: 4, activity: 'Follow-up nurture sequences' }
        ],
        assets: [
          'Social media graphics (5 sets)',
          'Email templates (3 sequences)',
          'Press release',
          'Landing page copy',
          'Video testimonials'
        ]
      }
    }
  end

  # Brand Context Integration Methods
  
  def apply_brand_voice(base_tone, brand_context)
    return base_tone if brand_context.blank?
    
    # Extract brand voice/tone information
    brand_voice = brand_context['voice'] || brand_context[:voice]
    brand_tone = brand_context['tone'] || brand_context[:tone]
    
    # If brand context specifies a voice/tone, use it instead of the base tone
    effective_tone = brand_voice || brand_tone || base_tone
    
    # Map brand voices to our mock tone system
    tone_mapping = {
      'innovative' => 'enthusiastic',
      'trustworthy' => 'professional', 
      'approachable' => 'friendly',
      'authoritative' => 'professional',
      'creative' => 'enthusiastic',
      'reliable' => 'professional',
      'cutting-edge' => 'enthusiastic'
    }
    
    tone_mapping[effective_tone.to_s.downcase] || effective_tone
  end
  
  def apply_brand_keywords(content, brand_context)
    return content if brand_context.blank?
    
    brand_keywords = brand_context['keywords'] || brand_context[:keywords] || []
    return content if brand_keywords.empty?
    
    # Simulate incorporating brand keywords naturally into content
    # In a real implementation, this would use sophisticated NLP
    keyword = brand_keywords.sample
    
    if keyword && !content.downcase.include?(keyword.downcase)
      # Simple injection of brand keyword - always modify content
      injection_style = rand(4)
      case injection_style
      when 0
        content = "#{content} ##{keyword.gsub(' ', '')}" # hashtag format
      when 1
        # Inject in middle if there's a period, otherwise append
        if content.include?('. ')
          content = content.gsub(/\. /, ". #{keyword} ", 1) # inject once
        else
          content = "#{content} #{keyword}"
        end
      when 2
        content = "#{keyword}: #{content}" # prefix format
      else
        content = "#{content} with #{keyword}" # append with connector
      end
    end
    
    content
  end
  
  def apply_brand_style(content, brand_context)
    return content if brand_context.blank?
    
    # Apply brand-specific style modifications
    style_preferences = brand_context['style'] || brand_context[:style] || {}
    
    # Emoji usage preference
    if style_preferences['emoji'] == false || style_preferences[:emoji] == false
      content = content.gsub(/[😀-🿿]/, '') # Remove emojis
    elsif style_preferences['emoji'] == 'minimal' || style_preferences[:emoji] == 'minimal'
      # Keep only one emoji max
      emoji_count = content.scan(/[😀-🿿]/).length
      if emoji_count > 1
        content = content.gsub(/[😀-🿿]/, '').strip + ' 🎯'
      end
    end
    
    # Capitalization style
    case style_preferences['capitalization'] || style_preferences[:capitalization]
    when 'lowercase'
      content = content.downcase
    when 'sentence'
      content = content.capitalize
    end
    
    content
  end

  def generate_mock_content_from_prompt(prompt)
    prompt_lower = prompt.to_s.downcase
    
    # Generate content based on prompt keywords
    if prompt_lower.include?('competitive intelligence') || prompt_lower.include?('competitive analysis')
      generate_competitive_intelligence_content
    elsif prompt_lower.include?('market research') || prompt_lower.include?('market trends')
      generate_market_research_content
    elsif prompt_lower.include?('competitors') || prompt_lower.include?('competitor analysis')
      generate_competitor_analysis_content
    elsif prompt_lower.include?('industry benchmarks') || prompt_lower.include?('benchmarks')
      generate_industry_benchmarks_content
    else
      # Generic content
      "Based on the provided information, here is a comprehensive analysis that addresses the key points mentioned in your prompt."
    end
  end

  def generate_competitive_intelligence_content
    {
      "competitive_advantages" => ["Strong brand recognition", "Innovation leadership", "Market experience"],
      "market_threats" => ["New competitors", "Economic uncertainty", "Technology disruption"],
      "positioning_opportunities" => ["Premium market segment", "Underserved niches", "International expansion"],
      "differentiation_strategies" => ["Technology focus", "Customer service excellence", "Innovation pipeline"],
      "competitive_gaps" => ["Digital marketing", "Mobile optimization", "Social media presence"],
      "strategic_recommendations" => ["Invest in digital transformation", "Expand product line", "Strengthen partnerships"]
    }.to_json
  end

  def generate_market_research_content
    {
      "market_trends" => ["Digital transformation", "Sustainability focus", "Remote work adoption"],
      "consumer_insights" => ["Price sensitivity increase", "Quality over quantity preference", "Brand loyalty changes"],
      "market_size_data" => {
        "total_addressable_market" => "$2.1B",
        "growth_rate" => "8.5%",
        "key_segments" => ["Enterprise", "Mid-market", "SMB"]
      },
      "growth_opportunities" => ["Emerging markets", "New product categories", "Partnership channels"],
      "external_factors" => {
        "regulatory" => ["Data privacy laws", "Industry compliance"],
        "economic" => ["Interest rate changes", "Supply chain costs"],
        "technological" => ["AI advancement", "Cloud adoption"]
      }
    }.to_json
  end

  def generate_competitor_analysis_content
    {
      "competitors" => [
        {
          "name" => "Market Leader",
          "type" => "direct",
          "market_share" => "35%",
          "strengths" => ["Brand recognition", "Distribution network"],
          "weaknesses" => ["High prices", "Slow innovation"],
          "positioning" => "Premium leader",
          "key_campaigns" => ["Brand awareness", "Product launch"],
          "threat_level" => "high"
        },
        {
          "name" => "Challenger",
          "type" => "direct",
          "market_share" => "20%",
          "strengths" => ["Innovation", "Competitive pricing"],
          "weaknesses" => ["Limited market presence"],
          "positioning" => "Value leader",
          "key_campaigns" => ["Price promotion", "Feature comparison"],
          "threat_level" => "medium"
        }
      ],
      "competitive_landscape" => {
        "market_saturation" => "medium",
        "barriers_to_entry" => "high",
        "innovation_pace" => "fast"
      },
      "white_space_opportunities" => ["Niche segments", "Geographic expansion", "New use cases"]
    }.to_json
  end

  def generate_industry_benchmarks_content
    {
      "performance_benchmarks" => {
        "conversion_rates" => {
          "email" => "3.1%",
          "social_media" => "1.6%",
          "paid_advertising" => "4.2%",
          "organic_search" => "5.1%"
        },
        "engagement_metrics" => {
          "email_open_rate" => "22%",
          "email_click_rate" => "3.2%",
          "social_engagement_rate" => "2.0%",
          "website_bounce_rate" => "55%"
        }
      },
      "cost_benchmarks" => {
        "cost_per_acquisition" => "$95",
        "cost_per_click" => "$2.75",
        "cost_per_impression" => "$1.45",
        "budget_allocation" => {
          "paid_media" => "45%",
          "content_creation" => "25%",
          "tools_and_technology" => "20%",
          "personnel" => "10%"
        }
      },
      "timeline_benchmarks" => {
        "campaign_planning" => "10 days",
        "content_creation" => "7 days", 
        "campaign_execution" => "30 days",
        "performance_analysis" => "3 days"
      }
    }.to_json
  end
end