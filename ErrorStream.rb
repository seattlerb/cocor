# This file is generated. DO NOT MODIFY!


class ErrorStream

	def initialize()
	  @count = 0
	end
	
	def ParsErr(n, line, col)
		s = ""
		@count += 1
		$stderr.print("-- line " + line + " col " + col + ": ")
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
			when 26; s = "'[' expected"
			when 27; s = "']' expected"
			when 28; s = "',' expected"
			when 29; s = "'>' expected"
			when 30; s = "'<.' expected"
			when 31; s = "'.>' expected"
			when 32; s = "'|' expected"
			when 33; s = "'WEAK' expected"
			when 34; s = "'{' expected"
			when 35; s = "'}' expected"
			when 36; s = "'SYNC' expected"
			when 37; s = "'CONTEXT' expected"
			when 38; s = "'(.' expected"
			when 39; s = "'.)' expected"
			when 40; s = "??? expected"
			when 41; s = "invalid TokenFactor"
			when 42; s = "invalid Attribs"
			when 43; s = "invalid Attribs"
			when 44; s = "invalid Attribs"
			when 45; s = "invalid Attribs"
			when 46; s = "invalid Attribs"
			when 47; s = "invalid Factor"
			when 48; s = "invalid Term"
			when 49; s = "invalid Symbol"
			when 50; s = "invalid SimSet"
			when 51; s = "this symbol not expected in TokenDecl"
			when 52; s = "invalid TokenDecl"
			when 53; s = "invalid AttrDecl"
			when 54; s = "invalid Declaration"
			when 55; s = "invalid Declaration"
			when 56; s = "this symbol not expected in Coco"

		else s = "error " + n
		end
		$stderr.puts(s);
	end
	
	def SemErr(n, line, col)
		@count += 1
		$stderr.print("-- line " + line + " col " + col + ": ")
	end
	
	def Exception(s)
		$stderr.puts(s)
		exit(1)
	end
	
end
