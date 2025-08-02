class StrategicRationaleEngine
  def initialize(campaign)
    @campaign = campaign
    @llm_service = LlmService.new(temperature: 0.6)
  end

  def develop_market_analysis
    {
      market_size: analyze_market_size,
      competitive_landscape: analyze_competitive_landscape,
      market_trends: identify_market_trends,
      opportunity_assessment: assess_market_opportunities,
      risk_factors: identify_risk_factors
    }
  end

  def map_customer_journey
    {
      awareness_stage: map_awareness_stage,
      consideration_stage: map_consideration_stage,
      decision_stage: map_decision_stage,
      retention_stage: map_retention_stage,
      advocacy_stage: map_advocacy_stage
    }
  end

  def analyze_competitive_landscape
    prompt = build_competitive_analysis_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    {
      direct_competitors: parsed_response['direct_competitors'] || build_default_competitors,
      indirect_competitors: parsed_response['indirect_competitors'] || [],
      competitive_advantages: parsed_response['competitive_advantages'] || build_default_advantages,
      market_positioning: parsed_response['market_positioning'] || "Differentiated positioning",
      competitive_threats: parsed_response['competitive_threats'] || build_default_threats,
      market_share_analysis: parsed_response['market_share_analysis'] || build_market_share_analysis
    }
  end

  def assess_market_opportunities
    prompt = build_opportunity_assessment_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    {
      primary_opportunities: parsed_response['primary_opportunities'] || build_default_opportunities,
      market_gaps: parsed_response['market_gaps'] || identify_market_gaps,
      growth_potential: parsed_response['growth_potential'] || assess_growth_potential,
      strategic_priorities: parsed_response['strategic_priorities'] || build_strategic_priorities,
      investment_areas: parsed_response['investment_areas'] || identify_investment_areas,
      timeline_opportunities: parsed_response['timeline_opportunities'] || map_timeline_opportunities
    }
  end

  private

  def analyze_market_size
    # Build market size analysis based on campaign type and industry
    case @campaign.campaign_type
    when 'product_launch'
      {
        total_addressable_market: "$2.5B",
        serviceable_addressable_market: "$500M",
        serviceable_obtainable_market: "$50M",
        market_growth_rate: "15% annually",
        target_market_penetration: "2% in 3 years"
      }
    when 'b2b_lead_generation'
      {
        total_addressable_market: "$1.8B",
        serviceable_addressable_market: "$300M",
        serviceable_obtainable_market: "$30M",
        market_growth_rate: "12% annually",
        target_market_penetration: "3% in 2 years"
      }
    when 'brand_awareness'
      {
        total_addressable_market: "$5.2B",
        serviceable_addressable_market: "$800M",
        serviceable_obtainable_market: "$80M",
        market_growth_rate: "8% annually",
        target_market_penetration: "1.5% in 4 years"
      }
    else
      {
        total_addressable_market: "$3.0B",
        serviceable_addressable_market: "$600M",
        serviceable_obtainable_market: "$60M",
        market_growth_rate: "10% annually",
        target_market_penetration: "2.5% in 3 years"
      }
    end
  end

  def identify_market_trends
    prompt = build_market_trends_prompt
    response = @llm_service.analyze(prompt, json_response: true)
    
    parsed_response = parse_llm_response(response)
    
    parsed_response['trends'] || [
      "Digital transformation acceleration",
      "Increased focus on customer experience",
      "Data-driven decision making",
      "Sustainability and social responsibility",
      "Remote work and collaboration tools",
      "AI and automation adoption"
    ]
  end

  def identify_risk_factors
    {
      market_risks: [
        "Economic downturn affecting spending",
        "Increased competition from new entrants",
        "Technology disruption changing market dynamics"
      ],
      competitive_risks: [
        "Established players with larger budgets",
        "New competitors with innovative solutions",
        "Price competition affecting margins"
      ],
      operational_risks: [
        "Resource constraints limiting execution",
        "Timeline delays affecting market entry",
        "Quality issues affecting brand reputation"
      ],
      mitigation_strategies: [
        "Diversified marketing approach",
        "Strong value proposition differentiation",
        "Agile execution with rapid iteration",
        "Quality assurance and brand protection"
      ]
    }
  end

  def map_awareness_stage
    {
      touchpoints: [
        "Social media content",
        "Industry publications",
        "Search engine results",
        "Peer recommendations",
        "Industry events"
      ],
      pain_points: [
        "Information overload",
        "Difficulty finding relevant solutions",
        "Lack of trusted sources",
        "Time constraints for research"
      ],
      messaging_priorities: [
        "Problem identification and education",
        "Brand awareness and credibility",
        "Thought leadership content",
        "Educational value delivery"
      ],
      content_needs: [
        "Educational blog posts",
        "Industry reports",
        "Infographics and data visualizations",
        "Expert interviews and insights"
      ],
      success_metrics: [
        "Brand awareness lift",
        "Website traffic growth",
        "Content engagement rates",
        "Social media reach and impressions"
      ]
    }
  end

  def map_consideration_stage
    {
      touchpoints: [
        "Company website and resources",
        "Product demonstrations",
        "Case studies and testimonials",
        "Sales conversations",
        "Peer reviews and comparisons"
      ],
      pain_points: [
        "Comparison complexity",
        "Feature understanding challenges",
        "ROI calculation difficulties",
        "Implementation concerns",
        "Decision-making pressure"
      ],
      messaging_priorities: [
        "Value proposition clarity",
        "Competitive differentiation",
        "Proof of concept and results",
        "Implementation support assurance"
      ],
      content_needs: [
        "Detailed product information",
        "Comparison guides",
        "ROI calculators",
        "Implementation timelines",
        "Customer success stories"
      ],
      success_metrics: [
        "Lead generation volume",
        "Marketing qualified leads",
        "Content download rates",
        "Demo request conversions",
        "Sales pipeline velocity"
      ]
    }
  end

  def map_decision_stage
    {
      touchpoints: [
        "Sales presentations",
        "Proposal reviews",
        "Reference calls",
        "Trial or pilot programs",
        "Contract negotiations"
      ],
      pain_points: [
        "Budget approval processes",
        "Stakeholder alignment",
        "Implementation timeline concerns",
        "Risk assessment and mitigation",
        "Contract and pricing negotiations"
      ],
      messaging_priorities: [
        "Risk mitigation and guarantees",
        "Implementation support and training",
        "Pricing and value justification",
        "Success metrics and tracking"
      ],
      content_needs: [
        "Implementation guides",
        "Training materials",
        "Success metrics templates",
        "Contract and pricing information",
        "Risk mitigation documentation"
      ],
      success_metrics: [
        "Sales qualified leads",
        "Proposal win rates",
        "Sales cycle length",
        "Deal size optimization",
        "Conversion to customer"
      ]
    }
  end

  def map_retention_stage
    {
      touchpoints: [
        "Customer success programs",
        "Product usage and analytics",
        "Support interactions",
        "Training and education",
        "Account management"
      ],
      pain_points: [
        "Adoption and usage challenges",
        "Value realization timeline",
        "Support and service quality",
        "Feature requests and roadmap",
        "Renewal decision making"
      ],
      messaging_priorities: [
        "Value realization and ROI",
        "Continuous improvement and innovation",
        "Partnership and long-term success",
        "Expansion opportunities"
      ],
      content_needs: [
        "Best practices guides",
        "Advanced training materials",
        "Success measurement tools",
        "Expansion use cases",
        "Community and peer connections"
      ],
      success_metrics: [
        "Customer satisfaction scores",
        "Product adoption rates",
        "Support ticket resolution",
        "Renewal rates",
        "Account expansion revenue"
      ]
    }
  end

  def map_advocacy_stage
    {
      touchpoints: [
        "Customer advisory boards",
        "Case study participation",
        "Reference programs",
        "User conferences and events",
        "Social media and reviews"
      ],
      pain_points: [
        "Time investment for advocacy",
        "Confidentiality and approval processes",
        "Messaging consistency",
        "Recognition and incentives"
      ],
      messaging_priorities: [
        "Success story amplification",
        "Thought leadership opportunities",
        "Community building and networking",
        "Mutual value creation"
      ],
      content_needs: [
        "Case study templates",
        "Speaking opportunity support",
        "Co-marketing materials",
        "Community platform access",
        "Recognition and awards"
      ],
      success_metrics: [
        "Net promoter scores",
        "Reference participation rates",
        "Case study completion",
        "Referral lead generation",
        "Community engagement levels"
      ]
    }
  end

  def build_competitive_analysis_prompt
    <<~PROMPT
      Analyze the competitive landscape for a #{@campaign.campaign_type} campaign in the technology industry.

      Campaign Details:
      - Campaign Type: #{@campaign.campaign_type}
      - Target Persona: #{@campaign.persona&.name || 'Not specified'}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please provide a comprehensive competitive analysis including:
      1. Direct competitors (3-5 main competitors)
      2. Indirect competitors (alternative solutions)
      3. Competitive advantages (our strengths)
      4. Market positioning opportunities
      5. Competitive threats and challenges
      6. Market share analysis

      JSON structure:
      {
        "direct_competitors": ["competitor1", "competitor2", "competitor3"],
        "indirect_competitors": ["alternative1", "alternative2"],
        "competitive_advantages": ["advantage1", "advantage2", "advantage3"],
        "market_positioning": "positioning strategy description",
        "competitive_threats": ["threat1", "threat2"],
        "market_share_analysis": "market share insights"
      }
    PROMPT
  end

  def build_opportunity_assessment_prompt
    <<~PROMPT
      Assess market opportunities for a #{@campaign.campaign_type} campaign.

      Campaign Context:
      - Type: #{@campaign.campaign_type}
      - Target Market: #{@campaign.persona&.name || 'Not specified'}
      - Goals: #{(@campaign.goals.is_a?(Array) ? @campaign.goals.join(', ') : @campaign.goals) || 'Not specified'}

      Please identify and analyze:
      1. Primary market opportunities (3-5 key opportunities)
      2. Market gaps and unmet needs
      3. Growth potential and scalability
      4. Strategic priorities for market entry
      5. Investment areas for maximum impact
      6. Timeline opportunities and market windows

      JSON structure:
      {
        "primary_opportunities": ["opportunity1", "opportunity2", "opportunity3"],
        "market_gaps": ["gap1", "gap2"],
        "growth_potential": "growth assessment",
        "strategic_priorities": ["priority1", "priority2"],
        "investment_areas": ["area1", "area2"],
        "timeline_opportunities": ["timing1", "timing2"]
      }
    PROMPT
  end

  def build_market_trends_prompt
    <<~PROMPT
      Identify key market trends affecting a #{@campaign.campaign_type} campaign in the technology industry.

      Please identify 5-8 significant market trends that could impact our campaign strategy, including:
      - Technology trends
      - Consumer behavior trends
      - Industry-specific trends
      - Economic trends
      - Regulatory trends

      JSON structure:
      {
        "trends": ["trend1", "trend2", "trend3", "trend4", "trend5"]
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

  def build_default_competitors
    case @campaign.campaign_type
    when 'product_launch'
      ["Established market leader", "Innovative startup competitor", "Enterprise solution provider"]
    when 'b2b_lead_generation'
      ["Industry incumbent", "Technology-focused competitor", "Service-oriented competitor"]
    when 'brand_awareness'
      ["Well-known brand leader", "Regional strong player", "Digital-native competitor"]
    else
      ["Market leader", "Key competitor", "Emerging player"]
    end
  end

  def build_default_advantages
    [
      "Superior product quality and features",
      "Exceptional customer service and support",
      "Innovative technology and approach",
      "Competitive pricing and value",
      "Strong brand reputation and trust"
    ]
  end

  def build_default_threats
    [
      "Established competitors with larger budgets",
      "New market entrants with disruptive technology",
      "Price competition affecting margins",
      "Economic factors affecting customer spending"
    ]
  end

  def build_market_share_analysis
    "Fragmented market with opportunities for differentiated players to gain significant share through focused value proposition and superior execution."
  end

  def build_default_opportunities
    [
      "Underserved market segment with specific needs",
      "Technology advancement creating new possibilities",
      "Changing customer behavior opening new channels",
      "Regulatory changes favoring our approach",
      "Market consolidation creating partnership opportunities"
    ]
  end

  def identify_market_gaps
    [
      "Lack of integrated solutions in the market",
      "Poor user experience in existing offerings",
      "Limited customer support and service options",
      "Inadequate mobile and remote capabilities"
    ]
  end

  def assess_growth_potential
    "Strong growth potential driven by digital transformation trends, increasing market demand, and our differentiated value proposition."
  end

  def build_strategic_priorities
    [
      "Build brand awareness and market presence",
      "Develop strategic partnerships and alliances",
      "Invest in product innovation and differentiation",
      "Expand into adjacent market segments"
    ]
  end

  def identify_investment_areas
    [
      "Technology and product development",
      "Marketing and brand building",
      "Sales and customer success capabilities",
      "Strategic partnerships and ecosystem"
    ]
  end

  def map_timeline_opportunities
    [
      "Q1: Industry conference season for thought leadership",
      "Q2: Budget planning season for B2B prospects",
      "Q3: Summer campaign season for consumer focus",
      "Q4: Year-end decision making and planning"
    ]
  end
end