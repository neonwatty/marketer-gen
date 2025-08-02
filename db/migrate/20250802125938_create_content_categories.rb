class CreateContentCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :content_categories do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.references :parent, null: false, foreign_key: true
      t.integer :hierarchy_level
      t.string :hierarchy_path
      t.boolean :active

      t.timestamps
    end
  end
end
