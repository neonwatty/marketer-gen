class CreateContentSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :content_schedules do |t|
      t.references :content_item, polymorphic: true, null: false
      t.references :campaign, null: false, foreign_key: true
      t.string :channel
      t.string :platform
      t.datetime :scheduled_at
      t.datetime :published_at
      t.integer :status
      t.integer :priority
      t.string :frequency
      t.text :recurrence_data
      t.boolean :auto_publish
      t.string :time_zone
      t.text :metadata
      t.references :created_by, null: false, foreign_key: true
      t.references :updated_by, null: false, foreign_key: true

      t.timestamps
    end
  end
end
