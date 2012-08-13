class RemoveIsValidFromFutures < ActiveRecord::Migration
  def up
    remove_column :futures, :is_valid
  end

  def down
    add_column :futures, :is_valid, :boolean
  end
end
