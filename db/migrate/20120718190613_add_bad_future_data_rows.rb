class AddBadFutureDataRows < ActiveRecord::Migration
  def up
    create_table :bad_future_data_rows do |t|
      t.string :exchange
      t.string :symbol
      t.integer :year
      t.string :month
      t.date :date
      t.float :open
      t.float :high
      t.float :low
      t.float :settle
      t.float :volume
      t.float :interest
    end
  end

  def down
    drop_table :bad_future_data_rows
  end
end
