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

ActiveRecord::Schema[8.1].define(version: 2026_04_16_135635) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chapters", primary_key: ["novel_id", "chapter_no"], force: :cascade do |t|
    t.integer "chapter_no", null: false
    t.datetime "created_at", null: false
    t.integer "novel_id", null: false
    t.integer "price", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
  end

  create_table "follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "novel_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["novel_id"], name: "index_follows_on_novel_id"
    t.index ["user_id", "novel_id"], name: "index_follows_on_user_id_and_novel_id", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "genres", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "likeable_id", null: false
    t.string "likeable_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable"
    t.index ["user_id", "likeable_id", "likeable_type"], name: "index_likes_on_user_id_and_likeable_id_and_likeable_type", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "novel_genres", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "genre_id", null: false
    t.bigint "novel_id", null: false
    t.datetime "updated_at", null: false
    t.index ["genre_id"], name: "index_novel_genres_on_genre_id"
    t.index ["novel_id"], name: "index_novel_genres_on_novel_id"
  end

  create_table "novel_tfidf_vectors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "novel_id", null: false
    t.integer "partition_no", null: false
    t.halfvec "tf_idf", limit: 300, null: false
    t.datetime "updated_at", null: false
    t.index ["novel_id"], name: "index_novel_tfidf_vectors_on_novel_id"
    t.index ["tf_idf"], name: "index_novel_tfidf_vectors_on_tf_idf", opclass: :halfvec_cosine_ops, using: :hnsw
  end

  create_table "novels", force: :cascade do |t|
    t.string "cover_path"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_premium", default: false
    t.string "pen_name"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.integer "status", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "view_count", default: 0
    t.index ["user_id"], name: "index_novels_on_user_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.decimal "author_revenue", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "novel_id", null: false
    t.decimal "platform_fee", precision: 10, scale: 2, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["novel_id"], name: "index_purchases_on_novel_id"
    t.index ["user_id"], name: "index_purchases_on_user_id"
  end

  create_table "unlocked_chapters", force: :cascade do |t|
    t.bigint "chapter_id", null: false
    t.datetime "created_at", null: false
    t.decimal "price_paid", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["chapter_id"], name: "index_unlocked_chapters_on_chapter_id"
    t.index ["user_id", "chapter_id"], name: "index_unlocked_chapters_on_user_id_and_chapter_id", unique: true
    t.index ["user_id"], name: "index_unlocked_chapters_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_path"
    t.text "bio"
    t.integer "coin_balance", default: 0
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.string "pen_name"
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.string "username"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chapters", "novels"
  add_foreign_key "follows", "novels"
  add_foreign_key "follows", "users"
  add_foreign_key "likes", "users"
  add_foreign_key "novel_genres", "genres"
  add_foreign_key "novel_genres", "novels"
  add_foreign_key "novel_tfidf_vectors", "novels", on_delete: :cascade
  add_foreign_key "novels", "users"
  add_foreign_key "purchases", "novels"
  add_foreign_key "purchases", "users"
  add_foreign_key "unlocked_chapters", "users"
end
