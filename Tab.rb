
require "module-hack"

class Position	 			# position of source code stretch (e.g. semantic action)
  attr_accessor :beg			# start relative to the beginning of the file
  attr_accessor :len			# length of stretch
  attr_accessor :col			# column number of start position

  def initialize
    @beg = @len = @col = 0
  end

  def ==(o)
    ! o.nil? &&
      @beg == o.beg &&
      @len == o.len &&
      @col == o.col
  end
  
end

class SymInfo
  attr_accessor :name
  attr_accessor :kind			# 0 = ident, 1 = string

  def initialize
    @name = ""
    @kind = 0
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

# RENAMED from Symbol
class Sym
  attr_accessor :typ			# t, nt, pr, unknown
  attr_accessor :name			# symbol name
  attr_accessor :struct			# nt: index of first node of syntax graph
					# t:  token kind (literal, class, ...)
  attr_accessor :deletable		# nt: true if nonterminal is deletable
  attr_accessor :attrPos		# position of attributes in source text (or null)
  attr_accessor :retType		# nt: Type of output attribute (or null)
  attr_accessor :retVar			# nt: Name of output attribute (or null)
  attr_accessor :semPos			# pr: pos of semantic action in source text (or null)
					# nt: pos of local declarations in source text (or null)
  attr_accessor :line			# source text line number of item in this node

  def initialize # symbol
    @typ = @struct = @line = 0
    @deletable = @attrPos = @semPos = @line = nil
    @name = @retType = @retVar = ""
  end

  def ==(o)
    raise "Not implemented yet"
  end

  def to_s
    "<Symbol: name=#{@name}/retType=#{@retType.inspect}/retVar=#{@retVar.inspect}/attrPos:#{attrPos.inspect}>"
  end
  
end

class GraphNode
  attr_accessor :typ			# t, nt, wt, chr, clas, any, eps, sem, sync, alt, iter, opt
  attr_accessor :next			# index of successor node
					# next<0: to successor in enclosing structure
  attr_accessor :p1			# nt, t, wt: index to symbol list
					# any:       index to any-set
					# sync:      index to sync-set
					# alt:       index of 1st node of 1st alternative
					# iter, opt: 1st node in subexpression
					# chr:       ordinal character value
					# clas:      index of character class
  attr_accessor :p2			# alt:       index of 1st node of next alternative
					# chr, clas: transition code
  attr_accessor :pos			# nt, t, wt: pos of actual attributes
					# sem:       pos of semantic action in source text
  attr_accessor :retVar			# nt: name of output attribute (or null)
  attr_accessor :line			# source text line number of item in this node
  attr_accessor :state			# DFA state corresponding to this node
					# (only used in Sgen.ConvertToStates)

  def initialize
    @typ = @next = @p1 = @p2 = @line = 0
    @pos = nil
    @retVar = ""
    @state = nil
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class FirstSet
    attr_accessor :ts			# terminal symbols
    attr_accessor :ready		# if true, ts is complete

  def initialize
    @ts = nil
    @ready = false
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class FollowSet
    attr_accessor :ts			# terminal symbols
    attr_accessor :nts			# nonterminals whose start set is to be included into ts

  def initialize
    @ts = @nts = nil # BitSet
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class CharClass
    attr_accessor :name			# class name
    attr_accessor :set			# index of set representing the class

  def initialize
    @name = ""
    @set = 0
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class Graph
  attr_accessor :l			# left end of graph = head
  attr_accessor :r			# right end of graph = list of nodes to be linked to successor graph

  def initialize
    @l = @r = 0
  end

  def ==(o)
    raise "Not implemented yet"
  end

  def to_s
    raise "no"
    "<Graph@#{self.id}: #{@l}, #{@r}>"
  end
  
end

class XNode				# node of cross reference list
    attr_accessor :line
    attr_accessor :next

  def initialize
    @line = 0
    @next = nil
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class CNode				# node of list for finding circular productions
    attr_accessor :left
    attr_accessor :right
    attr_accessor :deleted

  def initialize
    @left = @right = 0
    @deleted = false
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
end

