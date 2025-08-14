class CreateJourneyTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :campaign_type, null: false
      t.text :template_data, null: false
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end

    add_index :journey_templates, [:campaign_type, :is_default]
    add_index :journey_templates, :name, unique: true
  end
end
