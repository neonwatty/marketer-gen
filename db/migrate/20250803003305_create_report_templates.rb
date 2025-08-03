class CreateReportTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :report_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :category, null: false, default: 'general'
      t.string :template_type, null: false, default: 'standard'
      t.json :configuration, default: {}
      t.boolean :is_public, default: false
      t.boolean :is_active, default: true
      t.integer :usage_count, default: 0
      t.decimal :rating, precision: 3, scale: 2, default: 0.0
      t.integer :rating_count, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :report_templates, :category
    add_index :report_templates, :template_type
    add_index :report_templates, :is_public
    add_index :report_templates, :is_active
    add_index :report_templates, :usage_count
    add_index :report_templates, :rating
  end
end
