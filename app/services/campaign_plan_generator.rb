class CampaignPlanGenerator
  include Rails.application.routes.url_helpers

  def initialize(campaign)
    @campaign = campaign
    @llm_service = LlmService.new(temperature: 0.7)
  end

  def generate_comprehensive_plan
    {
      strategic_rationale: generate_strategic_rationale,
      target_audience: generate_target_audience,
      messaging_framework: generate_messaging_framework,
      channel_strategy: generate_channel_strategy,
      timeline_phases: generate_timeline_phases,
      success_metrics: generate_success_metrics,
      budget_allocation: generate_budget_allocation,
      creative_approach: generate_creative_approach
    }
  end

  def generate_strategic_rationale
    prompt = build_strategic_rationale_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    {
      market_analysis: parsed_response["market_analysis"] || "Comprehensive market analysis for #{@campaign.campaign_type} campaign",
      competitive_advantage: parsed_response["competitive_advantage"] || "Unique value proposition and differentiation strategy",
      value_proposition: parsed_response["value_proposition"] || "Clear value proposition targeting customer pain points",
      strategic_goals: parsed_response["strategic_goals"] || [ "Increase brand awareness", "Generate qualified leads", "Drive conversions" ],
      market_opportunity: parsed_response["market_opportunity"] || "Significant market opportunity identified",
      target_market_size: parsed_response["target_market_size"] || "Large addressable market with growth potential"
    }
  end

  def generate_target_audience
    prompt = build_target_audience_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    {
      primary_persona: @campaign.persona&.name || "Target Persona",
      demographics: parsed_response["demographics"] || build_default_demographics,
      psychographics: parsed_response["psychographics"] || build_default_psychographics,
      pain_points: parsed_response["pain_points"] || [ "Efficiency challenges", "Cost concerns", "Time constraints" ],
      motivations: parsed_response["motivations"] || [ "Solve problems", "Improve performance", "Save time" ],
      preferred_channels: parsed_response["preferred_channels"] || [ "email", "social_media", "search" ],
      journey_stage: parsed_response["journey_stage"] || "consideration"
    }
  end

  def generate_messaging_framework
    prompt = build_messaging_framework_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    {
      primary_message: parsed_response["primary_message"] || "Transform your business with our solution",
      supporting_messages: parsed_response["supporting_messages"] || [
        "Proven results and ROI",
        "Expert support and guidance",
        "Scalable and flexible solution"
      ],
      value_propositions: parsed_response["value_propositions"] || [
        "Save time and resources",
        "Improve efficiency and performance",
        "Reduce costs and complexity"
      ],
      proof_points: parsed_response["proof_points"] || [
        "Customer testimonials",
        "Case studies and success stories",
        "Industry recognition and awards"
      ],
      call_to_action: parsed_response["call_to_action"] || "Get started today",
      tone_of_voice: parsed_response["tone_of_voice"] || "Professional, friendly, confident"
    }
  end

  def generate_channel_strategy
    industry_channels = get_industry_specific_channels

    prompt = build_channel_strategy_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    channels = parsed_response["channels"] || industry_channels

    channels.map do |channel|
      {
        channel: channel,
        strategy: generate_channel_specific_strategy(channel),
        budget_allocation: calculate_channel_budget_allocation(channel),
        timeline: generate_channel_timeline(channel),
        success_metrics: generate_channel_metrics(channel)
      }
    end
  end

  def generate_timeline_phases
    prompt = build_timeline_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    phases = parsed_response["phases"] || build_default_timeline_phases

    phases.map.with_index do |phase, index|
      {
        phase: phase["phase"] || "Phase #{index + 1}",
        duration_weeks: phase["duration_weeks"] || 4,
        objectives: phase["objectives"] || [ "Achieve phase goals" ],
        activities: phase["activities"] || [ "Execute campaign activities" ],
        deliverables: phase["deliverables"] || [ "Phase deliverables" ],
        milestones: phase["milestones"] || [ "Key milestones" ],
        dependencies: phase["dependencies"] || []
      }
    end
  end

  def generate_success_metrics
    prompt = build_success_metrics_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    {
      awareness: parsed_response["awareness"] || {
        reach: 100000,
        impressions: 500000,
        engagement_rate: 5.5,
        brand_mention_increase: 25
      },
      consideration: parsed_response["consideration"] || {
        website_visits: 10000,
        content_downloads: 500,
        email_signups: 1000,
        demo_requests: 100
      },
      conversion: parsed_response["conversion"] || {
        leads_generated: 200,
        sql_conversion: 25,
        revenue_attributed: 50000,
        customer_acquisition_cost: 250
      },
      retention: parsed_response["retention"] || {
        customer_lifetime_value: 5000,
        retention_rate: 85,
        upsell_rate: 20,
        referral_rate: 15
      }
    }
  end

  def generate_budget_allocation
    total_budget = @campaign.target_metrics&.dig("budget") || 50000

    {
      total_budget: total_budget,
      channel_allocation: {
        digital_advertising: (total_budget * 0.35).round,
        content_creation: (total_budget * 0.20).round,
        email_marketing: (total_budget * 0.15).round,
        social_media: (total_budget * 0.15).round,
        events_pr: (total_budget * 0.10).round,
        tools_technology: (total_budget * 0.05).round
      },
      phase_allocation: distribute_budget_across_phases(total_budget),
      contingency: (total_budget * 0.10).round
    }
  end

  def generate_creative_approach
    prompt = build_creative_approach_prompt
    response = @llm_service.analyze(prompt, json_response: true)

    if response.is_a?(String)
      parsed_response = JSON.parse(response) rescue {}
    else
      parsed_response = response || {}
    end

    {
      core_concept: parsed_response["core_concept"] || "Innovative solution for modern challenges",
      visual_identity: parsed_response["visual_identity"] || {
        color_palette: [ "#007bff", "#28a745", "#ffc107" ],
        typography: "Modern, clean, professional",
        imagery_style: "Real people, authentic moments"
      },
      content_themes: parsed_response["content_themes"] || [
        "Innovation and transformation",
        "Success stories and results",
        "Expert insights and thought leadership"
      ],
      creative_formats: parsed_response["creative_formats"] || [
        "Video testimonials",
        "Infographics and data visualizations",
        "Interactive demos and tools"
      ]
    }
  end

  private

  def build_strategic_rationale_prompt
    <<~PROMPT
      Create a strategic rationale for a #{@campaign.campaign_type} campaign targeting #{@campaign.persona&.name || 'target audience'}.

      Campaign Details:
      - Campaign Name: #{@campaign.name}
      - Campaign Type: #{@campaign.campaign_type}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}
      - Target Metrics: #{@campaign.target_metrics || 'Not specified'}

      Please provide a comprehensive strategic rationale including:
      1. Market analysis and opportunity
      2. Competitive advantage and differentiation
      3. Clear value proposition
      4. Strategic goals and objectives
      5. Market opportunity assessment
      6. Target market size estimation

      JSON structure:
      {
        "market_analysis": "detailed market analysis",
        "competitive_advantage": "competitive advantage description",
        "value_proposition": "clear value proposition",
        "strategic_goals": ["goal1", "goal2", "goal3"],
        "market_opportunity": "opportunity description",
        "target_market_size": "market size assessment"
      }
    PROMPT
  end

  def build_target_audience_prompt
    persona_context = @campaign.persona ? @campaign.persona.to_campaign_context : {}

    <<~PROMPT
      Define the target audience for a #{@campaign.campaign_type} campaign.

      Persona Context: #{persona_context}
      Campaign Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please provide detailed target audience information including:
      1. Demographics (age, gender, income, location, etc.)
      2. Psychographics (values, interests, lifestyle)
      3. Pain points and challenges
      4. Motivations and goals
      5. Preferred communication channels
      6. Customer journey stage

      JSON structure:
      {
        "demographics": {"age": "25-45", "income": "$50k-$100k", "location": "Urban areas"},
        "psychographics": {"values": ["efficiency", "innovation"], "interests": ["technology", "business"]},
        "pain_points": ["challenge1", "challenge2"],
        "motivations": ["motivation1", "motivation2"],
        "preferred_channels": ["channel1", "channel2"],
        "journey_stage": "awareness/consideration/decision"
      }
    PROMPT
  end

  def build_messaging_framework_prompt
    <<~PROMPT
      Create a messaging framework for a #{@campaign.campaign_type} campaign.

      Campaign Context:
      - Name: #{@campaign.name}
      - Type: #{@campaign.campaign_type}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}
      - Target: #{@campaign.persona&.name || 'Target audience'}

      Please provide a comprehensive messaging framework including:
      1. Primary message (main value proposition)
      2. Supporting messages (key benefits)
      3. Value propositions (specific values delivered)
      4. Proof points (credibility and trust)
      5. Call to action
      6. Tone of voice

      JSON structure:
      {
        "primary_message": "main message",
        "supporting_messages": ["message1", "message2", "message3"],
        "value_propositions": ["value1", "value2", "value3"],
        "proof_points": ["proof1", "proof2", "proof3"],
        "call_to_action": "action statement",
        "tone_of_voice": "tone description"
      }
    PROMPT
  end

  def build_channel_strategy_prompt
    <<~PROMPT
      Recommend the optimal channel mix for a #{@campaign.campaign_type} campaign.

      Consider:
      - Campaign type: #{@campaign.campaign_type}
      - Target audience: #{@campaign.persona&.name || 'Not specified'}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please recommend 4-6 marketing channels that would be most effective for this campaign.

      JSON structure:
      {
        "channels": ["channel1", "channel2", "channel3", "channel4"]
      }
    PROMPT
  end

  def build_timeline_prompt
    <<~PROMPT
      Create a timeline with phases for a #{@campaign.campaign_type} campaign.

      Campaign Details:
      - Type: #{@campaign.campaign_type}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please create 3-5 campaign phases with:
      1. Phase name and objectives
      2. Duration in weeks
      3. Key activities
      4. Deliverables
      5. Milestones

      JSON structure:
      {
        "phases": [
          {
            "phase": "Phase 1",
            "duration_weeks": 4,
            "objectives": ["objective1", "objective2"],
            "activities": ["activity1", "activity2"],
            "deliverables": ["deliverable1", "deliverable2"],
            "milestones": ["milestone1", "milestone2"],
            "dependencies": ["dependency1"]
          }
        ]
      }
    PROMPT
  end

  def build_success_metrics_prompt
    <<~PROMPT
      Define success metrics for a #{@campaign.campaign_type} campaign.

      Campaign Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}
      Target Metrics: #{@campaign.target_metrics || 'Not specified'}

      Please provide specific, measurable metrics across the marketing funnel:
      1. Awareness metrics
      2. Consideration metrics#{'  '}
      3. Conversion metrics
      4. Retention metrics

      JSON structure:
      {
        "awareness": {"reach": 100000, "impressions": 500000, "engagement_rate": 5.5},
        "consideration": {"website_visits": 10000, "content_downloads": 500},
        "conversion": {"leads_generated": 200, "sql_conversion": 25},
        "retention": {"customer_lifetime_value": 5000, "retention_rate": 85}
      }
    PROMPT
  end

  def build_creative_approach_prompt
    <<~PROMPT
      Develop a creative approach for a #{@campaign.campaign_type} campaign.

      Campaign: #{@campaign.name}
      Type: #{@campaign.campaign_type}
      Target: #{@campaign.persona&.name || 'Target audience'}

      Please provide creative direction including:
      1. Core creative concept
      2. Visual identity guidelines
      3. Content themes
      4. Creative formats

      JSON structure:
      {
        "core_concept": "main creative concept",
        "visual_identity": {
          "color_palette": ["color1", "color2"],
          "typography": "typography style",
          "imagery_style": "imagery description"
        },
        "content_themes": ["theme1", "theme2"],
        "creative_formats": ["format1", "format2"]
      }
    PROMPT
  end

  def get_industry_specific_channels
    case @campaign.campaign_type
    when "b2b_lead_generation", "product_launch"
      [ "linkedin", "email", "content_marketing", "webinars", "search" ]
    when "seasonal_promotion", "brand_awareness"
      [ "social_media", "paid_search", "display_ads", "email", "influencer" ]
    when "event_promotion"
      [ "event_marketing", "partnerships", "social_media", "email", "pr" ]
    when "customer_retention", "upsell"
      [ "email", "in_app", "customer_success", "webinars", "content" ]
    else
      [ "email", "social_media", "content_marketing", "search", "display_ads" ]
    end
  end

  def generate_channel_specific_strategy(channel)
    strategies = {
      "email" => "Nurture leads with personalized, value-driven email sequences",
      "social_media" => "Build community and engagement through authentic content",
      "content_marketing" => "Establish thought leadership and provide valuable insights",
      "linkedin" => "Target decision makers with professional, B2B-focused content",
      "search" => "Capture high-intent traffic with optimized search campaigns",
      "webinars" => "Educate prospects and demonstrate expertise through live sessions",
      "display_ads" => "Build awareness and retarget engaged prospects",
      "partnerships" => "Leverage partner networks for expanded reach and credibility"
    }

    strategies[channel] || "Targeted strategy for maximum impact and ROI"
  end

  def calculate_channel_budget_allocation(channel)
    # Default budget allocation percentages by channel
    allocations = {
      "linkedin" => 0.25,
      "email" => 0.15,
      "content_marketing" => 0.20,
      "webinars" => 0.15,
      "search" => 0.20,
      "social_media" => 0.20,
      "paid_search" => 0.25,
      "display_ads" => 0.15,
      "event_marketing" => 0.30,
      "partnerships" => 0.10
    }

    (allocations[channel] || 0.15) * 100
  end

  def generate_channel_timeline(channel)
    {
      "setup_weeks" => 1,
      "execution_weeks" => 8,
      "optimization_weeks" => 2
    }
  end

  def generate_channel_metrics(channel)
    metrics = {
      "email" => { "open_rate" => 25, "click_rate" => 4, "conversion_rate" => 2 },
      "social_media" => { "engagement_rate" => 5, "reach" => 50000, "clicks" => 2000 },
      "content_marketing" => { "page_views" => 10000, "time_on_page" => 3, "shares" => 500 },
      "linkedin" => { "ctr" => 0.8, "conversion_rate" => 3, "cost_per_lead" => 50 },
      "search" => { "ctr" => 3, "conversion_rate" => 5, "cost_per_click" => 2.5 }
    }

    metrics[channel] || { "engagement" => 5, "conversion_rate" => 3 }
  end

  def build_default_timeline_phases
    [
      {
        "phase" => "Planning & Setup",
        "duration_weeks" => 2,
        "objectives" => [ "Campaign setup", "Content creation", "Asset preparation" ],
        "activities" => [ "Strategy finalization", "Creative development", "Platform setup" ],
        "deliverables" => [ "Campaign assets", "Content calendar", "Tracking setup" ],
        "milestones" => [ "Strategy approval", "Creative approval", "Platform ready" ]
      },
      {
        "phase" => "Launch & Awareness",
        "duration_weeks" => 4,
        "objectives" => [ "Generate awareness", "Build audience", "Drive initial engagement" ],
        "activities" => [ "Content publishing", "Social promotion", "PR outreach" ],
        "deliverables" => [ "Content pieces", "Social posts", "Press coverage" ],
        "milestones" => [ "Launch completion", "Awareness targets", "Engagement goals" ]
      },
      {
        "phase" => "Engagement & Consideration",
        "duration_weeks" => 6,
        "objectives" => [ "Nurture prospects", "Build relationships", "Generate leads" ],
        "activities" => [ "Email campaigns", "Webinars", "Content marketing" ],
        "deliverables" => [ "Email sequences", "Webinar content", "Lead magnets" ],
        "milestones" => [ "Lead targets", "Engagement metrics", "Pipeline growth" ]
      },
      {
        "phase" => "Conversion & Optimization",
        "duration_weeks" => 4,
        "objectives" => [ "Drive conversions", "Optimize performance", "Scale results" ],
        "activities" => [ "Sales enablement", "Retargeting", "Optimization" ],
        "deliverables" => [ "Sales materials", "Optimized campaigns", "Performance reports" ],
        "milestones" => [ "Conversion targets", "ROI goals", "Optimization complete" ]
      }
    ]
  end

  def build_default_demographics
    {
      "age" => "25-45",
      "income" => "$50,000-$150,000",
      "education" => "College educated",
      "location" => "Urban and suburban areas",
      "company_size" => "50-1000 employees"
    }
  end

  def build_default_psychographics
    {
      "values" => [ "Efficiency", "Innovation", "Quality", "Reliability" ],
      "interests" => [ "Technology", "Business growth", "Professional development" ],
      "behavior" => [ "Research-driven", "Peer-influenced", "Value-conscious" ],
      "lifestyle" => [ "Busy professionals", "Tech-savvy", "Results-oriented" ]
    }
  end

  def distribute_budget_across_phases(total_budget)
    {
      "planning_setup" => (total_budget * 0.15).round,
      "launch_awareness" => (total_budget * 0.30).round,
      "engagement_consideration" => (total_budget * 0.35).round,
      "conversion_optimization" => (total_budget * 0.20).round
    }
  end
end
