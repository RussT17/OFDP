class DropOldFuturesTables < ActiveRecord::Migration
  def up
    drop_table :futures_contents
    drop_table :futures_data_rows
    drop_table :ticker_symbols
  end

  def down
    create_table :futures_data_rows do |t|
      t.date :dt
      t.string :exchange
      t.string :ticker
      t.string :month
      t.string :year
      t.float :open
      t.float :high
      t.float :low
      t.float :settle
      t.float :volume
      t.float :interest
    end
    
    add_index :futures_data_rows, :exchange
    add_index :futures_data_rows, :ticker
    add_index :futures_data_rows, :year
    add_index :futures_data_rows, :month
    
    create_table :futures_contents do |t|
      t.string :ticker
      t.string :exchange
      t.string :year
      t.string :month
    end
    
    create_table :ticker_symbols do |t|
      t.string :exchange
      t.string :symbol
      t.string :name
    end
  end
end
