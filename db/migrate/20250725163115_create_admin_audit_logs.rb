class CreateAdminAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.string :auditable_type
      t.integer :auditable_id
      t.text :change_details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
