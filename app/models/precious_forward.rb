class PreciousForward < ActiveRecord::Base
  attr_accessible :metal_dataset_id,:date,:gofo1,:gofo2,:gofo3,:gofo6,:gofo12,:libor1,:libor2,:libor3,:libor6,:libor12
  belongs_to :metal_dataset
end