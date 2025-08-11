class CreateAiGenerationRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_generation_requests do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :content_type
      t.text :prompt_data
      t.string :status
      t.text :generated_content
      t.text :metadata
      t.string :webhook_url
      t.datetime :completed_at

      t.timestamps
    end
  end
end
