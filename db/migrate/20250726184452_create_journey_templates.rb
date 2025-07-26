class CreateJourneyTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.string :campaign_type
      t.boolean :is_active, default: true
      t.integer :usage_count, default: 0
      t.json :template_data, default: {}
      t.json :metadata, default: {}
      t.string :thumbnail_url
      t.integer :estimated_duration_days
      t.string :difficulty_level
      t.text :best_practices

      t.timestamps
    end
    
    add_index :journey_templates, :usage_count
    add_index :journey_templates, :category
    add_index :journey_templates, :campaign_type
    add_index :journey_templates, :is_active
    add_index :journey_templates, [:category, :is_active]
  end
end
