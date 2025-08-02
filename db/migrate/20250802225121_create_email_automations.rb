class CreateEmailAutomations < ActiveRecord::Migration[8.0]
  def change
    create_table :email_automations do |t|
      t.references :email_integration, null: false, foreign_key: true
      t.string :platform_automation_id, null: false
      t.string :name, null: false
      t.string :automation_type
      t.string :status, null: false
      t.string :trigger_type
      t.text :trigger_configuration
      t.integer :total_subscribers, default: 0
      t.integer :active_subscribers, default: 0
      t.text :configuration

      t.timestamps
    end

    add_index :email_automations, [:email_integration_id, :platform_automation_id], unique: true, name: "idx_email_automations_integration_platform"
    add_index :email_automations, :status
    add_index :email_automations, :automation_type
    add_index :email_automations, :trigger_type
  end
end
