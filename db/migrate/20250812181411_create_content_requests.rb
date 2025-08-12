class CreateContentRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :content_requests do |t|
      t.string :campaign_name
      t.string :content_type
      t.string :platform
      t.text :brand_context
      t.string :campaign_goal
      t.text :target_audience
      t.string :tone
      t.string :content_length
      t.text :required_elements
      t.text :restrictions
      t.text :additional_context
      t.text :request_metadata

      t.timestamps
    end
  end
end
