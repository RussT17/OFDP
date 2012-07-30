#The class that FutureEntry, OptionEntry, and MetalEntry all inherit from.
#requires an extension to ruby's class Class which gives DataEntry a custom attribute
#accessor called entry_attr_accessor.

require_relative "../ext/class.rb"

class DataEntry
  def initialize
    @record = Hash.new
  end
  
  def to_s
    @record.to_s
  end
end