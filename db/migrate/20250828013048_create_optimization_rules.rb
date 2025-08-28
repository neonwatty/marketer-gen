class CreateOptimizationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_rules do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.string :rule_type, null: false
      t.string :trigger_type, null: false
      t.string :status, null: false, default: 'active'
      t.integer :priority, null: false, default: 5
      t.decimal :confidence_threshold, null: false, default: 0.7, precision: 3, scale: 2
      t.integer :execution_count, null: false, default: 0
      t.datetime :last_executed_at
      t.string :last_execution_result
      t.datetime :paused_at
      t.datetime :deactivated_at
      t.text :trigger_conditions
      t.text :optimization_actions
      t.text :safety_checks
      t.text :rollback_conditions
      t.text :metadata

      t.timestamps
    end

    add_index :optimization_rules, :status
    add_index :optimization_rules, :rule_type
    add_index :optimization_rules, :trigger_type
    add_index :optimization_rules, :priority
    add_index :optimization_rules, [:campaign_plan_id, :status]
    add_index :optimization_rules, :last_executed_at
  end
end
