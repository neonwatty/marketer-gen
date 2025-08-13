class MultiFormatExportService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :export_type, :data_scope, :filters, :formats, :options

  SUPPORTED_FORMATS = %w[csv pdf calendar].freeze
  SUPPORTED_SCOPES = %w[campaigns content_variants content_assets journeys brand_assets all].freeze

  def initialize(export_type:, data_scope: 'all', filters: {}, formats: ['csv'], options: {})
    @export_type = export_type.to_s
    @data_scope = data_scope.to_s
    @filters = filters || {}
    @formats = Array(formats).map(&:to_s) & SUPPORTED_FORMATS
    @options = options || {}
  end

  def export
    validate_parameters!
    
    results = {}
    formats.each do |format|
      results[format] = export_format(format)
    end

    {
      results: results,
      summary: generate_export_summary(results),
      metadata: {
        export_type: export_type,
        data_scope: data_scope,
        formats: formats,
        filters_applied: filters,
        exported_at: Time.current,
        total_formats: formats.length
      }
    }
  end

  def export_to_files(base_directory)
    export_results = export
    file_paths = {}

    export_results[:results].each do |format, result|
      filename = result[:filename]
      filepath = File.join(base_directory, filename)
      
      case format
      when 'csv'
        File.write(filepath, result[:data])
      when 'pdf'
        File.binwrite(filepath, result[:data])
      when 'calendar'
        File.write(filepath, result[:data])
      end
      
      file_paths[format] = filepath
    end

    {
      file_paths: file_paths,
      summary: export_results[:summary],
      metadata: export_results[:metadata]
    }
  end

  # Batch export methods
  def self.export_campaign_package(campaign_id, formats: %w[csv pdf calendar], options: {})
    campaign = Campaign.find(campaign_id)
    
    exports = {}
    
    if formats.include?('csv')
      exports[:csv] = export_campaign_csv(campaign, options)
    end
    
    if formats.include?('pdf')
      exports[:pdf] = export_campaign_pdf(campaign, options)
    end
    
    if formats.include?('calendar')
      exports[:calendar] = export_campaign_calendar(campaign, options)
    end
    
    {
      campaign: campaign,
      exports: exports,
      generated_at: Time.current
    }
  end

  def self.export_comprehensive_report(filters: {}, formats: %w[csv pdf], options: {})
    new(
      export_type: 'comprehensive_report',
      data_scope: 'all',
      filters: filters,
      formats: formats,
      options: options
    ).export
  end

  def self.export_performance_analysis(date_range: nil, formats: %w[csv pdf], options: {})
    filters = {}
    filters[:date_range] = date_range if date_range
    filters[:status] = ['active', 'completed', 'testing']

    new(
      export_type: 'performance_analysis',
      data_scope: 'content_variants',
      filters: filters,
      formats: formats,
      options: options
    ).export
  end

  def self.export_content_calendar(campaign_ids: [], formats: %w[calendar pdf], options: {})
    filters = {}
    filters[:campaign_ids] = campaign_ids if campaign_ids.any?

    new(
      export_type: 'content_calendar',
      data_scope: 'campaigns',
      filters: filters,
      formats: formats,
      options: options
    ).export
  end

  def self.export_brand_package(brand_identity_id, formats: %w[csv pdf], options: {})
    filters = { brand_identity_id: brand_identity_id }

    new(
      export_type: 'brand_package',
      data_scope: 'brand_assets',
      filters: filters,
      formats: formats,
      options: options
    ).export
  end

  private

  def validate_parameters!
    unless SUPPORTED_SCOPES.include?(data_scope)
      raise ArgumentError, "Unsupported data scope: #{data_scope}. Supported: #{SUPPORTED_SCOPES.join(', ')}"
    end

    if formats.empty?
      raise ArgumentError, "At least one format must be specified"
    end

    invalid_formats = formats - SUPPORTED_FORMATS
    if invalid_formats.any?
      raise ArgumentError, "Unsupported formats: #{invalid_formats.join(', ')}. Supported: #{SUPPORTED_FORMATS.join(', ')}"
    end
  end

  def export_format(format)
    case format
    when 'csv'
      export_csv_format
    when 'pdf'
      export_pdf_format
    when 'calendar'
      export_calendar_format
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  def export_csv_format
    case data_scope
    when 'campaigns'
      CsvExportService.export_campaigns(filters: filters, options: options)
    when 'content_variants'
      CsvExportService.export_content_variants(filters: filters, options: options)
    when 'content_assets'
      CsvExportService.export_content_assets(filters: filters, options: options)
    when 'journeys'
      CsvExportService.export_journeys(filters: filters, options: options)
    when 'brand_assets'
      CsvExportService.export_brand_assets(filters: filters, options: options)
    when 'all'
      export_all_data_csv
    else
      raise ArgumentError, "Unsupported CSV data scope: #{data_scope}"
    end
  end

  def export_pdf_format
    case export_type
    when 'campaign_report'
      export_campaign_pdf_report
    when 'content_deck'
      export_content_deck_pdf
    when 'performance_analysis'
      export_performance_pdf
    when 'brand_package'
      export_brand_package_pdf
    when 'comprehensive_report'
      export_comprehensive_pdf
    else
      export_standard_pdf_report
    end
  end

  def export_calendar_format
    case data_scope
    when 'campaigns'
      export_campaigns_calendar
    when 'content_variants'
      export_content_calendar
    when 'journeys'
      export_journeys_calendar
    when 'all'
      export_comprehensive_calendar
    else
      raise ArgumentError, "Calendar export not supported for scope: #{data_scope}"
    end
  end

  # CSV export methods
  def export_all_data_csv
    all_data = CsvExportService.export_all_data(
      date_range: filters[:date_range],
      options: options
    )
    
    # Combine all CSV data into a single archive or return the comprehensive set
    if options[:combine_csv]
      combine_csv_data(all_data)
    else
      all_data[:campaigns] # Return campaigns as primary data
    end
  end

  def combine_csv_data(all_data)
    combined_csv = "# Marketing Platform Data Export\n"
    combined_csv += "# Generated at: #{Time.current}\n\n"
    
    all_data.each do |type, data|
      combined_csv += "## #{type.to_s.humanize}\n"
      combined_csv += data[:data]
      combined_csv += "\n\n"
    end
    
    {
      data: combined_csv,
      filename: "marketing_platform_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
      content_type: 'text/csv',
      metadata: all_data.values.first[:metadata].merge(combined: true)
    }
  end

  # PDF export methods
  def export_campaign_pdf_report
    campaign_id = filters[:campaign_id] || filters[:ids]&.first
    return standard_pdf_error('No campaign specified') unless campaign_id

    campaign = Campaign.find(campaign_id)
    PdfExportService.generate_campaign_pdf(campaign, options: options)
  end

  def export_content_deck_pdf
    content_variants = fetch_content_variants
    PdfExportService.generate_content_deck(content_variants, options: options)
  end

  def export_performance_pdf
    performance_data = build_performance_data
    PdfExportService.generate_performance_report(performance_data, options: options)
  end

  def export_brand_package_pdf
    brand_identity_id = filters[:brand_identity_id]
    return standard_pdf_error('No brand identity specified') unless brand_identity_id

    brand_identity = BrandIdentity.find(brand_identity_id)
    PdfExportService.generate_brand_guidelines(brand_identity, options: options)
  end

  def export_comprehensive_pdf
    comprehensive_data = {
      campaigns: fetch_campaigns,
      content_variants: fetch_content_variants,
      journeys: fetch_journeys,
      performance_summary: build_performance_summary
    }
    
    PdfExportService.new(
      content_data: comprehensive_data,
      template_type: :comprehensive_report,
      options: options
    ).generate
  end

  def export_standard_pdf_report
    data = case data_scope
           when 'campaigns'
             { campaigns: fetch_campaigns }
           when 'content_variants'
             { content_variants: fetch_content_variants }
           when 'journeys'
             { journeys: fetch_journeys }
           else
             { message: "Standard PDF report for #{data_scope}" }
           end

    PdfExportService.new(
      content_data: data,
      template_type: :standard,
      options: options
    ).generate
  end

  def standard_pdf_error(message)
    {
      data: nil,
      filename: 'error.pdf',
      content_type: 'application/pdf',
      metadata: { error: message }
    }
  end

  # Calendar export methods
  def export_campaigns_calendar
    campaigns = fetch_campaigns
    CalendarExportService.export_comprehensive_schedule(
      campaigns: campaigns,
      options: options
    )
  end

  def export_content_calendar
    content_variants = fetch_content_variants
    CalendarExportService.export_content_publishing_schedule(
      content_variants,
      options: options
    )
  end

  def export_journeys_calendar
    journeys = fetch_journeys
    CalendarExportService.export_journey_schedule(journeys, options: options)
  end

  def export_comprehensive_calendar
    CalendarExportService.export_comprehensive_schedule(
      campaigns: fetch_campaigns,
      content_variants: fetch_content_variants,
      journeys: fetch_journeys,
      options: options
    )
  end

  # Data fetching methods
  def fetch_campaigns
    query = Campaign.all
    apply_common_filters(query, Campaign)
  end

  def fetch_content_variants
    query = ContentVariant.all
    apply_common_filters(query, ContentVariant)
  end

  def fetch_journeys
    query = Journey.all
    apply_common_filters(query, Journey)
  end

  def fetch_content_assets
    query = ContentAsset.all
    apply_common_filters(query, ContentAsset)
  end

  def fetch_brand_assets
    query = BrandAsset.all
    apply_common_filters(query, BrandAsset)
  end

  def apply_common_filters(query, model_class)
    filters.each do |key, value|
      next if value.blank?

      case key.to_s
      when 'status'
        query = query.where(status: value) if model_class.column_names.include?('status')
      when 'date_range'
        if value.is_a?(Hash) && value[:start] && value[:end]
          query = query.where(created_at: value[:start]..value[:end])
        end
      when 'campaign_id', 'campaign_ids'
        campaign_ids = Array(value)
        if model_class.column_names.include?('campaign_id')
          query = query.where(campaign_id: campaign_ids)
        elsif model_class.reflect_on_association(:campaign)
          query = query.joins(:campaign).where(campaigns: { id: campaign_ids })
        end
      when 'brand_identity_id'
        if model_class.column_names.include?('brand_identity_id')
          query = query.where(brand_identity_id: value)
        elsif model_class.reflect_on_association(:brand_identity)
          query = query.joins(:brand_identity).where(brand_identities: { id: value })
        end
      when 'ids'
        query = query.where(id: Array(value))
      when 'limit'
        query = query.limit(value.to_i)
      end
    end

    # Apply ordering
    order_by = options[:order_by] || 'created_at'
    order_direction = options[:order_direction] || 'desc'
    query = query.order("#{order_by} #{order_direction}")

    query
  end

  def build_performance_data
    content_variants = fetch_content_variants
    
    {
      total_variants: content_variants.count,
      performance_variants: content_variants.where.not(performance_score: nil),
      avg_performance: content_variants.average(:performance_score),
      top_performers: content_variants.where('performance_score > ?', 0.7).limit(10),
      strategy_distribution: content_variants.group(:strategy_type).count,
      monthly_performance: build_monthly_performance_data(content_variants)
    }
  end

  def build_performance_summary
    {
      campaigns_count: fetch_campaigns.count,
      content_variants_count: fetch_content_variants.count,
      journeys_count: fetch_journeys.count,
      active_campaigns: fetch_campaigns.where(status: 'active').count,
      completed_campaigns: fetch_campaigns.where(status: 'completed').count
    }
  end

  def build_monthly_performance_data(content_variants)
    # Group variants by month and calculate average performance
    content_variants.group_by_month(:created_at).group(:strategy_type).average(:performance_score)
  end

  def generate_export_summary(results)
    summary = {
      total_exports: results.length,
      successful_exports: results.count { |_, result| result[:data].present? },
      failed_exports: results.count { |_, result| result[:data].blank? },
      total_file_size: 0
    }

    results.each do |format, result|
      if result[:data]
        summary[:total_file_size] += result[:data].bytesize
        summary["#{format}_size"] = result[:data].bytesize
      end
    end

    summary
  end

  # Static helper methods for specific use cases
  def self.export_campaign_csv(campaign, options = {})
    filters = { campaign_id: campaign.id }
    CsvExportService.export_campaign_summary(campaign.id, options: options)
  end

  def self.export_campaign_pdf(campaign, options = {})
    PdfExportService.generate_campaign_pdf(campaign, options: options)
  end

  def self.export_campaign_calendar(campaign, options = {})
    CalendarExportService.export_campaign_schedule(campaign, options: options)
  end

  # Bulk processing methods
  def self.bulk_export_campaigns(campaign_ids, formats: %w[csv], options: {})
    results = {}
    
    campaign_ids.each do |campaign_id|
      begin
        campaign = Campaign.find(campaign_id)
        results[campaign_id] = export_campaign_package(campaign_id, formats: formats, options: options)
      rescue => e
        results[campaign_id] = { error: e.message }
      end
    end
    
    results
  end

  def self.scheduled_export(export_config)
    # For scheduled exports (would be called by a background job)
    new(
      export_type: export_config[:export_type],
      data_scope: export_config[:data_scope],
      filters: export_config[:filters],
      formats: export_config[:formats],
      options: export_config[:options]
    ).export
  end
end