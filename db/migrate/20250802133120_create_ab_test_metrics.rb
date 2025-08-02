class CreateAbTestMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_metrics do |t|
      t.references :ab_test, null: false, foreign_key: true
      t.string :metric_name
      t.decimal :value
      t.datetime :timestamp
      t.json :metadata

      t.timestamps
    end
  end
end