class Tab

  # --- constants ---
  MaxSymbols   =  512	# max. no. of t, nt, and pragmas
  MaxTerminals =  256	# max. no. of terminals    # TODO: never used
  MaxNodes     = 1500	# max. no. of graph nodes
  MaxSetNr     =  128	# max. no. of symbol sets
  MaxClasses   =   50	# max. no. of character classes

  T    = 1				# node kinds
  Pr   = 2
  Nt   = 3
  Clas = 4
  Chr  = 5
  Wt   = 6
  Any  = 7
  Eps  = 8
  Sync = 9
  Sem  = 10
  Alt  = 11
  Iter = 12
  Opt  = 13

  ClassToken    = 0		# token kinds
  LitToken      = 1
  ClassLitToken = 2

  NormTrans    = 0		# transition codes
  ContextTrans = 1

  EofSy = 0
  NoSym = -1

  # --- variables ---
  @@maxSet = nil				# index of last set
  @@maxT = nil					# terminals stored from 0 to maxT
  @@maxP = nil					# pragmas stored from maxT+1 to maxP
  @@firstNt = nil				# index of first nt: available after CompSymbolSets
  @@lastNt = nil				# index of last nt: available after CompSymbolSets
  @@maxC = nil					# index of last character class
## TODO: convert usage to @@
  @@semDeclPos = nil				# position of global semantic declarations
  @@importPos = nil				# position of imported identifiers
  @@ignored = nil				# characters ignored by the scanner
  @@ddt = Array.new(10, false)			# debug and test switches
  @@nNodes = nil				# index of last graph node
  @@gramSy = 0					# root nonterminal filled by ATG

  @@sy = Array.new(MaxSymbols, :Sym)		# symbol table
  @@gn = Array.new(MaxNodes, :GraphNode)	# grammar graph
  @@first = nil # FirstSet[]			# first[i] = start symbols of sy[i+@@firstNt]
  @@follow = nil #  FollowSet[] 		# follow[i] = followers of sy[i+@@firstNt]
  @@chClass = nil # new CharClass[MaxClasses]	# character classes
  @@chClass = Array.new(MaxClasses) # HACK

  @@set = Array.new(128) # new BitSet[128]	# set[0] = union of all synchr. sets

  @@err = nil					# error messages
  @@dummyName = 0				# for unnamed character classes
  @@visited = nil # BitSet
  @@termNt = nil # BitSet			# mark lists for graph traversals
  @@curSy = 0					# current symbol in computation of sets
  @@nTyp = [ "    ", "T   ", "Pr  ", "Nt  ", "Clas", "Chr ", "Wt  ",
             "Any ", "Eps ", "Sync", "Sem ", "Alt ", "Iter", "Opt " ]

  # HACK HACK HACK... this is weird that I need to copy this code in.
  def self.cls_attr_accessor(*names)
    for name in names do
      eval "def self.#{name}; @@#{name}; end; def self.#{name}=(x); @@#{name}=x; end"
    end
  end

  # I'm only adding these as they get used and fubar something
  cls_attr_accessor :ignored, :semDeclPos, :nNodes, :gramSy, :firstNt, :lastNt
  cls_attr_accessor :ddt, :maxT, :maxP

#   def self.ddt # HACK : I have no idea why cls_attr_accessor isn't working 
#     @@ddt
#   end

#   def self.maxT # HACK : I have no idea why cls_attr_accessor isn't working 
#     @@maxT
#   end

