package Coco;

import java.io.*;
import java.util.*;

class ParserGen {

    static final int maxSymSets = 128;	// max. nr. of symbol sets
    static final int maxTerm = 3;		// sets of size < maxTerm are enumerated
    static final char CR  = '\r';
    static final char LF  = '\n';
    static final char TAB = '\t';
    static final char EOF = '\uffff';

    static final int tErr = 0;			// error codes
    static final int altErr = 1;
    static final int syncErr = 2;
	
    static int maxSS;					// number of symbol sets
    static int errorNr;					// highest parser error number
    static int curSy;					// symbol whose production is currently generated
    static InputStream fram;			// parser frame file
    static PrintStream gen;				// generated parser source file
    static StringBuffer err;			// generated parser error messages
    static String srcName;				// name of attribute grammar file
    static String srcDir;				// directory of attribute grammar file
    static BitSet[] symSet;
	
    private static String Int(int n, int len) {
	char[] a = new char[16];
	String s = String.valueOf(n);
	int i, j, d = len - s.length();
	for (i=0; i<d; i++) a[i] = ' ';
	for (j=0; i<len; i++) {a[i] = s.charAt(j); j++;}
	return new String(a, 0, len);
    }
	
    private static void Indent(int n) {
	for (int i=1; i<=n; i++) gen.print('\t');
    }
	
