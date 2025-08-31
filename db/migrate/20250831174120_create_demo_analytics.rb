class CreateDemoAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :demo_analytics do |t|
      t.string :workflow_key, null: false
      t.references :user, null: true, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration
      t.integer :steps_completed, default: 0
      t.integer :total_steps
      t.text :user_agent
      t.string :ip_address
      t.decimal :completion_rate, precision: 5, scale: 4

      t.timestamps
    end
    
    add_index :demo_analytics, :workflow_key
    add_index :demo_analytics, :started_at
    add_index :demo_analytics, [:workflow_key, :started_at]
  end
end
