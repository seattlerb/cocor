package Coco;

import java.io.*;
import java.util.*;

class Position {			// position of source code stretch (e.g. semantic action)
	int beg;					// start relative to the beginning of the file
	int len;					// length of stretch
	int col;					// column number of start position
}

class SymInfo {
	String name;
	int kind;		// 0 = ident, 1 = string
}

class Symbol {
	int typ;				// t, nt, pr, unknown
	String name;			// symbol name
	int struct;				// nt: index of first node of syntax graph
							// t:  token kind (literal, class, ...)
	boolean deletable;		// nt: true if nonterminal is deletable
	Position attrPos;		// position of attributes in source text (or null)
	String retType;			// nt: Type of output attribute (or null)
	String retVar;			// nt: Name of output attribute (or null)
	Position semPos;		// pr: pos of semantic action in source text (or null)
							// nt: pos of local declarations in source text (or null)
	int line;				// source text line number of item in this node
}

class GraphNode {
	int typ;				// t, nt, wt, chr, clas, any, eps, sem, sync, alt, iter, opt
	int next;				// index of successor node
							// next<0: to successor in enclosing structure
	int p1;					// nt, t, wt: index to symbol list
							// any:       index to any-set
							// sync:      index to sync-set
							// alt:       index of 1st node of 1st alternative
							// iter, opt: 1st node in subexpression
							// chr:       ordinal character value
							// clas:      index of character class
	int p2;					// alt:       index of 1st node of next alternative
							// chr, clas: transition code
	Position pos;			// nt, t, wt: pos of actual attributes
							// sem:       pos of semantic action in source text
	String retVar;			// nt: name of output attribute (or null)
	int line;				// source text line number of item in this node
	State state;			// DFA state corresponding to this node
							// (only used in Sgen.ConvertToStates)
}

class FirstSet {
	BitSet ts;			// terminal symbols
	boolean ready;		// if true, ts is complete
}

class FollowSet {
	BitSet ts;			// terminal symbols
	BitSet nts;			// nonterminals whose start set is to be included into ts
}

class CharClass {
	String name;		// class name
	int set;			// index of set representing the class
}

class Graph {
	int l;				// left end of graph = head
	int r;				// right end of graph = list of nodes to be linked to successor graph
}

class XNode {			// node of cross reference list
	int line;
	XNode next;
}

class CNode {			// node of list for finding circular productions
	int left, right;
	boolean deleted;
}

class Tab {

	/*--- constants ---*/
	static final int maxSymbols   =  512;	// max. no. of t, nt, and pragmas
	static final int maxTerminals =  256;	// max. no. of terminals
	static final int maxNodes     = 1500;	// max. no. of graph nodes
	static final int maxSetNr     =  128;	// max. no. of symbol sets
	static final int maxClasses   =   50;	// max. no. of character classes

	static final int t    = 1;				// node kinds
	static final int pr   = 2;
	static final int nt   = 3;
	static final int clas = 4;
	static final int chr  = 5;
	static final int wt   = 6;
	static final int any  = 7;
	static final int eps  = 8;
	static final int sync = 9;
	static final int sem  = 10;
	static final int alt  = 11;
	static final int iter = 12;
	static final int opt  = 13;

	static final int classToken    = 0;		// token kinds
	static final int litToken      = 1;
	static final int classLitToken = 2;

	static final int normTrans    = 0;		// transition codes
	static final int contextTrans = 1;

	static final int eofSy = 0;
	static final int noSym = -1;

	/*--- variables ---*/
	static int maxSet;				// index of last set
	static int maxT;				// terminals stored from 0 to maxT
	static int maxP;				// pragmas stored from maxT+1 to maxP
	static int firstNt;				// index of first nt: available after CompSymbolSets
	static int lastNt;				// index of last nt: available after CompSymbolSets
	static int maxC;				// index of last character class
	static Position semDeclPos;		// position of global semantic declarations
	static Position importPos;		// position of imported identifiers
	static BitSet ignored;			// characters ignored by the scanner
	static boolean[] ddt = new boolean[10];	// debug and test switches
	static int nNodes;				// index of last graph node
	static int gramSy;				// root nonterminal; filled by ATG