    private static int Alternatives (int p) {
	int i = 0;
	while (p > 0) {
	    i++; p = Tab.Node(p).p2;
	}
	return i;
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
			if (i==high) return; // stop[0..i] found
			ch = fram.read(); i++;
		    } while (ch==stop.charAt(i));
		    // stop[0..i-1] found; continue with last read character
		    gen.print(stop.substring(0, i));
		} else if (ch==CR) {
		    ch = fram.read();
		} else if (ch==LF) {
		    gen.println();
		    ch = fram.read();
		} else {
		    gen.print((char)ch);
		    ch = fram.read();
		}
	} catch (IOException e) {
	    Scanner.err.Exception("-- error reading Parser.frame");
	}
    }

    private static void CopySourcePart(Position pos, int indent) {
	// Copy text described by pos from atg to gen
	int ch, nChars, i;
	if (pos != null) {
	    Buffer.Set(pos.beg); ch = Buffer.read(); nChars = pos.len - 1;
	    Indent(indent);
	    loop:
	    while (nChars >= 0) {
		while (ch==CR) {
		    gen.println(); Indent(indent);
		    ch = Buffer.read(); nChars--;
		    if (ch==LF) {ch = Buffer.read(); nChars--;}
		    for (i=1; i<=pos.col && ch<=' '; i++) { // skip blanks at beginning of line
			ch = Buffer.read(); nChars--;
		    }
		    if (i <= pos.col) pos.col = i - 1; // heading TABs => not enough blanks
		    if (nChars < 0) break loop;
		}
		gen.print((char)ch);
		ch = Buffer.read(); nChars--;
	    }
	    if (indent > 0) gen.println();
	}
    }
	
    private static void GenErrorMsg(int errTyp, int errSym) {
	errorNr++;
	String name = Tab.Sym(errSym).name.replace('"', '\'');
	err.append("\t\t\twhen " + errorNr + "; s = \"");
	switch (errTyp) {
	case tErr: {err.append(name + " expected"); break;}
	case altErr: {err.append("invalid " + name); break;}
	case syncErr: {err.append("this symbol not expected in " + name); break;}
	}
	err.append("\"\n");
    }
	
    private static int NewCondSet(BitSet s) {
	for (int i=1; i<=maxSS; i++) // skip symSet[0] (reserved for union of SYNC sets)
	    if (s.equals(symSet[i])) return i;
	maxSS++; symSet[maxSS] = (BitSet) s.clone();
	return maxSS;
    }
	
    private static void GenCond(BitSet s) {
	int n, i;
	n = Sets.Size(s);
	if (n==0) gen.print("false"); // should never happen
	else if (n <= maxTerm)
	    for (i=0; i<=Tab.maxT; i++) {
		if (s.get(i)) {
		    gen.print("@t.kind==" + i);
		    n--; if (n > 0) gen.print(" || ");
		}
	    }
	else gen.print("StartOf(" + NewCondSet(s) + ")");
    }
	
    private static void PutCaseLabels(BitSet s) {
	int max = s.size();
	for (int i=0; i<=max; i++)
	    if (s.get(i)) gen.print("when " + i + " then ");
    }
	
    private static void GenCode (int p, int indent, BitSet checked) {
	GraphNode n, n2;
	BitSet s1, s2;
	boolean equal;
	int alts, p2;
	Symbol sym;
	while (p > 0) {
	    n = Tab.Node(p);
	    switch (n.typ) {
	    case Tab.nt: {
		Indent(indent);
		sym = Tab.Sym(n.p1);
		if (n.retVar!=null) gen.print(n.retVar + " = ");
		gen.print(sym.name + "(");
		CopySourcePart(n.pos, 0);
		gen.println(")");
		break;
	    }
	    case Tab.t: {
		Indent(indent);
		if (checked.get(n.p1)) gen.println("Get()");
		else gen.println("Expect(" + n.p1 + ")");
		break;
	    }
	    case Tab.wt: {
		Indent(indent);
		s1 = Tab.Expected(Math.abs(n.next), curSy);
		s1.or(Tab.Set(0));
		gen.println("ExpectWeak(" + n.p1 + ", " + NewCondSet(s1) + ")");
		break;
	    }
	    case Tab.any: {
		Indent(indent);
		gen.println("Get()");
		break;
	    }
	    case Tab.eps: break; // nothing
	    case Tab.sem: {
		CopySourcePart(n.pos, indent);
		break;
	    }
	    case Tab.sync: {
		Indent(indent);
		GenErrorMsg(syncErr, curSy);
		s1 = (BitSet) Tab.Set(n.p1).clone();
		gen.print("while (!("); GenCond(s1);
		gen.println(")); Error(" + errorNr + "); Get(); end");
		break;
	    }
	    case Tab.alt: {
		s1 = Tab.First(p); equal = s1.equals(checked);
		alts = Alternatives(p);
		if (alts > 5) {Indent(indent); gen.println("case (@t.kind)");}
		p2 = p;
		while (p2 != 0) {
		    n2 = Tab.Node(p2);
		    s1 = Tab.Expected(n2.p1, curSy);
		    Indent(indent);

		    if (alts > 5) {
			PutCaseLabels(s1); gen.println();
		    } else if (p2==p) {
			gen.print("if ("); GenCond(s1); gen.println(") then");
		    } else if (n2.p2==0 && equal) {
			gen.println("else");
		    } else {
			gen.print("elsif ("); GenCond(s1); gen.println(") then");
		    }

		    s1.or(checked);
		    GenCode(n2.p1, indent + 1, s1);
		    /*
		    if (alts > 5) {
			Indent(indent); gen.println();
			Indent(indent); gen.println("end");
		    }
		    */
		    p2 = n2.p2;
		}
		Indent(indent);
		if (equal) gen.println("end");
		else {
		    GenErrorMsg(altErr, curSy);
		    if (alts > 5) {
			gen.println("else");
			gen.println("  Error(" + errorNr + ")");
			Indent(indent); gen.println("end");
		    } else {
			gen.println("else Error(" + errorNr + ")");
			gen.println("end");
		    }
		}
		break;
	    }
	    case Tab.iter: {
		Indent(indent);
		n2 = Tab.Node(n.p1);
		gen.print("while (");
		if (n2.typ==Tab.wt) {
		    s1 = Tab.Expected(Math.abs(n2.next), curSy);
		    s2 = Tab.Expected(Math.abs(n.next), curSy);
		    gen.print("WeakSeparator(" + n2.p1 + "," + NewCondSet(s1) + ","
			      + NewCondSet(s2) + ") ");
		    s1 = new BitSet(); // for inner structure
		    if (n2.next > 0) p2 = n2.next; else p2 = 0;
		} else {
		    p2 = n.p1; s1 = Tab.First(p2); GenCond(s1);
		}
		gen.println(")");
		GenCode(p2, indent + 1, s1);
		Indent(indent); gen.println("end");
		break;
	    }
	    case Tab.opt:
		s1 = Tab.First(n.p1);
		if (!checked.equals(s1)) {
		    Indent(indent);
		    gen.print("if ("); GenCond(s1); gen.println(") then");
		    GenCode(n.p1, indent+1, s1);
		    Indent(indent); gen.println("end");
		} else GenCode(n.p1, indent, checked);
		break;
	    }
	    if (n.typ!=Tab.eps && n.typ!=Tab.sem && n.typ!=Tab.sync) checked = new BitSet();
	    p = n.next;
	}
    }
	
    private static void GenCodePragmas() {
	for (int i=Tab.maxT+1; i<=Tab.maxP; i++) {
	    gen.println("\t\tif (@t.kind==" + i + ") then");
	    CopySourcePart(Tab.Sym(i).semPos, 3);
	    gen.println("\t\tend");
	}
    }
	
    private static void GenProductions() {
	Symbol sym;
	for (curSy=Tab.firstNt; curSy<=Tab.lastNt; curSy++) {
	    sym = Tab.Sym(curSy);
	    gen.print("\tprivate; ");
	    // if (sym.retType==null) gen.print("void "); else gen.print(sym.retType + " ");
	    gen.print("def self.");
	    gen.print(sym.name + "(");
	    CopySourcePart(sym.attrPos, 0); // HACK: need to only copy the varname
	    gen.println(")");
	    // if (sym.retVar!=null) gen.println("\t\t" + sym.retType + " " + sym.retVar);
	    CopySourcePart(sym.semPos, 2);
	    GenCode(sym.struct, 2, new BitSet());
	    if (sym.retVar!=null) gen.println("\t\treturn " + sym.retVar);
	    gen.println("\tend"); gen.println();
	}
    }
	
    private static void InitSets() {
	int i, j;
	BitSet s;
	symSet[0] = Tab.Set(0);
	for (i=0; i<=maxSS; i++) {
	    gen.print("\t["); s = symSet[i];
	    for (j=0; j<=Tab.maxT; j++) {
		if (s.get(j)) gen.print("T,"); else gen.print("X,");
		if (j%4==3) gen.print(" ");
	    }
	    if (i < maxSS) gen.println("X],"); else gen.print("X],");
	}
    }
	
    static String GetString(int beg, int end) {
	StringBuffer s = new StringBuffer();
	int oldPos = Buffer.pos;
	Buffer.Set(beg);
	while (beg < end) {s.append((char)Buffer.read()); beg++;}
	Buffer.Set(oldPos);
	return s.toString();
    }
	
    static void WriteParser() {
	OutputStream s;
	Symbol root = Tab.Sym(Tab.gramSy);
	try {fram = new BufferedInputStream(new FileInputStream(srcDir + "Parser.frame"));}
	catch (IOException e) {
	    Scanner.err.Exception("-- cannot open Parser.frame. " +
				  "Must be in the same directory as the grammar file.");
	}
	try {
	    s = new BufferedOutputStream(new FileOutputStream(srcDir + "Parser.rb"));
	    gen = new PrintStream(s);}
	catch (IOException e) {
	    Scanner.err.Exception("-- cannot generate parser file");
	}
	err = new StringBuffer(2048);
	for (int i=0; i<=Tab.maxT; i++) GenErrorMsg(tErr, i);
	gen.println("# This file is generated. DO NOT MODIFY!");
	gen.println();
	// gen.println("class " + root.name); // HACK
	CopyFramePart("-->constants");
	gen.println("\tprivate; MaxT = " + Tab.maxT); // TODO: const case them
	gen.println("\tprivate; MaxP = " + Tab.maxP);
	CopyFramePart("-->declarations"); CopySourcePart(Tab.semDeclPos, 0);
	CopyFramePart("-->pragmas"); GenCodePragmas();
	CopyFramePart("-->productions"); GenProductions();
	CopyFramePart("-->parseRoot"); gen.println("\t\t" + Tab.Sym(Tab.gramSy).name + "()");
	CopyFramePart("-->initialization"); InitSets();
	CopyFramePart("-->ErrorStream");
	gen.close();
		
	try {
	    s = new BufferedOutputStream(new FileOutputStream(srcDir + "ErrorStream.rb"));
	    gen = new PrintStream(s);}
	catch (IOException e) {
	    Scanner.err.Exception("-- cannot generate error stream file");
	}
	gen.println("# This file is generated. DO NOT MODIFY!");
	gen.println();
	// gen.println("class " + root.name); // HACK
	CopyFramePart("-->errors"); gen.print(err.toString());
	CopyFramePart("$$$");
	gen.close();
    }
	
    static void WriteStatistics() {
	Trace.println((Tab.maxT+1) + " terminals");
	Trace.println((Tab.maxSymbols-Tab.firstNt+Tab.maxT+1) + " symbols");
	Trace.println(Tab.nNodes + " nodes");
	Trace.println(maxSS + " sets");
    }

    static void Init(String src, String dir) {
	srcName = src;
	srcDir = dir;
	errorNr = -1;
	symSet = new BitSet[maxSymSets];
	maxSS = 0; // symSet[0] reserved for union of all SYNC sets
    }
	
}
