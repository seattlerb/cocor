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
end 
