class AddRevampedFuturesTables < ActiveRecord::Migration
  def change
    create_table :assets do |t|
      t.string :symbol
      t.string :exchange
      t.string :name
    end
    
    create_table :futures do |t|
      t.integer :asset_id
      t.string :month
      t.integer :year
    end
    
    create_table :future_data_rows do |t|
      t.integer :future_id
      t.date :date
      t.float :open
      t.float :high
      t.float :low
      t.float :settle
      t.integer :volume
      t.integer :interest
      t.integer :front_rank
    end
  end
end
