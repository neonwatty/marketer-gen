class CreateEmailSubscribers < ActiveRecord::Migration[8.0]
  def change
    create_table :email_subscribers do |t|
      t.references :email_integration, null: false, foreign_key: true
      t.string :platform_subscriber_id, null: false
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.string :status, null: false
      t.datetime :subscribed_at
      t.datetime :unsubscribed_at
      t.text :tags
      t.text :segments
      t.text :location
      t.string :source

      t.timestamps
    end

    add_index :email_subscribers, [:email_integration_id, :platform_subscriber_id], unique: true, name: "idx_email_subscribers_integration_platform"
    add_index :email_subscribers, :email
    add_index :email_subscribers, :status
    add_index :email_subscribers, :subscribed_at
    add_index :email_subscribers, :source
  end
end
