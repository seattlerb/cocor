
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

# NOTE: renamed from Symbol
class Sym

  class << self
    include Enumerable
  end

  @@terminals = []
  @@pragmas = []
  @@nonterminals = []

  EofSy = 0
  NoSym = nil
  ClassToken    = 0		# token kinds
  LitToken      = 1
  ClassLitToken = 2
  MaxSymbols    = 512		# max. no. of t, nt, and pragmas

  attr_accessor :n			# symbol number
  attr_accessor :typ			# t, nt, pr, unknown
  attr_accessor :name			# symbol name
  attr_accessor :graph			# nt: first node of syntax graph
					# t:  token kind (literal, class, ...)
  # TODO: it looks like we are misusing graph above. C# version has graph(Node) and tokenKind(int).
  attr_accessor :tokenKind
  attr_accessor :deletable		# nt: true if nonterminal is deletable
  attr_accessor :firstReady		# nt: true if terminal start symbols have been computed
  attr_accessor :first			# nt: terminal start symbols
  attr_accessor :follow			# nt: terminal followers
  attr_accessor :nts			# nt: nonterminals whose followers have been added to this sym
  attr_accessor :line			# source text line number of item in this node
  attr_accessor :attrPos		# position of attributes in source text (or null)
  attr_accessor :semPos			# pr: pos of semantic action in source text (or null)
					# nt: pos of local declarations in source text (or null)
  # TODO: retVar and retType don't occur in C# version at all
  attr_accessor_warn :retVar			# nt: Name of output attribute (or null)
  attr_accessor :retType		# nt: Type of output attribute (or null)

  def initialize(typ=0, name="", line=0)
    @typ  = typ
    @name = name
    @line = line
    @tokenKind = -1
    @deletable = firstReady = false
    @graph = @first = @follow = @nts = @attrPos = @semPos = nil
    @retType = @retVar = nil	# strings

    case typ 
    when Node::T
      @n = @@terminals.size
      @@terminals.push self
    when Node::Pr
      @n = @@pragmas.size
      @@pragmas.unshift self
    when Node::Nt
      @n = @@nonterminals.size
      @@nonterminals.unshift self
    end

  end

  def ==(o)
    if o.kind_of?(Fixnum) then
      $stderr.puts "WARNING: Sym#== called with int from #{caller[0]}"
      return self.n == o
    else
      return false if o.nil?
      return true if self.object_id == o.object_id
      
      return @typ == o.typ && @name == o.name && @line == o.line && @n == o.n && @graph == o.graph && @deletable == o.deletable && @attrPos == o.attrPos && @semPos == o.semPos && @retType = o.retType && @retVar == o.retVar && @tokenKind == o.tokenKind
    end
  end

  def resetFirstSet
    @firstReady = false
    @first = BitSet.new
  end

  def resetFollowSet
    @follow = BitSet.new
    @nts = BitSet.new
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

  # not actually used, but required for enumerable
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

  def self.Find(name)
    return @@terminals.detect { |s| s.name == name } || @@nonterminals.detect { |s| s.name == name } || NoSym
  end

  def node_type
    return Node::NodeTypes[@typ]
  end

  def to_s
    self.n.to_s
  end
  
  def self.RenumberPragmas
    n = self.terminal_count
    self.each_pragma do |sym|
      sym.n = n
      n += 1
    end
  end

end

class Node

  class << self
    include Enumerable
  end

  @@nodes = Array.new(0, :Node)	# grammar graph

  NodeTypes = [ "    ", "t   ", "pr  ", "nt  ", "clas", "chr ", "wt  ",
                "any ", "eps ", "sync", "sem ", "alt ", "iter", "opt " ]

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

  NormTrans    = 0		# transition codes
  ContextTrans = 1

  attr_accessor :n			# node number
  attr_accessor :typ			# t, nt, wt, chr, clas, any, eps, sem, sync, alt, iter, opt
  attr_accessor :nxt			# successor node
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
  attr_accessor :line			# source text line number of item in this node
  attr_accessor :state			# DFA state corresponding to this node
					# (only used in Sgen.ConvertToStates)

  # TODO: C# doesn't have retVar... check it out.
  attr_accessor_warn :retVar		# nt: name of output attribute (or null)

  def initialize(typ, val, line=0)

    @typ = typ
    @line = line
    @n = @@nodes.length

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

    @@nodes << self
  end

  # Not actually used, but required for enumerable
  def self.each(&b)
    @@nodes.each(&b)
  end

  def node_type
    return NodeTypes[@typ]
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
    return @@nodes.length - 1
  end

  def self.EraseNodes
    @@nodes = Array.new(0, :Node)		# grammar graph
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

  def self.PrintNodes
    n = nil
    Trace.println("Graph:")
    Trace.println("  nr typ  next   v1   v2 line")

    Node.each do |n|
      Trace.println(n)
    end
    Trace.println()
  end

