
SHELL=/bin/bash

LINKS = BitSet.rb Comp.rb DFA.rb Parser.frame ParserGen.rb Scanner.frame Sets.rb Tab.rb Trace.rb Parser.rb Scanner.rb ErrorStream.rb module-hack.rb

# TODO: split this loop up and make it work via make.
all: links
	rm -rf build; \
	mkdir build; \
	for g in *.ATG; do \
	  echo $$g; \
	  d=build/$$(basename $$g .ATG); \
	  r=$$d/ruby; \
	  mkdir -p $$r; \
	  cp *.frame $$g $$r; \
	  ruby -w Comp.rb $$r/$$g; \
	done

links: build
	chmod -R a+w build
	for f in $(LINKS); do \
	  ln -sf ../build2/$$f . ; \
	done
	for f in *.frame; do ln -sf ../$$f build; done

build:
	mkdir build

clean:
	rm -rf Coco listing build $(LINKS) *~

