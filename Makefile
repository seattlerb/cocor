
JAVA=Comp.java DFA.java ErrorStream.java Parser.java ParserGen.java Scanner.java Sets.java Tab.java Trace.java
CLASSES=$(patsubst %.java, build/Coco/%.class, $(JAVA))

build/Coco/%.class: %.java
	javac -d build $^

all: build coco
# java

coco:
	chmod -R a+w build
	cp *.rb *.frame *.ATG build
	cp Makefile.sub build/Makefile
	(cd build; java Coco.Comp Coco.ATG)
	(cd build; ruby -cw *.rb)
	(cd build; $(MAKE))
	(cp Makefile.sub build/build/Makefile; cd build/build; $(MAKE))

# java: build $(CLASSES)

build:
	mkdir build
	javac -d build *.java

clean:
	rm -rf build *~
