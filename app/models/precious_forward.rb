class PreciousForward < ActiveRecord::Base
  #the columns are poorly named here, but the gofo's are used as general "forward rates" for either gold or silver
  #and the libor columns are used to mean "libor rate minus forward rate"
  attr_accessible :metal_dataset, :date,:gofo1,:gofo2,:gofo3,:gofo6,:gofo12,:libor1,:libor2,:libor3,:libor6,:libor12
  belongs_to :metal_dataset
end