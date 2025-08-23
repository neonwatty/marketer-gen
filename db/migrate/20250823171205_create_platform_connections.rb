class CreatePlatformConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :platform, null: false
      t.text :credentials # Encrypted JSON storage for tokens/credentials
      t.string :status, default: 'inactive'
      t.datetime :last_sync_at
      t.text :metadata # JSON storage for platform-specific data
      t.string :account_id # Platform-specific account identifier
      t.string :account_name # Human-readable account name

      t.timestamps
    end
    
    add_index :platform_connections, [:user_id, :platform], unique: true
    add_index :platform_connections, :status
    add_index :platform_connections, :last_sync_at
  end
end
