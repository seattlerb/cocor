LINKS = BitSet.rb Comp.rb DFA.rb Parser.frame ParserGen.rb Scanner.frame Sets.rb Tab.rb Trace.rb

GENFILES = Parser.rb Scanner.rb ErrorStream.rb

G=Stupid.ATG
I=input2.txt

all: links
	rm -f $(GENFILES)
	java Coco.Comp $(G)
	ruby Comp.rb $(I)

links:
	ln -sf ../build/Coco .
	for f in $(LINKS); do if [ -f ../$$f ]; then ln -sf ../$$f .; fi; done

clean:
	rm -f Coco $(GENFILES) listing $(LINKS) *~
