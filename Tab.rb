
require "module-hack"

def assert(cond, n)
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

class Position	 			# position of source code stretch (e.g. semantic action)
  attr_accessor :beg			# start relative to the beginning of the file
  attr_accessor :len			# length of stretch
  attr_accessor :col			# column number of start position

  # REFACTOR: needs 3 args
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

# REFACTOR: c# version has this folded into Sym(bol)
class SymInfo
  attr_accessor :name
  attr_accessor :kind			# 0 = ident, 1 = string

  # REFACTOR: needs 2 args
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

  MaxSymbols   =  512	# max. no. of t, nt, and pragmas

  # FIX: nuke me... use iterators for real
  @@firstNt = MaxSymbols		# idx of first nt:available after CompSymbolSets
  @@maxP = MaxSymbols			# pragmas stored from maxT+1 to maxP
  @@maxT = -1				# terminals stored from 0 to maxT
  @@sy = Array.new(MaxSymbols, :Sym)	# symbol table
  @@lastNt = @@maxP - 1		# index of last nt: available after CompSymbolSets

  # TODO: get rid of me
  cls_attr_accessor :maxT, :firstNt, :sy, :maxP, :lastNt

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

  # REFACTOR: needs args (typ, name, line)
  def initialize # symbol
    @typ = @struct = @line = @struct = 0
    @deletable = @attrPos = @semPos = @line = nil
    @name = @retType = @retVar = nil	# strings
  end

  def ==(o)
    raise "Not implemented yet"
  end

  # TODO: <=>

  # TODO: this is totally unnecessary in ruby
  def self.FindSym(name)

    # TODO: make clean like this
    # foreach (Symbol s in terminals)
    # if (s.name == name) return s;
    # foreach (Symbol s in nonterminals)
    # if (s.name == name) return s;
    # return null;
    
    # TODO: if @@maxT and Sym.firstNt are always side-by-side, this can become one each_with_index
    # @@sy.each_with_index do |sym, i|
    #   return i if name == sym.name
    # end
    i = 0
    while (i <= @@maxT)
      if (name == @@sy[i].name) then
	return i
      end
      i += 1
    end
    i = Sym.firstNt
    while (i < MaxSymbols)
      if (name == @@sy[i].name) then
	return i
      end
      i += 1
    end
    return Tab::NoSym
  end

  # REFACTOR: move to sym
  def self.NewSym(typ, name, line)
    s = nil
    i = 0

    assert(@@maxT+1 < Sym.firstNt, 6)

    case typ 
    when Tab::T
      @@maxT += 1
      i = @@maxT
    when Tab::Pr
      @@maxP -= 1
      Sym.firstNt -= 1
      @@lastNt -= 1
      i = @@maxP
    when Tab::Nt
      Sym.firstNt -= 1
      i = Sym.firstNt
    end

    assert(@@maxT+1 < Sym.firstNt, 6)

#    puts "NewSym(#{typ}, #{name}, #{line})"

    s = Sym.new()
    s.typ = typ
    s.name = name
    s.line = line
    @@sy[i] = s

    return i
  end

  # TODO: make all Sym.sy[n] be Sym.Sym(n)
  def self.Sym(i)
    return @@sy[i]
  end

  def to_s
    "<Symbol: name=#{@name}/retType=#{@retType.inspect}/retVar=#{@retVar.inspect}/attrPos:#{attrPos.inspect}>"
  end
  
end

# TODO: rename to Node
class GraphNode

  MaxNodes = 1500	# max. no. of graph nodes

  @@gn = Array.new(MaxNodes, :GraphNode)	# grammar graph
  @@nNodes = -1					# index of last graph node

  cls_attr_accessor :gn, :nNodes # TODO: nuke me

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
    @retVar = nil			# string
    @state = nil
  end

  def self.NewNode(typ, p1, line)
    n = nil
    @@nNodes += 1
    assert(@@nNodes <= GraphNode::MaxNodes, 3)
    n = GraphNode.new
    n.typ = typ
    n.p1 = p1
    n.line = line
    @@gn[@@nNodes] = n

    return @@nNodes
  end

  def ==(o)
    raise "Not implemented yet"
  end
  
  def self.Node(i)
    return @@gn[i]
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
    if (n.typ==Tab::Nt) then
      return Sym.sy[n.p1].deletable
    elsif (n.typ==Tab::Alt) then
      return DelAlt(n.p1) || n.p2!=0 && DelAlt(n.p2)
    else
      return n.typ==Tab::Eps || n.typ==Tab::Iter || n.typ==Tab::Opt || n.typ==Tab::Sem || n.typ==Tab::Sync
    end
  end

