
require 'BitSet'

class Sets

  def Sets.Empty(s)
    raise "um... you passed a FixNum" if s.kind_of? Fixnum
    s.each do |x| 
      return false if x
    end
    return true
  end
	
  def Sets.Different(s1, s2)
    return s1 != s2
  end
  
  def Sets.Includes(s1, s2)
    r = true
    for i in 0...s2.size
      if (s2[i] != s1[i]) then
	r = false
	break
      end
    end
    return r
  end
  
  def Sets.FullSet(max)
    warn_usage if $DEBUG
    
    # TODO: this is dumb: return BitSet.new(max, true)
    s = BitSet.new
    for i in 0..max
      s.set(i)
    end
    return s
  end
	
  def Sets.Size(s)
    return s.trueCount
  end
	
  def Sets.First(s)
    r = -1
    for i in 0...s.size
      if (s[i]) then
	r = i
	break
      end
    end
    return r
  end
	
  def Sets.Differ(s, s1)
    max = s.size
    for i in 0..(max-1)
      s.clear(i) if (s1[i])
    end
  end
end
