# This file is generated. DO NOT MODIFY!


require 'Sets'
require 'module-hack'

class Parser
	private; MaxT = 38

	private; T = true
	private; X = false
	
	@token=nil			# last recognized token
	@t=nil				# lookahead token

	private; @@ident = 0
	private; @@string = 1
	private; @@genScanner = nil

	private; def Parser.SemErr(n)
		Scanner.err.SemErr(n, @t.line, @t.col)
	end
	
	private; def Parser.MatchLiteral(sym) # store string either as token or as literal
		sym2 = DFA.MatchedDFA(sym.name, sym)
		if (sym2.nil?)
		  sym.graph = Sym::ClassToken
		else 
		  sym2.graph = Sym::ClassLitToken
		  sym.graph = Sym::LitToken
		end
	end
	
	private; def Parser.SetCtx(p) # set transition code to contextTrans
		until (p.nil?)
			# TODO: make a case statement or refactor better
			if (p.typ==Node::Chr || p.typ==Node::Clas) then
				p.code = Node::ContextTrans
			elsif (p.typ==Node::Opt || p.typ==Node::Iter) then
				SetCtx(p.sub)
			elsif (p.typ==Node::Alt) then
				SetCtx(p.sub)
				SetCtx(p.down)
			end
			break if p.up
			p = p.nxt
		end
	end
	
	private; def Parser.SetDDT(s)
		for i in 1..(s.length-1)
		  ch = s[i]
		  if (ch >= ?0 && ch <= ?9) then
		    Tab.ddt[ch - ?0] = true
		  end
		end
	end
	
	private; def Parser.FixString(s)
		a=s # TODO: remove a
		len = a.length
		if (len == 2) then
		  SemErr(29)
		end
		dbl = false
		for i in 1..(len-1)
		  if (a[i]=='"') then
		    dbl = true
		  elsif (a[i]==' ') then
		    SemErr(24)
		  end
		end
		if (!dbl) then
		  a[0] = '"'
		  a[len-1] = '"'
		end

		return a.clone
	end
	
# -------------------------------------------------------------------------



	private; def Parser.Error(n)
		Scanner.err.ParsErr(n, @t.line, @t.col)
	end
	
	private; def Parser.Get
		while true
			@token = @t
			@t = Scanner.Scan
			return if (@t.kind<=MaxT)
		if (@t.kind==39) then
			SetDDT(@t.val) 
		end

			@t = @token
		end
	end
	
	private; def Parser.Expect(n)
		if (@t.kind==n) then
		  Get()
		else
		  Error(n)
		end
	end
	
	private; def Parser.StartOf(s)
		return @@set[s][@t.kind]
	end
	
	private; def Parser.ExpectWeak(n, follow)
		if (@t.kind == n)
		  Get()
		else
		  Error(n);
		  while (!StartOf(follow))
		    Get();
		  end
		end
	end
	
	private; def Parser.WeakSeparator(n, syFol, repFol)
		s = []
		if (@t.kind==n) then
		  Get()
		  return true
		elsif (StartOf(repFol))
		  return false
		else
			for i in 0..MaxT
				s[i] = @@set[syFol][i] || @@set[repFol][i] || @@set[0][i]
			end
			Error(n)
			while (!s[@t.kind])
			  Get()
			end
			return StartOf(syFol)
		end
	end
	
	private; def self.AttrRest(n)
		beg = col = 0 
		beg = @t.pos
				   col = @t.col
				 
		while (StartOf(1))
			Get()
		end
		Expect(27)
		if (@token.pos > beg) then
                                     n.pos = Position.new(beg, @token.pos - beg, col)
                                   end
				
	end

	private; def self.TokenFactor()
		name = s = nil
				   kind = c = 0
				 
		g = Graph.new 
		if (@t.kind==1 || @t.kind==2) then
			name, kind = self.Symbol()
			if (kind==@@ident) then
                                     c = CharClass.ClassWithName(name)
                                     if (c < 0) then
                                       SemErr(15)
                                       c = CharClass.NewClass(name, BitSet.new())
                                     end
                                     g.l = Node.new(Node::Clas, c, 0)
                                     g.r = g.l
                                   else # string
				     g = Graph.StrToGraph(name)
				   end
				
		elsif (@t.kind==21) then
			Get()
			g = self.TokenExpr()
			Expect(22)
		elsif (@t.kind==30) then
			Get()
			g = self.TokenExpr()
			Expect(31)
			g = Graph.Option(g) 
		elsif (@t.kind==32) then
			Get()
			g = self.TokenExpr()
			Expect(33)
			g = Graph.Iteration(g) 
		else Error(39)
