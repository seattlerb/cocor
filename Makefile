
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
	(cd build; java Coco.Comp Coco.ATG &> output)
	(cd build; ruby -cw *.rb)
	(cd build; $(MAKE))
	rm -rf build[1-9]
	mv build/build2 .
	mv build2/build3 .
	diff -r build build2 | cat -e

build:
	mkdir build
	javac -d build *.java

diff: all
	-echo -n "1&2: "; ./qfind.sh build/output build2/output
	-echo -n "2&3: "; ./qfind.sh build2/output build3/output
	-./qformat.pl build/output
	-./qformat.pl build2/output
	-./qformat.pl build3/output

clean:
	rm -rf build build[1-9] *~

