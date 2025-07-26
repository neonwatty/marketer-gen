class CreateJourneyExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :journey_executions do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :current_step, null: true, foreign_key: { to_table: :journey_steps }
      t.string :status, default: 'initialized', null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :paused_at
      t.json :execution_context, default: {}
      t.json :metadata, default: {}
      t.text :completion_notes

      t.timestamps
    end
    
    add_index :journey_executions, [:user_id, :journey_id], unique: true
    add_index :journey_executions, :status
    add_index :journey_executions, :started_at
    add_index :journey_executions, :completed_at
  end
end
