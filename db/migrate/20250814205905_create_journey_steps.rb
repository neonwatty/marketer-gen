class CreateJourneySteps < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_steps do |t|
      t.references :journey, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :step_type, null: false
      t.text :content
      t.string :channel
      t.integer :sequence_order, null: false, default: 0
      t.text :settings

      t.timestamps
    end

    add_index :journey_steps, [:journey_id, :sequence_order], unique: true
    add_index :journey_steps, :step_type
    add_index :journey_steps, :channel
  end
end
