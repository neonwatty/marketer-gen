# frozen_string_literal: true

class CreateCrmLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_leads do |t|
      t.references :crm_integration, null: false, foreign_key: true, index: true
      t.references :brand, null: false, foreign_key: true, index: true
      t.string :crm_id, null: false, limit: 255
      
      # Lead Information
      t.string :first_name, limit: 255
      t.string :last_name, limit: 255
      t.string :email, limit: 255
      t.string :phone, limit: 50
      t.string :company, limit: 255
      t.string :title, limit: 255
      t.string :status, limit: 100
      t.string :source, limit: 255
      t.text :description
      
      # Lead Qualification
      t.string :lead_score, limit: 50
      t.string :lead_grade, limit: 10
      t.string :lifecycle_stage, limit: 100
      t.boolean :marketing_qualified, default: false
      t.boolean :sales_qualified, default: false
      t.datetime :mql_date
      t.datetime :sql_date
      
      # Attribution and Tracking
      t.string :original_source, limit: 255
      t.string :original_medium, limit: 255
      t.string :original_campaign, limit: 255
      t.string :first_touch_campaign_id, limit: 255
      t.string :last_touch_campaign_id, limit: 255
      t.json :utm_parameters
      
      # Financial Information
      t.decimal :annual_revenue, precision: 15, scale: 2
      t.integer :number_of_employees
      t.string :industry, limit: 255
      
      # CRM Sync Information
      t.datetime :crm_created_at
      t.datetime :crm_updated_at
      t.datetime :last_synced_at
      t.json :raw_data
      t.json :custom_fields
      
      # Conversion Tracking
      t.boolean :converted, default: false
      t.datetime :converted_at
      t.string :converted_contact_id, limit: 255
      t.string :converted_opportunity_id, limit: 255
      t.string :converted_account_id, limit: 255
      
      t.timestamps
      
      t.index [:crm_integration_id, :crm_id], unique: true
      t.index [:email]
      t.index [:status]
      t.index [:lifecycle_stage]
      t.index [:marketing_qualified]
      t.index [:sales_qualified]
      t.index [:converted]
      t.index [:last_synced_at]
      t.index [:original_campaign]
    end
  end
end
