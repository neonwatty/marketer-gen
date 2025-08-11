class CreatePromptTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_templates do |t|
      t.string :name, null: false
      t.string :prompt_type, null: false # campaign_planning, brand_analysis, content_generation, etc.
      t.text :system_prompt, null: false
      t.text :user_prompt, null: false
      t.json :variables, null: false, default: []
      t.json :default_values, null: false, default: {}
      t.text :description
      t.string :category # social_media, email, web, etc.
      t.integer :version, null: false, default: 1
      t.boolean :is_active, null: false, default: true
      t.integer :usage_count, null: false, default: 0
      t.references :parent_template, null: true, foreign_key: { to_table: :prompt_templates }
      t.json :metadata, null: false, default: {}
      t.string :tags
      t.float :temperature, default: 0.7
      t.integer :max_tokens, default: 2000
      t.string :model_preferences # JSON string for model-specific settings

      t.timestamps
    end

    # Add indexes for performance
    add_index :prompt_templates, :name
    add_index :prompt_templates, :prompt_type
    add_index :prompt_templates, :category
    add_index :prompt_templates, :is_active
    add_index :prompt_templates, :version
    add_index :prompt_templates, :usage_count
    add_index :prompt_templates, [:prompt_type, :category]
    add_index :prompt_templates, [:is_active, :prompt_type]
  end
end
