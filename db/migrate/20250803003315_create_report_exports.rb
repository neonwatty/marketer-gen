class CreateReportExports < ActiveRecord::Migration[8.0]
  def change
    create_table :report_exports do |t|
      t.references :custom_report, null: false, foreign_key: true
      t.string :export_format, null: false
      t.string :file_path
      t.string :filename
      t.bigint :file_size
      t.string :status, null: false, default: 'pending'
      t.text :error_message
      t.datetime :generated_at
      t.datetime :expires_at
      t.integer :download_count, default: 0
      t.datetime :last_downloaded_at
      t.json :metadata, default: {}
      t.references :user, null: false, foreign_key: true
      t.references :report_schedule, null: true, foreign_key: true

      t.timestamps
    end

    add_index :report_exports, :export_format
    add_index :report_exports, :status
    add_index :report_exports, :generated_at
    add_index :report_exports, :expires_at
    add_index :report_exports, [:custom_report_id, :status]
  end
end
