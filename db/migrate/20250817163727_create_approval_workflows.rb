class CreateApprovalWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_workflows do |t|
      t.references :generated_content, null: false, foreign_key: true
      t.string :workflow_type, null: false
      t.json :required_approvers, null: false
      t.integer :current_stage, default: 1, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :due_date
      t.json :escalation_rules
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.json :metadata

      t.timestamps
    end
    
    add_index :approval_workflows, :status
    add_index :approval_workflows, :workflow_type
    add_index :approval_workflows, :due_date
  end
end
