# frozen_string_literal: true

# Controller for managing external platform integrations
# Handles Meta, Google Ads, and LinkedIn platform connections and data sync
class PlatformIntegrationsController < ApplicationController
  include LlmServiceHelper
  include Authentication
  include ActivityMonitoring

  before_action :require_authentication
  before_action :set_platform_connection, only: [ :show, :update, :destroy, :test_connection, :sync_data ]
  before_action :validate_platform, only: [ :create, :update ]

  # GET /platform_integrations
  # List all platform connections for the current user
  def index
    @connections = current_user.platform_connections.includes(:user)
    @connection_status = {}

    # Get recent sync status for each platform
    PlatformIntegrationService::SUPPORTED_PLATFORMS.each do |platform|
      connection = @connections.find { |c| c.platform == platform }
      @connection_status[platform] = connection ? connection.account_info : { status: "not_connected" }
    end

    respond_to do |format|
      format.html
      format.json { render json: { connections: @connection_status } }
    end
  end

  # GET /platform_integrations/:platform
  # Show details for a specific platform connection
  def show
    respond_to do |format|
      format.html
      format.json {
        render json: {
          connection: @connection.account_info,
          recent_syncs: recent_sync_history(@connection),
          health_status: @connection.test_connection
        }
      }
    end
  end

  # POST /platform_integrations
  # Create a new platform connection
  def create
    @connection = current_user.platform_connections.build(connection_params)

    begin
      if @connection.save
        # Test the connection immediately after creation
        test_result = @connection.test_connection

        if test_result[:success]
          log_activity("platform_connection_created", { platform: @connection.platform })

          respond_to do |format|
            format.html {
              redirect_to platform_integrations_path,
              notice: "Successfully connected to #{@connection.platform.humanize}!"
            }
            format.json {
              render json: {
                success: true,
                connection: @connection.account_info,
                test_result: test_result
              }, status: :created
            }
          end
        else
          @connection.destroy
          handle_connection_error(test_result[:error])
        end
      else
        handle_validation_errors(@connection.errors)
      end
    rescue => error
      Rails.logger.error "Failed to create platform connection: #{error.message}"
      handle_connection_error("Failed to create connection: #{error.message}")
    end
  end

  # PATCH /platform_integrations/:platform
  # Update an existing platform connection
  def update
    begin
      if @connection.update(connection_params)
        # Test the updated connection
        test_result = @connection.test_connection

        if test_result[:success]
          log_activity("platform_connection_updated", { platform: @connection.platform })

          respond_to do |format|
            format.html {
              redirect_to platform_integration_path(@connection.platform),
              notice: "Successfully updated #{@connection.platform.humanize} connection!"
            }
            format.json {
              render json: {
                success: true,
                connection: @connection.account_info,
                test_result: test_result
              }
            }
          end
        else
          handle_connection_error(test_result[:error])
        end
      else
        handle_validation_errors(@connection.errors)
      end
    rescue => error
      Rails.logger.error "Failed to update platform connection: #{error.message}"
      handle_connection_error("Failed to update connection: #{error.message}")
    end
  end

  # DELETE /platform_integrations/:platform
  # Remove a platform connection
  def destroy
    platform_name = @connection.platform.humanize

    if @connection.destroy
      log_activity("platform_connection_removed", { platform: @connection.platform })

      respond_to do |format|
        format.html {
          redirect_to platform_integrations_path,
          notice: "Successfully disconnected from #{platform_name}!"
        }
        format.json { render json: { success: true, message: "Connection removed" } }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to platform_integrations_path,
          alert: "Failed to disconnect from #{platform_name}"
        }
        format.json {
          render json: { success: false, error: "Failed to remove connection" },
          status: :unprocessable_entity
        }
      end
    end
  end

  # POST /platform_integrations/:platform/test_connection
  # Test connectivity for a specific platform
  def test_connection
    test_result = @connection.test_connection

    log_activity("platform_connection_tested", {
      platform: @connection.platform,
      success: test_result[:success]
    })

    respond_to do |format|
      format.html {
        if test_result[:success]
          redirect_to platform_integration_path(@connection.platform),
                      notice: "Connection to #{@connection.platform.humanize} is working!"
        else
          redirect_to platform_integration_path(@connection.platform),
                      alert: "Connection test failed: #{test_result[:error]}"
        end
      }
      format.json { render json: test_result }
    end
  end

  # POST /platform_integrations/:platform/sync_data
  # Trigger data synchronization for a specific platform
  def sync_data
    date_range = parse_date_range_params
    campaign_plan = params[:campaign_plan_id] ? current_user.campaign_plans.find(params[:campaign_plan_id]) : nil

    # Schedule async sync job
    job = PlatformIntegrationJob.sync_platform(
      current_user,
      @connection.platform,
      campaign_plan,
      date_range: date_range,
      trigger_analytics_refresh: params[:refresh_analytics] == "true",
      send_notification: params[:send_notification] == "true",
      notification_email: current_user.email
    )

    log_activity("platform_sync_scheduled", {
      platform: @connection.platform,
      campaign_plan_id: campaign_plan&.id,
      job_id: job.job_id
    })

    respond_to do |format|
      format.html {
        redirect_to platform_integration_path(@connection.platform),
        notice: "Data sync has been scheduled for #{@connection.platform.humanize}"
      }
      format.json {
        render json: {
          success: true,
          message: "Sync scheduled",
          job_id: job.job_id
        }
      }
    end
  end

  # POST /platform_integrations/sync_all
  # Trigger data synchronization for all connected platforms
  def sync_all
    date_range = parse_date_range_params
    campaign_plan = params[:campaign_plan_id] ? current_user.campaign_plans.find(params[:campaign_plan_id]) : nil

    # Schedule async sync job for all platforms
    job = PlatformIntegrationJob.sync_all_platforms(
      current_user,
      campaign_plan,
      date_range: date_range,
      trigger_analytics_refresh: params[:refresh_analytics] == "true",
      send_notification: params[:send_notification] == "true",
      notification_email: current_user.email
    )

    log_activity("platform_sync_all_scheduled", {
      campaign_plan_id: campaign_plan&.id,
      job_id: job.job_id
    })

    respond_to do |format|
      format.html {
        redirect_to platform_integrations_path,
        notice: "Data sync has been scheduled for all connected platforms"
      }
      format.json {
        render json: {
          success: true,
          message: "Sync scheduled for all platforms",
          job_id: job.job_id
        }
      }
    end
  end

  # GET /platform_integrations/sync_status/:job_id
  # Check the status of a sync job
  def sync_status
    # This would require implementing job status tracking
    # For now, return basic response
    respond_to do |format|
      format.json {
        render json: {
          job_id: params[:job_id],
          status: "processing",
          message: "Sync in progress"
        }
      }
    end
  end

  # GET /platform_integrations/export
  # Export performance data across platforms
  def export
    date_range = parse_date_range_params
    format = params[:format] || "json"
    campaign_plan = params[:campaign_plan_id] ? current_user.campaign_plans.find(params[:campaign_plan_id]) : nil

    service = PlatformIntegrationService.new(current_user, campaign_plan)
    result = service.export_performance_data(format, date_range)

    if result[:success]
      log_activity("platform_data_exported", {
        format: format,
        campaign_plan_id: campaign_plan&.id
      })

      send_data result[:data][:content],
                filename: result[:data][:filename],
                type: format == "csv" ? "text/csv" : "application/json"
    else
      respond_to do |format|
        format.html {
          redirect_to platform_integrations_path,
          alert: "Export failed: #{result[:error]}"
        }
        format.json {
          render json: { success: false, error: result[:error] },
          status: :unprocessable_entity
        }
      end
    end
  end

  private

  def set_platform_connection
    platform = params[:platform] || params[:id]
    @connection = current_user.platform_connections.for_platform(platform).first

    unless @connection
      respond_to do |format|
        format.html {
          redirect_to platform_integrations_path,
          alert: "No connection found for #{platform&.humanize}"
        }
        format.json {
          render json: { error: "Connection not found" },
          status: :not_found
        }
      end
    end
  end

  def validate_platform
    platform = connection_params[:platform]
    unless PlatformIntegrationService::SUPPORTED_PLATFORMS.include?(platform)
      respond_to do |format|
        format.html {
          redirect_to platform_integrations_path,
          alert: "Unsupported platform: #{platform}"
        }
        format.json {
          render json: { error: "Unsupported platform: #{platform}" },
          status: :unprocessable_entity
        }
      end
    end
  end

  def connection_params
    params.require(:platform_connection).permit(
      :platform, :credentials, :account_id, :account_name,
      credentials: {}
    ).tap do |whitelisted|
      # Handle nested credentials parameter
      if params[:platform_connection][:credentials].is_a?(ActionController::Parameters)
        whitelisted[:credentials] = params[:platform_connection][:credentials].to_unsafe_h.to_json
      end
    end
  end

  def parse_date_range_params
    date_range = {}
    date_range[:since] = Date.parse(params[:since]) if params[:since].present?
    date_range[:until] = Date.parse(params[:until]) if params[:until].present?
    date_range[:time_increment] = params[:time_increment] if params[:time_increment].present?
    date_range
  rescue Date::Error
    {} # Return empty hash if date parsing fails
  end

  def recent_sync_history(connection)
    # This would typically come from a sync history table or logs
    # For now, return basic information from metadata
    metadata = connection.metadata || {}
    [
      {
        sync_time: metadata["last_successful_sync"],
        status: "success",
        data_points: metadata["sync_count"] || 0
      }
    ].compact
  end

  def handle_connection_error(error_message)
    respond_to do |format|
      format.html {
        redirect_to platform_integrations_path,
        alert: error_message
      }
      format.json {
        render json: { success: false, error: error_message },
        status: :unprocessable_entity
      }
    end
  end

  def handle_validation_errors(errors)
    respond_to do |format|
      format.html {
        redirect_to platform_integrations_path,
        alert: "Validation failed: #{errors.full_messages.join(', ')}"
      }
      format.json {
        render json: {
          success: false,
          errors: errors.full_messages
        }, status: :unprocessable_entity
      }
    end
  end
end
