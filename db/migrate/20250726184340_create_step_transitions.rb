class CreateStepTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :step_transitions do |t|
      t.references :from_step, null: false, foreign_key: { to_table: :journey_steps }
      t.references :to_step, null: false, foreign_key: { to_table: :journey_steps }
      t.json :conditions, default: {}
      t.integer :priority, default: 0
      t.string :transition_type, default: 'sequential'
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :step_transitions, [:from_step_id, :to_step_id], unique: true
    add_index :step_transitions, :priority
    add_index :step_transitions, :transition_type
  end
end
