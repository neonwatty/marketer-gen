# frozen_string_literal: true

require 'openai'

# OpenAI provider for LLM integrations
# Handles all OpenAI API interactions with proper error handling and response parsing
class LlmProviders::OpenaiProvider < LlmProviders::BaseProvider
  
  # Social media content generation
  def generate_social_media_content(params)
    make_request(__method__, params)
  end

  # Email content generation
  def generate_email_content(params)
    make_request(__method__, params)
  end

  # Ad copy generation
  def generate_ad_copy(params)
    make_request(__method__, params)
  end

  # Landing page content generation
  def generate_landing_page_content(params)
    make_request(__method__, params)
  end

  # Campaign plan generation
  def generate_campaign_plan(params)
    make_request(__method__, params)
  end

  # Content variations
  def generate_content_variations(params)
    make_request(__method__, params)
  end

  # Content optimization
  def optimize_content(params)
    make_request(__method__, params)
  end

  # Brand compliance checking
  def check_brand_compliance(params)
    make_request(__method__, params)
  end

  # Analytics insights
  def generate_analytics_insights(params)
    make_request(__method__, params)
  end

  # Generic content generation
  def generate_content(params)
    make_request(__method__, params)
  end

  private

  def build_client
    OpenAI::Client.new(
      access_token: config[:api_key],
      uri_base: config[:endpoint] || "https://api.openai.com",
      request_timeout: config[:timeout] || 30,
      log_errors: Rails.env.development?
    )
  end

  def health_check_request
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: "Health check" }],
        max_tokens: 10
      }
    )
  end

  # Request methods for each content type
  def generate_social_media_content_request(params)
    prompt = build_social_media_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 500,
        temperature: config[:temperature] || 0.7
      }
    )
  end

  def generate_email_content_request(params)
    prompt = build_email_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 1000,
        temperature: config[:temperature] || 0.7
      }
    )
  end

  def generate_ad_copy_request(params)
    prompt = build_ad_copy_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 300,
        temperature: config[:temperature] || 0.8
      }
    )
  end

  def generate_landing_page_content_request(params)
    prompt = build_landing_page_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 1500,
        temperature: config[:temperature] || 0.7
      }
    )
  end

  def generate_campaign_plan_request(params)
    prompt = build_campaign_plan_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 2000,
        temperature: config[:temperature] || 0.6
      }
    )
  end

  def generate_content_variations_request(params)
    prompt = build_content_variations_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 800,
        temperature: config[:temperature] || 0.9
      }
    )
  end

  def optimize_content_request(params)
    prompt = build_optimization_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 800,
        temperature: config[:temperature] || 0.5
      }
    )
  end

  def check_brand_compliance_request(params)
    prompt = build_compliance_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 500,
        temperature: config[:temperature] || 0.3
      }
    )
  end

  def generate_analytics_insights_request(params)
    prompt = build_analytics_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens] || 1000,
        temperature: config[:temperature] || 0.4
      }
    )
  end

  def generate_content_request(params)
    prompt = params[:prompt] || params['prompt'] || "Generate marketing content."
    
    client.chat(
      parameters: {
        model: config[:model] || "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: params[:max_tokens] || params['max_tokens'] || config[:max_tokens] || 1000,
        temperature: params[:temperature] || params['temperature'] || config[:temperature] || 0.7
      }
    )
  end

  def transform_response(response, method)
    content = response.dig("choices", 0, "message", "content")
    
    return generate_fallback_response(method.to_s) if content.blank?

    case method
    when :generate_social_media_content
      parse_social_media_response(content)
    when :generate_email_content
      parse_email_response(content)
    when :generate_ad_copy
      parse_ad_copy_response(content)
    when :generate_landing_page_content
      parse_landing_page_response(content)
    when :generate_campaign_plan
      parse_campaign_plan_response(content)
    when :generate_content_variations
      parse_variations_response(content)
    when :optimize_content
      parse_optimization_response(content)
    when :check_brand_compliance
      parse_compliance_response(content)
    when :generate_analytics_insights
      parse_analytics_response(content)
    when :generate_content
      parse_generic_response(content)
    else
      parse_generic_response(content)
    end
  end

  # Prompt builders
  def build_social_media_prompt(params)
    platform = params[:platform] || params['platform'] || 'general'
    tone = params[:tone] || params['tone'] || 'professional'
    topic = params[:topic] || params['topic'] || 'marketing campaign'
    character_limit = params[:character_limit] || params['character_limit'] || 280
    brand_context = build_brand_context(params[:brand_context] || params['brand_context'] || {})

    <<~PROMPT
      You are an expert social media content creator. Generate engaging social media content for #{platform}.

      Requirements:
      - Platform: #{platform}
      - Tone: #{tone}
      - Topic: #{topic}
      - Character limit: #{character_limit}

      #{brand_context}

      Please generate content that:
      1. Stays within the character limit
      2. Matches the specified tone
      3. Incorporates the brand voice and guidelines
      4. Is engaging and action-oriented
      5. Includes relevant hashtags if appropriate

      Return your response as JSON in this exact format:
      {
        "content": "Your generated content here",
        "metadata": {
          "character_count": 120,
          "hashtags_used": ["#example"],
          "tone_confidence": 0.95
        }
      }
    PROMPT
  end

  def build_email_prompt(params)
    email_type = params[:email_type] || params['email_type'] || 'promotional'
    subject_topic = params[:subject] || params['subject'] || 'marketing campaign'
    tone = params[:tone] || params['tone'] || 'professional'
    brand_context = build_brand_context(params[:brand_context] || params['brand_context'] || {})

    <<~PROMPT
      You are an expert email marketing copywriter. Generate compelling email content.

      Requirements:
      - Email type: #{email_type}
      - Subject topic: #{subject_topic}
      - Tone: #{tone}

      #{brand_context}

      Please generate:
      1. A compelling subject line
      2. Email body content that matches the tone
      3. Clear call-to-action
      4. Personalized and engaging copy

      Return your response as JSON in this exact format:
      {
        "subject": "Your subject line here",
        "content": "Your email body here",
        "metadata": {
          "email_type": "#{email_type}",
          "word_count": 150,
          "tone": "#{tone}"
        }
      }
    PROMPT
  end

  def build_ad_copy_prompt(params)
    ad_type = params[:ad_type] || params['ad_type'] || 'search'
    platform = params[:platform] || params['platform'] || 'google'
    objective = params[:objective] || params['objective'] || 'conversions'
    brand_context = build_brand_context(params[:brand_context] || params['brand_context'] || {})

    <<~PROMPT
      You are an expert advertising copywriter. Create high-converting ad copy.

      Requirements:
      - Ad type: #{ad_type}
      - Platform: #{platform}
      - Objective: #{objective}

      #{brand_context}

      Please generate:
      1. Attention-grabbing headline
      2. Compelling description
      3. Strong call-to-action
      4. Copy optimized for #{objective}

      Return your response as JSON in this exact format:
      {
        "headline": "Your headline here",
        "description": "Your ad description here",
        "call_to_action": "Your CTA here",
        "metadata": {
          "ad_type": "#{ad_type}",
          "platform": "#{platform}",
          "objective": "#{objective}"
        }
      }
    PROMPT
  end

  def build_landing_page_prompt(params)
    page_type = params[:page_type] || params['page_type'] || 'product'
    objective = params[:objective] || params['objective'] || 'conversion'
    key_features = params[:key_features] || params['key_features'] || []
    brand_context = build_brand_context(params[:brand_context] || params['brand_context'] || {})

    features_text = key_features.any? ? "Key features to highlight: #{key_features.join(', ')}" : ""

    <<~PROMPT
      You are an expert conversion copywriter. Create high-converting landing page copy.

      Requirements:
      - Page type: #{page_type}
      - Objective: #{objective}
      #{features_text}

      #{brand_context}

      Please generate:
      1. Compelling headline
      2. Supporting subheadline
      3. Body copy that drives action
      4. Strong call-to-action

      Return your response as JSON in this exact format:
      {
        "headline": "Your headline here",
        "subheadline": "Your subheadline here",
        "body": "Your body copy here",
        "cta": "Your call-to-action here",
        "metadata": {
          "page_type": "#{page_type}",
          "objective": "#{objective}",
          "feature_count": #{key_features.length}
        }
      }
    PROMPT
  end

  def build_campaign_plan_prompt(params)
    campaign_type = params[:campaign_type] || params['campaign_type'] || 'product_launch'
    objective = params[:objective] || params['objective'] || 'brand_awareness'
    brand_context = build_brand_context(params[:brand_context] || params['brand_context'] || {})

    <<~PROMPT
      You are a strategic marketing planner. Create a comprehensive campaign plan.

      Requirements:
      - Campaign type: #{campaign_type}
      - Primary objective: #{objective}

      #{brand_context}

      Please generate a strategic campaign plan including:
      1. Campaign summary
      2. Strategic approach
      3. Timeline with key milestones
      4. Required assets

      Return your response as JSON in this exact format:
      {
        "summary": "Campaign overview and goals",
        "strategy": {
          "phases": ["Phase 1", "Phase 2", "Phase 3"],
          "channels": ["channel1", "channel2"],
          "budget_allocation": {"channel1": 40, "channel2": 60}
        },
        "timeline": [
          {"week": 1, "activity": "Activity description"}
        ],
        "assets": ["Asset 1", "Asset 2"],
        "metadata": {
          "campaign_type": "#{campaign_type}",
          "objective": "#{objective}"
        }
      }
    PROMPT
  end

  def build_content_variations_prompt(params)
    original_content = params[:original_content] || params['original_content'] || 'Original content'
    content_type = params[:content_type] || params['content_type'] || 'social_media'
    variant_count = [params[:variant_count] || params['variant_count'] || 3, 10].min

    <<~PROMPT
      You are a creative marketing copywriter. Create #{variant_count} variations of the following content.

      Original content: "#{original_content}"
      Content type: #{content_type}

      Please create #{variant_count} different variations using different approaches:
      - Emotional appeal
      - Urgency/scarcity
      - Social proof
      - Question format
      - Benefit-focused

      Return your response as JSON array in this exact format:
      [
        {
          "content": "Variation 1 content here",
          "variant_number": 1,
          "strategy": "emotional_appeal",
          "metadata": {
            "content_type": "#{content_type}"
          }
        }
      ]
    PROMPT
  end

  def build_optimization_prompt(params)
    content = params[:content] || params['content'] || 'Sample content'
    content_type = params[:content_type] || params['content_type'] || 'general'

    <<~PROMPT
      You are a content optimization expert. Analyze and improve the following content.

      Original content: "#{content}"
      Content type: #{content_type}

      Please optimize the content for:
      1. Better engagement
      2. Clearer messaging
      3. Stronger call-to-action
      4. Improved readability

      Return your response as JSON in this exact format:
      {
        "optimized_content": "Your improved content here",
        "changes": ["Change 1 description", "Change 2 description"],
        "metadata": {
          "content_type": "#{content_type}",
          "optimization_count": 2
        }
      }
    PROMPT
  end

  def build_compliance_prompt(params)
    content = params[:content] || params['content'] || ''
    brand_guidelines = params[:brand_guidelines] || params['brand_guidelines'] || {}

    <<~PROMPT
      You are a brand compliance expert. Analyze the following content for brand compliance.

      Content to analyze: "#{content}"
      
      Brand guidelines:
      #{brand_guidelines.map { |k, v| "#{k}: #{v}" }.join("\n")}

      Please check for:
      1. Brand voice consistency
      2. Tone appropriateness
      3. Terminology compliance
      4. Style guide adherence

      Return your response as JSON in this exact format:
      {
        "compliant": true,
        "issues": ["Issue description if any"],
        "suggestions": ["Improvement suggestion"],
        "metadata": {
          "content_length": #{content.length},
          "checks_performed": ["tone", "terminology", "format"]
        }
      }
    PROMPT
  end

  def build_analytics_prompt(params)
    time_period = params[:time_period] || params['time_period'] || '30_days'
    metrics = params[:metrics] || params['metrics'] || ['impressions', 'clicks', 'conversions']

    <<~PROMPT
      You are a marketing analytics expert. Generate insights and recommendations.

      Analysis period: #{time_period}
      Metrics to analyze: #{metrics.join(', ')}

      Please provide:
      1. Key performance insights
      2. Trend analysis
      3. Actionable recommendations
      4. Strategic suggestions

      Return your response as JSON in this exact format:
      {
        "insights": ["Insight 1", "Insight 2", "Insight 3"],
        "recommendations": ["Recommendation 1", "Recommendation 2"],
        "metadata": {
          "time_period": "#{time_period}",
          "metrics_analyzed": #{metrics.to_json}
        }
      }
    PROMPT
  end

  # Response parsers
  def parse_social_media_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      generated_content = parsed['content']
      metadata = parsed['metadata'] || {}
      
      # Override character count with actual content length
      metadata['character_count'] = generated_content.length
      
      {
        content: generated_content,
        metadata: metadata.merge(
          generated_at: Time.current,
          service: provider_name
        )
      }
    rescue JSON::ParserError
      {
        content: content.strip,
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_email_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        subject: parsed['subject'],
        content: parsed['content'],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      # Fallback parsing
      lines = content.strip.split("\n")
      subject_line = lines.find { |line| line.downcase.include?('subject') } || lines.first
      body = lines[1..-1]&.join("\n") || content
      
      {
        subject: subject_line&.gsub(/subject:?\s*/i, '') || 'Generated Email Subject',
        content: body,
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_ad_copy_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        headline: parsed['headline'],
        description: parsed['description'],
        call_to_action: parsed['call_to_action'],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      lines = content.strip.split("\n").reject(&:blank?)
      
      {
        headline: lines[0] || 'Generated Headline',
        description: lines[1] || 'Generated description',
        call_to_action: lines.last || 'Learn More',
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_landing_page_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        headline: parsed['headline'],
        subheadline: parsed['subheadline'],
        body: parsed['body'],
        cta: parsed['cta'],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      sections = content.strip.split("\n\n")
      
      {
        headline: sections[0] || 'Generated Headline',
        subheadline: sections[1] || 'Generated subheadline',
        body: sections[2..-2]&.join("\n\n") || 'Generated body content',
        cta: sections.last || 'Get Started',
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_campaign_plan_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        summary: parsed['summary'],
        strategy: parsed['strategy'],
        timeline: parsed['timeline'],
        assets: parsed['assets'],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      {
        summary: content.strip,
        strategy: { phases: [], channels: [], budget_allocation: {} },
        timeline: [],
        assets: [],
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_variations_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      if parsed.is_a?(Array)
        parsed.map do |variation|
          variation.merge(
            'metadata' => (variation['metadata'] || {}).merge(
              'generated_at' => Time.current,
              'service' => provider_name
            )
          )
        end
      else
        [parse_generic_response(content)]
      end
    rescue JSON::ParserError
      # Fallback: split content into variations
      lines = content.strip.split("\n").reject(&:blank?)
      lines.first(5).map.with_index do |line, index|
        {
          'content' => line,
          'variant_number' => index + 1,
          'strategy' => 'generated',
          'metadata' => {
            'fallback_parsing' => true,
            'generated_at' => Time.current,
            'service' => provider_name
          }
        }
      end
    end
  end

  def parse_optimization_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        optimized_content: parsed['optimized_content'],
        changes: parsed['changes'] || [],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      {
        optimized_content: content.strip,
        changes: ['Content optimized'],
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_compliance_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        compliant: parsed['compliant'] != false,
        issues: parsed['issues'] || [],
        suggestions: parsed['suggestions'] || [],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      {
        compliant: true,
        issues: [],
        suggestions: [],
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_analytics_response(content)
    begin
      json_content = extract_json(content)
      parsed = JSON.parse(json_content)
      
      {
        insights: parsed['insights'] || [],
        recommendations: parsed['recommendations'] || [],
        metadata: parsed['metadata']&.merge(
          generated_at: Time.current,
          service: provider_name
        ) || {
          generated_at: Time.current,
          service: provider_name
        }
      }
    rescue JSON::ParserError
      insights = content.split("\n").select { |line| line.strip.length > 10 }.first(3)
      
      {
        insights: insights,
        recommendations: ['Review performance data', 'Optimize based on results'],
        metadata: {
          fallback_parsing: true,
          generated_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  def parse_generic_response(content)
    {
      success: true,
      content: content.strip,
      metadata: {
        generated_at: Time.current,
        service: provider_name
      }
    }
  end
end