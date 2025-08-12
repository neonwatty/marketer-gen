# JourneysController - Handles journey CRUD operations and validation
class JourneysController < ApplicationController
  before_action :set_journey, only: [:show, :edit, :update, :destroy, :validate, :duplicate, :versions, :restore_version, :export, :import]
  before_action :set_campaign, only: [:index, :new, :create]

  # GET /journeys
  def index
    @journeys = @campaign ? @campaign.journeys.ordered : Journey.ordered
    @journeys = @journeys.includes(:journey_stages, :content_assets)

    respond_to do |format|
      format.html
      format.json { render json: { journeys: @journeys } }
    end
  end

  # GET /journeys/1
  def show
    @stages = @journey.journey_stages.ordered.includes(:content_assets)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          journey: @journey,
          stages: @stages,
          validation_status: get_validation_status(@journey)
        }
      end
    end
  end

  # GET /journeys/new
  def new
    @journey = @campaign ? @campaign.journeys.build : Journey.new
    @journey.position = (@campaign&.journeys&.maximum(:position) || 0) + 1
  end

  # GET /journeys/1/edit
  def edit
    @stages = @journey.journey_stages.ordered
  end

  # POST /journeys
  def create
    @journey = @campaign ? @campaign.journeys.build(journey_params) : Journey.new(journey_params)

    if @journey.save
      # Run initial validation
      validation_result = validate_journey_data(@journey)
      
      respond_to do |format|
        format.html { 
          redirect_to @journey, 
          notice: 'Journey was successfully created.' 
        }
        format.json { 
          render json: { 
            journey: @journey,
            validation: validation_result,
            status: :created 
          }
        }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @journey.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /journeys/1
  def update
    if @journey.update(journey_params)
      # Run validation after update
      validation_result = validate_journey_data(@journey)
      
      respond_to do |format|
        format.html { 
          redirect_to @journey, 
          notice: 'Journey was successfully updated.' 
        }
        format.json { 
          render json: { 
            journey: @journey,
            validation: validation_result,
            status: :ok 
          }
        }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @journey.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /journeys/1
  def destroy
    campaign = @journey.campaign
    @journey.destroy!
    
    respond_to do |format|
      format.html { 
        redirect_to campaign ? campaign_path(campaign) : journeys_url, 
        notice: 'Journey was successfully deleted.' 
      }
      format.json { head :no_content }
    end
  end

  # POST /journeys/1/validate
  def validate
    begin
      validation_types = params[:validation_types] || [
        'completeness', 'field_requirements', 'business_rules', 'logical_flow'
      ]
      
      options = {
        strict_mode: params[:strict_mode] || false,
        check_audience_overlap: params[:check_audience_overlap] != false,
        warning_as_error: params[:warning_as_error] || false
      }

      # Add custom business rules if provided
      if params[:custom_business_rules].present?
        options[:custom_business_rules] = params[:custom_business_rules]
      end

      validator = JourneyValidator.new(
        validation_types: validation_types,
        strict_mode: options[:strict_mode],
        check_audience_overlap: options[:check_audience_overlap],
        warning_as_error: options[:warning_as_error],
        custom_business_rules: options[:custom_business_rules] || {}
      )

      validation_result = validator.validate_journey(@journey, options)

      # Store validation results for future reference
      cache_validation_results(@journey, validation_result)

      respond_to do |format|
        format.json { render json: validation_result }
        format.html do
          flash[:validation_result] = validation_result
          redirect_to @journey
        end
      end

    rescue JourneyValidator::ValidationError => e
      respond_to do |format|
        format.json { 
          render json: { 
            error: e.message,
            overall_status: 'error',
            validation_results: []
          }, status: :unprocessable_entity 
        }
        format.html do
          flash[:error] = "Validation error: #{e.message}"
          redirect_to @journey
        end
      end
    rescue => e
      Rails.logger.error "Journey validation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.json { 
          render json: { 
            error: 'Validation service temporarily unavailable',
            overall_status: 'error',
            validation_results: []
          }, status: :service_unavailable 
        }
        format.html do
          flash[:error] = 'Unable to validate journey at this time'
          redirect_to @journey
        end
      end
    end
  end

  # POST /journeys/1/duplicate
  def duplicate
    begin
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      new_journey = persistence_service.duplicate_journey(
        name: params[:name]
      )
      
      respond_to do |format|
        format.html { 
          redirect_to new_journey, 
          notice: 'Journey was successfully duplicated.' 
        }
        format.json { 
          render json: { 
            journey: new_journey,
            original_id: @journey.id,
            status: :created 
          }
        }
      end
    rescue JourneyPersistenceService::PersistenceError => e
      respond_to do |format|
        format.html { 
          redirect_to @journey, 
          alert: "Failed to duplicate journey: #{e.message}" 
        }
        format.json { 
          render json: { error: e.message }, 
          status: :unprocessable_entity 
        }
      end
    rescue => e
      Rails.logger.error "Journey duplication failed: #{e.message}"
      respond_to do |format|
        format.html { 
          redirect_to @journey, 
          alert: 'Failed to duplicate journey.' 
        }
        format.json { 
          render json: { error: 'Duplication failed' }, 
          status: :unprocessable_entity 
        }
      end
    end
  end

  # GET /journeys/1/versions
  def versions
    begin
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      versions = persistence_service.get_version_history(
        params[:limit]&.to_i || 20
      )
      
      respond_to do |format|
        format.json { render json: { versions: versions } }
        format.html do
          @versions = versions
          render :versions
        end
      end
    rescue => e
      Rails.logger.error "Failed to load version history: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: 'Failed to load version history' }, status: :service_unavailable }
        format.html do
          flash[:error] = 'Unable to load version history'
          redirect_to @journey
        end
      end
    end
  end

  # POST /journeys/1/restore_version
  def restore_version
    begin
      version_number = params[:version]&.to_i
      unless version_number
        raise ArgumentError, 'Version number is required'
      end
      
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      result = persistence_service.restore_to_version(version_number)
      
      respond_to do |format|
        format.json { render json: result }
        format.html do
          flash[:notice] = "Journey restored to version #{version_number}"
          redirect_to @journey
        end
      end
      
    rescue JourneyPersistenceService::PersistenceError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
        format.html do
          flash[:error] = "Failed to restore version: #{e.message}"
          redirect_to @journey
        end
      end
    rescue => e
      Rails.logger.error "Version restore failed: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: 'Restore failed' }, status: :service_unavailable }
        format.html do
          flash[:error] = 'Unable to restore version'
          redirect_to @journey
        end
      end
    end
  end

  # GET /journeys/1/export
  def export
    begin
      format = params[:format] || 'json'
      include_history = params[:include_history] == 'true'
      
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      export_data = persistence_service.export_journey(format, {
        include_history: include_history
      })
      
      filename = "journey-#{@journey.id}-#{Date.current.strftime('%Y%m%d')}.#{format}"
      
      respond_to do |response_format|
        response_format.json do
          if format == 'json'
            render json: JSON.parse(export_data)
          else
            render json: { export_data: export_data, filename: filename }
          end
        end
        response_format.any do
          content_type = case format
                        when 'csv' then 'text/csv'
                        when 'yaml' then 'text/yaml'
                        else 'application/json'
                        end
          
          send_data export_data, 
                    filename: filename,
                    type: content_type,
                    disposition: 'attachment'
        end
      end
      
    rescue JourneyPersistenceService::PersistenceError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
        format.html do
          flash[:error] = "Export failed: #{e.message}"
          redirect_to @journey
        end
      end
    rescue => e
      Rails.logger.error "Journey export failed: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: 'Export failed' }, status: :service_unavailable }
        format.html do
          flash[:error] = 'Unable to export journey'
          redirect_to @journey
        end
      end
    end
  end

  # POST /journeys/1/import
  def import
    begin
      unless params[:file] || params[:import_data]
        raise ArgumentError, 'No import data provided'
      end
      
      import_data = if params[:file]
                     parse_import_file(params[:file])
                   else
                     JSON.parse(params[:import_data])
                   end
      
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      imported_journey = persistence_service.import_journey(import_data, {
        name: params[:name],
        campaign: @campaign,
        import_history: params[:import_history] == 'true'
      })
      
      respond_to do |format|
        format.json do
          render json: {
            success: true,
            journey: imported_journey,
            message: 'Journey imported successfully'
          }
        end
        format.html do
          flash[:notice] = 'Journey imported successfully'
          redirect_to imported_journey
        end
      end
      
    rescue JourneyPersistenceService::PersistenceError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
        format.html do
          flash[:error] = "Import failed: #{e.message}"
          redirect_back(fallback_location: journeys_path)
        end
      end
    rescue => e
      Rails.logger.error "Journey import failed: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: 'Import failed' }, status: :service_unavailable }
        format.html do
          flash[:error] = 'Unable to import journey'
          redirect_back(fallback_location: journeys_path)
        end
      end
    end
  end

  # POST /journeys/1/auto_save
  def auto_save
    begin
      expected_version = params[:expected_version]&.to_i
      journey_data = params[:journey_data] || {}
      
      persistence_service = JourneyPersistenceService.new(
        journey: @journey,
        user: current_user
      )
      
      result = persistence_service.save_journey(journey_data, {
        expected_version: expected_version,
        is_auto_save: true,
        change_type: 'auto_save'
      })
      
      render json: result
      
    rescue JourneyPersistenceService::ConflictError => e
      render json: {
        success: false,
        conflict: true,
        conflict_data: e.conflict_data,
        conflict_type: e.conflict_type,
        message: e.message
      }, status: :conflict
      
    rescue JourneyPersistenceService::PersistenceError => e
      render json: {
        success: false,
        error: e.message,
        retry_recommended: true
      }, status: :unprocessable_entity
      
    rescue => e
      Rails.logger.error "Auto-save failed: #{e.message}"
      render json: {
        success: false,
        error: 'Auto-save temporarily unavailable',
        retry_recommended: true
      }, status: :service_unavailable
    end
  end

  private

  def set_journey
    @journey = Journey.find(params[:id])
  end

  def set_campaign
    @campaign = params[:campaign_id] ? Campaign.find(params[:campaign_id]) : nil
  end

  def journey_params
    params.require(:journey).permit(
      :name, :purpose, :goals, :timing, :audience, :template_type, 
      :is_active, :position, :campaign_id
    )
  end

  # Validate journey using the JourneyValidator service
  def validate_journey_data(journey, options = {})
    validator = JourneyValidator.new(
      validation_types: options[:validation_types] || [
        'completeness', 'field_requirements', 'business_rules'
      ],
      strict_mode: options[:strict_mode] || false
    )

    validator.validate_journey(journey, options)
  end

  # Get cached validation status for a journey
  def get_validation_status(journey)
    cached_result = Rails.cache.read(validation_cache_key(journey))
    
    if cached_result
      {
        cached: true,
        timestamp: cached_result[:timestamp],
        overall_status: cached_result[:overall_status],
        summary: cached_result[:summary],
        critical_issues: cached_result[:critical_issues] || 0,
        errors: cached_result[:errors] || 0,
        warnings: cached_result[:warnings] || 0
      }
    else
      { cached: false, overall_status: 'unknown' }
    end
  end

  # Cache validation results
  def cache_validation_results(journey, validation_result)
    cache_data = {
      timestamp: Time.current,
      overall_status: validation_result[:overall_status],
      summary: validation_result[:summary],
      critical_issues: validation_result[:critical_issues],
      errors: validation_result[:errors],
      warnings: validation_result[:warnings],
      recommendations_count: (validation_result[:recommendations] || []).length
    }

    Rails.cache.write(
      validation_cache_key(journey), 
      cache_data,
      expires_in: 30.minutes
    )
  end

  def validation_cache_key(journey)
    "journey_validation:#{journey.id}:#{journey.updated_at.to_i}"
  end

  # Parse import file based on format
  def parse_import_file(file)
    case file.original_filename
    when /\.json$/i
      JSON.parse(file.read)
    when /\.csv$/i
      # Simple CSV parsing - in production you'd want more robust parsing
      require 'csv'
      csv_data = CSV.parse(file.read, headers: true)
      convert_csv_to_journey_data(csv_data)
    when /\.ya?ml$/i
      YAML.safe_load(file.read)
    else
      raise ArgumentError, "Unsupported file format: #{file.original_filename}"
    end
  end

  # Convert CSV data to journey format (simplified)
  def convert_csv_to_journey_data(csv_data)
    journey_data = { stages: [] }
    
    csv_data.each do |row|
      case row['Field']
      when 'Name'
        journey_data['name'] = row['Value']
      when 'Purpose'
        journey_data['purpose'] = row['Value']
      when 'Audience'
        journey_data['audience'] = row['Value']
      when /Stage (\d+) Name/
        stage_index = $1.to_i - 1
        journey_data['stages'][stage_index] ||= {}
        journey_data['stages'][stage_index]['name'] = row['Value']
      when /Stage (\d+) Type/
        stage_index = $1.to_i - 1
        journey_data['stages'][stage_index] ||= {}
        journey_data['stages'][stage_index]['stage_type'] = row['Value']
      when /Stage (\d+) Duration/
        stage_index = $1.to_i - 1
        journey_data['stages'][stage_index] ||= {}
        journey_data['stages'][stage_index]['duration_days'] = row['Value'].to_i
      when /Stage (\d+) Description/
        stage_index = $1.to_i - 1
        journey_data['stages'][stage_index] ||= {}
        journey_data['stages'][stage_index]['description'] = row['Value']
      end
    end
    
    { journey: journey_data }
  end

  # Get current user (placeholder - implement based on your auth system)
  def current_user
    # This should be implemented based on your authentication system
    # For now, return a mock user or nil
    nil
  end
end