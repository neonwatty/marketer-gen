class CreateJourneyTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_templates do |t|
      t.string :name, null: false
      t.string :template_type, null: false
      t.string :category
      t.json :template_data, default: {}, null: false
      t.text :description
      t.boolean :is_active, default: true, null: false
      t.integer :usage_count, default: 0, null: false
      t.integer :version, default: 1, null: false
      t.string :author
      t.json :variables, default: [], null: false
      t.json :metadata, default: {}, null: false
      t.string :tags
      t.datetime :published_at
      t.integer :parent_template_id

      t.timestamps
    end
    
    add_index :journey_templates, [:template_type, :is_active]
    add_index :journey_templates, [:category]
    add_index :journey_templates, [:name]
    add_index :journey_templates, [:usage_count]
    add_index :journey_templates, [:parent_template_id]
    add_foreign_key :journey_templates, :journey_templates, column: :parent_template_id
  end
end
