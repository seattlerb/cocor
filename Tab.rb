
class Module
  def cls_attr_accessor(*names)
    for name in names do
      eval "def self.#{name}; @@#{name}; end; def self.#{name}=(x); @@#{name}=x; end"
    end
  end
end

class Position	 			# position of source code stretch (e.g. semantic action)
  attr_accessor :beg			# start relative to the beginning of the file
  attr_accessor :len			# length of stretch
  attr_accessor :col			# column number of start position
end

class SymInfo
  attr_accessor :name
  attr_accessor :kind			# 0 = ident, 1 = string
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
    # do nothing... so far... maybe init everything to nil?
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
end

class FirstSet
    attr_accessor :ts			# terminal symbols
    attr_accessor :ready		# if true, ts is complete
end

class FollowSet
    attr_accessor :ts			# terminal symbols
    attr_accessor :nts			# nonterminals whose start set is to be included into ts
end

class CharClass
    attr_accessor :name			# class name
    attr_accessor :set			# index of set representing the class
end

class Graph
    attr_accessor :l			# left end of graph = head
    attr_accessor :r			# right end of graph = list of nodes to be linked to successor graph
end

class XNode				# node of cross reference list
    attr_accessor :line
    attr_accessor :next
end

class CNode				# node of list for finding circular productions
    attr_accessor :left
    attr_accessor :right
    attr_accessor :deleted
end

class Tab

	# --- constants ---
  MaxSymbols   =  512	# max. no. of t, nt, and pragmas
  MaxTerminals =  256	# max. no. of terminals			TODO: never used
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
  @@gramSy = nil				# root nonterminal filled by ATG

  @@sy = Array.new(MaxSymbols, :Sym)		# symbol table
  @@gn = Array.new(MaxNodes, :GraphNode)	# grammar graph
  @@first = nil # FirstSet[]			# first[i] = start symbols of sy[i+@@firstNt]
  @@follow = nil #  FollowSet[] 		# follow[i] = followers of sy[i+@@firstNt]
  @@chClass = nil # new CharClass[MaxClasses]	# character classes
  @@set = Array.new(128) # new BitSet[128]	# set[0] = union of all synchr. sets

  @@err = nil					# error messages
  @@dummyName = 0				# for unnamed character classes
  @@visited = nil # BitSet
  @@termNt = nil # BitSet			# mark lists for graph traversals
  @@curSy = 0					# current symbol in computation of sets
  @@nTyp = [ "    ", "T   ", "Pr  ", "Nt  ", "Clas", "Chr ", "Wt  ",
             "Any ", "Eps ", "Sync", "Sem ", "Alt ", "Iter", "Opt " ]

  # I'm only adding these as they get used and fubar something
  cls_attr_accessor :ignored, :semDeclPos

  private
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
      exit(n)
    end
  end
  public

  # ---------------------------------------------------------------------
  # Symbol table management
  # ---------------------------------------------------------------------

  def self.NewSym(typ, name, line)
    s = nil
    i = 0

    self.Assert(@@maxT+1 < @@firstNt, 6);

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

    self.Assert(@@maxT+1 < @@firstNt, 6);

    s = Sym.new()
    s.typ = typ
    s.name = name
    s.line = line
    @@sy[i] = s

    return i;
  end

  def self.Sym(i)
    return @@sy[i];
  end

  # TODO: this is totally unnecessary in ruby
  def self.FindSym(name)
    i = 0
    while (i <= @@maxT)
      if (name.equals(@@sy[i].name)) 
	return i;
      end
      i += 1
    end
    i = @@firstNt
    while (i < MaxSymbols)
      if (name.equals(@@sy[i].name)) then
	return i;
      end
      i += 1
    end
    return NoSym;
  end

  ############################################################
  # START OF HACKS

  def self.Init # HACK
    @@err = Scanner.err
    @@maxSet = 0
    @@set[0] = BitSet.new()
    @@set[0].set(EofSy)

    @@maxT = -1;
    @@maxP = MaxSymbols;
    @@firstNt = MaxSymbols;
    @@lastNt = @@maxP - 1;
    @@dummyName = 0;
    @@maxC = -1;
    @@nNodes = -1;
    # int dummy = NewNode(0, 0, 0); # Uhh... this looks stupid
  end

  def self.t # HACK
    raise "Um. no"
  end

  def self.ddt
    $stderr.puts "ddt"
    return @@ddt
  end

end

__END__

class Tab {

