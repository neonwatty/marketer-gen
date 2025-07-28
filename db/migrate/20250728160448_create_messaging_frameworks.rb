class CreateMessagingFrameworks < ActiveRecord::Migration[8.0]
  def change
    create_table :messaging_frameworks do |t|
      t.references :brand, null: false, foreign_key: true
      t.json :key_messages, default: {}
      t.json :value_propositions, default: {}
      t.json :terminology, default: {}
      t.text :tagline
      t.text :mission_statement
      t.text :vision_statement
      t.json :approved_phrases, default: []
      t.json :banned_words, default: []
      t.json :tone_attributes, default: {}
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :messaging_frameworks, [:brand_id, :active]
  end
end
