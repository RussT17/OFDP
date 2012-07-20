class AddDataPathToMetals < ActiveRecord::Migration
  def change
    add_column :metals, :data_path, :string
  end
end
