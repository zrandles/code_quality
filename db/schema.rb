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

ActiveRecord::Schema[8.0].define(version: 2025_10_24_210258) do
  create_table "actions", force: :cascade do |t|
    t.integer "player_id", null: false
    t.string "action_type"
    t.integer "target_x"
    t.integer "target_y"
    t.datetime "completes_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_actions_on_player_id"
  end

  create_table "apps", force: :cascade do |t|
    t.string "name", null: false
    t.string "path", null: false
    t.datetime "last_scanned_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_scanned_at"], name: "index_apps_on_last_scanned_at"
    t.index ["name"], name: "index_apps_on_name", unique: true
    t.index ["status"], name: "index_apps_on_status"
  end

  create_table "examples", force: :cascade do |t|
    t.string "name"
    t.string "category"
    t.string "status"
    t.text "description"
    t.integer "priority"
    t.decimal "score"
    t.integer "complexity"
    t.integer "speed"
    t.integer "quality"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "factions", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.integer "total_power"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "game_states", force: :cascade do |t|
    t.boolean "running"
    t.integer "winner_faction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "metric_summaries", force: :cascade do |t|
    t.integer "app_id", null: false
    t.string "scan_type", null: false
    t.integer "total_issues", default: 0
    t.integer "high_severity", default: 0
    t.integer "medium_severity", default: 0
    t.integer "low_severity", default: 0
    t.float "average_score"
    t.datetime "scanned_at"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "scan_type"], name: "index_metric_summaries_on_app_id_and_scan_type"
    t.index ["app_id"], name: "index_metric_summaries_on_app_id"
    t.index ["scanned_at"], name: "index_metric_summaries_on_scanned_at"
  end

  create_table "player_positions", force: :cascade do |t|
    t.integer "player_id", null: false
    t.integer "territory_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_player_positions_on_player_id"
    t.index ["territory_id"], name: "index_player_positions_on_territory_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "faction_id", null: false
    t.string "name"
    t.boolean "is_bot"
    t.integer "resources"
    t.integer "power_level"
    t.datetime "last_active_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "last_territory_id"
    t.index ["faction_id"], name: "index_players_on_faction_id"
  end

  create_table "quality_scans", force: :cascade do |t|
    t.integer "app_id", null: false
    t.string "scan_type", null: false
    t.string "severity"
    t.text "message"
    t.string "file_path"
    t.integer "line_number"
    t.float "metric_value"
    t.datetime "scanned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "scan_type"], name: "index_quality_scans_on_app_id_and_scan_type"
    t.index ["app_id"], name: "index_quality_scans_on_app_id"
    t.index ["scanned_at"], name: "index_quality_scans_on_scanned_at"
    t.index ["severity"], name: "index_quality_scans_on_severity"
  end

  create_table "scan_runs", force: :cascade do |t|
    t.integer "app_id", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "total_issues"
    t.string "status"
    t.text "scan_types"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_scan_runs_on_app_id"
  end

  create_table "territories", force: :cascade do |t|
    t.integer "x"
    t.integer "y"
    t.integer "faction_id"
    t.integer "player_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_rally_point", default: false, null: false
    t.index ["faction_id"], name: "index_territories_on_faction_id"
  end

  add_foreign_key "actions", "players"
  add_foreign_key "metric_summaries", "apps"
  add_foreign_key "player_positions", "players"
  add_foreign_key "player_positions", "territories"
  add_foreign_key "players", "factions"
  add_foreign_key "quality_scans", "apps"
  add_foreign_key "scan_runs", "apps"
  add_foreign_key "territories", "factions"
end
