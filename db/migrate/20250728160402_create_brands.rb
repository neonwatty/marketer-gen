class CreateBrands < ActiveRecord::Migration[8.0]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.json :settings, default: {}
      t.string :industry
      t.string :website
      t.json :color_scheme, default: {}
      t.json :typography, default: {}
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :brands, [:user_id, :name], unique: true
    add_index :brands, :active
    add_index :brands, :industry
  end
end
