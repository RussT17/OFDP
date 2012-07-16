class AddCfcs < ActiveRecord::Migration
  def up
    create_table :cfcs do |t|
      t.integer :asset_id
      t.integer :depth
    end
    
    remove_column :future_data_rows, :front_rank
    add_column :future_data_rows, :cfc_id, :integer
  end

  def down
    drop_table :cfcs
    add_column :future_data_rows, :front_rank, :integer
    remove_column :future_data_rows, :cfc_id
  end
end
