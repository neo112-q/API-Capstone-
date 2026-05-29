class AddLanguageToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :language, :string, default: 'th'
    add_index :novels, :language
  end
end
