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

ActiveRecord::Schema[8.1].define(version: 2026_05_13_023947) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contact_point_group_memberships", force: :cascade do |t|
    t.bigint "contact_point_group_id", null: false
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_group_id", "contact_point_id"], name: "idx_cpg_memberships_on_group_and_cp", unique: true
    t.index ["contact_point_group_id"], name: "idx_on_contact_point_group_id_1c884f5aab"
    t.index ["contact_point_id"], name: "index_contact_point_group_memberships_on_contact_point_id"
  end

  create_table "contact_point_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_contact_point_groups_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_contact_point_groups_on_organization_id"
  end

  create_table "contact_point_other_deductions", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.bigint "monthly_period_id", null: false
    t.integer "other_type", default: 0, null: false
    t.decimal "other_value", precision: 12, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_point_id", "monthly_period_id"], name: "idx_cp_other_deductions_on_cp_and_period", unique: true
    t.index ["contact_point_id"], name: "index_contact_point_other_deductions_on_contact_point_id"
    t.index ["monthly_period_id"], name: "index_contact_point_other_deductions_on_monthly_period_id"
  end

  create_table "contact_points", force: :cascade do |t|
    t.integer "contact_point_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "group_name"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["contact_point_type"], name: "index_contact_points_on_contact_point_type"
    t.index ["organization_id", "name"], name: "index_contact_points_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_contact_points_on_organization_id"
  end

  create_table "main_meter_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "electricity_supply_kw", precision: 12, scale: 2, null: false
    t.bigint "main_meter_id", null: false
    t.bigint "monthly_period_id", null: false
    t.datetime "updated_at", null: false
    t.index ["main_meter_id", "monthly_period_id"], name: "idx_main_meter_readings_on_meter_and_period", unique: true
    t.index ["main_meter_id"], name: "index_main_meter_readings_on_main_meter_id"
    t.index ["monthly_period_id"], name: "index_main_meter_readings_on_monthly_period_id"
  end

  create_table "main_meters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["name"], name: "index_main_meters_on_name", unique: true
    t.index ["zone_id"], name: "index_main_meters_on_zone_id"
  end

  create_table "meter_readings", force: :cascade do |t|
    t.decimal "consumption", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.bigint "meter_id", null: false
    t.bigint "monthly_period_id", null: false
    t.decimal "reading_end", precision: 12, scale: 2
    t.decimal "reading_start", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.index ["meter_id", "monthly_period_id"], name: "idx_meter_readings_on_meter_and_period", unique: true
    t.index ["meter_id"], name: "index_meter_readings_on_meter_id"
    t.index ["monthly_period_id"], name: "index_meter_readings_on_monthly_period_id"
  end

  create_table "meters", force: :cascade do |t|
    t.bigint "contact_point_id"
    t.datetime "created_at", null: false
    t.integer "meter_type", default: 0, null: false
    t.string "name", null: false
    t.boolean "no_loss", default: false, null: false
    t.text "notes"
    t.bigint "organization_id", null: false
    t.integer "position", default: 0
    t.bigint "pump_station_id"
    t.string "serial_number"
    t.datetime "updated_at", null: false
    t.index ["contact_point_id"], name: "index_meters_on_contact_point_id"
    t.index ["meter_type"], name: "index_meters_on_meter_type"
    t.index ["organization_id"], name: "index_meters_on_organization_id"
    t.index ["pump_station_id"], name: "index_meters_on_pump_station_id"
    t.index ["serial_number"], name: "index_meters_on_serial_number"
  end

  create_table "monthly_calculations", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.decimal "division_public_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "loss_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "meter_usage_kw", precision: 12, scale: 2, default: "0.0"
    t.bigint "monthly_period_id", null: false
    t.text "notes"
    t.decimal "other_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "over_under_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank1_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank2_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank3_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank4_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank5_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank6_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "rank7_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "remaining_standard_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "savings_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.integer "total_personnel", default: 0, null: false
    t.decimal "total_standard_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_usage_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "unit_price", precision: 12, scale: 2, default: "0.0"
    t.decimal "unit_public_deduction_kw", precision: 12, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.decimal "water_pump_actual_kw", precision: 12, scale: 2, default: "0.0"
    t.decimal "water_pump_standard_kw", precision: 12, scale: 2, default: "0.0"
    t.index ["contact_point_id", "monthly_period_id"], name: "idx_monthly_calcs_on_contact_point_and_period", unique: true
    t.index ["contact_point_id"], name: "index_monthly_calculations_on_contact_point_id"
    t.index ["monthly_period_id"], name: "index_monthly_calculations_on_monthly_period_id"
  end

  create_table "monthly_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "locked", default: false, null: false
    t.datetime "locked_at"
    t.bigint "locked_by_id"
    t.integer "month", null: false
    t.decimal "unit_price", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["locked_by_id"], name: "index_monthly_periods_on_locked_by_id"
    t.index ["year", "month"], name: "index_monthly_periods_on_year_and_month", unique: true
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "level", default: 2, null: false
    t.bigint "main_meter_id"
    t.string "name", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.bigint "zone_id"
    t.index ["level", "name"], name: "index_organizations_on_level_and_name", unique: true
    t.index ["level"], name: "index_organizations_on_level"
    t.index ["main_meter_id"], name: "index_organizations_on_main_meter_id"
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
    t.index ["zone_id"], name: "index_organizations_on_zone_id"
  end

  create_table "personnel", force: :cascade do |t|
    t.bigint "contact_point_id", null: false
    t.datetime "created_at", null: false
    t.bigint "monthly_period_id", null: false
    t.integer "rank1_count", default: 0, null: false
    t.integer "rank2_count", default: 0, null: false
    t.integer "rank3_count", default: 0, null: false
    t.integer "rank4_count", default: 0, null: false
    t.integer "rank5_count", default: 0, null: false
    t.integer "rank6_count", default: 0, null: false
    t.integer "rank7_count", default: 0, null: false
    t.datetime "reviewed_at"
    t.datetime "updated_at", null: false
    t.index ["contact_point_id", "monthly_period_id"], name: "idx_personnel_on_contact_point_and_period", unique: true
    t.index ["contact_point_id"], name: "index_personnel_on_contact_point_id"
    t.index ["monthly_period_id"], name: "index_personnel_on_monthly_period_id"
  end

  create_table "pump_station_assignments", force: :cascade do |t|
    t.bigint "assignable_id", null: false
    t.string "assignable_type", null: false
    t.datetime "created_at", null: false
    t.decimal "fixed_pump_percentage", precision: 5, scale: 2
    t.bigint "pump_station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pump_station_id", "assignable_type", "assignable_id"], name: "idx_pump_assignments_on_station_and_assignable", unique: true
    t.index ["pump_station_id"], name: "index_pump_station_assignments_on_pump_station_id"
  end

  create_table "pump_stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["organization_id"], name: "index_pump_stations_on_organization_id"
    t.index ["zone_id"], name: "index_pump_stations_on_zone_id"
  end

  create_table "rank_quotas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "quota_kw", precision: 10, scale: 2, null: false
    t.integer "rank_group", null: false
    t.string "rank_name", null: false
    t.datetime "updated_at", null: false
    t.index ["rank_group"], name: "index_rank_quotas_on_rank_group", unique: true
  end

  create_table "unit_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "division_public_rate", precision: 5, scale: 4
    t.bigint "monthly_period_id", null: false
    t.bigint "organization_id", null: false
    t.integer "other_deduction_type", default: 0
    t.decimal "other_deduction_value", precision: 12, scale: 4, default: "0.0"
    t.decimal "savings_rate", precision: 5, scale: 4
    t.decimal "unit_public_rate", precision: 5, scale: 4
    t.datetime "updated_at", null: false
    t.index ["monthly_period_id"], name: "index_unit_configs_on_monthly_period_id"
    t.index ["organization_id", "monthly_period_id"], name: "idx_unit_configs_on_org_and_period", unique: true
    t.index ["organization_id"], name: "index_unit_configs_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "force_password_change", default: true, null: false
    t.string "full_name", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.bigint "organization_id", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 1, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  create_table "work_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.bigint "owner_organization_id", null: false
    t.integer "personnel_count", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_organization_id", "name"], name: "idx_work_groups_on_owner_and_name", unique: true
    t.index ["owner_organization_id"], name: "index_work_groups_on_owner_organization_id"
  end

  create_table "zones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "manager_organization_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["manager_organization_id"], name: "index_zones_on_manager_organization_id"
    t.index ["name"], name: "index_zones_on_name", unique: true
  end

  add_foreign_key "contact_point_group_memberships", "contact_point_groups"
  add_foreign_key "contact_point_group_memberships", "contact_points"
  add_foreign_key "contact_point_groups", "organizations"
  add_foreign_key "contact_point_other_deductions", "contact_points"
  add_foreign_key "contact_point_other_deductions", "monthly_periods"
  add_foreign_key "contact_points", "organizations"
  add_foreign_key "main_meter_readings", "main_meters"
  add_foreign_key "main_meter_readings", "monthly_periods"
  add_foreign_key "main_meters", "zones"
  add_foreign_key "meter_readings", "meters"
  add_foreign_key "meter_readings", "monthly_periods"
  add_foreign_key "meters", "contact_points"
  add_foreign_key "meters", "organizations"
  add_foreign_key "meters", "pump_stations"
  add_foreign_key "monthly_calculations", "contact_points"
  add_foreign_key "monthly_calculations", "monthly_periods"
  add_foreign_key "monthly_periods", "users", column: "locked_by_id"
  add_foreign_key "organizations", "main_meters"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "organizations", "zones"
  add_foreign_key "personnel", "contact_points"
  add_foreign_key "personnel", "monthly_periods"
  add_foreign_key "pump_station_assignments", "pump_stations"
  add_foreign_key "pump_stations", "organizations"
  add_foreign_key "pump_stations", "zones"
  add_foreign_key "unit_configs", "monthly_periods"
  add_foreign_key "unit_configs", "organizations"
  add_foreign_key "users", "organizations"
  add_foreign_key "work_groups", "organizations", column: "owner_organization_id"
  add_foreign_key "zones", "organizations", column: "manager_organization_id"
end
