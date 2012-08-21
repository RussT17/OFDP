#The class that entries in all the scrapers inherit from.
#requires an extension to ruby's class Class which gives DataEntry a custom attribute
#accessor called entry_attr_accessor:
require_relative "../ext/class.rb"
#entry_attr_accessor automatically creates some functions, for example, using fields: field1 and field2
#The line 
#    entry_attr_accessor :field1, :field2
#will create these functions:
#
#    def field1=(input)
#       @field1 = input
#    end
#    def field2=(input)
#       @field2 = input
#    end
#
#    def save
#       @record = {:field1 => @field1, :field2 => @field2}
#       puts "Entry" + to_s + "saved."
#    end
#
#    def field1
#       @record[:field1]
#    end
#    def field2
#       @record[:field2]
#    end
#
#The creation of entry_attr_accessor was not at all necessary, more of an experiment with extending the
#class Class. The save function acts as a buffer between the input variables and the @record hash which is used internally
#in entry. A hash was a convenient method of storing entry values internally because rails model calls often take
#hashes as input.

class DataEntry
  def initialize
    @record = Hash.new
  end
  
  def to_s
    @record.to_s
  end
end