
.FORCE: all
all: build
	chmod -R a+w build
	cp *.rb *.frame *.ATG build
	cp Makefile.sub build/Makefile
	(cd build; java Coco.Comp Coco.ATG)
	(cd build; ruby -cw *.rb)
	(cd build; $(MAKE))
	(cp Makefile.sub build/build/Makefile; cd build/build; $(MAKE))

java: build
	javac -d build *.java

build:
	mkdir build

clean:
	rm -rf build *~
