require 'Scanner'
require "module-hack"

############################################################
# HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK 
############################################################

class Fixnum
  def n
    $stderr.puts "WARNING: Fixnum#n called from " + caller[0]
    self
  end
  def nil?
    $stderr.puts "WARNING: Fixnum#nil? called from " + caller[0]
    return self == 0
  end
end

############################################################
# HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK HACK 
############################################################

class StateSet		# set of target states returned by GetTargetStates

  attr_accessor :set		# all target states of an action
  attr_accessor :endOf		# token that is recognized after this action
  attr_accessor :ctx		# true if target states are reached via context transition
  attr_accessor :correct	# true if no error occured in GetTargetStates

  def initialize
    @set = nil
    @endOf = 0
    @ctx = @correct = false
  end

  def ==(o)
    raise "Not implemented yet"
  end

end

#-----------------------------------------------------------------------------
#  State
#-----------------------------------------------------------------------------

class State				# state of finite automaton
  @@lastNr = 0

  cls_attr_accessor :lastNr		# highest state number
  attr_accessor :nr			# state number
  attr_accessor :firstAction		# to first action of this state
  attr_accessor :endOf			# nr. of recognized token if state is final
  attr_accessor :ctx			# true if state is reached via contextTrans
  attr_accessor :nxt

  def initialize
    self.class.lastNr += 1
    @nr = self.class.lastNr
    @endOf = Sym::NoSym
    @ctx = false
    @firstAction = @nxt = nil
  end

  def ==(o)
    return !o.nil? &&
      @nr == o.nr &&
      @firstAction == o.firstAction &&
      @endOf == o.endOf &&
      @ctx == o.ctx &&
      @nxt == o.nxt
  end

  def AddAction(act)
    lasta = nil
    a = @firstAction
    while (a and act.typ >= a.typ) do
      lasta = a
      a = a.nxt
    end

    # collecting classes at the beginning gives better performance
    act.nxt = a
    if (a == @firstAction) then
      @firstAction = act
    else
      unless lasta.nil? then
	lasta.nxt = act
      else
	$stderr.puts "AddAction: lasta is nil. @firstAction=#{@firstAction}"
      end
    end
  end

  def DetachAction(act)
    lasta = nil
    a = @firstAction

    while (a != nil && a != act) do
      lasta = a
      a = a.nxt
    end

    if (a != nil) then
      if (a==@firstAction) then
	@firstAction = a.nxt
      else
	lasta.nxt = a.nxt
      end
    end
  end

  def TheAction(ch)
    s=nil
    a=@firstAction
    while (a!=nil) do
      if (a.typ==Node::Chr && ch==a.sym) then
	return a
      elsif (a.typ==Node::Clas) then
	s = CharClass.Class(a.sym)
	return a if s.get(ch)
      end
      a=a.nxt
    end
    return nil
  end

  def MeltWith(s) # copy actions of s to state
    a = nil
    action=s.firstAction
    while (action != nil) do
      a = Action.new(action.typ, action.sym, action.tc)
      a.AddTargets(action)
      self.AddAction(a)
      action=action.nxt
    end
  end
end

#-----------------------------------------------------------------------------
#  Action
#-----------------------------------------------------------------------------

