class CreateTouchpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :touchpoints do |t|
      t.references :user, null: false, foreign_key: true
      t.references :journey, null: false, foreign_key: true
      t.references :journey_step, null: true, foreign_key: true
      t.string :channel, null: false
      t.string :touchpoint_type, null: false
      t.datetime :occurred_at, null: false
      t.string :attribution_weight
      t.text :metadata
      t.text :tracking_data

      t.timestamps
    end

    add_index :touchpoints, [:user_id, :occurred_at]
    add_index :touchpoints, [:journey_id, :occurred_at]
    add_index :touchpoints, :channel
    add_index :touchpoints, :touchpoint_type
    add_index :touchpoints, [:channel, :touchpoint_type]
  end
end