	static Symbol[] sy = new Symbol[maxSymbols];	// symbol table
	static GraphNode[] gn = new GraphNode[maxNodes];// grammar graph
	static FirstSet[] first;	                    // first[i] = start symbols of sy[i+firstNt]
	static FollowSet[] follow;	                    // follow[i] = followers of sy[i+firstNt]
	static CharClass[] chClass = new CharClass[maxClasses];	// character classes
	static BitSet[] set = new BitSet[128];			// set[0] = union of all synchr. sets

	static ErrorStream err;							// error messages
	static int dummyName;							// for unnamed character classes
	static BitSet visited, termNt;					// mark lists for graph traversals
	static int curSy;								// current symbol in computation of sets
	static String[] nTyp =
		{" ","t   ","pr  ","nt  ","clas","chr ","wt  ","any ","eps ","sync",
		"sem ","alt ","iter","opt "};

	private static void Assert(boolean cond, int n) {
		if (!cond) {
			System.out.println("-- SymTab fatal error ");
			switch (n) {
				case 3: {System.out.println("-- too many nodes in graph"); break;}
				case 4: {System.out.println("-- too many sets"); break;}
				case 6: {System.out.println("-- too many symbols"); break;}
				case 7: {System.out.println("-- too many character classes"); break;}
			}
			System.exit(n);
		}
	}

	/*---------------------------------------------------------------------
	  Symbol table management
	---------------------------------------------------------------------*/

	static int NewSym(int typ, String name, int line) {
		Symbol s;
		int i = 0;
		Assert(maxT+1 < firstNt, 6);
		switch (typ) {
			case t:  {maxT++; i = maxT; break;}
			case pr: {maxP--; firstNt--; lastNt--; i = maxP; break;}
			case nt: {firstNt--; i = firstNt; break;}
		}
		Assert(maxT+1 < firstNt, 6);
		s = new Symbol();
		s.typ = typ; s.name = name; s.line = line;
		sy[i] = s;
		return i;
	}

	static Symbol Sym(int i) {
		return sy[i];
	}

	static int FindSym(String name) {
		int i;
		for (i=0; i<=maxT; i++)
			if (name.equals(sy[i].name)) return i;
		for (i=firstNt; i<maxSymbols; i++)
			if (name.equals(sy[i].name)) return i;
		return noSym;
	}

	/*---------------------------------------------------------------------
	  topdown graph management
	---------------------------------------------------------------------*/

