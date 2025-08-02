class CreateSocialMediaIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :social_media_integrations do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :platform, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.text :scope
      t.string :platform_account_id
      t.string :status, null: false, default: 'pending'
      t.datetime :last_sync_at
      t.integer :error_count, default: 0
      t.datetime :rate_limit_reset_at
      t.text :configuration

      t.timestamps
    end
    
    add_index :social_media_integrations, :platform
    add_index :social_media_integrations, :platform_account_id
    add_index :social_media_integrations, :status
    add_index :social_media_integrations, [:brand_id, :platform], unique: true
  end
end
