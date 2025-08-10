class CreateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :templates do |t|
      t.string :name, null: false
      t.string :template_type, null: false
      t.string :category
      t.json :template_data, null: false, default: {}
      t.boolean :is_active, null: false, default: true
      t.integer :usage_count, null: false, default: 0
      t.text :description
      t.integer :version, null: false, default: 1
      t.references :parent_template, null: true, foreign_key: { to_table: :templates }
      t.string :author
      t.json :variables, null: false, default: []
      t.json :metadata, null: false, default: {}
      t.datetime :published_at
      t.string :tags  # Simple string for SQLite compatibility

      t.timestamps
    end

    # Add indexes for performance
    add_index :templates, :name
    add_index :templates, :template_type
    add_index :templates, :category
    add_index :templates, :is_active
    add_index :templates, :usage_count
    add_index :templates, :version
    add_index :templates, :published_at
    add_index :templates, [:template_type, :category]
    add_index :templates, [:is_active, :template_type]
  end
end