end
		return g
	end

	private; def self.TokenTerm()
		g2 = nil 
		g = self.TokenFactor()
		while (StartOf(2))
			g2 = self.TokenFactor()
			g = Graph.Sequence(g, g2) 
		end
		if (@t.kind==35) then
			Get()
			Expect(21)
			g2 = self.TokenExpr()
			SetCtx(g2.l)
				   g = Graph.Sequence(g, g2)
				 
			Expect(22)
		end
		return g
	end

	private; def self.Attribs(n)
		beg = col = 0; buf = [] 
		Expect(24)
		if (@t.kind==25) then
			Get()
			beg = @t.pos 
			while (StartOf(3))
				Get()
			end
			buf << ParserGen.GetString(beg, @t.pos) 
			while (@t.kind==26)
				Get()
				Expect(25)
				beg = @t.pos 
				while (StartOf(3))
					Get()
				end
				buf << ParserGen.GetString(beg, @t.pos) 
			end
			if (@t.kind==26) then
				Get()
				self.AttrRest(n)
			elsif (@t.kind==27) then
				Get()
			else Error(40)
end
			n.retVar = buf.join(', ') if ! buf.empty? 
		elsif (StartOf(4)) then
			self.AttrRest(n)
		else Error(41)
end
	end

	private; def self.Factor()
		n = s = sym = pos = set = nil
				   sp = typ = 0
				   undefined = weak = false
				 
		g = Graph.new()
				   weak = false
				 
		case (@t.kind)
		when 1, 2, 29 then

			if (@t.kind==29) then
				Get()
				weak = true 
			end
			name, kind = self.Symbol()
			sp = Sym.FindSym(name)
				   undefined = sp==Sym::NoSym
                                   if (undefined) then
                                       if (kind==@@ident) then
                                           sp = Sym.new(Node::Nt, name, 0) # forward nt
                                       elsif (@@genScanner) then
                                           sp = Sym.new(Node::T, name, @token.line)
                                           MatchLiteral(sp)
                                       else # undefined string in production
                                           SemErr(6) 
					   sp = nil
                                       end
                                   end
				   sym = sp # FIX
				   typ = sym.typ
                                   if (typ!=Node::T && typ!=Node::Nt) then
				     SemErr(4)
				   end
                                   if (weak) then
                                       if (sym.typ==Node::T) then
				         typ = Node::Wt
				       else
				         SemErr(23)
				       end
				   end
                                   g.l = Node.new(typ, sp, @token.line)
				   g.r = g.l
                                   n = g.l
				 
			if (@t.kind==24) then
				self.Attribs(n)
				if (kind!=@@ident) then
    	    			     SemErr(3)
				   end
				 
			end
			if (undefined) then
                                     sym.attrPos = n.pos
				     sym.retVar  = n.retVar # dummies
                                   else
                                     if ((!n.pos.nil?    &&  sym.attrPos.nil?) ||
				         (!n.retVar.nil? &&  sym.retVar.nil?) ||
					 ( n.pos.nil?    && !sym.attrPos.nil?) ||
					 ( n.retVar.nil? && !sym.retVar.nil?)) then
					 STDERR.puts "Attribs"
				       SemErr(5)
				     end
                                   end
				 
		when 21 then

			Get()
			g = self.Expression()
			Expect(22)
		when 30 then

			Get()
			g = self.Expression()
			Expect(31)
			g = Graph.Option(g) 
		when 32 then

			Get()
			g = self.Expression()
			Expect(33)
			g = Graph.Iteration(g) 
		when 36 then

			pos = self.SemText()
			g.l = Node.new(Node::Sem, 0, 0)
                                   g.r = g.l
                                   n = g.l
				   n.pos = pos
				 
		when 23 then

			Get()
			set = Sets.FullSet(Tab::MaxTerminals)
                                   set.clear(Sym::EofSy)
                                   g.l = Node.new(Node::Any, Tab.NewSet(set), 0)
                                   g.r = g.l
				 
		when 34 then

			Get()
			g.l = Node.new(Node::Sync, 0, 0)
                                   g.r = g.l
				 
		else
  Error(42)
		end
		return g
	end

	private; def self.Term()
		g2 = nil 
		g = nil 
		if (StartOf(5)) then
			g = self.Factor()
			while (StartOf(5))
				g2 = self.Factor()
				g = Graph.Sequence(g, g2) 
			end
		elsif (StartOf(6)) then
			g = Graph.new()
                                   g.l = Node.new(Node::Eps, 0, 0)
                                   g.r = g.l
				 
		else Error(43)
