class CreateBudgetAllocations < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_allocations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :campaign_plan, null: true, foreign_key: true
      t.string :name, null: false
      t.decimal :total_budget, precision: 10, scale: 2, null: false
      t.decimal :allocated_amount, precision: 10, scale: 2, null: false
      t.string :channel_type, null: false
      t.date :time_period_start, null: false
      t.date :time_period_end, null: false
      t.string :optimization_objective, null: false
      t.integer :status, default: 0, null: false
      t.text :predictive_model_data
      t.text :performance_metrics
      t.text :allocation_breakdown
      t.decimal :efficiency_score, precision: 5, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :budget_allocations, :channel_type
    add_index :budget_allocations, :status
    add_index :budget_allocations, [:time_period_start, :time_period_end]
  end
end
