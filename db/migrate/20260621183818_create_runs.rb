class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.string :status, default: "active"
      t.text :starting_prompt
      t.integer :score_net_worth, default: 0

      t.timestamps
    end
  end
end