end
		return g
	end

	private; def self.Symbol()
		name = "???"
				   kind = @@ident
				 
		if (@t.kind==1) then
			Get()
			name = @token.val 
		elsif (@t.kind==2) then
			Get()
			name = FixString(@token.val)
    				   kind = @@string
				 
		else Error(44)
end
		return name, kind
	end

	private; def self.SimSet()
		name = ""
				   c = n = 0
				
		s = BitSet.new(128) 
		if (@t.kind==1) then
			Get()
			c = CharClass.ClassWithName(@token.val)
                                   if (c < 0) then
				     SemErr(15)
				   else
				     s.or(CharClass.Class(c))
				   end
				
		elsif (@t.kind==2) then
			Get()
			name = @token.val
				   i=1
                                   while (name[i] != name[0]) do
                                     s.set(name[i])
				     i += 1
				   end
				
		elsif (@t.kind==20) then
			Get()
			Expect(21)
			Expect(3)
			n = @token.val.to_i
                                   s.set(n)
				
			Expect(22)
		elsif (@t.kind==23) then
			Get()
			s = Sets.FullSet(127) 
		else Error(45)
end
		return s
	end

	private; def self.Set()
		s2 = nil 
		s = self.SimSet()
		while (@t.kind==18 || @t.kind==19)
			if (@t.kind==18) then
				Get()
				s2 = self.SimSet()
				s.or(s2) 
			else
				Get()
				s2 = self.SimSet()
				Sets.Differ(s, s2) 
			end
		end
		return s
	end

	private; def self.TokenExpr()
		g2 = nil
				   first = false
				 
		g = self.TokenTerm()
		first = true 
		while (WeakSeparator(28,2,7) )
			g2 = self.TokenTerm()
			if (first) then
				     g = Graph.FirstAlt(g)
				     first = false
				   end
                                   g = Graph.Alternative(g, g2)
				 
		end
		return g
	end

	private; def self.TokenDecl(typ)
		s = pos = g = nil
				   sp = 0
				 
		name, kind = self.Symbol()
		if (Sym.FindSym(name) != Sym::NoSym) then
				     SemErr(7)
				     sp = 0
                                   else
                                     sp = Sym.new(typ, name, @token.line)
                                     sp.graph = Sym::ClassToken
                                   end
				 
		while (!(StartOf(8))); Error(46); Get(); end
		if (@t.kind==7) then
			Get()
			g = self.TokenExpr()
			Expect(8)
			if (kind != @@ident) then
				     SemErr(13)
				   end
                                   Graph.CompleteGraph(g.r)
                                   DFA.ConvertToStates(g.l, sp)
				 
		elsif (StartOf(9)) then
			if (kind==@@ident) then
				     @@genScanner = false
                                   else
				     MatchLiteral(sp)
				   end
				
		else Error(47)
