# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_21_183832) do
  create_table "characters", force: :cascade do |t|
    t.integer "age", default: 18
    t.json "assets", default: []
    t.integer "cash", default: 1000
    t.integer "charisma", default: 50
    t.datetime "created_at", null: false
    t.string "first_name"
    t.integer "fitness", default: 50
    t.integer "happiness", default: 50
    t.integer "health", default: 100
    t.integer "intelligence", default: 50
    t.string "last_name"
    t.string "location"
    t.integer "looks", default: 50
    t.string "occupation"
    t.json "relationships", default: {}
    t.integer "run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_characters_on_run_id"
  end

  create_table "life_events", force: :cascade do |t|
    t.integer "age"
    t.json "choices", default: []
    t.datetime "created_at", null: false
    t.string "icon_type", default: "lightning"
    t.text "narrative"
    t.text "player_custom_action"
    t.text "resolution_narrative"
    t.integer "run_id", null: false
    t.string "selected_choice_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_life_events_on_run_id"
  end

  create_table "runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "score_net_worth", default: 0
    t.text "starting_prompt"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "characters", "runs"
  add_foreign_key "life_events", "runs"
end
