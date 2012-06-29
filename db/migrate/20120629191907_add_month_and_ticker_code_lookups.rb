class AddMonthAndTickerCodeLookups < ActiveRecord::Migration
  def up
    create_table :month_codes, :id => false do |t|
      t.string :code
      t.string :month
    end
    
    create_table :ticker_symbols, :id => false do |t|
      t.string :exchange
      t.string :symbol
      t.string :name
    end
  end

  def down
    drop_table :month_codes
    drop_table :ticker_symbols
  end
end