end

class Graph

  attr_accessor :l			# left end of graph = head
  attr_accessor :r			# right end of graph = list of nodes to be linked to successor graph

  def initialize(l=nil, r=l)
    @l = l
    @r = r
  end

  def self.FirstAlt(g)
    g.l = Node.new(Node::Alt, g.l)
    g.l.nxt = g.r
    g.r = g.l
  end

  def self.Alternative(g1, g2)
    g2.l = Node.new(Node::Alt, g2.l)
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
  end

  def self.Sequence(g1, g2)
    p = g1.r.nxt
    g1.r.nxt = g2.l		# link head node
    until (p.nil?) do		# link substructure
      q = p.nxt
      p.nxt = g2.l
      p.up = true
      p = q
    end
    g1.r = g2.r
  end

  def self.Iteration(g)
    g.l = Node.new(Node::Iter, g.l)
    p = g.r
    g.r = g.l
    until (p.nil?) do
      q = p.nxt
      p.nxt = g.l
      p.up = true
      p = q
    end
  end

  def self.Option(g)
    g.l = Node.new(Node::Opt, g.l)
    g.l.nxt = g.r
    g.r = g.l
  end

  def self.Finish(g)
    p = g.r
    until (p.nil?) do
      q = p.nxt
      p.nxt = nil
      p = q
    end
  end

  def self.SetContextTrans(p) # set transition code to contextTrans
    # TODO: DFA.hasContextMoves = true
    until (p.nil?) do
      # TODO: make a case statement or refactor better
      if (p.typ==Node::Chr || p.typ==Node::Clas) then
	p.code = Node::ContextTrans
      elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
	self.SetContextTrans(p.sub)
      elsif (p.typ==Node::Alt) then
	self.SetContextTrans(p.sub)
	self.SetContextTrans(p.down)
      end
      break if p.up
      p = p.nxt
    end
  end

  # TODO: def self.DeleteNodes (see Node.EraseNodes)

  # ---------------------------------------------------------------------
  #   topdown graph management
  # ---------------------------------------------------------------------

  def self.StrToGraph(s)
    # TODO: s = DFA.Unescape(s[1..-2])

    temp = Node.new(Node::Eps, nil)

    g = Graph.new
    g.r = temp

    raise "s is messed up" if s.length <= 2

    s[1..-2].each_byte do | c |
      p = Node.new(Node::Chr, c)
      g.r.nxt = p
      g.r = p
    end
    
    g.l = temp.nxt
    temp.nxt = nil

    return g
  end

end

class CharClass

  @@classes = []
  @@dummyName = ?A				# for unnamed character classes

  # TODO: CharSetSize = 256 # must be a multiple of 16

  # TODO: get rid of these
  cls_attr_accessor_warn :classes

  attr_accessor :n			# class number
  attr_accessor :name			# class name
  attr_accessor :set			# index of set representing the class

  def initialize(name, s=BitSet.new)
    @name = ""
    @set = 0

    if (name == "#") then
      name = "#" + @@dummyName.chr
      @@dummyName += 1
    end

    @n = @@classes.size
    @name = name
    @set = s

    @@classes << self
  end

  # ---------------------------------------------------------------------
  #   Character class management
  # ---------------------------------------------------------------------

  def self.Find(val)
    case val
    when BitSet then
      @@classes.detect do |c|
	c.set == val
      end
    when String then
      @@classes.detect do |c|
	c.name == val
      end
    else
      raise "Bad argument type #{val.class}"
    end
  end

  def self.Set(s)
    return @@classes[s].set
  end

  # TODO: def self.Ch(ch)
  # TODO: def self.WriteCharSet(w, s)

  def self.WriteClasses
    @@classes.each do |c|
      Trace.println("#{c.name}: #{c.set}")
    end
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

  def initialize(l, r)
    @left = l
    @right = r
    @deleted = false
  end

end

class Tab

  EofSy = Sym.new(Node::T, "EOF", 0)				# TODO: move to Sym
  MaxTerminals =  256	# max. no. of terminals			# TODO: nuke
  MaxSetNr     =  128	# max. no. of symbol sets		# TODO: nuke

  @@semDeclPos = nil			# position of global semantic declarations
  @@ignored = nil			# characters ignored by the scanner
  @@ddt = Array.new(10, false)		# debug and test switches
  @@gramSy = nil			# root nonterminal filled by ATG
  # TODO: trace = some output stream
  @@allSyncSets = BitSet.new
  @@visited = nil 
  @@curSy = 0				# current symbol in computation of sets # TODO: = nil

  # REFACTOR: NUKE ME
  @@importPos = nil			# position of imported identifiers	# TODO: nuke
  @@maxSet = nil			# index of last set	# TODO: nuke
  @@set = Array.new(128)		# set[0] = union of all synchr. sets
  @@err = nil				# error messages
  @@termNt = nil 			# mark lists for graph traversals

  # TODO: get rid of these
  cls_attr_accessor_warn :ignored, :semDeclPos, :gramSy, :ddt, :allSyncSets

