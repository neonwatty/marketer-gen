class CreateWorkflowNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_notifications do |t|
      t.integer :user_id
      t.references :workflow, null: false, foreign_key: { to_table: :content_workflows }
      t.string :notification_type
      t.string :title
      t.text :message
      t.integer :priority
      t.integer :status
      t.datetime :read_at
      t.datetime :clicked_at
      t.integer :click_count
      t.datetime :dismissed_at
      t.datetime :archived_at
      t.text :metadata

      t.timestamps
    end
  end
end
