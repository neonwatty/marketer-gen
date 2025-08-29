class CreateValidationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :validation_rules do |t|
      t.string :table_name, null: false
      t.string :field_name, null: false
      t.json :rules
      t.boolean :real_time_enabled, default: true
      t.string :validation_endpoint
      t.text :error_message_template

      t.timestamps
    end
    
    add_index :validation_rules, [:table_name, :field_name], unique: true
    add_index :validation_rules, :real_time_enabled
  end
end
