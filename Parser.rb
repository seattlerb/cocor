# This file is generated. DO NOT MODIFY!


require 'Sets'
require 'module-hack'

class Parser
	private; MaxT = 40
	private; MaxP = 41

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
	
	private; def Parser.MatchLiteral(sp) # store string either as token or as literal
		sym = Sym.Sym(sp)
		matchedSp = DFA.MatchedDFA(sym.name, sp)
		if (matchedSp==Tab::NoSym)
		  sym.struct = Tab::ClassToken
		else 
		  sym1 = Sym.Sym(matchedSp)
		  sym1.struct = Tab::ClassLitToken
		  sym.struct = Tab::LitToken
		end
	end
	
	private; def Parser.SetCtx(p) # set transition code to contextTrans
		while (p > 0)
			n = GraphNode.Node(p)
			if (n.typ==Tab::Chr || n.typ==Tab::Clas) then
				n.p2 = Tab::ContextTrans
			elsif (n.typ==Tab::Opt || n.typ==Tab::Iter) then
				SetCtx(n.p1)
			elsif (n.typ==Tab::Alt) then
				SetCtx(n.p1)
				SetCtx(n.p2)
			end
			p = n.next
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
		if (@t.kind==41) then
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
	
	private; def self.AttrRest1(n)
		beg = col = 0 
		beg = @t.pos
				   col = @t.col
				 
		while (StartOf(1))
			Get()
		end
		Expect(31)
		if (@token.pos > beg) then
                                     n.pos = Position.new()
                                     n.pos.beg = beg
				     n.pos.col = col
                                     n.pos.len = @token.pos - beg
                                   end
				 
	end

	private; def self.AttrRest(n)
		beg = col = 0 
		beg = @t.pos
				   col = @t.col
				 
		while (StartOf(2))
			Get()
		end
		Expect(29)
		if (@token.pos > beg) then
                                     n.pos = Position.new()
                                     n.pos.beg = beg
				     n.pos.col = col
                                     n.pos.len = @token.pos - beg
                                   end
				
	end

	private; def self.TokenFactor()
		name = s = nil
				   kind = c = 0
				 
		g = Graph.new 
		if (@t.kind==1 || @t.kind==2) then
			s = self.Symbol()
			if (s.kind==@@ident) then
                                     c = CharClass.ClassWithName(s.name)
                                     if (c < 0) then
                                       SemErr(15)
                                       c = CharClass.NewClass(s.name, BitSet.new())
                                     end
                                     g.l = GraphNode.NewNode(Tab::Clas, c, 0)
                                     g.r = g.l
                                   else # string
				     g = Graph.StrToGraph(s.name)
				   end
				
		elsif (@t.kind==21) then
			Get()
			g = self.TokenExpr()
			Expect(22)
		elsif (@t.kind==26) then
			Get()
			g = self.TokenExpr()
			Expect(27)
			g = Graph.Option(g) 
		elsif (@t.kind==34) then
			Get()
			g = self.TokenExpr()
			Expect(35)
			g = Graph.Iteration(g) 
		else Error(41)
end
		return g
	end

	private; def self.TokenTerm()
		g2 = nil 
		g = self.TokenFactor()
		while (StartOf(3))
			g2 = self.TokenFactor()
			g = Graph.Sequence(g, g2) 
		end
		if (@t.kind==37) then
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
		beg = col = 0 
		if (@t.kind==24) then
			Get()
			if (@t.kind==25) then
				Get()
				beg = @t.pos 
				while (StartOf(4))
					Get()
				end
				n.retVar = ParserGen.GetString(beg, @t.pos)
				 
				if (@t.kind==28) then
					Get()
					self.AttrRest(n)
				elsif (@t.kind==29) then
					Get()
				else Error(42)
end
			elsif (StartOf(5)) then
				self.AttrRest(n)
			else Error(43)
end
		elsif (@t.kind==30) then
			Get()
			if (@t.kind==25) then
				Get()
				beg = @t.pos 
				while (StartOf(6))
					Get()
				end
				n.retVar = ParserGen.GetString(beg, @t.pos)
				 
				if (@t.kind==28) then
					Get()
					self.AttrRest1(n)
				elsif (@t.kind==31) then
					Get()
				else Error(44)
