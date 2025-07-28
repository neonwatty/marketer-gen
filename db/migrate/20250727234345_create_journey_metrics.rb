class CreateJourneyMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_metrics do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :metric_name, null: false
      t.decimal :metric_value, precision: 10, scale: 4, default: 0.0
      t.string :metric_type, null: false
      t.string :aggregation_period, null: false
      t.datetime :calculated_at, null: false
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :journey_metrics, [:journey_id, :metric_name, :aggregation_period], 
              name: 'index_journey_metrics_on_journey_metric_period'
    add_index :journey_metrics, [:campaign_id, :metric_name]
    add_index :journey_metrics, [:user_id, :calculated_at]
    add_index :journey_metrics, :metric_type
    add_index :journey_metrics, :aggregation_period
    add_index :journey_metrics, :calculated_at
    add_index :journey_metrics, [:metric_name, :calculated_at]
  end
end
