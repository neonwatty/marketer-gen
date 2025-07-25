class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :controller, null: false
      t.string :request_path
      t.string :request_method
      t.string :ip_address
      t.text :user_agent
      t.string :session_id
      t.integer :response_status
      t.float :response_time
      t.text :metadata
      t.datetime :occurred_at, null: false
      t.string :referrer
      t.boolean :suspicious, default: false
      t.string :device_type
      t.string :browser_name
      t.string :os_name

      t.timestamps
    end

    # user_id index is automatically created by references
    add_index :activities, [:user_id, :occurred_at]
    add_index :activities, :occurred_at
    add_index :activities, :action
    add_index :activities, :suspicious
    add_index :activities, :session_id
    add_index :activities, :ip_address
  end
end
