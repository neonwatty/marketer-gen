class CampaignPlanExporter
  def initialize(campaign, brand_settings = {})
    @campaign = campaign
    @brand_settings = brand_settings
  end

  def export_to_pdf
    # Generate PDF content string
    # In a real implementation, this would use a PDF generation library like Prawn or WickedPDF
    pdf_content = generate_pdf_content

    # Return PDF content as string (would be actual PDF bytes in real implementation)
    "%PDF-1.4\n#{pdf_content}"
  end

  def export_to_powerpoint
    # Generate PowerPoint content
    # In a real implementation, this would use a library like ruby-pptx or axlsx
    pptx_content = generate_powerpoint_content

    # Return PowerPoint content as string (would be actual PPTX bytes in real implementation)
    pptx_content
  end

  def export_with_branding(format)
    content = case format
    when :pdf
      export_to_pdf
    when :powerpoint
      export_to_powerpoint
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end

    {
      content: content,
      metadata: {
        brand_applied: true,
        primary_color: @brand_settings[:primary_color],
        secondary_color: @brand_settings[:secondary_color],
        font_family: @brand_settings[:font_family],
        logo_url: @brand_settings[:logo_url],
        generated_at: Time.current,
        format: format
      }
    }
  end

  def generate_slide_structure
    {
      title_slide: {
        title: @campaign.name,
        subtitle: "Campaign Strategic Plan",
        date: Date.current.strftime("%B %d, %Y"),
        presenter: "Marketing Team"
      },
      executive_summary: {
        title: "Executive Summary",
        content: generate_executive_summary,
        key_points: extract_key_points
      },
      target_audience: {
        title: "Target Audience Analysis",
        content: format_target_audience_data,
        personas: extract_persona_information
      },
      strategy_overview: {
        title: "Strategic Approach",
        content: format_strategy_overview,
        frameworks: extract_strategic_frameworks
      },
      timeline_phases: {
        title: "Campaign Timeline & Phases",
        content: format_timeline_data,
        milestones: extract_key_milestones
      },
      success_metrics: {
        title: "Success Metrics & KPIs",
        content: format_metrics_data,
        targets: extract_target_metrics
      },
      budget_allocation: {
        title: "Budget & Resource Allocation",
        content: format_budget_data,
        breakdown: generate_budget_breakdown
      },
      creative_approach: {
        title: "Creative Direction & Messaging",
        content: format_creative_approach,
        examples: generate_creative_examples
      },
      implementation_plan: {
        title: "Implementation Roadmap",
        content: format_implementation_plan,
        responsibilities: define_responsibilities
      },
      appendix: {
        title: "Appendix & Supporting Materials",
        content: compile_appendix_materials,
        references: gather_references
      }
    }
  end

  private

  def generate_pdf_content
    content = []

    content << "CAMPAIGN STRATEGIC PLAN"
    content << "=" * 50
    content << ""
    content << "Campaign Name: #{@campaign.name}"
    content << "Campaign Type: #{@campaign.campaign_type&.humanize}"
    content << "Status: #{@campaign.status&.humanize}"
    content << "Created: #{@campaign.created_at&.strftime('%B %d, %Y')}"
    content << ""

    # Campaign Overview
    content << "CAMPAIGN OVERVIEW"
    content << "-" * 30
    content << format_campaign_overview
    content << ""

    # Strategic Rationale
    content << "STRATEGIC RATIONALE"
    content << "-" * 30
    if campaign_plan = @campaign.campaign_plans.first
      content << format_strategic_rationale(campaign_plan.strategic_rationale)
    else
      content << "Strategic rationale to be developed"
    end
    content << ""

    # Target Audience
    content << "TARGET AUDIENCE"
    content << "-" * 30
    if campaign_plan = @campaign.campaign_plans.first
      content << format_target_audience(campaign_plan.target_audience)
    else
      content << "Target audience analysis to be developed"
    end
    content << ""

    # Timeline
    content << "CAMPAIGN TIMELINE"
    content << "-" * 30
    content << format_timeline
    content << ""

    # Success Metrics
    content << "SUCCESS METRICS"
    content << "-" * 30
    content << format_success_metrics
    content << ""

    content.join("\n")
  end

  def generate_powerpoint_content
    slides = generate_slide_structure

    content = []
    content << "PowerPoint Presentation Structure:"
    content << "=" * 40
    content << ""

    slides.each_with_index do |(slide_key, slide_data), index|
      content << "Slide #{index + 1}: #{slide_data[:title]}"
      content << "-" * 30

      if slide_data[:content].is_a?(Hash)
        slide_data[:content].each do |key, value|
          content << "#{key.to_s.humanize}: #{value}"
        end
      elsif slide_data[:content].is_a?(Array)
        slide_data[:content].each do |item|
          content << "• #{item}"
        end
      else
        content << slide_data[:content]
      end

      content << ""
    end

    content.join("\n")
  end

  def format_campaign_overview
    overview = []
    overview << "Campaign: #{@campaign.name}"
    overview << "Type: #{@campaign.campaign_type&.humanize}"
    overview << "Persona: #{@campaign.persona&.name}" if @campaign.persona
    if @campaign.goals.present? && @campaign.goals.is_a?(Array)
      overview << "Goals: #{@campaign.goals.join(', ')}"
    elsif @campaign.goals.present?
      overview << "Goals: #{@campaign.goals}"
    end
    overview << "Duration: #{calculate_campaign_duration}"
    overview.join("\n")
  end

  def format_strategic_rationale(rationale)
    return "Strategic rationale not available" unless rationale.present?

    formatted = []

    if rationale.is_a?(Hash)
      rationale.each do |key, value|
        formatted << "#{key.to_s.humanize}: #{value}"
      end
    elsif rationale.is_a?(String)
      formatted << rationale
    else
      formatted << rationale.to_s
    end

    formatted.join("\n")
  end

  def format_target_audience(audience)
    return "Target audience not defined" unless audience.present?

    formatted = []

    if audience.is_a?(Hash)
      audience.each do |key, value|
        if value.is_a?(Array)
          formatted << "#{key.to_s.humanize}: #{value.join(', ')}"
        else
          formatted << "#{key.to_s.humanize}: #{value}"
        end
      end
    else
      formatted << audience.to_s
    end

    formatted.join("\n")
  end

  def format_timeline
    timeline = []
    timeline << "Start Date: #{@campaign.started_at&.strftime('%B %d, %Y') || 'TBD'}"
    timeline << "End Date: #{@campaign.ended_at&.strftime('%B %d, %Y') || 'TBD'}"
    timeline << "Duration: #{calculate_campaign_duration}"

    if campaign_plan = @campaign.campaign_plans.first
      if campaign_plan.timeline_phases.present?
        timeline << "\nCampaign Phases:"
        campaign_plan.timeline_phases.each_with_index do |phase, index|
          timeline << "#{index + 1}. #{phase['phase'] || "Phase #{index + 1}"}"
          timeline << "   Duration: #{phase['duration_weeks'] || 'TBD'} weeks"
          if phase["activities"]
            timeline << "   Activities: #{phase['activities'].join(', ')}"
          end
        end
      end
    end

    timeline.join("\n")
  end

  def format_success_metrics
    metrics = []

    if @campaign.target_metrics.present?
      metrics << "Target Metrics:"
      @campaign.target_metrics.each do |key, value|
        metrics << "• #{key.humanize}: #{value}"
      end
    end

    if campaign_plan = @campaign.campaign_plans.first
      if campaign_plan.success_metrics.present?
        metrics << "\nCampaign Plan Metrics:"
        campaign_plan.success_metrics.each do |category, category_metrics|
          metrics << "#{category.to_s.humanize}:"
          if category_metrics.is_a?(Hash)
            category_metrics.each do |metric, target|
              metrics << "  • #{metric.to_s.humanize}: #{target}"
            end
          end
        end
      end
    end

    metrics.any? ? metrics.join("\n") : "Success metrics to be defined"
  end

  def calculate_campaign_duration
    return "Duration not specified" unless @campaign.started_at && @campaign.ended_at

    days = (@campaign.ended_at - @campaign.started_at).to_i
    weeks = (days / 7.0).round(1)

    "#{days} days (#{weeks} weeks)"
  end

  def generate_executive_summary
    summary = {
      campaign_objective: @campaign.goals&.first || "Primary campaign objective",
      target_market: @campaign.persona&.name || "Target market segment",
      key_strategies: [ "Strategy 1", "Strategy 2", "Strategy 3" ],
      expected_outcomes: [ "Outcome 1", "Outcome 2", "Outcome 3" ],
      investment_required: calculate_total_budget,
      timeline_overview: calculate_campaign_duration
    }
    summary
  end

  def extract_key_points
    [
      "Strategic campaign approach aligned with business objectives",
      "Comprehensive target audience analysis and segmentation",
      "Multi-channel execution plan with integrated messaging",
      "Clear success metrics and performance tracking framework"
    ]
  end

  def format_target_audience_data
    if @campaign.persona
      {
        primary_persona: @campaign.persona.name,
        demographics: "Target demographics",
        psychographics: "Target psychographics",
        pain_points: "Key pain points",
        motivations: "Primary motivations"
      }
    else
      {
        primary_persona: "To be defined",
        demographics: "Demographics analysis needed",
        psychographics: "Psychographics research required",
        pain_points: "Pain points identification needed",
        motivations: "Motivation analysis required"
      }
    end
  end

  def extract_persona_information
    if @campaign.persona
      [ @campaign.persona.name ]
    else
      [ "Primary persona to be defined" ]
    end
  end

  def format_strategy_overview
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan
      {
        strategic_approach: "Comprehensive multi-phase campaign",
        messaging_framework: "Consistent messaging across channels",
        channel_strategy: "Integrated multi-channel approach",
        creative_direction: "Brand-aligned creative execution"
      }
    else
      {
        strategic_approach: "Strategy development in progress",
        messaging_framework: "Messaging framework to be defined",
        channel_strategy: "Channel strategy under development",
        creative_direction: "Creative direction to be established"
      }
    end
  end

  def extract_strategic_frameworks
    [ "Customer journey mapping", "Competitive analysis", "Value proposition framework" ]
  end

  def format_timeline_data
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan&.timeline_phases&.any?
      timeline_data = {}
      campaign_plan.timeline_phases.each_with_index do |phase, index|
        timeline_data["phase_#{index + 1}"] = {
          name: phase["phase"] || "Phase #{index + 1}",
          duration: "#{phase['duration_weeks'] || 4} weeks",
          objectives: phase["objectives"] || [ "Phase objectives" ],
          activities: phase["activities"] || [ "Phase activities" ]
        }
      end
      timeline_data
    else
      {
        phase_1: { name: "Planning", duration: "2 weeks", objectives: [ "Campaign setup" ], activities: [ "Strategy development" ] },
        phase_2: { name: "Launch", duration: "4 weeks", objectives: [ "Campaign execution" ], activities: [ "Multi-channel launch" ] },
        phase_3: { name: "Optimization", duration: "6 weeks", objectives: [ "Performance optimization" ], activities: [ "Continuous improvement" ] }
      }
    end
  end

  def extract_key_milestones
    [ "Campaign launch", "Mid-campaign review", "Performance optimization", "Campaign completion" ]
  end

  def format_metrics_data
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan&.success_metrics&.any?
      campaign_plan.success_metrics
    else
      {
        awareness: { reach: "100,000", engagement: "5%" },
        consideration: { leads: "500", mql_rate: "25%" },
        conversion: { sales: "50", close_rate: "10%" }
      }
    end
  end

  def extract_target_metrics
    @campaign.target_metrics || { leads: 100, awareness: "10%" }
  end

  def format_budget_data
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan&.budget_allocation&.any?
      campaign_plan.budget_allocation
    else
      {
        total_budget: calculate_total_budget,
        digital_marketing: "40%",
        content_creation: "25%",
        events_pr: "20%",
        tools_technology: "15%"
      }
    end
  end

  def generate_budget_breakdown
    {
      "Digital Advertising" => 40,
      "Content Creation" => 25,
      "Events & PR" => 20,
      "Tools & Technology" => 15
    }
  end

  def format_creative_approach
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan&.creative_approach&.any?
      campaign_plan.creative_approach
    else
      {
        creative_concept: "Brand-aligned creative direction",
        messaging_theme: "Consistent messaging framework",
        visual_identity: "Professional visual treatment",
        content_strategy: "Engaging content approach"
      }
    end
  end

  def generate_creative_examples
    [ "Hero messaging example", "Visual treatment sample", "Content format examples" ]
  end

  def format_implementation_plan
    {
      week_1_2: "Campaign setup and preparation",
      week_3_6: "Campaign launch and initial execution",
      week_7_12: "Performance monitoring and optimization",
      week_13_16: "Campaign completion and analysis"
    }
  end

  def define_responsibilities
    {
      "Campaign Manager" => "Overall campaign coordination and management",
      "Creative Team" => "Asset creation and brand compliance",
      "Digital Marketing" => "Channel execution and optimization",
      "Analytics Team" => "Performance tracking and reporting"
    }
  end

  def compile_appendix_materials
    [
      "Detailed persona research",
      "Competitive analysis findings",
      "Creative asset specifications",
      "Performance tracking framework"
    ]
  end

  def gather_references
    [
      "Industry research reports",
      "Competitive intelligence sources",
      "Best practice frameworks",
      "Performance benchmarks"
    ]
  end

  def calculate_total_budget
    campaign_plan = @campaign.campaign_plans.first

    if campaign_plan&.budget_allocation&.dig("total_budget")
      "$#{campaign_plan.budget_allocation['total_budget'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    elsif @campaign.target_metrics&.dig("budget")
      "$#{@campaign.target_metrics['budget'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    else
      "$50,000"
    end
  end
end
