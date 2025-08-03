# frozen_string_literal: true

# CustomReportsController handles CRUD operations for custom reports
# Includes drag-and-drop report builder, preview, and export functionality
class CustomReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_brand
  before_action :set_custom_report, only: [ :show, :edit, :update, :destroy, :builder, :preview, :export, :duplicate ]
  before_action :authorize_report_access, only: [ :show, :edit, :update, :destroy, :builder, :preview, :export ]

  # GET /custom_reports
  def index
    @reports = current_user.custom_reports
                          .where(brand: @brand)
                          .includes(:report_metrics, :report_schedules, :report_exports)

    # Apply filters
    @reports = @reports.by_type(params[:type]) if params[:type].present?
    @reports = @reports.where(status: params[:status]) if params[:status].present?

    # Search
    if params[:search].present?
      @reports = @reports.where(
        "name ILIKE ? OR description ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    # Sort
    case params[:sort]
    when "name"
      @reports = @reports.order(:name)
    when "updated"
      @reports = @reports.order(updated_at: :desc)
    when "created"
      @reports = @reports.order(created_at: :desc)
    when "generation_time"
      @reports = @reports.by_generation_time
    else
      @reports = @reports.recent
    end

    @reports = @reports.page(params[:page]).per(20)

    # Stats for dashboard
    @stats = {
      total_reports: current_user.custom_reports.where(brand: @brand).count,
      active_reports: current_user.custom_reports.where(brand: @brand, status: "active").count,
      recent_exports: ReportExport.joins(:custom_report)
                                 .where(custom_reports: { user: current_user, brand: @brand })
                                 .where("report_exports.created_at > ?", 7.days.ago)
                                 .count,
      avg_generation_time: calculate_avg_generation_time
    }

    respond_to do |format|
      format.html
      format.json { render json: { reports: @reports, stats: @stats } }
    end
  end

  # GET /custom_reports/:id
  def show
    @recent_exports = @custom_report.report_exports.recent.limit(5)
    @schedules = @custom_report.report_schedules.active

    respond_to do |format|
      format.html
      format.json { render json: @custom_report.as_json(include: [ :report_metrics, :report_schedules ]) }
    end
  end

  # GET /custom_reports/new
  def new
    @custom_report = current_user.custom_reports.build(brand: @brand)
    @templates = ReportTemplate.public_templates.by_category(params[:category])
    @data_sources = CustomReport.available_data_sources

    # If creating from template
    if params[:template_id].present?
      @template = ReportTemplate.find(params[:template_id])
      @custom_report.assign_attributes(
        name: @template.name,
        description: @template.description,
        report_type: @template.template_type,
        configuration: @template.configuration.deep_dup
      )
    end
  end

  # POST /custom_reports
  def create
    @custom_report = current_user.custom_reports.build(custom_report_params)
    @custom_report.brand = @brand

    if @custom_report.save
      # Create metrics if provided
      create_metrics_from_params if params[:metrics].present?

      redirect_to custom_report_path(@custom_report),
                  notice: "Report was successfully created."
    else
      @templates = ReportTemplate.public_templates
      @data_sources = CustomReport.available_data_sources
      render :new, status: :unprocessable_entity
    end
  end

  # GET /custom_reports/:id/edit
  def edit
    @data_sources = CustomReport.available_data_sources
    @visualization_types = CustomReport.visualization_types
  end

  # PATCH/PUT /custom_reports/:id
  def update
    if @custom_report.update(custom_report_params)
      # Update metrics if provided
      update_metrics_from_params if params[:metrics].present?

      redirect_to @custom_report, notice: "Report was successfully updated."
    else
      @data_sources = CustomReport.available_data_sources
      @visualization_types = CustomReport.visualization_types
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /custom_reports/:id
  def destroy
    @custom_report.destroy
    redirect_to custom_reports_url, notice: "Report was successfully deleted."
  end

  # GET /custom_reports/:id/builder
  def builder
    @data_sources = CustomReport.available_data_sources
    @visualization_types = CustomReport.visualization_types
    @available_metrics = build_available_metrics_hash
    @brand_integrations = check_brand_integrations

    respond_to do |format|
      format.html
      format.json do
        render json: {
          report: @custom_report.as_json(include: :report_metrics),
          data_sources: @data_sources,
          visualization_types: @visualization_types,
          available_metrics: @available_metrics,
          brand_integrations: @brand_integrations
        }
      end
    end
  end

  # GET /custom_reports/:id/preview
  def preview
    begin
      # Generate preview data (limited dataset for speed)
      preview_service = ReportPreviewService.new(@custom_report)
      @preview_data = preview_service.generate_preview

      respond_to do |format|
        format.html
        format.json { render json: @preview_data }
      end
    rescue StandardError => e
      Rails.logger.error "Report preview failed: #{e.message}"

      respond_to do |format|
        format.html { redirect_to @custom_report, alert: "Preview failed: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # POST /custom_reports/:id/export
  def export
    export_format = params[:format] || "pdf"

    unless %w[pdf excel csv powerpoint].include?(export_format)
      return render json: { error: "Invalid export format" }, status: :bad_request
    end

    # Create export record
    report_export = @custom_report.report_exports.create!(
      user: current_user,
      export_format: export_format,
      status: "pending"
    )

    # Queue generation job
    ReportGenerationJob.perform_later(
      custom_report_id: @custom_report.id,
      export_format: export_format,
      export_id: report_export.id,
      user_id: current_user.id
    )

    respond_to do |format|
      format.html { redirect_to @custom_report, notice: "Export queued successfully." }
      format.json { render json: { export_id: report_export.id, status: "queued" } }
    end
  end

  # POST /custom_reports/:id/duplicate
  def duplicate
    new_report = @custom_report.duplicate(new_name: params[:new_name])

    respond_to do |format|
      format.html { redirect_to new_report, notice: "Report duplicated successfully." }
      format.json { render json: new_report }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to @custom_report, alert: "Duplication failed: #{e.message}" }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # GET /custom_reports/:id/schedule
  def schedule
    @schedule = @custom_report.report_schedules.build
    @distribution_lists = current_user.report_distribution_lists.active.where(brand: @brand)
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id]) if params[:brand_id]
    @brand ||= current_user.brands.first

    unless @brand
      redirect_to brands_path, alert: "Please select a brand first."
    end
  end

  def set_custom_report
    @custom_report = current_user.custom_reports.find(params[:id])
  end

  def authorize_report_access
    unless @custom_report.brand == @brand
      redirect_to custom_reports_path, alert: "Access denied."
    end
  end

  def custom_report_params
    params.require(:custom_report).permit(
      :name, :description, :report_type, :status,
      configuration: {}
    )
  end

  def create_metrics_from_params
    return unless params[:metrics].is_a?(Array)

    params[:metrics].each_with_index do |metric_params, index|
      @custom_report.report_metrics.create!(
        metric_name: metric_params[:metric_name],
        display_name: metric_params[:display_name],
        data_source: metric_params[:data_source],
        aggregation_type: metric_params[:aggregation_type] || "sum",
        filters: metric_params[:filters] || {},
        visualization_config: metric_params[:visualization_config] || {},
        sort_order: index + 1
      )
    end
  end

  def update_metrics_from_params
    return unless params[:metrics].is_a?(Array)

    # Remove existing metrics and recreate (simple approach)
    @custom_report.report_metrics.destroy_all
    create_metrics_from_params
  end

  def build_available_metrics_hash
    CustomReport.available_data_sources.index_with do |source|
      ReportMetric.available_metrics_for(source)
    end
  end

  def check_brand_integrations
    {
      google_analytics: @brand.respond_to?(:google_analytics_connected?) ? @brand.google_analytics_connected? : false,
      google_ads: @brand.respond_to?(:google_ads_connected?) ? @brand.google_ads_connected? : false,
      social_media: @brand.social_media_integrations.active.any?,
      email_marketing: @brand.respond_to?(:email_integrations) ? @brand.email_integrations.active.any? : false,
      crm: @brand.respond_to?(:crm_integrations) ? @brand.crm_integrations.active.any? : false
    }
  end

  def calculate_avg_generation_time
    times = current_user.custom_reports
                        .where(brand: @brand)
                        .where.not(generation_time_ms: nil)
                        .pluck(:generation_time_ms)

    return 0 if times.empty?

    (times.sum / times.count.to_f).round
  end

  def authenticate_user!
    # This assumes you have a current_user method from your authentication system
    return if current_user

    redirect_to new_session_path, alert: "Please sign in to continue."
  end
end
