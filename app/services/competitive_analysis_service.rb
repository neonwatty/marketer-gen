# frozen_string_literal: true

# Service for performing competitive analysis and market research integration
# Processes competitive intelligence, market research data, competitor analysis, and industry benchmarks
class CompetitiveAnalysisService < ApplicationService
  attr_reader :campaign_plan

  def initialize(campaign_plan)
    super()
    @campaign_plan = campaign_plan
  end

  def call
    begin
      # Perform competitive analysis in background
      CompetitiveAnalysisJob.perform_later(campaign_plan.id)

      # Return immediate success response
      {
        success: true,
        data: {
          message: "Competitive analysis initiated",
          campaign_plan_id: campaign_plan.id,
          status: "processing"
        }
      }
    rescue => error
      Rails.logger.error "CompetitiveAnalysisService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      {
        success: false,
        error: error.message,
        context: { campaign_plan_id: campaign_plan.id }
      }
    end
  end

  # Synchronous analysis method (called by the background job)
  def perform_analysis
    begin
      analysis_data = {
        competitive_intelligence: generate_competitive_intelligence,
        market_research: conduct_market_research,
        competitor_analysis: analyze_competitors,
        industry_benchmarks: gather_industry_benchmarks
      }

      # Update campaign plan with analysis results
      campaign_plan.update!(
        competitive_intelligence: analysis_data[:competitive_intelligence],
        market_research_data: analysis_data[:market_research],
        competitor_analysis: analysis_data[:competitor_analysis],
        industry_benchmarks: analysis_data[:industry_benchmarks],
        competitive_analysis_last_updated_at: Time.current
      )

      {
        success: true,
        data: analysis_data
      }
    rescue => error
      Rails.logger.error "CompetitiveAnalysisService error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      {
        success: false,
        error: error.message,
        context: { campaign_plan_id: campaign_plan.id }
      }
    end
  end

  private

  def generate_competitive_intelligence
    prompt = build_competitive_intelligence_prompt

    # Use LLM service to generate competitive intelligence
    response = llm_service.generate_content(
      prompt: prompt,
      max_tokens: 2000,
      temperature: 0.7
    )

    if response[:success]
      parse_competitive_intelligence_response(response[:content])
    else
      Rails.logger.error "Failed to generate competitive intelligence: #{response[:error]}"
      default_competitive_intelligence
    end
  end

  def conduct_market_research
    prompt = build_market_research_prompt

    response = llm_service.generate_content(
      prompt: prompt,
      max_tokens: 2000,
      temperature: 0.6
    )

    if response[:success]
      parse_market_research_response(response[:content])
    else
      Rails.logger.error "Failed to conduct market research: #{response[:error]}"
      default_market_research
    end
  end

  def analyze_competitors
    prompt = build_competitor_analysis_prompt

    response = llm_service.generate_content(
      prompt: prompt,
      max_tokens: 2500,
      temperature: 0.5
    )

    if response[:success]
      parse_competitor_analysis_response(response[:content])
    else
      Rails.logger.error "Failed to analyze competitors: #{response[:error]}"
      default_competitor_analysis
    end
  end

  def gather_industry_benchmarks
    prompt = build_industry_benchmarks_prompt

    response = llm_service.generate_content(
      prompt: prompt,
      max_tokens: 1500,
      temperature: 0.4
    )

    if response[:success]
      parse_industry_benchmarks_response(response[:content])
    else
      Rails.logger.error "Failed to gather industry benchmarks: #{response[:error]}"
      default_industry_benchmarks
    end
  end

  # Prompt building methods
  def build_competitive_intelligence_prompt
    <<~PROMPT
      Generate competitive intelligence for the following campaign:

      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Target Audience: #{campaign_plan.target_audience}
      Industry Context: #{extract_industry_context}

      Please provide a comprehensive competitive intelligence analysis including:
      1. Key competitive advantages we can leverage
      2. Market threats and challenges
      3. Positioning opportunities
      4. Differentiation strategies
      5. Competitive gaps to exploit

      Format the response as JSON with the following structure:
      {
        "competitive_advantages": ["advantage1", "advantage2"],
        "market_threats": ["threat1", "threat2"],
        "positioning_opportunities": ["opportunity1", "opportunity2"],
        "differentiation_strategies": ["strategy1", "strategy2"],
        "competitive_gaps": ["gap1", "gap2"],
        "strategic_recommendations": ["recommendation1", "recommendation2"]
      }
    PROMPT
  end

  def build_market_research_prompt
    <<~PROMPT
      Conduct market research analysis for the following campaign:

      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Target Audience: #{campaign_plan.target_audience}
      Budget Context: #{campaign_plan.budget_constraints}

      Please provide comprehensive market research including:
      1. Current market trends
      2. Consumer insights and behavior patterns
      3. Market size and growth opportunities
      4. Emerging technologies and platforms
      5. Regulatory and economic factors

      Format the response as JSON:
      {
        "market_trends": ["trend1", "trend2"],
        "consumer_insights": ["insight1", "insight2"],
        "market_size_data": {
          "total_addressable_market": "value",
          "growth_rate": "percentage",
          "key_segments": ["segment1", "segment2"]
        },
        "growth_opportunities": ["opportunity1", "opportunity2"],
        "external_factors": {
          "regulatory": ["factor1", "factor2"],
          "economic": ["factor1", "factor2"],
          "technological": ["factor1", "factor2"]
        }
      }
    PROMPT
  end

  def build_competitor_analysis_prompt
    <<~PROMPT
      Analyze competitors for the following campaign context:

      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Industry: #{extract_industry_context}
      Target Audience: #{campaign_plan.target_audience}

      Please identify and analyze key competitors including:
      1. Direct competitors with similar offerings
      2. Indirect competitors solving similar problems
      3. Emerging competitors and disruptors
      4. Competitor strengths and weaknesses
      5. Market share and positioning analysis

      Format the response as JSON:
      {
        "competitors": [
          {
            "name": "Competitor Name",
            "type": "direct/indirect/emerging",
            "market_share": "percentage or 'unknown'",
            "strengths": ["strength1", "strength2"],
            "weaknesses": ["weakness1", "weakness2"],
            "positioning": "positioning statement",
            "key_campaigns": ["campaign1", "campaign2"],
            "threat_level": "high/medium/low"
          }
        ],
        "competitive_landscape": {
          "market_saturation": "high/medium/low",
          "barriers_to_entry": "high/medium/low",
          "innovation_pace": "fast/moderate/slow"
        },
        "white_space_opportunities": ["opportunity1", "opportunity2"]
      }
    PROMPT
  end

  def build_industry_benchmarks_prompt
    <<~PROMPT
      Provide industry benchmarks and performance metrics for:

      Campaign Type: #{campaign_plan.campaign_type}
      Objective: #{campaign_plan.objective}
      Industry: #{extract_industry_context}

      Please provide relevant industry benchmarks including:
      1. Performance metrics and KPIs
      2. Cost benchmarks and budget allocation
      3. Channel performance standards
      4. Conversion rates and engagement metrics
      5. Timeline and execution benchmarks

      Format the response as JSON:
      {
        "performance_benchmarks": {
          "conversion_rates": {
            "email": "percentage",
            "social_media": "percentage",
            "paid_advertising": "percentage",
            "organic_search": "percentage"
          },
          "engagement_metrics": {
            "email_open_rate": "percentage",
            "email_click_rate": "percentage",
            "social_engagement_rate": "percentage",
            "website_bounce_rate": "percentage"
          }
        },
        "cost_benchmarks": {
          "cost_per_acquisition": "value",
          "cost_per_click": "value",
          "cost_per_impression": "value",
          "budget_allocation": {
            "paid_media": "percentage",
            "content_creation": "percentage",
            "tools_and_technology": "percentage",
            "personnel": "percentage"
          }
        },
        "timeline_benchmarks": {
          "campaign_planning": "days",
          "content_creation": "days",
          "campaign_execution": "days",
          "performance_analysis": "days"
        }
      }
    PROMPT
  end

  # Response parsing methods
  def parse_competitive_intelligence_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse competitive intelligence response: #{e.message}"
    default_competitive_intelligence
  end

  def parse_market_research_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse market research response: #{e.message}"
    default_market_research
  end

  def parse_competitor_analysis_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse competitor analysis response: #{e.message}"
    default_competitor_analysis
  end

  def parse_industry_benchmarks_response(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse industry benchmarks response: #{e.message}"
    default_industry_benchmarks
  end

  # Default responses for error cases
  def default_competitive_intelligence
    {
      "competitive_advantages" => [ "Market experience", "Brand recognition", "Customer loyalty" ],
      "market_threats" => [ "New competitors", "Economic uncertainty", "Technology disruption" ],
      "positioning_opportunities" => [ "Unique value proposition", "Underserved market segments" ],
      "differentiation_strategies" => [ "Innovation focus", "Customer service excellence" ],
      "competitive_gaps" => [ "Digital presence", "Mobile optimization" ],
      "strategic_recommendations" => [ "Invest in digital transformation", "Focus on customer experience" ]
    }
  end

  def default_market_research
    {
      "market_trends" => [ "Digital transformation", "Sustainability focus", "Personalization" ],
      "consumer_insights" => [ "Price sensitivity", "Quality preference", "Convenience demand" ],
      "market_size_data" => {
        "total_addressable_market" => "TBD",
        "growth_rate" => "5-10%",
        "key_segments" => [ "Enterprise", "SMB", "Consumer" ]
      },
      "growth_opportunities" => [ "International expansion", "New product lines" ],
      "external_factors" => {
        "regulatory" => [ "Data privacy", "Industry compliance" ],
        "economic" => [ "Interest rates", "Consumer spending" ],
        "technological" => [ "AI advancement", "Mobile adoption" ]
      }
    }
  end

  def default_competitor_analysis
    {
      "competitors" => [
        {
          "name" => "Market Leader",
          "type" => "direct",
          "market_share" => "25%",
          "strengths" => [ "Brand recognition", "Distribution network" ],
          "weaknesses" => [ "High prices", "Legacy technology" ],
          "positioning" => "Premium market leader",
          "key_campaigns" => [ "Brand awareness", "Product launch" ],
          "threat_level" => "high"
        }
      ],
      "competitive_landscape" => {
        "market_saturation" => "medium",
        "barriers_to_entry" => "medium",
        "innovation_pace" => "moderate"
      },
      "white_space_opportunities" => [ "Underserved demographics", "Emerging channels" ]
    }
  end

  def default_industry_benchmarks
    {
      "performance_benchmarks" => {
        "conversion_rates" => {
          "email" => "2-3%",
          "social_media" => "1-2%",
          "paid_advertising" => "3-5%",
          "organic_search" => "4-6%"
        },
        "engagement_metrics" => {
          "email_open_rate" => "20-25%",
          "email_click_rate" => "2-5%",
          "social_engagement_rate" => "1-3%",
          "website_bounce_rate" => "40-60%"
        }
      },
      "cost_benchmarks" => {
        "cost_per_acquisition" => "$50-200",
        "cost_per_click" => "$1-5",
        "cost_per_impression" => "$0.50-2.00",
        "budget_allocation" => {
          "paid_media" => "40-50%",
          "content_creation" => "20-30%",
          "tools_and_technology" => "15-20%",
          "personnel" => "20-25%"
        }
      },
      "timeline_benchmarks" => {
        "campaign_planning" => "14-21 days",
        "content_creation" => "7-14 days",
        "campaign_execution" => "30-90 days",
        "performance_analysis" => "7-14 days"
      }
    }
  end

  def extract_industry_context
    # Try to extract industry context from campaign plan or default to generic
    brand_context = campaign_plan.brand_context_summary
    industry = brand_context.dig("industry") ||
               brand_context.dig("vertical") ||
               campaign_plan.campaign_type.humanize

    industry.present? ? industry : "General Business"
  end
end
