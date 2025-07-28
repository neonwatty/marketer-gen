class CreateJourneyAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_analytics do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.integer :total_executions, default: 0
      t.integer :completed_executions, default: 0
      t.integer :abandoned_executions, default: 0
      t.float :average_completion_time, default: 0.0
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :engagement_score, precision: 5, scale: 2, default: 0.0
      t.json :metrics, default: {}
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :journey_analytics, [:journey_id, :period_start]
    add_index :journey_analytics, [:campaign_id, :period_start]
    add_index :journey_analytics, [:user_id, :period_start]
    add_index :journey_analytics, :period_start
    add_index :journey_analytics, :period_end
    add_index :journey_analytics, :conversion_rate
    add_index :journey_analytics, :engagement_score
  end
end