#   def self.maxP # HACK : I have no idea why cls_attr_accessor isn't working 
#     @@maxP
#   end

  def initialize
    raise "Not implemented yet"
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
  def self.Assert(cond, n)
    if (!cond) then
      $stderr.puts("-- SymTab fatal error ")
      case (n)
      when 3 
	  $stderr.puts("-- too many nodes in graph")
      when 4
	  $stderr.puts("-- too many sets")
      when 6
	  $stderr.puts("-- too many symbols")
      when 7
	  $stderr.puts("-- too many character classes")
      end
      $stderr.puts("Stack Trace = #{caller.join "\n"}")
      exit(n)
    end
  end

  def self.Init
    @@err = Scanner.err
    @@maxSet = 0
    @@set[0] = BitSet.new()
    @@set[0].set(EofSy)

    @@maxT = -1
    @@maxP = MaxSymbols
    @@firstNt = MaxSymbols
    @@lastNt = @@maxP - 1
    @@dummyName = 0
    @@maxC = -1
    @@nNodes = -1
    dummy = NewNode(0, 0, 0) # fills slot zero
  end

  # ---------------------------------------------------------------------
  # Symbol table management
  # ---------------------------------------------------------------------

  def self.NewSym(typ, name, line)
    s = nil
    i = 0

    self.Assert(@@maxT+1 < @@firstNt, 6)

    case typ 
    when T
      @@maxT += 1
      i = @@maxT
    when Pr
      @@maxP -= 1
      @@firstNt -= 1
      @@lastNt -= 1
      i = @@maxP
    when Nt
      @@firstNt -= 1
      i = @@firstNt
    end

    self.Assert(@@maxT+1 < @@firstNt, 6)

    s = Sym.new()
    s.typ = typ
    s.name = name
    s.line = line
    @@sy[i] = s

    return i
  end

  def self.Sym(i)
    return @@sy[i]
  end

  # TODO: this is totally unnecessary in ruby
  def self.FindSym(name)
    i = 0
    while (i <= @@maxT)
      if (name == @@sy[i].name) then
	return i
      end
      i += 1
    end
    i = @@firstNt
    while (i < MaxSymbols)
      if (name == @@sy[i].name) then
	return i
      end
      i += 1
    end
    return NoSym
  end

  # ---------------------------------------------------------------------
  #   topdown graph management
  # ---------------------------------------------------------------------

  def self.NewNode(typ, p1, line)
    n = nil
    @@nNodes += 1
    self.Assert(@@nNodes <= MaxNodes, 3)
    n = GraphNode.new
    n.typ = typ
    n.p1 = p1
    n.line = line
    @@gn[@@nNodes] = n

#    HACK puts "Adding a GraphNode, ##{@@nNodes}: type #{@@nTyp[typ]}, p1=#{p1}, line=#{line}"
#    puts "Caller = #{caller.join("\n")}"
#    self.PrintGraph

    return @@nNodes
  end

  def self.Node(i)
    return @@gn[i]
  end

  def self.CompleteGraph(p)
#    HACK self.PrintGraph
    while (p != 0) do
      q = @@gn[p].next
      @@gn[p].next = 0
      p = q
    end
