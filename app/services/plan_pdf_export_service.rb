class PlanPdfExportService
  def initialize(campaign_plan)
    @campaign_plan = campaign_plan
  end

  def generate_pdf
    return { success: false, message: 'Plan not completed' } unless @campaign_plan.completed?

    pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
    
    begin
      add_header(pdf)
      add_plan_overview(pdf)
      add_strategic_overview(pdf)
      add_timeline(pdf)
      add_content_strategy(pdf)
      add_creative_approach(pdf)
      add_content_mapping(pdf)
      add_footer(pdf)

      { success: true, pdf: pdf }
    rescue => e
      { success: false, message: "PDF generation failed: #{e.message}" }
    end
  end

  private

  def add_header(pdf)
    pdf.font_size 24
    pdf.text "Campaign Plan: #{@campaign_plan.name}", align: :center, style: :bold
    pdf.move_down 10
    
    pdf.font_size 12
    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center
    pdf.move_down 20
    
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_plan_overview(pdf)
    pdf.font_size 16
    pdf.text "Plan Overview", style: :bold
    pdf.move_down 10
    
    pdf.font_size 10
    
    overview_data = [
      ["Campaign Type", @campaign_plan.campaign_type.humanize],
      ["Objective", @campaign_plan.objective.humanize],
      ["Status", @campaign_plan.status.humanize],
      ["Created", @campaign_plan.created_at.strftime('%B %d, %Y')],
      ["Last Updated", @campaign_plan.updated_at.strftime('%B %d, %Y')]
    ]
    
    if @campaign_plan.description.present?
      overview_data << ["Description", @campaign_plan.description]
    end

    pdf.table(overview_data, width: pdf.bounds.width, cell_style: { borders: [] }) do
      cells.padding = [2, 5, 2, 5]
      column(0).font_style = :bold
      column(0).width = 120
    end
    
    pdf.move_down 20
  end

  def add_strategic_overview(pdf)
    return unless strategic_content_present?
    
    pdf.font_size 16
    pdf.text "Strategic Overview", style: :bold
    pdf.move_down 10
    
    if @campaign_plan.generated_summary.present?
      pdf.font_size 12
      pdf.text "Summary", style: :bold
      pdf.move_down 5
      pdf.font_size 10
      pdf.text @campaign_plan.generated_summary
      pdf.move_down 15
    end

    if strategy_data.present?
      pdf.font_size 12
      pdf.text "Strategy Details", style: :bold
      pdf.move_down 5
      pdf.font_size 10
      add_json_content(pdf, strategy_data)
      pdf.move_down 15
    end

    if strategic_rationale_data.present?
      pdf.font_size 12
      pdf.text "Strategic Rationale", style: :bold
      pdf.move_down 5
      pdf.font_size 10
      add_json_content(pdf, strategic_rationale_data)
      pdf.move_down 15
    end
  end

  def add_timeline(pdf)
    return unless timeline_data.present?
    
    pdf.font_size 16
    pdf.text "Campaign Timeline", style: :bold
    pdf.move_down 10
    
    pdf.font_size 10
    add_json_content(pdf, timeline_data)
    pdf.move_down 20
  end

  def add_content_strategy(pdf)
    return unless content_strategy_data.present?
    
    pdf.font_size 16
    pdf.text "Content Strategy", style: :bold
    pdf.move_down 10
    
    pdf.font_size 10
    add_json_content(pdf, content_strategy_data)
    pdf.move_down 20
  end

  def add_creative_approach(pdf)
    return unless creative_approach_data.present?
    
    pdf.font_size 16
    pdf.text "Creative Approach", style: :bold
    pdf.move_down 10
    
    pdf.font_size 10
    add_json_content(pdf, creative_approach_data)
    pdf.move_down 20
  end

  def add_content_mapping(pdf)
    return unless content_mapping_data.present?
    
    pdf.font_size 16
    pdf.text "Content Mapping", style: :bold
    pdf.move_down 10
    
    pdf.font_size 10
    add_json_content(pdf, content_mapping_data)
    pdf.move_down 20
  end

  def add_footer(pdf)
    pdf.number_pages "<page> of <total>", at: [pdf.bounds.right - 50, 0], width: 50, align: :right, size: 8
  end

  def add_json_content(pdf, data)
    case data
    when Hash
      data.each do |key, value|
        pdf.text "#{key.to_s.humanize}:", style: :bold
        pdf.move_down 2
        add_json_content(pdf, value)
        pdf.move_down 8
      end
    when Array
      data.each_with_index do |item, index|
        pdf.text "#{index + 1}. ", style: :bold
        add_json_content(pdf, item)
        pdf.move_down 5
      end
    else
      pdf.text data.to_s
    end
  end

  def strategic_content_present?
    @campaign_plan.generated_summary.present? || 
    strategy_data.present? || 
    strategic_rationale_data.present?
  end

  def strategy_data
    @strategy_data ||= safe_parse_json(@campaign_plan.generated_strategy)
  end

  def timeline_data
    @timeline_data ||= safe_parse_json(@campaign_plan.generated_timeline)
  end

  def content_strategy_data
    @content_strategy_data ||= safe_parse_json(@campaign_plan.content_strategy)
  end

  def creative_approach_data
    @creative_approach_data ||= safe_parse_json(@campaign_plan.creative_approach)
  end

  def strategic_rationale_data
    @strategic_rationale_data ||= safe_parse_json(@campaign_plan.strategic_rationale)
  end

  def content_mapping_data
    @content_mapping_data ||= safe_parse_json(@campaign_plan.content_mapping)
  end

  def safe_parse_json(json_field)
    return nil if json_field.blank?
    
    case json_field
    when Hash
      json_field
    when String
      JSON.parse(json_field)
    else
      nil
    end
  rescue JSON::ParserError
    nil
  end
end