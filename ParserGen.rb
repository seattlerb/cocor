
class ParserGen

  MaxSymSets = 128	# max. nr. of symbol sets
  MaxTerm    = 3	# sets of size < maxTerm are enumerated
  CR         = '\r'
  LF         = '\n'
  TAB        = '\t'
  EOF        = '\uffff'

  TErr = 0		# error codes
  AltErr = 1
  SyncErr = 2

  @@maxSS = 0		# number of symbol sets
  @@errorNr = 0	# highest parser error number
  @@curSy = 0		# symbol whose production is currently generated
  @@fram = nil		# parser frame file
  @@gen = nil		# generated parser source file
  @@err = nil		# generated parser error messages
  @@srcName = ""	# name of attribute grammar file
  @@srcDir = ""	# directory of attribute grammar file
  @@symSet = []

  def self.Init(file, dir)
    @@srcName = file
    @@srcDir = dir
    @@errorNr = -1
    @@symSet = Array.new(MaxSymSets)
    @@maxSS = 0 # @@symSet[0] reserved for union of all SYNC sets
  end

  def self.Int(n, len) # FIX: this doesn't appear to be used
    sprintf("%*d", len, n)
  end

  def self.Indent(n)
    "\t" * n
  end

  def self.Alternatives(p)
    i = 0
    while (p > 0) do
      i += 1
      p = Tab.Node(p).p2
    end
    return i
  end

  # TODO: this has got to be a 2 liner in ruby...
  def self.CopyFramePart(stop)
    ch = i = j = 0
    startCh = stop[0]
    high = stop.length() - 1

    begin
      ch = @@fram.read()
      while (ch!=EOF) do
	if (ch==startCh) then
	  i = 0
	  begin
	    return if (i==high) # stop[0..i] found
	    ch = @@fram.read()
	    i += 1
	  end while (ch==stop[i])
	  # stop[0..i-1] found; continue with last read character
	  @@gen.print(stop.substring(0, i))
	elsif (ch==CR) then
	  ch = @@fram.read()
	elsif (ch==LF) then
	  @@gen.println()
	  ch = @@fram.read()
	else
	  @@gen.print(ch.chr)
	  ch = @@fram.read()
	end
      end
    rescue 
      Scanner.err.Exception("-- error reading Parser.frame")
    end
  end

  def self.CopySourcePart(pos, indent)
    # Copy text described by pos from atg to @@gen
    ch = nChars = i = 0

    if (pos != null) then
      Buffer.Set(pos.beg)
      ch = Buffer.read()
      nChars = pos.len - 1
      Indent(indent)
      catch :loop do
        while (nChars >= 0) do
	  while (ch==CR) do
	    @@gen.println()
	    Indent(indent)
	    ch = Buffer.read()
	    nChars -= 1
	    if (ch==LF) then
	      ch = Buffer.read()
	      nChars -= 1
	    end
	    i = 1

	    # skip blanks at beginning of line
	    while (i<=pos.col && ch<=' ') do
	      ch = Buffer.read()
	      nChars -= 1
	      i += 1
	    end

	    # heading TABs => not enough blanks
	    pos.col = i - 1 if (i <= pos.col)

	    throw :loop if (nChars < 0) # jumps to end of catch
	  end # inner while
	  @@gen.print(ch.chr)
	  ch = Buffer.read()
	  nChars -= 1
	end # outer while
      end # catch
      @@gen.println if (indent > 0)
    end
  end

  def self.GenErrorMsg(errTyp, errSym)
    @@errorNr += 1
    name = Tab.Sym(@@errSym).name.gsub('"', '\'')
    @@err.append("\t\t\twhen " + @@errorNr + "; s = \"")

    case @@errTyp
    when TErr
      @@err.append(name + " expected")
    when AltErr
	@@err.append("invalid " + name)
    when SyncErr
      @@err.append("this symbol not expected in " + name)
    end
    @@err.append("\"\n")
  end

  def self.NewCondSet(s)
    for i in 1..@@maxSS do # skip @@symSet[0] (reserved for union of SYNC sets)
      return i if (s == @@symSet[i])
    end
    @@maxSS += 1
    @@symSet[@@maxSS] = s.clone
    return @@maxSS
  end

  def self.GenCond(s) 
    i = 0
    n = Sets.Size(s)
    if (n==0) then
      @@gen.print("false") # should never happen
    elsif (n <= maxTerm) then
      for i in 0..Tab.maxT do
	if (s.get(i)) then
	  @@gen.print("@t.kind==" + i)
	  n -= 1
	  if (n > 0) then
	    @@gen.print(" || ")
	  end
	end
      end
    else
      @@gen.print("StartOf(" + NewCondSet(s) + ")")
    end
  end

  def self.PutCaseLabels(s)
    max = s.size
    first = true
    @@gen.print("when ")

    # TODO: this could probably be a 2 liner w/ join(", ")
    for i in 0..max do
      if (s.get(i)) then
	if (!first) then
	  @@gen.print(", ")
	else
	  first = false
	end
	@@gen.print(i)
      end
    end
    @@gen.println(" then")
  end

  def self.GenCode (p, indent, checked)
    raise "not ported yet"
  end

  def self.GenCodePragmas
    for i in Tab.maxT+1..Tab.maxP do
      @@gen.println("\t\tif (@t.kind==" + i + ") then")
      CopySourcePart(Tab.Sym(i).semPos, 3)
      @@gen.println("\t\tend")
    end
  end

  def self.GenProductions
    sym = nil
    for @@curSy in Tab.firstNt..Tab.lastNt do
      sym = Tab.Sym(@@curSy)
      @@gen.print("\tprivate; ")
      # if (sym.retType==null) @@gen.print("void ")
      # else @@gen.print(sym.retType + " ")
      @@gen.print("def self.")
      @@gen.print(sym.name + "(")
      
      if (sym.attrPos != null) then
	args = GetString(sym.attrPos.beg, sym.attrPos.beg + sym.attrPos.len)
	args = args.split(/\s*,\s*/)
	args.each do | arg_pair |
	  names = arg.split(/\s+/)
	  type = names.shift # Ignore the type in ruby...
	  unless (name.empty?) then
	    @@gen.print(names.join(", "))
	  end
	end
      end

      # HACK: need to only copy the varname
      # HACK CopySourcePart(sym.attrPos, 0)

      @@gen.println(")")
      # if (sym.retVar!=null) 
      #   @@gen.println("\t\t" + sym.retType + " " + sym.retVar)
      # HACK @@gen.println("\t\t$std@@err.puts(\"+ " + sym.name + "\")")

      CopySourcePart(sym.semPos, 2)
      GenCode(sym.struct, 2, new BitSet())

      # HACK @@gen.println("\t\t$std@@err.puts(\"- " + sym.name + "\")")

      @@gen.println("\t\treturn " + sym.retVar) if (sym.retVar!=null)
      @@gen.println("\tend")
      @@gen.println()
    end
  end

  def self.InitSets
    i = j = 0
    s = nil
    @@symSet[0] = Tab.Set(0)
    for i in 0..@@maxSS do
      @@gen.print("\t[")
      s = @@symSet[i]
      for j in 0..Tab.maxT do
	if (s.get(j)) then
	  @@gen.print("T,")
	else
	  @@gen.print("X,")
	end
	@@gen.print(" ") if (j%4==3)
      end
      if (i < @@maxSS) then
	@@gen.println("X],")
      else
	@@gen.print("X],")
      end
    end
  end

  def self.GetString(beg, nd)
    s = ""
    oldPos = Buffer.pos
    Buffer.Set(beg)
    while (beg < nd) do
      s += Buffer.read.chr
      beg += 1
    end
    Buffer.Set(oldPos)
    return s.to_s
  end

  def self.WriteParser()
    s = nil
    root = Tab.Sym(Tab.gramSy)

    begin
      @@fram = File.new(@@srcDir + "Parser.frame")
    rescue 
      Scanner.err.Exception("-- 1 cannot open Parser.frame. " +
			    "Must be in the same directory as the grammar file.")
    end

    begin
      @@gen = File.new(@@srcDir + "Parser.rb", "w")
    rescue
      Scanner.err.Exception("-- cannot generate parser file")
    end

    @@err = new StringBuffer(2048);

    for i in 0..Tab.maxT do
      GenErrorMsg(tErr, i);
    end

    @@gen.println("# This file is @@generated. DO NOT MODIFY!");
    @@gen.println();
    # @@gen.println("class " + root.name); # HACK
    CopyFramePart("-->constants");
    @@gen.println("\tprivate; MaxT = " + Tab.maxT); # TODO: const case them
    @@gen.println("\tprivate; MaxP = " + Tab.maxP);
    CopyFramePart("-->declarations");
    CopySourcePart(Tab.semDeclPos, 0);
    CopyFramePart("-->pragmas");
    GenCodePragmas();
    CopyFramePart("-->productions");
    GenProductions();
    CopyFramePart("-->parseRoot");
    @@gen.println("\t\t" + Tab.Sym(Tab.gramSy).name + "()");
    CopyFramePart("-->initialization");
    InitSets();
    CopyFramePart("-->ErrorStream");
    @@gen.close();

    begin
      s = File.new(@@srcDir + "ErrorStream.rb", "w");
      @@gen = new PrintStream(s);
    rescue
      Scanner.err.Exception("-- cannot generate error stream file");
    end
    @@gen.println("# This file is @@generated. DO NOT MODIFY!");
    @@gen.println();
    # @@gen.println("class " + root.name); # HACK
    CopyFramePart("-->errors");
    @@gen.print(@@err.toString());
    CopyFramePart("$$$");
    @@gen.close();
  end

