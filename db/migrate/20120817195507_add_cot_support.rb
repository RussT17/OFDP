class AddCotSupport < ActiveRecord::Migration
  def up
    create_table :cots do |t|
      t.string :name
      t.string :desc
      t.boolean :legacy
    end
    
    create_table :cot_data_rows do |t|
      t.integer :cot_id
      t.date :date
      t.string :data
    end
  end

  def down
    drop_table :cots
    drop_table :cot_data_rows
  end
end
