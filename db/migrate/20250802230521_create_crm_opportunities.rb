# frozen_string_literal: true

class CreateCrmOpportunities < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_opportunities do |t|
      t.references :crm_integration, null: false, foreign_key: true, index: true
      t.references :brand, null: false, foreign_key: true, index: true
      t.string :crm_id, null: false, limit: 255
      
      # Opportunity Information
      t.string :name, null: false, limit: 500
      t.string :account_name, limit: 255
      t.string :account_id, limit: 255
      t.string :contact_id, limit: 255
      t.string :lead_id, limit: 255
      t.text :description
      
      # Sales Information
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, limit: 10, default: 'USD'
      t.string :stage, limit: 100
      t.string :type, limit: 100
      t.decimal :probability, precision: 5, scale: 2
      t.date :close_date
      t.date :expected_close_date
      
      # Pipeline and Tracking
      t.string :pipeline_id, limit: 255
      t.string :pipeline_name, limit: 255
      t.integer :stage_order
      t.datetime :stage_changed_at
      t.string :previous_stage, limit: 100
      t.integer :days_in_current_stage
      t.integer :total_days_in_pipeline
      
      # Attribution and Source
      t.string :lead_source, limit: 255
      t.string :original_source, limit: 255
      t.string :original_medium, limit: 255
      t.string :original_campaign, limit: 255
      t.string :first_touch_campaign_id, limit: 255
      t.string :last_touch_campaign_id, limit: 255
      t.json :utm_parameters
      
      # Owner and Team
      t.string :owner_id, limit: 255
      t.string :owner_name, limit: 255
      t.string :team_id, limit: 255
      t.string :team_name, limit: 255
      
      # Status and Lifecycle
      t.boolean :is_closed, default: false
      t.boolean :is_won, default: false
      t.datetime :closed_at
      t.string :close_reason, limit: 255
      t.string :lost_reason, limit: 255
      
      # CRM Sync Information
      t.datetime :crm_created_at
      t.datetime :crm_updated_at
      t.datetime :last_synced_at
      t.json :raw_data
      t.json :custom_fields
      
      # Analytics and Metrics
      t.integer :days_to_close
      t.decimal :conversion_rate, precision: 5, scale: 2
      t.integer :pipeline_velocity_score
      t.decimal :deal_size_score, precision: 5, scale: 2
      
      t.timestamps
      
      t.index [:crm_integration_id, :crm_id], unique: true
      t.index [:stage]
      t.index [:is_closed]
      t.index [:is_won]
      t.index [:close_date]
      t.index [:amount]
      t.index [:pipeline_id]
      t.index [:owner_id]
      t.index [:last_synced_at]
      t.index [:original_campaign]
      t.index [:lead_source]
    end
  end
end
