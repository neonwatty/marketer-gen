class AddStrategicFieldsToCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_plans, :content_strategy, :text
    add_column :campaign_plans, :creative_approach, :text
    add_column :campaign_plans, :strategic_rationale, :text
    add_column :campaign_plans, :content_mapping, :text
  end
end
