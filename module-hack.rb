
class Module
  def cls_attr_accessor(*names)
    for name in names do
      eval "def self.#{name}; @@#{name}; end; def self.#{name}=(x); @@#{name}=x; end"
    end
  end
end
