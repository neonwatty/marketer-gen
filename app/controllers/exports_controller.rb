class ExportsController < ApplicationController
  before_action :set_export_params, only: [:show, :download]
  
  # GET /exports
  def index
    @available_formats = MultiFormatExportService::SUPPORTED_FORMATS
    @available_scopes = MultiFormatExportService::SUPPORTED_SCOPES
    @available_templates = ExportTemplateService.get_available_templates
    @recent_exports = [] # Could be expanded to track export history
  end

  # POST /exports
  def create
    @export_service = build_export_service
    
    begin
      @result = @export_service.export
      
      if params[:download_immediately]
        download_export(@result[:results][params[:format].to_s])
      else
        render json: {
          success: true,
          message: 'Export generated successfully',
          metadata: @result[:metadata],
          summary: @result[:summary],
          download_urls: build_download_urls(@result[:results])
        }
      end
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/campaigns/:id
  def campaign
    @campaign = Campaign.find(params[:id])
    formats = Array(params[:formats] || ['csv'])
    
    begin
      @result = MultiFormatExportService.export_campaign_package(
        @campaign.id,
        formats: formats,
        options: build_export_options
      )
      
      if params[:download_immediately] && formats.length == 1
        download_export(@result[:exports][formats.first.to_sym])
      else
        render json: {
          success: true,
          campaign: @campaign.name,
          exports: @result[:exports],
          download_urls: build_campaign_download_urls(@campaign.id, @result[:exports])
        }
      end
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/comprehensive
  def comprehensive
    filters = build_filters_from_params
    formats = Array(params[:formats] || ['csv'])
    
    begin
      @result = MultiFormatExportService.export_comprehensive_report(
        filters: filters,
        formats: formats,
        options: build_export_options
      )
      
      render json: {
        success: true,
        message: 'Comprehensive export generated',
        metadata: @result[:metadata],
        summary: @result[:summary],
        download_urls: build_download_urls(@result[:results])
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/performance
  def performance
    date_range = build_date_range_from_params
    formats = Array(params[:formats] || ['csv', 'pdf'])
    
    begin
      @result = MultiFormatExportService.export_performance_analysis(
        date_range: date_range,
        formats: formats,
        options: build_export_options
      )
      
      render json: {
        success: true,
        message: 'Performance analysis export generated',
        metadata: @result[:metadata],
        summary: @result[:summary],
        download_urls: build_download_urls(@result[:results])
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/calendar
  def calendar
    campaign_ids = Array(params[:campaign_ids])
    formats = Array(params[:formats] || ['calendar'])
    
    begin
      @result = MultiFormatExportService.export_content_calendar(
        campaign_ids: campaign_ids,
        formats: formats,
        options: build_export_options
      )
      
      if params[:download_immediately]
        download_export(@result[:results]['calendar'])
      else
        render json: {
          success: true,
          message: 'Calendar export generated',
          metadata: @result[:metadata],
          download_urls: build_download_urls(@result[:results])
        }
      end
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/brand/:id
  def brand
    @brand_identity = BrandIdentity.find(params[:id])
    formats = Array(params[:formats] || ['csv', 'pdf'])
    
    begin
      @result = MultiFormatExportService.export_brand_package(
        @brand_identity.id,
        formats: formats,
        options: build_export_options
      )
      
      render json: {
        success: true,
        brand: @brand_identity.name,
        metadata: @result[:metadata],
        download_urls: build_download_urls(@result[:results])
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # POST /exports/bulk
  def bulk
    campaign_ids = Array(params[:campaign_ids])
    formats = Array(params[:formats] || ['csv'])
    
    if campaign_ids.empty?
      return render json: {
        success: false,
        error: 'No campaign IDs provided'
      }, status: :bad_request
    end
    
    begin
      @results = MultiFormatExportService.bulk_export_campaigns(
        campaign_ids,
        formats: formats,
        options: build_export_options
      )
      
      render json: {
        success: true,
        message: "Bulk export completed for #{campaign_ids.length} campaigns",
        results: @results,
        download_urls: build_bulk_download_urls(@results)
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /exports/download/:type/:format
  def download
    case params[:type]
    when 'campaign'
      download_campaign_export
    when 'comprehensive'
      download_comprehensive_export
    when 'performance'
      download_performance_export
    when 'calendar'
      download_calendar_export
    when 'brand'
      download_brand_export
    else
      render json: { error: 'Invalid export type' }, status: :not_found
    end
  end

  # GET /exports/templates
  def templates
    format_type = params[:format_type]&.to_sym
    
    render json: {
      available_templates: ExportTemplateService.get_available_templates(format_type),
      supported_formats: MultiFormatExportService::SUPPORTED_FORMATS,
      supported_scopes: MultiFormatExportService::SUPPORTED_SCOPES
    }
  end

  # GET /exports/preview
  def preview
    # Generate a preview of the export without creating the full file
    begin
      export_service = build_export_service
      
      # Get a sample of the data
      preview_options = build_export_options.merge(limit: 10)
      export_service.options.merge!(preview_options)
      
      case params[:format]
      when 'csv'
        preview_data = generate_csv_preview(export_service)
      when 'pdf'
        preview_data = generate_pdf_preview(export_service)
      when 'calendar'
        preview_data = generate_calendar_preview(export_service)
      else
        preview_data = { message: 'Preview not available for this format' }
      end
      
      render json: {
        success: true,
        preview: preview_data,
        estimated_size: estimate_export_size(export_service),
        estimated_records: estimate_record_count(export_service)
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  private

  def set_export_params
    @export_type = params[:type]
    @format = params[:format]
    @export_id = params[:id]
  end

  def build_export_service
    case params[:export_type]
    when 'csv'
      build_csv_export_service
    when 'multi_format'
      build_multi_format_export_service
    else
      build_multi_format_export_service
    end
  end

  def build_csv_export_service
    model_class = determine_model_class_from_scope(params[:data_scope])
    
    CsvExportService.new(
      model_class: model_class,
      filters: build_filters_from_params,
      columns: params[:columns],
      options: build_export_options
    )
  end

  def build_multi_format_export_service
    MultiFormatExportService.new(
      export_type: params[:export_type] || 'standard',
      data_scope: params[:data_scope] || 'campaigns',
      filters: build_filters_from_params,
      formats: Array(params[:formats] || ['csv']),
      options: build_export_options
    )
  end

  def determine_model_class_from_scope(scope)
    case scope
    when 'campaigns'
      Campaign
    when 'content_variants'
      ContentVariant
    when 'content_assets'
      ContentAsset
    when 'journeys'
      Journey
    when 'brand_assets'
      BrandAsset
    else
      Campaign
    end
  end

  def build_filters_from_params
    filters = {}
    
    filters[:status] = params[:status] if params[:status].present?
    filters[:campaign_id] = params[:campaign_id] if params[:campaign_id].present?
    filters[:campaign_ids] = Array(params[:campaign_ids]) if params[:campaign_ids].present?
    filters[:brand_identity_id] = params[:brand_identity_id] if params[:brand_identity_id].present?
    filters[:search] = params[:search] if params[:search].present?
    filters[:ids] = Array(params[:ids]) if params[:ids].present?
    
    if params[:date_range].present?
      filters[:date_range] = build_date_range_from_params
    end
    
    filters
  end

  def build_date_range_from_params
    return nil unless params[:date_range].present?
    
    case params[:date_range]
    when Hash
      {
        start: params[:date_range][:start]&.to_date,
        end: params[:date_range][:end]&.to_date
      }
    when String
      case params[:date_range]
      when 'last_7_days'
        { start: 7.days.ago.to_date, end: Date.current }
      when 'last_30_days'
        { start: 30.days.ago.to_date, end: Date.current }
      when 'last_90_days'
        { start: 90.days.ago.to_date, end: Date.current }
      when 'this_month'
        { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
      when 'last_month'
        last_month = 1.month.ago
        { start: last_month.beginning_of_month, end: last_month.end_of_month }
      else
        nil
      end
    else
      nil
    end
  end

  def build_export_options
    options = {}
    
    options[:order_by] = params[:order_by] if params[:order_by].present?
    options[:order_direction] = params[:order_direction] if params[:order_direction].present?
    options[:limit] = params[:limit].to_i if params[:limit].present?
    options[:timezone] = params[:timezone] if params[:timezone].present?
    options[:template] = params[:template] if params[:template].present?
    
    # Brand settings
    if params[:brand_identity_id].present?
      brand_identity = BrandIdentity.find_by(id: params[:brand_identity_id])
      if brand_identity
        options[:brand_settings] = ExportTemplateService.extract_brand_settings_from_identity(brand_identity)
      end
    end
    
    options
  end

  def build_download_urls(results)
    urls = {}
    
    results.each do |format, result|
      urls[format] = rails_export_download_url(
        type: params[:export_type] || 'standard',
        format: format,
        timestamp: Time.current.to_i
      )
    end
    
    urls
  end

  def build_campaign_download_urls(campaign_id, exports)
    urls = {}
    
    exports.each do |format, export_data|
      next if export_data[:error]
      
      urls[format] = rails_export_download_url(
        type: 'campaign',
        format: format,
        id: campaign_id,
        timestamp: Time.current.to_i
      )
    end
    
    urls
  end

  def build_bulk_download_urls(results)
    urls = {}
    
    results.each do |campaign_id, campaign_results|
      next if campaign_results[:error]
      
      urls[campaign_id] = {}
      campaign_results[:exports]&.each do |format, export_data|
        urls[campaign_id][format] = rails_export_download_url(
          type: 'campaign',
          format: format,
          id: campaign_id,
          timestamp: Time.current.to_i
        )
      end
    end
    
    urls
  end

  def download_export(export_result)
    return render json: { error: 'Export data not found' }, status: :not_found unless export_result

    filename = export_result[:filename]
    content_type = export_result[:content_type]
    data = export_result[:data]

    send_data data,
              filename: filename,
              type: content_type,
              disposition: 'attachment'
  end

  def download_campaign_export
    campaign = Campaign.find(params[:id])
    format = params[:format]
    
    export_result = case format
                   when 'csv'
                     MultiFormatExportService.export_campaign_csv(campaign, build_export_options)
                   when 'pdf'
                     MultiFormatExportService.export_campaign_pdf(campaign, build_export_options)
                   when 'calendar'
                     MultiFormatExportService.export_campaign_calendar(campaign, build_export_options)
                   else
                     return render json: { error: 'Unsupported format' }, status: :bad_request
                   end

    download_export(export_result)
  end

  def download_comprehensive_export
    filters = build_filters_from_params
    format = params[:format]
    
    result = MultiFormatExportService.export_comprehensive_report(
      filters: filters,
      formats: [format],
      options: build_export_options
    )
    
    download_export(result[:results][format])
  end

  def download_performance_export
    date_range = build_date_range_from_params
    format = params[:format]
    
    result = MultiFormatExportService.export_performance_analysis(
      date_range: date_range,
      formats: [format],
      options: build_export_options
    )
    
    download_export(result[:results][format])
  end

  def download_calendar_export
    campaign_ids = Array(params[:campaign_ids])
    
    result = MultiFormatExportService.export_content_calendar(
      campaign_ids: campaign_ids,
      formats: ['calendar'],
      options: build_export_options
    )
    
    download_export(result[:results]['calendar'])
  end

  def download_brand_export
    brand_identity = BrandIdentity.find(params[:id])
    format = params[:format]
    
    result = MultiFormatExportService.export_brand_package(
      brand_identity.id,
      formats: [format],
      options: build_export_options
    )
    
    download_export(result[:results][format])
  end

  # Preview methods
  def generate_csv_preview(export_service)
    # Generate a small sample CSV
    sample_result = export_service.export
    lines = sample_result[:data].split("\n")
    
    {
      headers: lines.first,
      sample_rows: lines[1..5], # Show first 5 data rows
      total_estimated_rows: sample_result[:metadata][:total_records]
    }
  end

  def generate_pdf_preview(export_service)
    {
      message: 'PDF preview shows document structure and branding',
      estimated_pages: 'Unknown',
      template_type: export_service.template_type || 'standard'
    }
  end

  def generate_calendar_preview(export_service)
    {
      message: 'Calendar preview shows event structure',
      estimated_events: 'Unknown',
      calendar_name: export_service.calendar_name || 'Marketing Calendar'
    }
  end

  def estimate_export_size(export_service)
    # Rough estimation based on format and data scope
    case export_service.class.name
    when 'CsvExportService'
      'Small to Medium (KB to MB range)'
    when 'PdfExportService'
      'Medium (MB range)'
    when 'CalendarExportService'
      'Small (KB range)'
    else
      'Unknown'
    end
  end

  def estimate_record_count(export_service)
    # This would need to be implemented based on filters and scope
    'Estimated based on current filters'
  end

  def rails_export_download_url(params)
    # Generate download URL - this would need to be implemented based on routing
    export_download_url(params)
  rescue
    "#download-url-for-#{params[:type]}-#{params[:format]}"
  end
end