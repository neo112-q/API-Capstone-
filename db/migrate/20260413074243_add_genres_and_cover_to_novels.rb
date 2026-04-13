class AddGenresAndCoverToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column(:novels, :genres, :string, array: true, default: [])
    add_column(:novels, :cover_path, :string)
  end
end