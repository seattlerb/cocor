package Coco;

import java.io.*;

class Trace {
	static PrintStream out;
	
	static void Init(String dir) {
		OutputStream s;
		try {
			s = new BufferedOutputStream(new FileOutputStream(dir + "listing"));
			out = new PrintStream(s);
		}
		catch (IOException e) {
			Scanner.err.Exception("-- could not open trace file");
		}
	}

	static void print(String s) {
		out.print(s);
	}

	static void println(String s) {
		out.println(s);
	}
	
	static void println() {
		out.println();
	}
}
