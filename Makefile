
RUBY=BitSet.rb Comp.rb DFA.rb ParserGen.rb Sets.rb Tab.rb Trace.rb module-hack.rb
FRAMES=Parser.frame Scanner.frame

.FORCE: all
all:
	rm -rf build
	mkdir build
	cp $(RUBY) $(FRAMES) Coco.ATG build
	ruby -w Comp.rb build/Coco.ATG &> build/output
	(cd build; ruby -cw *.rb)
	mkdir build/build2
	cp $(RUBY) $(FRAMES) Coco.ATG build/build2
	(cd build; ruby -w Comp.rb build2/Coco.ATG &> build2/output)
	mv build/build2 .
	diff build/output build2/output

clean:
	rm -rf build build[1-9] *~

