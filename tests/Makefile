LINKS = BitSet.rb Comp.rb DFA.rb Parser.frame ParserGen.rb Scanner.frame Sets.rb Tab.rb Trace.rb

all: links Coco
	java Coco.Comp Stupid.ATG
	ruby Comp.rb input.txt 

links:
	ln -sf ../build/Coco .
	for f in $(LINKS); do if [ -f ../$$f ]; then ln -sf ../$$f .; fi; done

clean:
	rm -f Coco Parser.rb Scanner.rb ErrorStream.rb listing $(LINKS) *~
