# frozen_string_literal: true

class CreateCrmIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_integrations do |t|
      t.string :platform, null: false, limit: 50
      t.string :name, null: false, limit: 255
      t.text :description
      t.references :brand, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # OAuth and Authentication
      t.text :access_token_encrypted
      t.text :refresh_token_encrypted
      t.text :client_id_encrypted
      t.text :client_secret_encrypted
      t.text :additional_credentials_encrypted
      t.datetime :token_expires_at
      t.datetime :last_token_refresh_at
      
      # API Configuration
      t.string :api_version, limit: 20
      t.string :instance_url, limit: 500
      t.string :sandbox_mode, default: false
      t.json :api_configuration
      
      # Connection Status
      t.boolean :active, default: true
      t.string :status, default: 'pending', null: false, limit: 50
      t.text :last_error_message
      t.datetime :last_successful_sync_at
      t.datetime :last_attempted_sync_at
      t.integer :consecutive_error_count, default: 0
      
      # Rate Limiting
      t.datetime :rate_limit_reset_at
      t.integer :rate_limit_remaining
      t.integer :daily_api_calls, default: 0
      t.integer :monthly_api_calls, default: 0
      
      # Sync Configuration
      t.json :sync_configuration
      t.json :field_mappings
      t.datetime :last_sync_cursor
      t.boolean :sync_leads, default: true
      t.boolean :sync_opportunities, default: true
      t.boolean :sync_contacts, default: true
      t.boolean :sync_accounts, default: true
      t.boolean :sync_campaigns, default: true
      
      # Metrics and Analytics
      t.integer :total_leads_synced, default: 0
      t.integer :total_opportunities_synced, default: 0
      t.integer :total_contacts_synced, default: 0
      t.bigint :total_revenue_tracked, default: 0
      
      t.timestamps
      
      t.index [:platform, :brand_id], unique: true
      t.index [:status]
      t.index [:active]
      t.index [:last_successful_sync_at]
      t.index [:rate_limit_reset_at]
    end
  end
end
