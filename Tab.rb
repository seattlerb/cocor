
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

  def initialize(beg, len, col)
    @beg = beg
    @len = len
    @col = col
  end

  def ==(o)
    ! o.nil? &&
      @beg == o.beg &&
      @len == o.len &&
      @col == o.col
  end
end

# RENAMED from Symbol
class Sym

  class << self
    include Enumerable
  end

  EofSy = 0
  NoSym = nil
  ClassToken    = 0		# token kinds
  LitToken      = 1
  ClassLitToken = 2
  MaxSymbols    = 512		# max. no. of t, nt, and pragmas

  # FIX: nuke me... use iterators for real
  @@maxP = MaxSymbols			# pragmas stored from maxT+1 to maxP
  @@maxT = -1				# terminals stored from 0 to maxT
  @@firstNt = MaxSymbols		# idx of first nt:available after CompSymbolSets
  @@lastNt = @@maxP - 1		# index of last nt: available after CompSymbolSets

  # 0       .. maxT		== terminals
  # firstNt .. lastNt		== non-terminals
  # maxP    .. MaxSymbols-1	== pragmas
  @@terminals = []
  @@pragmas = []
  @@nonterminals = []

  @@stupidhack=true # HACK HACK HACK
  def self.MovePragmas
    if @@stupidhack then
      @@maxP = index = self.terminal_count - 1
      self.each_pragma do |sym|
	@@maxP += 1
	sym.n = @@maxP
      end
      @@stupidhack=false
    end
  end

  # TODO: get rid of these
  cls_attr_accessor :firstNt

  attr_accessor :n			# symbol number
  attr_accessor :typ			# t, nt, pr, unknown
  attr_accessor :name			# symbol name
  attr_accessor :graph			# nt: first node of syntax graph
					# t:  token kind (literal, class, ...)
  attr_accessor :deletable		# nt: true if nonterminal is deletable
  attr_accessor :attrPos		# position of attributes in source text (or null)
  attr_accessor :retType		# nt: Type of output attribute (or null)
  attr_accessor :retVar			# nt: Name of output attribute (or null)
  attr_accessor :semPos			# pr: pos of semantic action in source text (or null)
					# nt: pos of local declarations in source text (or null)
  attr_accessor :line			# source text line number of item in this node
  attr_accessor :n			# index in the array, currently @sy, but soon to be the actual array it is stored in

  def initialize(typ=0, name="", line=0)
    @typ  = typ
    @name = name
    @line = line
    @n = -1
    @graph = nil
    @deletable = @attrPos = @semPos = nil
    @retType = @retVar = nil	# strings

    assert(@@maxT+1 < @@firstNt, 6)

    case typ 
    when Node::T
      @@maxT += 1
      @n = @@maxT
      @@terminals.push self
    when Node::Pr
      @@maxP -= 1
      @@firstNt -= 1
      @@lastNt -= 1
      @n = @@maxP
      @@pragmas.unshift self
    when Node::Nt
      @@firstNt -= 1
      @n = @@firstNt
      @@nonterminals.unshift self
    end

    assert(@@maxT+1 < @@firstNt, 6)
  end

  def ==(o)
    if o.kind_of?(Fixnum) then
      $stderr.puts "WARNING: Sym#== called with int from #{caller[0]}"
      return self.n == o
    else
      return false if o.nil?
      return true if self.object_id == o.object_id
      
      return @typ == o.typ && @name == o.name && @line == o.line && @n == o.n && @graph == o.graph && @deletable == o.deletable && @attrPos == o.attrPos && @semPos == o.semPos && @retType = o.retType && @retVar == o.retVar
    end
  end

  def self.terminal_count
    return @@terminals.size
  end

  def self.nonterminal_count
    return @@nonterminals.size
  end
  
  def self.symbol_count
    return @@terminals.size + @@nonterminals.size + @@pragmas.size
  end

  def self.each(&b)
    each_terminal(&b)
    each_pragma(&b)
    each_nonterminal(&b)
  end

  def self.each_both_terminals(&b) # REFACTOR: terrible name
    @@terminals.each(&b)
    @@nonterminals.each(&b)
  end

  def self.each_terminal(&b)
    @@terminals.each(&b)
  end

  def self.each_nonterminal(&b)
    @@nonterminals.each(&b)
  end

  def self.each_pragma(&b)
    @@pragmas.each(&b)
  end

  def self.FindSym(name)

    return @@terminals.detect { |s| s.name == name } || @@nonterminals.detect { |s| s.name == name } || NoSym

  end

  def to_s
    self.n.to_s
  end
  