end
			elsif (StartOf(5)) then
				self.AttrRest1(n)
			else Error(45)
end
		else Error(46)
end
	end

	private; def self.Factor()
		n = s = sym = pos = set = nil
				   sp = typ = 0
				   undefined = weak = false
				 
		g = Graph.new()
				   weak = false
				 
		case (@t.kind)
		when 1, 2, 33 then

			if (@t.kind==33) then
				Get()
				weak = true 
			end
			s = self.Symbol()
			sp = Sym.FindSym(s.name)
				   undefined = sp==Tab::NoSym
                                   if (undefined) then
                                       if (s.kind==@@ident) then
                                           sp = Sym.NewSym(Tab::Nt, s.name, 0) # forward nt
                                       elsif (@@genScanner) then
                                           sp = Sym.NewSym(Tab::T, s.name, @token.line)
                                           MatchLiteral(sp)
                                       else # undefined string in production
                                           SemErr(6) 
					   sp = 0
                                       end
                                   end
                                   sym = Sym.Sym(sp)
				   typ = sym.typ
                                   if (typ!=Tab::T && typ!=Tab::Nt) then
				     SemErr(4)
				   end
                                   if (weak) then
                                       if (sym.typ==Tab::T) then
				         typ = Tab::Wt
				       else
				         SemErr(23)
				       end
				   end
                                   g.l = GraphNode.NewNode(typ, sp, @token.line)
				   g.r = g.l
                                   n = GraphNode.Node(g.l)
				 
			if (@t.kind==24 || @t.kind==30) then
				self.Attribs(n)
				if (s.kind!=@@ident) then
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
				       SemErr(5)
				     end
                                   end
				 
		when 21 then

			Get()
			g = self.Expression()
			Expect(22)
		when 26 then

			Get()
			g = self.Expression()
			Expect(27)
			g = Graph.Option(g) 
		when 34 then

			Get()
			g = self.Expression()
			Expect(35)
			g = Graph.Iteration(g) 
		when 38 then

			pos = self.SemText()
			g.l = GraphNode.NewNode(Tab::Sem, 0, 0)
                                   g.r = g.l
                                   n = GraphNode.Node(g.l)
				   n.pos = pos
				 
		when 23 then

			Get()
			set = Sets.FullSet(Tab::MaxTerminals)
                                   set.clear(Tab::EofSy)
                                   g.l = GraphNode.NewNode(Tab::Any, Tab.NewSet(set), 0)
                                   g.r = g.l
				 
		when 36 then

			Get()
			g.l = GraphNode.NewNode(Tab::Sync, 0, 0)
                                   g.r = g.l
				 
		else
  Error(47)
		end
		return g
	end

	private; def self.Term()
		g2 = nil 
		g = nil 
		if (StartOf(7)) then
			g = self.Factor()
			while (StartOf(7))
				g2 = self.Factor()
				g = Graph.Sequence(g, g2) 
			end
		elsif (StartOf(8)) then
			g = Graph.new()
                                   g.l = GraphNode.NewNode(Tab::Eps, 0, 0)
                                   g.r = g.l
				 
		else Error(48)
end
		return g
	end

	private; def self.Symbol()
		s = SymInfo.new() 
		if (@t.kind==1) then
			Get()
			s.kind = @@ident
				   s.name = @token.val
				 
		elsif (@t.kind==2) then
			Get()
			s.kind = @@string
				   s.name = FixString(@token.val)
				 
		else Error(49)
