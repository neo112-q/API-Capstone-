class CreateNovelTfidfVectors < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :novel_tfidf_vectors do |t|
      t.column :tf_idf, "halfvec(300)", null: false 
      
      t.references :novel, null: false, foreign_key: { on_delete: :cascade }
      t.integer :partition_no, null: false
      t.timestamps
    end

    add_index :novel_tfidf_vectors, :tf_idf, using: :hnsw, opclass: :halfvec_cosine_ops
  end
end