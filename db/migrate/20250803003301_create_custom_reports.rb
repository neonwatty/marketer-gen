class CreateCustomReports < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_reports do |t|
      t.string :name, null: false
      t.text :description
      t.string :report_type, null: false, default: 'standard'
      t.json :configuration, default: {}
      t.string :status, null: false, default: 'draft'
      t.datetime :last_generated_at
      t.integer :generation_time_ms
      t.boolean :is_template, default: false
      t.boolean :is_public, default: false
      t.references :user, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: true

      t.timestamps
    end

    add_index :custom_reports, [:user_id, :brand_id]
    add_index :custom_reports, :report_type
    add_index :custom_reports, :status
    add_index :custom_reports, :is_template
    add_index :custom_reports, :last_generated_at
  end
end
