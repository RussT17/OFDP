class Class
  def entry_attr_accessor (*syms)
    pairs = Array.new
    syms.each do |sym|
      #first the writer
      self.class_eval("def #{sym.to_s}=(val);@#{sym.to_s}=val;end")
      
      #next is the reader
      self.class_eval("def #{sym};@record[:#{sym.to_s}];end")
      
      pairs << ":#{sym.to_s}=>@#{sym.to_s}"
    end
    
    #now the saver
    self.class_eval("def save;@record={" + pairs.join(',') + "};puts 'Record ' + to_s + ' saved';end")
  end
end