end

__END__

class ParserGen {

def self.WriteStatistics() {
Trace.println((Tab.maxT+1) + " terminals");
Trace.println((Tab.maxSymbols-Tab.firstNt+Tab.maxT+1) + " symbols");
Trace.println(Tab.nNodes + " nodes");
Trace.println(@@maxSS + " sets");
}

def self.Init(String src, String dir) {
# ...
}

def self.GenCode (int p, int indent, BitSet checked) {
GraphNode n, n2;
BitSet s1, s2;
boolean equal;
int alts, p2;
Symbol sym;
while (p > 0) {
n = Tab.Node(p);
case (n.typ) {
when Tab.nt
Indent(indent);
sym = Tab.Sym(n.p1);
if (n.retVar!=null) @@gen.print(n.retVar + " = ");
@@gen.print(sym.name + "(");
CopySourcePart(n.pos, 0);
@@gen.println(")");
break;
}
when Tab.t
Indent(indent);
if (checked.get(n.p1)) @@gen.println("Get()");
else @@gen.println("Expect(" + n.p1 + ")");
break;
}
when Tab.wt
Indent(indent);
s1 = Tab.Expected(Math.abs(n.next), @@curSy);
s1.or(Tab.Set(0));
@@gen.println("ExpectWeak(" + n.p1 + ", " + NewCondSet(s1) + ")");
break;
}
when Tab.any
Indent(indent);
@@gen.println("Get()");
break;
}
when Tab.eps: break; # nothing
when Tab.sem
CopySourcePart(n.pos, indent);
break;
}
when Tab.sync
Indent(indent);
GenErrorMsg(SyncErr, @@curSy);
s1 = (BitSet) Tab.Set(n.p1).clone();
@@gen.print("while (!(");
GenCond(s1);
@@gen.println(")); Error(" + @@errorNr + "); Get(); end");
break;
}
when Tab.alt
s1 = Tab.First(p);
 equal = s1.equals(checked);
