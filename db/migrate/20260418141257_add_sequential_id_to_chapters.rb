class AddSequentialIdToChapters < ActiveRecord::Migration[8.1]
  def change
    # เพิ่ม seq_id column
    add_column :chapters, :seq_id, :bigint
    
    # รีเซ็ต sequence และ update ค่า
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE SEQUENCE IF NOT EXISTS chapters_seq_id_seq;
          ALTER TABLE chapters ALTER COLUMN seq_id SET DEFAULT nextval('chapters_seq_id_seq');
          UPDATE chapters SET seq_id = nextval('chapters_seq_id_seq');
          ALTER TABLE chapters ALTER COLUMN seq_id SET NOT NULL;
          CREATE UNIQUE INDEX index_chapters_on_seq_id ON chapters(seq_id);
        SQL
      end
    end
  end
end