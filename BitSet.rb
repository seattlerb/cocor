
class BitSet

  def initialize(size=128)
    @size = size
    @bits = Array.new(size, false)
  end

  def clear(i)
    @bits[i] = false
  end 
  # Sets the bit specified by the index to false .

  def get(i)
    @bits[i]
  end 
  alias :[] :get
  # Returns the value of the bit with the specified index. 

  def set(i)
    @bits[i] = true
  end 
  # Sets the bit specified by the index to true .

  def and(set) 
    raise "something"
  end
  # Performs a logical AND of this target bit set with the argument bit set. 

  def or(s)
    s.size.times do |i|
      self.set(i) if s[i] && !self[i]
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

  def size
    return @size
  end 
  # Returns the number of bits of space actually in use by this BitSet to represent bit values. 

end
