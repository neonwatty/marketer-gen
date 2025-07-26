class CreateJourneySteps < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_steps do |t|
      t.references :journey, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :stage, null: false
      t.integer :position, null: false, default: 0
      t.string :content_type
      t.string :channel
      t.integer :duration_days, default: 1
      t.json :config, default: {}
      t.json :conditions, default: {}
      t.json :metadata, default: {}
      t.boolean :is_entry_point, default: false
      t.boolean :is_exit_point, default: false

      t.timestamps
    end
    
    add_index :journey_steps, [:journey_id, :position]
    add_index :journey_steps, [:journey_id, :stage]
    add_index :journey_steps, :stage
    add_index :journey_steps, :content_type
    add_index :journey_steps, :channel
  end
end
