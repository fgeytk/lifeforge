class CreateLifeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :life_events do |t|
      t.references :run, null: false, foreign_key: true
      t.integer :age
      t.string :icon_type, default: "lightning"
      t.string :title
      t.text :narrative
      t.json :choices, default: []
      t.string :selected_choice_id
      t.text :player_custom_action
      t.text :resolution_narrative

      t.timestamps
    end
  end
end
