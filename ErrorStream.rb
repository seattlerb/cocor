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
			when 1; s = "EOF expected"
			when 2; s = "ident expected"
			when 3; s = "string expected"
			when 4; s = "number expected"
			when 5; s = "badString expected"
			when 6; s = "'COMPILER' expected"
			when 7; s = "'PRODUCTIONS' expected"
			when 8; s = "'=' expected"
			when 9; s = "'.' expected"
			when 10; s = "'END' expected"
			when 11; s = "'CHARACTERS' expected"
			when 12; s = "'TOKENS' expected"
			when 13; s = "'PRAGMAS' expected"
			when 14; s = "'COMMENTS' expected"
			when 15; s = "'FROM' expected"
			when 16; s = "'TO' expected"
			when 17; s = "'NESTED' expected"
			when 18; s = "'IGNORE' expected"
			when 19; s = "'+' expected"
			when 20; s = "'-' expected"
			when 21; s = "'CHR' expected"
			when 22; s = "'(' expected"
			when 23; s = "')' expected"
			when 24; s = "'ANY' expected"
			when 25; s = "'<' expected"
			when 26; s = "'^' expected"
			when 27; s = "',' expected"
			when 28; s = "'>' expected"
			when 29; s = "'|' expected"
			when 30; s = "'WEAK' expected"
			when 31; s = "'[' expected"
			when 32; s = "']' expected"
			when 33; s = "'{' expected"
			when 34; s = "'}' expected"
			when 35; s = "'SYNC' expected"
			when 36; s = "'CONTEXT' expected"
			when 37; s = "'(.' expected"
			when 38; s = "'.)' expected"
			when 39; s = "??? expected"
			when 40; s = "invalid TokenFactor"
			when 41; s = "invalid Attribs"
			when 42; s = "invalid Attribs"
			when 43; s = "invalid Factor"
			when 44; s = "invalid Term"
			when 45; s = "invalid Symbol"
			when 46; s = "invalid SimSet"
			when 47; s = "this symbol not expected in TokenDecl"
			when 48; s = "invalid TokenDecl"
			when 49; s = "invalid Declaration"
			when 50; s = "invalid Declaration"
			when 51; s = "this symbol not expected in Coco"

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
