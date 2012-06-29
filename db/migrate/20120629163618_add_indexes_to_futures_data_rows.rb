class AddIndexesToFuturesDataRows < ActiveRecord::Migration
  def change
    add_index :futures_data_rows, :exchange
    add_index :futures_data_rows, :ticker
    add_index :futures_data_rows, :year
    add_index :futures_data_rows, :month
  end
end