#  def initialize
#    raise "Not implemented yet"
#  end

#  def ==(o)
#    raise "Not implemented yet"
#  end

  class << self
    include Enumerable
  end

  def self.each_ignored
    @@ignored.each_with_index do |isTrue, index|
      yield(index) if isTrue
    end
  end

  # ---------------------------------------------------------------------
  #   Symbol set computations
  # ---------------------------------------------------------------------

  # TODO: nuke
  def self.NewSet(s)
    warn_usage if $DEBUG
    @@maxSet += 1
    assert(@@maxSet <= MaxSetNr, 4)
    @@set[@@maxSet] = s
    return @@maxSet
  end

  # TODO: nuke
  def self.Set(i)
    warn_usage if $DEBUG
    return @@set[i]
  end

  def self.First0(p, mark)
    s1 = s2 = nil
    fs = BitSet.new

    while (!p.nil? && !mark.get(p.n)) do
      mark.set(p.n)
		 
      case (p.typ)
      when Node::Nt then
	if (p.sym.firstReady) then
	  fs.or(p.sym.first)
	else 
	  fs.or(self.First0(p.sym.graph, mark))
	end
      when Node::T, Node::Wt then
	fs.set(p.sym.n)
      when Node::Any then
	fs.or(@@set[p.set]) # TODO: (SET) fs.or(p.set)
      when Node::Alt, Node::Iter, Node::Opt then
	fs.or(self.First0(p.sub, mark))
	if (p.typ==Node::Alt) then
	  fs.or(self.First0(p.down, mark))
	end
      end
      break unless Node.DelNode(p)
      p = p.nxt
    end
    return fs
  end
  
  def self.First(p)
    fs = First0(p, BitSet.new(Node.NodeCount))
    if (@@ddt[3]) then
      Trace.println()
      Trace.println("First: gp = #{p}") unless p.nil?
      BitSet.PrintSet(fs)
    end
    return fs
  end

  def self.CompFirstSets

    Sym.each_nonterminal do |sym|
      sym.resetFirstSet
    end

    Sym.each_nonterminal do |sym|
      sym.first = self.First(sym.graph)
      sym.firstReady = true
    end
  end
  
  def self.CompFollow(p)
    s = nil
    while (!p.nil? && !@@visited.get(p.n)) do
      @@visited.set(p.n)
      # TODO: change to switch statement
      if p.typ==Node::Nt then
	s = First(p.nxt)
	p.sym.follow.or(s)
	if Node.DelGraph(p.nxt) then
	  p.sym.nts.set(@@curSy.n)
	end
      elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
	CompFollow(p.sub)
      elsif p.typ==Node::Alt then
	CompFollow(p.sub)
	CompFollow(p.down)
      end
      p = p.nxt
    end
  end

  def self.Complete(sym)
    unless @@visited.get(sym.n) then
      @@visited.set(sym.n)
      Sym.each_nonterminal do | s |
	if sym.nts.get(s.n) then
	  Complete(s)
	  sym.follow.or(s.follow)
	  sym.nts.clear(s.n) if sym == @@curSy
	end
      end
    end
  end

  def self.CompFollowSets

    Sym.each_nonterminal do |sym|
      sym.resetFollowSet
    end

    @@visited = BitSet.new()

    Sym.each_nonterminal do |sym|	# get direct successors of nonterminals
      @@curSy = sym # FIX: this is a bad use of globals!
      CompFollow(sym.graph)
    end

    Sym.each_nonterminal do |sym|	# add indirect successors to followers
      @@visited = BitSet.new()
      @@curSy = sym # FIX: bad use of globals
      Complete(sym)
    end
  end

  def self.LeadingAny(p)

    return nil if p.nil?

    a = nil
    if p.typ==Node::Any then
      a = p
    elsif p.typ==Node::Alt then
      a = LeadingAny(p.sub)
      a = LeadingAny(p.down) if a.nil?
    elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
      a = LeadingAny(p.sub)
    elsif (Node.DelNode(p)) then # TODO: && ! p.up
      a = LeadingAny(p.nxt)
    end

    return a
  end

  def self.FindAS(p)
    a = nil
