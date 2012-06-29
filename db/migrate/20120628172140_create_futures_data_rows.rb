class CreateFuturesDataRows < ActiveRecord::Migration
  def change
    create_table :futures_data_rows do |t|
      t.date :dt
      t.string :exchange
      t.string :ticker
      t.string :month
      t.integer :year
      t.float :open
      t.float :high
      t.float :low
      t.float :settle
      t.float :volume
      t.float :interest
    end
  end
end
