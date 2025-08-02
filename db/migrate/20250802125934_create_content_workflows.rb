class CreateContentWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :content_workflows do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name
      t.integer :status
      t.boolean :parallel_approval
      t.boolean :auto_progression
      t.integer :step_timeout_hours

      t.timestamps
    end
  end
end