#    HACK self.PrintGraph
  end

  def self.Alternative(g1, g2)
    p = 0
    g2.l = NewNode(Alt, g2.l, 0)
    p = g1.l
    while (@@gn[p].p2 != 0) do
      p = @@gn[p].p2
    end
    @@gn[p].p2 = g2.l
    p = g1.r 
    while (@@gn[p].next != 0) do
      p = @@gn[p].next
    end
    @@gn[p].next = g2.r
    return g1
  end

  def self.Sequence(g1, g2)
    p = q = 0
    p = @@gn[g1.r].next
    @@gn[g1.r].next = g2.l # head node
    while (p != 0) do # substructure
      q = @@gn[p].next
      @@gn[p].next = -g2.l
      p = q
    end
    g1.r = g2.r
    return g1
  end

  def self.FirstAlt(g)
    g.l = NewNode(Alt, g.l, 0)
    @@gn[g.l].next = g.r
    g.r = g.l
    return g
  end

  def self.Iteration(g)
    p = q = 0
    g.l = NewNode(Iter, g.l, 0) # TODO: find all NewNode and cap 1st arg
    p = g.r
    g.r = g.l
    while (p != 0) do
      q = @@gn[p].next
      @@gn[p].next = -g.l
      p = q
    end
    return g
  end

  def self.Option(g)
    g.l = NewNode(Opt, g.l, 0)
    @@gn[g.l].next = g.r
    g.r = g.l
    return g
  end

  def self.StrToGraph(s)
    len = s.length() - 1
    g = Graph.new
    i = 1
    while (i<len) do
      @@gn[g.r].next = NewNode(Chr, s[i], 0)
      g.r = @@gn[g.r].next
      i += 1
    end
      g.l = @@gn[0].next
      @@gn[0].next = 0
    return g
  end

  def self.DelGraph(p)
    n = nil
    return true if p == 0 # end of graph found
    n = Node(p)
    return DelNode(n) && DelGraph(n.next.abs)
  end

  def self.DelAlt(p)
    n = nil
    return true if p <= 0 # end of graph found
    n = Node(p)
    return DelNode(n) && DelAlt(n.next)
  end

  def self.DelNode(n)
    if (n.typ==Nt) then
      return @@sy[n.p1].deletable
    elsif (n.typ==Alt) then
      return DelAlt(n.p1) || n.p2!=0 && DelAlt(n.p2)
    else
      return n.typ==Eps || n.typ==Iter || n.typ==Opt || n.typ==Sem || n.typ==Sync
    end
  end

  def self.PrintGraph
    n = nil
    Trace.println("Graph:")
    Trace.println("  nr typ   next p1   p2   line")
    i = 0
    while (i <= @@nNodes) do
      n = Node(i)
      s = sprintf("%4d %s %5d %s %s %5d", i, @@nTyp[n.typ], n.next, @@nTyp[n.p1], @@nTyp[n.p2], n.line)
      Trace.println(s)
      i += 1
    end
    Trace.println()
  end


  # ---------------------------------------------------------------------
  #   Character class management
  # ---------------------------------------------------------------------

  def self.NewClass(name, s)
    c = nil
    @@maxC += 1
    Assert(@@maxC < MaxClasses, 7)
    if (name == "#") then
      name = "#" + (?A + @@dummyName).chr
      @@dummyName += 1
    end
    c = CharClass.new
    c.name = name
    c.set = NewSet(s)
    @@chClass[@@maxC] = c
    return @@maxC
  end

  # TODO: these aren't necessary in ruby
  def self.ClassWithName(name)
    i=@@maxC
    while (i>=0 && name != @@chClass[i].name) do
      i -= 1
    end
    return i
  end

  # TODO: these aren't necessary in ruby
  def self.ClassWithSet(s)
    i = @@maxC
    while (i>=0 && s != @@set[@@chClass[i].set]) do
      i -= 1
    end
    return i
  end

  def self.Class(i)
    return @@set[@@chClass[i].set]
  end

  def self.ClassName(i)
    return @@chClass[i].name
  end

  # ---------------------------------------------------------------------
  #   Symbol set computations
  # ---------------------------------------------------------------------

  def self.PrintSet(s, indent)
    i = len = 0
    col = indent
    while (i <= @@maxT) do
      if (s.get(i)) then
	len = @@sy[i].name.length
	if (col + len + 1 > 80) then
	  Trace.println()
	  Trace.print(" " * indent)
	  col = indent
	end
	Trace.print(@@sy[i].name + "  ")
	col += len + 1
      end
      i += 1
    end

    if (col==indent) then
      Trace.print("-- empty set --")
    end

    Trace.println()
  end
    
  def self.NewSet(s)
    @@maxSet += 1
    Assert(@@maxSet <= MaxSetNr, 4)
    @@set[@@maxSet] = s
    return @@maxSet
  end

  def self.Set(i)
    return @@set[i]
  end

  def self.First0(p, mark)
    n = nil
    s1 = s2 = nil
    fs = BitSet.new

    while (p!=0 && !mark.get(p)) do
      n = self.Node(p)
      mark.set(p)
		 
      case (n.typ)
      when Nt then
	if (@@first[n.p1-@@firstNt].ready) then
	  fs.or(@@first[n.p1-@@firstNt].ts)
	else 
	  fs.or(self.First0(@@sy[n.p1].struct, mark))
	end
      when T, Wt then
	fs.set(n.p1)
      when Any then
	fs.or(@@set[n.p1])
      when Alt, Iter, Opt then
	fs.or(self.First0(n.p1, mark))
	if (n.typ==Alt) then
	  fs.or(self.First0(n.p2, mark))
	end
      end
      if (!self.DelNode(n)) then
	break
      end
      p = n.next.abs
    end
    return fs
  end
  
  def self.First(p)
    fs = First0(p, BitSet.new(@@nNodes+1))
    if (@@ddt[3]) then
      Trace.println()
      Trace.println("First: gp = " + p)
      PrintSet(fs, 0)
    end
    return fs
  end

  def self.CompFirstSets
    s = nil
    i = @@firstNt
    while (i<=@@lastNt) do
      s = FirstSet.new()
      s.ts = BitSet.new()
      s.ready = false
      @@first[i-@@firstNt] = s
      i += 1
    end

    i = @@firstNt
    while (i <= @@lastNt) do
      @@first[i-@@firstNt].ts = self.First(@@sy[i].struct)
      @@first[i-@@firstNt].ready = true
      i += 1
    end
  end
  
  def self.CompFollow(p)
    n = s = nil
    while (p>0 && !@@visited.get(p)) do
      n = Node(p)
      @@visited.set(p)
      if (n.typ==Nt) then
	s = First(n.next.abs)
	@@follow[n.p1-@@firstNt].ts.or(s)
	if (DelGraph(n.next.abs)) then
	  @@follow[n.p1-@@firstNt].nts.set(@@curSy-@@firstNt)
	end
      elsif (n.typ==Opt || n.typ==Iter) then
	CompFollow(n.p1)
      elsif (n.typ==Alt) then
	CompFollow(n.p1)
	CompFollow(n.p2)
      end
      p = n.next
    end
  end

  def self.Complete(i)
    if (!@@visited.get(i)) then
      @@visited.set(i)
      j = 0
      while (j<=@@lastNt-@@firstNt) do # for all nonterminals
	if (@@follow[i].nts.get(j)) then
	  Complete(j)
	  @@follow[i].ts.or(@@follow[j].ts)
	  if (i == @@curSy) then
	    @@follow[i].nts.clear(j)
	  end
	end
	j += 1
      end
    end
  end

  def self.CompFollowSets
    s = nil
    @@curSy = @@firstNt
    while (@@curSy<=@@lastNt) do
      s = FollowSet.new()
      s.ts = BitSet.new()
      s.nts = BitSet.new()
      @@follow[@@curSy-@@firstNt] = s
      @@curSy += 1
    end

    @@visited = BitSet.new()

    @@curSy = @@firstNt
    while (@@curSy<=@@lastNt) do # get direct successors of nonterminals
      CompFollow(@@sy[@@curSy].struct)
      @@curSy += 1
    end

    @@curSy = 0
    while (@@curSy<=@@lastNt-@@firstNt) do # add indirect successors to follow.ts
      visited = BitSet.new()
      Complete(@@curSy)
      @@curSy += 1
    end
  end

  def self.LeadingAny(p)
    n = a = nil

    if (p <= 0) then
      return nil
    end

    n = Node(p)

    if (n.typ==Any) then
      a = n
    elsif (n.typ==Alt) then
      a = LeadingAny(n.p1)
      if (a.nil?) then
	a = LeadingAny(n.p2)
      end
    elsif (n.typ==Opt || n.typ==Iter) then
      a = LeadingAny(n.p1)
    elsif (DelNode(n)) then
      a = LeadingAny(n.next)
    end

    return a
  end

  def self.FindAS(p)
    n = nod = a = s1 = s2 = nil
    q = 0

    while (p > 0) do
      n = Node(p)
      if (n.typ==Opt || n.typ==Iter) then
	FindAS(n.p1)
	a = LeadingAny(n.p1)
	unless (a.nil?) then
	  s1 = First(n.next.abs)
	  Sets.Differ(@@set[a.p1], s1)
	end
      elsif (n.typ==Alt) then
	s1 = BitSet.new()
	q = p
	while (q != 0) do
	  nod = Node(q)
	  FindAS(nod.p1)
	  a = LeadingAny(nod.p1)
	  unless (a.nil?) then
	    s2 = First(nod.p2)
	    s2.or(s1)
	    Sets.Differ(@@set[a.p1], s2)
	  else
	    s1.or(First(nod.p1))
	  end
	  q = nod.p2
	end
      end
      p = n.next
    end
  end

  def self.CompAnySets()
    @@curSy = @@firstNt
    while (@@curSy<=@@lastNt) do
      FindAS(@@sy[@@curSy].struct)
      @@curSy += 1
    end
  end

  def self.Expected(p, sp)
    s = First(p)
    if (DelGraph(p)) then
      s.or(@@follow[sp-@@firstNt].ts)
    end
    return s
  end

  def self.CompSync(p)
    n = s = nil
    while (p > 0 && !@@visited.get(p)) do
      n = Node(p)
      @@visited.set(p)
      if (n.typ==Sync) then
	s = Expected(n.next.abs, @@curSy)
	s.set(EofSy)
	@@set[0].or(s)
	n.p1 = NewSet(s)
      elsif (n.typ==Alt) then
	CompSync(n.p1)
	CompSync(n.p2)
      elsif (n.typ==Opt || n.typ==Iter) then
	CompSync(n.p1)
      end
      p = n.next
    end
  end

  def self.CompSyncSets
    @@visited = BitSet.new()
    @@curSy = @@firstNt
    while (@@curSy <= @@lastNt) do
      CompSync(@@sy[@@curSy].struct)
      @@curSy += 1
    end
  end

  def self.CompDeletableSymbols
    i = 0
    changed = true
    while (changed) do
      changed = false

      i = @@firstNt
      while (i<=@@lastNt) do
	if (!@@sy[i].deletable && DelGraph(@@sy[i].struct)) then
	  @@sy[i].deletable = true
	  changed = true
	end
	i += 1
      end
    end

    i = @@firstNt
    while (i<=@@lastNt) do
      if (@@sy[i].deletable) then
	puts("  " + @@sy[i].name + " deletable") # FIX
      end
      i += 1
    end
  end

  def self.MovePragmas
    if (@@maxP > @@firstNt) then
      @@maxP = @@maxT
      i = MaxSymbols - 1
      while (i > @@lastNt) do
	@@maxP += 1
	Assert(@@maxP < @@firstNt, 6)
	@@sy[@@maxP] = @@sy[i]
	i -= 1
      end
    end
  end

  def self.CompSymbolSets
    i = self.NewSym(T, "???", 0)
    # unknown symbols get code @@maxT
    MovePragmas()
    CompDeletableSymbols()

    @@first = Array.new(@@lastNt-@@firstNt+1)
    @@follow = Array.new(@@lastNt-@@firstNt+1)

    CompFirstSets()
    CompFollowSets()
    CompAnySets()
    CompSyncSets()
    if (@@ddt[1]) then
      Trace.println("First & follow symbols:")

      i = @@firstNt
      while (i<=@@lastNt) do
	Trace.println(@@sy[i].name)
	Trace.print("first:   ")
	PrintSet(@@first[i-@@firstNt].ts, 10)
	Trace.print("follow:  ")
	PrintSet(@@follow[i-@@firstNt].ts, 10)
	Trace.println()
	i += 1
      end

      if (@@maxSet >= 0) then
	Trace.println()
	Trace.println()
	Trace.println("List of sets (ANY, SYNC): ")
	i = 0
	while (i<=@@maxSet) do
	  Trace.print("     set[" + i + "] = ")
	  PrintSet(@@set[i], 16)
	  i += 1
	end
	Trace.println()
	Trace.println()
      end
    end
  end

  # ---------------------------------------------------------------------
  #   Grammar checks
  # ---------------------------------------------------------------------

  def self.GetSingles(p, singles) # (int p, BitSet singles)
    n = nil

    return if p <= 0 # end of graph

    n = Node(p)

    if (n.typ==Nt) then
      if (DelGraph(n.next.abs)) then
	singles.set(n.p1)
      end
    elsif (n.typ==Alt || n.typ==Iter || n.typ==Opt) then
      if (DelGraph(n.next.abs)) then
	GetSingles(n.p1, singles)
	if (n.typ==Alt) then
	  GetSingles(n.p2, singles)
	end
      end
    end

    if (DelNode(n)) then
      GetSingles(n.next, singles)
    end
  end

  def self.NoCircularProductions
    ok = changed = onLeftSide = onRightSide = false
    list = Array.new(150) # FIX: constify
    x = singles = sym = nil
    i = j = len = 0

    for i in @@firstNt..@@lastNt do
      singles = BitSet.new()
      GetSingles(@@sy[i].struct, singles)
      # get nts such that i-->j
      for j in @@firstNt..@@lastNt do
	if (singles.get(j)) then
	  x = CNode.new
	  x.left = i
	  x.right = j
	  x.deleted = false
	  list[len] = x
	  len += 1
	end
      end
    end

    begin
      changed = false
      for i in 0...len do
	if (!list[i].deleted) then
	  onLeftSide = false
	  onRightSide = false
	  
	  for j in 0...len do
	    if (!list[j].deleted) then
	      onRightSide = true if (list[i].left==list[j].right) 
	      onLeftSide = true if (list[j].left==list[i].right) 
	    end
	  end
	  
	  if (!onLeftSide || !onRightSide) then
	    list[i].deleted = true
	    changed = true
	  end
	end
      end
    end while(changed)

    ok = true

    for i in 0...len do
      if (!list[i].deleted) then
	ok = false
	puts("  "+@@sy[list[i].left].name+" --> "+@@sy[list[i].right].name)
      end
    end

    return ok
  end

  def self.LL1Error(cond, ts)
    print("  LL1 warning in " + @@sy[@@curSy].name + ": ")
    print(@@sy[ts].name + " is ") if (ts > 0)

    case cond
    when 1
      puts " start of several alternatives"
    when 2
      puts " start & successor of deletable structure"
    when 3
      puts " an ANY node that matches no symbol"
    end
  end

  def self.Overlap(s1, s2, cond)
    overlap = false

    for i in 0..@@maxT do
      if (s1.get(i) && s2.get(i)) then
	LL1Error(cond, i)
	overlap = true
      end
    end

    return overlap
  end

  def self.AltOverlap(p)
    overlap = false
    n = a = s1 = s2 = nil
    q = 0

    while (p > 0) do
      n = Node(p)
      if (n.typ==Alt) then
	q = p
	s1 = BitSet.new()
	while (q != 0) do # for all alternatives
	  a = Node(q)
	  s2 = Expected(a.p1, @@curSy)
	  overlap = true if (Overlap(s1, s2, 1)) 
	  s1.or(s2)
	  overlap = true if (AltOverlap(a.p1)) 
	  q = a.p2
	end
      elsif (n.typ==Opt || n.typ==Iter) then
	s1 = Expected(n.p1, @@curSy)
	s2 = Expected(n.next.abs, @@curSy)
	overlap = true if (Overlap(s1, s2, 2)) 
	overlap = true if (AltOverlap(n.p1)) 
      elsif (n.typ==Any) then
	if (Sets.Empty(Set(n.p1))) then # e.g. {ANY} ANY or [ANY] ANY
	  LL1Error(3, 0)
	  overlap = true
	end

      end
      p = n.next
    end

    return overlap
  end

  def self.LL1()
    ll1 = true
    for @@curSy in @@firstNt..@@lastNt do
      ll1 = false if (AltOverlap(@@sy[@@curSy].struct)) 
    end
    return ll1
  end

  def self.NtsComplete
    complete = true
    
    for i in @@firstNt..@@lastNt do
      if (@@sy[i].struct==0) then
	complete = false
	puts("  No production for " + @@sy[i].name)
      end
    end

    return complete
  end

  def self.MarkReachedNts(p)
    n = nil

    while (p > 0) do
      n = Node(p)
      if (n.typ==Nt) then
	if (!@@visited.get(n.p1)) then # new nt reached
	  @@visited.set(n.p1)
	  MarkReachedNts(@@sy[n.p1].struct)
	end
      elsif (n.typ==Alt || n.typ==Iter || n.typ==Opt) then
	MarkReachedNts(n.p1)
	MarkReachedNts(n.p2) if (n.typ==Alt)
      end
      p = n.next
    end
  end

  def self.AllNtReached
    n = nil
    ok = true
    @@visited = BitSet.new()
    @@visited.set(@@gramSy)

    MarkReachedNts(Sym(@@gramSy).struct)

    for i in @@firstNt..@@lastNt do
      if (!@@visited.get(i)) then
	ok = false
	puts("  " + @@sy[i].name + " cannot be reached")
      end
    end
    return ok
  end

  def self.Term(p) # true if graph can be derived to terminals
    n = nil

    while (p > 0) do
      n = Node(p)
      return false if (n.typ==Nt && !@@termNt.get(n.p1))
      return false if (n.typ==Alt && !Term(n.p1) && (n.p2==0 || !Term(n.p2)))
      p = n.next
    end

    return true
  end

  def self.AllNtToTerm
    changed = false
    ok = true
    i = 0
    @@termNt = BitSet.new

    begin
      changed = false
      for i in @@firstNt..@@lastNt do
	if (!@@termNt.get(i) && Term(@@sy[i].struct)) then
	  @@termNt.set(i)
	  changed = true
	end
      end
    end while changed

    for i in @@firstNt..@@lastNt do
      if (!@@termNt.get(i)) then
	ok = false
	puts "  " + @@sy[i].name + "cannot be derived to terminals"
      end
    end

    return ok
  end

  ############################################################
  # START OF HACKS

  def self.t # HACK
    raise "Um. no"
  end

