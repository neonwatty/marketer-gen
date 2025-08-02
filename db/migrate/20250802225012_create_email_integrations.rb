class CreateEmailIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :email_integrations do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :status, default: "pending", null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :platform_account_id
      t.string :account_name
      t.text :configuration
      t.string :api_endpoint
      t.string :webhook_secret
      t.datetime :last_sync_at
      t.integer :error_count, default: 0
      t.datetime :rate_limit_reset_at

      t.timestamps
    end

    add_index :email_integrations, [:brand_id, :platform], unique: true
    add_index :email_integrations, :platform
    add_index :email_integrations, :status
    add_index :email_integrations, :expires_at
    add_index :email_integrations, :last_sync_at
  end
end
