package Coco;
import java.util.*;

class Parser {
	private static final int maxT = 40;
	private static final int maxP = 41;

	private static final boolean T = true;
	private static final boolean x = false;
	
	static Token token;			// last recognized token
	static Token t;				// lookahead token

	private static final int ident = 0;
	private static final int string = 1;
	
	private static boolean genScanner;

	private static void SemErr(int n) {
		Scanner.err.SemErr(n, t.line, t.col);
	}
	
	private static void MatchLiteral(int sp) { // store string either as token or as literal
		Symbol sym, sym1;
		int matchedSp;
		sym = Tab.Sym(sp);
		matchedSp = DFA.MatchedDFA(sym.name, sp);
		if (matchedSp==Tab.noSym) sym.struct = Tab.classToken;
		else {
			sym1 = Tab.Sym(matchedSp); sym1.struct = Tab.classLitToken;
			sym.struct = Tab.litToken;
		}
	}
	
	private static void SetCtx(int p) { // set transition code to contextTrans
		GraphNode n;
		while (p > 0) {
			n = Tab.Node(p);
			if (n.typ==Tab.chr || n.typ==Tab.clas) {
				n.p2 = Tab.contextTrans;
			} else if (n.typ==Tab.opt || n.typ==Tab.iter) {
				SetCtx(n.p1);
			} else if (n.typ==Tab.alt) {
				SetCtx(n.p1); SetCtx(n.p2);
			}
			p = n.next;
		}
	}
	
	private static void SetDDT(String s) {
		char ch;
		for (int i=1; i<s.length(); i++) {
			ch = s.charAt(i);
			if (Character.isDigit(ch)) Tab.ddt[Character.digit(ch, 10)] = true;
		}
	}
	
	private static String FixString(String s) {
		char[] a = s.toCharArray();
		int len = a.length;
		if (len == 2) SemErr(29);
		boolean dbl = false;
		for (int i=1; i<len-1; i++)
			if (a[i]=='"') dbl = true; else if (a[i]==' ') SemErr(24);
		if (!dbl) {a[0] = '"'; a[len-1] = '"';}
		return new String(a, 0, len);
	}
	

/*-------------------------------------------------------------------------*/


	private static void Error(int n) {
		Scanner.err.ParsErr(n, t.line, t.col);
	}
	
	private static void Get() {
		for (;;) {
			token = t;
			t = Scanner.Scan();
			if (t.kind<=maxT) return;
		if (t.kind==41) {
			SetDDT(t.val); 
		}

			t = token;
		}
	}
	
	private static void Expect(int n) {
		if (t.kind==n) Get(); else Error(n);
	}
	
	private static boolean StartOf(int s) {
		return set[s][t.kind];
	}
	
	private static void ExpectWeak(int n, int follow) {
		if (t.kind == n) Get();
		else {
			Error(n);
			while (!StartOf(follow)) Get();
		}
	}
	
	private static boolean WeakSeparator(int n, int syFol, int repFol) {
		boolean[] s = new boolean[maxT+1];
		if (t.kind==n) {Get(); return true;}
		else if (StartOf(repFol)) return false;
		else {
			for (int i=0; i<=maxT; i++) {
				s[i] = set[syFol][i] || set[repFol][i] || set[0][i];
			}
			Error(n);
			while (!s[t.kind]) Get();
			return StartOf(syFol);
		}
	}
	
	private static void AttrRest1(GraphNode n) {
		int beg, col; 
		beg = t.pos; col = t.col; 
		while (StartOf(1)) {
			Get();
		}
		Expect(31);
		if (token.pos > beg) {
		    n.pos = new Position();
		    n.pos.beg = beg; n.pos.col = col;
		    n.pos.len = token.pos - beg;
		} 
	}

	private static void AttrRest(GraphNode n) {
		int beg, col; 
		beg = t.pos; col = t.col; 
		while (StartOf(2)) {
			Get();
		}
		Expect(29);
		if (token.pos > beg) {
		    n.pos = new Position();
		    n.pos.beg = beg; n.pos.col = col;
		    n.pos.len = token.pos - beg;
		} 
	}