end
		if (@t.kind==36) then
			pos = self.SemText()
			if (typ==Node::T) then
				     SemErr(14)
				   end
                                   sp.semPos = pos
				 
		end
	end

	private; def self.SetDecl()
		c = 0
				   s = nil
				   name = ""
				
		Expect(1)
		name = @token.val
                                   c = CharClass.ClassWithName(name)
                                   if (c > 0) then
				     SemErr(7)
				   end
				
		Expect(7)
		s = self.Set()
		c = CharClass.NewClass(name, s) 
		Expect(8)
	end

	private; def self.Expression()
		g2 = nil
	   	   		   first = false
				 
		g = self.Term()
		first = true 
		while (WeakSeparator(28,10,11) )
			g2 = self.Term()
			if (first) then
				     g = Graph.FirstAlt(g)
				     first = false
				   end
                                   g = Graph.Alternative(g, g2)
				 
		end
		return g
	end

	private; def self.SemText()
		Expect(36)
		beg = @t.pos
				   col = @t.col
				 
		while (StartOf(12))
			if (StartOf(13)) then
				Get()
			elsif (@t.kind==4) then
				Get()
				SemErr(18) 
			else
				Get()
				SemErr(19) 
			end
		end
		Expect(37)
		pos = Position.new(beg, @token.pos - beg, col)
  				 
		return pos
	end

	private; def self.AttrDecl(sym)
		beg = col = 0
				   buf = nil
				   buf2 = []
				 
		Expect(24)
		while (@t.kind==25)
			Get()
			Expect(1)
			buf = @token.val.clone 
			Expect(1)
			buf2 << @token.val.dup
    				   sym.retType = buf.to_s
				 
			if (@t.kind==26) then
				Get()
			end
		end
		sym.retVar = buf2.join(', ') unless buf2.empty?
  				   beg = @t.pos
  				   col = @t.col
				 
		while (StartOf(1))
			Get()
		end
		Expect(27)
		if (@token.pos > beg) then
                                     sym.attrPos = Position.new(beg, @token.pos - beg, col)
                                   end
				 
	end

	private; def self.Declaration()
		g1 = g2 = nil
				   nested = false
				
		if (@t.kind==10) then
			Get()
			while (@t.kind==1)
				self.SetDecl()
			end
		elsif (@t.kind==11) then
			Get()
			while (@t.kind==1 || @t.kind==2)
				self.TokenDecl(Node::T)
			end
		elsif (@t.kind==12) then
			Get()
			while (@t.kind==1 || @t.kind==2)
				self.TokenDecl(Node::Pr)
			end
		elsif (@t.kind==13) then
			Get()
			Expect(14)
			g1 = self.TokenExpr()
			Expect(15)
			g2 = self.TokenExpr()
			if (@t.kind==16) then
				Get()
				nested = true 
			elsif (StartOf(14)) then
				nested = false 
			else Error(48)
end
			Comment.new(g1.l, g2.l, nested) 
		elsif (@t.kind==17) then
			Get()
			Tab.ignored = self.Set()
		else Error(49)
