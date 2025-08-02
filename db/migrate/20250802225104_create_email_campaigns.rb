class CreateEmailCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :email_campaigns do |t|
      t.references :email_integration, null: false, foreign_key: true
      t.string :platform_campaign_id, null: false
      t.string :name, null: false
      t.string :subject
      t.string :status, null: false
      t.string :campaign_type
      t.string :list_id
      t.string :template_id
      t.datetime :send_time
      t.string :created_by
      t.integer :total_recipients, default: 0
      t.text :configuration

      t.timestamps
    end

    add_index :email_campaigns, [:email_integration_id, :platform_campaign_id], unique: true, name: "idx_email_campaigns_integration_platform"
    add_index :email_campaigns, :status
    add_index :email_campaigns, :campaign_type
    add_index :email_campaigns, :send_time
    add_index :email_campaigns, :created_at
  end
end