	private static Graph TokenFactor() {
		Graph g;
		String name; int kind, c; SymInfo s; 
		g = new Graph(); 
		if (t.kind==1 || t.kind==2) {
			s = Symbol();
			if (s.kind==ident) {
			    c = Tab.ClassWithName(s.name);
			    if (c < 0) {
			        SemErr(15);
			        c = Tab.NewClass(s.name, new BitSet());
			    }
			    g.l = Tab.NewNode(Tab.clas, c, 0);
			    g.r = g.l;
			} else /*string*/ g = Tab.StrToGraph(s.name); 
		} else if (t.kind==21) {
			Get();
			g = TokenExpr();
			Expect(22);
		} else if (t.kind==26) {
			Get();
			g = TokenExpr();
			Expect(27);
			g = Tab.Option(g); 
		} else if (t.kind==34) {
			Get();
			g = TokenExpr();
			Expect(35);
			g = Tab.Iteration(g); 
		} else Error(41);
		return g;
	}

	private static Graph TokenTerm() {
		Graph g;
		Graph g2; 
		g = TokenFactor();
		while (StartOf(3)) {
			g2 = TokenFactor();
			g = Tab.Sequence(g, g2); 
		}
		if (t.kind==37) {
			Get();
			Expect(21);
			g2 = TokenExpr();
			SetCtx(g2.l); g = Tab.Sequence(g, g2); 
			Expect(22);
		}
		return g;
	}

	private static void Attribs(GraphNode n) {
		int beg, col; 
		if (t.kind==24) {
			Get();
			if (t.kind==25) {
				Get();
				beg = t.pos; 
				while (StartOf(4)) {
					Get();
				}
				n.retVar = ParserGen.GetString(beg, t.pos); 
				if (t.kind==28) {
					Get();
					AttrRest(n);
				} else if (t.kind==29) {
					Get();
				} else Error(42);
			} else if (StartOf(5)) {
				AttrRest(n);
			} else Error(43);
		} else if (t.kind==30) {
			Get();
			if (t.kind==25) {
				Get();
				beg = t.pos; 
				while (StartOf(6)) {
					Get();
				}
				n.retVar = ParserGen.GetString(beg, t.pos); 
				if (t.kind==28) {
					Get();
					AttrRest1(n);
				} else if (t.kind==31) {
					Get();
				} else Error(44);
			} else if (StartOf(5)) {
				AttrRest1(n);
			} else Error(45);
		} else Error(46);
	}

	private static Graph Factor() {
		Graph g;
		GraphNode n;
		SymInfo s;
		Symbol sym;
		Position pos;
		BitSet set;
		int sp, typ;
		boolean undef, weak = false; 
		g = new Graph(); weak = false; 
		switch (t.kind) {
		case 1: case 2: case 33: {
			if (t.kind==33) {
				Get();
				weak = true; 
			}
			s = Symbol();
			sp = Tab.FindSym(s.name); undef = sp==Tab.noSym;
			if (undef) {
			    if (s.kind==ident)
			        sp = Tab.NewSym(Tab.nt, s.name, 0); // forward nt
			    else if (genScanner) { 
			        sp = Tab.NewSym(Tab.t, s.name, token.line);
			        MatchLiteral(sp);
			    } else { // undefined string in production
			        SemErr(6); sp = 0;
			    }
			}
			sym = Tab.Sym(sp); typ = sym.typ;
			if (typ!=Tab.t && typ!=Tab.nt) SemErr(4);
			if (weak)
			    if (sym.typ==Tab.t) typ = Tab.wt; else SemErr(23);
			g.l = Tab.NewNode(typ, sp, token.line); g.r = g.l;
			n = Tab.Node(g.l); 
			if (t.kind==24 || t.kind==30) {
				Attribs(n);
				if (s.kind!=ident) SemErr(3); 
			}
			if (undef) {
			    sym.attrPos = n.pos; sym.retVar = n.retVar; // dummies
			} else
			    if (n.pos!=null && sym.attrPos==null
			    || n.retVar!=null && sym.retVar==null
			    || n.pos==null && sym.attrPos!=null
			    || n.retVar==null && sym.retVar!=null) SemErr(5);
			
			break;
		}
		case 21: {
			Get();
			g = Expression();
			Expect(22);
			break;
		}
		case 26: {
			Get();
			g = Expression();
			Expect(27);
			g = Tab.Option(g); 
			break;
		}
		case 34: {
			Get();
			g = Expression();
			Expect(35);
			g = Tab.Iteration(g); 
			break;
		}
		case 38: {
			pos = SemText();
			g.l = Tab.NewNode(Tab.sem, 0, 0);
			g.r = g.l;
			n = Tab.Node(g.l); n.pos = pos; 
			break;
		}
		case 23: {
			Get();
			set = Sets.FullSet(Tab.maxTerminals);
			set.clear(Tab.eofSy);
			g.l = Tab.NewNode(Tab.any, Tab.NewSet(set), 0);
			g.r = g.l; 
			break;
		}
		case 36: {
			Get();
			g.l = Tab.NewNode(Tab.sync, 0, 0);
			g.r = g.l; 
			break;
		}
		default: Error(47);
		}
		return g;
	}

