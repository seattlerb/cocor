package Coco;

import java.util.BitSet;

class Sets {

	static boolean Empty(BitSet s) {			/** s=={}? */
	    boolean r = true;
		int max = s.size();
		for (int i=0; i<=max && r; i++) {
			if (s.get(i)) r = false;
		}
		return r;
	}
	
	static boolean Different(BitSet s1, BitSet s2) {	/** s1*s2=={}? */
	    boolean r = true;
		int max = s1.size();
		for (int i=0; i<=max && r; i++)
			if (s1.get(i) && s2.get(i)) r = false;
		return r;
	}
	
	static boolean Includes(BitSet s1, BitSet s2) {	/** s1 > s2 ? */
	    boolean r = true;
		int max = s2.size();
		for (int i=0; i<=max && r; i++)
			if (s2.get(i) && !s1.get(i)) r = false;
		return r;
	}
	
	static BitSet FullSet(int max) {			/** return {0..max} */
		BitSet s = new BitSet();
		for (int i=0; i<=max; i++) s.set(i);
		return s;
	}
	
	static int Size(BitSet s) {					/** return number of elements in s */
		int size = 0, max = s.size();
		for (int i=0; i<=max; i++)
			if (s.get(i)) size++;
		return size;
	}
	
	static int First(BitSet s) {				/** return first element in s */
	    int r = -1;
		int max = s.size();
		for (int i=0; i<=max && r < 0; i++)
			if (s.get(i)) r = i;
		return r;
	}
	
	static void Differ(BitSet s, BitSet s1) {	/** s = s - s1 */
		int max = s.size();
		for (int i=0; i<=max; i++) {
			if (s1.get(i)) s.clear(i);
		}
	}
	
}
