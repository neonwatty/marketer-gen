class CreatePersonaContents < ActiveRecord::Migration[8.0]
  def change
    create_table :persona_contents do |t|
      t.references :persona, null: false, foreign_key: true
      t.references :generated_content, null: false, foreign_key: true
      t.string :adaptation_type, null: false
      t.text :adapted_content
      t.text :adaptation_metadata
      t.decimal :effectiveness_score, precision: 5, scale: 2
      t.boolean :is_primary_adaptation, default: false
      t.text :adaptation_rationale

      t.timestamps
    end

    add_index :persona_contents, [:persona_id, :generated_content_id], unique: true, name: 'index_persona_contents_unique'
    add_index :persona_contents, :adaptation_type
    add_index :persona_contents, :effectiveness_score
  end
end
