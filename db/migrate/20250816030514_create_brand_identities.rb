class CreateBrandIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :brand_voice
      t.text :tone_guidelines
      t.text :messaging_framework
      t.text :restrictions
      t.string :status, default: 'draft', null: false
      t.boolean :is_active, default: false, null: false
      t.text :processed_guidelines

      t.timestamps
    end

    add_index :brand_identities, [:user_id, :name], unique: true
    add_index :brand_identities, :status
    add_index :brand_identities, :is_active
  end
end
