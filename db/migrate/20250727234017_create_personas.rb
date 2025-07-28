class CreatePersonas < ActiveRecord::Migration[8.0]
  def change
    create_table :personas do |t|
      t.string :name, null: false
      t.text :description
      t.json :demographics, default: {}
      t.json :behaviors, default: {}
      t.json :preferences, default: {}
      t.json :psychographics, default: {}
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :personas, [:user_id, :name], unique: true
    add_index :personas, :name
  end
end
