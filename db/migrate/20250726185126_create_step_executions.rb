class CreateStepExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :step_executions do |t|
      t.references :journey_execution, null: false, foreign_key: true
      t.references :journey_step, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.string :status, default: 'pending'
      t.json :context, default: {}
      t.json :result_data, default: {}
      t.text :notes

      t.timestamps
    end
    
    add_index :step_executions, [:journey_execution_id, :journey_step_id], name: 'index_step_executions_on_execution_and_step'
    add_index :step_executions, :status
    add_index :step_executions, :started_at
  end
end
