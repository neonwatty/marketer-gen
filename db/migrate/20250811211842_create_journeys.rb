class CreateJourneys < ActiveRecord::Migration[8.0]
  def change
    create_table :journeys do |t|
      t.string :name, null: false
      t.string :template_type
      t.text :purpose
      t.text :goals
      t.text :timing
      t.text :audience
      t.references :campaign, null: false, foreign_key: true
      t.boolean :is_active, default: true, null: false
      t.integer :position, default: 0

      t.timestamps
    end
    
    add_index :journeys, [:campaign_id, :position]
    add_index :journeys, [:template_type]
    add_index :journeys, [:is_active]
  end
end
