class Module
  private
  def cls_attr_accessor (*attrs)
    attrs.each {|attr|
      module_eval(<<-EOS)
        def self.#{attr};     @@#{attr};     end
        def self.#{attr}=(v); @@#{attr} = v; end
      EOS
    }
  end
  def move_methods (cls, *attrs)
    attrs.each {|attr|
      module_eval(<<-EOS)
        def self.#{attr}(*args)
	  $stderr.puts "WARNING: #{cls}.#{attr} called from " + caller[0]
          #{cls}.#{attr}(*args)
        end
      EOS
    }
  end
end 
