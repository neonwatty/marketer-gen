class CreateContentAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :content_audit_logs do |t|
      t.references :generated_content, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.json :old_values
      t.json :new_values
      t.string :ip_address
      t.text :user_agent
      t.json :metadata

      t.timestamps
    end
    
    add_index :content_audit_logs, :action
    add_index :content_audit_logs, :created_at
    add_index :content_audit_logs, [:generated_content_id, :created_at]
  end
end
