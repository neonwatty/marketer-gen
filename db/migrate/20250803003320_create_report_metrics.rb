class CreateReportMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :report_metrics do |t|
      t.references :custom_report, null: false, foreign_key: true
      t.string :metric_name, null: false
      t.string :aggregation_type, null: false, default: 'sum'
      t.string :data_source, null: false
      t.string :display_name
      t.text :description
      t.json :filters, default: {}
      t.json :visualization_config, default: {}
      t.integer :sort_order, default: 0
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :report_metrics, [:custom_report_id, :sort_order]
    add_index :report_metrics, :metric_name
    add_index :report_metrics, :data_source
    add_index :report_metrics, :aggregation_type
    add_index :report_metrics, :is_active
  end
end