end

class Node

  class << self
    include Enumerable
  end

  NormTrans    = 0		# transition codes
  ContextTrans = 1
  MaxNodes = 1500		# max. no. of graph nodes
  T    = 1			# node kinds
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

  @@nTyp = [ "    ", "t   ", "pr  ", "nt  ", "clas", "chr ", "wt  ",
             "any ", "eps ", "sync", "sem ", "alt ", "iter", "opt " ]
  @@gn = Array.new(0, :Node)		# grammar graph

  # TODO: get rid of these
  cls_attr_accessor :nTyp

  attr_accessor :n			# node number
  attr_accessor :typ			# t, nt, wt, chr, clas, any, eps, sem, sync, alt, iter, opt
  attr_reader :nxt			# successor node
					# nxt<0: to successor in enclosing structure
  attr_accessor :down			# alt: next alterative Node
  attr_accessor :sub			# alt, iter, opt: first node of substructure
  attr_accessor :up			# successor in enclosing structure
  attr_accessor :sym			# nt, t, wt: symbol of this node
  attr_accessor :val			# chr: ordinal character value
					# cls: index of character class
  attr_accessor :code			# chr, clas: transition code
  attr_accessor :set			# any, sync: set represented by node
  attr_accessor :pos			# nt, t, wt: pos of actual attributes
					# sem:       pos of semantic action in source text
  attr_accessor :retVar			# nt: name of output attribute (or null)
  attr_accessor :line			# source text line number of item in this node
  attr_accessor :state			# DFA state corresponding to this node
					# (only used in Sgen.ConvertToStates)

  def initialize(typ, val, line)

    assert(@@gn.length <= Node::MaxNodes, 3)

    @typ = typ
    @line = line
    @n = @@gn.length

    @up = false
    @nxt = @pos = @retVar = @state = @down = @sub = @set = @sym = nil
    @code = @val = -1

    case @typ
    when Nt, T, Wt then
      @sym = val
    when Any, Sync then
      @set = val
    when Alt, Iter, Opt then
      @sub = val
    when Chr, Clas then
      @val = val
    end

    @@gn.push self
  end

  def self.each(&b)
    @@gn.each(&b)
  end

  def node_type
    return @@nTyp[@typ]
  end

  def nxt=(o)
    raise "Node#nxt= called with int" if o.kind_of? Fixnum
    @nxt = o
  end

  def ==(o)

    raise "Node.== called with Fixnum" if o.kind_of? Fixnum
    return true if self.object_id == o.object_id
    return false unless @typ == o.typ

    r = false

    case @typ
    when Nt, T, Wt then
      r = @sym == o.sym
    when Any, Sync then
      r = @set == o.set
    when Alt, Iter, Opt then
      r = @sub.equal?(o.sub)
    when Chr, Clas then
      r = @val == o.val
    when Eps, Pr, Sem then
    else
      raise "typ is not set (#{@typ}) in call to Node#=="
    end

    return r && @typ == o.typ && @line == o.line && @nxt.equal?(o.nxt) && @down.equal?(o.down) && @code == o.code && @pos == o.pos && @retVar == o.retVar && @state == o.state
  end
  
  def self.NodeCount
    return @@gn.length - 1
  end

  def self.EraseNodes
    @@gn = Array.new(0, :Node)		# grammar graph
    @@gn.pop
  end

  def self.DelGraph(p)
    return true if p.nil? # end of graph found
    return DelNode(p) && DelGraph(p.nxt)
  end

  def self.DelAlt(p)
    return true if p.nil?
    return DelNode(p) && DelAlt(p.nxt)
  end

  def self.DelNode(n)
    if (n.typ==Node::Nt) then
      return n.sym.deletable
    elsif (n.typ==Node::Alt) then
      return DelAlt(n.sub) || !n.down.nil? && DelAlt(n.down)
    else
      return n.typ==Node::Eps || n.typ==Node::Iter || n.typ==Node::Opt || n.typ==Node::Sem || n.typ==Node::Sync
    end
  end

  def to_s
    v1 = case @typ
	 when Nt, T, Wt then
	   @sym.n
	 when Any, Sync then
	   @set
	 when Alt, Iter, Opt then
	   @sub.n
	 when Chr, Clas then
	   @val
	 else
	   0
	 end
    v2 = case @typ
	 when Opt then
	   @down.nil? ? 0 : @down.n
	 when Chr, Clas then
	   @code
	 else
	   0
	 end

    nxt = @nxt.nil? ? 0 : @nxt.n
    return sprintf("%4d %s%5d%5d%5d%5d", @n, node_type, nxt, v1, v2, @line)
  end

  def self.PrintGraph
    n = nil
    Trace.println("Graph:")
    Trace.println("  nr typ  next   v1   v2 line")

    Node.each do |n|
      Trace.println(n)
    end
    Trace.println()
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

  # TODO: get rid of these
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
    raise "WARNING: Class(#{i})" if ! i.kind_of?(Fixnum) && i.nil?
    raise "WARNING: Class(#{i}=>nil)" if ! @@chClass[i].set.kind_of?(Fixnum) && @@chClass[i].set.nil?
    return Tab.set[@@chClass[i].set]
  end

  def self.ClassName(i)
    return @@chClass[i].name
  end

