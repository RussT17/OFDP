class RemoveFuturesChoices < ActiveRecord::Migration
  def up
    drop_table :futures_choices
  end

  def down
    create_table :futures_choices do |t|
      t.string :choice
      t.string :field_type
    end
  end
end
