class RemoveMeanFromNonPrecPrices < ActiveRecord::Migration
  def up
    remove_column :non_prec_prices, :mean
  end

  def down
    add_column :non_prec_prices, :mean, :float
  end
end