end

class Graph

  attr_reader :l			# left end of graph = head
  attr_reader :r			# right end of graph = list of nodes to be linked to successor graph

  def initialize
    @l = @r = nil
  end

  def ==(o)
    raise "Not implemented yet"
  end

  def l=(o)
    raise "Graph.l= called with Fixnum" if o.kind_of? Fixnum
    @l = o
  end

  def r=(o)
    raise "Graph.r= called with Fixnum" if o.kind_of? Fixnum
    @r = o
  end

  def to_s
    raise "no"
    "<Graph@#{self.id}: #{@l}, #{@r}>"
  end
  
  def self.FirstAlt(g)
    g.l = Node.new(Node::Alt, g.l, 0)
    g.l.nxt = g.r
    g.r = g.l
    return g
  end

  def self.Alternative(g1, g2)
    g2.l = Node.new(Node::Alt, g2.l, 0)
    p = g1.l
    until (p.down.nil?) do
      p = p.down
    end
    p.down = g2.l
    p = g1.r 
    until (p.nxt.nil?) do
      p = p.nxt
    end
    p.nxt = g2.r
    return g1
  end

  def self.Sequence(g1, g2)
    q = nil
    p = g1.r.nxt
    g1.r.nxt = g2.l # head node
    until (p.nil?) do # substructure
      q = p.nxt
      p.nxt = g2.l
      p.up = true
      p = q
    end
    g1.r = g2.r
    return g1
  end

  def self.Iteration(g)
#    $stderr.puts "Iteration(#{g.inspect})"
    g.l = Node.new(Node::Iter, g.l, 0)
    p = g.r
    g.r = g.l
    until (p.nil?) do
      q = p.nxt
      p.nxt = g.l
      p.up = true
      p = q
    end
    return g
  end

  def self.Option(g)
    g.l = Node.new(Node::Opt, g.l, 0)
    g.l.nxt = g.r
    g.r = g.l
    return g
  end

  def self.CompleteGraph(p)
    until (p.nil?) do
      q = p.nxt
      p.nxt = nil
      p = q
    end
  end

  # ---------------------------------------------------------------------
  #   topdown graph management
  # ---------------------------------------------------------------------

  def self.StrToGraph(s)
    g = Graph.new
    temp = Node.new(Node::Eps, nil, 0)
    g.r = temp

    raise "g.r is messed up" if g.r.nil?
    raise "s is messed up" if s.length <= 2

    s[1..-2].each_byte do | c |
      p = Node.new(Node::Chr, c, 0)
      g.r.nxt = p
      g.r = p
    end
    
    g.l = temp.nxt
    temp.nxt = nil

    return g
  end