class Action			# action of finite automaton
  attr_accessor :typ		# type of action symbol: clas, chr
  attr_accessor :sym		# action symbol
  attr_accessor :tc		# transition code: normTrans, contextTrans
  attr_accessor :target		# states reached from this action
  attr_accessor :nxt

  def initialize(typ, sym, tc)
    @typ = typ
    @sym = sym
    @tc = tc
    @target = @nxt = nil

    if !sym.kind_of?(Fixnum) && sym.nil? then
      $stderr.puts "WARNING: sym set to nil, setting to zero from " + caller[0]
      @sym = 0
    end
  end

  def ==(o)
    return !o.nil? &&
      @typ == o.typ &&
      @sym == o.sym &&
      @tc == o.tc &&
      @nxt == o.nxt &&
      @target.eql?(o.target) # .eql? because == causes a cycle
  end

  def AddTarget(t)
    last = nil
    p = @target

    while (p != nil && t.state.nr >= p.state.nr) do
      return if t.state == p.state
      last = p
      p = p.nxt
    end
    t.nxt = p

    if (p==@target) then
      @target = t
    else
      last.nxt = t
    end
  end

  def AddTargets(a) # add copy of a.targets to action.targets
    t = last = nil

    p=a.target
    while (p!=nil) do
      t = Target.new(p.state)
      self.AddTarget(t)
      p=p.nxt
    end

    if (a.tc==Node::ContextTrans) then
      @tc = Node::ContextTrans
    end
  end

  def Symbols()
    s = nil

    if (@typ==Node::Clas) then
      s = CharClass.Class(@sym).clone()
    else
      s = BitSet.new()
      s.set(@sym)
    end

    return s
  end

  def ShiftWith(s)
    i = 0

    if (Sets.Size(s)==1) then
      @typ = Node::Chr
      @sym = Sets.First(s)
    else

      i = CharClass.maxC
      while (i>=0) do
	x = Tab.set()[CharClass.chClass[i].set]
	i -= 1
      end

      i = CharClass.ClassWithSet(s)
      if (i < 0) then # class with dummy name
	i = CharClass.NewClass("#", s)
      end
      @typ = Node::Clas
      @sym = i
    end
  end

  def GetTargetStates # compute the set of target states
    stateNr=0
    states = StateSet.new
    states.set = BitSet.new		# FIX: violation of encapsulation
    states.endOf = Sym::NoSym
    states.ctx = false
    states.correct = true

    t=@target

    while (t!=nil) do
      stateNr = t.state.nr
      if (stateNr <= DFA.lastSimState) then
	states.set.set(stateNr)
      else
	states.set.or(Melted.Set(stateNr))
      end
      if (t.state.endOf!=Sym::NoSym) then
	if (states.endOf==Sym::NoSym || states.endOf==t.state.endOf) then
	  states.endOf = t.state.endOf
	else
	  $stderr.puts("Tokens #{states.endOf} and #{t.state.endOf} cannot be distinguished")
	  states.correct = false
	end
      end
      if (t.state.ctx) then
	states.ctx = true
	# The following check seems to be unnecessary. It reported an error
	# if a symbol + context was the prefix of another symbol, e.g.
	# s1 = "a" "b" "c".
	# s2 = "a" CONTEXT("b").
	# But this is ok.
	# if (t.state.endOf!=Sym::NoSym) {
	# $stderr.puts("Ambiguous context clause")
	# states.correct = false
      end
      t=t.nxt
    end
    return states
  end

end # class Action

#-----------------------------------------------------------------------------
#  Target
#-----------------------------------------------------------------------------

class Target				# set of states that are reached by an action
  attr_accessor :state, :nxt

  def initialize(s)
    @state = s
    @nxt = nil
  end

  def ==(o)
    ! o.nil? &&
      @state == o.state &&
      @nxt == o.nxt
  end

end

#-----------------------------------------------------------------------------
#  Melted
#-----------------------------------------------------------------------------

class Melted			# info about melted states

  @@first = nil			# head of melted state list

  attr_accessor :set		# set of old states
  attr_accessor :state		# new state
  attr_accessor :nxt
  cls_attr_accessor :first

  def initialize(set, state)
    @set = set
    @state = state

    @nxt = @@first
    @@first = self
  end

  def ==(o)
    ! o.nil? &&
      @set == o.set &&
      @state == o.state &&
      @nxt == o.nxt
  end

  def self.Set(nr)
    m = @@first

    while (m != nil && m.state.nr != nr) do
      m = m.nxt
    end

    return m.set
  end

  def self.StateWithSet(s)
    m = @@first

    while (m != nil) do
      if (s == m.set) then
	return m
      end
      m = m.nxt
    end
    return nil
  end
end

#-----------------------------------------------------------------------------
#  Comment
#-----------------------------------------------------------------------------

