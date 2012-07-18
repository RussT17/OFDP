class AddMetalDataInfrastructure < ActiveRecord::Migration
  def up
    create_table :metals do |t|
      t.string :name
      t.string :source
    end
    
    create_table :metal_datasets do |t|
      t.integer :metal_id
      t.string :table
      t.string :name
    end
    
    create_table :precious_fixings do |t|
      t.integer :metal_dataset_id
      t.date :date
      t.float :usd
      t.float :gbp
      t.float :eur
    end
    
    create_table :precious_forwards do |t|
      t.integer :metal_dataset_id
      t.date :date
      t.float :gofo1
      t.float :gofo2
      t.float :gofo3
      t.float :gofo6
      t.float :gofo12
      t.float :libor1
      t.float :libor2
      t.float :libor3
      t.float :libor6
      t.float :libor12
    end
    
    create_table :non_prec_prices do |t|
      t.integer :metal_dataset_id
      t.date :date
      t.float :buyer
      t.float :seller
      t.float :mean
    end
  end

  def down
    drop_table :metals
    drop_table :metal_datasets
    drop_table :precious_fixings
    drop_table :precious_forwards
    drop_table :non_prec_prices
  end
end
