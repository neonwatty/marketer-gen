class CreateJourneyStages < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_stages do |t|
      t.references :journey, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :stage_type, null: false
      t.string :name, null: false
      t.text :description
      t.text :content
      t.json :configuration, default: {}, null: false
      t.integer :duration_days
      t.string :status, default: 'draft'
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :journey_stages, [:journey_id, :position]
    add_index :journey_stages, [:stage_type]
    add_index :journey_stages, [:status]
    add_index :journey_stages, [:is_active]
  end
end
