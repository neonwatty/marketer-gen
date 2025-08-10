class CampaignsController < ApplicationController
  def index
    @campaigns = Campaign.all.order(created_at: :desc)
    
    # Create sample campaigns if none exist
    if @campaigns.empty?
      create_sample_campaigns
      @campaigns = Campaign.all.order(created_at: :desc)
    end
  end

  private

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
