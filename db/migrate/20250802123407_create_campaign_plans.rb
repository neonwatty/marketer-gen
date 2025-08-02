class CreateCampaignPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_plans do |t|
      t.string :name
      t.references :campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.string :plan_type
      t.text :strategic_rationale
      t.text :target_audience
      t.text :messaging_framework
      t.text :channel_strategy
      t.text :timeline_phases
      t.text :success_metrics
      t.text :budget_allocation
      t.text :creative_approach
      t.text :market_analysis
      t.decimal :version
      t.datetime :approved_at
      t.integer :approved_by
      t.datetime :rejected_at
      t.integer :rejected_by
      t.text :rejection_reason
      t.datetime :submitted_at
      t.datetime :archived_at
      t.text :metadata

      t.timestamps
    end
  end
end