end
	end

	private; def self.Coco()
		gramLine = sp = eofSy = 0
                                   undefined = noAttrs = noRet = ok = ok1 = false
                                   gramName = ""
                                   sym = nil
                                   g = nil
				
		Expect(5)
		gramLine = @token.line
                                   eofSy = Sym.new(Node::T, "EOF", 0)
                                   @@genScanner = true
                                   ok = true
                                   Tab.ignored = BitSet.new()
				
		Expect(1)
		gramName = @token.val
                                   beg = @t.pos
				
		while (StartOf(15))
			Get()
		end
		Tab.semDeclPos = Position.new(beg, @t.pos-beg, 0)
				
		while (StartOf(16))
			self.Declaration()
		end
		while (!(@t.kind==0 || @t.kind==6)); Error(50); Get(); end
		Expect(6)
		Tab.ignored.set(32)	#' ' is always ignored
                                   if (@@genScanner) then
					ok = DFA.MakeDeterministic()
				   end
                                   Node.EraseNodes
				
		while (@t.kind==1)
			Get()
			sym = Sym.FindSym(@token.val)
                                   undefined = sym == Sym::NoSym
                                   if (undefined) then
                                       sym = Sym.new(Node::Nt, @token.val, @token.line)
                                   else 
                                       if (sym.typ==Node::Nt) then
					    if !sym.graph.nil? then
						SemErr(7)
					   end
                                       else
					 SemErr(8)
				       end
                                       sym.line = @token.line
                                   end
                                   noAttrs = sym.attrPos.nil?
				   sym.attrPos = nil
                                   noRet = sym.retVar.nil? || sym.retVar.empty?
				   sym.retVar = nil
				
			if (@t.kind==24) then
				self.AttrDecl(sym)
			end
			if (!undefined) then
                                     if ((noAttrs  && !sym.attrPos.nil?) || 
				         (noRet    && !sym.retVar.nil?) || 
					 (!noAttrs && sym.attrPos.nil?) || 
					 (!noRet   && sym.retVar .nil?)) then
					 STDERR.puts "AttrDecl #{noAttrs}, #{noRet} #{sym.attrPos.inspect} #{sym.retVar.inspect}"

                                     	 STDERR.puts "1" if (noAttrs  && !sym.attrPos.nil?)
					 STDERR.puts "2" if (noRet    && !sym.retVar.nil?)
					 STDERR.puts "3" if (!noAttrs && sym.attrPos.nil?)
					 STDERR.puts "4" if (!noRet   && sym.retVar .nil?)
				       SemErr(5)
				     end
				   end
                                   
			if (@t.kind==36) then
				sym.semPos = self.SemText()
			end
			ExpectWeak(7, 17)
			g = self.Expression()
			sym.graph = g.l
                                   Graph.CompleteGraph(g.r)
				
			ExpectWeak(8, 18)
		end
		if (Tab.ddt[2]) then
				     Node.PrintGraph()
				   end
                                   Tab.gramSy = Sym.FindSym(gramName)
                                   if (Tab.gramSy==Sym::NoSym) then
				       SemErr(11)
                                   else
                                       sym = Tab.gramSy
                                       unless (sym.attrPos.nil?) then
				         SemErr(12)
				       end
                                   end
				
		Expect(9)
		Expect(1)
		if (gramName != @token.val) then
					 SemErr(17)
				   end
                                   if (Scanner.err.count == 0) then
                                       puts("checking"); STDOUT.flush
                                       Tab.CompSymbolSets()
                                       if (ok) then
					 ok = Tab.NtsComplete()
				       end
                                       if (ok) then
                                           ok1 = Tab.AllNtReached()
                                           ok = Tab.NoCircularProductions()
                                       end
                                       if (ok) then
					 ok = Tab.AllNtToTerm()
				       end
                                       if (ok) then
					 ok1 = Tab.LL1()
				       end
                                       if (Tab.ddt[7]) then
					 Tab.XRef()
				       end
                                       if (ok) then
                                           print("parser"); STDOUT.flush()
                                           ParserGen.WriteParser()
                                           if (@@genScanner) then
                                               print(" + scanner"); STDOUT.flush()
                                               ok = DFA.WriteScanner()
                                               if (Tab.ddt[0]) then
					         DFA.PrintStates()
					       end
                                           end
                                           puts(" generated"); STDOUT.flush
                                           if (Tab.ddt[8]) then
					     ParserGen.WriteStatistics()
					   end
                                       end
                                   else
				     ok = false
				   end
                                   if (Tab.ddt[6]) then
					Tab.PrintSymbolTable()
				   end
                                   puts
				
		Expect(8)
	end



	def Parser.Parse()
		@t = Token.new();
		Get();
		Coco()

	end

	@@set = [
	[T,T,T,X, X,X,T,T, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, T,X,X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,X, T,T,T,T, T,T,T,T, T,T,T,X],
	[X,T,T,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,T,X,X, X,X,X,X, X,X,T,X, T,X,X,X, X,X,X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,X,X, T,T,T,T, T,T,T,T, T,T,T,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,X],
	[X,T,T,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,T,X,T, X,X,X,X, X,T,T,X, T,X,T,X, T,X,X,X],
	[X,X,X,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X,X,X, T,X,X,T, X,T,X,X, X,X,X,X],
	[X,X,X,X, X,X,T,X, T,X,T,T, T,T,X,T, T,T,X,X, X,X,T,X, X,X,X,X, X,X,X,T, X,T,X,X, X,X,X,X],
	[T,T,T,X, X,X,T,T, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, T,X,X,X],
	[X,T,T,X, X,X,T,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, T,X,X,X],
	[X,T,T,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,T,T,T, X,X,X,X, T,T,T,T, T,T,T,X, T,X,X,X],
	[X,X,X,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X,X,X, X,X,X,T, X,T,X,X, X,X,X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,X,T,X],
	[X,T,T,T, X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, X,X,T,X],
	[X,X,X,X, X,X,T,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X],
	[X,T,T,T, T,T,X,T, T,T,X,X, X,X,T,T, T,X,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,X],
	[X,X,X,X, X,X,X,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X],
	[T,T,T,X, X,X,T,T, T,X,T,T, T,T,X,X, X,T,X,X, X,T,X,T, X,X,X,X, T,T,T,X, T,X,T,X, T,X,X,X],
	[T,T,T,X, X,X,T,T, X,T,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, T,X,X,X],
	]
end

