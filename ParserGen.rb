
class String
  alias :append :<<
end

class IO
  alias :println :puts
end

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
  @@errorNr = 0		# highest parser error number
  @@curSy = 0		# symbol whose production is currently generated
  @@fram = nil		# parser frame file
  @@gen = nil		# generated parser source file
  @@err = nil		# generated parser error messages
  @@srcName = ""	# name of attribute grammar file
  @@srcDir = ""		# directory of attribute grammar file
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
	  @@gen.print(stop[0..i])
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
      Scanner.err.Exception("-- error reading Parser.frame")
    end
  end

  def self.CopySourcePart(pos, indent)
    # Copy text described by pos from atg to @@gen
    ch = nChars = i = 0

    unless (pos.nil?) then
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
    name = Tab.Sym(errSym).name.gsub('"', '\'')
    @@err.append("\t\t\twhen #{@@errorNr}; s = \"")

    case errTyp
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
    elsif (n <= MaxTerm) then
      for i in 0..Tab.maxT do
	if (s.get(i)) then
	  @@gen.print("@t.kind==" + i.to_s)
	  n -= 1
	  if (n > 0) then
	    @@gen.print(" || ")
	  end
	end
      end
    else
      @@gen.print("StartOf(" + NewCondSet(s).to_s + ")")
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
    n = n2 = s1 = s2 = sym = nil
    alts = p2 = 0
    equal = false

    while (p > 0) do
      n = Tab.Node(p);
      case (n.typ)
      when Tab::Nt then
	Indent(indent);
	sym = Tab.Sym(n.p1);
	if (n.retVar!=nil) then
	  @@gen.print(n.retVar + " = ");
	end
	@@gen.print(sym.name + "(");
	CopySourcePart(n.pos, 0);
	@@gen.println(")");
      when Tab::T then
	Indent(indent);
	if (checked.get(n.p1)) then
	  @@gen.println("Get()");
	else
	  @@gen.println("Expect(" + n.p1.to_s + ")");
	end
      when Tab::Wt then
	Indent(indent);
	s1 = Tab.Expected(n.next.abs, @@curSy);
	s1.or(Tab.Set(0));
	@@gen.println("ExpectWeak(" + n.p1.to_s + ", " + NewCondSet(s1).to_s + ")");
      when Tab::Any then
	Indent(indent);
	@@gen.println("Get()");
      when Tab::Eps then
	# nothing
      when Tab::Sem then
	CopySourcePart(n.pos, indent);
      when Tab::Sync then
	Indent(indent);
	GenErrorMsg(SyncErr, @@curSy);
	s1 = Tab.Set(n.p1).clone();
	@@gen.print("while (!(");
	GenCond(s1);
	@@gen.println(")); Error(" + @@errorNr.to_s + "); Get(); end");
      when Tab::Alt then
	s1 = Tab.First(p);
	equal = s1 == checked;
	alts = Alternatives(p);
	if (alts > 5) then
	  Indent(indent);
	  @@gen.println("case (@t.kind)");
	end
	p2 = p;
	while (p2 != 0) do
	  n2 = Tab.Node(p2);
	  s1 = Tab.Expected(n2.p1, @@curSy);
	  Indent(indent);

	  if (alts > 5) then
	    PutCaseLabels(s1);
	    @@gen.println();
	  elsif (p2==p) then
	    @@gen.print("if (");
	    GenCond(s1);
	    @@gen.println(") then");
	  elsif (n2.p2==0 && equal) then
	    @@gen.println("else");
	  else
	    @@gen.print("elsif (");
	    GenCond(s1);
	    @@gen.println(") then");
	  end

	  s1.or(checked);
	  GenCode(n2.p1, indent + 1, s1);

	  p2 = n2.p2;
	end

	Indent(indent);

	if (equal) then
	  @@gen.println("end");
	else 
	  GenErrorMsg(AltErr, @@curSy);
	  if (alts > 5) then
	    @@gen.println("else");
	    @@gen.println("  Error(" + @@errorNr.to_s + ")");
	    Indent(indent);
	    @@gen.println("end");
	  else
	    @@gen.println("else Error(" + @@errorNr.to_s + ")");
	    @@gen.println("end");
	  end
	end
      when Tab::Iter then
	Indent(indent);
	n2 = Tab.Node(n.p1);
	@@gen.print("while (");
	if (n2.typ==Tab::Wt) 
	  s1 = Tab.Expected(n2.next.abs, @@curSy);
	  s2 = Tab.Expected(n.next.abs, @@curSy);
	  @@gen.print("WeakSeparator(" + n2.p1.to_s + "," + NewCondSet(s1).to_s + "," + NewCondSet(s2).to_s + ") ");
	  s1 = BitSet.new # for inner structure
	  if (n2.next > 0) then
	    p2 = n2.next;
	  else
	    p2 = 0;
	  end
	else
	  p2 = n.p1;
	  s1 = Tab.First(p2);
	  GenCond(s1);
	end
	@@gen.println(")");
	GenCode(p2, indent + 1, s1);
	Indent(indent);
	@@gen.println("end");
      when Tab::Opt then
	s1 = Tab.First(n.p1);
	if (checked != s1) then
	  Indent(indent);
	  @@gen.print("if (");
	  GenCond(s1);
	  @@gen.println(") then");
	  GenCode(n.p1, indent+1, s1);
	  Indent(indent);
	  @@gen.println("end");
	else
	  GenCode(n.p1, indent, checked);
	end
      end

      if (n.typ!=Tab::Eps && n.typ!=Tab::Sem && n.typ!=Tab::Sync) then
	checked = BitSet.new;
      end

      p = n.next;

    end # while loop?
  end

  def self.GenCodePragmas
    for i in Tab.maxT+1..Tab.maxP do
      @@gen.println("\t\tif (@t.kind==" + i.to_s + ") then")
      CopySourcePart(Tab.Sym(i).semPos, 3)
      @@gen.println("\t\tend")
    end
  end

  def self.GenProductions
    sym = nil
    for @@curSy in Tab.firstNt..Tab.lastNt do
      sym = Tab.Sym(@@curSy)
      @@gen.print("\tprivate; ")
      # if (sym.retType==nil) @@gen.print("void ")
      # else @@gen.print(sym.retType + " ")
      @@gen.print("def self.")
      @@gen.print(sym.name + "(")

      if (sym.attrPos != nil) then
	args = GetString(sym.attrPos.beg, sym.attrPos.beg + sym.attrPos.len)
	args = args.split(/\s*,\s*/)
	args.each do | arg |
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
      # if (sym.retVar!=nil)
      #   @@gen.println("\t\t" + sym.retType + " " + sym.retVar)
      # HACK @@gen.println("\t\t$std@@err.puts(\"+ " + sym.name + "\")")

      CopySourcePart(sym.semPos, 2)
      GenCode(sym.struct, 2, BitSet.new)

      # HACK @@gen.println("\t\t$std@@err.puts(\"- " + sym.name + "\")")

      @@gen.println("\t\treturn " + sym.retVar) if (sym.retVar!=nil)
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
      @@fram = File.new(@@srcDir + "/Parser.frame")
    rescue
      Scanner.err.Exception("-- 1 cannot open Parser.frame. Must be in the same directory as the grammar file.")
    end

    begin
      @@gen = File.new(@@srcDir + "/Parser.rb", "w")
    rescue
      Scanner.err.Exception("-- cannot generate parser file")
    end

    @@err = ""

    for i in 0..Tab.maxT do
      GenErrorMsg(TErr, i);
    end

    @@gen.println("# This file is @@generated. DO NOT MODIFY!");
    @@gen.println();
    # @@gen.println("class " + root.name); # HACK
    CopyFramePart("-->constants");
    @@gen.println("\tprivate; MaxT = " + Tab.maxT.to_s); # TODO: const case them
    @@gen.println("\tprivate; MaxP = " + Tab.maxP.to_s);
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
      @@gen = File.new(@@srcDir + "/ErrorStream.rb", "w");
    rescue
      Scanner.err.Exception("-- cannot generate error stream file");
    end
    @@gen.println("# This file is @@generated. DO NOT MODIFY!");
    @@gen.println();
    # @@gen.println("class " + root.name); # HACK
    CopyFramePart("-->errors");
    @@gen.print(@@err)
    CopyFramePart("$$$");
    @@gen.close();
  end

  def self.WriteStatistics
    Trace.println((Tab.maxT+1) + " terminals");
    Trace.println("#{Tab.maxSymbols - Tab.firstNt + Tab.maxT + 1} symbols")
    Trace.println(Tab.nNodes + " nodes");
    Trace.println(@@maxSS + " sets");
  end

end