	# ---------------------------------------------------------------------
	#   topdown graph management
	# ---------------------------------------------------------------------

	static int NewNode(int typ, int p1, int line) {
		GraphNode n;
		nNodes++; Assert(nNodes <= MaxNodes, 3);
		n = new GraphNode();
		n.typ = typ; n.p1 = p1; n.line = line;
		gn[nNodes] = n;
		return nNodes;
	}

	static GraphNode Node(int i) {
		return gn[i];
	}

	static void CompleteGraph(int p) {
		int q;
		while (p != 0) {
			q = gn[p].next; gn[p].next = 0; p = q;
		}
	}

	static Graph Alternative(Graph g1, Graph g2) {
		int p;
		g2.l = NewNode(alt, g2.l, 0);
		p = g1.l; while (gn[p].p2 != 0) p = gn[p].p2;
		gn[p].p2 = g2.l;
		p = g1.r; while (gn[p].next != 0) p = gn[p].next;
		gn[p].next = g2.r;
		return g1;
	}

	static Graph Sequence(Graph g1, Graph g2) {
		int p, q;
		p = gn[g1.r].next; gn[g1.r].next = g2.l; # head node
		while (p != 0) { # substructure
			q = gn[p].next; gn[p].next = -g2.l; p = q;
		}
		g1.r = g2.r;
		return g1;
	}

	static Graph FirstAlt(Graph g) {
		g.l = NewNode(alt, g.l, 0); gn[g.l].next = g.r; g.r = g.l;
		return g;
	}

	static Graph Iteration(Graph g) {
		int p, q;
		g.l = NewNode(iter, g.l, 0);
		p = g.r; g.r = g.l;
		while (p != 0) {
			q = gn[p].next; gn[p].next = -g.l; p = q;
		}
		return g;
	}

	static Graph Option(Graph g) {
		g.l = NewNode(opt, g.l, 0); gn[g.l].next = g.r; g.r = g.l;
		return g;
	}

	static Graph StrToGraph(String s) {
		int len = s.length() - 1;
		Graph g = new Graph();
		for (int i=1; i<len; i++) {
			gn[g.r].next = NewNode(chr, (int) s.charAt(i), 0);
			g.r = gn[g.r].next;
		}
		g.l = gn[0].next; gn[0].next = 0;
		return g;
	}

	static boolean DelGraph(int p) {
		GraphNode n;
		if (p==0) return true; # end of graph found
		n = Node(p);
		return DelNode(n) && DelGraph(Math.abs(n.next));
	}

	static boolean DelAlt(int p) {
		GraphNode n;
		if (p<=0) return true; # end of graph found
		n = Node(p);
		return DelNode(n) && DelAlt(n.next);
	}

	static boolean DelNode(GraphNode n) {
		if (n.typ==nt) return sy[n.p1].deletable;
		else if (n.typ==alt) return DelAlt(n.p1) || n.p2!=0 && DelAlt(n.p2);
		else return n.typ==eps || n.typ==iter || n.typ==opt || n.typ==sem || n.typ==sync;
	}

	static void PrintGraph() {
		GraphNode n;
		Trace.println("Graph:");
		Trace.println("  nr typ  next   p1   p2 line");
		for (int i=1; i<=nNodes; i++) {
			n = Node(i);
			Trace.println(Int(i,4) + " " + nTyp[n.typ] + Int(n.next,5) +Int(n.p1,5)
				+ Int(n.p2,5) + Int(n.line,5));
		}
		Trace.println();
	}

	# ---------------------------------------------------------------------
	#   Character class management
	# ---------------------------------------------------------------------

	static int NewClass(String name, BitSet s) {
		CharClass c;
		@@maxC++; Assert(@@maxC < MaxClasses, 7);
		if (name.equals("#")) name = new String("#" + (char)((int)'A' + dummyName++));
		c = new CharClass(); c.name = name; c.set = NewSet(s);
		chClass[@@maxC] = c;
		return @@maxC;
	}

	static int ClassWithName(String name) {
		int i;
		for (i=@@maxC; i>=0 && !name.equals(chClass[i].name); i--);
		return i;
	}

	static int ClassWithSet(BitSet s) {
		int i;
		for (i=@@maxC; i>=0 && !s.equals(set[chClass[i].set]); i--);
		return i;
	}

	static BitSet Class(int i) {
		return set[chClass[i].set];
	}

	static String ClassName(int i) {
		return chClass[i].name;
	}

	# ---------------------------------------------------------------------
	#   Symbol set computations
	# ---------------------------------------------------------------------

