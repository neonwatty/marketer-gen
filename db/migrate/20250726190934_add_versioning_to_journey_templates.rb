class AddVersioningToJourneyTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :journey_templates, :version, :decimal, precision: 5, scale: 2, default: 1.0, null: false
    add_reference :journey_templates, :original_template, null: true, foreign_key: { to_table: :journey_templates }
    add_column :journey_templates, :parent_version, :decimal, precision: 5, scale: 2
    add_column :journey_templates, :version_notes, :text
    add_column :journey_templates, :is_published_version, :boolean, default: true, null: false
    
    add_index :journey_templates, [:original_template_id, :version], unique: true
    add_index :journey_templates, :is_published_version
  end
end