	private static Graph Term() {
		Graph g;
		Graph g2; 
		g = null; 
		if (StartOf(7)) {
			g = Factor();
			while (StartOf(7)) {
				g2 = Factor();
				g = Tab.Sequence(g, g2); 
			}
		} else if (StartOf(8)) {
			g = new Graph();
			g.l = Tab.NewNode(Tab.eps, 0, 0);
			g.r = g.l; 
		} else Error(48);
		return g;
	}

	private static SymInfo Symbol() {
		SymInfo s;
		s = new SymInfo(); 
		if (t.kind==1) {
			Get();
			s.kind = ident; s.name = token.val; 
		} else if (t.kind==2) {
			Get();
			s.kind = string; s.name = FixString(token.val); 
		} else Error(49);
		return s;
	}

	private static BitSet SimSet() {
		BitSet s;
		String name; int c, n; 
		s = new BitSet(128); 
		if (t.kind==1) {
			Get();
			c = Tab.ClassWithName(token.val);
			if (c < 0) SemErr(15); else s.or(Tab.Class(c)); 
		} else if (t.kind==2) {
			Get();
			name = token.val;
			for (int i=1; name.charAt(i)!=name.charAt(0); i++)
			    s.set((int) name.charAt(i)); 
		} else if (t.kind==20) {
			Get();
			Expect(21);
			Expect(3);
			n = Integer.parseInt(token.val, 10);
			s.set(n); 
			Expect(22);
		} else if (t.kind==23) {
			Get();
			s = Sets.FullSet(127); 
		} else Error(50);
		return s;
	}

	private static BitSet Set() {
		BitSet s;
		BitSet s2; 
		s = SimSet();
		while (t.kind==18 || t.kind==19) {
			if (t.kind==18) {
				Get();
				s2 = SimSet();
				s.or(s2); 
			} else {
				Get();
				s2 = SimSet();
				Sets.Differ(s, s2); 
			}
		}
		return s;
	}

	private static Graph TokenExpr() {
		Graph g;
		Graph g2; boolean first; 
		g = TokenTerm();
		first = true; 
		while (WeakSeparator(32,3,9) ) {
			g2 = TokenTerm();
			if (first) {g = Tab.FirstAlt(g); first = false;}
			g = Tab.Alternative(g, g2); 
		}
		return g;
	}

	private static void TokenDecl(int typ) {
		SymInfo s; int sp; Position pos; Graph g; 
		s = Symbol();
		if (Tab.FindSym(s.name) != Tab.noSym) {SemErr(7); sp = 0;}
		else {
		    sp = Tab.NewSym(typ, s.name, token.line);
		    Tab.Sym(sp).struct = Tab.classToken;
		} 
		while (!(StartOf(10))) {Error(51); Get();}
		if (t.kind==7) {
			Get();
			g = TokenExpr();
			Expect(8);
			if (s.kind != ident) SemErr(13);
			Tab.CompleteGraph(g.r);
			DFA.ConvertToStates(g.l, sp); 
		} else if (StartOf(11)) {
			if (s.kind==ident) genScanner = false;
			else MatchLiteral(sp); 
		} else Error(52);
		if (t.kind==38) {
			pos = SemText();
			if (typ==Tab.t) SemErr(14);
			Tab.Sym(sp).semPos = pos; 
		}
	}

	private static void SetDecl() {
		int c; BitSet s; String name; 
		Expect(1);
		name = token.val;
		c = Tab.ClassWithName(name);
		if (c > 0) SemErr(7); 
		Expect(7);
		s = Set();
		c = Tab.NewClass(name, s); 
		Expect(8);
	}

	private static Graph Expression() {
		Graph g;
		Graph g2; boolean first; 
		g = Term();
		first = true; 
		while (WeakSeparator(32,12,13) ) {
			g2 = Term();
			if (first) {g = Tab.FirstAlt(g); first = false;}
			g = Tab.Alternative(g, g2); 
		}
		return g;
	}

