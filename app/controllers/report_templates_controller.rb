# frozen_string_literal: true

# ReportTemplatesController manages predefined report templates
# Users can browse, create, and instantiate templates
class ReportTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_brand
  before_action :set_report_template, only: [ :show, :edit, :update, :destroy, :clone, :instantiate ]
  before_action :authorize_template_access, only: [ :edit, :update, :destroy ]

  # GET /report_templates
  def index
    @templates = ReportTemplate.active.includes(:user)

    # Filter by category
    @templates = @templates.by_category(params[:category]) if params[:category].present?

    # Filter by type
    @templates = @templates.by_type(params[:type]) if params[:type].present?

    # Filter public/private
    case params[:scope]
    when "public"
      @templates = @templates.public_templates
    when "mine"
      @templates = @templates.where(user: current_user)
    else
      # Show both public templates and user's private templates
      @templates = @templates.where(
        "is_public = ? OR user_id = ?",
        true, current_user.id
      )
    end

    # Search
    if params[:search].present?
      @templates = @templates.search(params[:search])
    end

    # Sort
    case params[:sort]
    when "name"
      @templates = @templates.order(:name)
    when "rating"
      @templates = @templates.order(rating: :desc, rating_count: :desc)
    when "usage"
      @templates = @templates.order(usage_count: :desc)
    when "recent"
      @templates = @templates.recent
    else
      @templates = @templates.order(rating: :desc, usage_count: :desc)
    end

    @templates = @templates.page(params[:page]).per(20)

    # Categories for sidebar
    @categories = ReportTemplate.categories_with_counts

    # Popular templates
    @popular_templates = ReportTemplate.popular.limit(5)

    respond_to do |format|
      format.html
      format.json { render json: { templates: @templates, categories: @categories } }
    end
  end

  # GET /report_templates/:id
  def show
    @can_edit = @report_template.user == current_user
    @usage_stats = {
      total_usage: @report_template.usage_count,
      rating: @report_template.rating,
      rating_count: @report_template.rating_count
    }

    respond_to do |format|
      format.html
      format.json { render json: @report_template.as_json(include: :user) }
    end
  end

  # GET /report_templates/new
  def new
    @report_template = current_user.report_templates.build
    @categories = %w[marketing sales analytics performance social_media email_marketing general]
    @template_types = %w[standard dashboard summary detailed custom]

    # If converting from existing report
    if params[:from_report_id].present?
      source_report = current_user.custom_reports.find(params[:from_report_id])
      @report_template.assign_attributes(
        name: "#{source_report.name} Template",
        description: source_report.description,
        template_type: source_report.report_type,
        configuration: source_report.configuration.deep_dup
      )
    end
  end

  # POST /report_templates
  def create
    @report_template = current_user.report_templates.build(report_template_params)

    if @report_template.save
      redirect_to @report_template, notice: "Template was successfully created."
    else
      @categories = %w[marketing sales analytics performance social_media email_marketing general]
      @template_types = %w[standard dashboard summary detailed custom]
      render :new, status: :unprocessable_entity
    end
  end

  # GET /report_templates/:id/edit
  def edit
    @categories = %w[marketing sales analytics performance social_media email_marketing general]
    @template_types = %w[standard dashboard summary detailed custom]
  end

  # PATCH/PUT /report_templates/:id
  def update
    if @report_template.update(report_template_params)
      redirect_to @report_template, notice: "Template was successfully updated."
    else
      @categories = %w[marketing sales analytics performance social_media email_marketing general]
      @template_types = %w[standard dashboard summary detailed custom]
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /report_templates/:id
  def destroy
    @report_template.destroy
    redirect_to report_templates_url, notice: "Template was successfully deleted."
  end

  # POST /report_templates/:id/clone
  def clone
    begin
      cloned_template = @report_template.dup
      cloned_template.assign_attributes(
        user: current_user,
        name: "#{@report_template.name} (Copy)",
        is_public: false,
        usage_count: 0,
        rating: 0.0,
        rating_count: 0
      )

      if cloned_template.save
        respond_to do |format|
          format.html { redirect_to cloned_template, notice: "Template cloned successfully." }
          format.json { render json: cloned_template }
        end
      else
        respond_to do |format|
          format.html { redirect_to @report_template, alert: "Failed to clone template." }
          format.json { render json: { errors: cloned_template.errors }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to @report_template, alert: "Clone failed: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # POST /report_templates/:id/instantiate
  def instantiate
    begin
      report_name = params[:report_name] || @report_template.name

      new_report = @report_template.instantiate_for(
        user: current_user,
        brand: @brand,
        report_name: report_name
      )

      respond_to do |format|
        format.html do
          redirect_to custom_report_path(new_report),
                      notice: "Report created from template successfully."
        end
        format.json { render json: new_report }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to @report_template, alert: "Failed to create report: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # POST /report_templates/:id/rate
  def rate
    rating = params[:rating].to_i

    unless rating.between?(1, 5)
      return render json: { error: "Rating must be between 1 and 5" }, status: :bad_request
    end

    if @report_template.add_rating(rating)
      render json: {
        success: true,
        new_rating: @report_template.rating,
        rating_count: @report_template.rating_count
      }
    else
      render json: { error: "Failed to add rating" }, status: :unprocessable_entity
    end
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id]) if params[:brand_id]
    @brand ||= current_user.brands.first

    unless @brand
      redirect_to brands_path, alert: "Please select a brand first."
    end
  end

  def set_report_template
    @report_template = ReportTemplate.find(params[:id])
  end

  def authorize_template_access
    unless @report_template.user == current_user
      redirect_to report_templates_path, alert: "Access denied."
    end
  end

  def report_template_params
    params.require(:report_template).permit(
      :name, :description, :category, :template_type, :is_public,
      configuration: {}
    )
  end

  def authenticate_user!
    return if current_user

    redirect_to new_session_path, alert: "Please sign in to continue."
  end
end
