require 'Scanner'
require "module-hack"

class StateSet		# set of target states returned by GetTargetStates
  attr_accessor :set, :endOf, :ctx, :correct
  # BitSet set		# all target states of an action
  # int endOf		# token that is recognized after this action
  # boolean ctx	# true if target states are reached via context transition
  # boolean correct	# true if no error occured in GetTargetStates

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

  cls_attr_accessor :lastNr
  attr_accessor :nr, :firstAction, :endOf, :ctx, :next

  def initialize
    @@lastNr += 1
    @nr = @@lastNr
    @endOf = Tab::NoSym
    @ctx = false
    @firstAction = @next = nil
  end

  def ==(o)
    return !o.nil? &&
      @nr == o.nr &&
      @firstAction == o.firstAction &&
      @endOf == o.endOf &&
      @ctx == o.ctx &&
      @next == o.next
  end

  def AddAction(act)
    lasta = nil
    a = @firstAction
    while (a and act.typ >= a.typ) do
      lasta = a
      a = a.next
    end

    # collecting classes at the beginning gives better performance
    act.next = a
    if (a == @firstAction) then
      @firstAction = act
    else
      unless lasta.nil? then
	lasta.next = act
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
      a = a.next
    end

    if (a != nil) then
      if (a==@firstAction) then
	@firstAction = a.next
      else
	lasta.next = a.next
      end
    end
  end

  def TheAction(ch)
    s=nil
    a=@firstAction
    while (a!=nil) do
      if (a.typ==Tab::Chr && ch==a.sym) then
	return a
      elsif (a.typ==Tab::Clas) then
	s = Tab.Class(a.sym)
	return a if s.get(ch)
      end
      a=a.next
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
      action=action.next
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
  attr_accessor :next

  def initialize(typ, sym, tc)
    @typ = typ
    @sym = sym
    @tc = tc
    @target = @next = nil
  end

  def ==(o)
    return !o.nil? &&
      @typ == o.typ &&
      @sym == o.sym &&
      @tc == o.tc &&
      @next == o.next &&
      @target.eql?(o.target) # .eql? because == causes a cycle
  end

  def AddTarget(t)
    last = nil
    p = @target

    while (p != nil && t.state.nr >= p.state.nr) do
      return if t.state == p.state
      last = p
      p = p.next
    end
    t.next = p

    if (p==@target) then
      @target = t
    else
      last.next = t
    end
  end

  def AddTargets(a) # add copy of a.targets to action.targets
    t = last = nil

    p=a.target
    while (p!=nil) do
      t = Target.new(p.state)
      self.AddTarget(t)
      p=p.next
    end

    if (a.tc==Tab::ContextTrans) then
      @tc = Tab::ContextTrans
    end
  end

  def Symbols()
    s = nil

    if (@typ==Tab::Clas) then
      s = Tab.Class(@sym).clone()
    else
      s = BitSet.new()
      s.set(@sym)
    end

    return s
  end

  def ShiftWith(s)
    i = 0

    if (Sets.Size(s)==1) then
      @typ = Tab::Chr
      @sym = Sets.First(s)
    else

      i = Tab.maxC
      while (i>=0) do
	x = Tab.set()[Tab.chClass[i].set]
	i -= 1
      end

      i = Tab.ClassWithSet(s)
      if (i < 0) then # class with dummy name
	i = Tab.NewClass("#", s)
      end
      @typ = Tab::Clas
      @sym = i
    end
  end

  def GetTargetStates # compute the set of target states
    stateNr=0
    states = StateSet.new
    states.set = BitSet.new		# FIX: violation of encapsulation
    states.endOf = Tab::NoSym
    states.ctx = false
    states.correct = true

    t=target

    while (t!=nil) do
      stateNr = t.state.nr
      if (stateNr <= DFA.lastSimState) then
	states.set.set(stateNr)
      else
	states.set.or(Melted.Set(stateNr))
      end
      if (t.state.endOf!=Tab::NoSym) then
	if (states.endOf==Tab::NoSym || states.endOf==t.state.endOf) then
	  states.endOf = t.state.endOf
	else
	  System.out.println("Tokens #{states.endOf} and #{t.state.endOf} cannot be distinguished")
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
	# if (t.state.endOf!=Tab::NoSym) {
	# System.out.println("Ambiguous context clause")
	# states.correct = false
      end
      t=t.next
    end
    return states
  end

end # class Action

#-----------------------------------------------------------------------------
#  Target
#-----------------------------------------------------------------------------

class Target				# set of states that are reached by an action
  attr_accessor :state, :next

  def initialize(s)
    @state = s
    @next = nil
  end

  def ==(o)
    ! o.nil? &&
      @state == o.state &&
      @next == o.next
  end

end

#-----------------------------------------------------------------------------
#  Melted
#-----------------------------------------------------------------------------