end
		return s
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
		else Error(50)
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
		while (WeakSeparator(32,3,9) )
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
				 
		s = self.Symbol()
		if (Sym.FindSym(s.name) != Tab::NoSym) then
				     SemErr(7)
				     sp = 0
                                   else
                                     sp = Sym.NewSym(typ, s.name, @token.line)
                                     Sym.Sym(sp).struct = Tab::ClassToken
                                   end
				 
		while (!(StartOf(10))); Error(51); Get(); end
		if (@t.kind==7) then
			Get()
			g = self.TokenExpr()
			Expect(8)
			if (s.kind != @@ident) then
				     SemErr(13)
				   end
                                   Graph.CompleteGraph(g.r)
                                   DFA.ConvertToStates(g.l, sp)
				 
		elsif (StartOf(11)) then
			if (s.kind==@@ident) then
				     @@genScanner = false
                                   else
				     MatchLiteral(sp)
				   end
				
		else Error(52)
end
		if (@t.kind==38) then
			pos = self.SemText()
			if (typ==Tab::T) then
				     SemErr(14)
				   end
                                   Sym.Sym(sp).semPos = pos
				 
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
		while (WeakSeparator(32,12,13) )
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
		Expect(38)
		pos = Position.new()
                                   pos.beg = @t.pos
				   pos.col = @t.col
				 
		while (StartOf(14))
			if (StartOf(15)) then
				Get()
			elsif (@t.kind==4) then
				Get()
				SemErr(18) 
			else
				Get()
				SemErr(19) 
			end
		end
		Expect(39)
		pos.len = @token.pos - pos.beg 
		return pos
	end

	private; def self.AttrDecl(sym)
		beg = col = dim = 0
				   buf = nil
				 
		if (@t.kind==24) then
			Get()
			if (@t.kind==25) then
				Get()
				Expect(1)
				buf = @token.val.clone
    				   dim = 0
				 
				while (@t.kind==26)
					Get()
					Expect(27)
					dim += 1 
				end
				Expect(1)
				sym.retVar = @token.val 
				while (@t.kind==26)
					Get()
					Expect(27)
					dim += 1 
				end
				while (dim > 0) do
				     buf.append("[]")
				     dim -= 1
				   end
    				   sym.retType = buf.to_s
				 
				if (@t.kind==28) then
					Get()
				end
			end
			beg = @t.pos
  				   col = @t.col
				 
			while (StartOf(2))
				Get()
			end
			Expect(29)
			if (@token.pos > beg) then
                                     sym.attrPos = Position.new
                                     sym.attrPos.beg = beg
				     sym.attrPos.col = col
                                     sym.attrPos.len = @token.pos - beg
                                   end
				 
		elsif (@t.kind==30) then
			Get()
			if (@t.kind==25) then
				Get()
				Expect(1)
				buf = [ @token.val ]
    				   dim = 0
				 
				while (@t.kind==26)
					Get()
					Expect(27)
					dim += 1 
				end
				Expect(1)
				sym.retVar = @token.val 
				while (@t.kind==26)
					Get()
					Expect(27)
					dim += 1 
				end
				while (dim > 0) do
    				     buf << "[]"
				     dim -= 1
				   end
				   sym.retType = buf.join('')
				 
				if (@t.kind==28) then
					Get()
				end
			end
			beg = @t.pos
  				   col = @t.col
				 
			while (StartOf(1))
				Get()
			end
			Expect(31)
			if (@token.pos > beg) then
                                       sym.attrPos = Position.new()
                                       sym.attrPos.beg = beg
				       sym.attrPos.col = col
                                       sym.attrPos.len = @token.pos - beg
                                   end
				 
		else Error(53)
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
				self.TokenDecl(Tab::T)
			end
		elsif (@t.kind==12) then
			Get()
			while (@t.kind==1 || @t.kind==2)
				self.TokenDecl(Tab::Pr)
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
			elsif (StartOf(16)) then
				nested = false 
			else Error(54)
