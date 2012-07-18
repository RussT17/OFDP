class AddContractMonths < ActiveRecord::Migration
  def up
    create_table :invalid_contract_months do |t|
      t.integer :asset_id
      t.string :month
    end
  end

  def down
    drop_table :invalid_contract_months
  end
end
