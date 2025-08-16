class AddCollaborationFieldsToCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_plans, :approval_status, :string, default: 'draft'
    add_column :campaign_plans, :submitted_for_approval_at, :datetime
    add_column :campaign_plans, :approved_at, :datetime
    add_reference :campaign_plans, :approved_by, null: true, foreign_key: { to_table: :users }
    add_column :campaign_plans, :rejected_at, :datetime
    add_reference :campaign_plans, :rejected_by, null: true, foreign_key: { to_table: :users }
    add_column :campaign_plans, :current_version_id, :integer
    add_column :campaign_plans, :rejection_reason, :text
    add_column :campaign_plans, :stakeholder_notes, :text
    
    add_index :campaign_plans, :approval_status
    add_index :campaign_plans, :current_version_id
    add_index :campaign_plans, :submitted_for_approval_at
  end
end
