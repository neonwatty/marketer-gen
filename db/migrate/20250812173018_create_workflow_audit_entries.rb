class CreateWorkflowAuditEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_audit_entries do |t|
      t.references :content_workflow, null: false, foreign_key: true
      t.string :action
      t.string :from_stage
      t.string :to_stage
      t.integer :performed_by_id
      t.text :comment
      t.text :metadata

      t.timestamps
    end
  end
end
