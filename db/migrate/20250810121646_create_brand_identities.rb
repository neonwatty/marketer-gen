class CreateBrandIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_identities do |t|
      t.string :name, null: false
      t.text :description
      t.json :guidelines, null: false, default: {}
      t.json :messaging_frameworks, null: false, default: {}
      t.json :color_palette, null: false, default: {}
      t.json :typography, null: false, default: {}
      t.integer :version, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.datetime :published_at

      t.timestamps
    end

    # Add indexes for performance
    add_index :brand_identities, :name, unique: true
    add_index :brand_identities, :version
    add_index :brand_identities, :active
    add_index :brand_identities, :published_at
  end
end