	private static Position SemText() {
		Position pos;
		Expect(38);
		pos = new Position();
		pos.beg = t.pos; pos.col = t.col; 
		while (StartOf(14)) {
			if (StartOf(15)) {
				Get();
			} else if (t.kind==4) {
				Get();
				SemErr(18); 
			} else {
				Get();
				SemErr(19); 
			}
		}
		Expect(39);
		pos.len = token.pos - pos.beg; 
		return pos;
	}

	private static void AttrDecl(Symbol sym) {
		int beg, col, dim; StringBuffer buf;
		if (t.kind==24) {
			Get();
			if (t.kind==25) {
				Get();
				Expect(1);
				buf = new StringBuffer(token.val); dim = 0;
				while (t.kind==26) {
					Get();
					Expect(27);
					dim++; 
				}
				Expect(1);
				sym.retVar = token.val; 
				while (t.kind==26) {
					Get();
					Expect(27);
					dim++; 
				}
				while (dim > 0) { buf.append("[]"); dim--; }
				sym.retType = buf.toString(); 
				if (t.kind==28) {
					Get();
				}
			}
			beg = t.pos; col = t.col; 
			while (StartOf(2)) {
				Get();
			}
			Expect(29);
			if (token.pos > beg) {
			    sym.attrPos = new Position();
			    sym.attrPos.beg = beg; sym.attrPos.col = col;
			    sym.attrPos.len = token.pos - beg;
			} 
		} else if (t.kind==30) {
			Get();
			if (t.kind==25) {
				Get();
				Expect(1);
				buf = new StringBuffer(token.val); dim = 0;
				while (t.kind==26) {
					Get();
					Expect(27);
					dim++; 
				}
				Expect(1);
				sym.retVar = token.val; 
				while (t.kind==26) {
					Get();
					Expect(27);
					dim++; 
				}
				while (dim > 0) { buf.append("[]"); dim--; }
				sym.retType = buf.toString(); 
				if (t.kind==28) {
					Get();
				}
			}
			beg = t.pos; col = t.col; 
			while (StartOf(1)) {
				Get();
			}
			Expect(31);
			if (token.pos > beg) {
			    sym.attrPos = new Position();
			    sym.attrPos.beg = beg; sym.attrPos.col = col;
			    sym.attrPos.len = token.pos - beg;
			} 
		} else Error(53);
	}

	private static void Declaration() {
		Graph g1, g2; boolean nested = false; 
		if (t.kind==10) {
			Get();
			while (t.kind==1) {
				SetDecl();
			}
		} else if (t.kind==11) {
			Get();
			while (t.kind==1 || t.kind==2) {
				TokenDecl(Tab.t);
			}
		} else if (t.kind==12) {
			Get();
			while (t.kind==1 || t.kind==2) {
				TokenDecl(Tab.pr);
			}
		} else if (t.kind==13) {
			Get();
			Expect(14);
			g1 = TokenExpr();
			Expect(15);
			g2 = TokenExpr();
			if (t.kind==16) {
				Get();
				nested = true; 
			} else if (StartOf(16)) {
				nested = false; 
			} else Error(54);
			new Comment(g1.l, g2.l, nested); 
		} else if (t.kind==17) {
			Get();
			Tab.ignored = Set();
		} else Error(55);
	}

