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

ActiveRecord::Schema[8.1].define(version: 2026_06_21_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "contact_point_type", ["residential", "public", "water_pump", "non_establishment"]
  create_enum "other_deduction_type", ["fixed", "coefficient", "unit_coefficient"]
  create_enum "user_role", ["technician", "system_admin", "unit_admin", "commander", "division_commander"]

  create_table "backups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "error_message"
    t.string "filename", null: false
    t.bigint "size_bytes", default: 0, null: false
    t.string "status", default: "completed", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_backups_on_created_at"
    t.index ["filename"], name: "index_backups_on_filename", unique: true
  end

  create_table "blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_blocks_on_discarded_at"
    t.index ["name", "unit_id"], name: "index_blocks_on_name_and_unit_id", unique: true
    t.index ["unit_id"], name: "index_blocks_on_unit_id"
  end

  create_table "calculation_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "inputs_changed_at"
    t.datetime "last_calculated_at"
    t.bigint "period_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["period_id"], name: "index_calculation_states_on_period_id"
    t.index ["zone_id", "period_id"], name: "idx_calculation_states_unique", unique: true
    t.index ["zone_id"], name: "index_calculation_states_on_zone_id"
  end

  create_table "calculations", force: :cascade do |t|
    t.datetime "calculated_at", null: false
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.decimal "deficit", default: "0.0", null: false
    t.decimal "deficit_amount", default: "0.0", null: false
    t.decimal "division_public_deduction", null: false
    t.decimal "loss_deduction", null: false
    t.decimal "other_deduction", null: false
    t.bigint "period_id", null: false
    t.decimal "remaining_standard", null: false
    t.decimal "residential_standard", null: false
    t.decimal "residential_usage", null: false
    t.decimal "savings_deduction", null: false
    t.decimal "surplus", default: "0.0", null: false
    t.decimal "surplus_amount", default: "0.0", null: false
    t.decimal "total_deduction", null: false
    t.integer "total_personnel", null: false
    t.decimal "total_standard", null: false
    t.decimal "total_usage", null: false
    t.decimal "unit_public_deduction", null: false
    t.datetime "updated_at", null: false
    t.decimal "water_pump_standard", null: false
    t.decimal "water_pump_usage", null: false
    t.index ["contact_point_id", "period_id"], name: "idx_calculations_unique", unique: true
    t.index ["contact_point_id"], name: "index_calculations_on_contact_point_id"
    t.index ["period_id"], name: "index_calculations_on_period_id"
  end

  create_table "contact_points", force: :cascade do |t|
    t.bigint "block_id"
    t.enum "contact_point_type", null: false, enum_type: "contact_point_type"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "group_id"
    t.string "name", null: false
    t.integer "personnel_count"
    t.bigint "unit_id"
    t.datetime "updated_at", null: false
    t.bigint "zone_id"
    t.index ["block_id"], name: "index_contact_points_on_block_id"
    t.index ["discarded_at"], name: "index_contact_points_on_discarded_at"
    t.index ["group_id"], name: "index_contact_points_on_group_id"
    t.index ["name", "unit_id", "zone_id", "contact_point_type"], name: "idx_contact_points_name_unique", unique: true
    t.index ["unit_id"], name: "index_contact_points_on_unit_id"
    t.index ["zone_id"], name: "index_contact_points_on_zone_id"
  end

  create_table "groups", force: :cascade do |t|
    t.bigint "block_id"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_groups_on_block_id"
    t.index ["discarded_at"], name: "index_groups_on_discarded_at"
    t.index ["name", "unit_id"], name: "index_groups_on_name_and_unit_id", unique: true
    t.index ["unit_id"], name: "index_groups_on_unit_id"
  end

  create_table "loss_summaries", force: :cascade do |t|
    t.decimal "a", null: false
    t.decimal "b", null: false
    t.decimal "c", null: false
    t.datetime "created_at", null: false
    t.bigint "period_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["period_id"], name: "index_loss_summaries_on_period_id"
    t.index ["zone_id", "period_id"], name: "index_loss_summaries_on_zone_id_and_period_id", unique: true
    t.index ["zone_id"], name: "index_loss_summaries_on_zone_id"
  end

  create_table "main_meter_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "main_meter_id", null: false
    t.bigint "period_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "usage", null: false
    t.index ["main_meter_id", "period_id"], name: "index_main_meter_readings_on_main_meter_id_and_period_id", unique: true
    t.index ["main_meter_id"], name: "index_main_meter_readings_on_main_meter_id"
    t.index ["period_id"], name: "index_main_meter_readings_on_period_id"
  end

  create_table "main_meters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["discarded_at"], name: "index_main_meters_on_discarded_at"
    t.index ["zone_id"], name: "index_main_meters_on_zone_id"
  end

  create_table "meter_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.decimal "loss"
    t.decimal "manual_usage"
    t.text "manual_usage_note"
    t.bigint "meter_id", null: false
    t.boolean "no_loss", default: false, null: false
    t.bigint "period_id", null: false
    t.decimal "reading_end"
    t.decimal "reading_start", default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["meter_id", "period_id"], name: "index_meter_readings_on_meter_id_and_period_id", unique: true
    t.index ["meter_id"], name: "index_meter_readings_on_meter_id"
    t.index ["period_id"], name: "index_meter_readings_on_period_id"
  end

  create_table "meters", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.boolean "no_loss", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_id"], name: "index_meters_on_contact_point_id"
    t.index ["discarded_at"], name: "index_meters_on_discarded_at"
    t.index ["name", "contact_point_id"], name: "index_meters_on_name_and_contact_point_id", unique: true
  end

  create_table "non_establishment_snapshots", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "period_id", null: false
    t.integer "personnel_count", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_id", "period_id"], name: "idx_non_establishment_snapshots_unique", unique: true
    t.index ["contact_point_id"], name: "index_non_establishment_snapshots_on_contact_point_id"
    t.index ["period_id"], name: "index_non_establishment_snapshots_on_period_id"
  end

  create_table "other_deductions", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.enum "other_type", default: "fixed", null: false, enum_type: "other_deduction_type"
    t.decimal "other_value", default: "0.0", null: false
    t.bigint "period_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_id", "period_id"], name: "idx_other_deductions_unique", unique: true
    t.index ["contact_point_id"], name: "index_other_deductions_on_contact_point_id"
    t.index ["period_id"], name: "index_other_deductions_on_period_id"
  end

  create_table "periods", force: :cascade do |t|
    t.boolean "closed", default: true, null: false
    t.datetime "created_at", null: false
    t.decimal "division_public_rate", default: "10.0", null: false
    t.integer "month", null: false
    t.boolean "pump_allocation_per_station", default: false, null: false
    t.decimal "savings_rate", default: "5.0", null: false
    t.decimal "unit_price", null: false
    t.datetime "updated_at", null: false
    t.decimal "water_pump_standard", default: "9.45", null: false
    t.integer "year", null: false
    t.index "(true)", name: "idx_periods_only_one_open", unique: true, where: "(closed = false)"
    t.index ["year", "month"], name: "index_periods_on_year_and_month", unique: true
  end

  create_table "personnel_entries", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "period_id", null: false
    t.bigint "rank_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_id", "period_id", "rank_id"], name: "idx_personnel_entries_unique", unique: true
    t.index ["contact_point_id"], name: "index_personnel_entries_on_contact_point_id"
    t.index ["period_id"], name: "index_personnel_entries_on_period_id"
    t.index ["rank_id"], name: "index_personnel_entries_on_rank_id"
  end

  create_table "pump_allocations", force: :cascade do |t|
    t.bigint "block_id"
    t.decimal "coefficient", default: "1.0", null: false
    t.bigint "contact_point_id"
    t.datetime "created_at", null: false
    t.decimal "fixed_percentage"
    t.bigint "group_id"
    t.integer "lock_version", default: 0, null: false
    t.bigint "period_id", null: false
    t.bigint "pump_contact_point_id"
    t.bigint "unit_id"
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["block_id"], name: "index_pump_allocations_on_block_id"
    t.index ["contact_point_id"], name: "index_pump_allocations_on_contact_point_id"
    t.index ["group_id"], name: "index_pump_allocations_on_group_id"
    t.index ["period_id"], name: "index_pump_allocations_on_period_id"
    t.index ["pump_contact_point_id"], name: "index_pump_allocations_on_pump_contact_point_id"
    t.index ["unit_id"], name: "index_pump_allocations_on_unit_id"
    t.index ["zone_id", "period_id", "pump_contact_point_id"], name: "index_pump_allocations_on_zone_period_station"
    t.index ["zone_id"], name: "index_pump_allocations_on_zone_id"
  end

  create_table "pump_station_charges", force: :cascade do |t|
    t.decimal "amount", null: false
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.bigint "period_id", null: false
    t.bigint "pump_contact_point_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["contact_point_id"], name: "index_pump_station_charges_on_contact_point_id"
    t.index ["period_id", "contact_point_id"], name: "index_pump_station_charges_on_period_id_and_contact_point_id"
    t.index ["period_id"], name: "index_pump_station_charges_on_period_id"
    t.index ["pump_contact_point_id"], name: "index_pump_station_charges_on_pump_contact_point_id"
    t.index ["zone_id", "period_id"], name: "index_pump_station_charges_on_zone_id_and_period_id"
    t.index ["zone_id"], name: "index_pump_station_charges_on_zone_id"
  end

  create_table "ranks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "period_id", null: false
    t.integer "position", null: false
    t.decimal "quota", null: false
    t.datetime "updated_at", null: false
    t.index ["period_id"], name: "index_ranks_on_period_id"
  end

  create_table "unit_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "period_id", null: false
    t.bigint "unit_id", null: false
    t.decimal "unit_public_rate", default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["period_id"], name: "index_unit_configs_on_period_id"
    t.index ["unit_id", "period_id"], name: "index_unit_configs_on_unit_id_and_period_id", unique: true
    t.index ["unit_id"], name: "index_unit_configs_on_unit_id"
  end

  create_table "units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["discarded_at"], name: "index_units_on_discarded_at"
    t.index ["name"], name: "index_units_on_name", unique: true
    t.index ["zone_id"], name: "index_units_on_zone_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_account", default: false, null: false
    t.string "display_name", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "force_password_change", default: true, null: false
    t.enum "role", null: false, enum_type: "user_role"
    t.bigint "unit_id"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["unit_id"], name: "index_users_on_unit_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["event"], name: "index_versions_on_event"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  create_table "zones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "manager_unit_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_zones_on_discarded_at"
    t.index ["manager_unit_id"], name: "index_zones_on_manager_unit_id"
    t.index ["name"], name: "index_zones_on_name", unique: true
  end

  add_foreign_key "backups", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "blocks", "units"
  add_foreign_key "calculation_states", "periods"
  add_foreign_key "calculation_states", "zones"
  add_foreign_key "calculations", "contact_points"
  add_foreign_key "calculations", "periods"
  add_foreign_key "contact_points", "blocks"
  add_foreign_key "contact_points", "groups"
  add_foreign_key "contact_points", "units"
  add_foreign_key "contact_points", "zones"
  add_foreign_key "groups", "blocks"
  add_foreign_key "groups", "units"
  add_foreign_key "loss_summaries", "periods"
  add_foreign_key "loss_summaries", "zones"
  add_foreign_key "main_meter_readings", "main_meters"
  add_foreign_key "main_meter_readings", "periods"
  add_foreign_key "main_meters", "zones"
  add_foreign_key "meter_readings", "meters"
  add_foreign_key "meter_readings", "periods"
  add_foreign_key "meters", "contact_points"
  add_foreign_key "non_establishment_snapshots", "contact_points"
  add_foreign_key "non_establishment_snapshots", "periods"
  add_foreign_key "other_deductions", "contact_points"
  add_foreign_key "other_deductions", "periods"
  add_foreign_key "personnel_entries", "contact_points"
  add_foreign_key "personnel_entries", "periods"
  add_foreign_key "personnel_entries", "ranks"
  add_foreign_key "pump_allocations", "blocks"
  add_foreign_key "pump_allocations", "contact_points"
  add_foreign_key "pump_allocations", "contact_points", column: "pump_contact_point_id"
  add_foreign_key "pump_allocations", "groups"
  add_foreign_key "pump_allocations", "periods"
  add_foreign_key "pump_allocations", "units"
  add_foreign_key "pump_allocations", "zones"
  add_foreign_key "pump_station_charges", "contact_points"
  add_foreign_key "pump_station_charges", "contact_points", column: "pump_contact_point_id"
  add_foreign_key "pump_station_charges", "periods"
  add_foreign_key "pump_station_charges", "zones"
  add_foreign_key "ranks", "periods"
  add_foreign_key "unit_configs", "periods"
  add_foreign_key "unit_configs", "units"
  add_foreign_key "units", "zones"
  add_foreign_key "users", "units"
  add_foreign_key "zones", "units", column: "manager_unit_id"
end
