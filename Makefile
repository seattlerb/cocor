
.FORCE: all
all:
	rm -rf build
	mkdir build
	javac -d build *.java
	cp *.rb *.frame *.ATG build
	cp Makefile.sub build/Makefile
	(cd build; java Coco.Comp Coco.ATG)
	(cd build; ruby -cw *.rb)
	(cd build; $(MAKE))
	(cp Makefile.sub build/build/Makefile; cd build/build; $(MAKE))
