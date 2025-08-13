class CreatePublishingQueues < ActiveRecord::Migration[8.0]
  def change
    create_table :publishing_queues do |t|
      t.references :content_schedule, null: false, foreign_key: true
      t.string :batch_id
      t.integer :processing_status
      t.datetime :scheduled_for
      t.datetime :attempted_at
      t.datetime :completed_at
      t.text :error_message
      t.integer :retry_count
      t.integer :max_retries
      t.text :processing_metadata

      t.timestamps
    end
  end
end
