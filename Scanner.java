package Coco;
import java.io.*;
import java.util.*;

class Token {
	int kind;		// token kind
	int pos;		// token position in the source text (starting at 0)
	int col;		// token column (starting at 0)
	int line;		// token line (starting at 1)
	String val;		// token value
}

class Buffer {
	static byte[] buf;
	static int bufLen;
	static int pos;
	
	static void Fill(String name) {
	    InputStream s;
		int n;
		try {
			s = new FileInputStream(name);
			bufLen = s.available();
			s = new BufferedInputStream(s, bufLen);
			buf = new byte[bufLen];
			n = s.read(buf); pos = 0;
		} catch (IOException e) {
			System.out.println("--- cannot open file " + name);
			System.exit(0);
		}
	}
	
	static void Set(int position) {
		if (position < 0) position = 0; else if (position >= bufLen) position = bufLen;
		pos = position;
	}
	
	static int read() {
	    int c;
		if (pos < bufLen)
			c= (int) buf[pos++];
		else
			c= 65535;
	    return c;
	}
}

class Scanner {

	static ErrorStream err;	// error messages

	private static final char EOF = '\0';
	private static final char EOL = '\r';
        private static final char NL = '\n';
	private static final int noSym = 40;
	private static final int[] start = {
 27,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  0,  0,  6,  0,  5,  0,  0,  7, 12, 13,  0, 10, 18, 11,  9,  0,
  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  0,  0, 14,  8, 19,  0,
  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 16,  0, 17, 15,  0,
  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 23, 22, 24,  0,  0,
  0};


	private static Token t;			// current token
	private static char ch;			// current input character
	private static int pos;			// position of current character
	private static int line;		// line number of current character
	private static int lineStart;	// start position of current line
	private static int oldEols;		// >0: no. of EOL in a comment;
	private static BitSet ignore;	// set of characters to be ignored by the scanner

	static void Init (String file, ErrorStream e) {
		ignore = new BitSet(128);
		ignore.set(9); ignore.set(10); ignore.set(13); ignore.set(32); 
		err = e;
		Buffer.Fill(file);
		pos = -1; line = 1; lineStart = 0;
		oldEols = 0;
		NextCh();
	}
	
	static void Init (String file) {
		Init(file, new ErrorStream());
	}
	
	private static void NextCh() {
		if (oldEols > 0) {
			ch = EOL; oldEols--;
		} else {
			ch = (char) Buffer.read(); pos++;
			if (ch==EOL) {line++; lineStart = pos + 1;}
			if (ch==NL) {line++; lineStart = pos + 1;}
		}
		if (ch > '\u007f') {
			if (ch == '\uffff') ch = EOF;
			else {
				System.out.println("-- invalid character at line " + line + " col " + (pos - lineStart));
				ch = ' ';
			}
		}
	}
	
private static boolean Comment0() {
	int level = 1, line0 = line, lineStart0 = lineStart; char startCh;
	NextCh();
	if (ch=='*') {
		NextCh();
		for(;;) {
			if (ch=='*') {
				NextCh();
				if (ch=='/') {
					level--;
					if (level==0) {oldEols=line-line0; NextCh(); return true;}
					NextCh();
				}
			} else if (ch=='/') {
				NextCh();
				if (ch=='*') {
					level++; NextCh();
				}
			} else if (ch==EOF) return false;
			else NextCh();
		}
	} else {
	    if (ch==EOL) {line--; lineStart = lineStart0;}
	    if (ch==NL)  {line--; lineStart = lineStart0;}
		pos = pos - 2; Buffer.Set(pos+1); NextCh();
	}
	return false;
}

	
	private static void CheckLiteral() {
		switch (t.val.charAt(0)) {
			case 'A': {
				if (t.val.equals("ANY")) t.kind = 23;
				break;}
			case 'C': {
				if (t.val.equals("CHARACTERS")) t.kind = 10;
				else if (t.val.equals("CHR")) t.kind = 20;
				else if (t.val.equals("COMMENTS")) t.kind = 13;
				else if (t.val.equals("COMPILER")) t.kind = 5;
				else if (t.val.equals("CONTEXT")) t.kind = 37;
				break;}
			case 'E': {
				if (t.val.equals("END")) t.kind = 9;
				break;}
			case 'F': {
				if (t.val.equals("FROM")) t.kind = 14;
				break;}
			case 'I': {
				if (t.val.equals("IGNORE")) t.kind = 17;
				break;}
			case 'N': {
				if (t.val.equals("NESTED")) t.kind = 16;
				break;}
			case 'P': {
				if (t.val.equals("PRAGMAS")) t.kind = 12;
				else if (t.val.equals("PRODUCTIONS")) t.kind = 6;
				break;}
			case 'S': {
				if (t.val.equals("SYNC")) t.kind = 36;
				break;}
			case 'T': {
				if (t.val.equals("TO")) t.kind = 15;
				else if (t.val.equals("TOKENS")) t.kind = 11;
				break;}
			case 'W': {
				if (t.val.equals("WEAK")) t.kind = 33;
				break;}

		}
	}

