# frozen_string_literal: true

class SocialMediaIntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_brand
  before_action :set_integration, only: [ :show, :destroy, :refresh_token, :sync_metrics ]

  # GET /brands/:brand_id/social_media_integrations
  def index
    @integrations = @brand.social_media_integrations.includes(:social_media_metrics)
    @available_platforms = SocialMediaIntegration::PLATFORMS - @integrations.pluck(:platform)
  end

  # GET /brands/:brand_id/social_media_integrations/:id
  def show
    @recent_metrics = @integration.social_media_metrics
                                 .recent(30)
                                 .group(:metric_type)
                                 .sum(:value)
  end

  # POST /brands/:brand_id/social_media_integrations
  def create
    platform = params[:platform]

    unless SocialMediaIntegration::PLATFORMS.include?(platform)
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "Invalid social media platform"
      return
    end

    # Check if integration already exists
    existing_integration = @brand.social_media_integrations.find_by(platform: platform)
    if existing_integration
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "#{platform.titleize} integration already exists"
      return
    end

    # Get OAuth authorization URL
    service = Analytics::SocialMediaIntegrationService.new(@brand)

    result = case platform
    when "facebook"
               service.connect_facebook_api
    when "instagram"
               service.connect_instagram_api
    when "linkedin"
               service.connect_linkedin_api
    when "twitter"
               service.connect_twitter_api
    when "tiktok"
               service.connect_tiktok_api
    else
               ServiceResult.failure("Unsupported platform")
    end

    if result.success?
      # Store the platform in session for callback
      session[:connecting_platform] = platform
      redirect_to result.data[:authorization_url], allow_other_host: true
    else
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "Failed to connect to #{platform.titleize}: #{result.message}"
    end
  end

  # GET /social_media/oauth_callback/:platform
  def oauth_callback
    platform = params[:platform]
    code = params[:code]
    state = params[:state]
    error = params[:error]

    if error.present?
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "Authorization failed: #{error}"
      return
    end

    unless code.present? && state.present?
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "Missing authorization parameters"
      return
    end

    # Handle the OAuth callback
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.handle_oauth_callback(platform, code, state)

    if result.success?
      # Schedule initial metrics sync
      SocialMediaSyncJob.perform_later(@brand.id, platform)

      redirect_to brand_social_media_integrations_path(@brand),
                  notice: result.message
    else
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "Failed to complete integration: #{result.message}"
    end
  ensure
    # Clean up session
    session.delete(:connecting_platform)
  end

  # DELETE /brands/:brand_id/social_media_integrations/:id
  def destroy
    @integration.disconnect!

    redirect_to brand_social_media_integrations_path(@brand),
                notice: "#{@integration.platform.titleize} integration has been disconnected"
  end

  # POST /brands/:brand_id/social_media_integrations/:id/refresh_token
  def refresh_token
    service = Analytics::SocialMediaIntegrationService.new(@brand, @integration)
    result = service.refresh_integration_token(@integration)

    if result.success?
      redirect_to brand_social_media_integration_path(@brand, @integration),
                  notice: "Token refreshed successfully"
    else
      redirect_to brand_social_media_integration_path(@brand, @integration),
                  alert: "Failed to refresh token: #{result.message}"
    end
  end

  # POST /brands/:brand_id/social_media_integrations/:id/sync_metrics
  def sync_metrics
    # Schedule metrics sync job
    SocialMediaSyncJob.perform_later(@brand.id, @integration.platform)

    redirect_to brand_social_media_integration_path(@brand, @integration),
                notice: "Metrics sync has been scheduled"
  end

  # POST /brands/:brand_id/social_media_integrations/sync_all
  def sync_all
    active_integrations = @brand.social_media_integrations.active

    if active_integrations.empty?
      redirect_to brand_social_media_integrations_path(@brand),
                  alert: "No active social media integrations found"
      return
    end

    # Schedule sync for all platforms
    SocialMediaSyncJob.perform_later(@brand.id)

    redirect_to brand_social_media_integrations_path(@brand),
                notice: "Metrics sync has been scheduled for all connected platforms"
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to brands_path, alert: "Brand not found"
  end

  def set_integration
    @integration = @brand.social_media_integrations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to brand_social_media_integrations_path(@brand),
                alert: "Social media integration not found"
  end
end
