# This file is generated. DO NOT MODIFY!


class ErrorStream

	attr_accessor :count

	def initialize()
	  @count = 0
	end

	def ==(o)
	  !o.nil? &&
	    @count == o.count
	end
	
	def ParsErr(n, line, col)
		s = ""
		@count += 1
		$stderr.print("-- line #{line} col #{col}: ")
		case (n)
			when 0; s = "EOF expected"
			when 1; s = "ident expected"
			when 2; s = "string expected"
			when 3; s = "number expected"
			when 4; s = "badString expected"
			when 5; s = "'COMPILER' expected"
			when 6; s = "'PRODUCTIONS' expected"
			when 7; s = "'=' expected"
			when 8; s = "'.' expected"
			when 9; s = "'END' expected"
			when 10; s = "'CHARACTERS' expected"
			when 11; s = "'TOKENS' expected"
			when 12; s = "'PRAGMAS' expected"
			when 13; s = "'COMMENTS' expected"
			when 14; s = "'FROM' expected"
			when 15; s = "'TO' expected"
			when 16; s = "'NESTED' expected"
			when 17; s = "'IGNORE' expected"
			when 18; s = "'+' expected"
			when 19; s = "'-' expected"
			when 20; s = "'CHR' expected"
			when 21; s = "'(' expected"
			when 22; s = "')' expected"
			when 23; s = "'ANY' expected"
			when 24; s = "'<' expected"
			when 25; s = "'^' expected"
			when 26; s = "',' expected"
			when 27; s = "'>' expected"
			when 28; s = "'|' expected"
			when 29; s = "'WEAK' expected"
			when 30; s = "'[' expected"
			when 31; s = "']' expected"
			when 32; s = "'{' expected"
			when 33; s = "'}' expected"
			when 34; s = "'SYNC' expected"
			when 35; s = "'CONTEXT' expected"
			when 36; s = "'(.' expected"
			when 37; s = "'.)' expected"
			when 38; s = "??? expected"
			when 39; s = "invalid TokenFactor"
			when 40; s = "invalid Attribs"
			when 41; s = "invalid Attribs"
			when 42; s = "invalid Factor"
			when 43; s = "invalid Term"
			when 44; s = "invalid Symbol"
			when 45; s = "invalid SimSet"
			when 46; s = "this symbol not expected in TokenDecl"
			when 47; s = "invalid TokenDecl"
			when 48; s = "invalid Declaration"
			when 49; s = "invalid Declaration"
			when 50; s = "this symbol not expected in Coco"

		else s = "error #{n}"
		end
		$stderr.puts(s);
	end
	
	def SemErr(n, line, col)
		@count += 1
		$stderr.print("-- line #{line} col #{col}: ")
	end
	
	def Exception(s)
		$stderr.puts(s)
		exit(1)
	end
	
end