end

# REFACTOR: merge into Sym per C# design
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

# REFACTOR: merge into Sym per C# design
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

  MaxClasses   =  150	# max. no. of character classes

  @@maxC = -1					# index of last character class
  @@chClass = Array.new(MaxClasses)#CharClass[] # character classes
  @@dummyName = 0				# for unnamed character classes

  cls_attr_accessor :maxC, :chClass

  attr_accessor :name			# class name
  attr_accessor :set			# index of set representing the class

  def initialize
    @name = ""
    @set = 0
  end

  def ==(o)
    raise "Not implemented yet"
  end
  

  # ---------------------------------------------------------------------
  #   Character class management
  # ---------------------------------------------------------------------

  def self.NewClass(name, s)
    c = nil
    @@maxC += 1
    assert(@@maxC < MaxClasses, 7)
    if (name == "#") then
      name = "#" + (?A + @@dummyName).chr
      @@dummyName += 1
    end
    c = CharClass.new
    c.name = name
    c.set = Tab.NewSet(s)
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

    while (i>=0 && s != Tab.set[@@chClass[i].set]) do
      i -= 1
    end

    return i
  end

  def self.Class(i)
    return Tab.set[@@chClass[i].set]
  end

  def self.ClassName(i)
    return @@chClass[i].name
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
  
  def self.FirstAlt(g)
    g.l = GraphNode.NewNode(Tab::Alt, g.l, 0)
    GraphNode.gn[g.l].next = g.r
    g.r = g.l
    return g
  end

  def self.Alternative(g1, g2)
    p = 0
    g2.l = GraphNode.NewNode(Tab::Alt, g2.l, 0)
    p = g1.l
    while (GraphNode.gn[p].p2 != 0) do
      p = GraphNode.gn[p].p2
    end
    GraphNode.gn[p].p2 = g2.l
    p = g1.r 
    while (GraphNode.gn[p].next != 0) do
      p = GraphNode.gn[p].next
    end
    GraphNode.gn[p].next = g2.r
    return g1
  end

  def self.Sequence(g1, g2)
    p = q = 0
    p = GraphNode.gn[g1.r].next
    GraphNode.gn[g1.r].next = g2.l # head node
    while (p != 0) do # substructure
      q = GraphNode.gn[p].next
      GraphNode.gn[p].next = -g2.l
      p = q
    end
    g1.r = g2.r
    return g1
  end

  def self.Iteration(g)
    p = q = 0
    g.l = GraphNode.NewNode(Tab::Iter, g.l, 0) # TODO: find all NewNode and cap 1st arg
    p = g.r
    g.r = g.l
    while (p != 0) do
      q = GraphNode.gn[p].next
      GraphNode.gn[p].next = -g.l
      p = q
    end
    return g
  end

  def self.Option(g)
    g.l = GraphNode.NewNode(Tab::Opt, g.l, 0)
    GraphNode.gn[g.l].next = g.r
    g.r = g.l
    return g
  end

  def self.CompleteGraph(p)
    while (p != 0) do
      q = GraphNode.gn[p].next
      GraphNode.gn[p].next = 0
      p = q
    end
  end

  # ---------------------------------------------------------------------
  #   topdown graph management
  # ---------------------------------------------------------------------

  def self.StrToGraph(s)
    len = s.length() - 1
    g = Graph.new
    i = 1
    while (i<len) do
      GraphNode.gn[g.r].next = GraphNode.NewNode(Tab::Chr, s[i], 0)
      g.r = GraphNode.gn[g.r].next
      i += 1
    end
      g.l = GraphNode.gn[0].next
      GraphNode.gn[0].next = 0
    return g
  end

  def self.PrintGraph
    n = nil
    Trace.println("Graph:")
    Trace.println("  nr typ  next   p1   p2 line")
    for i in 1..Tab.nNodes do
      n = GraphNode.Node(i)
      s = sprintf("%4d %s%5d%5d%5d%5d", i, Tab.nTyp[n.typ], n.next, n.p1, n.p2, n.line)
      Trace.println(s)
    end
    Trace.println()
  end

