
require 'BitSet'

class Sets

  def Sets.Empty(s)
    s.each do |x| 
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
    s = BitSet.new
    for i in 0..max
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
