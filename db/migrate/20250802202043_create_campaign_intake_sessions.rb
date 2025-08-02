class CreateCampaignIntakeSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_intake_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :campaign, null: true, foreign_key: true
      t.string :thread_id, null: false
      t.string :status
      t.json :context
      t.json :messages
      t.datetime :started_at
      t.datetime :completed_at
      t.float :estimated_completion_time
      t.float :actual_completion_time

      t.timestamps
    end
    add_index :campaign_intake_sessions, :status
    add_index :campaign_intake_sessions, [:user_id, :thread_id], unique: true
  end
end
