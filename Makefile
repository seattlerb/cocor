
RUBY=BitSet.rb Comp.rb DFA.rb ParserGen.rb Sets.rb Tab.rb Trace.rb module-hack.rb
FRAMES=Parser.frame Scanner.frame

build/Coco/%.class: %.java
	javac -d build $^

all: build coco
# java

coco:
	chmod -R a+w build
	cp $(RUBY) $(FRAMES) Coco.ATG build
	cp Makefile.sub build/Makefile
	(cd build; java Coco.Comp Coco.ATG)
	(cd build; ruby -cw *.rb)
	(cd build; $(MAKE))

build:
	mkdir build
	javac -d build *.java

clean:
	rm -rf build *~


