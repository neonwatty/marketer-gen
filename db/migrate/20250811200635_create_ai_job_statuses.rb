class CreateAiJobStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_job_statuses do |t|
      t.references :generation_request, null: false, foreign_key: { to_table: :ai_generation_requests }
      t.string :job_id
      t.string :status
      t.text :progress_data

      t.timestamps
    end
  end
end