class Melted			# info about melted states

  @@first = nil			# head of melted state list

  attr_accessor :set		# set of old states
  attr_accessor :state		# new state
  attr_accessor :next
  cls_attr_accessor :first

  def initialize(set, state)
    @set = set
    @state = state

    @next = @@first
    @@first = self
  end

  def ==(o)
    ! o.nil? &&
      @set == o.set &&
      @state == o.state &&
      @next == o.next
  end

  def self.Set(nr)
    m = @@first

    while (m != nil && m.state.nr != nr) do
      m = m.next
    end

    return m.set
  end

  def self.StateWithSet(s)
    m = @@first

    while (m != nil) do
      if (s == m.set) then
	return m
      end
      m = m.next
    end
    return nil
  end
end

#-----------------------------------------------------------------------------
#  Comment
#-----------------------------------------------------------------------------

class Comment				# info about comment syntax
  @@first = nil

  attr_accessor :start
  attr_accessor :stop
  attr_accessor :nested
  attr_accessor :next
#  cls_attr_accessor :first

  def initialize(from, to, nested)
    @start = self.class.Str(from)
    @stop = self.class.Str(to)
    @nested = nested
    @next = @@first
    @@first = self
  end

  def self.first # HACK HACK HACK
    raise "no"
  end

  def self.firstX # HACK HACK HACK
    @@first
  end

  def ==(o)
    raise "Not implemented yet"
  end

  # private maybe??
  def self.Str(p)
    s = ""
    n = nil
    set = nil

    while (p != 0) do
      n = Tab.Node(p)

      if (n.typ==Tab::Chr) then
	s << n.p1.chr
      elsif (n.typ==Tab::Clas) then
	set = Tab.Class(n.p1)
	if (Sets.Size(set) != 1) then
	  DFA.SemErr(26)
	end
	s << Sets.First(set).chr
      else
	DFA.SemErr(22)
      end
      p = n.next
    end

    if (s.length() > 2) then
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
    # HACK Comment.first = nil
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
      @@lastState.next = s
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
	b = a.next
	while (b != nil) do
	  if (a.target.state==b.target.state && a.tc==b.tc) then
	    seta = a.Symbols()
	    setb = b.Symbols()
	    seta.or(setb)
	    a.ShiftWith(seta)
	    c = b
	    b = b.next
	    state.DetachAction(c)
	  else
	    b = b.next
	  end
	end # while
	a=a.next
      end # while
      state=state.next
    end # while
  end

  def self.FindUsedStates(state, used)
    return if used.get(state.nr)

    used.set(state.nr)
    a=state.firstAction
    until (a.nil?) do
      FindUsedStates(a.target.state, used)
      a=a.next
    end
  end

  def self.DeleteRedundantStates
    newState = Array.new(MAXSTATES)
    used = BitSet.new()
    FindUsedStates(@@firstState, used)

    # combine equal final states
    s1=@@firstState.next
    until (s1.nil?) do # firstState cannot be final
      if (used.get(s1.nr) && s1.endOf != Tab::NoSym && s1.firstAction.nil? && !s1.ctx) then
	s2=s1.next
	until (s2.nil?) do
	  if (used.get(s2.nr) && s1.endOf == s2.endOf && s2.firstAction.nil? && !s2.ctx) then
	    used.clear(s2.nr)
	    newState[s2.nr] = s1
	  end
	  s2=s2.next
	end
      end
      s1=s1.next
    end

    state=@@firstState
    until (state.nil?) do
      if (used.get(state.nr)) then
	a=state.firstAction
	until (a.nil?) do
	  unless (used.get(a.target.state.nr)) then
	    a.target.state = newState[a.target.state.nr]
	  end
	  a=a.next
	end
      end
      state=state.next
    end

    # delete unused states
    @@lastState = @@firstState
    State.lastNr = 0 # @@firstState has number 0

    state=@@firstState.next
    until (state.nil?) do
      if (used.get(state.nr)) then
	State.lastNr += 1
	state.nr = State.lastNr
	@@lastState = state
      else
	@@lastState.next = state.next
      end
      state=state.next
    end
  end

  def self.TheState(p)
    state = nil
    if (p==0) then
      state = self.NewState()
      state.endOf = @@curSy
    else
      state = Tab.Node(p).state
    end
    return state
  end

  def self.Step(from, p, stepped)
    n = nil
    return if p == 0

    stepped.set(p)
    n = Tab.Node(p)

    case (n.typ)
    when Tab::Clas, Tab::Chr then
      NewTransition(from, TheState(n.next.abs), n.typ, n.p1, n.p2)
    when Tab::Alt then
      Step(from, n.p1, stepped)
      Step(from, n.p2, stepped)
    when Tab::Iter, Tab::Opt then
      nxt = n.next.abs
      if (!stepped.get(nxt)) then
	Step(from, nxt, stepped)
      end
      Step(from, n.p1, stepped)
    end
  end

  def self.NumberNodes(p, state)
    # Assigns a state n.state to every node n. There will be a transition from
    # n.state to n.next.state triggered by n.sym. All nodes in an alternative
    # chain are represented by the same state.

    return if p == 0

    n = Tab.Node(p)

    return unless n.state.nil? # already visited

    if (state.nil?) then
      state = NewState()
    end

    n.state = state

    if (Tab.DelGraph(p)) then
      state.endOf = @@curSy
    end

    case (n.typ)
    when Tab::Clas, Tab::Chr then
      NumberNodes(n.next.abs, nil)
    when Tab::Opt then
      NumberNodes(n.next.abs, nil)
      NumberNodes(n.p1, state)
    when Tab::Iter then
      NumberNodes(n.next.abs, state)
      NumberNodes(n.p1, state)
    when Tab::Alt then
      NumberNodes(n.p1, state)
      NumberNodes(n.p2, state)
    end
  end

  def self.FindTrans (p, start, mark)
    return if p==0 || mark.get(p)
    mark.set(p)
    n = Tab.Node(p)

    if (start) then
      Step(n.state, p, BitSet.new(512)) # start of group of equally numbered nodes
    end

    case (n.typ)
    when Tab::Clas, Tab::Chr then
      FindTrans(n.next.abs, true, mark)
    when Tab::Opt then
      FindTrans(n.next.abs, true, mark)
      FindTrans(n.p1, false, mark)
    when Tab::Iter then
      FindTrans(n.next.abs, false, mark)
      FindTrans(n.p1, false, mark)
    when Tab::Alt then
      FindTrans(n.p1, false, mark)
      FindTrans(n.p2, false, mark)
    end
  end

  def self.ConvertToStates(p, sp)
    @@curGraph = p
    @@curSy = sp

    if (Tab.DelGraph(@@curGraph)) then
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

      if (a.typ == Tab::Clas) then
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
      NewTransition(state, to, Tab::Chr, s[i], Tab::NormTrans)
      state = to
      i += 1
    end

    matchedSp = state.endOf
    if (state.endOf==Tab::NoSym) then
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

    if (a.typ==Tab::Chr) then
      if (b.typ==Tab::Chr) then
	result = a.sym==b.sym
      else
	setb = Tab.Class(b.sym)
	result = setb.get(a.sym)
      end
    else
      seta = Tab.Class(a.sym)
      if (b.typ==Tab::Chr) then
	result = seta.get(b.sym)
      else
	setb = Tab.Class(b.sym)
	result = ! Sets.Different(seta, setb)
      end
    end
    return result
  end

  def self.MakeUnique(state) # return true if actions were split # verified 2003-07-13
    changed = false

    a = state.firstAction
    until (a.nil?) do
      b = a.next
      until (b.nil?) do
	if (Overlap(a, b)) then
	  SplitActions(state, a, b)
	  changed = true
	end
	b = b.next
      end
      a = a.next
    end
    return changed
  end

  def self.MeltStates(state)
    changed = correct = true
    states = s = targ = melt = nil

    action=state.firstAction
    while (action!=nil) do
      if (action.target.next != nil) then
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
	    targ=targ.next
	  end
	  begin
	    changed = MakeUnique(s)
	  end while changed
	  melt = Melted.new(states.set, s)
	end
	action.target.next = nil
	action.target.state = melt.state
      end
      action=action.next
    end
    return correct
  end

  def self.FindCtxStates()
    state = @@firstState
    while (state!=nil) do
      a = state.firstAction
      while (a != nil) do
	if a.tc == Tab::ContextTrans then
	  a.target.state.ctx = true
	end
	a=a.next
      end
      state=state.next
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
      state=state.next
    end
    correct = true

    state=@@firstState
    while (state!=nil) do
      correct = MeltStates(state) && correct
      state=state.next
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

      if (state.endOf == Tab::NoSym) then
	Trace.print("     ")
      else
	Trace.print("E(#{sprintf('%2d', state.endOf)[0..1]})")
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
	if (action.typ==Tab::Clas) then
	  Trace.print(Tab.ClassName(action.sym))
	else
	  Trace.print(Ch(action.sym))
	end

	targ=action.target
	while (targ!=nil) do
	  Trace.print(" #{targ.state.nr}")
	  if (action.tc==Tab::ContextTrans) then
	    Trace.println(" context")
	  else
	    Trace.println()
	  end
	  targ=targ.next
	end
	action=action.next
      end
      state=state.next
    end
    Trace.println("\n---------- character classes ----------")
    i = 0
    while (i<=Tab.maxC) do
      set = Tab.Class(i)
      Trace.println("#{Tab.ClassName(i)}: #{set}")
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

    for i in 1..Tab.maxT do
      sym = Tab.Sym(i)
      if (sym.struct==Tab::LitToken) then
	j = k-1
	while (j>=0 && ((sym.name <=> key[j]) < 0)) do
	  key[j+1] = key[j]
	  knr[j+1] = knr[j]
	  j -= 1
	end
	key[j+1] = sym.name
	knr[j+1] = i
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

    if (endOf > Tab.maxT) then
      endOf = Tab.maxT + Tab::MaxSymbols - endOf # pragmas have been moved
    end

    @@gen.println("\t\t\t\twhen #{state.nr}")
    ctxEnd = state.ctx

    action = state.firstAction
    until (action.nil?) do
      if (action==state.firstAction) then
	@@gen.print("\t\t\t\t\tif (")
      else
	@@gen.print("\t\t\t\t\telsif (")
      end

      if (action.typ==Tab::Chr)
	@@gen.print(ChCond(action.sym)) # FIX: action.sym might be a char?
      else
	PutRange(Tab.Class(action.sym))
      end
      @@gen.println(") then")
      if (action.target.state != state) then
	@@gen.println("state = #{action.target.state.nr}")
      end
      if (action.tc == Tab::ContextTrans) then
	@@gen.println("apx += 1")
	ctxEnd = false
      elsif (state.ctx) then
	@@gen.println("apx = 0")
      end
      action = action.next
    end # while

    # NO @@gen.println("\t\t\t\t\t\tbreak") if (action.next==nil)
    @@gen.println("\t\t\t\t\telse") unless state.firstAction.nil?

    if (endOf==Tab::NoSym) then
      @@gen.println("@@t.kind = @@noSym; break; end")
    else # final state
      if (state.firstAction.nil?) then
	@@gen.print("\t\t\t\t\t")
      else
	@@gen.print("")
      end
      sym = Tab.Sym(endOf)
      if (ctxEnd) then # final context state: cut appendix
	@@gen.println()
	@@gen.println("\t\t\t\t\t\tpos = pos - apx - 1; Buffer.Set(pos+1); i = buf.length()")
	@@gen.println("\t\t\t\t\t\twhile (apx > 0) do")
	@@gen.println("\t\t\t\t\t\t\ti -= 1")
	@@gen.println("\t\t\t\t\t\t\t@@ch = buf[i]") # FIX HACK
	@@gen.println("\t\t\t\t\t\t\tif (@@ch==EOL) then line -= 1; end")
	@@gen.println("\t\t\t\t\t\t\tapx -= 1")
	@@gen.println("\t\t\t\t\t\tend")
	# HACK @@gen.println("\t\t\t\t\t\tbuf.setLength(i)")
	@@gen.println("\t\t\t\t\t\tNextCh()")
	@@gen.print(  "\t\t\t\t\t\t")
      end
      @@gen.println("@@t.kind = #{endOf}")
      if (sym.struct==Tab::ClassLitToken) then
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
      if (action.typ==Tab::Chr) then
	startTab[action.sym] = targetState
      else
	s = Tab.Class(action.sym)
	max = s.size()
	for i in 0..max do
	  startTab[i] = targetState if (s.get(i))
	end
      end
      action=action.next
    end
  end

  def self.WriteScanner
    i = j = max = 0
    startTab = Array.new(128, 0)
    ok = true
    s = com = nil
    root = Tab.Sym(Tab.gramSy)

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
    @@gen.println("# HACK: package #{root.name};")
    CopyFramePart("-->declarations")
    @@gen.println("\tprivate; @@noSym = #{Tab.maxT}; # FIX: make this a constant")
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
    com = Comment.firstX # HACK

    i = 0
    until (com.nil?) do
      GenComment(com, i)
      com = com.next
      i+= 1
    end

    CopyFramePart("-->literals")
    GenLiterals()
    CopyFramePart("-->scan1")

    unless (Comment.firstX.nil?) then # HACK
      @@gen.print("\t\tif (")
      com = Comment.firstX # HACK 
      i = 0
      until (com.nil?) do
	@@gen.print(ChCond(com.start[0]))
	@@gen.print(" && Comment#{i}() ")
	@@gen.print(" || ") unless com.next.nil?
	com = com.next
	i += 1
      end
      @@gen.print(") then ; return Scan(); end")
    end

    CopyFramePart("-->scan2")
    state=@@firstState.next
    while (state!=nil)
      WriteState(state)
      state=state.next
    end
    @@gen.println("\t\t\t\twhen #{State.lastNr+1}")
    @@gen.println("\t\t\t\t\t@@t.kind = 0")
    CopyFramePart("$$$")
    @@gen.flush()
    return ok
  end

end # class DFA
