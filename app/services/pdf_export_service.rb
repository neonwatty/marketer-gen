require 'prawn'
require 'prawn/table'

class PdfExportService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :content_data, :template_type, :brand_settings, :options

  def initialize(content_data:, template_type: :standard, brand_settings: {}, options: {})
    @content_data = content_data
    @template_type = template_type.to_sym
    @brand_settings = brand_settings || {}
    @options = options || {}
  end

  def generate
    pdf = create_pdf_document
    
    case template_type
    when :content_deck
      generate_content_deck(pdf)
    when :campaign_report
      generate_campaign_report(pdf)
    when :performance_summary
      generate_performance_summary(pdf)
    when :brand_guidelines
      generate_brand_guidelines(pdf)
    when :content_calendar
      generate_content_calendar(pdf)
    else
      generate_standard_report(pdf)
    end

    {
      data: pdf.render,
      filename: generate_filename,
      content_type: 'application/pdf',
      metadata: {
        template_type: template_type,
        pages: pdf.page_count,
        generated_at: Time.current,
        brand_applied: brand_settings.present?
      }
    }
  end

  def generate_to_file(filepath)
    result = generate
    File.binwrite(filepath, result[:data])
    filepath
  end

  # Static methods for different PDF types
  def self.generate_campaign_pdf(campaign, options: {})
    content_data = {
      campaign: campaign,
      content_variants: campaign.respond_to?(:content_variants) ? campaign.content_variants : [],
      journeys: campaign.journeys || [],
      assets: campaign.content_assets || []
    }

    new(
      content_data: content_data,
      template_type: :campaign_report,
      brand_settings: extract_brand_settings(campaign),
      options: options
    ).generate
  end

  def self.generate_content_deck(content_variants, options: {})
    new(
      content_data: { content_variants: content_variants },
      template_type: :content_deck,
      options: options
    ).generate
  end

  def self.generate_performance_report(data, options: {})
    new(
      content_data: data,
      template_type: :performance_summary,
      options: options
    ).generate
  end

  def self.generate_brand_guidelines(brand_identity, options: {})
    content_data = {
      brand_identity: brand_identity,
      assets: brand_identity.respond_to?(:brand_assets) ? brand_identity.brand_assets : []
    }

    new(
      content_data: content_data,
      template_type: :brand_guidelines,
      brand_settings: extract_brand_settings_from_identity(brand_identity),
      options: options
    ).generate
  end

  private

  def create_pdf_document
    pdf_options = default_pdf_options.merge(options[:pdf_options] || {})
    Prawn::Document.new(pdf_options)
  end

  def default_pdf_options
    {
      page_size: 'A4',
      margin: 50,
      info: {
        Title: generate_title,
        Creator: 'Marketing Campaign Platform',
        CreationDate: Time.current
      }
    }
  end

  def generate_title
    case template_type
    when :campaign_report
      "Campaign Report - #{content_data[:campaign]&.name || 'Campaign'}"
    when :content_deck
      "Content Deck - #{content_data[:content_variants]&.length || 0} Variants"
    when :performance_summary
      'Performance Summary Report'
    when :brand_guidelines
      "Brand Guidelines - #{content_data[:brand_identity]&.name || 'Brand'}"
    when :content_calendar
      'Content Calendar Export'
    else
      'Marketing Report'
    end
  end

  def generate_filename
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    base_name = template_type.to_s.gsub('_', '-')
    "#{base_name}-#{timestamp}.pdf"
  end

  # PDF Generation Methods for Different Templates

  def generate_content_deck(pdf)
    add_header(pdf, 'Content Deck')
    add_brand_elements(pdf) if brand_settings.present?

    content_variants = content_data[:content_variants] || []
    
    if content_variants.empty?
      pdf.text 'No content variants available for export.', size: 12
      return
    end

    # Table of contents
    add_table_of_contents(pdf, content_variants)
    pdf.start_new_page

    # Individual content pages
    content_variants.each_with_index do |variant, index|
      add_content_variant_page(pdf, variant, index + 1)
      pdf.start_new_page unless index == content_variants.length - 1
    end

    add_footer(pdf)
  end

  def generate_campaign_report(pdf)
    campaign = content_data[:campaign]
    add_header(pdf, "Campaign Report: #{campaign.name}")
    add_brand_elements(pdf) if brand_settings.present?

    # Campaign overview
    add_campaign_overview(pdf, campaign)
    
    # Performance metrics
    add_performance_metrics(pdf, campaign)
    
    # Content summary
    add_content_summary(pdf, content_data[:content_variants] || [])
    
    # Journey information
    add_journey_summary(pdf, content_data[:journeys] || [])

    add_footer(pdf)
  end

  def generate_performance_summary(pdf)
    add_header(pdf, 'Performance Summary')
    
    # Performance overview
    add_performance_overview(pdf, content_data)
    
    # Charts and graphs (simplified text-based representations)
    add_performance_charts(pdf, content_data)
    
    # Recommendations
    add_recommendations(pdf, content_data)

    add_footer(pdf)
  end

  def generate_brand_guidelines(pdf)
    brand = content_data[:brand_identity]
    add_header(pdf, "Brand Guidelines: #{brand.name}")
    
    # Brand overview
    add_brand_overview(pdf, brand)
    
    # Color palette
    add_color_palette(pdf, brand)
    
    # Typography
    add_typography_guidelines(pdf, brand)
    
    # Asset gallery
    add_asset_gallery(pdf, content_data[:assets] || [])

    add_footer(pdf)
  end

  def generate_content_calendar(pdf)
    add_header(pdf, 'Content Calendar')
    
    calendar_data = content_data[:calendar_items] || []
    add_calendar_view(pdf, calendar_data)

    add_footer(pdf)
  end

  def generate_standard_report(pdf)
    add_header(pdf, 'Marketing Report')
    
    pdf.text 'This is a standard report template.', size: 12
    pdf.move_down 20
    
    # Add any provided data
    content_data.each do |key, value|
      next unless value.present?
      
      pdf.text key.to_s.humanize, style: :bold, size: 14
      pdf.move_down 10
      
      if value.is_a?(Array)
        add_data_table(pdf, value)
      else
        pdf.text value.to_s, size: 10
      end
      
      pdf.move_down 20
    end

    add_footer(pdf)
  end

  # Helper Methods for PDF Elements

  def add_header(pdf, title)
    pdf.font_size 24
    pdf.text title, style: :bold, align: :center
    pdf.move_down 10
    
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_brand_elements(pdf)
    # Add brand colors, logo placeholder, etc.
    if brand_settings[:primary_color]
      pdf.fill_color brand_settings[:primary_color]
      pdf.text 'Brand Color Applied', size: 8, align: :right
      pdf.fill_color '000000' # Reset to black
    end

    if brand_settings[:logo_text]
      pdf.text brand_settings[:logo_text], size: 10, align: :right, style: :italic
    end

    pdf.move_down 10
  end

  def add_table_of_contents(pdf, content_variants)
    pdf.text 'Table of Contents', size: 18, style: :bold
    pdf.move_down 15

    content_variants.each_with_index do |variant, index|
      pdf.text "#{index + 1}. #{variant.name || "Variant #{variant.variant_number}"}", size: 12
      pdf.move_down 5
    end
  end

  def add_content_variant_page(pdf, variant, page_number)
    pdf.text "Content Variant #{page_number}", size: 18, style: :bold
    pdf.move_down 10

    # Variant details
    details = [
      ['Name', variant.name || 'Unnamed'],
      ['Strategy Type', variant.strategy_type&.humanize || 'N/A'],
      ['Status', variant.status&.humanize || 'N/A'],
      ['Performance Score', variant.respond_to?(:performance_score) ? variant.performance_score&.round(3) : 'N/A']
    ]

    pdf.table(details, width: pdf.bounds.width) do
      cells.border_width = 1
      cells.padding = 8
      columns(0).font_style = :bold
      columns(0).width = 150
    end

    pdf.move_down 20

    # Content
    pdf.text 'Content:', size: 14, style: :bold
    pdf.move_down 10
    
    content_text = variant.content || 'No content available'
    pdf.text content_text, size: 10, leading: 5

    pdf.move_down 20

    # Performance data if available
    if variant.respond_to?(:performance_data) && variant.performance_data.present?
      add_performance_data_section(pdf, variant.performance_data)
    end
  end

  def add_campaign_overview(pdf, campaign)
    pdf.text 'Campaign Overview', size: 16, style: :bold
    pdf.move_down 10

    overview_data = [
      ['Campaign Name', campaign.name],
      ['Status', campaign.status&.humanize],
      ['Start Date', campaign.start_date&.strftime('%B %d, %Y') || 'Not set'],
      ['End Date', campaign.end_date&.strftime('%B %d, %Y') || 'Not set'],
      ['Duration', campaign.respond_to?(:duration_days) ? "#{campaign.duration_days} days" : 'N/A'],
      ['Budget', campaign.respond_to?(:budget) ? campaign.budget : 'Not set'],
      ['Progress', campaign.respond_to?(:progress_percentage) ? "#{campaign.progress_percentage}%" : 'N/A']
    ]

    pdf.table(overview_data, width: pdf.bounds.width) do
      cells.border_width = 1
      cells.padding = 8
      columns(0).font_style = :bold
      columns(0).width = 150
    end

    pdf.move_down 20

    # Purpose
    if campaign.purpose.present?
      pdf.text 'Purpose:', size: 14, style: :bold
      pdf.move_down 5
      pdf.text campaign.purpose, size: 10
      pdf.move_down 20
    end
  end

  def add_performance_metrics(pdf, campaign)
    pdf.text 'Performance Metrics', size: 16, style: :bold
    pdf.move_down 10

    # This would integrate with actual metrics when available
    metrics = [
      ['Total Content Variants', content_data[:content_variants]&.length || 0],
      ['Active Journeys', content_data[:journeys]&.count { |j| j.status == 'active' } || 0],
      ['Content Assets', content_data[:assets]&.length || 0]
    ]

    pdf.table(metrics, width: pdf.bounds.width) do
      cells.border_width = 1
      cells.padding = 8
      columns(0).font_style = :bold
    end

    pdf.move_down 20
  end

  def add_content_summary(pdf, content_variants)
    return if content_variants.empty?

    pdf.text 'Content Summary', size: 16, style: :bold
    pdf.move_down 10

    # Strategy distribution
    strategies = content_variants.group_by(&:strategy_type)
    strategy_data = strategies.map { |strategy, variants| [strategy&.humanize || 'Unknown', variants.length] }

    if strategy_data.any?
      pdf.text 'Content by Strategy:', size: 12, style: :bold
      pdf.move_down 5

      pdf.table([['Strategy Type', 'Count']] + strategy_data, width: pdf.bounds.width) do
        cells.border_width = 1
        cells.padding = 8
        row(0).font_style = :bold
      end

      pdf.move_down 20
    end
  end

  def add_journey_summary(pdf, journeys)
    return if journeys.empty?

    pdf.text 'Customer Journeys', size: 16, style: :bold
    pdf.move_down 10

    journey_data = journeys.map do |journey|
      [
        journey.name || 'Unnamed Journey',
        journey.status&.humanize || 'Unknown',
        journey.respond_to?(:total_stages) ? journey.total_stages : 'N/A'
      ]
    end

    pdf.table([['Journey Name', 'Status', 'Stages']] + journey_data, width: pdf.bounds.width) do
      cells.border_width = 1
      cells.padding = 8
      row(0).font_style = :bold
    end

    pdf.move_down 20
  end

  def add_performance_overview(pdf, data)
    pdf.text 'Performance Overview', size: 16, style: :bold
    pdf.move_down 10

    # Add summary statistics
    summary_text = "This report provides an overview of marketing performance metrics and insights."
    pdf.text summary_text, size: 10
    pdf.move_down 20
  end

  def add_performance_charts(pdf, data)
    pdf.text 'Performance Charts', size: 16, style: :bold
    pdf.move_down 10

    # Placeholder for charts (in a real implementation, you'd integrate with a charting library)
    pdf.text 'Chart visualizations would appear here in the full implementation.', size: 10, style: :italic
    pdf.move_down 20
  end

  def add_recommendations(pdf, data)
    pdf.text 'Recommendations', size: 16, style: :bold
    pdf.move_down 10

    recommendations = [
      'Continue monitoring campaign performance',
      'Test additional content variations',
      'Optimize based on top-performing strategies',
      'Review and adjust targeting parameters'
    ]

    recommendations.each do |rec|
      pdf.text "• #{rec}", size: 10
      pdf.move_down 5
    end

    pdf.move_down 20
  end

  def add_brand_overview(pdf, brand)
    pdf.text 'Brand Overview', size: 16, style: :bold
    pdf.move_down 10

    if brand.respond_to?(:description) && brand.description.present?
      pdf.text brand.description, size: 10
      pdf.move_down 20
    end
  end

  def add_color_palette(pdf, brand)
    pdf.text 'Color Palette', size: 16, style: :bold
    pdf.move_down 10

    # This would show actual brand colors when available
    pdf.text 'Brand colors would be displayed here with actual color swatches.', size: 10, style: :italic
    pdf.move_down 20
  end

  def add_typography_guidelines(pdf, brand)
    pdf.text 'Typography Guidelines', size: 16, style: :bold
    pdf.move_down 10

    pdf.text 'Font specifications and usage guidelines would appear here.', size: 10, style: :italic
    pdf.move_down 20
  end

  def add_asset_gallery(pdf, assets)
    return if assets.empty?

    pdf.text 'Brand Assets', size: 16, style: :bold
    pdf.move_down 10

    asset_data = assets.map do |asset|
      [
        asset.name || 'Unnamed Asset',
        asset.respond_to?(:asset_type) ? asset.asset_type&.humanize : 'Unknown',
        asset.respond_to?(:file_size) ? format_file_size(asset.file_size) : 'N/A'
      ]
    end

    pdf.table([['Asset Name', 'Type', 'Size']] + asset_data, width: pdf.bounds.width) do
      cells.border_width = 1
      cells.padding = 8
      row(0).font_style = :bold
    end

    pdf.move_down 20
  end

  def add_calendar_view(pdf, calendar_items)
    pdf.text 'Calendar Items', size: 16, style: :bold
    pdf.move_down 10

    if calendar_items.empty?
      pdf.text 'No calendar items available.', size: 10
      return
    end

    # Simple list view of calendar items
    calendar_items.each do |item|
      pdf.text "#{item[:date]}: #{item[:title]}", size: 10
      pdf.move_down 5
    end
  end

  def add_performance_data_section(pdf, performance_data)
    pdf.text 'Performance Data:', size: 12, style: :bold
    pdf.move_down 5

    performance_data.each do |key, value|
      pdf.text "#{key.humanize}: #{value}", size: 9
      pdf.move_down 3
    end

    pdf.move_down 10
  end

  def add_data_table(pdf, data)
    return if data.empty?

    # Convert array of objects to table format
    if data.first.respond_to?(:attributes)
      headers = data.first.attributes.keys.map(&:humanize)
      rows = data.map { |item| item.attributes.values.map(&:to_s) }
      
      pdf.table([headers] + rows, width: pdf.bounds.width) do
        cells.border_width = 1
        cells.padding = 5
        row(0).font_style = :bold
        cells.size = 8
      end
    else
      pdf.text data.join(', '), size: 10
    end
  end

  def add_footer(pdf)
    pdf.number_pages "Page <page> of <total>", 
                     at: [pdf.bounds.right - 150, 0], 
                     width: 150, 
                     align: :right, 
                     size: 9

    pdf.number_pages "Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", 
                     at: [0, 0], 
                     width: 300, 
                     align: :left, 
                     size: 9
  end

  def format_file_size(size_in_bytes)
    return 'N/A' unless size_in_bytes.is_a?(Numeric)

    units = ['B', 'KB', 'MB', 'GB']
    size = size_in_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  # Brand settings extraction helpers
  def self.extract_brand_settings(campaign)
    brand_identity = campaign.respond_to?(:brand_identity) ? campaign.brand_identity : nil
    extract_brand_settings_from_identity(brand_identity)
  end

  def self.extract_brand_settings_from_identity(brand_identity)
    return {} unless brand_identity

    settings = {}
    
    if brand_identity.respond_to?(:primary_color)
      settings[:primary_color] = brand_identity.primary_color
    end
    
    if brand_identity.respond_to?(:name)
      settings[:logo_text] = brand_identity.name
    end
    
    settings
  end
end