end
			Comment.new(g1.l, g2.l, nested) 
		elsif (@t.kind==17) then
			Get()
			Tab.ignored = self.Set()
		else Error(55)
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
                                   eofSy = Sym.NewSym(Tab::T, "EOF", 0)
                                   @@genScanner = true
                                   ok = true
                                   Tab.ignored = BitSet.new()
				
		Expect(1)
		gramName = @token.val
                                   Tab.semDeclPos = Position.new()
                                   Tab.semDeclPos.beg = @t.pos
				
		while (StartOf(17))
			Get()
		end
		Tab.semDeclPos.len = @t.pos - Tab.semDeclPos.beg
                                   Tab.semDeclPos.col = 0
				
		while (StartOf(18))
			self.Declaration()
		end
		while (!(@t.kind==0 || @t.kind==6)); Error(56); Get(); end
		Expect(6)
		Tab.ignored.set(32)	#' ' is always ignored
                                   if (@@genScanner) then
					ok = DFA.MakeDeterministic()
				   end
                                   Tab.nNodes = 0
				
		while (@t.kind==1)
			Get()
			sp = Sym.FindSym(@token.val)
                                   undefined = sp == Tab::NoSym
                                   if (undefined) then
                                       sp = Sym.NewSym(Tab::Nt, @token.val, @token.line)
                                       sym = Sym.Sym(sp)
                                   else 
                                       sym = Sym.Sym(sp)
                                       if (sym.typ==Tab::Nt) then
                                           if (sym.struct > 0) then
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
				
			if (@t.kind==24 || @t.kind==30) then
				self.AttrDecl(sym)
			end
			if (!undefined) then
                                     if ((noAttrs  && !sym.attrPos.nil?) || 
				         (noRet    && !sym.retVar.nil?) || 
					 (!noAttrs && sym.attrPos.nil?) || 
					 (!noRet   && sym.retVar .nil?)) then
				       SemErr(5)
				     end
				   end
                                   
			if (@t.kind==38) then
				sym.semPos = self.SemText()
			end
			ExpectWeak(7, 19)
			g = self.Expression()
			sym.struct = g.l
                                   Graph.CompleteGraph(g.r)
				
			ExpectWeak(8, 20)
		end
		if (Tab.ddt[2]) then
				     Graph.PrintGraph()
				   end
                                   Tab.gramSy = Sym.FindSym(gramName)
                                   if (Tab.gramSy==Tab::NoSym) then
				       SemErr(11)
                                   else
                                       sym = Sym.Sym(Tab.gramSy)
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
	[T,T,T,X, X,X,T,T, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,X, T,T,T,T, T,T,T,T, T,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,X,T,T, T,T,T,T, T,T,T,T, T,X],
	[X,T,T,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,T,X,X, X,X,T,X, X,X,X,X, X,X,T,X, X,X,X,X, X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, X,X,T,T, T,T,T,T, T,T,T,T, T,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, X,T,T,X, T,T,T,T, T,T,T,T, T,X],
	[X,T,T,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,T,X,T, X,X,T,X, X,X,X,X, X,T,T,X, T,X,T,X, X,X],
	[X,X,X,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X,X,T, X,X,X,X, T,X,X,T, X,X,X,X, X,X],
	[X,X,X,X, X,X,T,X, T,X,T,T, T,T,X,T, T,T,X,X, X,X,T,X, X,X,X,T, X,X,X,X, X,X,X,T, X,X,X,X, X,X],
	[T,T,T,X, X,X,T,T, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X],
	[X,T,T,X, X,X,T,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X],
	[X,T,T,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,T,T,T, X,X,T,T, X,X,X,X, T,T,T,T, T,X,T,X, X,X],
	[X,X,X,X, X,X,X,X, T,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X,X,T, X,X,X,X, X,X,X,T, X,X,X,X, X,X],
	[X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,X, T,X],
	[X,T,T,T, X,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,X,X, T,X],
	[X,X,X,X, X,X,T,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X],
	[X,T,T,T, T,T,X,T, T,T,X,X, X,X,T,T, T,X,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,X],
	[X,X,X,X, X,X,X,X, X,X,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X],
	[T,T,T,X, X,X,T,T, T,X,T,T, T,T,X,X, X,T,X,X, X,T,X,T, X,X,T,X, X,X,X,X, T,T,T,X, T,X,T,X, X,X],
	[T,T,T,X, X,X,T,T, X,T,T,T, T,T,X,X, X,T,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,X,X, X,X,T,X, X,X],
	]
end

