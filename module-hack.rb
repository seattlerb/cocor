
############################################################
# HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK 
############################################################

class Module

  def warn_usage
    c = module_eval("self.name")
    m = /\`([^\']+)\'/.match(caller(1).first)[1]
    $stderr.puts "WARNING: #{c}.#{m} called from #{caller[2]}"
  end

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

  def attr_accessor_warn (*attrs)
    attrs.each {|attr|
      module_eval(<<-EOS)
        def #{attr};
	  $stderr.puts "WARNING: \#\{self.class}.#{attr} called from \#\{caller[0]}" if $DEBUG
	  @#{attr};
	end
        def #{attr}=(v);
	  $stderr.puts "WARNING: \#\{self.class}.#{attr}=(o) called from \#\{caller[0]}" if $DEBUG
	  @#{attr} = v; 
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
end