end

# REFACTOR: move this into graphnode
class XNode				# node of cross reference list
  attr_accessor :line
  attr_accessor :next

  def initialize
    @line = 0
    @next = nil
  end

  def ==(o)
    !o.nil? && @line == o.line && @next == o.next
  end
  
end # FUCK

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
  MaxTerminals =  256	# max. no. of terminals
  MaxSetNr     =  128	# max. no. of symbol sets

  # REFACTOR: move to node
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
## TODO: convert usage to @@
  @@semDeclPos = nil				# position of global semantic declarations
  @@importPos = nil				# position of imported identifiers
  @@ignored = nil				# characters ignored by the scanner
  @@ddt = Array.new(10, false)			# debug and test switches
  @@gramSy = 0					# root nonterminal filled by ATG

  @@first = nil # FirstSet[]			# first[i] = start symbols of sy[i+Sym.firstNt]
  @@follow = nil #  FollowSet[] 		# follow[i] = followers of sy[i+Sym.firstNt]

  @@set = Array.new(128) # new BitSet[128]	# set[0] = union of all synchr. sets

  @@err = nil					# error messages
  @@visited = nil # BitSet
  @@termNt = nil # BitSet			# mark lists for graph traversals
  @@curSy = 0					# current symbol in computation of sets
  @@nTyp = [ "    ", "t   ", "pr  ", "nt  ", "clas", "chr ", "wt  ",
             "any ", "eps ", "sync", "sem ", "alt ", "iter", "opt " ]

  # I'm only adding these as they get used and fubar something
  cls_attr_accessor :ignored, :semDeclPos, :nNodes, :gramSy, :firstNt, :lastNt
  cls_attr_accessor :ddt, :maxP, :maxC, :set

  move_class_methods Graph, :FirstAlt, :Alternative, :Sequence, :Iteration, :Option, :CompleteGraph, :PrintGraph, :StrToGraph

  def initialize
    raise "Not implemented yet"
  end

  def ==(o)
    raise "Not implemented yet"
  end

  def self.Init
    @@err = Scanner.err
    @@maxSet = 0
    @@set[0] = BitSet.new()
    @@set[0].set(EofSy)

    dummy = GraphNode.NewNode(0, 0, 0) # fills slot zero
  end

  # ---------------------------------------------------------------------
  #   Symbol set computations
  # ---------------------------------------------------------------------

  def self.PrintSet(s, indent)
    i = len = 0
    col = indent
    for i in 0..Sym.maxT do
      if (s.get(i)) then
	len = Sym.sy[i].name.length
	Trace.print(Sym.sy[i].name + "  ")
	col += len + 1
      end
    end

    if (col==indent) then
      Trace.print("-- empty set --")
    end

    Trace.println()
  end
    
  def self.NewSet(s)
    @@maxSet += 1
    assert(@@maxSet <= MaxSetNr, 4)
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
      n = GraphNode.Node(p)
      mark.set(p)
		 
      case (n.typ)
      when Nt then
	if (@@first[n.p1-Sym.firstNt].ready) then
	  fs.or(@@first[n.p1-Sym.firstNt].ts)
	else 
	  fs.or(self.First0(Sym.sy[n.p1].struct, mark))
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
      if (!GraphNode.DelNode(n)) then
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
      Trace.println("First: gp = #{p}")
      PrintSet(fs, 0)
    end
    return fs
  end

  def self.CompFirstSets
    s = nil
    i = Sym.firstNt
    while (i<=Sym.lastNt) do
      s = FirstSet.new()
      s.ts = BitSet.new()
      s.ready = false
      @@first[i-Sym.firstNt] = s
      i += 1
    end

    i = Sym.firstNt
    while (i <= Sym.lastNt) do
      @@first[i-Sym.firstNt].ts = self.First(Sym.sy[i].struct)
      @@first[i-Sym.firstNt].ready = true
      i += 1
    end
  end
  
  def self.CompFollow(p)
    n = s = nil
    while (p>0 && !@@visited.get(p)) do
      n = GraphNode.Node(p)
      @@visited.set(p)
      if (n.typ==Nt) then
	s = First(n.next.abs)
	@@follow[n.p1-Sym.firstNt].ts.or(s)
	if (GraphNode.DelGraph(n.next.abs)) then
	  @@follow[n.p1-Sym.firstNt].nts.set(@@curSy-Sym.firstNt)
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
      while (j<=Sym.lastNt-Sym.firstNt) do # for all nonterminals
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
    @@curSy = Sym.firstNt
    while (@@curSy<=Sym.lastNt) do
      s = FollowSet.new()
      s.ts = BitSet.new()
      s.nts = BitSet.new()
      @@follow[@@curSy-Sym.firstNt] = s
      @@curSy += 1
    end

    @@visited = BitSet.new()

    @@curSy = Sym.firstNt
    while (@@curSy<=Sym.lastNt) do # get direct successors of nonterminals
      CompFollow(Sym.sy[@@curSy].struct)
      @@curSy += 1
    end

    @@curSy = 0
    while (@@curSy<=Sym.lastNt-Sym.firstNt) do # add indirect successors to follow.ts
      @@visited = BitSet.new()
      Complete(@@curSy)
      @@curSy += 1
    end
  end

  def self.LeadingAny(p)
    n = a = nil

    if (p <= 0) then
      return nil
    end

    n = GraphNode.Node(p)

    if (n.typ==Any) then
      a = n
    elsif (n.typ==Alt) then
      a = LeadingAny(n.p1)
      if (a.nil?) then
	a = LeadingAny(n.p2)
      end
    elsif (n.typ==Opt || n.typ==Iter) then
      a = LeadingAny(n.p1)
    elsif (GraphNode.DelNode(n)) then
      a = LeadingAny(n.next)
    end

    return a
  end

  def self.FindAS(p)
    n = nod = a = s1 = s2 = nil
    q = 0

    while (p > 0) do
      n = GraphNode.Node(p)
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
	  nod = GraphNode.Node(q)
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
    @@curSy = Sym.firstNt
    while (@@curSy<=Sym.lastNt) do
      FindAS(Sym.sy[@@curSy].struct)
      @@curSy += 1
    end
  end

  def self.Expected(p, sp)
    s = First(p)
    if (GraphNode.DelGraph(p)) then
      s.or(@@follow[sp-Sym.firstNt].ts)
    end
    return s
  end

  def self.CompSync(p)
    n = s = nil
    while (p > 0 && !@@visited.get(p)) do
      n = GraphNode.Node(p)
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
    @@curSy = Sym.firstNt
    while (@@curSy <= Sym.lastNt) do
      CompSync(Sym.sy[@@curSy].struct)
      @@curSy += 1
    end
  end

  def self.CompDeletableSymbols
    i = 0
    changed = true
    begin
      changed = false

      i = Sym.firstNt
      while (i<=Sym.lastNt) do
	if (!Sym.sy[i].deletable && GraphNode.DelGraph(Sym.sy[i].struct)) then
	  Sym.sy[i].deletable = true
	  changed = true
	end
	i += 1
      end
    end while (changed)

    for i in Sym.firstNt..Sym.lastNt do
      if (Sym.sy[i].deletable) then
	puts("  " + Sym.sy[i].name + " deletable") # FIX
	$stdout.flush
      end
      i += 1
    end
  end

  def self.MovePragmas
    if (Sym.maxP > Sym.firstNt) then
      Sym.maxP = Sym.maxT
      i = Sym::MaxSymbols - 1
      while (i > Sym.lastNt) do
	Sym.maxP += 1
	assert(Sym.maxP < Sym.firstNt, 6)
	Sym.sy[Sym.maxP] = Sym.sy[i]
	i -= 1
      end
    end
  end

  def self.CompSymbolSets
    i = Sym.NewSym(T, "???", 0)
    # unknown symbols get code Sym.maxT
    MovePragmas()
    CompDeletableSymbols()

    @@first = Array.new(Sym.lastNt-Sym.firstNt+1)
    @@follow = Array.new(Sym.lastNt-Sym.firstNt+1)

    CompFirstSets()
    CompFollowSets()
    CompAnySets()
    CompSyncSets()
    if (@@ddt[1]) then
      Trace.println("First & follow symbols:")

      i = Sym.firstNt
      while (i<=Sym.lastNt) do
	Trace.println(Sym.sy[i].name)
	Trace.print("first:   ")
	PrintSet(@@first[i-Sym.firstNt].ts, 10)
	Trace.print("follow:  ")
	PrintSet(@@follow[i-Sym.firstNt].ts, 10)
	Trace.println()
	i += 1
      end

      if (@@maxSet >= 0) then
	Trace.println()
	Trace.println()
	Trace.println("List of sets (ANY, SYNC): ")
	i = 0
	while (i<=@@maxSet) do
	  Trace.print("     set[#{i}] = ")
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

    n = GraphNode.Node(p)

    if (n.typ==Nt) then
      if (GraphNode.DelGraph(n.next.abs)) then
	singles.set(n.p1)
      end
    elsif (n.typ==Alt || n.typ==Iter || n.typ==Opt) then
      if (GraphNode.DelGraph(n.next.abs)) then
	GetSingles(n.p1, singles)
	if (n.typ==Alt) then
	  GetSingles(n.p2, singles)
	end
      end
    end

    if (GraphNode.DelNode(n)) then
      GetSingles(n.next, singles)
    end
  end

  def self.NoCircularProductions
    ok = changed = onLeftSide = onRightSide = false
    list = Array.new(150) # FIX: constify
    x = singles = sym = nil
    i = j = len = 0

    for i in Sym.firstNt..Sym.lastNt do
      singles = BitSet.new()
      GetSingles(Sym.sy[i].struct, singles)
      # get nts such that i-->j
      for j in Sym.firstNt..Sym.lastNt do
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
	puts("  "+Sym.sy[list[i].left].name+" --> "+Sym.sy[list[i].right].name)
      end
    end

    return ok
  end

  def self.LL1Error(cond, ts)
    print("  LL1 warning in " + Sym.sy[@@curSy].name + ": ")
    print(Sym.sy[ts].name + " is ") if (ts > 0)

    case cond
    when 1
      puts " start of several alternatives"
    when 2
      puts " start & successor of deletable structure"
    when 3
      puts " an ANY node that matches no symbol"
    end
    STDOUT.flush
  end

  def self.Overlap(s1, s2, cond)
    overlap = false

    for i in 0..Sym.maxT do
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
      n = GraphNode.Node(p)
      if (n.typ==Alt) then
	q = p
	s1 = BitSet.new()
	while (q != 0) do # for all alternatives
	  a = GraphNode.Node(q)
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
    for @@curSy in Sym.firstNt..Sym.lastNt do
      ll1 = false if (AltOverlap(Sym.sy[@@curSy].struct)) 
    end
    return ll1
  end

  def self.NtsComplete
    complete = true
    
    for i in Sym.firstNt..Sym.lastNt do
      if (Sym.sy[i].struct==0) then
	complete = false
	puts("  No production for " + Sym.sy[i].name)
      end
    end

    return complete
  end

  def self.MarkReachedNts(p)
    n = nil

    while (p > 0) do
      n = GraphNode.Node(p)
      if (n.typ==Nt) then
	if (!@@visited.get(n.p1)) then # new nt reached
	  @@visited.set(n.p1)
	  MarkReachedNts(Sym.sy[n.p1].struct)
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

    MarkReachedNts(Sym.Sym(@@gramSy).struct)

    for i in Sym.firstNt..Sym.lastNt do
      if (!@@visited.get(i)) then
	ok = false
	puts("  " + Sym.sy[i].name + " cannot be reached")
      end
    end
    return ok
  end

  def self.Term(p) # true if graph can be derived to terminals
    n = nil

    while (p > 0) do
      n = GraphNode.Node(p)
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
      for i in Sym.firstNt..Sym.lastNt do
	if (!@@termNt.get(i) && Term(Sym.sy[i].struct)) then
	  @@termNt.set(i)
	  changed = true
	end
      end
    end while changed

    for i in Sym.firstNt..Sym.lastNt do
      if (!@@termNt.get(i)) then
	ok = false
	puts "  " + Sym.sy[i].name + "cannot be derived to terminals"
      end
    end

    return ok
  end

