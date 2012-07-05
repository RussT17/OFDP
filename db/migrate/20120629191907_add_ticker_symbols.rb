class AddTickerSymbols < ActiveRecord::Migration
  def up
    create_table :ticker_symbols do |t|
      t.string :exchange
      t.string :symbol
      t.string :name
    end
  end

  def down
    drop_table :ticker_symbols
  end
end
