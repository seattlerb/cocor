
class StateSet					# set of target states returned by GetTargetStates
  attr_accessor :set, :endOf, :ctx, :correct
  # BitSet set					# all target states of an action
  # int endOf					# token that is recognized after this action
  # boolean ctx					# true if target states are reached via context transition
  # boolean correct				# true if no error occured in GetTargetStates
end

#-----------------------------------------------------------------------------
#  State
#-----------------------------------------------------------------------------

class State						# state of finite automaton
  @@lastNr = 0
  attr_accessor :nr, :firstAction, :endOf, :ctx, :next
  
  # static int lastNr					# highest state number
  # int nr						# state number
  # Action firstAction				# to first action of this state
  # int endOf						# nr. of recognized token if state is final
  # boolean ctx					# true if state is reached via contextTrans
  # State next
  
  def initialize
    @nr = @@lastNr
    @@lastNr += 1
    @endOf = Tab.noSym
    @firstAction = nil
    @endOf = 0
    @ctx = false
    @state = nil
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
      lasta.next = act
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
      if (a.typ==Tab.chr && ch==a.sym) then
	return a
      elsif (a.typ==Tab.clas) then
	s = Tab.Class(a.sym)
	if (s.get(ch)) then
	  return a
	else
	  return nil
	end
      end
      a=a.next
    end
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

class Action						# action of finite automaton
  attr_accessor :typ					# type of action symbol: clas, chr
  attr_accessor :sym					# action symbol
  attr_accessor :tc					# transition code: normTrans, contextTrans
  attr_accessor :target				# states reached from this action
  attr_accessor :next
  
  def initialize(typ, sym, tc)
    @typ = typ
    @sym = sym
    @tc = tc
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

    if (a.tc==Tab.contextTrans) then
      @tc = Tab.contextTrans
    end
  end

  def Symbols()
    s = nil

    if (@typ==Tab.clas) then
      s = Tab.Class(@sym).clone()
    else 
      s = new BitSet() 
      s.set(@sym)
    end

    return s
  end
  
  def ShiftWith(s)
    i = 0

    if (Sets.Size(s)==1) then
      @typ = Tab.chr
      @sym = Sets.First(s)
    else
      i = Tab.ClassWithSet(s)
      if (i < 0) then # class with dummy name
	i = Tab.NewClass("#", s)
      end
      @typ = Tab.clas
      @sym = i
    end
  end
  
  def GetTargetStates # compute the set of target states
    stateNr=0
    states = StateSet.new
    states.set = BitSet.new		# FIX: violation of encapsulation
    states.endOf = Tab.noSym
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
      if (t.state.endOf!=Tab.noSym) then
	if (states.endOf==Tab.noSym || states.endOf==t.state.endOf) then
	  states.endOf = t.state.endOf
	else
	  System.out.println("Tokens " + states.endOf + " and " + t.state.endOf + " cannot be distinguished")
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
	# if (t.state.endOf!=Tab.noSym) {
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
end

#-----------------------------------------------------------------------------
#  Melted
#-----------------------------------------------------------------------------

class Melted			# info about melted states

  @@first = nil			# head of melted state list

  attr_accessor :set		# set of old states
  attr_accessor :state		# new state
  attr_accessor :next 
  
  def initialize(set, state)
    @set = set
    @state = state
    
    @next = @@first
    @@first = self
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
      if (s.equals(m.set)) then
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
  
  # private maybe??
  def self.Str(p)
    s = ""
    n = nil
    set = nil

    while (p != 0) do
      n = Tab.Node(p)

      if (n.typ==Tab.chr) then
	s << n.p1.chr
      elsif (n.typ==Tab.clas) then
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
  
  def initialize(from, to, nested)
    @start = Str(from)
    @stop = Str(to)
    @nested = nested
    @next = @@first
    @@first = self
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
  @@lastState=nil			# last allocated state
  @@lastSimState=nil		# last non melted state
  @@fram=nil		# scanner frame input
  @@gen=nil			# generated scanner file
  @@srcDir=nil			# directory of attribute grammar file
  @@curSy=nil				# current token to be recognized (in FindTrans)
  @@curGraph=nil			# start of graph for current token (in FindTrans)
  @@dirtyDFA=nil		# DFA may become nondeterministic in MatchedDFA

  def self.Init(dir)
  end
    
  def self.SemErr(n)
    Scanner.err.SemErr(n, 0, 0)
  end
    
