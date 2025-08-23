class CreateContentAbTestResults < ActiveRecord::Migration[8.0]
  def change
    create_table :content_ab_test_results do |t|
      t.string :metric_name, null: false, limit: 100
      t.decimal :metric_value, null: false, precision: 12, scale: 4
      t.integer :sample_size, null: false, default: 1
      t.date :recorded_date, null: false
      t.string :data_source, limit: 100
      t.text :metadata
      t.references :content_ab_test_variant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :content_ab_test_results, :metric_name
    add_index :content_ab_test_results, :recorded_date
    add_index :content_ab_test_results, [:content_ab_test_variant_id, :metric_name]
    add_index :content_ab_test_results, [:content_ab_test_variant_id, :recorded_date]
    add_index :content_ab_test_results, [:metric_name, :recorded_date]
    add_index :content_ab_test_results, :data_source
  end
end
