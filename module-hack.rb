
############################################################
# HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK 
############################################################

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
  def cls_attr_accessor_warn (*attrs)
    attrs.each {|attr|
      module_eval(<<-EOS)
        def self.#{attr};
	  $stderr.puts "WARNING: #{attr} called from \#\{caller[0]}" if $DEBUG
	  @@#{attr};
	end
        def self.#{attr}=(v);
	  $stderr.puts "WARNING: #{attr}=(o) called from \#\{caller[0]}" if $DEBUG
	  @@#{attr} = v; 
	end
      EOS
    }
  end
  def move_class_methods (cls, *attrs)
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

class Fixnum
  def n
    $stderr.puts "WARNING: Fixnum#n called from " + caller[0]
    self
  end
  def nil?
    $stderr.puts "WARNING: Fixnum#nil? called from " + caller[0]
    return self == 0
  end
end

