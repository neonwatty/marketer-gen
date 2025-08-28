class CreateApiQuotaTrackers < ActiveRecord::Migration[8.0]
  def change
    create_table :api_quota_trackers do |t|
      t.string :platform, null: false
      t.string :endpoint, null: false
      t.string :customer_id, null: false
      t.integer :quota_limit, null: false, default: 0
      t.integer :current_usage, null: false, default: 0
      t.integer :reset_interval, null: false
      t.datetime :reset_time

      t.timestamps
    end

    add_index :api_quota_trackers, [:platform, :customer_id, :endpoint], unique: true, name: 'idx_quota_trackers_platform_customer_endpoint'
    add_index :api_quota_trackers, [:customer_id]
    add_index :api_quota_trackers, [:reset_time]
  end
end
