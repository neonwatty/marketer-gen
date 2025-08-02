# frozen_string_literal: true

class CreateCrmAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_analytics do |t|
      t.references :crm_integration, null: false, foreign_key: true, index: true
      t.references :brand, null: false, foreign_key: true, index: true
      t.date :analytics_date, null: false
      t.string :metric_type, null: false, limit: 100
      
      # Lead Metrics
      t.integer :total_leads
      t.integer :new_leads
      t.integer :marketing_qualified_leads
      t.integer :sales_qualified_leads
      t.integer :converted_leads
      t.decimal :lead_conversion_rate, precision: 5, scale: 2
      t.decimal :mql_conversion_rate, precision: 5, scale: 2
      t.decimal :sql_conversion_rate, precision: 5, scale: 2
      
      # Opportunity Metrics
      t.integer :total_opportunities
      t.integer :new_opportunities
      t.integer :closed_opportunities
      t.integer :won_opportunities
      t.integer :lost_opportunities
      t.decimal :opportunity_win_rate, precision: 5, scale: 2
      t.decimal :total_opportunity_value, precision: 15, scale: 2
      t.decimal :won_opportunity_value, precision: 15, scale: 2
      t.decimal :average_deal_size, precision: 15, scale: 2
      
      # Pipeline Metrics
      t.decimal :pipeline_velocity, precision: 10, scale: 2
      t.decimal :average_sales_cycle_days, precision: 8, scale: 2
      t.decimal :pipeline_value, precision: 15, scale: 2
      t.integer :pipeline_count
      t.decimal :weighted_pipeline_value, precision: 15, scale: 2
      
      # Attribution Metrics
      t.string :top_performing_campaign, limit: 255
      t.decimal :campaign_attributed_revenue, precision: 15, scale: 2
      t.integer :campaign_attributed_leads
      t.integer :campaign_attributed_opportunities
      t.json :attribution_breakdown
      
      # Conversion Metrics
      t.decimal :marketing_to_sales_conversion_rate, precision: 5, scale: 2
      t.decimal :lead_to_opportunity_conversion_rate, precision: 5, scale: 2
      t.decimal :opportunity_to_customer_conversion_rate, precision: 5, scale: 2
      t.decimal :overall_conversion_rate, precision: 5, scale: 2
      
      # Time-based Metrics
      t.decimal :time_to_mql_hours, precision: 10, scale: 2
      t.decimal :time_to_sql_hours, precision: 10, scale: 2
      t.decimal :time_to_opportunity_hours, precision: 10, scale: 2
      t.decimal :time_to_close_hours, precision: 10, scale: 2
      
      # Channel Performance
      t.json :channel_performance
      t.json :source_performance
      t.json :campaign_performance
      
      # Lifecycle Stage Progression
      t.json :lifecycle_stage_breakdown
      t.json :stage_progression_metrics
      
      # Additional Metadata
      t.json :raw_metrics
      t.json :calculated_metrics
      t.datetime :calculated_at
      
      t.timestamps
      
      t.index [:crm_integration_id, :analytics_date, :metric_type], unique: true, name: 'idx_crm_analytics_unique'
      t.index [:analytics_date]
      t.index [:metric_type]
      t.index [:calculated_at]
    end
  end
end