end

__END__

class Tab {

# ---------------------------------------------------------------------
#   Utility functions
# ---------------------------------------------------------------------

static String Str(String s, int len) {
char[] a = new char[64];
int i = s.length();
s.getChars(0, i, a, 0);
for (; i<len; i++) a[i] = ' ';
return String.new(a, 0, len);
}

static String Int(int n, int len) {
char[] a = new char[16];
String s = String.valueOf(n);
int i = 0, j = 0, d = len - s.length();
while (i < d) {a[i] = ' ';
i++;}
while (i < len) {a[i] = s.charAt(j);
i++;
j++;}
return String.new(a, 0, len);
}

static void PrintSymbolTable() {
int i;
Trace.println("Symbol Table:");
Trace.println(" nr name       typ  hasAt struct del   line");
Trace.println();
i = 0;
while (i < MaxSymbols) {
Trace.print(Int(i, 3) + " " + Str(sy[i].name, 10) + " " + nTyp[sy[i].typ]);
if (sy[i].attrPos==null) Trace.print(" false ");
else Trace.print(" true  ");
Trace.print(Int(sy[i].struct, 5));
if (sy[i].deletable) Trace.print(" true  ");
else Trace.print(" false ");
Trace.println(Int(sy[i].line, 5));
if (i==@@maxT) i = @@firstNt;
else i++;
}
Trace.println();
}

static void XRef() {
Sym sym;
GraphNode n;
XNode[] list = new XNode[@@lastNt+1];
XNode p, q, x;
int i, col;
if (@@maxT <= 0) return;
MovePragmas();
# search lines where symbol has been referenced
for (i=@@nNodes; i>=1; i--) {
n = Node(i);
if (n.typ==t || n.typ==wt || n.typ==nt) {
p = XNode.new();
p.line = n.line;
p.next = list[n.p1];
list[n.p1] = p;
}
}
# search lines where symbol has been defined and insert in order
i = 1;
while (i <= @@lastNt) {
sym = Sym(i);
p = list[i];
q = null;
while (p != null && sym.line > p.line) {q = p;
p = p.next;}
x = XNode.new();
x.line = -sym.line;
x.next = p;
if (q==null) list[i] = x;
else q.next = x;
if (i==@@maxP) i = @@firstNt;
else i++;
}
# print cross reference list
Trace.println();
Trace.println("Cross reference list:");
Trace.println();
Trace.println("Terminals:");
Trace.println("  0 EOF");
i = 1;
while (i <= @@lastNt) {
Trace.print(Int(i, 3) + " " + sy[i].name + "  ");
p = list[i];
col = 25;
while (p != null) {
if (col + 5 > 80) {
Trace.println();
for (col=0; col<25; col++) Trace.print(" ");
}
if (p.line==0) Trace.print("undef  ");
else Trace.print(p.line + "  ");
col = col + 5;
p = p.next;
}
Trace.println();
if (i==@@maxT) {Trace.println();
Trace.println("Pragmas:");}
if (i==@@maxP) {Trace.println();
Trace.println("Nonterminals:");
i = @@firstNt;}
else i++;
}
Trace.println();
Trace.println();
}

static void Init() {
# ...
}

}