	static void PrintSet(BitSet s, int indent) {
		int col, i, len;
		col = indent;
		for (i=0; i<=@@maxT; i++) {
			if (s.get(i)) {
				len = sy[i].name.length();
				if (col + len + 1 > 80) {
					Trace.println();
					for (col=1; col<indent; col++) Trace.print(" ");
				}
				Trace.print(sy[i].name + "  ");
				col += len + 1;
			}
		}
		if (col==indent) Trace.print("-- empty set --");
		Trace.println();
	}

	static int NewSet(BitSet s) {
		@@maxSet++; Assert(@@maxSet <= MaxSetNr, 4);
		set[@@maxSet] = s;
		return @@maxSet;
	}

	static BitSet Set(int i) {
		return set[i];
	}

	static private BitSet First0(int p, BitSet mark) {
		GraphNode n;
		BitSet s1, s2, fs = new BitSet();
		while (p!=0 && !mark.get(p)) {
			n = Node(p); mark.set(p);
			switch (n.typ) {
				case nt: {
					if (first[n.p1-@@firstNt].ready) fs.or(first[n.p1-@@firstNt].ts);
					else fs.or(First0(sy[n.p1].struct, mark));
					break;
				}
				case t: case wt: {
					fs.set(n.p1); break;
				}
				case any: {
					fs.or(set[n.p1]); break;
				}
				case alt: case iter: case opt: {
					fs.or(First0(n.p1, mark));
					if (n.typ==alt)
						fs.or(First0(n.p2, mark));
					break;
				}
			}
			if (!DelNode(n)) break;
			p = Math.abs(n.next);
		}
		return fs;
	}

	static BitSet First(int p) {
		BitSet fs = First0(p, new BitSet(nNodes+1));
		if (ddt[3]) {Trace.println(); Trace.println("First: gp = " + p); PrintSet(fs, 0);}
		return fs;
	}

	static private void CompFirstSets() {
		FirstSet s;
		int i;
		for (i=@@firstNt; i<=@@lastNt; i++) {
			s = new FirstSet();
			s.ts = new BitSet(); s.ready = false;
			first[i-@@firstNt] = s;
		}
		for (i=@@firstNt; i<=@@lastNt; i++) {
			first[i-@@firstNt].ts = First(sy[i].struct);
			first[i-@@firstNt].ready = true;
		}
	}

	static private void CompFollow(int p) {
		GraphNode n;
		BitSet s;
		while (p>0 && !visited.get(p)) {
			n = Node(p); visited.set(p);
			if (n.typ==nt) {
				s = First(Math.abs(n.next));
				follow[n.p1-@@firstNt].ts.or(s);
				if (DelGraph(Math.abs(n.next)))
					follow[n.p1-@@firstNt].nts.set(curSy-@@firstNt);
			} else if (n.typ==opt || n.typ==iter) {
				CompFollow(n.p1);
			} else if (n.typ==alt) {
				CompFollow(n.p1); CompFollow(n.p2);
			}
			p = n.next;
		}
	}

	static private void Complete(int i) {
		if (!visited.get(i)) {
			visited.set(i);
			for (int j=0; j<=@@lastNt-@@firstNt; j++) { # for all nonterminals
				if (follow[i].nts.get(j)) {
					Complete(j);
					follow[i].ts.or(follow[j].ts);
					if (i == curSy) follow[i].nts.clear(j);
				}
			}
		}
	}

	static private void CompFollowSets() {
		FollowSet s;
		for (curSy=@@firstNt; curSy<=@@lastNt; curSy++) {
			s = new FollowSet();
			s.ts = new BitSet(); s.nts = new BitSet();
			follow[curSy-@@firstNt] = s;
		}
		visited = new BitSet();
		for (curSy=@@firstNt; curSy<=@@lastNt; curSy++) # get direct successors of nonterminals
			CompFollow(sy[curSy].struct);
		# CompFollow(root); # curSy = @@lastNt+1
		for (curSy=0; curSy<=@@lastNt-@@firstNt; curSy++) { # add indirect successors to follow.ts
			visited = new BitSet();
			Complete(curSy);
		}
	}

	static private GraphNode LeadingAny(int p) {
		GraphNode n, a = null;
		if (p <= 0) return null;
		n = Node(p);
		if (n.typ==any) a = n;
		else if (n.typ==alt) {
			a = LeadingAny(n.p1);
			if (a==null) a = LeadingAny(n.p2);
		}
		else if (n.typ==opt || n.typ==iter) a = LeadingAny(n.p1);
		else if (DelNode(n)) a = LeadingAny(n.next);
		return a;
	}

