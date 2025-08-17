class AddAnalyticsFieldsToCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_plans, :engagement_metrics, :text
    add_column :campaign_plans, :performance_data, :text
    add_column :campaign_plans, :roi_tracking, :text
    add_column :campaign_plans, :analytics_enabled, :boolean, default: true, null: false
    add_column :campaign_plans, :analytics_last_updated_at, :datetime
    add_column :campaign_plans, :plan_execution_started_at, :datetime
    add_column :campaign_plans, :plan_execution_completed_at, :datetime
    
    add_index :campaign_plans, :analytics_enabled
    add_index :campaign_plans, :analytics_last_updated_at
    add_index :campaign_plans, :plan_execution_started_at
  end
end