class Comment				# info about comment syntax
  @@first = nil

  cls_attr_accessor :first

  attr_accessor :start
  attr_accessor :stop
  attr_accessor :nested
  attr_accessor :nxt

  def initialize(from, to, nested)
    @start = self.class.Str(from)
    @stop = self.class.Str(to)
    @nested = nested
    @nxt = @@first
    @@first = self
  end

  def ==(o)
    raise "Not implemented yet"
  end

  # private maybe??
  def self.Str(p)
    s = ""
    set = nil

    until (p.nil?) do
      if (p.typ==Node::Chr) then
	s << p.val.chr
      elsif (p.typ==Node::Clas) then
	set = CharClass.Class(p.val)
	if (Sets.Size(set) != 1) then
	  DFA.SemErr(26)
	end
	s << Sets.First(set).chr
      else
	DFA.SemErr(22)
      end
      p = p.nxt
    end

    if (s.length() > 2) then
      $stderr.puts("Comment is fubar! '#{s}'")
      DFA.SemErr(25)
    end

    return s.to_s
  end

end

#-----------------------------------------------------------------------------
#  DFA
#-----------------------------------------------------------------------------

class DFA
  MAXSTATES = 300
  EOF = '\uffff' # FIX: not a valid ruby character... *sigh*
  CR  = '\r'
  LF  = '\n'

  @@firstState=nil
  @@lastState=nil	# last allocated state
  @@lastSimState=0	# last non melted state
  @@fram=nil		# scanner frame input
  @@gen=nil		# generated scanner file
  @@srcDir=""		# directory of attribute grammar file
  @@curSy=0		# current token to be recognized (in FindTrans)
  @@curGraph=0		# start of graph for current token (in FindTrans)
  @@dirtyDFA=false	# DFA may become nondeterministic in MatchedDFA

  def self.lastSimState
    @@lastSimState
  end

  def self.Init(dir)
    @@srcDir = dir

    @@firstState = @@lastState = nil
    State.lastNr = -1
    @@firstState = NewState()
    Melted.first = nil
    @@dirtyDFA = false
  end

  def self.SemErr(n)
    Scanner.err.SemErr(n, 0, 0)
  end

  def self.Ch(ch)
    if (ch<?\ || ch >= 127 || ch==?' || ch==?\\) then
      return ch.to_s
    else
      return "?#{ch.chr}" # TODO check this
    end
  end

  def self.ChCond(ch)
    # TODO: assert ch is an int?
    return "@@ch==#{self.Ch(ch)}"
  end

  def self.PutRange(s)
    lo = Array.new(32, 0)
    hi = Array.new(32, 0)
    s1 = nil

    # fill lo and hi
    top = -1
    i = 0
    while (i < 128) do		# run length encoding... lo[0]..hi[0] is a span of trues in bitset
      if (s.get(i)) then
	top += 1
	lo[top] = i
	i += 1
	i += 1 while (i < 128 && s.get(i))
	hi[top] = i-1
      else
	i += 1
      end
    end

    # print ranges
    if (top==1 && lo[0]==0 && hi[1]==127 && hi[0]+2==lo[1]) then # only one bit is false
      # FIX: WHY THE MOTHERFUCK DIDN'T THEY JUST OUTPUT THE FUCKING CODE?!?
      # e.g. @@gen.print("@@ch != " + Ch((char)hi[0]+1))
      s1 = BitSet.new		# FIX: omg this makes no sense
      s1.set(hi[0]+1)
      @@gen.print("!")
      PutRange(s1)
    else
      @@gen.print("(")
      for i in 0..top do
	if (hi[i]==lo[i]) then
	  @@gen.print("@@ch==#{Ch(lo[i])}")
	elsif (lo[i]==0) then
	  @@gen.print("@@ch<=#{Ch(hi[i])}")
	elsif (hi[i]==127)
	  @@gen.print("@@ch>=#{Ch(lo[i])}")
	else
	  @@gen.print("@@ch>=#{Ch(lo[i])} && @@ch<=#{Ch(hi[i])}")
	end
	if (i < top) then
	  @@gen.print(" || ")
	end
      end
      @@gen.print(")")
    end
  end

  def self.NewState
    s = State.new
    if @@firstState.nil? then
      @@firstState = s
    else
      @@lastState.nxt = s
    end
    @@lastState = s
    return s
  end

  def self.NewTransition(from, to, typ, sym, tc)
    a = t = nil
    if (to==@@firstState) then
      SemErr(21)
    end
    t = Target.new(to)
    a = Action.new(typ, sym, tc)
    a.target = t
    from.AddAction(a)
  end

  def self.CombineShifts
    seta = setb = a = b = c = nil
    state = @@firstState
    while (state!=nil) do
      a=state.firstAction
      while (a!=nil) do
	b = a.nxt
	while (b != nil) do
	  if (a.target.state==b.target.state && a.tc==b.tc) then
	    seta = a.Symbols()
	    setb = b.Symbols()
	    seta.or(setb)
	    a.ShiftWith(seta)
	    c = b
	    b = b.nxt
	    state.DetachAction(c)
	  else
	    b = b.nxt
	  end
	end # while
	a=a.nxt
      end # while
      state=state.nxt
    end # while
  end

  def self.FindUsedStates(state, used)
    return if used.get(state.nr)

    used.set(state.nr)
    a=state.firstAction
    until (a.nil?) do
      FindUsedStates(a.target.state, used)
      a=a.nxt
    end
  end

  def self.DeleteRedundantStates
    newState = Array.new(MAXSTATES)
    used = BitSet.new()
    FindUsedStates(@@firstState, used)

    # combine equal final states
    s1=@@firstState.nxt
    until (s1.nil?) do # firstState cannot be final
      if (used.get(s1.nr) && s1.endOf != Sym::NoSym && s1.firstAction.nil? && !s1.ctx) then
	s2=s1.nxt
	until (s2.nil?) do
	  if (used.get(s2.nr) && s1.endOf == s2.endOf && s2.firstAction.nil? && !s2.ctx) then
	    used.clear(s2.nr)
	    newState[s2.nr] = s1
	  end
	  s2=s2.nxt
	end
      end
      s1=s1.nxt
    end

    state=@@firstState
    until (state.nil?) do
      if (used.get(state.nr)) then
	a=state.firstAction
	until (a.nil?) do
	  unless (used.get(a.target.state.nr)) then
	    a.target.state = newState[a.target.state.nr]
	  end
	  a=a.nxt
	end
      end
      state=state.nxt
    end

    # delete unused states
    @@lastState = @@firstState
    State.lastNr = 0 # @@firstState has number 0

    state=@@firstState.nxt
    until (state.nil?) do
      if (used.get(state.nr)) then
	State.lastNr += 1
	state.nr = State.lastNr
	@@lastState = state
      else
	@@lastState.nxt = state.nxt
      end
      state=state.nxt
    end
  end

  def self.TheState(p)
    state = nil
    if (p.nil?) then
      state = self.NewState()
      state.endOf = @@curSy
    else
      state = p.state
    end
    return state
  end

  def self.Step(from, p, stepped)
    return if p.nil?

    stepped.set(p.n)

    case (p.typ)
    when Node::Clas, Node::Chr then
      NewTransition(from, TheState(p.nxt), p.typ, p.val, p.code)
    when Node::Alt then
      Step(from, p.sub, stepped)
      Step(from, p.down, stepped)
    when Node::Iter, Node::Opt then
      if (!p.nxt.nil? && !stepped[p.nxt.n]) then
	Step(from, p.nxt, stepped)
      end
      Step(from, p.sub, stepped)
    end
  end

  def self.NumberNodes(p, state)
    # Assigns a state n.state to every node n. There will be a transition from
    # n.state to n.nxt.state triggered by n.sym. All nodes in an alternative
    # chain are represented by the same state.

    return if p.nil?

    return unless p.state.nil? # already visited

    if (state.nil?) then
      state = NewState()
    end

    p.state = state

    if (Node.DelGraph(p)) then
      state.endOf = @@curSy
    end

    case (p.typ)
    when Node::Clas, Node::Chr then
      NumberNodes(p.nxt, nil)
    when Node::Opt then
      NumberNodes(p.nxt, nil)
      NumberNodes(p.sub, state)
    when Node::Iter then
      NumberNodes(p.nxt, state)
      NumberNodes(p.sub, state)
    when Node::Alt then
      NumberNodes(p.sub, state)
      NumberNodes(p.down, state)
    end
  end

  def self.FindTrans (p, start, mark)
    return if p.nil? || mark[p.n]
    mark.set(p.n)

    if (start) then
      Step(p.state, p, BitSet.new(512)) # start of group of equally numbered nodes
    end

    case (p.typ)
    when Node::Clas, Node::Chr then
      FindTrans(p.nxt, true, mark)
    when Node::Opt then
      FindTrans(p.nxt, true, mark)
      FindTrans(p.sub, false, mark)
    when Node::Iter then
      FindTrans(p.nxt, false, mark)
      FindTrans(p.sub, false, mark)
    when Node::Alt then
      FindTrans(p.sub, false, mark)
      FindTrans(p.down, false, mark)
    end
  end

  def self.ConvertToStates(p, sp)
    @@curGraph = p
    @@curSy = sp

    if (Node.DelGraph(@@curGraph)) then
      self.SemErr(20)
    end

    NumberNodes(@@curGraph, @@firstState)
    FindTrans(@@curGraph, true, BitSet.new(512))
  end

  def self.MatchedDFA(s, sp)
    state = to = a = nil
    i = matchedSp = 0
    len = s.length - 1
    weakMatch = false

    # s has quotes
    state = @@firstState

    i = 1
    while (i < len) do # try to match s against existing DFA
      a = state.TheAction(s[i])
      break if (a == nil)

      if (a.typ == Node::Clas) then
	weakMatch = true			# TODO: check and see if this should break
      end
      state = a.target.state
      i += 1
    end

    if (weakMatch && i < len) then
      state = @@firstState
      i = 1
      @@dirtyDFA = true
    end

    while (i<len) do # make new DFA for s[i..len-1]
      to = NewState()
      NewTransition(state, to, Node::Chr, s[i], Node::NormTrans)
      state = to
      i += 1
    end

    matchedSp = state.endOf
    if (state.endOf==Sym::NoSym) then
      state.endOf = sp
    end

    return matchedSp
  end

  def self.SplitActions(state, a, b)

    c = setc = nil
    seta = a.Symbols()
    setb = b.Symbols()

    if (seta == setb) then
      a.AddTargets(b)
      state.DetachAction(b)
    elsif (Sets.Includes(seta, setb)) then
      setc = seta.clone()
      Sets.Differ(setc, setb)
      b.AddTargets(a)
      a.ShiftWith(setc)
    elsif (Sets.Includes(setb, seta)) then
      setc = setb.clone()
      Sets.Differ(setc, seta)
      a.AddTargets(b)
      b.ShiftWith(setc)
    else
      setc = seta.clone()
      setc.and(setb)
      Sets.Differ(seta, setc)
      Sets.Differ(setb, setc)
      a.ShiftWith(seta)
      b.ShiftWith(setb)
      c = Action.new(0, 0, 0)
      c.AddTargets(a)
      c.AddTargets(b)
      c.ShiftWith(setc)
      state.AddAction(c)
    end
  end

  def self.Overlap(a, b)
    result = false
    seta = setb = nil

    if (a.typ==Node::Chr) then
      if (b.typ==Node::Chr) then
	result = a.sym==b.sym
      else
	setb = CharClass.Class(b.sym)
	result = setb.get(a.sym)
      end
    else
      seta = CharClass.Class(a.sym)
      if (b.typ==Node::Chr) then
	result = seta.get(b.sym)
      else
	setb = CharClass.Class(b.sym)
	result = ! Sets.Different(seta, setb)
      end
    end
    return result
  end

  def self.MakeUnique(state) # return true if actions were split # verified 2003-07-13
    changed = false

    a = state.firstAction
    until (a.nil?) do
      b = a.nxt
      until (b.nil?) do
	if (Overlap(a, b)) then
	  SplitActions(state, a, b)
	  changed = true
	end
	b = b.nxt
      end
      a = a.nxt
    end
    return changed
  end

  def self.MeltStates(state)
    changed = correct = true
    states = s = targ = melt = nil

    action=state.firstAction
    while (action!=nil) do
      if (action.target.nxt != nil) then
	states = action.GetTargetStates()
	correct = correct && states.correct
	melt = Melted.StateWithSet(states.set)
	if (melt==nil) then
	  s = NewState()
	  s.endOf = states.endOf
	  s.ctx = states.ctx
	  targ = action.target
	  while (targ!=nil) do
	    s.MeltWith(targ.state)
	    targ=targ.nxt
	  end
	  begin
	    changed = MakeUnique(s)
	  end while changed
	  melt = Melted.new(states.set, s)
	end
	action.target.nxt = nil
	action.target.state = melt.state
      end
      action=action.nxt
    end
    return correct
  end

  def self.FindCtxStates()
    state = @@firstState
    until (state.nil?) do
      a = state.firstAction
      until (a.nil?) do
	if a.tc == Node::ContextTrans then
	  a.target.state.ctx = true
	end
	a=a.nxt
      end
      state=state.nxt
    end
  end

  def self.MakeDeterministic()

    state = nil
    changed = correct = true
    @@lastSimState = @@lastState.nr

    FindCtxStates()

    state = @@firstState
    i = 1
    until (state.nil?) do
      j = 1
      begin
	changed = MakeUnique(state)
	j+= 1
      end while changed
      i += 1
      state=state.nxt
    end
    correct = true

    state=@@firstState
    while (state!=nil) do
      correct = MeltStates(state) && correct
      state=state.nxt
    end

    DeleteRedundantStates()
    CombineShifts()
    return correct
  end

  def self.PrintStates()
    action = targ = set = nil
    first = true
    Trace.println("\n---------- states ----------")

    state = @@firstState
    while (state!=nil) do
      first = true

      if (state.endOf == Sym::NoSym) then
	Trace.print("     ")
      else
	Trace.print("E(#{sprintf('%2d', state.endOf.n)[0..1]})")
      end

      Trace.print(sprintf("%3d:", state.nr))

      if (state.firstAction == nil) then
	Trace.println()
      end

      action = state.firstAction
      while (action!=nil) do
	if (first) then
	  Trace.print(" ")
	  first = false
	else
	  Trace.print("          ")
	end
	if (action.typ==Node::Clas) then
	  Trace.print(CharClass.ClassName(action.sym))
	else
	  Trace.print(Ch(action.sym))
	end

	targ=action.target
	while (targ!=nil) do
	  Trace.print(" #{targ.state.nr}")
	  if (action.tc==Node::ContextTrans) then
	    Trace.println(" context")
	  else
	    Trace.println()
	  end
	  targ=targ.nxt
	end
	action=action.nxt
      end
      state=state.nxt
    end
    Trace.println("\n---------- character classes ----------")
    i = 0
    while (i<=CharClass.maxC) do
      set = CharClass.Class(i)
      Trace.println("#{CharClass.ClassName(i)}: #{set}")
      i += 1
    end
  end

  def self.GenComBody(com)
    @@gen.println("\t\tloop do")
    @@gen.println("\t\t\tif (#{ChCond(com.stop[0])}) then")
    if (com.stop.length()==1) then
      @@gen.println("\t\t\t\tlevel -= 1")
      @@gen.println("\t\t\t\tif (level==0) then ; oldEols=@@line-line0; NextCh(); return true; end")
      @@gen.println("\t\t\t\tNextCh()")
    else # REFACTOR
      @@gen.println("\t\t\t\tNextCh()")
      @@gen.println("\t\t\t\tif (#{ChCond(com.stop[1])}) then")
      @@gen.println("\t\t\t\t\tlevel -= 1")
      @@gen.println("\t\t\t\t\tif (level==0) then ; oldEols=@@line-line0; NextCh(); return true; end")
      @@gen.println("\t\t\t\t\tNextCh()")
      @@gen.println("\t\t\t\tend")
    end

    if (com.nested) then
      @@gen.println("\t\t\telsif (#{ChCond(com.start[0])}) then")
      if (com.start.length()==1) then
	@@gen.println("\t\t\t\tlevel += 1; NextCh()")
      else
	@@gen.println("\t\t\t\tNextCh()")
	@@gen.println("\t\t\t\tif (#{ChCond(com.start[1])}) then")
	@@gen.println("\t\t\t\t\tlevel += 1; NextCh()")
	@@gen.println("\t\t\t\tend")
      end
    end
    @@gen.println("\t\t\telsif (@@ch==EOF) then; return false")
    @@gen.println("\t\t\telse NextCh()")
    @@gen.println("\t\t\tend")
    @@gen.println("\t\tend")
  end

  def self.GenComment(com, i)
    @@gen.println("private; def self.Comment#{i}()")
    @@gen.println("\tlevel = 1; line0 = @@line; lineStart0 = @@lineStart; startCh=nil")
    if (com.start.length()==1) then
      @@gen.println("\tNextCh()")
      GenComBody(com)
    else
      @@gen.println("\tNextCh()")
      @@gen.println("\tif (#{ChCond(com.start[1])}) then")
      @@gen.println("\t\tNextCh()")
      GenComBody(com)
      @@gen.println("\telse")
      @@gen.println("\t\tif (@@ch==EOL) then; @@line -= 1; @@lineStart = lineStart0; end")
      @@gen.println("\t\t@@pos -= 2; Buffer.Set(@@pos+1); NextCh()")
      @@gen.println("\tend")
    end
    @@gen.println("\treturn false")
    @@gen.println("end")
  end

  # REFACTOR: this is duplicate code from ParserGen
  def self.CopyFramePart(stop)
    ch = i = j = 0
    startCh = stop[0]
    high = stop.length() - 1

    begin
      ch = (@@fram.read(1))[0]
      while (ch!=EOF) do
	if (ch==startCh) then
	  i = 0
	  begin
	    return if (i==high) # stop[0..i] found
	    ch = (@@fram.read(1))[0]
	    i += 1
	  end while (ch==stop[i])
	  # stop[0..i-1] found; continue with last read character
	  @@gen.print(stop[0...i])
	elsif (ch==CR) then
	  @@gen.println()
	  ch = (@@fram.read(1))[0]
	elsif (ch==LF) then
	  @@gen.println()
	  ch = (@@fram.read(1))[0]
	else
	  @@gen.print(ch.chr)
	  ch = (@@fram.read(1))[0]
	end
      end
    rescue
      Scanner.err.Exception("-- error reading Scanner.frame")
    end
  end

  def self.GenLiterals
    i = j = k = l = ch = 0
    sym = nil
    key = Array.new(128)
    knr = Array.new(128, 0)
    # sort literal list (don't consider eofSy)
    k = 0

    Sym.each_terminal do |sym|
      if (sym.graph==Sym::LitToken) then
	j = k-1
	while (j>=0 && ((sym.name <=> key[j]) < 0)) do
	  key[j+1] = key[j]
	  knr[j+1] = knr[j]
	  j -= 1
	end
	key[j+1] = sym.name
	knr[j+1] = sym.n # HACK was i... not sure if this is good or not
	k += 1
      end
    end

    # print switch statement
    i = 0
    while (i < k) do
      ch = key[i][1] # key[i, 0] is quote
      @@gen.println("\t\t\twhen #{Ch(ch)}")
      j = i
      begin
	if (i==j) then
	  @@gen.print("\t\t\t\tif ")
	else
	  @@gen.print("\t\t\t\telsif ")
	end
	@@gen.println("(@@t.val == #{key[i]}) then; @@t.kind = #{knr[i]}")
	i+= 1
      end while (i<k && !key[i].nil? && key[i][1]==ch)
      @@gen.println("\t\t\t\tend")
    end
  end

  def self.WriteState(state)
    action = sym = nil
    ctxEnd = false
    endOf = state.endOf

    @@gen.println("\t\t\t\twhen #{state.nr}")
    ctxEnd = state.ctx

    action = state.firstAction
    until (action.nil?) do
      if (action==state.firstAction) then
	@@gen.print("\t\t\t\t\tif (")
      else
	@@gen.print("\t\t\t\t\telsif (")
      end

      if (action.typ==Node::Chr)
	@@gen.print(ChCond(action.sym)) # FIX: action.sym might be a char?
      else
	PutRange(CharClass.Class(action.sym))
      end
      @@gen.println(") then")
      if (action.target.state != state) then
	@@gen.println("state = #{action.target.state.nr}")
      end
      if (action.tc == Node::ContextTrans) then
	@@gen.println("apx += 1")
	ctxEnd = false
      elsif (state.ctx) then
	@@gen.println("apx = 0")
      end
      action = action.nxt
    end # while

    @@gen.println("\t\t\t\t\telse") unless state.firstAction.nil?

    if (endOf==Sym::NoSym) then
      @@gen.println("@@t.kind = @@noSym; break; end")
    else # final state
      if (state.firstAction.nil?) then
	@@gen.print("\t\t\t\t\t")
      else
	@@gen.print("")
      end
      sym = endOf
      if (ctxEnd) then # final context state: cut appendix
	@@gen.println()
	@@gen.println("\t\t\t\t\t\tpos = pos - apx - 1; Buffer.Set(pos+1); i = buf.length()")
	@@gen.println("\t\t\t\t\t\twhile (apx > 0) do")
	@@gen.println("\t\t\t\t\t\t\ti -= 1")
	@@gen.println("\t\t\t\t\t\t\t@@ch = buf[i]")
	@@gen.println("\t\t\t\t\t\t\tif (@@ch==EOL) then line -= 1; end")
	@@gen.println("\t\t\t\t\t\t\tapx -= 1")
	@@gen.println("\t\t\t\t\t\tend")
	@@gen.println("\t\t\t\t\t\tNextCh()")
	@@gen.print(  "\t\t\t\t\t\t")
      end
      @@gen.println("@@t.kind = #{endOf}")
      if (sym.graph==Sym::ClassLitToken) then
	@@gen.println("@@t.val = buf.to_s; CheckLiteral()")
      end
      @@gen.println("break")
      if (state.firstAction != nil)
	@@gen.println("end")
      end
    end
  end

  def self.FillStartTab(startTab) # array of ints
    targetState = max = i = 0
    s = nil
    startTab[0] = State.lastNr + 1 # eof

    action = @@firstState.firstAction
    until (action.nil?) do
      targetState = action.target.state.nr
      if (action.typ==Node::Chr) then
	startTab[action.sym] = targetState
      else
	s = CharClass.Class(action.sym)
	max = s.size()
	for i in 0..max do
	  startTab[i] = targetState if (s.get(i))
	end
      end
      action=action.nxt
    end
  end

  def self.WriteScanner
    i = j = max = 0
    startTab = Array.new(128, 0)
    ok = true
    s = com = nil
    root = Tab.gramSy

    begin
      @@fram = File.new(@@srcDir + "/Scanner.frame")
    rescue
      Scanner.err.Exception("-- cannot open Scanner.frame. Must be in the same directory as the grammar file.")
    end

    begin
      @@gen = File.new(@@srcDir + "/Scanner.rb", "w")
    rescue
      Scanner.err.Exception("-- cannot generate scanner file")
    end

    ok = MakeDeterministic() if @@dirtyDFA

    FillStartTab(startTab)
    @@gen.println("# This file is generated. DO NOT MODIFY!")
    @@gen.println()
    @@gen.println("# TODO namespace/module starts here: package #{root.name};")
    CopyFramePart("-->declarations")
    @@gen.println("\tprivate; @@noSym = #{Sym.terminal_count-1}; # FIX: make this a constant")
    @@gen.println("\tprivate; @@start = [")
    for i in 0...8 do
      for j in 0...16 do
	@@gen.printf "%3d,", startTab[16*i+j]
      end
      @@gen.println()
    end

    @@gen.println("  0]")
    CopyFramePart("-->initialization")
    @@gen.print("\t\t")
    max = Tab.ignored.size()
    for i in 0..max do
      @@gen.println("@@ignore.set(#{i})") if Tab.ignored.get(i)
    end

    CopyFramePart("-->comment")
    com = Comment.first

    i = 0
    until (com.nil?) do
      GenComment(com, i)
      com = com.nxt
      i+= 1
    end

    CopyFramePart("-->literals")
    GenLiterals()
    CopyFramePart("-->scan1")

    unless (Comment.first.nil?) then
      @@gen.print("\t\tif (")
      com = Comment.first
      i = 0
      until (com.nil?) do
	@@gen.print(ChCond(com.start[0]))
	@@gen.print(" && Comment#{i}() ")
	@@gen.print(" || ") unless com.nxt.nil?
	com = com.nxt
	i += 1
      end
      @@gen.print(") then ; return Scan(); end")
    end

    CopyFramePart("-->scan2")
    state=@@firstState.nxt
    while (state!=nil)
      WriteState(state)
      state=state.nxt
    end
    @@gen.println("\t\t\t\twhen #{State.lastNr+1}")
    @@gen.println("\t\t\t\t\t@@t.kind = 0")
    CopyFramePart("$$$")
    @@gen.flush()
    return ok
  end

end # class DFA
