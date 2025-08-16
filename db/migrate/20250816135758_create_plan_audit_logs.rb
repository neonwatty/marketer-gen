class CreatePlanAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_audit_logs do |t|
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false # created, updated, submitted_for_approval, approved, rejected, feedback_added, etc.
      t.json :details
      t.json :metadata
      t.references :plan_version, null: true, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :plan_audit_logs, [:campaign_plan_id, :created_at]
    add_index :plan_audit_logs, [:user_id, :created_at]
    add_index :plan_audit_logs, :action
  end
end