# ---------------------------------------------------------------------
#   Utility functions
# ---------------------------------------------------------------------

  def self.PrintSymbolTable

    Trace.println("Symbol Table:")
    Trace.println(" nr name       typ  hasAt struct del   line")
    Trace.println()
    i = 0
    while (i < Sym::MaxSymbols) do
      Trace.print(sprintf("%3d %-10.10s %s", i, Sym.sy[i].name, @@nTyp[Sym.sy[i].typ]))
      if (Sym.sy[i].attrPos==nil) then
	Trace.print(" false ")
      else
	Trace.print(" true  ")
      end

      Trace.print(sprintf("%5d", Sym.sy[i].struct))
      if (Sym.sy[i].deletable) then
	Trace.print(" true  ")
      else
	Trace.print(" false ")
      end

      Trace.println(sprintf("%5d", Sym.sy[i].line))

      if (i==Sym.maxT) then
	i = Sym.firstNt
      else
	i += 1
      end
    end
    Trace.println()
  end

  def self.XRef

    sym = n = p = q = x = nil
    list = Array.new(Sym.lastNt + 1) # XNode[] list = new XNode[Sym.lastNt+1]
    i = col = 0
    
    return if (Sym.maxT <= 0) 

    MovePragmas()

    # search lines where symbol has been referenced
    i = @@nNodes
    while (i>=1) do
      n = GraphNode.Node(i);
      if (n.typ==T || n.typ==Wt || n.typ==Nt) then
	p = XNode.new();
	p.line = n.line;
	p.next = list[n.p1];
	list[n.p1] = p;
      end
      i -= 1
    end

    # search lines where symbol has been defined and insert in order
    i = 1;
    while (i <= Sym.lastNt) do
      sym = Sym.Sym(i);
      p = list[i];
      q = nil;
      while (p != nil && sym.line > p.line) do
	q = p;
	p = p.next;
      end
      x = XNode.new();
      x.line = -sym.line;
      x.next = p;
      if (q==nil) then
	list[i] = x;
      else 
	q.next = x;
      end
      if (i==Sym.maxP) then
	i = Sym.firstNt;
      else 
	i += 1
      end
    end

    # print cross reference list
    Trace.println();
    Trace.println("Cross reference list:");
    Trace.println();
    Trace.println("Terminals:");
    Trace.println("  0 EOF");
    i = 1;

    while (i <= Sym.lastNt) do
      Trace.print(sprintf("%3d %s  ", i, Sym.sy[i].name))
      p = list[i];
      col = 25;
      while (p != nil) do
	if (col + 5 > 80) then
	  Trace.println();
	  Trace.print(" " * 24);
	  col = 25
	end
	if (p.line==0)
	  Trace.print("undef  ");
	else
	  Trace.print("#{p.line}  ");
	end
	col = col + 5;
	p = p.next;
      end
      Trace.println();
      if (i==Sym.maxT) then
	Trace.println();
	Trace.println("Pragmas:");
      end
      if (i==Sym.maxP) then
	Trace.println();
	Trace.println("Nonterminals:");
	i = Sym.firstNt;
      else
	i += 1
      end
    end
    Trace.println();
    Trace.println();

  end

  ############################################################
  # START OF HACKS

  def self.t # HACK
    raise "Um. no"
  end

end
