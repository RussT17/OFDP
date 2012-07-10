class AddStocks < ActiveRecord::Migration
  def change
    create_table :stocks do |t|
      t.string :symbol
      t.string :name
      t.string :sector
      t.string :exchange
    end
  end
end
