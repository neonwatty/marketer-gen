class CreateSyncRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_records do |t|
      t.references :platform_connection, null: false, foreign_key: true
      t.string :entity_type, null: false
      t.string :external_id, null: false
      t.string :sync_type, null: false
      t.string :status, default: 'pending'
      t.string :direction, default: 'bidirectional'
      t.text :local_data
      t.text :external_data
      t.text :metadata
      t.text :conflict_data
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :retry_count, default: 0

      t.timestamps
    end

    add_index :sync_records, [:platform_connection_id, :entity_type]
    add_index :sync_records, [:platform_connection_id, :external_id], unique: true
    add_index :sync_records, :status
    add_index :sync_records, :sync_type
    add_index :sync_records, :created_at
    add_index :sync_records, [:entity_type, :status]
  end
end
