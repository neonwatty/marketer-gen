class CreatePersonas < ActiveRecord::Migration[8.0]
  def change
    create_table :personas do |t|
      t.string :name, null: false
      t.text :description
      t.text :characteristics
      t.text :demographics
      t.text :goals
      t.text :pain_points
      t.text :preferred_channels
      t.text :content_preferences
      t.text :behavioral_traits
      t.boolean :is_active, default: true, null: false
      t.integer :priority, default: 0
      t.references :user, null: false, foreign_key: true
      t.text :tags # JSON field for flexible tagging
      t.text :matching_rules # JSON field for persona matching logic

      t.timestamps
    end

    add_index :personas, [:user_id, :name], unique: true
    add_index :personas, :is_active
    add_index :personas, :priority
  end
end
