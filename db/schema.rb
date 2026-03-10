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

ActiveRecord::Schema[8.1].define(version: 2026_03_10_204622) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "businesses", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "address"
    t.time "break_end_time"
    t.time "break_start_time"
    t.time "closing_time"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "logo_url"
    t.string "name", null: false
    t.time "opening_time"
    t.bigint "owner_id", null: false
    t.string "phone"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_businesses_on_owner_id"
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
  end

  create_table "employee_services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "service_id"], name: "index_employee_services_on_employee_id_and_service_id", unique: true
    t.index ["employee_id"], name: "index_employee_services_on_employee_id"
    t.index ["service_id"], name: "index_employee_services_on_service_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "avatar_url"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["business_id"], name: "index_employees_on_business_id"
    t.index ["user_id"], name: "index_employees_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.integer "notification_type", null: false
    t.boolean "read", default: false, null: false
    t.datetime "sent_at"
    t.bigint "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id"], name: "index_notifications_on_ticket_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_services_on_business_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "max_employees", default: 2, null: false
    t.integer "plan", default: 0, null: false
    t.decimal "price", precision: 10, scale: 2
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_subscriptions_on_business_id"
  end

  create_table "ticket_services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "service_id", null: false
    t.bigint "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_ticket_services_on_service_id"
    t.index ["ticket_id", "service_id"], name: "index_ticket_services_on_ticket_id_and_service_id", unique: true
    t.index ["ticket_id"], name: "index_ticket_services_on_ticket_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "client_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "employee_id"
    t.integer "estimated_time"
    t.boolean "paid", default: false, null: false
    t.integer "queue_position"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "ticket_number", null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "created_at"], name: "index_tickets_on_business_id_and_created_at"
    t.index ["business_id", "paid"], name: "index_tickets_on_business_id_and_paid"
    t.index ["business_id", "status"], name: "index_tickets_on_business_id_and_status"
    t.index ["business_id", "ticket_number"], name: "index_tickets_on_business_id_and_ticket_number", unique: true
    t.index ["business_id"], name: "index_tickets_on_business_id"
    t.index ["client_id"], name: "index_tickets_on_client_id"
    t.index ["employee_id"], name: "index_tickets_on_employee_id"
    t.index ["paid"], name: "index_tickets_on_paid"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "businesses", "users", column: "owner_id"
  add_foreign_key "employee_services", "employees"
  add_foreign_key "employee_services", "services"
  add_foreign_key "employees", "businesses"
  add_foreign_key "employees", "users"
  add_foreign_key "notifications", "tickets"
  add_foreign_key "notifications", "users"
  add_foreign_key "services", "businesses"
  add_foreign_key "subscriptions", "businesses"
  add_foreign_key "ticket_services", "services"
  add_foreign_key "ticket_services", "tickets"
  add_foreign_key "tickets", "businesses"
  add_foreign_key "tickets", "employees"
  add_foreign_key "tickets", "users", column: "client_id"
end