	static private void FindAS(int p) {
		GraphNode n, nod, a;
		BitSet s1, s2;
		int q;
		while (p > 0) {
			n = Node(p);
			if (n.typ==opt || n.typ==iter) {
				FindAS(n.p1);
				a = LeadingAny(n.p1);
				if (a!=null) {
					s1 = First(Math.abs(n.next));
					Sets.Differ(set[a.p1], s1);
				}
			} else if (n.typ==alt) {
				s1 = new BitSet();
				q = p;
				while (q != 0) {
					nod = Node(q); FindAS(nod.p1);
					a = LeadingAny(nod.p1);
					if (a!=null) {
						s2 = First(nod.p2);
						s2.or(s1);
						Sets.Differ(set[a.p1], s2);
					} else {
						s1.or(First(nod.p1));
					}
					q = nod.p2;
				}
			}
			p = n.next;
		}
	}

	static private void CompAnySets() {
		for (curSy=@@firstNt; curSy<=@@lastNt; curSy++)
			FindAS(sy[curSy].struct);
	}

	static BitSet Expected(int p, int sp) {
		BitSet s = First(p);
		if (DelGraph(p)) s.or(follow[sp-@@firstNt].ts);
		return s;
	}

	static private void CompSync(int p) {
		GraphNode n;
		BitSet s;
		while (p > 0 && !visited.get(p)) {
			n = Node(p); visited.set(p);
			if (n.typ==sync) {
				s = Expected(Math.abs(n.next), curSy);
				s.set(eofSy);
				set[0].or(s);
				n.p1 = NewSet(s);
			} else if (n.typ==alt) {
				CompSync(n.p1); CompSync(n.p2);
			} else if (n.typ==opt || n.typ==iter)
				CompSync(n.p1);
			p = n.next;
		}
	}

	static private void CompSyncSets() {
		visited = new BitSet();
		for (curSy=@@firstNt; curSy<=@@lastNt; curSy++)
			CompSync(sy[curSy].struct);
	}

	static void CompDeletableSymbols() {
		int i;
		boolean changed;
		do {
			changed = false;
			for (i=@@firstNt; i<=@@lastNt; i++)
				if (!sy[i].deletable && DelGraph(sy[i].struct)) {
					sy[i].deletable = true; changed = true;
				}
		} while (changed);
		for (i=@@firstNt; i<=@@lastNt; i++)
			if (sy[i].deletable) System.out.println("  " + sy[i].name + " deletable");
	}

	static private void MovePragmas() {
		if (@@maxP > @@firstNt) {
			@@maxP = @@maxT;
			for (int i=MaxSymbols-1; i>@@lastNt; i--) {
				@@maxP++; Assert(@@maxP < @@firstNt, 6);
				sy[@@maxP] = sy[i];
			}
		}
	}

	static void CompSymbolSets() {
		int i;
		i = self.NewSym(t, "???", 0); # unknown symbols get code @@maxT
		MovePragmas();
		CompDeletableSymbols();
		first = new FirstSet[@@lastNt-@@firstNt+1];
		follow = new FollowSet[@@lastNt-@@firstNt+1];
		CompFirstSets();
		CompFollowSets();
		CompAnySets();
		CompSyncSets();
		if (ddt[1]) {
			Trace.println("First & follow symbols:");
			for (i=@@firstNt; i<=@@lastNt; i++) {
				Trace.println(sy[i].name);
				Trace.print("first:   "); PrintSet(first[i-@@firstNt].ts, 10);
				Trace.print("follow:  "); PrintSet(follow[i-@@firstNt].ts, 10);
				Trace.println();
			}
			if (@@maxSet >= 0) {
				Trace.println(); Trace.println();
				Trace.println("List of sets (ANY, SYNC): ");
				for (i=0; i<=@@maxSet; i++) {
					Trace.print("     set[" + i + "] = ");
					PrintSet(set[i], 16);
				}
				Trace.println(); Trace.println();
			}
		}
	}

	# ---------------------------------------------------------------------
	#   Grammar checks
	# ---------------------------------------------------------------------

