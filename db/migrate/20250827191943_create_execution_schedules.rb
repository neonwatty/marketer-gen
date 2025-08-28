class CreateExecutionSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :execution_schedules do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.datetime :scheduled_at, null: false
      t.json :platform_targets, default: {}
      t.json :execution_rules, default: {}
      t.string :status, null: false, default: 'scheduled'
      t.integer :priority, default: 5
      t.json :metadata, default: {}
      t.datetime :last_executed_at
      t.datetime :next_execution_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :execution_schedules, [:status, :scheduled_at]
    add_index :execution_schedules, [:campaign_plan_id, :status]
    add_index :execution_schedules, :next_execution_at
    add_index :execution_schedules, [:priority, :scheduled_at]
    add_index :execution_schedules, :active
  end
end
