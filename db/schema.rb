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

ActiveRecord::Schema[8.1].define(version: 2025_10_26_014918) do
  create_table "actions", force: :cascade do |t|
    t.string "action_type"
    t.datetime "completes_at"
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.string "status"
    t.integer "target_x"
    t.integer "target_y"
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_actions_on_player_id"
  end

  create_table "examples", force: :cascade do |t|
    t.string "category"
    t.integer "complexity"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "priority"
    t.integer "quality"
    t.decimal "score"
    t.integer "speed"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "factions", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "total_power"
    t.datetime "updated_at", null: false
  end

  create_table "game_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "running"
    t.datetime "updated_at", null: false
    t.integer "winner_faction_id"
  end

  create_table "metric_summaries", force: :cascade do |t|
    t.integer "app_id", null: false
    t.float "average_score"
    t.datetime "created_at", null: false
    t.integer "high_severity", default: 0
    t.integer "low_severity", default: 0
    t.integer "medium_severity", default: 0
    t.text "metadata"
    t.string "scan_type", null: false
    t.datetime "scanned_at"
    t.integer "total_issues", default: 0
    t.datetime "updated_at", null: false
    t.index ["app_id", "scan_type"], name: "index_metric_summaries_on_app_id_and_scan_type"
    t.index ["app_id"], name: "index_metric_summaries_on_app_id"
    t.index ["scanned_at"], name: "index_metric_summaries_on_scanned_at"
  end

  create_table "player_positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "territory_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_player_positions_on_player_id"
    t.index ["territory_id"], name: "index_player_positions_on_territory_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "faction_id", null: false
    t.boolean "is_bot"
    t.datetime "last_active_at"
    t.integer "last_territory_id"
    t.string "name"
    t.integer "power_level"
    t.integer "resources"
    t.datetime "updated_at", null: false
    t.index ["faction_id"], name: "index_players_on_faction_id"
  end

  create_table "quality_scans", force: :cascade do |t|
    t.integer "app_id", null: false
    t.datetime "created_at", null: false
    t.string "file_path"
    t.integer "line_number"
    t.text "message"
    t.float "metric_value"
    t.string "scan_type", null: false
    t.datetime "scanned_at"
    t.string "severity"
    t.datetime "updated_at", null: false
    t.index ["app_id", "scan_type"], name: "index_quality_scans_on_app_id_and_scan_type"
    t.index ["app_id"], name: "index_quality_scans_on_app_id"
    t.index ["scanned_at"], name: "index_quality_scans_on_scanned_at"
    t.index ["severity"], name: "index_quality_scans_on_severity"
  end

  create_table "scan_runs", force: :cascade do |t|
    t.integer "app_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "scan_types"
    t.datetime "started_at"
    t.string "status"
    t.integer "total_issues"
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_scan_runs_on_app_id"
  end

  create_table "scanned_apps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_scanned_at"
    t.string "name", null: false
    t.string "path", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["last_scanned_at"], name: "index_scanned_apps_on_last_scanned_at"
    t.index ["name"], name: "index_scanned_apps_on_name", unique: true
    t.index ["status"], name: "index_scanned_apps_on_status"
  end

  create_table "territories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "faction_id"
    t.boolean "is_rally_point", default: false, null: false
    t.integer "player_count"
    t.datetime "updated_at", null: false
    t.integer "x"
    t.integer "y"
    t.index ["faction_id"], name: "index_territories_on_faction_id"
  end

  add_foreign_key "actions", "players"
  add_foreign_key "metric_summaries", "scanned_apps", column: "app_id"
  add_foreign_key "player_positions", "players"
  add_foreign_key "player_positions", "territories"
  add_foreign_key "players", "factions"
  add_foreign_key "quality_scans", "scanned_apps", column: "app_id"
  add_foreign_key "scan_runs", "scanned_apps", column: "app_id"
  add_foreign_key "territories", "factions"
end
