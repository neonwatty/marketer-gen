class AddSecurityFieldsToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :last_active_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
    add_column :sessions, :expires_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    
    add_index :sessions, :expires_at
  end
end
