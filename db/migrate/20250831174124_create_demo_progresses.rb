class CreateDemoProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :demo_progresses do |t|
      t.references :demo_analytic, null: false, foreign_key: true
      t.integer :step_number
      t.string :step_title
      t.datetime :completed_at
      t.integer :time_spent

      t.timestamps
    end
  end
end
