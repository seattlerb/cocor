package Coco;

class ErrorStream {

	int count;	// number of errors detected
	
	ErrorStream() {
		count = 0;
	}
	
	void ParsErr(int n, int line, int col) {
		String s;
		count++;
		System.err.print("-- line " + line + " col " + col + ": ");
		switch (n) {
			case 0: {s = "EOF expected"; break;}
			case 1: {s = "ident expected"; break;}
			case 2: {s = "string expected"; break;}
			case 3: {s = "number expected"; break;}
			case 4: {s = "badString expected"; break;}
			case 5: {s = "'COMPILER' expected"; break;}
			case 6: {s = "'PRODUCTIONS' expected"; break;}
			case 7: {s = "'=' expected"; break;}
			case 8: {s = "'.' expected"; break;}
			case 9: {s = "'END' expected"; break;}
			case 10: {s = "'CHARACTERS' expected"; break;}
			case 11: {s = "'TOKENS' expected"; break;}
			case 12: {s = "'PRAGMAS' expected"; break;}
			case 13: {s = "'COMMENTS' expected"; break;}
			case 14: {s = "'FROM' expected"; break;}
			case 15: {s = "'TO' expected"; break;}
			case 16: {s = "'NESTED' expected"; break;}
			case 17: {s = "'IGNORE' expected"; break;}
			case 18: {s = "'+' expected"; break;}
			case 19: {s = "'-' expected"; break;}
			case 20: {s = "'CHR' expected"; break;}
			case 21: {s = "'(' expected"; break;}
			case 22: {s = "')' expected"; break;}
			case 23: {s = "'ANY' expected"; break;}
			case 24: {s = "'<' expected"; break;}
			case 25: {s = "'^' expected"; break;}
			case 26: {s = "'[' expected"; break;}
			case 27: {s = "']' expected"; break;}
			case 28: {s = "',' expected"; break;}
			case 29: {s = "'>' expected"; break;}
			case 30: {s = "'<.' expected"; break;}
			case 31: {s = "'.>' expected"; break;}
			case 32: {s = "'|' expected"; break;}
			case 33: {s = "'WEAK' expected"; break;}
			case 34: {s = "'{' expected"; break;}
			case 35: {s = "'}' expected"; break;}
			case 36: {s = "'SYNC' expected"; break;}
			case 37: {s = "'CONTEXT' expected"; break;}
			case 38: {s = "'(.' expected"; break;}
			case 39: {s = "'.)' expected"; break;}
			case 40: {s = "??? expected"; break;}
			case 41: {s = "invalid TokenFactor"; break;}
			case 42: {s = "invalid Attribs"; break;}
			case 43: {s = "invalid Attribs"; break;}
			case 44: {s = "invalid Attribs"; break;}
			case 45: {s = "invalid Attribs"; break;}
			case 46: {s = "invalid Attribs"; break;}
			case 47: {s = "invalid Factor"; break;}
			case 48: {s = "invalid Term"; break;}
			case 49: {s = "invalid Symbol"; break;}
			case 50: {s = "invalid SimSet"; break;}
			case 51: {s = "this symbol not expected in TokenDecl"; break;}
			case 52: {s = "invalid TokenDecl"; break;}
			case 53: {s = "invalid AttrDecl"; break;}
			case 54: {s = "invalid Declaration"; break;}
			case 55: {s = "invalid Declaration"; break;}
			case 56: {s = "this symbol not expected in Coco"; break;}

			default: s = "error " + n;
		}
		System.err.println(s);
	}
	
	void SemErr(int n, int line, int col) {
		count++;
		System.err.print("-- line " + line + " col " + col + ": ");
	}
	
	void Exception (String s) {
	    System.err.println(s); 
	    System.exit(1);
	}
	
}
