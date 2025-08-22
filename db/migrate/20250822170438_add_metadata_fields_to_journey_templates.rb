class AddMetadataFieldsToJourneyTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :journey_templates, :category, :string
    add_column :journey_templates, :industry, :string
    add_column :journey_templates, :complexity_level, :string
    add_column :journey_templates, :prerequisites, :text

    # Add indexes for filtering performance
    add_index :journey_templates, :category
    add_index :journey_templates, :industry
    add_index :journey_templates, :complexity_level
    add_index :journey_templates, [ :category, :industry ]
  end
end
