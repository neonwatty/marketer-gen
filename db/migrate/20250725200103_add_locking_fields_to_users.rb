class AddLockingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :locked_at, :datetime
    add_column :users, :lock_reason, :string
  end
end
