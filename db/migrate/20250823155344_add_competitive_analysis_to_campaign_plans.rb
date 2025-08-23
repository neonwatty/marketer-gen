class AddCompetitiveAnalysisToCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_plans, :competitive_intelligence, :text
    add_column :campaign_plans, :market_research_data, :text
    add_column :campaign_plans, :competitor_analysis, :text
    add_column :campaign_plans, :industry_benchmarks, :text
    add_column :campaign_plans, :competitive_analysis_last_updated_at, :datetime
    
    add_index :campaign_plans, :competitive_analysis_last_updated_at
  end
end
