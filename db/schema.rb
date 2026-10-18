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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_112827) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "department_memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_department_memberships_on_department_id"
    t.index ["user_id", "department_id"], name: "index_department_memberships_on_user_id_and_department_id", unique: true
    t.index ["user_id"], name: "index_department_memberships_on_user_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.integer "parent_id"
    t.integer "manager_id"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_departments_on_code", unique: true
    t.index ["manager_id"], name: "index_departments_on_manager_id"
    t.index ["name"], name: "index_departments_on_name", unique: true
    t.index ["parent_id"], name: "index_departments_on_parent_id"
  end

  create_table "documents", force: :cascade do |t|
    t.integer "equipment_id"
    t.integer "equipment_model_id"
    t.integer "uploaded_by_id"
    t.integer "supersedes_id"
    t.string "document_type", default: "other", null: false
    t.string "title", null: false
    t.integer "version_number", default: 1, null: false
    t.string "version_label"
    t.date "valid_until"
    t.text "notes"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_documents_on_equipment_id"
    t.index ["equipment_model_id"], name: "index_documents_on_equipment_model_id"
    t.index ["supersedes_id"], name: "index_documents_on_supersedes_id", unique: true
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
  end

  create_table "equipment_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "code_prefix", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_prefix"], name: "index_equipment_categories_on_code_prefix", unique: true
    t.index ["name"], name: "index_equipment_categories_on_name", unique: true
  end

  create_table "equipment_code_counters", force: :cascade do |t|
    t.integer "category_id", null: false
    t.integer "manufacturer_id", null: false
    t.integer "last_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "manufacturer_id"], name: "idx_on_category_id_manufacturer_id_6c6dbb9b4e", unique: true
    t.index ["category_id"], name: "index_equipment_code_counters_on_category_id"
    t.index ["manufacturer_id"], name: "index_equipment_code_counters_on_manufacturer_id"
  end

  create_table "equipment_models", force: :cascade do |t|
    t.integer "manufacturer_id", null: false
    t.integer "category_id", null: false
    t.string "name", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_equipment_models_on_category_id"
    t.index ["manufacturer_id", "name"], name: "index_equipment_models_on_manufacturer_id_and_name", unique: true
    t.index ["manufacturer_id"], name: "index_equipment_models_on_manufacturer_id"
  end

  create_table "equipment_moves", force: :cascade do |t|
    t.integer "equipment_id", null: false
    t.integer "from_location_id"
    t.integer "to_location_id", null: false
    t.integer "user_id"
    t.datetime "moved_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_equipment_moves_on_equipment_id"
    t.index ["from_location_id"], name: "index_equipment_moves_on_from_location_id"
    t.index ["to_location_id"], name: "index_equipment_moves_on_to_location_id"
    t.index ["user_id"], name: "index_equipment_moves_on_user_id"
  end

  create_table "equipments", force: :cascade do |t|
    t.string "code", null: false
    t.string "serial_number"
    t.integer "equipment_model_id", null: false
    t.integer "location_id", null: false
    t.string "status", default: "in_service", null: false
    t.string "criticality", default: "medium", null: false
    t.date "acquired_on"
    t.date "commissioned_on"
    t.date "warranty_ends_on"
    t.date "decommissioned_on"
    t.text "notes"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_equipments_on_code", unique: true
    t.index ["equipment_model_id", "serial_number"], name: "index_equipments_on_equipment_model_id_and_serial_number", unique: true
    t.index ["equipment_model_id"], name: "index_equipments_on_equipment_model_id"
    t.index ["location_id"], name: "index_equipments_on_location_id"
    t.index ["status"], name: "index_equipments_on_status"
  end

  create_table "events", force: :cascade do |t|
    t.integer "equipment_id", null: false
    t.integer "incident_id"
    t.integer "performed_by_id"
    t.string "event_type", default: "corrective", null: false
    t.string "status", default: "planned", null: false
    t.string "title", null: false
    t.date "scheduled_on"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "contractor"
    t.integer "cost_cents"
    t.integer "downtime_minutes"
    t.text "report"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_events_on_equipment_id"
    t.index ["incident_id"], name: "index_events_on_incident_id"
    t.index ["performed_by_id"], name: "index_events_on_performed_by_id"
    t.index ["scheduled_on"], name: "index_events_on_scheduled_on"
    t.index ["status"], name: "index_events_on_status"
  end

  create_table "incident_status_changes", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.integer "user_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_incident_status_changes_on_incident_id"
    t.index ["user_id"], name: "index_incident_status_changes_on_user_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.integer "equipment_id", null: false
    t.integer "reported_by_id", null: false
    t.integer "assigned_to_id"
    t.string "severity", default: "minor", null: false
    t.string "nature", default: "technical", null: false
    t.string "status", default: "declared", null: false
    t.text "description", null: false
    t.datetime "detected_at", null: false
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.text "root_cause"
    t.text "corrective_action"
    t.boolean "mandatory_declaration", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_incidents_on_assigned_to_id"
    t.index ["equipment_id"], name: "index_incidents_on_equipment_id"
    t.index ["reported_by_id"], name: "index_incidents_on_reported_by_id"
    t.index ["severity"], name: "index_incidents_on_severity"
    t.index ["status"], name: "index_incidents_on_status"
  end

  create_table "locations", force: :cascade do |t|
    t.integer "department_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.integer "referent_id"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id", "code"], name: "index_locations_on_department_id_and_code", unique: true
    t.index ["department_id"], name: "index_locations_on_department_id"
    t.index ["referent_id"], name: "index_locations_on_referent_id"
  end

  create_table "manufacturers", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_manufacturers_on_code", unique: true
    t.index ["name"], name: "index_manufacturers_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "reporter", null: false
    t.date "valid_until"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["valid_until"], name: "index_users_on_valid_until"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object", limit: 1073741823
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "department_memberships", "departments"
  add_foreign_key "department_memberships", "users"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "users", column: "manager_id"
  add_foreign_key "documents", "documents", column: "supersedes_id"
  add_foreign_key "documents", "equipment_models"
  add_foreign_key "documents", "equipments"
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "equipment_code_counters", "equipment_categories", column: "category_id"
  add_foreign_key "equipment_code_counters", "manufacturers"
  add_foreign_key "equipment_models", "equipment_categories", column: "category_id"
  add_foreign_key "equipment_models", "manufacturers"
  add_foreign_key "equipment_moves", "equipments"
  add_foreign_key "equipment_moves", "locations", column: "from_location_id"
  add_foreign_key "equipment_moves", "locations", column: "to_location_id"
  add_foreign_key "equipment_moves", "users"
  add_foreign_key "equipments", "equipment_models"
  add_foreign_key "equipments", "locations"
  add_foreign_key "events", "equipments"
  add_foreign_key "events", "incidents"
  add_foreign_key "events", "users", column: "performed_by_id"
  add_foreign_key "incident_status_changes", "incidents"
  add_foreign_key "incident_status_changes", "users"
  add_foreign_key "incidents", "equipments"
  add_foreign_key "incidents", "users", column: "assigned_to_id"
  add_foreign_key "incidents", "users", column: "reported_by_id"
  add_foreign_key "locations", "departments"
  add_foreign_key "locations", "users", column: "referent_id"
  add_foreign_key "sessions", "users"
end