end

__END__

    private static String Int(int n, int len) {
      char[] a = new char[16];
      String s = String.valueOf(n);
      int i, j, d = len - s.length();
      for (i=0; i<d; i++) a[i] = ' ';
	for (j=0; i<len; i++) {a[i] = s.charAt(j); j++;}
	  return new String(a, 0, len);
	}
	
	private static String Ch(char ch) {
	  if (ch<' ' || ch>=127 || ch=='\'' || ch=='\\') return String.valueOf((int)ch);
	  else return "'" + ch + "'";
	  }
	  
	  private static String ChCond(char ch) {
	    return "@@ch==" + Ch(ch);
	  }
	  
	  private static void PutRange(BitSet s) {
	    int[] lo = new int[32];
	    int[] hi = new int[32];
	    BitSet s1;
	    int i, top;
	    # fill lo and hi
	    top = -1; i = 0;
	    while (i < 128) {
		if (s.get(i)) {
		    top++; lo[top] = i; i++;
		    while (i < 128 && s.get(i)) i++;
		      hi[top] = i-1;
		    } else i++;
		  }
		  # print ranges
		  if (top==1 && lo[0]==0 && hi[1]==127 && hi[0]+2==lo[1]) {
		      s1 = new BitSet(); s1.set(hi[0]+1);
		      gen.print("!"); PutRange(s1);
		    } else {
		      gen.print("(");
		      for (i=0; i<=top; i++) {
			  if (hi[i]==lo[i]) gen.print("@@ch==" + Ch((char)lo[i]));
			  else if (lo[i]==0) gen.print("@@ch<=" + Ch((char)hi[i]));
			       else if (hi[i]==127) gen.print("@@ch>=" + Ch((char)lo[i]));
				    else gen.print("@@ch>=" + Ch((char)lo[i]) + " && @@ch<=" + Ch((char)hi[i]));
				      if (i < top) gen.print(" || ");
				      }
				      gen.print(")");
				    }
			       }
			    
			    private static State NewState() {
			      State s = new State();
			      if (firstState==nil) firstState = s; else lastState.next = s;
				lastState = s;
				return s;
			      }
			      
			      private static void NewTransition(State from, State to, int typ, int sym, int tc) {
				Action a;
				Target t;
				if (to==firstState) SemErr(21);
				  t = new Target(to);
				  a = new Action(typ, sym, tc); a.target = t;
				  from.AddAction(a);
				}
				
				private static void CombineShifts() {
				  State state;
				  Action a, b, c;
				  BitSet seta, setb;
				  for (state=firstState; state!=nil; state=state.next) {
				      for (a=state.firstAction; a!=nil; a=a.next) {
					  b = a.next;
					  while (b != nil)
					    if (a.target.state==b.target.state && a.tc==b.tc) {
						seta = a.Symbols(); setb = b.Symbols();
						seta.or(setb);
						a.ShiftWith(seta);
						c = b; b = b.next; state.DetachAction(c);
					      } else b = b.next;
					    }
					  }
					}
					
					private static void FindUsedStates(State state, BitSet used) {
					  if (used.get(state.nr)) return;
					    used.set(state.nr);
					    for (Action a=state.firstAction; a!=nil; a=a.next)
					      FindUsedStates(a.target.state, used);
					    }
					    
					    private static void DeleteRedundantStates() {
					      State[] newState = new State[MAXSTATES];
					      BitSet used = new BitSet();
					      FindUsedStates(firstState, used);
					      # combine equal final states
					      for (State s1=firstState.next; s1!=nil; s1=s1.next) # firstState cannot be final
						if (used.get(s1.nr) && s1.endOf!=Tab.noSym && s1.firstAction==nil && !s1.ctx)
						  for (State s2=s1.next; s2!=nil; s2=s2.next)
						    if (used.get(s2.nr) && s1.endOf==s2.endOf && s2.firstAction==nil & !s2.ctx) {
							used.clear(s2.nr); newState[s2.nr] = s1;
						      }
						      for (State state=firstState; state!=nil; state=state.next)
							if (used.get(state.nr))
							  for (Action a=state.firstAction; a!=nil; a=a.next)
							    if (!used.get(a.target.state.nr))
							      a.target.state = newState[a.target.state.nr];
							      # delete unused states
							      lastState = firstState; State.lastNr = 0; # firstState has number 0
							      for (State state=firstState.next; state!=nil; state=state.next)
								if (used.get(state.nr)) {state.nr = ++State.lastNr; lastState = state;}
								else lastState.next = state.next;
								}
								
								private static State TheState(int p) {
								  State state;
								  if (p==0) {state = NewState(); state.endOf = curSy; return state;}
								  else return Tab.Node(p).state;
								  }
								  
								  private static void Step(State from, int p, BitSet stepped) {
								    GraphNode n;
								    if (p==0) return;
								      stepped.set(p);
								      n = Tab.Node(p);
								      switch (n.typ) {
									case Tab.clas: case Tab.chr: {
									      NewTransition(from, TheState(Math.abs(n.next)), n.typ, n.p1, n.p2);
									      break;
									    }
											 case Tab.alt: {
										Step(from, n.p1, stepped); Step(from, n.p2, stepped);
										break;
									      }
											   case Tab.iter: case Tab.opt: {
										    int next = Math.abs(n.next);
										    if (!stepped.get(next)) Step(from, next, stepped);
										      Step(from, n.p1, stepped);
										      break;
										    }
										  }
													  }
											     
											     private static void NumberNodes(int p, State state) {
										  # Assigns a state n.state to every node n. There will be a transition from
										  # n.state to n.next.state triggered by n.sym. All nodes in an alternative
										  # chain are represented by the same state.

										  if (p==0) return;
										    GraphNode n = Tab.Node(p);
										    if (n.state != nil) return; # already visited;
										      if (state==nil) state = NewState();
											n.state = state;
											if (Tab.DelGraph(p)) state.endOf = curSy;
											  switch (n.typ) {
											    case Tab.clas: case Tab.chr: {
												  NumberNodes(Math.abs(n.next), nil);
												  break;
												}
													     case Tab.opt: {
												    NumberNodes(Math.abs(n.next), nil); NumberNodes(n.p1, state);
												    break;
												  }
													       case Tab.iter: {
												      NumberNodes(Math.abs(n.next), state); NumberNodes(n.p1, state);
												      break;
												    }
														 case Tab.alt: {
													NumberNodes(n.p1, state); NumberNodes(n.p2, state);
													break;
												      }
														 }
													       }
													       
													       private static void FindTrans (int p, boolean start, BitSet mark) {
												    if (p==0 || mark.get(p)) return;
												      mark.set(p);
												      GraphNode n = Tab.Node(p);
												      if (start) Step(n.state, p, new BitSet(512)); # start of group of equally numbered nodes
													switch (n.typ) {
													  case Tab.clas: case Tab.chr: {
														FindTrans(Math.abs(n.next), true, mark);
														break;
													      }
															   case Tab.opt: {
														  FindTrans(Math.abs(n.next), true, mark); FindTrans(n.p1, false, mark);
														  break;
														}
															     case Tab.iter: {
														    FindTrans(Math.abs(n.next), false, mark); FindTrans(n.p1, false, mark);
														    break;
														  }
															       case Tab.alt: {
														      FindTrans(n.p1, false, mark); FindTrans(n.p2, false, mark);
														      break;
														    }
															       }
															     }
															     
															     static void ConvertToStates(int p, int sp) {
														  curGraph = p; curSy = sp;
														  if (Tab.DelGraph(curGraph)) SemErr(20);
														    NumberNodes(curGraph, firstState);
														    FindTrans(curGraph, true, new BitSet(512));
														  }
														  
														  static int MatchedDFA(String s, int sp) {
														    State state, to;
														    Action a;
														    int i, matchedSp, len = s.length() - 1;
														    boolean weakMatch = false;
														    # s has quotes
														    state = firstState;
														    for (i=1; i<len; i++) { # try to match s against existing DFA
															a = state.TheAction(s.charAt(i));
															if (a==nil) break;
															  if (a.typ == Tab.clas) weakMatch = true;
															    state = a.target.state;
															  }
															  if (weakMatch && i < len) {
															      state = firstState; i = 1;
															      dirtyDFA = true;
															    }
															    for (;i<len; i++) { # make new DFA for s[i..len-1]
																to = NewState();
																NewTransition(state, to, Tab.chr, s.charAt(i), Tab.normTrans);
																state = to;
															      }
															      matchedSp = state.endOf;
															      if (state.endOf==Tab.noSym) state.endOf = sp;
																return matchedSp;
															      }
															      
															      private static void SplitActions(State state, Action a, Action b) {
																Action c; BitSet seta, setb, setc;
																seta = a.Symbols(); setb = b.Symbols();
																if (seta.equals(setb)) {
																    a.AddTargets(b);
																    state.DetachAction(b);
																  } else if (Sets.Includes(seta, setb)) {
																      setc = (BitSet) seta.clone(); Sets.Differ(setc, setb);
																      b.AddTargets(a);
																      a.ShiftWith(setc);
																    } else if (Sets.Includes(setb, seta)) {
																	setc = (BitSet) setb.clone(); Sets.Differ(setc, seta);
																	a.AddTargets(b);
																	b.ShiftWith(setc);
																      } else {
																	setc = (BitSet) seta.clone(); setc.and(setb);
																	Sets.Differ(seta, setc);
																	Sets.Differ(setb, setc);
																	a.ShiftWith(seta);
																	b.ShiftWith(setb);
																	c = new Action(0, 0, 0);
																	c.AddTargets(a);
																	c.AddTargets(b);
																	c.ShiftWith(setc);
																	state.AddAction(c);
																      }
																	   }
																	   
																	   private static boolean Overlap(Action a, Action b) {
																      BitSet seta, setb;
																      if (a.typ==Tab.chr)
																	if (b.typ==Tab.chr) return a.sym==b.sym;
																	else {setb = Tab.Class(b.sym); return setb.get(a.sym);}
																	else {
																	    seta = Tab.Class(a.sym);
																	    if (b.typ==Tab.chr) return seta.get(b.sym);
																	    else {setb = Tab.Class(b.sym); return !Sets.Different(seta, setb);}
																	    }
																	  }
																	  
																	  private static boolean MakeUnique(State state) { # return true if actions were split
																	    boolean changed = false;
																	    for (Action a=state.firstAction; a!=nil; a=a.next)
																	      for (Action b=a.next; b!=nil; b=b.next)
																		if (Overlap(a, b)) {SplitActions(state, a, b); changed = true;}
																		  return changed;
																		}
																		
																		private static boolean MeltStates(State state) {
																		  boolean changed, correct = true;
																		  StateSet states;
																		  State s;
																		  Target targ;
																		  Melted melt;
																		  for (Action action=state.firstAction; action!=nil; action=action.next) {
																		      if (action.target.next != nil) {
																			  states = action.GetTargetStates();
																			  correct = correct && states.correct;
																			  melt = Melted.StateWithSet(states.set);
																			  if (melt==nil) {
																			      s = NewState(); s.endOf = states.endOf; s.ctx = states.ctx;
																			      for (targ=action.target; targ!=nil; targ=targ.next)
																				s.MeltWith(targ.state);
																				do {changed = MakeUnique(s);} while (changed);
																				  melt = new Melted(states.set, s);
																				}
																				action.target.next = nil;
																				action.target.state = melt.state;
																			      }
																			    }
																			    return correct;
																			  }
																			  
																			  private static void FindCtxStates() {
																			    for (State state=firstState; state!=nil; state=state.next)
																			      for (Action a=state.firstAction; a!=nil; a=a.next)
																				if (a.tc==Tab.contextTrans) a.target.state.ctx = true;
																				}
																				
																				static boolean MakeDeterministic() {
																				  State state;
																				  boolean changed, correct;
																				  lastSimState = lastState.nr;
																				  FindCtxStates();
																				  for (state=firstState; state!=nil; state=state.next)
																				    do {changed = MakeUnique(state);} while (changed);
																				      correct = true;
																				      for (state=firstState; state!=nil; state=state.next)
																					correct = MeltStates(state) && correct;
																					DeleteRedundantStates();
																					CombineShifts();
																					return correct;
																				      }
																				      
																				      static void PrintStates() {
																					Action action; Target targ;
																					BitSet set;
																					boolean first;
																					Trace.println("\n---------- states ----------");
																					for (State state=firstState; state!=nil; state=state.next) {
																					    first = true;
																					    if (state.endOf==Tab.noSym) Trace.print("     ");
																					    else Trace.print("E(" + Int(state.endOf, 2) + ")");
																					      Trace.print(Int(state.nr, 3) + ":");
																					      if (state.firstAction==nil) Trace.println();
																						for (action=state.firstAction; action!=nil; action=action.next) {
																						    if (first) {Trace.print(" "); first = false;} else Trace.print("          ");
																						      if (action.typ==Tab.clas) Trace.print(Tab.ClassName(action.sym));
																						      else Trace.print(Ch((char)action.sym));
																							for (targ=action.target; targ!=nil; targ=targ.next)
																							  Trace.print(" " + targ.state.nr);
																							  if (action.tc==Tab.contextTrans) Trace.println(" context"); else Trace.println();
																							  }
																							}
																							Trace.println("\n---------- character classes ----------");
																							for (int i=0; i<=Tab.maxC; i++) {
																							    set = Tab.Class(i);
																							    Trace.println(Tab.ClassName(i) + ": " + set.toString());
																							  }
																							}
																							
																							private static void GenComBody(Comment com) {
																							  gen.println(    "\t\tloop do");
																							  gen.println(    "\t\t\tif (" + ChCond(com.stop.charAt(0)) + ") then");
																							  if (com.stop.length()==1) {
																							      gen.println("\t\t\t\tlevel -= 1;");
																							      gen.println("\t\t\t\tif (level==0) then ; oldEols=line-line0; NextCh(); return true; end");
																							      gen.println("\t\t\t\tNextCh();");
																							    } else {
																							      gen.println("\t\t\t\tNextCh();");
																							      gen.println("\t\t\t\tif (" + ChCond(com.stop.charAt(1)) + ") then");
																							      gen.println("\t\t\t\t\tlevel -= 1;");
																							      gen.println("\t\t\t\t\tif (level==0) then ; oldEols=line-line0; NextCh(); return true; end");
																							      gen.println("\t\t\t\t\tNextCh();");
																							      gen.println("\t\t\t\tend");
																							    }
																							    if (com.nested) {
																								gen.println("\t\t\telsif (" + ChCond(com.start.charAt(0)) + ") then");
																								if (com.start.length()==1)
																								  gen.println("\t\t\t\tlevel += 1; NextCh();");
																								else {
																								    gen.println("\t\t\t\tNextCh();");
																								    gen.println("\t\t\t\tif (" + ChCond(com.start.charAt(1)) + ") then");
																								    gen.println("\t\t\t\t\tlevel += 1; NextCh();");
																								    gen.println("\t\t\t\tend");
																								  }
																								}
																								gen.println("\t\t\telsif (ch==EOF) then; return false");
																								gen.println("\t\t\telse NextCh();");
																								gen.println("\t\t\tend");
																								gen.println("\t\tend");
																							      }
																							      
																							      private static void GenComment(Comment com, int i) {
																								gen.println("private; def self.Comment" + i + "()");
																								gen.println("\tlevel = 1; line0 = line; lineStart0 = lineStart; startCh=nil");
																								if (com.start.length()==1) {
																								    gen.println("\tNextCh();");
																								    GenComBody(com);
																								  } else {
																								    gen.println("\tNextCh();");
																								    gen.println("\tif (" + ChCond(com.start.charAt(1)) + ") then");
																								    gen.println("\t\tNextCh();");
																								    GenComBody(com);
																								    gen.println("\telse");
																								    gen.println("\t\tif (ch==EOL) then; line -= 1; lineStart = lineStart0; end");
																								    gen.println("\t\tpos = pos - 2; Buffer.Set(pos+1); NextCh();");
																								    gen.println("\tend");
																								  }
																								  gen.println("\treturn false;");
																								  gen.println("end");
																								}
																								
																								private static void CopyFramePart(String stop) {
																								  int startCh, ch; int high, i, j;
																								  startCh = stop.charAt(0); high = stop.length() - 1;
																								  try {
																								    ch = fram.read();
																								    while (ch!=EOF)
																								      if (ch==startCh) {
																									  i = 0;
																									  do {
																									      if (i==high) return; # stop[0..i] found
																										ch = fram.read(); i++;
																									      } while (ch==stop.charAt(i));
																									      # stop[0..i-1] found; continue with last read character
																									      gen.print(stop.substring(0, i));
																									    } else if (ch==CR) {gen.println(); ch = fram.read();
																									      } else if (ch==LF) {gen.println(); ch = fram.read();
																										} else {
																										  gen.print((char)ch); ch = fram.read();
																										}
																										     } catch (IOException e) {
																										Scanner.err.Exception("-- error reading Scanner.frame");
																									      }
																										   }
																									    
																									    private static void GenLiterals() {
																									      int i, j, k, l;
																									      char ch;
																									      Symbol sym;
																									      String[] key = new String[128];
																									      int[] knr = new int[128];
																									      # sort literal list (don't consider eofSy)
																									      k = 0;
																									      for (i=1; i<=Tab.maxT; i++) {
																										  sym = Tab.Sym(i);
																										  if (sym.struct==Tab.litToken) {
																										      for (j=k-1; j>=0 && sym.name.compareTo(key[j]) < 0; j--) {
																											  key[j+1] = key[j]; knr[j+1] = knr[j];
																											}
																											key[j+1] = sym.name; knr[j+1] = i; k++;
																										      }
																										    }
																										    # print switch statement
																										    i = 0;
																										    while (i < k) {
																											ch = key[i].charAt(1); # key[i, 0] is quote
																											gen.println("\t\t\twhen " + Ch(ch));
																											j = i;
																											do {
																											    if (i==j) gen.print("\t\t\t\tif ");
																											    else gen.print("\t\t\t\telsif ");
																											      gen.println("(t.val.equals(" + key[i] + ")) then; t.kind = " + knr[i] + ";");
																											      i++;
																											    } while (i<k && key[i].charAt(1)==ch);
																											    gen.println("\t\t\t\tend");
																											  }
																											}
																											
																											private static void WriteState(State state) {
																											  Action action;
																											  Symbol sym;
																											  int endOf;
																											  boolean ctxEnd;
																											  endOf = state.endOf;
																											  if (endOf > Tab.maxT)
																											    endOf = Tab.maxT + Tab.maxSymbols - endOf; # pragmas have been moved
																											    gen.println("\t\t\t\twhen " + state.nr);
																											    ctxEnd = state.ctx;
																											    for (action=state.firstAction; action!=nil; action=action.next) {
																												if (action==state.firstAction) 
																												  gen.print("\t\t\t\t\tif (");
																												else
																												  gen.print("\t\t\t\t\telsif (");

																												  if (action.typ==Tab.chr) 
																												    gen.print(ChCond((char)action.sym));
																												  else
																												    PutRange(Tab.Class(action.sym));

																												    gen.println(") then; ");

																												    if (action.target.state != state)
																												      gen.println("state = " + action.target.state.nr + "; ");

																												      if (action.tc == Tab.contextTrans) {
																													  gen.println("apx += 1; "); 
																													  ctxEnd = false;
																													} else if (state.ctx)
																														 gen.println("apx = 0; ");

																														 if (action.next==nil)
																														   gen.println("\t\t\t\t\t\tbreak");
																														 }

																														 if (state.firstAction != nil) gen.println("\t\t\t\t\telse ;");
																														   if (endOf==Tab.noSym)
																														     gen.println("t.kind = noSym; break; end");
																														   else { # final state
																														if (state.firstAction==nil)
																														  gen.print("\t\t\t\t\t");
																														else
																														  gen.print("");
																														  sym = Tab.Sym(endOf);
																														  if (ctxEnd) { # final context state: cut appendix
																														      gen.println();
																														      gen.println("\t\t\t\t\t\tpos = pos - apx - 1; Buffer.Set(pos+1); i = buf.length();");
																														      gen.println("\t\t\t\t\t\twhile (apx > 0) {");
																														      gen.println("\t\t\t\t\t\t\tch = buf.charAt(--i);");
																														      gen.println("\t\t\t\t\t\t\tif (ch==EOL) line--;");
																														      gen.println("\t\t\t\t\t\t\tapx--;");
																														      gen.println("\t\t\t\t\t\t}");
																														      gen.println("\t\t\t\t\t\tbuf.setLength(i); NextCh();");
																														      gen.print(  "\t\t\t\t\t\t");
																														    }
																														    gen.println("t.kind = " + endOf + "; ");
																														    if (sym.struct==Tab.classLitToken)
																														      gen.println("t.val = buf.toString(); CheckLiteral(); ");
																														      if (state.firstAction != nil) gen.println("end");
																														      }
																														    }
																														    
																														    private static void FillStartTab(int[] startTab) {
																														      int targetState, max, i;
																														      BitSet s;
																														      startTab[0] = State.lastNr + 1; # eof
																														      for (Action action= firstState.firstAction; action!=nil; action=action.next) {
																															  targetState = action.target.state.nr;
																															  if (action.typ==Tab.chr) startTab[action.sym] = targetState;
																															  else {
																															      s = Tab.Class(action.sym); max = s.size();
																															      for (i=0; i<=max; i++)
																																if (s.get(i)) startTab[i] = targetState;
																																}
																															      }
																															    }
																															    
																															    static boolean WriteScanner() {
																															      int i, j, max;
																															      int[] startTab = new int[128];
																															      boolean ok = true;
																															      OutputStream s;
																															      Comment com;
																															      Symbol root = Tab.Sym(Tab.gramSy);
																															      try {fram = new BufferedInputStream(new FileInputStream(srcDir + "Scanner.frame"));}
																															      catch (IOException e) {
																																Scanner.err.Exception("-- cannot open Scanner.frame. " +
																																		      "Must be in the same directory as the grammar file.");
																															      }
																															      try {
																																s = new BufferedOutputStream(new FileOutputStream(srcDir + "Scanner.rb"));
																																gen = new PrintStream(s);}
																															      catch (IOException e) {
																																Scanner.err.Exception("-- cannot generate scanner file");
																															      }
																															      if (dirtyDFA) ok = MakeDeterministic();
																																FillStartTab(startTab);
																																gen.println("# This file is generated. DO NOT MODIFY!");
																																gen.println();
																																gen.println("# HACK: package " + root.name + ";");
																																CopyFramePart("-->declarations");
																																gen.println("\tprivate; @@noSym = " + Tab.maxT + "; # FIX: make this a constant");
																																gen.println("\tprivate; @@start = [");
																																for (i=0; i<8; i++) {
																																    for (j=0; j<16; j++)
																																      gen.print(Int(startTab[16*i+j], 3) + ",");
																																      gen.println();
																																    }
																																    gen.println("  0]");
																																    CopyFramePart("-->initialization");
																																    gen.print("\t\t");
																																    max = Tab.ignored.size();
																																    for (i=0; i<=max; i++)
																																      if (Tab.ignored.get(i)) gen.println("@@ignore.set(" + i + ")");
																																	CopyFramePart("-->comment");
																																	com = Comment.first; i = 0;
																																	while (com != nil) {
																																	    GenComment(com, i);
																																	    com = com.next; i++;
																																	  }
																																	  CopyFramePart("-->literals"); GenLiterals();
																																	  CopyFramePart("-->scan1");
																																	  if (Comment.first!=nil) {
																																	      gen.print("\t\tif (");
																																	      com = Comment.first; i = 0;
																																	      while (com != nil) {
																																		  gen.print(ChCond(com.start.charAt(0)));
																																		  gen.print(" && Comment" + i + "() ");
																																		  if (com.next != nil) gen.print(" || ");
																																		    com = com.next; i++;
																																		  }
																																		  gen.print(") then ; return Scan(); end");
																																		}
																																		CopyFramePart("-->scan2");
																																		for (State state=firstState.next; state!=nil; state=state.next)
																																		  WriteState(state);
																																		  gen.println("\t\t\t\twhen "+(State.lastNr+1));
																																		  gen.println("\t\t\t\t\tt.kind = 0; ");
																																		  CopyFramePart("$$$");
																																		  gen.flush();
																																		  return ok;
																																		}
																																		
																																		static void Init(String dir) {
																																		  srcDir = dir;
																																		  firstState = nil; lastState = nil; State.lastNr = -1;
																																		  firstState = NewState();
																																		  Melted.first = nil; Comment.first = nil;
																																		  dirtyDFA = false;
																																		}
																																		
																																	      }
