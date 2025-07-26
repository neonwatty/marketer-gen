class CreateUserActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.string :controller_name
      t.string :action_name
      t.string :resource_type
      t.integer :resource_id
      t.string :ip_address
      t.text :user_agent
      t.text :request_params
      t.json :metadata
      t.datetime :performed_at

      t.timestamps
    end
  end
end