	private static void Coco() {
		int gramLine, sp, eofSy;
		boolean undef, noAttrs, noRet, ok, ok1;
		String gramName;
		Symbol sym;
		Graph g; 
		Expect(5);
		gramLine = token.line;
		eofSy = Tab.NewSym(Tab.t, "EOF", 0);
		genScanner = true;
		ok = true;
		Tab.ignored = new BitSet(); 
		Expect(1);
		gramName = token.val;
		Tab.semDeclPos = new Position();
		Tab.semDeclPos.beg = t.pos; 
		while (StartOf(17)) {
			Get();
		}
		Tab.semDeclPos.len = t.pos - Tab.semDeclPos.beg;
		Tab.semDeclPos.col = 0; 
		while (StartOf(18)) {
			Declaration();
		}
		while (!(t.kind==0 || t.kind==6)) {Error(56); Get();}
		Expect(6);
		Tab.ignored.set(32); /*' ' is always ignored*/
		if (genScanner) ok = DFA.MakeDeterministic();
		Tab.nNodes = 0; 
		while (t.kind==1) {
			Get();
			sp = Tab.FindSym(token.val);
			undef = sp == Tab.noSym;
			if (undef) {
			    sp = Tab.NewSym(Tab.nt, token.val, token.line);
			    sym = Tab.Sym(sp);
			} else {
			    sym = Tab.Sym(sp);
			    if (sym.typ==Tab.nt) {
			        if (sym.struct > 0) SemErr(7);
			    } else SemErr(8);
			      sym.line = token.line;
			}
			noAttrs = sym.attrPos==null; sym.attrPos = null;
			noRet = sym.retVar==null; sym.retVar = null; 
			if (t.kind==24 || t.kind==30) {
				AttrDecl(sym);
			}
			if (!undef)
			    if (noAttrs && sym.attrPos!=null 
			    || noRet && sym.retVar!=null
			    || !noAttrs && sym.attrPos==null
			    || !noRet && sym.retVar==null) SemErr(5);
			
			if (t.kind==38) {
				sym.semPos = SemText();
			}
			ExpectWeak(7, 19);
			g = Expression();
			sym.struct = g.l;
			Tab.CompleteGraph(g.r); 
			ExpectWeak(8, 20);
		}
		if (Tab.ddt[2]) Tab.PrintGraph();
		Tab.gramSy = Tab.FindSym(gramName);
		if (Tab.gramSy==Tab.noSym) SemErr(11);
		else {
		    sym = Tab.Sym(Tab.gramSy);
		    if (sym.attrPos != null) SemErr(12);
		} 
		Expect(9);
		Expect(1);
		if (!gramName.equals(token.val)) SemErr(17);
		if (Scanner.err.count == 0) {
		    System.out.println("checking");
		    Tab.CompSymbolSets();
		    if (ok) ok = Tab.NtsComplete();
		    if (ok) {
		        ok1 = Tab.AllNtReached();
		        ok = Tab.NoCircularProductions();
		    }
		    if (ok) ok = Tab.AllNtToTerm();
		    if (ok) ok1 = Tab.LL1();
		    if (Tab.ddt[7]) Tab.XRef();
		    if (ok) {
		        System.out.print("parser"); System.out.flush();
		        ParserGen.WriteParser();
		        if (genScanner) {
		            System.out.print(" + scanner");
		            System.out.flush();
		            ok = DFA.WriteScanner();
		            if (Tab.ddt[0]) DFA.PrintStates();
		        }
		        System.out.println(" generated");
		        if (Tab.ddt[8]) ParserGen.WriteStatistics();
		    }
		} else ok = false;
		if (Tab.ddt[6]) Tab.PrintSymbolTable();
		System.out.println(); 
		Expect(8);
	}



	static void Parse() {
		t = new Token();
		Get();
		Coco();

	}

	private static boolean[][] set = {
	{T,T,T,x, x,x,T,T, x,x,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,x, T,T,T,T, T,T,T,T, T,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,x,T,T, T,T,T,T, T,T,T,T, T,x},
	{x,T,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,T,x,x, x,x,T,x, x,x,x,x, x,x,T,x, x,x,x,x, x,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, x,x,T,T, T,T,T,T, T,T,T,T, T,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, x,T,T,x, T,T,T,T, T,T,T,T, T,x},
	{x,T,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,T,x,T, x,x,T,x, x,x,x,x, x,T,T,x, T,x,T,x, x,x},
	{x,x,x,x, x,x,x,x, T,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,T, x,x,x,x, T,x,x,T, x,x,x,x, x,x},
	{x,x,x,x, x,x,T,x, T,x,T,T, T,T,x,T, T,T,x,x, x,x,T,x, x,x,x,T, x,x,x,x, x,x,x,T, x,x,x,x, x,x},
	{T,T,T,x, x,x,T,T, x,x,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x},
	{x,T,T,x, x,x,T,x, x,x,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x},
	{x,T,T,x, x,x,x,x, T,x,x,x, x,x,x,x, x,x,x,x, x,T,T,T, x,x,T,T, x,x,x,x, T,T,T,T, T,x,T,x, x,x},
	{x,x,x,x, x,x,x,x, T,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,T, x,x,x,x, x,x,x,T, x,x,x,x, x,x},
	{x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,x, T,x},
	{x,T,T,T, x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,x,x, T,x},
	{x,x,x,x, x,x,T,x, x,x,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x},
	{x,T,T,T, T,T,x,T, T,T,x,x, x,x,T,T, T,x,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,x},
	{x,x,x,x, x,x,x,x, x,x,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x},
	{T,T,T,x, x,x,T,T, T,x,T,T, T,T,x,x, x,T,x,x, x,T,x,T, x,x,T,x, x,x,x,x, T,T,T,x, T,x,T,x, x,x},
	{T,T,T,x, x,x,T,T, x,T,T,T, T,T,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x}

	};
}

