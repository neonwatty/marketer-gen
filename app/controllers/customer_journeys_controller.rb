class CustomerJourneysController < ApplicationController
  before_action :set_campaign
  before_action :set_customer_journey, only: [:show, :update, :destroy]

  def show
    if @customer_journey
      render json: {
        journey: @customer_journey,
        stages: @customer_journey.stages || [],
        touchpoints: @customer_journey.touchpoints || {},
        metrics: @customer_journey.metrics || {}
      }
    else
      render json: { journey: nil, stages: [], touchpoints: {}, metrics: {} }
    end
  end

  def builder
    # This action serves the journey builder interface
    @customer_journey = @campaign.customer_journey || @campaign.build_customer_journey
    render :builder
  end

  def create
    @customer_journey = @campaign.build_customer_journey(customer_journey_params)
    
    if @customer_journey.save
      render json: { 
        success: true, 
        message: 'Journey created successfully',
        journey: @customer_journey 
      }, status: :created
    else
      render json: { 
        success: false, 
        message: 'Failed to create journey',
        errors: @customer_journey.errors 
      }, status: :unprocessable_content
    end
  end

  def update
    if @customer_journey.update(customer_journey_params)
      render json: { 
        success: true, 
        message: 'Journey updated successfully',
        journey: @customer_journey 
      }
    else
      render json: { 
        success: false, 
        message: 'Failed to update journey',
        errors: @customer_journey.errors 
      }, status: :unprocessable_content
    end
  end

  def destroy
    @customer_journey.destroy
    render json: { 
      success: true, 
      message: 'Journey deleted successfully' 
    }
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Campaign not found' }, status: :not_found
  end

  def set_customer_journey
    @customer_journey = @campaign.customer_journey
    
    unless @customer_journey
      render json: { error: 'Customer journey not found' }, status: :not_found
    end
  end

  def customer_journey_params
    params.require(:customer_journey).permit(:name, :content_types => [], stages: [])
  end
end