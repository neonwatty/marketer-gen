class CreateWorkflowAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_assignments do |t|
      t.references :content_workflow, null: false, foreign_key: true
      t.integer :user_id
      t.string :role
      t.string :stage
      t.integer :status
      t.integer :assignment_type
      t.datetime :assigned_at
      t.integer :assigned_by_id
      t.datetime :unassigned_at
      t.integer :unassigned_by_id
      t.datetime :expires_at
      t.datetime :activated_at
      t.integer :activated_by_id
      t.datetime :suspended_at
      t.integer :suspended_by_id
      t.datetime :extended_at
      t.integer :extended_by_id

      t.timestamps
    end
  end
end
