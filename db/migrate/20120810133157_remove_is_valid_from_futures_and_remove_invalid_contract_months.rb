class RemoveIsValidFromFuturesAndRemoveInvalidContractMonths < ActiveRecord::Migration
  def up
    remove_column :futures, :is_valid
    drop_table :invalid_contract_months
  end

  def down
    add_column :futures, :is_valid, :boolean
    create_table :invalid_contract_months do |t|
      t.integer :asset_id
      t.string :month
    end
  end
end
