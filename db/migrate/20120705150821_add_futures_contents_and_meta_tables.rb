class AddFuturesContentsAndMetaTables < ActiveRecord::Migration
  def up
    create_table :futures_contents do |t|
      t.string :ticker
      t.string :exchange
      t.string :year
      t.string :month
    end
    
    create_table :futures_choices do |t|
      t.string :choice
      t.string :field_type
    end
  end

  def down
    drop_table :futures_contents
    drop_table :futures_choices
  end
end
