
RUBY=BitSet.rb Comp.rb DFA.rb ParserGen.rb Sets.rb Tab.rb Trace.rb module-hack.rb
FRAMES=Parser.frame Scanner.frame

.FORCE: all
all:
	rm -rf build build2
	mkdir build
	cp $(RUBY) $(FRAMES) Coco.ATG build
	ruby -w Comp.rb build/Coco.ATG &> build/output
	(cd build; ruby -cw *.rb)
	mkdir build/build2
	cp $(RUBY) $(FRAMES) Coco.ATG build/build2
	(cd build; ruby -w Comp.rb build2/Coco.ATG &> build2/output)
	mv build/build2 .
	diff build/output build2/output

bootstrap: all
	mv Parser.rb Parser.rb.prev
	mv Scanner.rb Scanner.rb.prev
	mv ErrorStream.rb ErrorStream.rb.prev
	cp build/Parser.rb build/Scanner.rb build/ErrorStream.rb .
	$(MAKE) all

rollback:
	mv Parser.rb.prev Parser.rb
	mv Scanner.rb.prev Scanner.rb
	mv ErrorStream.rb.prev ErrorStream.rb

clean:
	rm -rf build build2 *~