	static Token Scan() {
		int state, apx, i;
		StringBuffer buf;
		while (ignore.get((int)ch)) NextCh();
		if (ch=='/' && Comment0() ) return Scan();
		t = new Token();
		t.pos = pos; t.col = pos - lineStart; t.line = line; 
		buf = new StringBuffer();
		state = start[ch];
		apx = 0;
		loop: for (;;) {
			buf.append(ch);
			NextCh();
			switch (state) {
				case 0: {t.kind = noSym; break loop;} // NextCh already done
				case 1:
					if ((ch>='0' && ch<='9' || ch>='A' && ch<='Z' || ch>='a' && ch<='z')) {break;}
					else {t.kind = 1; t.val = buf.toString(); CheckLiteral(); break loop;}
				case 2:
					{t.kind = 2; break loop;}
				case 3:
					if ((ch>='0' && ch<='9')) {break;}
					else {t.kind = 3; break loop;}
				case 4:
					{t.kind = 4; break loop;}
				case 5:
					if ((ch>='0' && ch<='9')) {break;}
					else {t.kind = 41; break loop;}
				case 6:
					if ((ch<=12 || ch>=14 && ch<='!' || ch>='#')) {break;}
					else if ((ch==13)) {state = 4; break;}
					else if ((ch==10)) {state = 4; break;}
					else if (ch=='"') {state = 2; break;}
					else {t.kind = noSym; break loop;}
				case 7:
					if ((ch<=12 || ch>=14 && ch<='&' || ch>='(')) {break;}
					else if ((ch==13)) {state = 4; break;}
					else if ((ch==10)) {state = 4; break;}
					else if (ch==39) {state = 2; break;}
					else {t.kind = noSym; break loop;}
				case 8:
					{t.kind = 7; break loop;}
				case 9:
					if (ch=='>') {state = 21; break;}
					else if (ch==')') {state = 26; break;}
					else {t.kind = 8; break loop;}
				case 10:
					{t.kind = 18; break loop;}
				case 11:
					{t.kind = 19; break loop;}
				case 12:
					if (ch=='.') {state = 25; break;}
					else {t.kind = 21; break loop;}
				case 13:
					{t.kind = 22; break loop;}
				case 14:
					if (ch=='.') {state = 20; break;}
					else {t.kind = 24; break loop;}
				case 15:
					{t.kind = 25; break loop;}
				case 16:
					{t.kind = 26; break loop;}
				case 17:
					{t.kind = 27; break loop;}
				case 18:
					{t.kind = 28; break loop;}
				case 19:
					{t.kind = 29; break loop;}
				case 20:
					{t.kind = 30; break loop;}
				case 21:
					{t.kind = 31; break loop;}
				case 22:
					{t.kind = 32; break loop;}
				case 23:
					{t.kind = 34; break loop;}
				case 24:
					{t.kind = 35; break loop;}
				case 25:
					{t.kind = 38; break loop;}
				case 26:
					{t.kind = 39; break loop;}
				case 27: {t.kind = 0; break loop;}
			}
		}
		t.val = buf.toString();
		return t;
	}

}