	static private void GetSingles(int p, BitSet singles) {
		GraphNode n;
		if (p <= 0) return;  # end of graph
		n = Node(p);
		if (n.typ==nt) {
			if (DelGraph(Math.abs(n.next))) singles.set(n.p1);
		} else if (n.typ==alt || n.typ==iter || n.typ==opt) {
			if (DelGraph(Math.abs(n.next))) {
				GetSingles(n.p1, singles);
				if (n.typ==alt) GetSingles(n.p2, singles);
			}
		}
		if (DelNode(n)) GetSingles(n.next, singles);
	}

	static boolean NoCircularProductions() {
		boolean ok, changed, onLeftSide, onRightSide;
		CNode[] list = new CNode[150];
		CNode x;
		BitSet singles;
		Sym sym;
		int i, j, len = 0;
		for (i=@@firstNt; i<=@@lastNt; i++) {
			singles = new BitSet();
			GetSingles(sy[i].struct, singles); # get nts such that i-->j
			for (j=@@firstNt; j<=@@lastNt; j++) {
				if (singles.get(j)) {
					x = new CNode(); x.left = i; x.right = j; x.deleted = false;
					list[len++] = x;
				}
			}
		}
		do {
			changed = false;
			for (i=0; i<len; i++) {
				if (!list[i].deleted) {
					onLeftSide = false; onRightSide = false;
					for (j=0; j<len; j++) {
						if (!list[j].deleted) {
							if (list[i].left==list[j].right) onRightSide = true;
							if (list[j].left==list[i].right) onLeftSide = true;
						}
					}
					if (!onLeftSide || !onRightSide) {
						list[i].deleted = true; changed = true;
					}
				}
			}
		} while(changed);
		ok = true;
		for (i=0; i<len; i++) {
			if (!list[i].deleted) {
				ok = false;
				System.out.println("  "+sy[list[i].left].name+" --> "+sy[list[i].right].name);
			}
		}
		return ok;
	}

	static private void LL1Error(int cond, int ts) {
		System.out.print("  LL1 warning in " + sy[curSy].name + ": ");
		if (ts > 0) System.out.print(sy[ts].name + " is ");
		switch (cond) {
			case 1: {System.out.println(" start of several alternatives"); break;}
			case 2: {System.out.println(" start & successor of deletable structure"); break;}
			case 3: {System.out.println(" an ANY node that matches no symbol"); break;}
		}
	}

	static private boolean Overlap(BitSet s1, BitSet s2, int cond) {
		boolean overlap = false;
		for (int i=0; i<=@@maxT; i++) {
			if (s1.get(i) && s2.get(i)) {LL1Error(cond, i); overlap = true;}
		}
		return overlap;
	}

	static private boolean AltOverlap(int p) {
		boolean overlap = false;
		GraphNode n, a;
		BitSet s1, s2;
		int q;
		while (p > 0) {
			n = Node(p);
			if (n.typ==alt) {
				q = p; s1 = new BitSet();
				while (q != 0) { # for all alternatives
					a = Node(q); s2 = Expected(a.p1, curSy);
					if (Overlap(s1, s2, 1)) overlap = true;
					s1.or(s2);
					if (AltOverlap(a.p1)) overlap = true;
					q = a.p2;
				}
			} else if (n.typ==opt || n.typ==iter) {
				s1 = Expected(n.p1, curSy);
				s2 = Expected(Math.abs(n.next), curSy);
				if (Overlap(s1, s2, 2)) overlap = true;
				if (AltOverlap(n.p1)) overlap = true;
			} else if (n.typ==any) {
				if (Sets.Empty(Set(n.p1))) {LL1Error(3, 0); overlap = true;}
				# e.g. {ANY} ANY or [ANY] ANY
			}
			p = n.next;
		}
		return overlap;
	}

	static boolean LL1() {
		boolean ll1 = true;
		for (curSy=@@firstNt; curSy<=@@lastNt; curSy++)
			if (AltOverlap(sy[curSy].struct)) ll1 = false;
		return ll1;
	}

	static boolean NtsComplete() {
		boolean complete = true;
		for (int i=@@firstNt; i<=@@lastNt; i++) {
			if (sy[i].struct==0) {
				complete = false;
				System.out.println("  No production for " + sy[i].name);
			}
		}
		return complete;
	}

	static private void MarkReachedNts(int p) {
		GraphNode n;
		while (p > 0) {
			n = Node(p);
			if (n.typ==nt) {
				if (!visited.get(n.p1)) { # new nt reached
					visited.set(n.p1);
					MarkReachedNts(sy[n.p1].struct);
				}
			} else if (n.typ==alt || n.typ==iter || n.typ==opt) {
				MarkReachedNts(n.p1);
				if (n.typ==alt) MarkReachedNts(n.p2);
			}
			p = n.next;
		}
	}

