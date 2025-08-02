class CreateGoogleAnalyticsMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :google_analytics_metrics do |t|
      t.date :date, null: false
      t.integer :sessions, default: 0
      t.integer :users, default: 0
      t.integer :new_users, default: 0
      t.integer :page_views, default: 0
      t.float :bounce_rate, default: 0.0
      t.float :avg_session_duration, default: 0.0
      t.integer :goal_completions, default: 0
      t.decimal :transaction_revenue, precision: 12, scale: 2, default: 0.0
      t.json :dimension_data
      t.json :raw_data
      t.string :pipeline_id, null: false
      t.datetime :processed_at, null: false

      t.timestamps
    end

    # Strategic indexes for analytics performance
    add_index :google_analytics_metrics, :date
    add_index :google_analytics_metrics, :pipeline_id
    add_index :google_analytics_metrics, :processed_at
    add_index :google_analytics_metrics, [:date, :sessions]
    add_index :google_analytics_metrics, [:date, :users]
    add_index :google_analytics_metrics, [:date, :transaction_revenue]
  end
end
