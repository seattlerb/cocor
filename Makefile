
RUBY=ruby
RUBYFLAGS=-w
RUBYFILES=BitSet.rb Comp.rb DFA.rb ParserGen.rb Sets.rb Tab.rb Trace.rb module-hack.rb
FRAMES=Parser.frame Scanner.frame

.FORCE: all
all:
	rm -rf build build2
	mkdir build
	cp $(RUBYFILES) $(FRAMES) Coco.ATG build
	$(RUBY) $(RUBYFLAGS) Comp.rb build/Coco.ATG
	(cd build; $(RUBY) $(RUBYFLAGS) -c *.rb)
	mkdir build/build2
	cp $(RUBYFILES) $(FRAMES) Coco.ATG build/build2
	(cd build; $(RUBY) $(RUBYFLAGS) Comp.rb build2/Coco.ATG)
	mv build/build2 .
	-diff build/listing build2/listing
	diff -r build build2

bootstrap: all
	mv Parser.rb Parser.rb.prev
	mv Scanner.rb Scanner.rb.prev
	mv ErrorStream.rb ErrorStream.rb.prev
	cp build/Parser.rb build/Scanner.rb build/ErrorStream.rb .
	$(MAKE) all

force-bootstrap:
	mv Parser.rb Parser.rb.prev
	mv Scanner.rb Scanner.rb.prev
	mv ErrorStream.rb ErrorStream.rb.prev
	cp build/Parser.rb build/Scanner.rb build/ErrorStream.rb .

diff-bootstrap:
	-diff Parser.rb Parser.rb.prev
	-diff Scanner.rb Scanner.rb.prev
	-diff ErrorStream.rb ErrorStream.rb.prev

rollback:
	mv Parser.rb.prev Parser.rb
	mv Scanner.rb.prev Scanner.rb
	mv ErrorStream.rb.prev ErrorStream.rb

profile:
	$(RUBY) $(RUBYFLAGS) -rprofile Comp.rb build/Coco.ATG

occur:
	$(RUBY) $(RUBYFLAGS) Comp.rb build/Coco.ATG 2>&1 | occur

clean:
	rm -rf build build2 *.prev *~