end

# REFACTOR: move this into Node
class XNode				# node of cross reference list
  attr_accessor :line
  attr_accessor :nxt

  def initialize
    @line = 0
    @nxt = nil
  end

  def ==(o)
    !o.nil? && @line == o.line && @nxt == o.nxt
  end
  
end

class CNode				# node of list for finding circular productions
    attr_accessor :left
    attr_accessor :right
    attr_accessor :deleted

  def initialize
    @left = @right = nil
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

  # --- variables ---
  @@maxSet = nil			# index of last set
  @@semDeclPos = nil			# position of global semantic declarations
  @@importPos = nil			# position of imported identifiers
  @@ignored = nil			# characters ignored by the scanner
  @@ddt = Array.new(10, false)		# debug and test switches
  @@gramSy = 0				# root nonterminal filled by ATG # FIX - nil
  @@first = nil				# first[i] = start symbols of sy[i+Sym.firstNt]
  @@follow = nil	 		# follow[i] = followers of sy[i+Sym.firstNt]

  # REFACTOR: NUKE ME
  @@set = Array.new(128)		# set[0] = union of all synchr. sets

  @@err = nil				# error messages
  @@visited = nil 
  @@termNt = nil 			# mark lists for graph traversals
  @@curSy = 0				# current symbol in computation of sets

  # TODO: get rid of these
  cls_attr_accessor :ignored, :semDeclPos, :gramSy, :ddt, :set

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
    @@set[0].set(Sym::EofSy)

    Node.EraseNodes # TODO: remove me... stupid bastards
  end

  # ---------------------------------------------------------------------
  #   Symbol set computations
  # ---------------------------------------------------------------------

  def self.PrintSet(s, indent)
    i = len = 0
    col = indent

    Sym.each_terminal do |sym|
      if (s.get(sym.n)) then
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
    s1 = s2 = nil
    fs = BitSet.new

    while (!p.nil? && !mark.get(p.n)) do
      mark.set(p.n)
		 
      case (p.typ)
      when Node::Nt then
	if (@@first[p.sym.n-Sym.firstNt].ready) then
	  fs.or(@@first[p.sym.n-Sym.firstNt].ts)
	else 
	  fs.or(self.First0(p.sym.graph, mark))
	end
      when Node::T, Node::Wt then
	fs.set(p.sym.n)
      when Node::Any then
	fs.or(@@set[p.set])
      when Node::Alt, Node::Iter, Node::Opt then
	fs.or(self.First0(p.sub, mark))
	if (p.typ==Node::Alt) then
	  fs.or(self.First0(p.down, mark))
	end
      end
      if (!Node.DelNode(p)) then
	break
      end
      p = p.nxt
    end
    return fs
  end
  
  def self.First(p)
    fs = First0(p, BitSet.new(Node.NodeCount+1))
    if (@@ddt[3]) then
      Trace.println()
      Trace.println("First: gp = #{p}")
      PrintSet(fs, 0)
    end
    return fs
  end

  def self.CompFirstSets

    # FIX: this whole thing seems stupid... why are we iterating twice?

    Sym.each_nonterminal do |sym|
      s = FirstSet.new() # FIX: use a constructor for real damnit
      s.ts = BitSet.new()
      s.ready = false
      @@first[sym.n-Sym.firstNt] = s
    end

    Sym.each_nonterminal do |sym|
      @@first[sym.n-Sym.firstNt].ts = self.First(sym.graph)
      @@first[sym.n-Sym.firstNt].ready = true
    end
  end
  
  def self.CompFollow(p)
    s = nil
    while (!p.nil? && !@@visited.get(p.n)) do
      @@visited.set(p.n)
      if (p.typ==Node::Nt) then
	s = First(p.nxt)
	@@follow[p.sym.n-Sym.firstNt].ts.or(s)
	if (Node.DelGraph(p.nxt)) then
	  @@follow[p.sym.n-Sym.firstNt].nts.set(@@curSy.n-Sym.firstNt)
	end
      elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
	CompFollow(p.sub)
      elsif (p.typ==Node::Alt) then
	CompFollow(p.sub)
	CompFollow(p.down)
      end
      p = p.nxt
    end
  end

  def self.Complete(i)
    if (!@@visited.get(i)) then
      @@visited.set(i)
      j = 0
      max = Sym.nonterminal_count - 1
      while (j <= max) do # for all nonterminals
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
    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX: bad use of globals
      s = FollowSet.new()
      s.ts = BitSet.new()
      s.nts = BitSet.new()
      @@follow[@@curSy.n-Sym.firstNt] = s
    end

    @@visited = BitSet.new()

    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX: this is a bad use of globals!
      CompFollow(sym.graph)
    end

    @@curSy = 0
    max = Sym.nonterminal_count - 1 # FIX: this is still terrible
    while (@@curSy<=max) do # add indirect successors to follow.ts
      @@visited = BitSet.new()
      Complete(@@curSy) # FIX
      @@curSy += 1
    end
  end

  def self.LeadingAny(p)
    a = nil

    return nil if p.nil?

    if (p.typ==Node::Any) then
      a = p
    elsif (p.typ==Node::Alt) then
      a = LeadingAny(p.sub)
      if (a.nil?) then
	a = LeadingAny(p.down)
      end
    elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
      a = LeadingAny(p.sub)
    elsif (Node.DelNode(p)) then
      a = LeadingAny(p.nxt)
    end

    return a
  end

  def self.FindAS(p)
    nod = a = s1 = s2 = nil
    q = nil

    until (p.nil?) do
      if (p.typ==Node::Opt || p.typ==Node::Iter) then
	FindAS(p.sub)
	a = LeadingAny(p.sub)
	unless (a.nil?) then
	  s1 = First(p.nxt)
	  Sets.Differ(@@set[a.set], s1)
	end
      elsif (p.typ==Node::Alt) then
	s1 = BitSet.new()
	q = p
	until (q.nil?) do
	  FindAS(q.sub)
	  a = LeadingAny(q.sub)
	  unless (a.nil?) then
	    s2 = First(q.down)
	    s2.or(s1)
	    Sets.Differ(@@set[a.set], s2)
	  else
	    s1.or(First(q.sub))
	  end
	  q = q.down
	end
      end
      break if p.up
      p = p.nxt
    end
  end

  def self.CompAnySets()
    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX : bad use of globals
      FindAS(sym.graph)
    end
  end

  def self.Expected(p, sp)
    s = First(p)
    if (Node.DelGraph(p)) then
      s.or(@@follow[sp.n-Sym.firstNt].ts)
    end
    return s
  end

  def self.CompSync(p)
    s = nil
    while (!p.nil? && !@@visited.get(p.n)) do
      @@visited.set(p.n)
      if (p.typ==Node::Sync) then
	s = Expected(p.nxt, @@curSy)
	s.set(Sym::EofSy)
	@@set[0].or(s)
	p.set = NewSet(s)
      elsif (p.typ==Node::Alt) then
	CompSync(p.sub)
	CompSync(p.down)
      elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
	CompSync(p.sub)
      end
      p = p.nxt
    end
  end

  def self.CompSyncSets
    @@visited = BitSet.new()

    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX: bad use of global
      CompSync(sym.graph)
    end
  end

  def self.CompDeletableSymbols
    i = 0
    changed = true
    begin
      changed = false

      Sym.each_nonterminal do |sym|
	if (!sym.deletable && Node.DelGraph(sym.graph)) then
	  sym.deletable = true
	  changed = true
	end
      end
    end while (changed)

    Sym.each_nonterminal do |sym|
      if (sym.deletable) then
	puts("  #{sym.name} deletable")
	$stdout.flush
      end
    end
  end

  def self.CompSymbolSets
    i = Sym.new(Node::T, "???", 0)
    # unknown symbols get code Sym.maxT
    Sym.MovePragmas()
    CompDeletableSymbols()

    @@first  = Array.new(Sym.nonterminal_count)
    @@follow = Array.new(Sym.nonterminal_count)

    CompFirstSets()
    CompFollowSets()
    CompAnySets()
    CompSyncSets()
    if (@@ddt[1]) then
      Trace.println("First & follow symbols:")

      Sym.each_nonterminal do |sym|
	Trace.println(sym.name)
	Trace.print("first:   ")
	PrintSet(@@first[sym.n-Sym.firstNt].ts, 10)
	Trace.print("follow:  ")
	PrintSet(@@follow[sym.n-Sym.firstNt].ts, 10)
	Trace.println()
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
    return if p.nil? # end of graph

    if (p.typ==Node::Nt) then
      if (Node.DelGraph(p.nxt)) then
	singles.set(p.sym.n)
      end
    elsif (p.typ==Node::Alt || p.typ==Node::Iter || p.typ==Node::Opt) then
      if (Node.DelGraph(p.nxt)) then
	GetSingles(p.sub, singles)
	if (p.typ==Node::Alt) then
	  GetSingles(p.down, singles)
	end
      end
    end

    if (Node.DelNode(p)) then
      GetSingles(p.nxt, singles)
    end
  end

  def self.NoCircularProductions
    ok = changed = onLeftSide = onRightSide = false
    list = Array.new(Tab::MaxTerminals)
    x = singles = sym = nil
    i = j = len = 0

    Sym.each_nonterminal do |sym1|
      singles = BitSet.new()
      GetSingles(sym1.graph, singles)
      # get nts such that i-->j
      Sym.each_nonterminal do |sym2|
	if (singles.get(sym2.n)) then
	  x = CNode.new
	  x.left = sym1.n
	  x.right = sym2.n
	  x.deleted = false
	  list[len] = x # FIX: just push damnit
	  len += 1 # FIX: nuke
	end
      end
    end

    begin
      changed = false
      for i in 0...len do # FIX: enumerate
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
	puts("  #{list[i].left.name} --> #{list[i].right.name}")
      end
    end

    return ok
  end

  def self.LL1Error(cond, ts)
    print("  LL1 warning in #{@@curSy.name}: ")
    print("#{ts.name} is ") if (ts.n > 0) # HACK: why zero?

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

    Sym.each_terminal do |sym|
      if (s1.get(sym.n) && s2.get(sym.n)) then
	LL1Error(cond, sym)
	overlap = true
      end
    end

    return overlap
  end

  def self.AltOverlap(p)
    overlap = false
    s1 = s2 = nil
    q = nil

    until (p.nil?) do
      if (p.typ==Node::Alt) then
	q = p
	s1 = BitSet.new()
	until (q.nil?) do # for all alternatives
	  s2 = Expected(q.sub, @@curSy)
	  overlap = true if (Overlap(s1, s2, 1)) 
	  s1.or(s2)
	  overlap = true if (AltOverlap(q.sub)) 
	  q = q.down
	end
      elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
	s1 = Expected(p.sub, @@curSy)
	s2 = Expected(p.nxt, @@curSy)
	overlap = true if (Overlap(s1, s2, 2)) 
	overlap = true if (AltOverlap(p.sub)) 
      elsif (p.typ==Node::Any) then
	if (Sets.Empty(Set(p.set))) then # e.g. {ANY} ANY or [ANY] ANY
	  LL1Error(3, 0)
	  overlap = true
	end

      end
      break if p.up
      p = p.nxt
    end

    return overlap
  end

  def self.LL1()
    ll1 = true
    
    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX: bad use of globals
      ll1 = false if AltOverlap(sym.graph)
    end

    return ll1
  end

  def self.NtsComplete
    complete = true
    
    Sym.each_nonterminal do |sym|
      if (sym.graph.nil?) then
	complete = false
	puts("  No production for #{sym.name}")
      end
    end

    return complete
  end

  def self.MarkReachedNts(p)
    until (p.nil?) do
      if (p.typ==Node::Nt) then
	if (!@@visited.get(p.sym.n)) then # new nt reached
	  @@visited.set(p.sym.n)
	  MarkReachedNts(p.sym.graph)
	end
      elsif (p.typ==Node::Alt || p.typ==Node::Iter || p.typ==Node::Opt) then
	MarkReachedNts(p.sub)
	MarkReachedNts(p.down) if (p.typ==Node::Alt)
      end
      break if p.up
      p = p.nxt
    end
  end

  def self.AllNtReached
    n = nil
    ok = true
    @@visited = BitSet.new()
    @@visited.set(@@gramSy.n)

    MarkReachedNts(@@gramSy.graph)

    Sym.each_nonterminal do |sym|
      if (!@@visited.get(sym.n)) then
	ok = false
	puts("  #{sym.name} cannot be reached")
      end
    end
    return ok
  end

  def self.Term(p) # true if graph can be derived to terminals
    n = nil

    until (p.nil?) do
      return false if (p.typ==Node::Nt  && !@@termNt.get(p.sym.n))
      return false if (p.typ==Node::Alt && !Term(p.sub) && (p.down.nil? || !Term(p.down)))
      break if p.up
      p = p.nxt
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
      Sym.each_nonterminal do |sym|
	if (!@@termNt.get(sym.n) && Term(sym.graph)) then
	  @@termNt.set(sym.n)
	  changed = true
	end
      end
    end while changed

    Sym.each_nonterminal do |sym|
      if (!@@termNt.get(sym.n)) then
	ok = false
	puts "  #{sym.name} cannot be derived to terminals"
      end
    end

    return ok
  end

