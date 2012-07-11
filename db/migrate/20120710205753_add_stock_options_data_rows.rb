class AddStockOptionsDataRows < ActiveRecord::Migration
  def change
    create_table :stock_options do |t|
      t.integer :stock_id
      t.date :expiry_date
      t.boolean :is_call
      t.float :strike_price
      t.string :symbol
    end
    
    create_table :stock_option_data_rows do |t|
      t.integer :stock_option_id
      t.date :date
      t.float :last_trade_price
      t.float :change
      t.float :bid
      t.float :ask
      t.integer :volume
      t.integer :open_interest
    end
  end
end
