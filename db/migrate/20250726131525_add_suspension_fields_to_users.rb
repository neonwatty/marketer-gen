class AddSuspensionFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :suspended_at, :datetime
    add_column :users, :suspension_reason, :text
    add_column :users, :suspended_by_id, :integer
    
    add_index :users, :suspended_at
    add_foreign_key :users, :users, column: :suspended_by_id
  end
end
