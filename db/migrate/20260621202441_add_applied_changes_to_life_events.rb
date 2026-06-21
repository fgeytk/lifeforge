class AddAppliedChangesToLifeEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :life_events, :applied_changes, :json
  end
end
