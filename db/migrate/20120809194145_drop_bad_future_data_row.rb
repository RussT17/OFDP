class DropBadFutureDataRow < ActiveRecord::Migration
  def up
    drop_table :bad_future_data_rows
  end

  def down
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
end
