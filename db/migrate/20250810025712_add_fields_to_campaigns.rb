class AddFieldsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :brand_identity_id, :integer
    add_column :campaigns, :target_audience, :text
    add_column :campaigns, :budget_cents, :integer
    add_column :campaigns, :start_date, :date
    add_column :campaigns, :end_date, :date

    # Add indexes for performance
    add_index :campaigns, :status
    add_index :campaigns, :brand_identity_id
    add_index :campaigns, :start_date
    add_index :campaigns, :created_at
    add_index :campaigns, [ :status, :start_date ], name: 'index_campaigns_on_status_and_start_date'

    # Add foreign key constraint (will be created when BrandIdentity model is implemented)
    # add_foreign_key :campaigns, :brand_identities
  end
end
