class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :characters do |t|
      t.references :run, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.integer :age, default: 18
      t.string :location
      t.string :occupation
      t.integer :cash, default: 1000
      t.integer :health, default: 100
      t.integer :happiness, default: 50
      t.integer :intelligence, default: 50
      t.integer :fitness, default: 50
      t.integer :looks, default: 50
      t.integer :charisma, default: 50
      t.json :relationships, default: {}
      t.json :assets, default: []

      t.timestamps
    end
  end
end
