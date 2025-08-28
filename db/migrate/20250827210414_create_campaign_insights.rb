class CreateCampaignInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_insights do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.string :insight_type, null: false
      t.text :insight_data, null: false
      t.decimal :confidence_score, precision: 3, scale: 2, null: false
      t.datetime :analysis_date, null: false
      t.text :metadata

      t.timestamps
    end
    
    add_index :campaign_insights, :insight_type
    add_index :campaign_insights, :analysis_date
    add_index :campaign_insights, [:campaign_plan_id, :insight_type]
    add_index :campaign_insights, [:campaign_plan_id, :analysis_date]
  end
end
