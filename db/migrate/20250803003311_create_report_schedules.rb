class CreateReportSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :report_schedules do |t|
      t.references :custom_report, null: false, foreign_key: true
      t.string :schedule_type, null: false, default: 'manual'
      t.string :cron_expression
      t.text :email_recipients
      t.json :distribution_lists, default: []
      t.json :export_formats, default: ['pdf']
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.datetime :last_success_at
      t.text :last_error
      t.integer :run_count, default: 0
      t.boolean :is_active, default: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :report_schedules, :schedule_type
    add_index :report_schedules, :next_run_at
    add_index :report_schedules, :is_active
    add_index :report_schedules, [:custom_report_id, :is_active]
  end
end
