Coco/R(uby)
    http://www.zenspider.com/
    support@zenspider.com

DESCRIPTION:
  
(Stolen from http://www.scifac.ru.ac.za/coco/)

Coco/R combines the functionality of the well-known UNIX tools lex and
yacc , to form an extremely easy to use compiler generator that
generates recursive descent parsers, their associated scanners, and
(in some versions) a driver program, from attributed grammars (written
using EBNF syntax with attributes and semantic actions) which conform
to the restrictions imposed by LL(1) parsing (rather than LALR
parsing, as allowed by yacc ). The user has to add modules for symbol
table handling, optimization, and code generation in order to get a
running compiler. Coco/R can also be used to construct other
syntax-based applications that have less of a "compiler" flavour.

(Not stolen)

Coco/R(uby) is a port of Coco/R to ruby and generates pure ruby
parsers and scanners. This version of Coco/R is not related to Mark
Probert's version (http://raa.ruby-lang.org/list.rhtml?name=coco-rb).

This version of Coco/R generates pure ruby. Mark's version generates C
for ruby extensions. If you find this version too slow, you might want
to check out Mark's. If however, you need pure ruby or can't deploy
where there is a C compiler, you finally have an LL solution.

FEATURES/PROBLEMS:
  
+ Happy neato ruby parsers and lexers.
- Not clean. Design needs massive cleanup.
- Needs actual documentation (unless you've used coco/r before).

SYNOPSYS:

  None yet...

REQUIREMENTS:

+ Ruby

INSTALL:

+ None

LICENSE:

(The MIT License)

Copyright (c) 2001-2002 Ryan Davis, Zen Spider Software

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
