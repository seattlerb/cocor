
require "module-hack"

class BitSet < Array

  attr_reader :trueCount

  def initialize(size=128)
    super(size, false)
    @trueCount = 0
  end

  def clone
    return Marshal.load(Marshal.dump(self))
  end

  def to_s
    indexes = []
    self.each_with_index do |t,i|
      indexes << i if t
    end

    "{#{indexes.join(", ")}}"
  end

  def clear(i)
    @trueCount -= 1
    self[i] = false
  end 
  # Sets the bit specified by the index to false .

  def get(i)
    self.class.warn_usage if $DEBUG
    self[i]
  end
  # Returns the value of the bit with the specified index. 

  def set(i)
    @trueCount += 1
    self[i] = true
  end 
  # Sets the bit specified by the index to true .

  def and(s) 
    s.size.times do |i|
      self.clear(i) unless s[i] && self[i]
    end
  end
  # Performs a logical AND of this target bit set with the argument bit set. 

  def or(s)
    s.size.times do |i|
      self.set(i) if s[i]
    end
  end 
  # Performs a logical OR of this bit set with the bit set   argument. 

  def andNot(set)
    raise "something"
  end 
  # Clears all of the bits in this BitSet whose corresponding  bit is set in the specified BitSet .

  def xor(set)
    raise "something"
  end 
  # Performs a logical XOR of this bit set with the bit set   argument. 

  def length
    raise "something"
  end 
  # Returns the "logical size" of this BitSet : the index of  the highest set bit in the BitSet plus one. 

  def self.PrintSet(s, indent=0)
    i = len = 0
    col = indent

    Sym.each_terminal do |sym|
      if s[sym.n] then
	len = sym.name.length
	Trace.print(sym.name + "  ")
	col += len + 1
      end
    end

    if (col==indent) then
      Trace.print("-- empty set --")
    end

    Trace.println()
  end
    
end
