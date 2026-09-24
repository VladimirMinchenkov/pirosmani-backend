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

ActiveRecord::Schema[7.0].define(version: 2026_09_25_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "addon_groups", force: :cascade do |t|
    t.string "name", null: false
    t.integer "min_selection", default: 0, null: false
    t.integer "max_selection"
    t.boolean "required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_addon_groups_on_name", unique: true
  end

  create_table "addons", force: :cascade do |t|
    t.bigint "addon_group_id", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addon_group_id"], name: "index_addons_on_addon_group_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token"
    t.index ["access_token"], name: "index_admin_users_on_access_token", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "archived_carts", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.jsonb "data"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_archived_carts_on_client_id"
  end

  create_table "bonus_transactions", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "order_id"
    t.string "kind", null: false
    t.integer "amount", null: false
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "created_at"], name: "index_bonus_transactions_on_client_id_and_created_at"
    t.index ["client_id"], name: "index_bonus_transactions_on_client_id"
    t.index ["kind"], name: "index_bonus_transactions_on_kind"
    t.index ["order_id"], name: "index_bonus_transactions_on_order_id"
  end

  create_table "cart_item_addons", force: :cascade do |t|
    t.bigint "cart_item_id", null: false
    t.bigint "addon_id"
    t.string "addon_name", null: false
    t.decimal "addon_price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addon_id"], name: "index_cart_item_addons_on_addon_id"
    t.index ["cart_item_id"], name: "index_cart_item_addons_on_cart_item_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "menu_item_id"
    t.index ["cart_id", "menu_item_id"], name: "idx_cart_items_cart_menu_item_unique", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "client_id"
    t.string "session_id"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "status"], name: "index_carts_on_client_id_and_status"
    t.index ["client_id"], name: "index_carts_on_client_id"
    t.index ["session_id"], name: "index_carts_on_session_id"
    t.check_constraint "client_id IS NOT NULL AND session_id IS NULL OR client_id IS NULL AND session_id IS NOT NULL", name: "chk_carts_client_or_session"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url"
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "client_addresses", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "label"
    t.string "emoji"
    t.string "street", null: false
    t.string "entrance"
    t.string "apt"
    t.string "floor"
    t.string "intercom"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_addresses_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "phone"
    t.datetime "phone_verified_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "bonus_points", default: 0, null: false
    t.index ["phone"], name: "index_clients_on_phone", unique: true
  end

  create_table "combo_items", force: :cascade do |t|
    t.bigint "combo_id", null: false
    t.bigint "menu_item_id", null: false
    t.integer "quantity", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["combo_id"], name: "index_combo_items_on_combo_id"
    t.index ["menu_item_id"], name: "index_combo_items_on_menu_item_id"
  end

  create_table "combos", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "image_url"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delivery_zones", force: :cascade do |t|
    t.string "name"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "coordinates", default: []
    t.decimal "price"
  end

  create_table "menu_item_addon_groups", force: :cascade do |t|
    t.bigint "menu_item_id", null: false
    t.bigint "addon_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addon_group_id"], name: "index_menu_item_addon_groups_on_addon_group_id"
    t.index ["menu_item_id", "addon_group_id"], name: "idx_menu_item_addon_groups_unique", unique: true
    t.index ["menu_item_id"], name: "index_menu_item_addon_groups_on_menu_item_id"
  end

  create_table "menu_item_groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.integer "position_in_category", default: 0, null: false
    t.integer "min_total_quantity"
    t.text "description"
    t.string "image_url"
    t.boolean "available", default: true, null: false
    t.index ["category_id", "position_in_category"], name: "idx_menu_item_groups_cat_pos_unique", unique: true
    t.index ["name"], name: "index_menu_item_groups_on_name", unique: true
    t.index ["slug"], name: "index_menu_item_groups_on_slug", unique: true
  end

  create_table "menu_item_tags", force: :cascade do |t|
    t.bigint "menu_item_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_item_id", "tag_id"], name: "idx_menu_item_tags_unique", unique: true
    t.index ["menu_item_id"], name: "index_menu_item_tags_on_menu_item_id"
    t.index ["tag_id"], name: "index_menu_item_tags_on_tag_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.string "image_url"
    t.boolean "available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.bigint "menu_item_group_id"
    t.string "weight_label"
    t.integer "calories"
    t.jsonb "allergens", default: [], null: false
    t.string "sku"
    t.integer "position", default: 0, null: false
    t.integer "position_in_category"
    t.integer "position_in_group"
    t.index ["category_id", "position_in_category"], name: "idx_menu_items_cat_pos_unique", unique: true, where: "(menu_item_group_id IS NULL)"
    t.index ["category_id"], name: "index_menu_items_on_category_id"
    t.index ["menu_item_group_id", "position_in_group"], name: "idx_menu_items_group_pos_unique", unique: true, where: "(menu_item_group_id IS NOT NULL)"
    t.index ["menu_item_group_id"], name: "index_menu_items_on_menu_item_group_id"
    t.index ["position"], name: "index_menu_items_on_position"
    t.index ["sku"], name: "index_menu_items_on_sku", unique: true
  end

  create_table "order_item_addons", force: :cascade do |t|
    t.bigint "order_item_id", null: false
    t.bigint "addon_id"
    t.string "addon_name", null: false
    t.decimal "addon_price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addon_id"], name: "index_order_item_addons_on_addon_id"
    t.index ["order_item_id"], name: "index_order_item_addons_on_order_item_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "menu_item_id"
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "combo_id"
    t.index ["combo_id"], name: "index_order_items_on_combo_id"
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.check_constraint "menu_item_id IS NOT NULL AND combo_id IS NULL OR menu_item_id IS NULL AND combo_id IS NOT NULL", name: "order_items_menu_item_xor_combo"
  end

  create_table "order_promotions", force: :cascade do |t|
    t.decimal "min_amount", precision: 10, scale: 2, null: false
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_order_promotions_on_active"
  end

  create_table "orders", force: :cascade do |t|
    t.string "status"
    t.string "address"
    t.decimal "total_price"
    t.decimal "delivery_price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "client_id", null: false
    t.string "order_type", default: "delivery", null: false
    t.datetime "scheduled_at"
    t.bigint "client_address_id"
    t.bigint "delivery_zone_id"
    t.bigint "promo_code_id"
    t.integer "bonus_points_used", default: 0, null: false
    t.index ["client_address_id"], name: "index_orders_on_client_address_id"
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["delivery_zone_id"], name: "index_orders_on_delivery_zone_id"
    t.index ["promo_code_id"], name: "index_orders_on_promo_code_id"
  end

  create_table "otp_codes", force: :cascade do |t|
    t.string "phone", null: false
    t.string "code", null: false
    t.datetime "verified_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_otp_codes_on_expires_at"
    t.index ["phone", "code"], name: "index_otp_codes_on_phone_and_code", unique: true
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "discount_type", default: "fixed", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.decimal "min_order_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "active_from"
    t.datetime "active_until"
    t.integer "usage_limit"
    t.integer "usage_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "menu_item_id", null: false
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_promotions_on_active"
    t.index ["menu_item_id"], name: "index_promotions_on_menu_item_id"
    t.index ["menu_item_id"], name: "index_promotions_on_menu_item_id_unique", unique: true
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "token"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_refresh_tokens_on_client_id"
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color"
    t.string "emoji"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addons", "addon_groups"
  add_foreign_key "archived_carts", "clients"
  add_foreign_key "bonus_transactions", "clients"
  add_foreign_key "bonus_transactions", "orders"
  add_foreign_key "cart_item_addons", "addons"
  add_foreign_key "cart_item_addons", "cart_items"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "menu_items"
  add_foreign_key "carts", "clients"
  add_foreign_key "client_addresses", "clients"
  add_foreign_key "combo_items", "combos"
  add_foreign_key "combo_items", "menu_items"
  add_foreign_key "menu_item_addon_groups", "addon_groups"
  add_foreign_key "menu_item_addon_groups", "menu_items"
  add_foreign_key "menu_item_tags", "menu_items"
  add_foreign_key "menu_item_tags", "tags"
  add_foreign_key "menu_items", "categories"
  add_foreign_key "menu_items", "menu_item_groups"
  add_foreign_key "order_item_addons", "addons"
  add_foreign_key "order_item_addons", "order_items"
  add_foreign_key "order_items", "combos"
  add_foreign_key "order_items", "menu_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "client_addresses"
  add_foreign_key "orders", "clients"
  add_foreign_key "orders", "delivery_zones"
  add_foreign_key "orders", "promo_codes"
  add_foreign_key "promotions", "menu_items"
  add_foreign_key "refresh_tokens", "clients"
end