# ---------------------------------------------------------------------
#   Utility functions
# ---------------------------------------------------------------------

  def self.PrintSym(sym)
      Trace.print(sprintf("%3d %-10.10s %s", sym.n, sym.name, Node.nTyp[sym.typ]))
      if (sym.attrPos==nil) then
	Trace.print(" false ")
      else
	Trace.print(" true  ")
      end

      graph = sym.graph
      case graph
      when NilClass
	graph = 0
      when Fixnum
      when Node
	graph = graph.n
      else
	raise "struct broken!!!"
      end

      Trace.print(sprintf("%5d", graph))
      if (sym.deletable) then
	Trace.print(" true  ")
      else
	Trace.print(" false ")
      end

      Trace.println(sprintf("%5d", sym.line))
  end

  def self.PrintSymbolTable

    Trace.println("Symbol Table:")
    Trace.println(" nr name       typ  hasAt struct del   line")
    Trace.println()

    Sym.each_terminal    { |sym| PrintSym(sym) }
    Sym.each_pragma      { |sym| PrintSym(sym) }
    Sym.each_nonterminal { |sym| PrintSym(sym) }

    Trace.println()
  end

  def self.PrintXRef(list, sym)
    Trace.print(sprintf("%3d %s  ", sym.n, sym.name))
    p = list[sym.n];
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
      p = p.nxt;
    end
    Trace.println();
  end

  def self.XRef

    sym = n = p = q = x = nil
    list = []
    i = col = 0
    
    return if (Sym.terminal_count <= 0) 

    Sym.MovePragmas()

    # search lines where symbol has been referenced
    Node.each do |n|
      if (n.typ==Node::T || n.typ==Node::Wt || n.typ==Node::Nt) then
	p = XNode.new();
	p.line = n.line;
	p.nxt = list[n.sym.n];
	list[n.sym.n] = p;
      end
    end

    # search lines where symbol has been defined and insert in order
    i = 1;
    Sym.each do |sym|
      p = list[sym.n];
      q = nil;
      while (p != nil && sym.line > p.line) do
	q = p;
	p = p.nxt;
      end
      x = XNode.new();
      x.line = -sym.line;
      x.nxt = p;
      if (q==nil) then
	list[sym.n] = x;
      else 
	q.nxt = x;
      end
    end

    # print cross reference list
    Trace.println();
    Trace.println("Cross reference list:");
    Trace.println();
    Trace.println("Terminals:");
    Trace.println("  0 EOF");
    Sym.each_terminal    { |sym| PrintXRef(list, sym) }
    Trace.println();
    Trace.println("Pragmas:");
    Sym.each_pragma      { |sym| PrintXRef(list, sym) }
    Trace.println();
    Trace.println("Nonterminals:");
    Sym.each_nonterminal { |sym| PrintXRef(list, sym) }
    Trace.println();
    Trace.println();

  end
end
