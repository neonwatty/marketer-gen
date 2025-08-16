class CreateCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :campaign_type, null: false
      t.string :objective, null: false
      t.text :target_audience
      t.text :brand_context
      t.text :budget_constraints
      t.text :timeline_constraints
      t.text :generated_summary
      t.text :generated_strategy
      t.text :generated_timeline
      t.text :generated_assets
      t.string :status, default: 'draft', null: false
      t.text :metadata

      t.timestamps
    end
    
    add_index :campaign_plans, [:user_id, :name], unique: true
    add_index :campaign_plans, :campaign_type
    add_index :campaign_plans, :status
    add_index :campaign_plans, :objective
  end
end