#    nod = s1 = s2 = nil
#    q = nil

    until p.nil? do
      if (p.typ==Node::Opt || p.typ==Node::Iter) then
	FindAS(p.sub)
	a = LeadingAny(p.sub)
	Sets.Differ(@@set[a.set], First(p.nxt)) unless a.nil? # TODO: a.set
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
# HACK	    Sets.Differ(@@set[a.set], First(q.down).or(s1)) # TODO: a.set
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
      @@curSy = sym # FIX : bad use of globals - C# doesn't do this
      FindAS(sym.graph)
    end
  end

  def self.Expected(p, curSy)
    s = First(p)
    if (Node.DelGraph(p)) then
      s.or(curSy.follow)
    end
    return s
  end

  def self.CompSync(p)
    s = nil
    while (!p.nil? && !@@visited.get(p.n)) do
      @@visited.set(p.n)

      # TODO: switch to case
      if (p.typ==Node::Sync) then
	s = Expected(p.nxt, @@curSy)
	s.set(Tab::EofSy.n)
	@@allSyncSets.or(s)
	p.set = NewSet(s) # TODO: p.set = s from C#
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
    @@allSyncSets = BitSet.new(Sym.terminal_count)
    @@allSyncSets.set(Tab::EofSy.n)
    @@visited = BitSet.new()

    Sym.each_nonterminal do |sym|
      @@curSy = sym # FIX: bad use of global
      CompSync(sym.graph)
    end
  end

  # TODO: def self.SetupAnys - called from Coco.atg in "ANY" section

  def self.CompDeletableSymbols

    begin
      changed = false

      Sym.each_nonterminal do |sym|
	if (!sym.deletable && Node.DelGraph(sym.graph)) then # TODO: deletable && !sym.graph.nil?
	  sym.deletable = true
	  changed = true
	end
      end
    end while changed

    Sym.each_nonterminal do |sym|
      if sym.deletable then
	puts("  #{sym.name} deletable")
	$stdout.flush
      end
    end
  end

  # TODO: RenumberPragmas goes here

  def self.CompSymbolSets
    i = Sym.new(Node::T, "???", 0) # TODO: WTF is this for? Does Sym.new do add to some array?

    CompDeletableSymbols()
    CompFirstSets()
    CompFollowSets()
    CompAnySets()
    CompSyncSets()
    Sym.RenumberPragmas() # TODO: nuke

    if (@@ddt[1]) then
      Trace.println("First & follow symbols:")

      Sym.each_nonterminal do |sym|
	Trace.println(sym.name)
	Trace.print("first:   ")
	BitSet.PrintSet(sym.first, 10)
	Trace.print("follow:  ")
	BitSet.PrintSet(sym.follow, 10)
	Trace.println()
      end

      if @@ddt[4] then
	Trace.println()
	Trace.println()
	Trace.println("List of sets (ANY, SYNC): ")
	Node.each do |p|
	  Trace.print("#{p.n} #{p.node_type}: ")
	  BitSet.PrintSet(@@set[p.set], 16) unless p.set.nil? # TODO: p.set
	  Trace.println
	end
	Trace.println()
	Trace.println()
      end
    end
  end

  # ---------------------------------------------------------------------
  #   Grammar checks
  # ---------------------------------------------------------------------

  # TODO: def self.GrammarOk

  def self.GetSingles(p, singles) # (int p, BitSet singles)
    return if p.nil? # end of graph

    if (p.typ==Node::Nt) then
      if (Node.DelGraph(p.nxt)) then # TODO: if p.up || ...
	singles.set(p.sym.n) # TODO: C# version has singles as an array, so: singles << p.sym
      end
    elsif (p.typ==Node::Alt || p.typ==Node::Iter || p.typ==Node::Opt) then
      if (Node.DelGraph(p.nxt)) then # TODO: if p.up || ...
	GetSingles(p.sub, singles)
	if (p.typ==Node::Alt) then
	  GetSingles(p.down, singles)
	end
      end
    end

    if (Node.DelNode(p)) then # TODO: if !p.up
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
	  x = CNode.new(sym1.n, sym2.n)
	  list[len] = x # FIX: just push damnit
	  len += 1 # FIX: nuke
	end
      end
    end

    # TODO:
    # Sym.each_nonterminal do |sym| 
    #   singles = []
    #   GetSingles(sym.graph, singles); // get nonterminals s such that sym-->s
    #   singles.each do |s|
    #     list.Add(CNode.new(sym, s));
    #   end
    # end

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
    print("  LL1 warning in #{@@curSy.name}: #{ts.name} is ")

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

  def self.AltOverlap(p) # REFACTOR: rename to CheckAlts
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

  def self.LL1() # REFACTOR: rename CheckLL1
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
      Trace.print(sprintf("%3d %-10.10s %s", sym.n, sym.name, sym.node_type))
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

  def self.Init
    @@err = Scanner.err
    @@maxSet = 0

    @@set[0] = BitSet.new()
    @@set[0].set(Tab::EofSy.n)
  end

end # class Tab
