class CreateOptimizationExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_executions do |t|
      t.references :optimization_rule, null: false, foreign_key: true
      t.datetime :executed_at, null: false
      t.string :status
      t.text :result
      t.text :performance_data_snapshot
      t.text :actions_taken
      t.text :metadata
      t.datetime :rolled_back_at

      t.timestamps
    end

    add_index :optimization_executions, :status
    add_index :optimization_executions, :executed_at
    add_index :optimization_executions, [:optimization_rule_id, :status]
    add_index :optimization_executions, [:optimization_rule_id, :executed_at]
    add_index :optimization_executions, :rolled_back_at
  end
end
