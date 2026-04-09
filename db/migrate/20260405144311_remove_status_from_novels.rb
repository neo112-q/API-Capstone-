class RemoveStatusFromNovels < ActiveRecord::Migration[8.1]
  def change
    remove_column :novels, :status, :string
  end
end