alts = Alternatives(p);
if (alts > 5) {Indent(indent);
 @@gen.println("case (@t.kind)");}
p2 = p;
while (p2 != 0) {
n2 = Tab.Node(p2);
s1 = Tab.Expected(n2.p1, @@curSy);
Indent(indent);

if (alts > 5) {
PutCaseLabels(s1);
 @@gen.println();
} else if (p2==p) {
@@gen.print("if (");
GenCond(s1);
 @@gen.println(") then");
} else if (n2.p2==0 && equal) {
@@gen.println("else");
} else {
@@gen.print("elsif (");
GenCond(s1);
 @@gen.println(") then");
}

s1.or(checked);
GenCode(n2.p1, indent + 1, s1);

#if (alts > 5) {
#Indent(indent);
# @@gen.println();
#Indent(indent);
# @@gen.println("end");
#}

p2 = n2.p2;
}
Indent(indent);
if (equal) @@gen.println("end");
else {
GenErrorMsg(AltErr, @@curSy);
if (alts > 5) {
@@gen.println("else");
@@gen.println("  Error(" + @@errorNr + ")");
Indent(indent);
 @@gen.println("end");
} else {
@@gen.println("else Error(" + @@errorNr + ")");
@@gen.println("end");
}
}
break;
}
when Tab.iter
Indent(indent);
n2 = Tab.Node(n.p1);
@@gen.print("while (");
if (n2.typ==Tab.wt) {
s1 = Tab.Expected(Math.abs(n2.next), @@curSy);
s2 = Tab.Expected(Math.abs(n.next), @@curSy);
@@gen.print("WeakSeparator(" + n2.p1 + "," + NewCondSet(s1) + ","
+ NewCondSet(s2) + ") ");
s1 = new BitSet(); # for inner structure
if (n2.next > 0) p2 = n2.next;
 else p2 = 0;
} else {
p2 = n.p1;
 s1 = Tab.First(p2);
GenCond(s1);
}
@@gen.println(")");
GenCode(p2, indent + 1, s1);
Indent(indent);
 @@gen.println("end");
break;
}
when Tab.opt:
s1 = Tab.First(n.p1);
if (!checked.equals(s1)) {
Indent(indent);
@@gen.print("if (");
GenCond(s1);
 @@gen.println(") then");
GenCode(n.p1, indent+1, s1);
Indent(indent);
 @@gen.println("end");
} else
GenCode(n.p1, indent, checked);
break;
}
if (n.typ!=Tab.eps && n.typ!=Tab.sem && n.typ!=Tab.sync) checked = new BitSet();
p = n.next;
}
}

}