	static boolean AllNtReached() {
		GraphNode n;
		boolean ok = true;
		visited = new BitSet();
		visited.set(gramSy);
		MarkReachedNts(Sym(gramSy).struct);
		for (int i=@@firstNt; i<=@@lastNt; i++) {
			if (!visited.get(i)) {
				ok = false;
				System.out.println("  " + sy[i].name + " cannot be reached");
			}
		}
		return ok;
	}

	static private boolean Term(int p) { # true if graph can be derived to terminals
		GraphNode n;
		while (p > 0) {
			n = Node(p);
			if (n.typ==nt && !termNt.get(n.p1)) return false;
			if (n.typ==alt && !Term(n.p1) && (n.p2==0 || !Term(n.p2))) return false;
			p = n.next;
		}
		return true;
	}

	static boolean AllNtToTerm() {
		boolean changed, ok = true;
		int i;
		termNt = new BitSet();
		do {
			changed = false;
			for (i=@@firstNt; i<=@@lastNt; i++)
				if (!termNt.get(i) && Term(sy[i].struct)) {
					termNt.set(i); changed = true;
				}
		} while (changed);
		for (i=@@firstNt; i<=@@lastNt; i++)
			if (!termNt.get(i)) {
				ok = false;
				System.out.println("  " + sy[i].name + "cannot be derived to terminals");
			}
		return ok;
	}

	# ---------------------------------------------------------------------
	#   Utility functions
	# ---------------------------------------------------------------------

	static private String Str(String s, int len) {
		char[] a = new char[64];
		int i = s.length();
		s.getChars(0, i, a, 0);
		for (; i<len; i++) a[i] = ' ';
		return new String(a, 0, len);
	}

	static private String Int(int n, int len) {
		char[] a = new char[16];
		String s = String.valueOf(n);
		int i = 0, j = 0, d = len - s.length();
		while (i < d) {a[i] = ' '; i++;}
		while (i < len) {a[i] = s.charAt(j); i++; j++;}
		return new String(a, 0, len);
	}

	static void PrintSymbolTable() {
		int i;
		Trace.println("Symbol Table:");
		Trace.println(" nr name       typ  hasAt struct del   line"); Trace.println();
		i = 0;
		while (i < MaxSymbols) {
			Trace.print(Int(i, 3) + " " + Str(sy[i].name, 10) + " " + nTyp[sy[i].typ]);
			if (sy[i].attrPos==null) Trace.print(" false "); else Trace.print(" true  ");
			Trace.print(Int(sy[i].struct, 5));
			if (sy[i].deletable) Trace.print(" true  "); else Trace.print(" false ");
			Trace.println(Int(sy[i].line, 5));
			if (i==@@maxT) i = @@firstNt; else i++;
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
		for (i=nNodes; i>=1; i--) {
			n = Node(i);
			if (n.typ==t || n.typ==wt || n.typ==nt) {
				p = new XNode(); p.line = n.line;
				p.next = list[n.p1]; list[n.p1] = p;
			}
		}
		# search lines where symbol has been defined and insert in order
		i = 1;
		while (i <= @@lastNt) {
			sym = Sym(i); p = list[i]; q = null;
			while (p != null && sym.line > p.line) {q = p; p = p.next;}
			x = new XNode(); x.line = -sym.line; x.next = p;
			if (q==null) list[i] = x; else q.next = x;
			if (i==@@maxP) i = @@firstNt; else i++;
		}
		# print cross reference list
		Trace.println();
		Trace.println("Cross reference list:"); Trace.println();
		Trace.println("Terminals:");
		Trace.println("  0 EOF");
		i = 1;
		while (i <= @@lastNt) {
			Trace.print(Int(i, 3) + " " + sy[i].name + "  ");
			p = list[i]; col = 25;
			while (p != null) {
				if (col + 5 > 80) {
					Trace.println();
					for (col=0; col<25; col++) Trace.print(" ");
				}
				if (p.line==0) Trace.print("undef  "); else Trace.print(p.line + "  ");
				col = col + 5;
				p = p.next;
			}
			Trace.println();
			if (i==@@maxT) {Trace.println(); Trace.println("Pragmas:");}
			if (i==@@maxP) {Trace.println(); Trace.println("Nonterminals:"); i = @@firstNt;}
			else i++;
		}
		Trace.println(); Trace.println();
	}

	static void Init() {
		# ...
	}

}









