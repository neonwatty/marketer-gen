# frozen_string_literal: true

class CampaignIntelligenceService < ApplicationService
  attr_reader :campaign_plan

  def initialize(campaign_plan)
    super()
    @campaign_plan = campaign_plan
  end

  def call
    begin
      if campaign_plan.nil?
        return {
          success: false,
          error: "Campaign plan is required",
          context: {}
        }
      end
      
      Rails.logger.info "Service Call: CampaignIntelligenceService with params: { campaign_plan_id: #{campaign_plan.id} }"
      
      intelligence_data = generate_comprehensive_intelligence
      
      {
        success: true,
        data: {
          message: "Campaign intelligence generated successfully",
          campaign_plan_id: campaign_plan.id,
          insights_generated: intelligence_data[:insights_count],
          confidence_average: intelligence_data[:avg_confidence],
          analysis_types: intelligence_data[:analysis_types]
        }
      }
    rescue => error
      Rails.logger.error "Service Error in #{self.class}: #{error.message}"
      Rails.logger.error "Context: { campaign_plan_id: #{campaign_plan&.id} }" if campaign_plan
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Return a structured error response
      {
        success: false,
        error: error.message,
        context: { campaign_plan_id: campaign_plan&.id }
      }
    end
  end

  def generate_comprehensive_intelligence
    insights = []
    
    # Generate different types of intelligence
    insights << generate_competitive_intelligence
    insights << generate_market_trend_analysis
    insights << generate_performance_predictions
    insights << generate_strategic_recommendations
    insights << generate_audience_intelligence
    insights << generate_budget_optimization_insights
    
    # Calculate summary statistics
    avg_confidence = insights.map { |i| i[:confidence_score] }.sum / insights.size.to_f
    analysis_types = insights.map { |i| i[:insight_type] }
    
    {
      insights_count: insights.size,
      avg_confidence: avg_confidence.round(2),
      analysis_types: analysis_types,
      insights: insights
    }
  end

  private

  def generate_competitive_intelligence
    # Integrate with existing CompetitiveAnalysisService
    competitive_service = CompetitiveAnalysisService.new(campaign_plan)
    competitive_data = competitive_service.perform_analysis
    
    if competitive_data[:success]
      insight_data = competitive_data[:data]
      confidence = 0.85
    else
      # Use default competitive analysis when service fails
      insight_data = default_competitive_intelligence
      confidence = 0.5
    end
    
    create_insight(
      insight_type: 'competitive_analysis',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'CompetitiveAnalysisService', integration: true }
    )
  end

  def generate_market_trend_analysis
    prompt = build_market_trend_prompt
    
    response = llm_service.generate_content({
      prompt: prompt,
      max_tokens: 2000,
      temperature: 0.6
    })
    
    if response[:success]
      insight_data = parse_market_trend_response(response[:content])
      confidence = 0.80
    else
      insight_data = default_market_trends
      confidence = 0.50
    end
    
    create_insight(
      insight_type: 'market_trends',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'LLM', analysis_method: 'trend_monitoring' }
    )
  end

  def generate_performance_predictions
    prompt = build_performance_prediction_prompt
    
    response = llm_service.generate_content({
      prompt: prompt,
      max_tokens: 1800,
      temperature: 0.5
    })
    
    if response[:success]
      insight_data = parse_performance_prediction_response(response[:content])
      confidence = 0.75
    else
      insight_data = default_performance_predictions
      confidence = 0.45
    end
    
    create_insight(
      insight_type: 'performance_prediction',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'LLM', prediction_horizon: '90_days' }
    )
  end

  def generate_strategic_recommendations
    prompt = build_strategic_recommendations_prompt
    
    response = llm_service.generate_content({
      prompt: prompt,
      max_tokens: 2200,
      temperature: 0.4
    })
    
    if response[:success]
      insight_data = parse_strategic_recommendations_response(response[:content])
      confidence = 0.88
    else
      insight_data = default_strategic_recommendations
      confidence = 0.60
    end
    
    create_insight(
      insight_type: 'strategic_recommendation',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'LLM', recommendation_priority: 'high' }
    )
  end

  def generate_audience_intelligence
    prompt = build_audience_intelligence_prompt
    
    response = llm_service.generate_content({
      prompt: prompt,
      max_tokens: 1600,
      temperature: 0.6
    })
    
    if response[:success]
      insight_data = parse_audience_intelligence_response(response[:content])
      confidence = 0.82
    else
      insight_data = default_audience_intelligence
      confidence = 0.55
    end
    
    create_insight(
      insight_type: 'audience_intelligence',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'LLM', analysis_depth: 'comprehensive' }
    )
  end

  def generate_budget_optimization_insights
    prompt = build_budget_optimization_prompt
    
    response = llm_service.generate_content({
      prompt: prompt,
      max_tokens: 1400,
      temperature: 0.3
    })
    
    if response[:success]
      insight_data = parse_budget_optimization_response(response[:content])
      confidence = 0.78
    else
      insight_data = default_budget_optimization
      confidence = 0.50
    end
    
    create_insight(
      insight_type: 'budget_optimization',
      insight_data: insight_data,
      confidence_score: confidence,
      metadata: { source: 'LLM', optimization_focus: 'roi_maximization' }
    )
  end

  def create_insight(insight_type:, insight_data:, confidence_score:, metadata: {})
    insight = campaign_plan.campaign_insights.create!(
      insight_type: insight_type,
      insight_data: insight_data,
      confidence_score: confidence_score,
      analysis_date: Time.current,
      metadata: metadata
    )
    
    {
      insight_type: insight_type,
      confidence_score: confidence_score,
      insight_id: insight.id,
      data: insight_data
    }
  end

  # Prompt building methods
  def build_market_trend_prompt
    <<~PROMPT
      Analyze current market trends for the following campaign context:

      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Target Audience: #{campaign_plan.target_audience}
      Industry: #{extract_industry_context}
      Timeline: #{campaign_plan.timeline_constraints}

      Provide comprehensive market trend analysis including:
      1. Current trending topics and themes
      2. Consumer behavior shifts
      3. Technology adoption trends
      4. Channel preference changes
      5. Seasonal and temporal factors
      6. Emerging opportunities and threats

      Format as JSON:
      {
        "trending_topics": ["topic1", "topic2"],
        "behavior_shifts": ["shift1", "shift2"],
        "technology_trends": ["trend1", "trend2"],
        "channel_preferences": {
          "growing": ["channel1", "channel2"],
          "declining": ["channel3", "channel4"]
        },
        "seasonal_factors": ["factor1", "factor2"],
        "opportunities": ["opportunity1", "opportunity2"],
        "threats": ["threat1", "threat2"],
        "trend_confidence": "high/medium/low"
      }
    PROMPT
  end

  def build_performance_prediction_prompt
    <<~PROMPT
      Predict campaign performance based on the following parameters:

      Campaign Details:
      - Type: #{campaign_plan.campaign_type}
      - Objective: #{campaign_plan.objective}
      - Target Audience: #{campaign_plan.target_audience}
      - Budget: #{campaign_plan.budget_constraints}
      - Timeline: #{campaign_plan.timeline_constraints}

      Historical Context:
      - Industry: #{extract_industry_context}
      - Previous competitive analysis: #{campaign_plan.competitive_intelligence.present? ? 'Available' : 'Not available'}

      Provide detailed performance predictions including:
      1. Expected engagement rates by channel
      2. Conversion rate predictions
      3. ROI forecasts
      4. Risk factors and mitigation strategies
      5. Key performance indicators to monitor

      Format as JSON:
      {
        "engagement_predictions": {
          "email": "percentage",
          "social_media": "percentage",
          "paid_advertising": "percentage",
          "content_marketing": "percentage"
        },
        "conversion_predictions": {
          "lead_conversion": "percentage",
          "sales_conversion": "percentage",
          "retention_rate": "percentage"
        },
        "roi_forecast": {
          "expected_roi": "percentage",
          "break_even_timeline": "days",
          "confidence_interval": "range"
        },
        "risk_factors": ["risk1", "risk2"],
        "mitigation_strategies": ["strategy1", "strategy2"],
        "monitoring_kpis": ["kpi1", "kpi2"],
        "prediction_confidence": "high/medium/low"
      }
    PROMPT
  end

  def build_strategic_recommendations_prompt
    <<~PROMPT
      Generate strategic recommendations for optimizing the following campaign:

      Campaign Context:
      - Type: #{campaign_plan.campaign_type}
      - Objective: #{campaign_plan.objective}
      - Target Audience: #{campaign_plan.target_audience}
      - Budget Constraints: #{campaign_plan.budget_constraints}
      - Timeline: #{campaign_plan.timeline_constraints}

      Available Intelligence:
      - Competitive Analysis: #{campaign_plan.competitive_intelligence.present? ? 'Complete' : 'Pending'}
      - Market Research: #{campaign_plan.market_research_data.present? ? 'Complete' : 'Pending'}

      Provide actionable strategic recommendations including:
      1. Optimization opportunities
      2. Resource allocation suggestions
      3. Timing and execution recommendations
      4. Channel strategy improvements
      5. Creative direction guidance
      6. Risk mitigation approaches

      Format as JSON:
      {
        "optimization_opportunities": [
          {
            "area": "optimization_area",
            "recommendation": "specific_action",
            "impact": "high/medium/low",
            "effort": "high/medium/low"
          }
        ],
        "resource_allocation": {
          "budget_reallocation": ["suggestion1", "suggestion2"],
          "team_focus": ["focus1", "focus2"],
          "tool_recommendations": ["tool1", "tool2"]
        },
        "execution_strategy": {
          "timing_recommendations": ["timing1", "timing2"],
          "phase_approach": ["phase1", "phase2"],
          "milestones": ["milestone1", "milestone2"]
        },
        "channel_strategy": {
          "primary_channels": ["channel1", "channel2"],
          "secondary_channels": ["channel3", "channel4"],
          "integration_points": ["integration1", "integration2"]
        },
        "creative_direction": ["direction1", "direction2"],
        "risk_mitigation": ["approach1", "approach2"],
        "success_metrics": ["metric1", "metric2"]
      }
    PROMPT
  end

  def build_audience_intelligence_prompt
    <<~PROMPT
      Analyze audience intelligence for the following campaign:

      Target Audience: #{campaign_plan.target_audience}
      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Industry Context: #{extract_industry_context}

      Provide comprehensive audience intelligence including:
      1. Detailed audience segmentation
      2. Behavioral patterns and preferences
      3. Communication preferences
      4. Decision-making factors
      5. Engagement triggers
      6. Content consumption habits

      Format as JSON:
      {
        "audience_segments": [
          {
            "segment_name": "name",
            "size_percentage": "percentage",
            "characteristics": ["trait1", "trait2"],
            "preferences": ["pref1", "pref2"],
            "engagement_level": "high/medium/low"
          }
        ],
        "behavioral_patterns": {
          "online_behavior": ["behavior1", "behavior2"],
          "purchase_patterns": ["pattern1", "pattern2"],
          "content_preferences": ["type1", "type2"]
        },
        "communication_preferences": {
          "preferred_channels": ["channel1", "channel2"],
          "messaging_tone": "formal/casual/mixed",
          "frequency_preference": "high/medium/low"
        },
        "decision_factors": ["factor1", "factor2"],
        "engagement_triggers": ["trigger1", "trigger2"],
        "optimal_timing": {
          "days": ["day1", "day2"],
          "times": ["time1", "time2"]
        },
        "intelligence_confidence": "high/medium/low"
      }
    PROMPT
  end

  def build_budget_optimization_prompt
    <<~PROMPT
      Optimize budget allocation for the following campaign:

      Budget Constraints: #{campaign_plan.budget_constraints}
      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Timeline: #{campaign_plan.timeline_constraints}
      Target Audience: #{campaign_plan.target_audience}

      Provide budget optimization recommendations including:
      1. Optimal budget allocation across channels
      2. Cost efficiency improvements
      3. ROI maximization strategies
      4. Budget reallocation opportunities
      5. Cost-saving recommendations

      Format as JSON:
      {
        "optimal_allocation": {
          "paid_advertising": "percentage",
          "content_creation": "percentage",
          "tools_technology": "percentage",
          "personnel_resources": "percentage",
          "contingency": "percentage"
        },
        "channel_allocation": {
          "social_media": "percentage",
          "email_marketing": "percentage",
          "search_advertising": "percentage",
          "content_marketing": "percentage",
          "influencer_marketing": "percentage"
        },
        "efficiency_improvements": [
          {
            "area": "improvement_area",
            "suggestion": "specific_action",
            "potential_savings": "percentage",
            "implementation_effort": "high/medium/low"
          }
        ],
        "roi_strategies": ["strategy1", "strategy2"],
        "reallocation_opportunities": ["opportunity1", "opportunity2"],
        "cost_saving_measures": ["measure1", "measure2"],
        "budget_monitoring": ["metric1", "metric2"],
        "optimization_confidence": "high/medium/low"
      }
    PROMPT
  end

  # Response parsing methods
  def parse_market_trend_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse market trend response: #{e.message}"
    default_market_trends
  end

  def parse_performance_prediction_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse performance prediction response: #{e.message}"
    default_performance_predictions
  end

  def parse_strategic_recommendations_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse strategic recommendations response: #{e.message}"
    default_strategic_recommendations
  end

  def parse_audience_intelligence_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse audience intelligence response: #{e.message}"
    default_audience_intelligence
  end

  def parse_budget_optimization_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse budget optimization response: #{e.message}"
    default_budget_optimization
  end

  # Default responses for error cases
  def default_competitive_intelligence
    {
      "competitive_advantages" => [
        "Unique value proposition",
        "Established brand presence",
        "Customer loyalty"
      ],
      "threats" => [
        "Market competition",
        "Price sensitivity",
        "Technology disruption"
      ],
      "opportunities" => [
        "Market gaps",
        "Digital transformation",
        "Partnership potential"
      ],
      "market_positioning" => {
        "current_position" => "Emerging player",
        "target_position" => "Market challenger",
        "differentiation" => "Innovation focus"
      },
      "competitive_landscape" => {
        "direct_competitors" => ["Competitor A", "Competitor B"],
        "indirect_competitors" => ["Alternative solution providers"],
        "market_leaders" => ["Industry leader"]
      },
      "strategic_recommendations" => [
        "Focus on differentiation",
        "Strengthen digital presence",
        "Build strategic partnerships"
      ],
      "analysis_confidence" => "medium"
    }
  end

  def default_market_trends
    {
      "trending_topics" => ["Digital transformation", "Sustainability", "Personalization"],
      "behavior_shifts" => ["Mobile-first consumption", "Social commerce adoption"],
      "technology_trends" => ["AI integration", "Voice search optimization"],
      "channel_preferences" => {
        "growing" => ["TikTok", "Instagram Reels", "Podcast advertising"],
        "declining" => ["Facebook organic", "Display advertising"]
      },
      "seasonal_factors" => ["Holiday shopping patterns", "Back-to-school timing"],
      "opportunities" => ["Micro-influencer partnerships", "Interactive content"],
      "threats" => ["Ad blocking adoption", "Privacy regulations"],
      "trend_confidence" => "medium"
    }
  end

  def default_performance_predictions
    {
      "engagement_predictions" => {
        "email" => "2.5%",
        "social_media" => "1.8%",
        "paid_advertising" => "3.2%",
        "content_marketing" => "4.1%"
      },
      "conversion_predictions" => {
        "lead_conversion" => "12%",
        "sales_conversion" => "3.5%",
        "retention_rate" => "65%"
      },
      "roi_forecast" => {
        "expected_roi" => "250%",
        "break_even_timeline" => "45 days",
        "confidence_interval" => "200-300%"
      },
      "risk_factors" => ["Market saturation", "Economic uncertainty"],
      "mitigation_strategies" => ["Diversify channels", "Flexible budget allocation"],
      "monitoring_kpis" => ["CAC", "LTV", "Engagement rate"],
      "prediction_confidence" => "medium"
    }
  end

  def default_strategic_recommendations
    {
      "optimization_opportunities" => [
        {
          "area" => "Content strategy",
          "recommendation" => "Increase video content production",
          "impact" => "high",
          "effort" => "medium"
        },
        {
          "area" => "Channel mix",
          "recommendation" => "Expand social media presence",
          "impact" => "medium",
          "effort" => "low"
        }
      ],
      "resource_allocation" => {
        "budget_reallocation" => ["Shift 20% from traditional to digital", "Increase content budget"],
        "team_focus" => ["Data analysis capabilities", "Creative production"],
        "tool_recommendations" => ["Marketing automation platform", "Analytics dashboard"]
      },
      "execution_strategy" => {
        "timing_recommendations" => ["Launch in Q1", "Peak activity in month 2"],
        "phase_approach" => ["Awareness phase", "Conversion phase", "Retention phase"],
        "milestones" => ["30-day performance review", "Budget optimization checkpoint"]
      },
      "channel_strategy" => {
        "primary_channels" => ["Social media", "Email marketing"],
        "secondary_channels" => ["Content marketing", "Paid search"],
        "integration_points" => ["Cross-channel messaging", "Unified analytics"]
      },
      "creative_direction" => ["User-generated content", "Interactive experiences"],
      "risk_mitigation" => ["A/B test all major changes", "Monitor competitor activities"],
      "success_metrics" => ["Engagement rate", "Conversion rate", "ROI"]
    }
  end

  def default_audience_intelligence
    {
      "audience_segments" => [
        {
          "segment_name" => "Early Adopters",
          "size_percentage" => "25%",
          "characteristics" => ["Tech-savvy", "High income"],
          "preferences" => ["Innovation", "Quality"],
          "engagement_level" => "high"
        },
        {
          "segment_name" => "Mainstream Users",
          "size_percentage" => "60%",
          "characteristics" => ["Value-conscious", "Brand loyal"],
          "preferences" => ["Reliability", "Value"],
          "engagement_level" => "medium"
        }
      ],
      "behavioral_patterns" => {
        "online_behavior" => ["Research-heavy", "Social proof driven"],
        "purchase_patterns" => ["Seasonal buying", "Comparison shopping"],
        "content_preferences" => ["Video tutorials", "Customer reviews"]
      },
      "communication_preferences" => {
        "preferred_channels" => ["Email", "Social media"],
        "messaging_tone" => "casual",
        "frequency_preference" => "medium"
      },
      "decision_factors" => ["Price", "Quality", "Brand reputation"],
      "engagement_triggers" => ["Limited time offers", "Personalized recommendations"],
      "optimal_timing" => {
        "days" => ["Tuesday", "Wednesday", "Thursday"],
        "times" => ["10 AM", "2 PM", "7 PM"]
      },
      "intelligence_confidence" => "medium"
    }
  end

  def default_budget_optimization
    {
      "optimal_allocation" => {
        "paid_advertising" => "45%",
        "content_creation" => "25%",
        "tools_technology" => "15%",
        "personnel_resources" => "10%",
        "contingency" => "5%"
      },
      "channel_allocation" => {
        "social_media" => "35%",
        "email_marketing" => "20%",
        "search_advertising" => "25%",
        "content_marketing" => "15%",
        "influencer_marketing" => "5%"
      },
      "efficiency_improvements" => [
        {
          "area" => "Automation",
          "suggestion" => "Implement marketing automation",
          "potential_savings" => "15%",
          "implementation_effort" => "medium"
        }
      ],
      "roi_strategies" => ["Focus on high-converting channels", "Optimize ad spend timing"],
      "reallocation_opportunities" => ["Move budget from low-performing channels", "Increase spend on proven channels"],
      "cost_saving_measures" => ["Negotiate better rates", "Use free tools where possible"],
      "budget_monitoring" => ["Cost per acquisition", "Return on ad spend"],
      "optimization_confidence" => "medium"
    }
  end

  def extract_industry_context
    brand_context = campaign_plan.brand_context_summary
    industry = brand_context.dig("industry") ||
               brand_context.dig("vertical") ||
               campaign_plan.campaign_type.humanize

    industry.present? ? industry : "General Business"
  end
end