	static int NewNode(int typ, int p1, int line) {
		GraphNode n;
		nNodes++; Assert(nNodes <= maxNodes, 3);
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
		p = gn[g1.r].next; gn[g1.r].next = g2.l; // head node
		while (p != 0) { // substructure
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
		if (p==0) return true; // end of graph found
		n = Node(p);
		return DelNode(n) && DelGraph(Math.abs(n.next));
	}

	static boolean DelAlt(int p) {
		GraphNode n;
		if (p<=0) return true; // end of graph found
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

	/*---------------------------------------------------------------------
	  Character class management
	---------------------------------------------------------------------*/

	static int NewClass(String name, BitSet s) {
		CharClass c;
		maxC++; Assert(maxC < maxClasses, 7);
		if (name.equals("#")) name = new String("#" + (char)((int)'A' + dummyName++));
		c = new CharClass(); c.name = name; c.set = NewSet(s);
		chClass[maxC] = c;
		return maxC;
	}

	static int ClassWithName(String name) {
		int i;
		for (i=maxC; i>=0 && !name.equals(chClass[i].name); i--);
		return i;
	}

	static int ClassWithSet(BitSet s) {
		int i;
		for (i=maxC; i>=0 && !s.equals(set[chClass[i].set]); i--);
		return i;
	}

	static BitSet Class(int i) {
		return set[chClass[i].set];
	}

	static String ClassName(int i) {
		return chClass[i].name;
	}

	/*---------------------------------------------------------------------
	  Symbol set computations
	---------------------------------------------------------------------*/

	static void PrintSet(BitSet s, int indent) {
		int col, i, len;
		col = indent;
		for (i=0; i<=maxT; i++) {
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
		maxSet++; Assert(maxSet <= maxSetNr, 4);
		set[maxSet] = s;
		return maxSet;
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
					if (first[n.p1-firstNt].ready) fs.or(first[n.p1-firstNt].ts);
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
		for (i=firstNt; i<=lastNt; i++) {
			s = new FirstSet();
			s.ts = new BitSet(); s.ready = false;
			first[i-firstNt] = s;
		}
		for (i=firstNt; i<=lastNt; i++) {
			first[i-firstNt].ts = First(sy[i].struct);
			first[i-firstNt].ready = true;
		}
	}

	static private void CompFollow(int p) {
		GraphNode n;
		BitSet s;
		while (p>0 && !visited.get(p)) {
			n = Node(p); visited.set(p);
			if (n.typ==nt) {
				s = First(Math.abs(n.next));
				follow[n.p1-firstNt].ts.or(s);
				if (DelGraph(Math.abs(n.next)))
					follow[n.p1-firstNt].nts.set(curSy-firstNt);
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
			for (int j=0; j<=lastNt-firstNt; j++) { // for all nonterminals
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
		for (curSy=firstNt; curSy<=lastNt/*+1*/; curSy++) {
			s = new FollowSet();
			s.ts = new BitSet(); s.nts = new BitSet();
			follow[curSy-firstNt] = s;
		}
		visited = new BitSet();
		for (curSy=firstNt; curSy<=lastNt; curSy++) // get direct successors of nonterminals
			CompFollow(sy[curSy].struct);
		// CompFollow(root); // curSy = lastNt+1
		for (curSy=0; curSy<=lastNt-firstNt; curSy++) { // add indirect successors to follow.ts
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
		for (curSy=firstNt; curSy<=lastNt; curSy++)
			FindAS(sy[curSy].struct);
	}

	static BitSet Expected(int p, int sp) {
		BitSet s = First(p);
		if (DelGraph(p)) s.or(follow[sp-firstNt].ts);
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
		for (curSy=firstNt; curSy<=lastNt; curSy++)
			CompSync(sy[curSy].struct);
	}

	static void CompDeletableSymbols() {
		int i;
		boolean changed;
		do {
			changed = false;
			for (i=firstNt; i<=lastNt; i++)
				if (!sy[i].deletable && DelGraph(sy[i].struct)) {
					sy[i].deletable = true; changed = true;
				}
		} while (changed);
		for (i=firstNt; i<=lastNt; i++)
			if (sy[i].deletable) System.out.println("  " + sy[i].name + " deletable");
	}

	static private void MovePragmas() {
		if (maxP > firstNt) {
			maxP = maxT;
			for (int i=maxSymbols-1; i>lastNt; i--) {
				maxP++; Assert(maxP < firstNt, 6);
				sy[maxP] = sy[i];
			}
		}
	}

	static void CompSymbolSets() {
		int i;
		i = NewSym(t, "???", 0); // unknown symbols get code maxT
		MovePragmas();
		CompDeletableSymbols();
		first = new FirstSet[lastNt-firstNt+1];
		follow = new FollowSet[lastNt-firstNt+1];
		CompFirstSets();
		CompFollowSets();
		CompAnySets();
		CompSyncSets();
		if (ddt[1]) {
			Trace.println("First & follow symbols:");
			for (i=firstNt; i<=lastNt; i++) {
				Trace.println(sy[i].name);
				Trace.print("first:   "); PrintSet(first[i-firstNt].ts, 10);
				Trace.print("follow:  "); PrintSet(follow[i-firstNt].ts, 10);
				Trace.println();
			}
			if (maxSet >= 0) {
				Trace.println(); Trace.println();
				Trace.println("List of sets (ANY, SYNC): ");
				for (i=0; i<=maxSet; i++) {
					Trace.print("     set[" + i + "] = ");
					PrintSet(set[i], 16);
				}
				Trace.println(); Trace.println();
			}
		}
	}

	/*---------------------------------------------------------------------
	  Grammar checks
	---------------------------------------------------------------------*/

	static private void GetSingles(int p, BitSet singles) {
		GraphNode n;
		if (p <= 0) return;  // end of graph
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
		Symbol sym;
		int i, j, len = 0;
		for (i=firstNt; i<=lastNt; i++) {
			singles = new BitSet();
			GetSingles(sy[i].struct, singles); // get nts such that i-->j
			for (j=firstNt; j<=lastNt; j++) {
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
		for (int i=0; i<=maxT; i++) {
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
				while (q != 0) { // for all alternatives
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
				// e.g. {ANY} ANY or [ANY] ANY
			}
			p = n.next;
		}
		return overlap;
	}

	static boolean LL1() {
		boolean ll1 = true;
		for (curSy=firstNt; curSy<=lastNt; curSy++)
			if (AltOverlap(sy[curSy].struct)) ll1 = false;
		return ll1;
	}

	static boolean NtsComplete() {
		boolean complete = true;
		for (int i=firstNt; i<=lastNt; i++) {
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
				if (!visited.get(n.p1)) { // new nt reached
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
		for (int i=firstNt; i<=lastNt; i++) {
			if (!visited.get(i)) {
				ok = false;
				System.out.println("  " + sy[i].name + " cannot be reached");
			}
		}
		return ok;
	}

	static private boolean Term(int p) { // true if graph can be derived to terminals
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
			for (i=firstNt; i<=lastNt; i++)
				if (!termNt.get(i) && Term(sy[i].struct)) {
					termNt.set(i); changed = true;
				}
		} while (changed);
		for (i=firstNt; i<=lastNt; i++)
			if (!termNt.get(i)) {
				ok = false;
				System.out.println("  " + sy[i].name + "cannot be derived to terminals");
			}
		return ok;
	}

	/*---------------------------------------------------------------------
	  Utility functions
	---------------------------------------------------------------------*/

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
		while (i < maxSymbols) {
			Trace.print(Int(i, 3) + " " + Str(sy[i].name, 10) + " " + nTyp[sy[i].typ]);
			if (sy[i].attrPos==null) Trace.print(" false "); else Trace.print(" true  ");
			Trace.print(Int(sy[i].struct, 5));
			if (sy[i].deletable) Trace.print(" true  "); else Trace.print(" false ");
			Trace.println(Int(sy[i].line, 5));
			if (i==maxT) i = firstNt; else i++;
		}
		Trace.println();
	}

	static void XRef() {
		Symbol sym;
		GraphNode n;
		XNode[] list = new XNode[lastNt+1];
		XNode p, q, x;
		int i, col;
		if (maxT <= 0) return;
		MovePragmas();
		// search lines where symbol has been referenced
		for (i=nNodes; i>=1; i--) {
			n = Node(i);
			if (n.typ==t || n.typ==wt || n.typ==nt) {
				p = new XNode(); p.line = n.line;
				p.next = list[n.p1]; list[n.p1] = p;
			}
		}
		// search lines where symbol has been defined and insert in order
		i = 1;
		while (i <= lastNt) {
			sym = Sym(i); p = list[i]; q = null;
			while (p != null && sym.line > p.line) {q = p; p = p.next;}
			x = new XNode(); x.line = -sym.line; x.next = p;
			if (q==null) list[i] = x; else q.next = x;
			if (i==maxP) i = firstNt; else i++;
		}
		// print cross reference list
		Trace.println();
		Trace.println("Cross reference list:"); Trace.println();
		Trace.println("Terminals:");
		Trace.println("  0 EOF");
		i = 1;
		while (i <= lastNt) {
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
			if (i==maxT) {Trace.println(); Trace.println("Pragmas:");}
			if (i==maxP) {Trace.println(); Trace.println("Nonterminals:"); i = firstNt;}
			else i++;
		}
		Trace.println(); Trace.println();
	}

	static void Init() {
		err = Scanner.err;
		maxSet = 0; set[0] = new BitSet(); set[0].set(eofSy);
		maxT = -1;
		maxP = maxSymbols;
		firstNt = maxSymbols;
		lastNt = maxP - 1;
		dummyName = 0;
		maxC = -1;
		nNodes = -1;
		int dummy = NewNode(0, 0, 0);
	}

}















