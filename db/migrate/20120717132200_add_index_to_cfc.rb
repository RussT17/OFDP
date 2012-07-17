class AddIndexToCfc < ActiveRecord::Migration
  def change
    add_index :future_data_rows, :date
  end
end
