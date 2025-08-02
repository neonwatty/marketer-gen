class CreateContentTags < ActiveRecord::Migration[8.0]
  def change
    create_table :content_tags do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :tag_name
      t.integer :tag_type

      t.timestamps
    end
  end
end
