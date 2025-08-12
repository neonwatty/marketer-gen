class CreateContentResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :content_responses do |t|
      t.references :content_request, null: false, foreign_key: true
      t.text :generated_content
      t.string :generation_status
      t.text :response_metadata

      t.timestamps
    end
  end
end
