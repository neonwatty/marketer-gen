class AddChildTemplatesCountToPromptTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_templates, :child_templates_count, :integer, default: 0, null: false
  end
end
