
#Trace output
#  0: prints the states of the scanner automaton
#  1: prints the First and Follow sets of all nonterminals
#  2: prints the syntax graph of the productions
#  3: traces the computation of the First sets
#  6: prints the symbol table (terminals, nonterminals, pragmas)
#  7: prints a cross reference list of all syntax symbols
#  8: prints statistics about the Coco run
#  
#Trace output can be switched on by the pragma
#     $ {digit}
#in the attributed grammar.

require 'DFA'
require 'ErrorStream'
require 'Parser'
require 'ParserGen'
require 'Scanner'
require 'Tab'
require 'Trace'

class Errors < ErrorStream
    
  def SemErr (n, line, col)
    super(n, line, col)
    case (n)
    when 3
      s = "a literal must not have attributes"
    when 4
      s = "this symbol kind is not allowed in a production"
    when 5
      s = "attribute mismatch between declaration and use of this symbol"
    when 6
      s = "undefined string in production"
    when 7
      s = "name declared twice"
    when 8
      s = "this symbol kind not allowed on left side of production"
    when 11
      s = "missing production for grammar name"
    when 12
      s = "grammar symbol must not have attributes"
    when 13
      s = "a literal must not be declared with a structure"
    when 14
      s = "semantic action not allowed here"
    when 15
      s = "undefined name"
    when 17
      s = "name does not match grammar name"
    when 18
      s = "bad string in semantic action"
    when 19
      s = "missing end of previous semantic action"
    when 20
      s = "token may be empty"
    when 21
      s = "token must not start with an iteration"
    when 22
      s = "only characters allowed in comment declaration"
    when 23
      s = "only terminals may be weak"
    when 24
      s = "tokens must not contain blanks"
    when 25
      s = "comment delimited must not exceed 2 characters"
    when 26
      s = "character set contains more than 1 character"
    when 29
      s = "empty token not allowed"
    else 
      s = "error " + n
    end
    $stderr.puts(s);
  end
end

if $0 == __FILE__ then
  puts("Coco/R V1.1");
  if (ARGV.length == 0) then
    $stderr.puts("-- no file name specified")
    exit(1)
  end

  f = ARGV.shift
  file = File.basename(f)
  dir = File.dirname(f)
    
  Scanner.Init(file, Errors.new)
  Tab.Init
  DFA.Init(dir)
  ParserGen.Init(file, dir)
  Trace.Init(dir)
  Parser.Parse
  puts("#{Scanner.err.count} error(s) detected")
  Trace.out.flush()
end
