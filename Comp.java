/*--------------------------------------------
Trace output
  0: prints the states of the scanner automaton
  1: prints the First and Follow sets of all nonterminals
  2: prints the syntax graph of the productions
  3: traces the computation of the First sets
  6: prints the symbol table (terminals, nonterminals, pragmas)
  7: prints a cross reference list of all syntax symbols
  8: prints statistics about the Coco run
  
Trace output can be switched on by the pragma
     $ {digit}
in the attributed grammar.
--------------------------------------------*/
package Coco;

class Errors extends ErrorStream {

	void SemErr (int n, int line, int col) {
		String s;
		super.SemErr(n, line, col);
		switch (n) {
			case  3: {s = "a literal must not have attributes"; break;}
			case  4: {s = "this symbol kind is not allowed in a production"; break;}
			case  5: {s = "attribute mismatch between declaration and use of this symbol"; break;}
			case  6: {s = "undefined string in production"; break;}
			case  7: {s = "name declared twice"; break;}
			case  8: {s = "this symbol kind not allowed on left side of production"; break;}
			case 11: {s = "missing production for grammar name"; break;}
			case 12: {s = "grammar symbol must not have attributes"; break;}
			case 13: {s = "a literal must not be declared with a structure"; break;}
			case 14: {s = "semantic action not allowed here"; break;}
			case 15: {s = "undefined name"; break;}
			case 17: {s = "name does not match grammar name"; break;}
			case 18: {s = "bad string in semantic action"; break;}
			case 19: {s = "missing end of previous semantic action"; break;}
			case 20: {s = "token may be empty"; break;}
			case 21: {s = "token must not start with an iteration"; break;}
			case 22: {s = "only characters allowed in comment declaration"; break;}
			case 23: {s = "only terminals may be weak"; break;}
			case 24: {s = "tokens must not contain blanks"; break;}
			case 25: {s = "comment delimited must not exceed 2 characters"; break;}
			case 26: {s = "character set contains more than 1 character"; break;}
			case 29: {s = "empty token not allowed"; break;}
			default: {s = "error " + n; break;}
		}
		System.out.println(s);
	}
}

public class Comp {

	public static void main (String[] args) {
		System.out.println("Coco/R V1.1");
		if (args.length == 0) { System.out.println("-- no file name specified"); System.exit(0); }
		int pos = args[0].lastIndexOf('/');
		if (pos < 0) pos = args[0].lastIndexOf('\\');
		String file = args[0];
		String dir = args[0].substring(0, pos+1);

		Scanner.Init(file, new Errors());
		Tab.Init(); DFA.Init(dir); ParserGen.Init(file, dir); Trace.Init(dir);
		Parser.Parse();
		System.out.println(Scanner.err.count + " error(s) detected");
		Trace.out.flush();
	}

}
