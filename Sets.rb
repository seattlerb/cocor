
require 'BitSet'

class Sets

  def Sets.Empty(s)
    s.bits.each do |x| 
      return false if (x) 
    end
    return true
  end
	
  def Sets.Different(s1, s2)
    return s1 != s2
#    max = s1.size
#    for i in 0..(max-1)
#      return false if (s1[i] == s2[i])
#    end
#    return true
  end
  
  def Sets.Includes(s1, s2)
    max = s2.size
    for i in 0..(max-1)
      return false if (s2[i] != s1[i])
    end
    return true
  end
  
  def Sets.FullSet(max)
    s = BitSet.new
    for i in 0..(max-1)
      s.set(i)
    end
    return s
  end
	
  def Sets.Size(s)
    return s.trueCount
#    size = 0
#    max = s.size
#    for i in 0..(max-1)
#      size += 1 if (s[i]) 
#    end
#    return size
  end
	
  def Sets.First(s)
    max = s.size
    for i in 0..(max-1)
      return i if (s[i])
    end
    return -1
  end
	
  def Sets.Differ(s, s1)
    max = s.size
    for i in 0..(max-1)
      s.clear(i) if (s1[i])
    end
  end
end
