class AddIndexSupport < ActiveRecord::Migration
  def up
    create_table :indices do |t|
      t.string :name
    end
    
    create_table :index_data_rows do |t|
      t.integer :index_id
      t.date :date
      t.float :value
    end
  end

  def down
    drop_table :indexes
    drop_table :index_data_rows
  end
end
