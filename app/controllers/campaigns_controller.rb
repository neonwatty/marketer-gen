class CampaignsController < ApplicationController
  before_action :set_campaign, only: [:show, :edit, :update, :destroy]

  def index
    @campaigns = Campaign.all.order(created_at: :desc)

    # Create sample campaigns if none exist
    if @campaigns.empty?
      create_sample_campaigns
      @campaigns = Campaign.all.order(created_at: :desc)
    end

    respond_to do |format|
      format.html
      format.json { render json: @campaigns.select(:id, :name, :status, :purpose) }
    end
  end

  def show
    # Show campaign details
  end

  def new
    @campaign = Campaign.new
  end

  def create
    @campaign = Campaign.new(campaign_params)
    
    if @campaign.save
      redirect_to @campaign, notice: 'Campaign was successfully created.'
    else
      render :new
    end
  end

  def edit
    # Edit campaign form
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: 'Campaign was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: 'Campaign was successfully deleted.'
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaigns_path, alert: 'Campaign not found.'
  end

  def campaign_params
    params.require(:campaign).permit(:name, :purpose, :status)
  end

  def create_sample_campaigns
    Campaign.create!([
      {
        name: "Summer Sales Boost",
        status: "active",
        purpose: "Drive summer product sales through targeted email marketing and social media campaigns featuring seasonal promotions."
      },
      {
        name: "Brand Awareness Q4",
        status: "draft",
        purpose: "Increase brand visibility in key demographics through content marketing, influencer partnerships, and strategic advertising placements."
      },
      {
        name: "Holiday Shopping Rush",
        status: "paused",
        purpose: "Maximize holiday season revenue with multi-channel marketing approach including email sequences, social ads, and retargeting campaigns."
      },
      {
        name: "Spring Product Launch",
        status: "completed",
        purpose: "Successfully launched new product line with coordinated marketing across all channels, achieving 150% of initial sales targets."
      }
    ])
  end
end
